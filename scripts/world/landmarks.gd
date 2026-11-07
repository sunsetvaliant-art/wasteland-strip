class_name Landmarks
extends Node3D
## The Meshy buildings set round the map (assets/world/landmarks.json, from tools/place_landmarks.py): servo canopies
## on the real service stations and old two-storey houses along the town streets and back roads. Each is built when
## you come within sight of it and dropped again when you've gone; you can walk into the houses and drive under the
## canopies (their collision follows the mesh).

const BUILD_R := 1100.0
const DROP_R := 1400.0
const MODELS := {"servo_canopy": "res://assets/meshy/servo_canopy.glb", "village_hq": "res://assets/meshy/village_hq.glb"}
var main
var spots: Array = []            # [{kind, x, z, y, yaw, node}]
var _t := 0.0
static var _shapes := {}         # kind -> [[Transform3D, Shape3D]] (trimeshes made once, shared)

func setup(m) -> void:
	main = m
	var f := FileAccess.open("res://assets/world/landmarks.json", FileAccess.READ)
	if f == null:
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for e in d.landmarks:
		if MODELS.has(e.kind):
			e["node"] = null
			spots.append(e)
	print("LANDMARKS ", spots.size())

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or main == null or main.player == null:
		return
	_t = 0.7
	var me: Vector3 = main.player.vehicle.global_position if main.player.vehicle else main.player.global_position
	if main.forge and main.forge.active: me = main.forge.cam.global_position
	for s in spots:
		var d := Vector2(me.x - float(s.x), me.z - float(s.z)).length()
		if s.node == null and d < BUILD_R:
			_build(s)
		elif s.node != null and d > DROP_R:
			(s.node as Node).queue_free()
			s.node = null

func _build(s: Dictionary) -> void:
	var ps: PackedScene = load(MODELS[s.kind])
	if ps == null:
		return
	var sb := StaticBody3D.new()
	sb.name = "Landmark"
	var vis: Node3D = ps.instantiate()
	sb.add_child(vis)
	if not _shapes.has(s.kind):
		var list := []
		for mi: MeshInstance3D in vis.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D()
			var n: Node = mi
			while n and n != vis:
				if n is Node3D: xf = (n as Node3D).transform * xf
				n = n.get_parent()
			list.append([xf, mi.mesh.create_trimesh_shape()])
		_shapes[s.kind] = list
	for e in _shapes[s.kind]:
		var cs := CollisionShape3D.new()
		cs.transform = e[0]
		cs.shape = e[1]
		sb.add_child(cs)
	add_child(sb)
	# sat down on the lowest corner of its block so no corner hangs in the air
	var y: float = float(s.y)
	if main.has_method("ground_at"):
		y = INF
		var b := Basis(Vector3.UP, float(s.yaw))
		for o in [Vector3(-4, 0, -4), Vector3(4, 0, -4), Vector3(-4, 0, 4), Vector3(4, 0, 4), Vector3.ZERO]:
			var p: Vector3 = Vector3(float(s.x), 0, float(s.z)) + b * o
			y = min(y, main.ground_at(p.x, p.z))
	sb.global_transform = Transform3D(Basis(Vector3.UP, float(s.yaw)), Vector3(float(s.x), y - 0.08, float(s.z)))
	s.node = sb
