#!/usr/bin/env python3
"""Stand a downloaded vehicle .glb upright, in metres, long side along Z, sitting on y=0, centred: in place.

glb_upright.py file.glb [--len 4.8] [--flip] [--other]

Sketchfab exports disagree about up (some come Z-up, standing on their tail) and units (cm, m). The long side is
the longest extent; up is whichever of the other two axes the tyres sit furthest off-centre along (they're at the
bottom), else the shorter one. Metres: an extent over 30 is taken as centimetres; --len forces the length.
Wraps the scene in one new root node, so nothing inside is touched (named wheel nodes stay findable).
"""
import json, re, struct, sys
import numpy as np

TYRE = re.compile(r"tire|tyre|rubber|wheel", re.I)


def load(p):
    b = open(p, "rb").read()
    jl = struct.unpack("<I", b[12:16])[0]
    return b, json.loads(b[20:20 + jl]), 20 + jl


def node_mat(nd):
    if "matrix" in nd: return np.array(nd["matrix"], dtype=float).reshape(4, 4).T
    t = np.eye(4)
    if "scale" in nd: t = np.diag(list(nd["scale"]) + [1.0]) @ t
    if "rotation" in nd:
        x, y, z, w = nd["rotation"]
        r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                      [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                      [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        rt = np.eye(4); rt[:3, :3] = r; t = rt @ t
    if "translation" in nd:
        tt = np.eye(4); tt[:3, 3] = nd["translation"]; t = tt @ t
    return t


def positions(b, j, binoff, acc_i):
    a = j["accessors"][acc_i]; bv = j["bufferViews"][a["bufferView"]]
    if a.get("componentType") != 5126: return None      # quantized: not here (we run gltfpack with -noq)
    start = binoff + 8 + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 12)
    n = a["count"]
    buf = np.frombuffer(b, dtype=np.uint8, count=stride * (n - 1) + 12, offset=start)
    rows = np.lib.stride_tricks.as_strided(buf, shape=(n, 12), strides=(stride, 1))
    return np.ascontiguousarray(rows).view(np.float32).reshape(n, 3)


def main():
    p = sys.argv[1]
    want_len = float(sys.argv[sys.argv.index("--len") + 1]) if "--len" in sys.argv else None
    b, j, binoff = load(p)
    pts_all, pts_tyre = [], []

    def walk(i, parent):
        nd = j["nodes"][i]
        m = parent @ node_mat(nd)
        if "mesh" in nd:
            for pr in j["meshes"][nd["mesh"]]["primitives"]:
                P = positions(b, j, binoff, pr["attributes"]["POSITION"])
                if P is None: continue
                W = (m @ np.c_[P, np.ones(len(P))].T).T[:, :3]
                if len(W) > 4000: W = W[:: len(W) // 4000]
                pts_all.append(W)
                mi = pr.get("material")
                if mi is not None and TYRE.search(j["materials"][mi].get("name", "")): pts_tyre.append(W)
        for c in nd.get("children", []): walk(c, m)

    roots = j["scenes"][j.get("scene", 0)]["nodes"]
    for r in roots: walk(r, np.eye(4))
    A = np.vstack(pts_all)
    lo, hi = A.min(0), A.max(0); ext = hi - lo; ctr = (lo + hi) / 2
    longa = int(np.argmax(ext))
    others = [k for k in range(3) if k != longa]
    up, sign = None, 1.0
    if pts_tyre:
        T = np.vstack(pts_tyre)
        off = [(T[:, k].mean() - ctr[k]) / max(ext[k], 1e-6) for k in others]
        k = int(np.argmax(np.abs(off)))
        if abs(off[k]) > 0.12:
            up = others[k]; sign = -1.0 if off[k] > 0 else 1.0     # tyres low: up points away from them
    how = "tyres"
    if up is None:
        up = others[int(np.argmin([ext[k] for k in others]))]; how = "shorter"
        # which way up: more of the body's bulk sits above the axle line than below
        sign = 1.0 if np.median(A[:, up]) > ctr[up] - 0.05 * ext[up] else -1.0
    if "--other" in sys.argv:                                   # it took the side for up: use the other short axis
        up = [k for k in others if k != up][0]; how = "forced"
        sign = 1.0 if np.median(A[:, up]) > ctr[up] - 0.05 * ext[up] else -1.0
    if "--flip" in sys.argv: sign = -sign                         # it guessed upside down
    side = [k for k in range(3) if k not in (longa, up)][0]
    L = ext[longa]
    s = (want_len / L) if want_len else (0.01 if L > 30 else 1.0)
    # rotation: up -> +Y, long -> +Z, side -> +X (right-handed)
    R = np.zeros((3, 3))
    R[1, up] = sign
    R[2, longa] = 1.0
    xrow = np.cross(R[1], R[2]); R[0] = xrow
    M = np.eye(4); M[:3, :3] = R * s
    # recentre: x/z on the middle, the lowest point on y=0
    Ab = (M @ np.c_[A, np.ones(len(A))].T).T[:, :3]
    lo2, hi2 = Ab.min(0), Ab.max(0)
    M[:3, 3] = -np.array([(lo2[0] + hi2[0]) / 2, lo2[1], (lo2[2] + hi2[2]) / 2])
    j["nodes"].append({"name": "Upright", "matrix": [float(v) for v in M.T.reshape(-1)], "children": roots})
    j["scenes"][j.get("scene", 0)]["nodes"] = [len(j["nodes"]) - 1]
    js = json.dumps(j, separators=(",", ":")).encode(); js += b" " * ((4 - len(js) % 4) % 4)
    rest = b[binoff:]
    out = b[:12] + struct.pack("<I", len(js)) + b"JSON" + js + rest
    out = out[:8] + struct.pack("<I", len(out)) + out[12:]
    open(p, "wb").write(out)
    size = (hi2 - lo2)
    print(json.dumps({"up_from": how, "size_m": [round(float(v), 2) for v in size]}))


if __name__ == "__main__":
    main()
