#!/usr/bin/env python3
"""Tweed City directory plan (the user's screenshot) -> traced shapes for the game's Twin City.
Segments the picture by colour (concourse, shops, anchors), cleans it, and writes twin_city.json: every shop and
anchor as a polygon (angles and curves kept as short straight runs), the walls round them classed by what's on the
other side (outside / concourse / next shop), the building outline, the ways in. Coordinates are metres in the
mall's own frame: x = south, z = west (the TWIN CITY lot's frame), fitted to the lot's 378.3 x 244.7 m.
usage: trace.py <screenshot.jpg> <out.json> [debug.png]"""
import sys, json, math
import numpy as np, cv2
from scipy import ndimage as ndi
LOT_W, LOT_D = 378.3, 244.7           # lot: w along x (south), d along z (west)
src, out = sys.argv[1], sys.argv[2]
im = cv2.imread(src)
if im.shape[0] > 2000: im = im[420:1800, 60:1000]          # the whole phone screenshot: cut it down to the plan
rgb = im[..., ::-1].astype(int); r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
v = rgb.mean(2); sat = rgb.max(2) - rgb.min(2); grey = sat < 14
H, W = v.shape
conc = grey & (v >= 224) & (v < 249)
shop = grey & (v >= 170) & (v < 224)
dark = grey & (v < 170)
kmart = (b > r + 25) & (v > 150); coles = (r > g + 60) & (r > 150); wool = (g > b + 25) & (g > r + 10); bigw = (b > r + 40) & (v < 150)
# the three pad sites out west and the LOADING DOCK lettering aren't the mall
for m in (conc, shop, dark):
    m[:, :90] = False; m[300:600, 860:] = False

def biggest(mask, n=1, close=9):
    m = cv2.morphologyEx(mask.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((close, close), np.uint8))
    lab, k = ndi.label(m)
    if k == 0: return []
    sizes = ndi.sum(m, lab, range(1, k + 1))
    res = []
    for i in np.argsort(sizes)[::-1][:n]:
        res.append(ndi.binary_fill_holes(lab == i + 1))
    return res

L = np.zeros((H, W), np.int32)          # 0 outside, 1 concourse, 2.. shops and anchors
units = {}
nid = 2
def add(mask, kind, name, title=""):
    global nid
    L[mask] = nid; units[nid] = {"kind": kind, "name": name, "title": title}; nid += 1
anch = np.zeros((H, W), bool)
for mask, kind, name, title in [(biggest(kmart)[0], "bigbox", "kmart", "HOLLIS & CRANE"), (biggest(coles)[0], "super", "coles", "FRESHWAY"),
                                (biggest(wool)[0], "super", "woolworths", "GREENGATE"), (biggest(bigw)[0], "bigbox", "bigw", "BIG VALUE")]:
    add(mask, kind, name, title); anch |= mask
darks = biggest(dark, 3, 13)
darks.sort(key=lambda m: ndi.center_of_mass(m)[0])          # north to south: Best&Less, JB Hi-Fi, Hoyts
for mask, (kind, name, title) in zip(darks, [("store", "bestless", "BETTER FOR LESS"), ("store", "jbhifi", "VOLT ELECTRICAL"), ("cinema", "hoyts", "REGENT CINEMAS")]):
    mask = mask & ~anch; add(mask, kind, name, title); anch |= mask

# shops: tidy the speckle the watermark leaves, split into units along the thin lines between them. The lines are
# only a pixel or two wide and leak on the diagonals, so label a shrunken copy and let each unit grow back after.
s = shop & ~anch
s = cv2.morphologyEx(s.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)).astype(bool)
core = cv2.erode(s.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
lab, k = ndi.label(core)
sizes = ndi.sum(core, lab, range(1, k + 1))
small = np.zeros((H, W), bool)
for i, sz in enumerate(sizes):
    m = lab == i + 1
    if sz < 220:                         # under ~30 m2: a kiosk, a column, a speck: leave it as open floor
        small |= m; continue
    m = ndi.binary_fill_holes(m)
    add(m & (L == 0), "unit", "shop%d" % nid)
dist0, idx0 = ndi.distance_transform_edt(L < 2, return_indices=True)
back = s & (L == 0) & (dist0 <= 3) & ~small
L[back] = L[idx0[0], idx0[1]][back]
# the building: everything, closed up so the cinema meets the mall, and filled; a wing standing apart (JB Hi-Fi and
# the south-west dining wing) is joined to the main building by a covered link straight across the gap
bld = (L > 0) | conc | small
bld = cv2.morphologyEx(bld.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8)).astype(bool)
lab, k = ndi.label(bld); sizes = ndi.sum(bld, lab, range(1, k + 1))
order = np.argsort(sizes)[::-1]
main = lab == (int(order[0]) + 1)
link = np.zeros((H, W), np.uint8)
for i in order[1:]:
    if sizes[i] < 3000: continue
    part = lab == (int(i) + 1)
    dm, im_ = ndi.distance_transform_edt(~main, return_indices=True)
    yy, xx = np.where(part)
    j = int(np.argmin(dm[yy, xx]))
    p_from = (int(xx[j]), int(yy[j])); p_to = (int(im_[1][yy[j], xx[j]]), int(im_[0][yy[j], xx[j]]))
    cv2.line(link, p_from, p_to, 1, 30)
    main = main | part
    print("joined a wing across", round(float(dm[yy[j], xx[j]]) * 0.3, 1), "m at px", p_from)
bld = ndi.binary_fill_holes(main | (link > 0))
L[~bld] = 0
# what's left inside is concourse; then units and anchors grow into the thin lines between them (not into real malls)
free = bld & (L == 0)
wide = cv2.morphologyEx(free.astype(np.uint8), cv2.MORPH_OPEN, np.ones((9, 9), np.uint8)).astype(bool)
thin = free & ~wide
dist, idx = ndi.distance_transform_edt(L < 2, return_indices=True)
near = L[idx[0], idx[1]]
grow = thin & (dist <= 6)
L[grow] = near[grow]
L[bld & (L == 0)] = 1
# every stretch of mall has to be reachable from the rest: a piece cut off (the strip in front of the cinema, the
# south-west wing behind JB Hi-Fi) gets a 3.6 m passage carved straight across to the main mall, through a shop if
# one's in the way
def mall_pieces():
    ce = ndi.binary_erosion(L == 1, iterations=2)
    lab, k = ndi.label(ce)
    sizes = ndi.sum(ce, lab, range(1, k + 1))
    return lab, sizes
from skimage.graph import MCP_Geometric
def carve_to_main(target, main_c, what):
    """a 3.6 m passage from the main mall to `target` (a mask), by the cheapest way that stays inside the building:
    along mall floor for nothing, through shops if it must, through an anchor only as a last resort"""
    cost = np.full((H, W), np.inf)
    cost[bld] = 1.0
    cost[L == 1] = 0.05
    for uid, u in units.items():
        if u["kind"] != "unit":
            # through an anchor only along its edge (a strip off the side, not a cut through the middle)
            am = L == uid
            cost[am] = np.where(ndi.distance_transform_edt(am)[am] <= 13, 2.0, 40.0)
    cost[target] = 0.05
    starts = np.argwhere(main_c)[::7]
    mcp = MCP_Geometric(cost)
    cum, _ = mcp.find_costs(starts.tolist())
    ring = target if what == "mall" else (cv2.dilate(target.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool) & ~target & bld)
    yy, xx = np.where(ring)
    if len(yy) == 0: return False
    j = int(np.argmin(cum[yy, xx]))
    if not np.isfinite(cum[yy[j], xx[j]]): return False
    path = np.array(mcp.traceback((int(yy[j]), int(xx[j]))))
    carve = np.zeros((H, W), np.uint8)
    cv2.polylines(carve, [path[:, ::-1].reshape(-1, 1, 2).astype(np.int32)], False, 1, 12)
    cut = (carve > 0) & bld & (L != 1)
    if what != "mall": cut &= ~target
    L[cut] = 1
    print("carved a passage to a cut-off", what, "at px", (int(xx[j]), int(yy[j])), "through", int(cut.sum() * 0.09), "m2 of shops")
    return True
for _round in range(12):
    lab, sizes = mall_pieces()
    order = np.argsort(sizes)[::-1]
    main_c = lab == (int(order[0]) + 1)
    todo = [int(i) + 1 for i in order[1:] if sizes[i] >= 250]
    if not todo: break
    if not carve_to_main(lab == todo[0], main_c, "mall"): break
# the anchors too: each needs a front on the main mall
for uid, u in list(units.items()):
    if u["kind"] == "unit": continue
    lab, sizes = mall_pieces()
    main_c = lab == (int(np.argmax(sizes)) + 1)
    m = L == uid
    if (ndi.binary_dilation(main_c, iterations=6) & m).any(): continue
    carve_to_main(m, main_c, u["name"])
# a shop the carving cut in two keeps its bigger part; the offcut becomes mall floor
for uid in list(units):
    m = L == uid
    lab2, k2 = ndi.label(m)
    if k2 > 1:
        sz = ndi.sum(m, lab2, range(1, k2 + 1))
        keep = int(np.argmax(sz)) + 1
        L[m & (lab2 != keep)] = 1
lab, sizes = mall_pieces()
main_c = ndi.binary_dilation(lab == (int(np.argmax(sizes)) + 1), iterations=6)
# units with no front on the mall are back rooms: join each to the neighbouring shop it shares the longest wall with
def touching(mask):
    ring = cv2.dilate(mask.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool) & ~mask
    ids, cnt = np.unique(L[ring], return_counts=True)
    return dict(zip(ids.tolist(), cnt.tolist()))
for uid in sorted(units):
    m = L == uid
    if not m.any(): units.pop(uid); continue
    if units[uid]["kind"] != "unit": continue
    if int((main_c & m).sum()) >= 6: continue
    t = touching(m)
    cands = {i: c for i, c in t.items() if i >= 2 and i != uid and units.get(i, {}).get("kind") == "unit"}
    if cands:
        L[m] = max(cands, key=cands.get); units.pop(uid)
    # else: an island of storerooms, kept shut

widec = cv2.morphologyEx((L == 1).astype(np.uint8), cv2.MORPH_OPEN, np.ones((11, 11), np.uint8)).astype(bool)
# ---- to metres in the lot frame
ys, xs = np.where(bld)
px0, px1, py0, py1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
kx = LOT_D / (px1 - px0); ky = LOT_W / (py1 - py0)
cx, cy = (px0 + px1) / 2, (py0 + py1) / 2
def M(px, py): return [round((py - cy) * ky, 2), round(-(px - cx) * kx, 2)]      # [x south, z west]
print("plan px bbox", px0, px1, py0, py1, "m/px", round(kx, 4), round(ky, 4))

def contour(mask, eps=1.3):
    cs, _ = cv2.findContours(mask.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(cs, key=cv2.contourArea)
    return cv2.approxPolyDP(c, eps, True)[:, 0, :].astype(float)

def classify(poly, own):
    """walls round a polygon: runs of edge with the same thing on the far side: [[x0,z0,x1,z1,other],...]"""
    runs = []
    n = len(poly)
    area2 = sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n))
    sgn = 1.0 if area2 > 0 else -1.0
    for i in range(n):
        a, b2 = poly[i], poly[(i + 1) % n]
        d = b2 - a; ln = math.hypot(*d)
        if ln < 0.5: continue
        t = d / ln; nrm = np.array([t[1], -t[0]]) * sgn          # outward
        steps = max(1, int(round(ln / 4.0)))
        prev = None; start = a
        for sidx in range(steps):
            p0 = a + d * (sidx / steps); p1 = a + d * ((sidx + 1) / steps); mid = (p0 + p1) / 2
            votes = {}
            for off in (3.5, 5.5):
                q = mid + nrm * off; qx, qy = int(round(q[0])), int(round(q[1]))
                o = int(L[qy, qx]) if 0 <= qx < W and 0 <= qy < H else 0
                if o == own: continue
                votes[o] = votes.get(o, 0) + 1
            other = max(votes, key=votes.get) if votes else 0
            if prev is None: prev = other; start = p0
            elif other != prev:
                runs.append((start, p0, prev)); prev = other; start = p0
        runs.append((start, b2, prev))
    return [[*M(*a), *M(*b2), int(o)] for a, b2, o in runs if math.hypot(*(b2 - a)) > 0.6]

def inner_rect(mask):
    """largest axis-aligned rectangle inside a mask (px): x0, y0, x1, y1"""
    ys, xs = np.where(mask); y0, x0 = ys.min(), xs.min()
    m = mask[y0:ys.max() + 1, x0:xs.max() + 1]
    hgt = np.zeros(m.shape[1], int); best = (0, 0, 0, 0, 0)
    for yy in range(m.shape[0]):
        hgt = np.where(m[yy], hgt + 1, 0)
        st = []
        for xx in range(m.shape[1] + 1):
            cur = hgt[xx] if xx < m.shape[1] else 0
            while st and hgt[st[-1]] >= cur:
                hh = hgt[st.pop()]; ww = xx - (st[-1] + 1 if st else 0)
                if hh * ww > best[0]: best = (hh * ww, (st[-1] + 1 if st else 0), yy - hh + 1, xx, yy + 1)
            st.append(xx)
    return best[1] + x0, best[2] + y0, best[3] + x0, best[4] + y0

res = {"units": [], "outline": [M(*p) for p in contour(bld, 1.5)], "entries": [], "glass": [], "scale": [kx, ky]}
for uid in sorted(units):
    m = L == uid
    if m.sum() < 200: continue
    poly = contour(m)
    if len(poly) < 3: continue
    rx0, ry0, rx1, ry1 = inner_rect(cv2.erode(m.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool) if m.sum() > 600 else m)
    a, b2 = M(rx0, ry0), M(rx1, ry1)
    u = dict(units[uid]); u["id"] = uid
    if u["kind"] == "unit" and m.sum() * kx * ky > 1200: u["kind"] = "bigbox"; u["title"] = "HARTLEY'S"
    u["poly"] = [M(*p) for p in poly]
    u["rect"] = [min(a[0], b2[0]), min(a[1], b2[1]), max(a[0], b2[0]), max(a[1], b2[1])]
    u["walls"] = classify(poly, uid)
    u["area"] = round(float(m.sum()) * kx * ky, 1)
    res["units"].append(u)
# the concourse's own edge to the outside: short runs at the end of a mall are ways in, long runs are glass walls
opoly = contour(bld, 1.5)
n = len(opoly)
runs = []
area2 = sum(opoly[i][0] * opoly[(i + 1) % n][1] - opoly[(i + 1) % n][0] * opoly[i][1] for i in range(n)); sgn = 1.0 if area2 > 0 else -1.0
cur = None
for i in range(n):
    a, b2 = opoly[i], opoly[(i + 1) % n]; d = b2 - a; ln = math.hypot(*d)
    if ln < 0.5: continue
    t = d / ln; nrm = np.array([t[1], -t[0]]) * sgn
    steps = max(1, int(round(ln / 3.0)))
    for sidx in range(steps):
        p0 = a + d * (sidx / steps); p1 = a + d * ((sidx + 1) / steps); mid = (p0 + p1) / 2
        q = mid - nrm * 3.5; qx, qy = int(round(q[0])), int(round(q[1]))
        inside = int(L[qy, qx]) if 0 <= qx < W and 0 <= qy < H else 0
        # a way in needs real mall behind it (a wide stretch of concourse within 4 m), not a sliver of noise
        q2 = mid - nrm * 9.0; ax, ay = int(round(q2[0])), int(round(q2[1]))
        real = True
        for off in (8, 16, 24, 32):
            q3 = mid - nrm * off; bx_, by_ = int(round(q3[0])), int(round(q3[1]))
            if not (0 <= bx_ < W and 0 <= by_ < H and L[by_, bx_] == 1): real = False
        if inside == 1:
            seg = [p0, p1, real]
            if cur is None: cur = [seg]
            else: cur.append(seg)
        elif cur is not None:
            runs.append(cur); cur = None
if cur is not None: runs.append(cur)
for run in runs:
    # split each run where it stops being real mall
    part = []
    def flush(part):
        if not part: return
        ln = sum(math.hypot(*(p1 - p0)) for p0, p1, _ in part) * (kx + ky) / 2
        segs = [[*M(*p0), *M(*p1)] for p0, p1, _ in part]
        real = part[0][2]
        (res["entries"] if (real and 2.5 <= ln <= 30.0) else res["glass"]).append({"len": round(ln, 1), "segs": segs})
    for seg in run:
        if part and seg[2] != part[-1][2]:
            flush(part); part = []
        part.append(seg)
    flush(part)
# the glass roof's frame: beams across the malls every 6 m both ways, each one a run of concourse along a line
res["beams"] = []
cm = (L == 1)
for step_m, axis in ((6.0, 0), (6.0, 1)):
    n = int(round(step_m / (ky if axis == 0 else kx)))
    for line in range(n // 2, (H if axis == 0 else W), n):
        row = cm[line, :] if axis == 0 else cm[:, line]
        d1 = np.diff(np.concatenate([[0], row.astype(np.int8), [0]]))
        for a0, b0 in zip(np.where(d1 == 1)[0], np.where(d1 == -1)[0]):
            if b0 - a0 < 6: continue
            res["beams"].append([*M(a0, line), *M(b0, line)] if axis == 0 else [*M(line, a0), *M(line, b0)])
json.dump(res, open(out, "w"), separators=(",", ":"))
print("units", len(res["units"]), "kinds", {k: sum(1 for u in res["units"] if u["kind"] == k) for k in ("unit", "bigbox", "super", "store", "cinema")},
      "entries", [e["len"] for e in res["entries"]], "glass", [e["len"] for e in res["glass"]], "outline pts", len(res["outline"]))
np.save("/home/claude/tc/L.npy", L)
if len(sys.argv) > 3:
    rng = np.random.default_rng(3)
    cols = rng.integers(90, 230, (L.max() + 1, 3)).astype(np.uint8); cols[0] = (255, 255, 255); cols[1] = (150, 235, 255)
    dbg = cols[L]
    # draw from the json (metres back to px) so the picture checks the data that ships
    def P(x, z): return (int(round(cx - z / kx)), int(round(cy + x / ky)))
    WC = {0: (0, 0, 0), 1: (0, 200, 0)}
    for u in res["units"]:
        for x0, z0, x1, z1, o in u["walls"]:
            cv2.line(dbg, P(x0, z0), P(x1, z1), WC.get(o, (0, 0, 255)), 2 if o in (0, 1) else 1)
        rc = u["rect"]; cv2.rectangle(dbg, P(rc[0], rc[3]), P(rc[2], rc[1]), (255, 255, 255), 1)
    for e in res["entries"]:
        for sg in e["segs"]: cv2.line(dbg, P(sg[0], sg[1]), P(sg[2], sg[3]), (255, 0, 255), 4)
    for e in res["glass"]:
        for sg in e["segs"]: cv2.line(dbg, P(sg[0], sg[1]), P(sg[2], sg[3]), (255, 160, 0), 3)
    cv2.imwrite(sys.argv[3], dbg)
