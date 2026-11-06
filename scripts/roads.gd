class_name Roads
extends Node3D
## The Tweed road network (tools/bake_roads.py): 1 km tiles of road surface. Every tile is drawn out to the view range;
## collision is built only for tiles near the player, a vehicle someone is in, or the Forge camera, and dropped again
## when nobody's near, so 1,370 km of road doesn't cost us 4 million triangles of physics.

const COLLIDE_IN := 700.0
const COLLIDE_OUT := 1000.0
const DRAW := 3200.0

var tiles: Array = []            # [{pos: Vector3, node: Node3D, mesh: Mesh, body: StaticBody3D}]
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
	for t in idx.tiles:
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
		tiles.append({"pos": Vector3(t.x, 0, t.z), "mi": mi, "mesh": mesh, "body": null, "names": t.names})

## Points that need solid road under them: you, cars with someone in them, the Forge camera, and any car moving
func _anchors() -> Array:
	var a := []
	if main.player: a.append(main.player.global_position)
	if main.forge and main.forge.active: a.append(main.forge.cam.global_position)
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v.driver or (v is RigidBody3D and (v as RigidBody3D).linear_velocity.length() > 1.0):
			a.append(v.global_position)
	return a

func _physics_process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.4
	var anchors := _anchors()
	for t in tiles:
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
