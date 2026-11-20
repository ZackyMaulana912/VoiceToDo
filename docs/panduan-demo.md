# Panduan demo Voice-to-Todo

Daftar periksa untuk presentasi atau demo kedua versi. Langkah yang belum pernah dicoba di HP sungguhan ditandai
"belum diuji di HP" (lihat `catatan-uji.md`, bagian Uji yang menunggu HP).

## 1. Persiapan versi iPhone

Kerjakan sehari sebelum demo, karena aplikasi dari akun developer gratis kedaluwarsa 7 hari setelah dipasang.

- Sambungkan iPhone ke Mac, lalu pasang ulang aplikasi dari Xcode. Aplikasi sekitar 4,4 GB karena model AI ikut di
  dalamnya, jadi pastikan ruang kosong di HP cukup.
- Kalau iPhone menolak membuka aplikasi ("Untrusted Developer"), percayai profil developer lewat Settings > General >
  VPN & Device Management. Langkah ini butuh internet, cukup sekali.
- Buka aplikasi dan proses satu rekaman pendek, supaya model sudah siap saat demo. Proses pertama setelah dipasang
  diperkirakan lebih lama karena Core ML menyiapkan model (belum diuji di HP).
- Isi baterai penuh dan matikan notifikasi yang bisa muncul di layar saat demo.
- Nyalakan mode pesawat sebelum demo dimulai, untuk menunjukkan aplikasi tidak butuh internet.

## 2. Persiapan versi web

- Buka situs lewat HTTPS di browser HP (Safari di iPhone atau Chrome di Android). Lewat HTTP biasa, browser tidak
  mengizinkan mikrofon.
- Izinkan mikrofon saat diminta, lalu coba satu rekaman pendek untuk memastikan kunci API di server masih berlaku.
- Pastikan HP tersambung internet yang stabil. Hotspot cadangan berguna kalau Wi-Fi ruangan lambat.
- Jangan mencoba terlalu sering sebelum demo: server membatasi 10 permintaan per 10 menit per alamat, dan kuota Groq
  milik rekan tim ikut terpakai.
