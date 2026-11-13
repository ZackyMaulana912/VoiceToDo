import Foundation

/// Teks chip tenggat di kartu to-do, relatif terhadap hari ini.
public enum LabelTenggat {
    public struct Hasil: Equatable, Sendable {
        public let teks: String
        /// True bila tenggat sudah lewat dan to-do belum selesai (chip ditampilkan merah).
        public let terlambat: Bool
    }

    static let bulan = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"]
    static let hari = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"]

    /// - Parameters:
    ///   - tanggal: tenggat hasil `FrasaWaktu`, bila ada.
    ///   - frasa: frasa waktu asli dari rekaman ("minggu depan"), dipakai bila tidak ada tanggal.
    public static func buat(tanggal: Tanggal?, frasa: String?, hariIni: Tanggal, selesai: Bool) -> Hasil? {
        guard let tanggal else {
            guard let f = frasa?.trimmingCharacters(in: .whitespaces), let awal = f.first else { return nil }
            return Hasil(teks: awal.uppercased() + f.dropFirst(), terlambat: false)
        }
        let jarak = hariIni.selisihHari(ke: tanggal)
        switch jarak {
        case ..<0:
            return selesai ? Hasil(teks: singkat(tanggal, hariIni), terlambat: false)
                           : Hasil(teks: "Terlambat · \(singkat(tanggal, hariIni))", terlambat: true)
        case 0: return Hasil(teks: "Hari ini", terlambat: false)
        case 1: return Hasil(teks: "Besok", terlambat: false)
        case 2: return Hasil(teks: "Lusa", terlambat: false)
        case 3...6: return Hasil(teks: hari[tanggal.hariDalamPekan - 1], terlambat: false)
        default: return Hasil(teks: singkat(tanggal, hariIni), terlambat: false)
        }
    }

    /// "15 Des", atau "15 Des 2027" bila tahunnya berbeda dengan hari ini.
    static func singkat(_ t: Tanggal, _ hariIni: Tanggal) -> String {
        let dasar = "\(t.hari) \(bulan[t.bulan - 1])"
        return t.tahun == hariIni.tahun ? dasar : "\(dasar) \(t.tahun)"
    }
}
