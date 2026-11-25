import pypdf, re
r = pypdf.PdfReader(r"C:\Users\chenk\Downloads\像素丧尸FPS游戏开发流程.pdf")
txt = "\n".join((p.extract_text() or "") for p in r.pages)
open(r"D:\mygame\tmp\_pdf.txt","w",encoding="utf-8").write(txt)
print("pages", len(r.pages), "chars", len(txt))
for kw in ["手臂","主角","角色","配色","硬核","蔚蓝","参考","第一人称","手部","袖"]:
    for m in re.finditer(kw, txt):
        s = max(0, m.start()-90); e = min(len(txt), m.end()+90)
        print("---", kw, "---")
        print(txt[s:e].replace("\n"," "))
        break
