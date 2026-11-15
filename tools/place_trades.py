#!/usr/bin/env python3
"""Hardware stores, car parts stores, mechanics and tyre shops, wreckers and caravan parks (0.2.49), from Overture Maps
places (docs/ref/2026/overture_places.geojsonl.gz, downloaded with
  overturemaps download --bbox=153.312,-28.465,153.639,-28.175 -f geojsonseq --type=place -o <file>)
put onto the real footprints in assets/world/buildings.json (run tools/import_footprints.py first):
  hardware:  Bunnings and the like (big roofs) -> warehouse "hardware:<NAME>" (racking in rows, checkouts, a
             timber yard); main street ones -> shop "hardware/<storeys>/0/<NAME>" (Mitre 10 Murwillumbah: 2 storeys)
  parts:     Repco, Supercheap, Autobarn, Burson, Auto One -> workshop "parts:<NAME>"
  mechanics: automotive services (mechanics, tyres, smash repairs, auto electricians) -> workshop "mech:<NAME>" /
             "tyres:<NAME>"
  wreckers:  a fenced yard of wrecked cars beside the wrecker's shed (assets/world/yards.json, built by YardGen);
             houses and sheds inside the yard go, the biggest shed in it becomes the office and parts shed
  caravan parks: the park's outline from its cluster of cabins round the place (yards.json); small roofs inside
             become cabins, the park gets its internal road, caravans in the sites, the office by the gate
  python3 tools/place_trades.py
"""
import sys; sys.path.insert(0, "/home/claude/game/tools"); import geo
import gzip, json, math, collections
import numpy as np, cv2
from shapely.geometry import Polygon, Point
from scipy.spatial import cKDTree

ROOT = "/home/claude/game"
LAT0 = -28.3285718; LON0 = 153.4035024
KX = 111320 * math.cos(math.radians(LAT0)); KZ = 110574
import os
B = json.load(open(os.environ.get("LOTS_IN", ROOT + "/assets/world/buildings.json")))
L = B["lots"]
servos = json.load(open(ROOT + "/assets/world/servos.json"))["servos"]
rg = json.load(open(ROOT + "/assets/roads/rg_graph.json"))
rp = []
for e in rg["edges"]:
    P = e["pts"]
    for a, b in zip(P, P[1:]):
        n = max(1, int(math.hypot(b[0] - a[0], b[2] - a[2]) / 3.0))
        for k in range(n):
            t = k / n; rp.append((a[0] + (b[0] - a[0]) * t, a[2] + (b[2] - a[2]) * t))
road_t = cKDTree(np.array(rp))

places = []
for line in gzip.open(ROOT + "/docs/ref/2026/overture_places.geojsonl.gz", "rt"):
    g = json.loads(line); p = g["properties"]
    nm = ((p.get("names") or {}).get("primary") or "").strip()
    cat = ((p.get("categories") or {}).get("primary") if isinstance(p.get("categories"), dict) else None) or p.get("basic_category") or ""
    lon, lat = g["geometry"]["coordinates"][:2]
    places.append({"n": nm, "cat": cat, "x": geo.ll(lon, lat)[0], "z": geo.ll(lon, lat)[1], "conf": p.get("confidence") or 0})

def poly(l, pad=0.0):
    b = float(l[3]); c, s = math.cos(b), math.sin(b); hw, hd = l[4] / 2 + pad, l[5] / 2 + pad
    return np.array([(l[1] + lx * c + lz * s, l[2] - lx * s + lz * c) for lx, lz in ((-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd))], np.float32)

def protected(l):
    return l[0] in ("mall", "tower") or (len(l) > 7 and str(l[7]).startswith(("servo/", "hardware", "parts:", "mech:", "tyres:", "wreckers:")))

lot_t = cKDTree(np.array([[l[1], l[2]] for l in L]))
def lot_at(x, z, min_area=0.0, r=30.0):
    """the lot whose footprint holds (x, z), else the nearest within r (biggest if several hold it)"""
    best = None
    for i in lot_t.query_ball_point((x, z), r + 70.0):
        l = L[i]
        if l is None or l[0] == "mall" or l[4] * l[5] < min_area: continue
        inside = cv2.pointPolygonTest(poly(l, 1.0), (float(x), float(z)), True)
        if inside < 0 and math.hypot(l[1] - x, l[2] - z) > r: continue
        key = (inside >= 0, l[4] * l[5] if inside >= 0 else -math.hypot(l[1] - x, l[2] - z))
        if best is None or key > best[0]: best = (key, i)
    return best[1] if best else None

def setsub(i, kind, sub):
    l = L[i]; l[0] = kind
    if len(l) > 7: l[7] = sub
    else: l.append(sub)

stats = collections.Counter()
up = lambda s: s.upper().replace("'", "")
# ---- hardware
for p in places:
    n = p["n"].lower()
    if not (("bunnings" in n) or ("mitre 10" in n) or ("true value" in n) or ("builders hardware" in n) or (n == "village hardware") or ("home hardware" in n)): continue
    i = lot_at(p["x"], p["z"], 60.0)
    if i is None: continue
    l = L[i]; a = l[4] * l[5]
    nm = "BUNNINGS" if "bunnings" in n else ("MITRE 10" if "mitre 10" in n else ("HOME HARDWARE" if "home" in n else up(p["n"])[:22]))
    if a >= 1500: setsub(i, "warehouse", "hardware:" + nm)
    else: setsub(i, "shop", "hardware/%d/0/%s" % (2 if "mitre 10" in n else 1, nm))
    stats["hardware " + nm] += 1
# ---- parts stores
for p in places:
    n = p["n"].lower()
    if not any(k in n for k in ("repco", "supercheap", "autobarn", "burson", "auto one")): continue
    i = lot_at(p["x"], p["z"], 60.0, 40.0)
    if i is None or protected(L[i]): continue
    nm = "REPCO" if "repco" in n else ("SUPERCHEAP AUTO" if "supercheap" in n else ("AUTOBARN" if "autobarn" in n else ("BURSONS" if "burson" in n else "AUTO ONE")))
    setsub(i, "workshop", "parts:" + nm); stats["parts store"] += 1
# ---- mechanics, tyre shops, smash repairs
for p in places:
    if p["cat"] != "automotive_service" or p["conf"] < 0.5: continue
    n = p["n"].lower()
    if any(k in n for k in ("wreck", "recycl", "wash", "detail", "tint", "ambulance", "storage", "marine", "boat", "mower", "signs", "glass")): continue
    i = lot_at(p["x"], p["z"], 60.0, 20.0)
    if i is None or protected(L[i]) or L[i][0] in ("shop", "school", "church", "pub", "club", "hospital", "police", "fire", "post", "motel"): continue
    kind = "tyres:" if any(k in n for k in ("tyre", "tire", "beaurepaires", "bridgestone", "goodyear", "michelin")) else "mech:"
    setsub(i, "workshop", kind + up(p["n"])[:26]); stats["mechanic" if kind == "mech:" else "tyre shop"] += 1

# ---- wreckers: a fenced yard beside the shed
yards = {"wreckers": [], "caravan": []}
def face_road(x, z):
    d, i = road_t.query((x, z)); ux, uz = rp[i][0] - x, rp[i][1] - z
    return math.atan2(ux, uz), d
seen = []
best_conf = {}
for p in places:
    if any(k in p["n"].lower() for k in ("wrecker", "metal recycl")): best_conf[p["n"]] = max(best_conf.get(p["n"], 0), p["conf"])
for p in places:
    n = p["n"].lower()
    if not any(k in n for k in ("wrecker", "metal recycl")): continue
    if p["conf"] < best_conf[p["n"]]: continue          # the same business listed twice: the surer one
    if any(math.hypot(p["x"] - s[0], p["z"] - s[1]) < 150 for s in seen): continue
    seen.append((p["x"], p["z"]))
    yaw, rd = face_road(p["x"], p["z"])
    # the yard: 60 x 45, front to the street. Try it behind the frontage at a few depths and along the street either
    # side, and take the spot that covers the fewest real buildings (houses and garden sheds may go; workshops,
    # warehouses, shops and named places may not) and no road
    fx, fz = math.sin(yaw), math.cos(yaw)
    best = None
    for back in (8.0, 14.0, 24.0, 36.0):
        for t in (0.0, -25.0, 25.0, -50.0, 50.0):
            dist = rd - back - 22.5
            cx = p["x"] + fx * dist + fz * t; cz = p["z"] + fz * dist - fx * t
            yp = Polygon(poly(["", cx, cz, yaw, 60.0, 45.0]))
            cost = abs(t) * 0.2 + abs(back - 8.0) * 0.3
            cost += 400.0 * len([1 for j in road_t.query_ball_point((cx, cz), 40.0) if yp.contains(Point(rp[j]))])
            for i in lot_t.query_ball_point((cx, cz), 110):
                l = L[i]
                if l is None: continue
                a2 = yp.intersection(Polygon(poly(l))).area
                if a2 <= 0: continue
                cost += a2 * (0.3 if l[0] in ("qlder", "brick", "cottage", "two_storey", "shed", "machine_shed") else 6.0)
            if best is None or cost < best[0]: best = (cost, cx, cz)
    cx, cz = best[1], best[2]
    y = {"name": up(p["n"])[:30], "c": [round(cx, 1), round(cz, 1)], "yaw": round(yaw, 4), "w": 60.0, "d": 45.0}
    yp = poly(["", cx, cz, yaw, 60.0, 45.0])
    ypp = Polygon(yp)
    shops_in = sum(1 for i in lot_t.query_ball_point((cx, cz), 60) if L[i] is not None and L[i][0] == "shop" and cv2.pointPolygonTest(yp, (float(L[i][1]), float(L[i][2])), False) >= 0)
    if shops_in >= 3: stats["wreckers skipped (in a shopping street: an office address)"] += 1; continue
    office = None
    for i in lot_t.query_ball_point((cx, cz), 110):
        l = L[i]
        if l is None or protected(l): continue
        lp = Polygon(poly(l))
        ov = ypp.intersection(lp).area
        if l[0] in ("workshop", "warehouse", "shed", "machine_shed") and l[4] * l[5] > 60 and ypp.distance(lp) < 12.0:
            # the wrecker's shed: the biggest one in or beside the yard
            if office is None or l[4] * l[5] > L[office][4] * L[office][5]: office = i
        elif ov > 0.2 * lp.area and l[0] not in ("school", "church", "club", "pub", "hospital", "police", "fire", "post", "motel", "shop", "workshop", "warehouse"):
            L[i] = None; stats["cleared for a wreckers yard"] += 1
    if office is not None: setsub(office, "workshop", "wreckers:" + y["name"])
    yards["wreckers"].append(y); stats["wreckers"] += 1

# ---- caravan parks: the cluster of small roofs (cabins, amenities) round the place
parkish = ("holiday park", "caravan park", "tourist park", "tourist retreat", "hacienda", "holiday village", "tourist caravan", "pyramid holiday", "north star")
notpark = ("clinic", "hire", "trailer", "storage", "suite", "sales", "repairs")
small = [i for i, l in enumerate(L) if l is not None and l[4] * l[5] < 110 and l[0] in ("shed", "cottage", "qlder", "brick", "two_storey")]
small_t = cKDTree(np.array([[L[i][1], L[i][2]] for i in small]))
seen = []
for p in places:
    n = p["n"].lower()
    if not (any(k in n for k in parkish) or (p["cat"] == "campground" and "holiday" in n)): continue
    if any(k in n for k in notpark): continue
    if any(math.hypot(p["x"] - s[0], p["z"] - s[1]) < 250 for s in seen): continue
    seen.append((p["x"], p["z"]))
    # grow from the nearest small roof: neighbours within 16 m, up to 220 m from the place
    d0, j0 = small_t.query((p["x"], p["z"]))
    if d0 > 90: stats["caravan park with no cabins found"] += 1; members = []
    else:
        members = {j0}; front = [j0]
        while front:
            j = front.pop()
            for k in small_t.query_ball_point((L[small[j]][1], L[small[j]][2]), 25.0):
                if k in members: continue
                if math.hypot(L[small[k]][1] - p["x"], L[small[k]][2] - p["z"]) > 220: continue
                members.add(k); front.append(k)
    pts = [(p["x"], p["z"])]
    for j in members:
        pts += [tuple(q) for q in poly(L[small[j]], 6.0)]
    pts = np.array(pts, np.float32)
    if len(members) < 4:
        # too few traced cabins (mostly vans on sites): a 90 x 70 park behind its road frontage
        yaw, rd = face_road(p["x"], p["z"])
        fx, fz = math.sin(yaw), math.cos(yaw)
        off = rd - 8.0 - 35.0
        hull = poly(["", p["x"] + fx * off, p["z"] + fz * off, yaw, 90.0, 70.0])
    else:
        hull = cv2.convexHull(pts).reshape(-1, 2)
    yaw, _ = face_road(float(hull[:, 0].mean()), float(hull[:, 1].mean()))
    # small roofs inside become cabins
    for i in lot_t.query_ball_point((float(hull[:, 0].mean()), float(hull[:, 1].mean())), 260):
        l = L[i]
        if l is None or protected(l) or l[4] * l[5] >= 110: continue
        if cv2.pointPolygonTest(hull.astype(np.float32), (float(l[1]), float(l[2])), False) >= 0 and l[0] in ("shed", "qlder", "brick", "cottage", "two_storey"):
            l[0] = "cottage"; l[4] = max(l[4], 6.0); l[5] = max(l[5], 5.0)
            if len(l) > 7: l[7] = "shack"
            else: l.append("shack")
            stats["cabins"] += 1
    yards["caravan"].append({"name": up(p["n"]).replace("TWEED HOLIDAY PARKS ", "")[:30], "poly": [[round(float(q[0]), 1), round(float(q[1]), 1)] for q in hull],
                             "yaw": round(yaw, 4)})
    stats["caravan parks"] += 1

B["lots"] = [l for l in L if l is not None]
B["ver"] += "+trades1"
json.dump(B, open(ROOT + "/assets/world/buildings.json", "w"), separators=(",", ":"))
json.dump({"v": 1, **yards}, open(ROOT + "/assets/world/yards.json", "w"), separators=(",", ":"))
for k, v in stats.most_common(): print("  ", k, v)
