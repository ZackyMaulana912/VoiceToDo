import SwiftUI

enum TodoCategory: String, Codable, CaseIterable {
    case rapat = "Rapat"
    case kuliah = "Kuliah"
    case ide = "Ide"

    var title: String { rawValue }

    var background: Color {
        switch self {
        case .rapat: return Color(hex: 0xEEF2FF)
        case .kuliah: return Color(hex: 0xF0FDFA)
        case .ide: return Color(hex: 0xFFFBEB)
        }
    }

    var foreground: Color {
        switch self {
        case .rapat: return Color(hex: 0x4338CA)
        case .kuliah: return Color(hex: 0x0F766E)
        case .ide: return Color(hex: 0x92400E)
        }
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var category: TodoCategory
    var due: String?
    var source: String
    var isDone = false
    var recordingID: UUID?
    var createdAt = Date()
}

enum RecordingStatus: String, Codable {
    case processing
    case done
    case failed

    var label: String {
        switch self {
        case .processing: return "Memproses"
        case .done: return "Selesai"
        case .failed: return "Gagal"
        }
    }

    var background: Color {
        switch self {
        case .processing: return Color(hex: 0xFFFBEB)
        case .done: return Color(hex: 0xF0FDF4)
        case .failed: return Color(hex: 0xFEF2F2)
        }
    }

    var foreground: Color {
        switch self {
        case .processing: return Color(hex: 0x92400E)
        case .done: return Color(hex: 0x166534)
        case .failed: return Color(hex: 0xB91C1C)
        }
    }
}

struct Recording: Identifiable, Codable, Equatable {
    var id = UUID()
    var createdAt = Date()
    var title: String
    var category: TodoCategory
    var status: RecordingStatus
    var duration: Int
    var summary = ""
    var points: [String] = []
    var todoIDs: [UUID] = []
    var transcript = ""
    var audioFileName: String?
    /// Diisi bila rekaman berhenti sendiri (telepon masuk, layar dikunci, dll.), bukan karena tombol Selesai.
    var stopNote: String?

    var dateText: String { Formatters.full.string(from: createdAt) }
    var durationText: String { Formatters.duration(duration) }
}

enum Formatters {
    static let full: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "d MMM yyyy '·' HH.mm"
        return f
    }()

    static let short: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "d MMM"
        return f
    }()

    static func duration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
