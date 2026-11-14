#!/usr/bin/env python3
"""Vegetation and ground classes for the strip north of the old map edge (z = -16960), so it grows and looks like the
country south of it instead of the old mask's edge row smeared north.
Reads assets/world/north_h.bin (heights), assets/world/buildings.json (lots, for town), assets/vegmask*.png (to match
the south's mix and blend across the seam). Writes assets/vegmask_north.png and assets/vegmask2_north.png in the same
channel layout as vegmask.png / vegmask2.png:
  vegmask:  r canopy, g sand, b town, a wet          vegmask2: r short grass, g cane, b water
10 m a pixel, x from X0N, row 0 = the strip's north edge.  usage: tools/bake_north_veg.py"""
import json, os, struct
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, distance_transform_edt, zoom, label
GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
X0, Z0, MPX = -8960.0, -16960.0, 10.0

f = open(f"{GAME}/assets/world/north_h.bin", "rb")
xa, zn, w, h, sp = struct.unpack("<ffIIf", f.read(20))
H5 = (np.frombuffer(f.read(w * h * 2), "<u2").reshape(h, w).astype(np.float64) - 1000.0) / 100.0
# to 10 m pixels covering [xa, xa + w*sp) x [zn, Z0)
W, R = int(w * sp / MPX), int((Z0 - zn) / MPX)
H = zoom(H5, (R / h, W / w), order=1)[:R, :W]
rng = np.random.default_rng(1977)

def fbm(shape, scales, seed):
    r = np.random.default_rng(seed); out = np.zeros(shape)
    for s, amp in scales:
        out += gaussian_filter(r.standard_normal(shape), s) * amp / max(gaussian_filter(r.standard_normal(shape), s).std(), 1e-6)
    return (out - out.mean()) / out.std()

water = H < 0.25
# the open sea: the biggest connected body of water (rivers and canals stay "water" but don't make beaches)
lab, n = label(water)
sea = np.zeros_like(water)
if n:
    sizes = np.bincount(lab.ravel()); sizes[0] = 0
    sea = lab == sizes.argmax()
# open ocean only: water more than 250 m from any land (rivers, inlets and the low ground at the strip's eased-off ends
# don't count), then the beach is the land within ~140 m of the ocean's shore
core = sea & (distance_transform_edt(sea) * MPX > 250)
core[:, :30] = False; core[:, -30:] = False
core[:, :int((11000 - xa) / MPX)] = False        # west of here the big water is Cobaki Broadwater, a lake: no beach
dsea = distance_transform_edt(~core) * MPX - 250
dwat = distance_transform_edt(~water) * MPX
sand = (~water) & (dsea < 140) & (H < 6.0)
sand_v = np.clip(1.0 - (dsea - 60) / 80.0, 0, 1) * sand

# town: building density from the lot list (lots north of the edge)
lots = json.load(open(f"{GAME}/assets/world/buildings.json"))["lots"]
dens = np.zeros((R, W))
for l in lots:
    x, z = float(l[1]), float(l[2])
    if z >= Z0 or z < zn: continue
    c = int((x - xa) / MPX); r = int((z - zn) / MPX)
    if 0 <= r < R and 0 <= c < W: dens[r, c] += 1
town = np.clip(gaussian_filter(dens, 4.0) * 60.0, 0, 1)

# wet: low ground near water, not beach
wet = np.clip(1.0 - dwat / 120.0, 0, 1) * np.clip((3.0 - H) / 2.5, 0, 1) * (~sand) * (~water)

# canopy: patches of bush, thicker on hills and gullies, thin in town and on the beach, to match the south's mix
slope = np.hypot(*np.gradient(H, MPX))
noise = fbm((R, W), [(18, 1.0), (6, 0.5), (2, 0.25)], 41)
c = noise + 0.9 * np.clip((H - 12) / 30, 0, 1) + 1.5 * np.clip(slope - 0.08, 0, 0.3) / 0.3 - 1.4 * town - 3.0 * sand_v
canopy = np.clip((c - 0.45) / 0.6, 0, 1)
canopy[water] = 0

short = np.clip(0.15 + 0.5 * town, 0, 1)

def u8(a): return (np.clip(a, 0, 1) * 255).astype(np.uint8)
m = np.stack([canopy, sand_v, town, wet], -1)
m2 = np.stack([short, np.zeros((R, W)), water.astype(float), np.ones((R, W))], -1)

# blend into the south mask's first rows over the last 200 m so the edge doesn't show
S = np.asarray(Image.open(f"{GAME}/assets/vegmask.png").convert("RGBA")).astype(float) / 255
S2 = np.asarray(Image.open(f"{GAME}/assets/vegmask2.png").convert("RGBA")).astype(float) / 255
c0 = int((xa - X0) / MPX)
edge = S[0, c0:c0 + W]; edge2 = S2[0, c0:c0 + W]
k = np.clip((np.arange(R)[::-1] + 0.5) / 20.0, 0, 1)[:, None, None]        # 0 at the seam row, 1 by 200 m north
k = k * k * (3 - 2 * k)
mb = m * k + edge[None] * (1 - k)
m2b = m2 * k + edge2[None] * (1 - k)
m2b[..., 3] = 1.0
Image.fromarray(u8(mb), "RGBA").save(f"{GAME}/assets/vegmask_north.png")
Image.fromarray(u8(m2b), "RGBA").save(f"{GAME}/assets/vegmask2_north.png")
land = ~water
print("north veg", (R, W), "x0", xa, "z0", zn, "| on land: canopy mean %.2f >0.5 %.2f, sand %.2f, town %.2f, wet %.2f" % (
    canopy[land].mean(), (canopy[land] > 0.5).mean(), sand_v[land].mean(), town[land].mean(), wet[land].mean()))
