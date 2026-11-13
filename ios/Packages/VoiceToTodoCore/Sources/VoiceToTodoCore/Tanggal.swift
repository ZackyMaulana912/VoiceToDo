import Foundation

/// Tanggal tanpa jam (tenggat to-do). Disimpan sebagai tahun-bulan-hari supaya tidak bergeser karena zona waktu.
public struct Tanggal: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let tahun: Int
    public let bulan: Int
    public let hari: Int

    /// Zona patokan aplikasi (CLAUDE.md 5.5).
    public static let zona = TimeZone(identifier: "Asia/Jakarta")!

    static var kalender: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zona
        c.locale = Locale(identifier: "id_ID")
        return c
    }

    public init(tahun: Int, bulan: Int, hari: Int) {
        self.tahun = tahun
        self.bulan = bulan
        self.hari = hari
    }

    /// Tanggal di zona Asia/Jakarta pada saat `date`.
    public init(_ date: Date) {
        let c = Self.kalender.dateComponents([.year, .month, .day], from: date)
        self.init(tahun: c.year!, bulan: c.month!, hari: c.day!)
    }

    /// Tengah hari di zona Jakarta, aman dari pergantian hari saat dihitung.
    public var date: Date {
        Self.kalender.date(from: DateComponents(year: tahun, month: bulan, day: hari, hour: 12))!
    }

    public func tambah(hari n: Int) -> Tanggal {
        Tanggal(Self.kalender.date(byAdding: .day, value: n, to: date)!)
    }

    /// Selisih hari dari `self` ke `lain` (positif bila `lain` lebih akhir).
    public func selisihHari(ke lain: Tanggal) -> Int {
        Self.kalender.dateComponents([.day], from: date, to: lain.date).day!
    }

    /// 1 = Minggu, 2 = Senin, ... 7 = Sabtu (aturan Calendar).
    public var hariDalamPekan: Int {
        Self.kalender.component(.weekday, from: date)
    }

    public static func < (a: Tanggal, b: Tanggal) -> Bool {
        (a.tahun, a.bulan, a.hari) < (b.tahun, b.bulan, b.hari)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", tahun, bulan, hari)
    }

    // Disimpan sebagai teks "2026-11-14" di JSON.
    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Tanggal tidak valid: \(text)"))
        }
        self.init(tahun: parts[0], bulan: parts[1], hari: parts[2])
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}
