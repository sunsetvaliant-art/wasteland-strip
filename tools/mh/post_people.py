"""0.2.75: after gen_people.py: shrink the textures (1024 jpg colour, 512 png normals; alpha kept as png), point the
glTFs at the new names, copy the lot into assets/characters/mh and write each one's .import (the Mixamo bone map,
like the other characters).
usage: python3 tools/mh/post_people.py <gen out dir>"""
import os, sys, json, glob, shutil
from PIL import Image
src = sys.argv[1]
game = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
T = os.path.join(src, "mh_tex"); ren = {}
for f in sorted(os.listdir(T)):
    p = os.path.join(T, f)
    if not f.endswith(".png"): continue
    im = Image.open(p)
    has_a = im.mode in ("RGBA", "LA") and im.getextrema()[-1][0] < 250
    n = "normal" in f
    size = 512 if n else 1024
    if max(im.size) > size: im = im.resize((size, size * im.size[1] // im.size[0]), Image.LANCZOS)
    if has_a or n: im.save(p, optimize=True)
    else:
        im.convert("RGB").save(p[:-4] + ".jpg", quality=88); os.remove(p); ren[f] = f[:-4] + ".jpg"
for g in glob.glob(os.path.join(src, "people", "*.gltf")):
    j = json.load(open(g))
    for im in j.get("images", []):
        b = os.path.basename(im["uri"])
        if b in ren: im["uri"] = im["uri"].replace(b, ren[b]); im["mimeType"] = "image/jpeg"
    json.dump(j, open(g, "w"))
dst = os.path.join(game, "assets", "characters", "mh")
for sub in ("people", "mh_tex"):
    os.makedirs(os.path.join(dst, sub), exist_ok=True)
    for f in os.listdir(os.path.join(src, sub)):
        shutil.copy(os.path.join(src, sub, f), os.path.join(dst, sub, f))
tmpl = open(os.path.join(game, "assets", "characters", "player.glb.import")).read()
for g in glob.glob(os.path.join(dst, "people", "*.gltf")):
    n = os.path.basename(g)[:-5]
    lines = [l for l in tmpl.splitlines() if not l.startswith(("uid=", "path=", "dest_files"))]
    t = "\n".join(lines).replace("res://assets/characters/player.glb", "res://assets/characters/mh/people/%s.gltf" % n)
    t = t.replace("PATH:target_character/Skeleton3D", "PATH:%s_rig/Skeleton3D" % n)
    imp = g + ".import"
    if not os.path.exists(imp): open(imp, "w").write(t + "\n")
print("people installed:", len(glob.glob(os.path.join(dst, "people", "*.gltf"))), "textures renamed", len(ren))
