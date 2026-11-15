#!/usr/bin/env python3
"""0.2.50: put everything placed from latitude/longitude onto the game's own ground.
The game's roads and terrain (the old browser build) were laid out with true metres per degree; every tool here that
converted lat/lon itself (OSM buildings, Overture footprints, servos, trades, yards) used x = dlon * 111320 * cos(lat0),
z = -dlat * 110574, which is 0.075% short east-west and 0.227% short north-south. Nothing at Murwillumbah (the origin),
but 10 m east and 37 m north out by Tweed Heads: houses on the roads. Fitted against Overture's roads over the whole
map (assets/world/geo_fit.json, median 0.5 m after). The north strip (z < -16960: lidar, roads and buildings baked
by tools/bake_north.py with the short conversion) is consistent with itself and stays as it is.
  python3 tools/realign.py            (once: the lot list's ver gets "+geo1"; refuses to run twice)
Tools that convert lat/lon should use tools/geo.py from now on."""
import json, sys
sys.path.insert(0, "/home/claude/game/tools")
from geo import fix
ROOT = "/home/claude/game/assets/world/"
B = json.load(open(ROOT + "buildings.json"))
if "+geo1" in B["ver"]: sys.exit("already realigned")
for l in B["lots"]:
    l[1], l[2] = fix(l[1], l[2])
for t in B.get("towns", []):
    t["x"], t["z"] = fix(t["x"], t["z"])
B["ver"] += "+geo1"
json.dump(B, open(ROOT + "buildings.json", "w"), separators=(",", ":"))
def walk(o):
    """every [x, z] pair, and every [x, z, yaw, w, d] box, in a servo or yard entry"""
    if isinstance(o, list):
        if len(o) >= 2 and all(isinstance(v, (int, float)) for v in o[:2]) and len(o) in (2, 5, 6) and all(isinstance(v, (int, float)) for v in o):
            o[0], o[1] = fix(o[0], o[1]); return
        for v in o: walk(v)
    elif isinstance(o, dict):
        for k, v in o.items():
            if k in ("shop", "area", "canopies", "c", "poly", "pumps", "sign"): walk(v)
S = json.load(open(ROOT + "servos.json"))
for s in S["servos"]: walk(s)
S["v"] = int(S.get("v", 1)) + 1
json.dump(S, open(ROOT + "servos.json", "w"), indent=1)
Y = json.load(open(ROOT + "yards.json"))
for k in [k for k in Y if isinstance(Y[k], list)]:
    for y in Y[k]: walk(y)
json.dump(Y, open(ROOT + "yards.json", "w"), indent=1)
print("realigned", len(B["lots"]), "lots,", len(S["servos"]), "servos,", sum(len(v) for v in Y.values() if isinstance(v, list)), "yards")
