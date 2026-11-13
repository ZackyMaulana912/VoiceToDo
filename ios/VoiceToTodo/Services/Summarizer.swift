import Foundation

struct TodoDraft {
    var title: String
    /// Frasa waktu seperti yang diucapkan; tanggalnya dihitung kode (`FrasaWaktu`), bukan AI.
    var due: String?
}

struct SummaryResult {
    var title: String
    var category: TodoCategory
    var summary: String
    var points: [String]
    var todos: [TodoDraft]
}

/// Membuat judul, kategori, ringkasan, poin, dan to-do dari transkrip. Versi asli memakai llama.cpp
/// (`LlamaSummarizer`); test memakai versi tiruan.
protocol Summarizer: Sendable {
    func summarize(_ transcript: String, date: Date) async throws -> SummaryResult
}
