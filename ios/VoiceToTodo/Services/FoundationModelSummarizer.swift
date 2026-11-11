#if canImport(FoundationModels)
import Foundation
import FoundationModels

// Requires Xcode 26 / iOS 26 and a device with Apple Intelligence.
// On older toolchains this file compiles to nothing and the rule-based summarizer is used.

@available(iOS 26.0, *)
@Generable
struct GeneratedTodo {
    @Guide(description: "Tugas singkat dalam Bahasa Indonesia, diawali kata kerja")
    var title: String

    @Guide(description: "Tenggat jika disebut, misalnya Jumat atau Besok. Kosongkan jika tidak ada")
    var due: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedSummary {
    @Guide(description: "Judul pendek 2 sampai 4 kata")
    var title: String

    @Guide(description: "Tepat salah satu dari: Rapat, Kuliah, Ide")
    var category: String

    @Guide(description: "Rangkuman 2 sampai 3 kalimat dalam Bahasa Indonesia")
    var summary: String

    @Guide(description: "2 sampai 4 poin penting, masing-masing satu kalimat pendek")
    var points: [String]

    @Guide(description: "Daftar to-do dari pembicaraan. Kosong jika tidak ada tugas")
    var todos: [GeneratedTodo]
}

@available(iOS 26.0, *)
enum FoundationModelSummarizer {
    static func summarize(_ transcript: String, date: Date) async -> SummaryResult? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }

        let session = LanguageModelSession(
            instructions: """
            Kamu asisten yang merangkum rekaman suara berbahasa Indonesia menjadi rangkuman singkat, \
            poin penting, dan daftar to-do. Gunakan hanya informasi dari transkrip. Jangan mengarang tugas.
            """
        )

        do {
            let response = try await session.respond(
                to: "Transkrip:\n\(String(transcript.prefix(6000)))",
                generating: GeneratedSummary.self
            )
            let generated = response.content
            let lower = generated.category.lowercased()
            let category: TodoCategory = lower.contains("kuliah") ? .kuliah : (lower.contains("ide") ? .ide : .rapat)
            let todos = generated.todos.map {
                TodoDraft(title: $0.title, due: $0.due.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0.due)
            }
            return SummaryResult(
                title: generated.title,
                category: category,
                summary: generated.summary,
                points: generated.points,
                todos: todos
            )
        } catch {
            return nil // e.g. transcript too long for the model: use the fallback
        }
    }
}
#endif
