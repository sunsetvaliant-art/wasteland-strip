#!/usr/bin/env python3
"""Tweed City from the user's annotated directory plan (docs/ref/2026/tweed_city_annotated.jpg), v2.
The user drew a colour key on the plan:
  red    = interior walls, shop fronts included        green  = way in/out between inside and outside
  yellow = toilet doors                                 orange = travelators down to the underground car park
  purple = outside but covered (shops open onto it)     pink   = the cinema, one level up (lobby and cinemas)
  grey   = stairs inside the mall up to the cinema lobby
Teal = shops, blue = anchors, light grey = mall floor. Everything is written in metres in the TWIN CITY lot's frame
(x = south, z = west), fitted to the lot's 378.3 x 244.7 m: assets/world/twin_city.json, read by PolyMall (v2).
usage: trace_mall2.py <annotated.jpg> <out.json> [debug.png]"""
import sys, json, math
import numpy as np, cv2
from scipy import ndimage as ndi
import mapbox_earcut as earcut

LOT_W, LOT_D = 378.3, 244.7
src, out = sys.argv[1], sys.argv[2]
im = cv2.imread(src)
rgb = im[..., ::-1].astype(int); r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
v = rgb.mean(2); sat = rgb.max(2) - rgb.min(2)
H, W = v.shape
red = (r > 170) & (g < 90) & (b < 90)
purple = (np.abs(r - b) < 30) & (r > 120) & (r - g > 50)
green = (g > 140) & (r < 110) & (b < 130) & (g - r > 50)
yellow = (r > 210) & (g > 170) & (b < 90)
orange = (r > 220) & (g > 110) & (g < 190) & (b < 80)
pink = (r > 235) & (g > 150) & (g < 205) & (b > 180) & (b < 230)
greyl = (sat < 10) & (v > 110) & (v < 145)
teal = (r < 90) & (g > 120) & (b > 130) & (np.abs(g - b) < 30)
blue = (r < 60) & (b > 140) & (g < 130) & (g > 70)
white = (sat < 10) & (v > 244)
KEYX = 290                                   # the key's writing is down the left below y 900: not the mall
notmall = np.zeros((H, W), bool); notmall[:, :100] = True; notmall[900:, :KEYX] = True
for m in (red, purple, green, yellow, orange, teal, blue, greyl, pink): m[notmall] = False

def comps(mask, min_px=1):
    lab, k = ndi.label(mask)
    out_ = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        mm = lab[sl] == i + 1
        if mm.sum() >= min_px: out_.append((sl, mm))
    return out_

def full(sl, mm):
    z = np.zeros((H, W), bool); z[sl] = mm; return z

# ------------------------------------------------------------- units
L = np.zeros((H, W), np.int32)       # 0 outside, 1 inside, 2 covered, 4 ramp hall, 5 stair hall, >= 10 units
units = {}
nid = [10]
def add(mask, kind, name, title=""):
    i = nid[0]; nid[0] += 1
    L[mask & (L == 0)] = i
    units[i] = {"kind": kind, "name": name, "title": title}
    return i

# anchors: the big blue blocks, split along the thin white lines between them (Best&Less / Harris Scarfe)
# logos and lettering cut holes in them: close those up first (not across the white seams between anchors)
bclosed = cv2.morphologyEx(blue.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((25, 25), np.uint8)).astype(bool)
bclosed = ndi.binary_fill_holes(bclosed) & ~cv2.dilate((teal | red).astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
bcore = cv2.erode(bclosed.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
anchors = []
for sl, mm in comps(bcore, 2500):
    m = ndi.binary_fill_holes(full(sl, mm))
    m = cv2.dilate(m.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool) & bclosed
    m = ndi.binary_fill_holes(m)
    cy, cx = ndi.center_of_mass(m)
    anchors.append((cy, cx, m, int(m.sum())))
NAMES = []
for cy, cx, m, n in anchors:
    if cy < 300 and cx < 520: nm, kind, title = "kmart", "bigbox", "HOLLIS & CRANE"
    elif cy < 300: nm, kind, title = "coles", "super", "FRESHWAY"
    elif cy < 440 and cx > 620: nm, kind, title = "bestless", "store", "BETTER FOR LESS"
    elif cy < 640 and cx > 620: nm, kind, title = "harris", "store", "HARRIS & SONS"
    elif cy < 740 and cx < 450: nm, kind, title = "jbhifi", "store", "VOLT ELECTRICAL"
    elif cy < 950 and cx < 450: nm, kind, title = "hoyts", "cinema", "REGENT CINEMAS"
    elif cy < 1080: nm, kind, title = "woolworths", "super", "GREENGATE"
    else: nm, kind, title = "bigw", "bigbox", "BIG VALUE"
    if nm in NAMES:
        i = [k for k, u in units.items() if u["name"] == nm][0]
        L[m & (L == 0)] = i
        continue
    add(m, kind, nm, title); NAMES.append(nm)
print("anchors", NAMES)

# toilets: white rooms in red walls with a yellow door
barrier_t = cv2.dilate(red.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
tw = (white | ((blue | (sat < 40)) & ~teal)) & ~barrier_t & (L == 0)
tlab, tk = ndi.label(tw)
ycomps = comps(yellow, 3)
tid = 0
for sl, mm in ycomps:
    yy, xx = np.where(full(sl, mm))
    cy, cx = int(yy.mean()), int(xx.mean())
    best = None
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            q = tlab[min(max(cy + dy, 0), H - 1), min(max(cx + dx, 0), W - 1)]
            if q:
                n = int((tlab == q).sum())
                if 150 < n < 7000 and (best is None or n < best[1]): best = (q, n)
    if best:
        m = ndi.binary_fill_holes(tlab == best[0])
        if not (L[m] >= 10).any():
            tid += 1; add(m, "toilet", "toilet%d" % tid, "TOILETS")
print("toilets", tid)

# shops: teal, split along the thin lines between them
s = teal & (L == 0)
s = cv2.morphologyEx(s.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)).astype(bool)
core = cv2.erode(s.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
kiosk = np.zeros((H, W), bool)
for sl, mm in comps(core):
    m = full(sl, mm)
    if mm.sum() < 200: kiosk |= m; continue
    add(ndi.binary_fill_holes(m), "unit", "shop")
d0, i0 = ndi.distance_transform_edt(L < 10, return_indices=True)
back = s & (L == 0) & (d0 <= 3)
L[back] = L[i0[0], i0[1]][back]
# a unit big enough to be a store of its own
for uid, u in units.items():
    if u["kind"] == "unit" and (L == uid).sum() > 14000: u["kind"] = "bigbox"; u["title"] = "HARTLEY'S"

# ------------------------------------------------------------- cinema, stairs
pk = max(comps(pink, 50), key=lambda c: (c[0][0].stop - c[0][0].start) * (c[0][1].stop - c[0][1].start))
PY0, PY1, PX0, PX1 = pk[0][0].start, pk[0][0].stop, pk[0][1].start, pk[0][1].stop
gy = [c for c in comps(greyl, 30) if c[0][0].start > 700 and c[0][0].stop < 800 and c[0][1].start > 300 and c[0][1].stop < 430]
gy = max(gy, key=lambda c: c[1].sum())
SY0, SY1, SX0, SX1 = gy[0][0].start, gy[0][0].stop, gy[0][1].start, gy[0][1].stop
print("cinema px", (PX0, PY0, PX1, PY1), "stairs px", (SX0, SY0, SX1, SY1))
cine = np.zeros((H, W), bool); cine[PY0:PY1, PX0:PX1] = True
stair = np.zeros((H, W), bool); stair[SY0:SY1 + 2, SX0:SX1] = True
L[stair & (L < 10)] = 5
L[cine & (L < 10)] = 4

# ------------------------------------------------------------- inside and covered
walls = (red | green).astype(bool)
bigteal = np.zeros((H, W), bool)
for sl, mm in comps(teal, 250): bigteal |= full(sl, mm)          # kiosks in the mall aren't walls
base = (red | green | greyl | pink | bigteal | blue).astype(np.uint8)
bar = cv2.morphologyEx(base, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)).astype(bool)
free = ~bar & (L == 0) & ~cine & ~stair
flab, _ = ndi.label(free)
seed = flab[520, 480]                          # open floor in the food court
inside = flab == seed
assert not (inside[0].any() or inside[-1].any() or inside[:, 0].any() or inside[:, -1].any()), "the mall leaks"
small = cv2.morphologyEx(inside.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)).astype(bool)
filled = ndi.binary_fill_holes(small)
# ATMs, signs, kiosks and lettering in the mall are floor (holes in it smaller than a shop)
hl, hk = ndi.label(filled & ~small)
for sl, mm in comps(filled & ~small):
    if mm.sum() > 600: filled[sl][mm] = False
inside = filled & (L == 0)
print("inside px", int(inside.sum()))
L[inside] = 1
# outside: flood from the edge of the picture, held back by the purple line, the buildings and the inside
pb = cv2.dilate(purple.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
obar = cv2.morphologyEx((base | pb).astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)).astype(bool) | (L == 1)
ofree = ~obar & (L == 0)
olab, _ = ndi.label(ofree)
edge_ids = set(np.unique(np.concatenate([olab[0], olab[-1], olab[:, 0], olab[:, -1]]))) - {0}
outside = np.isin(olab, list(edge_ids)) | (~obar & (L == 0) & notmall)
cov = (L == 0) & ~outside & ~notmall
# only what's actually tucked in behind a purple line counts
near_p = ndi.distance_transform_edt(~purple) < 120
cov &= near_p
cl, ck = ndi.label(cov)
keep = np.zeros((H, W), bool)
for sl, mm in comps(cov, 400):
    m = full(sl, mm)
    if (cv2.dilate(m.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool) & purple).any(): keep |= m
L[keep] = 2
print("covered px", int(keep.sum()))
# the drawn lines themselves: shared out to whatever's either side of them
lines = (L == 0) & (walls | pb | yellow | orange | kiosk) & ~outside
d1, i1 = ndi.distance_transform_edt(L == 0, return_indices=True)
grow = lines & (d1 <= 6)
L[grow] = L[i1[0], i1[1]][grow]
# shops facing nothing are back rooms of a neighbour
def touching(mask):
    ring = cv2.dilate(mask.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool) & ~mask
    ids, cnt = np.unique(L[ring], return_counts=True)
    return dict(zip(ids.tolist(), cnt.tolist()))
for uid in sorted(units):
    m = L == uid
    if not m.any(): units.pop(uid); continue
    if units[uid]["kind"] != "unit": continue
    t = touching(m)
    if t.get(1, 0) + t.get(2, 0) >= 8: continue
    c = {i: n for i, n in t.items() if i >= 10 and units.get(i, {}).get("kind") == "unit"}
    if c: L[m] = max(c, key=c.get); units.pop(uid)

# white gaps left inside the building (between a shop and the line drawn in front of it): to whatever's nearest
bld0 = ndi.binary_fill_holes(cv2.morphologyEx((L > 0).astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8)).astype(bool))
gap = bld0 & (L == 0) & ~outside
d2, i2 = ndi.distance_transform_edt(L == 0, return_indices=True)
L[gap] = L[i2[0], i2[1]][gap]
print("gaps filled px", int(gap.sum()))
bld = (L > 0)
bld = ndi.binary_fill_holes(cv2.morphologyEx(bld.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8)).astype(bool))
ys, xs = np.where(bld)
px0, px1, py0, py1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
kx = LOT_D / (px1 - px0); ky = LOT_W / (py1 - py0)
cx, cy = (px0 + px1) / 2, (py0 + py1) / 2
def M(px, py): return [round((py - cy) * ky, 2), round(-(px - cx) * kx, 2)]
print("bbox px", (px0, px1, py0, py1), "m/px", round(kx, 4), round(ky, 4))

def contours(mask, eps=1.2, holes=False):
    mode = cv2.RETR_CCOMP if holes else cv2.RETR_EXTERNAL
    cs, hier = cv2.findContours(mask.astype(np.uint8), mode, cv2.CHAIN_APPROX_NONE)
    res = []
    for i, c in enumerate(cs):
        if cv2.contourArea(c) < 20: continue
        p = cv2.approxPolyDP(c, eps, True)[:, 0, :].astype(float)
        if len(p) < 3: continue
        res.append((p, hier[0][i][3] if holes else -1, i))
    return res

def tris(mask, eps=1.2):
    """earcut triangles over a mask with holes, in metres: flat [x0,z0,x1,z1,x2,z2, ...]"""
    cs, hier = cv2.findContours(mask.astype(np.uint8), cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
    out_ = []
    if hier is None: return out_
    for i, c in enumerate(cs):
        if hier[0][i][3] != -1 or cv2.contourArea(c) < 20: continue
        rings = [cv2.approxPolyDP(c, eps, True)[:, 0, :].astype(float)]
        j = hier[0][i][2]
        while j != -1:
            if cv2.contourArea(cs[j]) >= 12:
                hp = cv2.approxPolyDP(cs[j], eps, True)[:, 0, :].astype(float)
                if len(hp) >= 3: rings.append(hp)
            j = hier[0][j][0]
        if len(rings[0]) < 3: continue
        verts = np.vstack([np.array([M(*p) for p in rg]) for rg in rings]).astype(np.float64)
        ends = np.cumsum([len(rg) for rg in rings]).astype(np.uint32)
        idx = earcut.triangulate_float64(verts, ends)
        for k in idx: out_ += [float(verts[k][0]), float(verts[k][1])]
    return out_

def classify(poly, own, step_m=3.0):
    runs = []
    n = len(poly)
    area2 = sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n))
    sgn = 1.0 if area2 > 0 else -1.0
    for i in range(n):
        a, b2 = poly[i], poly[(i + 1) % n]
        d = b2 - a; ln = math.hypot(*d)
        if ln < 0.5: continue
        t = d / ln; nrm = np.array([t[1], -t[0]]) * sgn
        steps = max(1, int(round(ln * kx / step_m)))
        prev = None; start = a
        for k in range(steps):
            p0 = a + d * (k / steps); p1 = a + d * ((k + 1) / steps); mid = (p0 + p1) / 2
            votes = {}
            for off in (2.5, 4.5, 7.0):
                q = mid + nrm * off; qx, qy = int(round(q[0])), int(round(q[1]))
                o = int(L[qy, qx]) if 0 <= qx < W and 0 <= qy < H else 0
                if o == own: continue
                votes[o] = votes.get(o, 0) + 1
                break
            other = max(votes, key=votes.get) if votes else 0
            if prev is None: prev = other; start = p0
            elif other != prev: runs.append((start, p0, prev)); prev = other; start = p0
        runs.append((start, b2, prev))
    return [[*M(*a), *M(*b2), int(o)] for a, b2, o in runs if math.hypot(*(b2 - a)) > 0.5]

def inner_rect(mask):
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

def seg_of(mask):
    """a drawn mark as a line segment along its long axis, in metres: [x0,z0,x1,z1]"""
    yy, xx = np.where(mask)
    (rx, ry), (rw, rh), ang = cv2.minAreaRect(np.stack([xx, yy], 1).astype(np.float32))
    ln = max(rw, rh); a = math.radians(ang if rw >= rh else ang + 90)
    dx, dy = math.cos(a) * ln / 2, math.sin(a) * ln / 2
    return [*M(rx - dx, ry - dy), *M(rx + dx, ry + dy)], (rx, ry, ln, min(rw, rh), a)

res = {"v": 2, "scale": [kx, ky], "units": []}
for uid in sorted(units):
    m = L == uid
    if m.sum() < 150: continue
    ps = contours(m)
    if not ps: continue
    poly = max(ps, key=lambda q: cv2.contourArea(q[0].astype(np.float32)))[0]
    er = cv2.erode(m.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    rx0, ry0, rx1, ry1 = inner_rect(er if er.sum() > 200 else m)
    a, b2 = M(rx0, ry0), M(rx1, ry1)
    u = dict(units[uid]); u["id"] = uid
    u["poly"] = [M(*p) for p in poly]
    u["rect"] = [min(a[0], b2[0]), min(a[1], b2[1]), max(a[0], b2[0]), max(a[1], b2[1])]
    u["walls"] = classify(poly, uid)
    res["units"].append(u)
# the outline (far off), the floor (holes where the travelators and the car ramp go down)
res["outline"] = [M(*p) for p in max(contours(bld, 1.5), key=lambda q: cv2.contourArea(q[0].astype(np.float32)))[0]]
trav = []
holes = np.zeros((H, W), np.uint8)
for sl, mm in comps(orange, 40):
    sg, (rx, ry, ln, wd, a) = seg_of(full(sl, mm))
    # it goes down towards the end further from the mall's middle line... simply: down to the south/east end
    p0, p1 = sg[:2], sg[2:]
    if p0[0] + p0[1] * 0.2 > p1[0] + p1[1] * 0.2: p0, p1 = p1, p0
    w_m = max(wd * kx + 0.6, 3.2)
    trav.append([*p0, *p1, round(w_m, 2)])
    box = cv2.boxPoints(((rx, ry), (ln + 2, max(wd, 3.2 / kx) + 2), math.degrees(a)))
    cv2.fillPoly(holes, [box.astype(np.int32)], 1)
res["travelators"] = trav
# the car ramp: in the cinema's ground floor, beside the cinema block, opening south; 7 m wide, 32 m long
hoy = [i for i, u in units.items() if u["name"] == "hoyts"]
hm = (L == hoy[0]) if hoy else np.zeros((H, W), bool)
ramp_w_px = 7.0 / kx
rx_c = PX0 + 4 + ramp_w_px / 2 + 3
ry_top = PY1 - 6 - 4.5 / ky                      # flat for the first few metres in from the door
ry_bot = ry_top - 32.0 / ky
res["ramp"] = {"top": M(rx_c, ry_top), "bottom": M(rx_c, ry_bot), "door": M(rx_c, PY1 - 1), "w": 7.0}
rampm = np.zeros((H, W), bool)
rampm[int(ry_bot) - 2:PY1, int(rx_c - ramp_w_px / 2) - 2:int(rx_c + ramp_w_px / 2) + 3] = True
floor = ((L >= 1) & (L != 4)) | ((L == 4) & ~rampm)
floor &= ~holes.astype(bool)
res["floor_tris"] = tris(floor)
res["inside_tris"] = tris(ndi.binary_fill_holes(L == 1) & ~stair)
res["covered_tris"] = tris(L == 2)
# where the inside meets anything that isn't a shop: walls, with the green ways in cut through them
ins_walls = []
for p, par, _ in contours(L == 1, 1.2, holes=True):
    ins_walls += [w_ for w_ in classify(p, 1) if w_[4] in (0, 2, 4)]
res["inside_walls"] = ins_walls
res["entries"] = [seg_of(full(sl, mm))[0] for sl, mm in comps(green, 6)]
res["toilet_doors"] = [seg_of(full(sl, mm))[0] for sl, mm in ycomps]
# posts along the outer edge of the covered walkways
posts = []
for p, _, _ in contours(L == 2, 2.0):
    q = np.vstack([p, p[:1]])
    acc = 0.0
    for i in range(len(q) - 1):
        a, b2 = q[i], q[i + 1]; ln = math.hypot(*(b2 - a)) * kx
        while acc <= ln:
            pt = a + (b2 - a) * (acc / max(ln, 1e-6))
            px, py = int(pt[0]), int(pt[1])
            # only on the open side (next to the outside, not against a shop)
            nb = L[max(py - 6, 0):py + 7, max(px - 6, 0):px + 7]
            if (nb == 0).any() and not (nb >= 10).any(): posts.append(M(*pt))
            acc += 6.0
        acc -= ln
res["covered_posts"] = posts
# the cinema upstairs and the stairs up to it
cy0, cz0 = M(PX1, PY0); cy1, cz1 = M(PX0, PY1)
res["cinema"] = {"rect": [cy0, cz0, cy1, cz1], "y": 5.2, "roof": 13.0,
                 # JB Hi-Fi's straight north of the stair box: the stairs climb from the mall on the east side to the
                 # west, along the cinema's north wall, to a landing with the way into the cinema lobby
                 "stairs": {"bottom": M(SX1 - 1, PY0 - 2.5 / ky), "top": M(SX0 + 4.0 / kx, PY0 - 2.5 / ky),
                            "landing": M(SX0 + 1.0, PY0 - 2.5 / ky), "w": 4.0},
                 "box": [*M(SX1, SY0 - 3), *M(SX0, PY0)]}
# the underground car park: under the mall and the cinema, in from the outside walls, with the ramp's foot in it
bm = cv2.erode((bld & ~(L == 2)).astype(np.uint8), np.ones((15, 15), np.uint8)).astype(bool)
bm |= cv2.dilate(holes, np.ones((9, 9), np.uint8)).astype(bool) & bld
lab_b, kb = ndi.label(bm)
sz = ndi.sum(bm, lab_b, range(1, kb + 1)); bm = lab_b == (int(np.argmax(sz)) + 1)
foot = np.zeros((H, W), bool); foot[int(ry_bot) - int(10 / ky):int(ry_bot) + 3, int(rx_c - ramp_w_px / 2):int(rx_c + ramp_w_px / 2) + 1] = True
bm |= foot
bm = ndi.binary_fill_holes(bm)
bfl = bm & ~(rampm & ~foot)
bw = []
for p, _, _ in contours(bm, 1.5):
    n = len(p)
    for i in range(n):
        bw.append([*M(*p[i]), *M(*p[(i + 1) % n])])
cols = []
yy0, yy1 = np.where(bm.any(1))[0][[0, -1]]
for yy in np.arange(yy0 + 10 / ky, yy1, 8.4 / ky):
    for xx in np.arange(px0 + 4, px1, 8.4 / kx):
        X, Y = int(xx), int(yy)
        if bm[max(Y - 8, 0):Y + 9, max(X - 8, 0):X + 9].all() and not cv2.dilate(holes, np.ones((15, 15), np.uint8))[Y, X] and not rampm[Y, X]:
            cols.append(M(xx, yy))
res["basement"] = {"y": -4.0, "tris": tris(bfl), "walls": bw, "cols": cols}
# the glass roof's frame
res["beams"] = []
cm = ndi.binary_fill_holes(L == 1)
for axis in (0, 1):
    n = int(round(6.0 / (ky if axis == 0 else kx)))
    for line in range(n // 2, (H if axis == 0 else W), n):
        row = cm[line, :] if axis == 0 else cm[:, line]
        dd = np.diff(np.concatenate([[0], row.astype(np.int8), [0]]))
        for a0, b0 in zip(np.where(dd == 1)[0], np.where(dd == -1)[0]):
            if b0 - a0 < 6: continue
            res["beams"].append([*M(a0, line), *M(b0, line)] if axis == 0 else [*M(line, a0), *M(line, b0)])
json.dump(res, open(out, "w"), separators=(",", ":"))
kinds = {}
for u in res["units"]: kinds[u["kind"]] = kinds.get(u["kind"], 0) + 1
print("units", len(res["units"]), kinds, "| travelators", len(trav), "entries", len(res["entries"]), "toilet doors", len(res["toilet_doors"]),
      "| covered posts", len(posts), "| basement cols", len(cols), "| floor tris", len(res["floor_tris"]) // 6)
if len(sys.argv) > 3:
    rng = np.random.default_rng(5)
    pal = rng.integers(90, 230, (L.max() + 1, 3)).astype(np.uint8)
    pal[0] = (255, 255, 255); pal[1] = (150, 235, 255); pal[2] = (230, 170, 240); pal[4] = (200, 200, 255); pal[5] = (120, 120, 120)
    dbg = pal[L].copy()
    dbg[bm & (L == 0)] = (180, 255, 180)
    def P(x, z): return (int(round(cx - z / kx)), int(round(cy + x / ky)))
    for u in res["units"]:
        for x0, z0, x1, z1, o in u["walls"]:
            col = {0: (0, 0, 0), 1: (0, 160, 0), 2: (200, 0, 200), 4: (255, 0, 0), 5: (255, 0, 0)}.get(o, (0, 0, 255))
            cv2.line(dbg, P(x0, z0), P(x1, z1), col, 2 if o < 10 else 1)
    for x0, z0, x1, z1, o in ins_walls: cv2.line(dbg, P(x0, z0), P(x1, z1), (0, 90, 255), 2)
    for e in res["entries"]: cv2.line(dbg, P(e[0], e[1]), P(e[2], e[3]), (0, 255, 0), 5)
    for e in res["toilet_doors"]: cv2.line(dbg, P(e[0], e[1]), P(e[2], e[3]), (0, 220, 255), 5)
    for t in trav: cv2.arrowedLine(dbg, P(t[0], t[1]), P(t[2], t[3]), (0, 120, 255), 4)
    rp = res["ramp"]; cv2.arrowedLine(dbg, P(*rp["top"]), P(*rp["bottom"]), (0, 0, 180), 6)
    st = res["cinema"]["stairs"]; cv2.arrowedLine(dbg, P(*st["bottom"]), P(*st["top"]), (40, 40, 40), 5)
    for q in posts: cv2.circle(dbg, P(*q), 3, (120, 0, 120), -1)
    for q in cols: cv2.circle(dbg, P(*q), 2, (0, 100, 0), -1)
    cv2.imwrite(sys.argv[3], dbg[..., ::-1])
