#!/usr/bin/env python3
"""0.2.51: the real pubs and motels, by name, where Overture Maps says they are.
The pub generator (CivicGen "pub": public bar under a verandah, lounge, kitchen, cool room; ShopGen's two-storey
"pub" shop front on a main street) was only used for the two pubs OpenStreetMap had as buildings. Now every hotel and
tavern in the places data gets one: on a main street (the roof is a shop, or shops all round) it's the two-storey shop
pub with its name; anywhere else (a tavern on its own block, by the water) it's the CivicGen pub with its name over
the door. Motels (motel / motor inn) the same way with CivicGen's motel. Run after tools/realign.py (uses geo.ll)."""
import gzip, json, math, re, sys
sys.path.insert(0, "/home/claude/game/tools")
import geo
from shapely.geometry import Polygon, Point
from shapely.strtree import STRtree
ROOT = "/home/claude/game/"
B = json.load(open(ROOT + "assets/world/buildings.json"))
L = B["lots"]
if "+pubs1" in B["ver"]: sys.exit("already placed")
def poly(l):
    x, z, y, w, d = l[1:6]; c, s = math.cos(y), math.sin(y)
    return Polygon([(x + c * lx + s * lz, z - s * lx + c * lz) for lx, lz in ((-w/2, -d/2), (w/2, -d/2), (w/2, d/2), (-w/2, d/2))])
P = [poly(l) for l in L]
T = STRtree(P)
def sub(l): return str(l[7]) if len(l) > 7 else ""
SKIP = ("mall", "school", "church", "hospital", "police", "fire", "post", "club", "tower")
def usable(l):
    s = sub(l)
    return l[0] not in SKIP and ":" not in s and not s.startswith(("servo/", "hardware", "5g")) and len(s.split("/")) <= 3
NOT_PUB = ("MOTEL", "MOTOR INN", "APARTMENT", "RESORT", "RETREAT", "COTTAGE", "VILLA", "CARAVAN", "HOLIDAY", "BNB", "LODGE")
places = {"pub": [], "motel": []}
for line in gzip.open(ROOT + "docs/ref/2026/overture_places.geojsonl.gz", "rt"):
    g = json.loads(line); pr = g["properties"]
    nm = ((pr.get("names") or {}).get("primary") or "").strip()
    up = nm.upper(); cat = pr.get("basic_category") or ""
    conf = pr.get("confidence", 0) or 0
    if conf < 0.6 or g["geometry"]["type"] != "Point": continue
    lon, lat = g["geometry"]["coordinates"][:2]
    x, z = geo.ll(lon, lat)
    if "HAVEN BAR" in up: continue      # its point sits on the Tweed River Motel, 3 km out of town
    if (" HOTEL" in " " + up or re.search(r"\bTAVERN\b", up) or up.startswith("IVORY")) and not any(k in up for k in NOT_PUB) and cat in ("bar", "hotel", "casual_eatery", "gaming_venue", "pub", "restaurant", "sports_and_recreation"):
        # "Haven Bar Murwillumbah Hotel" -> MURWILLUMBAH HOTEL; "Ivory Waterside" / "Ivory Tavern, Tweed Heads" -> IVORY TAVERN
        n = up.split(",")[0]
        if n.startswith("IVORY"): n = "IVORY TAVERN"
        places["pub"].append({"n": n, "x": x, "z": z, "c": conf})
    elif cat == "hotel" and ("MOTEL" in up or "MOTOR INN" in up):
        places["motel"].append({"n": up.split(" - ")[0][:28], "x": x, "z": z, "c": conf})
stats = {"pubs": 0, "main-street pubs": 0, "motels": 0, "no building": 0, "duplicates": 0}
done = []; used = set()
for kind in ("pub", "motel"):
    for p in sorted(places[kind], key=lambda q: -q["c"]):
        # one of each name (the best-placed), and not two of a kind on one corner
        if any(p["n"] == q[2] or (math.hypot(p["x"] - q[0], p["z"] - q[1]) < 90 and kind == q[3]) for q in done):
            stats["duplicates"] += 1; continue
        pt = Point(p["x"], p["z"])
        best = None
        for j in T.query(pt.buffer(60)):
            j = int(j); l = L[j]
            if j in used or not usable(l): continue
            a = l[4] * l[5]
            if a < (90 if kind == "pub" else 120): continue
            dd = P[j].distance(pt)
            if dd > 45: continue
            score = dd - min(a, 1500) / 120.0          # nearest, but a bigger roof wins a close call (pubs are big)
            if best is None or score < best[0]: best = (score, j)
        if best is None: stats["no building"] += 1; print("  no building for", kind, p["n"]); continue
        j = best[1]; l = L[j]
        shops = sum(1 for k in T.query(pt.buffer(70)) if L[int(k)][0] == "shop")
        if kind == "pub" and (l[0] == "shop" or shops >= 4) and l[4] <= 30:
            L[j] = ["shop"] + l[1:7] + ["pub/2/3.0/" + p["n"][:26]]; stats["main-street pubs"] += 1
        else:
            L[j] = [kind] + l[1:7] + [p["n"][:28]]
            stats["pubs" if kind == "pub" else "motels"] += 1
        done.append((p["x"], p["z"], p["n"], kind)); used.add(j)
        print("  %-6s %-28s -> %s (%.0f, %.0f) %.0fx%.0f" % (kind, p["n"], L[j][0], l[1], l[2], l[4], l[5]))
B["ver"] += "+pubs1"
json.dump(B, open(ROOT + "assets/world/buildings.json", "w"), separators=(",", ":"))
print(stats)
