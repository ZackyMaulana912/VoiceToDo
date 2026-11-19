# Catatan uji versi web

Hasil pemeriksaan kode web (repo `voice-to-todo`, commit `5116f11`) yang dijalankan pada 19 November 2026 di
salinan terpisah, tanpa mengubah kode rekan tim. Semua uji memakai AI tiruan (mock), jadi tidak ada audio yang
dikirim ke Groq dan tidak ada kuota yang terpakai.

## 1. Lingkungan

| Hal | Nilai |
|---|---|
| Komputer | Mac, macOS 27.2 |
| Node.js | 22.23.4 (Vitest 5.1 butuh Node 22 ke atas; di Node 20 gagal menyalakan worker) |
| Next.js | 16.4.6 |
| Browser uji | Chromium headless bawaan Playwright 1.65.0, layar 390 x 844 |
| Server uji | `next dev` hanya di `127.0.0.1:3107`, dimatikan setelah uji selesai |

## 2. Pemeriksaan kode dan build

| Pemeriksaan | Perintah | Hasil |
|---|---|---|
| Lint | `npm run lint` | v lolos, tanpa peringatan |
| Tipe TypeScript | `npx next typegen` lalu `npx tsc --noEmit` | v lolos |
| Build produksi | `npx next build` | v berhasil, `/api/process` jadi fungsi server dan halaman lain statis |

`next typegen` perlu dijalankan dulu. Tanpa itu, `tsc` mengeluh `LayoutProps` dan `PageProps` tidak ditemukan
karena tipe rute Next.js belum dibuat.
