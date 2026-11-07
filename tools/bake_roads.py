#!/usr/bin/env python3
"""Roads for the Tweed map, from the browser build's surveyed road data (OpenStreetMap centrelines with smoothed
height profiles, camber/superelevation, earthworks extents and bridge flags; 8 floats a point:
x, z, y, superelevation, left-earthworks-extent, left-ground-height, right-extent, right-ground-height).

Writes
  data/height_roads.r16       the height map with every road cut and filled into it (terrain sits 0.3 m under the seal)
  assets/roads/road_X_Z.glb   1 km tiles of road surface: seal, shoulders/kerbs/footpaths, grassed batters, bridges
  assets/roadmask.png         5 m clearance field (metres from the road's outer edge, +10, x10): no plants on roads
  assets/roads/index.json     tile list and the road names in each tile

Vertex data the road shader reads:
  UV   = (offset across the road in m, distance along it in m)
  UV2  = (half-width of the seal in m, end fade 0..1 so markings fade into junctions)
  COLOR= (surface 0 seal / .5 gravel / .75 grass batter / 1 concrete, marking style, in-a-curve flag, wildness)
"""
import json, base64, struct, os, sys, math
import numpy as np
from scipy.spatial import cKDTree

SRC = "/home/claude/ws_src/tw"
GAME = "/home/claude/game"
X0, Z0, SP, T = -8960.0, -16960.0, 5.0, 6401
HMIN, HR = -60.0, 900.0
TILE = 1024.0
SINK = 0.30            # terrain under the seal is pushed this far below it, so the road mesh always covers it

RANK = {"motorway": 0, "trunk": 1, "primary": 2, "secondary": 3, "motorway_link": 4, "trunk_link": 4, "primary_link": 4,
        "secondary_link": 4, "tertiary": 5, "tertiary_link": 5, "unclassified": 6, "residential": 7, "living_street": 8, "service": 9}
# marking style: 0 none, .25 two-lane rural (dashed centre, solid on curves, edge lines), .5 motorway carriageway, .75 link (edge lines)
MARK = {"motorway": 0.5, "trunk": 0.25, "primary": 0.25, "secondary": 0.25, "tertiary": 0.25, "unclassified": 0.25,
        "motorway_link": 0.75, "trunk_link": 0.75, "primary_link": 0.75, "secondary_link": 0.75, "tertiary_link": 0.75}
# how far nature has got back in: busy highways least, driveways and tracks most
WILD = {0: 0.35, 1: 0.4, 2: 0.45, 3: 0.5, 4: 0.5, 5: 0.6, 6: 0.75, 7: 0.7, 8: 0.8, 9: 1.0}

def log(*a):
    print(*a, flush=True)

# ------------------------------------------------------------------ load
idx = json.load(open(f"{SRC}/roads_idx.json"))
SPEC = idx["spec"]
roads = []
for key, ents in idx["regions"].items():
    raw = json.load(open(f"{SRC}/d_{key}.json")).get("r", "")
    if not raw:
        continue
    F = np.frombuffer(base64.b64decode(raw), np.float32).reshape(-1, 8)
    for e in ents:
        if e["c"] < 2:
            continue
        P = F[e["o"]:e["o"] + e["c"]].astype(np.float64)
        k = e["k"] if e["k"] in SPEC else "tertiary"
        roads.append({"k": k, "b": e["b"], "n": e["n"], "run": e["run"], "P": P, "rank": RANK.get(k, 6)})
log("roads", len(roads))

# ------------------------------------------------------------------ de-duplicate (the hero runs share pieces with the normal roads)
roads.sort(key=lambda r: (0 if r["run"] else 1, r["rank"]))
G = 8.0
seg_grid = {}
def near_existing(x, z):
    gx, gz = int(math.floor(x / G)), int(math.floor(z / G))
    for ix in (gx - 1, gx, gx + 1):
        for iz in (gz - 1, gz, gz + 1):
            for (ax, az, bx, bz, hs) in seg_grid.get((ix, iz), ()):
                dx, dz = bx - ax, bz - az
                L2 = dx * dx + dz * dz or 1e-9
                t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / L2))
                px, pz = ax + dx * t - x, az + dz * t - z
                if px * px + pz * pz < (0.6 * hs) ** 2:
                    return True
    return False
def add_segs(P, hs):
    for i in range(len(P) - 1):
        ax, az, bx, bz = P[i, 0], P[i, 1], P[i + 1, 0], P[i + 1, 1]
        for ix in range(int(math.floor(min(ax, bx) / G)), int(math.floor(max(ax, bx) / G)) + 1):
            for iz in range(int(math.floor(min(az, bz) / G)), int(math.floor(max(az, bz) / G)) + 1):
                seg_grid.setdefault((ix, iz), []).append((ax, az, bx, bz, hs))
kept = []
for r in roads:
    P = r["P"]; n = len(P); hs = SPEC[r["k"]][0]
    a, b = 0, n - 1
    while a < n and near_existing(P[a, 0], P[a, 1]): a += 1
    if a >= n - 1: continue
    while b > a and near_existing(P[b, 0], P[b, 1]): b -= 1
    a, b = max(0, a - 1), min(n - 1, b + 1)
    if b - a < 1: continue
    r["P"] = P[a:b + 1]
    add_segs(r["P"], hs)
    kept.append(r)
roads = kept
log("kept", len(roads), "points", sum(len(r["P"]) for r in roads))

# ------------------------------------------------------------------ bridge ends meet the road
# The survey's bridge decks have their own height profiles, smoothed separately from the roads either side: most
# ends came out below the road they join (median 0.3 m, up to 2 m), and about a quarter stop 3-8 m short of it.
# Each end is pulled across to the nearest road's centreline and up (or down) to that road's height there; the
# correction fades out over 40 m (the whole span for a short bridge), so the middle keeps its own line.
def _bridge_ends():
    segs = []
    for r in roads:
        if r["b"]: continue
        P = r["P"]
        for i in range(len(P) - 1): segs.append((P[i, 0], P[i, 1], P[i, 2], P[i + 1, 0], P[i + 1, 1], P[i + 1, 2]))
    S = np.array(segs)
    ax, az, ay, bx, bz, by = S.T
    dx, dz = bx - ax, bz - az; L2 = dx * dx + dz * dz + 1e-9
    def closest(x, z):
        t = np.clip(((x - ax) * dx + (z - az) * dz) / L2, 0, 1)
        px, pz = ax + dx * t, az + dz * t; d = np.hypot(px - x, pz - z)
        k = int(np.argmin(d)); return d[k], px[k], pz[k], ay[k] + (by[k] - ay[k]) * t[k]
    moved = joined = 0
    for r in roads:
        if not r["b"]: continue
        P = r["P"]
        delta = [0.0, 0.0]
        for e, i in ((0, 0), (1, len(P) - 1)):
            d, px, pz, py = closest(P[i, 0], P[i, 1])
            if d > 8.0:
                continue
            if d > 0.75:                              # stops short: carry the deck on to the road
                q = P[i].copy(); q[0], q[1], q[2] = px, pz, P[i, 2]; q[3] = 0.0
                P = np.vstack([q[None], P]) if e == 0 else np.vstack([P, q[None]])
                joined += 1
            delta[e] = py - (P[0, 2] if e == 0 else P[-1, 2])
        if abs(delta[0]) + abs(delta[1]) < 0.02:
            r["P"] = P; continue
        s = np.zeros(len(P)); s[1:] = np.cumsum(np.hypot(np.diff(P[:, 0]), np.diff(P[:, 1])))
        Ln = max(s[-1], 1e-3)
        if Ln <= 80.0:
            corr = delta[0] + (delta[1] - delta[0]) * (s / Ln)
        else:
            ua = np.clip(1.0 - s / 40.0, 0, 1); ub = np.clip(1.0 - (Ln - s) / 40.0, 0, 1)
            corr = delta[0] * ua * ua * (3 - 2 * ua) + delta[1] * ub * ub * (3 - 2 * ub)
        P = P.copy(); P[:, 2] += corr
        r["P"] = P
        moved += 1
    log("bridges: ends levelled on", moved, "decks, carried on to the road at", joined, "ends")
_bridge_ends()

# ------------------------------------------------------------------ per-point derived data
for r in roads:
    P = r["P"]; n = len(P)
    hs, kerb, verge, drain = SPEC[r["k"]]
    r.update(hs=hs, kerb=kerb, verge=verge)
    d = np.zeros(n)
    d[1:] = np.cumsum(np.hypot(np.diff(P[:, 0]), np.diff(P[:, 1])))
    r["along"] = d
    a = np.clip(np.arange(n) - 1, 0, n - 1); b = np.clip(np.arange(n) + 1, 0, n - 1)
    tx, tz = P[b, 0] - P[a, 0], P[b, 1] - P[a, 1]
    tl = np.hypot(tx, tz); tl[tl == 0] = 1
    r["tx"], r["tz"] = tx / tl, tz / tl
    r["curve"] = (np.abs(P[:, 3]) > 0.025).astype(float)
    r["endf"] = np.minimum(1.0, np.minimum(d, d[-1] - d) / 14.0)

def surf_y(P, hs, s):
    """road surface height at normalised offset s (-1..1) across the seal: crown camber + superelevation"""
    return P[:, 2] - 0.025 * hs * np.abs(s) + s * P[:, 3] * hs

# ------------------------------------------------------------------ dense centreline (1 m) for the terrain carve and the clearance field
cols = []
for r in roads:
    P = r["P"]; d = r["along"]
    if d[-1] < 0.5: continue
    m = max(2, int(d[-1]) + 1)
    s = np.linspace(0, d[-1], m)
    Q = np.stack([np.interp(s, d, P[:, c]) for c in range(8)], 1)
    tx = np.interp(s, d, r["tx"]); tz = np.interp(s, d, r["tz"]); tl = np.hypot(tx, tz); tl[tl == 0] = 1
    inner = r["hs"] + r["verge"] + (1.8 if r["kerb"] else 0.0) + 0.5
    cols.append(np.column_stack([Q, tx / tl, tz / tl, np.full(m, r["hs"]), np.full(m, inner), np.full(m, r["b"])]))
D = np.concatenate(cols)
log("dense points", len(D))
tree = cKDTree(D[:, :2])

# ------------------------------------------------------------------ carve the height map, build the clearance field
MESH_ONLY = os.environ.get("MESH_ONLY", "") != ""      # just rebuild the road meshes (the terrain carve is unchanged)
def _carve():
    global H16, OUT, MASK
    H16 = np.fromfile(f"{GAME}/data/height.r16", "<u2").reshape(T, T)
    OUT = np.empty_like(H16)
    MASK = np.full((T, T), 255, np.uint8)
    xs = X0 + np.arange(T) * SP
    STRIP = 200
    moved = 0
    for y0 in range(0, T, STRIP):
        y1 = min(T, y0 + STRIP)
        H = H16[y0:y1].astype(np.float32) / 65535 * HR + HMIN
        zz = Z0 + np.arange(y0, y1) * SP
        gx, gz = np.meshgrid(xs, zz)
        pts = np.column_stack([gx.ravel(), gz.ravel()])
        dist, k = tree.query(pts, distance_upper_bound=40.0)
        hit = np.isfinite(dist)
        Hf = H.ravel().copy()
        if hit.any():
            Q = D[k[hit]]; dd = dist[hit]; p = pts[hit]
            nx, nz = Q[:, 9], -Q[:, 8]                       # n = (tz, -tx), the browser build's right-hand normal
            side = np.where((p[:, 0] - Q[:, 0]) * nx + (p[:, 1] - Q[:, 1]) * nz < 0, -1.0, 1.0)
            hs = Q[:, 10]; inner = Q[:, 11]; bridge = Q[:, 12] > 0.5
            e = np.where(side < 0, Q[:, 4], Q[:, 6])
            e = np.maximum(e, inner + 4.0)
            sn = np.clip(dd / hs, 0, 1) * side
            y_seal = Q[:, 2] - 0.025 * hs * np.abs(sn) + sn * Q[:, 3] * hs
            y_edge = Q[:, 2] - 0.025 * hs + side * Q[:, 3] * hs
            target = np.where(dd <= hs, y_seal, y_edge) - SINK
            t = np.clip((dd - inner) / np.maximum(e - inner, 0.1), 0, 1)
            w = np.where(dd <= inner, 1.0, 1.0 - (t * t * (3 - 2 * t)))
            w[bridge] = 0.0                                  # a bridge flies over what's under it
            old = Hf[hit]
            new = old * (1 - w) + target * w
            moved += int((np.abs(new - old) > 0.05).sum())
            Hf[hit] = new
            clear = dd - (inner - 0.5)
            mv = np.clip((clear + 10.0) * 10.0, 0, 255).astype(np.uint8)
            MASK.ravel()[y0 * T:y1 * T][np.flatnonzero(hit)] = mv
        OUT[y0:y1] = np.clip(np.round((Hf.reshape(H.shape) - HMIN) / HR * 65535), 0, 65535).astype(np.uint16)
        sys.stdout.write(f"\rcarve {y1}/{T}"); sys.stdout.flush()
    print()
    OUT.astype("<u2").tofile(f"{GAME}/data/height_roads.r16")
    from PIL import Image
    Image.fromarray(MASK, "L").save(f"{GAME}/assets/roadmask.png", optimize=True)
    log("cells moved", moved)
    del H16, OUT, MASK


if not MESH_ONLY:
    _carve()

# ------------------------------------------------------------------ the Road Generator pilot's roads replace these stretches
CUT = os.environ.get("PILOT_CUT", f"{GAME}/assets/roads/rg_cut.json" if os.path.exists(f"{GAME}/assets/roads/rg_cut.json") else f"{GAME}/assets/roads/pilot_cut.json")
if os.path.exists(CUT):
    segs = []
    for c in json.load(open(CUT)):
        P = np.array(c["pts"], float)
        if len(P) == 1:
            P = np.vstack([P, P])
        for i in range(len(P) - 1):
            segs.append((P[i, 0], P[i, 1], P[i + 1, 0], P[i + 1, 1], c["r"], 1.0 if c.get("bridges") else 0.0))
    S = np.array(segs)
    from scipy.spatial import cKDTree as _KD
    _mid = _KD(np.column_stack([(S[:, 0] + S[:, 2]) / 2, (S[:, 1] + S[:, 3]) / 2]))
    _half = float(np.max(np.hypot(S[:, 2] - S[:, 0], S[:, 3] - S[:, 1]))) / 2 + float(S[:, 4].max())
    def inside(x, z, bridge=False):
        near = _mid.query_ball_point([x, z], _half)
        if not near: return False
        ax, az, bx, bz, rr, br = S[near].T
        if bridge:            # bridges keep their old decks (barriers, piers) unless a road was built over that one
            m = br > 0.5
            if not m.any(): return False
            ax, az, bx, bz, rr = ax[m], az[m], bx[m], bz[m], rr[m]
        dx, dz = bx - ax, bz - az
        L2 = dx * dx + dz * dz + 1e-9
        t = np.clip(((x - ax) * dx + (z - az) * dz) / L2, 0, 1)
        return bool((((ax + dx * t - x) ** 2 + (az + dz * t - z) ** 2) < rr * rr).any())
    pieces = []
    cut_pts = 0
    for r in roads:
        P = r["P"]
        keep = np.array([not inside(P[i, 0], P[i, 1], r["b"]) for i in range(len(P))])
        cut_pts += int((~keep).sum())
        i = 0
        while i < len(P):
            if not keep[i]:
                i += 1; continue
            j = i
            while j < len(P) and keep[j]: j += 1
            if j - i >= 2:
                q = dict(r)
                for k in ("P", "along", "tx", "tz", "curve", "endf"):
                    q[k] = r[k][i:j]
                # markings fade out where a cut end meets the new road
                e = q["endf"].copy(); dd = q["along"] - q["along"][0]
                if i > 0: e = np.minimum(e, np.minimum(1.0, dd / 14.0))
                if j < len(P): e = np.minimum(e, np.minimum(1.0, (dd[-1] - dd) / 14.0))
                q["endf"] = e
                pieces.append(q)
            i = j
    log("pilot cut: points removed", cut_pts, "roads", len(roads), "->", len(pieces))
    roads = pieces

# ------------------------------------------------------------------ flush roads: a skin lying on the carved ground
# (FLUSH=1): no kerbs, shoulders or batters; every vertex sits on the height map, a little proud; finer along the road
# so it follows the ground; bridge decks kept but brought down at their ends onto the (sunk) approaches. Bridge decks
# go in their own surface ("deck") so they alone get collision; everything else you drive on is the terrain.
FLUSH = os.environ.get("FLUSH", "") != ""
if FLUSH:
    HF = np.fromfile(f"{GAME}/data/height_roads.r16", "<u2").reshape(T, T).astype(np.float32) / 65535 * HR + HMIN
    def hgt(x, z):
        fx = (np.asarray(x) - X0) / SP; fz = (np.asarray(z) - Z0) / SP
        i0 = np.clip(np.floor(fx).astype(int), 0, T - 2); j0 = np.clip(np.floor(fz).astype(int), 0, T - 2)
        a_ = np.clip(fx - i0, 0, 1); b_ = np.clip(fz - j0, 0, 1)
        return (HF[j0, i0] * (1 - a_) * (1 - b_) + HF[j0, i0 + 1] * a_ * (1 - b_) + HF[j0 + 1, i0] * (1 - a_) * b_ + HF[j0 + 1, i0 + 1] * a_ * b_)
    _out = []
    for r in roads:
        d = r["along"] - r["along"][0]
        if r["b"]:
            P = r["P"].copy(); L = d[-1]
            P[:, 2] -= SINK * np.clip(1 - np.minimum(d, L - d) / 10.0, 0, 1)
            r["P"] = P
        else:
            m = max(2, int(math.ceil(d[-1] / 4.0)) + 1)
            sx = np.linspace(0, d[-1], m)
            q = dict(r)
            q["P"] = np.stack([np.interp(sx, d, r["P"][:, c]) for c in range(8)], 1)
            for k in ("tx", "tz", "curve", "endf"):
                q[k] = np.interp(sx, d, r[k])
            tl = np.hypot(q["tx"], q["tz"]); tl[tl == 0] = 1; q["tx"] = q["tx"] / tl; q["tz"] = q["tz"] / tl
            q["along"] = sx + r["along"][0]
            r = q
        _out.append(r)
    roads = _out
    log("flush: roads resampled", len(roads))

# ------------------------------------------------------------------ road meshes
def section(r):
    """cross-section stations for this road: list of (offset_m, kind) where kind picks height rule and surface"""
    hs, verge, kerb = r["hs"], r["verge"], r["kerb"]
    if r["b"]:   # bridge deck: seal edge to edge, the barriers are separate
        return [(-hs - 0.25, "deck"), (-hs, "seal"), (-hs / 2, "seal"), (0, "seal"), (hs / 2, "seal"), (hs, "seal"), (hs + 0.25, "deck")]
    if FLUSH:
        n = max(2, int(math.ceil(2 * hs / 1.6)))
        return [(-hs - 0.9, "edge")] + [(-hs + 2 * hs * i / n, "seal") for i in range(n + 1)] + [(hs + 0.9, "edge")]
    if kerb:
        st = [(-hs - 2.6, "batter"), (-hs - 1.8, "path"), (-hs - 0.05, "kerbtop"), (-hs, "seal"), (-hs / 2, "seal"), (0, "seal"),
              (hs / 2, "seal"), (hs, "seal"), (hs + 0.05, "kerbtop"), (hs + 1.8, "path"), (hs + 2.6, "batter")]
    else:
        v = max(verge, 0.4)
        st = [(-hs - v - 1.2, "batter"), (-hs - v, "shoulder"), (-hs, "seal"), (-hs / 2, "seal"), (0, "seal"), (hs / 2, "seal"),
              (hs, "seal"), (hs + v, "shoulder"), (hs + v + 1.2, "batter")]
    return st

SURF = {"seal": 0.0, "shoulder": 0.5, "batter": 0.75, "path": 1.0, "kerbtop": 1.0, "deck": 1.0, "edge": 0.5}

class Builder:
    def __init__(self):
        self.p, self.n, self.uv, self.uv2, self.c, self.i = [], [], [], [], [], []
        self.cp, self.cn, self.ci = [], [], []          # concrete (bridge barriers, piers, undersides)
        self.count = 0; self.ccount = 0
    def strip(self, rows, uvs, uv2s, cols):
        """rows: (n, m, 3) grid of positions along x across; builds quads between neighbours"""
        n, m, _ = rows.shape
        base = self.count
        self.p.append(rows.reshape(-1, 3)); self.uv.append(uvs.reshape(-1, 2)); self.uv2.append(uv2s.reshape(-1, 2)); self.c.append(cols.reshape(-1, 4))
        # normals from the grid
        da = np.gradient(rows, axis=0); dc = np.gradient(rows, axis=1)
        nr = np.cross(dc, da); nl = np.linalg.norm(nr, axis=2, keepdims=True); nl[nl == 0] = 1; nr = nr / nl
        nr[nr[..., 1] < 0] *= -1
        self.n.append(nr.reshape(-1, 3))
        ii, jj = np.meshgrid(np.arange(n - 1), np.arange(m - 1), indexing="ij")
        v = base + ii * m + jj
        q = np.stack([v, v + m, v + 1, v + 1, v + m, v + m + 1], -1).reshape(-1)   # counter-clockwise seen from above
        self.i.append(q)
        self.count += n * m
    def concrete_quads(self, quads):
        for (a, b, c, d) in quads:     # a b along the bottom, c d along the top; normal from the winding
            nrm = np.cross(np.subtract(b, a), np.subtract(c, a)); l = np.linalg.norm(nrm) or 1; nrm = nrm / l
            base = self.ccount
            self.cp += [a, b, c, d]; self.cn += [nrm] * 4
            # wound so the face the normal points out of is the front (the other way round, both sides lit dark)
            self.ci += [base, base + 1, base + 2, base + 1, base + 3, base + 2]
            self.ccount += 4

tiles = {}
decks = {}
lines = {}     # FLUSH: tile -> [(hs, surf, mark, wild, pts (n x 5: x, z, along, endf, curve))] built in the game
names = {}
def tile_of(x, z):
    return (int((x - X0) // TILE), int((z - Z0) // TILE))

for r in roads:
    P = r["P"]; n = len(P); hs = r["hs"]
    st = section(r)
    offs = np.array([o for o, _ in st]); kinds = [k for _, k in st]
    nx, nz = r["tz"], -r["tx"]
    rows = np.zeros((n, len(st), 3)); uvs = np.zeros((n, len(st), 2)); uv2 = np.zeros((n, len(st), 2)); col = np.zeros((n, len(st), 4))
    side = np.sign(offs)
    for j, (o, kd) in enumerate(st):
        rows[:, j, 0] = P[:, 0] + nx * o
        rows[:, j, 2] = P[:, 1] + nz * o
        sgn = 1.0 if o > 0 else -1.0
        y_edge = P[:, 2] - 0.025 * hs + sgn * P[:, 3] * hs
        if kd == "seal": y = surf_y(P, hs, np.full(n, o / hs))
        elif kd == "deck": y = y_edge + 0.02
        elif kd == "shoulder": y = y_edge - 0.06
        elif kd == "kerbtop": y = y_edge + 0.15
        elif kd == "path": y = y_edge + 0.17
        else: y = y_edge - 0.75                      # batter: down into the ground under the verge
        if FLUSH and not r["b"]:
            y = hgt(rows[:, j, 0], rows[:, j, 2]) + (0.045 if kd == "seal" else 0.02)
        rows[:, j, 1] = y
        uvs[:, j, 0] = o; uvs[:, j, 1] = r["along"]
        uv2[:, j, 0] = hs; uv2[:, j, 1] = r["endf"]
        col[:, j, 0] = 0.5 if (r["k"] == "service" and kd == "seal") else SURF[kd]
        col[:, j, 1] = MARK.get(r["k"], 0.0)
        col[:, j, 2] = r["curve"]
        col[:, j, 3] = WILD[r["rank"]]
    # cut into tiles by segment midpoint, keeping each run of segments in one tile together
    mid_t = [tile_of((P[i, 0] + P[i + 1, 0]) / 2, (P[i, 1] + P[i + 1, 1]) / 2) for i in range(n - 1)]
    i0 = 0
    while i0 < n - 1:
        tkey = mid_t[i0]; i1 = i0
        while i1 + 1 < n - 1 and mid_t[i1 + 1] == tkey: i1 += 1
        B = tiles.setdefault(tkey, Builder())
        if FLUSH and not r["b"]:
            sl = slice(i0, i1 + 2)
            pts = np.column_stack([P[sl, 0], P[sl, 1], r["along"][sl], r["endf"][sl], r["curve"][sl]])
            lines.setdefault(tkey, []).append((hs, 0.5 if r["k"] == "service" else 0.0, MARK.get(r["k"], 0.0), WILD[r["rank"]], pts))
        else:
            (decks.setdefault(tkey, Builder()) if FLUSH else B).strip(rows[i0:i1 + 2], uvs[i0:i1 + 2], uv2[i0:i1 + 2], col[i0:i1 + 2])
        if r["n"]: names.setdefault(tkey, set()).add(r["n"])
        if r["b"]:   # bridge: barriers, underside, piers
            q = []
            for i in range(i0, i1 + 1):
                for s in (-1, 1):
                    ox0, oz0 = nx[i] * (hs + 0.25) * s, nz[i] * (hs + 0.25) * s
                    ox1, oz1 = nx[i + 1] * (hs + 0.25) * s, nz[i + 1] * (hs + 0.25) * s
                    ya = P[i, 2] - 0.025 * hs + s * P[i, 3] * hs; yb = P[i + 1, 2] - 0.025 * hs + s * P[i + 1, 3] * hs
                    a = (P[i, 0] + ox0, ya - 1.3, P[i, 1] + oz0); b = (P[i + 1, 0] + ox1, yb - 1.3, P[i + 1, 1] + oz1)
                    c = (P[i, 0] + ox0, ya + 0.9, P[i, 1] + oz0); d = (P[i + 1, 0] + ox1, yb + 0.9, P[i + 1, 1] + oz1)
                    q.append((a, b, c, d) if s > 0 else (b, a, d, c))
                    # inner face of the barrier, slightly in
                    ia = (P[i, 0] + ox0 * 0.97, ya + 0.02, P[i, 1] + oz0 * 0.97); ib = (P[i + 1, 0] + ox1 * 0.97, yb + 0.02, P[i + 1, 1] + oz1 * 0.97)
                    ic = (P[i, 0] + ox0 * 0.97, ya + 0.9, P[i, 1] + oz0 * 0.97); idd = (P[i + 1, 0] + ox1 * 0.97, yb + 0.9, P[i + 1, 1] + oz1 * 0.97)
                    q.append((ib, ia, idd, ic) if s > 0 else (ia, ib, ic, idd))
                # underside
                ua = (P[i, 0] - nx[i] * hs, P[i, 2] - 1.3, P[i, 1] - nz[i] * hs); ub = (P[i + 1, 0] - nx[i + 1] * hs, P[i + 1, 2] - 1.3, P[i + 1, 1] - nz[i + 1] * hs)
                uc = (P[i, 0] + nx[i] * hs, P[i, 2] - 1.3, P[i, 1] + nz[i] * hs); ud = (P[i + 1, 0] + nx[i + 1] * hs, P[i + 1, 2] - 1.3, P[i + 1, 1] + nz[i + 1] * hs)
                q.append((ua, ub, uc, ud))
            # piers every ~18 m where the deck is well up off the ground (ground height from the carved map)
            step = max(1, int(round(18 / max(1e-3, np.mean(np.diff(r["along"]))))))
            for i in range(i0 + 1, i1 + 1, step):
                for ss in (-0.55, 0.55):
                    px, pz = P[i, 0] + nx[i] * hs * ss, P[i, 1] + nz[i] * hs * ss
                    gy = min(P[i, 5], P[i, 7], P[i, 2] - 3.0)
                    if P[i, 2] - gy < 2.5: continue
                    for t in range(8):
                        a0, a1 = t / 8 * 2 * math.pi, (t + 1) / 8 * 2 * math.pi
                        p0 = (px + math.cos(a0) * 0.55, gy - 4.0, pz + math.sin(a0) * 0.55); p1 = (px + math.cos(a1) * 0.55, gy - 4.0, pz + math.sin(a1) * 0.55)
                        p2 = (px + math.cos(a0) * 0.55, P[i, 2] - 1.3, pz + math.sin(a0) * 0.55); p3 = (px + math.cos(a1) * 0.55, P[i, 2] - 1.3, pz + math.sin(a1) * 0.55)
                        q.append((p1, p0, p3, p2))
            B.concrete_quads(q)
        i0 = i1 + 1

# ------------------------------------------------------------------ glTF out
def write_glb(path, B, origin, BD=None):
    parts, views, acc = [], [], []
    off = 0
    def add(buf, target=None):
        nonlocal off
        pad = (-len(buf)) % 4
        views.append({"buffer": 0, "byteOffset": off, "byteLength": len(buf), **({"target": target} if target else {})})
        parts.append(buf); parts.append(b"\0" * pad); off += len(buf) + pad
        return len(views) - 1
    def accessor(arr, typ, comp=5126, target=34962, normalized=False):
        a = {"bufferView": add(arr.tobytes(), target), "componentType": comp, "count": int(arr.shape[0]), "type": typ}
        if normalized: a["normalized"] = True
        if typ == "VEC3" and comp == 5126 and target == 34962:
            a["min"] = arr.min(0).tolist(); a["max"] = arr.max(0).tolist()
        acc.append(a); return len(acc) - 1
    prims = []
    mats = [{"name": "road"}, {"name": "concrete"}, {"name": "deck"}]
    for BB, mi_ in ((B, 0), (BD, 2)):
        if BB is None or not BB.count: continue
        P = (np.concatenate(BB.p) - origin).astype(np.float32)
        prims.append({"attributes": {"POSITION": accessor(P, "VEC3"), "NORMAL": accessor(np.concatenate(BB.n).astype(np.float32), "VEC3"),
                                     "TEXCOORD_0": accessor(np.concatenate(BB.uv).astype(np.float32), "VEC2"),
                                     "TEXCOORD_1": accessor(np.concatenate(BB.uv2).astype(np.float32), "VEC2"),
                                     "COLOR_0": accessor((np.clip(np.concatenate(BB.c), 0, 1) * 255 + 0.5).astype(np.uint8), "VEC4", 5121, normalized=True)},
                      "indices": accessor(np.concatenate(BB.i).astype(np.uint32), "SCALAR", 5125, 34963), "material": mi_})
    if B.ccount:
        CP = (np.array(B.cp) - origin).astype(np.float32)
        prims.append({"attributes": {"POSITION": accessor(CP, "VEC3"), "NORMAL": accessor(np.array(B.cn, np.float32), "VEC3")},
                      "indices": accessor(np.array(B.ci, np.uint32), "SCALAR", 5125, 34963), "material": 1})
    g = {"asset": {"version": "2.0", "generator": "bake_roads"}, "scene": 0, "scenes": [{"nodes": [0]}],
         "nodes": [{"name": "road", "mesh": 0, "translation": origin.tolist()}], "meshes": [{"name": "road", "primitives": prims}],
         "materials": mats, "accessors": acc, "bufferViews": views, "buffers": [{"byteLength": off}]}
    js = json.dumps(g).encode(); js += b" " * ((-len(js)) % 4)
    bin_ = b"".join(parts)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(bin_), 0x004E4942)); f.write(bin_)

od = f"{GAME}/assets/roads"
os.makedirs(od, exist_ok=True)
for f in os.listdir(od):
    if f.endswith(".glb"): os.remove(os.path.join(od, f))      # .import files stay: they hold the tiles' import options
index = []
tot = 0
for k_ in decks:
    tiles.setdefault(k_, Builder())
if FLUSH:
    # the centrelines for the game to lay the road skin from, tile by tile
    with open(f"{od}/lines.bin", "wb") as f:
        f.write(struct.pack("<I", len(lines)))
        for (tx_, tz_), pcs in sorted(lines.items()):
            f.write(struct.pack("<iiI", tx_, tz_, len(pcs)))
            for hs_, sf_, mk_, wl_, pts in pcs:
                f.write(struct.pack("<ffffI", hs_, sf_, mk_, wl_, len(pts)))
                f.write(pts.astype("<f4").tobytes())
    log("lines.bin MB", round(os.path.getsize(f"{od}/lines.bin") / 1e6, 1), "tiles", len(lines))
    # tiles with nothing baked (no bridges) still need a place in the index for their names
    for k_ in lines:
        tiles.setdefault(k_, Builder())
for (tx, tz), B in sorted(tiles.items()):
    origin = np.array([X0 + tx * TILE + TILE / 2, 0.0, Z0 + tz * TILE + TILE / 2])
    fn = f"road_{tx}_{tz}.glb"
    if not B.count and not B.ccount and not decks.get((tx, tz)):
        index.append({"file": "", "x": float(origin[0]), "z": float(origin[2]), "names": sorted(names.get((tx, tz), []))})
        continue
    write_glb(f"{od}/{fn}", B, origin, decks.get((tx, tz)))
    index.append({"file": fn, "x": float(origin[0]), "z": float(origin[2]), "names": sorted(names.get((tx, tz), []))})
    tot += os.path.getsize(f"{od}/{fn}")
json.dump({"tile": TILE, "tiles": index}, open(f"{od}/index.json", "w"))
log("tiles", len(index), "MB", round(tot / 1e6, 1))
