import XCTest
@testable import VoiceToTodoCore

final class LabelTenggatTests: XCTestCase {
    let kamis = Tanggal(tahun: 2026, bulan: 11, hari: 12)

    func label(_ t: Tanggal?, frasa: String? = nil, selesai: Bool = false) -> LabelTenggat.Hasil? {
        LabelTenggat.buat(tanggal: t, frasa: frasa, hariIni: kamis, selesai: selesai)
    }

    func testTanpaTanggalDanFrasa() {
        XCTAssertNil(label(nil))
        XCTAssertNil(label(nil, frasa: "  "))
    }

    func testTanpaTanggalMemakaiFrasa() {
        XCTAssertEqual(label(nil, frasa: "minggu depan")?.teks, "Minggu depan")
        XCTAssertEqual(label(nil, frasa: "minggu depan")?.terlambat, false)
    }

    func testDekat() {
        XCTAssertEqual(label(kamis)?.teks, "Hari ini")
        XCTAssertEqual(label(kamis.tambah(hari: 1))?.teks, "Besok")
        XCTAssertEqual(label(kamis.tambah(hari: 2))?.teks, "Lusa")
        XCTAssertEqual(label(kamis.tambah(hari: 3))?.teks, "Minggu")
        XCTAssertEqual(label(kamis.tambah(hari: 6))?.teks, "Rabu")
    }

    func testJauh() {
        XCTAssertEqual(label(kamis.tambah(hari: 7))?.teks, "19 Nov")
        XCTAssertEqual(label(Tanggal(tahun: 2026, bulan: 12, hari: 25))?.teks, "25 Des")
        XCTAssertEqual(label(Tanggal(tahun: 2027, bulan: 1, hari: 5))?.teks, "5 Jan 2027")
    }

    func testTerlambat() {
        let kemarin = kamis.tambah(hari: -1)
        XCTAssertEqual(label(kemarin), .init(teks: "Terlambat · 11 Nov", terlambat: true))
        XCTAssertEqual(label(kemarin, selesai: true), .init(teks: "11 Nov", terlambat: false))
    }
}
