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

    private let fileURL: URL

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
            audioFileName: audio.fileName
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
        if transcript.isEmpty, let name = current.audioFileName {
            // Live transcription found nothing: try again from the saved audio file.
            transcript = await SpeechTranscriber.transcribe(url: SpeechRecorder.folder.appendingPathComponent(name)) ?? ""
        }

        let wordCount = transcript.split(whereSeparator: { $0.isWhitespace }).count
        guard wordCount >= 3 else {
            update(id) { $0.status = .failed; $0.transcript = transcript; $0.summary = "Rekamanmu aman tersimpan." }
            banner = Banner(kind: .failed, recordingID: id)
            return
        }

        let result = await SummarizerService.summarize(transcript, date: current.createdAt)
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
            $0.title = result.title
            $0.category = result.category
            $0.summary = result.summary
            $0.points = result.points
            $0.transcript = transcript
            $0.todoIDs = newTodos.map(\.id)
        }
        banner = Banner(kind: .result, recordingID: id)
    }

    private func update(_ id: UUID, _ change: (inout Recording) -> Void) {
        guard let i = recordings.firstIndex(where: { $0.id == id }) else { return }
        change(&recordings[i])
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var snapshot = try? decoder.decode(Snapshot.self, from: data) else { return }
        // A recording left "processing" means the app was closed mid-way; let the user retry.
        for i in snapshot.recordings.indices where snapshot.recordings[i].status == .processing {
            snapshot.recordings[i].status = .failed
        }
        todos = snapshot.todos
        recordings = snapshot.recordings
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(Snapshot(todos: todos, recordings: recordings)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
