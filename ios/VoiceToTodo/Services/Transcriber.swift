import Foundation
import WhisperKit

/// Transkripsi di HP dengan WhisperKit, tanpa internet. Model dimuat saat dibutuhkan dan dilepas lagi sesudahnya,
/// supaya tidak berbarengan dengan model ringkasan (CLAUDE.md 5.1).
struct WhisperTranscriber: Transcriber {
    static let turbo = "openai_whisper-large-v3-v20240930_turbo_632MB"
    static let base = "openai_whisper-base"

    /// iPhone 13 (A15, "iPhone14,x") ke atas memakai model turbo yang jauh lebih akurat; HP yang lebih lama
    /// (misalnya XR, "iPhone11,8") memakai base. Daftar bawaan WhisperKit 1.1.1 belum mengenal iPhone 17
    /// ("iPhone18"), jadi aturannya ditulis sendiri. Simulator dan Mac memakai turbo.
    static func preferredModel(device: String = WhisperKit.deviceName()) -> String {
        guard device.hasPrefix("iPhone"),
              let major = Int(device.dropFirst("iPhone".count).split(separator: ",").first ?? "") else { return turbo }
        return major >= 14 ? turbo : base
    }

    /// Perkiraan memori yang dibutuhkan saat memuat model (BELUM_DIUJI di HP; diukur di Fase 1).
    static func neededMB(_ model: String) -> Int { model == turbo ? 1_000 : 300 }

    static var lastModelName: String?

    func transcribe(_ audio: URL) async throws -> String {
        guard let root = ModelFiles.root else { throw ProcessingError.modelMissing }
        var name = Self.preferredModel()
        if !FileManager.default.fileExists(atPath: root.appendingPathComponent("whisper/\(name)").path) { name = Self.base }
        let folder = root.appendingPathComponent("whisper/\(name)")
        guard FileManager.default.fileExists(atPath: folder.path) else { throw ProcessingError.modelMissing }
        try DeviceCheck.ensureReady(neededMB: Self.neededMB(name))
        Self.lastModelName = name

        let kit: WhisperKit
        do {
            kit = try await WhisperKit(WhisperKitConfig(
                modelFolder: folder.path,
                tokenizerFolder: root.appendingPathComponent("tokenizers"),
                verbose: false,
                logLevel: .error,
                prewarm: false,
                load: true,
                download: false // jangan pernah mengunduh; semua file ada di aplikasi
            ))
        } catch {
            throw ProcessingError.modelMissing
        }

        var options = DecodingOptions(
            task: .transcribe,
            language: "id",
            temperature: 0,
            usePrefillPrompt: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            chunkingStrategy: .vad
        )
        // Ambang keyakinan bawaan membuat model base membuang segmen ucapan diam-diam (uji 2026-11-12:
        // separuh rekaman hilang). Dimatikan supaya isi rekaman tidak hilang.
        options.logProbThreshold = nil
        options.firstTokenLogProbThreshold = nil

        do {
            let results = try await kit.transcribe(audioPath: audio.path, decodeOptions: options) { _ in
                Task.isCancelled ? false : nil
            }
            await kit.unloadModels()
            try Task.checkCancellation()
            return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        } catch is CancellationError {
            await kit.unloadModels()
            throw CancellationError()
        } catch {
            await kit.unloadModels()
            if Task.isCancelled { throw CancellationError() }
            throw ProcessingError.transcriptionFailed
        }
    }
}
