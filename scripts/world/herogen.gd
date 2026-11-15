class_name HeroGen
extends RefCounted
## Landmark buildings drawn from the user's own pictures (0.2.52), built by the same room machinery as everything
## else so they have their insides (rooms, doors, stairs, furniture, loot):
##   imperial: the Imperial Hotel, Murwillumbah. Two storeys, pink render, three Dutch gables (IMPERIAL HOTEL on the
##             middle one, an arched window in the big end one), tiled hip roof, an open arched verandah upstairs with
##             diamond panels under the arches, a long street awning on tie rods lettered GELATO & CO, RESTAURANT,
##             PUB, BOTTLE SHOP, dark stone at the foot of the piers. Inside: gelato shop, restaurant, public bar,
##             bottle shop across the front; kitchen, cool room, toilets, office behind; the stair up to a corridor of
##             hotel rooms and the verandah.
##   austral:  the Austral Cafe & Bakery, Murwillumbah St. Art deco, white: a tiled band along the parapet, a row of
##             big steel-framed windows upstairs under a slab hood, a fluted panel above the awning, the arched sign
##             on the awning, glass across the front and tables out on the footpath.
##   riverview: the Riverview Hotel (home). A weatherboard pub up on posts with a deck all the way round, solar
##             panels on the roof, BREW WITH A VIEW on the wall, and the Bottlemart drive-through beside it.
## The lot's sub picks it: a shop's 5th part ("pub/2/3.5/IMPERIAL HOTEL/imperial"), a civic's after a bar
## ("RIVERVIEW HOTEL|riverview").

const GOLD := Color(0.86, 0.72, 0.38)

# ================================================================================================ the Imperial
## The rooms (called from ShopGen.plan_into once the shop's own settings are made)
static func imperial_plan(p: Dictionary, w: float, d: float) -> void:
	p.two = true
	p.sub = "pub"
	p.clad = "plaster:pink"
	p.trim = "trim:white"
	p.roof = {"type": "hip", "mat": "roof_tile"}
	p.front.awning = true
	p.front.verandah = false
	p.front.awn_d = 3.2
	p.front.recess = false
	p.floors.clear()
	var GH := ShopGen.GH
	var UY := ShopGen.UY
	var x := -w / 2
	var fz := d / 2 - 11.0            # the back of the front rooms
	var cz := fz - 1.6                # the passage behind them
	var L := ceilf(UY / BuildGen.RISE) * BuildGen.GOING
	var sx0 := w / 2 - 12.0           # the stair, beside the bottle shop's cool room
	var sx1 := sx0 + 1.2
	var st1 := cz                     # its foot at the passage
	var st0 := cz - L                 # its head, upstairs, at the back
	var g := []
	# the front rooms, left to right as you look at it from the street (the street is +z, left is -x)
	var cuts := [x, x + 6.0, x + 17.0, w / 2 - 10.0, w / 2]
	var fronts := [["shop", "gelato"], ["dining", ""], ["shop", "bar"], ["shop", "bottle"]]
	for i in 4:
		var r := {"x0": cuts[i], "z0": fz, "x1": cuts[i + 1], "z1": d / 2, "type": fronts[i][0], "imp": fronts[i][1]}
		if fronts[i][1] == "bar": r["hub"] = true
		if fronts[i][0] == "shop": r["sub"] = "pub" if fronts[i][1] != "gelato" else "cafe"
		g.append(r)
	g.append({"x0": -w / 2, "z0": cz, "x1": w / 2, "z1": fz, "type": "hall"})
	# behind the passage
	var bx := [-w / 2, -w / 2 + 6.0, -w / 2 + 17.0, -w / 2 + 24.0, -w / 2 + 28.0, sx0]
	var bt := ["store", "kitchen", "store", "toilet", "office"]
	for i in 5:
		if bx[i + 1] - bx[i] < 1.5: continue
		if bt[i] == "toilet":
			var zm := (cz - d / 2) * 0.5
			g.append({"x0": bx[i], "z0": zm, "x1": bx[i + 1], "z1": cz, "type": "toilet"})
			g.append({"x0": bx[i], "z0": -d / 2, "x1": bx[i + 1], "z1": zm, "type": "toilet"})
		else:
			g.append({"x0": bx[i], "z0": -d / 2, "x1": bx[i + 1], "z1": cz, "type": bt[i]})
	g.append({"x0": sx0, "z0": st0, "x1": sx1, "z1": st1, "type": "stair"})
	g.append({"x0": sx0, "z0": -d / 2, "x1": sx1, "z1": st0, "type": "hall"})
	g.append({"x0": sx1, "z0": -d / 2, "x1": w / 2, "z1": cz, "type": "store"})
	p.floors.append({"y": 0.0, "h": GH, "rooms": g})
	# upstairs: the verandah across the front, rooms off a corridor, the landing at the head of the stair
	var u := []
	var vz := d / 2 - 2.8
	var rz := vz - 4.6
	var uz := rz - 1.6
	u.append({"x0": -w / 2, "z0": vz, "x1": w / 2, "z1": d / 2, "type": "hall", "imp": "verandah", "nowin": true})
	var nb := maxi(3, int(w / 4.2))
	for k in nb:
		var a := snappedf(-w / 2 + w * k / nb, 0.01)
		var b := snappedf(-w / 2 + w * (k + 1) / nb, 0.01)
		u.append({"x0": a, "z0": rz, "x1": b, "z1": vz, "type": "bed"})
	u.append({"x0": -w / 2, "z0": uz, "x1": w / 2, "z1": rz, "type": "hall", "hub": true})
	# the stairwell, the landing behind it, and a passage beside it back to the corridor
	var px0 := sx0 - 1.3
	u.append({"x0": sx0, "z0": st0, "x1": sx1, "z1": st1, "type": "void"})
	u.append({"x0": sx0, "z0": st1, "x1": sx1, "z1": uz, "type": "hall"})
	u.append({"x0": sx0, "z0": st0 - 1.5, "x1": sx1, "z1": st0, "type": "hall"})
	u.append({"x0": px0, "z0": st0 - 1.5, "x1": sx0, "z1": uz, "type": "hall"})
	u.append({"x0": sx0, "z0": -d / 2, "x1": sx1, "z1": st0 - 1.5, "type": "bath"})
	u.append({"x0": px0, "z0": -d / 2, "x1": sx0, "z1": st0 - 1.5, "type": "store"})
	# rooms along the back
	var xx := -w / 2
	var kk := 0
	while px0 - xx > 2.0:
		var ww := 2.4 if kk % 3 == 2 else 4.0
		var xe := minf(xx + ww, px0)
		if px0 - xe < 2.0: xe = px0
		u.append({"x0": xx, "z0": -d / 2, "x1": xe, "z1": uz, "type": "bath" if kk % 3 == 2 else "bed"})
		xx = xe
		kk += 1
	u.append({"x0": sx1, "z0": -d / 2, "x1": w / 2, "z1": uz, "type": "bed"})
	p.floors.append({"y": UY, "h": ShopGen.UH, "rooms": u})
	p["_imp_cuts"] = cuts

## Street doors and windows (instead of ShopGen.ext_doors / windows)
static func imperial_openings(p: Dictionary) -> void:
	var w: float = p.w
	var d: float = p.d
	p["_piers"] = []
	for r in p.floors[0].rooms:
		var imp := str(r.get("imp", ""))
		if imp == "": continue
		var a := float(r.x0)
		var b := float(r.x1)
		var c := (a + b) / 2.0
		# a pair of doors in the middle (one in the gelato shop), big shop windows either side
		var dw := BuildGen.DOOR_W
		var doors_x := [c - dw / 2] if imp == "gelato" else [c - dw - 0.06, c + 0.06]
		for dx: float in doors_x:
			var op := BuildGen._add_op(r, "S", dx, dx + dw, "door", 0.0, BuildGen.DOOR_H)
			op["leaf"] = true
			op["ext"] = true
			p.ext_doors.append({"room": r, "side": "S", "c": dx + dw / 2, "front": true})
		var lo: float = doors_x[0] - 0.25
		var hi: float = doors_x[-1] + dw + 0.25
		for span in [[a + 0.45, lo], [hi, b - 0.45]]:
			var s0: float = span[0]
			var s1: float = span[1]
			if s1 - s0 < 1.0: continue
			var n := maxi(1, int((s1 - s0) / 2.6))
			var pw := (s1 - s0 - 0.5 * (n - 1)) / n
			for k in n:
				var w0 := s0 + k * (pw + 0.5)
				var op := BuildGen._add_op(r, "S", w0, w0 + pw, "window", 0.6, 2.9)
				op["display"] = true
				op["fixed"] = true
				p._piers.append([w0 - 0.5, w0])
				p._piers.append([w0 + pw, w0 + pw + 0.5])
	# out the back: the kitchen door, the cool rooms' roller doors, the toilets' windows
	for r in p.floors[0].rooms:
		if absf(float(r.z0) + d / 2) > 0.02: continue
		var a := float(r.x0)
		var b := float(r.x1)
		var c := (a + b) / 2.0
		match str(r.type):
			"kitchen", "office", "hall":
				if b - a > 1.1:
					var op := BuildGen._add_op(r, "N", c - BuildGen.DOOR_W / 2, c + BuildGen.DOOR_W / 2, "door", 0.0, BuildGen.DOOR_H)
					op["leaf"] = true
					op["ext"] = true
					p.ext_doors.append({"room": r, "side": "N", "c": c, "front": false})
			"store":
				if b - a > 4.0:
					var op := BuildGen._add_op(r, "N", c - 1.6, c + 1.6, "roller", 0.0, 3.0)
					op["ext"] = true
					op["open_frac"] = 0.3
			"toilet":
				BuildGen._add_op(r, "N", c - 0.3, c + 0.3, "window", 1.6, 2.1)
	# upstairs: arches along the verandah (open, a sill wall under), windows in the two end blocks, and
	# ordinary windows out the back and the ends
	var cuts: Array = p._imp_cuts
	var ex0: float = -w / 2 + 3.6          # the left end block
	var ex1: float = w / 2 - 7.5           # the right end block
	for r in p.floors[1].rooms:
		var a := float(r.x0)
		var b := float(r.x1)
		if str(r.get("imp", "")) == "verandah":
			var n := maxi(6, int((ex1 - ex0) / 2.5))
			var pw := (ex1 - ex0) / n
			for k in n:
				var o0 := ex0 + k * pw + 0.32
				var op := BuildGen._add_op(r, "S", o0, o0 + pw - 0.64, "open", 0.95, 2.75)
				op["ext"] = true
			BuildGen._add_op(r, "S", -w / 2 + 1.3, -w / 2 + 2.3, "window", 0.9, 2.5)
			BuildGen._add_op(r, "S", ex1 + 2.6, ex1 + 4.4, "window", 0.7, 2.6)
			continue
		for side in ["N", "W", "E"]:
			if not BuildGen._ext_side(p, r, side): continue
			var span := (b - a) if side == "N" else (float(r.z1) - float(r.z0))
			var lo := a if side == "N" else float(r.z0)
			if r.type == "bath":
				BuildGen._add_op(r, side, lo + span / 2 - 0.3, lo + span / 2 + 0.3, "window", 1.6, 2.2)
			elif r.type in ["bed", "hall"] and span > 1.8:
				BuildGen._add_op(r, side, lo + span / 2 - 0.55, lo + span / 2 + 0.55, "window", 0.9, 2.2)

## Everything above and in front of the walls: roof, gables, arches, awning, stone, lettering
static func imperial_top(p: Dictionary, g: BuildGen.Geo, top_h: float, ground: Callable, lod: bool) -> void:
	var w: float = p.w
	var d: float = p.d
	var T := BuildGen.T_OUT
	var clad: String = p.clad
	var trim: String = p.trim
	if not p.has("_labels"): p["_labels"] = []
	var x0 := -w / 2 - T
	var x1 := w / 2 + T
	var zf := d / 2 + T
	var UY := ShopGen.UY
	# the tiled hip roof
	_hip(g, "roof_tile:brick_dark:uv", w + 2 * T, d + 2 * T, top_h + 0.05, deg_to_rad(24.0), 0.45)
	g.aabb(trim, Vector3(x0 - 0.45, top_h - 0.2, zf), Vector3(x1 + 0.45, top_h + 0.06, zf + 0.45), false)    # fascia
	# the string course at the upstairs floor, and the cornice under the eaves
	g.aabb(trim, Vector3(x0, UY - 0.14, zf), Vector3(x1, UY + 0.02, zf + 0.08), false)
	g.aabb(clad, Vector3(x0, top_h - 0.45, zf), Vector3(x1, top_h - 0.2, zf + 0.06), false)
	# the three gables
	var gx := [[-w / 2 + 1.8, 1.8, 2.3, "", false], [-w / 2 + w * 0.36, 2.7, 2.9, "IMPERIAL\nHOTEL", false], [w / 2 - 3.75, 3.75, 3.8, "", true]]
	for gg in gx:
		_dutch_gable(p, g, float(gg[0]), float(gg[1]), float(gg[2]), top_h - 0.45, zf, clad, trim, str(gg[3]), bool(gg[4]), lod)
	# the arches over the verandah openings: the corners of each opening filled in a curve, a keystone, and a
	# panel of diamonds in the sill wall under it
	for r in p.floors[1].rooms:
		if str(r.get("imp", "")) != "verandah": continue
		for op in r.ops.S:
			if op.kind != "open": continue
			var a := float(op.a)
			var b := float(op.b)
			var yt := UY + float(op.y1)
			var hw := (b - a) / 2.0
			var rise := minf(0.75, hw)
			if not lod:
				var n := 7
				for k in n:
					var t0 := float(k) / n
					var t1 := float(k + 1) / n
					var xm := (t0 + t1) * 0.5
					# a circular segment: how far down from the top of the opening the arch comes at this x
					var dy := rise * (1.0 - sqrt(maxf(0.0, 1.0 - pow(1.0 - xm, 2))))
					for s: float in [-1.0, 1.0]:
						var xa := a + hw + s * hw * (1.0 - t1) if s > 0 else a + hw * t0
						var xb := a + hw + s * hw * (1.0 - t0) if s > 0 else a + hw * t1
						if s > 0:
							xa = b - hw * t1
							xb = b - hw * t0
						g.aabb(clad, Vector3(minf(xa, xb), yt - dy - 0.02, zf - T * 2 - 0.02), Vector3(maxf(xa, xb), yt, zf + 0.01), false)
				g.aabb(trim, Vector3(a + hw - 0.12, yt - 0.18, zf), Vector3(a + hw + 0.12, yt + 0.12, zf + 0.06), false)
				# diamonds in the panel under the opening
				var nd := maxi(2, int((b - a) / 0.55))
				for k in nd:
					var dx := a + (b - a) * (k + 0.5) / nd
					g.box("trim:white", Transform3D(Basis(Vector3.BACK, PI / 4), Vector3(dx, UY + 0.45, zf + 0.015)), Vector3(0.2, 0.2, 0.03), false)
			g.aabb(trim, Vector3(a - 0.04, UY + 0.88, zf - 0.2), Vector3(b + 0.04, UY + 0.95, zf + 0.04), false)     # the sill
	# dark stone at the foot of the piers between the shop windows, and on the end walls of the front
	var piers: Array = p.get("_piers", [])
	piers.append([x0, x0 + 0.5])
	piers.append([x1 - 0.5, x1])
	for pr in piers:
		g.aabb("tile:black", Vector3(float(pr[0]), 0.0, zf), Vector3(float(pr[1]), 1.15, zf + 0.04), false)
	# the street awning: tie rods up to the wall, a deep fascia lettered for what's behind it
	var ad := float(p.front.get("awn_d", 3.2))
	var ze := zf + ad
	var ya := ShopGen.AWN_Y + 0.4
	g.aabb("trim:cream", Vector3(x0, ya, zf), Vector3(x1, ya + 0.04, ze))
	BuildGen._roof_quad(g, "tin_rust:white:uv", Vector3(x0, ya + 0.32, zf), Vector3(x1, ya + 0.32, zf), Vector3(x1, ya + 0.18, ze), Vector3(x0, ya + 0.18, ze))
	g.aabb("trim:charcoal", Vector3(x0, ya - 0.22, ze - 0.06), Vector3(x1, ya + 0.3, ze), false)
	for sx in [x0, x1 - 0.05]:
		g.aabb("trim:charcoal", Vector3(sx, ya - 0.05, zf), Vector3(sx + 0.05, ya + 0.3, ze), false)
	if not lod:
		var nr := int((x1 - x0) / 3.2)
		for k in nr + 1:
			var rx := x0 + 0.4 + (x1 - x0 - 0.8) * k / nr
			ShopGen._rod(g, Vector3(rx, UY + 2.2, zf + 0.02), Vector3(rx, ya + 0.26, ze - 0.12), 0.018)
		var cuts: Array = p._imp_cuts
		var words := ["GELATO & CO", "RESTAURANT", "PUB", "BOTTLE SHOP"]
		for i in 4:
			var cx := (float(cuts[i]) + float(cuts[i + 1])) / 2.0
			var span := float(cuts[i + 1]) - float(cuts[i])
			ShopGen._label(p, Vector3(cx, ya + 0.04, ze + 0.02), words[i], 0.34, span * 0.7, 0.0, GOLD)
		# the side entry: an old steel frame out over the footpath by the restaurant
		var ex := float(cuts[1]) + 1.2
		for fx: float in [ex - 1.6, ex + 1.6]:
			for fz: float in [zf + 0.4, ze - 0.3]:
				var gy: float = ground.call(fx, fz)
				g.aabb("trim:terracotta", Vector3(fx - 0.05, gy, fz - 0.05), Vector3(fx + 0.05, ya - 0.2, fz + 0.05), false)
		g.aabb("trim:terracotta", Vector3(ex - 1.7, ya - 0.3, zf + 0.3), Vector3(ex + 1.7, ya - 0.2, ze - 0.2), false)

## A Dutch gable on the front: the wall carried up past the eaves, stepping in at the shoulders in a curve, a round
## top, a cap along its edge, an emblem; lettering or an arched window in it
static func _dutch_gable(p: Dictionary, g: BuildGen.Geo, cx: float, hw: float, gh: float, y0: float, zf: float, clad: String, trim: String, text: String, arch: bool, lod: bool) -> void:
	var th := 0.35
	var zb := zf - th
	var y1 := y0 + gh * 0.5          # the body, straight up
	var y2 := y0 + gh * 0.78         # the shoulders, in to the neck
	var hn := hw * 0.5               # the neck's half width
	var n := 10
	var prev_y := y0
	var prof := []
	for k in n + 1:
		var y := y0 + (gh + hn * 0.6) * k / n
		var h: float
		if y <= y1: h = hw
		elif y <= y2:
			var t := (y - y1) / (y2 - y1)
			h = lerpf(hw, hn, 1.0 - cos(t * PI * 0.5))       # an ogee-ish sweep in
		elif y <= y0 + gh: h = hn
		else:
			var t := (y - (y0 + gh)) / (hn * 0.6)
			h = hn * sqrt(maxf(0.0, 1.0 - t * t))             # the round top
		prof.append([y, h])
	for k in n:
		var ya: float = prof[k][0]
		var yb: float = prof[k + 1][0]
		var h := minf(float(prof[k][1]), float(prof[k + 1][1])) if k >= n / 2 else float(prof[k][1])
		if h < 0.05: continue
		g.aabb(clad, Vector3(cx - h, ya, zb), Vector3(cx + h, yb, zf + 0.02))
		if not lod:
			g.aabb(trim, Vector3(cx - h - 0.04, yb - 0.06, zb - 0.02), Vector3(cx - h + 0.06, yb + 0.02, zf + 0.06), false)
			g.aabb(trim, Vector3(cx + h - 0.06, yb - 0.06, zb - 0.02), Vector3(cx + h + 0.04, yb + 0.02, zf + 0.06), false)
	if lod: return
	# the emblem near the top
	var ey := y0 + gh * 0.86
	g.aabb("trim:charcoal", Vector3(cx - 0.18, ey - 0.25, zf + 0.02), Vector3(cx + 0.18, ey + 0.2, zf + 0.06), false)
	for s: float in [-1.0, 1.0]:
		g.box("trim:charcoal", Transform3D(Basis(Vector3.BACK, s * 0.5), Vector3(cx + s * 0.38, ey, zf + 0.04)), Vector3(0.36, 0.06, 0.03), false)
	if text != "":
		ShopGen._label(p, Vector3(cx, y0 + gh * 0.42, zf + 0.04), text, 0.32, hw * 1.5, 0.0, Color(0.28, 0.26, 0.28))
	if arch:
		# an arched window high in the big end gable
		var aw := 0.75
		var ay0 := y0 - 0.2
		var ay1 := y0 + gh * 0.55
		g.aabb("glass_dark", Vector3(cx - aw, ay0, zf + 0.01), Vector3(cx + aw, ay1, zf + 0.025), false)
		for k in 6:
			var t := float(k) / 6.0
			var hh := aw * sqrt(1.0 - t * t)
			g.aabb("glass_dark", Vector3(cx - hh, ay1 + aw * t, zf + 0.01), Vector3(cx + hh, ay1 + aw * (t + 1.0 / 6.0), zf + 0.025), false)
		g.aabb("trim:white", Vector3(cx - aw - 0.1, ay0 - 0.08, zf), Vector3(cx + aw + 0.1, ay0, zf + 0.08), false)

## A hip roof over a w x d box centred on the origin, eaves at y, ridge along x (along z if d > w)
static func _hip(g: BuildGen.Geo, mk: String, w: float, d: float, y: float, pitch: float, ov: float) -> void:
	var W := w / 2 + ov
	var D := d / 2 + ov
	var along_x := w >= d
	var half := D if along_x else W
	var rise := half * tan(pitch)
	var r := (W - half) if along_x else (D - half)        # half the ridge's length
	if along_x:
		BuildGen._roof_quad(g, mk, Vector3(-r, y + rise, 0), Vector3(r, y + rise, 0), Vector3(W, y, D), Vector3(-W, y, D))
		BuildGen._roof_quad(g, mk, Vector3(r, y + rise, 0), Vector3(-r, y + rise, 0), Vector3(-W, y, -D), Vector3(W, y, -D))
		g.tri(mk, Vector3(-W, y, D), Vector3(-W, y, -D), Vector3(-r, y + rise, 0), Vector3(-1, 1, 0).normalized(), Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1))
		g.tri(mk, Vector3(W, y, -D), Vector3(W, y, D), Vector3(r, y + rise, 0), Vector3(1, 1, 0).normalized(), Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1))
	else:
		BuildGen._roof_quad(g, mk, Vector3(0, y + rise, r), Vector3(0, y + rise, -r), Vector3(W, y, -D), Vector3(W, y, D))
		BuildGen._roof_quad(g, mk, Vector3(0, y + rise, -r), Vector3(0, y + rise, r), Vector3(-W, y, D), Vector3(-W, y, -D))
		g.tri(mk, Vector3(W, y, D), Vector3(-W, y, D), Vector3(0, y + rise, r), Vector3(0, 1, 1).normalized(), Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1))
		g.tri(mk, Vector3(-W, y, -D), Vector3(W, y, -D), Vector3(0, y + rise, -r), Vector3(0, 1, -1).normalized(), Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1))

# ================================================================================================ the Austral
## Settings on top of ShopGen's (called from ShopGen.plan_into)
static func austral_plan(p: Dictionary) -> void:
	p.two = true
	p.clad = "plaster:white"
	p.trim = "trim:white"
	p.front.style = "box"
	p.front.awning = true
	p.front.awn_d = 3.0
	p.front.recess = false
	p.front.door_at = "c"
	p.front.ph = 1.3

## The row of big steel windows upstairs (instead of ShopGen's sashes)
static func austral_windows(p: Dictionary) -> void:
	var w: float = p.w
	for r in p.floors[1].rooms:
		if r.type != "lounge": continue
		var a := maxf(float(r.x0), -w / 2 + 0.35)
		var b := minf(float(r.x1), w / 2 - 0.35)
		var n := maxi(3, int((b - a) / 1.15))
		var pw := (b - a) / n
		for k in n:
			var op := BuildGen._add_op(r, "S", a + k * pw + 0.04, a + (k + 1) * pw - 0.04, "window", 0.55, 2.55)
			op["fixed"] = k % 3 != 1

## Parapet band, the hood over the windows, the fluted panel, the arched sign and the tables out the front
static func austral_top(p: Dictionary, g: BuildGen.Geo, top_h: float, ground: Callable, lod: bool) -> void:
	var w: float = p.w
	var d: float = p.d
	var T := BuildGen.T_OUT
	var clad: String = p.clad
	if not p.has("_labels"): p["_labels"] = []
	var x0 := -w / 2 - T
	var x1 := w / 2 + T
	var zf := d / 2 + T
	var UY := ShopGen.UY
	var pt := top_h + float(p.front.ph)
	# the roof behind the parapet, the parapet and its tiled band
	var y0 := top_h + 0.06
	var fall := d * tan(deg_to_rad(3.0))
	BuildGen._roof_quad(g, "tin:white:uv", Vector3(-w / 2, y0 + fall, d / 2 - 0.2), Vector3(w / 2, y0 + fall, d / 2 - 0.2), Vector3(w / 2, y0, -d / 2 - T - 0.35), Vector3(-w / 2, y0, -d / 2 - T - 0.35))
	for sx in [-w / 2 - T, w / 2]:
		g.aabb(clad, Vector3(sx, top_h, -d / 2 - T), Vector3(sx + T, y0 + fall + 0.2, d / 2 - 0.2), false)
	g.aabb(clad, Vector3(x0, top_h, d / 2 - 0.2), Vector3(x1, pt, zf))
	g.aabb("trim:white", Vector3(x0 - 0.03, pt, d / 2 - 0.23), Vector3(x1 + 0.03, pt + 0.06, zf + 0.05), false)
	# the wall up the sides of the front, a little proud, like the real one's piers
	for px: float in [x0, x1 - 0.55]:
		g.aabb(clad, Vector3(px, 0.0, zf), Vector3(px + 0.55, pt + 0.08, zf + 0.14))
	if not lod:
		var by0 := pt - 0.62
		var by1 := pt - 0.22
		g.aabb("trim:cream", Vector3(x0 + 0.6, by0, zf), Vector3(x1 - 0.6, by1, zf + 0.012), false)
		var nt := int((x1 - x0 - 1.2) / 0.42)
		for k in nt + 1:
			var tx := x0 + 0.6 + (x1 - x0 - 1.2) * k / nt
			g.aabb("trim:grey", Vector3(tx - 0.012, by0, zf + 0.012), Vector3(tx + 0.012, by1, zf + 0.02), false)
		for ty: float in [by0, by1]:
			g.aabb("trim:grey", Vector3(x0 + 0.6, ty - 0.012, zf + 0.012), Vector3(x1 - 0.6, ty + 0.012, zf + 0.02), false)
	# the slab hood over the upstairs windows
	g.aabb(clad, Vector3(x0 + 0.55, UY + 2.7, zf), Vector3(x1 - 0.55, UY + 2.86, zf + 0.6))
	g.aabb("trim:grey", Vector3(x0 + 0.55, UY + 2.66, zf + 0.56), Vector3(x1 - 0.55, UY + 2.7, zf + 0.6), false)
	# the fluted panel between the awning and the windows
	var fy0 := ShopGen.AWN_Y + 0.45
	var fy1 := UY + 0.5
	g.aabb(clad, Vector3(x0 + 0.55, fy0, zf), Vector3(x1 - 0.55, fy1, zf + 0.05), false)
	if not lod:
		var groups := maxi(3, int((x1 - x0) / 2.6))
		for gi in groups:
			var gc := x0 + 0.55 + (x1 - x0 - 1.1) * (gi + 0.5) / groups
			for k in 5:
				var fx := gc + (k - 2) * 0.12
				g.aabb("trim:grey", Vector3(fx - 0.02, fy0 + 0.1, zf + 0.05), Vector3(fx + 0.02, fy1 - 0.1, zf + 0.07), false)
	# the awning
	var ad := float(p.front.awn_d)
	var ze := zf + ad
	var ya := ShopGen.AWN_Y
	g.aabb("trim:cream", Vector3(x0, ya, zf), Vector3(x1, ya + 0.04, ze))
	BuildGen._roof_quad(g, "tin:white:uv", Vector3(x0, ya + 0.36, zf), Vector3(x1, ya + 0.36, zf), Vector3(x1, ya + 0.2, ze), Vector3(x0, ya + 0.2, ze))
	g.aabb("trim:pale_blue", Vector3(x0, ya - 0.1, ze - 0.06), Vector3(x1, ya + 0.42, ze), false)
	if lod: return
	for x: float in [x0 + 0.45, x1 - 0.45, 0.0]:
		ShopGen._rod(g, Vector3(x, ya + 1.6, zf + 0.02), Vector3(x, ya + 0.3, ze - 0.12), 0.02)
	ShopGen._label(p, Vector3(0, ya + 0.16, ze + 0.02), "A Great Place To Meet & Eat", 0.22, w * 0.8, 0.0, Color(0.15, 0.15, 0.17))
	# the arched sign standing on the awning's front: a board with a round top
	var sw := minf(w * 0.55, 6.0)
	var sy0 := ya + 0.42
	var sy1 := sy0 + 0.75
	g.aabb("trim:pale_blue", Vector3(-sw / 2, sy0, ze - 0.08), Vector3(sw / 2, sy1, ze - 0.02), false)
	var ar := sw * 0.22
	for k in 6:
		var t := float(k) / 6.0
		var hh := ar * sqrt(1.0 - t * t)
		g.aabb("trim:pale_blue", Vector3(-hh, sy1 + ar * 0.6 * t, ze - 0.08), Vector3(hh, sy1 + ar * 0.6 * (t + 1.0 / 6.0), ze - 0.02), false)
	g.aabb("trim:white", Vector3(-sw / 2 - 0.04, sy0, ze - 0.09), Vector3(sw / 2 + 0.04, sy0 + 0.04, ze - 0.01), false)
	ShopGen._label(p, Vector3(0, sy0 + 0.33, ze), "CAFE & BAKERY", 0.42, sw - 0.3, 0.0, Color(0.55, 0.36, 0.2))
	ShopGen._label(p, Vector3(0, sy1 + 0.18, ze), "Austral", 0.26, ar * 1.6, 0.0, Color(0.5, 0.33, 0.18))
	# tables and chairs on the footpath
	for tx: float in [-w * 0.28, w * 0.28]:
		var tz := zf + 1.1
		var gy: float = ground.call(tx, tz)
		g.aabb("steel", Vector3(tx - 0.03, gy, tz - 0.03), Vector3(tx + 0.03, gy + 0.72, tz + 0.03), false)
		g.aabb("steel", Vector3(tx - 0.35, gy + 0.72, tz - 0.35), Vector3(tx + 0.35, gy + 0.75, tz + 0.35), false)
		for s: float in [-1.0, 1.0]:
			var cxp := tx + s * 0.65
			g.aabb("trim:black", Vector3(cxp - 0.22, gy + 0.45, tz - 0.22), Vector3(cxp + 0.22, gy + 0.48, tz + 0.22), false)
			g.aabb("trim:black", Vector3(cxp + s * 0.2 - 0.02, gy + 0.48, tz - 0.22), Vector3(cxp + s * 0.2 + 0.02, gy + 0.9, tz + 0.22), false)
			for lx: float in [-0.19, 0.19]:
				for lz: float in [-0.19, 0.19]:
					g.aabb("steel", Vector3(cxp + lx - 0.012, gy, tz + lz - 0.012), Vector3(cxp + lx + 0.012, gy + 0.45, tz + lz + 0.012), false)

# ================================================================================================ the Riverview
## Settings on top of CivicGen's pub (called from CivicGen.plan_into)
static func riverview_plan(p: Dictionary, w: float, d: float) -> void:
	p.clad = "weatherboard:cream"
	p.raised = 1.3
	p.stumps = true
	p.under = false
	p.h = 3.3
	p.verandah = {"depth": 3.4, "sides": true}
	p.roof = {"type": "hip", "pitch": deg_to_rad(18.0), "mat": "tin"}
	p["sign"] = "THE RIVERVIEW HOTEL"
	# the bottle shop at the east end of the bar
	var rooms: Array = p.floors[0].rooms
	for r in rooms:
		if r.get("sub", "") == "pub" and float(r.x1) - float(r.x0) > 12.0:
			var cut := float(r.x1) - 7.0
			rooms.append({"x0": cut, "z0": float(r.z0), "x1": float(r.x1), "z1": float(r.z1), "type": "shop", "sub": "pub", "entry": true})
			r.x1 = cut
			break

## Solar panels on the roof, BREW WITH A VIEW on the wall, the Bottlemart drive-through off the east end
static func riverview_extras(p: Dictionary, g: BuildGen.Geo, top_h: float, ground: Callable, lod: bool) -> void:
	var w: float = p.w
	var d: float = p.d
	var T := BuildGen.T_OUT
	if not p.has("_labels"): p["_labels"] = []
	var pitch := float(p.roof.pitch)
	var tn := tan(pitch)
	var ov := 0.45
	var D := d / 2 + T + ov
	var W := w / 2 + T + ov
	var half := minf(D, W)
	# the panels: rows up the front and back slopes, inside the hips
	if not lod:
		for side: float in [1.0, -1.0]:
			for row in 3:
				var e := 1.4 + row * 1.9               # metres in from the eave, up the slope
				if e + 1.7 > half: break
				var span := W - e - 1.0
				var np := int(span * 2.0 / 1.1)
				for k in np:
					var px := -span + (k + 0.5) * (span * 2.0 / np)
					if k % 5 == 4: continue
					var ez := D - e - 0.85
					var y := top_h + (e + 0.85) * tn + 0.12
					g.box("glass_dark", Transform3D(Basis(Vector3.RIGHT, -pitch * side), Vector3(px, y, ez * side)), Vector3(1.0, 0.05, 1.65), false)
	# the sign board on the front wall, by the bar
	var bz := d / 2 + T + 0.02
	var by := 2.3
	g.aabb("trim:navy", Vector3(-w * 0.25 - 2.6, by - 0.35, bz), Vector3(-w * 0.25 + 2.6, by + 0.35, bz + 0.04), false)
	if not lod:
		ShopGen._label(p, Vector3(-w * 0.25, by, bz + 0.05), "BREW WITH A VIEW", 0.42, 4.9, 0.0, Color(0.95, 0.95, 0.97))
	# the drive-through: a big skillion on posts off the east end, blue fascia
	var cx0 := w / 2 + T + float(p.verandah.depth) + 0.4
	var cx1 := cx0 + 8.5
	var cz0 := -d / 2 + 2.0
	var cz1 := d / 2 + 1.5
	var ch := 4.6
	for px: float in [cx0 + 0.3, cx1 - 0.3]:
		for k in 4:
			var pz := cz0 + 0.3 + (cz1 - cz0 - 0.6) * k / 3.0
			var gy: float = ground.call(px, pz)
			g.aabb("steel", Vector3(px - 0.1, gy, pz - 0.1), Vector3(px + 0.1, ch, pz + 0.1))
	BuildGen._roof_quad(g, "tin:white:uv", Vector3(cx0, ch + 0.35, cz1), Vector3(cx1, ch + 0.35, cz1), Vector3(cx1, ch + 0.05, cz0), Vector3(cx0, ch + 0.05, cz0))
	g.aabb("trim:navy", Vector3(cx0 - 0.05, ch - 0.25, cz1), Vector3(cx1 + 0.05, ch + 0.6, cz1 + 0.08), false)
	g.aabb("trim:navy", Vector3(cx1, ch - 0.25, cz0), Vector3(cx1 + 0.08, ch + 0.6, cz1), false)
	g.aabb("trim:shell_yellow", Vector3(cx0 - 0.05, ch - 0.3, cz1 + 0.02), Vector3(cx1 + 0.05, ch - 0.25, cz1 + 0.09), false)
	if not lod:
		ShopGen._label(p, Vector3((cx0 + cx1) / 2, ch + 0.17, cz1 + 0.1), "Bottlemart", 0.55, 6.0, 0.0, Color(1.0, 0.85, 0.1))
		ShopGen._label(p, Vector3(cx1 + 0.1, ch + 0.17, (cz0 + cz1) / 2), "Bottlemart", 0.55, 6.0, PI / 2, Color(1.0, 0.85, 0.1))
	# a concrete pad under it
	var gy0: float = ground.call((cx0 + cx1) / 2, (cz0 + cz1) / 2)
	g.aabb("concrete", Vector3(cx0, gy0 - 0.2, cz0), Vector3(cx1, gy0 + 0.05, cz1), false)
