#!/usr/bin/env python3
"""Building types checked against the real world (0.2.56), on assets/world/buildings.json.

1. Businesses that are houses: a shop, workshop, warehouse or club lot needs some proof it's a business: a storefront
   place (Overture places: restaurants, cafes, stores, mechanics, pubs, banks... not the tradies and agents registered
   at a house), a commercial / retail / industrial footprint class, a real name, or retail / commercial / industrial
   land under it. Without any, in among houses (sheds aside) and under 650 m2, it becomes a house of the street's kind (sized the
   way tools/fix_footprints.py sizes houses).
2. Schools are campuses: every building inside a school's grounds (OSM / Overture land use: school, college,
   kindergarten) becomes one of the school's buildings, each on its own footprint, each from an era (1920s timber
   high-set, 1960s brick two-storey, 1970s besser block, a modern colorbond block), instead of one big shed and
   a scatter of 'warehouses' and 'units'. The school's name goes over the biggest one's door.
Run: python3 tools/fix_types.py  (marks the file; a second run does nothing)
"""
import json, gzip, math, collections, sys
import numpy as np
from shapely.geometry import Point, Polygon, shape
from shapely.strtree import STRtree
sys.path.insert(0, "/home/claude/game/tools"); import geo

ROOT = "/home/claude/game"
P = ROOT + "/assets/world/buildings.json"
B = json.load(open(P))
if B.get("types_fixed"):
    print("already done"); sys.exit(0)
L = B["lots"]
HOUSES = ("qlder", "cottage", "brick", "two_storey")
STOREFRONT = {"restaurant", "cafe", "coffee_shop", "casual_eatery", "bar", "pub", "hotel", "motel", "food_and_beverage_store", "fashion_and_apparel_store",
    "hardware_home_and_garden_store", "automotive_service", "auto_dealer", "gas_station", "shopping", "sporting_goods_store", "flowers_and_gifts_store",
    "financial_service", "personal_or_beauty_service", "pharmacy", "grocery_store", "supermarket", "bakery", "butcher_shop", "convenience_store",
    "liquor_store", "dental_clinic", "medical_clinic", "gym", "fitness_studio", "post_office", "library", "storage_facility", "manufacturer",
    "shipping_or_delivery_service", "sport_or_recreation_club", "social_or_community_service", "lodging", "fast_food_restaurant", "pizza_restaurant",
    "takeaway", "bank", "electronics_store", "furniture_store", "pet_store", "book_store", "department_store", "second_hand_store", "office_supplies_store"}

def rect(l, pad=0.0):
    x, z, yaw, w, d = float(l[1]), float(l[2]), float(l[3]), float(l[4]) / 2 + pad, float(l[5]) / 2 + pad
    c, s = math.cos(yaw), math.sin(yaw)
    return Polygon([(x + lx * c + lz * s, z - lx * s + lz * c) for lx, lz in ((-w, -d), (w, -d), (w, d), (-w, d))])

# evidence: storefront places, footprint classes, land use
places = []
for line in gzip.open(ROOT + "/docs/ref/2026/overture_places.geojsonl.gz", "rt"):
    d = json.loads(line); p = d["properties"]
    cat = str(p.get("basic_category") or "")
    if cat in STOREFRONT or cat.endswith("_store") or cat.endswith("_restaurant"):
        if float(p.get("confidence") or 0) < 0.5: continue
        lon, lat = d["geometry"]["coordinates"][:2]
        x, z = geo.ll(lon, lat); places.append(Point(x, z))
place_t = STRtree(places)
fpc = []
for line in gzip.open(ROOT + "/docs/ref/2026/overture_buildings.geojsonl.gz", "rt"):
    d = json.loads(line); p = d["properties"]
    sub = p.get("subtype"); cls = p.get("class")
    if sub in ("commercial", "industrial") or cls in ("retail", "commercial", "warehouse", "office", "industrial", "supermarket"):
        g = shape(d["geometry"])
        fpc.append(shapely_g := __import__("shapely").transform(g, lambda a: np.array([geo.ll(x, y) for x, y in a])))
fpc_t = STRtree(fpc) if fpc else None
# every big traced outline (any class): a school's 'one building' is often the whole campus traced as one shape
bigfp = []
for line in gzip.open(ROOT + "/docs/ref/2026/overture_buildings.geojsonl.gz", "rt"):
    d = json.loads(line); g = d["geometry"]
    ring = g["coordinates"][0] if g["type"] == "Polygon" else g["coordinates"][0][0]
    xs = [p[0] for p in ring]; ys = [p[1] for p in ring]
    if (max(xs) - min(xs)) * (max(ys) - min(ys)) * 1.1e10 < 900: continue
    bigfp.append(__import__("shapely").transform(shape(g), lambda a: np.array([geo.ll(x, y) for x, y in a])).buffer(0))
bigfp_t = STRtree(bigfp) if bigfp else None

def max_rect(grid):
    """largest all-true rectangle in a bool grid: (area, r0, c0, r1, c1), histogram method"""
    h = np.zeros(grid.shape[1], int); best = (0, 0, 0, 0, 0)
    for r in range(grid.shape[0]):
        h = np.where(grid[r], h + 1, 0)
        stack = []
        for c in range(len(h) + 1):
            cur = h[c] if c < len(h) else 0
            start = c
            while stack and stack[-1][1] >= cur:
                start, hh = stack.pop()
                a = hh * (c - start)
                if a > best[0] and hh >= 7 and (c - start) >= 7: best = (a, r - hh + 1, start, r + 1, c)
            stack.append((start, cur))
    return best

def wings(poly):
    """cut a traced outline into the rectangular wings it is made of: biggest rectangle first, in the direction of
    the outline's own walls; returns [(x, z, yaw, w, d)]"""
    angs = []
    for g in (poly.geoms if poly.geom_type == "MultiPolygon" else [poly]):
        cs = list(g.exterior.coords)
        for (ax, az), (bx, bz) in zip(cs, cs[1:]):
            ln = math.hypot(bx - ax, bz - az)
            if ln > 10: angs.append((math.atan2(bz - az, bx - ax) % (math.pi / 2), ln))
    dirs = []
    for a, ln in sorted(angs, key=lambda t: -t[1]):
        if all(min(abs(a - b), math.pi / 2 - abs(a - b)) > 0.12 for b in dirs): dirs.append(a)
    dirs = dirs[:4] or [0.0]
    out = []; rest = poly
    for _ in range(24):
        if rest.is_empty or rest.area < 90: break
        best = None
        for a in dirs:
            c, s = math.cos(a), math.sin(a)
            pr = __import__("shapely").transform(rest, lambda p: np.c_[p[:, 0] * c + p[:, 1] * s, -p[:, 0] * s + p[:, 1] * c])
            x0, z0, x1, z1 = pr.bounds
            gx = np.arange(x0 + 0.5, x1, 1.0); gz = np.arange(z0 + 0.5, z1, 1.0)
            if len(gx) < 7 or len(gz) < 7: continue
            import shapely
            X, Z = np.meshgrid(gx, gz)
            inside = shapely.contains_xy(pr, X, Z)
            ar, r0, c0, r1, c1 = max_rect(inside)
            if ar and (best is None or ar > best[0]):
                lx = x0 + (c0 + c1) / 2.0; lz = z0 + (r0 + r1) / 2.0
                best = (ar, lx * c - lz * s, lx * s + lz * c, a, float(c1 - c0), float(r1 - r0))
        if best is None or best[0] < 90: break
        _, x, z, a, w, d = best
        out.append((x, z, a, w, d))
        cc, ss = math.cos(a), math.sin(a)
        r = Polygon([(x + lx * cc - lz * ss, z + lx * ss + lz * cc) for lx, lz in ((-w / 2 - 1, -d / 2 - 1), (w / 2 + 1, -d / 2 - 1), (w / 2 + 1, d / 2 + 1), (-w / 2 - 1, d / 2 + 1))])
        rest = rest.difference(r).buffer(-0.5).buffer(0.5)
    return out
lu_biz, schools = [], []
for line in open(ROOT + "/docs/ref/streets/land_use.geojsonl"):
    d = json.loads(line); p = d["properties"]
    cls = p.get("class"); sub = p.get("subtype")
    if cls in ("retail", "commercial", "industrial") or (sub == "education" and cls in ("school", "college", "kindergarten", "education", "university")):
        g = __import__("shapely").transform(shape(d["geometry"]), lambda a: np.array([geo.ll(x, y) for x, y in a])).buffer(0)
        nm = ((p.get("names") or {}).get("primary") or "")
        (schools if sub == "education" else lu_biz).append((g, nm))
lu_t = STRtree([g for g, _ in lu_biz]) if lu_biz else None
print("evidence: %d storefronts, %d commercial footprints, %d business land uses, %d school grounds" % (len(places), len(fpc), len(lu_biz), len(schools)))

pts = np.array([[float(l[1]), float(l[2])] for l in L])
from scipy.spatial import cKDTree
kd = cKDTree(pts)
st = collections.Counter()

def house_kind(i):
    near = kd.query_ball_point(pts[i], 90.0)
    c = collections.Counter(L[j][0] for j in near if L[j][0] in ("qlder", "cottage", "brick"))
    return c.most_common(1)[0][0] if c else "brick"

CAP = {"qlder": (12.5, 12.0), "cottage": (10.5, 10.5), "brick": (18.0, 14.0)}
VF = {"qlder": 2.8, "cottage": 0.0, "brick": 0.0}
def as_house(i, k):
    l = L[i]
    wo, do = float(l[4]), float(l[5])
    cw, cd = CAP[k]
    vs = 1.6 if k == "qlder" else 0.0
    w = min(max(wo - 1.0 - 2 * vs, 7.0), cw); d = min(max(do - 1.0 - VF[k], 7.0), cd)
    zc = do / 2 - 0.5 - VF[k] - d / 2
    yaw = float(l[3])
    x = float(l[1]) + zc * math.sin(yaw); z = float(l[2]) + zc * math.cos(yaw)
    return [k, round(x, 2), round(z, 2), round(yaw, 4), round(w, 2), round(d, 2), l[6]]

out = list(L)
# ---- 1. businesses with no proof
for i, l in enumerate(L):
    k = str(l[0])
    sub = str(l[7]) if len(l) > 7 else ""
    if k not in ("shop", "workshop", "warehouse", "club"): continue
    if sub: st["kept: named / hand-made"] += 1; continue
    r = rect(l, 8.0)
    proof = len(place_t.query(r, predicate="intersects")) > 0
    if not proof and fpc_t is not None: proof = len(fpc_t.query(rect(l), predicate="intersects")) > 0
    if not proof and lu_t is not None: proof = any(lu_biz[j][0].contains(Point(pts[i])) for j in lu_t.query(Point(pts[i])))
    if proof: st["kept: proof it's a business"] += 1; continue
    area = float(l[4]) * float(l[5])
    near = [j for j in kd.query_ball_point(pts[i], 80.0) if j != i and L[j][0] not in ("shed", "machine_shed")]
    houses = sum(1 for j in near if L[j][0] in HOUSES)
    if area < 650 and near and houses >= 0.4 * len(near):
        out[i] = as_house(i, house_kind(i)); st["business -> house"] += 1
    else:
        st["kept: no proof but not among houses"] += 1
# ---- 2. schools as campuses
ERAS = ["1920", "1960", "1970", "modern"]
removed = set()
for g, nm in schools:
    if g.area < 2000: continue
    inside = [i for i in range(len(out)) if i not in removed and g.contains(Point(float(out[i][1]), float(out[i][2])))]
    if not inside: continue
    bldgs = [i for i in inside if str(out[i][0]) not in ("mall",) and not (len(out[i]) > 7 and str(out[i][7]).startswith("servo/"))]
    # the old single 'school' lot placed where OSM said: drop it when real footprints sit on the campus
    fps = [i for i in bldgs if not (str(out[i][0]) == "school" and len(out[i]) <= 7)]
    big = [i for i in fps if float(out[i][4]) * float(out[i][5]) >= 60.0]
    if len(big) >= 2:
        for i in bldgs:
            if str(out[i][0]) == "school" and i not in big:
                removed.add(i)
    else:
        big = [i for i in bldgs if float(out[i][4]) * float(out[i][5]) >= 60.0]
    if not big: continue
    biggest = max(big, key=lambda i: float(out[i][4]) * float(out[i][5]))
    name = nm.upper() if nm else ""
    for i in big:
        l = out[i]
        # one traced outline over 500 m2 is several wings joined by covered walkways: cut it into wings ~12 m deep and
        # up to 36 m long with gaps between, each its own building from its own decade
        x, z, yaw, w, d = float(l[1]), float(l[2]), float(l[3]), float(l[4]), float(l[5])
        c_, s_ = math.cos(yaw), math.sin(yaw)
        pieces = []
        fp = None
        if w * d > 500.0 and bigfp_t is not None:
            cand = [bigfp[j] for j in bigfp_t.query(Point(x, z).buffer(3.0)) if bigfp[j].area > 300]
            if cand: fp = max(cand, key=lambda g: g.area)
        if fp is not None and fp.area < 0.8 * w * d:
            # the traced shape is wings joined at the corners: take its own rectangles, then break long wings into
            # buildings ~30-45 m long, a walkway gap between
            for (wx, wz, wa, ww, wd) in wings(fp):
                if ww < wd: ww, wd, wa = wd, ww, wa + math.pi / 2
                n = max(1, int(round(ww / 40.0)))
                seg = (ww - 4.0 * (n - 1)) / n
                ca, sa = math.cos(wa), math.sin(wa)
                for k in range(n):
                    o = -ww / 2 + seg / 2 + k * (seg + 4.0)
                    # game yaw: local x runs along (cos yaw, -sin yaw)
                    pieces.append((wx + o * ca, wz + o * sa, round(-wa, 4), seg - 1.0, wd - 1.0))
            st["school outlines cut into their own wings"] += 1
        elif w * d > 500.0:
            nw = max(1, int(round((w + 6.0) / 42.0))); nd = max(1, int(round((d + 5.0) / 17.0)))
            pw = (w - 6.0 * (nw - 1)) / nw; pd = (d - 5.0 * (nd - 1)) / nd
            for a_ in range(nw):
                for b_ in range(nd):
                    lx = -w / 2 + pw / 2 + a_ * (pw + 6.0); lz = -d / 2 + pd / 2 + b_ * (pd + 5.0)
                    pieces.append((x + lx * c_ + lz * s_, z - lx * s_ + lz * c_, l[3], pw, pd))
            st["school outlines cut into wings"] += 1
        else:
            pieces.append((x, z, l[3], w, d))
        for pi_, (px, pz, pyaw, pw, pd) in enumerate(pieces):
            era = ERAS[abs(hash((round(px), round(pz)))) % 4]
            sub = "era/%s" % era + (("/" + name) if i == biggest and pi_ == 0 and name else "")
            nl = ["school", round(px, 2), round(pz, 2), pyaw, round(pw, 2), round(pd, 2), float(l[6]) + pi_, sub]
            if pi_ == 0: out[i] = nl
            else: out.append(nl)
            st["school building"] += 1
    st["school campuses"] += 1
out = [l for i, l in enumerate(out) if i not in removed]
st["old single school lots dropped"] = len(removed)
B["lots"] = out
B["types_fixed"] = True
json.dump(B, open(P, "w"), separators=(",", ":"))
for k, v in st.most_common(): print("  ", k, v)
