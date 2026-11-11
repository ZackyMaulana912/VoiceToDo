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

### Belum dicek (butuh HP dan Apple ID)

| Hal | iPhone XR | iPhone 17 Pro |
|---|---|---|
| Identifier model | | |
| Versi iOS | | |
| Ruang kosong | | |
| Developer Mode aktif | | |
| Aplikasi bisa dipasang dari Xcode dan dibuka | | |
