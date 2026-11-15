"""0.2.49: lots standing on each other.
The footprint import (0.2.48) put back every OSM-named lot that no footprint picked up, where OSM had it - and some of
those stand on a real footprint that was already taken (two shops in one building). Where two lots overlap by more
than 30% of the smaller one, keep one: a trade / servo / mall / named-landmark lot wins, else the real footprint (the
earlier lot). What the dropped one was (a shop type, or a school, police station...) is handed to the one kept.
Also: Mitre 10 Murwillumbah runs from Wollumbin St through to Cliffords Lane - its roof and the one behind are one
building."""
import json, math, sys
from shapely.geometry import Polygon
from shapely.strtree import STRtree
ROOT = "/home/claude/game"
B = json.load(open(ROOT + "/assets/world/buildings.json"))
L = B["lots"]
def poly(l):
    x, z, y, w, d = l[1], l[2], l[3], l[4], l[5]
    c, s = math.cos(y), math.sin(y)
    return Polygon([(x + c * lx + s * lz, z - s * lx + c * lz) for lx, lz in ((-w/2, -d/2), (w/2, -d/2), (w/2, d/2), (-w/2, d/2))])
def sub(l): return str(l[7]) if len(l) > 7 else ""
def special(l):
    s = sub(l)
    return l[0] == "mall" or ":" in s or s.startswith("servo/") or s == "5g" or s.startswith("hardware") or len(s.split("/")) > 3
GENERIC = ("shop", "qlder", "brick", "two_storey", "cottage", "shed", "machine_shed")
P = [poly(l) for l in L]
tree = STRtree(P)
drop = set(); stats = {"dropped": 0, "type handed on": 0, "kind handed on": 0}
for i, p in enumerate(P):
    if i in drop: continue
    for j in tree.query(p):
        j = int(j)
        if j <= i or j in drop: continue
        a = p.intersection(P[j]).area
        if a < 0.3 * min(p.area, P[j].area): continue
        keep, lose = (j, i) if special(L[j]) and not special(L[i]) else (i, j)
        k, o = L[keep], L[lose]
        if o[0] not in GENERIC and k[0] in GENERIC:
            # the school / police station / pub takes the real roof
            L[keep] = [o[0]] + k[1:7] + ([sub(o)] if sub(o) else []); stats["kind handed on"] += 1
        elif k[0] == "shop" and o[0] == "shop" and not special(k):
            ts, to = sub(k).split("/"), sub(o).split("/")
            if (len(ts) < 2 or ts[0] == "") and to[0] != "":
                ts = ts if len(ts) > 1 else ["", "0", "2.8"]
                ts[0] = to[0]; L[keep] = k[:7] + ["/".join(ts)]; stats["type handed on"] += 1
        drop.add(lose); stats["dropped"] += 1
        if lose == i: break
# Mitre 10: one building, Wollumbin St to Cliffords Lane
for i, l in enumerate(L):
    if i in drop or "MITRE 10" not in sub(l) or math.hypot(l[1] + 689, l[2] + 146) > 30: continue
    yaw = l[3]; fx, fz = math.sin(yaw), math.cos(yaw)           # its front, toward Wollumbin St
    front = (l[1] + fx * l[5] / 2, l[2] + fz * l[5] / 2)
    for j, o in enumerate(L):
        if j == i or j in drop: continue
        # the lot behind it, back to back
        bx, bz = l[1] - fx * (l[5] / 2 + o[5] / 2), l[2] - fz * (l[5] / 2 + o[5] / 2)
        if math.hypot(o[1] - bx, o[2] - bz) < 4.0 and abs(o[4] - l[4]) < 3.0:
            back = (o[1] - fx * o[5] / 2, o[2] - fz * o[5] / 2)
            D = math.hypot(front[0] - back[0], front[1] - back[1])
            L[i] = [l[0], round((front[0] + back[0]) / 2, 2), round((front[1] + back[1]) / 2, 2), l[3], l[4], round(D, 2)] + l[6:]
            drop.add(j); print("Mitre 10: through to Cliffords Lane, %.1f m deep (lot %d joined)" % (D, j))
            break
B["lots"] = [l for i, l in enumerate(L) if i not in drop]
B["ver"] = B["ver"] + "+dedupe1"
json.dump(B, open(ROOT + "/assets/world/buildings.json", "w"), separators=(",", ":"))
print(stats, "lots:", len(B["lots"]))
