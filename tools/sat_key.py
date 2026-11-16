#!/usr/bin/env python3
"""0.2.53 ground key pilot: turn the imagery (tools/sat_fetch.py) into what the game paints from.
  python3 tools/sat_key.py NAME
Outputs (assets/world/ground_key/):
  NAME_class.bin.gz  R8, 0.25 m a texel, rows = z: what the ground is. 0 leave the terrain as it is (trees, water,
                     rough ground), 1 road asphalt, 2 car park / lane asphalt (worn), 3 concrete, 4 pavers, 5 lawn,
                     6 dirt, 7 gravel, 9 asphalt with yellow paint on it
  NAME_marks.bin.gz  R8, 0.125 m: the painted lines as a distance field (128 = the paint's edge, 0.3 m each way)
  NAME_kerbs.json    kerb lines (road on the left going along: left = (-dz, dx)) and the islands
  NAME.json          where it lies
How: the photo's colour and texture, taught by what the map data already says (the road seals, car parks, parks,
footpaths), a random forest over every pixel; roofs (the game's own building lots) and shadows filled from the
ground round them; the road seals kept as road under cars and trees. Painted lines: bright thin things on the
asphalt (cars are too wide to pass). Kerbs: where road meets footpath, pavers or lawn.
Imagery (c) Spatial Services, NSW Department of Customer Service, CC BY 4.0."""
import gzip, json, math, os, sys, time
import numpy as np, cv2
from PIL import Image
from sklearn.ensemble import RandomForestClassifier
sys.path.insert(0, os.path.dirname(__file__))
import geo, road_lines
Image.MAX_IMAGE_PIXELS = None
G = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..") + "/"
name = sys.argv[1] if len(sys.argv) > 1 else "pilot"
PREV = "/tmp/key"; os.makedirs(PREV, exist_ok=True)
OUT = G + "assets/world/ground_key/"; os.makedirs(OUT, exist_ok=True)
meta = json.load(open(G + "docs/ref/sat/%s.json" % name))
X0, Z0, X1, Z1 = meta["x0"], meta["z0"], meta["x1"], meta["z1"]
R = 0.25
N = int(round((X1 - X0) / R))
t0 = time.time()
def log(*a): print("[%5.0fs]" % (time.time() - t0), *a, flush=True)
def to_px(x, z, res=R): return (np.asarray(x) - X0) / res, (np.asarray(z) - Z0) / res
def ring_px(ring, res=R):
    pts = [geo.ll(lo, la) for lo, la in ring]
    px, pz = to_px([p[0] for p in pts], [p[1] for p in pts], res)
    return np.round(np.stack([px, pz], 1)).astype(np.int32)
def gj(t):
    f = G + "docs/ref/sat/osm/%s_%s.geojsonl" % (name, t)
    if os.path.exists(f):
        for line in open(f): yield json.loads(line)
def polys(geom):
    if geom["type"] == "Polygon": return [geom["coordinates"]]
    if geom["type"] == "MultiPolygon": return geom["coordinates"]
    return []

# ------------------------------------------------------------------ the photo and what the map data says
rgb_full = np.asarray(Image.open(G + "docs/ref/sat/%s_rgb.png" % name).convert("RGB"))
small = cv2.resize(rgb_full, (N, N), interpolation=cv2.INTER_AREA).astype(np.float32) / 255.0
log("photo", rgb_full.shape)
seal = np.zeros((N, N), np.uint8)
for hs, sf, a in road_lines.read(G + "assets/roads/lines.bin"):
    if a[:, 0].max() < X0 - 20 or a[:, 0].min() > X1 + 20 or a[:, 1].max() < Z0 - 20 or a[:, 1].min() > Z1 + 20: continue
    px, pz = to_px(a[:, 0], a[:, 1])
    cv2.polylines(seal, [np.round(np.stack([px, pz], 1) * 4).astype(np.int32)], False, 1, max(1, int(round(2 * hs / R))), shift=2)
roof = np.zeros((N, N), np.uint8)
for l in json.load(open(G + "assets/world/buildings.json"))["lots"]:
    x, z, y, w, d = l[1:6]
    if not (X0 - 80 < x < X1 + 80 and Z0 - 80 < z < Z1 + 80): continue
    c, s = math.cos(y), math.sin(y)
    pts = [(x + c * lx + s * lz, z - s * lx + c * lz) for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]
    px, pz = to_px([p[0] for p in pts], [p[1] for p in pts])
    cv2.fillPoly(roof, [np.round(np.stack([px, pz], 1)).astype(np.int32)], 1)
roof = cv2.dilate(roof, np.ones((3, 3), np.uint8))
park = np.zeros((N, N), np.uint8); green = np.zeros((N, N), np.uint8); foot = np.zeros((N, N), np.uint8); water = np.zeros((N, N), np.uint8)
for g in gj("infrastructure"):
    if g["properties"].get("class") == "parking":
        for pl in polys(g["geometry"]): cv2.fillPoly(park, [ring_px(pl[0])], 1)
for g in gj("land_use"):
    if g["properties"].get("class") in ("park", "grass", "recreation_ground", "pitch"):
        for pl in polys(g["geometry"]): cv2.fillPoly(green, [ring_px(pl[0])], 1)
for g in gj("segment"):
    if g["properties"].get("class") in ("footway", "path", "cycleway") and g["geometry"]["type"] == "LineString":
        cv2.polylines(foot, [ring_px(g["geometry"]["coordinates"])], False, 1, 7)
for g in gj("water"):
    for pl in polys(g["geometry"]): cv2.fillPoly(water, [ring_px(pl[0])], 1)
log("map data: seal %d park %d green %d foot %d water %d roof %d" % (seal.sum(), park.sum(), green.sum(), foot.sum(), water.sum(), roof.sum()))

# ------------------------------------------------------------------ the user's own tags (Ground Tagger artifact)
# docs/ref/sat/NAME_tags.json: [{kind: stroke|area|line|point|note, cls, pts [[x, z]...], r, text}] in game metres
TAG_CLS = {"road": 1, "carpark": 2, "concrete": 3, "pavers": 4, "lawn": 5, "garden": 6, "dirt": 6, "gravel": 7, "trees": 10, "water": 11, "building": 12}
tags = []
tf = G + "docs/ref/sat/%s_tags.json" % name
if os.path.exists(tf): tags = json.load(open(tf))
told = np.zeros((N, N), np.uint8)               # 0 = not tagged, else TAG_CLS value
for t in sorted([t for t in tags if t.get("kind") in ("area", "stroke")], key=lambda t: t["kind"] == "stroke"):
    v = TAG_CLS.get(t.get("cls"))
    if not v: continue
    px, pz = to_px([p[0] for p in t["pts"]], [p[1] for p in t["pts"]])
    pts = np.round(np.stack([px, pz], 1) * 4).astype(np.int32)
    if t["kind"] == "area": cv2.fillPoly(told, [pts], v, shift=2)
    else:
        r = max(1, int(round(float(t.get("r", 1.0)) / R)))
        if len(pts) == 1: cv2.circle(told, (int(pts[0][0]) >> 2, int(pts[0][1]) >> 2), r, v, -1)
        else: cv2.polylines(told, [pts], False, v, 2 * r, shift=2)
roof[told == 12] = 1
water[told == 11] = 1
log("tags: %d (%d px told)" % (len(tags), int((told > 0).sum())))

# ------------------------------------------------------------------ features
hsv = cv2.cvtColor(small, cv2.COLOR_RGB2HSV)            # h 0..360, s, v 0..1
lum = small.mean(2)
exg = (2 * small[:, :, 1] - small[:, :, 0] - small[:, :, 2]) / (small.sum(2) + 1e-3)
rb = small[:, :, 0] - small[:, :, 2]
def lsd(img, k):
    m = cv2.blur(img, (k, k)); return np.sqrt(np.maximum(cv2.blur(img * img, (k, k)) - m * m, 0))
feats = [small[:, :, 0], small[:, :, 1], small[:, :, 2], hsv[:, :, 1], lum, exg, rb, lsd(lum, 3), lsd(lum, 7), lsd(exg, 7),
         cv2.blur(lum, (9, 9)), cv2.blur(exg, (9, 9)), cv2.blur(rb, (9, 9)), cv2.blur(hsv[:, :, 1], (9, 9)), lum - cv2.blur(lum, (25, 25))]
F = np.stack(feats, -1).reshape(-1, len(feats))
log("features", F.shape)
# teaching labels: 1 asphalt, 3 concrete, 4 pavers, 5 lawn, 10 tree canopy, 6 dirt
sd7 = feats[8]
lab = np.zeros((N, N), np.uint8)
inner = cv2.erode(seal, np.ones((7, 7), np.uint8)) > 0
lab[(inner | (cv2.erode(park, np.ones((5, 5), np.uint8)) > 0)) & (lum < 0.55) & (hsv[:, :, 1] < 0.22) & (exg < 0.09)] = 1
lab[(foot > 0) & (seal == 0) & (lum > 0.52) & (hsv[:, :, 1] < 0.16) & (exg < 0.08)] = 3
lab[(foot > 0) & (seal == 0) & (rb > 0.1) & (hsv[:, :, 1] > 0.24) & (exg < 0.05) & (lum > 0.3)] = 4
lab[(green > 0) & (exg > 0.12) & (sd7 < 0.035) & (lum > 0.25)] = 5
lab[(exg > 0.08) & (sd7 > 0.06) & (lum < 0.4) & (seal == 0)] = 10
lab[(green > 0) & (exg < 0.02) & (rb > 0.09) & (hsv[:, :, 1] > 0.22) & (sd7 < 0.05)] = 6
for v, k in ((1, 1), (2, 1), (3, 3), (4, 4), (5, 5), (6, 6), (7, 6), (10, 10)):
    lab[told == v] = k
lab[roof > 0] = 0
lab[water > 0] = 0
counts = {int(k): int((lab == k).sum()) for k in (1, 3, 4, 5, 6, 10)}
log("teaching pixels", counts)
rng = np.random.default_rng(1)
idx = []
for k, n in counts.items():
    if n == 0: continue
    ii = np.flatnonzero(lab.ravel() == k)
    idx.append(rng.choice(ii, min(n, 40000), replace=False))
idx = np.concatenate(idx)
rf = RandomForestClassifier(n_estimators=40, max_depth=16, min_samples_leaf=4, n_jobs=-1, random_state=1)
rf.fit(F[idx], lab.ravel()[idx])
pred = np.zeros(F.shape[0], np.uint8)
step = 2_000_000
for i in range(0, F.shape[0], step):
    pred[i:i + step] = rf.predict(F[i:i + step])
cls = pred.reshape(N, N)
log("forest done", {int(k): int((cls == k).sum()) for k in np.unique(cls)})

# ------------------------------------------------------------------ clean up with what we know
# gravel: light, warm, grainy, not green, not road (the forest wasn't taught it)
cls[(cls == 3) & (rb > 0.07) & (feats[7] > 0.035) & (hsv[:, :, 1] > 0.14) & (seal == 0)] = 7
# the road seals stay road under cars, shadows and overhanging trees (the edges are the photo's)
core = cv2.erode(seal, np.ones((5, 5), np.uint8)) > 0
cls[core & (cls != 3)] = 1
# car parks: worn asphalt (not their gardens and trees)
cls[(park > 0) & (cls == 1)] = 2
cls[(seal == 0) & (cls == 1) & (park == 0)] = 2             # asphalt off the streets: lanes, yards, drives
cls[water > 0] = 0
# shadows (very dark, not water, not under trees) and roofs: filled from the ground round them
shadow = (lum < 0.16) & (water == 0) & (cls != 10)
hole = (roof > 0) | shadow
dist, lab_idx = cv2.distanceTransformWithLabels(hole.astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
ys, xs = np.nonzero(~hole)
lut = np.zeros(lab_idx.max() + 1, np.uint8)
lut[lab_idx[~hole]] = cls[~hole]
filled = lut[lab_idx]
cls = np.where(hole, filled, cls)
# under a roof: no trees, no road - lawn if it was green round it, concrete otherwise
cls[(roof > 0) & (cls == 10)] = 5
cls[(roof > 0) & np.isin(cls, (1, 2))] = 3
# what the user tagged is what it is
for v, k in ((1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (10, 10), (11, 0)):
    cls[told == v] = k
# smooth: the commonest class over 1.25 m
oh = np.stack([(cls == k).astype(np.float32) for k in range(11)], -1)
for k in range(11): oh[:, :, k] = cv2.blur(oh[:, :, k], (5, 5))
cls = oh.argmax(-1).astype(np.uint8)
cls[core & (cls != 3) & (cls != 4)] = 1
for v, k in ((1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (11, 0)):
    cls[told == v] = k                                        # tags survive the smoothing too
cls[cls == 10] = 0                                            # trees: the terrain and its trees do those
log("classes", {int(k): int((cls == k).sum()) for k in np.unique(cls)})

# ------------------------------------------------------------------ painted lines (0.125 m)
RF_ = 0.125
NF = rgb_full.shape[0]
lumf = cv2.cvtColor(rgb_full, cv2.COLOR_RGB2GRAY)
hsvf = cv2.cvtColor(rgb_full, cv2.COLOR_RGB2HSV)
asph = cv2.resize(np.isin(cls, (1, 2)).astype(np.uint8), (NF, NF), interpolation=cv2.INTER_NEAREST)
asph = cv2.erode(asph, np.ones((5, 5), np.uint8))
bg = cv2.medianBlur(lumf, 15)
white = ((lumf.astype(np.int16) - bg) > 28) & (hsvf[:, :, 1] < 70) & (asph > 0)
yellow = (hsvf[:, :, 0] >= 15) & (hsvf[:, :, 0] <= 34) & (hsvf[:, :, 1] > 90) & (hsvf[:, :, 2] > 110) & (asph > 0)
paint = (white | yellow).astype(np.uint8)
paint = cv2.morphologyEx(paint, cv2.MORPH_CLOSE, np.ones((2, 2), np.uint8))
n, cc, st, _ = cv2.connectedComponentsWithStats(paint, 8)
dt = cv2.distanceTransform(paint, cv2.DIST_L2, 3)
maxw = np.zeros(n, np.float32)
np.maximum.at(maxw, cc.ravel(), dt.ravel())
keep = np.zeros(n, bool)
for i in range(1, n):
    a = st[i, cv2.CC_STAT_AREA]
    bw, bh = st[i, cv2.CC_STAT_WIDTH], st[i, cv2.CC_STAT_HEIGHT]
    if a < 6 or maxw[i] > 3.6: continue                      # specks; anything wider than ~0.8 m (a car)
    if a < 40 and max(bw, bh) < 3.0 * max(1, min(bw, bh)): continue   # small and squat: not a line
    keep[i] = True
paint = keep[cc].astype(np.uint8)
yellow_u8 = (yellow & (paint > 0)).astype(np.uint8)
# painted lines the user drew (0.12 m wide; dashed: 3 m on, 6 m off)
for t in tags:
    if t.get("kind") != "line" or t.get("cls") not in ("white", "whitedash", "yellow"): continue
    pts = [np.array(p, np.float64) for p in t["pts"]]
    segs = []
    if t["cls"] == "whitedash":
        acc = 0.0
        for a, b in zip(pts[:-1], pts[1:]):
            L = np.linalg.norm(b - a); u = 0.0
            while u < L:
                ph = acc % 9.0; step = (3.0 - ph) if ph < 3.0 else (9.0 - ph)
                v = min(u + step, L)
                if ph < 3.0: segs.append((a + (b - a) * u / L, a + (b - a) * v / L))
                acc += v - u; u = v
    else:
        segs = list(zip(pts[:-1], pts[1:]))
    for a, b in segs:
        ax, az = to_px(a[0], a[1], RF_); bx, bz = to_px(b[0], b[1], RF_)
        cv2.line(paint, (int(round(ax * 4)), int(round(az * 4))), (int(round(bx * 4)), int(round(bz * 4))), 1, 1, shift=2)
        if t["cls"] == "yellow":
            cv2.line(yellow_u8, (int(round(ax * 4)), int(round(az * 4))), (int(round(bx * 4)), int(round(bz * 4))), 1, 1, shift=2)
log("paint px", int(paint.sum()), "components kept", int(keep.sum()))
# yellow: mark the class texels that hold yellow paint
ysmall = cv2.resize(yellow_u8, (N, N), interpolation=cv2.INTER_AREA)
cls[(ysmall > 0) & np.isin(cls, (1, 2))] = 9
# a distance field at twice the resolution, stored at 0.125 m
marks = np.zeros((NF, NF), np.uint8)
T = 1000; PAD = 16
for j in range(0, NF, T):
    for i in range(0, NF, T):
        j0, j1, i0, i1 = max(0, j - PAD), min(NF, j + T + PAD), max(0, i - PAD), min(NF, i + T + PAD)
        tile = paint[j0:j1, i0:i1].astype(np.float32)
        up = cv2.resize(cv2.GaussianBlur(tile, (3, 3), 0.6), ((i1 - i0) * 2, (j1 - j0) * 2), interpolation=cv2.INTER_LINEAR) > 0.42
        u8 = up.astype(np.uint8)
        din = cv2.distanceTransform(u8, cv2.DIST_L2, 5)
        dout = cv2.distanceTransform(1 - u8, cv2.DIST_L2, 5)
        sdf = np.clip((din - dout) * (RF_ / 2), -1.0, 1.0)       # metres, + inside the paint
        sdf = cv2.resize(sdf, (i1 - i0, j1 - j0), interpolation=cv2.INTER_AREA)
        sdf = cv2.GaussianBlur(sdf, (0, 0), 1.1) - 0.015          # straighter edges, a touch thinner (real lines are 0.1-0.15 m)
        v = np.clip(128 + sdf / 0.3 * 127, 0, 255).astype(np.uint8)
        marks[j:min(NF, j + T), i:min(NF, i + T)] = v[j - j0:j - j0 + min(T, NF - j), i - i0:i - i0 + min(T, NF - i)]
log("distance field")

# ------------------------------------------------------------------ kerbs and islands
road = np.isin(cls, (1, 2, 9)).astype(np.uint8)
road = cv2.morphologyEx(road, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
road = cv2.morphologyEx(road, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
# cars parked on the asphalt look like little islands: holes in the road smaller than a car park space (or in a car
# park, without grass) are asphalt with a car on it
cs, hh = cv2.findContours(road, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
cars = 0
for i, cnt in enumerate(cs):
    if hh[0][i][3] < 0: continue
    a = cv2.contourArea(cnt) * R * R
    if a > 60: continue
    m = np.zeros((N, N), np.uint8); cv2.drawContours(m, [cnt], -1, 1, -1)
    inside = cls[m > 0]
    grassy = (inside == 5).mean() if inside.size else 0
    in_park = park[m > 0].mean() if inside.size else 0
    if (a < 14 and grassy < 0.5) or (in_park > 0.5 and grassy < 0.3):
        road[m > 0] = 1
        cls[(m > 0) & ~np.isin(cls, (1, 2, 9))] = 2 if in_park > 0.5 else 1
        cars += 1
log("cars filled", cars)
kerb_side = np.isin(cls, (3, 4, 5)) & (road == 0)
# kerbs only along the streets (within 6 m of a mapped road seal), not round every yard and slab
street = cv2.dilate(seal, np.ones((25, 25), np.uint8)) > 0
def px2w(p): return [round(X0 + (float(p[0]) + 0.5) * R, 2), round(Z0 + (float(p[1]) + 0.5) * R, 2)]
contours, hier = cv2.findContours(road, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
kerbs = []; islands = []
def runs_of(cnt):
    c = cnt[:, 0, :].astype(np.float32)
    n = len(c)
    if n < 12: return []
    out = []
    flags = np.zeros(n, bool)
    for k in range(n):
        a = c[(k - 3) % n]; b = c[(k + 3) % n]
        t = b - a; L = np.hypot(*t)
        if L < 1e-3: continue
        nrm = np.array([-t[1], t[0]]) / L
        for sgn in (1, -1):
            q = c[k] + nrm * sgn * 3.0                          # 0.75 m either side
            qx, qy = int(round(q[0])), int(round(q[1]))
            if 0 <= qx < N and 0 <= qy < N and road[qy, qx] == 0 and kerb_side[qy, qx] and street[qy, qx]:
                flags[k] = True
    # split into runs of kerb, at least 3 m
    k = 0
    start = None
    seq = list(range(n)) + list(range(min(n, 40)))
    seen = set()
    cur = []
    for k in seq:
        if flags[k] and k not in seen:
            cur.append(k); seen.add(k)
        else:
            if len(cur) >= 12: out.append(c[cur])
            cur = []
    if len(cur) >= 12: out.append(c[cur])
    return out
def oriented(poly):
    """road on the left going along (left = (-dz, dx)); the pixel steps smoothed out (1 m), then simplified to 5 cm"""
    poly = poly.astype(np.float32)
    if len(poly) >= 9:
        k = np.exp(-0.5 * (np.arange(-8, 9) / 4.0) ** 2); k /= k.sum()
        pad = np.concatenate([np.repeat(poly[:1], 8, 0), poly, np.repeat(poly[-1:], 8, 0)])
        poly = np.stack([np.convolve(pad[:, 0], k, "valid"), np.convolve(pad[:, 1], k, "valid")], 1)
    p = cv2.approxPolyDP(poly.reshape(-1, 1, 2).astype(np.float32), 0.2, False)[:, 0, :]
    if len(p) < 2: return None
    votes = 0
    for a, b in zip(p[:-1], p[1:]):
        t = b - a; L = np.hypot(*t)
        if L < 1e-3: continue
        m = (a + b) / 2 + np.array([-t[1], t[0]]) / L * 2.5
        mx, my = int(round(m[0])), int(round(m[1]))
        if 0 <= mx < N and 0 <= my < N: votes += 1 if road[my, mx] else -1
    if votes < 0: p = p[::-1]
    return [px2w(q) for q in p]
for i, cnt in enumerate(contours):
    is_hole = hier[0][i][3] >= 0
    area = cv2.contourArea(cnt) * R * R
    if is_hole and 1.5 < area < 600 and street[int(cnt[0][0][1]), int(cnt[0][0][0])]:
        m = np.zeros((N, N), np.uint8); cv2.drawContours(m, [cnt], -1, 1, -1)
        inside = cls[(m > 0) & (road == 0)]
        if inside.size:
            fill = {3: "concrete", 4: "pavers", 5: "grass"}.get(int(np.bincount(inside, minlength=11)[[3, 4, 5]].argmax() + 3), "concrete")
            if np.isin(inside, (0, 6, 7)).mean() < 0.6:
                cp = cnt[:, 0, :].astype(np.float32)
                if len(cp) >= 9:
                    k = np.exp(-0.5 * (np.arange(-4, 5) / 2.0) ** 2); k /= k.sum()
                    pad = np.concatenate([cp[-4:], cp, cp[:4]])
                    cp = np.stack([np.convolve(pad[:, 0], k, "valid"), np.convolve(pad[:, 1], k, "valid")], 1)
                poly = cv2.approxPolyDP(cp.reshape(-1, 1, 2).astype(np.float32), 0.2, True)[:, 0, :]
                islands.append({"poly": [px2w(q) for q in poly], "fill": fill, "area": round(area, 1)})
    for run in runs_of(cnt):
        o = oriented(run)
        if o and len(o) >= 2: kerbs.append(o)
# kerbs: "no kerb" and "edge of the bitumen" lines rub out what was found within 1.5 m; drawn kerbs go in as drawn
rub = np.zeros((N, N), np.uint8)
for t in tags:
    if t.get("kind") == "line" and t.get("cls") in ("nokerb", "edge"):
        px, pz = to_px([p[0] for p in t["pts"]], [p[1] for p in t["pts"]])
        cv2.polylines(rub, [np.round(np.stack([px, pz], 1) * 4).astype(np.int32)], False, 1, 12, shift=2)
def cut(line):
    out, cur = [], []
    for p in line:
        i, j = int((p[0] - X0) / R), int((p[1] - Z0) / R)
        if 0 <= i < N and 0 <= j < N and rub[j, i]:
            if len(cur) >= 2: out.append(cur)
            cur = []
        else: cur.append(p)
    if len(cur) >= 2: out.append(cur)
    return out
kerbs = [c for k in kerbs for c in cut(k)]
for t in tags:
    if t.get("kind") == "line" and t.get("cls") == "kerb" and len(t["pts"]) >= 2:
        p = np.array([to_px(q[0], q[1]) for q in t["pts"]], np.float32)
        o = oriented(p)
        if o: kerbs.append(o)
features = [{"kind": t["cls"], "at": t["pts"][0]} for t in tags if t.get("kind") == "point"]
notes = [{"text": t.get("text", ""), "at": t["pts"][0]} for t in tags if t.get("kind") == "note"]
# a roundabout with a garden: the island round that point gets a garden fill (or a 4 m one if none was found)
for f in features:
    if f["kind"] != "rgarden": continue
    best = None
    for isl in islands:
        poly = np.array(isl["poly"], np.float32)
        if cv2.pointPolygonTest(poly, (float(f["at"][0]), float(f["at"][1])), False) >= 0: best = isl
    if best: best["fill"] = "garden"
    else:
        islands.append({"poly": [[round(f["at"][0] + 4 * math.cos(a), 2), round(f["at"][1] + 4 * math.sin(a), 2)] for a in np.linspace(0, 2 * math.pi, 24, endpoint=False)], "fill": "garden", "area": 50.0})
        kerbs.append([[round(f["at"][0] + 4 * math.cos(a), 2), round(f["at"][1] - 4 * math.sin(a), 2)] for a in np.linspace(0, 2 * math.pi, 25)])
klen = sum(sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(k[:-1], k[1:])) for k in kerbs)
log("kerbs %d (%.1f km), islands %d" % (len(kerbs), klen / 1000, len(islands)))

# ------------------------------------------------------------------ write
open(OUT + name + "_class.bin.gz", "wb").write(gzip.compress(cls.tobytes(), 9))
open(OUT + name + "_marks.bin.gz", "wb").write(gzip.compress(marks.tobytes(), 9))
json.dump({"kerbs": kerbs, "islands": islands, "features": features, "notes": notes}, open(OUT + name + "_kerbs.json", "w"), separators=(",", ":"))
json.dump({"x0": X0, "z0": Z0, "x1": X1, "z1": Z1, "class_res": R, "class_n": N, "marks_res": RF_, "marks_n": NF,
           "classes": {"0": "terrain", "1": "road", "2": "worn asphalt", "3": "concrete", "4": "pavers", "5": "lawn", "6": "dirt", "7": "gravel", "9": "yellow paint"},
           "source": meta.get("source", "")}, open(OUT + name + ".json", "w"), indent=1)
# previews
pal = np.array([[60, 110, 50], [55, 55, 60], [95, 95, 100], [200, 200, 195], [170, 90, 70], [120, 200, 90], [140, 100, 60], [190, 170, 140], [0, 0, 0], [220, 200, 0], [30, 80, 30]], np.uint8)
prev = pal[cls]
pm = cv2.resize(marks, (N, N), interpolation=cv2.INTER_AREA) > 128
prev[pm] = [255, 255, 255]
for k in kerbs:
    pts = np.array([[(p[0] - X0) / R, (p[1] - Z0) / R] for p in k], np.int32)
    cv2.polylines(prev, [pts], False, (255, 0, 255), 1)
for isl in islands:
    pts = np.array([[(p[0] - X0) / R, (p[1] - Z0) / R] for p in isl["poly"]], np.int32)
    cv2.polylines(prev, [pts], True, (0, 255, 255), 1)
Image.fromarray(prev).save(PREV + "/%s_classes.png" % name)
log("written")
