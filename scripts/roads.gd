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

static var inst: Roads
var _seg := {}          # Vector2i (32 m) -> PackedFloat32Array of segments [x0, z0, x1, z1, half-width]

func setup(m) -> void:
	main = m
	inst = self
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
	_setup_overlay()
	var idx = JSON.parse_string(FileAccess.get_file_as_string("res://assets/roads/index.json"))
	if typeof(idx) != TYPE_DICTIONARY:
		push_warning("no road index")
		return
	var lines := _read_lines()
	# the roads north of the old map edge (tools/bake_north.py): tiles of their own, no bridges
	var north := _read_lines("res://assets/roads/lines_north.bin")
	for k in north:
		if lines.has(k): lines[k] = lines[k] + north[k]
		else: lines[k] = north[k]
	print("ROADS flush tiles ", lines.size())
	_index_segments(lines)
	var listed := {}
	for t in idx.tiles:
		listed[Vector2i(floori((float(t.x) - X0) / 1024.0), floori((float(t.z) - Z0) / 1024.0))] = true
	for k in north:
		if listed.has(k): continue
		var td0 := {"pos": Vector3(X0 + k.x * 1024.0 + 512.0, 0, Z0 + k.y * 1024.0 + 512.0), "mi": null, "mesh": null, "body": null, "names": [], "lines": lines[k], "flush": null}
		tiles.append(td0)
		_by_key[k] = td0
	# bridges: the modular kit (scripts/world/bridge_kit.gd) unless BRIDGE_OLD asks for the old baked decks
	var kit := OS.get_environment("BRIDGE_OLD") == "" and FileAccess.file_exists("res://assets/world/bridges.json")
	for t in idx.tiles:
		var key := Vector2i(floori((float(t.x) - X0) / 1024.0), floori((float(t.z) - Z0) / 1024.0))
		var td := {"pos": Vector3(t.x, 0, t.z), "mi": null, "mesh": null, "body": null, "names": t.names, "lines": lines.get(key, []), "flush": null}
		tiles.append(td)
		_by_key[key] = td
		if str(t.get("file", "")) == "" or kit:
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

	if kit: _build_bridges()

func _build_bridges() -> void:
	var t0 := Time.get_ticks_msec()
	var data: Terrain3DData = main.terrain.data
	BridgeKit.load_all()
	var moved := BridgeKit.conform(data)
	if moved > 0: data.update_maps(Terrain3DRegion.TYPE_HEIGHT)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.62, 0.64, 0.66); steel.metallic = 0.7; steel.roughness = 0.45
	steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	var built := BridgeKit.build(data, [road_mat, conc_mat, steel], X0, Z0)
	for key in built:
		var td: Dictionary = _by_key.get(key, {})
		if td.is_empty():
			td = {"pos": built[key].org, "mi": null, "mesh": null, "body": null, "names": [], "lines": [], "flush": null}
			tiles.append(td); _by_key[key] = td
		var mi := MeshInstance3D.new()
		mi.mesh = built[key].mesh
		mi.position = built[key].org
		mi.visibility_range_end = DRAW
		mi.visibility_range_end_margin = 200.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mi)
		td.mi = mi
		td.mesh = mi.mesh
	print("BRIDGES kit: %d bridges in %d tiles, %d ground points reshaped, %d ms" % [BridgeKit.bridges.size(), built.size(), moved, Time.get_ticks_msec() - t0])

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
func _read_lines(path := "res://assets/roads/lines.bin") -> Dictionary:
	var out := {}
	var f := FileAccess.open(path, FileAccess.READ)
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
				var edge := j == 0 or j == m - 1
				vs.append(p - org)
				ns.append(Vector3.UP)
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
	am.surface_set_material(0, overlay_mat)
	return am

# ------------------------------------------------------------------ the roads, painted into the terrain
# The road skins live in a world of their own and are drawn from straight above into three textures that follow
# you (6 cm, 0.5 m and 4 m to a pixel); the terrain's shader blends them into the ground. One surface, so nothing to
# flicker, and no edge to drive into.
var overlay_world := World3D.new()
var overlay_mat: ShaderMaterial
var _cascades: Array = []         # [{vp, cam, size, px, centre: Vector2, dirty, step}]
const CASCADES := [[256.0, 4096], [1024.0, 2048], [8192.0, 2048]]

func _setup_overlay() -> void:
	if OS.get_environment("ROAD_OVERLAY_OFF") != "":
		return
	var code: String = (road_mat.shader as Shader).code
	code = code.replace("render_mode cull_back, diffuse_burley, specular_schlick_ggx;", "render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix, fog_disabled;")
	code = code.replace("\tPOSITION = PROJECTION_MATRIX * vp;", "")
	code = code.replace("\tALBEDO = col;", "\tALBEDO = col;\n\tALPHA = 1.0 - smoothstep(hs, hs + 0.9, abs(off));")
	var sh := Shader.new()
	sh.code = code
	overlay_mat = road_mat.duplicate()
	overlay_mat.shader = sh
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	for i in CASCADES.size():
		var vp := SubViewport.new()
		vp.size = Vector2i(CASCADES[i][1], CASCADES[i][1])
		vp.world_3d = overlay_world
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.positional_shadow_atlas_size = 0
		add_child(vp)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = CASCADES[i][0]
		cam.near = 1.0
		cam.far = 4000.0
		cam.environment = env
		vp.add_child(cam)
		cam.current = true
		_cascades.append({"vp": vp, "cam": cam, "size": float(CASCADES[i][0]), "centre": Vector2(INF, INF), "dirty": true, "step": float(CASCADES[i][0]) / 8.0})
	# the terrain's own shader with the cascades blended in at the end
	var tm: Terrain3DMaterial = main.terrain.material
	tm.shader_override_enabled = true
	var tsh: Shader = tm.shader_override
	if tsh == null:
		push_warning("no terrain shader to paint roads into")
		return
	var tc := tsh.code
	if not tc.contains("road_paint"):
		var funcs := """
uniform sampler2D road_c0 : source_color, filter_linear, repeat_disable;
uniform sampler2D road_c1 : source_color, filter_linear, repeat_disable;
uniform sampler2D road_c2 : source_color, filter_linear, repeat_disable;
uniform vec4 road_r0 = vec4(0.0, 0.0, -1.0, 0.0);
uniform vec4 road_r1 = vec4(0.0, 0.0, -1.0, 0.0);
uniform vec4 road_r2 = vec4(0.0, 0.0, -1.0, 0.0);
vec4 road_cascade(sampler2D t, vec4 r, vec2 p, out float inside) {
	vec2 uv = (p - r.xy) / max(r.z, 1.0);
	vec2 e = min(uv, vec2(1.0) - uv);
	inside = r.z > 0.0 ? clamp(min(e.x, e.y) * 16.0, 0.0, 1.0) : 0.0;
	return texture(t, uv);
}
vec4 road_paint(vec2 p) {
	float i0; float i1; float i2;
	vec4 c2 = road_cascade(road_c2, road_r2, p, i2);
	vec4 c1 = road_cascade(road_c1, road_r1, p, i1);
	vec4 c0 = road_cascade(road_c0, road_r0, p, i0);
	vec4 c = c2 * i2;
	c = mix(c, c1, i1);
	c = mix(c, c0, i0);
	return c;
}
"""
		var blend := """
	vec4 rp = road_paint(v_vertex.xz);
	if (rp.a > 0.003) {
		vec3 rc = rp.rgb / max(rp.a, 0.003);
		ALBEDO = mix(ALBEDO, rc, rp.a);
		ROUGHNESS = mix(ROUGHNESS, 0.82, rp.a);
		SPECULAR = mix(SPECULAR, 0.3, rp.a);
		NORMAL_MAP = mix(NORMAL_MAP, vec3(0.5, 0.5, 1.0), rp.a * 0.85);
		AO = mix(AO, 1.0, rp.a);
	}
"""
		var fi := tc.find("void fragment()")
		tc = tc.substr(0, fi) + funcs + tc.substr(fi)
		var ai := tc.rfind("AO_LIGHT_AFFECT = mat.ao_affect;")
		var nl := tc.find("\n", ai)
		tc = tc.substr(0, nl + 1) + blend + tc.substr(nl + 1)
		var nsh := Shader.new()
		nsh.code = tc
		tm.shader_override = nsh
	for i in _cascades.size():
		tm.set_shader_param("road_c%d" % i, (_cascades[i].vp as SubViewport).get_texture())
	print("ROADS painted into the terrain")

var _ov_t := 0.0
func _update_overlay(me: Vector3) -> void:
	if _cascades.is_empty():
		return
	_ov_t -= 0.1
	if _ov_t > 0.0:
		return
	_ov_t = 0.5
	var tm: Terrain3DMaterial = main.terrain.material
	for i in _cascades.size():
		var c: Dictionary = _cascades[i]
		var step: float = c.step
		var want := Vector2(roundf(me.x / step) * step, roundf(me.z / step) * step)
		if want == c.centre and not c.dirty:
			continue
		c.centre = want
		c.dirty = false
		var cam: Camera3D = c.cam
		cam.look_at_from_position(Vector3(want.x, 2000.0, want.y), Vector3(want.x, 0.0, want.y), Vector3(0, 0, -1))
		(c.vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
		_set_rect.call_deferred(tm, i, want, float(c.size))

func _set_rect(tm: Terrain3DMaterial, i: int, centre: Vector2, size: float) -> void:
	await RenderingServer.frame_post_draw
	tm.set_shader_param("road_r%d" % i, Vector4(centre.x - size * 0.5, centre.y - size * 0.5, size, 0.0))

func _index_segments(lines: Dictionary) -> void:
	for key in lines:
		for pc in lines[key]:
			var pts: PackedFloat32Array = pc.pts
			var hs: float = pc.hs
			for i in pts.size() / 5 - 1:
				var ax := pts[i * 5]
				var az := pts[i * 5 + 1]
				var bx := pts[i * 5 + 5]
				var bz := pts[i * 5 + 6]
				var gx0 := floori((minf(ax, bx) - hs) / 32.0)
				var gx1 := floori((maxf(ax, bx) + hs) / 32.0)
				var gz0 := floori((minf(az, bz) - hs) / 32.0)
				var gz1 := floori((maxf(az, bz) + hs) / 32.0)
				for gx in range(gx0, gx1 + 1):
					for gz in range(gz0, gz1 + 1):
						var k := Vector2i(gx, gz)
						if not _seg.has(k): _seg[k] = PackedFloat32Array()
						_seg[k].append_array(PackedFloat32Array([ax, az, bx, bz, hs]))

## Metres from (x, z) to the nearest road's seal edge (negative on the road); 30 if none near
func edge_dist(x: float, z: float) -> float:
	var best := 30.0
	var c := Vector2i(floori(x / 32.0), floori(z / 32.0))
	for gx in range(c.x - 1, c.x + 2):
		for gz in range(c.y - 1, c.y + 2):
			var a: PackedFloat32Array = _seg.get(Vector2i(gx, gz), PackedFloat32Array())
			for i in range(0, a.size(), 5):
				var dx := a[i + 2] - a[i]
				var dz := a[i + 3] - a[i + 1]
				var l2 := dx * dx + dz * dz + 0.000001
				var t := clampf(((x - a[i]) * dx + (z - a[i + 1]) * dz) / l2, 0.0, 1.0)
				var ex := a[i] + dx * t - x
				var ez := a[i + 1] + dz * t - z
				var d := sqrt(ex * ex + ez * ez) - a[i + 4]
				if d < best: best = d
	return best

## Is (x, z) on a road's seal? (for tyres; the road mask: metres from the outer edge, negative on the road)
func on_road(x: float, z: float) -> bool:
	return edge_dist(x, z) < 0.1

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
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _cascades.is_empty(): add_child(mi)
		else: _cascades[0].vp.add_child(mi)          # drawn only into the overlay, never in the world
		best.flush = mi
		for c in _cascades: c.dirty = true
	_update_overlay(me)

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
