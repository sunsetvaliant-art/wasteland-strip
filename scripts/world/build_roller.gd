class_name BuildRoller
extends StaticBody3D
## A roller door (sheds, workshops): F rolls it up or down. Zombies can't work it. Frame: bottom centre of the
## opening at the origin, the door in the xy plane.

var w := 3.6
var h := 3.0
var open_frac := 0.0
var _target := 0.0
var _panel: MeshInstance3D
var _shape: CollisionShape3D
var _box: BoxShape3D
var _snd: AudioStreamPlayer3D

func setup(width: float, height: float, frac: float) -> void:
	w = width
	h = height
	add_to_group("rollers")
	collision_layer = 1
	_panel = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, 0.04)
	_panel.mesh = bm
	_panel.material_override = BuildGen.mat("tin:grey")
	add_child(_panel)
	_shape = CollisionShape3D.new()
	_box = BoxShape3D.new()
	_box.size = Vector3(w, h, 0.06)
	_shape.shape = _box
	add_child(_shape)
	# the drum it rolls up into
	var drum := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.22
	cm.height = w + 0.1
	drum.mesh = cm
	drum.material_override = BuildGen.mat("steel")
	drum.rotation.z = PI * 0.5
	drum.position = Vector3(0, h + 0.18, -0.12)
	add_child(drum)
	_snd = AudioStreamPlayer3D.new()
	_snd.stream = Gun.sfx("roller_door")
	_snd.unit_size = 10.0
	add_child(_snd)
	open_frac = frac
	_target = frac
	_apply()

func hint() -> String:
	return "F  roll the door down" if _target > 0.5 else "F  roll the door up"

func toggle() -> void:
	_target = 0.0 if _target > 0.5 else 0.94
	_snd.play()
	set_physics_process(true)

func _physics_process(dt: float) -> void:
	open_frac = move_toward(open_frac, _target, dt * 0.6)
	_apply()
	if is_equal_approx(open_frac, _target):
		set_physics_process(false)

func _apply() -> void:
	var vis_h := h * (1.0 - open_frac)
	_panel.scale.y = maxf(1.0 - open_frac, 0.02)
	_panel.position.y = h - vis_h * 0.5
	_box.size = Vector3(w, maxf(vis_h, 0.05), 0.06)
	_shape.position.y = h - vis_h * 0.5
	_panel.visible = open_frac < 0.99
