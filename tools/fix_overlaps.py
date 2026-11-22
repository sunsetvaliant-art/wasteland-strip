#!/usr/bin/env python3
"""Buildings standing inside each other (0.2.59): two traced outlines over the same ground (a shed with a house in
it, two shops in one). Where two lots overlap by more than a quarter of the smaller, the smaller goes. Malls, named
lots and lots with a sub-type (servos, schools, shops inside a mall) are left alone: they're meant to be where they are.
Run after tools/fix_types.py: python3 tools/fix_overlaps.py (marks the file; a second run does nothing)
"""
import json, math, sys
from shapely.geometry import Polygon
from shapely.strtree import STRtree
P = "/home/claude/game/assets/world/buildings.json"
B = json.load(open(P))
if B.get("overlaps_fixed"):
    print("already done"); sys.exit(0)
L = B["lots"]
def rect(l):
    x, z, yaw, w, d = map(float, l[1:6]); c, s = math.cos(yaw), math.sin(yaw)
    return Polygon([(x + lx * c + lz * s, z - lx * s + lz * c) for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))])
R = [rect(l) for l in L]
t = STRtree(R)
fixed = lambda l: str(l[0]) == "mall" or (len(l) > 7 and str(l[7]) != "")
drop = set()
order = sorted(range(len(L)), key=lambda i: -R[i].area)
for i in order:
    if i in drop: continue
    for j in t.query(R[i]):
        if j == i or j in drop: continue
        a = R[i].intersection(R[j]).area
        if a < 2.0: continue
        small, big = (i, j) if R[i].area < R[j].area else (j, i)
        if a < 0.25 * R[small].area: continue
        if fixed(L[small]):
            if fixed(L[big]): continue
            small, big = big, small
        drop.add(small)
print("dropped %d of %d lots that stood inside a bigger one" % (len(drop), len(L)))
B["lots"] = [l for i, l in enumerate(L) if i not in drop]
B["overlaps_fixed"] = True
json.dump(B, open(P, "w"), separators=(",", ":"))
