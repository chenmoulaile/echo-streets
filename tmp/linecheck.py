p = r"D:\mygame\scripts\level\chapter_02_office.gd"
b = open(p,"rb").read()
print("bytes", len(b))
print("CRLF", b.count(b"\r\n"), "LF", b.count(b"\n"), "CR", b.count(b"\r"))
print("CR-only (\\r not followed by \\n):", b.count(b"\r") - b.count(b"\r\n"))
s = b.decode("utf-8")
lines = s.splitlines()
print("splitlines:", len(lines))
print("split('\\n'):", len(s.split("\n")))
# 找异常字符
import unicodedata
odd = set(ch for ch in s if ord(ch) in (0x2028,0x2029,0x0b,0x0c,0x85))
print("odd line sep chars:", odd)
print("has BOM:", b[:3] == b"\xef\xbb\xbf")
