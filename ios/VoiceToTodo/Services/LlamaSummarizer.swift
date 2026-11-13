import Foundation
import llama
import VoiceToTodoCore

/// Peringkas di HP dengan llama.cpp, tanpa internet (CLAUDE.md 5.4). Model dimuat saat dibutuhkan dan dilepas
/// sesudahnya, jadi tidak pernah berbarengan dengan model Whisper.
struct LlamaSummarizer: Summarizer {
    /// Nama file model di Model/llm, urut dari yang paling diutamakan.
    static let models = ["Qwen3-4B-Instruct-2507-Q4_K_M.gguf", "Qwen3-1.7B-Q4_K_M.gguf"]

    /// Catatan untuk uji kelayakan (Fase 1): model dan waktu per tahap pada pemanggilan terakhir.
    nonisolated(unsafe) static var lastRun: [String: String] = [:]

    var modelOverride: String? = nil

    func summarize(_ transcript: String, date: Date) async throws -> SummaryResult {
        guard let file = Self.chooseModel(override: modelOverride) else { throw ProcessingError.modelMissing }
        let sizeMB = ((try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0) / 1_048_576
        // Perkiraan: bobot model + cache konteks + kerja (BELUM_DIUJI di HP; diukur di Fase 1).
        try DeviceCheck.ensureReady(neededMB: sizeMB + 700)

        let stop = StopFlag()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                try Self.run(file: file, transcript: transcript, stop: stop)
            }.value
        } onCancel: {
            stop.set()
        }
    }

    /// Model terbesar yang ada di aplikasi dan cocok untuk HP ini. HP tanpa GPU yang didukung llama.cpp
    /// (lebih lama dari A14, misalnya XR) memakai model kecil karena berjalan di CPU.
    static func chooseModel(override: String? = nil) -> URL? {
        guard let root = ModelFiles.root?.appendingPathComponent("llm") else { return nil }
        let names = override.map { [$0] } ?? (Self.gpuSupported ? models : Array(models.reversed()))
        return names.map { root.appendingPathComponent($0) }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// llama.cpp butuh GPU keluarga Apple7 (A14, "iPhone13,x") ke atas untuk Metal. Simulator memakai CPU.
    static var gpuSupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        var info = utsname()
        uname(&info)
        let id = withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        guard id.hasPrefix("iPhone"), let major = Int(id.dropFirst(6).split(separator: ",").first ?? "") else { return true }
        return major >= 13
        #endif
    }

    static func run(file: URL, transcript: String, stop: StopFlag) throws -> SummaryResult {
        let t0 = Date()
        let runner = try LlamaRunner(path: file.path, gpu: gpuSupported)
        let loaded = Date()
        var attempts: [Int] = []

        /// Satu putaran model untuk `teks`. Percobaan pertama tanpa acak (paling stabil); bila keluaran melanggar
        /// aturan, coba sekali lagi dengan sedikit acak (CLAUDE.md 5.2: coba ulang sekali, lalu "ringkasan-gagal").
        func ringkas(_ teks: String, grammar: String = Ringkasan.grammar) throws -> HasilRingkasan {
            let prompt = runner.chatPrompt(system: Ringkasan.pesanSistem, user: Ringkasan.pesanPengguna(transkrip: teks))
            var lastError = "?"
            for attempt in 0..<2 {
                let output = try runner.generate(prompt: prompt, grammar: grammar, maxTokens: 1_536,
                                                 temperature: attempt == 0 ? 0 : 0.6, seed: 42, stop: stop)
                do {
                    let h = try Ringkasan.baca(output, transkrip: teks)
                    attempts.append(attempt + 1)
                    return h
                } catch {
                    lastError = "\(error)"
                }
            }
            lastRun = ["model": file.lastPathComponent, "galat": lastError]
            throw ProcessingError.summaryFailed
        }

        // Transkrip panjang: tugas diambil per bagian, lalu satu putaran terakhir untuk judul dan ringkasan.
        let bagian = Ringkasan.bagian(transcript)
        let hasil: HasilRingkasan
        if bagian.count == 1 {
            hasil = try ringkas(transcript)
        } else {
            let perBagian = try bagian.map { try ringkas($0) }
            let akhir = try ringkas(Ringkasan.ringkasanBagian(perBagian), grammar: Ringkasan.grammarTanpaTugas)
            hasil = Ringkasan.gabung(perBagian, akhir: akhir)
        }

        lastRun = [
            "model": file.lastPathComponent,
            "muat_detik": String(format: "%.1f", loaded.timeIntervalSince(t0)),
            "total_detik": String(format: "%.1f", Date().timeIntervalSince(t0)),
            "bagian": "\(bagian.count)",
            "percobaan": attempts.map(String.init).joined(separator: ","),
        ]
        return SummaryResult(
            title: hasil.judul,
            category: TodoCategory(rawValue: hasil.kategori) ?? .ide,
            summary: hasil.ringkasan,
            points: hasil.poin,
            todos: hasil.tugas.map { TodoDraft(title: $0.teks, due: $0.frasaWaktu) }
        )
    }
}

/// Penanda batal yang aman dibaca dari thread lain.
final class StopFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.lock(); value = true; lock.unlock() }
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

/// Pembungkus kecil untuk API C llama.cpp: satu model, satu konteks per pemanggilan `generate`.
final class LlamaRunner {
    private static let backend: Void = llama_backend_init()

    private let model: OpaquePointer
    private let vocab: OpaquePointer
    private(set) var lastPromptTokens = 0
    private(set) var lastOutputTokens = 0

    init(path: String, gpu: Bool) throws {
        _ = Self.backend
        var params = llama_model_default_params()
        params.n_gpu_layers = gpu ? 999 : 0
        guard let model = llama_model_load_from_file(path, params) else { throw ProcessingError.modelMissing }
        self.model = model
        self.vocab = llama_model_get_vocab(model)
    }

    deinit {
        llama_model_free(model)
    }

    /// Menyusun prompt dengan template chat bawaan model (Qwen, Gemma, dll.).
    func chatPrompt(system: String, user: String) -> String {
        let template = llama_model_chat_template(model, nil)
        let roles = [strdup("system"), strdup("user")]
        let contents = [strdup(system), strdup(user)]
        defer { (roles + contents).forEach { free($0) } }
        var messages = [
            llama_chat_message(role: roles[0], content: contents[0]),
            llama_chat_message(role: roles[1], content: contents[1]),
        ]
        var buffer = [CChar](repeating: 0, count: (system.utf8.count + user.utf8.count) * 2 + 1_024)
        var n = llama_chat_apply_template(template, &messages, 2, true, &buffer, Int32(buffer.count))
        if n > buffer.count {
            buffer = [CChar](repeating: 0, count: Int(n) + 1)
            n = llama_chat_apply_template(template, &messages, 2, true, &buffer, Int32(buffer.count))
        }
        var prompt = n > 0 ? String(decoding: buffer.prefix(Int(n)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
                           : "\(system)\n\n\(user)\n\n"
        // Model Qwen3 "hybrid" berpikir dulu kecuali diberi blok pikir kosong (setara enable_thinking=false).
        if let template, String(cString: template).contains("enable_thinking") {
            prompt += "<think>\n\n</think>\n\n"
        }
        return prompt
    }

    func tokenize(_ text: String) -> [llama_token] {
        let count = Int32(text.utf8.count)
        var tokens = [llama_token](repeating: 0, count: Int(count) + 16)
        var n = llama_tokenize(vocab, text, count, &tokens, Int32(tokens.count), false, true)
        if n < 0 {
            tokens = [llama_token](repeating: 0, count: Int(-n))
            n = llama_tokenize(vocab, text, count, &tokens, Int32(tokens.count), false, true)
        }
        return Array(tokens.prefix(Int(max(n, 0))))
    }

    func generate(prompt: String, grammar: String, maxTokens: Int, temperature: Float, seed: UInt32,
                  stop: StopFlag) throws -> String {
        let tokens = tokenize(prompt)
        lastPromptTokens = tokens.count
        lastOutputTokens = 0
        var cparams = llama_context_default_params()
        cparams.n_ctx = UInt32(tokens.count + maxTokens + 16)
        cparams.n_batch = 512
        cparams.n_ubatch = 512
        guard let ctx = llama_init_from_model(model, cparams) else { throw ProcessingError.lowMemory }
        defer { llama_free(ctx) }

        let chain = llama_sampler_chain_init(llama_sampler_chain_default_params())!
        defer { llama_sampler_free(chain) }
        guard let grammarSampler = llama_sampler_init_grammar(vocab, grammar, "root") else {
            throw ProcessingError.summaryFailed
        }
        llama_sampler_chain_add(chain, grammarSampler)
        if temperature > 0 {
            llama_sampler_chain_add(chain, llama_sampler_init_temp(temperature))
            llama_sampler_chain_add(chain, llama_sampler_init_dist(seed))
        } else {
            llama_sampler_chain_add(chain, llama_sampler_init_greedy())
        }

        // Prompt dimasukkan per potongan 512 token.
        var position = 0
        while position < tokens.count {
            if stop.isSet { throw CancellationError() }
            let end = min(position + 512, tokens.count)
            var slice = Array(tokens[position..<end])
            let result = slice.withUnsafeMutableBufferPointer { buf in
                llama_decode(ctx, llama_batch_get_one(buf.baseAddress, Int32(buf.count)))
            }
            guard result == 0 else { throw ProcessingError.summaryFailed }
            position = end
        }

        var bytes: [UInt8] = []
        var piece = [CChar](repeating: 0, count: 256)
        for _ in 0..<maxTokens {
            if stop.isSet { throw CancellationError() }
            var token = llama_sampler_sample(chain, ctx, -1) // sekaligus menerima token (grammar ikut maju)
            if llama_vocab_is_eog(vocab, token) { break }
            lastOutputTokens += 1
            let n = llama_token_to_piece(vocab, token, &piece, Int32(piece.count), 0, false)
            if n > 0 { bytes += piece.prefix(Int(n)).map { UInt8(bitPattern: $0) } }
            let result = llama_decode(ctx, llama_batch_get_one(&token, 1))
            guard result == 0 else { throw ProcessingError.summaryFailed }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
