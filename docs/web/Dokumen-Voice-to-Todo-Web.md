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

## 3. Keputusan desain utama

| Keputusan | Alasan |
|---|---|
| AI berjalan di server lewat Groq: `whisper-large-v3` untuk suara dan `openai/gpt-oss-120b` untuk ringkasan | Kualitas model besar tanpa membebani HP; Groq punya tier gratis |
| Penyedia AI bisa diganti lewat variabel lingkungan (Groq, Claude, OpenAI, atau tiruan) | Bisa pindah penyedia tanpa mengubah kode; versi tiruan dipakai untuk uji |
| Rekaman dan audionya ditulis ke IndexedDB dalam satu transaksi sebelum dikirim | Rekaman tidak hilang walau internet putus atau server gagal (KF-02) |
| Keluaran AI dipaksa berbentuk JSON ketat, lalu divalidasi zod di server dan sekali lagi di browser; coba ulang sekali | Hasil rusak tidak masuk ke data |
| AI memilih tanggal tenggat dari tabel 15 hari yang disiapkan kode; tanggal sebelum hari rekaman atau lebih dari 366 hari dibuang | Model tidak perlu berhitung sendiri, dan tanggal yang mustahil tidak tersimpan |
| Server tidak menyimpan apa pun dan log hanya berisi kode galat, ukuran, dan durasi | Privasi (KNF-W2) |
| Batas audio 4 MB dan rekaman 32 kbps | Batas badan permintaan Vercel 4,5 MB; rekaman 10 menit sekitar 2,4 MB |
| Setiap kegagalan punya kode galat dan keterangan di layar | Tidak gagal diam-diam |

## 4. Pola arsitektur

Aplikasi memakai pola klien dan server dengan lapisan berikut:

1. **Tampilan** (React, komponen dari Figma): Beranda, Perekam, Riwayat, Detail. Tampilan membaca data langsung dari
   IndexedDB lewat `useLiveQuery`, sehingga otomatis berubah saat data berubah.
2. **Data di browser** (`lib/repo.ts`, Dexie): satu-satunya tempat menulis ke IndexedDB, berisi tiga tabel: rekaman,
   tugas, dan audio.
3. **Pemroses di browser** (`lib/proses.ts`): mengambil audio yang tersimpan, mengirimnya ke server, memvalidasi
   jawaban, lalu menyimpan hasil atau kode galat.
4. **Server** (`app/api/process`, `server/`): memeriksa permintaan, memanggil penyedia transkripsi dan ringkasan
   lewat antarmuka `Transkriptor` dan `Peringkas`, lalu mengembalikan hasil tanpa menyimpannya.

## 5. Model 4+1 View

### 5.1 Scenario View

Pengguna memakai aplikasi lewat browser HP. Merekam dan Coba lagi melibatkan layanan AI di server.

![Use Case Diagram](diagram/1-use-case.png)

Gambar 1. Use Case Diagram Voice-to-Todo versi web

Urutan proses satu rekaman, dari tombol Selesai sampai hasil tampil:

![Sequence Diagram](diagram/2-sequence.png)

Gambar 2. Sequence Diagram proses satu rekaman Voice-to-Todo versi web

### 5.2 Logical View

Kode web memakai tipe dan fungsi TypeScript, bukan class. Modul digambar sebagai kelas dengan stereotip «modul».

![Class Diagram](diagram/3-class.png)

Gambar 3. Class Diagram Voice-to-Todo versi web

### 5.3 Process View

Status rekaman dari menekan tombol rekam sampai selesai, gagal, atau dihapus:

![State Machine Diagram](diagram/4-state.png)

Gambar 4. State Machine Diagram status rekaman Voice-to-Todo versi web

### 5.4 Development View

| Folder | Isi |
|---|---|
| `app/` | Halaman (`/`, `/riwayat`, `/riwayat/[id]`) dan `api/process` |
| `components/ui/` | Komponen dari frame Komponen di Figma |
| `components/fitur/` | Layar: Beranda, Perekam, Riwayat, DetailRekaman |
| `lib/` | IndexedDB (db, repo), perekaman, format waktu, pemrosesan di browser |
| `server/` | Transkripsi, ringkasan, tabel tanggal, pembatas permintaan |
| `e2e/` | Uji Playwright (layar 390x844) dan tangkapan layar |
| `docs/design-gaps.md` | Celah desain dan keputusan yang diambil |

| Teknologi | Versi |
|---|---|
| Next.js | 16.4.6 |
| React | 19.3.0 |
| TypeScript | 5.9.3 |
| Tailwind CSS | 4.3.3 |
| Dexie (IndexedDB) | 4.4.7 |
| zod | 4.6.7 |
| Model suara | Groq `whisper-large-v3` |
| Model ringkasan | Groq `openai/gpt-oss-120b` (cadangan: Claude `claude-haiku-5-5`) |
| Uji | Vitest 5.1.0, Playwright 1.65.0, axe-core 4.14.0 |

### 5.5 Physical View

HP hanya menjalankan halaman dan menyimpan data. Pemrosesan AI terjadi di server Vercel dan Groq.

![Deployment Diagram](diagram/5-deployment.png)

Gambar 5. Deployment Diagram Voice-to-Todo versi web
