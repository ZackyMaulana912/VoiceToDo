# Desain tambahan di luar Figma

Bagian tampilan yang tidak ada di Figma tetapi dibutuhkan aplikasi iPhone. Ditambahkan dengan warna, huruf, dan sudut
yang sudah ada di desain (izin user 2026-11-12). Daftar ini bisa dipakai rekan tim untuk melengkapi Figma.

| Layar | Tambahan | Alasan |
|---|---|---|
| Perekam | Dialog "Buang rekaman ini?" saat menekan Batal, dengan pilihan "Buang rekaman" dan "Lanjut merekam" | Rekaman tidak terbuang karena salah tekan |
| Perekam | Tulisan "Menyimpan rekaman…" dengan putaran kecil setelah menekan Selesai; tombol diredupkan | Tanda aplikasi sedang bekerja, mencegah tekan dua kali |
| Beranda | Pesan "Rekaman dihentikan" saat rekaman berhenti sendiri (layar dikunci, telepon, earphone) | Pengguna tahu rekamannya terpotong dan berapa lama yang tersimpan |
| Detail | Keterangan kecil berwarna cokelat di atas isi, misalnya "Rekaman berhenti karena layar dikunci…" | Keterangan tetap ada setelah pesan ditutup |
| Beranda | Saat kartu hasil tampil, to-do dari rekaman itu tidak diulang di daftar bawahnya | Di Figma dan versi web to-do yang sama tampil dua kali |
| Kartu hasil | Mode edit: tombol "Batal" dan "Simpan" (sebelumnya Salin dan Simpan); garis merah dan tulisan "Ringkasan tidak boleh kosong." | Perubahan bisa dibatalkan; ringkasan tidak bisa disimpan kosong |
| Kartu gagal | Pesan sesuai penyebab (lihat kode galat di `ios/VoiceToTodo/Models/Models.swift`); tombol Coba lagi disembunyikan bila file audio tidak ada | Pengguna tahu apa yang salah dan apakah mencoba lagi ada gunanya |
| Beranda, kartu hasil, detail | Tekan lama to-do: menu "Hapus to-do" (ikon tempat sampah), lalu konfirmasi "Hapus to-do ini?" | Figma belum punya cara menghapus to-do |
| Detail | Tombol "Hapus rekaman" (teks merah, garis abu, di bawah isi) dan konfirmasi "Hapus rekaman ini?" yang menyebut jumlah to-do yang ikut terhapus. Tidak tampil saat rekaman sedang diproses | Figma belum punya cara menghapus rekaman |
| Beranda | Tombol teks "+ Tambah" di kanan judul "To-do kamu" | Figma belum punya cara menambah to-do sendiri |
| Lembar isian to-do | Lembar setengah layar: judul "Edit to-do"/"Tambah to-do", kotak teks bergaris ungu (merah bila lebih dari 280 karakter), pilihan kategori berbentuk kapsul (hanya saat menambah), tombol Batal dan Simpan | Bentuk "kartu form satu isian teks" di CLAUDE.md 5.7 belum digambar di Figma |
| Menu tekan lama to-do | Ditambah "Edit to-do" (ikon pensil) di atas "Hapus to-do" | Satu tempat untuk mengubah dan menghapus |
| Semua layar | Pesan "Gagal menyimpan" bila data tidak bisa ditulis ke HP | Tidak gagal diam-diam |
