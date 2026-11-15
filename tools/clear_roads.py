#!/usr/bin/env python3
"""0.2.50: after tools/realign.py, the few lots still over a painted road seal (assets/roads/lines.bin and
lines_north.bin: roads the old build had that OSM no longer does, a driveway drawn as a street) are pushed straight off
it, half a metre at a time up to 5 m; a house that still can't clear is left out, a named place stays where it is."""
import json, math, sys
import numpy as np
from scipy.spatial import cKDTree
sys.path.insert(0, "/home/claude/game/tools")
import road_lines
ROOT = "/home/claude/game/"
pcs = road_lines.read(ROOT + "assets/roads/lines.bin") + road_lines.read(ROOT + "assets/roads/lines_north.bin")
P, H = road_lines.dense(pcs, 1.0)
T = cKDTree(P)
B = json.load(open(ROOT + "assets/world/buildings.json"))
NAMED = ("shop", "school", "pub", "club", "church", "motel", "hospital", "police", "fire", "post", "workshop", "warehouse", "tower", "mall")
def samples(x, z, y, w, d):
    c, s = math.cos(y), math.sin(y)
    return [(x + c * fx * w + s * fz * d, z - s * fx * w + c * fz * d) for fx in (-0.5, 0, 0.5) for fz in (-0.5, 0, 0.5)]
def worst(x, z, y, w, d):
    pts = samples(x, z, y, w, d)
    dd, ii = T.query(pts)
    g = dd - H[ii] - 0.5                 # clearance past the seal edge, half a metre spare
    k = int(np.argmin(g))
    return g[k], pts[k], P[ii[k]]
out = []; st = {"clear": 0, "nudged": 0, "left out": 0, "named, kept": 0}
for l in B["lots"]:
    if l[0] == "mall" or (len(l) > 7 and str(l[7]).startswith(("servo/", "5g"))): out.append(l); continue
    x, z = l[1], l[2]
    g, sp, rp = worst(x, z, *l[3:6])
    if g >= 0: out.append(l); st["clear"] += 1; continue
    moved = 0.0
    while g < 0 and moved < 5.0:
        vx, vz = sp[0] - rp[0], sp[1] - rp[1]; n = math.hypot(vx, vz) or 1.0
        x += vx / n * 0.5; z += vz / n * 0.5; moved += 0.5
        g, sp, rp = worst(x, z, *l[3:6])
    if g >= 0:
        l[1], l[2] = round(float(x), 2), round(float(z), 2); out.append(l); st["nudged"] += 1
    elif l[0] in NAMED:
        out.append(l); st["named, kept"] += 1
    else:
        st["left out"] += 1
B["lots"] = out
B["ver"] += "+clear1"
json.dump(B, open(ROOT + "assets/world/buildings.json", "w"), separators=(",", ":"))
print(st, "lots:", len(out))
