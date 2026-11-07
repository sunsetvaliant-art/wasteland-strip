#!/usr/bin/env python3
"""Tidy a Meshy GLB for the game: prefix its animation names (so 'Walking' from a zombie doesn't clash with the
player's 'Walking' in the shared clip pool) and shrink its textures (Meshy ships 4K PNGs; 2K JPEG is plenty).
usage: glb_repack.py in.glb out.glb [--prefix name__] [--max 2048] [--quality 88]"""
import io, json, struct, sys, argparse
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("dst")
ap.add_argument("--prefix", default=""); ap.add_argument("--max", type=int, default=2048); ap.add_argument("--quality", type=int, default=88)
a = ap.parse_args()
f = open(a.src, "rb")
magic, ver, total = struct.unpack("<III", f.read(12))
L, t = struct.unpack("<II", f.read(8)); j = json.loads(f.read(L))
L2, t2 = struct.unpack("<II", f.read(8)); binb = f.read(L2)
for an in j.get("animations", []):
    if a.prefix and not an.get("name", "").startswith(a.prefix):
        an["name"] = a.prefix + an.get("name", "anim")
img_views = {}
for i, im in enumerate(j.get("images", [])):
    bv = j["bufferViews"][im["bufferView"]]
    data = binb[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
    pic = Image.open(io.BytesIO(data))
    has_alpha = pic.mode in ("RGBA", "LA") and pic.getchannel("A").getextrema()[0] < 250
    pic = pic.convert("RGBA" if has_alpha else "RGB")
    if max(pic.size) > a.max:
        s = a.max / max(pic.size); pic = pic.resize((round(pic.width * s), round(pic.height * s)), Image.LANCZOS)
    out = io.BytesIO()
    if has_alpha: pic.save(out, "PNG", optimize=True); im["mimeType"] = "image/png"
    else: pic.save(out, "JPEG", quality=a.quality); im["mimeType"] = "image/jpeg"
    img_views[im["bufferView"]] = out.getvalue()
# rebuild the binary buffer, 4-byte aligned, every view at its new offset
nb = bytearray()
for vi, bv in enumerate(j["bufferViews"]):
    data = img_views.get(vi)
    if data is None:
        data = binb[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
    while len(nb) % 4: nb.append(0)
    bv["byteOffset"] = len(nb); bv["byteLength"] = len(data); nb += data
while len(nb) % 4: nb.append(0)
j["buffers"][0]["byteLength"] = len(nb)
js = json.dumps(j, separators=(",", ":")).encode()
js += b" " * (-len(js) % 4)
with open(a.dst, "wb") as o:
    o.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(nb)))
    o.write(struct.pack("<II", len(js), 0x4E4F534A)); o.write(js)
    o.write(struct.pack("<II", len(nb), 0x004E4942)); o.write(nb)
print(a.dst, len(nb) // 1024, "KB;", [an["name"] for an in j.get("animations", [])])
