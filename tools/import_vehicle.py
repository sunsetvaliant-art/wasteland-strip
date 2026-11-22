#!/usr/bin/env python3
"""A downloaded car body into the game (0.2.60): the wheels found and cut off (they become a wheel model; the sim
spins its own), scaled to its real length, nose to +X, origin at rear axle height between the axles. Prints and
writes the catalog entry. The source has x across, y up, z forward (Sketchfab's usual); --flip if the nose is -z.
Usage: import_vehicle.py src.glb key glb_name "Name" length_m kg cls [--flip]"""
import sys, json, numpy as np, trimesh
src, key, gname, title, L, kg, cls = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], float(sys.argv[5]), float(sys.argv[6]), sys.argv[7]
flip = "--flip" in sys.argv
G = "/home/claude/game/assets/vehicles"
sc = trimesh.load(src, force="scene")
parts = []
for node in sc.graph.nodes_geometry:
    T, g = sc.graph[node]
    m = sc.geometry[g].copy(); m.apply_transform(T)
    if flip: m.apply_transform(trimesh.transformations.rotation_matrix(np.pi, [0, 1, 0]))
    parts.append((node, m))
allv = np.vstack([m.vertices for _, m in parts])
S = L / np.ptp(allv[:, 2])
for _, m in parts: m.apply_transform(trimesh.transformations.scale_matrix(S))
allv = allv * S if not flip else np.vstack([m.vertices for _, m in parts])
allv = np.vstack([m.vertices for _, m in parts])
ymin = allv[:, 1].min()
# tyres: round in y-z, thin in x, out at the sides, sitting near the ground
tyres = []
for i, (n, m) in enumerate(parts):
    e = np.ptp(m.vertices, 0); c = (m.vertices.min(0) + m.vertices.max(0)) / 2
    if e[1] > 0.45 and abs(e[1] - e[2]) < 0.06 * e[1] and e[0] < 0.75 * e[1] and abs(c[0]) > 0.4 and c[1] - e[1] / 2 < ymin + 0.08:
        tyres.append((i, c, e[1]))
# one per corner: the biggest round part at each of the four corners
corners = {}
for i, c, d in tyres:
    k = (c[0] > 0, c[2] > 0)
    if k not in corners or d > corners[k][2]: corners[k] = (i, c, d)
assert len(corners) == 4, "found %d wheel corners" % len(corners)
wheel_of = {}
for k, (i, c, d) in corners.items():
    for j, (n, m) in enumerate(parts):
        cj = (m.vertices.min(0) + m.vertices.max(0)) / 2; ej = np.ptp(m.vertices, 0)
        if np.linalg.norm((cj - c)[[1, 2]]) < 0.12 * d and abs(cj[0] - c[0]) < 0.6 * d and max(ej[1], ej[2]) <= d * 1.02:
            wheel_of[j] = k
front = [corners[(s, True)][1] for s in (False, True)]; rear = [corners[(s, False)][1] for s in (False, True)]
fc = (front[0] + front[1]) / 2; rc = (rear[0] + rear[1]) / 2
mid_z = (fc[2] + rc[2]) / 2
Tm = trimesh.transformations.translation_matrix([0.0, -rc[1], -mid_z])
Rm = trimesh.transformations.rotation_matrix(np.pi / 2, [0, 1, 0])
X = Rm @ Tm
out = trimesh.Scene()
for j, (n, m) in enumerate(parts):
    if j in wheel_of: continue
    mm = m.copy(); mm.apply_transform(X); out.add_geometry(mm, node_name="body_%d" % j)
out.export(G + "/%s.glb" % gname)
v = np.vstack([g.vertices for g in out.geometry.values()])
mn, mx = v.min(0), v.max(0)
# the front left wheel as the car's own wheel model: centred, 1 m across, axle along Z, face out (+Z)
wk = (True, True)
wm = [parts[j][1].copy() for j, k in wheel_of.items() if k == wk]
c = corners[wk][1]; d = corners[wk][2]
ws = trimesh.Scene()
for i, m in enumerate(wm):
    m.apply_transform(trimesh.transformations.translation_matrix(-c))
    m.apply_transform(trimesh.transformations.rotation_matrix(-np.pi / 2, [0, 1, 0]))   # +x (outward on the left) -> +z
    m.apply_transform(trimesh.transformations.scale_matrix(1.0 / d))
    ws.add_geometry(m, node_name="%s_wheel_%d" % (key, i))
ws.export(G + "/wheels/%s.glb" % key)
r_f = corners[(True, True)][2] / 2; r_r = corners[(True, False)][2] / 2
ent = {"name": title, "glb": gname, "cls": cls, "kg": kg, "ax_f": round(float(fc[2] - mid_z), 3), "ax_r": round(float(rc[2] - mid_z), 3),
       "min": [round(float(x), 4) for x in mn], "ext": [round(float(x), 4) for x in (mx - mn)],
       "seat": [round(float(fc[2] - mid_z) - 1.25, 3), 0.15, 0.38], "ride": 0.0, "tyre_r": [round(float(r_f), 3), round(float(r_r), 3)],
       "track": [round(abs(float(front[0][0] - front[1][0])) / 2, 3), round(abs(float(rear[0][0] - rear[1][0])) / 2, 3)],
       "lift": [round(float(rc[1] - fc[1]), 3), 0.0], "wheels": [key, key]}
print(json.dumps(ent)); print("wheel parts cut:", len(wheel_of), "of", len(parts))
json.dump(ent, open("/tmp/%s_entry.json" % key, "w"))
