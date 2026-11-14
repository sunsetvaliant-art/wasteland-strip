#!/usr/bin/env python3
"""Sheds belong in the country. Sheds and machine sheds that landed in town streets (6+ houses within 100 m, within
1.5 km of a town) and are bigger than a garden shed (25 m2) become houses like their neighbours (the commonest kind
within 100 m), trimmed to a house's size. Garden sheds and every rural shed stay. Rewrites assets/world/buildings.json
and marks its version "+sheds1" (so cupboards start fresh once).
  python3 tools/fix_sheds.py
"""
import json, math, collections
import numpy as np
from scipy.spatial import cKDTree

P = "/home/claude/game/assets/world/buildings.json"
d = json.load(open(P))
if "+sheds1" in d["ver"]:
    print("already done"); raise SystemExit
L = d["lots"]
H = ["qlder", "brick", "cottage", "two_storey"]
hi = [i for i, l in enumerate(L) if l[0] in H]
T = cKDTree(np.array([[L[i][1], L[i][2]] for i in hi]))
TT = cKDTree(np.array([[t["x"], t["z"]] for t in d["towns"]]))
SIZE = {"qlder": (12.0, 11.0), "brick": (14.0, 11.0), "cottage": (11.0, 10.0), "two_storey": (12.0, 10.0)}
changed = collections.Counter()
for l in L:
    if l[0] not in ("shed", "machine_shed"): continue
    if l[4] * l[5] <= 25.0: continue
    dt, _ = TT.query([l[1], l[2]])
    if dt > 1500.0: continue
    near = T.query_ball_point([l[1], l[2]], 100.0)
    if len(near) < 6: continue
    kind = collections.Counter(L[hi[j]][0] for j in near).most_common(1)[0][0]
    w, dd = SIZE[kind]
    changed[(l[0], kind)] += 1
    l[0] = kind
    l[4] = round(min(l[4], w), 2)
    l[5] = round(min(l[5], dd), 2)
d["ver"] += "+sheds1"
json.dump(d, open(P, "w"), separators=(",", ":"))
print("sheds turned into houses:", sum(changed.values()), dict(changed))
