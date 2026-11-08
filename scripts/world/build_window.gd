class_name BuildWindow
extends StaticBody3D
## A window in a generated building: a sash window you can slide open (F) and climb through (Space), or put a bullet
## through (the glass goes). Can be boarded up (G, with a hammer, nails and two planks).
## Frame: centre of the opening at the origin, glass in the xy plane, +z outside.

var w := 1.2
var h := 1.15
var state := "closed"            # closed | open | broken
var boards: Boards
var key := ""
var _lower: Node3D
var _upper: Node3D
var _shape: CollisionShape3D
var _box: BoxShape3D

func setup(width: float, height: float, broken := false) -> void:
	w = width
	h = height
	add_to_group("windows")
	collision_layer = 1
	var glass: Material = BuildGen.mat("glass")
	var frame: Material = BuildGen.mat("trim")
	_upper = _sash(glass, frame, 0.012)
	_upper.position = Vector3(0, h * 0.25, 0.012)
	_lower = _sash(glass, frame, -0.012)
	_lower.position = Vector3(0, -h * 0.25, -0.012)
	_shape = CollisionShape3D.new()
	_box = BoxShape3D.new()
	_box.size = Vector3(w, h, 0.05)
	_shape.shape = _box
	add_child(_shape)
	if broken:
		_smash(false, false)

func _sash(glass: Material, frame: Material, _z: float) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var g := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w - 0.08, h * 0.5 - 0.06, 0.006)
	g.mesh = bm
	g.material_override = glass
	n.add_child(g)
	for e in [[Vector3(0, h * 0.25 - 0.02, 0), Vector3(w, 0.04, 0.035)], [Vector3(0, -h * 0.25 + 0.02, 0), Vector3(w, 0.04, 0.035)],
			[Vector3(-w * 0.5 + 0.02, 0, 0), Vector3(0.04, h * 0.5, 0.035)], [Vector3(w * 0.5 - 0.02, 0, 0), Vector3(0.04, h * 0.5, 0.035)]]:
		var f := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = e[1]
		f.mesh = fb
		f.material_override = frame
		f.position = e[0]
		n.add_child(f)
	return n

func hint() -> String:
	if boards: return boards.hint()
	match state:
		"broken": return "Space  climb through"
		"open": return "F  close window   ·   Space  climb through"
	return "F  open window"

func toggle() -> void:
	if boards or state == "broken":
		return
	state = "open" if state == "closed" else "closed"
	var tw := create_tween()
	tw.tween_property(_lower, "position:y", (h * 0.25 - 0.03) if state == "open" else -h * 0.25, 0.35)
	# open: only the top half is glass now
	_box.size = Vector3(w, h * 0.5 if state == "open" else h, 0.05)
	_shape.position.y = h * 0.25 if state == "open" else 0.0

func passable() -> bool:
	return boards == null and state != "closed"

## Shot (or hit hard): the glass goes
func glass_hit(_p: Vector3, _d: Vector3) -> void:
	if state != "broken":
		_smash(true)

func _smash(fx: bool, remember := true) -> void:
	state = "broken"
	for s in [_lower, _upper]:
		for c in s.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).material_override == BuildGen.mat("glass"):
				c.queue_free()
	_shape.disabled = true
	if remember and Buildings.inst and key != "":
		Buildings.inst.broken[key] = true
	if fx:
		var a := AudioStreamPlayer3D.new()
		a.stream = Gun.sfx("glass_break")
		a.unit_size = 8.0
		add_child(a)
		a.play()
		var pt := CPUParticles3D.new()
		pt.one_shot = true
		pt.amount = 40
		pt.lifetime = 1.2
		pt.explosiveness = 0.95
		pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		pt.emission_box_extents = Vector3(w * 0.4, h * 0.4, 0.02)
		pt.direction = Vector3(0, 0, 1)
		pt.spread = 70.0
		pt.initial_velocity_min = 0.5
		pt.initial_velocity_max = 2.5
		pt.gravity = Vector3(0, -9.8, 0)
		var q := BoxMesh.new()
		q.size = Vector3(0.03, 0.03, 0.003)
		pt.mesh = q
		pt.material_override = BuildGen.mat("glass")
		add_child(pt)
		pt.emitting = true
		get_tree().create_timer(2.0).timeout.connect(pt.queue_free)

## Through the window to the other side of it from `who`, landing on whatever floor or ground is there
func climb(who: CharacterBody3D) -> void:
	if not passable():
		return
	var lp := to_local(who.global_position)
	var side := -1.0 if lp.z > 0.0 else 1.0
	var over := to_global(Vector3(0, -h * 0.5 + 0.2, side * 0.8))
	var q := PhysicsRayQueryParameters3D.create(over + Vector3.UP * 0.5, over + Vector3.DOWN * 4.0, 1, [who.get_rid(), get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var land: Vector3 = (hit.position as Vector3) + Vector3.UP * 0.05 if hit else over
	var tw := who.create_tween()
	tw.tween_property(who, "global_position", to_global(Vector3(0, -h * 0.5 + 0.4, 0)), 0.3)
	tw.tween_property(who, "global_position", land, 0.35)
