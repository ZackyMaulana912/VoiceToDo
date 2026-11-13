import SwiftUI

/// Alat uji kelayakan AI (Fase 1). Hanya muncul bila aplikasi dibuka dengan argumen `-ujiKelayakan`, misalnya:
///   xcrun devicectl device process launch --device <id> com.zackymaulana912.voicetodo -- -ujiKelayakan
/// File WAV uji disalin ke Documents/UjiKelayakan; hasilnya ditulis ke Documents/UjiKelayakan/hasil-<waktu>.jsonl.
/// Memakai pengenal suara dan peringkas yang sama dengan aplikasi; data to-do pengguna tidak disentuh.
struct UjiKelayakanView: View {
    @State private var log: [String] = []
    @State private var selesai = false

    static var folder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UjiKelayakan", isDirectory: true)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Uji kelayakan AI").font(.inter(24, weight: .semibold))
                Text("Jangan tutup aplikasi sampai tertulis selesai.").font(.inter(13)).foregroundStyle(Color.mutedInk)
                ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.system(size: 13, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
                }
                if selesai { Text("SELESAI").font(.inter(16, weight: .semibold)).foregroundStyle(Color(hex: 0x166534)) }
            }
            .padding(16)
        }
        .task { await jalankan() }
    }

    private func catat(_ s: String) {
        log.append(s)
        print("[uji] \(s)")
    }

    private func jalankan() async {
        ScreenAwake.set("uji", true)
        defer { ScreenAwake.set("uji", false) }
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let files = ((try? FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { ["wav", "caf", "m4a"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let out = Self.folder.appendingPathComponent("hasil-\(Int(Date().timeIntervalSince1970)).jsonl")
        FileManager.default.createFile(atPath: out.path, contents: nil)
        let handle = try? FileHandle(forWritingTo: out)
        let device = WhisperKitDevice.name
        catat("HP \(device), iOS \(UIDevice.current.systemVersion), \(files.count) file")
        if files.isEmpty { catat("Tidak ada file WAV di Documents/UjiKelayakan") }

        for file in files {
            var row: [String: Any] = [
                "file": file.lastPathComponent, "hp": device, "ios": UIDevice.current.systemVersion,
                "tanggal": ISO8601DateFormatter().string(from: Date()),
            ]
            row["memori_sisa_awal_mb"] = DeviceCheck.availableMB
            row["suhu_awal"] = Self.suhu
            catat("\(file.lastPathComponent): mengubah suara jadi teks...")
            let t0 = Date()
            do {
                let teks = try await WhisperTranscriber().transcribe(file)
                row["model_suara"] = WhisperTranscriber.lastModelName ?? "?"
                row["transkripsi_detik"] = Date().timeIntervalSince(t0)
                row["transkrip"] = teks
                row["memori_puncak_mb"] = MemoryInfo.peakFootprintMB
                row["memori_sisa_setelah_transkripsi_mb"] = DeviceCheck.availableMB
                row["suhu_setelah_transkripsi"] = Self.suhu
                catat("  teks \(teks.split(separator: " ").count) kata, \(String(format: "%.1f", Date().timeIntervalSince(t0))) s; merangkum...")

                let t1 = Date()
                let hasil = try await LlamaSummarizer().summarize(teks, date: Date())
                row["ringkasan_detik"] = Date().timeIntervalSince(t1)
                row["model_ringkasan"] = LlamaSummarizer.lastRun["model"] ?? "?"
                row["ringkasan_info"] = LlamaSummarizer.lastRun
                row["judul"] = hasil.title
                row["kategori"] = hasil.category.rawValue
                row["ringkasan"] = hasil.summary
                row["poin"] = hasil.points
                row["todo"] = hasil.todos.map { ["teks": $0.title, "frasa": $0.due as Any? ?? NSNull()] as [String: Any] }
                catat("  \(hasil.todos.count) to-do, \(String(format: "%.1f", Date().timeIntervalSince(t1))) s")
            } catch {
                row["galat"] = "\(error)"
                row["ringkasan_info"] = LlamaSummarizer.lastRun
                catat("  GAGAL: \(error)")
            }
            row["total_detik"] = Date().timeIntervalSince(t0)
            row["memori_puncak_akhir_mb"] = MemoryInfo.peakFootprintMB
            row["memori_sisa_akhir_mb"] = DeviceCheck.availableMB
            row["suhu_akhir"] = Self.suhu
            if let data = try? JSONSerialization.data(withJSONObject: row) {
                handle?.write(data)
                handle?.write(Data("\n".utf8))
            }
        }
        try? handle?.close()
        catat("Hasil: \(out.lastPathComponent)")
        selesai = true
    }

    static var suhu: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "normal"
        case .fair: return "hangat"
        case .serious: return "panas"
        case .critical: return "kritis"
        @unknown default: return "?"
        }
    }
}

/// Nama perangkat ("iPhone18,1"), tanpa bergantung pada WhisperKit di tampilan.
enum WhisperKitDevice {
    static var name: String {
        #if targetEnvironment(simulator)
        return "Simulator " + (ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "?")
        #else
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        #endif
    }
}

/// Pemakaian memori aplikasi menurut iOS (angka yang dipakai iOS untuk menutup paksa aplikasi).
enum MemoryInfo {
    static var peakFootprintMB: Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Int(info.ledger_phys_footprint_peak / 1_048_576)
    }
}
