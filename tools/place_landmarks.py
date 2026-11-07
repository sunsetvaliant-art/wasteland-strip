#!/usr/bin/env python3
"""Where the Meshy buildings go (assets/world/landmarks.json):
  servo canopies on the real service stations (OpenStreetMap amenity=fuel, via Nominatim), squared up to the road
  out front and set back off it;
  the old two-storey houses along town streets and the older country roads, facing the street, set back on a flat
  block, well apart from each other and clear of every other road.
usage: place_landmarks.py   (reads the surveyed roads and the height map; fuel stations cached in data/fuel.json)"""
import json, math, os, urllib.request
import numpy as np
from scipy.ndimage import map_coordinates
GAME = "/home/claude/game"
src = open(f"{GAME}/tools/bake_roads.py").read()
cut = src.index("# ------------------------------------------------------------------ bridge ends meet the road")
ns = {}; exec(src[:cut], ns)
roads = [r for r in ns["roads"] if not r["b"]]
SPEC = ns["SPEC"]
LAT0, LON0 = -28.3285718, 153.4035024
KX = 111320 * math.cos(math.radians(LAT0)); KZ = 110574
X0, Z0, SP, T = -8960.0, -16960.0, 5.0, 6401
H = np.fromfile(f"{GAME}/data/height_roads.r16", "<u2").reshape(T, T).astype(np.float32) / 65535 * 900 - 60
def hat(x, z): return map_coordinates(H, [np.atleast_1d((z - Z0) / SP), np.atleast_1d((x - X0) / SP)], order=1)
# every road as segments, for "how far to the nearest road" and "which way does it run"
S = []
for r in roads:
    P = r["P"]; hs = SPEC[r["k"]][0]
    for i in range(len(P) - 1): S.append((P[i, 0], P[i, 1], P[i + 1, 0], P[i + 1, 1], hs, ns["RANK"].get(r["k"], 6)))
S = np.array(S)
ax, az, bx, bz, hs, rank = S.T
dx, dz = bx - ax, bz - az; L2 = dx * dx + dz * dz + 1e-9
def nearest(x, z):
    t = np.clip(((x - ax) * dx + (z - az) * dz) / L2, 0, 1)
    px, pz = ax + dx * t, az + dz * t; d = np.hypot(px - x, pz - z) - hs
    k = int(np.argmin(d)); L = math.sqrt(L2[k])
    return d[k], px[k], pz[k], dx[k] / L, dz[k] / L, int(rank[k])
def clear(x, z, r):
    t = np.clip(((x - ax) * dx + (z - az) * dz) / L2, 0, 1)
    return float((np.hypot(ax + dx * t - x, az + dz * t - z) - hs).min()) > r
def flat(x, z, r, tol):
    xs = x + np.array([0, r, -r, 0, 0, r, -r, r, -r]); zs = z + np.array([0, 0, 0, r, -r, r, r, -r, -r])
    h = hat(xs, zs); return float(h.max() - h.min()) < tol, float(h.min())

out = []
# ---- servos
fp = f"{GAME}/data/fuel.json"
if not os.path.exists(fp):
    q = "https://nominatim.openstreetmap.org/search?q=%5Bfuel%5D&format=jsonv2&viewbox=153.31,-28.17,153.64,-28.47&bounded=1&limit=50"
    req = urllib.request.Request(q, headers={"User-Agent": "WastelandStripGame/1.0 (map building)"})
    json.dump(json.load(urllib.request.urlopen(req)), open(fp, "w"))
fuel = json.load(open(fp))
for f in fuel:
    x = (float(f["lon"]) - LON0) * KX; z = -(float(f["lat"]) - LAT0) * KZ
    d, px, pz, tx, tz, rk = nearest(x, z)
    if d > 60: continue                                    # nowhere near a road we've got
    nx, nz = -tz, tx
    if (x - px) * nx + (z - pz) * nz < 0: nx, nz = -nx, -nz   # the side of the road the station's on
    back = SPEC_hs = 0
    cx, cz = px + nx * (d + 0), pz + nz * (d + 0)
    # canopy 10.5 x 7.4 m: its long side along the road, its near edge 6 m off the seal
    hsd = float(np.interp(0, [0], [0]))
    off = 6.0 + 3.7
    road_hs = float(hs[int(np.argmin(np.hypot(ax - px, az - pz)))])
    cx, cz = px + nx * (road_hs + off), pz + nz * (road_hs + off)
    if not clear(cx, cz, 4.5): continue
    ok, h = flat(cx, cz, 5.0, 2.5)
    yaw = math.atan2(-tz, tx)                             # model +X along the road
    out.append({"kind": "servo_canopy", "name": f.get("name") or "Service station", "x": round(cx, 2), "z": round(cz, 2), "y": round(h, 2), "yaw": round(yaw, 4)})
# ---- houses
rng = np.random.default_rng(1902)
cands = []
for r in roads:
    if r["k"] not in ("residential", "tertiary", "unclassified", "living_street"): continue
    P = r["P"]; hsr = SPEC[r["k"]][0]
    d = np.r_[0, np.cumsum(np.hypot(np.diff(P[:, 0]), np.diff(P[:, 1])))]
    for s in np.arange(30, d[-1] - 30, 60):
        x = np.interp(s, d, P[:, 0]); z = np.interp(s, d, P[:, 1])
        i = min(np.searchsorted(d, s), len(P) - 1); j = max(i - 1, 0)
        tx, tz = P[i, 0] - P[j, 0], P[i, 1] - P[j, 1]; L = math.hypot(tx, tz) or 1; tx /= L; tz /= L
        side = 1 if rng.random() < 0.5 else -1
        nx, nz = -tz * side, tx * side
        cx, cz = x + nx * (hsr + 14.0), z + nz * (hsr + 14.0)    # set back off the street on its block
        cands.append((cx, cz, nx, nz, r["k"]))
rng.shuffle(cands)
houses = []
for cx, cz, nx, nz, k in cands:
    if len(houses) >= 40: break
    if not clear(cx, cz, 8.5): continue
    if any(math.hypot(cx - hx, cz - hz) < 350 for hx, hz in houses): continue
    if any(math.hypot(cx - o["x"], cz - o["z"]) < 120 for o in out): continue
    ok, h = flat(cx, cz, 8.0, 2.0)
    if not ok or h < 2.0: continue
    houses.append((cx, cz))
    yaw = math.atan2(-nx, -nz)                             # model +Z (its front) to the street
    out.append({"kind": "village_hq", "name": "Old house", "x": round(cx, 2), "z": round(cz, 2), "y": round(h, 2), "yaw": round(yaw, 4)})
json.dump({"landmarks": out}, open(f"{GAME}/assets/world/landmarks.json", "w"), indent=0)
print("servos", sum(1 for o in out if o["kind"] == "servo_canopy"), "houses", len(houses))
