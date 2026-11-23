"""0.2.73: clean up the open coast (beaches) from a dump of the Terrain3D regions (run tools/dump_terrain.gd first).
The surveyed heights leave sand bars and lumps poking up through the sea sheet (it sits at 0.1 m) and a ragged,
narrow beach; the aerial colours painted half the beach as concrete. This works out, for the open coast only (within
300 m of water that's 300 m from any land, so rivers and the flood plain are left alone):
  - the wet zone: ground under 0.7 m joined to the sea there. It's reshaped as a beach: 0.7 m at the foot of the land
    falling 3.5 % out to sea (dry sand ~17 m wide, then under water), down to -3 m; never raised
  - sand on all of it, on the dunes behind (25 m, under 3.5 m high) and on anything painted concrete within 100 m
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
# the wet zone: under 0.7 m and joined to the ocean, on the coast
lab2, n2 = ndimage.label((Hn < 0.7) & coast)
touch = np.unique(lab2[ocean & coast])
touch = touch[touch > 0]
wet = np.isin(lab2, touch)
print("wet px", wet.sum())
d_wet_land = edt(wet) * 5.0      # metres from the foot of the land
prof = np.clip(0.7 - 0.035 * d_wet_land, -3.0, 0.7)
# only what's above the sea sheet moves in the water (the sea bed's flat at 0 already)
lift = wet & (Hn >= 0.1)
newH = np.where(lift, np.minimum(Hn, prof), Hn)
# the beach itself: from the water's edge up at 4.5 % (about 40 m of sand before it's 2 m up), taking the low ground
# behind the waterline down to it; fading out between 25 and 45 m so the dunes and the land behind keep their shape
water = coast & (newH < 0.1)
d_water = edt(~water) * 5.0
beach_h = 0.1 + 0.045 * d_water
wgt = np.clip((45.0 - d_water) / 20.0, 0.0, 1.0)
land_band = coast & ~water & (d_water < 45.0) & (Hn < 3.5)
lowered = Hn - np.maximum(Hn - beach_h, 0.0) * wgt
newH = np.where(land_band, np.minimum(newH, lowered), newH)
# a little smoothing on the reshaped ground (the land edge is 5 m stair steps)
moved = lift | land_band
sm = ndimage.uniform_filter(newH, 3)
newH = np.where(moved, np.minimum(newH, sm), newH)
# sand: the beach band, the shallows, the dunes behind, and concrete near the beach
d_from_wet = edt(~wet) * 5.0
base = (C >> 27) & 0x1F
sand = (wet & (d_wet_land < 60)) | (coast & ~water & (d_water < 45.0) & (newH < 3.5)) | (~wet & (d_from_wet < 100) & (base == 6) & coast)
newC = C.copy()
keep = np.uint32(~((0x1F << 27) | (0x1F << 22) | (0xFF << 14)) & 0xFFFFFFFF)
newC = np.where(sand, (C & keep) | np.uint32(4 << 27) | np.uint32(4 << 22), C)
changed_h = valid & (np.abs(newH - Hn) > 0.005)
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
    img[changed_h[sub] & (nh < 0.1) & (Hn[sub] >= 0.1)] = (220, 40, 40)      # lumps sunk
    Image.fromarray(img).save(sys.argv[3])
    print("preview", sys.argv[3], img.shape, "origin px", x0 + CX0, y0, "grid origin region", xs[0], zs[0])
