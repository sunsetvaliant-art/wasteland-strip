#!/usr/bin/env python3
"""Streets by the block (0.2.54). Every patch of ground the sealed roads close off is a block; each block gets a
kerb profile from what's in it, and the street around it is built from rules instead of read off the photos:

  MAIN   shops / retail land: barrier kerb and gutter, footpath paved at kerb height to the shop fronts, bins,
         benches, street lights
  TOWN   older streets of houses: barrier kerb and gutter, grass nature strip, 1.2 m concrete path
  EST    estates (brick homes in lined-up rows): roll-top kerb, path behind a verge
  IND    industrial: barrier kerb, no path
  ISL    medians and traffic islands (thin blocks between carriageways): kerbed, concrete when narrow
  RBT    roundabout centres: kerbed; small ones a mountable concrete dome
  rural  big empty blocks: no kerb at all (and any kerb run with no lot within 60 m on its side is dropped)

Kerb corners are rounded (a 3-9 m return by profile) and the bit of road that rounding opens up is painted as
seal. Driveways (every house lot, every OSM driveway / service road / car park aisle that meets the kerb) get a
layback in the kerb and a concrete crossover. Crossings get kerb ramps, zebras in shopping streets and stop-line
pairs at the lights. Stop / give way points get their line and sign. Car parks (OSM outlines) are sealed and laid
out in 2.5 x 5.4 m bays with 6.4 m aisles, or painted from OSM's own bays where it has them.

Inputs: assets/roads/lines.bin + lines_north.bin (the painted roads, game frame), assets/world/buildings.json,
assets/world/bridges.json, assets/world/servos.json, docs/ref/streets/{segment,infrastructure,land_use}.geojsonl
(Overture Maps, `overturemaps download --bbox=153.28215,-28.47565,153.58502,-28.14179 -f geojsonseq --type=...`).
Writes assets/world/streets.bin (format: scripts/world/streets.gd). Usage: make_streets.py [x0 z0 x1 z1]
"""
import sys, os, json, math, struct, zlib, time, collections
import numpy as np
import shapely
from shapely.geometry import LineString, Point, Polygon, MultiPolygon, box, shape
from shapely.ops import unary_union, polygonize, nearest_points, substring
from shapely.strtree import STRtree
import mapbox_earcut as earcut

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(GAME, "tools"))
import road_lines, geo

T0 = time.time()
def log(*a): print("%6.1fs" % (time.time() - T0), *a, flush=True)

AREA = [float(v) for v in sys.argv[1:5]] if len(sys.argv) >= 5 else None
TILE = 128.0
X0, Z0 = -12288.0, -20736.0          # tile grid origin (multiple of 128 below the map's corner)

PROF = {"MAIN": 0, "TOWN": 1, "EST": 2, "IND": 3, "ISL": 4, "RBT": 5, "LAY": 6, "RAMP": 7}
ROUND = {"MAIN": 3.0, "TOWN": 6.0, "EST": 8.0, "IND": 9.0, "ISL": 0.6, "RBT": 0.3}

# ------------------------------------------------------------------ inputs
def in_area(x, z, m=0.0):
    return AREA is None or (AREA[0] - m <= x <= AREA[2] + m and AREA[1] - m <= z <= AREA[3] + m)

pieces = road_lines_all = []
def read_lines(path):
    out = []
    f = open(path, "rb").read(); o = 0
    def u32():
        nonlocal o; v = struct.unpack_from("<I", f, o)[0]; o += 4; return v
    nt = u32()
    for _ in range(nt):
        u32(); u32(); npc = u32()
        for _ in range(npc):
            hs, sf, mk, wl = struct.unpack_from("<4f", f, o); o += 16
            n = u32(); a = np.frombuffer(f, dtype="<f4", count=n * 5, offset=o).reshape(n, 5); o += n * 20
            out.append((hs, sf, mk, a[:, :2].astype(np.float64)))
    return out

raw = read_lines(f"{GAME}/assets/roads/lines.bin") + read_lines(f"{GAME}/assets/roads/lines_north.bin")
M = 300.0
seal, gravel = [], []
for hs, sf, mk, a in raw:
    if len(a) < 2: continue
    if AREA is not None and not (a[:, 0].max() > AREA[0] - M and a[:, 0].min() < AREA[2] + M and a[:, 1].max() > AREA[1] - M and a[:, 1].min() < AREA[3] + M):
        continue
    ls = LineString(a)
    if ls.length < 0.5: continue
    (gravel if sf > 0.25 else seal).append((ls, float(hs), float(mk)))
log("road pieces: %d sealed, %d gravel" % (len(seal), len(gravel)))

lots = json.load(open(f"{GAME}/assets/world/buildings.json"))["lots"]
HOUSE = {"qlder", "cottage", "brick", "two_storey"}
SHOPK = {"shop", "pub", "mall", "motel", "club", "post", "hardware"}
INDK = {"warehouse", "workshop", "factory"}
lot_pts, lot_kind, lot_rect = [], [], []
for l in lots:
    x, z = float(l[1]), float(l[2])
    if not in_area(x, z, M): continue
    yaw, w, d = float(l[3]), float(l[4]), float(l[5])
    c, s = math.cos(yaw), math.sin(yaw)
    # Godot: Basis(UP, yaw) * (lx, 0, lz) -> (lx c + lz s, -lx s + lz c)
    corners = [(x + lx * c + lz * s, z - lx * s + lz * c) for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]
    lot_pts.append(Point(x, z)); lot_kind.append(str(l[0])); lot_rect.append(Polygon(corners))
lot_tree = STRtree(lot_pts)
rect_tree = STRtree(lot_rect)
log("lots", len(lot_pts))

# estate homes: brick, among brick neighbours lined up with them (the same test Buildings._house_styles uses)
estate = np.zeros(len(lot_pts), bool)
yaws = []
for l in lots:
    if in_area(float(l[1]), float(l[2]), M): yaws.append(float(l[3]))
P = np.array([[p.x, p.y] for p in lot_pts]) if lot_pts else np.zeros((0, 2))
from scipy.spatial import cKDTree
kd = cKDTree(P) if len(P) else None
for i in range(len(P)):
    if lot_kind[i] != "brick": continue
    dd, jj = kd.query(P[i], k=9, distance_upper_bound=120.0)
    brick = aligned = 0
    for j in jj[1:]:
        if j >= len(P): continue
        if lot_kind[j] == "brick": brick += 1
        dy = (yaws[j] - yaws[i] + math.pi / 4) % (math.pi / 2) - math.pi / 4
        if abs(dy) < 0.12: aligned += 1
    estate[i] = brick >= 6 and aligned >= 5

bridges = []
for b in json.load(open(f"{GAME}/assets/world/bridges.json"))["bridges"]:
    pts = [(p[0], p[2]) for p in b["pts"]]
    if len(pts) >= 2: bridges.append(LineString(pts).buffer(float(b["hw"]) + 4.0))
bridge_zone = unary_union(bridges) if bridges else Polygon()

servo_zone = []
try:
    for s in json.load(open(f"{GAME}/assets/world/servos.json"))["servos"]:
        for key in ("area", "forecourt", "outline"):
            if key in s and len(s[key]) >= 3:
                servo_zone.append(Polygon([(p[0], p[1]) for p in s[key]]).buffer(2.0))
except Exception as e:
    log("servos:", e)
servo_zone = unary_union(servo_zone) if servo_zone else Polygon()

def ov(name):
    p = f"{GAME}/docs/ref/streets/{name}.geojsonl"
    out = []
    for line in open(p):
        d = json.loads(line)
        out.append(d)
    return out

def to_game(geom):
    """lon/lat shapely geometry -> game metres"""
    return shapely.transform(geom, lambda a: np.array([geo.ll(x, y) for x, y in a]))

segs = []          # (LineString game, class, subclass, name)
for d in ov("segment"):
    p = d["properties"]
    if p.get("subtype") != "road": continue
    g = to_game(shape(d["geometry"]))
    if AREA is not None and not g.intersects(box(AREA[0] - M, AREA[1] - M, AREA[2] + M, AREA[3] + M)): continue
    nm = ((p.get("names") or {}).get("primary") or "")
    segs.append((g, p.get("class"), p.get("subclass"), nm))
seg_tree = STRtree([s[0] for s in segs])
log("overture segments", len(segs))

infra = collections.defaultdict(list)
for d in ov("infrastructure"):
    p = d["properties"]
    g = to_game(shape(d["geometry"]))
    c = g.centroid
    if not in_area(c.x, c.y, 50.0): continue
    infra[(p.get("subtype"), p.get("class"))].append(g)
log("infrastructure", {"%s/%s" % k: len(v) for k, v in infra.items() if len(v) > 5})

landuse = []
for d in ov("land_use"):
    p = d["properties"]
    if p.get("class") not in ("retail", "commercial", "industrial", "residential"): continue
    g = to_game(shape(d["geometry"]))
    if AREA is not None and not g.intersects(box(AREA[0] - M, AREA[1] - M, AREA[2] + M, AREA[3] + M)): continue
    landuse.append((g.buffer(0), p.get("class")))
lu_tree = STRtree([g for g, _ in landuse]) if landuse else None

# ------------------------------------------------------------------ the road surface and the blocks
seal_lines = [s[0] for s in seal]
road_poly = unary_union([ls.buffer(hs, quad_segs=6) for ls, hs, _ in seal])
log("road surface built")
noded = unary_union(seal_lines)
faces = list(polygonize(noded))
log("faces", len(faces))
gravel_zone = unary_union([ls.buffer(hs + 1.5) for ls, hs, _ in gravel]) if gravel else Polygon()
seal_tree = STRtree(seal_lines)

# dead ends in town get a turning bulb (OSM's turning circles aren't in the Overture data)
ends = collections.Counter()
for g in (noded.geoms if hasattr(noded, "geoms") else [noded]):
    cs = list(g.coords)
    ends[(round(cs[0][0], 1), round(cs[0][1], 1))] += 1
    ends[(round(cs[-1][0], 1), round(cs[-1][1], 1))] += 1
bulbs = []
for (x, z), n in ends.items():
    if n != 1 or not in_area(x, z): continue
    near = lot_tree.query(Point(x, z).buffer(45.0))
    houses = sum(1 for i in near if lot_kind[i] in HOUSE)
    if houses >= 4:
        bulbs.append(Point(x, z).buffer(9.0, quad_segs=8))
bulb_poly = unary_union(bulbs) if bulbs else Polygon()
road_all = unary_union([road_poly, bulb_poly])
log("turning bulbs", len(bulbs))
# the road surface piece by piece, for local questions (the whole-map union is far too big to ask anything of)
road_pieces = [ls.buffer(hs, quad_segs=6) for ls, hs, _ in seal] + list(bulbs)
road_tree = STRtree(road_pieces)
def local_roads(g, pad=0.0):
    ids = road_tree.query(g.buffer(pad) if pad else g)
    return unary_union([road_pieces[i] for i in ids]) if len(ids) else Polygon()
def near_road(pts, tol):
    """bool per point: within tol of the road surface"""
    P = shapely.points(np.asarray(pts))
    hit = np.zeros(len(pts), bool)
    idx = road_tree.query_nearest(P, max_distance=tol, all_matches=False)
    hit[idx[0]] = True
    return hit
for zname in ("bridge_zone", "gravel_zone", "servo_zone"):
    shapely.prepare(globals()[zname])

def lots_in(g):
    return [i for i in lot_tree.query(g, predicate="contains")]

def lu_share(g, classes):
    if lu_tree is None or g.area <= 0: return 0.0
    a = 0.0
    for j in lu_tree.query(g):
        lg, lc = landuse[j]
        if lc in classes:
            try: a += lg.intersection(g).area
            except Exception: pass
    return a / g.area

def classify(face, part):
    A = part.area
    ids = lots_in(face)
    kinds = [lot_kind[i] for i in ids]
    houses = sum(1 for k in kinds if k in HOUSE)
    shops = sum(1 for k in kinds if k in SHOPK)
    ind = sum(1 for k in kinds if k in INDK)
    # islands and roundabouts
    if not ids and A < 2500.0:
        mrr = part.minimum_rotated_rectangle
        xs, ys = mrr.exterior.coords.xy
        e = sorted([math.hypot(xs[i + 1] - xs[i], ys[i + 1] - ys[i]) for i in range(2)])
        compact = 4 * math.pi * A / max(part.length ** 2, 1e-6)
        if compact > 0.6 and A < 1600.0: return "RBT"
        if e[0] < 14.0 or A < 400.0: return "ISL"
    dens = len(ids) / max(face.area / 1e4, 0.01)
    urban = dens >= 1.5 or lu_share(face, ("retail", "commercial", "industrial", "residential")) > 0.4
    if not urban: return None
    if shops >= 3 or lu_share(face, ("retail", "commercial")) > 0.3: return "MAIN"
    if lu_share(face, ("industrial",)) > 0.4 or (ids and ind >= max(2, 0.5 * len(ids))): return "IND"
    est = sum(1 for i in ids if estate[i])
    if houses and est >= 0.5 * houses: return "EST"
    return "TOWN"

# ------------------------------------------------------------------ output collectors, per 128 m tile
tiles = collections.defaultdict(lambda: {"kerb": [], "paint": [], "furn": [], "slab": [], "fence": []})
def tkey(x, z): return (int(math.floor((x - X0) / TILE)), int(math.floor((z - Z0) / TILE)))

def add_paint(geom, surf, style=0.0):
    """triangulate a polygon (or multi) and file the triangles by tile"""
    if geom.is_empty: return
    for poly in getattr(geom, "geoms", [geom]):
        if poly.geom_type != "Polygon" or poly.area < 0.05: continue
        # big ones are cut at the tile edges so each tile holds its own
        minx, minz, maxx, maxz = poly.bounds
        if (maxx - minx) > TILE or (maxz - minz) > TILE:
            kx0, kz0 = tkey(minx, minz); kx1, kz1 = tkey(maxx, maxz)
            for kx in range(kx0, kx1 + 1):
                for kz in range(kz0, kz1 + 1):
                    cell = box(X0 + kx * TILE, Z0 + kz * TILE, X0 + (kx + 1) * TILE, Z0 + (kz + 1) * TILE)
                    sub = poly.intersection(cell)
                    if not sub.is_empty:
                        for sp in getattr(sub, "geoms", [sub]):
                            if sp.geom_type == "Polygon": _tri(sp, surf, style)
            continue
        _tri(poly, surf, style)

def _tri(poly, surf, style):
    poly = poly.simplify(0.04)
    if poly.is_empty or poly.geom_type != "Polygon": return
    rings = [np.array(poly.exterior.coords)[:-1]] + [np.array(r.coords)[:-1] for r in poly.interiors]
    rings = [r for r in rings if len(r) >= 3]
    if not rings: return
    v = np.concatenate(rings)
    ends = np.cumsum([len(r) for r in rings]).astype(np.uint32)
    idx = earcut.triangulate_float64(v, ends)
    if len(idx) == 0: return
    c = poly.representative_point()
    tiles[tkey(c.x, c.y)]["paint"].append((surf, style, v[idx].astype(np.float32)))

def add_furn(kind, x, z, yaw, param=0.0):
    if not in_area(x, z): return
    tiles[tkey(x, z)]["furn"].append((kind, x, z, yaw, param))

def add_kerb_run(pts, kinds, prof):
    """pts: list of (x, z) with the block on the +n side (n = (tz, -tx)), split by tile"""
    if len(pts) < 2: return
    cur = [0]
    k0 = tkey(*((np.array(pts[0]) + np.array(pts[1])) / 2))
    for i in range(1, len(pts) - 1):
        k = tkey(*((np.array(pts[i]) + np.array(pts[i + 1])) / 2))
        cur.append(i)
        if k != k0:
            _file_run(k0, [pts[j] for j in cur], [kinds[j] for j in cur], prof)
            cur = [i]; k0 = k
    cur.append(len(pts) - 1)
    _file_run(k0, [pts[j] for j in cur], [kinds[j] for j in cur], prof)

def _file_run(k, pts, kinds, prof):
    pr = PROF[prof] if isinstance(prof, str) else prof
    i = 0
    while i < len(pts) - 1:
        j = min(i + 40, len(pts) - 1)
        tiles[k]["kerb"].append((pr, pts[i:j + 1], kinds[i:j + 1]))
        i = j

# ------------------------------------------------------------------ gaps in the kerb: driveways, aisles, crossings
gap_lines = []        # (LineString, half width, kind)
for g, cls, sub, nm in segs:
    if cls == "service" or cls == "living_street" and False:
        hw = 3.0 if sub in ("parking_aisle", "alley", None) else 1.8
        gap_lines.append((g, hw, "LAY"))
gap_tree = STRtree([g for g, _, _ in gap_lines]) if gap_lines else None

crossings = []
for g in infra[("transportation", "crossing")]:
    crossings.append(g.centroid)
signals = [g.centroid for g in infra[("transportation", "traffic_signals")]]
sig_tree = STRtree(signals) if signals else None
cross_tree = STRtree(crossings) if crossings else None

def resample(ring, step=2.0):
    """points along a ring every <= step m, keeping its corners"""
    cs = np.array(ring.coords)
    out = [cs[0]]
    for a, b in zip(cs[:-1], cs[1:]):
        L = np.hypot(*(b - a)); n = max(1, int(math.ceil(L / step)))
        for k in range(1, n + 1): out.append(a + (b - a) * k / n)
    return np.array(out)

stats = collections.Counter()

def kerb_for(part, prof, urban_keep, face_lots):
    edge_tol = 0.45 * ROUND.get(prof, 6.0) + 0.6
    """build the kerb rings of one rounded block (part), the block on the +n side"""
    rings = [part.exterior] + list(part.interiors)
    for ring in rings:
        pts = resample(ring.simplify(0.15), 2.0)
        if len(pts) < 4: continue
        # make the block lie on +n: test the middle of the longest segment
        seglen = np.hypot(*(pts[1:] - pts[:-1]).T)
        i = int(np.argmax(seglen))
        a, b = pts[i], pts[i + 1]
        t = (b - a) / max(seglen[i], 1e-6)
        n = np.array([t[1], -t[0]])
        m = (a + b) / 2 + n * 0.3
        if not part.contains(Point(m)):
            pts = pts[::-1]
        kinds = []
        keep = []
        on_edge = near_road(pts, edge_tol)
        for j, p in enumerate(pts):
            P_ = Point(p)
            k = PROF[prof]
            ok = in_area(p[0], p[1])
            if ok and not on_edge[j]: ok = False
            if ok and bridge_zone.contains(P_): ok = False
            if ok and gravel_zone.contains(P_): ok = False
            if ok and prof in ("MAIN", "TOWN", "EST", "IND") and urban_keep is not None and not urban_keep.contains(P_): ok = False
            if ok and servo_zone.contains(P_): k = PROF["LAY"]
            elif prof == "MAIN" and not shop_zone.contains(P_): k = PROF["TOWN"]
            keep.append(ok); kinds.append(k)
        # laybacks where a service road / driveway meets the kerb
        if gap_tree is not None:
            ring_ls = LineString(pts)
            for gi in gap_tree.query(ring_ls.buffer(1.0)):
                gl, hw, kd = gap_lines[gi]
                x = gl.intersection(ring_ls.buffer(0.5))
                if x.is_empty: continue
                c = x.centroid
                d = np.hypot(pts[:, 0] - c.x, pts[:, 1] - c.y)
                for j in np.nonzero(d < hw + 0.5)[0]: kinds[j] = PROF["LAY"]
                stats["service laybacks"] += 1
        # kerb ramps at crossings
        if cross_tree is not None:
            for ci in cross_tree.query(LineString(pts).buffer(hsmax_near(pts) + 3.0)):
                c = crossings[ci]
                d = np.hypot(pts[:, 0] - c.x, pts[:, 1] - c.y)
                j = int(np.argmin(d))
                if d[j] < 12.0:
                    for jj in np.nonzero(np.hypot(pts[:, 0] - pts[j][0], pts[:, 1] - pts[j][1]) < 1.2)[0]:
                        if kinds[jj] != PROF["LAY"]: kinds[jj] = PROF["RAMP"]
                    stats["kerb ramps"] += 1
        # house driveways: the kerb point nearest each house lot's front gets a 3.4 m layback and a crossover
        if prof in ("TOWN", "EST", "MAIN") and face_lots:
            ring_ls = LineString(pts)
            for li in face_lots:
                if lot_kind[li] not in HOUSE: continue
                lp = lot_pts[li]
                if ring_ls.distance(lp) > 30.0: continue
                q = ring_ls.interpolate(ring_ls.project(lp))
                d = np.hypot(pts[:, 0] - q.x, pts[:, 1] - q.y)
                j = int(np.argmin(d))
                # off to one side of the house's middle (the drive runs down beside the house)
                off = (hash(li) % 2 * 2 - 1) * min(4.0, lot_rect[li].minimum_rotated_rectangle.length / 8.0)
                s = ring_ls.project(q) + off
                q2 = ring_ls.interpolate(s)
                d = np.hypot(pts[:, 0] - q2.x, pts[:, 1] - q2.y)
                near = np.nonzero(d < 1.7)[0]
                if len(near) == 0 or any(not keep[jj] for jj in near): continue
                if any(kinds[jj] == PROF["LAY"] for jj in near): continue
                for jj in near: kinds[jj] = PROF["LAY"]
                # the crossover: concrete from the kerb back to the lot
                jn = int(np.argmin(d))
                a = pts[max(jn - 1, 0)]; b = pts[min(jn + 1, len(pts) - 1)]
                t = (b - a) / max(np.hypot(*(b - a)), 1e-6); n = np.array([t[1], -t[0]])
                L = max(2.0, min(14.0, lot_rect[li].distance(Point(q2.x, q2.y)) + 1.0))
                st = np.array([q2.x, q2.y])
                drive = LineString([st + n * 0.5, st + n * L]).buffer(1.5, cap_style="flat")
                drive = drive.difference(lot_rect[li])
                add_paint(drive, 1.0)
                stats["driveways"] += 1
        # insert hard edges where the kind changes (so a layback starts and stops square, not over 2 m)
        P2, K2 = [], []
        for j in range(len(pts)):
            if not keep[j]:
                if len(P2) >= 2: add_kerb_run(P2, K2, prof)
                P2, K2 = [], []
                continue
            if P2 and K2[-1] != kinds[j]:
                a = np.array(P2[-1]); b = pts[j]
                L = np.hypot(*(b - a))
                if L > 0.6:
                    P2.append(tuple(a + (b - a) * (0.5 - 0.15 / L))); K2.append(K2[-1])
                    P2.append(tuple(a + (b - a) * (0.5 + 0.15 / L))); K2.append(kinds[j])
            P2.append(tuple(pts[j])); K2.append(kinds[j])
        if len(P2) >= 2: add_kerb_run(P2, K2, prof)
        stats["kerb m " + prof] += float(np.hypot(*(pts[1:] - pts[:-1]).T).sum())

_hs_cache = {}
def hsmax_near(pts):
    c = Point(np.mean(pts, axis=0))
    best = 4.0
    for i in seal_tree.query(c.buffer(80.0)):
        best = max(best, seal[i][1])
    return best

# ------------------------------------------------------------------ the blocks
# Not polygonize: the painted centrelines don't always meet at junctions, which merges whole suburbs into one face.
# Instead the blocks are what's left of the map once the road surface is cut out. Anything bigger than 20 ha
# (farmland running in behind a street) is rounded whole, then cut into 200 m cells that are judged on their own.
face_prof = {}
unit_list = []        # (polygon, already rounded, from a big part)
bx = box(*(AREA if AREA else (min(l.bounds[0] for l in seal_lines), min(l.bounds[1] for l in seal_lines),
                                 max(l.bounds[2] for l in seal_lines), max(l.bounds[3] for l in seal_lines))))
CELL = 200.0
for gx in np.arange(bx.bounds[0], bx.bounds[2], 2000.0):
    for gz in np.arange(bx.bounds[1], bx.bounds[3], 2000.0):
        chunk = box(gx, gz, gx + 2000.0, gz + 2000.0).intersection(bx)
        rd = [road_all] if False else None
        comp = chunk.difference(local_roads(chunk, 20.0))
        for part in getattr(comp, "geoms", [comp]):
            if part.geom_type != "Polygon" or part.area < 3.0: continue
            # a part touching the 2 km chunk edge is judged in cells too (it may run on into the next chunk)
            if part.area < 20e4 and not part.boundary.intersects(chunk.boundary.buffer(0.01)):
                unit_list.append((part, False, False))
                continue
            pr = part.buffer(-6.0, quad_segs=8).buffer(6.0, quad_segs=8)
            if pr.is_empty: continue
            fill = part.difference(pr.buffer(0.02))
            for fp in getattr(fill, "geoms", [fill]):
                if fp.geom_type == "Polygon" and fp.area < 150.0 and len(road_tree.query(fp.buffer(0.2))):
                    add_paint(fp, 0.0)
            minx, minz, maxx, maxz = pr.bounds
            for cx in np.arange(math.floor(minx / CELL) * CELL, maxx, CELL):
                for cz in np.arange(math.floor(minz / CELL) * CELL, maxz, CELL):
                    u = pr.intersection(box(cx, cz, cx + CELL, cz + CELL))
                    for up in getattr(u, "geoms", [u]):
                        if up.geom_type == "Polygon" and up.area > 3.0: unit_list.append((up, True, True))
        log("chunk %.0f %.0f: %d units so far" % (gx, gz, len(unit_list)))
log("block units", len(unit_list))

main_polys = []
shop_zone = Polygon()
fence_blocks = []
for ui, (part, rounded, big) in enumerate(unit_list):
    c = part.representative_point()
    if not in_area(c.x, c.y): continue
    prof = classify(part, part)
    if prof is None: continue
    if big and prof in ("ISL", "RBT"): prof = "TOWN"
    if rounded:
        pr = part
    else:
        r = ROUND[prof]
        pr = part.buffer(-r, quad_segs=8).buffer(r, quad_segs=8)
        if pr.is_empty or pr.area < 0.75 * part.area:
            r = 0.8
            pr = part.buffer(-r, quad_segs=4).buffer(r, quad_segs=4)
        if pr.is_empty: pr = part
        fill = part.difference(pr.buffer(0.02))
        for fp in getattr(fill, "geoms", [fill]):
            if fp.geom_type == "Polygon" and fp.area < 150.0 and len(road_tree.query(fp.buffer(0.2))):
                add_paint(fp, 0.0)
    if prof == "MAIN": main_polys.append(part.buffer(1.0))
    face_lots = lots_in(part) if prof in ("TOWN", "EST", "MAIN") else []
    shop_zone = Polygon()
    if prof == "MAIN":
        sl = [lot_rect[i] for i in lots_in(part.buffer(12.0)) if lot_kind[i] in SHOPK or lot_kind[i] in ("bank", "hall", "civic")]
        shop_zone = unary_union([r.buffer(10.0) for r in sl]) if sl else Polygon()
        shapely.prepare(shop_zone)
    keep = None
    if prof in ("MAIN", "TOWN", "EST", "IND") and (big or part.area > 6e4):
        near = [lot_rect[i] for i in lots_in(part)]
        keep = unary_union([g.buffer(60.0) for g in near]) if near else Polygon()
        if lu_share(part, ("retail", "commercial", "industrial", "residential")) > 0.4: keep = None
    for p in getattr(pr, "geoms", [pr]):
        if p.geom_type != "Polygon": continue
        kerb_for(p, prof, keep, face_lots)
        stats["blocks " + prof] += 1
        if prof in ("TOWN", "EST", "MAIN"): fence_blocks.append((p, prof))
        if prof == "MAIN":
            # 0.2.55: the wide paving only runs in front of the shops; houses in a shopping block get a town path
            fp = p.buffer(-0.8).difference(p.buffer(-8.0)).intersection(shop_zone)
            tp = p.buffer(-2.2).difference(p.buffer(-3.4)).difference(shop_zone)
            if keep is not None: tp = tp.intersection(keep)
            tp = tp.intersection(local_roads(p, 1.0).buffer(4.9))
            bl = [lot_rect[i] for i in rect_tree.query(p)]
            if bl:
                tp = tp.difference(unary_union([lot_rect[i].buffer(3.5 if lot_kind[i] == "qlder" else 0.3) for i in rect_tree.query(p)]))
            add_paint(tp, 1.0)
            if bl: fp = fp.difference(unary_union(bl))
            if keep is not None: fp = fp.intersection(keep)
            fp = fp.intersection(local_roads(p, 1.0).buffer(9.0))          # not along a cell's cut edge
            if gap_tree is not None:
                cut = [gap_lines[i][0].buffer(gap_lines[i][1]) for i in gap_tree.query(p)]
                if cut: fp = fp.difference(unary_union(cut))
            kerbline = p.boundary
            for sp in getattr(fp, "geoms", [fp]):
                if sp.geom_type == "Polygon" and sp.area > 1.0:
                    c2 = sp.representative_point()
                    tiles[tkey(c2.x, c2.y)]["slab"].append((sp, kerbline))
            add_paint(fp, 1.0)
        elif prof in ("TOWN", "EST"):
            a_, b_ = (2.2, 3.4) if prof == "TOWN" else (1.6, 3.1)
            fp = p.buffer(-a_).difference(p.buffer(-b_))
            if keep is not None: fp = fp.intersection(keep)
            fp = fp.intersection(local_roads(p, 1.0).buffer(b_ + 1.5))
            bl = [lot_rect[i] for i in rect_tree.query(p)]
            if bl: fp = fp.difference(unary_union(bl).buffer(0.3))
            add_paint(fp, 1.0)
        elif prof == "ISL":
            mrr = p.minimum_rotated_rectangle
            xs, ys = mrr.exterior.coords.xy
            e = min(math.hypot(xs[i + 1] - xs[i], ys[i + 1] - ys[i]) for i in range(2))
            if e < 3.5 or p.area < 30.0: add_paint(p.buffer(-0.15), 1.0)
        elif prof == "RBT":
            rr = math.sqrt(p.area / math.pi)
            if rr < 6.0: add_paint(p.buffer(-0.2), 1.0)
    if ui % 2000 == 0: log("unit %d/%d" % (ui, len(unit_list)), dict(stats))
log("blocks done", dict(stats))
for b in bulbs: add_paint(b.difference(unary_union([road_pieces[i] for i in road_tree.query(b) if i < len(seal)])), 0.0)

# ------------------------------------------------------------------ crossings, stop lines, signs
def road_at(p, r=8.0):
    """nearest sealed piece to p: (LineString, hs, unit tangent at the nearest point, nearest point)"""
    best = None
    for i in seal_tree.query(p.buffer(r)):
        ls, hs, mk = seal[i]
        d = ls.distance(p)
        if d < r and (best is None or d < best[0]): best = (d, i)
    if best is None: return None
    ls, hs, mk = seal[best[1]]
    s = ls.project(p)
    a = ls.interpolate(max(0.0, s - 1.5)); b = ls.interpolate(min(ls.length, s + 1.5))
    t = np.array([b.x - a.x, b.y - a.y]); t /= max(np.linalg.norm(t), 1e-6)
    q = ls.interpolate(s)
    return ls, hs, t, np.array([q.x, q.y])

def prof_at(p):
    """the kerb profile of the blocks either side of a point on a road (MAIN wins)"""
    out = set()
    for d in (-1, 1):
        pass
    return out

def is_main(p):
    return main_tree is not None and len(main_tree.query(p.buffer(12.0))) > 0
main_tree = STRtree(main_polys) if main_polys else None

def stripe(c, t, along, across, w_al, w_ac):
    """a painted rectangle centred c + t*along + n*across, w_al long (along t) and w_ac wide"""
    n = np.array([t[1], -t[0]])
    o = c + t * along + n * across
    pts = [o + t * dx + n * dz for dx, dz in ((-w_al / 2, -w_ac / 2), (w_al / 2, -w_ac / 2), (w_al / 2, w_ac / 2), (-w_al / 2, w_ac / 2))]
    return Polygon(pts)

zebras = sig_x = 0
for c in crossings:
    if not in_area(c.x, c.y): continue
    r = road_at(c, 6.0)
    if r is None: continue
    ls, hs, t, q = r
    near_sig = sig_tree is not None and any(signals[i].distance(c) < 35.0 for i in sig_tree.query(c.buffer(35.0)))
    if near_sig:
        # two white lines across the road 3 m apart
        g = unary_union([stripe(q, t, -1.6, 0.0, 0.2, 2 * hs), stripe(q, t, 1.6, 0.0, 0.2, 2 * hs)])
        add_paint(g, 0.0, 1.0); sig_x += 1
    elif is_main(c):
        # zebra: bars along the traffic, 0.6 m wide, 1.2 m apart, 3 m long
        bars = []
        k = -hs + 0.5
        while k < hs - 0.3:
            bars.append(stripe(q, t, 0.0, k + 0.3, 3.0, 0.6)); k += 1.2
        add_paint(unary_union(bars), 0.0, 1.0); zebras += 1
log("crossings: %d zebras, %d at the lights" % (zebras, sig_x))

# junctions: where three or more sealed pieces meet
deg = collections.Counter()
for g in (noded.geoms if hasattr(noded, "geoms") else [noded]):
    cs = list(g.coords)
    for e in (cs[0], cs[-1]): deg[(round(e[0], 1), round(e[1], 1))] += 1
junc = [Point(k) for k, v in deg.items() if v >= 3]
junc_tree = STRtree(junc) if junc else None

def approach(p):
    """for a point on a road near a junction: (q on the road, unit direction toward the junction, hs, junction)"""
    r = road_at(p, 8.0)
    if r is None or junc_tree is None: return None
    ls, hs, t, q = r
    best = None
    for i in junc_tree.query(Point(q).buffer(40.0)):
        d = junc[i].distance(Point(q))
        if best is None or d < best[0]: best = (d, junc[i])
    if best is None: return None
    j = np.array([best[1].x, best[1].y])
    if np.dot(j - q, t) < 0: t = -t
    return q, t, hs, j

def line_and_sign(p, sign_kind, dashed):
    a = approach(p)
    if a is None: return False
    q, t, hs, j = a
    n_left = np.array([t[1], -t[0]])        # Australia: you keep left; left of travel (x east, z south) is (tz, -tx)
    # sit the line back from the junction a little: a few metres before the crossing road's edge
    d = np.linalg.norm(j - q)
    stop_at = q if d > 6.0 else j - t * 6.0
    if dashed:
        g = unary_union([stripe(stop_at, t, 0.0, s + 0.3, 0.3, 0.6) for s in np.arange(0.2, hs - 0.5, 1.2)])
    else:
        g = stripe(stop_at, t, 0.0, hs / 2 + 0.05, 0.4, hs - 0.2)
    # stripe() lays 'across' along n = (tz, -tx): the left half of the road for travel t
    add_paint(g, 0.0, 1.0)
    sp = stop_at + n_left * (hs + 1.0)
    add_furn(sign_kind, sp[0], sp[1], math.atan2(-t[0], -t[1]))
    return True

FURN = {"signal": 1, "bus_sign": 2, "shelter": 3, "bin": 4, "bench": 5, "lamp": 6, "pole": 7, "stop": 8, "give_way": 9}
ns = sum(line_and_sign(g.centroid, FURN["stop"], False) for g in infra[("transportation", "stop")])
ng = sum(line_and_sign(g.centroid, FURN["give_way"], True) for g in infra[("transportation", "give_way")])
log("stop lines %d, give way lines %d" % (ns, ng))

# traffic lights: a pole on each kerb corner round the junction, facing it, with a stop line on each approach
kerb_pts = []      # every kerb vertex with its profile, for snapping
for k, td in tiles.items():
    for prof, pts, kinds in td["kerb"]:
        for p in pts: kerb_pts.append(p)
KP = np.array(kerb_pts) if kerb_pts else np.zeros((0, 2))
kkd = cKDTree(KP) if len(KP) else None
nsig = 0
for s in signals:
    if not in_area(s.x, s.y) or kkd is None: continue
    idx = kkd.query_ball_point([s.x, s.y], 20.0)
    if not idx: continue
    # corner points: the kerb points nearest the junction in each quadrant round it
    quad = {}
    for i in idx:
        p = KP[i]; v = p - np.array([s.x, s.y]); d = np.linalg.norm(v)
        qd = (int(v[0] > 0), int(v[1] > 0))
        if qd not in quad or d < quad[qd][0]: quad[qd] = (d, p)
    for d, p in quad.values():
        v = np.array([s.x, s.y]) - p; v /= max(np.linalg.norm(v), 1e-6)
        pp = p - v * 0.7
        add_furn(FURN["signal"], pp[0], pp[1], math.atan2(v[0], v[1])); nsig += 1
    # a stop line on each road leaving the junction
    for i in seal_tree.query(s.buffer(12.0)):
        ls, hs, mk = seal[i]
        if ls.distance(s) > 10.0: continue
        sp = ls.project(s)
        for dirn in (-1, 1):
            s2 = sp + dirn * (hs + 9.0)
            if s2 < 0 or s2 > ls.length: continue
            a = ls.interpolate(s2); b = ls.interpolate(min(max(s2 - dirn * 1.0, 0), ls.length))
            t = np.array([b.x - a.x, b.y - a.y]); t /= max(np.linalg.norm(t), 1e-6)   # toward the junction
            add_paint(stripe(np.array([a.x, a.y]), t, 0.0, hs / 2 + 0.05, 0.4, hs - 0.2), 0.0, 1.0)
log("traffic light poles", nsig)

# bus stops: a sign at the kerb on the stop's side, a shelter behind it in town
nbus = 0
for g in infra[("transit", "bus_stop")]:
    c = g.centroid
    if not in_area(c.x, c.y) or kkd is None: continue
    d, i = kkd.query([c.x, c.y], distance_upper_bound=14.0)
    if not np.isfinite(d): continue
    p = KP[i]
    r = road_at(Point(p), 12.0)
    if r is None: continue
    ls, hs, t, q = r
    v = p - q; v /= max(np.linalg.norm(v), 1e-6)            # from the road out to the kerb
    s1 = p + v * 0.6
    add_furn(FURN["bus_sign"], s1[0], s1[1], math.atan2(-v[0], -v[1]))
    s2 = p + v * 2.6
    blocked = len(rect_tree.query(Point(s2).buffer(2.2), predicate="intersects")) > 0
    if not blocked:
        add_furn(FURN["shelter"], s2[0], s2[1], math.atan2(-v[0], -v[1]))
    nbus += 1
log("bus stops", nbus)

for g in infra[("pedestrian", "bench")]: add_furn(FURN["bench"], g.centroid.x, g.centroid.y, 0.0, -1.0)
for g in infra[("waste_management", "waste_basket")]: add_furn(FURN["bin"], g.centroid.x, g.centroid.y, 0.0)
for g in infra[("power", "power_pole")]: add_furn(FURN["pole"], g.centroid.x, g.centroid.y, 0.0)

# ------------------------------------------------------------------ along the kerbs: lights, poles, bins, benches
osm_poles = [g.centroid for g in infra[("power", "power_pole")]]
pole_tree = STRtree(osm_poles) if osm_poles else None
gen = collections.Counter()
for k, td in list(tiles.items()):
    for prof, pts, kinds in td["kerb"]:
        if prof not in (PROF["MAIN"], PROF["TOWN"], PROF["EST"]): continue
        P_ = np.array(pts)
        seg = np.hypot(*(P_[1:] - P_[:-1]).T)
        along = np.concatenate([[0], np.cumsum(seg)])
        step = 26.0 if prof == PROF["MAIN"] else 42.0
        s = (hash((round(pts[0][0]), round(pts[0][1]))) % 100) / 100.0 * step
        while s < along[-1]:
            j = min(int(np.searchsorted(along, s)), len(P_) - 1)
            j0 = max(j - 1, 0)
            a, b = P_[j0], P_[j]
            t = (b - a) / max(np.linalg.norm(b - a), 1e-6); n = np.array([t[1], -t[0]])
            if kinds[j] != prof or kinds[j0] != prof:
                s += 4.0; continue
            p = a + (b - a) * min(1.0, max(0.0, (s - along[j0]) / max(seg[j0] if j0 < len(seg) else 1, 1e-6)))
            yaw = math.atan2(-n[0], -n[1])
            if prof == PROF["MAIN"]:
                lp = p + n * 0.7
                add_furn(FURN["lamp"], lp[0], lp[1], yaw); gen["lamps"] += 1
                i = int(s / step)
                if i % 3 == 1:
                    bp = p + n * 0.9 + t * 3.0
                    add_furn(FURN["bin"], bp[0], bp[1], yaw); gen["bins"] += 1
                elif i % 3 == 2:
                    bp = p + n * 1.6 + t * 6.0
                    add_furn(FURN["bench"], bp[0], bp[1], yaw); gen["benches"] += 1
            else:
                # one side of the street: the side whose block lies north-east of the road
                if n[0] - n[1] > 0.2:
                    lp = p + n * 0.9
                    if pole_tree is None or not pole_tree.query(Point(lp).buffer(30.0)).size:
                        add_furn(FURN["pole"], lp[0], lp[1], yaw, 1.0 if int(s / step) % 2 == 0 else 0.0); gen["poles"] += 1
            s += step
log("street furniture", dict(gen))

# ------------------------------------------------------------------ car parks
mall_rects = [lot_rect[i] for i in range(len(lot_rect)) if lot_kind[i] == "mall"]
mall_zone = unary_union([r.buffer(36.0) for r in mall_rects]) if mall_rects else Polygon()
spaces = [g for g in infra[("transit", "parking_space")] if g.geom_type == "Polygon"]
space_tree = STRtree(spaces) if spaces else None
ncp = nbay = 0
for g in infra[("transit", "parking")]:
    if g.geom_type not in ("Polygon", "MultiPolygon"): continue
    g = g.buffer(0)
    c = g.centroid
    if not in_area(c.x, c.y): continue
    if g.area < 120.0 or g.area > 60000.0: continue
    if mall_zone.intersection(g).area > 0.5 * g.area: continue
    if servo_zone.intersection(g).area > 0.3 * g.area: continue
    bl = [lot_rect[i] for i in rect_tree.query(g)]
    lotg = g.difference(unary_union(bl)) if bl else g
    lotg = lotg.difference(local_roads(g, 1.0))
    if lotg.is_empty: continue
    add_paint(lotg, 0.0)
    lines = []
    own = [spaces[i] for i in space_tree.query(g)] if space_tree is not None else []
    own = [s for s in own if g.contains(s.centroid)]
    if own:
        for s in own: lines.append(s.exterior.buffer(0.06))
        nbay += len(own)
    else:
        mrr = lotg.minimum_rotated_rectangle
        cs = np.array(mrr.exterior.coords)[:4]
        e1, e2 = cs[1] - cs[0], cs[2] - cs[1]
        u, v = (e1, e2) if np.linalg.norm(e1) >= np.linalg.norm(e2) else (e2, e1)
        Lu, Lv = np.linalg.norm(u), np.linalg.norm(v)
        u /= Lu; v /= Lv
        o = cs[0] if np.linalg.norm(e1) >= np.linalg.norm(e2) else cs[1]
        # rows across v: bay 5.4, aisle 6.4, bay 5.4, repeated
        inner = lotg.buffer(-0.4)
        rows = []
        y = 0.0
        while y + 5.4 <= Lv + 0.01:
            rows.append(y); y += 5.4
            if y + 6.4 + 5.4 <= Lv + 0.01:
                y += 6.4; rows.append(y); y += 5.4
            else:
                break
        for y0 in rows:
            x = 0.3
            while x + 2.5 <= Lu:
                p0 = o + u * x + v * y0
                bay = Polygon([p0, p0 + u * 2.5, p0 + u * 2.5 + v * 5.4, p0 + v * 5.4])
                if inner.contains(bay):
                    for xe in (0.0, 2.5):
                        a = p0 + u * xe
                        lines.append(LineString([a + v * 0.2, a + v * 5.2]).buffer(0.06, cap_style="flat"))
                    nbay += 1
                x += 2.5
    if lines: add_paint(unary_union(lines), 0.0, 1.0)
    ncp += 1
log("car parks %d, bays %d" % (ncp, nbay))

# ------------------------------------------------------------------ back yard fences (0.2.56)
# Each town block is cut into property parcels (each house gets the ground nearer to it than to its neighbours, inside
# the property line a verge back from the kerb). A fence runs along every boundary two parcels share, built once, so
# neighbours share it and its corner posts; and along the property line where a yard backs or sides onto a street or
# open ground, but not across the front. It runs from the house fronts back, and not through any building.
FENCE_MAT = {"timber": 0, "colorbond": 1, "brick": 2}
nf = 0
HOUSEY = HOUSE | {"units"}
for p, prof in fence_blocks:
    verge = 3.6 if prof != "EST" else 3.2
    prop = p.buffer(-verge)
    if prop.is_empty or prop.area < 200: continue
    ids = [i for i in lot_tree.query(prop, predicate="contains") if lot_kind[i] not in ("shed", "machine_shed")]
    hs_ = [i for i in ids if lot_kind[i] in HOUSE]
    if len(hs_) < 2: continue
    seeds = shapely.MultiPoint([lot_pts[i] for i in ids])
    cells = shapely.voronoi_polygons(seeds, extend_to=prop.envelope.buffer(50))
    parcels = {}
    for cell in cells.geoms:
        for i in ids:
            if cell.contains(lot_pts[i]):
                pc = cell.intersection(prop)
                if not pc.is_empty: parcels[i] = pc
                break
    keys = list(parcels.keys())
    # in the lot's frame: the front of the house (its walls; a Queenslander's verandah) and the way it faces
    blds = unary_union([lot_rect[i].buffer(0.45) for i in lot_tree.query(prop.buffer(5))])
    def behind(i):
        # the half of the world behind the house's front wall (its own frame, +z the front)
        x, z = lot_pts[i].x, lot_pts[i].y
        r = lot_rect[i]
        cs = np.array(r.exterior.coords)[:4]
        # lot_rect corners were built (-w/2,-d/2),(w/2,-d/2),(w/2,d/2),(-w/2,d/2): the front edge is corners 2-3
        fm = (cs[2] + cs[3]) / 2; ctr = cs.mean(0)
        fdir = fm - ctr; L_ = np.linalg.norm(fdir)
        if L_ < 1e-6: return Polygon(), np.array([0.0, 1.0])
        fdir /= L_
        sdir = np.array([fdir[1], -fdir[0]])
        vf = 2.6 if lot_kind[i] == "qlder" else 0.0
        a = fm + fdir * vf
        big = 200.0
        poly = Polygon([a + sdir * big, a - sdir * big, a - sdir * big - fdir * big, a + sdir * big - fdir * big])
        return poly, fdir
    beh = {i: behind(i) for i in keys}
    def mat_for(i, j):
        ki, kj = lot_kind[i], (lot_kind[j] if j is not None else lot_kind[i])
        if "qlder" in (ki, kj) or "cottage" in (ki, kj): return "timber"
        return "colorbond"
    def emit(g, i, j):
        global nf
        if g.is_empty: return
        g = g.difference(blds)
        for ln in getattr(g, "geoms", [g]):
            if ln.geom_type != "LineString" or ln.length < 0.8: continue
            cs = [tuple(np.round(c, 3)) for c in ln.coords]
            m = mat_for(i, j)
            col = abs(hash((min(i, j if j is not None else i), max(i, j if j is not None else i)))) % 5
            mid = ln.interpolate(0.5, normalized=True)
            if not in_area(mid.x, mid.y): continue
            tiles[tkey(mid.x, mid.y)]["fence"].append((FENCE_MAT[m], col, cs))
            nf += 1
    ptree = STRtree([parcels[i] for i in keys])
    for a_, i in enumerate(keys):
        if lot_kind[i] not in HOUSE: continue
        pi = parcels[i]
        # shared with each neighbour (built by the lower index of a pair where both are houses)
        for b_ in ptree.query(pi):
            j = keys[b_]
            if j == i: continue
            if lot_kind[j] in HOUSE and j < i: continue
            sh = pi.boundary.intersection(parcels[j].boundary)
            if sh.is_empty or sh.length < 0.8: continue
            sh = shapely.line_merge(sh) if sh.geom_type == "MultiLineString" else sh
            zone = unary_union([beh[i][0].intersection(pi), beh[j][0].intersection(parcels[j])]) if j in beh else beh[i][0]
            emit(sh.intersection(zone.buffer(0.05)), i, j)
        # the property line, except across the front (and within 45 m of the house)
        pl = pi.boundary.intersection(prop.boundary.buffer(0.05))
        pl = pl.intersection(lot_pts[i].buffer(45.0))
        fdir = beh[i][1]
        for ln in getattr(pl, "geoms", [pl]):
            if ln.geom_type != "LineString": continue
            cs = np.array(ln.coords)
            keep = []
            for q0, q1 in zip(cs[:-1], cs[1:]):
                t = q1 - q0; L_ = np.linalg.norm(t)
                if L_ < 1e-6: continue
                n = np.array([t[1], -t[0]]) / L_
                m = (q0 + q1) / 2
                if pi.contains(Point(m + n * 0.3)): n = -n          # outward
                if np.dot(n, fdir) > 0.45:
                    if len(keep) >= 2: emit(LineString(keep), i, None)
                    keep = []
                    continue
                if not keep: keep = [tuple(q0)]
                keep.append(tuple(q1))
            if len(keep) >= 2: emit(LineString(keep).intersection(beh[i][0].buffer(0.05)), i, None)
log("fences: %d runs" % nf)

# ------------------------------------------------------------------ the hard ground mask (no plants): 1 m bits per tile
def raster_mask(td, k):
    if not td["paint"] and not td["kerb"]: return b""
    N = 128
    m = np.zeros((N, N), bool)
    ox, oz = X0 + k[0] * TILE, Z0 + k[1] * TILE
    from matplotlib.path import Path as MPath
    gx, gz = np.meshgrid(np.arange(N) + 0.5 + ox, np.arange(N) + 0.5 + oz)
    G = np.stack([gx.ravel(), gz.ravel()], 1)
    for surf, style, tri in td["paint"]:
        if style > 0.5: continue
        for t in tri.reshape(-1, 3, 2):
            mn = t.min(0); mx = t.max(0)
            i0 = max(int(mn[0] - ox), 0); i1 = min(int(mx[0] - ox) + 1, N)
            j0 = max(int(mn[1] - oz), 0); j1 = min(int(mx[1] - oz) + 1, N)
            if i0 >= i1 or j0 >= j1: continue
            sub = np.stack(np.meshgrid(np.arange(i0, i1) + 0.5 + ox, np.arange(j0, j1) + 0.5 + oz), -1).reshape(-1, 2)
            inside = MPath(t).contains_points(sub, radius=0.3).reshape(j1 - j0, i1 - i0)
            m[j0:j1, i0:i1] |= inside
    for prof, pts, kinds in td["kerb"]:
        for p in pts:
            i = int(p[0] - ox); j = int(p[1] - oz)
            if 0 <= i < N and 0 <= j < N: m[j, i] = True
    return zlib.compress(np.packbits(m.ravel()).tobytes(), 9)

# ------------------------------------------------------------------ write
def wtile(k, td):
    b = bytearray()
    b += struct.pack("<I", len(td["kerb"]))
    for prof, pts, kinds in td["kerb"]:
        b += struct.pack("<II", prof, len(pts))
        for (x, z), kd in zip(pts, kinds): b += struct.pack("<ffI", x, z, kd)
    b += struct.pack("<I", len(td["paint"]))
    for surf, style, tri in td["paint"]:
        b += struct.pack("<ffI", surf, style, len(tri)) + tri.astype("<f4").tobytes()
    b += struct.pack("<I", len(td["furn"]))
    for kind, x, z, yaw, prm in td["furn"]: b += struct.pack("<Iffff", kind, x, z, yaw, prm)
    # raised slabs (shopping-street footpaths): triangles plus the outline for the skirt
    # each slab vertex carries its anchor: the nearest point on the kerb line, whose road level the footpath keeps
    # (0.2.55: a footpath no longer climbs the bank behind the shops)
    def anchored(a, kl):
        pts = shapely.points(a.astype(np.float64))
        q = shapely.line_interpolate_point(kl, shapely.line_locate_point(kl, pts))
        qa = np.stack([shapely.get_x(q), shapely.get_y(q)], 1)
        return np.hstack([a, qa]).astype("<f4")
    slabs = []
    for sp, kl in td["slab"]:
        sp = sp.simplify(0.05)
        if sp.is_empty or sp.geom_type != "Polygon": continue
        rings = [np.array(sp.exterior.coords)[:-1]] + [np.array(r.coords)[:-1] for r in sp.interiors]
        rings = [r for r in rings if len(r) >= 3]
        v = np.concatenate(rings); ends = np.cumsum([len(r) for r in rings]).astype(np.uint32)
        idx = earcut.triangulate_float64(v, ends)
        if len(idx) == 0: continue
        slabs.append((anchored(v[idx], kl), [anchored(np.vstack([r, r[:1]]), kl) for r in rings]))
    b += struct.pack("<I", len(slabs))
    for tri, rings in slabs:
        b += struct.pack("<I", len(tri)) + tri.tobytes()          # 4 floats a vertex: x, z, anchor x, anchor z
        b += struct.pack("<I", len(rings))
        for r in rings: b += struct.pack("<I", len(r)) + r.tobytes()
    b += struct.pack("<I", len(td["fence"]))
    for m, col, cs in td["fence"]:
        b += struct.pack("<III", m, col, len(cs))
        for x, z in cs: b += struct.pack("<ff", x, z)
    mk = raster_mask(td, k)
    mask_at = len(b)
    b += struct.pack("<I", len(mk)) + mk
    return bytes(b), mask_at

out = f"{GAME}/assets/world/streets.bin"
keys = sorted(k for k, td in tiles.items() if td["kerb"] or td["paint"] or td["furn"] or td["slab"] or td["fence"])
blobs = [wtile(k, tiles[k]) for k in keys]
with open(out, "wb") as f:
    # STR3: each index entry also says where the tile's plant mask starts, so veg can read it without the rest
    f.write(b"STR3" + struct.pack("<ffI", X0, Z0, len(keys)))
    off = 16 + len(keys) * 20
    for k, (bl, ma) in zip(keys, blobs):
        f.write(struct.pack("<iiIII", k[0], k[1], off, len(bl), ma)); off += len(bl)
    for bl, ma in blobs: f.write(bl)
log("wrote %s: %d tiles, %.1f MB" % (out, len(keys), os.path.getsize(out) / 1e6))
json.dump({k: (round(v) if isinstance(v, float) else v) for k, v in stats.items()}, open(f"{GAME}/docs/ref/streets/stats.json", "w"), indent=1)
