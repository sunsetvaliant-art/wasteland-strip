#!/usr/bin/env python3
"""Road Generator roads for the whole map: every drivable OpenStreetMap road (the Richmond-Tweed extract, clipped to
the map), turned into a road graph that tools/bake_rg.gd builds with the Road Generator addon and bakes into tiles.
Bridges stay the old baked decks (they have their barriers and piers); the roads stop where a bridge starts.
Tweed Valley Way south of the Tweed Regional Gallery gets the southbound overtaking lane read off NSW aerial imagery
(OSM doesn't tag it): starts at the gallery, ~1.1 km, merges back by ~1.2 km.
Writes
  assets/roads/pilot.json      {"edges": [{name, cls, pts:[[x,y,z]..], fwd, rev, lane_w, a, b, lanes_at:[..]}],
                                "junctions": [{id, pos, kind: "x" | "roundabout", r}]}
  assets/roads/pilot_cut.json  polylines + radius: the old baked road mesh is cut away under these (tools/bake_roads.py)
Usage: road_pilot.py <osm files...>  (fetched from api.openstreetmap.org/api/0.6/map)
"""
import sys, json, math, base64
import xml.etree.ElementTree as ET
import numpy as np
from scipy.spatial import cKDTree

LAT0, LON0 = -28.3285718, 153.4035024          # map origin, the Riverview Hotel: x east, z south, metres
PUB_R = 380.0
GALLERY = (-28.348867, 153.4004758)
TVW_LEN = 1700.0                                  # metres of Tweed Valley Way south of the gallery
OVERTAKE = (20.0, 1120.0)                         # metres along it with two lanes southbound
GAME = "/home/claude/game"
SRC = "/home/claude/ws_src/tw"
KEEP = {"motorway", "motorway_link", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential", "living_street",
        "trunk_link", "primary_link", "secondary_link", "tertiary_link"}
LANE_W = {"motorway": 3.5, "trunk": 3.5, "primary": 3.4, "secondary": 3.3, "tertiary": 3.2, "unclassified": 3.0, "residential": 3.2,
          "living_street": 2.8}


def proj(lat, lon):
    return ((lon - LON0) * 111320.0 * math.cos(math.radians(LAT0)), -(lat - LAT0) * 110574.0)


# ------------------------------------------------------------------ OSM
nodes, ways, ways_all = {}, {}, {}
for f in sys.argv[1:]:
    t = ET.parse(f).getroot()
    for n in t.iter("node"):
        nodes[n.get("id")] = proj(float(n.get("lat")), float(n.get("lon")))
    for w in t.iter("way"):
        tg = {x.get("k"): x.get("v") for x in w.findall("tag")}
        hw = tg.get("highway", "")
        if hw in KEEP:
            ways_all[w.get("id")] = (tg, [x.get("ref") for x in w.findall("nd")])
            if tg.get("bridge", "no") in ("no", ""):
                ways[w.get("id")] = ways_all[w.get("id")]
print("ways", len(ways))

# ------------------------------------------------------------------ surveyed seal heights (the roads as tools/bake_roads.py has them)
_src = open(f"{GAME}/tools/bake_roads.py").read()
_ns = {}
exec(_src[:_src.index("# ------------------------------------------------------------------ per-point derived data")], _ns)
H = np.concatenate([r["P"][:, :3] for r in _ns["roads"]]).astype(np.float64)
htree = cKDTree(H[:, :2])
MAPX = (-8960.0, -8960.0 + 6400 * 5.0); MAPZ = (-16960.0, -16960.0 + 6400 * 5.0)


def seal_y(x, z):
    d, k = htree.query([x, z], k=4)
    w = 1.0 / np.maximum(d, 0.3) ** 2
    return float((H[k, 2] * w).sum() / w.sum())


# ------------------------------------------------------------------ pick the ways
def dist0(p):
    return math.hypot(p[0], p[1])


def in_map(p, m=30.0):
    return MAPX[0] + m < p[0] < MAPX[1] - m and MAPZ[0] + m < p[1] < MAPZ[1] - m
sel = {}
for wid, (tg, nd) in ways.items():
    keep = [r for r in nd if r in nodes and in_map(nodes[r])]
    if len(keep) >= 2:
        sel[wid] = (tg, keep)

# B: Tweed Valley Way chain south from the gallery
gal = proj(*GALLERY)
tvw = [(wid, tg, nd) for wid, (tg, nd) in ways_all.items() if tg.get("name") == "Tweed Valley Way"]
ends = {}
for i, (wid, tg, nd) in enumerate(tvw):
    for e in (nd[0], nd[-1]):
        ends.setdefault(e, []).append(i)
best = min(((math.dist(nodes[r], gal), i, j) for i, (w, tg, nd) in enumerate(tvw) for j, r in enumerate(nd) if r in nodes))
_, wi, j = best
w = tvw[wi][2]
path = w[j:] if nodes[w[-1]][1] > nodes[w[0]][1] else w[:j + 1][::-1]
used = {wi}
while True:
    e = path[-1]
    nxt = next((k for k in ends.get(e, []) if k not in used and not (tvw[k][1].get("oneway") == "yes" and tvw[k][2][0] != e)), None)
    if nxt is None:
        break
    used.add(nxt)
    nd = tvw[nxt][2]
    path += nd[1:] if nd[0] == e else nd[::-1][1:]
    L = sum(math.dist(nodes[path[i]], nodes[path[i + 1]]) for i in range(len(path) - 1))
    if L > TVW_LEN + 200:
        break
chain = [path[0]]
L = 0.0
for i in range(1, len(path)):
    L += math.dist(nodes[path[i - 1]], nodes[path[i]])
    chain.append(path[i])
    if L > TVW_LEN:
        break
print("TVW chain", len(chain), "nodes, %.0f m" % L)
# the chain is built as its own edge (it has the lane plan), so those stretches come out of the normal ways
chain_set = set(chain[1:-1])
for wid in list(sel):
    tg, nd = sel[wid]
    if tg.get("name") == "Tweed Valley Way" and any(r in chain_set for r in nd):
        rest = [r for r in nd if r not in chain_set]
        if len(rest) >= 2 and len(rest) < len(nd):
            # keep only the part beyond the chain (contiguous run outside it)
            runs, cur = [], []
            for r in nd:
                if r in chain_set:
                    if len(cur) >= 2: runs.append(cur)
                    cur = []
                else:
                    cur.append(r)
            if len(cur) >= 2: runs.append(cur)
            del sel[wid]
            for i, run in enumerate(runs):
                sel[f"{wid}_{i}"] = (tg, run)
        else:
            del sel[wid]

# ------------------------------------------------------------------ graph: split ways at shared nodes
use = {}
for wid, (tg, nd) in sel.items():
    for r in nd:
        use[r] = use.get(r, 0) + 1
for wid, (tg, nd) in sel.items():
    if len(nd) >= 1:
        use[nd[0]] += 1
        use[nd[-1]] += 1

# roundabouts: connected groups of junction=roundabout ways -> one junction at the centroid
rb_ways = [wid for wid, (tg, nd) in sel.items() if tg.get("junction") in ("roundabout", "circular")]
rb_groups, seen = [], set()
for wid in rb_ways:
    if wid in seen:
        continue
    grp, stack = [], [wid]
    while stack:
        a = stack.pop()
        if a in seen:
            continue
        seen.add(a)
        grp.append(a)
        sa = set(sel[a][1])
        for b in rb_ways:
            if b not in seen and sa & set(sel[b][1]):
                stack.append(b)
    rb_groups.append(grp)
rb_node = {}
junctions = []
for gi, grp in enumerate(rb_groups):
    ring = sorted({r for a in grp for r in sel[a][1]})
    P = np.array([nodes[r] for r in ring])
    c = P.mean(0)
    rad = float(np.median(np.linalg.norm(P - c, axis=1)))
    jid = "rb%d" % gi
    junctions.append({"id": jid, "pos": [float(c[0]), seal_y(*c), float(c[1])], "kind": "roundabout", "r": max(rad, 6.0)})
    for r in ring:
        rb_node[r] = jid
print("roundabouts", len(rb_groups), [round(j["r"], 1) for j in junctions])

edges = []


def lanes_of(tg):
    oneway = tg.get("oneway") == "yes" or tg.get("junction") == "roundabout"
    n = int(tg.get("lanes", "1" if oneway else "2").split(";")[0] or 2)
    if oneway:
        return max(n, 1), 0
    f = int(tg.get("lanes:forward", max(1, n // 2)))
    b = int(tg.get("lanes:backward", max(1, n - f)))
    return f, b


def add_edge(name, cls, pts, fwd, rev, a, b, lanes_at=None):
    if len(pts) < 2:
        return
    P = np.array(pts)
    d = np.r_[0, np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))]
    if d[-1] < 6.0:
        return
    edges.append({"name": name, "cls": cls, "raw": P, "d": d, "fwd": fwd, "rev": rev, "a": a, "b": b,
                  "lane_w": LANE_W.get(cls.replace("_link", ""), 3.2), "lanes_at": lanes_at})


jpos = {}
for wid, (tg, nd) in sel.items():
    if wid in rb_ways:
        continue
    fwd, rev = lanes_of(tg)
    cut = [0]
    for i in range(1, len(nd) - 1):
        if use.get(nd[i], 0) >= 2 or nd[i] in rb_node:
            cut.append(i)
    cut.append(len(nd) - 1)
    for s, e in zip(cut[:-1], cut[1:]):
        seg = nd[s:e + 1]

        def jn(r):
            if r in rb_node:
                return rb_node[r]
            if use.get(r, 0) >= 3 or (use.get(r, 0) >= 2 and r not in (nd[0], nd[-1])):
                jpos[r] = nodes[r]
                return "n" + r
            return None
        a, b = jn(seg[0]), jn(seg[-1])
        # trim inside a roundabout: stop the leg at the ring
        pts = [nodes[r] for r in seg if r not in rb_node or r in (seg[0], seg[-1])]
        add_edge(tg.get("name", ""), tg.get("highway"), pts, fwd, rev, a, b)

# B, one edge, its own lane plan
tg = {"highway": "trunk"}
pts = [nodes[r] for r in chain]
P = np.array(pts)
d = np.r_[0, np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))]
add_edge("Tweed Valley Way", "trunk", pts, 1, 1, None, None)
edges[-1]["overtake"] = list(OVERTAKE)

# join chains through plain degree-2 nodes (one way ending where the next begins) so roads aren't chopped up
for r, c in list(use.items()):
    pass

# ------------------------------------------------------------------ junction degree check: 2-way "junctions" are just joins
deg = {}
for e in edges:
    for k in (e["a"], e["b"]):
        if k:
            deg[k] = deg.get(k, 0) + 1
for k, p in jpos.items():
    jid = "n" + k
    if deg.get(jid, 0) >= 3:
        junctions.append({"id": jid, "pos": [p[0], seal_y(*p), p[1]], "kind": "x", "r": 0.0})
valid = {j["id"] for j in junctions}
for e in edges:
    if e["a"] not in valid: e["a"] = None
    if e["b"] not in valid: e["b"] = None

# ------------------------------------------------------------------ trim back from junctions, resample, heights
jmap = {j["id"]: j for j in junctions}
out = []
for e in edges:
    P, d = e["raw"], e["d"]
    half = e["lane_w"] * max(e["fwd"] + e["rev"], 1) * 0.5
    t0, t1 = 0.0, d[-1]
    for end, key in ((0, e["a"]), (1, e["b"])):
        if not key:
            continue
        j = jmap[key]
        back = (j["r"] + 6.0) if j["kind"] == "roundabout" else (half + 7.0)
        if end == 0:
            t0 = max(t0, min(back, d[-1] * 0.45))
        else:
            t1 = min(t1, d[-1] - min(back, d[-1] * 0.45))
    if t1 - t0 < 4.0:
        continue
    step = 12.0
    n = max(2, int(math.ceil((t1 - t0) / step)) + 1)
    s = np.linspace(t0, t1, n)
    x = np.interp(s, d, P[:, 0]); z = np.interp(s, d, P[:, 1])
    y = np.array([seal_y(a, b) for a, b in zip(x, z)])
    y = np.convolve(np.pad(y, 2, mode="edge"), np.ones(5) / 5, mode="valid")
    rec = {"name": e["name"], "cls": e["cls"], "fwd": e["fwd"], "rev": e["rev"], "lane_w": e["lane_w"],
           "a": e["a"], "b": e["b"], "pts": [[round(float(a), 2), round(float(c), 2), round(float(b), 2)] for a, b, c in zip(x, z, y)]}
    if "overtake" in e:
        o0, o1 = e["overtake"]
        rec["lanes_at"] = [2 if o0 <= si <= o1 else 1 for si in s]       # southbound lanes at each point
    out.append(rec)
print("edges", len(out), "junctions", len(junctions), "x:", sum(1 for j in junctions if j["kind"] == "x"))
# ------------------------------------------------------------------ blocks: the addon slows right down on a graph this big, so
# tools/bake_rg.gd builds it a block at a time; an edge that crosses a block edge is cut there into two pieces that
# meet end to end at the same point, heading the same way
BLOCK = 2048.0
def blk(p): return (int(math.floor((p[0] - MAPX[0]) / BLOCK)), int(math.floor((p[2] - MAPZ[0]) / BLOCK)))
jblock = {j["id"]: blk(j["pos"]) for j in junctions}
for j in junctions: j["block"] = list(jblock[j["id"]])
pieces = []
for e in out:
    bs = [blk(p) for p in e["pts"]]
    runs, start = [], 0
    for i in range(1, len(bs)):
        if bs[i] != bs[start]:
            runs.append((start, i))           # this piece runs start..i (it ends on the first point of the next block)
            start = i
    runs.append((start, len(bs) - 1))
    for k, (i0, i1) in enumerate(runs):
        if i1 - i0 < 1: continue
        q = dict(e)
        q["pts"] = e["pts"][i0:i1 + 1]
        if "lanes_at" in e: q["lanes_at"] = e["lanes_at"][i0:i1 + 1]
        q["a"] = e["a"] if k == 0 else None
        q["b"] = e["b"] if k == len(runs) - 1 else None
        q["block"] = list(bs[i0])
        # a junction in another block can't take this piece as a branch
        if q["a"] and jblock.get(q["a"]) != bs[i0]: q["a"] = None
        if q["b"] and jblock.get(q["b"]) != bs[i0]: q["b"] = None
        pieces.append(q)
print("pieces", len(pieces), "blocks", len({tuple(q["block"]) for q in pieces}))
json.dump({"edges": pieces, "junctions": junctions}, open(f"{GAME}/assets/roads/rg_graph.json", "w"))

# ------------------------------------------------------------------ what to cut out of the old baked roads
cut = [{"pts": [[p[0], p[2]] for p in e["pts"]], "r": e["lane_w"] * max(e["fwd"] + e["rev"], 1) * 0.5 + 6.0,
        "bridges": "lanes_at" in e} for e in out]
for j in junctions:
    cut.append({"pts": [[j["pos"][0], j["pos"][2]]], "r": (j["r"] + 14.0) if j["kind"] == "roundabout" else 16.0})
json.dump(cut, open(f"{GAME}/assets/roads/rg_cut.json", "w"))
print("cut pieces", len(cut))
