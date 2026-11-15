#!/usr/bin/env python3
"""Real building footprints (0.2.48). Every roof in the valley from Overture Maps' buildings (OpenStreetMap merged with
Microsoft's satellite-traced footprints, with height estimates), downloaded once with
  overturemaps download --bbox=153.312,-28.465,153.639,-28.175 -f geojsonseq --type=building -o <file>
and kept gzipped in docs/ref/2026/overture_buildings.geojsonl.gz. Each footprint becomes a lot at its real place: the
fitted rectangle, turned so its front faces the nearest street, storeys from the height (3 m a storey).

What each roof is:
  - an existing named lot sitting on it (shop, school, pub, club, church, motel, hospital, police, fire, post,
    workshop, warehouse, tower) keeps its kind and name and takes the footprint's size and place
  - the hand-made places stay as they are and footprints under them are dropped: the malls, the servos (and their
    forecourts), the Pearl Street block
  - otherwise from what OSM calls it if it says, else from size, height and the neighbourhood:
      under 18 m2: left out (tanks, carports); 18-50 m2: a garden shed or garage
      50-450 m2 with neighbours: a house (2 storeys -> two_storey, 3+ -> a block of units); out in the country a
        house, or a farm shed if it's big
      over 450 m2: 3+ storeys -> a tower of units; among big buildings -> warehouse; in the country -> machine shed;
        near the shops -> a shop; otherwise a block of units
  - houses take the kind (qlder / cottage / brick) most common among the old lots round them, so a street keeps
    its era; Buildings._house_styles then adds the beach shacks, 70s units and estates again
Writes assets/world/buildings.json with a new version (cupboards and boards start fresh once).
  python3 tools/import_footprints.py
"""
import sys; sys.path.insert(0, "/home/claude/game/tools"); import geo
import gzip, json, math, collections, os, random
import numpy as np, cv2
from scipy.spatial import cKDTree

ROOT = "/home/claude/game"
SRC = ROOT + "/docs/ref/2026/overture_buildings.geojsonl.gz"
LAT0 = -28.3285718; LON0 = 153.4035024
KX = 111320 * math.cos(math.radians(LAT0)); KZ = 110574
HOUSES = ("qlder", "brick", "cottage", "two_storey")
NAMED = ("shop", "school", "pub", "club", "church", "motel", "hospital", "police", "fire", "post", "workshop", "warehouse", "tower")

B = json.load(open(ROOT + "/assets/world/buildings.json"))
old = B["lots"]
servos = json.load(open(ROOT + "/assets/world/servos.json"))["servos"]

def lot_poly(l, pad=0.0):
    b = float(l[3]); c, s = math.cos(b), math.sin(b)
    hw, hd = float(l[4]) / 2 + pad, float(l[5]) / 2 + pad
    pts = []
    for lx, lz in ((-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)):
        # Basis(UP, yaw) * (lx, 0, lz) = (lx cos + lz sin, -lx sin + lz cos)
        pts.append((l[1] + lx * c + lz * s, l[2] - lx * s + lz * c))
    return np.array(pts, np.float32)

# the hand-made places: kept, and nothing else built over them
keep_polys = []
kept = []
for l in old:
    sub = str(l[7]) if len(l) > 7 else ""
    if l[0] == "mall" or sub.startswith("servo/") or sub == "5g":
        kept.append(l); keep_polys.append(lot_poly(l, 4.0 if l[0] == "mall" else 1.0))
for e in servos:
    keep_polys.append(np.array(e["area"], np.float32))
def in_kept(p):
    return any(cv2.pointPolygonTest(q, (float(p[0]), float(p[1])), False) >= 0 for q in keep_polys)

# old lots by position: named ones lend their identity; house kinds give each area its era
named = [l for l in old if l[0] in NAMED and l not in kept]
named_t = cKDTree(np.array([[l[1], l[2]] for l in named])) if named else None
house_old = [l for l in old if l[0] in HOUSES and not (len(l) > 7 and str(l[7]) == "units70")]
house_t = cKDTree(np.array([[l[1], l[2]] for l in house_old]))
shops_t = cKDTree(np.array([[l[1], l[2]] for l in old if l[0] == "shop"]))

# streets: points every 4 m along every road, to face each building to its street
rg = json.load(open(ROOT + "/assets/roads/rg_graph.json"))
rp = []
for e in rg["edges"]:
    pts = e["pts"]
    for a, b in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(b[0] - a[0], b[2] - a[2]) / 4.0))
        for k in range(n):
            t = k / n
            rp.append((a[0] + (b[0] - a[0]) * t, a[2] + (b[2] - a[2]) * t))
road_t = cKDTree(np.array(rp))
# the same points with the street's half width, to keep buildings off the streets
rp2 = []; rhw = []
for e in rg["edges"]:
    hw = float(e.get("lane_w") or 3.2) * (1.0 if e["cls"] in ("living_street",) else 1.0) * (2 if e["cls"] not in ("motorway", "motorway_link", "trunk", "trunk_link") else 1)
    hw = hw * 0.5 + (0.5 if e["cls"] in ("motorway", "motorway_link", "trunk") else 0.0)
    pts = e["pts"]
    for a, b in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(b[0] - a[0], b[2] - a[2]) / 1.5))
        for k in range(n):
            t = k / n
            rp2.append((a[0] + (b[0] - a[0]) * t, a[2] + (b[2] - a[2]) * t)); rhw.append(hw)
road2_t = cKDTree(np.array(rp2)); rhw = np.array(rhw)
def worst(cx, cz, yaw, w, d):
    c, s = math.cos(yaw), math.sin(yaw); best = (99.0, 0.0, 0.0)
    for fx in (-1, -0.33, 0.33, 1):
        for fz in (-1, -0.33, 0.33, 1):
            if abs(fx) < 0.9 and abs(fz) < 0.9: continue
            lx, lz = fx * w / 2, fz * d / 2
            x, z = cx + lx * c + lz * s, cz - lx * s + lz * c
            dd, i = road2_t.query((x, z))
            g = dd - rhw[i]
            if g < best[0]: best = (g, rp2[i][0] - x, rp2[i][1] - z)
    return best

# ---- read the footprints
fps = []
for line in gzip.open(SRC, "rt"):
    g = json.loads(line)
    geom = g["geometry"]
    ring = geom["coordinates"][0] if geom["type"] == "Polygon" else max((p[0] for p in geom["coordinates"]), key=len)
    pts = np.array([geo.ll(lon, lat) for lon, lat in ring], np.float32)
    cx, cz = pts.mean(0)
    if not (-8960 < cx < 23040 and -16960 < cz < 15040): continue
    area = abs(cv2.contourArea(pts))
    if area < 18.0: continue
    p = g["properties"]
    h = p.get("height") or 0.0
    fl = p.get("num_floors") or 0
    # the satellite heights sit low (most houses 2-4 m): under 5 m one storey, under 8 m two, then 3 m a storey
    hh = float(h or 0.0)
    storeys = int(fl) if fl else (1 if hh < 5.0 else (2 if hh < 8.0 else int(hh / 3.0)))
    (rx, rz), (w, d), ang = cv2.minAreaRect(pts)
    fps.append({"pts": pts, "c": (float(rx), float(rz)), "w": float(w), "d": float(d), "yaw": -math.radians(ang), "area": float(area),
                "s": storeys, "cls": (p.get("class") or p.get("subtype") or ""), "id": str(p.get("id", ""))})
print("footprints in the map:", len(fps))
fp_t = cKDTree(np.array([f["c"] for f in fps]))
areas = np.array([f["area"] for f in fps])

def face(f):
    """turn the fitted rectangle so its front (+z) faces the nearest street; returns yaw, w (across the front), d"""
    dd, i = road_t.query(f["c"])
    ux, uz = rp[i][0] - f["c"][0], rp[i][1] - f["c"][1]
    best = None
    for k in range(4):
        yaw = f["yaw"] + k * math.pi / 2
        dot = math.sin(yaw) * ux + math.cos(yaw) * uz
        if best is None or dot > best[0]: best = (dot, yaw, k)
    _, yaw, k = best
    w, d = (f["w"], f["d"]) if k % 2 == 0 else (f["d"], f["w"])
    return math.atan2(math.sin(yaw), math.cos(yaw)), w, d, dd

OSM_KIND = {"house": "house", "detached": "house", "residential": "house", "semidetached_house": "house", "terrace": "house", "bungalow": "house",
            "apartments": "units", "retail": "shop", "commercial": "shop", "supermarket": "shop", "kiosk": "shop",
            "industrial": "warehouse", "warehouse": "warehouse", "manufacture": "warehouse",
            "shed": "shed", "garage": "shed", "garages": "shed", "carport": None, "roof": None, "farm_auxiliary": "shed", "barn": "machine_shed",
            "shelter": None, "hut": "shed", "cabin": "cottage", "school": "school", "church": "church", "hospital": "hospital"}

def house_kind(c, area):
    near = house_t.query_ball_point(c, 90.0)
    if near:
        k = collections.Counter(house_old[j][0] for j in near if house_old[j][0] != "two_storey").most_common(1)
        if k: return k[0][0]
    return "brick" if area > 220 else "qlder"

lots = list(kept)
used_named = set()
stats = collections.Counter()
for f in fps:
    c = f["c"]
    if in_kept(c): stats["under a hand-made place"] += 1; continue
    yaw, w, d, road_d = face(f)
    seed = float(abs(hash(f["id"] or c)) % 100000)
    kind = None; sub = None
    # a named lot standing on this roof keeps its identity
    if named_t is not None:
        for j in named_t.query_ball_point(c, max(6.0, math.sqrt(f["area"]) * 0.6)):
            if j in used_named: continue
            if cv2.pointPolygonTest(f["pts"], (float(named[j][1]), float(named[j][2])), True) > -4.0:
                used_named.add(j); kind = named[j][0]; sub = named[j][7] if len(named[j]) > 7 else None
                if kind == "tower" and f["s"] >= 4: sub = str(f["s"])
                break
    n100 = len(fp_t.query_ball_point(c, 100.0)) - 1
    near_i = fp_t.query_ball_point(c, 120.0)
    med = float(np.median(areas[near_i])) if near_i else 0.0
    a = f["area"]; s = f["s"]
    if kind is None:
        k = OSM_KIND.get(f["cls"], "?") if f["cls"] else "?"
        if k is None: stats["left out (carport, roof, shelter)"] += 1; continue
        if k == "?":
            if a < 50: k = "shed"
            elif a <= 450: k = "house" if (n100 >= 3 or a < 200) else "machine_shed"
            elif s >= 4: k = "units"
            elif med > 400: k = "warehouse"
            elif n100 < 4: k = "machine_shed"
            elif shops_t.query(c)[0] < 250: k = "shop"
            else: k = "units"
        if k == "house":
            if s >= 4: k = "units"
            elif s >= 2: kind = "two_storey"
            else: kind = house_kind(c, a)
        if k == "units":
            if s >= 4: kind = "tower"; sub = str(min(s, 24))
            else: kind = "two_storey"
        elif k == "shed": kind = "shed" if a < 150 else "machine_shed"
        elif kind is None: kind = k
    # sizes the generators handle: houses up to 22 x 18, the rest as traced
    if kind in HOUSES: w = min(max(w, 7.0), 22.0); d = min(max(d, 7.0), 18.0)
    if kind == "shed": w = max(w, 2.5); d = max(d, 2.5)
    # off the streets: nudge away from a street it overlaps (up to 4 m), else leave it out (named places stay)
    cx, cz = c
    for _it in range(8):
        g, vx, vz = worst(cx, cz, yaw, w, d)
        if g >= 0.3: break
        n = math.hypot(vx, vz) or 1.0
        cx -= vx / n * 0.5; cz -= vz / n * 0.5
    moved = math.hypot(cx - c[0], cz - c[1])
    if worst(cx, cz, yaw, w, d)[0] < 0.3 or moved > 4.01:
        if kind not in NAMED: stats["left out: on a street"] += 1; continue
        cx, cz = c
    elif moved > 0.01: stats["nudged off a street"] += 1
    c = (cx, cz)
    l = [kind, round(c[0], 2), round(c[1], 2), round(yaw, 4), round(w, 2), round(d, 2), seed]
    if sub: l.append(sub)
    lots.append(l)
    stats[kind] += 1
# named lots that no footprint stood on stay where they were (OSM placed them)
for j, l in enumerate(named):
    if j not in used_named and not in_kept((l[1], l[2])):
        lots.append(l); stats["named, kept where it was"] += 1
B["lots"] = lots
B["ver"] = "fp1-overture-2026"
json.dump(B, open(ROOT + "/assets/world/buildings.json", "w"), separators=(",", ":"))
print("lots:", len(lots))
for k, v in stats.most_common(): print("  ", k, v)
