import SwiftUI

/// Single source of truth. Persists todos and recordings as JSON in Documents.
@MainActor
final class AppStore: ObservableObject {
    struct Banner: Equatable {
        enum Kind { case processing, failed, result }
        var kind: Kind
        var recordingID: UUID
    }

    private struct Snapshot: Codable {
        var todos: [TodoItem]
        var recordings: [Recording]
    }

    @Published private(set) var todos: [TodoItem] = []
    @Published private(set) var recordings: [Recording] = []
    @Published var banner: Banner?
    struct Problem: Equatable {
        var title: String
        var message: String
    }

    /// Masalah penyimpanan yang harus diketahui pengguna (data lama tidak terbaca, gagal menyimpan).
    @Published var problem: Problem?

    private let fileURL: URL
    /// False bila data lama tidak terbaca dan gagal diamankan; mencegah data lama tertimpa.
    private var canSave = true
    /// Supaya pesan gagal menyimpan tidak muncul berulang-ulang; diulang lagi setelah ada penyimpanan yang berhasil.
    private var saveFailureShown = false

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("voice-to-todo.json")
        load()
    }

    // MARK: Queries

    func recording(_ id: UUID) -> Recording? {
        recordings.first { $0.id == id }
    }

    func todos(for recording: Recording) -> [TodoItem] {
        todos.filter { recording.todoIDs.contains($0.id) }
    }

    // MARK: Mutations

    func toggle(_ id: UUID) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[i].isDone.toggle()
        save()
    }

    /// Batas panjang teks to-do (sama dengan versi web, lihat CLAUDE.md 5.2).
    static let maxTodoLength = 280

    /// Merapikan teks to-do dari isian: baris baru jadi spasi, spasi di ujung dibuang.
    /// Nil bila kosong atau lebih dari `maxTodoLength`.
    static func cleanTodoTitle(_ raw: String) -> String? {
        let text = raw.components(separatedBy: .newlines).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, text.count <= maxTodoLength else { return nil }
        return text
    }

    /// To-do yang ditulis sendiri oleh pengguna, tidak berasal dari rekaman.
    func addTodo(title: String, category: TodoCategory) {
        guard let text = Self.cleanTodoTitle(title) else { return }
        let item = TodoItem(
            title: text,
            category: category,
            due: nil,
            source: "ditulis sendiri, \(Formatters.short.string(from: Date()))"
        )
        todos.insert(item, at: 0)
        save()
    }

    func editTodo(_ id: UUID, title: String) {
        guard let text = Self.cleanTodoTitle(title),
              let i = todos.firstIndex(where: { $0.id == id }),
              todos[i].title != text else { return }
        todos[i].title = text
        save()
    }

    func deleteTodo(_ id: UUID) {
        todos.removeAll { $0.id == id }
        for i in recordings.indices {
            recordings[i].todoIDs.removeAll { $0 == id }
        }
        save()
    }

    /// Menghapus rekaman beserta to-do dan file audionya. Rekaman yang sedang diproses tidak bisa dihapus.
    func deleteRecording(_ id: UUID) {
        guard let rec = recording(id), rec.status != .processing else { return }
        todos.removeAll { $0.recordingID == id || rec.todoIDs.contains($0.id) }
        recordings.removeAll { $0.id == id }
        if banner?.recordingID == id { banner = nil }
        // Audio hanya dihapus bila data baru berhasil disimpan. Kalau gagal, rekaman muncul lagi saat aplikasi
        // dibuka, jadi audionya harus masih ada.
        guard save(), let name = rec.audioFileName, !name.isEmpty else { return }
        try? FileManager.default.removeItem(at: SpeechRecorder.folder.appendingPathComponent(name))
    }

    func updateSummary(_ recordingID: UUID, text: String) {
        update(recordingID) { $0.summary = text }
    }

    func dismissResultBanner() {
        if banner?.kind != .processing { banner = nil }
    }

    func finishRecording(_ audio: RecordedAudio) {
        let rec = Recording(
            title: "Rekaman baru",
            category: .rapat,
            status: .processing,
            duration: audio.duration,
            transcript: audio.transcript,
            audioFileName: audio.fileName,
            stopNote: audio.stopNote
        )
        recordings.insert(rec, at: 0)
        banner = Banner(kind: .processing, recordingID: rec.id)
        save()
        Task { await process(rec.id) }
    }

    func retry(_ id: UUID) {
        Task { await process(id) }
    }

    // MARK: Processing pipeline

    private func process(_ id: UUID) async {
        guard let current = recording(id) else { return }
        update(id) { $0.status = .processing }
        banner = Banner(kind: .processing, recordingID: id)

        var transcript = current.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        var audioMissing = false
        var recognizerUnavailable = false
        if Self.wordCount(transcript) < Self.minWords {
            // Transkrip langsung kosong atau terlalu pendek: dengarkan ulang dari file audio yang tersimpan.
            // Dulu hanya dicoba saat kosong, jadi transkrip 1-2 kata membuat "Coba lagi" selalu gagal dengan hasil sama.
            let audioURL = current.audioFileName.map { SpeechRecorder.folder.appendingPathComponent($0) }
            if let audioURL, FileManager.default.fileExists(atPath: audioURL.path) {
                if SpeechTranscriber.isAvailable {
                    let fromFile = (await SpeechTranscriber.transcribe(url: audioURL) ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if Self.wordCount(fromFile) > Self.wordCount(transcript) {
                        transcript = fromFile
                    }
                } else {
                    recognizerUnavailable = true
                }
            } else {
                audioMissing = true
            }
        }

        let words = Self.wordCount(transcript)
        guard words >= Self.minWords else {
            let reason: FailReason
            if audioMissing { reason = .noAudio }
            else if recognizerUnavailable { reason = .recognizerUnavailable }
            else if words == 0 { reason = .noSpeech }
            else { reason = .tooShort }
            update(id) { $0.status = .failed; $0.failReason = reason; $0.transcript = transcript; $0.summary = "Rekamanmu aman tersimpan." }
            banner = Banner(kind: .failed, recordingID: id)
            return
        }

        let result = await SummarizerService.summarize(transcript, date: current.createdAt)
        // Jaga-jaga: rekaman sudah tidak ada (dihapus) saat ringkasan selesai. Jangan tambahkan to-do yatim.
        guard recording(id) != nil else {
            if banner?.recordingID == id { banner = nil }
            return
        }
        let short = Formatters.short.string(from: current.createdAt)
        let newTodos = result.todos.map {
            TodoItem(
                title: $0.title,
                category: result.category,
                due: $0.due,
                source: "dari \(result.title.lowercased()), \(short)",
                recordingID: id
            )
        }

        todos.insert(contentsOf: newTodos, at: 0)
        update(id) {
            $0.status = .done
            $0.failReason = nil
            $0.title = result.title
            $0.category = result.category
            $0.summary = result.summary
            $0.points = result.points
            $0.transcript = transcript
            $0.todoIDs = newTodos.map(\.id)
        }
        banner = Banner(kind: .result, recordingID: id)
    }

    /// Transkrip di bawah jumlah kata ini dianggap terlalu pendek untuk dirangkum.
    private static let minWords = 3

    private static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    private func update(_ id: UUID, _ change: (inout Recording) -> Void) {
        guard let i = recordings.firstIndex(where: { $0.id == id }) else { return }
        change(&recordings[i])
        save()
    }

    // MARK: Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return } // pemakaian pertama
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var snapshot: Snapshot
        do {
            snapshot = try decoder.decode(Snapshot.self, from: Data(contentsOf: fileURL))
        } catch {
            // Data lama tidak terbaca (misalnya bentuk data berubah setelah update). Jangan dimulai kosong
            // lalu ditimpa: pindahkan dulu ke file cadangan supaya isinya tetap ada.
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("voice-to-todo-cadangan-\(Int(Date().timeIntervalSince1970)).json")
            do {
                try FileManager.default.moveItem(at: fileURL, to: backup)
                problem = Problem(
                    title: "Data lama tidak terbaca",
                    message: "Data lama tidak bisa dibaca, jadi aplikasi dimulai kosong. "
                        + "Salinannya aman tersimpan sebagai \(backup.lastPathComponent)."
                )
            } catch {
                canSave = false
                problem = Problem(
                    title: "Data lama tidak terbaca",
                    message: "Data lama tidak bisa dibaca. Perubahan baru tidak disimpan supaya data lama tidak tertimpa."
                )
            }
            return
        }
        // A recording left "processing" means the app was closed mid-way; let the user retry.
        for i in snapshot.recordings.indices where snapshot.recordings[i].status == .processing {
            snapshot.recordings[i].status = .failed
            snapshot.recordings[i].failReason = .interrupted
        }
        todos = snapshot.todos
        recordings = snapshot.recordings
    }

    /// True bila data berhasil ditulis ke HP.
    @discardableResult
    private func save() -> Bool {
        guard canSave else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(Snapshot(todos: todos, recordings: recordings))
            try data.write(to: fileURL, options: .atomic)
            saveFailureShown = false
            return true
        } catch {
            // Jangan gagal diam-diam: perubahan hanya ada di memori dan hilang saat aplikasi ditutup.
            guard !saveFailureShown else { return false }
            saveFailureShown = true
            problem = Problem(
                title: "Gagal menyimpan",
                message: "Perubahan terakhir belum tersimpan di HP, jadi bisa hilang saat aplikasi ditutup. "
                    + "Pastikan ruang penyimpanan HP masih cukup. (\(error.localizedDescription))"
            )
            return false
        }
    }
}
