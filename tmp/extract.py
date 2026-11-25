import sys
from pypdf import PdfReader
r = PdfReader(r"C:\Users\chenk\Downloads\像素丧尸FPS游戏开发流程.pdf")
out = []
for i, p in enumerate(r.pages):
    out.append(f"\n===== PAGE {i+1} =====\n")
    out.append(p.extract_text() or "")
txt = "".join(out)
open(r"D:\mygame\tmp\spec.txt","w",encoding="utf-8").write(txt)
print("pages:", len(r.pages), "chars:", len(txt))
