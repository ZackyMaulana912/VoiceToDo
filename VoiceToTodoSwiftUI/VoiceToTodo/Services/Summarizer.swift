import Foundation

struct TodoDraft {
    var title: String
    var due: String?
}

struct SummaryResult {
    var title: String
    var category: TodoCategory
    var summary: String
    var points: [String]
    var todos: [TodoDraft]
}

enum SummarizerService {
    /// Uses Apple's on-device language model when the device supports it,
    /// otherwise (or on any failure) falls back to the rule-based summarizer.
    static func summarize(_ transcript: String, date: Date) async -> SummaryResult {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let result = await FoundationModelSummarizer.summarize(transcript, date: date) {
            return result
        }
        #endif
        return HeuristicSummarizer.summarize(transcript, date: date)
    }
}

/// Offline Indonesian summarizer: scores sentences, detects category, action items and deadlines.
enum HeuristicSummarizer {
    private static let categoryKeywords: [TodoCategory: [String]] = [
        .rapat: ["rapat", "panitia", "proposal", "sponsor", "acara", "anggaran", "dana", "vendor", "rapat", "koordinasi", "tim", "himpunan", "organisasi", "notulen", "agenda"],
        .kuliah: ["kuliah", "dosen", "kuis", "ujian", "bab", "materi", "tugas", "makalah", "skripsi", "praktikum", "kelas", "semester", "mata kuliah", "dikumpulkan", "presentasi"],
        .ide: ["ide", "gimana kalau", "bagaimana kalau", "kayaknya", "sepertinya", "fitur", "konsep", "inspirasi", "bikin", "coba"],
    ]

    private static let actionCues = [
        "tolong", "harus", "perlu", "jangan lupa", "ingat", "dikirim", "dikumpulkan", "dikerjakan", "diselesaikan",
        "deadline", "tenggat", "kirim", "cek", "buat", "baca", "pesan", "siapkan", "hubungi", "kerjakan", "kumpulkan",
        "bawa", "bayar", "booking", "daftar", "survei", "survey", "beli", "cetak", "print", "telepon", "selesaikan",
        "persiapkan", "review", "rapikan", "jadwalkan", "konfirmasi", "tanyakan", "kabari", "upload", "pelajari",
        "bandingkan", "revisi", "ajukan", "ambil", "antar",
    ]

    private static let fillerPrefix = try! NSRegularExpression(
        pattern: #"^(oke|ok|okay|jadi|nah|terus|lalu|kemudian|selain itu|tolong|ya|eh|hmm|baik|nanti|kita perlu|kita harus|kita|jangan lupa untuk|jangan lupa|harus|perlu|dan|juga|sama)\b[,\s]*"#,
        options: [.caseInsensitive]
    )
    private static let fillerSuffix = try! NSRegularExpression(
        pattern: #"[,\s]*\b(ya|dong|deh|nih|sih|ya guys|guys)\b[.!?\s]*$"#,
        options: [.caseInsensitive]
    )

    private static let dueTerms: [(pattern: String, label: String)] = [
        (#"\bminggu depan\b"#, "Minggu depan"),
        (#"\bminggu ini\b"#, "Minggu ini"),
        (#"\bhari ini\b"#, "Hari ini"),
        (#"\bbesok\b"#, "Besok"),
        (#"\blusa\b"#, "Lusa"),
        (#"\bsenin\b"#, "Senin"),
        (#"\bselasa\b"#, "Selasa"),
        (#"\brabu\b"#, "Rabu"),
        (#"\bkamis\b"#, "Kamis"),
        (#"\bjum'?at\b"#, "Jumat"),
        (#"\bsabtu\b"#, "Sabtu"),
        (#"\bminggu\b"#, "Minggu"),
    ]

    static func summarize(_ transcript: String, date: Date) -> SummaryResult {
        let sentences = splitSentences(transcript)
        let category = detectCategory(transcript)

        // To-dos
        var todos: [TodoDraft] = []
        var seen = Set<String>()
        for sentence in sentences where isAction(sentence) {
            let title = cleanTitle(sentence)
            let key = String(title.lowercased().prefix(24))
            guard title.split(separator: " ").count >= 2, !seen.contains(key) else { continue }
            seen.insert(key)
            todos.append(TodoDraft(title: title, due: detectDue(sentence)))
            if todos.count == 6 { break }
        }

        // Summary: highest-scoring sentences, kept in spoken order.
        let scored = sentences.enumerated().map { index, sentence in
            (index, sentence, score(sentence, index: index, category: category))
        }
        let top = scored.sorted { $0.2 > $1.2 }.prefix(3).sorted { $0.0 < $1.0 }
        let summary = top.map { sentenceCase($0.1) }.joined(separator: " ")

        // Key points: the actions with their deadlines, or the next best sentences.
        var points = todos.prefix(4).map { draft -> String in
            draft.due.map { "\(draft.title) (\($0))." } ?? "\(draft.title)."
        }
        if points.isEmpty {
            points = scored.sorted { $0.2 > $1.2 }.prefix(3).map { shorten(sentenceCase($0.1), 90) }
        }

        let title = "\(category.title) \(Formatters.short.string(from: date))"
        return SummaryResult(
            title: title,
            category: category,
            summary: summary.isEmpty ? sentenceCase(transcript) : summary,
            points: points,
            todos: todos
        )
    }

    // MARK: Helpers

    private static func splitSentences(_ text: String) -> [String] {
        var parts = text
            .replacingOccurrences(of: "\n", with: ". ")
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.split(separator: " ").count >= 3 }

        // Speech without punctuation arrives as one long run: split on spoken connectors.
        parts = parts.flatMap { part -> [String] in
            guard part.split(separator: " ").count > 25 else { return [part] }
            let marked = part.replacingOccurrences(
                of: #"\s+(terus|lalu|kemudian|selain itu|jadi|nah|oke|dan juga|habis itu)\s+"#,
                with: "|$1 ",
                options: [.regularExpression, .caseInsensitive]
            )
            return marked.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.split(separator: " ").count >= 3 }
        }
        return parts.isEmpty ? [text.trimmingCharacters(in: .whitespacesAndNewlines)] : parts
    }

    private static func detectCategory(_ text: String) -> TodoCategory {
        let lower = text.lowercased()
        var best: (TodoCategory, Int) = (.ide, 0)
        for (category, words) in categoryKeywords {
            let hits = words.reduce(0) { $0 + (lower.contains($1) ? 1 : 0) }
            if hits > best.1 { best = (category, hits) }
        }
        return best.0
    }

    private static func isAction(_ sentence: String) -> Bool {
        let lower = sentence.lowercased()
        return actionCues.contains { lower.contains($0) }
    }

    private static func detectDue(_ sentence: String) -> String? {
        let lower = sentence.lowercased()
        for term in dueTerms where lower.range(of: term.pattern, options: .regularExpression) != nil {
            return term.label
        }
        return nil
    }

    private static func score(_ sentence: String, index: Int, category: TodoCategory) -> Double {
        let lower = sentence.lowercased()
        let words = sentence.split(separator: " ").count
        var value = 0.0
        if (6...35).contains(words) { value += 2 }
        value += Double(categoryKeywords[category, default: []].filter { lower.contains($0) }.count) * 1.5
        if detectDue(sentence) != nil { value += 2 }
        if isAction(sentence) { value += 1 }
        if index == 0 { value += 1 }
        return value
    }

    private static func cleanTitle(_ sentence: String) -> String {
        var text = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        for _ in 0..<4 {
            let range = NSRange(text.startIndex..., in: text)
            let stripped = fillerPrefix.stringByReplacingMatches(in: text, range: range, withTemplate: "")
            if stripped == text { break }
            text = stripped
        }
        let range = NSRange(text.startIndex..., in: text)
        text = fillerSuffix.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:"))
        return shorten(sentenceCase(text, addPeriod: false), 90)
    }

    private static func sentenceCase(_ text: String, addPeriod: Bool = true) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = t.first else { return t }
        t = first.uppercased() + t.dropFirst()
        if addPeriod, let last = t.last, !".!?".contains(last) { t += "." }
        return t
    }

    private static func shorten(_ text: String, _ limit: Int) -> String {
        guard text.count > limit else { return text }
        let cut = text.prefix(limit)
        if let space = cut.lastIndex(of: " ") { return String(cut[..<space]) + "…" }
        return String(cut) + "…"
    }
}
