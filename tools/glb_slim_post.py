#!/usr/bin/env python3
"""After gltfpack: make the glass see-through in Godot and shrink the textures, in place.

glb_slim_post.py file.glb [--tex 1024] [--json report.json]

- Glass: any material with KHR_materials_transmission (Godot ignores it, so the glass came out opaque), or already
  alpha-blended, or named like glass/window/windscreen, becomes alphaMode BLEND with a dark tint at 30 % opacity,
  rough 0.05; its transmission/volume/ior extensions are dropped.
- Textures: every embedded image over --tex px on its long side is scaled down; JPEG unless it has real alpha.
- Prints (and with --json writes) a report: triangles, materials, which are glass, interior-looking material names.
"""
import io, json, re, struct, sys
from PIL import Image

GLASS = re.compile(r"glass|window|windscreen|windshield|vidrio|cristal|scheibe|glas\b|lens", re.I)
INTERIOR = re.compile(r"interior|seat|dash|steer|carpet|leather|cabin|inside|gauge|pedal|headliner|door_?card|trim", re.I)


def load(p):
    b = open(p, "rb").read()
    jl = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    rest = b[20 + jl:]
    binc = b""
    if len(rest) >= 8:
        bl = struct.unpack("<I", rest[:4])[0]
        binc = rest[8:8 + bl]
    return j, binc


def save(p, j, views):
    """views: list of bytes, one per bufferView (all in buffer 0)"""
    out = bytearray()
    for i, v in enumerate(views):
        while len(out) % 4: out.append(0)
        j["bufferViews"][i]["byteOffset"] = len(out)
        j["bufferViews"][i]["byteLength"] = len(v)
        j["bufferViews"][i]["buffer"] = 0
        out += v
    while len(out) % 4: out.append(0)
    j["buffers"] = [{"byteLength": len(out)}]
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(out)
    with open(p, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, total))
        f.write(struct.pack("<I", len(js)) + b"JSON" + js)
        f.write(struct.pack("<I", len(out)) + b"BIN\0" + bytes(out))


def main():
    p = sys.argv[1]
    tex = int(sys.argv[sys.argv.index("--tex") + 1]) if "--tex" in sys.argv else 1024
    rep_path = sys.argv[sys.argv.index("--json") + 1] if "--json" in sys.argv else None
    j, binc = load(p)
    views = []
    for bv in j.get("bufferViews", []):
        o = bv.get("byteOffset", 0)
        views.append(binc[o:o + bv["byteLength"]])
    # ---- glass
    glass, interior = [], []
    for m in j.get("materials", []):
        nm = m.get("name", "")
        ext = m.get("extensions", {})
        pb = m.setdefault("pbrMetallicRoughness", {})
        is_glass = "KHR_materials_transmission" in ext or m.get("alphaMode") == "BLEND" or bool(GLASS.search(nm))
        if is_glass:
            glass.append(nm)
            c = pb.get("baseColorFactor", [1, 1, 1, 1])
            # keep a coloured lens its colour (tail lights), make clear glass a dark tint
            if max(c[:3]) - min(c[:3]) < 0.15:
                c = [0.08, 0.09, 0.1, 0.3]
            else:
                c = [c[0], c[1], c[2], min(c[3], 0.55)]
            pb["baseColorFactor"] = c
            pb["metallicFactor"] = 0.0
            pb["roughnessFactor"] = 0.05
            m["alphaMode"] = "BLEND"
            m.pop("alphaCutoff", None)
            for k in ("KHR_materials_transmission", "KHR_materials_volume", "KHR_materials_ior"):
                ext.pop(k, None)
            if not ext: m.pop("extensions", None)
        elif INTERIOR.search(nm):
            interior.append(nm)
    used = set()
    for m in j.get("meshes", []):
        for pr in m["primitives"]:
            used.add(pr.get("material", -1))
    for k in ("KHR_materials_transmission", "KHR_materials_volume", "KHR_materials_ior"):
        if k in j.get("extensionsUsed", []) and not any(k in m.get("extensions", {}) for m in j.get("materials", [])):
            j["extensionsUsed"].remove(k)
            if k in j.get("extensionsRequired", []): j["extensionsRequired"].remove(k)
    # ---- textures
    shrunk = 0
    for im in j.get("images", []):
        if "bufferView" not in im: continue
        bi = im["bufferView"]
        try:
            img = Image.open(io.BytesIO(views[bi]))
            img.load()
        except Exception:
            continue
        w, h = img.size
        if max(w, h) <= tex: continue
        s = tex / max(w, h)
        img = img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
        has_a = img.mode in ("RGBA", "LA") and img.getchannel("A").getextrema()[0] < 250
        buf = io.BytesIO()
        if has_a:
            img.save(buf, "PNG", optimize=True); im["mimeType"] = "image/png"
        else:
            img.convert("RGB").save(buf, "JPEG", quality=88); im["mimeType"] = "image/jpeg"
        views[bi] = buf.getvalue()
        shrunk += 1
    save(p, j, views)
    tris = 0
    for m in j.get("meshes", []):
        for pr in m["primitives"]:
            if "indices" in pr: tris += j["accessors"][pr["indices"]]["count"] // 3
            else: tris += j["accessors"][pr["attributes"]["POSITION"]]["count"] // 3
    rep = {"tris": tris, "materials": len(j.get("materials", [])), "primitives": sum(len(m["primitives"]) for m in j.get("meshes", [])),
           "glass": glass, "interior": interior, "textures_shrunk": shrunk}
    print(json.dumps(rep))
    if rep_path: json.dump(rep, open(rep_path, "w"), indent=1)


if __name__ == "__main__":
    main()
