class_name BuildDoor
extends StaticBody3D
## A hinged door in a generated building. F opens or shuts it; a zombie leaning on a shut one pushes it open.
## The body is the leaf: it swings about its hinge edge (the parent pivot), away from whoever opened it.

var pivot: Node3D
var boards: Boards
var key := ""
var leaf_w := 0.82
var leaf_h := 2.0
var open := false
var _target := 0.0
var _angle := 0.0
var width := 0.82
var _snd: AudioStreamPlayer3D

func setup(p: Node3D, w: float, h: float, mat: Material, glass := false) -> void:
	pivot = p
	width = w
	leaf_w = w
	leaf_h = h
	add_to_group("doors")
	collision_layer = 1
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, 0.04)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3(w * 0.5, h * 0.5, 0)
	add_child(mi)
	if glass:
		# a shop door: a timber frame round a big pane
		bm.size = Vector3(w, h, 0.045)
		mi.mesh = null
		var fr := [[Vector3(w * 0.5, 0.18, 0), Vector3(w, 0.36, 0.045)], [Vector3(w * 0.5, h - 0.06, 0), Vector3(w, 0.12, 0.045)],
			[Vector3(0.05, h * 0.5, 0), Vector3(0.1, h, 0.045)], [Vector3(w - 0.05, h * 0.5, 0), Vector3(0.1, h, 0.045)],
			[Vector3(w * 0.5, 1.05, 0), Vector3(w, 0.06, 0.045)]]
		for e in fr:
			var fm := MeshInstance3D.new()
			var fb := BoxMesh.new()
			fb.size = e[1]
			fm.mesh = fb
			fm.material_override = mat
			fm.position = e[0]
			add_child(fm)
		var gl := MeshInstance3D.new()
		var gb := BoxMesh.new()
		gb.size = Vector3(w - 0.2, h - 0.48, 0.008)
		gl.mesh = gb
		gl.material_override = BuildGen.mat("glass")
		gl.position = Vector3(w * 0.5, 0.36 + (h - 0.48) * 0.5, 0)
		add_child(gl)
	var knob := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(0.05, 0.05, 0.14)
	knob.mesh = km
	var kmat := StandardMaterial3D.new()
	kmat.albedo_color = Color(0.55, 0.5, 0.4)
	kmat.metallic = 0.8
	kmat.roughness = 0.4
	knob.material_override = kmat
	knob.position = Vector3(w - 0.08, 1.0, 0)
	knob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	knob.visibility_range_end = 40.0
	add_child(knob)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w - 0.02, h - 0.02, 0.05)
	cs.shape = bs
	cs.position = mi.position
	add_child(cs)
	set_meta("container_name", "door")

func hint() -> String:
	if boards: return boards.hint()
	return "F  Close door" if open else "F  Open door"

## Swing it from where `from` stands: away from them
func toggle(from := Vector3.INF) -> void:
	if boards:
		return
	if open:
		_target = 0.0
	else:
		var side := 1.0
		if from != Vector3.INF:
			var local := pivot.global_transform.affine_inverse() * from
			side = 1.0 if local.z > 0.0 else -1.0     # +angle swings the leaf toward -z, away from someone at +z
		_target = side * deg_to_rad(95.0)
	open = not open
	set_physics_process(true)

func push_open(from: Vector3) -> void:
	if not open and boards == null:
		toggle(from)

func _physics_process(dt: float) -> void:
	_angle = move_toward(_angle, _target, dt * 3.2)
	pivot.rotation.y = _angle
	if is_equal_approx(_angle, _target):
		set_physics_process(false)
