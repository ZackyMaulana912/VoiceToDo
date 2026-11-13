import AVFoundation
import SwiftUI
import VoiceToTodoCore

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
        /// File audio dari rekaman yang dihapus, menunggu kesempatan "Urungkan" lewat. Optional supaya data lama
        /// tetap terbaca. Dibuang saat aplikasi dibuka bila aplikasi tertutup sebelum sempat dibuang.
        var trash: [String]?
    }

    /// Tawaran "Urungkan" yang sedang tampil.
    struct UndoOffer: Equatable {
        let id = UUID()
        let message: String
    }

    /// Cara membatalkan satu aksi. Disimpan per aksi (bukan salinan seluruh data), supaya hasil rekaman lain yang
    /// selesai diproses di antaranya tidak ikut hilang saat diurungkan.
    private enum UndoAction {
        case toggle(UUID)
        case editTodo(UUID, oldTitle: String)
        case deleteTodo(TodoItem, index: Int, owners: [(recordingID: UUID, index: Int)])
        case deleteRecording(Recording, index: Int, todos: [(TodoItem, index: Int)])
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
    @Published private(set) var undoOffer: UndoOffer?

    private var undoAction: UndoAction?
    /// File audio yang menunggu dibuang (lihat `Snapshot.trash`).
    private var trash: [String] = []

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
        offerUndo(todos[i].isDone ? "To-do ditandai selesai" : "To-do ditandai belum selesai", .toggle(id))
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
        let old = todos[i].title
        todos[i].title = text
        save()
        offerUndo("To-do diubah", .editTodo(id, oldTitle: old))
    }

    func deleteTodo(_ id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        let item = todos.remove(at: index)
        var owners: [(recordingID: UUID, index: Int)] = []
        for i in recordings.indices {
            if let j = recordings[i].todoIDs.firstIndex(of: id) {
                owners.append((recordings[i].id, j))
                recordings[i].todoIDs.remove(at: j)
            }
        }
        save()
        offerUndo("To-do dihapus", .deleteTodo(item, index: index, owners: owners))
    }

    /// Menghapus rekaman beserta to-do dan file audionya. Rekaman yang sedang diproses tidak bisa dihapus.
    func deleteRecording(_ id: UUID) {
        guard let index = recordings.firstIndex(where: { $0.id == id }), recordings[index].status != .processing else { return }
        let rec = recordings.remove(at: index)
        var removed: [(TodoItem, index: Int)] = []
        for (i, todo) in todos.enumerated() where todo.recordingID == id || rec.todoIDs.contains(todo.id) {
            removed.append((todo, i))
        }
        todos.removeAll { $0.recordingID == id || rec.todoIDs.contains($0.id) }
        if banner?.recordingID == id { banner = nil }
        // Audio belum dibuang: masuk "tempat sampah" dulu supaya masih bisa diurungkan. Ikut disimpan, jadi kalau
        // aplikasi tertutup sebelum dibuang, file dibuang saat aplikasi dibuka lagi.
        if let name = rec.audioFileName, !name.isEmpty { trash.append(name) }
        save()
        offerUndo("Rekaman dihapus", .deleteRecording(rec, index: index, todos: removed))
    }

    // MARK: Urungkan

    /// Membatalkan aksi terakhir yang masih ditawarkan.
    func undo() {
        guard let action = undoAction else { return }
        undoAction = nil
        undoOffer = nil
        switch action {
        case .toggle(let id):
            if let i = todos.firstIndex(where: { $0.id == id }) { todos[i].isDone.toggle() }
        case .editTodo(let id, let oldTitle):
            if let i = todos.firstIndex(where: { $0.id == id }) { todos[i].title = oldTitle }
        case .deleteTodo(let item, let index, let owners):
            todos.insert(item, at: min(index, todos.count))
            for owner in owners {
                if let i = recordings.firstIndex(where: { $0.id == owner.recordingID }) {
                    recordings[i].todoIDs.insert(item.id, at: min(owner.index, recordings[i].todoIDs.count))
                }
            }
        case .deleteRecording(let rec, let index, let removed):
            recordings.insert(rec, at: min(index, recordings.count))
            for (todo, i) in removed { todos.insert(todo, at: min(i, todos.count)) }
            if let name = rec.audioFileName { trash.removeAll { $0 == name } }
        }
        save()
    }

    /// Dipanggil saat tawaran "Urungkan" habis waktunya. Aksinya jadi permanen.
    func expireUndo(_ offerID: UUID) {
        guard undoOffer?.id == offerID else { return }
        undoAction = nil
        undoOffer = nil
        emptyTrash()
    }

    private func offerUndo(_ message: String, _ action: UndoAction) {
        // Hanya aksi terakhir yang bisa diurungkan; aksi sebelumnya jadi permanen.
        emptyTrash(keepingLatest: action)
        undoAction = action
        undoOffer = UndoOffer(message: message)
    }

    /// Membuang file audio di tempat sampah. `keepingLatest`: aksi baru yang sedang ditawarkan, filenya jangan dibuang.
    private func emptyTrash(keepingLatest latest: UndoAction? = nil) {
        var keep: String?
        if case .deleteRecording(let rec, _, _) = latest { keep = rec.audioFileName }
        let toDelete = trash.filter { $0 != keep }
        guard !toDelete.isEmpty else { return }
        trash = trash.filter { $0 == keep }
        // Data disimpan dulu tanpa file-file ini. Kalau gagal, file tidak dibuang (dicoba lagi lain kali).
        guard save() else { trash += toDelete; return }
        for name in toDelete {
            try? FileManager.default.removeItem(at: SpeechRecorder.folder.appendingPathComponent(name))
        }
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
        let recordingDay = Tanggal(current.createdAt)
        let newTodos = result.todos.map {
            TodoItem(
                title: $0.title,
                category: result.category,
                due: $0.due,
                dueDate: $0.due.flatMap { FrasaWaktu.tanggal($0, hariRekaman: recordingDay) },
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
        trash = snapshot.trash ?? []
        emptyTrash() // sisa hapus rekaman yang belum sempat dibuang sebelum aplikasi tertutup
        recoverOrphanAudio()
    }

    /// File audio yang tidak dimiliki rekaman mana pun berarti aplikasi tertutup saat merekam (misalnya mati
    /// mendadak). Rekamannya dipulihkan, bukan dibuang (prinsip "rekaman tidak boleh hilang").
    /// Hanya dijalankan setelah data lama berhasil dibaca, supaya data yang gagal terbaca tidak dikira kosong.
    private func recoverOrphanAudio() {
        let folder = SpeechRecorder.folder
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        let known = Set(recordings.compactMap(\.audioFileName)).union(trash)
        var recovered: [Recording] = []
        for name in names.sorted() where !known.contains(name) && !name.hasPrefix(".") {
            let url = folder.appendingPathComponent(name)
            let created = (try? FileManager.default.attributesOfItem(atPath: url.path)[.creationDate] as? Date) ?? Date()
            var seconds = 0
            if let file = try? AVAudioFile(forReading: url), file.fileFormat.sampleRate > 0 {
                seconds = Int(Double(file.length) / file.fileFormat.sampleRate)
            }
            recovered.append(Recording(
                createdAt: created,
                title: "Rekaman dipulihkan",
                category: .ide,
                status: .failed,
                duration: seconds,
                audioFileName: name,
                stopNote: "Aplikasi tertutup saat merekam. Bagian yang sempat terekam dipulihkan.",
                failReason: .interrupted
            ))
        }
        guard !recovered.isEmpty else { return }
        recordings = (recordings + recovered).sorted { $0.createdAt > $1.createdAt }
        save()
    }

    /// True bila data berhasil ditulis ke HP.
    @discardableResult
    private func save() -> Bool {
        guard canSave else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(Snapshot(todos: todos, recordings: recordings, trash: trash.isEmpty ? nil : trash))
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
