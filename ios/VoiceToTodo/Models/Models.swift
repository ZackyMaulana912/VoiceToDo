import SwiftUI
import VoiceToTodoCore

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
    /// Frasa waktu seperti yang diucapkan ("Jumat", "minggu depan").
    var due: String?
    /// Tanggal tenggat hasil `FrasaWaktu` (kode, bukan AI). Nil bila frasa tidak menunjuk satu hari.
    /// Optional supaya data lama tetap terbaca.
    var dueDate: Tanggal?
    var source: String
    var isDone = false
    var recordingID: UUID?
    var createdAt = Date()

    /// Teks chip tenggat relatif terhadap hari ini.
    func dueLabel(today: Tanggal = Tanggal(Date())) -> LabelTenggat.Hasil? {
        LabelTenggat.buat(tanggal: dueDate, frasa: due, hariIni: today, selesai: isDone)
    }
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

/// Alasan rekaman gagal diproses. Nilai teks dipakai sebagai kode galat (lihat CLAUDE.md 5.6).
enum FailReason: String, Codable {
    case interrupted = "terganggu"
    case noSpeech = "tidak-terdengar"
    case tooShort = "terlalu-pendek"
    case transcriptionFailed = "transkripsi-gagal"
    case summaryFailed = "ringkasan-gagal"
    case lowMemory = "memori-kurang"
    case tooHot = "terlalu-panas"
    case modelMissing = "model-tidak-ada"
    case noAudio = "tanpa-audio"
    /// Dari versi lama yang memakai pengenal ucapan Apple (butuh internet). Tetap ada supaya data lama terbaca.
    case recognizerUnavailable = "pengenal-tidak-tersedia"

    var message: String {
        switch self {
        case .interrupted: return "Proses terhenti karena aplikasi ditutup atau ditinggalkan. Rekamanmu aman tersimpan."
        case .transcriptionFailed: return "Gagal mengubah suara jadi teks. Rekamanmu aman tersimpan."
        case .summaryFailed: return "Gagal merangkum rekaman. Rekamanmu aman tersimpan."
        case .lowMemory: return "Memori HP tidak cukup. Tutup aplikasi lain, lalu coba lagi."
        case .tooHot: return "HP terlalu panas. Tunggu sebentar, lalu coba lagi."
        case .modelMissing: return "File model AI tidak ditemukan. Pasang ulang aplikasi."
        case .noSpeech: return "Tidak ada suara yang terdengar di rekaman ini."
        case .tooShort: return "Ucapan yang tertangkap terlalu pendek untuk dirangkum (minimal 3 kata). Rekamanmu aman tersimpan."
        case .recognizerUnavailable:
            return "Pengenalan ucapan Bahasa Indonesia sedang tidak tersedia. Periksa koneksi internet lalu coba lagi. Rekamanmu aman tersimpan."
        case .noAudio: return "Audio rekaman ini tidak ada di perangkat, jadi tidak bisa diproses ulang."
        }
    }

    /// "Coba lagi" tidak ada gunanya bila file audionya sudah tidak ada.
    var canRetry: Bool { self != .noAudio && self != .modelMissing }

    /// Pesan untuk rekaman gagal lama yang belum punya alasan.
    static let genericMessage = "Gagal memproses. Rekamanmu aman tersimpan."
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
    /// Diisi saat status `failed`. Optional supaya data lama tetap terbaca.
    var failReason: FailReason?

    var failMessage: String { failReason?.message ?? FailReason.genericMessage }
    var canRetry: Bool { failReason?.canRetry ?? true }

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
