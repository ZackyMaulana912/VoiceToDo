# Dokumen versi web

Folder ini berisi dokumen Fase 8 untuk versi web Voice-to-Todo. Kodenya ada di repo terpisah `voice-to-todo`
milik rekan tim dan tidak diubah dari sini.

| File | Isi |
|---|---|
| `Dokumen-Voice-to-Todo-Web.md` | Spesifikasi dan arsitektur versi web (sumber) |
| `Dokumen-Voice-to-Todo-Web.docx` | Versi Word dari file di atas |
| `catatan-uji-web.md` | Hasil lint, tipe, build, Vitest, dan Playwright, serta yang belum diuji |
| `diagram/` | Lima diagram 4+1 View versi web beserta sumbernya |

Versi Word dibuat ulang setelah file `.md` berubah:

```sh
python3 docs/dokumen/buat-docx.py docs/web/Dokumen-Voice-to-Todo-Web.md
```
