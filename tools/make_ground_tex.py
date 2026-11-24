"""0.2.74: ground textures made from the scans already in the game (no new downloads):
  wet_sand   the sand the swash reaches: darker, browner, flatter and glossy
  wet_mud    a churned wet mud (river beds, wallows): the farm soil darkened, smeared and glossy, with puddle sheen
  cane_mud   under the cane: wet dark soil with the cane trash lying on top in drifts (replaces cane_trash's look)
Each is <name>_alb_h.png (rgb albedo, a height) and <name>_nrm_r.png (rgb normal, a roughness) like the others.
usage: python3 tools/make_ground_tex.py"""
import numpy as np, os
from PIL import Image
from scipy import ndimage
G = os.path.join(os.path.dirname(__file__), "..", "assets", "ground")
def load(n):
    a = np.asarray(Image.open(os.path.join(G, n + "_alb_h.png")).convert("RGBA")).astype(np.float32) / 255.0
    b = np.asarray(Image.open(os.path.join(G, n + "_nrm_r.png")).convert("RGBA")).astype(np.float32) / 255.0
    return a, b
def save(n, a, b):
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA").save(os.path.join(G, n + "_alb_h.png"))
    Image.fromarray((np.clip(b, 0, 1) * 255).astype(np.uint8), "RGBA").save(os.path.join(G, n + "_nrm_r.png"))
def tile_noise(size, scale, seed):
    r = np.random.default_rng(seed)
    n = r.normal(0, 1, (size, size)).astype(np.float32)
    n = ndimage.gaussian_filter(n, scale, mode="wrap")
    return (n - n.min()) / (n.max() - n.min() + 1e-9)
def flat_normal(nrm, k):
    out = nrm.copy()
    out[..., 0] = 0.5 + (nrm[..., 0] - 0.5) * k
    out[..., 1] = 0.5 + (nrm[..., 1] - 0.5) * k
    out[..., 2] = 1.0 - (1.0 - nrm[..., 2]) * k
    return out
def normal_from_h(h, s):
    gy, gx = np.gradient(h)
    n = np.dstack([-gx * s, -gy * s, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5

sa, sn = load("sand")
N = sa.shape[0]
# wet sand
wa = sa.copy()
lum = sa[..., :3].mean(2, keepdims=True)
wa[..., :3] = (sa[..., :3] * 0.55 + lum * 0.05) * np.array([1.0, 0.93, 0.82])
wa[..., 3] = 0.35 + sa[..., 3] * 0.3
wn = flat_normal(sn, 0.35)
sheen = tile_noise(N, 40, 3)
wn[..., 3] = 0.18 + 0.18 * (1 - sheen)
save("wet_sand", wa, wn)

fa, fn = load("farm_soil")
# wet mud: smear the soil, darken it, puddles where a low noise dips
sm = np.dstack([ndimage.gaussian_filter(fa[..., i], 2.0, mode="wrap") for i in range(4)])
pud = tile_noise(N, 70, 5)
pmask = np.clip((0.38 - pud) / 0.08, 0, 1)
ma = sm.copy()
ma[..., :3] = sm[..., :3] * np.array([0.62, 0.52, 0.42]) * 0.9
ma[..., :3] = ma[..., :3] * (1 - pmask[..., None] * 0.35) + pmask[..., None] * np.array([0.14, 0.11, 0.08]) * 0.35
h = 0.45 + (sm[..., 3] - 0.5) * 0.5 - pmask * 0.25 + (tile_noise(N, 6, 9) - 0.5) * 0.2
ma[..., 3] = np.clip(h, 0, 1)
mn = normal_from_h(ndimage.gaussian_filter(h, 1.5, mode="wrap"), 30.0)
mn = np.dstack([mn, 0.28 - pmask * 0.22 + (tile_noise(N, 10, 11) - 0.5) * 0.1])
save("wet_mud", ma, mn)

ca, cn = load("cane_trash")
# cane mud: the mud, and the trash lying on it in drifts (where a broad noise is high, and on the leaves' high spots)
drift = tile_noise(N, 55, 21)
leaf = np.clip((ca[..., 3] - 0.35) / 0.3, 0, 1) * np.clip((drift - 0.35) / 0.25, 0, 1)
leaf = np.clip(leaf * 1.4, 0, 1)[..., None]
cm = ma.copy()
cm[..., :3] = ma[..., :3] * (1 - leaf) + ca[..., :3] * 0.8 * leaf
cm[..., 3] = (ma[..., 3] * (1 - leaf[..., 0]) + ca[..., 3] * leaf[..., 0])
cnn = mn.copy()
cnn[..., :3] = mn[..., :3] * (1 - leaf) + cn[..., :3] * leaf
cnn[..., 3] = mn[..., 3] * (1 - leaf[..., 0]) + 0.85 * leaf[..., 0]
save("cane_mud", cm, cnn)
print("ground textures written")
