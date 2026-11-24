"""0.2.74: the game's coastline against the NSW aerial photos. Needs docs/ref/sat/coast_z16_rgb.png (SAT_Z=16 SAT_RES=5
python3 tools/sat_fetch.py 15000 -20480 19500 15360 coast_z16) and assets/world/sea_dist.png (tools/coast_fix.py).
Per 5 m row down the coast: where the sea starts in the photo (the first water or surf east of the sand) and where it
starts in the game; prints the differences and draws the game's line in red on the photo (docs/ref/sat/coast_check.jpg).
usage: python3 tools/coast_check.py"""
import numpy as np, os, json
from PIL import Image, ImageDraw
from scipy import ndimage
here = os.path.dirname(__file__)
sat = np.asarray(Image.open(os.path.join(here, "..", "docs", "ref", "sat", "coast_z16_rgb.png")).convert("RGB")).astype(int)
meta = json.load(open(os.path.join(here, "..", "docs", "ref", "sat", "coast_z16.json")))
r, g, b = sat[..., 0], sat[..., 1], sat[..., 2]
lum = (r + g + b) / 3
water = ((np.maximum(g, b) - r > 6) & (r < 170)) | ((r < 75) & (lum < 85) & (b >= r - 2))
surf = (np.minimum(np.minimum(r, g), b) > 185) & (r - b < 7)
wet = water | surf
wet = ndimage.binary_opening(wet, iterations=1)
lab, n = ndimage.label(wet)
east = np.unique(lab[:, -1]); east = east[east > 0]
sea_p = np.isin(lab, east)
sd = np.asarray(Image.open(os.path.join(here, "..", "assets", "world", "sea_dist.png"))).astype(int)
# sea_dist: 10 m a pixel from x 12000, z -20480; the photo: 5 m from meta x0, z0
x0, z0 = meta["x0"], meta["z0"]
H, W = sea_p.shape
rows = []
for j in range(H):
    z = z0 + (j + 0.5) * 5.0
    # photo: the westmost sea pixel of the run that reaches the east edge
    rowp = sea_p[j]
    if not rowp[-1]: continue
    k = W - 1
    while k > 0 and rowp[k - 1]: k -= 1
    xs = x0 + k * 5.0
    # game
    sj = int((z + 20480.0) / 10.0)
    if sj < 0 or sj >= sd.shape[0]: continue
    rowg = sd[sj] > 0
    if not rowg[-1]: continue
    m = sd.shape[1] - 1
    while m > 0 and rowg[m - 1]: m -= 1
    xg = 12000.0 + m * 10.0
    rows.append((j, z, xs, xg))
a = np.array(rows)
d = a[:, 2] - a[:, 3]
print("rows", len(a), "photo minus game (m): median %.0f, 10%% %.0f, 90%% %.0f" % (np.median(d), np.percentile(d, 10), np.percentile(d, 90)))
# stretches where they disagree by more than 60 m for 100 m or more (beyond tide and swash)
bad = np.abs(d - np.median(d)) > 60
lab2, n2 = ndimage.label(bad)
for i in range(1, n2 + 1):
    idx = np.nonzero(lab2 == i)[0]
    if len(idx) < 20: continue
    print("  z %.0f..%.0f: photo %.0f, game %.0f (%+.0f m)" % (a[idx[0], 1], a[idx[-1], 1], np.median(a[idx, 2]), np.median(a[idx, 3]), np.median(d[idx])))
im = Image.fromarray(sat.astype(np.uint8)).convert("RGB"); dr = ImageDraw.Draw(im)
for j, z, xs, xg in rows:
    dr.point(((xg - x0) / 5.0, j), fill=(255, 0, 0)); dr.point(((xs - x0) / 5.0, j), fill=(255, 255, 0))
im.save(os.path.join(here, "..", "docs", "ref", "sat", "coast_check.jpg"), quality=80)
