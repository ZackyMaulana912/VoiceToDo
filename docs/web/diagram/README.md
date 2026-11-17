# Diagram versi web

Sumber diagram ada di file `.dot` (Graphviz) dan `.mmd` (Mermaid). Gambar `.png` dibuat ulang dengan:

```sh
dot -Tpng -Gdpi=200 1-use-case.dot -o 1-use-case.png
dot -Tpng -Gdpi=200 5-deployment.dot -o 5-deployment.png
npx -p @mermaid-js/mermaid-cli@11.4.2 mmdc -i 2-sequence.mmd -o 2-sequence.png -s 2 -b white
npx -p @mermaid-js/mermaid-cli@11.4.2 mmdc -i 3-class.mmd -o 3-class.png -s 2 -b white
npx -p @mermaid-js/mermaid-cli@11.4.2 mmdc -i 4-state.mmd -o 4-state.png -s 2 -b white
```

Diagram digambar dari kode repo `voice-to-todo` commit `5116f11` per 17 November 2026. Use Case sengaja dibuat
sederhana: hanya kasus inti, tanpa «include» dan «extend». Kalau kode berubah, perbarui sumbernya lalu buat ulang
gambarnya.
