# Catatan uji

Hasil ukur dan uji per tanggal dan perangkat, termasuk yang gagal. Angka hanya ditulis dari hasil yang benar-benar
dijalankan.

## Fase 0: Inspeksi lingkungan

### 2026-11-11, Mac pengembang

| Hal | Hasil | Cara dicek |
|---|---|---|
| Xcode | 27.1 (build 27A9275) | `xcodebuild -version` |
| Swift | 6.4 | `swift --version` |
| Runtime Simulator iOS | belum ada yang terpasang | `xcrun simctl list runtimes` |
| Git LFS | 3.7.1 terpasang (dibutuhkan untuk file font `.ttf`) | `git lfs version` |
| Ruang disk Mac | 118 GB kosong | `df -h /` |
| Identitas signing (Apple ID di Xcode) | belum ada | `security find-identity -v -p codesigning` |
| HP tersambung ke Mac | belum ada | `xcrun devicectl list devices` |

### 2026-11-11, build aplikasi iPhone (tanpa signing, tujuan "Any iOS Device")

Perintah: `xcodebuild -project ios/VoiceToTodo.xcodeproj -scheme VoiceToTodo -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`

| Kondisi | Hasil |
|---|---|
| Kode apa adanya dari commit `bcb0762` | x GAGAL: `FoundationModelSummarizer.swift:38: cannot find type 'Date' in scope`. File itu belum `import Foundation`. Dugaan: di Xcode versi lama file ini dilewati (`#if canImport(FoundationModels)` bernilai salah), jadi errornya tidak muncul |
| Setelah menambah `import Foundation` | v BERHASIL. Hanya dibuktikan bisa dikompilasi; belum dipasang atau dijalankan di HP |

Bundle ID diganti dari `com.example.VoiceToTodo` ke `com.zackymaulana912.voicetodo` (dicek di `Info.plist` hasil
build). Target minimum di proyek masih iOS 16.0.

### 2026-11-11, pemasangan ke HP

Signing memakai akun Apple gratis (Personal Team) milik user. Data HP dibaca dengan
`xcrun devicectl device info details`.

| Hal | iPhone XR | iPhone 17 Pro |
|---|---|---|
| Identifier model | belum diuji | `iPhone18,1` |
| Versi iOS | belum diuji | 27.3 (build 24C5037i) |
| Kapasitas penyimpanan | belum diuji | 256 GB (ruang kosong belum dicatat) |
| Developer Mode | belum diuji | aktif |
| Aplikasi bisa dipasang dari Xcode | belum diuji | v berhasil (`xcodebuild -allowProvisioningUpdates`, lalu `devicectl device install app`) |
| Aplikasi bisa dibuka | belum diuji | v berjalan, prosesnya masih hidup 3 detik setelah dibuka. Hanya dibuka, fitur belum dicoba |

Yang terjadi selama pemasangan di 17 Pro:

- Percobaan pertama membuka aplikasi ditolak iPhone ("Untrusted Developer"). Ini perilaku normal untuk akun gratis:
  profil developer harus dipercayai dulu lewat Settings > General > VPN & Device Management. Langkah ini butuh
  internet, cukup sekali.
- Awalnya aplikasi belum punya ikon (katalog aset tidak berisi `AppIcon`). Ikon kemudian dibuat sendiri dengan format
  Icon Composer (`ios/VoiceToTodo/AppIcon.icon`): mikrofon dan centang di atas latar ungu aksen.
  Isi `Assets.car` hasil build (dibaca dengan `xcrun assetutil --info`) berisi versi terang, gelap, dan tinted, ditambah
  lapisan Liquid Glass. Xcode juga membuat gambar biasa `AppIcon60x60@2x.png` untuk iOS versi lama. Ikon sudah terpasang
  di 17 Pro. Tampilannya di iOS 17 (XR) belum dilihat langsung.
- Begitu Team dipilih di Xcode, file proyek berubah: `DEVELOPMENT_TEAM` terisi ID team user, dan Xcode mengurutkan
  ulang isi `project.pbxproj` dan `Info.plist` tanpa mengubah isinya (dibuktikan dengan membandingkan isi yang sudah
  diurutkan).

XR dijadwalkan diuji saat dipinjam (lihat jadwal uji XR).

## Perbaikan bug kritis dari audit

### 2026-11-11, bug 1: tombol "Tutup" menghapus rekaman

- Masalah: kalau aplikasi gagal mulai merekam lalu pengguna menekan "Tutup", `SpeechRecorder.cancel()` menghapus file
  berdasarkan nama file rekaman sebelumnya. Kalau belum pernah merekam sejak aplikasi dibuka, namanya kosong, dan
  `removeItem(folder.appendingPathComponent(""))` menghapus seluruh folder `Recordings`. Ini dibuktikan di Mac dengan
  kode yang sama: folder berisi 2 file ikut terhapus.
- Perbaikan: nama file dikosongkan di awal `start()`, dan `cancel()` hanya menghapus kalau namanya tidak kosong.
- Uji: build berhasil dan aplikasi terpasang di 17 Pro. Skenario gagal merekam belum dicoba langsung di HP, karena
  butuh kondisi yang membuat perekaman gagal dimulai (misalnya mikrofon sedang dipakai aplikasi lain).

### 2026-11-11, bug 2: data hilang setelah update

- Masalah: kalau `voice-to-todo.json` gagal dibaca (misalnya bentuk data berubah setelah update), `AppStore.load()`
  diam-diam mulai kosong, lalu penyimpanan berikutnya menimpa data lama. Dibuktikan di Mac: data tanpa kolom baru
  gagal dibaca (`keyNotFound`), walaupun kolom itu punya nilai bawaan di kode.
- Perbaikan: file yang gagal dibaca dipindah ke `voice-to-todo-cadangan-<waktu>.json`, lalu muncul pesan
  "Data lama tidak terbaca". Kalau pemindahan gagal, aplikasi berhenti menyimpan supaya data lama tidak tertimpa.
- Uji di iPhone 17 Pro (iOS 27.3), memakai `devicectl` untuk menyalin file data. Data asli user (2 to-do, 4 rekaman)
  dicadangkan ke Mac dulu, lalu dikembalikan setelah uji:

| Uji | Hasil |
|---|---|
| A. Data normal setelah update aplikasi | v terbaca seperti biasa, tidak ada file cadangan yang terbuat |
| B. Data tanpa kolom `summary` di satu rekaman | v file dipindah ke `voice-to-todo-cadangan-1794407516.json`, isinya sama persis (md5 cocok), dan pesan muncul di layar (dilihat user) |
| Pemulihan data asli | v md5 file di HP sama dengan cadangan; 4 file audio tetap ada |

File cadangan hasil uji B (2 KB) tertinggal di HP, karena `devicectl` tidak bisa menghapus file di dalam aplikasi.

## Uji yang menunggu HP

Keputusan user 2026-11-12: uji di HP dikumpulkan di akhir. Perubahan di bawah sudah dibuktikan lewat kode (build
berhasil untuk iOS, target minimum di proyek 17.0), tetapi **belum diuji di HP**. Hasilnya diisi saat diuji.

| Perubahan | Cara uji di 17 Pro | Hasil |
|---|---|---|
| Konfirmasi sebelum membuang rekaman | Rekam, tekan Batal: muncul "Buang rekaman ini?". "Lanjut merekam" tetap merekam; "Buang rekaman" kembali ke beranda | belum diuji |
| Tanda "Menyimpan rekaman…" | Rekam, tekan Selesai: tulisan muncul sebentar dan tombol tidak bisa ditekan | belum diuji |
| "Coba lagi" untuk transkrip 1-2 kata | Rekam satu atau dua kata sampai gagal, tekan Coba lagi: aplikasi mendengarkan ulang file audio | belum diuji |
| Rekaman terputus: layar dikunci | Rekam 20 detik, tekan tombol kunci, buka lagi: muncul "Rekaman dihentikan", rekaman 0:20-an tersimpan dan diproses, keterangan tampil di detail | belum diuji |
| Rekaman terputus: aplikasi ditinggalkan | Sama, tetapi geser ke layar utama | belum diuji |
| Rekaman terputus: telepon masuk | Minta orang menelepon saat merekam | belum diuji |
| Rekaman terputus: earphone | Cabut atau sambungkan earphone/AirPods saat merekam | belum diuji |
| Hapus to-do | Tekan lama kartu to-do (di daftar, kartu hasil, dan detail), pilih "Hapus to-do": muncul konfirmasi. Batal: to-do tetap. Hapus: to-do hilang dan tetap hilang setelah aplikasi dibuka ulang | belum diuji |
| Hapus rekaman | Buka detail rekaman, tekan "Hapus rekaman": konfirmasi menyebut jumlah to-do. Hapus: kembali ke Riwayat, rekaman dan to-do-nya hilang. Rekaman yang sedang diproses tidak punya tombol hapus | belum diuji |
| Edit to-do | Tekan lama to-do, pilih "Edit to-do": lembar isian muncul berisi teks lama dan keyboard terbuka. Batal: tidak berubah. Simpan: teks berubah di daftar dan di kartu hasil | belum diuji |
| Tambah to-do | Tekan "+ Tambah" di Beranda, tulis teks, pilih kategori, Simpan: to-do muncul paling atas di segmen Belum. Isian kosong atau lebih dari 280 karakter: Simpan tidak bisa ditekan | belum diuji |
| Bug 1: Tutup tidak menghapus rekaman lama | Putar musik/telepon yang memakai mikrofon, lalu mulai merekam sampai gagal, tekan Tutup: rekaman lama di Riwayat tetap ada | belum diuji |
| Urungkan | Centang, edit, hapus to-do, dan hapus rekaman: bar "Urungkan" muncul 5 detik di atas layar dan membatalkan aksinya | belum diuji |
| Perekaman WAV dan Whisper di HP | Rekam ucapan sungguhan 1 menit, Selesai: tahap "Mengubah suara jadi teks..." lalu "Merangkum...", hasil dan to-do muncul | belum diuji |
| Pemuatan pertama model | Catat lama proses rekaman pertama setelah aplikasi dipasang (Core ML menyiapkan model) | belum diuji |
| Mode pesawat | Seluruh alur di atas dengan mode pesawat menyala | belum diuji |
| Aplikasi ditinggalkan saat memproses | Saat "Merangkum...", geser ke layar utama, kembali: rekaman gagal "terganggu", Coba lagi berhasil | belum diuji |
| Uji kelayakan Fase 1 di 17 Pro | Salin WAV ke Documents/UjiKelayakan, buka dengan `-ujiKelayakan`, ambil hasil-*.jsonl: waktu, memori, suhu | belum diuji |
| Rekaman 10 menit | Rekam 10 menit penuh: berhenti otomatis, transkrip dipecah per bagian, waktu total dicatat | belum diuji |
| VoiceOver dan Dynamic Type di HP | Nyalakan VoiceOver dan ukuran teks besar, coba semua layar | belum diuji |
| Ukuran aplikasi dan pemasangan | Pasang dari Xcode (sekitar 4,4 GB), catat lama pemasangan | belum diuji |
| To-do tidak dobel di Beranda | Selesaikan satu rekaman: to-do hanya tampil di kartu hasil. Pindah ke Riwayat lalu kembali: to-do muncul di daftar | belum diuji |
| Edit ringkasan dengan Batal dan Simpan | Tekan Edit, ubah teks, tekan Batal: teks kembali seperti semula. Ubah lagi, tekan Simpan: tersimpan. Kosongkan teks: Simpan tidak bisa ditekan | belum diuji |
| Pesan gagal sesuai penyebab | Rekam diam saja: "Tidak ada suara yang terdengar…". Rekam satu-dua kata: "…terlalu pendek…". Tutup paksa aplikasi saat memproses lalu buka lagi: "Proses terhenti…" | belum diuji |
| Edit transkrip | Buka detail rekaman yang selesai, buka "Transkrip lengkap", tekan "Edit transkrip", ubah teksnya, Simpan: chip "Diedit" dan catatan "Transkrip sudah diubah…" muncul. Kosongkan teks: Simpan tidak bisa ditekan | belum diuji |
| Lihat dan kembalikan transkrip asli | Setelah transkrip diedit, tekan "Lihat transkrip asli": teks hasil AI tampil. Tekan "Kembalikan ke asli": transkrip kembali seperti hasil AI dan chip "Diedit" hilang | belum diuji |
| Ringkas ulang dengan model asli | Mode pesawat. Edit transkrip (misalnya tambah satu tugas), tekan "Ringkas ulang" lalu konfirmasi: tahap langsung "Merangkum..." tanpa "Mengubah suara jadi teks...", to-do lama diganti hasil baru, dan tugas tambahan ikut muncul | belum diuji |

Sudah dibuktikan di Mac (2026-11-12, kode `Models.swift` asli dikompilasi untuk macOS): rekaman lama tanpa kolom
keterangan baru (`stopNote`) tetap terbaca, dan keterangan tersimpan lalu terbaca kembali dengan benar.

### 2026-11-12, uji logika penyimpanan dan pesan gagal di Mac

`AppStore.swift`, `Models.swift`, dan `DesignTokens.swift` asli dikompilasi untuk macOS. Pengenal ucapan dan peringkas
diganti tiruan supaya setiap jenis kegagalan bisa dipicu. Folder data diarahkan ke scratchpad (bukan Documents milik
user) dan dihapus setelah uji. Hasil: 13 dari 13 lolos.

| Uji | Hasil |
|---|---|
| Data lama tanpa kolom baru (`stopNote`, `failReason`) terbaca, tanpa pesan masalah | v |
| Rekaman yang masih "memproses" saat aplikasi dibuka jadi gagal dengan kode `terganggu` | v |
| File audio tidak ada: `tanpa-audio`, tombol Coba lagi disembunyikan | v |
| Pengenal ucapan tidak tersedia: `pengenal-tidak-tersedia` | v |
| Tidak ada suara: `tidak-terdengar` | v |
| 1-2 kata: `terlalu-pendek`, transkrip diambil dari hasil dengar ulang file audio | v |
| Coba lagi berhasil: status selesai dan kode gagal dihapus | v |
| Data tersimpan terbaca ulang saat aplikasi dibuka lagi | v |
| Folder data tidak bisa ditulisi: muncul pesan "Gagal menyimpan" | v |
| Gagal berturut-turut: pesan tidak muncul berulang | v |
| Penyimpanan pulih lalu gagal lagi: pesan muncul lagi | v |

Keterbatasan: penyebab teknis di akhir pesan "Gagal menyimpan" berbahasa Inggris di Mac. Di iPhone berbahasa
Indonesia diduga ikut bahasa HP, belum dilihat.

### 2026-11-12, uji logika hapus di Mac

Cara sama dengan uji sebelumnya (kode `AppStore.swift` asli, pengenal ucapan dan peringkas tiruan, folder data di
scratchpad lalu dihapus). Hasil: 13 dari 13 lolos.

| Uji | Hasil |
|---|---|
| Hapus to-do: hilang dari daftar dan dari rekaman asalnya, tetap hilang setelah dibuka ulang | v |
| Hapus rekaman: rekaman dan to-do-nya hilang, rekaman lain utuh, tersimpan | v |
| Hapus rekaman: file audionya terhapus, audio rekaman lain dan folder `Recordings` tetap ada | v |
| Hapus rekaman: kartu hasil miliknya ikut tertutup | v |
| Rekaman yang sedang diproses tidak bisa dihapus dan tetap selesai normal | v |
| Penyimpanan gagal saat menghapus: muncul pesan, file audio tidak dihapus, rekaman masih ada setelah dibuka ulang | v |

### 2026-11-12, uji logika edit dan tambah to-do di Mac

Cara sama dengan uji sebelumnya. Hasil: 11 dari 11 lolos.

| Uji | Hasil |
|---|---|
| Teks dirapikan (spasi ujung dibuang, baris baru jadi spasi); kosong ditolak; 280 karakter diterima, 281 ditolak | v |
| Tambah: masuk paling atas dengan kategori pilihan, belum selesai, tanpa tenggat, asal "ditulis sendiri" | v |
| Tambah: teks kosong atau terlalu panjang tidak masuk | v |
| Edit: hanya teks yang berubah; kategori, tenggat, asal, status, dan rekaman asal tetap | v |
| Edit: to-do tetap tampil di kartu hasil rekamannya; teks kosong dan id tak dikenal tidak merusak data | v |
| Tersimpan dan terbaca ulang | v |

Catatan: batas 280 dihitung per huruf yang terlihat (emoji dihitung satu). Versi web menghitung dengan cara
JavaScript, jadi untuk teks berisi emoji batasnya bisa sedikit berbeda.

## Fase 1, 4, dan 5: Uji kelayakan AI (2026-11-12, di Mac dan Simulator)

**Status: belum selesai.** Angka target Fase 1 (waktu, memori, suhu) hanya sah dari HP sungguhan, dan uji
kualitas butuh 5 rekaman asli dari user. Yang di bawah ini dikerjakan tanpa HP supaya rangkaiannya terbukti jalan dan
pilihan model punya dasar. Semua angka waktu di bagian ini **bukan** angka HP.

Lingkungan: Mac Apple M5, RAM 16 GB, macOS 27.2; Simulator iPhone 17 Pro iOS 27.0.

### Data uji sintetis

Lima naskah berbahasa Indonesia (rapat panitia, kuliah, ide, obrolan santai, catatan singkat) dengan kunci jawaban
to-do yang ditulis **sebelum** pengujian (`ios/UjiKelayakan/data-sintetis/naskah.json`), dibacakan suara Damayanti
macOS (`buat-audio.sh`): 48, 42, 32, 32, dan 14 detik, ditambah gabungan kelimanya 169 detik. Suara buatan jauh lebih
jernih daripada rekaman sungguhan, jadi hasil di bawah adalah batas atas.

### Suara jadi teks (WhisperKit 1.1.1, kode dan file model yang sama dengan aplikasi)

WER = persentase kata yang salah dibanding naskah (angka "15" dihitung salah untuk "lima belas").

| Rekaman | base | large-v3 turbo |
|---|---|---|
| 01 rapat panitia | 14,9% | 5,0% |
| 02 kuliah | 14,3% | 7,1% |
| 03 ide | 4,4% | 0,0% |
| 04 obrolan santai | 15,3% | 0,0% |
| 05 catatan singkat | 30,0% | 10,0% |
| gabungan 169 detik | 16,3% | 5,1% |

- Dengan pengaturan bawaan WhisperKit, model base **kehilangan separuh awal** rekaman 04 (WER 63,9%): ambang
  `logProbThreshold` membuang segmen yang kurang yakin tanpa pemberitahuan. Ambang itu dimatikan di aplikasi; tidak ada
  rekaman yang memburuk.
- **Tanpa internet terbukti:** transkripsi tetap berhasil saat jaringan proses diblokir total dengan `sandbox-exec`
  (pada sandbox yang sama, `curl` gagal). Model dan tokenizer dimuat dari folder aplikasi.
- Pemuatan pertama model turbo di Mac 119 detik (Core ML menyiapkan model untuk perangkat), berikutnya 1 sampai 6
  detik. Di HP kemungkinan juga lambat sekali di awal; **belum diukur di HP**.

### Ringkasan dan to-do (llama.cpp b12291, prompt dan grammar yang sama dengan aplikasi)

Masukan: transkrip turbo dari rekaman 01 sampai 05 (17 to-do di kunci jawaban). Kecocokan to-do dinilai manual,
karena penilai otomatis menganggap "bab 4" berbeda dari "bab empat".

| Model | To-do ditemukan | To-do karangan per rekaman | Kategori benar | JSON tidak valid | Waktu rata-rata (Mac) |
|---|---|---|---|---|---|
| Qwen3-4B-Instruct-2507 Q4_K_M | 15/17 (88%) | 0,2 | 5/5 | 0 | 9,5 s |
| Qwen3-1.7B Q4_K_M | 16/17 (94%) | 0,6 | 4/5 | 0 | 6,1 s |
| Gemma 3 1B Q4_K_M | sekitar 6/17 | 0,6 | 3/5 | 0 | 6,3 s |

- Percobaan pertama memberi 0 to-do untuk kedua Qwen. Penyebab: grammar hanya mengizinkan 2 spasi, padahal model
  menulis JSON berindentasi. Diperbaiki (batas 16) dan diberi unit test; angka di atas dari setelah perbaikan.
- Transkrip panjang (gabungan, 355 kata): sekali jalan hanya 8/17 to-do (4B). Dengan pemecahan per 250 kata: 14/17,
  waktu Mac 39 detik.
- Skenario XR (transkrip base lalu Qwen3-1.7B): 9/17 menurut penilai otomatis yang ketat.
- Frasa waktu yang disalin model diubah jadi tanggal oleh kode; frasa yang tidak ada di transkrip dibuang.

### Rangkaian lengkap di dalam aplikasi (Simulator, mode `-ujiKelayakan`)

Kelima rekaman diproses aplikasi sungguhan tanpa kegagalan: Whisper turbo lalu Qwen3-1.7B (Simulator tidak punya
GPU, jadi aplikasi memilih model kecil sesuai rancangan). Waktu per rekaman 79 sampai 139 detik di CPU Mac; memori
puncak menurut Simulator 1.461 MB. **Angka ini tidak berlaku untuk HP.**

Masalah yang ditemukan dan diperbaiki lewat Simulator: aplikasi langsung tertutup saat dibuka karena pengaturan
`LD_RUNPATH_SEARCH_PATHS` tidak ada di proyek, sehingga llama.cpp tidak ditemukan. Kesalahan yang sama akan terjadi di
HP.

### Angka target Fase 1

| Ukuran | Target 17 Pro | Hasil |
|---|---|---|
| Waktu proses rekaman 10 menit | paling lama 1,5 menit | belum diukur di HP |
| Ditutup paksa karena memori (5 kali berturut) | 0 | belum diukur di HP |
| Suhu mencapai kritis | tidak pernah | belum diukur di HP |
| To-do ditemukan | minimal 70% | 88% (4B, Mac, audio sintetis) |
| To-do karangan per rekaman | paling banyak 1 | 0,2 (4B, Mac, audio sintetis) |
| JSON tidak valid setelah 1 kali coba ulang | 0 | 0 (Mac) |

## Fase 2 dan 3: logika inti dan perekam (2026-11-12, di Mac)

- Paket `VoiceToTodoCore` (frasa waktu jadi tanggal, label tenggat, validasi hasil AI, pemecahan transkrip): 39 unit
  test lolos (`swift test`). Setiap baris tabel CLAUDE.md 5.5 punya test, termasuk pergantian bulan, tahun, dan tahun
  kabisat, serta tanggal yang diucapkan dengan kata ("tanggal dua puluh").
- Uji regresi logika aplikasi `ios/UjiLogika` (kode `AppStore`, `Models`, `Processing`, `AudioSink` asli lewat
  symlink, dengan pengenal suara dan peringkas tiruan): 52 uji lolos, mencakup antrean satu per satu, aplikasi
  ditinggalkan saat memproses, rekaman yang masuk saat aplikasi di latar belakang, kode galat per penyebab, hapus,
  edit, tambah, Urungkan, rekaman yatim (termasuk pada pemakaian pertama), data lama, data rusak, gagal menyimpan,
  dan konversi audio. Jalankan: `cd ios/UjiLogika && CFFIXED_USER_HOME=$(mktemp -d) swift run`.
- Perekam (`AudioSink`, kode asli): suara 48 kHz dan 44,1 kHz diubah menjadi WAV 16 kHz mono 16-bit, panjang tepat
  (selisih 6 sampel), nada 440 Hz tetap (440,005 Hz), tanpa lonjakan di batas potongan. Ucapan 169 detik yang dilewatkan
  perekam ditranskripsi dengan WER sama persis (5,1%) dengan file aslinya.

## Fase 6 dan 7: Tampilan dan rangkaian lengkap (2026-11-12, Simulator iPhone 17 Pro iOS 27.0)

Uji UI otomatis (`ios/VoiceToTodoUITests`) menjalankan aplikasi sungguhan dan mengetuk layar seperti pengguna.
Putaran terakhir dengan kode final: **3 lolos, 1 dilewati**.

| Uji | Hasil | Isi |
|---|---|---|
| Alur to-do tanpa rekaman | v lolos (39 s) | Beranda kosong, Simpan mati saat isian kosong, tambah dua to-do, centang lalu Urungkan, edit lewat tekan lama, hapus dengan konfirmasi lalu Urungkan, segmen Selesai, Riwayat kosong |
| Proses rekaman sampai to-do | v lolos (151 s) | Rekaman yang tertinggal dipulihkan, Coba lagi, tahap "Mengubah suara jadi teks...", Whisper turbo dan Qwen3-1.7B sungguhan membuat ringkasan dan 4 to-do bertenggat, judul Riwayat berganti, hapus rekaman dengan konfirmasi, Urungkan mengembalikannya |
| Ukuran huruf besar | v lolos (30 s) | Tangkapan layar Beranda dan lembar Tambah pada ukuran XL dan Aksesibilitas L: teks membesar dan terlipat tanpa terpotong |
| Layar perekam dan Batal | dilewati | Simulator di Mac ini tidak bisa memberi masukan mikrofon. Dibuktikan dengan program terkecil yang hanya meminta `AVAudioEngine.inputNode`: ikut berhenti paksa (`Abort trap`) di Simulator yang sama, jadi bukan bug aplikasi. Harus diuji di HP |

Masalah yang ditemukan lewat uji ini dan sudah diperbaiki:

- Segmen Belum/Selesai melar setinggi sekitar 100 pt setelah tinggi baris dibuat fleksibel untuk huruf besar.
- Rekaman yang tertinggal tidak dipulihkan bila aplikasi baru pertama kali dipakai (file data belum ada).
- Tombol centang di kartu hasil dibacakan VoiceOver sebagai judul to-do, bukan "Tandai selesai".
- Pesan hapus masih menulis "tidak bisa dikembalikan" padahal sudah ada Urungkan.
- Tenggat tidak tampil di kartu hasil.

Ditemukan saat audit kode (bukan oleh uji): rekaman yang disimpan karena layar dikunci bisa mulai diproses AI saat
aplikasi sudah di latar belakang. Sekarang rekaman itu menunggu dan diproses saat aplikasi dibuka lagi (ada uji
regresinya).

Catatan kualitas dari uji ini (Qwen3-1.7B di Simulator): "nanti hasilnya dibandingkan" disalin model sebagai frasa
"nanti", lalu sesuai aturan 5.5 menjadi tenggat "Hari ini". Model 4B di Mac tidak melakukan kesalahan ini.

**Syarat Fase 7 belum terpenuhi**: masih ada BELUM_DIUJI (angka HP, XR, rekaman asli), jadi Fase 7 di HP belum
dimulai.
