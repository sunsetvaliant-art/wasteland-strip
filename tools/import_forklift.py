#!/usr/bin/env python3
"""The forklift (Mathieu.Godard's "ForkLift GameReady", CC BY) into the game, in pieces (0.2.66):
  assets/vehicles/forklift.glb           body (nose +X like every body; origin at rear axle height, between the axles)
  assets/vehicles/parts/fl_mast.glb      the mast, car frame (x across, y up, z forward), relative to the tilt pivot
  assets/vehicles/parts/fl_inner.glb     the mast's inner channel (rises in the top half of the lift)
  assets/vehicles/parts/fl_carriage.glb  carriage, backrest and the two tines, relative to the tilt pivot
  assets/vehicles/wheels/fl_front.glb / fl_rear.glb   wheel models (unit diameter, axle Z, face +Z)
Prints the catalog entry (with its "forks" block: pivot, tines and backrest boxes). Input: the upright copy
(tools/glb_upright.py --other --flip --len 3.3) with the forks to +Z.
Usage: import_forklift.py upright.glb"""
import json, sys
import numpy as np, trimesh

G = "/home/claude/game/assets/vehicles"
src = sys.argv[1]
sc = trimesh.load(src, force="scene", process=False)
parts = {}
for node in sc.graph.nodes_geometry:
    T, g = sc.graph[node]
    m = sc.geometry[g].copy(); m.apply_transform(T)
    parts[g] = m

def grp(names): return [parts[n] for n in names if n in parts]
# longer tines (1.2 m: a cab is 1.8-2 m wide, the forks have to get past its middle from the side)
for n in ["defaultMaterial_38", "defaultMaterial_33"]:
    v = parts[n].vertices.copy(); heel = v[:, 2].min() + 0.1
    sel = v[:, 2] > heel
    v[sel, 2] = heel + (v[sel, 2] - heel) * 1.33
    parts[n].vertices = v
WHEELS = {"fl": "defaultMaterial_21", "fr": "defaultMaterial_19", "rl": "defaultMaterial_22", "rr": "defaultMaterial_20"}
MAST = ["defaultMaterial_34", "defaultMaterial_39", "defaultMaterial_31", "defaultMaterial_41", "defaultMaterial_40",
        "defaultMaterial_36", "defaultMaterial_35"]
CARR = ["defaultMaterial_32", "defaultMaterial_37", "defaultMaterial_30", "defaultMaterial_38", "defaultMaterial_33"]
TINES = ["defaultMaterial_38", "defaultMaterial_33"]

def bounds(ms):
    v = np.vstack([m.vertices for m in ms]); return v.min(0), v.max(0)

def centre(n):
    lo, hi = bounds([parts[n]]); return (lo + hi) / 2, hi[1] - lo[1]

cf, df = centre(WHEELS["fl"]); cr, dr = centre(WHEELS["rl"])
cfr, _ = centre(WHEELS["fr"]); crr, _ = centre(WHEELS["rr"])
y0 = cr[1]; zmid = (cf[2] + cr[2]) / 2
to_car = np.array([0.0, -y0, -zmid])           # upright frame -> car frame (x across, y up, z forward)

def export(ms, path, shift):
    s = trimesh.Scene()
    for i, m in enumerate(ms):
        mm = m.copy(); mm.apply_translation(shift); s.add_geometry(mm, node_name="p%d" % i)
    s.export(path, include_normals=True)

# body: everything else, turned so the nose is +X (body x = car z, body z = -car x)
body = [m for n, m in parts.items() if n not in WHEELS.values() and n not in MAST and n not in CARR]
bs = trimesh.Scene()
R = np.array([[0, 0, 1, 0], [0, 1, 0, 0], [-1, 0, 0, 0], [0, 0, 0, 1]], float)
allv = []
for i, m in enumerate(body):
    mm = m.copy(); mm.apply_translation(to_car); mm.apply_transform(R); bs.add_geometry(mm, node_name="body_%d" % i)
    allv.append(mm.vertices)
bs.export(G + "/forklift.glb", include_normals=True)
v = np.vstack(allv); mn, mx = v.min(0), v.max(0)

# mast pivot: the foot of the mast, centred
mlo, mhi = bounds(grp(["defaultMaterial_34"]))
pivot = np.array([0.0, mlo[1] + 0.1, (mlo[2] + mhi[2]) / 2]) + to_car
shift = to_car - pivot
export(grp(MAST), G + "/parts/fl_mast.glb", shift)
export(grp(["defaultMaterial_34"]), G + "/parts/fl_inner.glb", shift)
export(grp(CARR), G + "/parts/fl_carriage.glb", shift)

# tines and backrest as boxes in pivot space: [centre, size]
boxes = []
for n in TINES:
    lo, hi = bounds([parts[n]]); lo = lo + shift; hi = hi + shift
    # the blade: the bottom 5 cm, from the heel forward
    blo = np.array([lo[0], lo[1], lo[2] + 0.1]); bhi = np.array([hi[0], lo[1] + 0.05, hi[2]])
    boxes.append([((blo + bhi) / 2).round(4).tolist(), (bhi - blo).round(4).tolist()])
lo, hi = bounds(grp(["defaultMaterial_32"])); lo = lo + shift; hi = hi + shift
back = [((lo + hi) / 2).round(4).tolist(), (hi - lo).round(4).tolist()]

# wheel models: the left ones, centred, unit diameter, axle along Z, face out (+Z: the left wheel's outside is -x)
for key, n in [("fl_front", WHEELS["fl"]), ("fl_rear", WHEELS["rl"])]:
    c, d = centre(n)
    m = parts[n].copy(); m.apply_translation(-c)
    m.apply_transform(trimesh.transformations.rotation_matrix(-np.pi / 2, [0, 1, 0]))   # -x (outside, left) -> +z
    m.apply_scale(1.0 / d)
    s = trimesh.Scene(); s.add_geometry(m, node_name=key); s.export(G + "/wheels/%s.glb" % key, include_normals=True)

ent = {"name": "Forklift", "glb": "forklift", "cls": "car", "kg": 1500, "ax_f": round(float(cf[2] - zmid), 3), "ax_r": round(float(cr[2] - zmid), 3),
       "min": [round(float(x), 4) for x in mn], "ext": [round(float(x), 4) for x in (mx - mn)],
       "seat": [round(float(-0.68 - zmid), 3), round(float(1.0 - y0), 3), 0.0], "ride": 0.0,
       "tyre_r": [round(float(df / 2), 3), round(float(dr / 2), 3)],
       "track": [round(abs(float(cf[0] - cfr[0])) / 2, 3), round(abs(float(cr[0] - crr[0])) / 2, 3)],
       "lift": [round(float(cr[1] - cf[1]), 3), 0.0], "wheels": ["fl_front", "fl_rear"],
       "forks": {"pivot": pivot.round(4).tolist(), "tines": boxes, "back": back, "lift": 1.75, "tilt": [-0.1, 0.17]}}
print(json.dumps(ent))
json.dump(ent, open("/tmp/forklift_entry.json", "w"))
