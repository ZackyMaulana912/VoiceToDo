import XCTest

/// Uji UI otomatis di Simulator (Fase 6 dan 7). Aplikasi dibuka dengan `-ujiUI` sehingga datanya kosong
/// (lihat UjiUI.swift). Tangkapan layar disimpan ke folder `SCREENSHOT_DIR` bila diisi, misalnya:
///   TEST_RUNNER_SCREENSHOT_DIR=/tmp/layar TEST_RUNNER_UJI_AUDIO=/path/rekaman.wav xcodebuild test ...
final class VoiceToTodoUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    func buka(ukuranHuruf: String? = nil, audio: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["-ujiUI"]
        if let ukuranHuruf { app.launchArguments += ["-UIPreferredContentSizeCategoryName", ukuranHuruf] }
        if audio, let path = ProcessInfo.processInfo.environment["UJI_AUDIO"] { app.launchEnvironment["UJI_AUDIO"] = path }
        app.launch()
    }

    func layar(_ nama: String) {
        let shot = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: shot)
        a.name = nama
        a.lifetime = .keepAlways
        add(a)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(nama).png"))
        }
    }

    func tambah(_ teks: String, kategori: String = "Kuliah") {
        app.buttons["Tambah to-do"].tap()
        let field = app.textFields["Teks to-do"].exists ? app.textFields["Teks to-do"] : app.textViews["Teks to-do"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(teks)
        app.buttons[kategori].tap()
        app.buttons["Simpan"].tap()
        XCTAssertTrue(app.staticTexts[teks].waitForExistence(timeout: 5))
    }

    // MARK: Alur tanpa AI

    func testAlurToDoTanpaRekaman() {
        buka()
        XCTAssertTrue(app.staticTexts["Belum ada to-do"].waitForExistence(timeout: 10))
        layar("01-beranda-kosong")

        // Isian kosong tidak bisa disimpan
        app.buttons["Tambah to-do"].tap()
        XCTAssertTrue(app.staticTexts["Tambah to-do"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Simpan"].isEnabled, "Simpan harus mati saat isian kosong")
        layar("02-lembar-tambah")
        app.buttons["Batal"].tap()

        tambah("Beli kertas HVS dua rim")
        tambah("Telepon Pak Andi", kategori: "Rapat")
        layar("03-beranda-dua-todo")

        // Centang lalu urungkan
        app.buttons["Tandai selesai"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["To-do ditandai selesai"].waitForExistence(timeout: 5))
        layar("04-bar-urungkan")
        app.buttons["Urungkan"].tap()
        XCTAssertTrue(app.staticTexts["Telepon Pak Andi"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "Tandai selesai").count, 2)

        // Edit lewat tekan lama
        app.staticTexts["Telepon Pak Andi"].press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Edit to-do"].waitForExistence(timeout: 5))
        layar("05-menu-tekan-lama")
        app.buttons["Edit to-do"].tap()
        let field = app.textFields["Teks to-do"].exists ? app.textFields["Teks to-do"] : app.textViews["Teks to-do"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(" besok")
        layar("06-lembar-edit")
        app.buttons["Simpan"].tap()
        XCTAssertTrue(app.staticTexts["Telepon Pak Andi besok"].waitForExistence(timeout: 5))

        // Hapus dengan konfirmasi, lalu urungkan
        app.staticTexts["Beli kertas HVS dua rim"].press(forDuration: 1.2)
        app.buttons["Hapus to-do"].tap()
        XCTAssertTrue(app.staticTexts["Hapus to-do ini?"].waitForExistence(timeout: 5))
        layar("07-konfirmasi-hapus")
        ketuk("Hapus to-do")
        XCTAssertTrue(app.staticTexts["To-do dihapus"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Beli kertas HVS dua rim"].exists)
        app.buttons["Urungkan"].tap()
        XCTAssertTrue(app.staticTexts["Beli kertas HVS dua rim"].waitForExistence(timeout: 5))

        // Segmen Selesai dan Riwayat kosong
        app.buttons["Selesai"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Belum ada to-do selesai"].waitForExistence(timeout: 5))
        app.buttons["tab-riwayat"].tap()
        layar("08-riwayat-kosong")
    }

    // MARK: Ukuran huruf besar (Dynamic Type)

    func testUkuranHurufBesar() {
        for (ukuran, nama) in [("UICTContentSizeCategoryXL", "xl"), ("UICTContentSizeCategoryAccessibilityL", "aksesibilitas-l")] {
            buka(ukuranHuruf: ukuran)
            XCTAssertTrue(app.staticTexts["Belum ada to-do"].waitForExistence(timeout: 10))
            tambah("Kirim proposal sponsor ke tiga perusahaan sebelum rapat berikutnya")
            layar("20-huruf-\(nama)-beranda")
            app.buttons["Tambah to-do"].tap()
            _ = app.staticTexts["Tambah to-do"].waitForExistence(timeout: 5)
            layar("21-huruf-\(nama)-lembar-tambah")
            app.buttons["Batal"].tap()
            app.terminate()
        }
    }

    // MARK: Layar perekam

    /// Butuh masukan mikrofon. Simulator di Mac pengembang tidak bisa memberikannya (bahkan program terkecil yang hanya
    /// meminta `AVAudioEngine.inputNode` berhenti paksa, uji 2026-11-12), jadi uji ini hanya jalan dengan UJI_MIKROFON=1.
    func testLayarPerekamDanBatal() throws {
        guard ProcessInfo.processInfo.environment["UJI_MIKROFON"] == "1" else {
            throw XCTSkip("butuh mikrofon: jalankan dengan TEST_RUNNER_UJI_MIKROFON=1 di HP atau Simulator yang punya akses mikrofon")
        }
        // Dialog izin mikrofon (bila belum diizinkan lewat `simctl privacy`) dijawab "Izinkan".
        addUIInterruptionMonitor(withDescription: "izin mikrofon") { alert in
            for label in ["Allow", "Izinkan", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        buka()
        app.buttons["Mulai merekam"].tap()
        app.tap() // memicu penanganan dialog izin bila ada
        let merekam = app.staticTexts["Merekam"].waitForExistence(timeout: 10)
        layar("29-setelah-tekan-rekam")
        XCTAssertTrue(merekam, "layar perekam tidak muncul (lihat tangkapan layar 29)")
        sleep(2)
        layar("30-perekam")
        app.buttons["Batal"].tap()
        XCTAssertTrue(app.staticTexts["Buang rekaman ini?"].waitForExistence(timeout: 5))
        layar("31-konfirmasi-batal")
        app.buttons["Lanjut merekam"].tap()
        XCTAssertTrue(app.staticTexts["Merekam"].exists, "Lanjut merekam harus tetap merekam")
        app.buttons["Batal"].tap()
        app.buttons["Buang rekaman"].tap()
        XCTAssertTrue(app.staticTexts["Belum ada to-do"].waitForExistence(timeout: 5))
        app.buttons["tab-riwayat"].tap()
        XCTAssertFalse(app.staticTexts["Rekaman baru"].exists, "rekaman yang dibuang tidak boleh muncul di Riwayat")
    }

    // MARK: Rekaman diproses AI sungguhan (Whisper + llama.cpp)

    /// Mengetuk tombol berlabel `label` yang benar-benar bisa diketuk (misalnya di dialog, bukan yang tertutup dialog).
    func ketuk(_ label: String) {
        let semua = app.buttons.matching(identifier: label).allElementsBoundByIndex
        guard let tombol = semua.last(where: { $0.isHittable }) else { return XCTFail("tombol \(label) tidak bisa diketuk") }
        tombol.tap()
    }

    /// Baris Riwayat adalah tombol; teks di dalamnya tergabung menjadi label tombol itu.
    func baris(_ teks: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", teks)).firstMatch
    }

    func testProsesRekamanSampaiToDo() throws {
        guard ProcessInfo.processInfo.environment["UJI_AUDIO"] != nil else { throw XCTSkip("UJI_AUDIO tidak diisi") }
        buka(audio: true)
        app.buttons["tab-riwayat"].tap()
        let dipulihkan = baris("Rekaman dipulihkan").waitForExistence(timeout: 10)
        layar("40-riwayat-rekaman-dipulihkan")
        XCTAssertTrue(dipulihkan, "rekaman yang tertinggal harus dipulihkan")
        baris("Rekaman dipulihkan").tap()
        XCTAssertTrue(app.buttons["Coba lagi"].waitForExistence(timeout: 5))
        layar("41-detail-gagal-terganggu")
        app.buttons["Coba lagi"].tap()
        XCTAssertTrue(app.staticTexts["Mengubah suara jadi teks..."].waitForExistence(timeout: 30))
        layar("42-memproses-tahap-1")

        // Model di CPU Simulator lambat; tunggu sampai 20 menit.
        let hasil = app.staticTexts["To-do dari rekaman"].waitForExistence(timeout: 1_200)
        layar("43-hasil-di-beranda")
        XCTAssertTrue(hasil, "hasil ringkasan tidak muncul")
        XCTAssertGreaterThan(app.buttons.matching(identifier: "Tandai selesai").count, 0)

        app.buttons["tab-riwayat"].tap()
        XCTAssertFalse(baris("Rekaman dipulihkan").exists, "judul rekaman harus diganti hasil AI")
        layar("44-riwayat-selesai")
        baris("Selesai").tap()
        XCTAssertTrue(app.buttons["Hapus rekaman"].waitForExistence(timeout: 5))
        app.swipeUp()
        layar("45-detail-selesai")
        app.buttons["Hapus rekaman"].tap()
        XCTAssertTrue(app.staticTexts["Hapus rekaman ini?"].waitForExistence(timeout: 5))
        layar("46-konfirmasi-hapus-rekaman")
        ketuk("Hapus rekaman")
        XCTAssertTrue(app.staticTexts["Rekaman dihapus"].waitForExistence(timeout: 5))
        layar("47-rekaman-dihapus")
        app.buttons["Urungkan"].tap()
        XCTAssertTrue(baris("Selesai").waitForExistence(timeout: 5), "rekaman harus kembali setelah diurungkan")
    }
}
