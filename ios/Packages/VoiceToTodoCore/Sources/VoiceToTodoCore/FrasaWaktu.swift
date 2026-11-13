import Foundation

/// Mengubah frasa waktu yang diucapkan ("besok", "Jumat", "tanggal 15") menjadi tanggal tenggat.
/// Aturannya di CLAUDE.md 5.5. AI hanya menyalin frasanya; perhitungan tanggal dilakukan di sini.
public enum FrasaWaktu {
    /// Tanggal tenggat untuk `frasa`, dihitung dari hari rekaman. Nil bila frasa tidak menunjuk satu hari
    /// (misalnya "minggu depan") atau hasilnya di luar rentang hari rekaman sampai 366 hari sesudahnya.
    public static func tanggal(_ frasa: String, hariRekaman: Tanggal) -> Tanggal? {
        guard let hasil = hitung(normalisasi(frasa), dari: hariRekaman) else { return nil }
        let jarak = hariRekaman.selisihHari(ke: hasil)
        return (0...366).contains(jarak) ? hasil : nil
    }

    // MARK: Aturan

    private static let namaHari: [(pola: String, weekday: Int)] = [
        ("senin", 2), ("selasa", 3), ("rabu", 4), ("kamis", 5), ("jumat", 6), ("sabtu", 7), ("minggu", 1),
    ]

    private static func hitung(_ f: String, dari rekaman: Tanggal) -> Tanggal? {
        guard !f.isEmpty else { return nil }

        // "hari Minggu" (juga "hari Minggu depan") selalu berarti hari Minggu.
        let hariMinggu = cocok(f, #"\bhari minggu\b"#)

        // Rentang yang tidak menunjuk satu hari: tanpa tenggat (ARTI_MINGGU_DEPAN).
        if !hariMinggu && cocok(f, #"\bminggu (depan|ini|lagi|berikutnya|ke ?depan)\b|\b\d+ minggu\b|\bdua minggu\b|\bbulan\b|\btahun\b|\bakhir pekan\b|\bweekend\b"#) {
            return nil
        }

        if cocok(f, #"\blusa\b"#) { return rekaman.tambah(hari: 2) }
        if cocok(f, #"\bbesok\b"#) { return rekaman.tambah(hari: 1) }
        // Nama hari: hari itu yang pertama setelah hari rekaman. Kalau dua nama hari berbeda disebut, ragu: kosong.
        let disebut = Set(namaHari.filter { cocok(f, "\\b\($0.pola)\\b") }.map(\.weekday))
        if disebut.count == 1, let target = disebut.first {
            var jarak = (target - rekaman.hariDalamPekan + 7) % 7
            if jarak == 0 { jarak = 7 } // hari yang sama dengan hari rekaman: pekan berikutnya
            return rekaman.tambah(hari: jarak)
        }
        if disebut.count > 1 { return nil }

        // "tanggal 15": tanggal 15 terdekat yang belum lewat (hari rekaman dihitung belum lewat).
        if let n = angka(f, #"\b(?:tanggal|tgl\.?)\s*(\d{1,2})\b"#), (1...31).contains(n) {
            var tahun = rekaman.tahun
            var bulan = rekaman.bulan
            for _ in 0..<13 {
                if n <= jumlahHari(tahun: tahun, bulan: bulan) {
                    let calon = Tanggal(tahun: tahun, bulan: bulan, hari: n)
                    if calon >= rekaman { return calon }
                }
                bulan += 1
                if bulan > 12 { bulan = 1; tahun += 1 }
            }
            return nil
        }

        // Dicek paling akhir supaya "nanti Jumat" tetap berarti Jumat.
        if cocok(f, #"\bhari ini\b|\bnanti\b|\b(pagi|siang|sore|malam) ini\b"#) { return rekaman }
        return nil
    }

    // MARK: Alat bantu

    static func normalisasi(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "jum'at", with: "jumat")
            .replacingOccurrences(of: "jum’at", with: "jumat")
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s.]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func cocok(_ s: String, _ pola: String) -> Bool {
        s.range(of: pola, options: .regularExpression) != nil
    }

    private static func angka(_ s: String, _ pola: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: pola),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return Int(s[r])
    }

    private static func jumlahHari(tahun: Int, bulan: Int) -> Int {
        let tgl = Tanggal(tahun: tahun, bulan: bulan, hari: 1).date
        return Tanggal.kalender.range(of: .day, in: .month, for: tgl)!.count
    }
}
