# Dokumen Spesifikasi dan Arsitektur Voice-to-Todo (versi web)

Mata kuliah RBPL. Versi 1.0, 17 November 2026.
Disusun dari kode repo `voice-to-todo` (commit `5116f11`, 15 November 2026) dan hasil uji yang dijalankan ulang pada
17 November 2026. Semua diagram digambar dari kode yang sudah jadi.

## 1. Tujuan dan batasan

Voice-to-Todo membantu mahasiswa dan panitia organisasi yang sering lupa tugas setelah rapat, kuliah, atau saat
mendapat ide. Pengguna cukup merekam suara berbahasa Indonesia paling lama 10 menit. Aplikasi lalu membuat judul,
kategori (Rapat, Kuliah, Ide), ringkasan, poin penting, dan daftar to-do lengkap dengan tenggatnya.

Versi web dibuka langsung dari browser HP di `https://voice-to-todo-nine.vercel.app`, tanpa pemasangan.

Batasan:

- Aplikasi web untuk layar HP (lebar maksimum 430 px), dibuat dengan Next.js dan React.
- Butuh internet setiap kali memproses rekaman, karena suara diubah jadi teks dan dirangkum oleh layanan AI di
  server (Groq).
- Mikrofon browser hanya bisa dipakai lewat HTTPS.
- Tanpa akun dan tanpa sinkronisasi: data hanya ada di browser tempat rekaman dibuat.
- Hanya bahasa Indonesia dan hanya tema terang.

## 2. Analisa kebutuhan

### 2.1 Kebutuhan pengguna

| Pengguna | Kebutuhan |
|---|---|
| Mahasiswa | Mencatat tugas dan tenggat yang disebut dosen tanpa menulis manual |
| Panitia atau anggota organisasi | Mengubah hasil rapat menjadi daftar tugas |
| Siapa pun dengan ide | Merekam ide secara cepat lalu mendapat ringkasan dan langkah berikutnya |
| Pengguna yang tidak mau memasang aplikasi | Cukup membuka alamat web di HP apa saja |

### 2.2 Kebutuhan fungsional

ID kebutuhan fungsional sama dengan dokumen versi iPhone, supaya kedua versi bisa dibandingkan.

| ID | Kebutuhan |
|---|---|
| KF-01 | Merekam suara sampai 10 menit, berhenti otomatis di batas itu |
| KF-02 | Menyimpan rekaman sebelum diproses; rekaman tidak hilang saat proses gagal |
| KF-03 | Mengubah suara berbahasa Indonesia menjadi teks (di server, lewat Groq) |
| KF-04 | Membuat judul, kategori, ringkasan, poin penting, dan to-do dari transkrip |
| KF-05 | Memberi tanggal tenggat dari frasa waktu ("besok", "Jumat") |
| KF-06 | Mencentang, mengubah, menambah, dan menghapus to-do; menghapus rekaman |
| KF-07 | Melihat riwayat rekaman, detail, dan transkrip lengkap; menyalin hasil |
| KF-08 | Memproses ulang rekaman yang gagal ("Coba lagi") |

KF-09 (edit transkrip dan ringkas ulang) hanya ada di versi iPhone.

### 2.3 Kebutuhan non-fungsional

| ID | Kebutuhan |
|---|---|
| KNF-W1 | Berjalan di browser HP modern (Safari di iPhone, Chrome di Android) lewat HTTPS, tanpa pemasangan |
| KNF-W2 | Data rekaman hanya tersimpan di browser; server tidak menyimpan audio atau transkrip; tanpa akun |
| KNF-W3 | Kunci API layanan AI hanya ada di server, tidak pernah dikirim ke browser |
| KNF-W4 | Memenuhi aksesibilitas WCAG 2.2 AA (kontras, area sentuh, label pembaca layar, navigasi keyboard) |
| KNF-W5 | Melindungi server dari pemakaian berlebih: audio maksimal 4 MB, 10 permintaan per 10 menit per alamat IP |
