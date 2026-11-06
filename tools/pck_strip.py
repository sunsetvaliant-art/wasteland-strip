#!/usr/bin/env python3
"""Drop every file from a Godot .pck patch that an earlier patch already shipped unchanged (same path, same MD5).
Godot's --export-patch only diffs against one base pack, so later patches would otherwise re-send old content.
usage: pck_strip.py patch.pck out.pck [earlier1.pck ...]
Also drops file-removal markers."""
import struct, sys, hashlib

def read_index(p):
    f = open(p, "rb")
    assert f.read(4) == b"GDPC", p
    ver = struct.unpack("<I", f.read(4))[0]
    vmaj, vmin, vpat = struct.unpack("<III", f.read(12))
    flags = struct.unpack("<I", f.read(4))[0]
    base = struct.unpack("<Q", f.read(8))[0]
    if ver >= 3:
        dir_off = struct.unpack("<Q", f.read(8))[0]
        f.seek(dir_off)
    else:
        f.read(64)
    n = struct.unpack("<I", f.read(4))[0]
    files = []
    for _ in range(n):
        L = struct.unpack("<I", f.read(4))[0]
        raw = f.read(L)
        off, size = struct.unpack("<QQ", f.read(16))
        md5 = f.read(16)
        fl = struct.unpack("<I", f.read(4))[0]
        files.append({"path": raw.rstrip(b"\0").decode(), "raw": raw, "off": off, "size": size, "md5": md5, "flags": fl})
    rel = bool(flags & 2)
    return {"ver": ver, "v": (vmaj, vmin, vpat), "flags": flags, "base": base, "files": files, "rel": rel, "fh": f}

def main():
    src, out, refs = sys.argv[1], sys.argv[2], sys.argv[3:]
    p = read_index(src)
    assert p["ver"] >= 3 and not (p["flags"] & 1), "only unencrypted v3+ packs"
    def digest(pk, e):
        pk["fh"].seek((pk["base"] if pk["rel"] else 0) + e["off"])
        h = hashlib.md5()
        left = e["size"]
        while left > 0:
            chunk = pk["fh"].read(min(left, 1 << 22))
            h.update(chunk)
            left -= len(chunk)
        return h.digest()
    want = {e["path"] for e in p["files"]}
    seen = {}
    for r in refs:                          # later refs override earlier ones, like the game loads them
        pr = read_index(r)
        for e in pr["files"]:
            if e["path"] in want:
                seen[e["path"]] = (e["size"], digest(pr, e))
    keep = []
    for e in p["files"]:
        if e["flags"] & 2:
            continue      # "removed" markers: exporting with a narrow preset marks everything else deleted. Never wanted.
        old = seen.get(e["path"])
        if old and old[0] == e["size"] and old[1] == digest(p, e):
            continue
        keep.append(e)
    dropped = len(p["files"]) - len(keep)
    # write: header, data (32-byte aligned), directory
    ALIGN = 32
    hdr = 4 + 4 + 12 + 4 + 8 + 8 + 64
    file_base = (hdr + ALIGN - 1) // ALIGN * ALIGN
    with open(out, "wb") as o:
        o.write(b"\0" * file_base)
        cur = 0
        fh = p["fh"]
        for e in keep:
            fh.seek((p["base"] if p["rel"] else 0) + e["off"])
            data = fh.read(e["size"])
            e["new_off"] = cur
            o.write(data)
            pad = (-len(data)) % ALIGN
            o.write(b"\0" * pad)
            cur += len(data) + pad
        dir_off = file_base + cur
        o.write(struct.pack("<I", len(keep)))
        for e in keep:
            o.write(struct.pack("<I", len(e["raw"])))
            o.write(e["raw"])
            o.write(struct.pack("<QQ", e["new_off"], e["size"]))
            o.write(e["md5"])
            o.write(struct.pack("<I", e["flags"]))
        o.seek(0)
        o.write(b"GDPC")
        o.write(struct.pack("<I", p["ver"]))
        o.write(struct.pack("<III", *p["v"]))
        o.write(struct.pack("<I", p["flags"] | 2))           # offsets relative to file_base
        o.write(struct.pack("<Q", file_base))
        o.write(struct.pack("<Q", dir_off))
    print(f"kept {len(keep)} files, dropped {dropped} already shipped")

main()
