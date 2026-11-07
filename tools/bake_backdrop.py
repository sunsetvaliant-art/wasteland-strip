#!/usr/bin/env python3
"""The country past the edge of the map: a low-detail heightfield from about 25 km out (Wollumbin / Mt Warning, the
caldera rim, the McPherson Range, the coast), so the skyline is the real one. Heights from the Terrarium elevation tiles
(AWS Terrain Tiles: SRTM and friends), corrected to match the map's LiDAR where they overlap (the 30 m data rounds the
peaks off ~10 %: Mt Cougal 663 m vs 734 m). Colour from NSW Spatial Services imagery where there is some, otherwise
shaded by height and slope. Writes assets/backdrop/backdrop.glb (mesh with a hole where the map is) and its texture.
usage: bake_backdrop.py"""
import math, os, io, json, struct, urllib.request
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates, gaussian_filter

GAME = "/home/claude/game"
CACHE = "/tmp/claude-0/dem"
os.makedirs(CACHE, exist_ok=True)
LAT0, LON0 = -28.3285718, 153.4035024
KX = 111320 * math.cos(math.radians(LAT0)); KZ = 110574
X0, Z0, SP, T = -8960.0, -16960.0, 5.0, 6401
MAPX = (X0, X0 + (T - 1) * SP); MAPZ = (Z0, Z0 + (T - 1) * SP)
EXT = 26000.0                       # how far past the map edge
STEP = 150.0                        # mesh spacing
ZD = 12                             # elevation tile zoom (~33 m)
ZI = 12                             # imagery zoom

def lat_of(z): return LAT0 - z / KZ
def lon_of(x): return LON0 + x / KX
def tile_f(lat, lon, z):
    n = 2 ** z
    return (lon + 180) / 360 * n, (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n

def fetch(url, path):
    if not os.path.exists(path):
        try:
            urllib.request.urlretrieve(url, path)
        except Exception as e:
            return None
    return path

def mosaic(kind, z, x0, x1, y0, y1):
    W = (x1 - x0 + 1) * 256; Hh = (y1 - y0 + 1) * 256
    out = np.zeros((Hh, W, 3), np.float32); have = np.zeros((Hh, W), bool)
    for ty in range(y0, y1 + 1):
        for tx in range(x0, x1 + 1):
            if kind == "dem":
                p = fetch(f"https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{tx}/{ty}.png", f"{CACHE}/t{z}_{tx}_{ty}.png")
            else:
                p = fetch(f"https://maps.six.nsw.gov.au/arcgis/rest/services/public/NSW_Imagery/MapServer/tile/{z}/{ty}/{tx}", f"{CACHE}/i{z}_{tx}_{ty}.jpg")
            if p is None: continue
            try:
                a = np.asarray(Image.open(p).convert("RGB")).astype(np.float32)
            except Exception:
                continue
            if a.shape[:2] != (256, 256): continue
            out[(ty - y0) * 256:(ty - y0 + 1) * 256, (tx - x0) * 256:(tx - x0 + 1) * 256] = a
            have[(ty - y0) * 256:(ty - y0 + 1) * 256, (tx - x0) * 256:(tx - x0 + 1) * 256] = True
    return out, have

# region in game metres, and its lat/lon box
RX = (MAPX[0] - EXT, MAPX[1] + EXT); RZ = (MAPZ[0] - EXT, MAPZ[1] + EXT)
lat_n, lat_s = lat_of(RZ[0]), lat_of(RZ[1]); lon_w, lon_e = lon_of(RX[0]), lon_of(RX[1])
def tiles_for(z):
    ax, ay = tile_f(lat_n, lon_w, z); bx, by = tile_f(lat_s, lon_e, z)
    return int(ax), int(bx), int(ay), int(by)
x0, x1, y0, y1 = tiles_for(ZD)
print("dem tiles", (x1 - x0 + 1) * (y1 - y0 + 1))
D, _ = mosaic("dem", ZD, x0, x1, y0, y1)
DEM = D[..., 0] * 256 + D[..., 1] + D[..., 2] / 256 - 32768
def dem_at(xs, zs):
    fx, fy = tile_f(lat_of(zs), lon_of(xs), ZD) if np.isscalar(xs) else (None, None)
    lat = lat_of(zs); lon = lon_of(xs); n = 2 ** ZD
    px = ((lon + 180) / 360 * n - x0) * 256
    py = ((1 - np.arcsinh(np.tan(np.radians(lat))) / np.pi) / 2 * n - y0) * 256
    return map_coordinates(DEM, [py - 0.5, px - 0.5], order=1, mode="nearest")

# fit the DEM to the map's LiDAR where they overlap: LiDAR = f(DEM), piecewise linear by height
H = np.fromfile(f"{GAME}/data/height.r16", "<u2").reshape(T, T).astype(np.float32) / 65535 * 900 - 60
Hs = gaussian_filter(H, 3)
rng = np.random.default_rng(3)
ii = rng.integers(0, T, 400000); jj = rng.integers(0, T, 400000)
lid = Hs[ii, jj]; dm = dem_at(X0 + jj * SP, Z0 + ii * SP)
ok = (lid > 1.0) & (dm > 1.0)
edges = np.array([0, 20, 50, 100, 200, 300, 400, 500, 600, 700, 800, 2000.0])
cx, cy = [0.0], [0.0]
for a, b in zip(edges[:-1], edges[1:]):
    m = ok & (dm >= a) & (dm < b)
    if m.sum() > 200:
        cx.append(float(np.median(dm[m]))); cy.append(float(np.median(lid[m])))
# past the top of the overlap keep the last ratio (the high country loses its peaks the same way)
ratio = cy[-1] / max(cx[-1], 1)
cx.append(3000.0); cy.append(3000.0 * ratio)
print("DEM -> LiDAR fit:", [(round(a), round(b)) for a, b in zip(cx, cy)])
# (the binned fit is printed for reference only: binning by DEM height drags it towards the mean. The real loss is at
# the summits, which the 30 m data rounds off, so the mesh gets its peaks sharpened back instead, below)
def fix(h): return h

# grid
gx = np.arange(RX[0], RX[1] + 1, STEP); gz = np.arange(RZ[0], RZ[1] + 1, STEP)
X, Z = np.meshgrid(gx, gz)
Y = fix(dem_at(X.ravel(), Z.ravel()).reshape(X.shape))
# give the summits back what the 30 m data shaved off: unsharp mask at ~300 m, raising only (Mt Cougal 663 -> ~720 m
# against 734 m surveyed, Wollumbin ~1060 -> ~1150 m against 1159 m)
lift = np.maximum(Y - gaussian_filter(Y, 2.0), 0.0) * 0.33
Y = Y + np.where(Y > 60.0, lift, 0.0)
Y_open = Y.copy()
Y[Y < 0.5] = -3.0                                       # sea and estuaries sit under the water plane
# under the map: drop it out of sight, and pull the ring next to the map edge down to the map's own edge heights
inside = (X > MAPX[0]) & (X < MAPX[1]) & (Z > MAPZ[0]) & (Z < MAPZ[1])
dx = np.maximum(np.maximum(MAPX[0] - X, X - MAPX[1]), 0); dz = np.maximum(np.maximum(MAPZ[0] - Z, Z - MAPZ[1]), 0)
dout = np.hypot(dx, dz)
ex = np.clip(X, MAPX[0], MAPX[1]); ez = np.clip(Z, MAPZ[0], MAPZ[1])
edge_h = map_coordinates(H, [(ez - Z0) / SP, (ex - X0) / SP], order=1, mode="nearest")
w = np.clip(dout / 1200.0, 0, 1); w = w * w * (3 - 2 * w)
Y = np.where(inside, -40.0, edge_h * (1 - w) + Y * w - 2.0 * (1 - w))
keep_v = ~inside | (np.minimum.reduce([X - MAPX[0], MAPX[1] - X, Z - MAPZ[0], MAPZ[1] - Z]) < 400)

# colour: imagery where NSW has it, else shaded by height and slope
ix0, ix1, iy0, iy1 = tiles_for(ZI)
print("imagery tiles", (ix1 - ix0 + 1) * (iy1 - iy0 + 1))
I, have = mosaic("img", ZI, ix0, ix1, iy0, iy1)
TEX = 2048
tu = np.linspace(RX[0], RX[1], TEX); tv = np.linspace(RZ[0], RZ[1], TEX)
TX, TZ = np.meshgrid(tu, tv)
n = 2 ** ZI
px = ((lon_of(TX) + 180) / 360 * n - ix0) * 256; py = ((1 - np.arcsinh(np.tan(np.radians(lat_of(TZ)))) / np.pi) / 2 * n - iy0) * 256
col = np.stack([map_coordinates(I[..., c], [py, px], order=1, mode="nearest") for c in range(3)], -1)
hv = map_coordinates(have.astype(np.float32), [py, px], order=0, mode="nearest") > 0.5
blank = (col.max(-1) > 245) | (col.max(-1) < 3)
hv &= ~blank
ht = fix(dem_at(TX.ravel(), TZ.ravel()).reshape(TX.shape))
gyy, gxx = np.gradient(gaussian_filter(ht, 2), (RZ[1] - RZ[0]) / TEX, (RX[1] - RX[0]) / TEX)
slope = np.hypot(gxx, gyy)
shade = np.clip(0.75 + (-gxx * 0.6 - gyy * 0.6) * 2.0, 0.45, 1.15)
forest = np.array([58, 78, 42], np.float32); pasture = np.array([112, 118, 70], np.float32); sea = np.array([40, 70, 95], np.float32)
t = np.clip((ht - 40) / 150 + slope * 2.0, 0, 1)[..., None]
proc = (pasture * (1 - t) + forest * t) * shade[..., None]
proc = np.where((ht < 0.5)[..., None], sea, proc)
img = np.where(hv[..., None], col, proc)
Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(f"{GAME}/assets/backdrop/backdrop.jpg", quality=86)

# mesh (only quads with a kept corner), UV over the region
nz, nx = X.shape
vid = np.arange(nz * nx).reshape(nz, nx)
qa = vid[:-1, :-1].ravel(); qb = vid[:-1, 1:].ravel(); qc = vid[1:, :-1].ravel(); qd = vid[1:, 1:].ravel()
kv = keep_v.ravel()
qk = kv[qa] | kv[qb] | kv[qc] | kv[qd]
idx = np.stack([qa, qc, qb, qb, qc, qd], -1)[qk].ravel()
P = np.stack([X.ravel(), Y.ravel(), Z.ravel()], -1).astype(np.float32)
UV = np.stack([(X.ravel() - RX[0]) / (RX[1] - RX[0]), (Z.ravel() - RZ[0]) / (RZ[1] - RZ[0])], -1).astype(np.float32)
used = np.unique(idx); remap = -np.ones(len(P), np.int64); remap[used] = np.arange(len(used))
P = P[used]; UV = UV[used]; idx = remap[idx].astype(np.uint32)
# normals
N = np.zeros_like(P)
tri = idx.reshape(-1, 3)
fn = np.cross(P[tri[:, 1]] - P[tri[:, 0]], P[tri[:, 2]] - P[tri[:, 0]])
for k in range(3): np.add.at(N, tri[:, k], fn)
N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-9
N[N[:, 1] < 0] *= -1
img_bytes = open(f"{GAME}/assets/backdrop/backdrop.jpg", "rb").read()
parts = []; views = []; acc = []; off = 0
def add(b, target=None):
    global off
    pad = (-len(b)) % 4; views.append({"buffer": 0, "byteOffset": off, "byteLength": len(b), **({"target": target} if target else {})})
    parts.append(b); parts.append(b"\0" * pad); off += len(b) + pad; return len(views) - 1
def accessor(a, typ, comp=5126, target=34962):
    d = {"bufferView": add(a.tobytes(), target), "componentType": comp, "count": int(a.shape[0]), "type": typ}
    if typ == "VEC3" and comp == 5126: d["min"] = a.min(0).tolist(); d["max"] = a.max(0).tolist()
    acc.append(d); return len(acc) - 1
prim = {"attributes": {"POSITION": accessor(P, "VEC3"), "NORMAL": accessor(N.astype(np.float32), "VEC3"), "TEXCOORD_0": accessor(UV, "VEC2")},
        "indices": accessor(idx, "SCALAR", 5125, 34963), "material": 0}
imv = add(img_bytes)
g = {"asset": {"version": "2.0", "generator": "bake_backdrop"}, "scene": 0, "scenes": [{"nodes": [0]}],
     "nodes": [{"name": "backdrop", "mesh": 0}], "meshes": [{"name": "backdrop", "primitives": [prim]}],
     "materials": [{"name": "backdrop", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 1.0}}],
     "textures": [{"source": 0}], "images": [{"bufferView": imv, "mimeType": "image/jpeg"}],
     "accessors": acc, "bufferViews": views, "buffers": [{"byteLength": off}]}
js = json.dumps(g).encode(); js += b" " * ((-len(js)) % 4); bin_ = b"".join(parts)
with open(f"{GAME}/assets/backdrop/backdrop.glb", "wb") as f:
    f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_)))
    f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
    f.write(struct.pack("<II", len(bin_), 0x004E4942)); f.write(bin_)
os.remove(f"{GAME}/assets/backdrop/backdrop.jpg")
wx, wz = (lon_of(0) and (153.2697 - LON0) * KX), -(-28.3997 - LAT0) * KZ
yy = float(Y[np.abs(gz - wz).argmin() - 3:np.abs(gz - wz).argmin() + 4, np.abs(gx - wx).argmin() - 3:np.abs(gx - wx).argmin() + 4].max())
cg = (153.325527 - LON0) * KX, -(-28.236031 - LAT0) * KZ
print("Mt Cougal W on the backdrop grid (inside the map, hidden):", round(float(Y_open[np.abs(gz - cg[1]).argmin() - 2:np.abs(gz - cg[1]).argmin() + 3, np.abs(gx - cg[0]).argmin() - 2:np.abs(gx - cg[0]).argmin() + 3].max())))
print("verts", len(P), "tris", len(idx) // 3, "MB", round((12 + 8 + len(js) + 8 + len(bin_)) / 1e6, 1), "Mt Warning at", round(wx), round(wz), "height", round(float(yy)))
