# Dokumen Spesifikasi dan Arsitektur Voice-to-Todo (iPhone, offline)

Mata kuliah RBPL. Versi 1.1, 16 November 2026 (versi 1.0: 12 November 2026; versi 1.1 menambah edit transkrip).
Disusun dari kode di folder `ios/` dan hasil uji di `docs/catatan-uji.md`. Semua diagram digambar dari kode yang sudah jadi.

## 1. Tujuan dan batasan

Voice-to-Todo membantu mahasiswa dan panitia organisasi yang sering lupa tugas setelah rapat, kuliah, atau saat
mendapat ide. Pengguna cukup merekam suara berbahasa Indonesia paling lama 10 menit. Aplikasi lalu membuat judul,
kategori (Rapat, Kuliah, Ide), ringkasan, poin penting, dan daftar to-do lengkap dengan tenggatnya.

Batasan:

- Aplikasi iPhone (iOS 17 ke atas) dengan Swift dan SwiftUI. Diuji di iPhone 17 Pro; iPhone XR menjadi patokan HP
  terendah.
- Seluruh proses berjalan di HP tanpa internet: tidak ada server, akun, atau sinkronisasi.
- Dipasang lewat Xcode dengan akun Apple gratis, sehingga aplikasi kedaluwarsa 7 hari setelah dipasang.
- Hanya bahasa Indonesia dan hanya tema terang.

## 2. Analisa kebutuhan

### 2.1 Kebutuhan pengguna

| Pengguna | Kebutuhan |
|---|---|
| Mahasiswa | Mencatat tugas dan tenggat yang disebut dosen tanpa menulis manual |
| Panitia atau anggota organisasi | Mengubah hasil rapat menjadi daftar tugas per orang |
| Siapa pun dengan ide | Merekam ide secara cepat lalu mendapat ringkasan dan langkah berikutnya |
| Pengguna yang peduli privasi | Suara dan isi rekaman tidak keluar dari HP |

### 2.2 Kebutuhan fungsional

| ID | Kebutuhan |
|---|---|
| KF-01 | Merekam suara sampai 10 menit, berhenti otomatis di batas itu |
| KF-02 | Menyimpan rekaman sebelum diproses; rekaman tidak hilang saat proses gagal |
| KF-03 | Mengubah suara berbahasa Indonesia menjadi teks di HP |
| KF-04 | Membuat judul, kategori, ringkasan, poin penting, dan to-do dari transkrip |
| KF-05 | Mengubah frasa waktu ("besok", "Jumat", "tanggal 20") menjadi tanggal tenggat |
| KF-06 | Mencentang, mengubah, menambah, dan menghapus to-do; menghapus rekaman |
| KF-07 | Melihat riwayat rekaman, detail, dan transkrip lengkap |
| KF-08 | Memproses ulang rekaman yang gagal ("Coba lagi") |
| KF-09 | Mengedit transkrip, melihat transkrip asli hasil AI, dan meringkas ulang dari transkrip yang sudah diedit |

### 2.3 Kebutuhan non-fungsional

| ID | Kebutuhan |
|---|---|
| KNF-01 | Berjalan tanpa internet sama sekali |
| KNF-02 | Berjalan di iPhone XR (iOS 17) sampai iPhone 17 Pro (iOS 27) |
| KNF-03 | Memenuhi angka target waktu, memori, suhu, dan kualitas |
| KNF-04 | Data hanya tersimpan di HP; tidak ada akun |
| KNF-05 | Bisa dipakai dengan VoiceOver dan ukuran teks besar (Dynamic Type) |

## 3. Keputusan desain utama

| Keputusan | Alasan |
|---|---|
| Semua AI berjalan di HP (WhisperKit untuk suara, llama.cpp untuk ringkasan) | Privasi dan tanpa biaya server (KNF-01, KNF-04) |
| AI hanya menulis teks; kode yang memutuskan tanggal, batas panjang, dan bentuk data | Model kecil tidak andal menghitung tanggal atau menjaga format |
| Keluaran model dipaksa berbentuk JSON dengan grammar, lalu divalidasi kode; coba ulang sekali sebelum gagal | Mencegah hasil rusak masuk ke data |
| Rekaman disimpan sebagai file WAV sebelum diproses; rekaman yang tertinggal karena aplikasi mati dipulihkan | Rekaman tidak boleh hilang (KF-02) |
| Model suara dan ringkasan dimuat bergantian, tidak pernah bersamaan | Supaya muat di memori 3 GB milik XR |
| Model dipilih menurut kemampuan HP: Whisper large-v3 turbo dan Qwen3-4B di 17 Pro, Whisper base dan Qwen3-1.7B di XR | Kualitas terbaik di HP baru tanpa membuat HP lama kehabisan memori |
| Transkrip panjang diringkas per bagian 250 kata | Model kecil melewatkan banyak tugas pada teks panjang |
| Transkrip yang diedit pengguna dipakai apa adanya saat Ringkas ulang atau Coba lagi; hasil asli AI tetap disimpan | Kata yang salah dengar bisa dibetulkan tanpa mengulang transkripsi, dan editan tidak tertimpa hasil AI (KF-09) |
| Setiap kegagalan punya kode galat dan pesan yang tampil di layar | Tidak gagal diam-diam |

## 4. Pola arsitektur

Aplikasi memakai pola satu sumber data (*single store*) dengan lapisan berikut:

1. **Tampilan** (SwiftUI): Beranda, Perekam, Riwayat, Detail, serta lembar isian to-do dan transkrip. Tampilan hanya membaca data dan
   meneruskan aksi pengguna.
2. **AppStore**: satu-satunya pemilik data rekaman dan to-do. Mengatur antrean proses (satu rekaman sekali jalan),
   Urungkan, dan penyimpanan ke file JSON.
3. **Layanan**: `SpeechRecorder` (mikrofon ke WAV), `WhisperTranscriber` (suara ke teks), `LlamaSummarizer` (teks ke
   ringkasan dan to-do). Pengenal suara dan peringkas dipakai lewat antarmuka (`Transcriber`, `Summarizer`), sehingga
   bisa diganti versi tiruan saat pengujian.
4. **Inti** (paket `VoiceToTodoCore`): logika murni yang tidak bergantung pada iPhone, yaitu frasa waktu menjadi
   tanggal, validasi keluaran AI, dan pemecahan transkrip. Bagian ini diuji dengan unit test di Mac.

## 5. Model 4+1 View

### 5.1 Scenario View

Pengguna berinteraksi langsung dengan aplikasi. Merekam, Coba lagi, dan Ringkas ulang selalu memicu pemrosesan rekaman. Ringkas ulang memakai transkrip yang sudah
diedit, jadi tahap suara jadi teks dilewati.

![Use Case Diagram](../diagram/1-use-case.png)

Gambar 1. Use Case Diagram Voice-to-Todo

Urutan proses satu rekaman, dari tombol Selesai sampai hasil tampil:

![Sequence Diagram](../diagram/2-sequence.png)

Gambar 2. Sequence Diagram proses satu rekaman Voice-to-Todo

### 5.2 Logical View

![Class Diagram](../diagram/3-class.png)

Gambar 3. Class Diagram Voice-to-Todo

### 5.3 Process View

Status rekaman dari mulai direkam sampai selesai, gagal, atau dihapus. Rekaman yang sudah selesai bisa kembali ke
Memproses lewat Ringkas ulang setelah transkripnya diedit:

![State Machine Diagram](../diagram/4-state.png)

Gambar 4. State Machine Diagram status rekaman Voice-to-Todo

### 5.4 Development View

| Folder | Isi |
|---|---|
| `ios/VoiceToTodo/Views` | Tampilan SwiftUI |
| `ios/VoiceToTodo/Services` | AppStore, perekam, pengenal suara, peringkas |
| `ios/VoiceToTodo/Models` | Data rekaman, to-do, kode galat |
| `ios/Packages/VoiceToTodoCore` | Logika inti dan unit test-nya |
| `ios/Packages/LlamaFramework` | Pembungkus llama.cpp (XCFramework tidak ikut git) |
| `ios/VoiceToTodoUITests` | Uji UI otomatis (Simulator) |
| `ios/UjiLogika` | Uji regresi logika aplikasi di Mac |
| `ios/UjiKelayakan` | Data uji sintetis dan kunci jawabannya |
| `ios/scripts` | Pengunduh model dan penyiap llama.cpp |

| Teknologi | Versi |
|---|---|
| Swift, SwiftUI | Swift 6.4 (mode bahasa 5), Xcode 27.1 |
| WhisperKit | 1.1.1 |
| llama.cpp | b12291 |
| Model suara | Whisper large-v3 turbo (632 MB), Whisper base (147 MB) |
| Model ringkasan | Qwen3-4B-Instruct-2507 Q4_K_M (2,5 GB), Qwen3-1.7B Q4_K_M (1,1 GB) |

### 5.5 Physical View

Semua bagian berjalan di dalam iPhone. Mac pengembang hanya dipakai saat memasang aplikasi.

![Deployment Diagram](../diagram/5-deployment.png)

Gambar 5. Deployment Diagram Voice-to-Todo

## 6. Keterlacakan kebutuhan

| ID | Komponen | Bukti uji |
|---|---|---|
| KF-01 | `SpeechRecorder`, `RecordingView` | Uji konversi audio di Mac; perekaman di HP menunggu |
| KF-02 | `AppStore.finishRecording`, `recoverOrphanAudio`, tempat sampah Urungkan | Uji regresi Mac (72 uji) |
| KF-03 | `WhisperTranscriber` | WER 5% (turbo, Mac, audio sintetis) |
| KF-04 | `LlamaSummarizer`, `Ringkasan` | 15/17 to-do (Qwen3-4B, Mac, audio sintetis) |
| KF-05 | `FrasaWaktu`, `LabelTenggat` | 22 unit test |
| KF-06 | `AppStore` (toggle, edit, tambah, hapus, Urungkan), lembar isian | Uji regresi Mac dan uji UI Simulator |
| KF-07 | `HistoryView`, `DetailView` | Uji UI Simulator |
| KF-08 | `AppStore.retry`, kartu gagal | Uji regresi Mac dan uji UI Simulator |
| KF-09 | `AppStore.editTranscript`, `AppStore.resummarize`, lembar edit transkrip dan transkrip asli | Uji regresi Mac (20 uji) dan uji UI Simulator |
| KNF-01 | Model di dalam aplikasi, `download: false` | Transkripsi berhasil dengan jaringan diblokir |
| KNF-02 | Pemilihan model per HP, target iOS 17 | Build iOS 17 berhasil; uji di XR menunggu |
| KNF-03 | Pemecahan per bagian, model dilepas bergantian | Kualitas di Mac; waktu dan memori di HP menunggu |
| KNF-04 | JSON dan WAV di Documents | Tidak ada kode jaringan atau akun |
| KNF-05 | Huruf mengikuti Dynamic Type, label VoiceOver, Kurangi gerakan | Tangkapan layar Simulator ukuran XL dan Aksesibilitas L |

## 7. Hasil uji dan keterbatasan

Rincian lengkap ada di `docs/catatan-uji.md`. Ringkasnya:

- Logika aplikasi: 39 unit test inti dan 72 uji regresi lolos di Mac.
- Uji UI otomatis di Simulator lolos: alur to-do (tambah, centang, edit, hapus, Urungkan), proses AI sungguhan dari
  rekaman sampai to-do muncul lalu rekaman dihapus dan diurungkan, ukuran huruf besar, serta edit transkrip (edit,
  lihat transkrip asli, kembalikan ke asli, Urungkan).
- Rangkaian AI lengkap berjalan di dalam aplikasi (Simulator) untuk lima rekaman uji tanpa kegagalan.
- Kualitas di Mac dengan audio sintetis: Whisper turbo WER 5%; Qwen3-4B menemukan 15 dari 17 to-do dengan 0,2
  to-do karangan per rekaman.

Keterbatasan yang jujur:

- **Belum diukur di HP sungguhan**: waktu proses rekaman 10 menit, memori, suhu, dan perekaman suara. Ukuran
  aplikasi sekitar 4,4 GB karena membawa empat model.
- Uji kualitas memakai suara buatan yang jernih. Rekaman asli (ruangan ramai, logat, suara bertumpuk) hampir pasti
  memberi hasil lebih rendah; lima rekaman asli dengan catatan to-do manual masih dibutuhkan.
- Model kecil masih bisa melewatkan to-do atau salah memasangkan frasa waktu; pengguna bisa mengubah, menambah, dan
  menghapus to-do.
- Ringkas ulang dari transkrip yang diedit baru diuji dengan peringkas tiruan di Mac, belum dengan model sungguhan
  di HP.
- Pemuatan pertama model suara bisa memakan waktu lama di HP karena Core ML menyiapkan model untuk perangkat.
- Akun Apple gratis membuat aplikasi kedaluwarsa 7 hari setelah dipasang.
