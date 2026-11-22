#!/usr/bin/env python3
"""Realistic houses on the satellite outlines (0.2.56).

The traced footprints are whole roofs (house, verandah, eaves, carport, attached garage, often the back patio), and
0.2.48 used them as the house's walls, then the generator added a verandah, eaves and stairs outside that. Houses
came out about twice the size and 1,582 had their stairs on a road. This pass, on assets/world/buildings.json:
  - treats the outline as the roof edge: walls go inside it, less the eaves (0.5 m round), and the verandah comes out of
    it (front 2.8 m, side verandahs fit in 1.6 m each side) instead of being added to it
  - caps houses at real sizes: Queenslander 12.5 x 12, cottage 10.5 x 10.5, brick 18 x 14, two-storey 16 x 13
  - sets the house at the street end of an outline that's bigger than that; the back of a long outline (the carport,
    the shed) becomes a shed lot
  - checks the whole house (walls, verandah, stairs, a metre of front yard) against the painted roads (lines.bin) and
    pushes it back off them (up to 6 m), else leaves it out
Run once: python3 tools/fix_footprints.py  (it marks the file, so a second run does nothing)
"""
import json, math, struct, collections, sys
import numpy as np
from shapely.geometry import LineString, Polygon
from shapely.strtree import STRtree

ROOT = "/home/claude/game"
P = ROOT + "/assets/world/buildings.json"
B = json.load(open(P))
if B.get("houses_fixed"):
    print("already fixed"); sys.exit(0)

def read_lines(path):
    out = []; f = open(path, "rb").read(); o = 0
    def u32():
        nonlocal o; v = struct.unpack_from("<I", f, o)[0]; o += 4; return v
    for _ in range(u32()):
        u32(); u32()
        for _ in range(u32()):
            hs, sf, mk, wl = struct.unpack_from("<4f", f, o); o += 16; n = u32()
            a = np.frombuffer(f, dtype="<f4", count=n * 5, offset=o).reshape(n, 5); o += n * 20
            if n > 1: out.append(LineString(a[:, :2].astype(float)).buffer(hs + 0.3, quad_segs=4))
    return out
roads = read_lines(ROOT + "/assets/roads/lines.bin") + read_lines(ROOT + "/assets/roads/lines_north.bin")
rt = STRtree(roads)
def on_road(g):
    return any(roads[i].intersects(g) for i in rt.query(g))

def rect(x, z, yaw, x0, x1, z0, z1):
    c, s = math.cos(yaw), math.sin(yaw)
    return Polygon([(x + lx * c + lz * s, z - lx * s + lz * c) for lx, lz in ((x0, z0), (x1, z0), (x1, z1), (x0, z1))])

EAVE = 0.5
CAP = {"qlder": (12.5, 12.0), "cottage": (10.5, 10.5), "brick": (18.0, 14.0), "two_storey": (16.0, 13.0)}
VER = {"qlder": (2.8, 1.6), "cottage": (0.0, 0.0)}          # front, each side (a shack's deck: 2.2 front)
STAIRS = {"qlder": 4.0, "cottage": 1.6}
out = []
st = collections.Counter()
for l in B["lots"]:
    k = str(l[0])
    if k not in CAP or (len(l) > 7 and str(l[7]) == "units70"):
        out.append(l); continue
    x, z, yaw, wo, do = float(l[1]), float(l[2]), float(l[3]), float(l[4]), float(l[5])
    sub = str(l[7]) if len(l) > 7 else ""
    vf, vs = VER.get(k, (0.0, 0.0))
    if k == "cottage" and sub == "shack": vf = 2.2
    cw, cd = CAP[k]
    w = min(max(wo - 2 * EAVE - 2 * vs, 7.0), cw)
    d = min(max(do - 2 * EAVE - vf, 7.0), cd)
    # the house at the street end (+z is the front) of the outline
    zf = do / 2 - EAVE - vf                       # the walls' front
    zc = zf - d / 2
    c, s = math.cos(yaw), math.sin(yaw)
    def at(lz): return x + lz * s, z + lz * c
    stairs = STAIRS.get(k, 0.6)
    pushed = 0.0
    ok = False
    for step in range(13):
        nx, nz = at(zc - pushed)
        env = rect(nx, nz, yaw, -w / 2 - vs, w / 2 + vs, -d / 2, d / 2 + vf + stairs + 1.0)
        if not on_road(env): ok = True; break
        pushed += 0.5
    if not ok:
        st["left out: on a road whatever we do"] += 1
        continue
    if pushed > 0: st["pushed back off a road"] += 1
    nx, nz = at(zc - pushed)
    nl = list(l)
    nl[1], nl[2], nl[4], nl[5] = round(nx, 2), round(nz, 2), round(w, 2), round(d, 2)
    out.append(nl)
    st[k] += 1
    st["area before"] += wo * do; st["area after"] += w * d
    # the back of a long outline: the carport / shed / patio, as a shed lot
    back = (do / 2 + (zc - pushed) - d / 2) if False else (zc - pushed - d / 2) - (-do / 2)
    if back >= 5.0 and wo >= 4.0:
        sw = min(6.5, wo - 1.0); sd = min(6.5, back - 1.5)
        if sd >= 3.0:
            bz = -do / 2 + 0.5 + sd / 2
            sx, sz = at(bz)
            out.append(["shed", round(sx, 2), round(sz, 2), round(yaw, 4), round(sw, 2), round(sd, 2), float(l[6]) + 7.0])
            st["sheds out the back"] += 1
B["lots"] = out
B["houses_fixed"] = True
B["ver"] = "fp2-houses-2026"
json.dump(B, open(P, "w"), separators=(",", ":"))
n = sum(st[k] for k in CAP)
print("houses:", n, "median-ish area before %.0f, after %.0f m2" % (st["area before"] / max(n, 1), st["area after"] / max(n, 1)))
for k, v in st.most_common():
    if not k.startswith("area"): print("  ", k, v)
