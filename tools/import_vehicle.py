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
# 0.2.64: a part that holds both tyres on one side (one mesh, two wheels: the VZ ute) is split into its pieces,
# grouped front and back, so each wheel can be found and cut
split = []
for n, m in parts:
    e = np.ptp(m.vertices, 0); c = (m.vertices.min(0) + m.vertices.max(0)) / 2
    if e[2] > 1.6 * e[1] and e[1] < 1.4 and e[0] < 0.6 * e[1] and abs(c[0]) > 0.3 * np.ptp(np.vstack([q.vertices for _, q in parts])[:, 0]) / 2:
        comps = m.split(only_watertight=False)
        if len(comps) > 1:
            groups = {}
            for q in comps:
                cz = (q.vertices[:, 2].min() + q.vertices[:, 2].max()) / 2
                groups.setdefault(cz > c[2], []).append(q)
            for k, qs in groups.items(): split.append((n + ("_f" if k else "_r"), trimesh.util.concatenate(qs)))
            print("split", n, "into", len(groups))
            continue
    split.append((n, m))
parts = split
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
# 0.2.64: per corner, the tyre (the wheel part reaching furthest out) and the rim (the rest): some models have no
# sidewall on the tyre part, it's a ring in some big shared mesh, which then stayed on the body round the wheel.
# Anything of the body in the band between the rim's edge and the tyre's tread at a wheel is cut out, and the wheel
# model gets a sidewall made for it
band = {}
for k, (i, c0, d0) in corners.items():
    rim_r, tyre_in, half_w = 0.0, d0 / 2, 0.0
    tyre_j, best = None, -1.0
    for j, kk in wheel_of.items():
        if kk != k: continue
        v = parts[j][1].vertices; r = np.hypot(v[:, 1] - c0[1], v[:, 2] - c0[2])
        if r.min() > 0.75 * d0 / 2:                        # a tyre piece (tread, shoulders): out near the edge
            tyre_in = min(tyre_in, r.min()); half_w = max(half_w, np.ptp(v[:, 0]) / 2)
            if r.min() > best: best, tyre_j = r.min(), j
        else:
            rim_r = max(rim_r, r.max())
    band[k] = (c0, rim_r, tyre_in, half_w, d0 / 2, tyre_j)
cut_faces = 0
for j, (n, m) in enumerate(parts):
    if j in wheel_of: continue
    keep = np.ones(len(m.faces), bool)
    fcen = m.triangles_center
    for k, (c0, rim_r, tyre_in, half_w, R, tj) in band.items():
        if tyre_in - rim_r < 0.02 * R * 2: continue
        r = np.hypot(fcen[:, 1] - c0[1], fcen[:, 2] - c0[2])
        hit = (r > rim_r * 0.98) & (r < R * 1.03) & (np.abs(fcen[:, 0] - c0[0]) < half_w + 0.03)
        keep &= ~hit
    if not keep.all():
        cut_faces += int((~keep).sum())
        m.update_faces(keep); m.remove_unreferenced_vertices()
print("body faces cut in the wheel bands:", cut_faces)
out = trimesh.Scene()
for j, (n, m) in enumerate(parts):
    if j in wheel_of or len(m.faces) == 0: continue
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
# the made sidewall (both faces), in the tyre's own material, if the tyre part has none
c0, rim_r, tyre_in, half_w, R, tj = band[wk]
if tyre_in - rim_r > 0.02 * R * 2 and tj is not None:
    a0, a1 = rim_r * 0.97 / d, tyre_in * 1.01 / d
    hw = half_w * 0.9 / d
    seg = 48
    V, F = [], []
    for side in (-1.0, 1.0):
        base = len(V)
        for i in range(seg):
            t = 2 * np.pi * i / seg
            V.append([a0 * np.cos(t), a0 * np.sin(t), side * hw]); V.append([a1 * np.cos(t), a1 * np.sin(t), side * hw])
        for i in range(seg):
            q0, q1 = base + 2 * i, base + 2 * ((i + 1) % seg)
            f = [[q0, q1, q0 + 1], [q1, q1 + 1, q0 + 1]]
            if side < 0: f = [[x[0], x[2], x[1]] for x in f]
            F += f
    sw = trimesh.Trimesh(np.array(V), np.array(F), process=False)
    tm_ = parts[tj][1]
    try: sw.visual = trimesh.visual.TextureVisuals(material=tm_.visual.material)
    except Exception: pass
    ws.add_geometry(sw, node_name="%s_sidewall" % key)
    print("made a sidewall:", round(a0, 3), "to", round(a1, 3))
ws.export(G + "/wheels/%s.glb" % key)
r_f = corners[(True, True)][2] / 2; r_r = corners[(True, False)][2] / 2
ent = {"name": title, "glb": gname, "cls": cls, "kg": kg, "ax_f": round(float(fc[2] - mid_z), 3), "ax_r": round(float(rc[2] - mid_z), 3),
       "min": [round(float(x), 4) for x in mn], "ext": [round(float(x), 4) for x in (mx - mn)],
       "seat": [round(float(fc[2] - mid_z) - 1.25, 3), 0.15, 0.38], "ride": 0.0, "tyre_r": [round(float(r_f), 3), round(float(r_r), 3)],
       "track": [round(abs(float(front[0][0] - front[1][0])) / 2, 3), round(abs(float(rear[0][0] - rear[1][0])) / 2, 3)],
       "lift": [round(float(rc[1] - fc[1]), 3), 0.0], "wheels": [key, key]}
print(json.dumps(ent)); print("wheel parts cut:", len(wheel_of), "of", len(parts))
json.dump(ent, open("/tmp/%s_entry.json" % key, "w"))
