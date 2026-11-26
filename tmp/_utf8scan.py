"""扫描项目里非 UTF-8 / 截断 UTF-8 的文本文件，定位 Godot 的 Unicode parsing error 来源。

判据：1) 严格 UTF-8 解码失败；2) 含 lead byte + 0x3f（'?'）这种被 GBK 往返破坏的残留。
"""
import os

ROOT = r"D:\mygame"
SKIP_DIRS = {".godot", ".git", "tmp", "node_modules"}
EXTS = {".gd", ".tscn", ".tres", ".cfg", ".json", ".md", ".txt", ".gdshader", ".shader", ".py"}

bad = []
trunc = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
    for fn in filenames:
        ext = os.path.splitext(fn)[1].lower()
        if ext not in EXTS:
            continue
        p = os.path.join(dirpath, fn)
        try:
            data = open(p, "rb").read()
        except OSError:
            continue
        rel = os.path.relpath(p, ROOT)
        try:
            data.decode("utf-8")
        except UnicodeDecodeError as e:
            bad.append((rel, str(e)))
        if b"\xe3\x80\x3f" in data or b"\xef\xbc\x3f" in data:
            trunc.append(rel)

print("== strict-utf8 failures ==")
for r, e in bad:
    print("  %-56s %s" % (r, e))
print("  total=%d" % len(bad))
print("== truncated-multibyte (lead+0x3f) ==")
for r in trunc:
    print("  " + r)
print("  total=%d" % len(trunc))
