# Fase 8: Penyusunan dokumen

Rencana dokumen akhir Voice-to-Todo (SRS dan arsitektur). Susunannya mengikuti contoh dokumen RBPL yang memakai model
4+1 View. Status: **belum dikerjakan**. Diagram digambar setelah aplikasinya jadi, supaya isinya sesuai kode
sungguhan, bukan rencana.

## Aturan

- Setiap diagram diberi keterangan tepat di bawah gambarnya yang menyebut jenis diagramnya.
  Contoh: "Gambar 1. Use Case Diagram Voice-to-Todo".
- Diagram digambar dari kode yang sudah jadi. Kalau kode berubah, diagramnya ikut diperbarui.
- ID kebutuhan (KF-xx dan KNF-xx) sama dengan yang dipakai di laporan progres dan pengujian.
- Angka performa hanya diambil dari `docs/catatan-uji.md`, lengkap dengan HP dan tanggalnya.
- Keterbatasan aplikasi ditulis dengan jujur.

## Lima diagram

| No | Diagram | Bagian 4+1 View | Isi |
|---|---|---|---|
| 1 | Use Case Diagram | Scenario View | Pengguna: merekam, melihat hasil, mengelola to-do, melihat riwayat dan detail, coba lagi |
| 2 | Sequence Diagram | Scenario View | Proses satu rekaman: rekam, simpan file, ubah suara jadi teks, lepas model, rangkum, ubah frasa waktu jadi tanggal, simpan hasil |
| 3 | Class Diagram | Logical View | Data (Rekaman, Tugas) dan bagian program (Pemroses, Transkriptor, Peringkas, pengubah frasa waktu) |
| 4 | State Machine Diagram | Process View | Status rekaman: memproses, selesai, gagal (dengan kode galat), lalu coba lagi |
| 5 | Deployment Diagram | Physical View | Semua bagian berjalan di dalam iPhone tanpa server: aplikasi, model AI, penyimpanan, mikrofon |

Activity Diagram dan ERD tidak dipakai, kecuali dosen mewajibkannya.

## Kerangka isi

1. Tujuan dan batasan
2. Analisa kebutuhan
   - 2.1 Kebutuhan pengguna
   - 2.2 Kebutuhan fungsional (KF-01 sampai KF-08)
   - 2.3 Kebutuhan non-fungsional (KNF-01 sampai KNF-05)
3. Keputusan desain utama (offline, AI hanya menulis teks, rekaman tidak boleh hilang, XR sebagai patokan)
4. Pola arsitektur
5. Model 4+1 View
   - 5.1 Scenario View: Gambar 1 (Use Case) dan Gambar 2 (Sequence)
   - 5.2 Logical View: Gambar 3 (Class)
   - 5.3 Process View: Gambar 4 (State Machine)
   - 5.4 Development View: struktur folder `ios/` dan tumpukan teknologi
   - 5.5 Physical View: Gambar 5 (Deployment)
6. Keterlacakan kebutuhan ke komponen (tabel KF/KNF ke file atau bagian program)
7. Hasil uji dan keterbatasan

## Belum diputuskan

- Format akhir dokumen (Word, PDF, atau lainnya) dan alat untuk menggambar diagram.
- Apakah perlu bagian laporan wawancara pengguna seperti di contoh dokumen.
