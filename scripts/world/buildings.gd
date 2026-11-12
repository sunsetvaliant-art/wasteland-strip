class_name Buildings
extends Node3D
## Every house, shed and workshop on the map (assets/world/buildings.json, from tools/place_buildings.py), made by
## BuildGen from each lot's kind, size and seed, so every machine builds the same town.
##   - near you (FULL_R): the whole building, inside and out: rooms, doors, furniture, loot in the cupboards;
##   - further out (to LOD_R): just the outsides, merged a 200 m cell at a time into one mesh;
##   - beyond that: nothing.
## Cupboards remember what you left in them while you're away, and fill up again once you've been gone long enough.
## Trees, grass and camps keep off the lots (Buildings.blocked).

const CELL := 200.0
const FULL_R := 90.0
const FULL_DROP := 120.0
const LOD_R := 1150.0
const LOD_DROP := 1300.0
const RESPAWN_S := 1800.0          # half an hour away and the cupboards fill again

static var inst: Buildings
var main
var lots: Array = []               # [kind, x, z, yaw, w, d, seed]
var towns: Array = []
var lots_ver := ""                 # which lot list this is: a save made on a different one doesn't apply
var cells := {}                    # Vector2i -> [lot indices]
var _q := {}                       # Vector2i (50 m) -> [lot indices] for blocked()
var full := {}                     # lot index -> Node3D
var lod := {}                      # cell -> MeshInstance3D (or null while queued)
var _floor := {}                   # lot index -> floor height (cached)
var loot_store := {}               # "lot:box" -> {"inv": Dictionary, "t": float, "gen": int}
var boards := {}                   # "lot:d3" / "lot:w2" -> {"n": planks, "side": +1/-1}: boarded-up doors and windows
var broken := {}                   # "lot:w2" -> true: windows someone's put through
var cars_taken := {}               # lot -> true: its project car's been driven off (don't make another)
var _lot_cars := {}                # lot -> [Node3D, spawn position]
const DRIVE_CHANCE := {"qlder": 0.16, "cottage": 0.16, "brick": 0.18, "two_storey": 0.2, "shop": 0.05, "workshop": 0.2, "warehouse": 0.15}
const PROJECT_CHANCE := {"shop": 0.0, "qlder": 0.05, "cottage": 0.05, "brick": 0.04, "two_storey": 0.03, "shed": 0.15, "machine_shed": 0.22,
	"workshop": 0.2, "dairy": 0.08, "warehouse": 0.05}
var _dirty := {}                   # cells whose LOD mesh needs rebuilding
var _t := 0.0

static func available() -> bool:
	return FileAccess.file_exists("res://assets/world/buildings.json")

func setup(m) -> void:
	main = m
	inst = self
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/buildings.json"))
	if typeof(d) != TYPE_DICTIONARY:
		return
	lots = d.lots
	towns = d.get("towns", [])
	lots_ver = str(d.get("ver", ""))
	for i in lots.size():
		var l: Array = lots[i]
		var c := Vector2i(floori(float(l[1]) / CELL), floori(float(l[2]) / CELL))
		if not cells.has(c): cells[c] = []
		cells[c].append(i)
		var r := sqrt(float(l[4]) * float(l[4]) + float(l[5]) * float(l[5])) * 0.5 + 6.0
		for gx in range(floori((float(l[1]) - r) / 50.0), floori((float(l[1]) + r) / 50.0) + 1):
			for gz in range(floori((float(l[2]) - r) / 50.0), floori((float(l[2]) + r) / 50.0) + 1):
				var k := Vector2i(gx, gz)
				if not _q.has(k): _q[k] = []
				_q[k].append(i)
	print("BUILDINGS ", lots.size())

## Is (x, z) on a building's lot (within pad metres of its walls)?
static func blocked(x: float, z: float, pad := 0.0) -> bool:
	for e in _extra:
		if absf(x - float(e[0])) < 14.0 and absf(z - float(e[1])) < 14.0:
			var dx := x - float(e[0])
			var dz := z - float(e[1])
			var yw := float(e[2])
			if absf(dx * cos(yw) - dz * sin(yw)) < float(e[3]) * 0.5 + pad and absf(dx * sin(yw) + dz * cos(yw)) < float(e[4]) * 0.5 + pad:
				return true
	if inst == null:
		return false
	var k := Vector2i(floori(x / 50.0), floori(z / 50.0))
	if not inst._q.has(k):
		return false
	for i in inst._q[k]:
		var l: Array = inst.lots[i]
		var yaw := float(l[3])
		var dx := x - float(l[1])
		var dz := z - float(l[2])
		# into the lot's frame (Basis(UP, yaw) inverse)
		var lx := dx * cos(yaw) - dz * sin(yaw)
		var lz := dx * sin(yaw) + dz * cos(yaw)
		var hw := float(l[4]) * 0.5 + pad + 0.3
		var hd := float(l[5]) * 0.5 + pad + 0.3
		if l[0] == "qlder": hd += 3.0          # the verandah and its stairs
		if l[0] in ["shop", "mall"]: hd += 3.2          # the awning over the footpath
		if absf(lx) < hw and absf(lz) < hd + 1.5:
			return true
	return false

static var _extra: Array = []          # other things trees and grass keep off: [x, z, yaw, w, d]

static func add_blocker(x: float, z: float, yaw: float, w: float, d: float) -> void:
	_extra.append([x, z, yaw, w, d])

## Is anything built within r of (x, z)?
static func near_any(x: float, z: float, r: float) -> bool:
	for o in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if blocked(x + o.x, z + o.y, r * 0.5):
			return true
	return false

func _plan(i: int) -> Dictionary:
	var l: Array = lots[i]
	return BuildGen.plan(str(l[0]), float(l[4]), float(l[5]), int(l[6]), str(l[7]) if l.size() > 7 else "")

func _xf(i: int, p: Dictionary) -> Transform3D:
	var l: Array = lots[i]
	var basis := Basis(Vector3.UP, float(l[3]))
	if not _floor.has(i):
		var top := -INF
		var w: float = l[4]
		var d: float = l[5]
		for c in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5), Vector2.ZERO]:
			var wp := basis * Vector3(c.x * w, 0, c.y * d)
			top = maxf(top, main.height_at(float(l[1]) + wp.x, float(l[2]) + wp.z))
		_floor[i] = top + float(p.raised)
	return Transform3D(basis, Vector3(float(l[1]), float(_floor[i]), float(l[2])))

func _ground_fn(xf: Transform3D) -> Callable:
	var m = main
	return func(lx: float, lz: float) -> float:
		var wp := xf * Vector3(lx, 0, lz)
		return m.height_at(wp.x, wp.z) - xf.origin.y

func _focus() -> Vector3:
	if main.player == null:
		return Vector3.ZERO
	if main.forge and main.forge.active:
		return main.forge.cam.global_position
	return main.player.vehicle.global_position if main.player.vehicle else main.player.global_position

var _perf_t := 0.0
func _process(dt: float) -> void:
	if OS.get_environment("PERF") != "":
		_perf_t += dt
		if _perf_t > 10.0:
			_perf_t = 0.0
			print("PERF fps ", Engine.get_frames_per_second(), " full ", full.size(), " lod ", lod.size(), " props pending ", BuildProps.pending.size(), " t ", Time.get_ticks_msec() / 1000)
	if lots.is_empty() or main == null or main.player == null:
		return
	var me := _focus()
	_t -= dt
	if _t <= 0.0:
		_t = 0.5
		_update_sets(me)
	# one piece of work a frame: the nearest full build that's wanted, else a cell's LOD
	var best := -1
	var bd := INF
	for i in _want_full:
		if full.has(i): continue
		var d := _lot_dist(i, me)
		if d < bd:
			bd = d
			best = i
	if best >= 0:
		_build_full(best)
		_want_full.erase(best)
	BuildProps.work(3500)
	_lod_jobs()

var _want_full := {}

func _update_sets(me: Vector3) -> void:
	# full builds in and out
	var cr := int(ceil(FULL_DROP / CELL)) + 1
	var mc := Vector2i(floori(me.x / CELL), floori(me.z / CELL))
	for gx in range(mc.x - cr, mc.x + cr + 1):
		for gz in range(mc.y - cr, mc.y + cr + 1):
			for i in cells.get(Vector2i(gx, gz), []):
				var d := _lot_dist(i, me)
				if d < FULL_R and not full.has(i):
					_want_full[i] = true
	for i in full.keys():
		var d := _lot_dist(i, me)
		if d > FULL_DROP:
			_drop_full(i)
	for i in _want_full.keys():
		var d := _lot_dist(i, me)
		if d > FULL_DROP:
			_want_full.erase(i)
	# LOD cells in and out
	var lr := int(ceil(LOD_DROP / CELL)) + 1
	for gx in range(mc.x - lr, mc.x + lr + 1):
		for gz in range(mc.y - lr, mc.y + lr + 1):
			var c := Vector2i(gx, gz)
			if not cells.has(c): continue
			var d := Vector2((gx + 0.5) * CELL - me.x, (gz + 0.5) * CELL - me.z).length()
			if d < LOD_R and not lod.has(c):
				lod[c] = null
				_dirty[c] = true
	for c in lod.keys():
		var d := Vector2((c.x + 0.5) * CELL - me.x, (c.y + 0.5) * CELL - me.z).length()
		if d > LOD_DROP:
			if lod[c]: (lod[c] as Node).queue_free()
			lod.erase(c)
			_dirty.erase(c)

## Build everything within r of a point right now (loading a save inside a house)
func build_near_now(pos: Vector3, r: float) -> void:
	var c := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	for gx in range(c.x - 1, c.x + 2):
		for gz in range(c.y - 1, c.y + 2):
			for i in cells.get(Vector2i(gx, gz), []):
				if not full.has(i) and Vector2(float(lots[i][1]) - pos.x, float(lots[i][2]) - pos.z).length() < r + 10.0:
					_build_full(i)

func _cell_of(i: int) -> Vector2i:
	return Vector2i(floori(float(lots[i][1]) / CELL), floori(float(lots[i][2]) / CELL))

# far-off buildings: each cell's merged outside-only mesh is made on a worker thread (two at a time), the nearest
# wanted cell first; the main thread then gives it its (faded-near) materials and puts it in
var _lod_task := {}          # cell -> WorkerThreadPool task id
var _lod_done := {}          # cell -> ArrayMesh
var _lod_mutex := Mutex.new()

func _lod_jobs() -> void:
	var me := _focus()
	# collect finished
	for c in _lod_task.keys():
		if WorkerThreadPool.is_task_completed(_lod_task[c]):
			WorkerThreadPool.wait_for_task_completion(_lod_task[c])
			_lod_task.erase(c)
			_lod_mutex.lock()
			var am: ArrayMesh = _lod_done.get(c)
			_lod_done.erase(c)
			_lod_mutex.unlock()
			if am == null or not lod.has(c):
				continue
			for si in am.get_surface_count():
				am.surface_set_material(si, BuildGen.mat_lod(am.surface_get_name(si)))
			if lod[c]: (lod[c] as Node).queue_free()
			var mi := MeshInstance3D.new()
			mi.name = "LOD_%d_%d" % [c.x, c.y]
			mi.mesh = am
			add_child(mi)
			lod[c] = mi
	if _lod_task.size() >= 2 or _dirty.is_empty():
		return
	var c: Vector2i = _dirty.keys()[0]
	var bdc := INF
	for k in _dirty:
		var dd := Vector2((k.x + 0.5) * CELL - me.x, (k.y + 0.5) * CELL - me.z).length()
		if dd < bdc:
			bdc = dd
			c = k
	_dirty.erase(c)
	# what the thread needs: plans, transforms and ground heights worked out here (the terrain's read on this thread)
	var jobs := []
	for i in cells.get(c, []):
		var p := _plan(i)
		var xf := _xf(i, p)
		jobs.append([p, xf, _ground_table(xf, p)])
	_lod_task[c] = WorkerThreadPool.add_task(_lod_thread.bind(c, jobs))

## Ground heights under a building on a 2.4 m grid in its own frame, so the thread needn't touch the terrain
func _ground_table(xf: Transform3D, p: Dictionary) -> Dictionary:
	var w: float = p.w
	var d: float = p.d + (6.0 if p.verandah != null else 0.0)
	var t := {}
	var nx := int(ceil(w / 2.4)) + 2
	var nz := int(ceil(d / 2.4)) + 2
	for ix in nx + 1:
		for iz in nz + 1:
			var lx := -w / 2 - 1.2 + ix * 2.4
			var lz: float = -float(p.d) / 2 - 1.2 + iz * 2.4
			var wp := xf * Vector3(lx, 0, lz)
			t[Vector2i(ix, iz)] = main.height_at(wp.x, wp.z) - xf.origin.y
	return {"t": t, "x0": -w / 2 - 1.2, "z0": -float(p.d) / 2 - 1.2, "nx": nx, "nz": nz}

func _lod_thread(c: Vector2i, jobs: Array) -> void:
	var g := BuildGen.Geo.new()
	for j in jobs:
		var gt: Dictionary = j[2]
		var ground := func(lx: float, lz: float) -> float:
			var ix := clampi(roundi((lx - float(gt.x0)) / 2.4), 0, int(gt.nx))
			var iz := clampi(roundi((lz - float(gt.z0)) / 2.4), 0, int(gt.nz))
			return float(gt.t.get(Vector2i(ix, iz), 0.0))
		g.xf = j[1]
		BuildGen.build_lod(j[0], g, ground)
	var am := g.commit(false)
	_lod_mutex.lock()
	_lod_done[c] = am
	_lod_mutex.unlock()

func _build_full(i: int) -> void:
	var p := _plan(i)
	var xf := _xf(i, p)
	var b := BuildGen.build(p, _ground_fn(xf))
	b.name = "B%d" % i
	b.transform = xf
	add_child(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(lots[i][6])
	var boxes := BuildProps.furnish(p, b, rng)
	var now := Time.get_unix_time_from_system()
	for bi in boxes.size():
		var box: Node3D = boxes[bi]
		var key := "%d:%d" % [i, bi]
		box.set_meta("loot_key", key)
		var st: Dictionary = loot_store.get(key, {})
		var gen := int(st.get("gen", 0))
		if not st.is_empty() and now - float(st.t) < RESPAWN_S:
			box.set_meta("inv", st.inv)
		elif not st.is_empty():
			gen += 1                         # been away long enough: a fresh lot of loot
			loot_store.erase(key)
		box.set_meta("loot_seed", int(lots[i][6]) * 31 + bi * 7919 + gen * 104729)
		# further from the pub you started at, the riskier it is and the better the odd find
		box.set_meta("loot_bonus", clampf((Vector2(float(lots[i][1]), float(lots[i][2])).length() - 1500.0) / 6000.0, 0.0, 1.0))
		box.set_meta("loot_gen", gen)
	full[i] = b
	b.set_meta("plan", p)
	_project_car(i, p, b)
	if p.kind == "mall":
		_mall_life(i, p, b)
	# doors and windows as they were left
	for n in b.find_children("*", "", true, false):
		if n is BuildDoor or n is BuildWindow:
			n.key = "%d:%s" % [i, n.key]
			if n is BuildWindow and broken.has(n.key):
				(n as BuildWindow)._smash(false)
			if boards.has(n.key):
				board(n, int(boards[n.key].side), int(boards[n.key].n))
	_nav.erase(i)

# ------------------------------------------------------------------ getting about inside (for zombies and scavs)
var _nav := {}       # lot -> {"edges": [[a, b, [local points a->b]]], "rooms": {id: room}, "floors": [y]}

## Which full-built building (lot index) a point is in or right by, else -1
func lot_at(pt: Vector3, pad := 1.0) -> int:
	var k := Vector2i(floori(pt.x / 50.0), floori(pt.z / 50.0))
	for i in _q.get(k, []):
		if not full.has(i): continue
		var l: Array = lots[i]
		var yaw := float(l[3])
		var dx := pt.x - float(l[1])
		var dz := pt.z - float(l[2])
		var lx := dx * cos(yaw) - dz * sin(yaw)
		var lz := dx * sin(yaw) + dz * cos(yaw)
		var extra := 3.5 if l[0] == "qlder" else 0.0
		if absf(lx) < float(l[4]) * 0.5 + pad and lz > -float(l[5]) * 0.5 - pad and lz < float(l[5]) * 0.5 + pad + extra:
			return i
	return -1

func _room_of(p: Dictionary, lp: Vector3) -> String:
	var best_f := -1
	for fi in p.floors.size():
		if float(p.floors[fi].y) <= lp.y + 0.8: best_f = fi
	if best_f < 0:
		return "out"
	for r in p.floors[best_f].rooms:
		if lp.x >= float(r.x0) - 0.05 and lp.x <= float(r.x1) + 0.05 and lp.z >= float(r.z0) - 0.05 and lp.z <= float(r.z1) + 0.05:
			return r.id
	return "out"

func _nav_of(i: int) -> Dictionary:
	if _nav.has(i):
		return _nav[i]
	var p: Dictionary = full[i].get_meta("plan")
	var edges := []
	var flights: Array = p.get("flights", [])
	for fi in p.floors.size():
		var fy := float(p.floors[fi].y)
		for r in p.floors[fi].rooms:
			for side in ["N", "S", "W", "E"]:
				for op in r.ops[side]:
					if op.kind not in ["door", "open", "arch", "roller", "bay"]: continue
					var c := (float(op.a) + float(op.b)) * 0.5
					var pt: Vector3
					var outv: Vector3
					match side:
						"N": pt = Vector3(c, fy, float(r.z0)); outv = Vector3(0, 0, -1)
						"S": pt = Vector3(c, fy, float(r.z1)); outv = Vector3(0, 0, 1)
						"W": pt = Vector3(float(r.x0), fy, c); outv = Vector3(-1, 0, 0)
						_: pt = Vector3(float(r.x1), fy, c); outv = Vector3(1, 0, 0)
					var inside := pt - outv * (0.6 + float(op.get("recess", 0.0)))
					if op.get("ext", false):
						# out the door, and down the steps if there are any
						var pts := [inside, pt, pt + outv * 0.7]
						if op.kind == "bay": pts = [inside, pt - outv * (float(op.recess) - 0.2), pt, pt + outv * 0.7]
						var best := {}
						var bd := 4.4
						for fl in flights:
							var dd := Vector2(fl.top.x - pt.x, fl.top.z - pt.z).length()
							if dd < bd and absf(float(fl.top.y) - fy) < 0.5:
								bd = dd
								best = fl
						if not best.is_empty():
							pts.append(best.top)
							pts.append(best.foot)
						else:
							pts.append(pt + outv * 1.6 + Vector3(0, -float(p.raised), 0))
						edges.append([r.id, "out", pts])
					else:
						var nb := _room_of_floor(p, fi, pt + outv * 0.3)
						if nb != "" and nb != r.id:
							edges.append([r.id, nb, [inside, pt, pt + outv * 0.6]])
			if r.type == "stair" and fi + 1 < p.floors.size():
				var cx := (float(r.x0) + float(r.x1)) * 0.5
				var up := _room_of_floor(p, fi + 1, Vector3(cx, 0, float(r.z0) - 0.4))
				if up != "":
					edges.append([r.id, up, [Vector3(cx, fy, float(r.z1) + 0.3), Vector3(cx, fy, float(r.z1) - 0.2),
						Vector3(cx, float(p.floors[fi + 1].y), float(r.z0) + 0.1), Vector3(cx, float(p.floors[fi + 1].y), float(r.z0) - 0.5)]])
	for e in p.get("nav_extra", []):
		edges.append(e)
	_nav[i] = {"edges": edges}
	return _nav[i]

func _room_of_floor(p: Dictionary, fi: int, lp: Vector3) -> String:
	for r in p.floors[fi].rooms:
		if lp.x >= float(r.x0) and lp.x <= float(r.x1) and lp.z >= float(r.z0) and lp.z <= float(r.z1):
			return r.id
	return ""

## Waypoints (world) from a to b through a building's doors and stairs, when either end is in one; else empty
func route(a: Vector3, b: Vector3) -> Array:
	var ib := lot_at(b)
	var ia := lot_at(a)
	var i := ib if ib >= 0 else ia
	if i < 0:
		return []
	var p: Dictionary = full[i].get_meta("plan")
	var xf: Transform3D = full[i].global_transform
	var inv := xf.affine_inverse()
	var ra := _room_of(p, inv * a) if ia == i else "out"
	var rb := _room_of(p, inv * b) if ib == i else "out"
	if ra == rb:
		return []
	var nav := _nav_of(i)
	# breadth first over rooms
	var prev := {ra: null}
	var q := [ra]
	while not q.is_empty():
		var cur: String = q.pop_front()
		if cur == rb: break
		for e in nav.edges:
			var nxt := ""
			var pts: Array
			if e[0] == cur: nxt = e[1]; pts = e[2]
			elif e[1] == cur: nxt = e[0]; pts = (e[2] as Array).duplicate(); pts.reverse()
			else: continue
			if prev.has(nxt): continue
			prev[nxt] = [cur, pts]
			q.append(nxt)
	if not prev.has(rb):
		return []
	var out := []
	var n = rb
	while prev[n] != null:
		var pts: Array = prev[n][1]
		var w := []
		for lp in pts: w.append(xf * (lp as Vector3))
		out = w + out
		n = prev[n][0]
	if rb == "out" and ib != i:
		pass
	return out

## Now and then a rolling chassis or a loose body: in the shed, or out the back of the house
func _project_car(i: int, p: Dictionary, b: Node3D) -> void:
	if cars_taken.has(i) or main == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(lots[i][6]) + 991
	var cat: Dictionary = Car.catalog()
	var keys: Array = cat.keys()
	if rng.randf() > float(PROJECT_CHANCE.get(p.kind, 0.0)):
		# no project in the shed: perhaps the family car's still in the drive, in whatever state it was left
		if rng.randf() < float(DRIVE_CHANCE.get(p.kind, 0.0)):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var dl := Vector3(side * (float(p.w) / 2 + 2.3), 0.0, float(p.d) / 2 - rng.randf_range(2.5, 5.0))
			var dw: Vector3 = b.global_transform * dl
			if not Buildings.blocked(dw.x, dw.z, 1.6) and (main.veg == null or main.veg.road_clearance(dw.x, dw.z) > 2.5):
				var dk: String = keys[rng.randi() % keys.size()]
				var dn: Car = main.spawn_vehicle(dk, Vector3(dw.x, main.height_at(dw.x, dw.z) + 0.9, dw.z), b.rotation.y + rng.randf_range(-0.12, 0.12) + (PI if rng.randf() < 0.3 else 0.0), VehicleSpecs.default_design(dk))
				_lot_cars[i] = [dn, dn.global_position]
		return
	var kind: String = keys[rng.randi() % keys.size()]
	var shedlike: bool = p.kind in ["shed", "machine_shed", "workshop", "warehouse", "dairy"]
	var lp := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.5, 1.5)) if shedlike else Vector3(rng.randf_range(-2.0, 2.0), 0.0, -float(p.d) / 2 - 5.0)
	var wp: Vector3 = b.global_transform * lp
	var yaw: float = b.rotation.y + (PI * 0.5 if p.kind == "machine_shed" else 0.0) + rng.randf_range(-0.3, 0.3)
	var gy: float = main.height_at(wp.x, wp.z) if not shedlike else b.global_position.y
	var node: Node3D
	if rng.randf() < 0.55:
		var design := VehicleSpecs.default_design(kind)
		design["no_cab"] = true
		node = main.spawn_vehicle(kind, Vector3(wp.x, gy + 1.0, wp.z), yaw, design)
	else:
		node = _shell(kind, Vector3(wp.x, gy, wp.z), yaw, rng)
	_lot_cars[i] = [node, node.global_position]

## A car body off its chassis, sat on the ground (not drivable: put it on a chassis in the garage)
func _shell(kind: String, pos: Vector3, yaw: float, rng: RandomNumberGenerator) -> Node3D:
	var d: Dictionary = Car.catalog()[kind]
	var sb := StaticBody3D.new()
	sb.set_meta("shell", kind)
	add_child(sb)
	var body: Node3D = load("res://assets/vehicles/%s.glb" % d.glb).instantiate()
	body.rotation_degrees.y = -90
	sb.add_child(body)
	var mn: Array = d.min
	var ext: Array = d.ext
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(float(ext[2]) * 0.95, float(ext[1]) * 0.9, float(ext[0]) * 0.97)
	cs.shape = bs
	cs.position = Vector3(0, float(mn[1]) + float(ext[1]) * 0.45, float(mn[0]) + float(ext[0]) * 0.5)
	sb.add_child(cs)
	sb.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, rng.randf_range(-0.04, 0.04)) * Basis(Vector3.BACK, rng.randf_range(-0.04, 0.04)),
		pos + Vector3(0, -float(mn[1]) - 0.12, 0))
	return sb

## A mall's crowd and the cars left in its car park: the dead in their dozens, shuffling about the concourse, the
## supermarket, the food court and the car park, until they hear you. Killed off, they stay gone a good while.
var _hordes := {}           # lot -> [zombies]
var _mall_cars := {}        # lot -> [wrecks]
var horde_cleared := {}     # lot -> when the last of them went down
const HORDE := 26

func _mall_life(i: int, p: Dictionary, b: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(lots[i][6]) + 4242
	var xf := b.global_transform
	# wrecks in the bays
	var wrecks := []
	var cat: Dictionary = Car.catalog()
	var keys: Array = cat.keys()
	for r in p.floors[0].rooms:
		if r.type != "carpark" or (float(r.x1) - float(r.x0)) * (float(r.z1) - float(r.z0)) < 200.0: continue
		for k in rng.randi_range(2, 5):
			var lp := Vector3(rng.randf_range(float(r.x0) + 3.0, float(r.x1) - 3.0), 0.0, rng.randf_range(float(r.z0) + 3.0, float(r.z1) - 3.0))
			var yaw := xf.basis.get_euler().y + (PI / 2 if rng.randf() < 0.5 else -PI / 2) + rng.randf_range(-0.15, 0.15)
			wrecks.append(_shell(keys[rng.randi() % keys.size()], xf * lp, yaw, rng))
	_mall_cars[i] = wrecks
	# the crowd
	if main.net and not main.net.runs_world(): return
	if OS.get_environment("NPC_OFF") != "": return
	if horde_cleared.has(i) and Time.get_unix_time_from_system() - float(horde_cleared[i]) < RESPAWN_S * 4.0: return
	var spots := []
	for fi in p.floors.size():
		for r in p.floors[fi].rooms:
			if r.type in ["concourse", "super", "foodcourt", "carpark", "bigbox", "lobby", "super_store"]:
				spots.append([r, float(p.floors[fi].y)])
	var crowd := []
	for k in HORDE:
		var e: Array = spots[rng.randi() % spots.size()]
		var r: Dictionary = e[0]
		var lp := Vector3(rng.randf_range(float(r.x0) + 1.0, float(r.x1) - 1.0), float(e[1]) + 0.15, rng.randf_range(float(r.z0) + 1.0, float(r.z1) - 1.0))
		var z := NPC.new()
		z.kind = "zombie"
		main.add_child(z)
		z.global_position = xf * lp
		z.rotation.y = rng.randf() * TAU
		z.home = z.global_position
		z.goal = z.global_position
		crowd.append(z)
	_hordes[i] = crowd

## How far a lot is, for deciding whether to build it in full: to its middle, less most of its half-size for a big one
## (a mall's edge is a long way from its middle)
func _lot_dist(i: int, me: Vector3) -> float:
	var l: Array = lots[i]
	return Vector2(float(l[1]) - me.x, float(l[2]) - me.z).length() - maxf(0.0, maxf(float(l[4]), float(l[5])) * 0.5 - 12.0)

func _drop_full(i: int) -> void:
	_nav.erase(i)
	for n in _mall_cars.get(i, []):
		if is_instance_valid(n): n.queue_free()
	_mall_cars.erase(i)
	if _hordes.has(i):
		var left := 0
		for z in _hordes[i]:
			if is_instance_valid(z) and not z.dead:
				left += 1
				z.free_body()
		if left == 0: horde_cleared[i] = Time.get_unix_time_from_system()
		_hordes.erase(i)
	if _lot_cars.has(i):
		var e: Array = _lot_cars[i]
		_lot_cars.erase(i)
		var n = e[0]
		if is_instance_valid(n):
			if n is Car and ((n as Car).has_meta("player_car") or (n as Car).global_position.distance_to(e[1]) > 6.0):
				cars_taken[i] = true            # someone's had it: it's theirs now
			else:
				n.queue_free()
	var b: Node3D = full[i]
	full.erase(i)
	_save_boxes(b)
	b.queue_free()

func _save_boxes(b: Node) -> void:
	var now := Time.get_unix_time_from_system()
	for n in b.find_children("*", "", true, false):
		if n.has_meta("loot_key") and n.has_meta("inv"):
			var key: String = n.get_meta("loot_key")
			loot_store[key] = {"inv": n.get_meta("inv"), "t": now, "gen": int(n.get_meta("loot_gen", 0))}   # t: when you left it

## Nail planks across a door or window (side: which face, +1 / -1 along its z); remembered for next time
func board(host: Node3D, side: int, n: int) -> Boards:
	var bd := Boards.new()
	bd.key = str(host.get("key"))
	if host is BuildDoor:
		var d: BuildDoor = host
		if d.open: d.toggle()
		d.pivot.rotation.y = 0.0
		d._angle = 0.0
		d._target = 0.0
		d.open = false
		var frame := Node3D.new()
		d.pivot.get_parent().add_child(frame)
		frame.transform = d.pivot.transform
		frame.add_child(bd)
		bd.setup(d.leaf_w, d.leaf_h, d.leaf_w * 0.5, d.leaf_h * 0.5, side, n)
	else:
		var w: BuildWindow = host
		w.add_child(bd)
		bd.setup(w.w, w.h, 0.0, 0.0, side, n)
	bd.host = host
	host.set("boards", bd)
	boards[bd.key] = {"n": n, "side": side}
	return bd

## For the world save: what's been taken out of which cupboards, what's boarded up, which windows are smashed
func save_state() -> Dictionary:
	for i in full:
		_save_boxes(full[i])
	return {"loot": loot_store, "boards": boards, "broken": broken, "cars_taken": cars_taken, "lots_ver": lots_ver, "hordes": horde_cleared}

func load_state(d: Dictionary) -> void:
	if str(d.get("lots_ver", "")) != lots_ver:
		print("SAVE buildings from a different town layout: cupboards and boards start fresh")
		return
	loot_store = d.get("loot", {})
	boards = d.get("boards", {})
	broken = d.get("broken", {})
	cars_taken = d.get("cars_taken", {})
	horde_cleared = d.get("hordes", {})

## The nearest town's name to a point (fictional names on the real towns)
func town_at(x: float, z: float, r := 2500.0) -> String:
	var best := ""
	var bd := r
	for t in towns:
		var d := Vector2(float(t.x) - x, float(t.z) - z).length()
		if d < bd:
			bd = d
			best = t.name
	return best
