"""Clean up the open coast (beaches) from a dump of the Terrain3D regions (run tools/dump_terrain.gd first), for the
open coast only (within 550 m of water that's 300 m from any land, so rivers and the flood plain are left alone).
0.2.77: one smooth shoreline (the survey's sea and the aerial photo's, blurred), the bed shelving out from it, an even
beach in from it (wet sand, dry sand, dunes), hollows near the beach filled, and sea_dist.png for the sea shader.
Writes assets/world/coast_fix.bin: per region [rx, rz, n] then n x (index int32, height float32, control uint32).
usage: python3 tools/coast_fix.py /tmp/td assets/world/coast_fix.bin [preview.png]"""
import sys, struct, glob, os
import numpy as np
from scipy import ndimage

src, out = sys.argv[1], sys.argv[2]
R = 1024
regs = {}
for f in glob.glob(os.path.join(src, "*_h.bin")):
    rx, rz = map(int, os.path.basename(f).split("_")[:2])
    regs[(rx, rz)] = f
xs = sorted({k[0] for k in regs}); zs = sorted({k[1] for k in regs})
W = (xs[-1] - xs[0] + 1) * R; Hh = (zs[-1] - zs[0] + 1) * R
H = np.full((Hh, W), np.nan, np.float32)
C = np.zeros((Hh, W), np.uint32)
for (rx, rz), f in regs.items():
    h = np.fromfile(f, np.float32).reshape(R, R)
    c = np.fromfile(f.replace("_h.bin", "_c.bin"), np.uint32).reshape(R, R)
    oy = (rz - zs[0]) * R; ox = (rx - xs[0]) * R
    H[oy:oy + R, ox:ox + R] = h
    C[oy:oy + R, ox:ox + R] = c
print("grid", H.shape, "min", np.nanmin(H), "max", np.nanmax(H))
# the coast is all on the east side: work on that part only (from region x 1) to keep the memory down
CX0 = (1 - xs[0]) * R                      # from region x = 1 (world x 5120 m)
H = H[:, CX0:].copy(); C = C[:, CX0:].copy()
W = H.shape[1]
valid = ~np.isnan(H)
Hn = np.where(valid, H, np.float32(99.0)).astype(np.float32)
del H
edt = lambda m: ndimage.distance_transform_edt(m).astype(np.float32)
# the ocean: water under 0.15 m joined to the east edge of the map (the Pacific); the rest of the map's edges are
# padding round the survey and inland
lab, n = ndimage.label(Hn < 0.15)
east = np.unique(lab[:, -1]); east = east[east > 0]
ocean = np.isin(lab, east)
wx = (np.arange(W) + CX0 + xs[0] * R) * 5.0                # world x of each column
east_side = np.broadcast_to(wx > 9000.0, Hn.shape)
print("ocean px", ocean.sum())
# open ocean: 300 m (60 px) from anything that isn't ocean
d_land = edt(ocean)
open_sea = d_land > 60
d_open = edt(~open_sea); del d_land
coast = (d_open < 110) & east_side         # within 550 m of open ocean (open: 300 m from any land)
# 0.2.74: checked against the NSW aerial photos (docs/ref/sat/coast_z16_rgb.png, tools/coast_check.py): along
# Bogangar, Cabarita and down to Hastings Point the survey has ground standing 150-400 m out where the photos show
# surf. Where the photo shows sea or breaking surf (joined to the open ocean), that's sea.
SATP = os.path.join(os.path.dirname(__file__), "..", "docs", "ref", "sat", "coast_z16_rgb.png")
psea_g = np.zeros(Hn.shape, bool)
if os.path.exists(SATP):
    from PIL import Image
    Image.MAX_IMAGE_PIXELS = None
    sat = np.asarray(Image.open(SATP).convert("RGB")).astype(np.int16)
    r_, g_, b_ = sat[..., 0], sat[..., 1], sat[..., 2]
    lum_ = (r_ + g_ + b_) / 3
    pw = ((np.maximum(g_, b_) - r_ > 6) & (r_ < 170)) | ((r_ < 75) & (lum_ < 85) & (b_ >= r_ - 2)) | ((np.minimum(np.minimum(r_, g_), b_) > 185) & (r_ - b_ < 7))
    pw = ndimage.binary_opening(pw, iterations=1)
    labp, _ = ndimage.label(pw)
    ep = np.unique(labp[:, -1]); ep = ep[ep > 0]
    psea = ndimage.binary_erosion(np.isin(labp, ep), iterations=2)
    del sat, r_, g_, b_, lum_, pw, labp
    c_off = int(15000 / 5) - (CX0 + xs[0] * R)          # the photo's first column in this grid (it's 5 m a pixel too)
    nr = min(psea.shape[0], Hn.shape[0])
    psea_g[:nr, c_off:c_off + psea.shape[1]] = psea[:nr]
    psea_g[:int((-16960.0 - zs[0] * R * 5.0) / 5.0), :] = False     # not the north strip (its own data)
    psea_g &= coast & valid & (Hn < 3.0)
    del psea
H0 = Hn.copy()
# 0.2.77: the open-coast beach, rebuilt from one smooth shoreline. 0.2.73-74 reshaped whatever the survey and the
# photo said point by point: the waterline came out ragged (5 m stair steps, the photo's surf and wet sand speckle),
# low ground behind it held the sea in pools across the beach, and the mud and paddock textures under them showed in
# patches. Now:
#   - the sea on the coast = the survey's ocean and the photo's sea, blurred (~12 m) and cut at half: a smooth line.
#     Sand bars and lumps out in it (under 2.5 ha) go under
#   - out from that line the bed shelves at 3 % to -3 m (only ever lowered)
#   - in from it a beach at an even 4 %: wet sand for the first 9 m, dry sand to 40 m (1.7 m up), then it blends into
#     the dunes and the land behind over 35 m with dune grass coming through. Rocky headlands (over 3.5 m) are kept
#   - hollows near the beach that would hold the sea sheet (under 0.35 m, all within 600 m, under 1 km2) are filled:
#     the survey's triangles of low ground behind Cabarita and the like (the creeks and lakes run further in)
# (the photo's line is blurred more: its surf and wet sand leave 20-50 m scallops; it's only wanted where it's out by
# a long way from the survey's)
seaf = (ndimage.gaussian_filter(ocean.astype(np.float32), 2.5) > 0.5) | (ndimage.gaussian_filter(psea_g.astype(np.float32), 8.0) > 0.5)
sea1 = np.where(coast, seaf, ocean); del seaf
labs, _ = ndimage.label(sea1)
es = np.unique(labs[:, -1]); es = es[es > 0]
sea1 = np.isin(labs, es); del labs
labl, nl = ndimage.label(~sea1)
szl = ndimage.sum(np.ones_like(sea1, np.uint8), labl, np.arange(1, nl + 1))
small = np.zeros(nl + 1, bool); small[1:] = szl < 1000
isl = small[labl] & coast
sea1 |= isl
print("islands put under", int(isl.sum()), "px"); del labl, small, isl
d_off = edt(sea1) * 5.0              # sea: metres out from the land
# the bed: an even shelf for the first 200 m (pits and bars both evened out: they showed through the clear water as
# dark and pale blotches), then anything left standing above the sea floor put under
prof = np.maximum(-3.0, 0.02 - 0.03 * d_off)
newH = np.where(sea1 & coast & (d_off < 200.0), prof, Hn)
newH = np.where(sea1 & coast & (d_off >= 200.0) & (Hn > 0.02), -1.0, newH).astype(np.float32)
# the land, measured from the open coast's water only (creeks and the river further in keep their banks)
open2 = d_off > 300.0                 # (measured again now the bars and lumps out there have gone under)
sea_open = sea1 & (edt(~open2) < 80); del open2
s = edt(~sea_open) * 5.0             # land: metres in from the open coast's water
WB, BL = 40.0, 35.0
land = coast & ~sea1 & valid
base = (C >> 27) & 0x1F
rock = (base == 5) | (Hn >= 3.5)
# a headland: rock or high ground right at the water; its beach band is left alone
headland = ndimage.binary_dilation(land & rock & (s < 15.0), iterations=4)
band = land & (s < WB + BL) & ~headland
tgt = 0.12 + 0.04 * s
w = np.clip((s - WB) / BL, 0.0, 1.0)
newH = np.where(band, tgt * (1.0 - w) + Hn * w, newH).astype(np.float32)
# hollows behind the beach that would show the sea sheet through
low = land & (newH < 0.35)
labh, nh = ndimage.label(low)
if nh:
    idx = np.arange(1, nh + 1)
    far = ndimage.maximum(s, labh, idx)
    szh = ndimage.sum(low, labh, idx)
    fill = np.zeros(nh + 1, bool); fill[1:] = (far < 600.0) & (szh < 40000)      # (creeks and lakes run further in)
    pool = fill[labh]
    newH = np.where(pool, 0.35 + 0.004 * np.minimum(s, 50.0), newH).astype(np.float32)
    print("hollows filled", int(pool.sum()), "px")
else:
    pool = np.zeros_like(low)
del labh, low
moved = (band | pool) & (np.abs(newH - Hn) > 0.005)
sm = ndimage.uniform_filter(newH, 3)
newH = np.where(moved & (band | pool), sm, newH).astype(np.float32)
# the ground textures: the sands in bands from the water's edge, dune grass behind, and on the shallow bed you see
# through the water; cane and mud left lying near the coast become sandy grass
newC = C.copy()
keep = np.uint32(~((0x1F << 27) | (0x1F << 22) | (0xFF << 14)) & 0xFFFFFFFF)
def ctl(base_id, over_id, blend):
    return (C & keep) | (np.uint32(base_id) << np.uint32(27)) | (np.uint32(over_id) << np.uint32(22)) | (np.clip(np.asarray(blend) * 255, 0, 255).astype(np.uint32) << np.uint32(14))
bedw = sea1 & coast & (d_off < 120.0)
newC = np.where(bedw, ctl(9, 9, 0.0), newC)
wet_s = band & (s < 9.0)
dry_s = band & (s >= 9.0) & (s < WB)
dune = band & (s >= WB) | (land & ~headland & (s >= WB + BL) & (s < WB + BL + 25) & np.isin(base, [2, 3, 7, 10]))
dune_k = np.clip((s - WB) / 45.0, 0.0, 1.0) * 0.75 + 0.15
newC = np.where(dune & ~rock, ctl(4, 8, dune_k), newC)
newC = np.where(dry_s, ctl(4, 4, 0.0), newC)
newC = np.where(wet_s, ctl(4, 9, np.clip(0.75 - s / 18.0, 0.25, 0.75)), newC)     # (the wet sand texture alone read as mud)
newC = np.where(pool & ~band, ctl(4, 8, 0.6), newC)
coast_mud = land & ~band & ~pool & (np.isin(base, [2, 7, 10]) & (s < 250.0) | (base == 6) & (s < 150.0))   # (concrete: the photo's pale dune scrub)
newC = np.where(coast_mud, ctl(4, 8, 0.75), newC)
sand = band | bedw
print("beach band", int(band.sum()), "wet", int(wet_s.sum()), "dry", int(dry_s.sum()), "dune", int(dune.sum()), "headland", int(headland.sum()))
# 0.2.74: how far out to sea every point is (for the water's colour: see-through turquoise in the shallows going to
# deep blue, and the swell lines running in to the beach). assets/world/sea_dist.png: 10 m a pixel from world
# (SEA_X0, grid z0); value = sqrt(metres from land / 4000), 0 on land.
from PIL import Image
lab3, n3 = ndimage.label(newH < 0.1)
e3 = np.unique(lab3[:, -1]); e3 = e3[e3 > 0]
sea_w = np.isin(lab3, e3); del lab3
# anything still standing out in the sea (small, off the coast band): count it, put it under
labi, ni = ndimage.label(~sea_w)
if ni:
    szi = ndimage.sum(np.ones_like(sea_w, np.uint8), labi, np.arange(1, ni + 1))
    smi = np.zeros(ni + 1, bool); smi[1:] = szi < 1000
    isl2 = smi[labi] & east_side & valid & coast
    isl2 &= edt(~(~sea_w & ~smi[labi])) * 5.0 > 150.0          # out at sea, not islands in the creeks and the river
    print("specks left in the sea", int(isl2.sum()), "px in", int(np.unique(labi[isl2]).size), "bits")
    if isl2.any():
        ys_, xs2_ = np.nonzero(isl2)
        print("  e.g. world x", (xs2_[:5] + CX0 + xs[0] * R) * 5.0, "z", (ys_[:5] + zs[0] * R) * 5.0)
    newH = np.where(isl2, np.minimum(newH, -1.0), newH).astype(np.float32)
    sea_w |= isl2
    del labi
d_sea = edt(sea_w) * 5.0
SEA_X0 = 12000.0
c0 = int((SEA_X0 / 5.0) - (CX0 + xs[0] * R))
ds = d_sea[::2, c0::2]
# 0.2.77: 16 bits (red = high byte, green = low byte; the shader filters it itself). 8 bits made the distance step
# 7-15 m at a time a few hundred metres out: the swell lines jumped at every step (the "wrinkles")
v16 = np.round(np.sqrt(np.clip(ds, 0, 4000) / 4000.0) * 65535.0).astype(np.uint32)
enc = np.zeros(ds.shape + (3,), np.uint8)
enc[..., 0] = (v16 >> 8).astype(np.uint8); enc[..., 1] = (v16 & 255).astype(np.uint8)
Image.fromarray(enc, "RGB").save(os.path.join(os.path.dirname(__file__), "..", "assets", "world", "sea_dist.png"))
print("sea_dist", enc.shape, "x0", SEA_X0, "z0", zs[0] * R * 5.0, "mpx 10")
del d_sea, sea_w
if os.environ.get("CF_DEBUG"):
    # a crop for looking at: CF_DEBUG=x0,z0,x1,z1 (world metres) -> /tmp/cf_debug.npz
    x0_, z0_, x1_, z1_ = map(float, os.environ["CF_DEBUG"].split(","))
    gx = lambda x: int(x / 5.0) - (CX0 + xs[0] * R); gz = lambda z: int(z / 5.0) - zs[0] * R
    sl = slice(gz(z0_), gz(z1_)), slice(gx(x0_), gx(x1_))
    np.savez_compressed("/tmp/cf_debug.npz", raw=(H0 if "H0" in globals() else Hn)[sl], new=newH[sl], c=newC[sl], c0=C[sl],
        psea=psea_g[sl], band=band[sl], s=s[sl], headland=headland[sl], pool=pool[sl], wet=sea1[sl], coast=coast[sl], origin=np.array([x0_, z0_]))
    print("debug crop saved")
changed_h = valid & (np.abs(newH - H0) > 0.005)
changed_c = valid & (newC != C)
ch = changed_h | changed_c
print("changed heights", changed_h.sum(), "controls", changed_c.sum())
with open(out, "wb") as f:
    f.write(b"CFX1")
    for (rx, rz) in sorted(regs):
        oy = (rz - zs[0]) * R; ox = (rx - xs[0]) * R - CX0
        if ox + R <= 0: continue
        if ox < 0: raise SystemExit("region straddles the crop: move CX0")
        m = ch[oy:oy + R, ox:ox + R]
        idx = np.flatnonzero(m).astype(np.int32)
        if idx.size == 0: continue
        hh = newH[oy:oy + R, ox:ox + R].ravel()[idx].astype(np.float32)
        cc = newC[oy:oy + R, ox:ox + R].ravel()[idx].astype(np.uint32)
        f.write(struct.pack("<iii", rx, rz, idx.size))
        f.write(idx.tobytes()); f.write(hh.tobytes()); f.write(cc.tobytes())
        print("region", rx, rz, idx.size)
print("wrote", out, os.path.getsize(out))
if len(sys.argv) > 3:
    from PIL import Image
    ys, xs_ = np.nonzero(ch)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs_.min(), xs_.max()
    sub = slice(y0, y1 + 1), slice(x0, x1 + 1)
    img = np.zeros((y1 - y0 + 1, x1 - x0 + 1, 3), np.uint8)
    nh = newH[sub]
    img[...] = (40, 110, 40)
    img[nh < 0.7] = (220, 200, 120)
    img[nh < 0.1] = (30, 60, 160)
    img[sand[sub] & (nh >= 0.1)] = (240, 220, 150)
    img[changed_h[sub] & (nh < 0.1) & ((H0 if "H0" in globals() else Hn)[sub] >= 0.1)] = (220, 40, 40)      # lumps sunk
    Image.fromarray(img).save(sys.argv[3])
    print("preview", sys.argv[3], img.shape, "origin px", x0 + CX0, y0, "grid origin region", xs[0], zs[0])
