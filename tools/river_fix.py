"""0.2.74: muddy river beds and banks, from a dump of the Terrain3D regions (tools/dump_terrain.gd) and the water in
the vegetation mask (assets/vegmask2.png, blue; 10 m a pixel). Off the open coast (tools/coast_fix.py does the sea):
  under the water   wet mud (10): the bed you see through the still water
  0-5 m from it     bare river mud (7)
  5-15 m            river mud coming through rough grass (7 under 8)
Only natural ground changes (pasture, forest floor, cane, farm soil, rough grass): never roads, concrete, sand, rock.
Writes assets/world/river_fix.bin: "RFX1", then per region [rx, rz, n] and n x (index int32, control uint32).
usage: python3 tools/river_fix.py /tmp/td assets/world/river_fix.bin"""
import sys, struct, glob, os
import numpy as np
from scipy import ndimage
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
R = 1024; P = 8
regs = {}
for f in glob.glob(os.path.join(src, "*_c.bin")):
    rx, rz = map(int, os.path.basename(f).split("_")[:2])
    regs[(rx, rz)] = f
m2 = np.asarray(Image.open(os.path.join(os.path.dirname(__file__), "..", "assets", "vegmask2.png")))[..., 2]
VX0, VZ0, VMPX = -8960.0, -16960.0, 10.0
# the open sea (water 300 m from any land) and 400 m into the water round it (beaches, the river mouths' sand) are
# coast_fix's, not this
_w = m2 > 115
_open = ndimage.distance_transform_edt(_w) > 30
SEA = _w & (ndimage.distance_transform_edt(~_open) < 40)
del _w, _open
keep = np.uint32(~((0x1F << 27) | (0x1F << 22) | (0xFF << 14)) & 0xFFFFFFFF)
def water(rx, rz):
    """the river mask for a region padded by P vertices each side"""
    xs = ((rx * R - P) + np.arange(R + 2 * P)) * 5.0
    zs = ((rz * R - P) + np.arange(R + 2 * P)) * 5.0
    px = ((xs - VX0) / VMPX).astype(np.int64); pz = ((zs - VZ0) / VMPX).astype(np.int64)
    okx = (px >= 0) & (px < m2.shape[1]); okz = (pz >= 0) & (pz < m2.shape[0])
    w = np.zeros((R + 2 * P, R + 2 * P), bool)
    sub = np.ix_(pz[okz], px[okx])
    w[np.ix_(okz, okx)] = (m2[sub] > 115) & ~SEA[sub]
    return w, xs
total = 0
with open(out, "wb") as f:
    f.write(b"RFX1")
    for (rx, rz) in sorted(regs):
        C = np.fromfile(regs[(rx, rz)], np.uint32).reshape(R, R)
        base = (C >> 27) & 0x1F
        w, xs = water(rx, rz)
        if not w.any(): continue
        d = ndimage.distance_transform_edt(~w)[P:-P, P:-P] * 5.0
        riv = w[P:-P, P:-P]
        natural = np.isin(base, [0, 1, 2, 3, 8])
        bed = riv & natural
        bank = natural & ~riv & (d <= 5.0)
        edge = natural & ~riv & (d > 5.0) & (d <= 15.0)
        newC = C.copy()
        newC = np.where(bed, (C & keep) | np.uint32(10 << 27) | np.uint32(10 << 22), newC)
        newC = np.where(bank, (C & keep) | np.uint32(7 << 27) | np.uint32(7 << 22), newC)
        bl = (np.clip((d - 5.0) / 10.0, 0.0, 1.0) * 0.6 + 0.3) * 255
        newC = np.where(edge, (C & keep) | np.uint32(7 << 27) | np.uint32(8 << 22) | (bl.astype(np.uint32) << np.uint32(14)), newC)
        ch = newC != C
        idx = np.flatnonzero(ch).astype(np.int32)
        if idx.size == 0: continue
        f.write(struct.pack("<iii", rx, rz, idx.size))
        f.write(idx.tobytes()); f.write(newC.ravel()[idx].astype(np.uint32).tobytes())
        total += idx.size
        print("region", rx, rz, "bed", bed.sum(), "bank", bank.sum(), "edge", edge.sum())
print("wrote", out, os.path.getsize(out), "points", total)
