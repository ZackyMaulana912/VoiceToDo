import AVFoundation
import Speech
import SwiftUI

struct RecordedAudio {
    let fileName: String
    let duration: Int
    let transcript: String
}

enum PermissionResult {
    case granted
    case denied(String)
}

/// State touched from the realtime audio thread. Kept separate from the main-actor recorder.
private final class AudioSink: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var file: AVAudioFile?
    var onLevel: (@Sendable (CGFloat) -> Void)?

    func setRequest(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock(); defer { lock.unlock() }
        self.request = request
    }

    func currentRequest() -> SFSpeechAudioBufferRecognitionRequest? {
        lock.lock(); defer { lock.unlock() }
        return request
    }

    func setFile(_ file: AVAudioFile?) {
        lock.lock(); defer { lock.unlock() }
        self.file = file
    }

    func endAudio() {
        lock.lock(); defer { lock.unlock() }
        request?.endAudio()
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let request = self.request
        let file = self.file
        lock.unlock()

        request?.append(buffer)
        try? file?.write(from: buffer)

        if let channel = buffer.floatChannelData?[0] {
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            var sum: Float = 0
            for i in 0..<count { sum += channel[i] * channel[i] }
            let rms = sqrt(sum / Float(count))
            onLevel?(CGFloat(min(1, rms * 9)))
        }
    }
}

@MainActor
final class SpeechRecorder: ObservableObject {
    static let maxSeconds = 600
    static let barCount = 21

    @Published private(set) var elapsed = 0
    @Published private(set) var levels = [CGFloat](repeating: 0.1, count: SpeechRecorder.barCount)
    @Published var errorMessage: String?

    static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private let engine = AVAudioEngine()
    private let sink = AudioSink()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "id-ID"))
    private var task: SFSpeechRecognitionTask?
    private var timer: Timer?
    private var fileName = ""
    private var committed = ""
    private var partial = ""
    private var isRecording = false
    private var isStopping = false
    private var finalReceived = false
    private var lastTaskStart = Date.distantPast

    // MARK: Permissions

    static func requestPermissions() async -> PermissionResult {
        let micGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard micGranted else {
            return .denied("Izinkan akses Mikrofon di Pengaturan agar Voice-to-Todo bisa merekam suaramu.")
        }
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else {
            return .denied("Izinkan Pengenalan Ucapan di Pengaturan agar ucapanmu bisa diubah jadi teks.")
        }
        return .granted
    }

    // MARK: Recording

    func start() throws {
        errorMessage = nil
        // Lupakan nama file rekaman sebelumnya. Kalau start() gagal sebelum file baru dibuat,
        // cancel() tidak boleh menghapus file rekaman lama (atau seluruh folder saat nama kosong).
        fileName = ""
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(
                domain: "VoiceToTodo", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Pengenalan ucapan Bahasa Indonesia belum tersedia. Periksa koneksi internet lalu coba lagi."]
            )
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        elapsed = 0
        committed = ""
        partial = ""
        isStopping = false
        finalReceived = false
        levels = [CGFloat](repeating: 0.1, count: Self.barCount)

        fileName = "\(UUID().uuidString).caf"
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        sink.setFile(try AVAudioFile(forWriting: Self.folder.appendingPathComponent(fileName), settings: format.settings))
        sink.onLevel = { [weak self] level in
            Task { @MainActor in self?.push(level) }
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format, block: Self.makeTap(sink: sink))
        engine.prepare()
        try engine.start()

        isRecording = true
        beginTask()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsed += 1 }
        }
        UIApplication.shared.isIdleTimerDisabled = true // "Jaga layar tetap menyala"
    }

    /// Created outside the main actor so the audio thread never touches actor-isolated state.
    nonisolated private static func makeTap(sink: AudioSink) -> AVAudioNodeTapBlock {
        { buffer, _ in sink.write(buffer) }
    }

    func stop() async -> RecordedAudio {
        isRecording = false
        isStopping = true
        timer?.invalidate()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        sink.endAudio()

        // Wait briefly for the recognizer to deliver its final result.
        var waited = 0.0
        while !finalReceived && waited < 4 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 0.1
        }
        if !finalReceived { commitPartial() }
        task?.cancel()
        task = nil

        teardown()
        let text = committed.trimmingCharacters(in: .whitespacesAndNewlines)
        return RecordedAudio(fileName: fileName, duration: elapsed, transcript: text)
    }

    func cancel() {
        isRecording = false
        isStopping = true
        timer?.invalidate()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        teardown()
        // Hanya hapus file milik rekaman yang sedang dibatalkan. Nama kosong berarti belum ada file,
        // dan appendingPathComponent("") menunjuk ke folder Recordings itu sendiri.
        if !fileName.isEmpty {
            try? FileManager.default.removeItem(at: Self.folder.appendingPathComponent(fileName))
        }
        fileName = ""
    }

    // MARK: Internals

    private func teardown() {
        sink.setRequest(nil)
        sink.setFile(nil)
        sink.onLevel = nil
        UIApplication.shared.isIdleTimerDisabled = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func push(_ level: CGFloat) {
        guard isRecording else { return }
        levels.removeFirst()
        levels.append(max(0.08, level))
    }

    private func commitPartial() {
        let text = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            committed += (committed.isEmpty ? "" : " ") + text
        }
        partial = ""
    }

    /// Server-side recognition stops after about a minute, so a new task is chained
    /// whenever one ends while the user is still recording.
    private func beginTask() {
        guard let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        sink.setRequest(request)
        lastTaskStart = Date()
        partial = ""

        task = Self.makeTask(recognizer: recognizer, request: request) { [weak self] text, ended in
            Task { @MainActor in self?.handle(text: text, ended: ended, request: request) }
        }
    }

    nonisolated private static func makeTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onUpdate: @escaping @Sendable (String?, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let ended = (result?.isFinal ?? false) || error != nil
            onUpdate(text, ended)
        }
    }

    private func handle(text: String?, ended: Bool, request: SFSpeechAudioBufferRecognitionRequest) {
        guard request === sink.currentRequest() else { return } // stale task
        if let text { partial = text }
        guard ended else { return }

        commitPartial()
        if isStopping {
            finalReceived = true
        } else if isRecording {
            let delay = Date().timeIntervalSince(lastTaskStart) < 1 ? 1.0 : 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.isRecording else { return }
                self.beginTask()
            }
        }
    }
}

/// Transcribes a saved audio file; used when the user taps "Coba lagi".
enum SpeechTranscriber {
    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func run(_ block: () -> Void) {
            lock.lock()
            let first = !done
            done = true
            lock.unlock()
            if first { block() }
        }
    }

    static func transcribe(url: URL) async -> String? {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "id-ID")), recognizer.isAvailable else {
            return nil
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        let once = Once()
        return await withCheckedContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                    once.run { continuation.resume(returning: text) }
                } else if error != nil {
                    once.run { continuation.resume(returning: nil) }
                }
            }
        }
    }
}
