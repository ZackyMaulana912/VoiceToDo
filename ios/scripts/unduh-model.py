#!/usr/bin/env python3
"""Mengunduh file model AI yang dibundel di aplikasi (tidak ikut git, lihat docs/model.md).

Pemakaian (dari folder mana saja):
    python3 ios/scripts/unduh-model.py              # model yang dipakai aplikasi
    python3 ios/scripts/unduh-model.py --kandidat   # ditambah model pembanding untuk uji kelayakan (Fase 1)
    python3 ios/scripts/unduh-model.py --ke FOLDER  # simpan di folder lain

Versi setiap repositori dikunci ke satu commit, dan setiap file besar dicek SHA-256-nya, supaya semua anggota tim
memakai file yang sama persis. Unduhan hanya terjadi di komputer pengembang; aplikasi tidak pernah mengunduh apa pun.
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys
import urllib.request

HF = "https://huggingface.co"

# (nama, repo, commit, isi, folder tujuan, kandidat?)
#   isi = nama folder di repo (diunduh seluruh isinya) atau daftar nama file.
MODELS = [
    ("whisper-base", "argmaxinc/whisperkit-coreml", "0f63a7800b00dd0226abd051b906c246e1907482",
     "openai_whisper-base", "whisper/openai_whisper-base", False),
    ("whisper-large-v3-turbo", "argmaxinc/whisperkit-coreml", "0f63a7800b00dd0226abd051b906c246e1907482",
     "openai_whisper-large-v3-v20240930_turbo_632MB", "whisper/openai_whisper-large-v3-v20240930_turbo_632MB", False),
    # Tokenizer disusun seperti cache Hugging Face, karena itu lokasi pertama yang dicari WhisperKit.
    ("tokenizer-base", "openai/whisper-base", "e37978b90ca9030d5170a5c07aadb050351a65bb",
     ["tokenizer.json", "tokenizer_config.json", "special_tokens_map.json", "added_tokens.json", "vocab.json",
      "merges.txt", "normalizer.json", "config.json"],
     "tokenizers/models/openai/whisper-base", False),
    ("tokenizer-large-v3", "openai/whisper-large-v3", "06f233fe06e710322aca913c1bc4249a0d71fce1",
     ["tokenizer.json", "tokenizer_config.json", "special_tokens_map.json", "added_tokens.json", "vocab.json",
      "merges.txt", "normalizer.json", "config.json"],
     "tokenizers/models/openai/whisper-large-v3", False),
    ("qwen3-1.7b", "unsloth/Qwen3-1.7B-GGUF", "d7f544eead698dbd1f15126ef60b45a1e1933222",
     ["Qwen3-1.7B-Q4_K_M.gguf"], "llm", False),
    ("qwen3-4b-instruct-2507", "unsloth/Qwen3-4B-Instruct-2507-GGUF", "a06e946bb6b655725eafa393f4a9745d460374c9",
     ["Qwen3-4B-Instruct-2507-Q4_K_M.gguf"], "llm", False),
    ("gemma-3-1b", "ggml-org/gemma-3-1b-it-GGUF", "f9c28bcd85737ffc5aef028638d3341d49869c27",
     ["gemma-3-1b-it-Q4_K_M.gguf"], "llm", True),
]


def api_tree(repo, rev, path):
    url = f"{HF}/api/models/{repo}/tree/{rev}/{path}?recursive=true"
    with urllib.request.urlopen(url, timeout=60) as r:
        return [x for x in json.load(r) if x["type"] == "file"]


def api_files(repo, rev, names):
    url = f"{HF}/api/models/{repo}/tree/{rev}?recursive=false"
    with urllib.request.urlopen(url, timeout=60) as r:
        items = {x["path"]: x for x in json.load(r) if x["type"] == "file"}
    missing = [n for n in names if n not in items]
    if missing:
        sys.exit(f"File tidak ada di {repo}@{rev}: {missing}")
    return [items[n] for n in names]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def ok(path, item):
    if not os.path.exists(path) or os.path.getsize(path) != item["size"]:
        return False
    lfs = item.get("lfs")
    return lfs is None or sha256(path) == lfs["oid"]


def fetch(repo, rev, item, dest):
    if ok(dest, item):
        return False
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    url = f"{HF}/{repo}/resolve/{rev}/{item['path']}"
    subprocess.run(["curl", "-L", "--fail", "--silent", "--show-error", "-C", "-", "-o", dest, url], check=True)
    if not ok(dest, item):
        os.remove(dest)
        sys.exit(f"Isi file tidak cocok (ukuran atau SHA-256): {item['path']}")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kandidat", action="store_true", help="unduh juga model pembanding Fase 1")
    ap.add_argument("--ke", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "VoiceToTodo", "Model"))
    ap.add_argument("--hanya", nargs="*", help="nama model tertentu saja")
    args = ap.parse_args()
    base = os.path.abspath(args.ke)

    for name, repo, rev, content, target, candidate in MODELS:
        if candidate and not args.kandidat:
            continue
        if args.hanya and name not in args.hanya:
            continue
        items = api_tree(repo, rev, content) if isinstance(content, str) else api_files(repo, rev, content)
        total = sum(i["size"] for i in items)
        print(f"{name}: {len(items)} file, {total / 1e6:.0f} MB", flush=True)
        new = 0
        for item in items:
            rel = item["path"][len(content) + 1:] if isinstance(content, str) else item["path"]
            new += fetch(repo, rev, item, os.path.join(base, target, rel))
        print(f"  v selesai ({new} diunduh, {len(items) - new} sudah ada dan cocok)", flush=True)


if __name__ == "__main__":
    main()
