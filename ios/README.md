# Voice-to-Todo for iOS

Aplikasi SwiftUI: rekam suara berbahasa Indonesia, ubah jadi teks, rangkum, dan hasilkan daftar to-do bertenggat.
Semua proses berjalan di iPhone tanpa internet.

## Menjalankan

1. Siapkan file yang tidak ikut git (sekali saja, butuh internet di Mac):

   ```sh
   python3 ios/scripts/unduh-model.py     # model AI, sekitar 4,4 GB
   sh ios/scripts/siapkan-llama.sh        # llama.cpp untuk iPhone asli
   sh ios/scripts/siapkan-llama.sh --simulator   # atau ini, bila ingin menjalankan di Simulator (butuh cmake)
   ```

2. Buka `VoiceToTodo.xcodeproj` di Xcode 27 atau lebih baru (aplikasi butuh iOS 17+, termasuk iPhone XR).
3. Pilih target **VoiceToTodo**, tab *Signing & Capabilities*, pilih Team Apple ID kamu.
4. Jalankan di **iPhone sungguhan**. Simulator bisa dipakai untuk tampilan dan proses AI, tetapi tidak bisa merekam
   suara.
5. Izinkan akses Mikrofon saat diminta. Tidak ada izin lain.

## Cara kerja

- **Merekam**: `AVAudioEngine` merekam ke file WAV 16 kHz mono di Documents/Recordings (`SpeechRecorder`,
  `AudioSink`). Telepon masuk, layar dikunci, atau earphone dicabut menghentikan rekaman dan bagian yang sudah
  terekam tetap disimpan.
- **Suara jadi teks**: WhisperKit (`WhisperTranscriber`). iPhone A15 ke atas memakai Whisper large-v3 turbo, HP yang
  lebih lama (misalnya XR) memakai Whisper base.
- **Ringkasan dan to-do**: llama.cpp dengan Qwen3 (`LlamaSummarizer`). Keluaran dipaksa berbentuk JSON dengan
  grammar, lalu divalidasi (`VoiceToTodoCore/Ringkasan`). Transkrip panjang diringkas per bagian 250 kata.
- **Tenggat**: frasa waktu yang disalin AI ("besok", "Jumat", "tanggal 20") diubah jadi tanggal oleh kode
  (`VoiceToTodoCore/FrasaWaktu`), bukan oleh AI.
- **Antrean**: rekaman diproses satu per satu; model suara dan model ringkasan tidak pernah dimuat bersamaan. Kalau
  aplikasi ditinggalkan saat memproses, proses dihentikan dan rekaman bisa dicoba lagi.
- **Gagal**: setiap kegagalan punya kode dan pesan sendiri (misalnya "Tidak ada suara yang terdengar", "Memori HP
  tidak cukup"). Audio tetap tersimpan; **Coba lagi** memproses ulang dari file.
- **Penyimpanan**: to-do dan riwayat di `voice-to-todo.json` (Documents). Data yang rusak dicadangkan, bukan
  ditimpa. Hapus bisa diurungkan selama 5 detik.

## Pengujian

```sh
cd ios/Packages/VoiceToTodoCore && swift test     # unit test logika inti di Mac
```

Uji UI di Simulator (folder tangkapan layar dan rekaman uji opsional):

```sh
TEST_RUNNER_SCREENSHOT_DIR=/tmp/layar \
TEST_RUNNER_UJI_AUDIO=$PWD/ios/UjiKelayakan/data-sintetis/01-rapat-panitia.wav \
xcodebuild test -project ios/VoiceToTodo.xcodeproj -scheme VoiceToTodo -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Uji kelayakan AI di HP: salin file WAV ke folder aplikasi `Documents/UjiKelayakan`, lalu buka aplikasi dengan argumen
`-ujiKelayakan`. Hasil (waktu, memori, suhu per tahap) ditulis ke `Documents/UjiKelayakan/hasil-<waktu>.jsonl`.
Audio uji sintetis dibuat dengan `sh ios/UjiKelayakan/buat-audio.sh`.

Hasil uji tercatat di `docs/catatan-uji.md`; model dan lisensi di `docs/model.md`.
