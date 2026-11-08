extends SceneTree
## Small item models made from primitives (saved as scenes): a duct tape roll, a box of nails, a timber plank, and a
## stack of planks for sheds. Real-world sizes, sitting on y = 0.
##   godot --headless --path . -s tools/make_item_scenes.gd
const OUT := "res://assets/props/items/"

func _mat(albedo_tex: String, col: Color, rough := 0.8, metal := 0.0, scale := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if albedo_tex != "":
		m.albedo_texture = load(albedo_tex)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m

func _save(root: Node3D, name: String) -> void:
	for c in root.find_children("*", "", true, false):
		c.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, OUT + name + ".tscn")
	print("saved ", name)

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _init() -> void:
	var timber := _mat("res://assets/ph/tex/weathered_brown_planks/weathered_brown_planks_diffuse.jpg", Color(1.1, 1.0, 0.9), 0.85, 0.0, 1.6)
	# duct tape: a silver roll on a cardboard core
	var tape := Node3D.new(); tape.name = "Tape"
	var tor := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.036; tm.outer_radius = 0.058; tm.rings = 24; tm.ring_segments = 10
	tor.mesh = tm
	tor.scale = Vector3(1, 2.2, 1)
	tor.position.y = 0.024
	tor.material_override = _mat("", Color(0.4, 0.41, 0.43), 0.5, 0.3)
	tape.add_child(tor)
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.037; cm.bottom_radius = 0.037; cm.height = 0.046
	core.mesh = cm; core.position.y = 0.024
	core.material_override = _mat("", Color(0.55, 0.42, 0.28), 0.9)
	tape.add_child(core)
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new(); hm.top_radius = 0.033; hm.bottom_radius = 0.033; hm.height = 0.047
	hole.mesh = hm; hole.position.y = 0.024
	hole.material_override = _mat("", Color(0.05, 0.05, 0.05), 1.0)
	tape.add_child(hole)
	_save(tape, "duct_tape")
	# box of nails: a small cardboard box, lid off a bit, nail heads showing
	var nails := Node3D.new(); nails.name = "Nails"
	var card := _mat("res://assets/ph/world/cardboard_box_01/textures/cardboard_box_01_diff_1k.jpg", Color(1, 1, 1), 0.9, 0.0, 6.0)
	_box(nails, Vector3(0.12, 0.07, 0.17), Vector3(0, 0.035, 0), card)
	_box(nails, Vector3(0.125, 0.012, 0.09), Vector3(0, 0.076, -0.045), card)
	var steel := _mat("", Color(0.55, 0.56, 0.58), 0.35, 0.9)
	for i in 14:
		var r := MeshInstance3D.new()
		var c2 := CylinderMesh.new(); c2.top_radius = 0.004; c2.bottom_radius = 0.004; c2.height = 0.006
		r.mesh = c2; r.material_override = steel
		r.position = Vector3(-0.045 + (i % 5) * 0.022, 0.071, 0.012 + (i / 5) * 0.022)
		nails.add_child(r)
	_box(nails, Vector3(0.122, 0.03, 0.0005), Vector3(0, 0.035, 0.0853), _mat("", Color(0.85, 0.2, 0.15), 0.8))
	_save(nails, "nails_box")
	# a plank: 1.2 m of 150 x 25 hardwood
	var plank := Node3D.new(); plank.name = "Plank"
	_box(plank, Vector3(0.15, 0.025, 1.2), Vector3(0, 0.0125, 0), timber)
	_save(plank, "plank")
	# a stack of them in a shed
	var stack := Node3D.new(); stack.name = "PlankStack"
	var rng := RandomNumberGenerator.new(); rng.seed = 4
	for layer in 4:
		for k in 3:
			_box(stack, Vector3(0.15, 0.025, 1.2), Vector3(-0.17 + k * 0.17 + rng.randf_range(-0.02, 0.02), 0.0125 + layer * 0.026, rng.randf_range(-0.04, 0.04)), timber, Vector3(0, rng.randf_range(-0.04, 0.04), 0))
	_save(stack, "plank_stack")
	quit()
