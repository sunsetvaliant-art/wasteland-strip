class_name Roads
extends Node3D
## The Tweed road network (tools/bake_roads.py, FLUSH): the roads are a skin laid on the terrain, built here a 1 km tile
## at a time from the centrelines (assets/roads/lines.bin) with every vertex on the ground under it, so there's no edge
## to catch a wheel: you drive on the terrain itself, and the car knows it's on bitumen from the road mask. Bridges are
## baked meshes (assets/roads/road_X_Z.glb) and the only road with collision of its own, near the player and cars.

const COLLIDE_IN := 700.0
const COLLIDE_OUT := 1000.0
const DRAW := 3200.0

var tiles: Array = []            # [{pos: Vector3, mi (bridges), mesh, body, names, lines, flush: MeshInstance3D}]
var _by_key := {}                # Vector2i tile -> tile dict
var road_mat: ShaderMaterial
var conc_mat: StandardMaterial3D
var main
var _t := 0.0

func setup(m) -> void:
	main = m
	road_mat = ShaderMaterial.new()
	road_mat.shader = load("res://shaders/road.gdshader")
	var P := "res://assets/ph/tex/"
	road_mat.set_shader_parameter("asph_alb", load(P + "asphalt_02/asphalt_02_diffuse.jpg"))
	road_mat.set_shader_parameter("asph_nrm", load(P + "asphalt_02/asphalt_02_nor_gl.jpg"))
	road_mat.set_shader_parameter("asph_rgh", load(P + "asphalt_02/asphalt_02_rough.jpg"))
	road_mat.set_shader_parameter("tyre_alb", load(P + "aerial_asphalt_01/aerial_asphalt_01_diffuse.jpg"))
	road_mat.set_shader_parameter("dirt_alb", load("res://assets/ground/farm_soil_alb_h.png"))
	road_mat.set_shader_parameter("dirt_nrm", load("res://assets/ground/farm_soil_nrm_r.png"))
	road_mat.set_shader_parameter("grass_alb", load("res://assets/ground/rough_grass_alb_h.png"))
	road_mat.set_shader_parameter("grass_nrm", load("res://assets/ground/rough_grass_nrm_r.png"))
	road_mat.set_shader_parameter("conc_alb", load("res://assets/ground/concrete_alb_h.png"))
	road_mat.set_shader_parameter("conc_nrm", load("res://assets/ground/concrete_nrm_r.png"))
	conc_mat = StandardMaterial3D.new()
	conc_mat.albedo_texture = load("res://assets/ground/concrete_alb_h.png")
	conc_mat.normal_enabled = true
	conc_mat.normal_texture = load("res://assets/ground/concrete_nrm_r.png")
	conc_mat.uv1_triplanar = true
	conc_mat.uv1_scale = Vector3.ONE * 0.25
	conc_mat.albedo_color = Color(0.82, 0.8, 0.76)
	conc_mat.roughness = 0.9
	conc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var idx = JSON.parse_string(FileAccess.get_file_as_string("res://assets/roads/index.json"))
	if typeof(idx) != TYPE_DICTIONARY:
		push_warning("no road index")
		return
	var lines := _read_lines()
	print("ROADS flush tiles ", lines.size())
	for t in idx.tiles:
		var key := Vector2i(floori((float(t.x) - X0) / 1024.0), floori((float(t.z) - Z0) / 1024.0))
		var td := {"pos": Vector3(t.x, 0, t.z), "mi": null, "mesh": null, "body": null, "names": t.names, "lines": lines.get(key, []), "flush": null}
		tiles.append(td)
		_by_key[key] = td
		if str(t.get("file", "")) == "":
			continue
		var ps: PackedScene = load("res://assets/roads/" + t.file)
		if ps == null:
			continue
		var n: Node3D = ps.instantiate()
		add_child(n)
		var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			mi.set_surface_override_material(s, conc_mat if (mat and mat.resource_name == "concrete") else road_mat)
		mi.visibility_range_end = DRAW
		mi.visibility_range_end_margin = 200.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		td.mi = mi
		td.mesh = mesh

## Points that need solid road under them: you, cars with someone in them, the Forge camera, and any car moving
func _anchors() -> Array:
	var a := []
	if main.player: a.append(main.player.global_position)
	if main.forge and main.forge.active: a.append(main.forge.cam.global_position)
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v.driver or (v is RigidBody3D and (v as RigidBody3D).linear_velocity.length() > 1.0):
			a.append(v.global_position)
	return a

const X0 := -8960.0
const Z0 := -16960.0

## lines.bin: per tile, the road pieces: half-width, surface, marking style, wildness, then points (x, z, along, end fade, curve)
func _read_lines() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://assets/roads/lines.bin", FileAccess.READ)
	if f == null:
		return out
	var nt := f.get_32()
	for _t in nt:
		var tx := f.get_32()
		var tz := f.get_32()
		if tx > 0x7fffffff: tx -= 0x100000000
		if tz > 0x7fffffff: tz -= 0x100000000
		var np := f.get_32()
		var pcs := []
		for _p in np:
			var hs := f.get_float()
			var sf := f.get_float()
			var mk := f.get_float()
			var wl := f.get_float()
			var n := f.get_32()
			var buf := f.get_buffer(n * 20)
			pcs.append({"hs": hs, "surf": sf, "mark": mk, "wild": wl, "pts": buf.to_float32_array()})
		out[Vector2i(tx, tz)] = pcs
	return out

## The road skin for one tile, every vertex on the terrain (a few cm proud; the shader pulls it toward the camera a
## touch more so far-off terrain LODs don't swallow it)
func _flush_mesh(t: Dictionary) -> ArrayMesh:
	var data: Terrain3DData = main.terrain.data
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cs := PackedColorArray()
	var idx := PackedInt32Array()
	var org: Vector3 = t.pos
	for pc in t.lines:
		var hs: float = pc.hs
		var pts: PackedFloat32Array = pc.pts
		var n := pts.size() / 5
		if n < 2: continue
		var nst := maxi(2, int(ceil(2.0 * hs / 1.6)))
		var offs := PackedFloat32Array([-hs - 0.9])
		for i in nst + 1: offs.append(-hs + 2.0 * hs * i / nst)
		offs.append(hs + 0.9)
		var m := offs.size()
		var base := vs.size()
		for i in n:
			var x := pts[i * 5]
			var z := pts[i * 5 + 1]
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, n - 1)
			var tx := pts[i1 * 5] - pts[i0 * 5]
			var tz := pts[i1 * 5 + 1] - pts[i0 * 5 + 1]
			var tl := sqrt(tx * tx + tz * tz)
			if tl < 0.0001: tl = 1.0
			var nx := tz / tl
			var nz := -tx / tl
			for j in m:
				var o := offs[j]
				var p := Vector3(x + nx * o, 0.0, z + nz * o)
				var h := data.get_height(p)
				if is_nan(h): h = 0.0
				var edge := j == 0 or j == m - 1
				p.y = h + (0.02 if edge else 0.045)
				vs.append(p - org)
				var nn := data.get_normal(p)
				ns.append(Vector3.UP if is_nan(nn.x) else nn)
				uv.append(Vector2(o, pts[i * 5 + 2]))
				uv2.append(Vector2(hs, pts[i * 5 + 3]))
				cs.append(Color(0.5 if edge else float(pc.surf), float(pc.mark), pts[i * 5 + 4], float(pc.wild)))
		for i in n - 1:
			for j in m - 1:
				var v := base + i * m + j
				idx.append_array(PackedInt32Array([v, v + 1, v + m, v + 1, v + m + 1, v + m]))
	if vs.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_COLOR] = cs
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, road_mat)
	return am

## Is (x, z) on a road's seal? (for tyres; the road mask: metres from the outer edge, negative on the road)
func on_road(x: float, z: float) -> bool:
	return main.veg != null and main.veg.road_clearance(x, z) < -0.6

var _ft := 0.0

func _process(dt: float) -> void:
	if main == null or main.terrain == null or main.terrain.data == null:
		return
	_ft -= dt
	if _ft > 0.0:
		return
	_ft = 0.1
	var me: Vector3 = main.player.global_position if main.player else Vector3.ZERO
	if main.player and main.player.vehicle: me = main.player.vehicle.global_position
	if main.forge and main.forge.active: me = main.forge.cam.global_position
	# lay the nearest wanted tile (one at a time), and drop far ones
	var best: Dictionary = {}
	var bd := INF
	for t in tiles:
		var d := Vector2(me.x - t.pos.x, me.z - t.pos.z).length()
		if t.flush == null and d < DRAW and not (t.lines as Array).is_empty() and d < bd:
			bd = d
			best = t
		elif t.flush != null and d > DRAW + 400.0:
			(t.flush as Node).queue_free()
			t.flush = null
	if not best.is_empty():
		var am := _flush_mesh(best)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.position = best.pos
		mi.visibility_range_end = DRAW
		mi.visibility_range_end_margin = 200.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		best.flush = mi

func _physics_process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.4
	var anchors := _anchors()
	for t in tiles:
		if t.mesh == null: continue
		var d := 1e9
		for p: Vector3 in anchors:
			d = min(d, Vector2(p.x - t.pos.x, p.z - t.pos.z).length())
		if t.body == null and d < COLLIDE_IN:
			_make_body(t)
		elif t.body != null and d > COLLIDE_OUT:
			t.body.queue_free()
			t.body = null

func _make_body(t: Dictionary) -> void:
	var b := StaticBody3D.new()
	b.add_to_group("road")
	var cs := CollisionShape3D.new()
	cs.shape = (t.mesh as Mesh).create_trimesh_shape()
	b.add_child(cs)
	(t.mi as Node3D).add_child(b)
	t.body = b
