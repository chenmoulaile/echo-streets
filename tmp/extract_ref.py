"""从 BOOMDoA.exe 尾部内嵌的 PCK 里抽取文件清单与着色器源码。

用途：D:\\BOOMDoA 1.10 是一个已发行的 Godot 4.7 复古 FPS，可作为本项目的
结构参考（目录布局、资源命名、着色器写法）。这里只读资源包，导出清单与
文本类资源用于对照学习，不参与本项目的构建。

PCK 头（Godot 4.4+ 内嵌式，pack_version=4）：
  magic 'GDPC' | pack_version u32 | ver_major/minor/patch u32*3 | flags u32
  | file_base u64 | dir_offset u64 | reserved[16] u32
目录表（位于 start + dir_offset）：
  file_count u32 | entry*
  entry: path_len u32 | path utf8 | offset u64 | size u64 | md5 16B | flags u32
条目 offset 相对 file_base，不是相对 PCK 起点；差 112 字节就会读成垃圾。
"""
import os
import struct

EXE = r"D:\BOOMDoA 1.10\BOOMDoA.exe"
OUT = r"D:\mygame\tmp\ref_boomdoa"


def parse(data):
    size = len(data)
    pck_size = struct.unpack_from("<Q", data, size - 12)[0]
    start = size - 12 - pck_size
    assert data[start:start + 4] == b"GDPC", "PCK magic mismatch"
    off = start + 4
    pack_version = struct.unpack_from("<I", data, off)[0]
    off += 4
    ver = struct.unpack_from("<III", data, off)
    off += 12
    flags = struct.unpack_from("<I", data, off)[0]
    off += 4
    file_base = struct.unpack_from("<Q", data, off)[0]
    off += 8
    dir_offset = struct.unpack_from("<Q", data, off)[0]
    print("pck_version=%d godot=%s flags=%d file_base=%d dir_offset=%d"
          % (pack_version, ".".join(map(str, ver)), flags, file_base, dir_offset))

    d = start + dir_offset
    count = struct.unpack_from("<I", data, d)[0]
    d += 4
    entries = []
    for _ in range(count):
        path_len = struct.unpack_from("<I", data, d)[0]
        d += 4
        path = data[d:d + path_len].decode("utf-8").rstrip("\x00")
        d += path_len
        eoff, esize = struct.unpack_from("<QQ", data, d)
        d += 16
        d += 16
        eflags = struct.unpack_from("<I", data, d)[0]
        d += 4
        entries.append((path, eoff, esize, eflags))
    print("file_count=%d" % count)
    return start + file_base, entries


def main():
    data = open(EXE, "rb").read()
    base, entries = parse(data)
    os.makedirs(OUT, exist_ok=True)

    with open(os.path.join(OUT, "_manifest.txt"), "w", encoding="utf-8") as fh:
        for path, _o, esize, eflags in sorted(entries):
            fh.write("%10d  flags=%d  %s\n" % (esize, eflags, path))

    dirs = {}
    for path, _o, _s, _f in entries:
        parts = path.strip("/").split("/")
        key = "/".join(parts[:2]) if len(parts) > 1 else parts[0]
        dirs[key] = dirs.get(key, 0) + 1
    print("\ntop-level layout (by file count):")
    for k in sorted(dirs, key=lambda x: -dirs[x])[:40]:
        print("  %5d  %s" % (dirs[k], k))

    shaders = [e for e in entries if e[0].endswith(".gdshader")]
    print("\n.gdshader files: %d" % len(shaders))
    for path, eoff, esize, _f in shaders:
        raw = data[base + eoff:base + eoff + esize]
        dest = os.path.join(OUT, path.lstrip("/").replace("/", os.sep))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as fh:
            fh.write(raw)
        print("  %7d  %s" % (esize, path))


if __name__ == "__main__":
    main()
