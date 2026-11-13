import XCTest
@testable import VoiceToTodoCore

/// Satu test untuk setiap baris tabel CLAUDE.md 5.5, ditambah pergantian bulan dan tahun.
final class FrasaWaktuTests: XCTestCase {
    /// Kamis, 12 November 2026.
    let kamis = Tanggal(tahun: 2026, bulan: 11, hari: 12)

    func t(_ frasa: String, _ dari: Tanggal? = nil) -> String? {
        FrasaWaktu.tanggal(frasa, hariRekaman: dari ?? kamis)?.description
    }

    func testPatokanBenarKamis() {
        XCTAssertEqual(kamis.hariDalamPekan, 5)
    }

    func testHariIniDanNanti() {
        XCTAssertEqual(t("hari ini"), "2026-11-12")
        XCTAssertEqual(t("Nanti"), "2026-11-12")
        XCTAssertEqual(t("nanti sore"), "2026-11-12")
        XCTAssertEqual(t("malam ini"), "2026-11-12")
    }

    func testBesokDanLusa() {
        XCTAssertEqual(t("besok"), "2026-11-13")
        XCTAssertEqual(t("Besok pagi"), "2026-11-13")
        XCTAssertEqual(t("lusa"), "2026-11-14")
        XCTAssertEqual(t("besok lusa"), "2026-11-14")
    }

    func testNamaHariPertamaSetelahHariRekaman() {
        XCTAssertEqual(t("Jumat"), "2026-11-13")
        XCTAssertEqual(t("hari Jumat"), "2026-11-13")
        XCTAssertEqual(t("Jumat ini"), "2026-11-13")
        XCTAssertEqual(t("jum'at"), "2026-11-13")
        XCTAssertEqual(t("paling lambat Jumat"), "2026-11-13")
        XCTAssertEqual(t("Sabtu"), "2026-11-14")
        XCTAssertEqual(t("Minggu"), "2026-11-15")
        XCTAssertEqual(t("Senin"), "2026-11-16")
        XCTAssertEqual(t("Selasa"), "2026-11-17")
        XCTAssertEqual(t("Rabu"), "2026-11-18")
    }

    func testNamaHariSamaDenganHariRekamanBerartiPekanBerikutnya() {
        XCTAssertEqual(t("Kamis"), "2026-11-19")
        XCTAssertEqual(t("hari Kamis ini"), "2026-11-19")
    }

    func testHariDepanSamaDenganNamaHari() {
        XCTAssertEqual(t("Jumat depan"), "2026-11-13")
        XCTAssertEqual(t("Senin depan"), "2026-11-16")
        XCTAssertEqual(t("hari Minggu depan"), "2026-11-15")
    }

    func testNantiDenganNamaHariTetapNamaHari() {
        XCTAssertEqual(t("nanti Jumat"), "2026-11-13")
    }

    func testTanggalN() {
        XCTAssertEqual(t("tanggal 15"), "2026-11-15")
        XCTAssertEqual(t("tanggal 12"), "2026-11-12", "hari rekaman dihitung belum lewat")
        XCTAssertEqual(t("tanggal 10"), "2026-12-10", "sudah lewat bulan ini: bulan depan")
        XCTAssertEqual(t("tgl 3"), "2026-12-03")
        XCTAssertEqual(t("sebelum tanggal 20"), "2026-11-20")
    }

    func testTanggalYangTidakAdaDiBulanItuLompatKeBulanBerikutnya() {
        let feb = Tanggal(tahun: 2026, bulan: 2, hari: 15)
        XCTAssertEqual(t("tanggal 31", feb), "2026-03-31")
        XCTAssertEqual(t("tanggal 30", feb), "2026-03-30")
        let nov = Tanggal(tahun: 2026, bulan: 11, hari: 20)
        XCTAssertEqual(t("tanggal 31", nov), "2026-12-31", "November hanya 30 hari")
    }

    func testTanpaTenggat() {
        for frasa in ["minggu depan", "Minggu depan", "2 minggu depan", "dua minggu lagi", "minggu ini", "bulan depan",
                      "akhir bulan", "tahun depan", "akhir pekan", "secepatnya", "kapan-kapan", "", "   ",
                      "Senin atau Selasa", "tanggal 32", "tanggal 0"] {
            XCTAssertNil(t(frasa), "\"\(frasa)\" seharusnya tanpa tenggat")
        }
    }

    func testPergantianBulan() {
        let akhirJan = Tanggal(tahun: 2026, bulan: 1, hari: 31)
        XCTAssertEqual(t("besok", akhirJan), "2026-02-01")
        XCTAssertEqual(t("lusa", akhirJan), "2026-02-02")
        let akhirNov = Tanggal(tahun: 2026, bulan: 11, hari: 30) // Senin
        XCTAssertEqual(t("Jumat", akhirNov), "2026-12-04")
    }

    func testPergantianTahun() {
        let akhirTahun = Tanggal(tahun: 2026, bulan: 12, hari: 31) // Kamis
        XCTAssertEqual(t("besok", akhirTahun), "2027-01-01")
        XCTAssertEqual(t("Senin", akhirTahun), "2027-01-04")
        XCTAssertEqual(t("tanggal 5", akhirTahun), "2027-01-05")
        XCTAssertEqual(t("tanggal 31", akhirTahun), "2026-12-31")
    }

    func testTahunKabisat() {
        XCTAssertEqual(t("besok", Tanggal(tahun: 2028, bulan: 2, hari: 28)), "2028-02-29")
        XCTAssertEqual(t("tanggal 29", Tanggal(tahun: 2027, bulan: 2, hari: 10)), "2027-03-29", "2027 bukan kabisat")
    }

    func testTanggalDariWaktuMemakaiZonaJakarta() {
        // 18.30 UTC = 01.30 WIB keesokan harinya.
        let date = ISO8601DateFormatter().date(from: "2026-11-12T18:30:00Z")!
        XCTAssertEqual(Tanggal(date).description, "2026-11-13")
    }

    func testTanggalDisimpanSebagaiTeks() throws {
        let data = try JSONEncoder().encode([kamis])
        XCTAssertEqual(String(data: data, encoding: .utf8), #"["2026-11-12"]"#)
        XCTAssertEqual(try JSONDecoder().decode([Tanggal].self, from: data), [kamis])
        XCTAssertThrowsError(try JSONDecoder().decode([Tanggal].self, from: Data(#"["kemarin"]"#.utf8)))
    }

    func testUrutanTanggal() {
        XCTAssertLessThan(kamis, kamis.tambah(hari: 1))
        XCTAssertEqual(kamis.selisihHari(ke: Tanggal(tahun: 2027, bulan: 11, hari: 12)), 365)
    }
}
