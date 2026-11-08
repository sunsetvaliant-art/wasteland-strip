class_name ShopGen
extends RefCounted
## Main-street shops, after Murwillumbah St (docs/SHOPS.md): hard on the footpath with shared side walls, a tall
## parapet hiding a low skillion roof, a cantilever awning on tie rods over the footpath (or a posted verandah with a
## balcony on a pub), highlight windows above the awning, display windows on tiled stall boards either side of a
## recessed entry, and painted render in heritage colours with the trim picked out.
## Inside: the shop floor at the front, a storeroom, toilet and back door behind; two-storey ones have their own street
## door and a long stair up to a flat over the shop.
## BuildGen calls in here for kind "shop"; same local frame (front +z, y = 0 the shop floor).

const GH := 4.2          # ground storey (floor to ceiling)
const UY := 4.5          # the upstairs floor
const UH := 3.0
const AWN_Y := 3.0       # awning soffit
const AWN_D := 2.8
const STRIP := 1.1       # the side passage to the stairs on a two-storey one
const SUBS := ["general", "general", "chemist", "hardware", "grocer", "grocer", "cafe", "cafe", "newsagent", "clothes", "clothes", "sports"]
const TITLES := {
	"general": ["GENERAL STORE", "EMPORIUM", "STORE", "MIXED BUSINESS"], "chemist": ["CHEMIST", "PHARMACY"],
	"hardware": ["HARDWARE", "IRONMONGERY"], "grocer": ["GROCER", "BUTCHER", "BAKERY", "FRUIT & VEG"],
	"cafe": ["CAFE", "MILK BAR", "REFRESHMENT ROOMS"], "newsagent": ["NEWSAGENCY", "BOOKS & NEWS"],
	"clothes": ["DRAPERY", "OUTFITTERS", "OP SHOP", "MENSWEAR"], "sports": ["SPORTS STORE", "GUNS & TACKLE"],
	"pub": ["HOTEL"], "bank": ["BANK"]}
const SURNAMES := ["MORRIS", "O'CONNELL", "HARDING", "BAXTER", "PRYOR", "LACEY", "QUINN", "WHITTAKER", "FRASER", "DOOLAN",
	"KEMP", "MACKAY", "BRENNAN", "SAUNDERS", "TULLY", "CALLAGHAN", "PEARCE", "NOLAN", "RYDER", "HOLT"]
const PUBS := ["ROYAL HOTEL", "COMMERCIAL HOTEL", "CRITERION HOTEL", "EXCHANGE HOTEL", "TATTERSALLS HOTEL", "RAILWAY HOTEL", "FEDERAL HOTEL"]
const BANKS := ["FARMERS & GRAZIERS BANK", "NORTH COAST SAVINGS BANK", "CANE GROWERS BANK"]
const FACADE := ["cream", "white", "sage", "terracotta", "mustard", "pale_blue", "pink", "heritage", "cream", "white", "sand"]
const TRIM := ["white", "cream", "heritage", "maroon", "navy", "charcoal", "terracotta", "mustard"]

# ------------------------------------------------------------------------------------------------ plan
## Fill in a "shop" plan. sub: "chemist", "pub/2" (levels after the slash), or "" to pick
static func plan_into(p: Dictionary, w: float, d: float, rng: RandomNumberGenerator, sub: String) -> void:
	# the lot is the outside of the walls (next door's wall is right there): the frame goes inside it
	w -= 2.0 * BuildGen.T_OUT
	d -= 2.0 * BuildGen.T_OUT
	p.w = w
	p.d = d
	var parts := sub.split("/")
	var s: String = parts[0] if parts[0] != "" else SUBS[rng.randi() % SUBS.size()]
	var lv := int(parts[1]) if parts.size() > 1 else 0
	var room := float(parts[2]) if parts.size() > 2 else AWN_D       # footpath to the kerb, for the awning
	var two: bool
	if s == "pub": two = true
	elif lv >= 2: two = true
	elif lv == 1: two = false
	else: two = rng.randf() < (0.6 if s == "bank" else 0.3)
	if d < 12.0 or w < 5.0: two = false
	if s == "pub" and not two: s = "cafe"
	p.sub = s
	p.two = two
	p.raised = 0.15
	var ft: String = FACADE[rng.randi() % FACADE.size()]
	var brick := rng.randf() < 0.18 and s not in ["bank", "pub"]
	p.clad = "brick" if brick else "plaster:" + ft
	var tt: String = TRIM[rng.randi() % TRIM.size()]
	if tt == ft: tt = "white" if ft != "white" else "heritage"
	p.trim = "trim:" + tt
	p.roof = {"type": "shop", "mat": "tin" if rng.randf() < 0.6 else "tin_rust"}
	p.h = GH
	p.stair_rise = UY
	var year := 1908 + rng.randi() % 32
	var style: String
	if s == "bank": style = "pediment"
	elif brick and rng.randf() < 0.5: style = "box"
	elif year >= 1928: style = ["stepped", "curved", "flat"][rng.randi() % 3]
	elif year < 1916: style = ["pediment", "flat", "curved"][rng.randi() % 3]
	else: style = ["flat", "curved", "stepped", "pediment"][rng.randi() % 4]
	var sur: String = SURNAMES[rng.randi() % SURNAMES.size()]
	var titles: Array = TITLES.get(s, ["STORE"])
	var title: String = titles[rng.randi() % titles.size()]
	var name: String
	match s:
		"pub": name = PUBS[rng.randi() % PUBS.size()]
		"bank": name = BANKS[rng.randi() % BANKS.size()]
		_:
			name = [sur + "'S BUILDINGS", sur + " & SONS", sur + " BROS", sur + "'S " + title, title][rng.randi() % 5]
	p.front = {"style": style, "ph": rng.randf_range(0.9, 1.7), "year": year, "name": name, "title": title,
		"awning": s != "pub" and (s != "bank" or rng.randf() < 0.4) and room >= 1.5, "verandah": s == "pub" and room >= 2.2,
		"awn_d": clampf(room, 1.5, AWN_D),
		"recess": s not in ["bank", "pub"] and w >= 5.5 and rng.randf() < 0.8,
		"door_at": "c" if (s in ["bank", "pub"] or rng.randf() < 0.45) else ("l" if rng.randf() < 0.5 else "r")}
	var flip := rng.randf() < 0.5
	p.floors.append({"y": 0.0, "h": GH, "rooms": _ground(w, d, rng, two, flip)})
	if two:
		p.floors.append({"y": UY, "h": UH, "rooms": upper_rooms(w, d, rng, flip)})

## Ground floor: the shop at the front, the storeroom, toilet and a passage behind; a side passage, the stair and a
## back hall down one side if there's a flat upstairs
static func _ground(w: float, d: float, rng: RandomNumberGenerator, two: bool, flip: bool) -> Array:
	var rooms := []
	var bz := clampf(d * 0.28, 3.5, 6.0)
	var zb := -d / 2 + bz
	var xa := -w / 2
	var xb := w / 2
	if two:
		var sa := -w / 2 if flip else w / 2 - STRIP
		var sb := sa + STRIP
		if flip: xa = sb
		else: xb = sa
		var s0 := -d / 2 + 1.5
		var s1 := s0 + ceil(UY / BuildGen.RISE) * BuildGen.GOING
		rooms.append({"x0": sa, "z0": -d / 2, "x1": sb, "z1": s0, "type": "hall"})
		rooms.append({"x0": sa, "z0": s0, "x1": sb, "z1": s1, "type": "stair"})
		rooms.append({"x0": sa, "z0": s1, "x1": sb, "z1": d / 2, "type": "hall", "street": true})
	# the toilet and the passage on the side away from the stairs (or either side)
	var tleft := flip if two else rng.randf() < 0.5
	var tx0 := xb - 1.6 if not tleft else xa
	var tx1 := tx0 + 1.6
	var sx0 := xa if not tleft else tx1
	var sx1 := tx0 if not tleft else xb
	rooms.append({"x0": xa, "z0": zb, "x1": xb, "z1": d / 2, "type": "shop", "hub": true})
	rooms.append({"x0": sx0, "z0": -d / 2, "x1": sx1, "z1": zb, "type": "store"})
	rooms.append({"x0": tx0, "z0": -d / 2, "x1": tx1, "z1": -d / 2 + 1.8, "type": "toilet"})
	rooms.append({"x0": tx0, "z0": -d / 2 + 1.8, "x1": tx1, "z1": zb, "type": "lobby"})
	return rooms

## Upstairs: a landing at the top of the stair (the back), the stairwell, a lounge across the front over the street,
## and the kitchen, bathroom and bedrooms down the other side
static func upper_rooms(w: float, d: float, rng: RandomNumberGenerator, flip: bool) -> Array:
	var rooms := []
	var sa := -w / 2 if flip else w / 2 - STRIP
	var sb := sa + STRIP
	var xa := sb if flip else -w / 2
	var xb := w / 2 if flip else sa
	var s0 := -d / 2 + 1.5
	var s1 := s0 + ceil(UY / BuildGen.RISE) * BuildGen.GOING
	var lz0 := maxf(s1, d / 2 - 4.5)
	rooms.append({"x0": sa, "z0": -d / 2, "x1": sb, "z1": s0, "type": "hall", "hub": true})
	rooms.append({"x0": sa, "z0": s0, "x1": sb, "z1": s1, "type": "void"})
	if lz0 > s1 + 0.05:
		rooms.append({"x0": sa, "z0": s1, "x1": sb, "z1": lz0, "type": "hall"})
	rooms.append({"x0": -w / 2, "z0": lz0, "x1": w / 2, "z1": d / 2, "type": "lounge"})
	var run := lz0 + d / 2
	var seq: Array = ["kitchen", "bath", "bed"] if run > 7.5 else ["kitchen", "bed"]
	if run > 11.0: seq = ["kitchen", "bed", "bath", "bed"]
	const WANT := {"kitchen": 3.6, "bed": 3.4, "bath": 2.3}
	var tot := 0.0
	var ws := []
	for t in seq:
		var v: float = WANT[t] * rng.randf_range(0.85, 1.15)
		ws.append(v)
		tot += v
	var z := lz0
	for i in seq.size():
		var z0: float = -d / 2 if i == seq.size() - 1 else z - run * ws[i] / tot
		rooms.append({"x0": xa, "z0": z0, "x1": xb, "z1": z, "type": seq[i]})
		z = z0
	return rooms

# ------------------------------------------------------------------------------------------------ openings
static func ext_doors(p: Dictionary, rng: RandomNumberGenerator) -> void:
	var w: float = p.w
	var d: float = p.d
	var f: Dictionary = p.front
	var rooms: Array = p.floors[0].rooms
	var shop: Dictionary = {}
	for r in rooms:
		if r.type == "shop": shop = r
	var a := float(shop.x0)
	var b := float(shop.x1)
	var bw := 2.0 if f.recess else BuildGen.DOOR_W
	var c := (a + b) / 2.0
	if f.door_at == "l": c = a + 0.5 + bw / 2
	elif f.door_at == "r": c = b - 0.5 - bw / 2
	c = clampf(c, a + 0.35 + bw / 2, b - 0.35 - bw / 2)
	var lo := c - bw / 2
	if f.recess:
		var op := BuildGen._add_op(shop, "S", lo, lo + bw, "bay", 0.0, 2.75)
		op["ext"] = true
		op["recess"] = 1.3
	else:
		var op := BuildGen._add_op(shop, "S", lo, lo + BuildGen.DOOR_W, "door", 0.0, BuildGen.DOOR_H)
		op["leaf"] = true
		op["ext"] = true
		bw = BuildGen.DOOR_W
	p["_door_c"] = c
	p.ext_doors.append({"room": shop, "side": "S", "c": c, "front": true})
	# the shop windows either side
	for span in [[a + 0.3, lo - 0.15], [lo + bw + 0.15, b - 0.3]]:
		var L: float = span[1] - span[0]
		if L < 0.7: continue
		if p.sub == "bank":
			var n := maxi(1, int(L / 1.7))
			for k in n:
				var cc: float = span[0] + L * (k + 0.5) / n
				BuildGen._add_op(shop, "S", cc - 0.5, cc + 0.5, "window", 0.9, 2.9)
			continue
		var n := int(ceil(L / 2.6))
		var pw := (L - 0.1 * (n - 1)) / n
		for k in n:
			var x0: float = span[0] + k * (pw + 0.1)
			var op := BuildGen._add_op(shop, "S", x0, x0 + pw, "window", 0.55, 2.75)
			op["display"] = true
			op["fixed"] = true
	# its own street door up to the flat
	for r in rooms:
		if r.get("street", false):
			var cc := (float(r.x0) + float(r.x1)) / 2.0 - BuildGen.DOOR_W / 2
			var op := BuildGen._add_op(r, "S", cc, cc + BuildGen.DOOR_W, "door", 0.0, BuildGen.DOOR_H)
			op["leaf"] = true
			op["ext"] = true
			p.ext_doors.append({"room": r, "side": "S", "c": cc + BuildGen.DOOR_W / 2, "front": true})
	# out the back: a roller door on the hardware's storeroom, else a back door
	var back: Dictionary = {}
	for t in ["store", "hall", "lobby"]:
		for r in rooms:
			if back.is_empty() and r.type == t and absf(float(r.z0) + d / 2) < 0.02 and float(r.x1) - float(r.x0) > 1.2:
				back = r
	if back.is_empty():
		return
	var ba := float(back.x0)
	var bb := float(back.x1)
	if p.sub == "hardware" and back.type == "store" and bb - ba > 4.2:
		var cc := (ba + bb) / 2.0 - 1.6
		var op := BuildGen._add_op(back, "N", cc, cc + 3.2, "roller", 0.0, 3.0)
		op["ext"] = true
		op["open_frac"] = rng.randf_range(0.0, 0.6)
	else:
		var cc := rng.randf_range(ba + 0.2, maxf(ba + 0.2, bb - 0.2 - BuildGen.DOOR_W))
		var op := BuildGen._add_op(back, "N", cc, cc + BuildGen.DOOR_W, "door", 0.0, BuildGen.DOOR_H)
		op["leaf"] = true
		op["ext"] = true
		p.ext_doors.append({"room": back, "side": "N", "c": cc + BuildGen.DOOR_W / 2, "front": false})

## Windows: the shopfront's done; tall sashes upstairs over the street, ordinary ones out the back. None in the side
## walls (they're shared with next door)
static func windows(p: Dictionary, rng: RandomNumberGenerator) -> void:
	for fi in p.floors.size():
		for r in p.floors[fi].rooms:
			if r.type in ["void", "stair", "shop"]: continue
			for side in ["N", "S"]:
				if not BuildGen._ext_side(p, r, side): continue
				var a := float(r.x0)
				var b := float(r.x1)
				var L := b - a
				if side == "S":
					if fi == 0 or r.type != "lounge": continue
					var n := maxi(2, int(L / 2.2))
					for k in n:
						var c := a + L * (k + 0.5) / n
						if BuildGen._free_span(r, side, c - 0.55, c + 0.55):
							BuildGen._add_op(r, side, c - 0.475, c + 0.475, "window", 0.7, 2.5)
					continue
				var ww := 1.2
				var y0 := 0.95 if fi > 0 else 1.6
				var y1 := 2.1 if fi > 0 else 2.6
				var n := maxi(1, int(L / 3.0))
				if r.type in ["bath", "toilet"]:
					ww = 0.6; y0 = 1.6; n = 1
				if r.type == "hall" and L < 1.5: continue
				for k in n:
					var c := a + L * (k + 1) / (n + 1) - ww / 2
					if BuildGen._free_span(r, side, c - 0.1, c + ww + 0.1):
						BuildGen._add_op(r, side, c, c + ww, "window", y0, y1)

## The recessed entry, cut into the front wall at op: tiled floor, glass returns on stall boards, the door at the back
## of it with glass side lights and a transom
static func bay(p: Dictionary, g: BuildGen.Geo, si: Dictionary, op: Dictionary, fy: float, doors: Array) -> void:
	var a := float(op.a)
	var b := float(op.b)
	var rd := float(op.recess)
	var zf: float = si.fixed + BuildGen.T_OUT * (-si.inward)     # the outside face
	var zb := float(si.fixed) - rd                                # the door line
	var top := fy + float(op.y1)
	var c := (a + b) / 2.0
	var da := c - BuildGen.DOOR_W / 2
	var db := c + BuildGen.DOOR_W / 2
	var trim: String = p.trim
	# floor: little tiles
	g.aabb("tile:black", Vector3(a, fy, zb), Vector3(b, fy + 0.008, zf), false)
	# soffit over it
	g.aabb("trim:cream", Vector3(a, top - 0.04, zb), Vector3(b, top, zf), false)
	# the door wall: stall boards and side lights either side of the door, a transom over
	for s in [[a, da], [db, b]]:
		var x0: float = s[0]
		var x1: float = s[1]
		if x1 - x0 < 0.12: continue
		g.aabb("tile:black", Vector3(x0, fy, zb - 0.06), Vector3(x1, fy + 0.5, zb + 0.04))
		p["_windows"].append({"xf": BuildGen._opening_xf({"axis": "x", "fixed": zb, "inward": -1.0}, (x0 + x1) / 2, fy + 0.5 + (top - fy - 0.5) / 2, 0.0),
			"w": x1 - x0 - 0.08, "h": top - fy - 0.55, "fixed": true})
		g.aabb(trim, Vector3(x0, fy + 0.5, zb - 0.04), Vector3(x0 + 0.05, top, zb + 0.04), false)
		g.aabb(trim, Vector3(x1 - 0.05, fy + 0.5, zb - 0.04), Vector3(x1, top, zb + 0.04), false)
	g.aabb(trim, Vector3(da - 0.05, fy + BuildGen.DOOR_H, zb - 0.05), Vector3(db + 0.05, fy + BuildGen.DOOR_H + 0.07, zb + 0.05))
	g.aabb("glass", Vector3(da, fy + BuildGen.DOOR_H + 0.07, zb - 0.005), Vector3(db, top, zb + 0.005))
	doors.append({"xf": Transform3D(Basis(), Vector3(da + 0.02, fy, zb)), "ext": true, "glass": true})
	# the returns: glass on stall boards from the shopfront back to the door
	for e in [[a, -1.0], [b, 1.0]]:
		var x: float = e[0]
		var inward: float = e[1]
		g.aabb("tile:black", Vector3(x - 0.05, fy, zb), Vector3(x + 0.05, fy + 0.5, zf))
		p["_windows"].append({"xf": BuildGen._opening_xf({"axis": "z", "fixed": x, "inward": inward}, (zb + zf) / 2, fy + 0.5 + (top - fy - 0.5) / 2, 0.0),
			"w": zf - zb - 0.1, "h": top - fy - 0.55, "fixed": true})
		g.aabb(trim, Vector3(x - 0.04, fy + 0.5, zf - 0.06), Vector3(x + 0.04, top, zf), false)

# ------------------------------------------------------------------------------------------------ the front and the roof
static func _rod(g: BuildGen.Geo, a: Vector3, b: Vector3, r: float, mk := "steel") -> void:
	var dv := b - a
	var z := dv.normalized()
	var x := z.cross(Vector3.UP)
	if x.length() < 0.01: x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	g.box(mk, Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(r * 2, r * 2, dv.length()), false)

static func _label(p: Dictionary, pos: Vector3, text: String, h: float, width: float, yaw := 0.0, col := Color(0.12, 0.12, 0.12)) -> void:
	var size := minf(h, width / maxf(1.0, text.length() * 0.62))
	p["_labels"].append({"pos": pos, "text": text, "size": size, "yaw": yaw, "col": col})

## Parapet, side walls, the roof behind, pilasters, highlight windows, the awning (or the pub's verandah). lod: the
## cheap version for far off (no rods, signs, lettering or little panes)
static func top(p: Dictionary, g: BuildGen.Geo, top_h: float, ground: Callable, lod := false) -> void:
	var w: float = p.w
	var d: float = p.d
	var T := BuildGen.T_OUT
	var f: Dictionary = p.front
	var clad: String = p.clad
	var trim: String = p.trim
	if not p.has("_labels"): p["_labels"] = []
	var x0 := -w / 2 - T
	var x1 := w / 2 + T
	var zf := d / 2 + T
	var zi := d / 2 - 0.2                  # back face of the parapet
	# roof: a low skillion falling to the back, hidden behind the parapet
	var y0 := top_h + 0.06
	var fall := d * tan(deg_to_rad(3.0))
	_roof_quad(g, String(p.roof.mat) + ":white:uv", Vector3(-w / 2, y0 + fall, zi), Vector3(w / 2, y0 + fall, zi),
		Vector3(w / 2, y0, -d / 2 - T - 0.35), Vector3(-w / 2, y0, -d / 2 - T - 0.35))
	# side walls up past the roofline
	var steps := 6
	for sx in [-w / 2 - T, w / 2]:
		for k in steps:
			var za := -d / 2 - T + (zi + d / 2 + T) * k / steps
			var zz := -d / 2 - T + (zi + d / 2 + T) * (k + 1) / steps
			var hh := fall * (zz + d / 2) / d + 0.2
			g.aabb(clad, Vector3(sx, top_h, za), Vector3(sx + T, y0 + hh, zz), false)
	# gutter along the back
	g.aabb("steel", Vector3(-w / 2 - T, y0 - 0.15, -d / 2 - T - 0.45), Vector3(w / 2 + T, y0 - 0.02, -d / 2 - T - 0.33), false)
	# the parapet
	var ph := maxf(float(f.ph), fall + 0.55)
	var pt := top_h + ph
	g.aabb(clad, Vector3(x0, top_h, zi), Vector3(x1, pt, zf))
	g.aabb(trim, Vector3(x0 - 0.03, pt, zi - 0.03), Vector3(x1 + 0.03, pt + 0.08, zf + 0.07), false)
	g.aabb(trim, Vector3(x0, top_h + 0.08, zf), Vector3(x1, top_h + 0.3, zf + 0.12), false)          # cornice
	g.aabb(trim, Vector3(x0, top_h + 0.3, zf), Vector3(x1, top_h + 0.36, zf + 0.06), false)
	var cap := func(ax: float, bx: float, y: float) -> void:
		g.aabb(trim, Vector3(ax - 0.03, y, zi - 0.03), Vector3(bx + 0.03, y + 0.08, zf + 0.07), false)
	var sign_y := top_h + 0.36 + (pt - top_h - 0.36) * 0.5
	var sign_h := pt - top_h - 0.56
	var sign_w := w * 0.7
	match str(f.style):
		"stepped":
			var tiers := [[w * 0.52, 0.45], [w * 0.26, 0.9]]
			for t in tiers:
				var hw: float = t[0] / 2
				g.aabb(clad, Vector3(-hw, pt, zi), Vector3(hw, pt + float(t[1]), zf))
				cap.call(-hw, hw, pt + float(t[1]))
				# fluting on the face
				for k in 3:
					var fx := -hw * 0.5 + hw * 0.5 * k
					g.aabb(trim, Vector3(fx - 0.03, pt + 0.05, zf), Vector3(fx + 0.03, pt + float(t[1]) - 0.08, zf + 0.03), false)
			if not lod:
				_label(p, Vector3(0, pt + 0.48, zf + 0.04), str(f.year), 0.3, w * 0.2)
		"curved":
			var hw := w * 0.3
			var n := 9
			for k in n:
				var xa := -hw + 2 * hw * k / n
				var xb := -hw + 2 * hw * (k + 1) / n
				var xm := (xa + xb) / 2
				var hgt := 0.75 * sqrt(maxf(0.0, 1.0 - pow(xm / hw, 2)))
				g.aabb(clad, Vector3(xa, pt, zi), Vector3(xb, pt + hgt, zf))
				cap.call(xa, xb, pt + hgt)
			if not lod:
				_label(p, Vector3(0, pt + 0.32, zf + 0.04), str(f.year), 0.26, hw * 0.8)
		"pediment":
			var hw := w * 0.32
			var rise := 0.85
			for zz in [zf, zi]:
				var n := Vector3(0, 0, 1) if zz == zf else Vector3(0, 0, -1)
				g.tri(clad, Vector3(-hw, pt, zz), Vector3(hw, pt, zz), Vector3(0, pt + rise, zz), n, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1))
			for s in [-1.0, 1.0]:
				_rod(g, Vector3(s * hw * 1.04, pt + 0.02, (zi + zf) / 2 + 0.02), Vector3(0, pt + rise + 0.06, (zi + zf) / 2 + 0.02), (zf - zi) / 2 + 0.04, trim)
			if not lod:
				_label(p, Vector3(0, pt + 0.28, zf + 0.02), str(f.year), 0.24, hw * 0.6)
		"box":
			sign_w = w * 0.85
			g.aabb(trim, Vector3(-sign_w / 2, top_h + 0.42, zf), Vector3(sign_w / 2, pt - 0.12, zf + 0.05), false)
	# name panel on the parapet (an inset on the plain ones)
	if str(f.style) != "box":
		g.aabb(trim, Vector3(-sign_w / 2, sign_y - sign_h / 2 - 0.04, zf), Vector3(sign_w / 2, sign_y + sign_h / 2 + 0.04, zf + 0.025), false)
		g.aabb(clad, Vector3(-sign_w / 2 + 0.05, sign_y - sign_h / 2, zf + 0.025), Vector3(sign_w / 2 - 0.05, sign_y + sign_h / 2, zf + 0.035), false)
	if not lod and sign_h > 0.15:
		_label(p, Vector3(0, sign_y, zf + 0.06), str(f.name), minf(0.5, sign_h * 0.75), sign_w - 0.3)
	# pilasters up the front at the ends
	for px in [x0 + 0.16, x1 - 0.16]:
		g.aabb(trim if clad == "brick" else clad, Vector3(px - 0.16, AWN_Y + 0.45, zf), Vector3(px + 0.16, pt, zf + 0.07), false)
		g.aabb(trim, Vector3(px - 0.2, pt - 0.12, zf), Vector3(px + 0.2, pt + 0.12, zf + 0.11), false)
	var two: bool = p.get("two", false)
	if two:
		g.aabb(trim, Vector3(x0, UY - 0.12, zf), Vector3(x1, UY + 0.04, zf + 0.07), false)     # string course
	# highlight windows above the awning
	if p.sub != "bank":
		var hy0 := AWN_Y + 0.42
		var hy1 := AWN_Y + 0.9
		var hx0 := x0 + 0.4
		var hx1 := x1 - 0.4
		if lod:
			g.aabb("glass_dark", Vector3(hx0, hy0, zf), Vector3(hx1, hy1, zf + 0.012), false)
		else:
			g.aabb(trim, Vector3(hx0 - 0.04, hy0 - 0.05, zf), Vector3(hx1 + 0.04, hy1 + 0.05, zf + 0.02), false)
			var n := maxi(3, int((hx1 - hx0) / 0.45))
			var pw := (hx1 - hx0) / n
			for k in n:
				var xa := hx0 + pw * k + 0.025
				g.aabb("glass_lead" if k % 2 == 0 else "glass_lead2", Vector3(xa, hy0, zf + 0.02), Vector3(xa + pw - 0.05, hy1, zf + 0.03), false)
	# over the footpath
	if f.awning:
		var ad := float(f.get("awn_d", AWN_D))
		var ze := zf + ad
		var ya := AWN_Y
		g.aabb("trim:cream", Vector3(x0, ya, zf), Vector3(x1, ya + 0.04, ze))                 # pressed-metal soffit
		_roof_quad(g, "tin:white:uv", Vector3(x0, ya + 0.36, zf), Vector3(x1, ya + 0.36, zf), Vector3(x1, ya + 0.2, ze), Vector3(x0, ya + 0.2, ze))
		g.aabb(trim, Vector3(x0, ya - 0.12, ze - 0.05), Vector3(x1, ya + 0.3, ze), false)     # fascia
		for sx in [x0, x1 - 0.04]:
			g.aabb(trim, Vector3(sx, ya - 0.05, zf), Vector3(sx + 0.04, ya + 0.32, ze), false)
		if not lod:
			var xs := [x0 + 0.45, x1 - 0.45]
			if w > 9.0: xs.append(0.0)
			var anchor := ya + 1.55
			for x in xs:
				_rod(g, Vector3(x, anchor, zf + 0.02), Vector3(x, ya + 0.28, ze - 0.12), 0.02)
				g.aabb("steel", Vector3(x - 0.07, anchor - 0.07, zf), Vector3(x + 0.07, anchor + 0.07, zf + 0.04), false)
			# a sign hung under it, across the footpath
			var sxp := clampf(float(p.get("_door_c", 0.0)), x0 + 1.0, x1 - 1.0)
			var sz := zf + ad * 0.55
			g.aabb(trim, Vector3(sxp - 0.02, ya - 0.5, sz - 0.65), Vector3(sxp + 0.02, ya - 0.15, sz + 0.65), false)
			for e in [[0.6, -0.6]]:
				_rod(g, Vector3(sxp, ya - 0.15, sz + float(e[0])), Vector3(sxp, ya, sz + float(e[0])), 0.008)
				_rod(g, Vector3(sxp, ya - 0.15, sz + float(e[1])), Vector3(sxp, ya, sz + float(e[1])), 0.008)
			for s in [1.0, -1.0]:
				_label(p, Vector3(sxp + s * 0.03, ya - 0.325, sz), str(f.title), 0.2, 1.2, s * PI / 2, Color(0.95, 0.93, 0.85))
	elif f.verandah:
		_pub_verandah(p, g, top_h, ground, lod)

## A pub's two-storey verandah: posts from the footpath, a balcony at the upstairs floor with a rail, lacework under
## the beams, and a skillion roof
static func _pub_verandah(p: Dictionary, g: BuildGen.Geo, top_h: float, ground: Callable, lod: bool) -> void:
	var w: float = p.w
	var d: float = p.d
	var T := BuildGen.T_OUT
	var trim: String = p.trim
	var x0 := -w / 2 - T
	var x1 := w / 2 + T
	var zf := d / 2 + T
	var vd := minf(3.0, float(p.front.get("awn_d", 3.0)))
	var ze := zf + vd
	var n := maxi(2, int(w / 3.0))
	for k in n + 1:
		var x := x0 + 0.1 + (x1 - x0 - 0.2) * k / n
		var gy: float = ground.call(x, ze - 0.1)
		g.aabb(trim, Vector3(x - 0.07, gy, ze - 0.17), Vector3(x + 0.07, top_h - 0.5, ze - 0.03))
	# balcony floor and the rail round it
	g.aabb("deck", Vector3(x0, UY - 0.14, zf), Vector3(x1, UY, ze))
	g.aabb(trim, Vector3(x0, UY - 0.4, ze - 0.15), Vector3(x1, UY - 0.14, ze - 0.02), false)
	g.aabb(trim, Vector3(x0, UY + 0.95, ze - 0.12), Vector3(x1, UY + 1.02, ze - 0.04))
	g.aabb(trim, Vector3(x0, UY + 0.06, ze - 0.11), Vector3(x1, UY + 0.11, ze - 0.05), false)
	for sx in [x0, x1 - 0.07]:
		g.aabb(trim, Vector3(sx, UY + 0.95, zf), Vector3(sx + 0.07, UY + 1.02, ze))
	if not lod:
		var nb := int((x1 - x0) / 0.13)
		for k in nb:
			var x := x0 + (x1 - x0) * (k + 0.5) / nb
			g.aabb(trim, Vector3(x - 0.016, UY + 0.11, ze - 0.1), Vector3(x + 0.016, UY + 0.95, ze - 0.068), false)
		# lacework: a band of little diamonds under each beam
		for y in [UY - 0.4, top_h - 0.5]:
			var nl := int((x1 - x0) / 0.3)
			for k in nl:
				var x := x0 + (x1 - x0) * (k + 0.5) / nl
				g.box(trim, Transform3D(Basis(Vector3.BACK, PI / 4), Vector3(x, y - 0.14, ze - 0.1)), Vector3(0.16, 0.16, 0.025), false)
			g.aabb(trim, Vector3(x0, y - 0.3, ze - 0.11), Vector3(x1, y - 0.27, ze - 0.09), false)
	# the verandah roof
	var rm: String = String(p.roof.mat) + ":white:uv"
	_roof_quad(g, rm, Vector3(x0, top_h - 0.05, zf), Vector3(x1, top_h - 0.05, zf), Vector3(x1, top_h - 0.45, ze + 0.25), Vector3(x0, top_h - 0.45, ze + 0.25))
	g.aabb(trim, Vector3(x0, top_h - 0.7, ze - 0.15), Vector3(x1, top_h - 0.48, ze - 0.02), false)

static func _roof_quad(g: BuildGen.Geo, mk: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	BuildGen._roof_quad(g, mk, a, b, c, d)

## The lettering (Label3D) the plan's front asked for
static func labels(p: Dictionary, root: Node3D) -> void:
	for lb in p.get("_labels", []):
		var l := Label3D.new()
		l.text = lb.text
		l.font_size = 64
		l.outline_size = 0
		l.pixel_size = float(lb.size) / 64.0
		l.modulate = lb.col
		l.double_sided = false
		l.shaded = true
		l.position = lb.pos
		l.rotation.y = float(lb.yaw)
		l.visibility_range_end = 120.0
		root.add_child(l)
