class_name CivicGen
extends RefCounted
## The buildings a town has one or two of: the pub, the school, the church, the hospital, the police and fire stations,
## the post office, the motel, the hall or club. Each is a floor plan of rooms like a house's (so walls, doors,
## windows, furniture, loot and zombies finding their way all come from the house generator), laid out the way that
## kind of place is, with its name over the door. tools/place_buildings.py puts them where OpenStreetMap says they are.

const KINDS := ["pub", "school", "church", "hospital", "police", "fire", "post", "motel", "club"]
const SIGN := {"pub": ["HOTEL", "THE ROYAL HOTEL", "COMMERCIAL HOTEL", "THE RIVERVIEW", "IMPERIAL HOTEL"], "school": ["PUBLIC SCHOOL", "PRIMARY SCHOOL", "HIGH SCHOOL"],
	"church": ["ST MARY'S", "UNITING CHURCH", "ST ANDREW'S", "ALL SAINTS"], "hospital": ["DISTRICT HOSPITAL", "MEDICAL CENTRE", "COMMUNITY HEALTH"],
	"police": ["POLICE"], "fire": ["FIRE STATION"], "post": ["POST OFFICE"], "motel": ["MOTEL", "MOTOR INN", "TRAVELLERS REST MOTEL"],
	"club": ["RSL CLUB", "BOWLS CLUB", "COMMUNITY HALL", "SERVICES CLUB", "SCHOOL OF ARTS"]}

static func plan_into(p: Dictionary, kind: String, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var tint: String = ["cream", "white", "green", "blue", "yellow", "white"][rng.randi() % 6]
	p.raised = 0.3
	p.h = 3.0
	p.clad = "brick"
	p.roof = {"type": "hip", "pitch": deg_to_rad(rng.randf_range(20, 26)), "mat": "tin"}
	p["sign"] = SIGN[kind][rng.randi() % SIGN[kind].size()]
	var rooms := []
	match kind:
		"pub":
			# the public bar across the front under a verandah, the lounge beside it, kitchen, cool room and toilets behind
			p.clad = "weatherboard:" + tint if rng.randf() < 0.5 else "brick"
			p.h = 3.4
			p.verandah = {"depth": 2.6, "sides": false}
			var zb := -d / 2 + clampf(d * 0.32, 3.2, 6.0)
			var xs := -w / 2 + w * 0.62
			rooms.append({"x0": -w / 2, "z0": zb, "x1": xs, "z1": d / 2, "type": "shop", "sub": "pub", "hub": true, "entry": true})
			rooms.append({"x0": xs, "z0": zb, "x1": w / 2, "z1": d / 2, "type": "dining", "entry": true})
			_cut_row(rooms, -w / 2, w / 2, -d / 2, zb, ["kitchen", "store", "toilet", "toilet", "office"])
		"church":
			# the nave under a steep roof, the vestry and a store behind the altar
			p.clad = ["weatherboard:white", "weatherboard:cream", "brick"][rng.randi() % 3]
			p.h = 4.6
			p.roof = {"type": "gable", "ridge": "z", "pitch": deg_to_rad(rng.randf_range(36, 44)), "mat": "tin"}
			var zb := -d / 2 + clampf(d * 0.2, 2.6, 4.0)
			rooms.append({"x0": -w / 2, "z0": zb, "x1": w / 2, "z1": d / 2, "type": "nave", "hub": true, "entry": true})
			_cut_row(rooms, -w / 2, w / 2, -d / 2, zb, ["office", "store"])
		"school":
			_corridor(rooms, w, d, ["classroom", "classroom", "reception", "classroom", "classroom"], ["classroom", "classroom", "lunch", "toilet", "toilet", "store"], 7.0)
			p.clad = "brick" if rng.randf() < 0.5 else "weatherboard:" + tint
		"hospital":
			_corridor(rooms, w, d, ["ward", "reception", "dispensary", "ward"], ["ward", "ward", "office", "store", "toilet", "bath"], 6.0)
			p.clad = "plaster:white" if rng.randf() < 0.5 else "brick"
		"police":
			_corridor(rooms, w, d, ["office", "reception", "office"], ["cell", "cell", "armoury", "lunch", "toilet"], 4.5)
		"club":
			# the big room, a kitchen and bar behind, toilets
			p.h = 3.8
			p.clad = "brick" if rng.randf() < 0.6 else "fibro:" + tint
			var zb := -d / 2 + clampf(d * 0.3, 3.0, 6.0)
			rooms.append({"x0": -w / 2, "z0": zb, "x1": w / 2, "z1": d / 2, "type": "clubroom", "hub": true, "entry": true})
			_cut_row(rooms, -w / 2, w / 2, -d / 2, zb, ["kitchen", "store", "toilet", "toilet", "office"])
		"post":
			var zb := -d / 2 + clampf(d * 0.4, 3.0, 7.0)
			rooms.append({"x0": -w / 2, "z0": zb, "x1": w / 2, "z1": d / 2, "type": "shop", "sub": "newsagent", "hub": true, "entry": true})
			_cut_row(rooms, -w / 2, w / 2, -d / 2, zb, ["store", "office", "toilet"])
		"fire":
			# the engine bay with its big doors, the watch room, mess and bunks beside it
			p.h = 4.4
			p.clad = "brick"
			var xs := -w / 2 + clampf(w * 0.58, 6.0, 14.0)
			rooms.append({"x0": -w / 2, "z0": -d / 2, "x1": xs, "z1": d / 2, "type": "workshop", "hub": true, "bay": true})
			var n := 4
			var types := ["office", "lunch", "bed", "toilet"]
			for k in n:
				rooms.append({"x0": xs, "z0": snappedf(d / 2 - d * (k + 1) / n, 0.01), "x1": w / 2, "z1": snappedf(d / 2 - d * k / n, 0.01), "type": types[k], "entry": k == 0})
		"motel":
			# a row of rooms each with its own door onto the car park and a bathroom behind; the office at one end
			p.h = 2.7
			p.clad = "brick" if rng.randf() < 0.6 else "fibro:" + tint
			p.roof = {"type": "gable", "pitch": deg_to_rad(18), "mat": "tin"}
			var n := maxi(3, int(w / 4.6))
			var zb := -d / 2 + clampf(d * 0.3, 2.0, 2.8)
			for k in n:
				var a := snappedf(-w / 2 + w * k / n, 0.01)
				var b := snappedf(-w / 2 + w * (k + 1) / n, 0.01)
				rooms.append({"x0": a, "z0": zb, "x1": b, "z1": d / 2, "type": "reception" if k == 0 else "bed", "entry": true, "hub": k == 0})
				rooms.append({"x0": a, "z0": -d / 2, "x1": b, "z1": zb, "type": "store" if k == 0 else "bath"})
	p.floors.append({"y": 0.0, "h": p.h, "rooms": rooms})

## A row of rooms a..b wide between z0 and z1, in the order given (toilets narrow)
static func _cut_row(rooms: Array, a: float, b: float, z0: float, z1: float, types: Array) -> void:
	var wts := []
	var tot := 0.0
	for t in types:
		var wt: float = {"toilet": 0.5, "bath": 0.6, "store": 0.8, "cell": 0.6, "armoury": 0.8}.get(t, 1.0)
		wts.append(wt)
		tot += wt
	var x := a
	for i in types.size():
		var nx := b if i == types.size() - 1 else snappedf(x + (b - a) * wts[i] / tot, 0.01)
		rooms.append({"x0": x, "z0": z0, "x1": nx, "z1": z1, "type": types[i]})
		x = nx

## A passage down the middle with rooms off both sides; the front room called "reception" has the street door.
## Short of room for every room named (each wants `per` metres), the list is trimmed from the ends.
static func _corridor(rooms: Array, w: float, d: float, front: Array, back: Array, per: float) -> void:
	var nf := clampi(int(w / per), 2, front.size())
	var f: Array = front.duplicate()
	while f.size() > nf:
		if f[0] != "reception": f.remove_at(0)
		else: f.remove_at(f.size() - 1)
	var b: Array = back.duplicate()
	while b.size() > maxi(2, int(w / (per * 0.7))): b.remove_at(0)
	rooms.append({"x0": -w / 2, "z0": -0.9, "x1": w / 2, "z1": 0.9, "type": "hall", "hub": true})
	_cut_row(rooms, -w / 2, w / 2, 0.9, d / 2, f)
	_cut_row(rooms, -w / 2, w / 2, -d / 2, -0.9, b)
	for r in rooms:
		if r.type == "reception": r["entry"] = true

## The street doors (called from BuildGen._ext_doors)
static func ext_doors(p: Dictionary, rng: RandomNumberGenerator) -> void:
	var d: float = p.d
	for r in p.floors[0].rooms:
		if absf(float(r.z1) - d / 2) > 0.02: continue
		if r.get("bay", false):
			var a := float(r.x0) + 0.8
			while a + 3.6 < float(r.x1) - 0.4:
				var op := BuildGen._add_op(r, "S", a, a + 3.6, "roller", 0.0, 3.6)
				op["ext"] = true
				op["open_frac"] = [0.0, 0.5, 1.0][rng.randi() % 3]
				a += 4.6
			continue
		if not r.get("entry", false): continue
		var c := (float(r.x0) + float(r.x1)) / 2.0 - BuildGen.DOOR_W / 2
		var op := BuildGen._add_op(r, "S", c, c + BuildGen.DOOR_W, "door", 0.0, BuildGen.DOOR_H)
		op["leaf"] = true
		op["ext"] = true
		p.ext_doors.append({"room": r, "side": "S", "c": c + BuildGen.DOOR_W / 2, "front": true})
