class_name RgRoads
extends Node3D
## The roads built with the Road Generator addon (every OpenStreetMap road on the map), baked into 1 km tiles by
## tools/bake_rg.gd: plain meshes drawn with the road shader, collision made for the tiles near anything that needs to
## stand or drive on them (like the old roads), and the roundabouts' kerbed islands.

const DRAW := 3500.0
const COLLIDE_IN := 700.0
const COLLIDE_OUT := 900.0
var main
var tiles: Array = []          # [{pos, mi, mesh, body}]
var mat: ShaderMaterial
var _t := 0.0

static func available() -> bool:
	return FileAccess.file_exists("res://assets/roads_rg/index.json")

func setup(m) -> void:
	main = m
	var idx = JSON.parse_string(FileAccess.get_file_as_string("res://assets/roads_rg/index.json"))
	if typeof(idx) != TYPE_DICTIONARY:
		return
	mat = RoadPilot.make_material()
	for t in idx.tiles:
		var mesh: Mesh = load("res://assets/roads_rg/" + t.file)
		if mesh == null: continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = DRAW
		mi.visibility_range_end_margin = 300.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mi)
		mi.position = Vector3(t.x, 0, t.z)
		tiles.append({"pos": Vector3(t.x, 0, t.z), "mi": mi, "mesh": mesh, "body": null})
	for e in idx.get("islands", []):
		add_child(RoadPilot.island_node(Vector3(e[0], e[1], e[2]), float(e[3])))
	print("RGROADS tiles ", tiles.size(), " roundabouts ", idx.get("islands", []).size())

func _physics_process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or main == null or main.roads == null:
		return
	_t = 0.4
	var anchors: Array = main.roads._anchors()
	for t in tiles:
		var d := 1e9
		for p: Vector3 in anchors:
			d = min(d, Vector2(p.x - t.pos.x, p.z - t.pos.z).length())
		if t.body == null and d < COLLIDE_IN:
			var b := StaticBody3D.new()
			b.add_to_group("road")
			var cs := CollisionShape3D.new()
			cs.shape = (t.mesh as Mesh).create_trimesh_shape()
			b.add_child(cs)
			(t.mi as Node3D).add_child(b)
			t.body = b
		elif t.body != null and d > COLLIDE_OUT:
			t.body.queue_free()
			t.body = null
