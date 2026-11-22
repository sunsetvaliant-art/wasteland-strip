#!/usr/bin/env python3
"""The 'Realistic JDM Rim Pack' (Sketchfab, CC BY) is laid out for show: each rim with its tyre beside it at an angle.
This lines each tyre up on its rim (each part's axle found from its shape), then saves them as wheels like
import_wheel.py does: assets/vehicles/wheels/jdm_<n>.glb, 1 m across the tyre, axle along Z."""
import numpy as np, trimesh
SRC = "/home/claude/sf/dl/u_jdm/model.glb"
sc = trimesh.load(SRC, force="scene")
def axis_ctr(V):
    c = (V.min(0) + V.max(0)) / 2
    w, vec = np.linalg.eigh(np.cov((V - V.mean(0)).T))
    return vec[:, 0], c          # least spread = the axle
def rot_to(a, b):
    a = a / np.linalg.norm(a); b = b / np.linalg.norm(b)
    if np.dot(a, b) < 0: b = -b
    v = np.cross(a, b); s = np.linalg.norm(v); c = np.dot(a, b)
    if s < 1e-8: return np.eye(3)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k * ((1 - c) / s ** 2)
for n in range(1, 5):
    rim, tyre = [], []
    for node in sc.graph.nodes_geometry:
        if not node.lower().startswith("rim%d_" % n): continue
        T, g = sc.graph[node]
        m = sc.geometry[g].copy(); m.apply_transform(T)
        (tyre if "material.00" in node.lower() else rim).append(m)
    RV = np.vstack([m.vertices for m in rim]); TV = np.vstack([m.vertices for m in tyre])
    ra, rc = axis_ctr(np.vstack([m.vertices for m in rim if len(m.vertices) > 2000]) if any(len(m.vertices) > 2000 for m in rim) else RV)
    ta, tc = axis_ctr(TV)
    Rt = rot_to(ta, ra)
    for m in tyre:
        m.vertices = (m.vertices - tc) @ Rt.T + rc
    # now everything about the rim's axle: turn that to Z, centre, 1 m across the tyre
    Rz = rot_to(ra, np.array([0, 0, 1.0]))
    parts = rim + tyre
    for m in parts: m.vertices = (m.vertices - rc) @ Rz.T
    TV2 = np.vstack([m.vertices for m in tyre])
    dia = max(np.ptp(TV2[:, 0]), np.ptp(TV2[:, 1]))
    out = trimesh.Scene()
    for i, m in enumerate(parts):
        m.vertices = m.vertices / dia
        out.add_geometry(m, node_name="jdm%d_%d" % (n, i))
    out.export("/home/claude/game/assets/vehicles/wheels/jdm_%d.glb" % n)
    V = np.vstack([m.vertices for m in parts])
    print("jdm_%d" % n, np.round(V.min(0), 3).tolist(), np.round(V.max(0), 3).tolist())
