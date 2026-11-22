#!/usr/bin/env python3
"""A wheel model for the garage's wheel list (0.2.59): any glb with one wheel in it -> assets/vehicles/wheels/<name>.glb,
centred, 1 m across, the axle along Z (the way rig.gd scales and turns wheel_car.glb). Parts named in --drop (brake
discs, calipers, logos) are left out. Usage: import_wheel.py in.glb name [--drop brake,logo]"""
import sys, numpy as np, trimesh
src, name = sys.argv[1], sys.argv[2]
drop = []
if "--drop" in sys.argv: drop = sys.argv[sys.argv.index("--drop") + 1].lower().split(",")
sc = trimesh.load(src, force="scene")
parts = []
for node in sc.graph.nodes_geometry:
    if any(d in node.lower() for d in drop): continue
    T, g = sc.graph[node]
    m = sc.geometry[g].copy()
    m.apply_transform(T)
    parts.append(m)
allv = np.vstack([p.vertices for p in parts])
mn, mx = allv.min(0), allv.max(0)
ctr = (mn + mx) / 2; ext = mx - mn
axle = int(np.argmin(ext))
R = np.eye(4)
if axle == 0: R = trimesh.transformations.rotation_matrix(np.pi / 2, [0, 1, 0])      # X -> Z
elif axle == 1: R = trimesh.transformations.rotation_matrix(np.pi / 2, [1, 0, 0])    # Y -> Z
dia = max(e for i, e in enumerate(ext) if i != axle)
S = trimesh.transformations.scale_matrix(1.0 / dia)
Tm = trimesh.transformations.translation_matrix(-ctr)
out = trimesh.Scene()
tris = 0
for i, p in enumerate(parts):
    p.apply_transform(S @ R @ Tm)
    out.add_geometry(p, node_name="%s_%d" % (name, i))
    tris += len(p.faces)
dst = "/home/claude/game/assets/vehicles/wheels/%s.glb" % name
out.export(dst)
v = np.vstack([g.vertices for g in out.geometry.values()])
print(name, "tris", tris, "bounds", np.round(v.min(0), 3).tolist(), np.round(v.max(0), 3).tolist(), "width/dia %.2f" % (ext[axle] / dia))
