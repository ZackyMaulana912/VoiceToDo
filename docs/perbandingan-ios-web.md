# Perbandingan Voice-to-Todo versi iPhone dan versi web

Ringkasan perbedaan kedua versi untuk bahan presentasi. Versi iPhone diambil dari repo ini (`ios/`), versi web dari
repo `voice-to-todo` commit `5116f11`. Per 19 November 2026.

## 1. Internet dan privasi

| Hal | iPhone | Web |
|---|---|---|
| Internet | Tidak perlu sama sekali, termasuk saat memproses | Wajib setiap kali memproses rekaman |
| Tempat suara diproses | Di HP | Di server Groq (pihak ketiga) lewat Vercel |
| Yang keluar dari HP | Tidak ada | Audio rekaman, lalu transkripnya untuk diringkas |
| Tempat data disimpan | File di HP (JSON dan audio WAV) | IndexedDB di browser yang dipakai |
| Akun | Tidak ada | Tidak ada |

Kedua versi sama-sama tidak punya akun dan tidak menyinkronkan data. Bedanya, data web hanya ada di satu browser:
kalau data situs dihapus atau pindah browser, rekamannya tidak ikut.
