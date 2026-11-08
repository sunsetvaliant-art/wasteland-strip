class_name MallGen
extends RefCounted
## Shopping centres (docs/MALLS.md), in the house generator's terms (rooms on floors, openings between them), so walls,
## doors, windows, roller shutters, loot, boarding up and zombies finding their way round all come for free.
##
## The Sunnyside kind (the user's description of the real one):
##   ground (street level): an undercroft car park you drive into off the street, columns on a grid, the loading dock at
##     the back; along the street front, a row of shops (a couple of cafes, a bank, the bottle shop, ...) and the entry
##     lobby, double height, where a ramp wide enough for four trolleys starts, climbs away from the street, turns 180
##     degrees round a gentle hairpin and comes up onto the first floor. A stair and a lift in the core beside it.
##   first floor: a concourse (the mall) across the whole width under a skylight; the supermarket and a big-box store
##     on the back side of it, a row of shop units with roller shutters on the front side (each with a stockroom behind),
##     the food court, toilets, the cleaners', a security office and a service corridor.
## Same local frame as the houses: front (the street) +z, y = 0 the ground floor.

const GH := 3.8          # ground (car park and street shops), floor to ceiling
const UY := 4.2          # the first floor
const UH := 6.5          # high ceilings: a sense of scale
const CW := 9.0          # concourse width
const FS := 12.0         # depth of the street shops
const RAMP_W := 16.0     # the ramp's bay
const LANE := 3.4        # four trolleys abreast
const CORE_W := 7.0
const COL := 8.4         # car park column grid

const BRANDS := [
	{"name": "FRESHWAY", "col": Color(0.78, 0.12, 0.12), "tint": "maroon"},      # the red one
	{"name": "GREENGATE", "col": Color(0.15, 0.5, 0.25), "tint": "heritage"},    # the green one
	{"name": "SAVEMART", "col": Color(0.12, 0.25, 0.6), "tint": "navy"},         # the cheap one
]
const UNIT_KINDS := [["CHEMIST", "chemist"], ["NEWS & GIFTS", "newsagent"], ["FASHION", "clothes"], ["DISCOUNT VARIETY", "general"],
	["SPORTS & OUTDOORS", "sports"], ["HAIR STUDIO", "general"], ["PHONE REPAIRS", "newsagent"], ["BUTCHER", "grocer"], ["BAKERY", "cafe"],
	["SHOES", "clothes"], ["JEWELLER", "newsagent"], ["PET SUPPLIES", "general"], ["OPTICAL", "general"], ["TAKEAWAY", "cafe"], ["OP SHOP", "clothes"],
	["CHEMIST", "chemist"], ["FASHION", "clothes"], ["HARDWARE & GARDEN", "hardware"]]
const STREET_KINDS := [["CAFE", "cafe"], ["CAFE", "cafe"], ["BANK", "bank"], ["BOTTLE SHOP", "bottlo"], ["CHEMIST", "chemist"], ["NEWSAGENCY", "newsagent"],
	["TAB", "general"], ["REAL ESTATE", "general"]]

# ------------------------------------------------------------------------------------------------ plan
static func plan_into(p: Dictionary, w: float, d: float, rng: RandomNumberGenerator, sub: String) -> void:
	var parts := sub.split("/")
	var hw := w / 2
	var hd := d / 2
	var c0 := -CW / 2
	var c1 := CW / 2
	p.sub = "mall"
	p.raised = 0.12
	p.clad = ["plaster:sand", "plaster:cream", "plaster:white", "plaster:sage"][rng.randi() % 4]
	p.trim = ["trim:navy", "trim:maroon", "trim:charcoal", "trim:heritage"][rng.randi() % 4]
	p.roof = {"type": "mall", "mat": "tin"}
	p.h = GH
	p.stair_rise = UY
	var brand: Dictionary = BRANDS[rng.randi() % BRANDS.size()]
	p.mall = {"name": parts[0] if parts[0] != "" else "SUNNYVALE", "brand": brand, "units": []}
	var L := ceil(UY / BuildGen.RISE) * BuildGen.GOING       # the core stair's run
	# where things go across the front: the ramp's bay a third of the way along, the core beside it, the food court
	# at the far end (a big enough mall)
	var ramp_x := clampf(-hw + w * 0.3, -hw + 0.5, hw - RAMP_W - CORE_W - 0.5)
	var core_x := ramp_x + RAMP_W
	var fc_w := clampf(w * 0.2, 14.0, 24.0) if w > 70.0 else 0.0
	var fc_x := hw - fc_w
	# ---- ground
	var g := []
	var street := STREET_KINDS.duplicate()
	var si := 0
	var put_shop := func(xa: float, xb: float) -> void:
		var k: Array = street[si % street.size()]
		si += 1
		g.append({"x0": xa, "z0": hd - FS, "x1": xb, "z1": hd, "type": "shop", "sub": k[1], "title": k[0], "street": true})
	for seg in _cut(-hw, ramp_x, 7.0, 11.0, rng):
		put_shop.call(seg[0], seg[1])
	g.append({"x0": ramp_x, "z0": hd - FS, "x1": core_x, "z1": hd, "type": "lobby", "open_above": true})
	for seg in _cut(core_x, hw, 7.0, 11.0, rng):
		put_shop.call(seg[0], seg[1])
	# the ramp's room behind the lobby, open to the floor above
	g.append({"x0": ramp_x, "z0": c1, "x1": core_x, "z1": hd - FS, "type": "ramp", "h": UY})
	# the core: stair (up to the concourse), lift, and car park round them
	g.append({"x0": core_x, "z0": c1, "x1": core_x + 2.0, "z1": c1 + L, "type": "stair"})
	g.append({"x0": core_x + 2.0, "z0": c1, "x1": core_x + 4.6, "z1": c1 + 2.6, "type": "lift"})
	g.append({"x0": core_x + 2.0, "z0": c1 + 2.6, "x1": core_x + 4.6, "z1": c1 + L, "type": "carpark"})
	g.append({"x0": core_x, "z0": c1 + L, "x1": core_x + 4.6, "z1": hd - FS, "type": "carpark"})
	g.append({"x0": core_x + 4.6, "z0": c1, "x1": hw, "z1": hd - FS, "type": "carpark"})
	if ramp_x > -hw + 0.5:
		g.append({"x0": -hw, "z0": c1, "x1": ramp_x, "z1": hd - FS, "type": "carpark"})
	# the back: the dock under the supermarket's storeroom, car park the rest
	g.append({"x0": -hw, "z0": -hd, "x1": -hw + 12.0, "z1": -hd + 10.0, "type": "dock"})
	g.append({"x0": -hw + 12.0, "z0": -hd, "x1": hw, "z1": -hd + 10.0, "type": "carpark"})
	g.append({"x0": -hw, "z0": -hd + 10.0, "x1": hw, "z1": c1, "type": "carpark"})
	p.floors.append({"y": 0.0, "h": GH, "rooms": g})
	# ---- first floor
	var u := []
	u.append({"x0": -hw, "z0": c0, "x1": hw, "z1": c1, "type": "concourse", "open_above": true})
	# behind the concourse: the supermarket, a service block, a big-box store
	var a_s := clampf(w * 0.5, 28.0, 60.0)
	u.append({"x0": -hw, "z0": -hd, "x1": -hw + a_s, "z1": -hd + 9.0, "type": "super_store"})
	u.append({"x0": -hw, "z0": -hd + 9.0, "x1": -hw + a_s, "z1": c0, "type": "super", "title": brand.name})
	var sx := -hw + a_s
	u.append({"x0": sx, "z0": -hd, "x1": sx + 2.4, "z1": c0, "type": "hall", "service": true})
	u.append({"x0": sx + 2.4, "z0": c0 - 6.0, "x1": sx + 8.0, "z1": c0, "type": "security"})
	u.append({"x0": sx + 2.4, "z0": -hd, "x1": sx + 8.0, "z1": c0 - 6.0, "type": "service"})
	if hw - (sx + 8.0) >= 16.0:
		u.append({"x0": sx + 8.0, "z0": -hd, "x1": hw, "z1": c0, "type": "bigbox", "title": "HOMESTEAD FURNITURE & ELECTRICAL"})
	else:
		for seg in _cut(sx + 8.0, hw, 7.0, 11.0, rng):
			_unit(u, seg[0], seg[1], -hd, c0, false, rng, p)
	# in front of it: units, the ramp's void, the core, the food court
	for seg in _cut(-hw, ramp_x, 7.0, 11.0, rng):
		_unit(u, seg[0], seg[1], c1, hd, true, rng, p)
	u.append({"x0": ramp_x, "z0": c1, "x1": core_x, "z1": hd, "type": "void"})
	u.append({"x0": core_x, "z0": c1, "x1": core_x + 2.0, "z1": c1 + L, "type": "void"})
	u.append({"x0": core_x + 2.0, "z0": c1, "x1": core_x + 4.6, "z1": c1 + 2.6, "type": "lift"})
	u.append({"x0": core_x + 2.0, "z0": c1 + 2.6, "x1": core_x + 4.6, "z1": c1 + L, "type": "store"})
	u.append({"x0": core_x + 4.6, "z0": c1, "x1": core_x + CORE_W, "z1": hd, "type": "hall"})
	var tz := c1 + L + (hd - c1 - L) * 0.5
	u.append({"x0": core_x, "z0": c1 + L, "x1": core_x + 4.6, "z1": tz, "type": "toilet"})
	u.append({"x0": core_x, "z0": tz, "x1": core_x + 4.6, "z1": hd, "type": "toilet"})
	for seg in _cut(core_x + CORE_W, fc_x, 7.0, 11.0, rng):
		_unit(u, seg[0], seg[1], c1, hd, true, rng, p)
	if fc_w > 0.0:
		u.append({"x0": fc_x, "z0": c1, "x1": hw, "z1": hd - 6.0, "type": "foodcourt"})
		var nk := maxi(2, int(fc_w / 5.0))
		for k in nk:
			u.append({"x0": fc_x + fc_w * k / nk, "z0": hd - 6.0, "x1": fc_x + fc_w * (k + 1) / nk, "z1": hd, "type": "fc_kitchen"})
	p.floors.append({"y": UY, "h": UH, "rooms": u})
	# the ramp: lane A from near the back of its bay up toward the street, round the hairpin, lane B back to the concourse
	var r := (RAMP_W - 2.0 * 1.3 - LANE) / 2.0          # centre-line radius of the turn
	var xa := ramp_x + 1.3 + LANE / 2
	var xb := xa + 2.0 * r
	var zh := hd - FS - r - LANE / 2 - 0.4
	var za := c1 + 4.0
	p.ramp = {"xa": xa, "xb": xb, "xc": (xa + xb) / 2, "r": r, "za": za, "zh": zh, "zt": c1}

## Split a..b into bays between lo and hi wide
static func _cut(a: float, b: float, lo: float, hi: float, rng: RandomNumberGenerator) -> Array:
	var out := []
	if b - a < 3.0:
		return out
	var x := a
	while b - x > hi + lo * 0.6:
		var wd := rng.randf_range(lo, hi)
		out.append([x, x + wd])
		x += wd
	if b - x > 0.1:
		if b - x < lo * 0.6 and not out.is_empty():
			out[out.size() - 1][1] = b
		else:
			out.append([x, b])
	return out

## A shop unit off the concourse: the shop in front, its stockroom behind
static func _unit(u: Array, xa: float, xb: float, za: float, zb: float, front: bool, rng: RandomNumberGenerator, p: Dictionary) -> void:
	var k: Array = UNIT_KINDS[rng.randi() % UNIT_KINDS.size()]
	var depth := zb - za
	var ud := minf(15.0, depth - 4.0)
	if depth - ud < 3.0: ud = depth
	if front:
		u.append({"x0": xa, "z0": za, "x1": xb, "z1": za + ud, "type": "unit", "sub": k[1], "title": k[0]})
		if ud < depth: u.append({"x0": xa, "z0": za + ud, "x1": xb, "z1": zb, "type": "store"})
	else:
		u.append({"x0": xa, "z0": zb - ud, "x1": xb, "z1": zb, "type": "unit", "sub": k[1], "title": k[0]})
		if ud < depth: u.append({"x0": xa, "z0": za, "x1": xb, "z1": zb - ud, "type": "store"})

# ------------------------------------------------------------------------------------------------ openings
## Between rooms by what they are; to the outside on the street and round the car park. Called once the rooms have ids.
static func openings(p: Dictionary, rng: RandomNumberGenerator) -> void:
	var w: float = p.w
	var d: float = p.d
	for fl in p.floors.size():
		var rooms: Array = p.floors[fl].rooms
		for pr in BuildGen._pairs(rooms):
			_between(p, pr, rng)
	# ---- outside
	var g: Array = p.floors[0].rooms
	for r in g:
		var ext_s := absf(float(r.z1) - d / 2) < 0.02
		match r.type:
			"shop":
				# a door and big windows onto the street
				var a := float(r.x0)
				var b := float(r.x1)
				var c := rng.randf_range(a + 0.8, b - 0.8 - BuildGen.DOOR_W)
				var op := BuildGen._add_op(r, "S", c, c + BuildGen.DOOR_W, "door", 0.0, BuildGen.DOOR_H)
				op["leaf"] = true
				op["ext"] = true
				p.ext_doors.append({"room": r, "side": "S", "c": c + BuildGen.DOOR_W / 2, "front": true})
				for span in [[a + 0.35, c - 0.15], [c + BuildGen.DOOR_W + 0.15, b - 0.35]]:
					var L: float = span[1] - span[0]
					if L < 0.8: continue
					var n := int(ceil(L / 2.6))
					var pw := (L - 0.1 * (n - 1)) / n
					for k in n:
						var x0: float = span[0] + k * (pw + 0.1)
						var wo := BuildGen._add_op(r, "S", x0, x0 + pw, "window", 0.5, 2.9)
						wo["display"] = true
						wo["fixed"] = true
			"lobby":
				# the way in: the doors are long gone
				var c := (float(r.x0) + float(r.x1)) / 2
				var op := BuildGen._add_op(r, "S", c - 3.0, c + 3.0, "open", 0.0, 3.0)
				op["ext"] = true
				p.ext_doors.append({"room": r, "side": "S", "c": c, "front": true})
				for e in [[float(r.x0) + 0.4, c - 3.2], [c + 3.2, float(r.x1) - 0.4]]:
					if float(e[1]) - float(e[0]) > 0.8:
						var wo := BuildGen._add_op(r, "S", float(e[0]), float(e[1]), "window", 0.3, 3.2)
						wo["fixed"] = true
			"dock":
				var op := BuildGen._add_op(r, "N", float(r.x0) + 2.0, float(r.x0) + 6.5, "roller", 0.0, 3.4)
				op["ext"] = true
				op["open_frac"] = rng.randf_range(0.0, 0.8)
			"carpark":
				for side in ["N", "W", "E", "S"]:
					if not BuildGen._ext_side(p, r, side): continue
					var si := BuildGen._side_info(r, side)
					var a: float = si.a
					var b: float = si.b
					# the drive-in: a wide gap at street level in the middle of each side of the back car park
					var big: bool = r.z1 - r.z0 > 15.0 and side in ["W", "E"]
					var mid := (a + b) / 2
					if big:
						var op := BuildGen._add_op(r, side, mid - 3.5, mid + 3.5, "open", 0.0, GH - 0.5)
						op["ext"] = true
						op["drive"] = true
					# the rest: open above a low wall between the columns (it's a car park, the air gets through)
					var x := a + 0.6
					while x + 2.0 < b - 0.6:
						var e := minf(x + COL - 1.2, b - 0.6)
						if not big or e < mid - 3.7 or x > mid + 3.7:
							var vo := BuildGen._add_op(r, side, x, e, "open", 1.1, GH - 0.5)
							vo["ext"] = true
						x += COL
	# ---- the first floor's ends: big windows at each end of the concourse
	for r in p.floors[1].rooms:
		if r.type != "concourse": continue
		for side in ["W", "E"]:
			for k in 3:
				var a: float = float(r.z0) + 0.4 + (CW - 0.8) * k / 3.0
				var wo := BuildGen._add_op(r, side, a + 0.05, a + (CW - 0.8) / 3.0 - 0.05, "window", 0.3, 4.0)
				wo["fixed"] = true
	# the ramp as a way between the floors (for zombies)
	var rp: Dictionary = p.ramp
	var ramp_room := ""
	var conc := ""
	for r in p.floors[0].rooms:
		if r.type == "ramp": ramp_room = r.id
	for r in p.floors[1].rooms:
		if r.type == "concourse": conc = r.id
	var pts := []
	for s in _ramp_samples(rp, 10):
		pts.append(s.pos)
	pts.append(Vector3(float(rp.xb), UY, float(rp.zt) - 0.8))
	p["nav_extra"] = [[ramp_room, conc, [Vector3(float(rp.xa), 0.0, float(rp.za) - 0.6)] + pts]]

static func _between(p: Dictionary, pr: Dictionary, rng: RandomNumberGenerator) -> void:
	var a: Dictionary = pr.a
	var b: Dictionary = pr.b
	var ta: String = a.type
	var tb: String = b.type
	var both_open := func(lo: float, hi: float, y0 := 0.0, y1 := -1.0) -> void:
		BuildGen._add_op(a, pr.sa, lo, hi, "open", y0, y1)
		BuildGen._add_op(b, pr.sb, lo, hi, "open", y0, y1)
	var door := func(on: Dictionary, side: String, other: Dictionary, oside: String) -> void:
		var lo: float = pr.lo + 0.3
		var hi: float = pr.hi - 0.3 - BuildGen.DOOR_W
		if hi < lo: return
		var c := rng.randf_range(lo, hi)
		var op := BuildGen._add_op(on, side, c, c + BuildGen.DOOR_W, "door", 0.0, BuildGen.DOOR_H)
		op["leaf"] = true
		BuildGen._add_op(other, oside, c, c + BuildGen.DOOR_W, "doorx", 0.0, BuildGen.DOOR_H)
	var pair := [ta, tb]
	pair.sort()
	var k := "%s|%s" % pair
	var of := func(t: String) -> Array:      # [room, its side, the other, its side]
		return [a, pr.sa, b, pr.sb] if ta == t else [b, pr.sb, a, pr.sa]
	match k:
		"carpark|carpark", "concourse|foodcourt", "concourse|void", "concourse|hall", "lobby|ramp":
			both_open.call(pr.lo, pr.hi)
		"carpark|stair":
			var e: Array = of.call("stair")
			if e[1] == "S": both_open.call(pr.lo, pr.hi)
		"carpark|ramp":
			# a way in from the car park to the foot of the ramp
			if pr.hi - pr.lo > 6.0:
				var c: float = (pr.lo + pr.hi) / 2
				both_open.call(c - 2.0, c + 2.0, 0.0, 3.0)
		"concourse|unit":
			var e: Array = of.call("unit")
			var op := BuildGen._add_op(e[0], e[1], pr.lo + 0.4, pr.hi - 0.4, "roller", 0.0, 3.3)
			op["open_frac"] = [0.0, 0.0, 0.3, 1.0, 1.0][rng.randi() % 5]
			BuildGen._add_op(e[2], e[3], pr.lo + 0.4, pr.hi - 0.4, "open", 0.0, 3.3)
		"concourse|super":
			var e: Array = of.call("super")
			var c: float = (pr.lo + pr.hi) / 2
			both_open.call(c - 5.0, c + 5.0, 0.0, 3.4)
			for s in [[pr.lo + 0.5, c - 5.3], [c + 5.3, pr.hi - 0.5]]:
				var L: float = s[1] - s[0]
				if L < 1.0: continue
				var n := int(ceil(L / 2.8))
				for j in n:
					var x0: float = s[0] + L * j / n + 0.05
					var wo := BuildGen._add_op(e[0], e[1], x0, s[0] + L * (j + 1) / n - 0.05, "window", 0.4, 3.0)
					wo["fixed"] = true
		"bigbox|concourse":
			var c: float = (pr.lo + pr.hi) / 2
			both_open.call(c - 3.5, c + 3.5, 0.0, 3.4)
		"concourse|security", "hall|service", "hall|security", "hall|store", "hall|toilet", "store|unit", "super|super_store":
			# the room that isn't the hall/concourse gets the leaf
			var t: String = tb if ta in ["concourse", "hall", "unit", "super"] else ta
			var e: Array = of.call(t)
			door.call(e[0], e[1], e[2], e[3])
			if k == "super|super_store" and pr.hi - pr.lo > 8.0:
				var c: float = pr.lo + (pr.hi - pr.lo) * 0.7
				both_open.call(c - 1.4, c + 1.4, 0.0, 2.6)       # the swing doors the trolleys of stock came through
		"fc_kitchen|foodcourt":
			var e: Array = of.call("fc_kitchen")
			BuildGen._add_op(e[0], e[1], pr.lo + 0.4, pr.hi - 1.6, "open", 1.05, 2.5)     # the servery
			BuildGen._add_op(e[2], e[3], pr.lo + 0.4, pr.hi - 1.6, "open", 1.05, 2.5)
			var op := BuildGen._add_op(e[0], e[1], pr.hi - 1.3, pr.hi - 1.3 + BuildGen.DOOR_W, "door", 0.0, BuildGen.DOOR_H)
			op["leaf"] = true
			BuildGen._add_op(e[2], e[3], pr.hi - 1.3, pr.hi - 1.3 + BuildGen.DOOR_W, "doorx", 0.0, BuildGen.DOOR_H)
		"carpark|shop":
			# the street shops' back doors into the car park
			var e: Array = of.call("shop")
			if e[1] == "N": door.call(e[0], e[1], e[2], e[3])
		"carpark|lobby":
			if pr.hi - pr.lo > 3.0: door.call(b if ta == "carpark" else a, pr.sb if ta == "carpark" else pr.sa, a if ta == "carpark" else b, pr.sa if ta == "carpark" else pr.sb)
		"carpark|dock":
			both_open.call(pr.lo + 1.0, minf(pr.hi - 1.0, pr.lo + 6.0), 0.0, 3.2)
		"concourse|lift", "carpark|lift":
			var e: Array = of.call("lift")
			BuildGen._add_op(e[0], e[1], (pr.lo + pr.hi) / 2 - 0.55, (pr.lo + pr.hi) / 2 + 0.55, "liftdoor", 0.0, 2.2)

# ------------------------------------------------------------------------------------------------ the ramp
## Points along the ramp's centre line, foot to top: {pos, dir}
static func _ramp_samples(rp: Dictionary, n_arc: int) -> Array:
	var xa: float = rp.xa
	var xb: float = rp.xb
	var xc: float = rp.xc
	var r: float = rp.r
	var za: float = rp.za
	var zh: float = rp.zh
	var zt: float = rp.zt
	var la := zh - za
	var lc := PI * r
	var lb := zh - zt
	var tot := la + lc + lb
	var out := []
	var at := func(s: float) -> Vector3:
		var y := UY * s / tot
		if s <= la:
			return Vector3(xa, y, za + s)
		if s <= la + lc:
			var t := (s - la) / r              # 0..PI, from the lane A side round the street end to lane B
			return Vector3(xc - r * cos(t), y, zh + r * sin(t))
		return Vector3(xb, y, zh - (s - la - lc))
	var stops := [0.0, la * 0.5, la]
	for i in n_arc:
		stops.append(la + lc * (i + 1) / n_arc)
	stops.append(la + lc + lb * 0.5)
	stops.append(tot)
	for s in stops:
		out.append({"pos": at.call(s), "s": s})
	return out

static func _ramp(p: Dictionary, g: BuildGen.Geo, lod: bool) -> void:
	var rp: Dictionary = p.ramp
	var trim: String = p.trim
	# fine steps along it: each a sloped slab, a low wall each side with a rail on top
	var n_arc := 18
	var la: float = float(rp.zh) - float(rp.za)
	var lb: float = float(rp.zh) - float(rp.zt)
	var steps := []
	var tot := la + PI * float(rp.r) + lb
	var segs := maxi(4, int(la / 3.0))
	for i in segs + 1: steps.append(la * i / segs)
	for i in range(1, n_arc + 1): steps.append(la + PI * float(rp.r) * i / n_arc)
	var segs_b := maxi(4, int(lb / 3.0))
	for i in range(1, segs_b + 1): steps.append(la + PI * float(rp.r) + lb * i / segs_b)
	var pos_at := func(s: float) -> Vector3:
		var y := UY * s / tot
		if s <= la: return Vector3(float(rp.xa), y, float(rp.za) + s)
		if s <= la + PI * float(rp.r):
			var t := (s - la) / float(rp.r)
			return Vector3(float(rp.xc) - float(rp.r) * cos(t), y, float(rp.zh) + float(rp.r) * sin(t))
		return Vector3(float(rp.xb), y, float(rp.zh) - (s - la - PI * float(rp.r)))
	for i in steps.size() - 1:
		var a: Vector3 = pos_at.call(steps[i])
		var b: Vector3 = pos_at.call(steps[i + 1])
		var fwd := (b - a)
		var L := fwd.length()
		fwd = fwd / L
		var right := fwd.cross(Vector3.UP).normalized()
		var up := right.cross(fwd).normalized()
		var bas := Basis(right, up, fwd)
		var mid := (a + b) * 0.5
		# the deck (a touch longer than its piece so they overlap round the turn)
		g.box("tile:grey", Transform3D(bas, mid - up * 0.15), Vector3(LANE + (0.3 if i >= segs else 0.0), 0.3, L + 0.25))
		if lod: continue
		for sd in [-1.0, 1.0]:
			var off: Vector3 = right * sd * (LANE / 2 + 0.08)
			g.box(p.clad, Transform3D(bas, mid + off + up * 0.5), Vector3(0.16, 1.0, L + 0.2))
			g.box("steel", Transform3D(bas, mid + off + up * 1.06), Vector3(0.07, 0.07, L + 0.2), false)
		# yellow edge lines
		for sd in [-1.0, 1.0]:
			g.box("enamel:yellow", Transform3D(bas, mid + right * sd * (LANE / 2 - 0.12) + up * 0.005), Vector3(0.08, 0.01, L), false)
		# a column under it now and then
		if i % 3 == 1 and mid.y > 1.2:
			g.aabb("concrete", Vector3(mid.x - 0.25, 0.0, mid.z - 0.25), Vector3(mid.x + 0.25, mid.y - 0.3, mid.z + 0.25))

# ------------------------------------------------------------------------------------------------ outside and on top
static func top(p: Dictionary, g: BuildGen.Geo, top_h: float, ground: Callable, lod := false) -> void:
	var w: float = p.w
	var d: float = p.d
	var hw := w / 2
	var hd := d / 2
	var T := BuildGen.T_OUT
	var clad: String = p.clad
	var trim: String = p.trim
	var m: Dictionary = p.mall
	if not p.has("_labels"): p["_labels"] = []
	var c0 := -CW / 2
	var c1 := CW / 2
	# the roof: flat, a skylight lantern down the concourse
	var ry := top_h + 0.3
	g.aabb("concrete_worn", Vector3(-hw - T, top_h + 0.06, -hd - T), Vector3(hw + T, ry, c0 + 0.6))
	g.aabb("concrete_worn", Vector3(-hw - T, top_h + 0.06, c1 - 0.6), Vector3(hw + T, ry, hd + T))
	g.aabb("concrete_worn", Vector3(-hw - T, top_h + 0.06, c0 + 0.6), Vector3(-hw + 1.0, ry, c1 - 0.6))
	g.aabb("concrete_worn", Vector3(hw - 1.0, top_h + 0.06, c0 + 0.6), Vector3(hw + T, ry, c1 - 0.6))
	# a metal deck on top
	for e in [[-hd - T, c0 + 0.6], [c1 - 0.6, hd + T]]:
		BuildGen._roof_quad(g, "tin:white:uv", Vector3(-hw - T, ry + 0.01, float(e[0])), Vector3(hw + T, ry + 0.01, float(e[0])), Vector3(hw + T, ry + 0.01, float(e[1])), Vector3(-hw - T, ry + 0.01, float(e[1])))
	# the concourse's ceiling either side of the lantern (it has no ceiling of its own)
	g.aabb("trim:white", Vector3(-hw, top_h, c0), Vector3(hw, top_h + 0.06, c0 + 0.6), false)
	g.aabb("trim:white", Vector3(-hw, top_h, c1 - 0.6), Vector3(hw, top_h + 0.06, c1), false)
	# the lantern's sides: a light well up from the ceiling to the roof
	for zz in [c0 + 0.6, c1 - 0.6]:
		g.aabb("trim:white", Vector3(-hw + 1.0, top_h, zz - 0.03), Vector3(hw - 1.0, ry, zz + 0.03), false)
	# the lantern: glass sloping up both sides to a ridge, steel frames; some panes gone
	var lx0 := -hw + 1.0
	var lx1 := hw - 1.0
	var n := int((lx1 - lx0) / 2.4)
	var ridge := ry + 1.4
	for k in n:
		var xa := lx0 + (lx1 - lx0) * k / n
		var xb := lx0 + (lx1 - lx0) * (k + 1) / n
		g.aabb("steel", Vector3(xa - 0.04, ry, c0 + 0.6), Vector3(xa + 0.04, ry + 0.12, c1 - 0.6), false)
		if lod: continue
		for sd in [-1.0, 1.0]:
			var e0 := Vector3(0, ry, (c0 + 0.6) if sd < 0 else (c1 - 0.6))
			var e1 := Vector3(0, ridge, 0.0)
			var broken := absi(hash(Vector2i(k, int(sd)))) % 7 == 0
			if not broken:
				BuildGen._roof_quad(g, "glass", Vector3(xa, e0.y, e0.z), Vector3(xb, e0.y, e0.z), Vector3(xb, e1.y, e1.z), Vector3(xa, e1.y, e1.z))
			ShopGen._rod(g, Vector3(xa, e0.y, e0.z), Vector3(xa, e1.y, e1.z), 0.035)
	if not lod:
		ShopGen._rod(g, Vector3(lx0, ridge, 0), Vector3(lx1, ridge, 0), 0.05)
	# parapet all round, a band at the first floor, the name across the front
	var pt := ry + 1.1
	g.aabb(clad, Vector3(-hw - T, ry, hd), Vector3(hw + T, pt, hd + T), false)
	g.aabb(clad, Vector3(-hw - T, ry, -hd - T), Vector3(hw + T, pt, -hd), false)
	g.aabb(clad, Vector3(-hw - T, ry, -hd), Vector3(-hw, pt, hd), false)
	g.aabb(clad, Vector3(hw, ry, -hd), Vector3(hw + T, pt, hd), false)
	for e in [[Vector3(-hw - T - 0.05, pt, hd - 0.05), Vector3(hw + T + 0.05, pt + 0.1, hd + T + 0.05)],
			[Vector3(-hw - T - 0.05, pt, -hd - T - 0.05), Vector3(hw + T + 0.05, pt + 0.1, -hd + 0.05)],
			[Vector3(-hw - T - 0.05, pt, -hd), Vector3(-hw + 0.05, pt + 0.1, hd)], [Vector3(hw - 0.05, pt, -hd), Vector3(hw + T + 0.05, pt + 0.1, hd)]]:
		g.aabb(trim, e[0], e[1], false)
	g.aabb(trim, Vector3(-hw - T - 0.04, UY - 0.2, hd + T), Vector3(hw + T + 0.04, UY + 0.25, hd + T + 0.08), false)
	# feature panels in the trim colour up the front of the first floor
	var np := maxi(3, int(w / 14.0))
	for k in np:
		var x := -hw + w * (k + 0.5) / np
		g.aabb(trim, Vector3(x - 0.9, UY + 0.4, hd + T), Vector3(x + 0.9, top_h - 0.3, hd + T + 0.05), false)
	# the name: a big sign board over the entrance
	var lobby_c := 0.0
	for r in p.floors[0].rooms:
		if r.type == "lobby": lobby_c = (float(r.x0) + float(r.x1)) / 2
	g.aabb("trim:white", Vector3(lobby_c - 7.5, UY + 1.2, hd + T + 0.05), Vector3(lobby_c + 7.5, UY + 3.6, hd + T + 0.2), false)
	if not lod:
		ShopGen._label(p, Vector3(lobby_c, UY + 2.4, hd + T + 0.22), str(m.name) + " MALL", 1.3, 14.0, 0.0, Color(0.15, 0.2, 0.35))
	# an awning along the street shops
	var ze := hd + T + 2.6
	g.aabb("trim:cream", Vector3(-hw - T, 3.2, hd + T), Vector3(hw + T, 3.24, ze))
	BuildGen._roof_quad(g, "tin:white:uv", Vector3(-hw - T, 3.55, hd + T), Vector3(hw + T, 3.55, hd + T), Vector3(hw + T, 3.4, ze), Vector3(-hw - T, 3.4, ze))
	g.aabb(trim, Vector3(-hw - T, 3.05, ze - 0.05), Vector3(hw + T, 3.5, ze), false)
	if not lod:
		var nr := int(w / 6.0)
		for k in nr + 1:
			var x := -hw + w * k / nr
			ShopGen._rod(g, Vector3(x, UY + 0.6, hd + T + 0.02), Vector3(x, 3.45, ze - 0.1), 0.02)
	# the drive-ins: a ramp down to the ground where the floor's above it
	for r in p.floors[0].rooms:
		for side in ["W", "E"]:
			for op in r.ops[side]:
				if not op.get("drive", false): continue
				var x := -hw - T if side == "W" else hw + T
				var outx := -1.0 if side == "W" else 1.0
				var gy: float = ground.call(x + outx * 1.0, (float(op.a) + float(op.b)) / 2)
				var drop := -gy
				if drop < 0.05: continue
				var run := clampf(drop * 7.0, 2.0, 12.0)
				var a := float(op.a) - 0.5
				var b := float(op.b) + 0.5
				BuildGen._roof_quad(g, "concrete", Vector3(x, 0.0, a), Vector3(x, 0.0, b), Vector3(x + outx * run, gy - 0.05, b), Vector3(x + outx * run, gy - 0.05, a))
	if lod:
		return
	# ---- inside: the ramp, car park columns and lines, the balustrade round the void, lift doors, signs over the units
	_ramp(p, g, false)
	for r in p.floors[0].rooms:
		if r.type != "carpark": continue
		var x := -hw + COL
		while x < hw - 0.5:
			var z := -hd + COL
			while z < hd - 0.5:
				if x > float(r.x0) + 1.0 and x < float(r.x1) - 1.0 and z > float(r.z0) + 1.0 and z < float(r.z1) - 1.0:
					g.aabb("concrete", Vector3(x - 0.3, 0.0, z - 0.3), Vector3(x + 0.3, UY - 0.12, z + 0.3))
					g.aabb("enamel:yellow", Vector3(x - 0.31, 0.0, z - 0.31), Vector3(x + 0.31, 0.9, z + 0.31), false)
					# bays either side of the column line
					for k in 3:
						var bx := x - COL / 2 + COL * (k + 0.5) / 3.0 + COL / 6.0
						if bx > float(r.x1) - 0.3: continue
						g.aabb("enamel:white", Vector3(bx - 0.05, 0.005, z - 2.6), Vector3(bx + 0.05, 0.012, z + 2.6), false)
				z += COL
			x += COL
	# the balustrade round the ramp's void (open where lane B comes up), and round the stairwell
	var rp: Dictionary = p.ramp
	for r in p.floors[1].rooms:
		if r.type != "void": continue
		var x0 := float(r.x0)
		var x1 := float(r.x1)
		var z0 := float(r.z0)
		var z1 := float(r.z1)
		var runs := []
		if absf(z0 - c1) < 0.05:
			# along the concourse edge: a gap for whatever comes up (the ramp's lane, or the stair)
			var gap0 := x0 + 0.2
			var gap1 := x1 - 0.2
			if x1 - x0 > 4.0:
				gap0 = float(rp.xb) - LANE / 2 - 0.1
				gap1 = float(rp.xb) + LANE / 2 + 0.1
			runs.append([Vector3(x0, 0, z0), Vector3(gap0, 0, z0)])
			runs.append([Vector3(gap1, 0, z0), Vector3(x1, 0, z0)])
		for e in runs:
			var a: Vector3 = e[0]
			var b: Vector3 = e[1]
			if b.x - a.x < 0.1: continue
			g.aabb("glass", Vector3(a.x, UY + 0.1, a.z - 0.02), Vector3(b.x, UY + 1.05, a.z + 0.02))
			g.aabb("steel", Vector3(a.x, UY + 1.05, a.z - 0.04), Vector3(b.x, UY + 1.12, a.z + 0.04), false)
			g.aabb("steel", Vector3(a.x, UY, a.z - 0.06), Vector3(b.x, UY + 0.1, a.z + 0.06), false)
	# the bays open to the floor below (the ramp's, the stairwell) get walls of their own, over the backs of their
	# neighbours' walls
	for r in p.floors[1].rooms:
		if r.type != "void": continue
		var x0 := float(r.x0)
		var x1 := float(r.x1)
		var z0 := float(r.z0)
		var z1 := float(r.z1)
		var y0 := UY - 0.4
		var y1 := UY + UH
		g.aabb(clad if false else "plaster:white", Vector3(x0, y0, z1 - 0.02), Vector3(x1, y1, z1), false)
		g.aabb("plaster:white", Vector3(x0, y0, z0), Vector3(x0 + 0.02, y1, z1), false)
		g.aabb("plaster:white", Vector3(x1 - 0.02, y0, z0), Vector3(x1, y1, z1), false)
	# lift doors (shut, the power's off)
	for f in p.floors:
		for r in f.rooms:
			for side in ["N", "S", "W", "E"]:
				for op in r.ops[side]:
					if op.kind != "liftdoor": continue
					var si := BuildGen._side_info(r, side)
					BuildGen._wall_box(g, "steel", si, float(op.a), float(op.b), float(f.y), float(f.y) + 2.2, -0.04, 0.02)
					BuildGen._wall_box(g, "dark", si, (float(op.a) + float(op.b)) / 2 - 0.01, (float(op.a) + float(op.b)) / 2 + 0.01, float(f.y), float(f.y) + 2.2, -0.05, 0.03, false)
	# signs over the units and the anchors, on the concourse side
	for r in p.floors[1].rooms:
		if not r.has("title"): continue
		var front_z := float(r.z0) if r.z0 >= c1 - 0.05 else float(r.z1)
		var dir := -1.0 if r.z0 >= c1 - 0.05 else 1.0
		var x0 := float(r.x0) + 0.4
		var x1 := float(r.x1) - 0.4
		var y0 := UY + 3.45
		var big: bool = r.type in ["super", "bigbox"]
		var hgt := 1.0 if big else 0.6
		var col: String = "trim:" + str(m.brand.tint) if r.type == "super" else "trim:charcoal"
		var zz := front_z + dir * 0.01
		g.aabb(col, Vector3(x0, y0, minf(zz, zz + dir * 0.06)), Vector3(x1, y0 + hgt, maxf(zz, zz + dir * 0.06)), false)
		var c := Color(0.95, 0.95, 0.9)
		ShopGen._label(p, Vector3((x0 + x1) / 2, y0 + hgt / 2, zz + dir * 0.08), str(r.title), hgt * 0.6, x1 - x0 - 0.3, 0.0 if dir > 0 else PI, c)
	# street shop signs on the awning fascia
	for r in p.floors[0].rooms:
		if r.type != "shop": continue
		ShopGen._label(p, Vector3((float(r.x0) + float(r.x1)) / 2, 3.28, ze + 0.02), str(r.title), 0.26, float(r.x1) - float(r.x0) - 0.6, 0.0, Color(0.95, 0.94, 0.88))
