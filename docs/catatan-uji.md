# Catatan uji

Hasil ukur dan uji per tanggal dan perangkat, termasuk yang gagal. Angka hanya ditulis dari hasil yang benar-benar
dijalankan.

## Fase 0: Inspeksi lingkungan

### 2026-11-11, Mac pengembang

| Hal | Hasil | Cara dicek |
|---|---|---|
| Xcode | 27.1 (build 27A9275) | `xcodebuild -version` |
| Swift | 6.4 | `swift --version` |
| Runtime Simulator iOS | belum ada yang terpasang | `xcrun simctl list runtimes` |
| Git LFS | 3.7.1 terpasang (dibutuhkan untuk file font `.ttf`) | `git lfs version` |
| Ruang disk Mac | 118 GB kosong | `df -h /` |
| Identitas signing (Apple ID di Xcode) | belum ada | `security find-identity -v -p codesigning` |
| HP tersambung ke Mac | belum ada | `xcrun devicectl list devices` |

### 2026-11-11, build aplikasi iPhone (tanpa signing, tujuan "Any iOS Device")

Perintah: `xcodebuild -project ios/VoiceToTodo.xcodeproj -scheme VoiceToTodo -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`

| Kondisi | Hasil |
|---|---|
| Kode apa adanya dari commit `bcb0762` | x GAGAL: `FoundationModelSummarizer.swift:38: cannot find type 'Date' in scope`. File itu belum `import Foundation`. Dugaan: di Xcode versi lama file ini dilewati (`#if canImport(FoundationModels)` bernilai salah), jadi errornya tidak muncul |
| Setelah menambah `import Foundation` | v BERHASIL. Hanya dibuktikan bisa dikompilasi; belum dipasang atau dijalankan di HP |

Bundle ID diganti dari `com.example.VoiceToTodo` ke `com.zackymaulana912.voicetodo` (dicek di `Info.plist` hasil
build). Target minimum di proyek masih iOS 16.0.

### 2026-11-11, pemasangan ke HP

Signing memakai akun Apple gratis (Personal Team) milik user. Data HP dibaca dengan
`xcrun devicectl device info details`.

| Hal | iPhone XR | iPhone 17 Pro |
|---|---|---|
| Identifier model | belum diuji | `iPhone18,1` |
| Versi iOS | belum diuji | 27.3 (build 24C5037i) |
| Kapasitas penyimpanan | belum diuji | 256 GB (ruang kosong belum dicatat) |
| Developer Mode | belum diuji | aktif |
| Aplikasi bisa dipasang dari Xcode | belum diuji | v berhasil (`xcodebuild -allowProvisioningUpdates`, lalu `devicectl device install app`) |
| Aplikasi bisa dibuka | belum diuji | v berjalan, prosesnya masih hidup 3 detik setelah dibuka. Hanya dibuka, fitur belum dicoba |

Yang terjadi selama pemasangan di 17 Pro:

- Percobaan pertama membuka aplikasi ditolak iPhone ("Untrusted Developer"). Ini perilaku normal untuk akun gratis:
  profil developer harus dipercayai dulu lewat Settings > General > VPN & Device Management. Langkah ini butuh
  internet, cukup sekali.
- Awalnya aplikasi belum punya ikon (katalog aset tidak berisi `AppIcon`). Ikon kemudian dibuat sendiri dengan format
  Icon Composer (`ios/VoiceToTodo/AppIcon.icon`): mikrofon dan centang di atas latar ungu aksen.
  Isi `Assets.car` hasil build (dibaca dengan `xcrun assetutil --info`) berisi versi terang, gelap, dan tinted, ditambah
  lapisan Liquid Glass. Xcode juga membuat gambar biasa `AppIcon60x60@2x.png` untuk iOS versi lama. Ikon sudah terpasang
  di 17 Pro. Tampilannya di iOS 17 (XR) belum dilihat langsung.
- Begitu Team dipilih di Xcode, file proyek berubah: `DEVELOPMENT_TEAM` terisi ID team user, dan Xcode mengurutkan
  ulang isi `project.pbxproj` dan `Info.plist` tanpa mengubah isinya (dibuktikan dengan membandingkan isi yang sudah
  diurutkan).

XR dijadwalkan diuji saat dipinjam (lihat jadwal uji XR).

## Perbaikan bug kritis dari audit

### 2026-11-11, bug 1: tombol "Tutup" menghapus rekaman

- Masalah: kalau aplikasi gagal mulai merekam lalu pengguna menekan "Tutup", `SpeechRecorder.cancel()` menghapus file
  berdasarkan nama file rekaman sebelumnya. Kalau belum pernah merekam sejak aplikasi dibuka, namanya kosong, dan
  `removeItem(folder.appendingPathComponent(""))` menghapus seluruh folder `Recordings`. Ini dibuktikan di Mac dengan
  kode yang sama: folder berisi 2 file ikut terhapus.
- Perbaikan: nama file dikosongkan di awal `start()`, dan `cancel()` hanya menghapus kalau namanya tidak kosong.
- Uji: build berhasil dan aplikasi terpasang di 17 Pro. Skenario gagal merekam belum dicoba langsung di HP, karena
  butuh kondisi yang membuat perekaman gagal dimulai (misalnya mikrofon sedang dipakai aplikasi lain).

### 2026-11-11, bug 2: data hilang setelah update

- Masalah: kalau `voice-to-todo.json` gagal dibaca (misalnya bentuk data berubah setelah update), `AppStore.load()`
  diam-diam mulai kosong, lalu penyimpanan berikutnya menimpa data lama. Dibuktikan di Mac: data tanpa kolom baru
  gagal dibaca (`keyNotFound`), walaupun kolom itu punya nilai bawaan di kode.
- Perbaikan: file yang gagal dibaca dipindah ke `voice-to-todo-cadangan-<waktu>.json`, lalu muncul pesan
  "Data lama tidak terbaca". Kalau pemindahan gagal, aplikasi berhenti menyimpan supaya data lama tidak tertimpa.
- Uji di iPhone 17 Pro (iOS 27.3), memakai `devicectl` untuk menyalin file data. Data asli user (2 to-do, 4 rekaman)
  dicadangkan ke Mac dulu, lalu dikembalikan setelah uji:

| Uji | Hasil |
|---|---|
| A. Data normal setelah update aplikasi | v terbaca seperti biasa, tidak ada file cadangan yang terbuat |
| B. Data tanpa kolom `summary` di satu rekaman | v file dipindah ke `voice-to-todo-cadangan-1794407516.json`, isinya sama persis (md5 cocok), dan pesan muncul di layar (dilihat user) |
| Pemulihan data asli | v md5 file di HP sama dengan cadangan; 4 file audio tetap ada |

File cadangan hasil uji B (2 KB) tertinggal di HP, karena `devicectl` tidak bisa menghapus file di dalam aplikasi.

## Uji yang menunggu HP

Keputusan user 2026-11-12: uji di HP dikumpulkan di akhir. Perubahan di bawah sudah dibuktikan lewat kode (build
berhasil untuk iOS, target minimum di proyek 16.0), tetapi **belum diuji di HP**. Hasilnya diisi saat diuji.

| Perubahan | Cara uji di 17 Pro | Hasil |
|---|---|---|
| Konfirmasi sebelum membuang rekaman | Rekam, tekan Batal: muncul "Buang rekaman ini?". "Lanjut merekam" tetap merekam; "Buang rekaman" kembali ke beranda | belum diuji |
| Tanda "Menyimpan rekaman…" | Rekam, tekan Selesai: tulisan muncul sebentar dan tombol tidak bisa ditekan | belum diuji |
| "Coba lagi" untuk transkrip 1-2 kata | Rekam satu atau dua kata sampai gagal, tekan Coba lagi: aplikasi mendengarkan ulang file audio | belum diuji |
| Rekaman terputus: layar dikunci | Rekam 20 detik, tekan tombol kunci, buka lagi: muncul "Rekaman dihentikan", rekaman 0:20-an tersimpan dan diproses, keterangan tampil di detail | belum diuji |
| Rekaman terputus: aplikasi ditinggalkan | Sama, tetapi geser ke layar utama | belum diuji |
| Rekaman terputus: telepon masuk | Minta orang menelepon saat merekam | belum diuji |
| Rekaman terputus: earphone | Cabut atau sambungkan earphone/AirPods saat merekam | belum diuji |
| Bug 1: Tutup tidak menghapus rekaman lama | Putar musik/telepon yang memakai mikrofon, lalu mulai merekam sampai gagal, tekan Tutup: rekaman lama di Riwayat tetap ada | belum diuji |
| To-do tidak dobel di Beranda | Selesaikan satu rekaman: to-do hanya tampil di kartu hasil. Pindah ke Riwayat lalu kembali: to-do muncul di daftar | belum diuji |
| Edit ringkasan dengan Batal dan Simpan | Tekan Edit, ubah teks, tekan Batal: teks kembali seperti semula. Ubah lagi, tekan Simpan: tersimpan. Kosongkan teks: Simpan tidak bisa ditekan | belum diuji |
| Pesan gagal sesuai penyebab | Rekam diam saja: "Tidak ada suara yang terdengar…". Rekam satu-dua kata: "…terlalu pendek…". Tutup paksa aplikasi saat memproses lalu buka lagi: "Proses terhenti…" | belum diuji |

Sudah dibuktikan di Mac (2026-11-12, kode `Models.swift` asli dikompilasi untuk macOS): rekaman lama tanpa kolom
keterangan baru (`stopNote`) tetap terbaca, dan keterangan tersimpan lalu terbaca kembali dengan benar.

### 2026-11-12, uji logika penyimpanan dan pesan gagal di Mac

`AppStore.swift`, `Models.swift`, dan `DesignTokens.swift` asli dikompilasi untuk macOS. Pengenal ucapan dan peringkas
diganti tiruan supaya setiap jenis kegagalan bisa dipicu. Folder data diarahkan ke scratchpad (bukan Documents milik
user) dan dihapus setelah uji. Hasil: 13 dari 13 lolos.

| Uji | Hasil |
|---|---|
| Data lama tanpa kolom baru (`stopNote`, `failReason`) terbaca, tanpa pesan masalah | v |
| Rekaman yang masih "memproses" saat aplikasi dibuka jadi gagal dengan kode `terganggu` | v |
| File audio tidak ada: `tanpa-audio`, tombol Coba lagi disembunyikan | v |
| Pengenal ucapan tidak tersedia: `pengenal-tidak-tersedia` | v |
| Tidak ada suara: `tidak-terdengar` | v |
| 1-2 kata: `terlalu-pendek`, transkrip diambil dari hasil dengar ulang file audio | v |
| Coba lagi berhasil: status selesai dan kode gagal dihapus | v |
| Data tersimpan terbaca ulang saat aplikasi dibuka lagi | v |
| Folder data tidak bisa ditulisi: muncul pesan "Gagal menyimpan" | v |
| Gagal berturut-turut: pesan tidak muncul berulang | v |
| Penyimpanan pulih lalu gagal lagi: pesan muncul lagi | v |

Keterbatasan: penyebab teknis di akhir pesan "Gagal menyimpan" berbahasa Inggris di Mac. Di iPhone berbahasa
Indonesia diduga ikut bahasa HP, belum dilihat.
