# Model AI, library, dan aset pihak ketiga

Setiap file model, library, atau aset dari pihak lain dicatat di sini sebelum dipakai: nama, versi, ukuran, sumber,
dan lisensinya. File model AI dan llama.cpp tidak dimasukkan ke git karena terlalu besar.

## Menyiapkan file sebelum build

Dijalankan sekali di Mac pengembang (butuh internet). Aplikasi sendiri tidak pernah mengunduh apa pun.

```sh
python3 ios/scripts/unduh-model.py          # model AI ke ios/VoiceToTodo/Model (sekitar 4,4 GB)
sh ios/scripts/siapkan-llama.sh             # llama.cpp rilis resmi (iPhone asli dan Mac)
sh ios/scripts/siapkan-llama.sh --simulator # atau: bangun sendiri, ditambah Simulator (butuh cmake)
```

Skrip unduhan mengunci setiap repositori ke satu commit dan mengecek SHA-256 setiap file besar. Tanpa model, build
tetap berhasil dengan peringatan, dan aplikasi menampilkan "File model AI tidak ditemukan" saat memproses.

## Model AI

Dipilih dari uji 2026-11-12 (lihat `docs/catatan-uji.md`, bagian Fase 1 dan Fase 5).

| Kegunaan | Model | Dipakai di | Ukuran | Sumber (commit) | Lisensi |
|---|---|---|---|---|---|
| Suara jadi teks | `openai_whisper-large-v3-v20240930_turbo_632MB` (Core ML) | iPhone 13 (A15) ke atas, termasuk 17 Pro | 646 MB | `argmaxinc/whisperkit-coreml` @ `0f63a780` | MIT |
| Suara jadi teks | `openai_whisper-base` (Core ML) | HP lebih lama, termasuk XR | 147 MB | `argmaxinc/whisperkit-coreml` @ `0f63a780` | MIT |
| Tokenizer Whisper | `openai/whisper-large-v3` (berkas tokenizer saja) | bersama model turbo | 4 MB | `openai/whisper-large-v3` @ `06f233fe` | Apache-2.0 |
| Tokenizer Whisper | `openai/whisper-base` (berkas tokenizer saja) | bersama model base | 4 MB | `openai/whisper-base` @ `e37978b9` | Apache-2.0 |
| Ringkasan | `Qwen3-4B-Instruct-2507-Q4_K_M.gguf` | HP dengan GPU yang didukung llama.cpp (A14 ke atas), termasuk 17 Pro | 2.497 MB, SHA-256 `3605803b…c4c67e597` | `unsloth/Qwen3-4B-Instruct-2507-GGUF` @ `a06e946b` | Apache-2.0 |
| Ringkasan | `Qwen3-1.7B-Q4_K_M.gguf` | HP tanpa GPU yang didukung (XR) dan Simulator | 1.107 MB, SHA-256 `b139949c…fa181897` | `unsloth/Qwen3-1.7B-GGUF` @ `d7f544ee` | Apache-2.0 |

Qwen3 secara resmi mendukung bahasa Indonesia (rumpun Austronesia di daftar bahasa blog resmi Qwen3, dibaca
2026-11-12).

Pembanding yang diuji tapi tidak dipakai: Gemma 3 1B (`ggml-org/gemma-3-1b-it-GGUF`, lisensi Gemma) menemukan jauh
lebih sedikit to-do pada data uji yang sama.

## Library

| Library | Versi | Kegunaan | Sumber | Lisensi |
|---|---|---|---|---|
| WhisperKit | 1.1.1 (dikunci tepat, lihat `Package.resolved`) | Menjalankan Whisper di HP | https://github.com/argmaxinc/WhisperKit | MIT |
| swift-argument-parser | 1.8.2 | Ikut diunduh sebagai dependensi paket WhisperKit; tidak masuk ke aplikasi | https://github.com/apple/swift-argument-parser | Apache-2.0 |
| llama.cpp | b12291 (XCFramework rilis resmi, SHA-256 `83eade80…a6de2289`) | Menjalankan model ringkasan di HP | https://github.com/ggml-org/llama.cpp | MIT |

Framework Apple yang dipakai: SwiftUI, AVFoundation, Core ML (lewat WhisperKit), Metal (lewat llama.cpp).
Pengenalan ucapan Apple (`Speech`) dan Apple Intelligence (`FoundationModels`) tidak lagi dipakai.

## Aset

| Nama | File | Versi | Ukuran | Sumber | Lisensi | Cara dicek |
|---|---|---|---|---|---|---|
| Inter (huruf) | `ios/VoiceToTodo/Resources/Inter-Variable.ttf` | 4.001 | 856 KiB | https://github.com/rsms/inter | SIL Open Font License 1.1 | Tabel `name` di dalam file font, dibaca 2026-11-11 |
