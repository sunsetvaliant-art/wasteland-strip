#!/usr/bin/env python3
"""The country north of the old map edge (z = -16960), three kilometres of it: the border towns.
Heights from the Mapzen/AWS terrarium tiles (Geoscience Australia's coastal DEM where it has it), roads and buildings
from OpenStreetMap (data/north/osm.json, an Overpass extract of the strip). Writes
  assets/world/north_h.bin    heights on the 5 m grid (uint16, centimetres + 1000), with a small header
  assets/roads/lines_north.bin  road centrelines in the same form as lines.bin
  data/north/bld.json         the buildings, for place_north (lots)
usage: bake_north.py"""
import json, math, os, struct, urllib.request, io
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, map_coordinates
GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAT0, LON0 = -28.3285718, 153.4035024
KX = 111320 * math.cos(math.radians(LAT0)); KZ = 110574
X0, Z0 = -8960.0, -16960.0
XA, XB = 8480.0, 15360.0          # the strip, east-west
ZN = Z0 - 3000.0                  # its north edge
def gx(lon): return (lon - LON0) * KX
def gz(lat): return -(lat - LAT0) * KZ
def lat_of(z): return LAT0 - z / KZ
def lon_of(x): return LON0 + x / KX
CACHE = f"{GAME}/data/north/tiles"; os.makedirs(CACHE, exist_ok=True)
ZOOM = 14
def tile_xy(lat, lon):
    n = 2 ** ZOOM
    return (lon + 180) / 360 * n, (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n
def fetch(tx, ty):
    p = f"{CACHE}/t{ZOOM}_{tx}_{ty}.png"
    if not os.path.exists(p):
        req = urllib.request.Request(f"https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{ZOOM}/{tx}/{ty}.png", headers={"User-Agent": "WastelandBake/1.0"})
        open(p, "wb").write(urllib.request.urlopen(req, timeout=60).read())
    a = np.asarray(Image.open(p).convert("RGB")).astype(np.float64)
    return a[:, :, 0] * 256 + a[:, :, 1] + a[:, :, 2] / 256 - 32768
# ---- heights
xs = np.arange(XA, XB + 1, 5.0); zs = np.arange(ZN, Z0, 5.0)          # rows north to south, the last row is 5 m north of the old edge
LON, LAT = np.meshgrid(lon_of(xs), lat_of(zs))
n = 2 ** ZOOM
FX = (LON + 180) / 360 * n
FY = (1 - np.arcsinh(np.tan(np.radians(LAT))) / math.pi) / 2 * n
tx0, tx1 = int(FX.min()), int(FX.max()); ty0, ty1 = int(FY.min()), int(FY.max())
mosaic = np.zeros(((ty1 - ty0 + 1) * 256, (tx1 - tx0 + 1) * 256))
for ty in range(ty0, ty1 + 1):
    for tx in range(tx0, tx1 + 1):
        mosaic[(ty - ty0) * 256:(ty - ty0 + 1) * 256, (tx - tx0) * 256:(tx - tx0 + 1) * 256] = fetch(tx, ty)
H = map_coordinates(mosaic, [(FY - ty0) * 256 - 0.5, (FX - tx0) * 256 - 0.5], order=1, mode="nearest")
# ---- the lidar (NSW Spatial Services 1 m DEM, the user's WASTELAND/DATA_2634501.zip; the tiles for this strip are in
# /home/claude/lidar, pulled out of the zip by range requests with /home/claude/lidar_tools/rz.py). Where it has data
# it replaces the public tiles; north of the border (Queensland) it has none.
import glob, re
def utm56(lat, lon):
    a = 6378137.0; f = 1 / 298.257222101; k0 = 0.9996; e2 = f * (2 - f); ep2 = e2 / (1 - e2)
    la = np.radians(lat); lo = np.radians(lon) - math.radians(153.0)
    N = a / np.sqrt(1 - e2 * np.sin(la) ** 2); T = np.tan(la) ** 2; C = ep2 * np.cos(la) ** 2; A = np.cos(la) * lo
    M = a * ((1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256) * la - (3 * e2 / 8 + 3 * e2 ** 2 / 32 + 45 * e2 ** 3 / 1024) * np.sin(2 * la)
             + (15 * e2 ** 2 / 256 + 45 * e2 ** 3 / 1024) * np.sin(4 * la) - (35 * e2 ** 3 / 3072) * np.sin(6 * la))
    E = k0 * N * (A + (1 - T + C) * A ** 3 / 6 + (5 - 18 * T + T ** 2 + 72 * C - 58 * ep2) * A ** 5 / 120) + 500000.0
    Nn = k0 * (M + N * np.tan(la) * (A ** 2 / 2 + (5 - T + 9 * C + 4 * C ** 2) * A ** 4 / 24 + (61 - 58 * T + T ** 2 + 600 * C - 330 * ep2) * A ** 6 / 720)) + 10000000.0
    return E, Nn
LID = np.full(H.shape, np.nan)
tiles_l = glob.glob("/home/claude/lidar/*_1m.tif")
if tiles_l:
    import tifffile
    UE, UN = utm56(LAT, LON)
    for fn in tiles_l:
        m = re.search(r"_(\d{3})(\d{4})_56_0002_0002_1m", fn)
        e0, n0 = int(m.group(1)) * 1000.0, int(m.group(2)) * 1000.0
        sel = (UE >= e0) & (UE < e0 + 2000) & (UN >= n0) & (UN < n0 + 2000)
        if not sel.any(): continue
        A = tifffile.imread(fn).astype(np.float64)
        A[(A < -100) | (A > 2000)] = np.nan
        # 5 m block means of the 1 m cells (NaN where a block is mostly empty)
        B = A[:2000, :2000].reshape(400, 5, 400, 5)
        cnt = np.isfinite(B).sum(axis=(1, 3))
        B5 = np.where(cnt >= 13, np.nansum(B, axis=(1, 3)) / np.maximum(cnt, 1), np.nan)
        col = np.clip(((UE[sel] - e0) / 5.0).astype(int), 0, 399)
        row = np.clip(((n0 + 2000 - UN[sel]) / 5.0).astype(int), 0, 399)
        LID[sel] = B5[row, col]
    print("lidar covers", round(float(np.isfinite(LID).mean()), 3), "of the strip; mean difference from the public tiles where both have land",
          round(float(np.nanmean((LID - H)[np.isfinite(LID) & (H > 1)])), 2))
    # the public tiles ride high (roofs, trees, a different datum): drop them by the typical difference, then feather
    # the two together over about 30 m so there's no step at the border
    off = float(np.nanmedian((LID - H)[np.isfinite(LID) & (H > 1)]))
    Hp = np.where(H > 0.35, np.maximum(H + off, 0.6), H)
    have = np.isfinite(LID).astype(float)
    ms = gaussian_filter(have, 6.0)
    ms = np.where(have > 0, np.clip((ms - 0.5) * 2.0, 0, 1), 0.0)
    H = np.where(have > 0, LID * ms + Hp * (1 - ms), Hp)
    H = np.where(np.isfinite(H), H, Hp)
    print("public tiles lowered by", round(off, 2))
sea = (H < 0.35) & ~np.isfinite(LID) | (np.isfinite(LID) & (LID < 0.15))
Hs = gaussian_filter(np.where(sea, 0.0, H), 1.6)         # the public tiles are a DSM: take the roofs and tree tops down a bit
H = np.where(np.isfinite(LID), np.where(sea, 0.0, H), Hs)  # the lidar is bare earth: as it is
H = np.where((gaussian_filter(sea.astype(float), 1.2) > 0.6) & ~np.isfinite(LID), 0.0, np.maximum(H, 0.0))
# meet the old ground along the seam: its last row, carried north and faded out over 80 m
T = 6401
old = np.memmap(f"{GAME}/data/height_roads.r16", "<u2", "r", shape=(T, T))
edge = old[0, int((XA - X0) / 5):int((XB - X0) / 5) + 1].astype(np.float64) / 65535 * 900 - 60
k = np.clip((Z0 - zs) / 80.0, 0, 1)[:, None]
k = k * k * (3 - 2 * k)
print("seam: mean |lidar - old map edge| along the first row north of the edge:", round(float(np.nanmean(np.abs(LID[-1] - edge))), 2), "m")
k = np.where(np.isfinite(LID), np.clip((Z0 - zs) / 15.0, 0, 1)[:, None] * np.ones_like(H), k)      # the lidar lines up with the old ground: a short blend
H = edge[None, :] * (1 - k) + H * k
# ease the west and east ends of the strip down to nothing so it has no cliff
ex = np.clip(np.minimum(xs - XA, XB - xs) / 150.0, 0, 1)[None, :]
far = np.clip((zs - ZN) / 150.0, 0, 1)[:, None]
H = H * np.minimum(ex + (1 - k) , 1.0) * np.minimum(far, 1.0)
with open(f"{GAME}/assets/world/north_h.bin", "wb") as f:
    f.write(struct.pack("<ffIIf", XA, ZN, len(xs), len(zs), 5.0))
    f.write(np.clip(H * 100 + 1000, 0, 65535).astype("<u2").tobytes())
print("heights", H.shape, "land share", round(float((H > 0.5).mean()), 2), "max", round(float(H.max()), 1))
def hat(x, z):
    return float(map_coordinates(H, [[(z - ZN) / 5.0], [(x - XA) / 5.0]], order=1, mode="nearest")[0])
# ---- roads
osm = json.load(open(f"{GAME}/data/north/osm.json"))
HALF = {"motorway": 5.6, "trunk": 4.6, "primary": 4.2, "secondary": 3.7, "tertiary": 3.4, "unclassified": 3.0, "residential": 3.0, "living_street": 2.6,
        "service": 1.9, "motorway_link": 3.2, "trunk_link": 3.0, "primary_link": 3.0, "secondary_link": 3.0, "tertiary_link": 3.0}
RANK = {"motorway": 0, "trunk": 1, "primary": 2, "secondary": 3, "motorway_link": 4, "trunk_link": 4, "primary_link": 4, "secondary_link": 4, "tertiary": 5,
        "tertiary_link": 5, "unclassified": 6, "residential": 7, "living_street": 8, "service": 9}
MARK = {"motorway": 0.5, "trunk": 0.25, "primary": 0.25, "secondary": 0.25, "tertiary": 0.25, "unclassified": 0.25}
WILD = {0: 0.35, 1: 0.4, 2: 0.45, 3: 0.5, 4: 0.5, 5: 0.6, 6: 0.75, 7: 0.7, 8: 0.8, 9: 1.0}
lines = {}; segs = []
nroad = 0
for e in osm["elements"]:
    if e["type"] != "way" or "highway" not in e.get("tags", {}): continue
    kd = e["tags"]["highway"]
    if kd not in HALF: continue
    if e["tags"].get("tunnel") == "yes" or e["tags"].get("access") == "private" and kd == "service": continue
    P = np.array([(gx(g["lon"]), gz(g["lat"])) for g in e["geometry"]])
    # only the part north of the old edge (the old map has its own roads), inside the strip
    runs = []; cur = []
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]
        L = float(np.hypot(*(b - a)))
        m = max(1, int(math.ceil(L / 6.0)))
        for j in range(m + (1 if i == len(P) - 2 else 0)):
            q = a + (b - a) * j / m
            if q[1] < Z0 - 2.0 and q[1] > ZN + 20 and XA + 20 < q[0] < XB - 20 and hat(q[0], q[1]) > 0.4:
                cur.append(q)
            else:
                if len(cur) > 1: runs.append(cur)
                cur = []
    if len(cur) > 1: runs.append(cur)
    hs = HALF[kd]; rank = RANK[kd]
    for run in runs:
        R = np.array(run)
        d = np.concatenate([[0], np.cumsum(np.hypot(np.diff(R[:, 0]), np.diff(R[:, 1])))])
        if d[-1] < 8: continue
        endf = np.minimum(1.0, np.minimum(d, d[-1] - d) / 14.0)
        nroad += 1
        segs.append((R, hs, kd))
        # cut into 1024 m tiles by segment midpoint
        key = lambda i: (int(math.floor(((R[i, 0] + R[i + 1, 0]) / 2 - X0) / 1024.0)), int(math.floor(((R[i, 1] + R[i + 1, 1]) / 2 - Z0) / 1024.0)))
        i0 = 0
        while i0 < len(R) - 1:
            tk = key(i0); i1 = i0
            while i1 + 1 < len(R) - 1 and key(i1 + 1) == tk: i1 += 1
            sl = slice(i0, i1 + 2)
            pts = np.column_stack([R[sl, 0], R[sl, 1], d[sl], endf[sl], np.zeros(i1 + 2 - i0)])
            lines.setdefault(tk, []).append((hs, 0.5 if kd == "service" else 0.0, MARK.get(kd, 0.0), WILD[rank], pts))
            i0 = i1 + 1
with open(f"{GAME}/assets/roads/lines_north.bin", "wb") as f:
    f.write(struct.pack("<I", len(lines)))
    for (tx_, tz_), pcs in sorted(lines.items()):
        f.write(struct.pack("<iiI", tx_, tz_, len(pcs)))
        for hs_, sf_, mk_, wl_, pts in pcs:
            f.write(struct.pack("<ffffI", hs_, sf_, mk_, wl_, len(pts)))
            f.write(pts.astype("<f4").tobytes())
print("roads", nroad, "tiles", len(lines), "KB", os.path.getsize(f"{GAME}/assets/roads/lines_north.bin") // 1024)
# ---- buildings and what OSM says they are
out = []
amen = [(gx(e["lon"]), gz(e["lat"]), e["tags"]) for e in osm["elements"] if e["type"] == "node" and "amenity" in e.get("tags", {})]
for e in osm["elements"]:
    t = e.get("tags", {})
    if e["type"] != "way" or "building" not in t: continue
    P = [(gx(g["lon"]), gz(g["lat"])) for g in e["geometry"]]
    cz = sum(p[1] for p in P) / len(P)
    if cz > Z0 - 4.0: continue
    out.append({"pts": [[round(p[0], 2), round(p[1], 2)] for p in P], "tag": t.get("building", "yes"), "name": t.get("name", ""), "amenity": t.get("amenity", ""),
                "shop": t.get("shop", ""), "tourism": t.get("tourism", ""), "levels": t.get("building:levels", ""), "religion": t.get("religion", "")})
json.dump({"b": out, "roads": [[r[0].round(1).tolist(), r[1], r[2]] for r in segs], "amenity": [[round(a[0], 1), round(a[1], 1), a[2].get("amenity", ""), a[2].get("name", "")] for a in amen]},
          open(f"{GAME}/data/north/bld.json", "w"))
print("buildings north of the old edge", len(out), "amenity nodes", len(amen))
import collections
print(collections.Counter(b["tag"] for b in out).most_common(14))
print([ (b["name"], b["tag"], b["levels"]) for b in out if b["name"]][:40])
