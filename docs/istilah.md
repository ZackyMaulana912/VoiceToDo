# Daftar istilah

Penjelasan singkat istilah teknis yang muncul di dokumen dan presentasi Voice-to-Todo.

## 1. Istilah umum dan versi iPhone

| Istilah | Arti |
|---|---|
| Transkripsi | Mengubah suara menjadi teks |
| Transkrip | Teks hasil transkripsi |
| Whisper | Model AI dari OpenAI untuk transkripsi, dilatih dengan banyak bahasa termasuk bahasa Indonesia |
| WhisperKit | Pustaka yang menjalankan Whisper di iPhone lewat Core ML |
| Core ML | Kerangka bawaan Apple untuk menjalankan model AI di perangkat |
| WER | Word Error Rate: persentase kata yang salah dalam transkrip. Makin kecil makin baik |
| LLM | Large Language Model: model AI yang membaca dan menulis teks, di sini untuk membuat ringkasan dan to-do |
| Qwen3 | Keluarga LLM yang dipakai versi iPhone (4B di HP baru, 1.7B di HP lama). "4B" artinya sekitar 4 miliar parameter |
| llama.cpp | Program yang menjalankan LLM di HP atau komputer tanpa server |
| GGUF | Format file model untuk llama.cpp |
| Q4_K_M | Cara memperkecil model (kuantisasi 4 bit) supaya muat di memori HP, dengan sedikit penurunan kualitas |
| Grammar JSON | Aturan yang memaksa LLM hanya menulis JSON dengan bentuk tertentu |
| JSON | Format teks terstruktur untuk menyimpan dan bertukar data |
| Mode pesawat | Semua sambungan nirkabel HP mati; dipakai untuk membuktikan aplikasi tidak butuh internet |
| Personal Team | Akun developer Apple gratis. Aplikasi yang dipasang dengannya kedaluwarsa setelah 7 hari |
| Simulator | iPhone tiruan di Mac untuk menguji tampilan; tidak dihitung sebagai bukti untuk bagian AI |
