import XCTest
@testable import VoiceToTodoCore

final class RingkasanTests: XCTestCase {
    let transkrip = "Dimas tolong kirim proposal paling lambat hari Jumat. Bayu selesaikan poster besok."

    func json(judul: String = "Rapat Panitia", kategori: String = "Rapat", ringkasan: String = "Rapat membahas sponsor.",
              poin: [String] = ["Sponsor belum pasti"], tugas: String = #"[{"teks":"Kirim proposal","frasaWaktu":"hari Jumat"}]"#) -> String {
        let p = poin.map { "\"\($0)\"" }.joined(separator: ",")
        return #"{"judul":"\#(judul)","kategori":"\#(kategori)","ringkasan":"\#(ringkasan)","poin":[\#(p)],"tugas":\#(tugas)}"#
    }

    func testKeluaranNormal() throws {
        let h = try Ringkasan.baca(json(), transkrip: transkrip)
        XCTAssertEqual(h.judul, "Rapat Panitia")
        XCTAssertEqual(h.kategori, "Rapat")
        XCTAssertEqual(h.tugas, [.init(teks: "Kirim proposal", frasaWaktu: "hari Jumat")])
    }

    func testTeksDirapikan() throws {
        let h = try Ringkasan.baca(json(judul: "  Rapat   Panitia ", poin: ["  satu ", "  "],
                                        tugas: #"[{"teks":"  Kirim  proposal ","frasaWaktu":"  besok "},{"teks":"   ","frasaWaktu":null}]"#),
                                   transkrip: transkrip)
        XCTAssertEqual(h.judul, "Rapat Panitia")
        XCTAssertEqual(h.poin, ["satu"])
        XCTAssertEqual(h.tugas, [.init(teks: "Kirim proposal", frasaWaktu: "besok")])
    }

    func testTugasKembarDibuang() throws {
        let h = try Ringkasan.baca(json(tugas: #"[{"teks":"Kirim proposal","frasaWaktu":null},{"teks":"kirim proposal","frasaWaktu":null}]"#),
                                   transkrip: transkrip)
        XCTAssertEqual(h.tugas.count, 1)
    }

    func testFrasaWaktuKaranganDikosongkan() throws {
        // "Senin" tidak ada di transkrip: dianggap karangan model.
        let h = try Ringkasan.baca(json(tugas: #"[{"teks":"Kirim proposal","frasaWaktu":"Senin"},{"teks":"Selesaikan poster","frasaWaktu":"Besok."}]"#),
                                   transkrip: transkrip)
        XCTAssertNil(h.tugas[0].frasaWaktu)
        XCTAssertEqual(h.tugas[1].frasaWaktu, "Besok.")
    }

    func testFrasaHarusKataUtuh() throws {
        // "Jum" ada di dalam "Jumat" tapi bukan kata utuh.
        let h = try Ringkasan.baca(json(tugas: #"[{"teks":"Kirim proposal","frasaWaktu":"Jum"}]"#), transkrip: transkrip)
        XCTAssertNil(h.tugas[0].frasaWaktu)
    }

    func testTeksSebelumDanSesudahJSONDiabaikan() throws {
        XCTAssertNoThrow(try Ringkasan.baca("Berikut hasilnya:\n" + json() + "\nSelesai.", transkrip: transkrip))
    }

    func testBukanJSON() {
        XCTAssertThrowsError(try Ringkasan.baca("maaf saya tidak bisa", transkrip: transkrip)) {
            XCTAssertEqual($0 as? Ringkasan.Galat, .bukanJSON)
        }
        XCTAssertThrowsError(try Ringkasan.baca(#"{"judul":"x"}"#, transkrip: transkrip))
    }

    func testMelanggarBatas() {
        func galat(_ s: String) -> Ringkasan.Galat? {
            do { _ = try Ringkasan.baca(s, transkrip: transkrip); return nil } catch { return error as? Ringkasan.Galat }
        }
        XCTAssertEqual(galat(json(judul: " ")), .tidakSesuaiAturan("judul"))
        XCTAssertEqual(galat(json(judul: String(repeating: "a", count: 121))), .tidakSesuaiAturan("judul"))
        XCTAssertEqual(galat(json(kategori: "Lainnya")), .tidakSesuaiAturan("kategori"))
        XCTAssertEqual(galat(json(ringkasan: "")), .tidakSesuaiAturan("ringkasan"))
        XCTAssertEqual(galat(json(poin: Array(repeating: "p", count: 13))), .tidakSesuaiAturan("poin"))
        XCTAssertEqual(galat(json(poin: [String(repeating: "p", count: 301)])), .tidakSesuaiAturan("poin"))
        let banyak = (1...31).map { #"{"teks":"tugas \#($0)","frasaWaktu":null}"# }.joined(separator: ",")
        XCTAssertEqual(galat(json(tugas: "[\(banyak)]")), .tidakSesuaiAturan("tugas"))
        XCTAssertEqual(galat(json(tugas: #"[{"teks":"\#(String(repeating: "t", count: 281))","frasaWaktu":null}]"#)), .tidakSesuaiAturan("tugas"))
        XCTAssertNil(galat(json(judul: String(repeating: "a", count: 120))))
    }

    func testTanpaTugas() throws {
        XCTAssertEqual(try Ringkasan.baca(json(tugas: "[]"), transkrip: transkrip).tugas, [])
    }

    func testTranskripPanjangDipotongDiBatasKata() {
        let panjang = String(repeating: "kata ", count: 13_000) // 65.000 karakter
        XCTAssertTrue(Ringkasan.terpotong(panjang))
        let p = Ringkasan.potong(panjang)
        XCTAssertLessThanOrEqual(p.count, Ringkasan.Batas.transkrip)
        XCTAssertTrue(p.hasSuffix("kata"))
        XCTAssertEqual(Ringkasan.potong("pendek"), "pendek")
    }

    func testGrammarMengizinkanJSONBerindentasi() {
        // Aturan spasi harus cukup untuk baris baru + 8 spasi (indentasi dua tingkat).
        let ws = Ringkasan.grammar.split(separator: "\n").first { $0.hasPrefix("ws ::=") }!
        let batas = Int(ws.split(separator: ",").last!.dropLast())!
        XCTAssertGreaterThanOrEqual(batas, 9)
    }

    func testTranskripPendekTidakDipecah() {
        XCTAssertEqual(Ringkasan.bagian(transkrip), [transkrip])
    }

    func testTranskripPanjangDipecahDiBatasKalimat() {
        let k1 = Array(repeating: "satu", count: 150).joined(separator: " ") + "."
        let k2 = Array(repeating: "dua", count: 150).joined(separator: " ") + "?"
        let k3 = Array(repeating: "tiga", count: 50).joined(separator: " ") + "!"
        let b = Ringkasan.bagian("\(k1) \(k2) \(k3)", kataPerBagian: 250)
        XCTAssertEqual(b, [k1, "\(k2) \(k3)"])
        // Tidak ada kata yang hilang.
        XCTAssertEqual(b.joined(separator: " ").split(separator: " ").count, 350)
    }

    func testKalimatSangatPanjangTanpaTitikDipecahPerKata() {
        let panjang = (1...600).map { "k\($0)" }.joined(separator: " ")
        let b = Ringkasan.bagian(panjang, kataPerBagian: 250)
        XCTAssertEqual(b.map { $0.split(separator: " ").count }, [250, 250, 100])
        XCTAssertEqual(b.joined(separator: " "), panjang)
    }

    func testGabungHasilBagian() {
        let a = HasilRingkasan(judul: "A", kategori: "Ide", ringkasan: "ra", poin: ["pa"],
                               tugas: [.init(teks: "Kirim proposal", frasaWaktu: "Jumat"), .init(teks: "Beli kertas", frasaWaktu: nil)])
        let b = HasilRingkasan(judul: "B", kategori: "Ide", ringkasan: "rb", poin: ["pb"],
                               tugas: [.init(teks: "kirim proposal", frasaWaktu: nil), .init(teks: "Telepon Andi", frasaWaktu: "besok")])
        let akhir = HasilRingkasan(judul: "Rapat Panitia", kategori: "Rapat", ringkasan: "gabungan", poin: ["p"], tugas: [])
        let g = Ringkasan.gabung([a, b], akhir: akhir)
        XCTAssertEqual(g.judul, "Rapat Panitia")
        XCTAssertEqual(g.kategori, "Rapat")
        XCTAssertEqual(g.tugas.map(\.teks), ["Kirim proposal", "Beli kertas", "Telepon Andi"])
        XCTAssertEqual(Ringkasan.ringkasanBagian([a, b]), "ra pa\nrb pb")
    }

    func testGrammarTanpaTugasBenarBenarMengosongkanTugas() {
        XCTAssertNotEqual(Ringkasan.grammarTanpaTugas, Ringkasan.grammar)
        XCTAssertTrue(Ringkasan.grammarTanpaTugas.contains(#"tugas ::= "[]""#))
        XCTAssertFalse(Ringkasan.grammarTanpaTugas.contains(#"tugas ::= "[" ws"#))
    }

    func testPesanPenggunaMembungkusTranskrip() {
        XCTAssertEqual(Ringkasan.pesanPengguna(transkrip: "halo"), "<transkrip>\nhalo\n</transkrip>")
    }
}
