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

## 2. Cara AI bekerja

| Hal | iPhone | Web |
|---|---|---|
| Suara jadi teks | WhisperKit di HP (turbo untuk A15 ke atas, base untuk XR) | Groq whisper-large-v3 |
| Ringkasan dan to-do | Qwen3 di HP lewat llama.cpp (4B, atau 1.7B bila memori kurang) | Groq gpt-oss-120b |
| Bentuk keluaran | Dipaksa grammar JSON, lalu divalidasi kode | JSON ketat, divalidasi zod di server dan di browser |
| Tanggal tenggat | AI hanya menyalin frasa waktu ("Jumat", "besok"), kode yang menghitung tanggalnya | AI memilih tanggal dari tabel kalender 15 hari yang diberikan server |
| "Minggu depan" | Tanpa tenggat, frasanya disimpan | Bisa diberi tanggal oleh AI |
| Kecepatan | Bergantung HP; belum diukur di HP sungguhan | Bergantung jaringan dan antrean Groq |

Di kedua versi, tanggal sebelum hari rekaman atau lebih dari 366 hari setelahnya dibuang, dan to-do-nya tetap ada.

## 3. Fitur yang berbeda

| Fitur | iPhone | Web |
|---|---|---|
| Rekam sampai 10 menit, berhenti otomatis | v | v |
| Rekaman disimpan sebelum diproses, bisa Coba lagi | v | v |
| Centang, ubah, tambah, dan hapus to-do | v | v |
| Riwayat, detail, dan transkrip lengkap | v | v |
| Salin hasil sebagai teks | v | v |
| Edit transkrip dan lihat transkrip asli hasil AI (KF-09) | v | x |
| Ringkas ulang dari transkrip yang sudah diedit (KF-09) | v | x |
| Urungkan setelah menghapus | v | x (hapus langsung permanen) |
| Format audio | WAV 16 kHz mono | WebM atau MP4, 32 kbps, maksimal 4 MB |
| Batas pemakaian | Tidak ada | 10 permintaan per 10 menit per alamat |

## 4. Pemasangan dan biaya

| Hal | iPhone | Web |
|---|---|---|
| Cara pasang | Lewat Xcode dari Mac, kabel ke HP | Buka alamat web lewat HTTPS |
| Masa berlaku | 7 hari (akun developer gratis), lalu pasang ulang | Tidak ada |
| HP yang didukung | iPhone XR (iOS 17) sampai iPhone 17 Pro | HP apa pun dengan browser modern dan mikrofon |
| Ukuran aplikasi | Besar, karena model AI ikut di dalam aplikasi | Kecil, model ada di server |
| Biaya berjalan | Tidak ada | Kuota API Groq per rekaman, ditambah hosting Vercel |
| Kualitas ringkasan | Dibatasi model kecil di HP | Lebih baik, model besar di server |

**Kapan pakai yang mana.** Versi iPhone cocok untuk rekaman yang tidak boleh keluar dari HP, atau saat tidak ada
sinyal. Versi web cocok untuk dipakai banyak orang tanpa pemasangan, selama ada internet dan rekamannya boleh dikirim
ke penyedia AI.
