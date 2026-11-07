#!/usr/bin/env python3
"""Where the generated buildings go (assets/world/buildings.json).
  - every OpenStreetMap building on the map, squared up (its smallest bounding rectangle), turned to face its nearest
    road, and given a kind from its tag, size and the land use it's in (house, shed, workshop, warehouse...);
  - the residential land use filled in along its streets where OSM has no buildings drawn: a house every 24-30 m each
    side, set back off the kerb on its block, with the odd empty block;
  - the industrial land use the same with workshops and warehouses;
  - farms along the back roads: a farmhouse well back off the road, with a shed or two and sometimes a dairy.
  Nothing on a road, in the river, on a cliff, on top of another building, or on the start square.
usage: place_buildings.py [osm_bld.json]   (osm_bld.json: buildings + land use cut from the OSM extract)"""
import json, math, sys
import numpy as np
from scipy.ndimage import map_coordinates
GAME = "/home/claude/game"
src = open(f"{GAME}/tools/bake_roads.py").read()
cut = src.index("# ------------------------------------------------------------------ bridge ends meet the road")
ns = {}; exec(src[:cut], ns)
roads = [r for r in ns["roads"] if not r["b"]]
SPEC = ns["SPEC"]
X0, Z0, SP, T = -8960.0, -16960.0, 5.0, 6401
H = np.fromfile(f"{GAME}/data/height_roads.r16", "<u2").reshape(T, T).astype(np.float32) / 65535 * 900 - 60
def hat(x, z): return map_coordinates(H, [np.atleast_1d((np.asarray(z) - Z0) / SP), np.atleast_1d((np.asarray(x) - X0) / SP)], order=1)
osm = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/bld/osm_bld.json"))
rng = np.random.default_rng(2611)
PUB = (4.4, 3.3)

# ---- roads as segments
S = []
for r in roads:
    P = r["P"]; hs = SPEC[r["k"]][0]
    for i in range(len(P) - 1): S.append((P[i, 0], P[i, 1], P[i + 1, 0], P[i + 1, 1], hs))
S = np.array(S)
ax, az, bx, bz, hs = S.T
dx, dz = bx - ax, bz - az; L2 = dx * dx + dz * dz + 1e-9
# a coarse grid of segment ids so "nearest road" doesn't scan 100k segments
G = 100.0
grid = {}
for i in range(len(S)):
    x0, x1 = sorted((ax[i], bx[i])); z0, z1 = sorted((az[i], bz[i]))
    for gx in range(int((x0 - X0) // G), int((x1 - X0) // G) + 1):
        for gz in range(int((z0 - Z0) // G), int((z1 - Z0) // G) + 1):
            grid.setdefault((gx, gz), []).append(i)
def near_ids(x, z, r):
    out = set()
    for gx in range(int((x - r - X0) // G), int((x + r - X0) // G) + 1):
        for gz in range(int((z - r - Z0) // G), int((z + r - Z0) // G) + 1):
            out.update(grid.get((gx, gz), ()))
    return np.fromiter(out, int) if out else np.zeros(0, int)
def road_dist(x, z, r=120.0):
    """distance from (x, z) to the nearest road edge, and that road's point and direction"""
    ids = near_ids(x, z, r)
    if len(ids) == 0: return 1e9, x, z, 1.0, 0.0
    t = np.clip(((x - ax[ids]) * dx[ids] + (z - az[ids]) * dz[ids]) / L2[ids], 0, 1)
    px = ax[ids] + dx[ids] * t; pz = az[ids] + dz[ids] * t
    d = np.hypot(px - x, pz - z) - hs[ids]
    k = int(np.argmin(d)); i = ids[k]; L = math.sqrt(L2[i])
    return float(d[k]), float(px[k]), float(pz[k]), float(dx[i] / L), float(dz[i] / L)

# ---- land use polygons (point-in-polygon by matplotlib's Path)
from matplotlib.path import Path
LU = {}
for l in osm["lu"]:
    LU.setdefault(l["lu"], []).append(Path(np.array(l["pts"])))
def in_lu(x, z, kinds):
    for k in kinds:
        for p in LU.get(k, []):
            if p.contains_point((x, z)): return True
    return False

# ---- what's been placed: oriented rectangles, with a grid for overlap tests
lots = []
lgrid = {}
def corners(x, z, yaw, w, d, pad=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    out = []
    for lx, lz in ((-w / 2 - pad, -d / 2 - pad), (w / 2 + pad, -d / 2 - pad), (w / 2 + pad, d / 2 + pad), (-w / 2 - pad, d / 2 + pad)):
        # Godot Basis(UP, yaw): local x -> (cos, 0, -sin), local z -> (sin, 0, cos)
        out.append((x + lx * c + lz * s, z - lx * s + lz * c))
    return out
def overlaps(x, z, yaw, w, d, pad):
    me = Path(np.array(corners(x, z, yaw, w, d, pad)))
    r = math.hypot(w, d) / 2 + pad
    for gx in range(int((x - r - X0) // 50) - 1, int((x + r - X0) // 50) + 2):
        for gz in range(int((z - r - Z0) // 50) - 1, int((z + r - Z0) // 50) + 2):
            for j in lgrid.get((gx, gz), ()):
                o = lots[j]
                if math.hypot(o[1] - x, o[2] - z) > r + math.hypot(o[4], o[5]) / 2 + 1: continue
                oc = corners(o[1], o[2], o[3], o[4], o[5])
                if me.contains_points(oc).any() or Path(np.array(oc)).contains_points(corners(x, z, yaw, w, d, pad)).any():
                    return True
                if me.contains_point((o[1], o[2])): return True
    return False
def add(kind, x, z, yaw, w, d, tag=""):
    j = len(lots)
    lots.append([kind, round(x, 2), round(z, 2), round(yaw, 4), round(w, 2), round(d, 2), int(rng.integers(1, 2**31 - 1))])
    r = math.hypot(w, d) / 2
    for gx in range(int((x - r - X0) // 50), int((x + r - X0) // 50) + 1):
        for gz in range(int((z - r - Z0) // 50), int((z + r - Z0) // 50) + 1):
            lgrid.setdefault((gx, gz), []).append(j)
def site_ok(x, z, yaw, w, d, road_clear=2.0, max_spread=3.0, min_h=2.0):
    if math.hypot(x - PUB[0], z - PUB[1]) < 30: return False
    cs = corners(x, z, yaw, w, d)
    hs_ = hat([c[0] for c in cs] + [x], [c[1] for c in cs] + [z])
    if hs_.min() < min_h or hs_.max() - hs_.min() > max_spread: return False
    for c in cs + [(x, z)]:
        if road_dist(c[0], c[1], 60.0)[0] < road_clear: return False
    return True

def house_kind(area, rural=False):
    r = rng.random()
    if rural: return "qlder" if r < 0.55 else ("cottage" if r < 0.85 else "brick")
    if area > 170 and r < 0.35: return "two_storey"
    return "qlder" if r < 0.33 else ("cottage" if r < 0.6 else ("brick" if r < 0.92 else "two_storey"))
HOUSE_DIMS = {"qlder": ((10, 14), (9, 12)), "cottage": ((8, 10.5), (7, 9.5)), "brick": ((11, 15), (9, 12)), "two_storey": ((10, 13), (9.5, 11.5))}
def clampdims(kind, w, d):
    if kind in HOUSE_DIMS:
        (a, b), (c, e) = HOUSE_DIMS[kind]
        return min(max(w, a), b), min(max(d, c), e)
    if kind == "shed": return min(max(w, 6), 18), min(max(d, 7), 30)
    if kind == "machine_shed": return min(max(w, 9), 24), min(max(d, 6), 12)
    if kind == "workshop": return min(max(w, 12), 30), min(max(d, 14), 40)
    if kind == "warehouse": return min(max(w, 20), 50), min(max(d, 24), 70)
    if kind == "dairy": return min(max(w, 12), 20), min(max(d, 7), 10)
    return w, d

# ---- 0. the service stations (Landmarks) hold their ground
for lm in json.load(open(f"{GAME}/assets/world/landmarks.json"))["landmarks"]:
    add("_lm", lm["x"], lm["z"], lm["yaw"], 20.0, 16.0)

# ---- 1. the buildings OSM has
def min_rect(pts):
    """smallest-area rectangle round a polygon: centre, the angle of its first side, length along it, across it"""
    P = np.array(pts)
    from scipy.spatial import ConvexHull
    try: hull = P[ConvexHull(P).vertices]
    except Exception: hull = P
    best = None
    for i in range(len(hull)):
        e = hull[(i + 1) % len(hull)] - hull[i]
        a = math.atan2(e[1], e[0])
        c, s = math.cos(a), math.sin(a)
        R = np.array([[c, s], [-s, c]])
        q = hull @ R.T
        mn, mx = q.min(0), q.max(0)
        area = (mx - mn).prod()
        if best is None or area < best[0]:
            ctr = ((mn + mx) / 2) @ R
            best = (area, ctr, a, mx[0] - mn[0], mx[1] - mn[1])
    return best
n_osm = 0
for b in osm["b"]:
    tag = b["tag"]
    if tag in ("toilets", "garage", "carport", "hut", "greenhouse", "ruins", "construction", "bunker", "kiosk"): continue
    area, ctr, a, la, lb = min_rect(b["pts"])
    if area < 25: continue
    cx, cz = float(ctr[0]), float(ctr[1])
    rd, px, pz, tx, tz = road_dist(cx, cz, 200.0)
    # front: the rectangle axis that points most at the road
    ux, uz = math.cos(a), math.sin(a)      # first axis (length la)
    vx, vz = -uz, ux                       # second axis (length lb)
    fx, fz = px - cx, pz - cz
    if abs(fx * ux + fz * uz) > abs(fx * vx + fz * vz):
        front = (ux, uz) if fx * ux + fz * uz > 0 else (-ux, -uz); w, d = lb, la
    else:
        front = (vx, vz) if fx * vx + fz * vz > 0 else (-vx, -vz); w, d = la, lb
    yaw = math.atan2(front[0], front[1])
    res = in_lu(cx, cz, ["residential"]); ind = in_lu(cx, cz, ["industrial"]); com = in_lu(cx, cz, ["retail", "commercial"])
    farm = in_lu(cx, cz, ["farmland", "farmyard", "orchard", "meadow"])
    if tag in ("house", "detached", "residential", "semidetached_house", "bungalow", "cabin", "terrace", "farm") or (tag == "yes" and res and area < 350):
        kind = house_kind(area, rural=farm)
    elif tag in ("shed", "barn", "farm_auxiliary", "stable", "cowshed"):
        kind = "shed" if area < 450 else "machine_shed"
    elif tag == "roof":
        kind = "machine_shed"
    elif tag in ("industrial", "warehouse", "manufacture") or ind:
        kind = "workshop" if area < 700 else "warehouse"
    elif tag in ("retail", "commercial", "office", "supermarket", "service") or com:
        kind = "brick" if area < 220 else ("workshop" if area < 900 else "warehouse")
    elif tag in ("school", "church", "hospital", "fire_station", "public", "civic", "kindergarten", "motel", "apartments", "hotel", "train_station"):
        kind = "brick" if area < 260 else "workshop"
    else:   # "yes" out in the country
        kind = "shed" if area < 70 else (house_kind(area, rural=True) if area < 260 else "machine_shed" if rng.random() < 0.4 else "shed")
    w, d = clampdims(kind, w, d)
    if overlaps(cx, cz, yaw, w, d, 0.5): continue
    if not site_ok(cx, cz, yaw, w, d, road_clear=0.5, max_spread=5.0 if kind == "qlder" else 4.0, min_h=0.5): continue
    add(kind, cx, cz, yaw, w, d); n_osm += 1
print("osm", n_osm)

# ---- 2. streets of houses in the residential land use, and workshops in the industrial
TOWN_C = [((lon - 153.4035024) * 111320 * math.cos(math.radians(-28.3285718)), -(lat + 28.3285718) * 110574) for lat, lon in
          [(-28.3267617, 153.3971541), (-28.332413, 153.4004688), (-28.3114787, 153.4351183), (-28.2751369, 153.4611025), (-28.4152778, 153.3305556),
           (-28.3121452, 153.275003), (-28.438543, 153.4703182), (-28.4436015, 153.491879), (-28.3963469, 153.404678), (-28.3408333, 153.3761111),
           (-28.2566667, 153.5761111), (-28.3869444, 153.5608333), (-28.181708, 153.5469621), (-28.2220841, 153.5370661), (-28.3363746, 153.5700922)]]
def near_town(x, z, r): return any(math.hypot(x - a, z - b) < r for a, b in TOWN_C)
def street_fill(road_kinds, lu_kinds, kinds_fn, spacing, setback, vacancy, any_res_street=False):
    n = 0
    for r in roads:
        if r["k"] not in road_kinds: continue
        P = r["P"]; hsr = SPEC[r["k"]][0]
        dd = np.r_[0, np.cumsum(np.hypot(np.diff(P[:, 0]), np.diff(P[:, 1])))]
        if dd[-1] < 20: continue
        for side in (1, -1):
            s = rng.uniform(4, spacing)
            while s < dd[-1] - 4:
                x = float(np.interp(s, dd, P[:, 0])); z = float(np.interp(s, dd, P[:, 1]))
                i = min(int(np.searchsorted(dd, s)), len(P) - 1); j = max(i - 1, 0)
                if i == j: i = min(j + 1, len(P) - 1)
                tx, tz = P[i, 0] - P[j, 0], P[i, 1] - P[j, 1]; L = math.hypot(tx, tz) or 1; tx /= L; tz /= L
                nx, nz = -tz * side, tx * side           # out from the road to this side
                kind = kinds_fn()
                (wa, wb), (da, db) = HOUSE_DIMS.get(kind, ((14, 24), (16, 30)))
                w = rng.uniform(wa, wb); d = rng.uniform(da, db)
                sb = rng.uniform(*setback)
                cx, cz = x + nx * (hsr + sb + d / 2), z + nz * (hsr + sb + d / 2)
                yaw = math.atan2(-nx, -nz)               # front (+z) to the street
                step = max(spacing, w + 4) * rng.uniform(0.9, 1.15)
                ok_here = in_lu(cx, cz, lu_kinds)
                if not ok_here and any_res_street:
                    # residential streets have houses on them whether or not OSM drew the land use; so do the bigger
                    # streets in town
                    if (r["k"] in ("residential", "living_street") or near_town(cx, cz, 1300)) and not in_lu(cx, cz, ["industrial", "retail", "commercial", "farmland"]):
                        ok_here = True
                if rng.random() < vacancy or not ok_here:
                    s += step; continue
                if not overlaps(cx, cz, yaw, w, d, 2.0) and site_ok(cx, cz, yaw, w, d, road_clear=2.0, max_spread=4.5 if kind == "qlder" else 3.0):
                    add(kind, cx, cz, yaw, w, d); n += 1
                    # a back-yard shed now and then
                    if kind in HOUSE_DIMS and rng.random() < 0.3:
                        bx_, bz_ = cx - nx * (d / 2 + 5.5), cz - nz * (d / 2 + 5.5)
                        sw, sd = rng.uniform(4, 6), rng.uniform(5, 7)
                        if not overlaps(bx_, bz_, yaw, sw, sd, 1.0) and site_ok(bx_, bz_, yaw, sw, sd, 3.0, 3.0):
                            add("shed", bx_, bz_, yaw, sw, sd)
                s += step
    return n
nres = street_fill(("residential", "living_street", "tertiary", "unclassified", "secondary"), ["residential"], lambda: house_kind(150), 26.0, (5.0, 9.0), 0.15, True)
print("street houses", nres)
nind = street_fill(("residential", "tertiary", "unclassified", "secondary", "service"), ["industrial"], lambda: "workshop" if rng.random() < 0.75 else "warehouse", 40.0, (6.0, 12.0), 0.2)
print("industrial", nind)

# ---- 3. farms along the back roads
nf = 0
for r in roads:
    if r["k"] not in ("unclassified", "tertiary", "track", "secondary"): continue
    P = r["P"]; hsr = SPEC[r["k"]][0]
    dd = np.r_[0, np.cumsum(np.hypot(np.diff(P[:, 0]), np.diff(P[:, 1])))]
    s = rng.uniform(100, 900)
    while s < dd[-1] - 50:
        x = float(np.interp(s, dd, P[:, 0])); z = float(np.interp(s, dd, P[:, 1]))
        i = min(int(np.searchsorted(dd, s)), len(P) - 1); j = max(i - 1, 0)
        if i == j: i = min(j + 1, len(P) - 1)
        tx, tz = P[i, 0] - P[j, 0], P[i, 1] - P[j, 1]; L = math.hypot(tx, tz) or 1; tx /= L; tz /= L
        side = 1 if rng.random() < 0.5 else -1
        nx, nz = -tz * side, tx * side
        s += rng.uniform(700, 1500)
        if in_lu(x, z, ["residential", "industrial", "retail", "commercial"]): continue
        kind = "qlder" if rng.random() < 0.6 else "cottage"
        (wa, wb), (da, db) = HOUSE_DIMS[kind]
        w = rng.uniform(wa, wb); d = rng.uniform(da, db)
        sb = rng.uniform(18, 45)
        cx, cz = x + nx * (hsr + sb + d / 2), z + nz * (hsr + sb + d / 2)
        yaw = math.atan2(-nx, -nz)
        if overlaps(cx, cz, yaw, w, d, 25.0) or not site_ok(cx, cz, yaw, w, d, 8.0, 4.0 if kind == "qlder" else 2.5): continue
        add(kind, cx, cz, yaw, w, d); nf += 1
        # its sheds: off to one side and behind, squared to the house
        ux, uz = math.cos(yaw), -math.sin(yaw)          # house local +x in world
        for k in range(int(rng.integers(1, 4))):
            sk = ["shed", "machine_shed", "shed", "dairy"][int(rng.integers(0, 4))] if k else "shed"
            if sk == "dairy" and rng.random() < 0.6: sk = "machine_shed"
            sw, sd = clampdims(sk, rng.uniform(8, 16), rng.uniform(8, 18))
            side2 = 1 if rng.random() < 0.5 else -1
            ox = side2 * rng.uniform(w / 2 + sw / 2 + 8, w / 2 + sw / 2 + 25)
            oz = -rng.uniform(0, d + 20)
            bx_ = cx + ux * ox - nx * (-oz); bz_ = cz + uz * ox - nz * (-oz)
            byaw = yaw + (math.pi / 2 if rng.random() < 0.3 else 0.0)
            if not overlaps(bx_, bz_, byaw, sw, sd, 3.0) and site_ok(bx_, bz_, byaw, sw, sd, 4.0, 3.0):
                add(sk, bx_, bz_, byaw, sw, sd)
print("farms", nf)

# fictional names for the real towns (our universe on the Tweed's ground)
LAT0, LON0 = -28.3285718, 153.4035024
KX = 111320 * math.cos(math.radians(LAT0)); KZ = 110574
TOWNS = [("Murwillumbah", -28.3267617, 153.3971541, "Mount Ruin"), ("South Murwillumbah", -28.332413, 153.4004688, "Southbank"),
         ("Condong", -28.3114787, 153.4351183, "Millside"), ("Tumbulgum", -28.2751369, 153.4611025, "Two Rivers"),
         ("Uki", -28.4152778, 153.3305556, "Ukee Crossing"), ("Chillingham", -28.3121452, 153.275003, "Chill Creek"),
         ("Burringbar", -28.438543, 153.4703182, "Burrow Bar"), ("Mooball", -28.4436015, 153.491879, "Moo Flat"),
         ("Stokers Siding", -28.3963469, 153.404678, "Stokers"), ("Bray Park", -28.3408333, 153.3761111, "Braybank"),
         ("Kingscliff", -28.2566667, 153.5761111, "Kings Reef"), ("Pottsville", -28.3869444, 153.5608333, "Potts Point"),
         ("Tweed Heads", -28.181708, 153.5469621, "The Heads"), ("Banora Point", -28.2220841, 153.5370661, "Banner Point"),
         ("Bogangar", -28.3363746, 153.5700922, "Bogg"), ("Crystal Creek", -28.3134264, 153.3198034, "Glass Creek"),
         ("Dunbible", -28.3744444, 153.3969444, "Dun Bridge"), ("Terranora", -28.2455556, 153.5094444, "Terra Nova")]
towns = []
for real, lat, lon, fake in TOWNS:
    x = (lon - LON0) * KX; z = -(lat - LAT0) * KZ
    if X0 < x < X0 + 32000 and Z0 < z < Z0 + 32000:
        towns.append({"name": fake, "x": round(x, 1), "z": round(z, 1)})
import collections
lots = [l for l in lots if not l[0].startswith("_")]
print("total", len(lots), collections.Counter(l[0] for l in lots))
json.dump({"lots": lots, "towns": towns}, open(f"{GAME}/assets/world/buildings.json", "w"), separators=(",", ":"))
