#!/usr/bin/env python3
"""0.2.53 ground key pilot: NSW Spatial Services imagery (public NSW_Imagery MapServer, ~0.13 m a pixel in town,
zoom 20 web-mercator tiles), reprojected onto the game's own frame (tools/geo.py) at 0.125 m a pixel.
  python3 tools/sat_fetch.py X0 Z0 X1 Z1 NAME      (game metres)  -> docs/ref/sat/NAME_rgb.png + NAME.json
Imagery (c) Spatial Services, NSW Department of Customer Service, CC BY 4.0."""
import json, math, os, subprocess, sys
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates
sys.path.insert(0, os.path.dirname(__file__))
import geo
Z = int(os.environ.get("SAT_Z", "20"))          # 0.2.74: SAT_Z / SAT_RES for a coarse look at a big area
RES = float(os.environ.get("SAT_RES", "0.125"))
URL = "https://maps.six.nsw.gov.au/arcgis/rest/services/public/NSW_Imagery/MapServer/tile/%d/%d/%d"
x0, z0, x1, z1 = map(float, sys.argv[1:5]); name = sys.argv[5]
OUT = os.path.join(os.path.dirname(__file__), "..", "docs", "ref", "sat")
CACHE = "/tmp/sat_tiles"; os.makedirs(CACHE, exist_ok=True)
def inv(x, z):
    """game (x, z) -> lon, lat (inverse of geo.fix on geo.ll; the north strip has no fit scale)"""
    north = np.asarray(z) < geo.NORTH_Z
    sx = np.where(north, 1.0, geo.SX); sz = np.where(north, 1.0, geo.SZ)
    return geo.LON0 + x / (geo.KX0 * sx), geo.LAT0 - z / (geo.KZ0 * sz)
def merc(lon, lat):
    n = 2 ** Z
    return (lon + 180) / 360 * n * 256, (1 - np.log(np.tan(np.radians(lat)) + 1 / np.cos(np.radians(lat))) / math.pi) / 2 * n * 256
lons, lats = [], []
for x, z in ((x0, z0), (x1, z0), (x0, z1), (x1, z1)):
    lo, la = inv(x, z); lons.append(lo); lats.append(la)
px0, py0 = merc(min(lons), max(lats)); px1, py1 = merc(max(lons), min(lats))
tx0, ty0, tx1, ty1 = int(px0 // 256) - 1, int(py0 // 256) - 1, int(px1 // 256) + 1, int(py1 // 256) + 1
jobs = []
for ty in range(ty0, ty1 + 1):
    for tx in range(tx0, tx1 + 1):
        f = "%s/%d_%d_%d.jpg" % (CACHE, Z, ty, tx)
        if not os.path.exists(f) or os.path.getsize(f) < 200: jobs.append("%s %s" % (URL % (Z, ty, tx), f))
print("tiles", (tx1 - tx0 + 1) * (ty1 - ty0 + 1), "to fetch", len(jobs))
if jobs:
    open("/tmp/sat_jobs.txt", "w").write("\n".join(jobs))
    subprocess.run("xargs -P 16 -L 1 sh -c 'curl -s -m 60 --retry 3 -o \"$1\" \"$0\"' < /tmp/sat_jobs.txt", shell=True)
W = (tx1 - tx0 + 1) * 256; H = (ty1 - ty0 + 1) * 256
mos = np.zeros((H, W, 3), np.uint8)
bad = 0
for ty in range(ty0, ty1 + 1):
    for tx in range(tx0, tx1 + 1):
        try:
            im = np.asarray(Image.open("%s/%d_%d_%d.jpg" % (CACHE, Z, ty, tx)).convert("RGB"))
            mos[(ty - ty0) * 256:(ty - ty0 + 1) * 256, (tx - tx0) * 256:(tx - tx0 + 1) * 256] = im
        except Exception: bad += 1
print("mosaic", W, H, "bad tiles", bad)
nx = int(round((x1 - x0) / RES)); nz = int(round((z1 - z0) / RES))
out = np.zeros((nz, nx, 3), np.uint8)
for j0 in range(0, nz, 512):
    j1 = min(nz, j0 + 512)
    zz, xx = np.meshgrid(z0 + (np.arange(j0, j1) + 0.5) * RES, x0 + (np.arange(nx) + 0.5) * RES, indexing="ij")
    lo, la = inv(xx, zz)
    mx, my = merc(lo, la)
    cx = mx - tx0 * 256 - 0.5; cy = my - ty0 * 256 - 0.5
    for c in range(3):
        out[j0:j1, :, c] = map_coordinates(mos[:, :, c], [cy, cx], order=1).astype(np.uint8)
Image.fromarray(out).save(os.path.join(OUT, name + "_rgb.png"))
json.dump({"x0": x0, "z0": z0, "x1": x1, "z1": z1, "res": RES, "zoom": Z, "source": "NSW Spatial Services NSW_Imagery (CC BY 4.0)"}, open(os.path.join(OUT, name + ".json"), "w"), indent=1)
print("wrote", nx, nz)
