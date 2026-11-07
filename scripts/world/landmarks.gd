class_name Landmarks
extends Node3D
## The Meshy buildings set round the map (assets/world/landmarks.json, from tools/place_landmarks.py): servo canopies
## on the real service stations and old two-storey houses along the town streets and back roads. Each is built when
## you come within sight of it and dropped again when you've gone; you can walk into the houses and drive under the
## canopies (their collision follows the mesh).

const BUILD_R := 1100.0
const DROP_R := 1400.0
const MODELS := {"servo_canopy": "res://assets/meshy/servo_canopy.glb", "village_hq": "res://assets/meshy/village_hq.glb",
	"ampol_servo": "res://assets/meshy/ampol_servo.glb"}
# holes cut in a model's walls (model space AABBs): the Ampol's shop door, and its workshop roller door half up
const CUTS := {"ampol_servo": [AABB(Vector3(-1.02, 0.12, 0.0), Vector3(0.82, 2.1, 2.7))]}
# rooms inside (model space), furnished like a generated building's: [x0, z0, x1, z1, type, floor y, front door span]
const ROOMS := {"ampol_servo": [[-7.5, -5.3, 0.25, 1.6, "servo_shop", [-1.05, -0.15]], [0.55, -5.3, 7.5, 1.4, "servo_bay", [0.4, 3.6]]]}
static var _meshes := {}         # kind -> [[path in scene, Mesh]] with the holes cut
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
		if MODELS.has(e.kind) and not (e.kind == "village_hq" and Buildings.available()):   # the town's houses are generated now
			e["node"] = null
			spots.append(e)
			if e.kind == "ampol_servo":
				Buildings.add_blocker(float(e.x), float(e.z), float(e.yaw), 16.5, 12.5)     # no trees or grass inside
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
			if main.buildings: main.buildings._save_boxes(s.node)
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
	if CUTS.has(s.kind):
		_cut_holes(s.kind, vis)
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
	# sat down on the lowest corner of its block so no corner hangs in the air; the Ampol on the highest, with a
	# concrete plinth under it down to the lowest, so the ground never comes up through the shop floor
	var y: float = float(s.y)
	if main.has_method("ground_at"):
		y = INF
		var hi := -INF
		var b := Basis(Vector3.UP, float(s.yaw))
		var pts := [Vector3(-4, 0, -4), Vector3(4, 0, -4), Vector3(-4, 0, 4), Vector3(4, 0, 4), Vector3.ZERO]
		if s.kind == "ampol_servo":
			pts = []
			for ix in [-7.8, -4.0, 0.0, 4.0, 7.8]:
				for iz in [-5.8, -2.0, 2.0, 5.8]:
					pts.append(Vector3(ix, 0, iz))
		for o in pts:
			var p: Vector3 = Vector3(float(s.x), 0, float(s.z)) + b * o
			var gy: float = main.height_at(p.x, p.z)
			y = min(y, gy)
			hi = max(hi, gy)
		if s.kind == "ampol_servo":
			var lo := y
			y = hi + 0.12
			var plinth := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(16.2, y - lo + 0.6, 12.2)
			plinth.mesh = bm
			plinth.material_override = BuildGen.mat("concrete")
			plinth.position = Vector3(0, -(y - lo + 0.6) / 2 + 0.06, 0)
			sb.add_child(plinth)
			var pcs := CollisionShape3D.new()
			var pbs := BoxShape3D.new()
			pbs.size = bm.size
			pcs.shape = pbs
			pcs.position = plinth.position
			sb.add_child(pcs)
	sb.global_transform = Transform3D(Basis(Vector3.UP, float(s.yaw)), Vector3(float(s.x), y - 0.08, float(s.z)))
	s.node = sb
	if ROOMS.has(s.kind):
		_furnish.call_deferred(s, sb)

## Take out the triangles inside the cut boxes (once per kind; every copy shares the cut meshes)
func _cut_holes(kind: String, vis: Node3D) -> void:
	if not _meshes.has(kind):
		var list := []
		for mi: MeshInstance3D in vis.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D()
			var n: Node = mi
			while n and n != vis:
				if n is Node3D: xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var src: Mesh = mi.mesh
			var am := ArrayMesh.new()
			for si in src.get_surface_count():
				var arr := src.surface_get_arrays(si)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var keep := PackedInt32Array()
				for t in range(0, idx.size(), 3):
					var c := xf * ((verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0)
					var cut := false
					for box: AABB in CUTS[kind]:
						if box.has_point(c):
							cut = true
							break
					if not cut:
						keep.append_array(PackedInt32Array([idx[t], idx[t + 1], idx[t + 2]]))
				arr[Mesh.ARRAY_INDEX] = keep
				for k in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
					arr[k] = null
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				am.surface_set_material(si, src.surface_get_material(si) if src.surface_get_material(si) else mi.get_active_material(si))
			list.append([vis.get_path_to(mi), am])
		_meshes[kind] = list
	for e in _meshes[kind]:
		var mi := vis.get_node_or_null(e[0]) as MeshInstance3D
		if mi: mi.mesh = e[1]

## Shelves, fridges and a counter in the shop; benches, tools and tyres in the workshop (loot in them)
func _furnish(s: Dictionary, sb: StaticBody3D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(sb): return
	var space := sb.get_world_3d().direct_space_state
	var plan := {"floors": [], "kind": "landmark", "seed": int(absf(float(s.x) * 7.0 + float(s.z) * 13.0))}
	var rooms := []
	for rd in ROOMS[s.kind]:
		# the floor: straight down onto the model's own floor in the middle of the room
		var cl := Vector3((rd[0] + rd[2]) * 0.5, 0, (rd[1] + rd[3]) * 0.5)
		var wp := sb.global_transform * (cl + Vector3(0, 3.0, 0))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(wp, wp + Vector3.DOWN * 6.0, 1))
		var fy := 0.25
		if hit: fy = (sb.global_transform.affine_inverse() * (hit.position as Vector3)).y
		var r := {"x0": rd[0], "z0": rd[1], "x1": rd[2], "z1": rd[3], "type": rd[4], "h": 3.2, "id": "lm",
			"ops": {"N": [], "S": [{"a": rd[5][0], "b": rd[5][1], "kind": "door", "y0": 0.0, "y1": 2.1}], "W": [], "E": []}}
		plan.floors.append({"y": fy, "h": 3.2, "rooms": [r]})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(plan.seed)
	var boxes := BuildProps.furnish(plan, sb, rng)
	for bi in boxes.size():
		var box: Node3D = boxes[bi]
		box.set_meta("loot_seed", int(plan.seed) * 31 + bi * 7919)
		box.set_meta("loot_key", "lm%d:%d" % [spots.find(s), bi])
		if main.buildings:
			var st: Dictionary = main.buildings.loot_store.get(box.get_meta("loot_key"), {})
			if not st.is_empty() and Time.get_unix_time_from_system() - float(st.t) < Buildings.RESPAWN_S:
				box.set_meta("inv", st.inv)
