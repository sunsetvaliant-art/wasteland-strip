class_name ServoGen
extends Node3D
## Service stations, generated (0.2.47) from the real ones in OpenStreetMap (assets/world/servos.json, from
## tools/make_servos.py): a concrete forecourt laid on the ground over the station's outline, each canopy at its real
## size and place (5.4 m clear, a truck canopy 6.5 m) in the brand's colours with the name along it, lit underneath,
## bowser islands under it, and a pylon sign by the road. The shop is a generated ShopGen "servo" building (a lot in
## buildings.json), with its door, shelves and loot. Built when you come within 900 m, dropped past 1200 m.

const COLOURS := {   # fascia, stripe, sign panel
	"Ampol": ["ampol_red", "ampol_blue", "white"], "BP": ["bp_green", "shell_yellow", "bp_green"], "Shell": ["shell_yellow", "red", "shell_yellow"],
	"Caltex": ["red", "navy", "white"], "Liberty": ["red", "navy", "white"], "7-Eleven": ["orange", "green", "white"], "United": ["navy", "shell_yellow", "navy"],
	"Freedom": ["green", "white", "green"], "Puma": ["puma_red", "white", "white"]}
const BUILD_R := 900.0
const DROP_R := 1200.0
var main
var servos: Array = []
var _t := 0.0

func setup(m) -> void:
	main = m
	var f := FileAccess.open("res://assets/world/servos.json", FileAccess.READ)
	if f == null: return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for e in d.servos:
		var a: Array = e.area
		var c := Vector2.ZERO
		for q in a: c += Vector2(float(q[0]), float(q[1]))
		c /= maxf(a.size(), 1)
		e["c"] = c
		e["node"] = null
		servos.append(e)
		# no trees or grass on the forecourt
		var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
		for q in a:
			lo = lo.min(Vector2(float(q[0]), float(q[1]))); hi = hi.max(Vector2(float(q[0]), float(q[1])))
		Buildings.add_blocker((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, 0.0, hi.x - lo.x, hi.y - lo.y)
	print("SERVOS ", servos.size())

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or main == null or main.player == null: return
	_t = 0.8
	var me: Vector3 = main.player.vehicle.global_position if main.player.vehicle else main.player.global_position
	if main.forge and main.forge.active: me = main.forge.cam.global_position
	for e in servos:
		var dd := Vector2(me.x, me.z).distance_to(e.c)
		if e.node == null and dd < BUILD_R:
			e.node = build(e, main.terrain.data)
			add_child(e.node)
		elif e.node != null and dd > DROP_R:
			e.node.queue_free()
			e.node = null

## the ground as it's drawn: bilinear between the 5 m vertices (get_height gives the nearest vertex)
static func _h(data: Terrain3DData, x: float, z: float) -> float:
	var x0 := floorf(x / 5.0) * 5.0; var z0 := floorf(z / 5.0) * 5.0
	var fx := (x - x0) / 5.0; var fz := (z - z0) / 5.0
	var a := float(data.get_height(Vector3(x0, 0, z0))); var b := float(data.get_height(Vector3(x0 + 5.0, 0, z0)))
	var c := float(data.get_height(Vector3(x0, 0, z0 + 5.0))); var d := float(data.get_height(Vector3(x0 + 5.0, 0, z0 + 5.0)))
	var h := lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)
	return 0.0 if is_nan(h) else h

## one station
static func build(e: Dictionary, data: Terrain3DData) -> Node3D:
	var root := Node3D.new()
	root.name = "Servo"
	var col: Array = COLOURS.get(str(e.brand), COLOURS["Ampol"])
	var c: Vector2 = e.c
	var base := _h(data, c.x, c.y)
	root.position = Vector3(c.x, base, c.y)
	var g := BuildGen.Geo.new()
	# ---- the forecourt: concrete over the outline, a 3 m grid laid on the ground
	var poly := PackedVector2Array()
	for q in e.area: poly.append(Vector2(float(q[0]), float(q[1])))
	var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for q in poly: lo = lo.min(q); hi = hi.max(q)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var S := 3.0
	var x := lo.x
	while x < hi.x:
		var z := lo.y
		while z < hi.y:
			var mid := Vector2(x + S * 0.5, z + S * 0.5)
			if Geometry2D.is_point_in_polygon(mid, poly):
				var q := []
				for o in [Vector2(0, 0), Vector2(S, 0), Vector2(S, S), Vector2(0, S)]:
					var p2: Vector2 = Vector2(x, z) + o
					q.append(Vector3(p2.x - c.x, _h(data, p2.x, p2.y) - base + 0.1, p2.y - c.y))
				st.set_normal(Vector3.UP)
				for v in [q[0], q[2], q[1], q[0], q[3], q[2]]: st.add_vertex(v)
			z += S
		x += S
	var conc := StandardMaterial3D.new()
	conc.albedo_texture = load("res://assets/ph/tex/concrete_floor_worn_001/concrete_floor_worn_001_diffuse.jpg") if ResourceLoader.exists("res://assets/ph/tex/concrete_floor_worn_001/concrete_floor_worn_001_diffuse.jpg") else null
	conc.albedo_color = Color(0.82, 0.81, 0.78)
	conc.uv1_triplanar = true; conc.uv1_world_triplanar = true; conc.uv1_scale = Vector3.ONE * 0.2
	var fm := MeshInstance3D.new()
	fm.mesh = st.commit()
	fm.material_override = conc
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fm)
	# ---- canopies
	for cn in e.get("canopies", []):
		var cc := Vector2(float(cn[0]), float(cn[1]))
		var yaw := float(cn[2]); var w := maxf(float(cn[3]), 8.0); var d := maxf(float(cn[4]), 6.0)
		var truck := int(cn[5]) == 1 if cn.size() > 5 else false
		var hgt := 6.5 if truck else 5.4
		var gy := _h(data, cc.x, cc.y) - base
		var b := Basis(Vector3.UP, yaw)
		var o := Vector3(cc.x - c.x, gy, cc.y - c.y)
		var X := b * Vector3(1, 0, 0); var Z := b * Vector3(0, 0, 1)
		# roof slab, fascia band in the brand colour with a stripe, lights underneath
		g.box("trim:white", Transform3D(b, o + Vector3(0, hgt + 0.35, 0)), Vector3(w, 0.7, d))
		# the fascia: a coloured band round the four edges (the roof itself white), a stripe in the second colour under it
		for sd: float in [-1.0, 1.0]:
			g.box("trim:" + str(col[0]), Transform3D(b, o + Z * sd * (d * 0.5 + 0.06) + Vector3(0, hgt + 0.45, 0)), Vector3(w + 0.24, 0.9, 0.12), false)
			g.box("trim:" + str(col[0]), Transform3D(b, o + X * sd * (w * 0.5 + 0.06) + Vector3(0, hgt + 0.45, 0)), Vector3(0.12, 0.9, d + 0.24), false)
			g.box("trim:" + str(col[1]), Transform3D(b, o + Z * sd * (d * 0.5 + 0.08) + Vector3(0, hgt - 0.05, 0)), Vector3(w + 0.28, 0.14, 0.1), false)
			g.box("trim:" + str(col[1]), Transform3D(b, o + X * sd * (w * 0.5 + 0.08) + Vector3(0, hgt - 0.05, 0)), Vector3(0.1, 0.14, d + 0.28), false)
		var nl := maxi(1, int(w / 4.0))
		for i in nl:
			for j: float in [-0.25, 0.25]:
				g.box("lamp", Transform3D(b, o + X * ((i + 0.5) / nl - 0.5) * (w - 2.0) + Z * j * d + Vector3(0, hgt - 0.01, 0)), Vector3(1.6, 0.04, 0.5), false)
		# columns down the middle line(s), islands with bowsers between them
		var rows := [0.0] if d < 13.0 else [-d * 0.25, d * 0.25]
		var ncol := maxi(2, int(w / 9.0) + 1)
		for rz: float in rows:
			for i in ncol:
				var t := (float(i) / (ncol - 1) - 0.5) * (w - 3.0)
				var pp := o + X * t + Z * rz
				var pg := _h(data, c.x + pp.x, c.y + pp.z) - base
				g.box("steel", Transform3D(b, Vector3(pp.x, (pg + hgt) * 0.5, pp.z)), Vector3(0.45, hgt - pg + 0.1, 0.45))
				if i < ncol - 1:
					var t2 := (float(i) + 0.5) / (ncol - 1) - 0.5
					var ip := o + X * t2 * (w - 3.0) + Z * rz
					var ig := _h(data, c.x + ip.x, c.y + ip.z) - base
					g.box("concrete", Transform3D(b, Vector3(ip.x, ig + 0.12, ip.z)), Vector3(minf(5.0, (w - 3.0) / (ncol - 1) - 2.5), 0.24, 1.2))
					for k: float in [-1.0, 1.0]:
						var bp: Vector3 = ip + X * k * 1.2
						g.box("trim:" + str(col[0]), Transform3D(b, Vector3(bp.x, ig + 1.05, bp.z)), Vector3(0.9, 1.7, 0.55))
						g.box("trim:white", Transform3D(b, Vector3(bp.x, ig + 1.45, bp.z)), Vector3(0.7, 0.4, 0.58), false)
						g.box("trim:black", Transform3D(b, Vector3(bp.x, ig + 1.5, bp.z)), Vector3(0.4, 0.2, 0.6), false)
		# the brand along both long sides of the fascia
		for sgn: float in [-1.0, 1.0]:
			var lp: Vector3 = o + Z * sgn * (d * 0.5 + 0.1) + Vector3(0, hgt + 0.45, 0)
			_label(root, lp, str(e.brand).to_upper(), 0.55, minf(w * 0.5, 9.0), yaw + (0.0 if sgn > 0.0 else PI), Color.WHITE if str(col[0]) != "shell_yellow" else Color(0.85, 0.1, 0.1))
	# ---- the pylon sign: by the road, at the forecourt corner nearest it
	var best := poly[0]; var bd := INF
	for q in poly:
		var ed: float = Roads.inst.edge_dist(q.x, q.y) if Roads.inst else 99.0
		if ed < bd: bd = ed; best = q
	var inward := (c - best).normalized()
	var sp := best + inward * 2.5
	var sg := _h(data, sp.x, sp.y) - base
	var ph := 14.0 if bool(e.get("hgv", false)) else 7.5
	var sb := Basis(Vector3.UP, atan2(inward.x, inward.y) + PI * 0.5)
	var sl := Vector3(sp.x - c.x, sg, sp.y - c.y)
	g.box("steel", Transform3D(sb, sl + Vector3(0, ph * 0.5, 0)), Vector3(0.35, ph, 0.35))
	g.box("trim:" + str(col[2]), Transform3D(sb, sl + Vector3(0, ph - 0.9, 0)), Vector3(2.6, 1.8, 0.35))
	g.box("trim:" + str(col[0]), Transform3D(sb, sl + Vector3(0, ph - 1.95, 0)), Vector3(2.6, 0.3, 0.36), false)
	for i in 3:
		g.box("trim:black", Transform3D(sb, sl + Vector3(0, ph - 2.5 - i * 0.62, 0)), Vector3(2.4, 0.5, 0.3))
	for sgn: float in [-1.0, 1.0]:
		_label(root, sl + sb * Vector3(0, 0, sgn * 0.19) + Vector3(0, ph - 0.9, 0), str(e.brand).to_upper(), 0.4, 2.3, atan2(inward.x, inward.y) + PI * 0.5 + (0.0 if sgn > 0.0 else PI), Color(0.1, 0.1, 0.1) if str(col[2]) in ["white", "shell_yellow"] else Color.WHITE)
		for i in 3:
			var price: String = ["U91  1.85", "P98  2.09", "DSL  1.99"][i]
			_label(root, sl + sb * Vector3(0, 0, sgn * 0.17) + Vector3(0, ph - 2.5 - i * 0.62, 0), price, 0.3, 2.2, atan2(inward.x, inward.y) + PI * 0.5 + (0.0 if sgn > 0.0 else PI), Color(1.0, 0.6, 0.1))
	# all of it as one mesh and its collision
	var mi := MeshInstance3D.new()
	mi.mesh = g.commit()
	root.add_child(mi)
	var body := StaticBody3D.new()
	for sh in g.shapes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sh[1]
		cs.shape = bs
		cs.transform = sh[0]
		body.add_child(cs)
	root.add_child(body)
	return root

static func _label(root: Node3D, at: Vector3, text: String, size: float, max_w: float, yaw: float, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = size / 64.0
	l.font_size = 64
	l.modulate = color
	l.outline_size = 0
	l.width = max_w / l.pixel_size
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.position = at
	l.rotation = Vector3(0, yaw, 0)
	l.double_sided = false
	l.visibility_range_end = 400.0
	root.add_child(l)
