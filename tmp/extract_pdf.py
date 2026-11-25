# -*- coding: utf-8 -*-
from pypdf import PdfReader

SRC = r"C:\Users\chenk\Downloads\像素丧尸FPS游戏开发流程.pdf"
DST = r"D:\mygame\tmp\pdf_text.txt"

reader = PdfReader(SRC)
chunks = []
for i, page in enumerate(reader.pages):
    chunks.append("\n===== PAGE %d =====\n" % (i + 1))
    chunks.append(page.extract_text() or "")
text = "".join(chunks)
with open(DST, "w", encoding="utf-8") as f:
    f.write(text)
print("PAGES", len(reader.pages))
print("CHARS", len(text))
