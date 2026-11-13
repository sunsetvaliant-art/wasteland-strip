#!/usr/bin/env python3
"""Buildings for the country north of the old map edge, from data/north/bld.json (OSM) and data/north/ms.json (Microsoft
footprints), onto the end of assets/world/buildings.json. Run after place_buildings.py (which calls it) and before
add_malls.py. Everything already listed north of the edge (bar the malls) is replaced."""
import json, math, os, hashlib, struct
import numpy as np
from matplotlib.path import Path
from scipy.ndimage import map_coordinates
GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
Z0 = -16960.0
rng = np.random.default_rng(1947)
D = json.load(open(f"{GAME}/data/north/bld.json"))
MS = json.load(open(f"{GAME}/data/north/ms.json"))
with open(f"{GAME}/assets/world/north_h.bin", "rb") as f:
    XA, ZN, W, Hn, SP = struct.unpack("<ffIIf", f.read(20))
    HH = (np.frombuffer(f.read(), "<u2").reshape(Hn, W).astype(np.float64) - 1000) / 100
def hat(x, z): return float(map_coordinates(HH, [[(z - ZN) / SP], [(x - XA) / SP]], order=1, mode="nearest")[0])
# road segments on a grid
SEG = []
for P, hs, kd in D["roads"]:
    for i in range(len(P) - 1):
        SEG.append((P[i][0], P[i][1], P[i + 1][0], P[i + 1][1], hs, kd == "service"))
SEG = np.array(SEG, float)
grid = {}
for i, s in enumerate(SEG):
    for gx_ in range(int(min(s[0], s[2]) // 60) - 1, int(max(s[0], s[2]) // 60) + 2):
        for gz_ in range(int(min(s[1], s[3]) // 60) - 1, int(max(s[1], s[3]) // 60) + 2):
            grid.setdefault((gx_, gz_), []).append(i)
def road(x, z, service=False):
    ids = [i for i in grid.get((int(x // 60), int(z // 60)), []) if service or not SEG[i][5]]
    if not ids: return 1e9, 1.0, 0.0, x, z
    s = SEG[ids]
    dx, dz = s[:, 2] - s[:, 0], s[:, 3] - s[:, 1]
    L2 = np.maximum(dx * dx + dz * dz, 1e-6)
    t = np.clip(((x - s[:, 0]) * dx + (z - s[:, 1]) * dz) / L2, 0, 1)
    px, pz = s[:, 0] + dx * t, s[:, 1] + dz * t
    d = np.hypot(px - x, pz - z) - s[:, 4]
    k = int(np.argmin(d)); L = math.sqrt(L2[k])
    return float(d[k]), float(dx[k] / L), float(dz[k] / L), float(px[k]), float(pz[k])
def min_rect(pts):
    P = np.array(pts[:-1] if pts[0] == pts[-1] else pts, float)
    c = P.mean(0); best = None
    for i in range(len(P)):
        e = P[(i + 1) % len(P)] - P[i]
        if np.hypot(*e) < 0.5: continue
        a = math.atan2(e[1], e[0]); ca, sa = math.cos(a), math.sin(a)
        u = (P - c) @ np.array([ca, sa]); v = (P - c) @ np.array([-sa, ca])
        ar = (u.max() - u.min()) * (v.max() - v.min())
        if best is None or ar < best[0]:
            cc = c + np.array([ca, sa]) * (u.max() + u.min()) / 2 + np.array([-sa, ca]) * (v.max() + v.min()) / 2
            best = (ar, cc, a, u.max() - u.min(), v.max() - v.min())
    return best
def corners(x, z, yaw, w, d, pad=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    return [(x + lx * c + lz * s, z - lx * s + lz * c) for lx, lz in ((-w / 2 - pad, -d / 2 - pad), (w / 2 + pad, -d / 2 - pad), (w / 2 + pad, d / 2 + pad), (-w / 2 - pad, d / 2 + pad))]
FIT = {"qlder": ((8.5, 16), (7.5, 14)), "cottage": ((7, 12), (6, 11)), "brick": ((8.5, 19), (7.5, 15)), "two_storey": ((8.5, 15), (8, 13)),
       "pub": ((12, 30), (10, 22)), "school": ((14, 44), (10, 20)), "church": ((7, 14), (10, 26)), "hospital": ((14, 44), (10, 22)), "police": ((9, 24), (9, 16)),
       "fire": ((10, 22), (8, 16)), "post": ((7, 16), (7, 16)), "motel": ((14, 46), (6.5, 9)), "club": ((10, 30), (10, 26)),
       "shed": ((3, 6), (3, 6)), "warehouse": ((15, 70), (15, 90)), "tower": ((16, 34), (14, 30))}
lots = []; lg = {}; towers = []
def overlaps(x, z, yaw, w, d):
    me = Path(np.array(corners(x, z, yaw, w, d, 0.5)))
    for j in lg.get((int(x // 40), int(z // 40)), []) + [j for dx in (-1, 0, 1) for dz in (-1, 0, 1) if (dx or dz) for j in lg.get((int(x // 40) + dx, int(z // 40) + dz), [])]:
        o = lots[j]
        oc = corners(o[1], o[2], o[3], o[4], o[5])
        if me.contains_points(oc).any() or Path(np.array(oc)).contains_points(corners(x, z, yaw, w, d, 0.5)).any() or me.contains_point((o[1], o[2])): return True
    return False
stats = {}
def put(kind, pts, tag=""):
    r = min_rect(pts)
    if r is None: return
    area, c, a, la, lb = r
    cx, cz = float(c[0]), float(c[1])
    if cz > Z0 - 6 or hat(cx, cz) < 0.7: return
    ux, uz = math.cos(a), math.sin(a); vx, vz = -uz, ux
    rd, tx, tz, px, pz = road(cx, cz)
    fx, fz = px - cx, pz - cz
    if abs(fx * ux + fz * uz) > abs(fx * vx + fz * vz): f, w, d = ((ux, uz) if fx * ux + fz * uz > 0 else (-ux, -uz)), lb, la
    else: f, w, d = ((vx, vz) if fx * vx + fz * vz > 0 else (-vx, -vz)), la, lb
    if rd < 45:
        b = max(((tx, tz), (-tx, -tz), (-tz, tx), (tz, -tx)), key=lambda q: q[0] * f[0] + q[1] * f[1])
        if b[0] * f[0] + b[1] * f[1] > 0.82: f = b
    (wa, wb), (da, db) = FIT[kind]
    w2 = min(max(w, wa), wb); d2 = min(max(d, da), db)
    yaw = math.atan2(f[0], f[1])
    for _ in range(4):
        worst = min((road(q[0], q[1]) for q in corners(cx, cz, yaw, w2, d2) + [(cx, cz)]), key=lambda q: q[0])
        if worst[0] >= 2.2: break
        nx, nz = -worst[2], worst[1]
        if (cx - worst[3]) * nx + (cz - worst[4]) * nz < 0: nx, nz = -nx, -nz
        cx += nx * (2.6 - worst[0]); cz += nz * (2.6 - worst[0])
    if min(road(q[0], q[1])[0] for q in corners(cx, cz, yaw, w2, d2) + [(cx, cz)]) < 1.5: stats["road"] = stats.get("road", 0) + 1; return
    hs = [hat(q[0], q[1]) for q in corners(cx, cz, yaw, w2, d2)]
    if min(hs) < 0.6 or max(hs) - min(hs) > 9: stats["site"] = stats.get("site", 0) + 1; return
    if kind in ("brick", "cottage") and max(hs) - min(hs) > 3: kind = "qlder"
    if overlaps(cx, cz, yaw, w2, d2): stats["overlap"] = stats.get("overlap", 0) + 1; return
    j = len(lots)
    lots.append([kind, round(cx, 2), round(cz, 2), round(yaw, 4), round(w2, 2), round(d2, 2), int(rng.integers(1, 2**31 - 1))] + ([tag] if tag else []))
    lg.setdefault((int(cx // 40), int(cz // 40)), []).append(j)
    stats[kind] = stats.get(kind, 0) + 1
def house(area, h):
    r = rng.random()
    if h >= 6.2: return "two_storey"
    return "qlder" if r < 0.3 else ("cottage" if r < 0.5 else "brick")
osm_paths = []
mall = None
for b in D["b"]:
    r = min_rect(b["pts"])
    if r is None: continue
    area = r[0]
    osm_paths.append(Path(np.array(b["pts"])))
    t = b["tag"]
    if "Mall" in b["name"] and area > 3000: mall = (b["name"], r); continue
    if t in ("roof", "carport", "shed", "shelter", "construction", "garage", "garages", "toilets", "hut") or area < 30: continue
    try: lv = int(float(b["levels"])) if b["levels"] else 0
    except ValueError: lv = 0
    am = b["amenity"]; nm = b["name"].lower(); civic = None
    if am in ("pub", "bar") or ("hotel" in nm and area < 1500): civic = "pub"
    elif am in ("school", "kindergarten", "college", "university") or t in ("school", "kindergarten", "college", "university"): civic = "school"
    elif am == "place_of_worship" or t in ("church", "chapel") or b["religion"]: civic = "church"
    elif am in ("hospital", "clinic", "doctors") or t in ("hospital", "clinic") or "ambulance" in nm: civic = "hospital"
    elif am == "police" or "police" in nm: civic = "police"
    elif am == "fire_station" or "fire" in nm and "service" in nm: civic = "fire"
    elif am == "post_office": civic = "post"
    elif (t == "motel" or "motel" in nm or "motor inn" in nm) and lv < 3: civic = "motel"
    elif am in ("community_centre", "social_club") or any(k_ in nm for k_ in ("rsl", "bowls", "services club", "surf club", "surf life saving", "sports club", "pavillion", "pavilion", "marine rescue")): civic = "club"
    if civic and area >= 60 and not (civic == "school" and lv >= 5): put(civic, b["pts"])
    elif t in ("warehouse", "hangar", "industrial"): put("warehouse", b["pts"])
    elif lv >= 5 or (t in ("apartments", "hotel") and area > 450) or b["tourism"] in ("hotel", "motel", "apartment"):
        towers.append({"name": b["name"], "levels": lv, "c": [float(r[1][0]), float(r[1][1])], "area": area})
        put("tower", b["pts"], "%d" % (lv if lv >= 3 else int(rng.integers(6, 13))))
    elif area > 360: put("brick", b["pts"])
    else: put(house(area, lv * 3.0), b["pts"])
for m in MS:
    r = min_rect(m["pts"])
    if r is None: continue
    area, c = r[0], r[1]
    if any(p.contains_point((c[0], c[1])) for p in osm_paths[::1] if abs(p.vertices[0][0] - c[0]) < 150 and abs(p.vertices[0][1] - c[1]) < 150): continue
    h = float(m.get("h", -1) or -1)
    if area < 45:
        if area > 12 and road(c[0], c[1])[0] > 16 and rng.random() < 0.35: put("shed", m["pts"])
        continue
    if h >= 14 and area > 300: put("tower", m["pts"], "%d" % int(min(max(round(h / 3.0), 5), 14)))
    elif area > 420: put("two_storey" if rng.random() < 0.5 else "brick", m["pts"])
    else: put(house(area, h), m["pts"])
print("north lots", len(lots), stats, "towers", len([l for l in lots if l[0] == "tower"]))
if mall: print("MALL", mall[0], "centre", mall[1][1].round(1), "angle", round(mall[1][2], 3), "size", round(mall[1][3], 1), round(mall[1][4], 1))
f = f"{GAME}/assets/world/buildings.json"
d = json.load(open(f))
keep = [l for l in d["lots"] if not (l[2] < Z0 - 2.0 and l[0] != "mall")]
d["lots"] = keep + lots
d["ver"] = hashlib.md5(json.dumps(d["lots"], separators=(",", ":")).encode()).hexdigest()[:12]
json.dump(d, open(f, "w"), separators=(",", ":"))
print("lots", len(d["lots"]))
