#!/usr/bin/env python3
"""Fill the holes in the painted roads (0.2.56). Some suburbs (Tweed Heads South, Banora Point, Chinderah...) had
houses but almost no roads in assets/roads/lines.bin. Every Overture road (docs/ref/streets/segment.geojsonl) that has
no painted road within 8 m for 15 m or more is added as a new piece: half-width from its class, gravel if Overture
says unpaved, the usual markings for its width. Bridges and tunnels are left to the bridge kit; the north strip (old
frame) is left alone. Writes lines.bin in place (a backup goes to /tmp/lines_before_fill.bin).
Run before make_streets.py (and before fix_footprints.py, which keeps houses off the roads).
"""
import json, struct, math, collections, shutil, sys
import numpy as np
from scipy.spatial import cKDTree
sys.path.insert(0, "/home/claude/game/tools"); import geo

ROOT = "/home/claude/game"
PATH = ROOT + "/assets/roads/lines.bin"
X0, Z0, T = -8960.0, -16960.0, 1024.0
NORTH_Z = -16960.0
HS = {"motorway": 7.0, "trunk": 6.0, "primary": 5.0, "secondary": 4.6, "tertiary": 4.2, "residential": 3.6, "unclassified": 3.4, "living_street": 3.0}

# ---- read
f = open(PATH, "rb").read(); o = 0
def u32():
    global o; v = struct.unpack_from("<I", f, o)[0]; o += 4; return v
def i32():
    global o; v = struct.unpack_from("<i", f, o)[0]; o += 4; return v
tiles = collections.OrderedDict()
pts_all = []
mk_by_hs = collections.defaultdict(collections.Counter); wl_all = []
for _ in range(u32()):
    tx, tz, n = i32(), i32(), u32()
    pcs = []
    for _ in range(n):
        hs, sf, mk, wl = struct.unpack_from("<4f", f, o); o += 16
        m = u32(); a = np.frombuffer(f, dtype="<f4", count=m * 5, offset=o).reshape(m, 5).copy(); o += m * 20
        pcs.append((hs, sf, mk, wl, a))
        mk_by_hs[round(hs * 2) / 2][round(mk, 3)] += 1; wl_all.append(wl)
        # dense points for the 'is there a road here' test
        for p, q in zip(a[:-1, :2], a[1:, :2]):
            L = float(np.hypot(*(q - p))); k = max(1, int(L / 2.0))
            for j in range(k): pts_all.append(p + (q - p) * j / k)
    tiles[(tx, tz)] = pcs
kd = cKDTree(np.array(pts_all))
wl_med = float(np.median(wl_all))
def mk_for(hs):
    c = mk_by_hs.get(round(hs * 2) / 2)
    return c.most_common(1)[0][0] if c else 0.25
print("existing pieces:", sum(len(v) for v in tiles.values()))

# ---- the missing roads
added = collections.Counter(); new_len = 0.0
for line in open(ROOT + "/docs/ref/streets/segment.geojsonl"):
    d = json.loads(line); p = d["properties"]
    if p.get("subtype") != "road" or p.get("class") not in HS: continue
    flags = [v for fl in (p.get("road_flags") or []) for v in (fl.get("values") or [])]
    if "is_bridge" in flags or "is_tunnel" in flags: continue
    surf = 0.0
    for rs in (p.get("road_surface") or []):
        if rs.get("value") in ("unpaved", "gravel", "dirt"): surf = 0.5
    hs = HS[p["class"]] if surf == 0.0 else 2.2
    pts = np.array([geo.ll(x, y) for x, y in d["geometry"]["coordinates"]])
    if pts[:, 1].min() < NORTH_Z + 200: continue
    # sample every 2 m, mark which samples have no painted road near
    S = [pts[0]]
    for a, b in zip(pts[:-1], pts[1:]):
        L = float(np.hypot(*(b - a))); k = max(1, int(L / 2.0))
        for j in range(1, k + 1): S.append(a + (b - a) * j / k)
    S = np.array(S)
    dist, _ = kd.query(S)
    miss = dist > 8.0
    # runs of missing samples, 15 m or longer, grown 3 samples each end so they join what's there
    i = 0
    while i < len(S):
        if not miss[i]: i += 1; continue
        j = i
        while j < len(S) and miss[j]: j += 1
        if (j - i) * 2.0 >= 15.0:
            a0, a1 = max(0, i - 3), min(len(S), j + 3)
            run = S[a0:a1]
            along = np.concatenate([[0], np.cumsum(np.hypot(*(run[1:] - run[:-1]).T))])
            arr = np.zeros((len(run), 5), np.float32)
            arr[:, 0] = run[:, 0]; arr[:, 1] = run[:, 1]; arr[:, 2] = along; arr[:, 3] = 1.0
            # split by tile (each segment to the tile of its middle)
            cur = [0]
            def key_of(k):
                m = (run[k] + run[min(k + 1, len(run) - 1)]) / 2
                return (int(math.floor((m[0] - X0) / T)), int(math.floor((m[1] - Z0) / T)))
            k0 = key_of(0)
            for k in range(1, len(run) - 1):
                cur.append(k)
                kk = key_of(k)
                if kk != k0:
                    tiles.setdefault(k0, []).append((hs, surf, mk_for(hs), wl_med, arr[cur].copy())); cur = [k]; k0 = kk
            cur.append(len(run) - 1)
            tiles.setdefault(k0, []).append((hs, surf, mk_for(hs), wl_med, arr[cur].copy()))
            added[p["class"]] += 1; new_len += float(along[-1])
        i = j
print("added:", dict(added), "%.1f km" % (new_len / 1000))

# ---- write
shutil.copy(PATH, "/tmp/lines_before_fill.bin")
b = bytearray(struct.pack("<I", len(tiles)))
for (tx, tz), pcs in tiles.items():
    b += struct.pack("<iiI", tx, tz, len(pcs))
    for hs, sf, mk, wl, a in pcs:
        b += struct.pack("<4fI", hs, sf, mk, wl, len(a)) + a.astype("<f4").tobytes()
open(PATH, "wb").write(b)
print("wrote", PATH, len(b) // 1024, "KB")
