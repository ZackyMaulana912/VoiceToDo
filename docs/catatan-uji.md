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
