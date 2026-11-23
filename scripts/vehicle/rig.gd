class_name VehicleRig
extends Node3D
## Everything under the body you can see and watch work: ladder frame, crossmembers, the engine, tailshaft,
## live-axle housings with the diff, leaf packs that bend with the axle, shocks that telescope, front wishbones,
## uprights, coil-overs, sway bar with end links, tie rods, and the wheels. Driven every frame from the car's sim state.

var car
var frame_y := 0.0
var m_frame: StandardMaterial3D
var m_steel: StandardMaterial3D
var m_spring: StandardMaterial3D
var m_shock: StandardMaterial3D
var m_chrome: StandardMaterial3D
var box_mesh: BoxMesh
var cyl_mesh: CylinderMesh
var coil_mesh: ArrayMesh
var wheel_nodes: Array = []       # per wheel: {pivot, spin, model}
## wheel models you can pick in the garage ("" = the stock car / 4x4 steelie by tyre size)
const WHEEL_MODELS := {
	"stock": {"name": "Stock steelies", "path": ""},
	"globe": {"name": "Globe mags (from the old build)", "path": "res://assets/props/globe.glb"},
	"rim4x4": {"name": "4x4 steelies", "path": "res://assets/vehicles/wheel_4x4.glb"},
	"car": {"name": "Car steelies", "path": "res://assets/vehicles/wheel_car.glb"},
	# 0.2.59: from Sketchfab (CC Attribution, credits in assets/credits.json), put to size by tools/import_wheel.py
	"jag20": {"name": "20-spoke mags", "path": "res://assets/vehicles/wheels/jag20.glb"},
	"stance_r13": {"name": "Wide 13 inch steelies", "path": "res://assets/vehicles/wheels/stance_r13.glb"},
	"saab": {"name": "Turbine alloys", "path": "res://assets/vehicles/wheels/saab.glb"},
	"r33": {"name": "Five-spoke alloys", "path": "res://assets/vehicles/wheels/r33.glb"},
	"tractor_lug": {"dir": -1, "name": "Tractor lugs", "path": "res://assets/vehicles/wheels/tractor_lug.glb"},
	"r6_front": {"dir": 1, "name": "Tractor front (R6)", "path": "res://assets/vehicles/wheels/r6_front.glb"},
	"r6_rear": {"dir": 1, "name": "Tractor rear (R6)", "path": "res://assets/vehicles/wheels/r6_rear.glb"},
	# 0.2.60: the user's picks (credits in assets/credits.json)
	"wire": {"name": "Wire spokes", "path": "res://assets/vehicles/wheels/wheel_a.glb"},
	"nissan_oem": {"name": "Nissan factory alloys", "path": "res://assets/vehicles/wheels/nissan_oem.glb"},
	"offroad_mt": {"name": "Mud terrains", "path": "res://assets/vehicles/wheels/offroad_mt.glb"},
	"jdm_1": {"name": "JDM rims: mesh", "path": "res://assets/vehicles/wheels/jdm_1.glb"},
	"jdm_2": {"name": "JDM rims: ten spoke", "path": "res://assets/vehicles/wheels/jdm_2.glb"},
	"jdm_3": {"name": "JDM rims: split spoke", "path": "res://assets/vehicles/wheels/jdm_3.glb"},
	"jdm_4": {"name": "JDM rims: five hole", "path": "res://assets/vehicles/wheels/jdm_4.glb"},
	"f100": {"name": "F100 steelies", "path": "res://assets/vehicles/wheels/f100.glb"},
	"hilux_dc": {"name": "Hilux alloys (2001)", "path": "res://assets/vehicles/wheels/hilux_dc.glb"},
	"bseries_dc": {"name": "Mazda B-Series alloys", "path": "res://assets/vehicles/wheels/bseries_dc.glb"},
	"ranger_dc": {"name": "Ranger alloys (2003)", "path": "res://assets/vehicles/wheels/ranger_dc.glb"},
	"vz_ute": {"name": "VZ ute steelies", "path": "res://assets/vehicles/wheels/vz_ute.glb"},
	"fl_front": {"name": "Forklift solids (drive)", "path": "res://assets/vehicles/wheels/fl_front.glb"},
	"fl_rear": {"name": "Forklift solids (steer)", "path": "res://assets/vehicles/wheels/fl_rear.glb"},
}
var beams: Array = []             # [{mi, fn: Callable}] updated every frame
var tailshaft: MeshInstance3D
var engine_node: Node3D

func setup(c) -> void:
	car = c
	var d: Dictionary = car.design
	frame_y = float(d.ride) + 0.16
	# 0.2.65: dull painted steel, not cartoon red and yellow
	m_frame = _mat(Color(0.075, 0.072, 0.07), 0.3, 0.72)
	m_frame.cull_mode = BaseMaterial3D.CULL_DISABLED
	m_steel = _mat(Color(0.2, 0.19, 0.18), 0.5, 0.6)
	m_spring = _mat(Color(0.1, 0.1, 0.105), 0.35, 0.55)
	m_shock = _mat(Color(0.06, 0.06, 0.065), 0.25, 0.5)
	m_chrome = _mat(Color(0.8, 0.8, 0.82), 1.0, 0.15)
	box_mesh = BoxMesh.new()
	cyl_mesh = CylinderMesh.new()
	cyl_mesh.top_radius = 0.5
	cyl_mesh.bottom_radius = 0.5
	cyl_mesh.height = 1.0
	cyl_mesh.radial_segments = 12
	coil_mesh = _make_coil(7.0, 0.5, 0.085)
	_build_profile()
	# 0.2.66: a machine with its own frame under the body (the forklift) has none of the car's chassis parts drawn
	var own_frame: bool = car.def.has("forks")
	if not own_frame: _build_frame()
	_build_engine()
	if own_frame and engine_node: engine_node.visible = false
	_build_wheels()
	if not own_frame:
		for ai in d.axles.size():
			var a: Dictionary = d.axles[ai]
			if a.type == "live": _build_live_axle(ai, a)
			else: _build_ifs(ai, a)
		_build_tailshaft()

func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m

func _part(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	return mi

## a box or cylinder stretched from a to b (local space), w x h cross-section
func _stretch(mi: MeshInstance3D, a: Vector3, b: Vector3, w: float, h: float, cyl := false) -> void:
	var dvec := b - a
	var L := dvec.length()
	if L < 0.0001:
		mi.visible = false
		return
	mi.visible = true
	var y := dvec / L
	var x := y.cross(Vector3.FORWARD if abs(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	if cyl:
		mi.transform = Transform3D(Basis(x * w, y * L, z * h), (a + b) * 0.5)
	else:
		mi.transform = Transform3D(Basis(x * w, y * L, z * h), (a + b) * 0.5)

func _beam(mesh: Mesh, mat: Material, w: float, h: float, fn: Callable, cyl := false) -> MeshInstance3D:
	var mi := _part(mesh, mat)
	beams.append({"mi": mi, "fn": fn, "w": w, "h": h, "cyl": cyl})
	return mi

func _make_coil(turns: float, radius: float, wire: float) -> ArrayMesh:
	# unit-height helix along +Y centred on the origin; scaled to the spring's length every frame
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := int(turns * 16)
	var ring := 6
	for i in segs:
		for j in ring:
			for k in [[i, j], [i + 1, j], [i, j + 1], [i, j + 1], [i + 1, j], [i + 1, j + 1]]:
				var t: float = float(k[0]) / segs
				var a: float = t * turns * TAU
				var c := Vector3(cos(a) * radius, t - 0.5, sin(a) * radius)
				var tang := Vector3(-sin(a) * radius * turns * TAU, 1.0, cos(a) * radius * turns * TAU).normalized()
				var nrm := Vector3(cos(a), 0, sin(a))
				var bin := tang.cross(nrm).normalized()
				var b: float = float(k[1]) / ring * TAU
				var o := (nrm * cos(b) + bin * sin(b)) * wire
				st.set_normal(o.normalized())
				st.add_vertex(c + o)
	return st.commit()

# ---------------------------------------------------------------- frame and engine
# 0.2.65: a ladder chassis like a real one: the rails kick up over each axle (the axle has to move up under them), the
# rear section stays up behind the back axle, the front pinches in ahead of the cab for the engine and steering lock,
# crossmembers at the front, the engine, the gearbox, ahead of the rear axle and the back. One mesh, one draw call.
var prof: Array = []              # [z, centre y, half width] from the back of the frame to the front, every 5 cm
const RAIL_W := 0.07
const RAIL_H := 0.15

func _axle_kick(a: Dictionary) -> float:
	# rail bottom clear of the housing top at full bump (the wheel's up 0.6 x travel from where it sits)
	var y_top := float(car.design.ride) - float(a.get("lift", 0.0)) + 0.6 * float(a.travel) + 0.05 + 0.03
	return maxf(0.0, y_top + RAIL_H * 0.5 - frame_y)

func _build_profile() -> void:
	var fr: Dictionary = car.design.frame
	var z_r := float(fr.z) - float(fr.len) * 0.5
	var z_f := float(fr.z) + float(fr.len) * 0.5
	var hw := float(fr.width) * 0.5
	var axles: Array = car.design.axles
	var zmin := INF; var zmax := -INF
	for a in axles: zmin = minf(zmin, float(a.z)); zmax = maxf(zmax, float(a.z))
	prof = []
	var n := maxi(2, int((z_f - z_r) / 0.05))
	for i in n + 1:
		var z := lerpf(z_r, z_f, float(i) / n)
		var y := frame_y
		for a in axles:
			var k := _axle_kick(a)
			if k <= 0.0: continue
			var dz := absf(z - float(a.z))
			var t := 1.0 - smoothstep(0.36, 0.7, dz)
			if float(a.z) <= zmin + 0.01 and z < float(a.z): t = 1.0       # behind the back axle it stays up
			y = maxf(y, frame_y + k * t)
		# pinched in ahead of the cab: full width behind the front axle - 0.9, 82 % from front axle - 0.3 forward
		var w := hw
		if axles.size() >= 2:
			w = lerpf(hw, hw * 0.82, smoothstep(zmax - 0.9, zmax - 0.3, z))
		prof.append([z, y, w])

func _prof_at(z: float) -> Array:
	if prof.is_empty(): return [z, frame_y, float(car.design.frame.width) * 0.5]
	var z0: float = prof[0][0]; var z1: float = prof[-1][0]
	var t := clampf((z - z0) / maxf(z1 - z0, 0.001), 0.0, 1.0) * (prof.size() - 1)
	var i := mini(int(t), prof.size() - 2)
	var f := t - i
	var a: Array = prof[i]; var b: Array = prof[i + 1]
	return [z, lerpf(a[1], b[1], f), lerpf(a[2], b[2], f)]

## Rail centre height and half width at z (for hangers, towers and mounts that bolt to the frame)
func rail_y(z: float) -> float: return float(_prof_at(z)[1])
func rail_hw(z: float) -> float: return float(_prof_at(z)[2])

func _box_quads(st: SurfaceTool, c0: Array, c1: Array) -> void:
	# a tube from one rectangular section (4 corners) to the next
	for k in 4:
		var a: Vector3 = c0[k]; var b: Vector3 = c0[(k + 1) % 4]; var c: Vector3 = c1[(k + 1) % 4]; var d: Vector3 = c1[k]
		var nrm := (b - a).cross(d - a).normalized()
		for v in [a, b, c, a, c, d]:
			st.set_normal(nrm); st.add_vertex(v)

func _section(x: float, y: float, z: float, w: float, h: float) -> Array:
	return [Vector3(x - w, y - h, z), Vector3(x + w, y - h, z), Vector3(x + w, y + h, z), Vector3(x - w, y + h, z)]

func _build_frame() -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1.0, 1.0]:
		for i in prof.size() - 1:
			var p0: Array = prof[i]; var p1: Array = prof[i + 1]
			_box_quads(st, _section(s * float(p0[2]), p0[1], p0[0], RAIL_W * 0.5, RAIL_H * 0.5), _section(s * float(p1[2]), p1[1], p1[0], RAIL_W * 0.5, RAIL_H * 0.5))
	# crossmembers
	var fr: Dictionary = car.design.frame
	var z_r := float(fr.z) - float(fr.len) * 0.5
	var z_f := float(fr.z) + float(fr.len) * 0.5
	var zs: Array = [z_r + 0.06, z_f - 0.06]
	var zmax := -INF; var zmin := INF
	for a in car.design.axles: zmax = maxf(zmax, float(a.z)); zmin = minf(zmin, float(a.z))
	zs.append(zmax - 0.32)                 # under the engine
	zs.append(zmax - 1.25)                 # gearbox
	zs.append(zmin + 0.78)                 # ahead of the rear axle's kick-up
	for a in car.design.axles:
		if float(a.z) > zmin + 0.01 and float(a.z) < zmax - 0.01: zs.append(float(a.z) + 0.6)
	for z in zs:
		if z < z_r or z > z_f: continue
		var y := rail_y(z); var w := rail_hw(z)
		var c0 := [Vector3(-w, y - 0.05, z - 0.04), Vector3(-w, y - 0.05, z + 0.04), Vector3(-w, y + 0.04, z + 0.04), Vector3(-w, y + 0.04, z - 0.04)]
		var c1 := [Vector3(w, y - 0.05, z - 0.04), Vector3(w, y - 0.05, z + 0.04), Vector3(w, y + 0.04, z + 0.04), Vector3(w, y + 0.04, z - 0.04)]
		_box_quads(st, c0, c1)
	var mi := MeshInstance3D.new()
	mi.name = "Frame"
	mi.mesh = st.commit()
	mi.material_override = m_frame
	add_child(mi)

func _build_engine() -> void:
	var e: Dictionary = car.eng
	var fz: float = car.design.axles[0].z
	if e.get("kit", false) or car.design.has("kit"):
		# 0.2.55: the code-made kit engine (old Meshy engines are put away)
		rebuild_engine()
		return
	var ps: PackedScene = load("res://assets/engines/%s.glb" % e.glb)
	if ps == null:
		return
	engine_node = ps.instantiate()
	engine_node.rotation_degrees.y = -90
	engine_node.position = Vector3(0, frame_y + 0.05, fz - float(e.len) * 0.5 + 0.15)
	add_child(engine_node)
	_fit_pending = 120

## (Re)build the kit engine, ECU and battery from car.design.kit: after a part goes on or comes off
var ecu_node: Node3D
var batt_node: Node3D
func rebuild_engine() -> void:
	for n in [engine_node, ecu_node, batt_node]:
		if n != null and is_instance_valid(n): n.queue_free()
	engine_node = null; ecu_node = null; batt_node = null
	var k: Dictionary = car.design.get("kit", {})
	var fz: float = car.design.axles[0].z
	var pb := EngineKit.parse_block(str(k.get("block", "")))
	if not pb.is_empty():
		engine_node = EngineKit.build_node(k)
		var L := EngineKit.length_of(pb[0])
		# a body with a low bonnet can drop the engine (catalog eng_y, 0.2.60: the F100's air cleaner came through it)
		engine_node.position = Vector3(0, frame_y + 0.24 + float(car.def.get("eng_y", 0.0)), fz - L * 0.5 + 0.1)
		add_child(engine_node)
		_fit_pending = 120              # the kit's meshes are made a frame or two later: fit it then
	var hw: float = float(car.design.frame.width) * 0.5
	if str(k.get("ecu", "")) != "":
		ecu_node = EngineKit.ecu_node()
		ecu_node.position = Vector3(-hw * 0.8, frame_y + 0.55, fz - 0.55)
		add_child(ecu_node)
	if float(CarCare.of(car).get("battery", 0.0)) >= 1.0 or Settings.creative():
		batt_node = EngineKit.battery_node()
		batt_node.position = Vector3(hw * 0.85, frame_y + 0.3, fz + 0.05)
		add_child(batt_node)

## 0.2.65: drop the engine until its top clears the bonnet skin (measured per body, tools/bonnet_tops.py) by 3 cm;
## at most 70 cm (the Meshy bodies sit their bonnets low over the wheels: up to 0.46 m needed)
var _fit_pending := 0
var eng_rear := INF              # the back of the engine (car frame) once it's fitted: the gearbox and tailshaft run from it
func _engine_fit() -> Vector3:
	if engine_node == null or car.design.get("no_cab", false) or not bool(car.def.get("eng_fit", true)): return Vector3.ZERO
	var ab := _aabb_of(engine_node, Transform3D.IDENTITY)
	if ab.size == Vector3.ZERO: return Vector3.ZERO
	var off: Array = car.design.cab_offset
	var o := Vector3(float(off[0]), float(off[1]), float(off[2]))
	# 0.2.68: fore and aft first: centred in the bay between the radiator and the firewall, never into the firewall
	var dz := 0.0
	var bay := BodyCut.bay_span(str(car.def.glb))
	if not bay.is_empty():
		var fw: float = float(bay[0]) + o.z - 0.05          # the firewall, less a little room
		var fr: float = float(bay[1]) + o.z - 0.22          # the radiator and fan
		var room := fr - fw
		var want := (fw + fr) * 0.5 - ab.get_center().z
		if ab.size.z > room: want = fw - ab.position.z      # too long to centre: tight to the firewall's clearance
		dz = clampf(want, -0.8, 0.8)
	var dx := o.x - ab.get_center().x
	var lo := BodyCut.skin_low(str(car.def.glb), ab.position.x + dx - o.x + 0.03, ab.end.x + dx - o.x - 0.03, ab.position.z + dz - o.z + 0.03, ab.end.z + dz - o.z - 0.03)
	if lo == INF: return Vector3(dx, 0, dz)
	var drop := (lo + o.y - 0.03) - ab.end.y
	return Vector3(dx, clampf(drop, -0.7, 0.0), dz)

func _aabb_of(n: Node, parent: Transform3D) -> AABB:
	var xf := parent
	if n is Node3D: xf = parent * (n as Node3D).transform
	var out := AABB()
	var first := true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = xf * (n as MeshInstance3D).get_aabb(); first = false
	for c in n.get_children():
		var b := _aabb_of(c, xf)
		if b.size == Vector3.ZERO: continue
		if first: out = b; first = false
		else: out = out.merge(b)
	return out

func _build_tailshaft() -> void:
	var rear := -1
	var zmin := 1e9
	for ai in car.design.axles.size():
		var a: Dictionary = car.design.axles[ai]
		if a.drive and float(a.z) < zmin:
			zmin = a.z
			rear = ai
	if rear < 0:
		return
	var ts_fn := func():
		var fz: float = car.design.axles[0].z
		var a := Vector3(0, frame_y - 0.05, (eng_rear - 0.5) if eng_rear < INF else (fz - float(car.eng.len) - 0.5))
		var b := _axle_centre(rear) + Vector3(0, -0.015, 0.2)       # the pinion flange (0.2.65 housing)
		return [a, b]
	tailshaft = _beam(cyl_mesh, m_steel, 0.075, 0.075, ts_fn, true)

# ---------------------------------------------------------------- wheels
func _build_wheels() -> void:
	var big: bool = car.wheels[0].r > 0.35
	var wm: String = str(car.design.get("wheel_model", "stock"))
	var path: String = WHEEL_MODELS.get(wm, WHEEL_MODELS.stock).path
	if path == "": path = "res://assets/vehicles/%s.glb" % ("wheel_4x4" if big else "wheel_car")
	var ps: PackedScene = load(path)
	for w in car.wheels:
		# 0.2.59: an axle can wear its own wheels (a tractor's big lugs at the back)
		var awm := str(w.a.get("wheel_model", ""))
		var wps: PackedScene = ps
		var key := wm
		if awm != "" and WHEEL_MODELS.has(awm) and str(WHEEL_MODELS[awm].path) != "":
			wps = load(str(WHEEL_MODELS[awm].path))
			key = awm
		var pivot := Node3D.new()
		add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var m: Node3D = wps.instantiate()
		m.scale = Vector3.ONE * float(w.r) * 2.0
		# 0.2.61: directional tread (lugs, chevrons) has a left and a right tyre: one model turned to face out on both
		# sides ran the lugs backwards on one of them, so that side wears it mirrored (fore and aft)
		var dside := int(WHEEL_MODELS.get(key, {}).get("dir", 0))
		if dside != 0 and signf(w.side) == signf(dside): m.scale.x = -m.scale.x
		m.rotation_degrees.y = 90 if w.side > 0 else -90
		spin.add_child(m)
		wheel_nodes.append({"pivot": pivot, "spin": spin, "model": m})

func _wheel_centre(w: Dictionary) -> Vector3:
	return w.mount - Vector3(0, w.L, 0)

func _axle_centre(ai: int) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for w in car.wheels:
		if w.axle == ai:
			c += _wheel_centre(w)
			n += 1
	return c / max(1, n)

func _wheels_of(ai: int) -> Array:
	return car.wheels.filter(func(w): return w.axle == ai)

# ---------------------------------------------------------------- live axle: housing, diff, leaf packs, shocks
static var _axle_scene: PackedScene
static var _axle_mat: Material
func _build_live_axle(ai: int, a: Dictionary) -> void:
	var ws := _wheels_of(ai)
	var wl: Dictionary = ws[0]
	var wr: Dictionary = ws[1]
	# 0.2.65: the real housing (diff centre, tubes, backing plates, spring perches; from the old game) instead of a
	# grey tube and a ball. Stretched across the track, pumpkin kept at its real size; the pinion points at the
	# gearbox (forward on a rear axle, back on a front one)
	if _axle_scene == null: _axle_scene = load("res://assets/vehicles/parts/live_axle.glb")
	var hous: Node3D = _axle_scene.instantiate()
	add_child(hous)
	if _axle_mat == null:
		for mi in hous.find_children("*", "MeshInstance3D", true, false):
			var src: Material = (mi as MeshInstance3D).mesh.surface_get_material(0)
			if src is StandardMaterial3D:
				var m2: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
				m2.albedo_color = Color(0.42, 0.4, 0.38)       # painted housing, not bright bare metal
				m2.metallic = 0.35
				m2.roughness = 0.75
				_axle_mat = m2
	for mi in hous.find_children("*", "MeshInstance3D", true, false):
		if _axle_mat: (mi as MeshInstance3D).material_override = _axle_mat
	var zmax := -INF
	for ax in car.design.axles: zmax = maxf(zmax, float(ax.z))
	var front: bool = float(a.z) >= zmax - 0.01 and car.design.axles.size() > 1
	var tr := float(a.track)
	var syz := 1.45
	var hous_fn := func():
		var cl := _wheel_centre(wl); var cr := _wheel_centre(wr)
		var c := (cl + cr) * 0.5
		var across := (cr - cl)                     # right minus left: +x
		var roll := atan2(across.y, across.x)
		var b := Basis(Vector3(0, 0, 1), roll)
		if front: b = b * Basis(Vector3.UP, PI)
		hous.transform = Transform3D(b * Basis.from_scale(Vector3(2.0 * tr * 0.94, syz, syz)), c)
		return null
	beams.append({"mi": hous, "fn": hous_fn, "w": 0, "h": 0, "cyl": false})
	for w in ws:
		var s: float = w.side
		var sp := func() -> float: return rail_hw(float(a.z)) * s
		if a.spring == "leaf":
			# leaf pack: front hanger and rear shackle on the rails (kicked up over the axle), centre on the perch on top
			# of the housing tube; 5 leaves, each shorter
			for leaf in 5:
				var th := 0.009
				var lo := leaf * th
				var shorten := leaf * 0.09
				for half in [1.0, -1.0]:
					_beam(box_mesh, m_spring, 0.06, th, func():
						# every leaf on the same line from the perch to the hanger, stacked under the main leaf, shorter
						var zc := float(a.z)
						var zh: float = zc + float(half) * 0.62
						var x := rail_hw(zh) * s
						var c0 := Vector3(x, _wheel_centre(w).y + 0.055 + 0.045, zc)
						var e0 := Vector3(x, rail_y(zh) - RAIL_H * 0.5 - 0.06, zh)
						var dn := Vector3(0, -lo, 0)
						return [c0 + dn, c0.lerp(e0, (0.62 - shorten) / 0.62) + dn])
			# U-bolt plate under the tube
			var plate := _part(box_mesh, m_steel)
			var plate_fn := func():
				plate.position = Vector3(sp.call(), _wheel_centre(w).y - 0.06, float(a.z))
				plate.scale = Vector3(0.08, 0.018, 0.12)
				return null
			beams.append({"mi": plate, "fn": plate_fn, "w": 0, "h": 0, "cyl": false})
		else:
			_beam(coil_mesh, m_spring, 0.15, 0.15, func():
				var z := float(a.z) - 0.05
				return [Vector3(rail_hw(z) * s, _wheel_centre(w).y + 0.07, z), Vector3(rail_hw(z) * s, rail_y(z) - RAIL_H * 0.5, z)], true)
		var sh_top := func() -> Vector3:
			var z := float(a.z) + 0.25
			return Vector3(rail_hw(z) * s * 0.92, rail_y(z) - 0.02, z)
		var sh_bot := func() -> Vector3: return Vector3(s * (float(a.track) - 0.3), _wheel_centre(w).y - 0.04, float(a.z) - 0.1)
		_shock(sh_top, sh_bot)
	if a.steer:
		_beam(cyl_mesh, m_steel, 0.024, 0.024, func(): return [_wheel_centre(wl) + Vector3(0.08, -0.05, -0.17), _wheel_centre(wr) + Vector3(-0.08, -0.05, -0.17)], true)

# ---------------------------------------------------------------- independent front: wishbones, upright, coil-over, sway bar, tie rods
func _build_ifs(ai: int, a: Dictionary) -> void:
	var ws := _wheels_of(ai)
	var hw: float = float(car.design.frame.width) * 0.5
	for w in ws:
		var s: float = w.side
		var z: float = a.z
		var inner_lo := func(): return Vector3(s * (rail_hw(z) - 0.05), rail_y(z) - 0.16, z)
		var inner_hi := func(): return Vector3(s * (rail_hw(z) - 0.02), rail_y(z) + 0.12, z - 0.02)
		var bj_lo := func(): return _wheel_centre(w) + Vector3(-s * 0.13, -0.11, 0)
		var bj_hi := func(): return _wheel_centre(w) + Vector3(-s * 0.16, 0.13, 0)
		for leg in [-0.16, 0.16]:
			_beam(box_mesh, m_steel, 0.045, 0.035, func(): return [inner_lo.call() + Vector3(0, 0, leg), bj_lo.call()])
			_beam(box_mesh, m_steel, 0.035, 0.03, func(): return [inner_hi.call() + Vector3(0, 0, leg * 0.7), bj_hi.call()])
		_beam(box_mesh, m_steel, 0.06, 0.06, func(): return [bj_lo.call(), bj_hi.call()])
		var seat_lo := func(): return (inner_lo.call() as Vector3).lerp(bj_lo.call(), 0.62) + Vector3(0, 0.03, 0)
		var tower := func(): return Vector3(s * (rail_hw(z) + 0.06), rail_y(z) + 0.3, z + 0.02)
		_beam(coil_mesh, m_spring, 0.13, 0.13, func(): return [seat_lo.call(), tower.call()], true)
		_shock(tower, seat_lo)
		# tie rod from the rack to the steering arm (the arm moves with the steering)
		_beam(cyl_mesh, m_steel, 0.022, 0.022, func():
			var arm := _wheel_centre(w) + Vector3(-s * 0.14, -0.04, -0.17) + Vector3(0, 0, 0)
			arm = _wheel_centre(w) + (Basis(Vector3.UP, w.steer) * (arm - _wheel_centre(w)))
			return [Vector3(s * 0.32, frame_y - 0.12, z - 0.17), arm], true)
	# sway bar across the front and its end links
	if float(a.arb) > 0.0:
		_beam(cyl_mesh, m_frame, 0.022, 0.022, func(): return [Vector3(-rail_hw(float(a.z)) + 0.02, rail_y(float(a.z)) - 0.2, float(a.z) + 0.3), Vector3(rail_hw(float(a.z)) - 0.02, rail_y(float(a.z)) - 0.2, float(a.z) + 0.3)], true)
		for w in ws:
			var s: float = w.side
			_beam(cyl_mesh, m_frame, 0.02, 0.02, func():
				var lo: Vector3 = Vector3(s * (rail_hw(float(a.z)) - 0.05), rail_y(float(a.z)) - 0.16, float(a.z)).lerp(_wheel_centre(w) + Vector3(-s * 0.13, -0.11, 0), 0.7)
				return [Vector3(s * (rail_hw(float(a.z)) - 0.02), rail_y(float(a.z)) - 0.2, float(a.z) + 0.3), lo + Vector3(0, 0.02, 0.1)], true)

func _shock(top_fn: Callable, bot_fn: Callable) -> void:
	# a fat body and a thin chrome shaft that slides out of it as the suspension extends
	var body := _part(cyl_mesh, m_shock)
	var shaft := _part(cyl_mesh, m_chrome)
	var fn := func():
		var t: Vector3 = top_fn.call()
		var b: Vector3 = bot_fn.call()
		var body_len := 0.26
		var dir := (t - b).normalized()
		_stretch(body, b, b + dir * body_len, 0.055, 0.055, true)
		_stretch(shaft, b + dir * (body_len - 0.02), t, 0.02, 0.02, true)
		return null
	beams.append({"mi": body, "fn": fn, "w": 0, "h": 0, "cyl": true})

func _process(_dt: float) -> void:
	if car == null:
		return
	if car.def.has("forks") and engine_node: engine_node.visible = false
	if _fit_pending > 0 and engine_node != null:
		_fit_pending -= 1
		if _aabb_of(engine_node, Transform3D.IDENTITY).size != Vector3.ZERO:
			var f := _engine_fit()
			engine_node.position += f
			eng_rear = _aabb_of(engine_node, Transform3D.IDENTITY).position.z
			if OS.get_environment("FIT_DEBUG") != "": print("FIT ", car.design.get("cab"), " ", f, " now ", engine_node.position)
			_fit_pending = 0
	for i in car.wheels.size():
		var w: Dictionary = car.wheels[i]
		var n: Dictionary = wheel_nodes[i]
		n.pivot.position = _wheel_centre(w)
		# 0.2.59: on a live axle the wheels stay square to the housing as it articulates (they used to stay upright and
		# looked like they turned on the ends of the axle)
		var roll := 0.0
		if str(w.a.get("type", "live")) == "live":
			for o in car.wheels:
				if o.axle == w.axle and o != w:
					var dy: float = _wheel_centre(w).y - _wheel_centre(o).y
					roll = atan2(dy * float(w.side), 2.0 * float(w.a.track))
		n.spin.rotation = Vector3(w.spin, 0, 0)
		# sidewall deflection: the tyre sits down under load (more on soft pressures); a squash on the visual
		# 0.2.62: the hub stays on the axle end (it used to drop by half the squash, off the housing's flange)
		var defl: float = w.get("defl", 0.0)
		n.pivot.basis = Basis(Vector3(0, 0, 1), roll) * Basis(Vector3.UP, w.steer) * Basis.from_scale(Vector3(1.0, 1.0 - defl / (float(w.r) * 2.0), 1.0))
	for b in beams:
		var r = b.fn.call()
		if r is Array:
			_stretch(b.mi, r[0], r[1], b.w, b.h, b.cyl)
