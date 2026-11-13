#!/bin/sh
# Membuat audio uji SINTETIS dari naskah.json dengan suara Damayanti (macOS), format WAV 16 kHz mono 16-bit.
# Hasilnya tidak ikut git. Pemakaian: sh ios/UjiKelayakan/buat-audio.sh
set -e
cd "$(dirname "$0")/data-sintetis"
python3 - <<'PY'
import json, subprocess
data = json.load(open("naskah.json"))
semua = []
for n in data["naskah"]:
    semua.append(n["teks"])
    open(f"{n['id']}.txt", "w").write(n["teks"])
open("06-gabungan.txt", "w").write(" ".join(semua))
PY
for t in *.txt; do
  id="${t%.txt}"
  say -v Damayanti -r 165 -f "$t" -o "$id.aiff"
  afconvert -f WAVE -d LEI16@16000 -c 1 "$id.aiff" "$id.wav"
  rm "$id.aiff" "$t"
  printf '%s: %s detik\n' "$id" "$(afinfo "$id.wav" | awk '/estimated duration/ {printf "%.0f", $3}')"
done
