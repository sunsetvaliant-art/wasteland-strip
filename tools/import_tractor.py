#!/usr/bin/env python3
"""The Lamborghini R6 tractor from Sketchfab (0.2.59) into a game body: wheels taken off (they're the game's own, spun by
the sim), scaled so the rear tyres are 1.70 m across, nose to +X, the rear axle centre at the origin. The front and
rear wheels become wheel models of their own. Prints the catalog entry."""
import json, numpy as np, trimesh
SRC = "/home/claude/sf/dl/tractor_lambo/model.glb"
G = "/home/claude/game/assets/vehicles"
sc = trimesh.load(SRC, force="scene")
wheels = {}; body = []
for node in sc.graph.nodes_geometry:
    T, g = sc.graph[node]
    m = sc.geometry[g].copy(); m.apply_transform(T)
    k = next((w for w in ("WHEEL_LF", "WHEEL_RF", "WHEEL_LR", "WHEEL_RR") if node.startswith(w)), None)
    if k: wheels[k] = m
    else: body.append((node, m))
def box(m): return m.vertices.min(0), m.vertices.max(0)
lr0, lr1 = box(wheels["WHEEL_LR"]); lf0, lf1 = box(wheels["WHEEL_LF"])
S = 1.70 / (lr1[1] - lr0[1])
rc = (lr0 + lr1) / 2; fc = (lf0 + lf1) / 2
mid_z = (rc[2] + fc[2]) / 2
# model: x across (+ left), y up, z forward  ->  game body: x forward, y up, z across (- left), origin rear axle height, between the axles
def to_game(p):
    p = (np.asarray(p) - np.array([0.0, rc[1], mid_z])) * S
    return np.c_[p[..., 2], p[..., 1], -p[..., 0]] if p.ndim > 1 else np.array([p[2], p[1], -p[0]])
M = np.eye(4)
Tm = trimesh.transformations.translation_matrix([0.0, -rc[1], -mid_z])
Sm = trimesh.transformations.scale_matrix(S)
Rm = trimesh.transformations.rotation_matrix(np.pi / 2, [0, 1, 0])      # +z -> +x
X = Rm @ Sm @ Tm
out = trimesh.Scene()
for i, (n, m) in enumerate(body):
    m.apply_transform(X); out.add_geometry(m, node_name="body_%d" % i)
out.export(G + "/tractor_r6.glb")
v = np.vstack([g.vertices for g in out.geometry.values()])
mn, mx = v.min(0), v.max(0)
ax_r = float(to_game(rc)[0]); ax_f = float(to_game(fc)[0])
r_r = 0.85; r_f = (lf1[1] - lf0[1]) * S / 2
fy = float(to_game(fc)[1])
tr_r = abs(float(rc[0])) * S; tr_f = abs(float(fc[0])) * S
# each wheel on its own: centred, 1 m across, axle along Z
for key, name in (("WHEEL_LF", "r6_front"), ("WHEEL_LR", "r6_rear")):
    m = wheels[key].copy()
    a, b = box(m); c = (a + b) / 2; dia = b[1] - a[1]
    m.apply_transform(trimesh.transformations.translation_matrix(-c))
    m.apply_transform(trimesh.transformations.rotation_matrix(np.pi / 2, [0, 1, 0]))     # axle (x) -> z
    m.apply_transform(trimesh.transformations.scale_matrix(1.0 / dia))
    sw = trimesh.Scene(); sw.add_geometry(m, node_name=name); sw.export(G + "/wheels/%s.glb" % name)
ent = {"name": "Lamborghini R6 tractor", "glb": "tractor_r6", "cls": "4x4", "kg": 2000, "ax_f": round(ax_f, 3), "ax_r": round(ax_r, 3),
       "min": [round(float(mn[0]), 4), round(float(mn[1]), 4), round(float(mn[2]), 4)], "ext": [round(float(mx[0] - mn[0]), 4), round(float(mx[1] - mn[1]), 4), round(float(mx[2] - mn[2]), 4)],
       "seat": [round(ax_r + 0.25, 3), 0.95, 0.0],
       "ride": 0.0, "tyre_r": [round(float(r_f), 3), r_r], "track": [round(tr_f, 3), round(tr_r, 3)], "lift": [round(-fy, 3), 0.0],
       "wheels": ["r6_front", "r6_rear"], "drive_f": True, "gearbox": "man4", "final": 11.5, "front_share": 0.42, "steer_max": 0.7}
print(json.dumps(ent))
json.dump(ent, open("/tmp/tractor_entry.json", "w"))
