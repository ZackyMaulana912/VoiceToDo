import AVFoundation
@testable import AppLogika
import VoiceToTodoCore

// Uji regresi logika aplikasi di Mac: kode asli AppStore/Models/Processing/AudioSink + paket inti,
// dengan pengenal suara dan peringkas tiruan.
// Jalankan dengan folder rumah sementara supaya Documents milikmu tidak tersentuh:
//   cd ios/UjiLogika && CFFIXED_USER_HOME=$(mktemp -d) swift run

var gagal = 0
var jumlah = 0
func cek(_ nama: String, _ ok: Bool) { jumlah += 1; print(ok ? "v" : "x", nama); if !ok { gagal += 1 } }

// MARK: Tiruan

final class FakeTranscriber: Transcriber, @unchecked Sendable {
    let lock = NSLock()
    var results: [String: Result<String, Error>] = [:]
    var delayNs: UInt64 = 0
    var running = 0
    var maxRunning = 0
    var calls: [String] = []

    func set(_ file: String, _ r: Result<String, Error>) { lock.lock(); results[file] = r; lock.unlock() }

    func transcribe(_ audio: URL) async throws -> String {
        lock.lock(); running += 1; maxRunning = max(maxRunning, running); calls.append(audio.lastPathComponent)
        let r = results[audio.lastPathComponent] ?? .success("besok kumpulkan laporan rapat"); let d = delayNs; lock.unlock()
        if d > 0 { try? await Task.sleep(nanoseconds: d) } // sengaja tidak berhenti saat dibatalkan (seperti model sungguhan)
        lock.lock(); running -= 1; lock.unlock()
        return try r.get()
    }
}

final class FakeSummarizer: Summarizer, @unchecked Sendable {
    var error: Error?
    var todos = [TodoDraft(title: "satu", due: "Jumat"), TodoDraft(title: "dua", due: "minggu depan"), TodoDraft(title: "tiga", due: nil)]
    var calls = 0
    func summarize(_ t: String, date: Date) async throws -> SummaryResult {
        calls += 1
        if let error { throw error }
        return SummaryResult(title: "Rapat Uji", category: .rapat, summary: "ringkas", points: ["p"], todos: todos)
    }
}

struct Lain: Error {}

func audio(_ n: String, detik: Double = 1) {
    let url = SpeechRecorder.folder.appendingPathComponent(n)
    let fmt = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
    let f = try! AVAudioFile(forWriting: url, settings: fmt.settings, commonFormat: .pcmFormatInt16, interleaved: true)
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(16000 * detik))!
    buf.frameLength = buf.frameCapacity
    try! f.write(from: buf)
}
func ada(_ n: String) -> Bool { FileManager.default.fileExists(atPath: SpeechRecorder.folder.appendingPathComponent(n).path) }

let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let dataFile = docs.appendingPathComponent("voice-to-todo.json")

@MainActor func bersih() {
    try? FileManager.default.removeItem(at: docs)
    try? FileManager.default.createDirectory(at: SpeechRecorder.folder, withIntermediateDirectories: true)
}
@MainActor func tunggu(_ s: AppStore, _ id: UUID) async {
    for _ in 0..<300 { if s.recording(id)?.status != .processing { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
}
@MainActor func tungguSemua(_ s: AppStore) async {
    for _ in 0..<300 { if !s.recordings.contains(where: { $0.status == .processing }) { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
}
@MainActor func rekam(_ s: AppStore, _ n: String, tunggu t: Bool = true) async -> UUID {
    audio(n)
    s.finishRecording(RecordedAudio(fileName: n, duration: 1))
    let id = s.recordings[0].id
    if t { await tunggu(s, id) }
    return id
}

// MARK: Uji

@MainActor func ujiAlurProses() async {
    print("== Alur proses")
    bersih()
    let tr = FakeTranscriber(), sm = FakeSummarizer()
    var layar: [Bool] = []
    let s = AppStore(transcriber: tr, summarizer: sm, keepScreenOn: { layar.append($0) })
    let a = await rekam(s, "a.wav")
    let r = s.recording(a)!
    cek("selesai: status done, transkrip dari audio, 3 to-do", r.status == .done && r.transcript == "besok kumpulkan laporan rapat" && s.todos(for: r).count == 3)
    let byTitle = Dictionary(uniqueKeysWithValues: s.todos.map { ($0.title, $0) })
    let hari = Tanggal(r.createdAt)
    cek("tenggat dihitung kode: Jumat -> tanggal, minggu depan -> tanpa tanggal",
        byTitle["satu"]?.dueDate == FrasaWaktu.tanggal("Jumat", hariRekaman: hari) && byTitle["satu"]?.dueDate != nil
        && byTitle["dua"]?.dueDate == nil && byTitle["dua"]?.due == "minggu depan" && byTitle["tiga"]?.dueDate == nil)
    cek("layar tetap menyala selama proses lalu dilepas", layar == [true, false])
    cek("tahap dan rekaman aktif kosong setelah selesai", s.stage == nil && s.activeID == nil)
    cek("kartu hasil tampil", s.banner == AppStore.Banner(kind: .result, recordingID: a))

    // Kegagalan per penyebab
    let kasus: [(String, Result<String, Error>, FailReason)] = [
        ("diam.wav", .success("   "), .noSpeech),
        ("pendek.wav", .success("halo tes"), .tooShort),
        ("memori.wav", .failure(ProcessingError.lowMemory), .lowMemory),
        ("panas.wav", .failure(ProcessingError.tooHot), .tooHot),
        ("model.wav", .failure(ProcessingError.modelMissing), .modelMissing),
        ("lain.wav", .failure(Lain()), .transcriptionFailed),
    ]
    for (file, hasil, alasan) in kasus {
        tr.set(file, hasil)
        let id = await rekam(s, file)
        cek("gagal \(file) -> \(alasan.rawValue)", s.recording(id)?.status == .failed && s.recording(id)?.failReason == alasan)
    }
    cek("model tidak ada: tanpa Coba lagi", s.recordings.first { $0.audioFileName == "model.wav" }?.canRetry == false)
    sm.error = ProcessingError.summaryFailed
    let rg = await rekam(s, "ringkas.wav")
    cek("peringkas gagal -> ringkasan-gagal, transkrip tetap tersimpan", s.recording(rg)?.failReason == .summaryFailed && s.recording(rg)?.transcript == "besok kumpulkan laporan rapat")
    sm.error = Lain()
    let rg2 = await rekam(s, "ringkas2.wav")
    cek("peringkas error lain -> ringkasan-gagal", s.recording(rg2)?.failReason == .summaryFailed)
    sm.error = nil

    // Coba lagi
    tr.set("pendek.wav", .success("besok kumpulkan laporan rapat"))
    let pendek = s.recordings.first { $0.audioFileName == "pendek.wav" }!.id
    s.retry(pendek)
    await tunggu(s, pendek)
    cek("Coba lagi berhasil: selesai, kode gagal dihapus", s.recording(pendek)?.status == .done && s.recording(pendek)?.failReason == nil)

    // Rekaman lama tanpa audio
    try? FileManager.default.removeItem(at: SpeechRecorder.folder.appendingPathComponent("diam.wav"))
    let diam = s.recordings.first { $0.audioFileName == "diam.wav" }!.id
    s.retry(diam)
    await tunggu(s, diam)
    cek("audio hilang -> tanpa-audio, tanpa Coba lagi", s.recording(diam)?.failReason == .noAudio && s.recording(diam)?.canRetry == false)
}

@MainActor func ujiAntrean() async {
    print("== Antrean dan gangguan")
    bersih()
    let tr = FakeTranscriber(), sm = FakeSummarizer()
    tr.delayNs = 200_000_000
    var layar: [Bool] = []
    let s = AppStore(transcriber: tr, summarizer: sm, keepScreenOn: { layar.append($0) })
    let a = await rekam(s, "a.wav", tunggu: false)
    let b = await rekam(s, "b.wav", tunggu: false)
    try? await Task.sleep(nanoseconds: 50_000_000)
    cek("dua rekaman: yang pertama aktif, kedua menunggu", s.activeID == a && s.recording(b)?.status == .processing && s.stage == .transcribing)
    await tungguSemua(s)
    cek("keduanya selesai berurutan, tidak pernah berbarengan", s.recording(a)?.status == .done && s.recording(b)?.status == .done && tr.maxRunning == 1 && tr.calls == ["a.wav", "b.wav"])
    cek("layar dinyalakan sekali dan dilepas sekali", layar == [true, false])

    // Aplikasi ditinggalkan saat memproses
    layar = []
    let c = await rekam(s, "c.wav", tunggu: false)
    let d = await rekam(s, "d.wav", tunggu: false)
    try? await Task.sleep(nanoseconds: 50_000_000)
    s.interruptProcessing()
    cek("ditinggalkan: yang aktif dan yang menunggu jadi gagal/terganggu",
        s.recording(c)?.failReason == .interrupted && s.recording(d)?.failReason == .interrupted && s.activeID == nil && s.stage == nil)
    cek("ditinggalkan: layar dilepas", layar == [true, false])
    try? await Task.sleep(nanoseconds: 400_000_000) // model tiruan baru selesai sekarang
    cek("hasil yang datang terlambat tidak menimpa status", s.recording(c)?.status == .failed && s.todos(for: s.recording(c)!).isEmpty && sm.calls == 2)
    s.resumeProcessing() // pengguna kembali ke aplikasi
    s.retry(c)
    await tunggu(s, c)
    cek("Coba lagi setelah terganggu berhasil", s.recording(c)?.status == .done)
    cek("rekaman d tetap gagal sampai dicoba lagi", s.recording(d)?.status == .failed)

    // Rekaman yang tersimpan saat aplikasi sudah di latar belakang (layar dikunci saat merekam): menunggu, tidak diproses
    let panggilanSebelum = tr.calls.count
    s.interruptProcessing() // aplikasi ke latar belakang
    let latar = await rekam(s, "latar.wav", tunggu: false)
    try? await Task.sleep(nanoseconds: 300_000_000)
    cek("di latar belakang: rekaman baru menunggu, AI tidak dijalankan", s.recording(latar)?.status == .processing && tr.calls.count == panggilanSebelum && s.activeID == nil)
    s.resumeProcessing() // aplikasi aktif lagi
    await tunggu(s, latar)
    cek("aktif lagi: rekaman yang menunggu langsung diproses", s.recording(latar)?.status == .done)

    // Aplikasi ditutup paksa saat memproses: dibuka lagi -> terganggu
    let e = await rekam(s, "e.wav", tunggu: false)
    let s2 = AppStore(transcriber: tr, summarizer: sm, keepScreenOn: { _ in })
    cek("ditutup paksa: dibuka lagi jadi gagal/terganggu", s2.recording(e)?.failReason == .interrupted)
    await tungguSemua(s)
}

@MainActor func ujiHapusEditUndo() async {
    print("== Hapus, edit, tambah, urungkan")
    bersih()
    let s = AppStore(transcriber: FakeTranscriber(), summarizer: FakeSummarizer(), keepScreenOn: { _ in })
    let a = await rekam(s, "a.wav")
    let b = await rekam(s, "b.wav")
    let urutan = s.todos.map(\.id)

    let t0 = s.todos[0].id
    s.toggle(t0); s.undo()
    cek("centang lalu urungkan", s.todos[0].isDone == false && s.undoOffer == nil)

    let lama = s.todos[1].title
    s.editTodo(s.todos[1].id, title: " judul\nbaru ")
    cek("edit dirapikan", s.todos[1].title == "judul baru")
    s.undo()
    cek("edit diurungkan", s.todos[1].title == lama)

    let recA = s.recording(a)!
    let tengah = recA.todoIDs[1]
    s.deleteTodo(tengah); s.undo()
    cek("hapus to-do diurungkan ke posisi semula", s.todos.map(\.id) == urutan && s.recording(a)!.todoIDs == recA.todoIDs)

    s.deleteRecording(b)
    cek("hapus rekaman: audio masih ada selama bisa diurungkan", s.recording(b) == nil && ada("b.wav"))
    s.undo()
    cek("hapus rekaman diurungkan", s.recording(b) != nil && s.todos.map(\.id) == urutan)
    s.deleteRecording(b)
    s.expireUndo(s.undoOffer!.id)
    cek("waktu urungkan habis: audio dibuang", !ada("b.wav") && ada("a.wav"))

    s.addTodo(title: "  tulis sendiri ", category: .ide)
    cek("tambah to-do", s.todos[0].title == "tulis sendiri" && s.todos[0].category == .ide && s.todos[0].recordingID == nil)
    s.addTodo(title: String(repeating: "x", count: 281), category: .ide)
    cek("tambah to-do terlalu panjang ditolak", s.todos[0].title == "tulis sendiri")

    // Rekaman yang sedang diproses tidak bisa dihapus
    let tr = FakeTranscriber(); tr.delayNs = 200_000_000
    let s2 = AppStore(transcriber: tr, summarizer: FakeSummarizer(), keepScreenOn: { _ in })
    let c = await rekam(s2, "c.wav", tunggu: false)
    s2.deleteRecording(c)
    cek("sedang diproses: tidak bisa dihapus", s2.recording(c) != nil && ada("c.wav"))
    await tunggu(s2, c)

    // Tertutup sebelum audio dibuang
    let d = await rekam(s2, "d.wav")
    s2.deleteRecording(d)
    let s3 = AppStore(transcriber: tr, summarizer: FakeSummarizer(), keepScreenOn: { _ in })
    cek("tertutup sebelum dibuang: dibuang saat dibuka lagi", !ada("d.wav") && s3.recording(d) == nil)

    // Pemakaian pertama (belum ada file data) dengan rekaman yatim: tetap dipulihkan
    let simpanData = try! Data(contentsOf: dataFile)
    try! FileManager.default.removeItem(at: dataFile)
    let folderLama = SpeechRecorder.folder.deletingLastPathComponent().appendingPathComponent("Recordings-lama")
    try! FileManager.default.moveItem(at: SpeechRecorder.folder, to: folderLama)
    audio("pertama.wav", detik: 1)
    let sPertama = AppStore(transcriber: tr, summarizer: FakeSummarizer(), keepScreenOn: { _ in })
    cek("pemakaian pertama: rekaman yatim tetap dipulihkan", sPertama.recordings.count == 1 && sPertama.recordings[0].audioFileName == "pertama.wav")
    let folderRekaman = docs.appendingPathComponent("Recordings") // tanpa SpeechRecorder.folder yang membuat folder
    try! FileManager.default.removeItem(at: folderRekaman)
    try! FileManager.default.moveItem(at: folderLama, to: folderRekaman)
    try! simpanData.write(to: dataFile)

    // Rekaman yatim dipulihkan
    audio("yatim.wav", detik: 2)
    let s4 = AppStore(transcriber: tr, summarizer: FakeSummarizer(), keepScreenOn: { _ in })
    let p = s4.recordings.first { $0.audioFileName == "yatim.wav" }
    cek("rekaman yatim dipulihkan (2 detik, terganggu)", p?.duration == 2 && p?.failReason == .interrupted && p?.canRetry == true)
}

@MainActor func ujiPenyimpanan() async {
    print("== Penyimpanan")
    bersih()
    // Data lama tanpa kolom-kolom baru
    let lama = """
    {"todos":[{"id":"11111111-2222-3333-4444-555555555555","title":"lama","category":"Rapat","due":"Jumat","source":"x","isDone":false,"createdAt":"2026-11-10T10:00:00Z"}],
     "recordings":[{"id":"8F2C4B7A-1111-2222-3333-444455556666","createdAt":"2026-11-11T10:00:00Z","title":"Lama","category":"Rapat","status":"processing","duration":4,"summary":"","points":[],"todoIDs":[],"transcript":"","audioFileName":"ada.wav"}]}
    """
    audio("ada.wav")
    try! Data(lama.utf8).write(to: dataFile)
    let s = AppStore(transcriber: FakeTranscriber(), summarizer: FakeSummarizer(), keepScreenOn: { _ in })
    cek("data versi lama terbaca tanpa pesan masalah", s.problem == nil && s.todos.count == 1 && s.recordings.count == 1)
    cek("to-do lama tanpa tanggal tetap menampilkan frasanya", s.todos[0].dueDate == nil && s.todos[0].dueLabel()?.teks == "Jumat")
    cek("kode galat versi lama tetap terbaca", (try? JSONDecoder().decode(FailReason.self, from: Data("\"pengenal-tidak-tersedia\"".utf8))) == .recognizerUnavailable)

    // Data rusak
    try! Data("{rusak".utf8).write(to: dataFile)
    let jumlahFile = try! FileManager.default.contentsOfDirectory(atPath: SpeechRecorder.folder.path).count
    let s2 = AppStore(transcriber: FakeTranscriber(), summarizer: FakeSummarizer(), keepScreenOn: { _ in })
    cek("data rusak: dicadangkan, audio tidak disentuh", s2.problem?.title == "Data lama tidak terbaca" && s2.recordings.isEmpty
        && (try! FileManager.default.contentsOfDirectory(atPath: SpeechRecorder.folder.path).count) == jumlahFile)

    // Gagal menyimpan
    bersih()
    let s3 = AppStore(transcriber: FakeTranscriber(), summarizer: FakeSummarizer(), keepScreenOn: { _ in })
    _ = await rekam(s3, "a.wav")
    chmod(docs.path, 0o500)
    s3.toggle(s3.todos[0].id)
    cek("gagal menyimpan: muncul pesan", s3.problem?.title == "Gagal menyimpan")
    s3.problem = nil
    s3.toggle(s3.todos[0].id)
    cek("gagal berturut-turut: pesan tidak diulang", s3.problem == nil)
    chmod(docs.path, 0o755)
    s3.toggle(s3.todos[0].id)
    cek("pulih: tidak ada pesan", s3.problem == nil)
    let ulang = AppStore(transcriber: FakeTranscriber(), summarizer: FakeSummarizer(), keepScreenOn: { _ in })
    cek("dibuka ulang: tanggal tenggat tersimpan", ulang.todos.first { $0.title == "satu" }?.dueDate != nil)
}

// MARK: Perekam (AudioSink asli)

func ujiPerekam() {
    print("== Perekam (konversi ke WAV 16 kHz)")
    for rate in [48000.0, 44100.0] {
        let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let src = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(rate * 3))!
        src.frameLength = src.frameCapacity
        for i in 0..<Int(src.frameLength) { src.floatChannelData![0][i] = 0.5 * Float(sin(2 * .pi * 440 * Double(i) / rate)) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sinus-\(Int(rate)).wav")
        let sink = AudioSink()
        sink.begin(file: try! AVAudioFile(forWriting: url, settings: RecordingFormat.format.settings, commonFormat: .pcmFormatInt16, interleaved: true),
                   converter: AVAudioConverter(from: fmt, to: RecordingFormat.format)!)
        var pos: AVAudioFrameCount = 0
        while pos < src.frameLength {
            let n = min(4096, src.frameLength - pos)
            let chunk = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n)!
            chunk.frameLength = n
            memcpy(chunk.floatChannelData![0], src.floatChannelData![0] + Int(pos), Int(n) * 4)
            sink.write(chunk)
            pos += n
        }
        let frames = sink.end()
        let f = try! AVAudioFile(forReading: url, commonFormat: .pcmFormatInt16, interleaved: true)
        let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length))!
        try! f.read(into: b)
        let p = b.int16ChannelData![0]
        var naik: [Int] = [], lonjak = 0
        for i in 1..<Int(b.frameLength) {
            if p[i-1] < 0 && p[i] >= 0 { naik.append(i) }
            if abs(Int(p[i]) - Int(p[i-1])) > 3277 { lonjak += 1 }
        }
        let hz = 16000 * Double(naik.count - 1) / Double(naik.last! - naik.first!)
        cek("\(Int(rate)) Hz: hasil 16 kHz mono, 3 detik (\(f.length) sampel), sama dengan yang dilaporkan",
            f.fileFormat.sampleRate == 16000 && f.fileFormat.channelCount == 1 && abs(f.length - 48000) <= 256 && frames == f.length)
        cek("\(Int(rate)) Hz: nada tetap 440 Hz (\(String(format: "%.3f", hz))), tanpa lonjakan di batas potongan", abs(hz - 440) < 0.5 && lonjak == 0)
        try? FileManager.default.removeItem(at: url)
    }
}

@MainActor func run() async {
    // Penjaga: hanya jalan di folder sementara (mktemp), tidak pernah di Documents asli.
    let sementara = ["/tmp/", "/var/folders/", "/private/var/folders/", "scratchpad"]
    guard ProcessInfo.processInfo.environment["CFFIXED_USER_HOME"] != nil, sementara.contains(where: docs.path.contains) else {
        print("x jalankan dengan CFFIXED_USER_HOME=$(mktemp -d), berhenti supaya Documents asli tidak tersentuh"); exit(2)
    }
    await ujiAlurProses()
    await ujiAntrean()
    await ujiHapusEditUndo()
    await ujiPenyimpanan()
    ujiPerekam()
    bersih()
    print(gagal == 0 ? "SEMUA LOLOS (\(jumlah) uji)" : "\(gagal) GAGAL dari \(jumlah)")
}
Task { await run(); exit(gagal == 0 ? 0 : 1) }
RunLoop.main.run()
