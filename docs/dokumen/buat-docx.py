#!/usr/bin/env python3
"""Membuat Dokumen-Voice-to-Todo.docx dari Dokumen-Voice-to-Todo.md (butuh: pip install python-docx).

Yang didukung: judul (#, ##, ###), paragraf, daftar (- dan 1.), tabel, gambar ![..](path), **tebal**, `kode`.
Baris yang diawali "Gambar N." tepat setelah gambar menjadi keterangan gambar (di tengah, miring).
Pemakaian: python3 docs/dokumen/buat-docx.py [file.md]
Tanpa argumen: Dokumen-Voice-to-Todo.md di folder ini. File .docx dibuat di sebelah file .md-nya.
Contoh versi web: python3 docs/dokumen/buat-docx.py docs/web/Dokumen-Voice-to-Todo-Web.md
"""
import os
import re
import sys

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Inches, Pt, RGBColor

SRC = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "Dokumen-Voice-to-Todo.md")
HERE = os.path.dirname(SRC)
OUT = os.path.splitext(SRC)[0] + ".docx"


def inline(paragraph, text):
    """Menambahkan teks dengan **tebal** dan `kode`."""
    for part in re.split(r"(\*\*[^*]+\*\*|`[^`]+`)", text):
        if not part:
            continue
        if part.startswith("**"):
            paragraph.add_run(part[2:-2]).bold = True
        elif part.startswith("`"):
            run = paragraph.add_run(part[1:-1])
            run.font.name = "Menlo"
            run.font.size = Pt(9.5)
        else:
            paragraph.add_run(part)


def table(doc, rows):
    cells = [[c.strip() for c in r.strip().strip("|").split("|")] for r in rows]
    cells = [c for c in cells if not all(re.fullmatch(r":?-+:?", x) for x in c)]
    t = doc.add_table(rows=len(cells), cols=len(cells[0]))
    t.style = "Table Grid"
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, row in enumerate(cells):
        for j, value in enumerate(row):
            p = t.cell(i, j).paragraphs[0]
            inline(p, value)
            for run in p.runs:
                run.font.size = Pt(9.5)
                if i == 0:
                    run.bold = True
    doc.add_paragraph()


def main():
    doc = Document()
    doc.styles["Normal"].font.name = "Calibri"
    doc.styles["Normal"].font.size = Pt(11)
    lines = open(SRC, encoding="utf-8").read().split("\n")
    i = 0
    after_image = False
    while i < len(lines):
        line = lines[i]
        if line.startswith("|"):
            block = []
            while i < len(lines) and lines[i].startswith("|"):
                block.append(lines[i])
                i += 1
            table(doc, block)
            continue
        m = re.match(r"!\[[^\]]*\]\(([^)]+)\)", line)
        if m:
            path = os.path.normpath(os.path.join(HERE, m.group(1)))
            doc.add_picture(path, width=Inches(6.2))
            doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
            after_image = True
        elif after_image and re.match(r"Gambar \d+\.", line):
            p = doc.add_paragraph()
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            run = p.add_run(line.strip())
            run.italic = True
            run.font.size = Pt(10)
            run.font.color.rgb = RGBColor(0x33, 0x41, 0x55)
            after_image = False
        elif line.startswith("# "):
            doc.add_heading(line[2:], level=0)
        elif line.startswith("## "):
            doc.add_heading(line[3:], level=1)
        elif line.startswith("### "):
            doc.add_heading(line[4:], level=2)
        elif re.match(r"\s*- ", line):
            text = re.sub(r"^\s*- ", "", line)
            while i + 1 < len(lines) and lines[i + 1].startswith("  ") and not re.match(r"\s*- ", lines[i + 1]):
                i += 1
                text += " " + lines[i].strip()
            inline(doc.add_paragraph(style="List Bullet"), text)
        elif re.match(r"\d+\. ", line):
            text = re.sub(r"^\d+\. ", "", line)
            while i + 1 < len(lines) and lines[i + 1].startswith("   "):
                i += 1
                text += " " + lines[i].strip()
            inline(doc.add_paragraph(style="List Number"), text)
        elif line.strip():
            text = line
            while i + 1 < len(lines) and lines[i + 1].strip() and not re.match(r"(#|\||!\[|\s*- |\d+\. |Gambar \d+\.)", lines[i + 1]):
                i += 1
                text += " " + lines[i].strip()
            inline(doc.add_paragraph(), text)
        i += 1
    doc.save(OUT)
    print("v", os.path.relpath(OUT))


if __name__ == "__main__":
    main()
