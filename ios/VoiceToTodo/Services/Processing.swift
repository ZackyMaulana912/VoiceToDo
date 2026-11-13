import Foundation
import os

/// Mengubah file audio menjadi teks. Versi asli memakai WhisperKit; test memakai versi tiruan.
protocol Transcriber: Sendable {
    func transcribe(_ audio: URL) async throws -> String
}

/// Kegagalan yang punya kode galat sendiri (CLAUDE.md 5.6).
enum ProcessingError: Error, Equatable {
    case modelMissing
    case lowMemory
    case tooHot
    case transcriptionFailed
    case summaryFailed

    var failReason: FailReason {
        switch self {
        case .modelMissing: return .modelMissing
        case .lowMemory: return .lowMemory
        case .tooHot: return .tooHot
        case .transcriptionFailed: return .transcriptionFailed
        case .summaryFailed: return .summaryFailed
        }
    }
}

/// Lokasi file model AI yang dibundel di aplikasi (disalin oleh fase build "Salin model AI").
enum ModelFiles {
    static var root: URL? {
        guard let url = Bundle.main.url(forResource: "Model", withExtension: nil),
              FileManager.default.fileExists(atPath: url.appendingPathComponent("whisper").path) else { return nil }
        return url
    }
}

/// Pemeriksaan sebelum memuat model besar: HP terlalu panas atau memori tidak cukup.
enum DeviceCheck {
    static func ensureReady(neededMB: Int) throws {
        if ProcessInfo.processInfo.thermalState == .critical { throw ProcessingError.tooHot }
        // 0 berarti tidak didukung (Simulator); lewati pemeriksaan.
        let available = availableMB
        if available > 0 && available < neededMB { throw ProcessingError.lowMemory }
    }

    /// Sisa memori untuk aplikasi ini dalam MB (0 di Simulator dan Mac). Dipakai juga untuk catatan uji kelayakan.
    static var availableMB: Int {
        #if os(iOS)
        return os_proc_available_memory() / 1_048_576
        #else
        return 0
        #endif
    }
}
