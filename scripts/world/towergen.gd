class_name TowerGen
extends RefCounted
## The beachfront towers: holiday units and motels, five to fourteen storeys. Three floors of one are real: the foyer
## off the street (reception, the lift), one floor part-way up (a corridor of rooms) and the roof. The lift goes
## between them (BuildLift: F at the panel). The rest is facade: bands of dark glass and balconies.

const SH := 3.1           # storey height
const NAMES := ["OCEAN VIEW", "THE SANDS", "PACIFIC TOWERS", "BORDER MOTOR INN", "SEA BREEZE", "POINT LOOKOUT", "TWIN TOWNS APARTMENTS", "KIRRA SURF", "THE ESPLANADE", "GREENMOUNT"]

static func plan_into(p: Dictionary, w: float, d: float, rng: RandomNumberGenerator, sub: String) -> void:
	# sub "5" = five storeys; "5g" = a five-storey residential block with garages across the ground floor
	var garages := sub.ends_with("g")
	var sl := sub.trim_suffix("g")
	var levels := clampi(int(sl) if sl.is_valid_int() else rng.randi_range(8, 12), 5, 14)
	var mid := maxi(2, levels / 2)
	p.raised = 0.2
	p.h = 3.4
	p.clad = ["plaster:white", "plaster:cream", "plaster:sand", "plaster:pale_blue", "plaster:sage"][rng.randi() % 5]
	p.trim = ["trim:navy", "trim:charcoal", "trim:white", "trim:maroon"][rng.randi() % 4]
	p.roof = {"type": "flat", "mat": "concrete"}
	p.tower = {"levels": levels, "mid": mid, "name": "" if garages else NAMES[rng.randi() % NAMES.size()], "garages": garages}
	if garages:
		p.clad = ["plaster:white", "plaster:cream", "plaster:sand"][rng.randi() % 3]
	var bz := -d / 2 + 2.8        # the back strip (lift and services) ends here
	var lift := func(h: float) -> Dictionary: return {"x0": -1.4, "z0": -d / 2, "x1": 1.4, "z1": bz, "type": "lift", "h": h}
	# the foyer
	p.floors.append({"y": 0.0, "h": 3.4, "rooms": [
		{"x0": -w / 2, "z0": bz, "x1": w / 2, "z1": d / 2, "type": "lobby", "hub": true},
		{"x0": -w / 2, "z0": -d / 2, "x1": -1.4, "z1": bz, "type": "office"},
		lift.call(3.4),
		{"x0": 1.4, "z0": -d / 2, "x1": w / 2, "z1": bz, "type": "store"}]})
	# part-way up: a corridor, rooms off it looking out the front
	var rooms := [{"x0": -w / 2, "z0": bz, "x1": w / 2, "z1": bz + 1.8, "type": "hall", "hub": true},
		{"x0": -w / 2, "z0": -d / 2, "x1": -1.4, "z1": bz, "type": "store"}, lift.call(2.7),
		{"x0": 1.4, "z0": -d / 2, "x1": w / 2, "z1": bz, "type": "laundry"}]
	var n := maxi(2, int(w / 6.5))
	for k in n:
		rooms.append({"x0": snappedf(-w / 2 + w * k / n, 0.01), "z0": bz + 1.8, "x1": snappedf(-w / 2 + w * (k + 1) / n, 0.01), "z1": d / 2, "type": "bed" if k % 2 == 0 else "lounge"})
	p.floors.append({"y": mid * SH, "h": 2.7, "rooms": rooms})
	# the roof: a parapet round a deck, the lift's head house
	p.floors.append({"y": levels * SH, "h": 1.1, "rooms": [
		{"x0": -w / 2, "z0": bz, "x1": w / 2, "z1": d / 2, "type": "hall", "hub": true, "open_above": true, "nowin": true},
		{"x0": -w / 2, "z0": -d / 2, "x1": -1.4, "z1": bz, "type": "hall", "open_above": true, "nowin": true},
		lift.call(2.6),
		{"x0": 1.4, "z0": -d / 2, "x1": w / 2, "z1": bz, "type": "hall", "open_above": true, "nowin": true}]})

## The facade on the storeys that aren't real, the balconies, the name
static func top(p: Dictionary, g: BuildGen.Geo, lod := false) -> void:
	var w: float = p.w
	var d: float = p.d
	var T := BuildGen.T_OUT
	var tw: Dictionary = p.tower
	var levels: int = tw.levels
	for k in levels:
		var y := k * SH
		var real: bool = k == 0 or k == int(tw.mid)
		# ribbon windows all round
		if not real:
			g.aabb("glass_dark", Vector3(-w / 2 + 0.8, y + 0.95, d / 2 + T), Vector3(w / 2 - 0.8, y + 2.3, d / 2 + T + 0.02), false)
			g.aabb("glass_dark", Vector3(-w / 2 + 0.8, y + 1.1, -d / 2 - T - 0.02), Vector3(w / 2 - 0.8, y + 2.1, -d / 2 - T), false)
			if not lod:
				g.aabb("glass_dark", Vector3(-w / 2 - T - 0.02, y + 1.1, -d / 2 + 1.5), Vector3(-w / 2 - T, y + 2.1, d / 2 - 1.5), false)
				g.aabb("glass_dark", Vector3(w / 2 + T, y + 1.1, -d / 2 + 1.5), Vector3(w / 2 + T + 0.02, y + 2.1, d / 2 - 1.5), false)
		# a balcony across the front of every storey above the street
		if k > 0:
			g.aabb("concrete", Vector3(-w / 2, y - 0.14, d / 2 + T), Vector3(w / 2, y, d / 2 + T + 1.4), k == int(tw.mid))
			g.aabb(p.clad, Vector3(-w / 2, y, d / 2 + T + 1.32), Vector3(w / 2, y + 1.0, d / 2 + T + 1.4), k == int(tw.mid))
			if not lod:
				var nb := maxi(2, int(w / 6.5))
				for j in nb + 1:
					var x := -w / 2 + w * j / nb
					g.aabb(p.clad, Vector3(x - 0.08, y, d / 2 + T), Vector3(x + 0.08, y + SH - 0.14, d / 2 + T + 1.4), false)
	# a band in the trim colour at the top, the head house's cap
	var ty := levels * SH
	g.aabb(p.trim, Vector3(-w / 2 - T - 0.03, ty + 0.75, -d / 2 - T - 0.03), Vector3(w / 2 + T + 0.03, ty + 1.12, -d / 2 - T), false)
	g.aabb(p.trim, Vector3(-w / 2 - T - 0.03, ty + 0.75, d / 2 + T), Vector3(w / 2 + T + 0.03, ty + 1.12, d / 2 + T + 0.03), false)
	g.aabb("concrete", Vector3(-1.6, ty + 2.6, -d / 2 - 0.1), Vector3(1.6, ty + 2.8, -d / 2 + 3.0))
	# the awning and the name over the way in
	g.aabb(p.trim, Vector3(-4.0, 3.0, d / 2 + T), Vector3(4.0, 3.25, d / 2 + T + 2.4))
	if not lod:
		if not p.has("_labels"): p["_labels"] = []
		if str(tw.name) != "": ShopGen._label(p, Vector3(0, 3.12, d / 2 + T + 2.42), str(tw.name), 0.2, 7.0, 0.0, Color(0.96, 0.95, 0.9))
	if tw.get("garages", false):
		# garages across the front of the ground floor: roller doors with a strip of wall between
		var ng := maxi(2, int(w / 3.4))
		for gi in ng:
			var gx0 := -w / 2 + 0.4 + (w - 0.8) * gi / ng + 0.15
			var gx1 := -w / 2 + 0.4 + (w - 0.8) * (gi + 1) / ng - 0.15
			g.aabb("tin:grey", Vector3(gx0, 0.05, d / 2 + T), Vector3(gx1, 2.3, d / 2 + T + 0.04), false)
			for k in 8:
				g.aabb("steel", Vector3(gx0, 0.25 + k * 0.27, d / 2 + T + 0.04), Vector3(gx1, 0.28 + k * 0.27, d / 2 + T + 0.05), false)

## The lift's panels: one in the car at every stop
static func lifts(p: Dictionary, root: Node3D) -> void:
	var stops := []
	var names := []
	var tw: Dictionary = p.tower
	for fi in p.floors.size():
		var f: Dictionary = p.floors[fi]
		for r in f.rooms:
			if r.type == "lift":
				stops.append(Vector3(0.0, float(f.y) + 0.1, (float(r.z0) + float(r.z1)) / 2 + 0.3))
				names.append("Ground" if fi == 0 else ("Level %d" % int(tw.mid) if fi == 1 else "Roof"))
	for i in stops.size():
		var l := BuildLift.new()
		root.add_child(l)
		l.setup(stops, names, i, float(p.d))
