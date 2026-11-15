#!/usr/bin/env python3
"""Service stations from OpenStreetMap (amenity=fuel, the canopies and shop buildings round each one, fetched with
Overpass on 2026-11-15 and converted to game metres: x = (lon - 153.4035024) * 111320 * cos(lat0),
z = (-28.3285718 - lat) * 110574). Writes assets/world/servos.json: per station the brand, the forecourt outline,
each canopy as a fitted rectangle, the shop as a fitted rectangle. Moves the servo landmarks (the shop model) onto the
real shop footprint, facing the canopy, adds the missing ones, and takes generated lots off the forecourts.
  python3 tools/make_servos.py
"""
import json, math
import numpy as np, cv2

S = [
 dict(name="Moo Moo Roadhouse", brand="Liberty", shop=[[8613,12510],[8621,12510],[8621,12506],[8636,12505],[8636,12507],[8646,12507],[8647,12524],[8639,12525],[8621,12526],[8613,12526]]),
 dict(name="BP Connect Chinderah", brand="BP", canopies=[[[15078,-9398],[15113,-9401],[15117,-9382],[15079,-9379]], [[15117,-9376],[15144,-9378],[15145,-9368],[15119,-9365]]],
      shop=[[15117,-9367],[15123,-9330],[15115,-9330],[15099,-9328],[15094,-9339],[15092,-9365],[15104,-9366],[15103,-9372],[15112,-9367]]),
 dict(name="Caltex", brand="Caltex", canopies=[[[665,-246],[672,-253],[663,-262],[670,-269],[690,-247],[683,-241],[678,-246],[671,-240]]],
      shop=[[671,-240],[683,-228],[673,-219],[669,-223],[666,-221],[657,-231],[654,-236],[654,-242],[656,-244],[655,-248],[659,-252],[665,-246]]),
 dict(name="Ampol", brand="Ampol", canopies=[[[555,-198],[569,-208],[578,-195],[557,-180],[552,-187],[559,-192]]],
      shop=[[557,-180],[561,-174],[552,-169],[548,-176],[544,-174],[539,-181],[548,-188],[552,-187]]),
 dict(name="BP", brand="BP", canopies=[[[479,-140],[474,-147],[481,-152],[486,-145]]], shop=[[467,-132],[479,-140],[485,-145],[495,-132],[476,-119]]),
 dict(name="BP Tweed Heads", brand="BP", canopies=[[[11993,-15780],[12023,-15776],[12022,-15768],[11992,-15773]]], shop=[[11997,-15806],[11995,-15793],[12017,-15790],[12019,-15802]]),
 dict(name="Freedom", brand="Freedom", canopies=[[[16844,-8042],[16849,-8049],[16859,-8041],[16853,-8035]]],
      shop=[[16832,-8037],[16839,-8046],[16844,-8042],[16853,-8035],[16849,-8029],[16839,-8036],[16837,-8034]]),
 dict(name="Shell", brand="Shell", canopies=[[[-115,64],[-108,67],[-99,70],[-107,89],[-112,101],[-120,95],[-114,82],[-121,79]]], shop=[[-128,101],[-124,93],[-120,95],[-112,101],[-116,108]]),
 dict(name="EG Ampol", brand="Ampol", canopies=[[[13833,-13683],[13834,-13669],[13841,-13669],[13842,-13659],[13854,-13660],[13853,-13671],[13863,-13672],[13862,-13686]]],
      shop=[[13842,-13659],[13843,-13651],[13858,-13653],[13857,-13661]]),
 dict(name="7-Eleven", brand="7-Eleven", canopies=[[[13872,-13372],[13873,-13362],[13899,-13365],[13898,-13375]]], shop=[[13879,-13350],[13879,-13340],[13897,-13342],[13896,-13351]]),
 dict(name="Shell Chinderah", brand="Shell", canopies=[[[15016,-11219],[15030,-11219],[15031,-11209],[15016,-11209]]], shop=[[15033,-11227],[15042,-11227],[15043,-11202],[15034,-11201]]),
 dict(name="Ampol Chinderah", brand="Ampol", hgv=True,
      area=[[11954,-7888],[12059,-7969],[12130,-7998],[12199,-7981],[12234,-7926],[12224,-7837],[12208,-7734],[12112,-7749],[12122,-7818],[12107,-7851],[12087,-7871],[12067,-7871],[12040,-7856],[12054,-7801],[12011,-7816],[11905,-7831],[11929,-7840],[11940,-7846],[11948,-7855],[11953,-7867],[11955,-7878]],
      canopies=[[[12157,-7859],[12170,-7843],[12166,-7840],[12178,-7827],[12204,-7849],[12193,-7863],[12177,-7850],[12164,-7865]], [[12139,-7869],[12124,-7856],[12130,-7848],[12146,-7861]], [[12145,-7915],[12149,-7919],[12158,-7908],[12154,-7905]]],
      truck=[0], shop=[[12152,-7853],[12187,-7881],[12165,-7910],[12129,-7883]]),
 dict(name="BP Hastings Point", brand="BP", canopies=[[[16607,2972],[16591,2978],[16596,2989],[16612,2982]]], shop=[[16571,2987],[16562,2966],[16570,2956],[16588,2957],[16596,2986],[16585,2993],[16579,2990]]),
 dict(name="Ampol Foodary", brand="Ampol", canopies=[[[13542,-12687],[13550,-12686],[13549,-12679],[13553,-12678],[13551,-12660],[13537,-12662],[13539,-12680],[13541,-12680]]],
      shop=[[13539,-12697],[13538,-12687],[13559,-12684],[13562,-12698],[13552,-12700],[13552,-12695]]),
 dict(name="United Tweed Heads South", brand="United", area=[[13725,-14681],[13729,-14686],[13733,-14686],[13761,-14654],[13765,-14622],[13730,-14624]]),
 dict(name="Liberty Stokers", brand="Liberty", area=[[2564,-1038],[2556,-1033],[2552,-1039],[2548,-1044],[2557,-1049],[2560,-1044]]),
 dict(name="Ampol Foodary Tweed Heads West", brand="Ampol", area=[[11680,-15653],[11715,-15666],[11719,-15665],[11721,-15663],[11736,-15621],[11699,-15607]]),
 dict(name="Shell Tweed Heads South", brand="Shell", area=[[13541,-14790],[13546,-14830],[13532,-14845],[13532,-14850],[13577,-14845],[13613,-14797],[13612,-14793],[13585,-14783]]),
 dict(name="Shell Pottsville", brand="Shell", area=[[16568,4450],[16528,4509],[16570,4516],[16602,4470]]),
]

def rect(poly):
    (cx, cz), (w, d), a = cv2.minAreaRect(np.array(poly, np.float32))
    yaw = -math.radians(a)          # cv2 angle about +y image axis; our yaw: Basis(UP, yaw)
    if w < d: w, d = d, w; yaw += math.pi / 2
    return [round(float(cx), 2), round(float(cz), 2), round(yaw, 4), round(float(w), 2), round(float(d), 2)]

out = []
for s in S:
    e = {"name": s["name"], "brand": s["brand"], "hgv": bool(s.get("hgv", False))}
    pts = []
    e["canopies"] = []
    for k, c in enumerate(s.get("canopies", [])):
        r = rect(c); r.append(1 if k in s.get("truck", []) else 0); e["canopies"].append(r); pts += c
    if "shop" in s: e["shop"] = rect(s["shop"]); pts += s["shop"]
    if "area" in s: e["area"] = s["area"]
    else:
        hull = cv2.convexHull(np.array(pts, np.float32)).reshape(-1, 2)
        c = hull.mean(0)
        grown = [[round(float(c[0] + (p[0] - c[0]) * 1.0 + (p[0] - c[0]) / max(1e-3, np.hypot(*(p - c))) * 7.0), 1),
                  round(float(c[1] + (p[1] - c[1]) * 1.0 + (p[1] - c[1]) / max(1e-3, np.hypot(*(p - c))) * 7.0), 1)] for p in hull]
        e["area"] = grown
    out.append(e)
json.dump({"v": 1, "servos": out}, open("/home/claude/game/assets/world/servos.json", "w"), separators=(",", ":"))
print("servos:", len(out))

# the old Ampol shop model is gone from every servo: each is generated now. Servo landmarks with no OSM outlines
# become generated servos too: the shop where the model stood, a canopy 13 m in front of it
L = json.load(open("/home/claude/game/assets/world/landmarks.json"))
for l in [l for l in L["landmarks"] if l["kind"] == "ampol_servo"]:
    if "Mechanical" in l.get("name", ""): continue
    if any(math.hypot(l["x"] - np.array(e["area"]).mean(0)[0], l["z"] - np.array(e["area"]).mean(0)[1]) < 60 for e in out): continue
    yaw = l["yaw"]; fx, fz = math.sin(yaw), math.cos(yaw)
    cx, cz = l["x"] + fx * 13.0, l["z"] + fz * 13.0
    e = {"name": l.get("name") or "Service station", "brand": "Liberty" if "Liberty" in l.get("name", "") else ("Shell" if "Shell" in l.get("name", "") else "Ampol"), "hgv": False,
         "canopies": [[round(cx, 2), round(cz, 2), round(yaw + math.pi / 2, 4), 18.0, 10.0, 0]],
         "shop": [l["x"], l["z"], round(yaw, 4), 14.0, 10.0]}
    c = [[l["x"] + fx * -7 + fz * 12, l["z"] + fz * -7 - fx * 12], [l["x"] + fx * -7 - fz * 12, l["z"] + fz * -7 + fx * 12],
         [l["x"] + fx * 22 - fz * 12, l["z"] + fz * 22 + fx * 12], [l["x"] + fx * 22 + fz * 12, l["z"] + fz * 22 - fx * 12]]
    e["area"] = [[round(q[0], 1), round(q[1], 1)] for q in c]
    out.append(e)
L["landmarks"] = [l for l in L["landmarks"] if l["kind"] != "ampol_servo"]
json.dump(L, open("/home/claude/game/assets/world/landmarks.json", "w"), separators=(",", ":"))
json.dump({"v": 1, "servos": out}, open("/home/claude/game/assets/world/servos.json", "w"), separators=(",", ":"))
print("servos with generated ones:", len(out))

# generated lots off the forecourts
B = json.load(open("/home/claude/game/assets/world/buildings.json"))
def inside(p, poly):
    return cv2.pointPolygonTest(np.array(poly, np.float32), (float(p[0]), float(p[1])), False) >= 0
keep = []; gone = 0
for l in B["lots"]:
    if l[0] not in ("mall", "tower") and not (len(l) > 7 and str(l[7]).startswith("servo/")) and any(inside((l[1], l[2]), e["area"]) for e in out):
        gone += 1; continue
    keep.append(l)
# each servo's shop: a ShopGen "servo" lot, its front (+z) to the canopy, sized to the real building's footprint
for e in out:
    if "shop" not in e: continue
    cx, cz, ry, w, d = e["shop"]
    tgt = e["canopies"][0][:2] if e["canopies"] else list(np.array(e["area"]).mean(0))
    face = math.atan2(tgt[0] - cx, tgt[1] - cz)
    # snap the facing to the footprint's sides: the long axis is along ry (x of the rect)
    best = min(range(4), key=lambda k: abs(math.atan2(math.sin(face - (ry + k * math.pi / 2)), math.cos(face - (ry + k * math.pi / 2)))))
    yaw = ry + best * math.pi / 2
    lw, ld = (d, w) if best % 2 == 0 else (w, d)
    lw = max(10.0, min(lw, 30.0)); ld = max(8.0, min(ld, 20.0))
    keep.append(["shop", round(cx, 2), round(cz, 2), round(yaw, 4), round(lw, 2), round(ld, 2), float(abs(hash(e["name"])) % 100000), "servo/1/0/" + e["brand"]])
B["lots"] = keep; B["ver"] += "+servos2"
json.dump(B, open("/home/claude/game/assets/world/buildings.json", "w"), separators=(",", ":"))
print("lots taken off forecourts", gone)
