# Voice-to-Todo

Tugas mata kuliah RBPL. Rekam suara berbahasa Indonesia (rapat, kuliah, atau ide), lalu aplikasi membuat judul,
kategori, ringkasan, poin penting, dan daftar to-do bertenggat.

## Isi repo

| Folder / file | Isi |
|---|---|
| `ios/` | Aplikasi iPhone (Swift + SwiftUI). Lihat `ios/README.md` |
| `docs/` | Catatan uji, daftar model dan lisensi, dokumen SRS dan arsitektur (`docs/dokumen/`), serta diagram (`docs/diagram/`) |
| `src/`, `public/`, `index.html` | Purwarupa tampilan versi web (React + Vite + Tailwind), dibuat di Figma Make. Datanya masih contoh |
| `.figma/`, `AGENTS.md`, `vite.config.ts` | File bawaan Figma Make. Jangan dipindah, supaya proyek tetap bisa disinkronkan dengan Figma Make |

## Menjalankan

**Aplikasi iPhone:** jalankan dulu `python3 ios/scripts/unduh-model.py` dan `sh ios/scripts/siapkan-llama.sh`
(model AI dan llama.cpp tidak ikut git), lalu buka `ios/VoiceToTodo.xcodeproj` di Xcode, pilih Team Apple ID di tab
*Signing & Capabilities*, dan jalankan di iPhone sungguhan. Rincian di `ios/README.md`.

**Purwarupa web:** butuh Node 22 dan pnpm (lihat `.mise.toml`).

```
pnpm install
pnpm dev
```
