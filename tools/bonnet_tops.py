#!/usr/bin/env python3
"""For every body in the catalog: the height of its skin over the front of the car (a 5 cm grid of the highest
point of the body, car frame: x across, z forward, y up, origin as the game puts the body), so an engine can be
dropped until it clears the bonnet; and the body's paint colour (sampled off its texture on the upward-facing
panels of the front half), for the engine bay's sheet metal. Writes assets/vehicles/body_info.json. (0.2.65)"""
import json, sys
import numpy as np, trimesh

G = "/home/claude/game/assets/vehicles"
cat = json.load(open(G + "/catalog.json"))
out = {}
CELL = 0.05
for key, d in cat.items():
    glb = d["glb"]
    if glb in out: continue
    try:
        sc = trimesh.load(f"{G}/{glb}.glb", force="scene")
    except Exception as e:
        print("skip", glb, e); continue
    V, cols = [], []
    for node in sc.graph.nodes_geometry:
        T, g = sc.graph[node]
        m = sc.geometry[g]
        v = trimesh.transform_points(m.vertices, T)
        # the game turns the body -90 about Y: model +X (nose) -> +Z, model z -> -x
        vv = np.c_[-v[:, 2], v[:, 1], v[:, 0]]
        # points all over the surface, not just the vertices (a low-poly bonnet is a few big triangles: cells with no
        # vertex of the skin in them read the junk under it)
        try:
            mm = trimesh.Trimesh(vv, m.faces, process=False)
            n_s = int(min(200000, max(500, mm.area / 0.0003)))
            pts, _ = trimesh.sample.sample_surface(mm, n_s)
            V.append(np.vstack([vv, pts]))
        except Exception:
            V.append(vv)
        # paint: the material with the most upward-facing area over the bonnet (the front 1.2 m, top half) wins;
        # its colour is the median of its texture there (times its base colour)
        try:
            fc = vv[m.faces].mean(1)
            nrm = np.cross(vv[m.faces[:, 1]] - vv[m.faces[:, 0]], vv[m.faces[:, 2]] - vv[m.faces[:, 0]])
            ln = np.linalg.norm(nrm, axis=1) + 1e-12
            ax_f0 = float(d.get("ax_f", 1.4))
            up = ((nrm[:, 1] / ln) > 0.8) & (fc[:, 2] > ax_f0 - 0.9) & (np.abs(fc[:, 0]) < 0.5)
            sel = np.where(up)[0]
            if len(sel) == 0: continue
            mat = getattr(m.visual, "material", None)
            if mat is not None and str(getattr(mat, "alphaMode", "") or "").upper() == "BLEND": continue     # glass
            img = None; base = np.array([1.0, 1.0, 1.0])
            if mat is not None:
                if getattr(mat, "baseColorTexture", None) is not None: img = mat.baseColorTexture
                bcf = getattr(mat, "baseColorFactor", None)
                if bcf is not None: base = np.array(bcf[:3], float) / (255.0 if np.max(bcf) > 1.0 else 1.0)
            # only the highest of those faces: the bonnet skin, not the engine or the seats
            ytop = np.percentile(fc[sel, 1], 60)
            sel = sel[fc[sel, 1] >= ytop]
            area = float(ln[sel].sum() * 0.5)
            s2 = sel[:: max(1, len(sel) // 400)]
            if img is not None and getattr(m.visual, "uv", None) is not None:
                im = np.asarray(img.convert("RGB"), dtype=float) / 255.0
                uv = m.visual.uv[m.faces[s2]].mean(1)
                px = np.clip((uv[:, 0] % 1.0) * (im.shape[1] - 1), 0, im.shape[1] - 1).astype(int)
                py = np.clip((1.0 - (uv[:, 1] % 1.0)) * (im.shape[0] - 1), 0, im.shape[0] - 1).astype(int)
                c = np.median(im[py, px], axis=0) * base
            else:
                c = base
            nm = str(getattr(mat, "name", "") or "").lower()
            cols.append((c, area * (10.0 if ("paint" in nm and "second" not in nm) else 1.0), float(fc[sel, 1].mean()) + (10.0 if ("paint" in nm and "second" not in nm) else 0.0)))
        except Exception as e:
            pass
    V = np.vstack(V)
    ax_f = float(d.get("ax_f", 1.4))
    front = V[V[:, 2] > ax_f - 1.6]
    x0 = float(np.floor(front[:, 0].min() / CELL)) * CELL; z0 = float(np.floor(front[:, 2].min() / CELL)) * CELL
    nx = int(np.ceil((front[:, 0].max() - x0) / CELL)) + 1; nz = int(np.ceil((front[:, 2].max() - z0) / CELL)) + 1
    h = np.full((nz, nx), -99.0)
    ix = ((front[:, 0] - x0) / CELL).astype(int); iz = ((front[:, 2] - z0) / CELL).astype(int)
    np.maximum.at(h, (iz, ix), front[:, 1])
    paint = None
    if cols:
        # the highest big panel: of the materials with real area up there, the one sitting highest is the bonnet skin
        amax = max(a for c, a, y in cols)
        cand = [(y, c) for c, a, y in cols if a > 0.25 * amax]
        c = max(cand, key=lambda t: t[0])[1]
        paint = [round(float(x), 3) for x in c]
    out[glb] = {"cell": CELL, "x0": round(x0, 3), "z0": round(z0, 3), "nx": nx, "nz": nz,
                "h": [round(float(x), 3) for x in h.reshape(-1)], "paint": paint}
    print(glb, nx, nz, paint)
json.dump(out, open(G + "/body_info.json", "w"), separators=(",", ":"))
print(len(out), "bodies")
