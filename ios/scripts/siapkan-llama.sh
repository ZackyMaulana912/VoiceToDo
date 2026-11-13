#!/bin/sh
# Menyiapkan llama.cpp (versi dikunci: b12291) untuk aplikasi di ios/Packages/LlamaFramework/llama.xcframework.
#
#   sh ios/scripts/siapkan-llama.sh              unduh rilis resmi (iPhone asli + Mac), cek SHA-256. Cepat.
#   sh ios/scripts/siapkan-llama.sh --simulator  bangun sendiri dari kode sumber tag yang sama, ditambah
#                                                Simulator (rilis resmi b12291 tidak punya bagian Simulator).
#                                                Butuh cmake, sekitar 10 sampai 20 menit.
set -e
TAG=b12291
SHA256=83eade8074c787ad37f2f696f4169dbe2f81b456c096ea0809f08a10a6de2289
DEST="$(cd "$(dirname "$0")/../Packages/LlamaFramework" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ "$1" = "--simulator" ]; then
  command -v cmake >/dev/null || { echo "cmake belum terpasang (brew install cmake)"; exit 1; }
  git clone --quiet --depth 1 --branch "$TAG" https://github.com/ggml-org/llama.cpp.git "$TMP/src"
  (cd "$TMP/src" && ./build-xcframework.sh ios-sim ios-device macos)
  SRC="$TMP/src/build-apple/llama.xcframework"
else
  curl -L --fail --silent --show-error -o "$TMP/llama.zip" \
    "https://github.com/ggml-org/llama.cpp/releases/download/$TAG/llama-$TAG-xcframework.zip"
  echo "$SHA256  $TMP/llama.zip" | shasum -a 256 -c -
  unzip -q "$TMP/llama.zip" -d "$TMP"
  SRC="$TMP/build-apple/llama.xcframework"
fi

rm -rf "$DEST/llama.xcframework"
cp -R "$SRC" "$DEST/llama.xcframework"
echo "v llama.xcframework ($TAG) siap: $(ls "$DEST/llama.xcframework" | grep -v Info.plist | tr '\n' ' ')"
