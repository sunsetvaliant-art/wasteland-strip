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
const FULL_R := 135.0
const FULL_DROP := 175.0
const LOD_R := 1150.0
const LOD_DROP := 1300.0
const RESPAWN_S := 1800.0          # half an hour away and the cupboards fill again

static var inst: Buildings
var main
var lots: Array = []               # [kind, x, z, yaw, w, d, seed]
var towns: Array = []
var cells := {}                    # Vector2i -> [lot indices]
var _q := {}                       # Vector2i (50 m) -> [lot indices] for blocked()
var full := {}                     # lot index -> Node3D
var lod := {}                      # cell -> MeshInstance3D (or null while queued)
var _floor := {}                   # lot index -> floor height (cached)
var loot_store := {}               # "lot:box" -> {"inv": Dictionary, "t": float, "gen": int}
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
	return BuildGen.plan(str(l[0]), float(l[4]), float(l[5]), int(l[6]))

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

func _process(dt: float) -> void:
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
		var d := Vector2(float(lots[i][1]) - me.x, float(lots[i][2]) - me.z).length()
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
				var d := Vector2(float(lots[i][1]) - me.x, float(lots[i][2]) - me.z).length()
				if d < FULL_R and not full.has(i):
					_want_full[i] = true
	for i in full.keys():
		var d := Vector2(float(lots[i][1]) - me.x, float(lots[i][2]) - me.z).length()
		if d > FULL_DROP:
			_drop_full(i)
	for i in _want_full.keys():
		var d := Vector2(float(lots[i][1]) - me.x, float(lots[i][2]) - me.z).length()
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

func _drop_full(i: int) -> void:
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

## For the world save: what's been taken out of which cupboards
func save_state() -> Dictionary:
	for i in full:
		_save_boxes(full[i])
	return {"loot": loot_store}

func load_state(d: Dictionary) -> void:
	loot_store = d.get("loot", {})

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
