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
var wheel_nodes: Array = []       # per wheel: {pivot, spin}
var beams: Array = []             # [{mi, fn: Callable}] updated every frame
var tailshaft: MeshInstance3D
var engine_node: Node3D

func setup(c) -> void:
	car = c
	var d: Dictionary = car.design
	frame_y = float(d.ride) + 0.16
	m_frame = _mat(Color(0.09, 0.085, 0.08), 0.35, 0.7)
	m_steel = _mat(Color(0.25, 0.22, 0.2), 0.6, 0.55)
	m_spring = _mat(Color(0.55, 0.12, 0.08), 0.4, 0.5)
	m_shock = _mat(Color(0.75, 0.6, 0.1), 0.3, 0.45)
	m_chrome = _mat(Color(0.8, 0.8, 0.82), 1.0, 0.15)
	box_mesh = BoxMesh.new()
	cyl_mesh = CylinderMesh.new()
	cyl_mesh.top_radius = 0.5
	cyl_mesh.bottom_radius = 0.5
	cyl_mesh.height = 1.0
	cyl_mesh.radial_segments = 12
	coil_mesh = _make_coil(7.0, 0.5, 0.11)
	_build_frame()
	_build_engine()
	_build_wheels()
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
func _build_frame() -> void:
	var fr: Dictionary = car.design.frame
	var L: float = fr.len
	var hw: float = float(fr.width) * 0.5
	var z0: float = float(fr.z) - L * 0.5
	for s in [-1.0, 1.0]:
		var rail := _part(box_mesh, m_frame)
		rail.scale = Vector3(0.07, 0.16, L)
		rail.position = Vector3(s * hw, frame_y, fr.z)
	var zs: Array = [z0 + 0.1, float(fr.z) + L * 0.5 - 0.1]
	for a in car.design.axles: zs.append(float(a.z) + 0.25)
	for z in zs:
		var x := _part(box_mesh, m_frame)
		x.scale = Vector3(hw * 2.0, 0.1, 0.08)
		x.position = Vector3(0, frame_y - 0.02, z)

func _build_engine() -> void:
	var e: Dictionary = car.eng
	var ps: PackedScene = load("res://assets/engines/%s.glb" % e.glb)
	if ps == null:
		return
	engine_node = ps.instantiate()
	engine_node.rotation_degrees.y = -90
	var fz: float = car.design.axles[0].z
	engine_node.position = Vector3(0, frame_y + 0.05, fz - float(e.len) * 0.5 + 0.15)
	add_child(engine_node)

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
		var a := Vector3(0, frame_y - 0.05, fz - float(car.eng.len) - 0.5)
		var b := _axle_centre(rear) + Vector3(0, 0.02, 0.12)
		return [a, b]
	tailshaft = _beam(cyl_mesh, m_steel, 0.075, 0.075, ts_fn, true)

# ---------------------------------------------------------------- wheels
func _build_wheels() -> void:
	var big: bool = car.wheels[0].r > 0.35
	var ps: PackedScene = load("res://assets/vehicles/%s.glb" % ("wheel_4x4" if big else "wheel_car"))
	for w in car.wheels:
		var pivot := Node3D.new()
		add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var m: Node3D = ps.instantiate()
		m.scale = Vector3.ONE * float(w.r) * 2.0
		m.rotation_degrees.y = 90 if w.side > 0 else -90
		spin.add_child(m)
		wheel_nodes.append({"pivot": pivot, "spin": spin})

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
func _build_live_axle(ai: int, a: Dictionary) -> void:
	var ws := _wheels_of(ai)
	var wl: Dictionary = ws[0]
	var wr: Dictionary = ws[1]
	_beam(cyl_mesh, m_steel, 0.09, 0.09, func(): return [_wheel_centre(wl) + Vector3(0.12, 0, 0), _wheel_centre(wr) - Vector3(0.12, 0, 0)], true)
	var diff := _part(SphereMesh.new(), m_steel)
	var diff_fn := func():
		diff.position = _axle_centre(ai) + Vector3(0, 0, 0.04)
		diff.rotation = Vector3(0, 0, (_wheel_centre(wl).y - _wheel_centre(wr).y) / (2.0 * float(a.track)))
		diff.scale = Vector3(0.32, 0.3, 0.3)
		return null
	beams.append({"mi": diff, "fn": diff_fn, "w": 0, "h": 0, "cyl": false})
	var hw: float = float(car.design.frame.width) * 0.5
	for w in ws:
		var s: float = w.side
		var x := s * hw
		if a.spring == "leaf":
			# leaf pack: front hanger, centre clamped on the axle, rear shackle; drawn as two bent halves, 3 leaves deep
			for leaf in 3:
				var th := 0.016
				var lo := leaf * th
				var shorten := leaf * 0.12
				for half in [1.0, -1.0]:
					_beam(box_mesh, m_spring, 0.065, th, func():
						var c := Vector3(x, _wheel_centre(w).y + 0.1 + lo, float(a.z))
						var end := Vector3(x, frame_y - 0.08 + lo * 0.5, float(a.z) + half * (0.62 - shorten))
						var mid := c.lerp(end, 0.5) + Vector3(0, -0.035, 0)
						return [c, end.lerp(mid, 0.0)])
			# U-bolt plate
			var plate := _part(box_mesh, m_steel)
			var plate_fn := func():
				plate.position = Vector3(x, _wheel_centre(w).y + 0.05, float(a.z))
				plate.scale = Vector3(0.1, 0.03, 0.16)
				return null
			beams.append({"mi": plate, "fn": plate_fn, "w": 0, "h": 0, "cyl": false})
		else:
			_beam(coil_mesh, m_spring, 0.24, 0.24, func():
				return [Vector3(x, _wheel_centre(w).y + 0.08, float(a.z) - 0.05), Vector3(x, frame_y - 0.04, float(a.z) - 0.05)], true)
		_shock(func(): return Vector3(x * 0.92, frame_y + 0.05, float(a.z) + 0.28), func(): return Vector3(s * (float(a.track) - 0.3), _wheel_centre(w).y - 0.02, float(a.z) - 0.12))
	if a.steer:
		_beam(cyl_mesh, m_steel, 0.028, 0.028, func(): return [_wheel_centre(wl) + Vector3(-0.08, -0.05, -0.18), _wheel_centre(wr) + Vector3(0.08, -0.05, -0.18)], true)

# ---------------------------------------------------------------- independent front: wishbones, upright, coil-over, sway bar, tie rods
func _build_ifs(ai: int, a: Dictionary) -> void:
	var ws := _wheels_of(ai)
	var hw: float = float(car.design.frame.width) * 0.5
	for w in ws:
		var s: float = w.side
		var z: float = a.z
		var inner_lo := func(): return Vector3(s * (hw - 0.05), frame_y - 0.16, z)
		var inner_hi := func(): return Vector3(s * (hw - 0.02), frame_y + 0.12, z - 0.02)
		var bj_lo := func(): return _wheel_centre(w) + Vector3(-s * 0.13, -0.11, 0)
		var bj_hi := func(): return _wheel_centre(w) + Vector3(-s * 0.16, 0.13, 0)
		for leg in [-0.16, 0.16]:
			_beam(box_mesh, m_steel, 0.045, 0.035, func(): return [inner_lo.call() + Vector3(0, 0, leg), bj_lo.call()])
			_beam(box_mesh, m_steel, 0.035, 0.03, func(): return [inner_hi.call() + Vector3(0, 0, leg * 0.7), bj_hi.call()])
		_beam(box_mesh, m_steel, 0.06, 0.06, func(): return [bj_lo.call(), bj_hi.call()])
		var seat_lo := func(): return (inner_lo.call() as Vector3).lerp(bj_lo.call(), 0.62) + Vector3(0, 0.03, 0)
		var tower := func(): return Vector3(s * (hw + 0.06), frame_y + 0.38, z + 0.02)
		_beam(coil_mesh, m_spring, 0.22, 0.22, func(): return [seat_lo.call(), tower.call()], true)
		_shock(tower, seat_lo)
		# tie rod from the rack to the steering arm (the arm moves with the steering)
		_beam(cyl_mesh, m_steel, 0.022, 0.022, func():
			var arm := _wheel_centre(w) + Vector3(-s * 0.14, -0.04, -0.17) + Vector3(0, 0, 0)
			arm = _wheel_centre(w) + (Basis(Vector3.UP, w.steer) * (arm - _wheel_centre(w)))
			return [Vector3(s * 0.32, frame_y - 0.12, z - 0.17), arm], true)
	# sway bar across the front and its end links
	if float(a.arb) > 0.0:
		_beam(cyl_mesh, m_frame, 0.03, 0.03, func(): return [Vector3(-hw + 0.02, frame_y - 0.2, float(a.z) + 0.3), Vector3(hw - 0.02, frame_y - 0.2, float(a.z) + 0.3)], true)
		for w in ws:
			var s: float = w.side
			_beam(cyl_mesh, m_frame, 0.02, 0.02, func():
				var lo: Vector3 = Vector3(s * (hw - 0.05), frame_y - 0.16, float(a.z)).lerp(_wheel_centre(w) + Vector3(-s * 0.13, -0.11, 0), 0.7)
				return [Vector3(s * (hw - 0.02), frame_y - 0.2, float(a.z) + 0.3), lo + Vector3(0, 0.02, 0.1)], true)

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
	for i in car.wheels.size():
		var w: Dictionary = car.wheels[i]
		var n: Dictionary = wheel_nodes[i]
		n.pivot.position = _wheel_centre(w)
		n.pivot.rotation = Vector3(0, w.steer, 0)
		n.spin.rotation = Vector3(w.spin, 0, 0)
	for b in beams:
		var r = b.fn.call()
		if r is Array:
			_stretch(b.mi, r[0], r[1], b.w, b.h, b.cyl)
