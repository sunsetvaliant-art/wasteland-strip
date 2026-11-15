class_name YardGen
extends Node3D
## Wreckers' yards and caravan parks (0.2.49), from assets/world/yards.json (tools/place_trades.py: real places from
## Overture Maps, each on its real ground).
##   wreckers: a corrugated iron fence round a 60 x 45 m yard with a gate to the street, rows of wrecked cars (some
##             stacked two high) you can search for parts and scrap; the wrecker's shed is a building lot
##   caravan parks: a chain-wire fence round the park with the boom gate and its sign where it meets the road, the
##             internal road, caravans with annexes on the sites (search them: holidays interrupted); its cabins are
##             building lots
## Built when you come within 450 m, dropped past 650 m.
const BUILD_R := 450.0
const DROP_R := 650.0
var main
var yards: Array = []
var _t := 0.0
var _store := {}          # what's left in the wrecks and vans you've searched, kept while the yard's unloaded

func setup(m) -> void:
	main = m
	var f := FileAccess.open("res://assets/world/yards.json", FileAccess.READ)
	if f == null: return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for y in d.get("wreckers", []):
		y["kind"] = "wreckers"
		y["cc"] = Vector2(float(y.c[0]), float(y.c[1]))
		y["node"] = null
		yards.append(y)
		Buildings.add_blocker(y.cc.x, y.cc.y, float(y.yaw), float(y.w), float(y.d))
	for y in d.get("caravan", []):
		y["kind"] = "caravan"
		var c := Vector2.ZERO
		for q in y.poly: c += Vector2(float(q[0]), float(q[1]))
		y["cc"] = c / maxf(y.poly.size(), 1)
		y["node"] = null
		yards.append(y)
	print("YARDS %d wreckers, %d caravan parks" % [d.get("wreckers", []).size(), d.get("caravan", []).size()])

func _process(dt: float) -> void:
	var _pt := Prof.t()
	_process_inner(dt)
	Prof.add("yards", _pt)

func _process_inner(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or main == null or main.player == null: return
	_t = 0.7
	var me: Vector3 = main.player.vehicle.global_position if main.player.vehicle else main.player.global_position
	if main.forge and main.forge.active: me = main.forge.cam.global_position
	for y in yards:
		var dd := Vector2(me.x, me.z).distance_to(y.cc)
		if y.node == null and dd < BUILD_R:
			y.node = _wreckers(y) if y.kind == "wreckers" else _park(y)
			add_child(y.node)
		elif y.node != null and dd > DROP_R:
			for n in y.node.get_children():
				if n.has_meta("yard_key") and n.has_meta("inv"): _store[n.get_meta("yard_key")] = n.get_meta("inv")
			y.node.queue_free()
			y.node = null

func _h(x: float, z: float) -> float:
	return ServoGen._h(main.terrain.data, x, z)

## a run of fence panels on the ground from a to b (world xz), into g (relative to org)
func _fence(g: BuildGen.Geo, org: Vector3, a: Vector2, b: Vector2, mk: String, hgt: float, post: String, step := 2.8) -> void:
	var L := a.distance_to(b)
	if L < 0.3: return
	var n := maxi(1, ceili(L / step))
	var yaw := atan2(b.x - a.x, b.y - a.y)
	for k in n:
		var p0 := a.lerp(b, float(k) / n); var p1 := a.lerp(b, float(k + 1) / n)
		var m := (p0 + p1) * 0.5
		var gy := _h(m.x, m.y) - org.y
		var th := 0.02 if mk == "grille" else 0.06
		g.box(mk, Transform3D(Basis(Vector3.UP, yaw), Vector3(m.x - org.x, gy + hgt * 0.5 - 0.1, m.y - org.z)), Vector3(th, hgt + 0.2, p0.distance_to(p1)))
		if mk == "grille":
			# chain wire: a top rail over the mesh
			g.box(post, Transform3D(Basis(Vector3.UP, yaw), Vector3(m.x - org.x, gy + hgt + 0.1, m.y - org.z)), Vector3(0.05, 0.05, p0.distance_to(p1)), false)
		if post != "":
			var pg := _h(p0.x, p0.y) - org.y
			g.box(post, Transform3D(Basis(Vector3.UP, yaw), Vector3(p0.x - org.x, pg + hgt * 0.5, p0.y - org.z)), Vector3(0.08, hgt + 0.15, 0.08), false)

func _finish(root: Node3D, g: BuildGen.Geo) -> void:
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

## a patch of ground surface over the quad q (world xz, in order round it), following the ground, 4 m cells
func _pad(org: Vector3, q: Array, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a: Vector2 = q[0]; var b: Vector2 = q[1]; var d: Vector2 = q[3]
	var nu := maxi(1, ceili(a.distance_to(b) / 4.0)); var nv := maxi(1, ceili(a.distance_to(d) / 4.0))
	var P := func(i: int, j: int) -> Vector3:
		var e: Vector2 = a + (b - a) * (float(i) / nu) + (d - a) * (float(j) / nv)
		return Vector3(e.x - org.x, _h(e.x, e.y) - org.y + 0.08, e.y - org.z)
	st.set_normal(Vector3.UP)
	for i in nu:
		for j in nv:
			var p00: Vector3 = P.call(i, j); var p10: Vector3 = P.call(i + 1, j); var p11: Vector3 = P.call(i + 1, j + 1); var p01: Vector3 = P.call(i, j + 1)
			for vv in [p00, p11, p10, p00, p01, p11]: st.add_vertex(vv)
	var mi := MeshInstance3D.new()
	var mesh := st.commit()
	# wound either way round: draw both sides
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static var _dirt_m: StandardMaterial3D
static func _dirt() -> Material:
	if _dirt_m == null:
		_dirt_m = StandardMaterial3D.new()
		var t := "res://assets/ph/tex/%s/%s_diffuse.jpg"
		for nm in ["concrete_floor_worn_001"]:
			if ResourceLoader.exists(t % [nm, nm]):
				_dirt_m.albedo_texture = load(t % [nm, nm]); break
		_dirt_m.albedo_color = Color(0.6, 0.5, 0.4) if _dirt_m.albedo_texture else Color(0.36, 0.3, 0.22)
		_dirt_m.uv1_triplanar = true; _dirt_m.uv1_world_triplanar = true; _dirt_m.uv1_scale = Vector3.ONE * 0.25
		_dirt_m.roughness = 1.0
		_dirt_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _dirt_m

# ---------------------------------------------------------------- wreckers
func _wreckers(y: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Wreckers"
	var c: Vector2 = y.cc
	var org := Vector3(c.x, _h(c.x, c.y), c.y)
	root.position = org
	var b := Basis(Vector3.UP, float(y.yaw))
	var hw := float(y.w) * 0.5; var hd := float(y.d) * 0.5
	var W := func(lx: float, lz: float) -> Vector2:
		var v := b * Vector3(lx, 0, lz)
		return Vector2(c.x + v.x, c.y + v.z)
	var g := BuildGen.Geo.new()
	# corrugated fence, a 7 m gate gap in the front (+z) middle
	var cor := [W.call(-hw, -hd), W.call(hw, -hd), W.call(hw, hd), W.call(3.5, hd)]
	_fence(g, org, cor[0], cor[1], "tin:grey", 2.2, "")
	_fence(g, org, cor[1], cor[2], "tin_rust", 2.2, "")
	_fence(g, org, cor[2], cor[3], "tin:grey", 2.2, "")
	_fence(g, org, W.call(-3.5, hd), W.call(-hw, hd), "tin:grey", 2.2, "")
	_fence(g, org, W.call(-hw, hd), cor[0], "tin_rust", 2.2, "")
	var sign: Vector2 = W.call(-6.5, hd + 0.4)
	var sgy := _h(sign.x, sign.y) - org.y
	ServoGen._label(root, Vector3(sign.x - org.x, sgy + 2.6, sign.y - org.z), str(y.name), 0.45, 9.0, float(y.yaw), Color(0.95, 0.85, 0.2))
	_finish(root, g)
	root.add_child(_pad(org, [W.call(-hw, -hd), W.call(hw, -hd), W.call(hw, hd), W.call(-hw, hd)], _dirt()))
	# wrecks: rows across the yard (cars side by side, nose to the aisle), the odd one stacked on another
	var cat: Dictionary = Car.catalog()
	var kinds := cat.keys()
	if kinds.is_empty(): return root
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(y.name))
	var made := 0
	for row in [-hd + 4.0, -hd + 14.0, -hd + 24.0, -hd + 34.0]:
		var x := -hw + 4.0
		while x < hw - 4.0 and made < 34:
			var p: Vector2 = W.call(x, row)
			var free: bool = Buildings.inst == null or Buildings.inst.lot_at(Vector3(p.x, 0, p.y), 3.0, true) == -1
			if free and rng.randf() < 0.6:
				var k0 := str(kinds[rng.randi() % kinds.size()])
				var car := _wreck(k0, Vector3(p.x, 0, p.y), org, float(y.yaw) + PI * 0.5 + rng.randf_range(-0.12, 0.12), 0.0, true)
				if car:
					root.add_child(car)
					made += 1
					var h0 := float(cat[k0].ext[1])
					if h0 < 1.45 and rng.randf() < 0.25 and made < 34:
						var top := _wreck(str(kinds[rng.randi() % kinds.size()]), Vector3(p.x, 0, p.y), org, float(y.yaw) + PI * 0.5 + rng.randf_range(-0.2, 0.2), h0 - 0.2, false)
						if top: root.add_child(top); made += 1
			x += 3.2
	return root

func _wreck(kind: String, p: Vector3, org: Vector3, yaw: float, up: float, searchable: bool) -> Node3D:
	var d: Dictionary = Car.catalog().get(kind, {})
	if d.is_empty(): return null
	var ps: PackedScene = load("res://assets/vehicles/%s.glb" % d.glb)
	if ps == null: return null
	var sb := StaticBody3D.new()
	var m: Node3D = ps.instantiate()
	m.rotation_degrees.y = -90
	sb.add_child(m)
	var bb := Gun._aabb(sb)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bb.size
	cs.shape = bs
	cs.position = bb.get_center()
	sb.add_child(cs)
	var gy := _h(p.x, p.z) - org.y
	sb.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, randf_range(-0.05, 0.05)), Vector3(p.x - org.x, gy - bb.position.y - 0.25 + up, p.z - org.z))
	for vi in sb.find_children("*", "VisualInstance3D", true, false):
		(vi as VisualInstance3D).visibility_range_end = 220.0
	if searchable:
		sb.set_meta("container", "wreck")
		sb.set_meta("container_name", "wreck")
		sb.set_meta("loot_seed", hash(Vector2i(roundi(p.x), roundi(p.z))))
		var key := "w%d_%d" % [roundi(p.x), roundi(p.z)]
		sb.set_meta("yard_key", key)
		if _store.has(key): sb.set_meta("inv", _store[key])
	return sb

# ---------------------------------------------------------------- caravan parks
func _park(y: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "CaravanPark"
	var c: Vector2 = y.cc
	var org := Vector3(c.x, _h(c.x, c.y), c.y)
	root.position = org
	var poly := PackedVector2Array()
	for q in y.poly: poly.append(Vector2(float(q[0]), float(q[1])))
	var n := poly.size()
	var g := BuildGen.Geo.new()
	# the gate: on the edge facing the road (yaw points from the park to its road)
	var fwd := Vector2(sin(float(y.yaw)), cos(float(y.yaw)))
	var gi := 0; var gbest := -INF
	for i in n:
		var m := (poly[i] + poly[(i + 1) % n]) * 0.5
		var s := (m - c).normalized().dot(fwd)
		if s > gbest: gbest = s; gi = i
	for i in n:
		var a := poly[i]; var b := poly[(i + 1) % n]
		if i == gi:
			var mid := (a + b) * 0.5
			var dir := (b - a).normalized()
			_fence(g, org, a, mid - dir * 4.5, "grille", 1.8, "steel", 3.0)
			_fence(g, org, mid + dir * 4.5, b, "grille", 1.8, "steel", 3.0)
			# boom gate, and the park's sign
			var gp := mid - dir * 3.8
			var gy := _h(gp.x, gp.y) - org.y
			g.box("trim:white", Transform3D(Basis(), Vector3(gp.x - org.x, gy + 0.55, gp.y - org.z)), Vector3(0.35, 1.1, 0.35))
			var bar_c := mid - dir * 1.6
			g.box("trim:red", Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(bar_c.x - org.x, gy + 1.0, bar_c.y - org.z)), Vector3(0.1, 0.1, 4.4), false)
			var sp := mid + dir * 6.5
			var sy := _h(sp.x, sp.y) - org.y
			g.box("timber", Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(sp.x - org.x, sy + 1.6, sp.y - org.z)), Vector3(0.15, 1.2, 3.4))
			ServoGen._label(root, Vector3(sp.x - org.x, sy + 1.6, sp.y - org.z) + Vector3(fwd.x, 0, fwd.y) * 0.1, str(y.name), 0.3, 3.2, atan2(fwd.x, fwd.y), Color(0.98, 0.95, 0.85))
		else:
			_fence(g, org, a, b, "grille", 1.8, "steel", 3.0)
	# the internal road: a loop 14 m in from the fence (toward the middle), 6 m wide, laid on the ground
	var asph := StandardMaterial3D.new()
	asph.albedo_texture = load("res://assets/ph/tex/asphalt_02/asphalt_02_diffuse.jpg") if ResourceLoader.exists("res://assets/ph/tex/asphalt_02/asphalt_02_diffuse.jpg") else null
	asph.albedo_color = Color(0.36, 0.36, 0.37)
	asph.uv1_triplanar = true; asph.uv1_world_triplanar = true; asph.uv1_scale = Vector3.ONE * 0.12
	var ring := PackedVector2Array()
	for q in poly:
		var v := q - c
		var L := v.length()
		ring.append(c + v * maxf(0.2, (L - 14.0) / maxf(L, 0.01)))
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a := ring[i]; var b := ring[(i + 1) % n]
		var L := a.distance_to(b)
		var k := maxi(1, ceili(L / 4.0))
		var side := (b - a).normalized().orthogonal() * 3.0
		for j in k:
			var p0 := a.lerp(b, float(j) / k); var p1 := a.lerp(b, float(j + 1) / k)
			var q := [p0 - side, p1 - side, p1 + side, p0 + side]
			var v3 := []
			for e in q: v3.append(Vector3(e.x - org.x, _h(e.x, e.y) - org.y + 0.1, e.y - org.z))
			st.set_normal(Vector3.UP)
			for vv in [v3[0], v3[2], v3[1], v3[0], v3[3], v3[2]]: st.add_vertex(vv)
	var rm := MeshInstance3D.new()
	rm.mesh = st.commit()
	rm.material_override = asph
	rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rm)
	_finish(root, g)
	# sites: both sides of the loop every 9 m, a caravan where there's no cabin, facing the road
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(y.name))
	var vans := 0
	for i in n:
		var a := ring[i]; var b := ring[(i + 1) % n]
		var L := a.distance_to(b)
		var dir := (b - a).normalized()
		var t := 5.0
		while t < L - 5.0 and vans < 36:
			for sg: float in [-1.0, 1.0]:
				var sp := a + dir * t + dir.orthogonal() * sg * 8.0
				if not Geometry2D.is_point_in_polygon(sp, poly): continue
				# the whole van, drawbar and annexe inside the fence (a metre spare)
				var vyaw := atan2(dir.x, dir.y) + PI * 0.5 * sg
				var fw := Vector2(sin(vyaw), cos(vyaw)); var sd := Vector2(fw.y, -fw.x)
				var inside := true
				for cn: Vector2 in [Vector2(-2.2, -4.5), Vector2(5.2, -4.5), Vector2(-2.2, 5.8), Vector2(5.2, 5.8)]:
					if not Geometry2D.is_point_in_polygon(sp + sd * cn.x + fw * cn.y, poly) or _edge_d(sp + sd * cn.x + fw * cn.y, poly) < 1.0:
						inside = false
				if not inside: continue
				if Buildings.inst and Buildings.inst.lot_at(Vector3(sp.x, 0, sp.y), 2.0, true) != -1: continue
				if rng.randf() < 0.25: continue
				root.add_child(_caravan(sp, atan2(dir.x, dir.y) + PI * 0.5 * sg, org, rng))
				vans += 1
			t += 9.0
	return root

func _edge_d(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
	return best

## a caravan on its site: body, roof, a stripe, windows, drawbar and jockey wheel, an awning annexe; searchable
func _caravan(p: Vector2, yaw: float, org: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var sb := StaticBody3D.new()
	var gy := _h(p.x, p.y)
	sb.position = Vector3(p.x - org.x, gy - org.y, p.y - org.z)
	sb.rotation.y = yaw
	var g := BuildGen.Geo.new()
	var L := rng.randf_range(4.8, 6.8); var Wd := 2.3; var Ht := 2.5
	var stripe: String = ["trim:navy", "trim:maroon", "trim:teal", "trim:charcoal", "trim:green"][rng.randi() % 5]
	g.box("trim:white", Transform3D(Basis(), Vector3(0, 0.45 + Ht * 0.5, 0)), Vector3(Wd, Ht, L), false)
	g.box("trim:cream", Transform3D(Basis(), Vector3(0, 0.45 + Ht + 0.06, 0)), Vector3(Wd - 0.1, 0.12, L - 0.2), false)
	g.box(stripe, Transform3D(Basis(), Vector3(0, 0.45 + Ht * 0.42, 0)), Vector3(Wd + 0.02, 0.18, L + 0.02), false)
	for wz: float in [-L * 0.3, L * 0.25]:
		g.box("trim:black", Transform3D(Basis(), Vector3(0, 0.45 + Ht * 0.68, wz)), Vector3(Wd + 0.03, 0.55, 1.1), false)
	g.box("trim:black", Transform3D(Basis(), Vector3(Wd * 0.5, 0.45 + Ht * 0.45, -L * 0.05)), Vector3(0.03, 1.8, 0.65), false)   # door
	g.box("steel", Transform3D(Basis(), Vector3(0, 0.35, L * 0.5 + 0.8)), Vector3(0.12, 0.12, 1.6), false)                         # drawbar
	g.box("trim:black", Transform3D(Basis(), Vector3(0, 0.15, L * 0.5 + 1.3)), Vector3(0.12, 0.3, 0.2), false)
	for sx: float in [-1.0, 1.0]:
		g.box("trim:black", Transform3D(Basis(), Vector3(sx * Wd * 0.5, 0.33, 0)), Vector3(0.22, 0.66, 0.66), false)
	if rng.randf() < 0.65:
		# the annexe: canvas over poles off the door side
		var cv: String = ["trim:sage", "trim:tan", "trim:green", "trim:cream"][rng.randi() % 4]
		g.box(cv, Transform3D(Basis(Vector3.FORWARD, -0.08), Vector3(Wd * 0.5 + 1.4, 0.45 + Ht - 0.15, 0)), Vector3(2.8, 0.04, L * 0.7), false)
		for pz: float in [-L * 0.33, L * 0.33]:
			g.box("steel", Transform3D(Basis(), Vector3(Wd * 0.5 + 2.75, 0.45 + (Ht - 0.4) * 0.5, pz)), Vector3(0.05, Ht - 0.4, 0.05), false)
	var mi := MeshInstance3D.new()
	mi.mesh = g.commit()
	mi.visibility_range_end = 350.0
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(Wd, Ht + 0.45, L)
	cs.shape = bs
	cs.position = Vector3(0, (Ht + 0.45) * 0.5, 0)
	sb.add_child(cs)
	sb.set_meta("container", "caravan")
	sb.set_meta("container_name", "caravan")
	sb.set_meta("loot_seed", hash(Vector2i(roundi(p.x), roundi(p.y))))
	var key := "c%d_%d" % [roundi(p.x), roundi(p.y)]
	sb.set_meta("yard_key", key)
	if _store.has(key): sb.set_meta("inv", _store[key])
	return sb
