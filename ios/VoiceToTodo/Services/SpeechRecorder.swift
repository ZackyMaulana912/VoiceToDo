import AVFoundation
import SwiftUI

struct RecordedAudio {
    let fileName: String
    let duration: Int
    var stopNote: String? = nil
}

enum PermissionResult {
    case granted
    case denied(String)
}

/// Merekam suara ke file WAV. Teks dibuat setelah rekaman selesai (Whisper, lihat `Transcriber`), jadi perekam
/// tidak butuh internet maupun izin Pengenalan Ucapan.
@MainActor
final class SpeechRecorder: ObservableObject {
    static let maxSeconds = 600
    static let barCount = 21

    @Published private(set) var elapsed = 0
    @Published private(set) var levels = [CGFloat](repeating: 0.1, count: SpeechRecorder.barCount)
    @Published var errorMessage: String?
    /// Terisi bila perekaman diputus dari luar (telepon masuk, Siri, alarm, earphone dicabut).
    /// Layar perekam memantau ini lalu menyimpan bagian yang sudah terekam.
    @Published private(set) var interruption: String?

    static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private let engine = AVAudioEngine()
    private let sink = AudioSink()
    private var timer: Timer?
    private var fileName = ""
    private var isRecording = false
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        // Telepon masuk, Siri, alarm, atau aplikasi lain mengambil alih mikrofon.
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in
                self?.interrupt("Rekaman berhenti karena ada panggilan masuk atau aplikasi lain memakai mikrofon.")
            }
        })
        // Mikrofon berganti (earphone dicabut atau disambung). Mesin audio berhenti sendiri saat ini terjadi,
        // jadi tanpa ini timer tetap jalan padahal suara tidak lagi terekam.
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.interrupt("Rekaman berhenti karena mikrofon berganti, misalnya earphone dicabut atau disambung.")
            }
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func interrupt(_ reason: String) {
        guard isRecording, interruption == nil else { return }
        interruption = reason
    }

    // MARK: Permissions

    static func requestPermissions() async -> PermissionResult {
        let micGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard micGranted else {
            return .denied("Izinkan akses Mikrofon di Pengaturan agar Voice-to-Todo bisa merekam suaramu.")
        }
        return .granted
    }

    // MARK: Recording

    func start() throws {
        errorMessage = nil
        interruption = nil
        // Lupakan nama file rekaman sebelumnya. Kalau start() gagal sebelum file baru dibuat,
        // cancel() tidak boleh menghapus file rekaman lama (atau seluruh folder saat nama kosong).
        fileName = ""

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        elapsed = 0
        levels = [CGFloat](repeating: 0.1, count: Self.barCount)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let converter = AVAudioConverter(from: inputFormat, to: RecordingFormat.format) else {
            throw NSError(domain: "VoiceToTodo", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Mikrofon tidak bisa dipakai saat ini. Tutup aplikasi lain yang memakai mikrofon, lalu coba lagi.",
            ])
        }

        fileName = "\(UUID().uuidString).wav"
        let file = try AVAudioFile(
            forWriting: Self.folder.appendingPathComponent(fileName),
            settings: RecordingFormat.format.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )
        sink.begin(file: file, converter: converter)
        sink.onLevel = { [weak self] level in
            Task { @MainActor in self?.push(level) }
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat, block: Self.makeTap(sink: sink))
        engine.prepare()
        try engine.start()

        isRecording = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsed += 1 }
        }
        ScreenAwake.set("rekam", true) // "Jaga layar tetap menyala"
    }

    /// Dibuat di luar main actor supaya thread audio tidak pernah menyentuh state milik main actor.
    nonisolated private static func makeTap(sink: AudioSink) -> AVAudioNodeTapBlock {
        { buffer, _ in sink.write(buffer) }
    }

    /// `note` diisi bila rekaman berhenti bukan karena tombol Selesai; ikut tersimpan di rekaman.
    func stop(note: String? = nil) async -> RecordedAudio {
        let frames = teardown()
        // Durasi dari jumlah sampel yang benar-benar tertulis, bukan dari timer.
        let seconds = Int((Double(frames) / RecordingFormat.sampleRate).rounded())
        return RecordedAudio(fileName: fileName, duration: seconds, stopNote: note)
    }

    func cancel() {
        _ = teardown()
        // Hanya hapus file milik rekaman yang sedang dibatalkan. Nama kosong berarti belum ada file,
        // dan appendingPathComponent("") menunjuk ke folder Recordings itu sendiri.
        if !fileName.isEmpty {
            try? FileManager.default.removeItem(at: Self.folder.appendingPathComponent(fileName))
        }
        fileName = ""
    }

    // MARK: Internals

    private func teardown() -> AVAudioFramePosition {
        isRecording = false
        timer?.invalidate()
        timer = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        let frames = sink.end()
        ScreenAwake.set("rekam", false)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return frames
    }

    private func push(_ level: CGFloat) {
        guard isRecording else { return }
        levels.removeFirst()
        levels.append(max(0.08, level))
    }
}
