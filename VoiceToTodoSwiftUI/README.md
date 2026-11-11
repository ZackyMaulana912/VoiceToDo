# Voice-to-Todo for iOS

Aplikasi SwiftUI: rekam suara, ubah jadi teks, rangkum, dan hasilkan daftar to-do.

## Menjalankan

1. Buka `VoiceToTodo.xcodeproj` di Xcode 15 atau lebih baru (aplikasi mendukung iOS 16+, termasuk iPhone XR).
2. Pilih target **VoiceToTodo**, tab *Signing & Capabilities*, pilih Team Apple ID kamu.
3. Jalankan di **iPhone sungguhan** (mikrofon dan pengenalan ucapan tidak bisa diandalkan di Simulator).
4. Izinkan akses Mikrofon dan Pengenalan Ucapan saat diminta.

## Cara kerja

- **Merekam**: `AVAudioEngine` merekam ke file `.caf` di Documents/Recordings sambil mengirim audio ke `SFSpeechRecognizer` (Bahasa Indonesia, `id-ID`). Bila perangkat mendukung, pengenalan berjalan sepenuhnya di perangkat.
- **Merangkum**:
  - iOS 26 + Apple Intelligence + Xcode 26: model bahasa bawaan Apple (`FoundationModelSummarizer.swift`).
  - Selain itu: peringkas lokal berbasis aturan (`Summarizer.swift`) yang mendeteksi kategori, kalimat tugas, dan tenggat (Jumat, besok, minggu depan, dst.).
- **Gagal**: transkrip kosong/terlalu pendek -> kartu "Gagal memproses". Audio tetap tersimpan, **Coba lagi** mentranskripsi ulang dari file.
- **Penyimpanan**: to-do dan riwayat disimpan di `voice-to-todo.json` (Documents), jadi tetap ada setelah aplikasi ditutup. Aplikasi mulai dalam keadaan kosong.
