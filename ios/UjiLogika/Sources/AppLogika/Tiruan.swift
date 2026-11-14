import Foundation
// Pengganti bagian khusus iPhone supaya logika aplikasi asli bisa dijalankan di Mac.
struct RecordedAudio { let fileName: String; let duration: Int; var stopNote: String? = nil }
enum SpeechRecorder {
    static var folder: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
}
@MainActor enum ScreenAwake { static var on = false; static func set(_ h: String, _ v: Bool) { on = v } }
struct TodoDraft { var title: String; var due: String?; init(title: String, due: String?) { self.title = title; self.due = due } }
struct SummaryResult { var title: String; var category: TodoCategory; var summary: String; var points: [String]; var todos: [TodoDraft]
    init(title: String, category: TodoCategory, summary: String, points: [String], todos: [TodoDraft]) { self.title = title; self.category = category; self.summary = summary; self.points = points; self.todos = todos } }
protocol Summarizer: Sendable { func summarize(_ transcript: String, date: Date) async throws -> SummaryResult }
struct LlamaSummarizer: Summarizer { func summarize(_ t: String, date: Date) async throws -> SummaryResult { fatalError() } }
struct WhisperTranscriber: Transcriber { func transcribe(_ a: URL) async throws -> String { fatalError() } }
