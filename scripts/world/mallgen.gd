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
const UH := 8.5          # high ceilings: a sense of scale
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
	p.sub = "mall"
	p.raised = 0.12
	p.clad = ["plaster:sand", "plaster:cream", "plaster:white", "plaster:sage"][rng.randi() % 4]
	p.trim = ["trim:navy", "trim:maroon", "trim:charcoal", "trim:heritage"][rng.randi() % 4]
	p.roof = {"type": "mall", "mat": "tin"}
	p.h = GH
	p.stair_rise = UY
	var brand: Dictionary = BRANDS[rng.randi() % BRANDS.size()]
	p.mall = {"name": parts[0] if parts[0] != "" else "SUNNYVALE", "brand": brand, "units": [], "fl": 1, "y": UY}
	if parts.size() > 1 and parts[1] == "P":
		_pavilion(p, w, d, rng)
	elif p.mall.name == "TWIN CITY" and not PolyMall.data("twin_city").is_empty():
		# traced from the real directory plan (angles, curves and all): scripts/world/polymall.gd
		PolyMall.plan(p, w, d, rng, "twin_city")
		return
	elif p.mall.name == "TWIN CITY":
		_twin_city(p, w, d, rng)
	elif p.mall.name == "BAY MALL":
		_bay_mall(p, w, d, rng)
	else:
		_sunnyside(p, w, d, rng)
	for r in p.floors[int(p.mall.fl)].rooms:
		if r.type in ["unit", "store", "toilet", "security", "service", "fc_kitchen", "hall", "cine_hall"]: r["ceil"] = 3.9

## The real Sunnyside Mall's two floor plans (docs/sunnyside_lower.png, sunnyside_upper.png), squared off. Written in
## metres east of the west wall (e) and south of the street front (s) on a 97.6 x 94.3 m block, stretched to the lot.
##   ground: shops along the street; behind them the lobby wraps round the ramp; the bottle shop and a small shop on its
##     east; car park to the west, the east and all of the south half (under the supermarket); lift and stair on the
##     west wall; the loading dock in the south-west corner.
##   upstairs: the mall is a C round the ramp's well (north, west and south arms); variety store and shops along the
##     street side, toilets and shops down the west, two shops on the island beside the ramp, the furniture and
##     electrical store filling the east; the supermarket takes the whole south half, off the south arm.
static func _sunnyside(p: Dictionary, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w / 2
	var hd := d / 2
	var ex := w / 97.6
	var sz := d / 94.3
	var L := ceil(UY / BuildGen.RISE) * BuildGen.GOING / sz       # the stair's run, in plan metres
	var R := func(list: Array, e0: float, s0: float, e1: float, s1: float, type: String, extra := {}) -> Dictionary:
		var r := {"x0": snappedf(hw - e1 * ex, 0.01), "z0": snappedf(hd - s1 * sz, 0.01), "x1": snappedf(hw - e0 * ex, 0.01), "z1": snappedf(hd - s0 * sz, 0.01), "type": type}
		r.merge(extra)
		list.append(r)
		return r
	var kinds := UNIT_KINDS.duplicate()
	var kind := func() -> Dictionary:
		var k: Array = kinds.pop_at(rng.randi() % kinds.size())
		return {"sub": k[1], "title": k[0]}
	# ---- ground
	var g := []
	var street := [[0.0, 10.0, "CAFE", "cafe"], [10.0, 15.5, "BANK", "bank"], [15.5, 33.0, "CHEMIST", "chemist"], [33.0, 39.0, "NEWSAGENCY", "newsagent"], [39.0, 45.0, "CAFE", "cafe"]]
	for e in street:
		R.call(g, e[0], 0.0, e[1], 12.0, "shop", {"sub": e[3], "title": e[2], "street": true})
	R.call(g, 45.0, 0.0, 49.0, 12.0, "lobby")
	R.call(g, 49.0, 0.0, 61.0, 31.0, "shop", {"sub": "bottlo", "title": "BOTTLE SHOP", "street": true})
	R.call(g, 49.0, 31.0, 61.0, 40.0, "shop", {"sub": "general", "title": "TAB"})
	R.call(g, 16.5, 12.0, 49.0, 19.0, "lobby")
	R.call(g, 16.5, 19.0, 24.0, 40.0, "lobby")
	R.call(g, 40.0, 19.0, 49.0, 36.0, "lobby")
	R.call(g, 24.0, 36.0, 49.0, 40.0, "lobby")
	var rr: Dictionary = R.call(g, 24.0, 19.0, 40.0, 36.0, "ramp", {"h": UY})
	R.call(g, 0.0, 12.0, 16.5, 40.0, "carpark")
	R.call(g, 61.0, 0.0, 97.6, 40.0, "carpark")
	R.call(g, 0.0, 40.0, 97.6, 43.0, "carpark")
	R.call(g, 0.0, 43.0, 2.0, 43.0 + L, "stair")
	R.call(g, 2.0, 43.0, 4.6, 45.6, "lift")
	R.call(g, 4.6, 43.0, 11.0, 55.0, "carpark")
	R.call(g, 2.0, 45.6, 4.6, 55.0, "carpark")
	R.call(g, 0.0, 43.0 + L, 2.0, 55.0, "carpark")
	R.call(g, 0.0, 55.0, 11.0, 94.3, "dock")
	R.call(g, 11.0, 43.0, 97.6, 94.3, "carpark")
	p.floors.append({"y": 0.0, "h": GH, "rooms": g})
	# ---- upstairs
	var u := []
	R.call(u, 0.0, 0.0, 38.0, 12.0, "unit", {"sub": "general", "title": "DISCOUNT VARIETY"})
	R.call(u, 38.0, 0.0, 54.5, 12.0, "unit", kind.call())
	R.call(u, 54.5, 0.0, 78.5, 36.0, "bigbox", {"title": "HOMESTEAD FURNITURE & ELECTRICAL"})
	R.call(u, 16.5, 12.0, 54.5, 19.0, "concourse", {"open_above": true})
	R.call(u, 16.5, 19.0, 24.0, 36.0, "concourse", {"open_above": true})
	R.call(u, 0.0, 36.0, 78.5, 43.0, "concourse", {"open_above": true})
	R.call(u, 0.0, 12.0, 16.5, 16.0, "toilet")
	R.call(u, 0.0, 16.0, 16.5, 20.0, "toilet")
	R.call(u, 0.0, 20.0, 16.5, 29.0, "unit", kind.call())
	R.call(u, 0.0, 29.0, 16.5, 36.0, "unit", kind.call())
	R.call(u, 24.0, 19.0, 40.0, 36.0, "void", {"well": true})
	R.call(u, 40.0, 19.0, 54.5, 27.5, "unit", kind.call())
	R.call(u, 40.0, 27.5, 54.5, 36.0, "unit", kind.call())
	R.call(u, 0.0, 43.0, 2.0, 43.0 + L, "void")
	R.call(u, 2.0, 43.0, 4.6, 45.6, "lift")
	R.call(u, 4.6, 43.0, 11.0, 55.0, "hall")
	R.call(u, 2.0, 45.6, 4.6, 55.0, "hall")
	R.call(u, 0.0, 43.0 + L, 2.0, 55.0, "hall")
	R.call(u, 0.0, 55.0, 11.0, 61.0, "security")
	R.call(u, 11.0, 43.0, 97.6, 88.0, "super", {"title": p.mall.brand.name})
	R.call(u, 11.0, 88.0, 97.6, 94.3, "super_store")
	p.floors.append({"y": UY, "h": UH, "rooms": u})
	# the ramp in its well: lane A from the south end north, round the hairpin, lane B back south up onto the south arm
	var bw: float = rr.x1 - rr.x0
	var r := (bw - 2.0 * 1.3 - LANE) / 2.0
	var xa: float = rr.x0 + 1.3 + LANE / 2
	var xb := xa + 2.0 * r
	var zt: float = rr.z0
	var zh: float = rr.z1 - r - LANE / 2 - 0.4
	p.ramp = {"xa": xa, "xb": xb, "xc": (xa + xb) / 2, "r": r, "za": zt + 4.0, "zh": zh, "zt": zt}

## The real Tweed City's ground floor (docs/ref/tweed_city_centremap.jpg), squared off: one level, 400 m north to
## south. Written in that map's own pixels (0.452 m each; its left is north, its bottom the main road on the west,
## which is this building's front): two supermarkets and a department store along the east, the discount department
## stores at the north-west and the south end, the long mall between them, a second mall and a cross mall round an
## island of shops and the food court, the west mall down to the main road, and the cinemas (five screens off their
## own foyer) on the south-west.
static func _twin_city(p: Dictionary, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var ex := w / 400.0 * 0.452
	var sz := d / 269.0 * 0.452
	p.h = UH
	p.mall.fl = 0
	p.mall.y = 0.0
	var g := []
	var R := func(x0: float, y0: float, x1: float, y1: float, type: String, extra := {}) -> Dictionary:
		var r := {"x0": snappedf((x0 - 1303.5) * ex, 0.01), "z0": snappedf((y0 - 637.5) * sz, 0.01), "x1": snappedf((x1 - 1303.5) * ex, 0.01), "z1": snappedf((y1 - 637.5) * sz, 0.01), "type": type}
		r.merge(extra)
		g.append(r)
		return r
	var kinds := []
	var kind := func() -> Dictionary:
		if kinds.is_empty(): kinds = UNIT_KINDS.duplicate()
		var k: Array = kinds.pop_at(rng.randi() % kinds.size())
		return {"sub": k[1], "title": k[0]}
	var row := func(x0: float, y0: float, x1: float, y1: float, n: int, along_x := true) -> void:
		for k in n:
			if along_x: R.call(x0 + (x1 - x0) * k / n, y0, x0 + (x1 - x0) * (k + 1) / n, y1, "unit", kind.call())
			else: R.call(x0, y0 + (y1 - y0) * k / n, x1, y0 + (y1 - y0) * (k + 1) / n, "unit", kind.call())
	var mall := {"open_above": true}
	# the east side, north to south
	R.call(862, 345, 1045, 462, "super", {"title": "FRESHWAY"})
	row.call(862, 462, 1045, 500, 4)
	R.call(1045, 345, 1072, 420, "store")
	R.call(1045, 420, 1072, 460, "toilet")
	R.call(1045, 460, 1072, 500, "toilet")
	R.call(1072, 380, 1135, 500, "unit", {"sub": "clothes", "title": "BETTER FOR LESS"})
	R.call(1135, 380, 1275, 462, "bigbox", {"title": "HOLLIS & CRANE"})
	row.call(1135, 462, 1275, 500, 3)
	R.call(1275, 430, 1300, 500, "unit", kind.call())
	R.call(1300, 430, 1340, 500, "concourse", mall)
	R.call(1340, 430, 1370, 500, "unit", kind.call())
	R.call(1370, 340, 1560, 462, "super", {"title": "GREENGATE"})
	row.call(1370, 462, 1560, 500, 4)
	R.call(1560, 380, 1595, 500, "unit", kind.call())
	R.call(1595, 403, 1745, 628, "bigbox", {"title": "BIG VALUE"})
	# the long mall
	R.call(862, 500, 1110, 532, "concourse", mall)
	R.call(1110, 500, 1330, 532, "concourse", mall)
	R.call(1330, 500, 1595, 532, "concourse", mall)
	# the island: shops, the food court and its kitchens, the cross malls
	row.call(862, 532, 990, 600, 3)
	for k in 3:
		R.call(990, 532 + 68.0 * k / 3, 1020, 532 + 68.0 * (k + 1) / 3, "fc_kitchen")
	R.call(1020, 532, 1110, 600, "foodcourt", mall)
	# the court: one high glass-roofed hall. The real centre's diagonal mall crosses it corner to corner between two
	# rows of shops standing at that angle; those rows are lots of their own (tools/add_malls.py, "TWIN CITY/P"),
	# turned 22 degrees, so their walls really are on the angle
	R.call(1110, 532, 1370, 640, "concourse", {"open_above": true, "court": true})
	R.call(1020, 600, 1110, 640, "concourse", mall)
	# the shops between the long mall and the cinemas, the cinemas
	row.call(1370, 532, 1595, 572, 4)
	R.call(1370, 572, 1420, 640, "cine_lobby", {"title": "REGAL CINEMAS"})
	R.call(1420, 572, 1595, 584, "cine_hall")
	for k in 5:
		R.call(1420 + 35.0 * k, 584, 1455 + 35.0 * k, 640, "cinema", {"screen": k + 1})
	# the north-west and the west mall
	R.call(862, 600, 1020, 865, "bigbox", {"title": "BIGMART"})
	row.call(1020, 640, 1130, 720, 2)
	row.call(1130, 640, 1210, 890, 5, false)
	R.call(1210, 640, 1250, 790, "concourse", mall)
	R.call(1210, 790, 1250, 935, "concourse", mall)
	R.call(1250, 640, 1348, 728, "unit", {"sub": "newsagent", "title": "DJ HI-FI"})
	R.call(1250, 728, 1299, 750, "toilet")
	R.call(1299, 728, 1348, 750, "toilet")
	R.call(1250, 750, 1348, 760, "store")
	row.call(1250, 760, 1348, 905, 3, false)
	p.floors.append({"y": 0.0, "h": UH, "rooms": g})

## The real Tweed Mall (docs/ref/tweed_mall_gmaps_indoor.jpg: Google's indoor map, 0.213 m a pixel by its scale bar),
## squared off, as BAY MALL. One level, 250 m north to south: the long mall down the middle from the supermarket at
## the north end to the south doors, three cross malls off it to the west doors, the big store on the east and the
## east doors; a supermarket at the north-west corner and another at the south-west; shops between. Local x = east,
## front (+z) = south.
static func _bay_mall(p: Dictionary, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var ex := w / 833.0
	var sz := d / 1175.0
	p.h = UH
	p.mall.fl = 0
	p.mall.y = 0.0
	var g := []
	var R := func(x0: float, y0: float, x1: float, y1: float, type: String, extra := {}) -> Dictionary:
		var r := {"x0": snappedf((x0 - 508.5) * ex, 0.01), "z0": snappedf((y0 - 1302.5) * sz, 0.01), "x1": snappedf((x1 - 508.5) * ex, 0.01), "z1": snappedf((y1 - 1302.5) * sz, 0.01), "type": type}
		r.merge(extra)
		g.append(r)
		return r
	var kinds := []
	var kind := func() -> Dictionary:
		if kinds.is_empty(): kinds = UNIT_KINDS.duplicate()
		var k: Array = kinds.pop_at(rng.randi() % kinds.size())
		return {"sub": k[1], "title": k[0]}
	var row := func(x0: float, y0: float, x1: float, y1: float, n: int, along_x := true) -> void:
		for k in n:
			if along_x: R.call(x0 + (x1 - x0) * k / n, y0, x0 + (x1 - x0) * (k + 1) / n, y1, "unit", kind.call())
			else: R.call(x0, y0 + (y1 - y0) * k / n, x1, y0 + (y1 - y0) * (k + 1) / n, "unit", kind.call())
	var mall := {"open_above": true}
	# the malls
	R.call(555, 870, 610, 1720, "concourse", mall)
	R.call(335, 940, 555, 975, "concourse", mall)
	R.call(310, 1235, 555, 1270, "concourse", mall)
	R.call(610, 1235, 665, 1270, "concourse", mall)
	R.call(430, 1510, 555, 1570, "concourse", mall)
	R.call(610, 1510, 735, 1570, "concourse", mall)
	# the anchors
	R.call(92, 740, 335, 1025, "super", {"title": "SAVEMART", "tint": "navy"})
	R.call(455, 715, 740, 870, "super", {"title": "FRESHWAY", "tint": "maroon"})
	R.call(665, 1045, 925, 1460, "bigbox", {"title": "K-SAVE"})
	R.call(155, 1570, 430, 1890, "super", {"title": "GREENGATE", "tint": "heritage"})
	# shops
	row.call(335, 880, 455, 940, 2)
	row.call(455, 870, 555, 940, 2)
	row.call(335, 975, 445, 1045, 3)
	R.call(335, 1045, 390, 1100, "toilet")
	R.call(390, 1045, 445, 1100, "toilet")
	R.call(335, 1100, 445, 1165, "store")
	row.call(335, 1165, 445, 1235, 3)
	row.call(445, 975, 555, 1235, 6, false)
	row.call(610, 870, 665, 1235, 8, false)
	row.call(310, 1270, 445, 1340, 3)
	R.call(310, 1340, 445, 1440, "store")
	row.call(445, 1270, 555, 1510, 5, false)
	row.call(610, 1270, 665, 1510, 5, false)
	row.call(430, 1570, 555, 1720, 3, false)
	R.call(610, 1570, 735, 1650, "foodcourt")
	for k in 3:
		R.call(735, 1570 + 80.0 * k / 3, 775, 1570 + 80.0 * (k + 1) / 3, "fc_kitchen")
	row.call(610, 1650, 735, 1720, 2)
	p.floors.append({"y": 0.0, "h": UH, "rooms": g})

## A row of shops standing free under a bigger roof (or in the open): shopfronts along the front, a low flat roof.
## Its lot can be turned to any angle, which is how a mall gets a row of shops off the square.
static func _pavilion(p: Dictionary, w: float, d: float, rng: RandomNumberGenerator) -> void:
	p.h = 4.3
	p.mall.fl = 0
	p.mall.y = 0.0
	p.mall["pavilion"] = true
	var g := []
	var kinds := UNIT_KINDS.duplicate()
	var n := maxi(1, int(round(w / 8.0)))
	for k in n:
		var kd: Array = kinds.pop_at(rng.randi() % kinds.size())
		g.append({"x0": snappedf(-w / 2 + w * k / n, 0.01), "z0": -d / 2, "x1": snappedf(-w / 2 + w * (k + 1) / n, 0.01), "z1": d / 2, "type": "unit", "sub": kd[1], "title": kd[0]})
	p.floors.append({"y": 0.0, "h": 4.3, "rooms": g})

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
	if p.mall.has("poly"): return          # a traced mall: its walls and ways in come with the trace
	var w: float = p.w
	var d: float = p.d
	for fl in p.floors.size():
		var rooms: Array = p.floors[fl].rooms
		for pr in BuildGen._pairs(rooms):
			_between(p, pr, rng)
	# a free-standing row: glass shopfronts straight onto whatever it stands in
	if p.mall.get("pavilion", false):
		for r in p.floors[0].rooms:
			var a := float(r.x0)
			var b := float(r.x1)
			var c := (a + b) / 2
			var op := BuildGen._add_op(r, "S", c - 1.3, c + 1.3, "roller", 0.0, 3.0)
			op["open_frac"] = [0.0, 0.3, 1.0, 1.0][rng.randi() % 4]
			op["grille"] = true
			op["ext"] = true
			p.ext_doors.append({"room": r, "side": "S", "c": c, "front": true})
			for e in [[a + 0.3, c - 1.5], [c + 1.5, b - 0.3]]:
				if e[1] - e[0] > 0.9:
					var wo := BuildGen._add_op(r, "S", e[0], e[1], "window", 0.12, 3.2)
					wo["fixed"] = true
			r["_fronts"] = [{"side": "S", "lo": a, "hi": b}]
	# a ground-level mall: wherever one of its malls meets the open air there's a way in (glass doors, long gone)
	if int(p.mall.get("fl", 1)) == 0:
		var rooms0: Array = p.floors[0].rooms
		for r in rooms0:
			if r.type != "concourse": continue
			for side in ["N", "S", "W", "E"]:
				for sp in _bare(rooms0, r, side):
					var L: float = float(sp[1]) - float(sp[0])
					if L < 4.0: continue
					var busy := false
					for op in r.ops[side]:
						if float(op.a) < float(sp[1]) and float(op.b) > float(sp[0]): busy = true
					if busy: continue
					var c: float = (float(sp[0]) + float(sp[1])) / 2
					var hwid := minf(2.5, L / 2 - 0.5)
					var eo := BuildGen._add_op(r, side, c - hwid, c + hwid, "open", 0.0, 3.2)
					eo["ext"] = true
					p.ext_doors.append({"room": r, "side": side, "c": c, "front": true})
					for e in [[float(sp[0]) + 0.3, c - hwid - 0.2], [c + hwid + 0.2, float(sp[1]) - 0.3]]:
						if e[1] - e[0] > 0.9:
							var wo := BuildGen._add_op(r, side, e[0], e[1], "window", 0.3, 3.2)
							wo["fixed"] = true
	_open_up(p, rng)
	# ---- outside
	var g: Array = p.floors[0].rooms
	for r in g:
		var ext_s := absf(float(r.z1) - d / 2) < 0.02
		match r.type:
			"shop":
				if not ext_s: continue
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
				if not ext_s: continue
				# the way in off the street: the doors are long gone
				var op := BuildGen._add_op(r, "S", float(r.x0) + 0.3, float(r.x1) - 0.3, "open", 0.0, 3.0)
				op["ext"] = true
				p.ext_doors.append({"room": r, "side": "S", "c": (float(r.x0) + float(r.x1)) / 2, "front": true})
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
					if b - a < 6.0: continue
					# the drive-in: a wide gap at street level in the middle of each long side
					var big: bool = b - a > 15.0
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
	# ---- a mall on the ground: wherever one of its arms meets the open air is a way in
	var fl := int(p.mall.fl)
	if fl == 0:
		var mrooms: Array = p.floors[0].rooms
		for r in mrooms:
			if r.type != "concourse": continue
			for side in ["N", "S", "W", "E"]:
				for sp in _bare(mrooms, r, side):
					var L: float = float(sp[1]) - float(sp[0])
					if L < 4.0: continue
					var c: float = (float(sp[0]) + float(sp[1])) / 2
					var hwid := minf(4.0, L / 2 - 0.6)
					BuildGen._add_op(r, side, c - hwid, c + hwid, "open", 0.0, 3.4)
					p.ext_doors.append({"room": r, "side": side, "c": c, "front": side == "S"})
					if not r.has("_entries"): r["_entries"] = []
					r["_entries"].append({"side": side, "c": c})
					for e in [[float(sp[0]) + 0.3, c - hwid - 0.2], [c + hwid + 0.2, float(sp[1]) - 0.3]]:
						if float(e[1]) - float(e[0]) > 1.0:
							var wo := BuildGen._add_op(r, side, float(e[0]), float(e[1]), "window", 0.3, 4.0)
							wo["fixed"] = true
	# ---- upstairs: big windows where the mall itself meets an outside wall
	for r in p.floors[1].rooms if fl == 1 else []:
		if r.type != "concourse": continue
		for side in ["N", "S", "W", "E"]:
			if not BuildGen._ext_side(p, r, side): continue
			var si := BuildGen._side_info(r, side)
			var n := maxi(1, int((float(si.b) - float(si.a) - 0.8) / 2.6))
			for k in n:
				var a: float = float(si.a) + 0.4 + (float(si.b) - float(si.a) - 0.8) * k / n
				var wo := BuildGen._add_op(r, side, a + 0.05, a + (float(si.b) - float(si.a) - 0.8) / n - 0.05, "window", 0.3, 4.0)
				wo["fixed"] = true
	if not p.has("ramp"): return
	# the ramp as a way between the floors (for zombies)
	var rp: Dictionary = p.ramp
	var ramp_room := ""
	var conc := ""
	for r in p.floors[0].rooms:
		if r.type == "ramp": ramp_room = r.id
	for r in p.floors[1].rooms:
		if r.type == "concourse" and absf(float(r.z1) - float(rp.zt)) < 0.05 and float(r.x0) < float(rp.xb) and float(r.x1) > float(rp.xb): conc = r.id
	var pts := []
	for s in _ramp_samples(rp, 10):
		pts.append(s.pos)
	pts.append(Vector3(float(rp.xb), UY, float(rp.zt) - 0.8))
	p["nav_extra"] = [[ramp_room, conc, [Vector3(float(rp.xa), 0.0, float(rp.za) - 0.6)] + pts]]

## Every room must be reachable: anything the rules above left shut in gets a door to a neighbour that isn't (or,
## failing that, to the outside)
static func _open_up(p: Dictionary, rng: RandomNumberGenerator) -> void:
	for fl in p.floors.size():
		var rooms: Array = p.floors[fl].rooms
		var pairs := BuildGen._pairs(rooms)
		var through := func(r: Dictionary, side: String, lo: float, hi: float) -> bool:
			for op in r.ops[side]:
				if op.kind in ["open", "door", "doorx", "roller", "arch", "bay"] and float(op.y0) < 0.3 and float(op.a) < hi and float(op.b) > lo: return true
			return false
		var reached := {}
		for r in rooms:
			if r.type in ["concourse", "carpark", "lobby", "foodcourt"]: reached[r.id] = true
			for side in ["N", "S", "W", "E"]:
				for op in r.ops[side]:
					if op.get("ext", false) and op.kind in ["open", "door", "roller"] and float(op.y0) < 0.3: reached[r.id] = true
		for _pass in rooms.size() + 2:
			var grew := false
			for pr in pairs:
				var ra: bool = reached.has(pr.a.id)
				var rb: bool = reached.has(pr.b.id)
				if ra == rb: continue
				if through.call(pr.a, pr.sa, pr.lo, pr.hi) or through.call(pr.b, pr.sb, pr.lo, pr.hi):
					reached[pr.a.id] = true
					reached[pr.b.id] = true
					grew = true
			if grew: continue
			# stuck: knock a door through the widest wall between a reached room and one that isn't
			var best := {}
			for pr in pairs:
				if reached.has(pr.a.id) == reached.has(pr.b.id): continue
				if pr.a.type in ["void", "lift"] or pr.b.type in ["void", "lift"]: continue
				if pr.hi - pr.lo < BuildGen.DOOR_W + 0.6: continue
				if best.is_empty() or pr.hi - pr.lo > best.hi - best.lo: best = pr
			if best.is_empty(): break
			var inside: bool = reached.has(best.a.id)
			var shut: Dictionary = best.b if inside else best.a
			var c: float = (best.lo + best.hi) / 2 - BuildGen.DOOR_W / 2
			var op := BuildGen._add_op(shut, best.sb if inside else best.sa, c, c + BuildGen.DOOR_W, "door", 0.0, BuildGen.DOOR_H)
			op["leaf"] = true
			BuildGen._add_op(best.a if inside else best.b, best.sa if inside else best.sb, c, c + BuildGen.DOOR_W, "doorx", 0.0, BuildGen.DOOR_H)
			reached[shut.id] = true
		# still shut in (no neighbour at all): a door to the open air
		for r in rooms:
			if reached.has(r.id) or r.type in ["void", "lift", "stair", "ramp"]: continue
			for side in ["S", "N", "E", "W"]:
				var sp: Array = _bare(rooms, r, side)
				if sp.is_empty() or float(sp[0][1]) - float(sp[0][0]) < 2.0: continue
				var c: float = (float(sp[0][0]) + float(sp[0][1])) / 2 - BuildGen.DOOR_W / 2
				var op := BuildGen._add_op(r, side, c, c + BuildGen.DOOR_W, "door", 0.0, BuildGen.DOOR_H)
				op["leaf"] = true
				op["ext"] = true
				reached[r.id] = true
				break

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
		"carpark|carpark", "concourse|foodcourt", "concourse|hall", "concourse|concourse", "lobby|lobby", "hall|hall":
			both_open.call(pr.lo, pr.hi)
		"concourse|void", "hall|void":
			# open to the well; top() puts the balustrade along it
			var e: Array = of.call("void")
			BuildGen._add_op(e[2], e[3], pr.lo, pr.hi, "open")
			if not e[0].has("_edges"): e[0]["_edges"] = []
			e[0]["_edges"].append({"side": e[1], "lo": pr.lo, "hi": pr.hi})
		"lobby|ramp":
			var e: Array = of.call("ramp")
			if e[1] == "N": both_open.call(pr.lo, pr.hi)
		"lobby|shop":
			# a shop off the lobby: a glass door and glass
			var e: Array = of.call("shop")
			var c: float = (pr.lo + pr.hi) / 2
			if pr.hi - pr.lo > 2.4:
				var op := BuildGen._add_op(e[0], e[1], c - BuildGen.DOOR_W / 2, c + BuildGen.DOOR_W / 2, "door", 0.0, BuildGen.DOOR_H)
				op["leaf"] = true
				BuildGen._add_op(e[2], e[3], c - BuildGen.DOOR_W / 2, c + BuildGen.DOOR_W / 2, "doorx", 0.0, BuildGen.DOOR_H)
				_glaze(e, pr.lo + 0.3, c - BuildGen.DOOR_W / 2 - 0.25, 0.4, 2.9)
				_glaze(e, c + BuildGen.DOOR_W / 2 + 0.25, pr.hi - 0.3, 0.4, 2.9)
		"cine_lobby|concourse", "cine_hall|cine_lobby":
			both_open.call(pr.lo + 0.5, pr.hi - 0.5, 0.0, 3.4)
		"cine_hall|cinema":
			var e: Array = of.call("cinema")
			var c: float = (pr.lo + pr.hi) / 2
			both_open.call(c - 1.0, c + 1.0, 0.0, 2.4)
			e[0]["_door_side"] = e[1]
		"concourse|toilet":
			var e: Array = of.call("toilet")
			door.call(e[0], e[1], e[2], e[3])
		"carpark|stair":
			var e: Array = of.call("stair")
			if e[1] == "S": both_open.call(pr.lo, pr.hi)
		"carpark|ramp":
			# a way in from the car park to the foot of the ramp
			if pr.hi - pr.lo > 6.0:
				var c: float = (pr.lo + pr.hi) / 2
				both_open.call(c - 2.0, c + 2.0, 0.0, 3.0)
		"concourse|unit":
			# a glass shopfront: the way in in the middle behind a see-through grille, full-height glass either side
			var e: Array = of.call("unit")
			if not e[0].has("_fronts"): e[0]["_fronts"] = []
			e[0]["_fronts"].append({"side": e[1], "lo": pr.lo, "hi": pr.hi})
			var c: float = (pr.lo + pr.hi) / 2
			var ew := minf(2.6, pr.hi - pr.lo - 1.2)
			var op := BuildGen._add_op(e[0], e[1], c - ew / 2, c + ew / 2, "roller", 0.0, 3.0)
			op["open_frac"] = [0.0, 0.0, 0.3, 1.0, 1.0][rng.randi() % 5]
			op["grille"] = true
			BuildGen._add_op(e[2], e[3], c - ew / 2, c + ew / 2, "open", 0.0, 3.0)
			_glaze(e, pr.lo + 0.3, c - ew / 2 - 0.2, 0.12, 3.2)
			_glaze(e, c + ew / 2 + 0.2, pr.hi - 0.3, 0.12, 3.2)
		"concourse|super":
			var e: Array = of.call("super")
			if not e[0].has("_fronts"): e[0]["_fronts"] = []
			e[0]["_fronts"].append({"side": e[1], "lo": pr.lo, "hi": pr.hi})
			var c: float = (pr.lo + pr.hi) / 2
			both_open.call(c - 5.0, c + 5.0, 0.0, 3.4)
			_glaze(e, pr.lo + 0.5, c - 5.3, 0.12, 3.2)
			_glaze(e, c + 5.3, pr.hi - 0.5, 0.12, 3.2)
		"bigbox|concourse":
			var c: float = (pr.lo + pr.hi) / 2
			both_open.call(c - 3.5, c + 3.5, 0.0, 3.4)
			var e: Array = of.call("bigbox")
			if not e[0].has("_fronts"): e[0]["_fronts"] = []
			e[0]["_fronts"].append({"side": e[1], "lo": pr.lo, "hi": pr.hi})
			_glaze(e, pr.lo + 0.5, c - 3.8, 0.12, 3.2)
			_glaze(e, c + 3.8, pr.hi - 0.5, 0.12, 3.2)
		"concourse|security", "concourse|store", "hall|service", "hall|security", "hall|store", "hall|toilet", "store|unit", "super|super_store":
			# the room that isn't the hall/concourse gets the leaf
			var t: String = tb if ta in ["concourse", "hall", "unit", "super"] else ta
			if k == "concourse|store": t = "store"
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
			# the way in from the car park
			if pr.hi - pr.lo > 5.0:
				var c: float = (pr.lo + pr.hi) / 2
				var hwid := minf(3.0, (pr.hi - pr.lo) / 2 - 0.6)
				both_open.call(c - hwid, c + hwid, 0.0, 3.0)
		"carpark|dock":
			both_open.call(pr.lo + 1.0, minf(pr.hi - 1.0, pr.lo + 6.0), 0.0, 3.2)
		"concourse|lift", "carpark|lift", "hall|lift":
			var e: Array = of.call("lift")
			BuildGen._add_op(e[0], e[1], (pr.lo + pr.hi) / 2 - 0.55, (pr.lo + pr.hi) / 2 + 0.55, "liftdoor", 0.0, 2.2)

## Glass panes (fixed, breakable) from lo to hi in the wall between e[0] (which owns them) and e[2]
static func _glaze(e: Array, lo: float, hi: float, y0: float, y1: float) -> void:
	var L := hi - lo
	if L < 0.9: return
	var n := int(ceil(L / 2.8))
	for j in n:
		var a := lo + L * j / n + 0.05
		var b := lo + L * (j + 1) / n - 0.05
		var wo := BuildGen._add_op(e[0], e[1], a, b, "window", y0, y1)
		wo["fixed"] = true
		BuildGen._add_op(e[2], e[3], a, b, "open", y0, y1)

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
		g.box("rubber", Transform3D(bas, mid - up * 0.15), Vector3(LANE + (0.3 if i >= segs else 0.0), 0.3, L + 0.25))
		if lod: continue
		for sd in [-1.0, 1.0]:
			var off: Vector3 = right * sd * (LANE / 2 + 0.08)
			g.box("steel", Transform3D(bas, mid + off + up * 0.14), Vector3(0.12, 0.28, L + 0.2), false)
			g.box("glass", Transform3D(bas, mid + off + up * 0.64), Vector3(0.03, 0.72, L + 0.2), false)
			g.box("steel", Transform3D(bas, mid + off + up * 1.04), Vector3(0.07, 0.07, L + 0.2), false)
			g.shapes.append([Transform3D(bas, mid + off + up * 0.52), Vector3(0.12, 1.04, L + 0.2)])
		# yellow edge lines
		for sd in [-1.0, 1.0]:
			g.box("enamel:yellow", Transform3D(bas, mid + right * sd * (LANE / 2 - 0.12) + up * 0.005), Vector3(0.08, 0.01, L), false)
		# a column under it now and then
		if i % 3 == 1 and mid.y > 1.2:
			g.aabb("concrete", Vector3(mid.x - 0.25, 0.0, mid.z - 0.25), Vector3(mid.x + 0.25, mid.y - 0.3, mid.z + 0.25))

## A point in a room's own frame: u along its long axis from its low end, v across from its low side
static func _uv(r: Dictionary, along_x: bool, u: float, y: float, v: float) -> Vector3:
	return Vector3(float(r.x0) + u, y, float(r.z0) + v) if along_x else Vector3(float(r.x0) + v, y, float(r.z0) + u)

static func _box_uv(g: BuildGen.Geo, mk: String, r: Dictionary, ax: bool, u0: float, u1: float, y0: float, y1: float, v0: float, v1: float, col := false) -> void:
	var a := _uv(r, ax, u0, y0, v0)
	var b := _uv(r, ax, u1, y1, v1)
	g.aabb(mk, Vector3(minf(a.x, b.x), y0, minf(a.z, b.z)), Vector3(maxf(a.x, b.x), y1, maxf(a.z, b.z)), col)

## Each arm of the mall as a 2020s one: bulkheads stepping down to the shopfronts with downlights in them, dark inlay
## bands in the polished floor, wayfinding signs and banners hung under the skylight, a few fallen ceiling panels
static func _dress(p: Dictionary, g: BuildGen.Geo) -> void:
	var MY: float = p.mall.y
	var MF: Array = p.floors[int(p.mall.fl)].rooms
	var top := MY + UH
	var m: Dictionary = p.mall
	var brand := str(m.brand.name)
	var texts := [brand + "   ·   CAR PARK", "TOILETS   ·   LIFT", "EXIT   ·   " + brand]
	var ti := 0
	for r in MF:
		if r.type != "concourse": continue
		var ax: bool = float(r.x1) - float(r.x0) >= float(r.z1) - float(r.z0)
		var L: float = (float(r.x1) - float(r.x0)) if ax else (float(r.z1) - float(r.z0))
		var W: float = (float(r.z1) - float(r.z0)) if ax else (float(r.x1) - float(r.x0))
		for sd in [0, 1]:
			var v := func(dep: float) -> Array: return [0.0, dep] if sd == 0 else [W - dep, W]
			var b1: Array = v.call(1.2)
			_box_uv(g, "trim:white", r, ax, 0.0, L, MY + 4.5, top, b1[0], b1[1])
			var b2: Array = v.call(1.9)
			_box_uv(g, "trim:white", r, ax, 0.0, L, MY + 5.4, top, b2[0], b2[1])
			var vc := 0.6 if sd == 0 else W - 0.6
			var uu := 1.5
			while uu < L - 1.0:
				_box_uv(g, "steel", r, ax, uu - 0.13, uu + 0.13, MY + 4.485, MY + 4.5, vc - 0.13, vc + 0.13)
				_box_uv(g, "dark", r, ax, uu - 0.09, uu + 0.09, MY + 4.48, MY + 4.486, vc - 0.09, vc + 0.09)
				uu += 3.0
			var fb: Array = [0.75, 1.1] if sd == 0 else [W - 1.1, W - 0.75]
			_box_uv(g, "terrazzo:charcoal", r, ax, 0.0, L, MY, MY + 0.006, fb[0], fb[1])
		_box_uv(g, "terrazzo:charcoal", r, ax, 0.0, L, MY, MY + 0.006, W / 2 - 0.2, W / 2 + 0.2)
		var ub := 6.0
		while ub < L - 3.0:
			_box_uv(g, "terrazzo:charcoal", r, ax, ub - 0.15, ub + 0.15, MY, MY + 0.006, 1.1, W - 1.1)
			ub += 12.0
		# hanging signs across the arm, banners between them
		var n := maxi(1, int(L / 26.0))
		var yaw := PI / 2 if ax else 0.0
		for k in n:
			var uu: float = L * (k + 0.5) / n
			_box_uv(g, "steel:charcoal", r, ax, uu - 0.04, uu + 0.04, MY + 3.5, MY + 4.0, W / 2 - 1.7, W / 2 + 1.7)
			for rv in [W / 2 - 1.5, W / 2 + 1.5]:
				ShopGen._rod(g, _uv(r, ax, uu, MY + 4.0, rv), _uv(r, ax, uu, top + 0.3, rv), 0.012)
			for sgn in [1.0, -1.0]:
				ShopGen._label(p, _uv(r, ax, uu + sgn * 0.05, MY + 3.75, W / 2), texts[ti % texts.size()], 0.26, 3.2, yaw + (0.0 if sgn > 0 else PI), Color(0.95, 0.95, 0.92))
			ti += 1
			var bu: float = uu + L / n * 0.5
			if bu < L - 4.0:
				_box_uv(g, p.trim, r, ax, bu - 0.02, bu + 0.02, MY + 3.9, MY + 6.3, W / 2 - 0.7, W / 2 + 0.7)
				for sgn in [1.0, -1.0]:
					ShopGen._label(p, _uv(r, ax, bu + sgn * 0.03, MY + 5.4, W / 2), str(m.name), 0.3, 1.2, yaw + (0.0 if sgn > 0 else PI), Color(0.96, 0.95, 0.9))
		# ceiling panels that have come down
		for k in maxi(2, int(L / 9.0)):
			var hsh := absi(hash(Vector3i(k, int(p.seed) % 1000, int(r.x0 * 7.0 + r.z0 * 13.0))))
			var pu: float = 2.0 + float(hsh % 1000) / 1000.0 * maxf(L - 4.0, 0.5)
			var pv: float = (0.6 + float((hsh >> 11) % 100) / 100.0 * 1.4) if (hsh >> 10) & 1 else (W - 0.6 - float((hsh >> 11) % 100) / 100.0 * 1.4)
			var bas := Basis(Vector3.UP, float((hsh >> 4) % 628) / 100.0) * Basis(Vector3.RIGHT, float((hsh >> 7) % 30) / 100.0)
			g.box("trim:white", Transform3D(bas, _uv(r, ax, pu, MY + 0.06, pv)), Vector3(0.6, 0.02, 1.2), false)

## The roof over one upstairs room: a slab with a metal deck, or (the mall's arms and the ramp's well) a ceiling margin
## and a glass lantern down the middle
static func _roof_room(p: Dictionary, g: BuildGen.Geo, r: Dictionary, top_h: float, lod: bool) -> void:
	var ry := top_h + 0.3
	var x0 := float(r.x0)
	var x1 := float(r.x1)
	var z0 := float(r.z0)
	var z1 := float(r.z1)
	var sky: bool = r.type == "concourse" or r.get("well", false)
	if not sky:
		g.aabb("concrete_worn", Vector3(x0, top_h + 0.06, z0), Vector3(x1, ry, z1))
		BuildGen._roof_quad(g, "tin:white:uv", Vector3(x0, ry + 0.01, z0), Vector3(x1, ry + 0.01, z0), Vector3(x1, ry + 0.01, z1), Vector3(x0, ry + 0.01, z1))
		return
	var ax: bool = x1 - x0 >= z1 - z0
	var L: float = (x1 - x0) if ax else (z1 - z0)
	var W: float = (z1 - z0) if ax else (x1 - x0)
	var mg := 0.6 if r.type == "concourse" else 1.2
	# the margin: ceiling, roof over it, the light well's sides
	for e in [[0.0, L, 0.0, mg], [0.0, L, W - mg, W], [0.0, 1.0, mg, W - mg], [L - 1.0, L, mg, W - mg]]:
		_box_uv(g, "trim:white", r, ax, e[0], e[1], top_h, top_h + 0.06, e[2], e[3])
		_box_uv(g, "concrete_worn", r, ax, e[0], e[1], top_h + 0.06, ry, e[2], e[3], true)
	for vv in [mg, W - mg]:
		_box_uv(g, "trim:white", r, ax, 1.0, L - 1.0, top_h, ry, vv - 0.03, vv + 0.03)
	var n := maxi(1, int((L - 2.0) / 2.4))
	var ridge := ry + minf(1.4, (W - 2 * mg) * 0.2)
	for k in n + 1:
		var ua := 1.0 + (L - 2.0) * k / n
		_box_uv(g, "steel", r, ax, ua - 0.04, ua + 0.04, ry, ry + 0.12, mg, W - mg)
		if lod or k == n: continue
		var ub := 1.0 + (L - 2.0) * (k + 1) / n
		for sd in [0, 1]:
			var ve := mg if sd == 0 else W - mg
			var broken := absi(hash(Vector3i(k, sd, int(x0 * 3.0 + z0)))) % 7 == 0
			var a := _uv(r, ax, ua, ry, ve)
			var b := _uv(r, ax, ub, ry, ve)
			var c := _uv(r, ax, ub, ridge, W / 2)
			var e := _uv(r, ax, ua, ridge, W / 2)
			if not broken:
				BuildGen._roof_quad(g, "glass", a, b, c, e)
			ShopGen._rod(g, a, e, 0.035)
	if not lod:
		ShopGen._rod(g, _uv(r, ax, 1.0, ridge, W / 2), _uv(r, ax, L - 1.0, ridge, W / 2), 0.05)

## A car park of open concrete decks: ground, and two levels over it, each reached by a ramp up the +x side that a
## car can take; columns on a grid, a low wall round every deck
static func _deck_carpark(g: BuildGen.Geo, x0: float, z0: float, x1: float, z1: float, lod: bool) -> void:
	var LH := 3.2
	var RW := 5.0                       # the ramps' strip
	var RL := 24.0
	var xs := x1 - RW
	for L: int in [1, 2]:
		var y: float = L * LH
		g.aabb("concrete", Vector3(x0, y - 0.25, z0), Vector3(xs, y, z1))
		# the ramp strip: deck except where this level's ramp comes up through it
		var ra: float = z0 + 6.0 if L == 1 else z1 - 6.0 - RL
		var rb := ra + RL
		if ra - z0 > 0.1: g.aabb("concrete", Vector3(xs, y - 0.25, z0), Vector3(x1, y, ra))
		if z1 - rb > 0.1: g.aabb("concrete", Vector3(xs, y - 0.25, rb), Vector3(x1, y, z1))
		# the ramp from the level below: up toward +z for the first, back toward -z for the second
		var lo := Vector3((xs + x1) / 2, y - LH, ra if L == 1 else rb)
		var hi := Vector3((xs + x1) / 2, y, rb if L == 1 else ra)
		var mid := (lo + hi) / 2
		var run := hi - lo
		var bas := Basis.looking_at(run.normalized(), Vector3.UP)
		g.box("concrete", Transform3D(bas, mid - Vector3(0, 0.12, 0)), Vector3(RW - 0.3, 0.25, run.length() + 0.4))
		g.box("enamel:yellow", Transform3D(bas, mid + Vector3(-(RW - 0.3) / 2, 0.3, 0)), Vector3(0.12, 0.6, run.length()), true)
		# a wall between the ramp and the deck beside it, and round the deck's edges
		g.aabb("concrete", Vector3(xs - 0.12, y, ra), Vector3(xs, y + 1.0, rb))
		g.aabb("concrete", Vector3(x0 - 0.15, y, z0 - 0.15), Vector3(x0, y + 1.0, z1 + 0.15))
		g.aabb("concrete", Vector3(x1, y, z0 - 0.15), Vector3(x1 + 0.15, y + 1.0, z1 + 0.15))
		g.aabb("concrete", Vector3(x0, y, z0 - 0.15), Vector3(x1, y + 1.0, z0))
		g.aabb("concrete", Vector3(x0, y, z1), Vector3(x1, y + 1.0, z1 + 0.15))
	# columns
	var x := x0 + 0.4
	while x < xs + 0.1:
		var z := z0 + 0.4
		while z < z1:
			g.aabb("concrete", Vector3(x - 0.3, 0.0, z - 0.3), Vector3(x + 0.3, 2 * LH - 0.25, z + 0.3), not lod)
			z += 8.1
		x += (xs - x0 - 0.8) / 3.0
	var z2 := z0 + 0.4
	while z2 < z1:
		g.aabb("concrete", Vector3(x1 - 0.5, 0.0, z2 - 0.3), Vector3(x1, 2 * LH - 0.25, z2 + 0.3), not lod)
		z2 += 8.1
	if lod: return
	# bay lines on every level
	for L in 3:
		var y: float = L * LH + 0.012
		var zz := z0 + 3.0
		while zz < z1 - 2.0:
			g.aabb("enamel:white", Vector3(x0 + 0.5, y, zz - 0.05), Vector3(x0 + 5.5, y + 0.006, zz + 0.05), false)
			g.aabb("enamel:white", Vector3(xs - 6.0, y, zz - 0.05), Vector3(xs - 1.0, y + 0.006, zz + 0.05), false)
			zz += 2.7

## The parts of a room's side that no other room on its floor shares: [[lo, hi], ...]
static func _bare(rooms: Array, r: Dictionary, side: String) -> Array:
	var si := BuildGen._side_info(r, side)
	var spans := [[float(si.a), float(si.b)]]
	for o in rooms:
		if o == r: continue
		var hit := false
		var lo := 0.0
		var hi := 0.0
		match side:
			"N": hit = absf(float(o.z1) - float(r.z0)) < 0.03
			"S": hit = absf(float(o.z0) - float(r.z1)) < 0.03
			"W": hit = absf(float(o.x1) - float(r.x0)) < 0.03
			_: hit = absf(float(o.x0) - float(r.x1)) < 0.03
		if not hit: continue
		if side in ["N", "S"]:
			lo = float(o.x0); hi = float(o.x1)
		else:
			lo = float(o.z0); hi = float(o.z1)
		var out := []
		for sp in spans:
			if hi <= sp[0] + 0.01 or lo >= sp[1] - 0.01:
				out.append(sp)
				continue
			if lo > sp[0] + 0.01: out.append([sp[0], lo])
			if hi < sp[1] - 0.01: out.append([hi, sp[1]])
		spans = out
	return spans

## A stretch of cladding [a, b] x [y0, y1] with the wall's openings (doors, ways in, windows) cut out of it:
## [[a, b, y0, y1], ...] pieces, the full height between openings, above and below each one
static func _clad_pieces(ops: Array, a: float, b: float, y0: float, y1: float, floor_y: float) -> Array:
	var holes := []
	for op in ops:
		if not (op.kind in ["open", "door", "doorx", "roller", "arch", "bay", "window"]): continue
		var oa := maxf(float(op.a), a); var ob := minf(float(op.b), b)
		if ob - oa < 0.05: continue
		holes.append([oa, ob, floor_y + float(op.get("y0", 0.0)), floor_y + float(op.get("y1", 3.0))])
	holes.sort_custom(func(h1, h2): return h1[0] < h2[0])
	var out := []
	var x := a
	for h in holes:
		if h[0] > x + 0.01: out.append([x, h[0], y0, y1])
		var hx0: float = maxf(h[0], x)
		if h[1] > hx0:
			if h[2] > y0 + 0.01: out.append([hx0, h[1], y0, h[2]])          # under a window
			if h[3] < y1 - 0.01: out.append([hx0, h[1], h[3], y1])          # over the opening
		x = maxf(x, h[1])
	if b > x + 0.01: out.append([x, b, y0, y1])
	return out

# ------------------------------------------------------------------------------------------------ outside and on top
static func top(p: Dictionary, g: BuildGen.Geo, top_h: float, ground: Callable, lod := false) -> void:
	if p.mall.has("poly"):
		PolyMall.build(p, g, lod)
		return
	var MY: float = p.mall.y
	var MF: Array = p.floors[int(p.mall.fl)].rooms
	var w: float = p.w
	var d: float = p.d
	var hw := w / 2
	var hd := d / 2
	var T := BuildGen.T_OUT
	var clad: String = p.clad
	var trim: String = p.trim
	var m: Dictionary = p.mall
	if not p.has("_labels"): p["_labels"] = []
	var up: Array = MF
	var ry := top_h + 0.3
	var pt := ry + 1.1
	# roofs, and cladding and a parapet wherever an upstairs wall faces the open air
	for r in up:
		if r.type == "void" and not r.get("well", false): 
			g.aabb("concrete_worn", Vector3(float(r.x0), top_h + 0.06, float(r.z0)), Vector3(float(r.x1), ry, float(r.z1)))
		else:
			_roof_room(p, g, r, top_h, lod)
		for side in ["N", "S", "W", "E"]:
			for sp in _bare(up, r, side):
				var si := BuildGen._side_info(r, side)
				var edge := BuildGen._ext_side(p, r, side)
				# out from the wall's line: the lot's own edges already have their cladding below the roof
				var y0 := ry if edge else MY - 0.3
				if y0 < ry:
					# down to the floor: leave the ways in and the windows open (a ground-level mall's entrances
					# are in these walls; cladding straight over them sealed Twin City and Bay Mall up)
					for piece in _clad_pieces(r.ops[side], float(sp[0]) - T, float(sp[1]) + T, y0, pt, MY):
						BuildGen._wall_box(g, clad, si, piece[0], piece[1], piece[2], piece[3], -T, 0.0, false)
				else:
					BuildGen._wall_box(g, clad, si, float(sp[0]) - T, float(sp[1]) + T, y0, pt, -T, 0.0, false)
				BuildGen._wall_box(g, trim, si, float(sp[0]) - T, float(sp[1]) + T, pt, pt + 0.1, -T - 0.05, 0.05, false)
				BuildGen._wall_box(g, trim, si, float(sp[0]) - T, float(sp[1]) + T, MY - 0.2, MY + 0.25, -T - 0.06, -T, false)
	# the roof deck over the car park where nothing's built on it
	for r in p.floors[0].rooms:
		if r.type == "void": continue
		var covered := false
		for o in up:
			if float(o.x0) < float(r.x1) - 0.05 and float(o.x1) > float(r.x0) + 0.05 and float(o.z0) < float(r.z1) - 0.05 and float(o.z1) > float(r.z0) + 0.05: covered = true
		if covered: continue
		g.aabb("concrete_worn", Vector3(float(r.x0), GH + 0.06, float(r.z0)), Vector3(float(r.x1), MY, float(r.z1)))
	# the street front: the name over the way in, an awning along the shops
	var lobby_c := 0.0
	var fx0 := hw
	var fx1 := -hw
	for r in p.floors[0].rooms:
		if absf(float(r.z1) - hd) > 0.02: continue
		if r.type == "lobby": lobby_c = (float(r.x0) + float(r.x1)) / 2
		if r.type in ["shop", "lobby"]:
			fx0 = minf(fx0, float(r.x0))
			fx1 = maxf(fx1, float(r.x1))
	var ze := hd + T + 2.6
	if fx1 > fx0:
		g.aabb("trim:white", Vector3(lobby_c - 7.5, MY + 1.2, hd + T + 0.05), Vector3(lobby_c + 7.5, MY + 3.6, hd + T + 0.2), false)
		if not lod:
			ShopGen._label(p, Vector3(lobby_c, MY + 2.4, hd + T + 0.22), str(m.name) + " MALL", 1.3, 14.0, 0.0, Color(0.15, 0.2, 0.35))
		var np := maxi(3, int((fx1 - fx0) / 14.0))
		for k in np:
			var x := fx0 + (fx1 - fx0) * (k + 0.5) / np
			if absf(x - lobby_c) < 8.5: continue
			g.aabb(trim, Vector3(x - 0.9, MY + 0.4, hd + T), Vector3(x + 0.9, top_h - 0.3, hd + T + 0.05), false)
		g.aabb("trim:cream", Vector3(fx0, 3.2, hd + T), Vector3(fx1, 3.24, ze))
		BuildGen._roof_quad(g, "tin:white:uv", Vector3(fx0, 3.55, hd + T), Vector3(fx1, 3.55, hd + T), Vector3(fx1, 3.4, ze), Vector3(fx0, 3.4, ze))
		g.aabb(trim, Vector3(fx0, 3.05, ze - 0.05), Vector3(fx1, 3.5, ze), false)
		if not lod:
			var nr := maxi(1, int((fx1 - fx0) / 6.0))
			for k in nr + 1:
				var x := fx0 + (fx1 - fx0) * k / nr
				ShopGen._rod(g, Vector3(x, MY + 0.6, hd + T + 0.02), Vector3(x, 3.45, ze - 0.1), 0.02)
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
	# Bay Mall's multi-level car park: three levels of concrete deck beside the south end, ramps up one side
	if str(m.name) == "BAY MALL":
		var ex := w / 833.0
		var sz := d / 1175.0
		_deck_carpark(g, (800.0 - 508.5) * ex, (1480.0 - 1302.5) * sz, (925.0 - 508.5) * ex, (1885.0 - 1302.5) * sz, lod)
	if lod:
		return
	# ---- inside: the ramp, car park columns and lines, the balustrade round the void, lift doors, signs over the units
	if p.has("ramp"): _ramp(p, g, false)
	_dress(p, g)
	for r in p.floors[0].rooms:
		if r.type != "ramp": continue
		for side in ["N", "S", "W", "E"]:
			var si := BuildGen._side_info(r, side)
			BuildGen._wall_box(g, "plaster:white", si, float(si.a), float(si.b), GH if side == "N" else 0.0, MY, 0.051, 0.07, false)
	for r in p.floors[0].rooms:
		if r.type != "carpark": continue
		var x := -hw + COL
		while x < hw - 0.5:
			var z := -hd + COL
			while z < hd - 0.5:
				if x > float(r.x0) + 1.0 and x < float(r.x1) - 1.0 and z > float(r.z0) + 1.0 and z < float(r.z1) - 1.0:
					g.aabb("concrete", Vector3(x - 0.3, 0.0, z - 0.3), Vector3(x + 0.3, MY - 0.12, z + 0.3))
					g.aabb("enamel:yellow", Vector3(x - 0.31, 0.0, z - 0.31), Vector3(x + 0.31, 0.9, z + 0.31), false)
					# bays either side of the column line
					for k in 3:
						var bx := x - COL / 2 + COL * (k + 0.5) / 3.0 + COL / 6.0
						if bx > float(r.x1) - 0.3: continue
						g.aabb("enamel:white", Vector3(bx - 0.05, 0.005, z - 2.6), Vector3(bx + 0.05, 0.012, z + 2.6), false)
				z += COL
			x += COL
	# round each well: a glass balustrade where the floor's open to it (a gap where the ramp or the stair comes up),
	# its own wall where it isn't
	var rp: Dictionary = p.get("ramp", {"xb": 0.0})
	for r in MF:
		if r.type != "void": continue
		var well: bool = r.get("well", false)
		var open_sides := {}
		for e in r.get("_edges", []):
			open_sides[e.side] = true
			var si := BuildGen._side_info(r, e.side)
			var runs := [[float(e.lo), float(e.hi)]]
			if e.side == "N":
				if well:
					runs = [[float(e.lo), float(rp.xb) - LANE / 2 - 0.1], [float(rp.xb) + LANE / 2 + 0.1, float(e.hi)]]
				else:
					runs = []
			for run in runs:
				if float(run[1]) - float(run[0]) < 0.1: continue
				BuildGen._wall_box(g, "glass", si, float(run[0]), float(run[1]), MY + 0.1, MY + 1.05, 0.02, 0.06)
				BuildGen._wall_box(g, "steel", si, float(run[0]), float(run[1]), MY + 1.05, MY + 1.12, 0.0, 0.08, false)
				BuildGen._wall_box(g, "steel", si, float(run[0]), float(run[1]), MY - 0.3, MY + 0.1, 0.0, 0.1, false)
		for side in ["N", "S", "W", "E"]:
			if open_sides.has(side): continue
			var si := BuildGen._side_info(r, side)
			BuildGen._wall_box(g, "plaster:white", si, float(si.a), float(si.b), MY - 0.4, MY + UH, 0.0, 0.02, false)
	# the ways in on a ground-floor mall: a canopy and the name over each
	for r in MF:
		for en in r.get("_entries", []):
			var si := BuildGen._side_info(r, en.side)
			var c := float(en.c)
			BuildGen._wall_box(g, "trim:white", si, c - 6.0, c + 6.0, MY + 3.6, MY + 3.8, -3.2, 0.0)
			BuildGen._wall_box(g, trim, si, c - 6.0, c + 6.0, MY + 3.8, MY + 5.6, -0.5, -0.1, false)
			for px in [c - 5.6, c + 5.6]:
				BuildGen._wall_box(g, "steel", si, px - 0.12, px + 0.12, -0.5, MY + 3.6, -3.1, -2.86)
			var pos: Vector3
			var yaw := 0.0
			match en.side:
				"N":
					pos = Vector3(c, MY + 4.7, float(r.z0) - 0.53); yaw = PI
				"S":
					pos = Vector3(c, MY + 4.7, float(r.z1) + 0.53)
				"W":
					pos = Vector3(float(r.x0) - 0.53, MY + 4.7, c); yaw = -PI / 2
				_:
					pos = Vector3(float(r.x1) + 0.53, MY + 4.7, c); yaw = PI / 2
			ShopGen._label(p, pos, str(m.name), 1.1, 11.0, yaw, Color(0.96, 0.95, 0.9))
	# the cinemas: the screen over the doors you came in by, the seats stepping up away from it
	for r in MF:
		if r.type != "cinema": continue
		var ds: String = r.get("_door_side", "N")
		var si := BuildGen._side_info(r, ds)
		var a0 := float(si.a)
		var a1 := float(si.b)
		var depth: float = (float(r.z1) - float(r.z0)) if ds in ["N", "S"] else (float(r.x1) - float(r.x0))
		BuildGen._wall_box(g, "trim:white", si, a0 + (a1 - a0) * 0.1, a1 - (a1 - a0) * 0.1, MY + 2.7, MY + UH - 0.5, 0.06, 0.12, false)
		BuildGen._wall_box(g, "dark", si, a0 + (a1 - a0) * 0.1 - 0.15, a1 - (a1 - a0) * 0.1 + 0.15, MY + 2.55, MY + UH - 0.35, 0.055, 0.06, false)
		var n := int((depth - 6.5) / 1.1)
		for k in n:
			var t0 := 5.0 + 1.1 * k
			BuildGen._wall_box(g, "carpet", si, a0, a1, MY + 0.18 * k, MY + 0.18 * (k + 1), t0, depth)
			var ty := MY + 0.18 * (k + 1)
			BuildGen._wall_box(g, "cloth:maroon", si, a0 + 1.3, a1 - 1.3, ty, ty + 0.42, t0 + 0.3, t0 + 0.85)
			BuildGen._wall_box(g, "cloth:maroon", si, a0 + 1.3, a1 - 1.3, ty + 0.42, ty + 0.95, t0 + 0.75, t0 + 0.85, false)
	# lift doors (shut, the power's off)
	for f in p.floors:
		for r in f.rooms:
			for side in ["N", "S", "W", "E"]:
				for op in r.ops[side]:
					if op.kind != "liftdoor": continue
					var si := BuildGen._side_info(r, side)
					BuildGen._wall_box(g, "steel", si, float(op.a), float(op.b), float(f.y), float(f.y) + 2.2, -0.04, 0.02)
					BuildGen._wall_box(g, "dark", si, (float(op.a) + float(op.b)) / 2 - 0.01, (float(op.a) + float(op.b)) / 2 + 0.01, float(f.y), float(f.y) + 2.2, -0.05, 0.03, false)
	# signs over the shops and the anchors, on the mall side
	for r in MF:
		if not r.has("title"): continue
		for fr in r.get("_fronts", []):
			var si := BuildGen._side_info(r, fr.side)
			var a := float(fr.lo) + 0.4
			var b := float(fr.hi) - 0.4
			if b - a < 1.5: continue
			var y0 := MY + 3.45
			var big: bool = r.type in ["super", "bigbox"]
			var hgt := 1.0 if big else 0.6
			var col: String = "trim:" + str(m.brand.tint) if r.type == "super" else "trim:charcoal"
			BuildGen._wall_box(g, col, si, a, b, y0, y0 + hgt, -0.07, -0.01, false)
			var mid := (a + b) / 2
			var pos: Vector3
			var yaw := 0.0
			match fr.side:
				"N":
					pos = Vector3(mid, y0 + hgt / 2, float(r.z0) - 0.09); yaw = PI
				"S":
					pos = Vector3(mid, y0 + hgt / 2, float(r.z1) + 0.09)
				"W":
					pos = Vector3(float(r.x0) - 0.09, y0 + hgt / 2, mid); yaw = -PI / 2
				_:
					pos = Vector3(float(r.x1) + 0.09, y0 + hgt / 2, mid); yaw = PI / 2
			ShopGen._label(p, pos, str(r.title), hgt * 0.6, minf(b - a - 0.3, 16.0), yaw, Color(0.95, 0.95, 0.9))
	# street shop signs on the awning fascia
	for r in p.floors[0].rooms:
		if r.type != "shop" or absf(float(r.z1) - hd) > 0.02: continue
		ShopGen._label(p, Vector3((float(r.x0) + float(r.x1)) / 2, 3.28, ze + 0.02), str(r.title), 0.26, float(r.x1) - float(r.x0) - 0.6, 0.0, Color(0.95, 0.94, 0.88))
