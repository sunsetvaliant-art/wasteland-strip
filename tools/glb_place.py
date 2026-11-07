#!/usr/bin/env python3
"""Puts a GLB at real size with its origin on the ground: wraps the scene in one node that scales it so its
biggest dimension (or its height, --by h) is the given metres, centred over the origin, bottom at y = 0.
usage: glb_place.py in.glb out.glb --size 0.95 [--by max|h|x|z] [--name key]"""
import json, struct, argparse
import numpy as np

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("dst"); ap.add_argument("--size", type=float, required=True)
ap.add_argument("--by", default="max"); ap.add_argument("--name", default="")
a = ap.parse_args()
f = open(a.src, "rb"); f.read(12)
L, t = struct.unpack("<II", f.read(8)); j = json.loads(f.read(L))
L2, t2 = struct.unpack("<II", f.read(8)); binb = f.read(L2)

def mat(n):
    if "matrix" in n: return np.array(n["matrix"], dtype=float).reshape(4, 4).T
    T = np.eye(4); T[:3, 3] = n.get("translation", [0, 0, 0])
    x, y, z, w = n.get("rotation", [0, 0, 0, 1])
    R = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)], [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)], [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
    S = np.diag(n.get("scale", [1, 1, 1]))
    M = np.eye(4); M[:3, :3] = R @ S
    return T @ M
lo = np.full(3, 1e18); hi = np.full(3, -1e18)
def walk(i, P):
    global lo, hi
    n = j["nodes"][i]; M = P @ mat(n)
    if "mesh" in n:
        for pr in j["meshes"][n["mesh"]]["primitives"]:
            acc = j["accessors"][pr["attributes"]["POSITION"]]
            mn = np.array(acc["min"]); mx = np.array(acc["max"])
            for c in range(8):
                p = np.array([mx[0] if c & 1 else mn[0], mx[1] if c & 2 else mn[1], mx[2] if c & 4 else mn[2], 1.0])
                q = (M @ p)[:3]; lo = np.minimum(lo, q); hi = np.maximum(hi, q)
    for c in n.get("children", []): walk(c, M)
sc = j["scenes"][j.get("scene", 0)]
for r in sc["nodes"]: walk(r, np.eye(4))
size = hi - lo
ref = {"max": size.max(), "h": size[1], "x": size[0], "z": size[2]}[a.by]
s = a.size / ref
cen = (lo + hi) / 2
root = {"name": a.name or "root", "scale": [s, s, s], "translation": [-cen[0] * s, -lo[1] * s, -cen[2] * s], "children": list(sc["nodes"])}
j["nodes"].append(root); sc["nodes"] = [len(j["nodes"]) - 1]
js = json.dumps(j, separators=(",", ":")).encode(); js += b" " * (-len(js) % 4)
with open(a.dst, "wb") as o:
    o.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binb)))
    o.write(struct.pack("<II", len(js), 0x4E4F534A)); o.write(js)
    o.write(struct.pack("<II", len(binb), 0x004E4942)); o.write(binb)
print(a.dst, "was", np.round(size, 2), "now", np.round(size * s, 2), "m")
