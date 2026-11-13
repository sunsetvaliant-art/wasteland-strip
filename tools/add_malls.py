#!/usr/bin/env python3
"""Put the big malls that OSM doesn't name onto the lot list (run after tools/place_buildings.py, which calls this):
anything already standing inside a mall's block is taken off, the mall goes on the end with a fixed seed, and the
list's version is worked out again. [name, centre x, centre z, yaw, w, d, seed]"""
import json, math, hashlib, os
GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MALLS = [
    # Tweed City: the OSM outline's best rectangle (378 m north-south, 245 m east-west), front (+z) to the main road on the west
    ["TWIN CITY", 13940.68, -14048.52, -1.7325, 378.3, 244.7, 20261112],
    # Tweed Mall: 177 m east-west, 250 m north-south, front (+z) south; it straddles the old north edge of the map
    # (z = -16960), which main.gd's _extend_north carries on for it
    ["BAY MALL", 13522.0, -17036.0, 0.0, 177.4, 250.3, 20261115],
    # the two rows of shops along its diagonal mall, standing in the court at 22 degrees (worked out in docs/MALLS.md)
    ["TWIN CITY/P", 13973.82, -14094.14, -1.3524, 58.0, 13.0, 20261113],
    ["TWIN CITY/P", 13958.07, -14049.66, -4.494, 58.0, 13.0, 20261114],
]
f = f"{GAME}/assets/world/buildings.json"
d = json.load(open(f))
lots = [l for l in d["lots"] if not (l[0] == "mall" and len(l) > 7 and l[7] in [m[0] for m in MALLS])]
for name, cx, cz, yaw, w, dd, seed in MALLS:
    keep = []
    for l in lots:
        dx, dz = l[1] - cx, l[2] - cz
        lx = dx * math.cos(yaw) - dz * math.sin(yaw)
        lz = dx * math.sin(yaw) + dz * math.cos(yaw)
        r = max(l[4], l[5]) / 2
        if l[0] == "mall": pass                  # another mall (this one's own rows stand inside it)
        elif abs(lx) < w / 2 + r * 0.7 + 2 and abs(lz) < dd / 2 + r * 0.7 + 2: continue
        keep.append(l)
    print(name, "removed", len(lots) - len(keep))
    lots = keep
    lots.append(["mall", cx, cz, yaw, w, dd, seed, name])
d["lots"] = lots
d["ver"] = hashlib.md5(json.dumps(lots, separators=(",", ":")).encode()).hexdigest()[:12]
json.dump(d, open(f, "w"), separators=(",", ":"))
print("lots", len(lots), "ver", d["ver"])
