# Model AI, library, dan aset pihak ketiga

Setiap file model, library, atau aset dari pihak lain dicatat di sini sebelum dipakai: nama, versi, ukuran, sumber,
dan lisensinya. File model AI tidak dimasukkan ke git.

## Model AI

Belum ada. Kandidat yang akan diuji di Fase 1:

| Kegunaan | Kandidat | Status |
|---|---|---|
| Transkripsi | WhisperKit `openai_whisper-base`, pembanding `openai_whisper-tiny` | belum diunduh, lisensi belum dicek |
| Ringkasan | Qwen3-1.7B, Gemma 3 1B (GGUF Q4_K_M) | belum diunduh, lisensi belum dicek |

## Library

Belum ada library pihak ketiga di aplikasi iPhone. Aplikasi saat ini hanya memakai framework bawaan Apple
(SwiftUI, AVFoundation, Speech, FoundationModels).

## Aset

| Nama | File | Versi | Ukuran | Sumber | Lisensi | Cara dicek |
|---|---|---|---|---|---|---|
| Inter (huruf) | `ios/VoiceToTodo/Resources/Inter-Variable.ttf` | 4.001 | 856 KiB | https://github.com/rsms/inter | SIL Open Font License 1.1 | Tabel `name` di dalam file font, dibaca 2026-11-11 |
