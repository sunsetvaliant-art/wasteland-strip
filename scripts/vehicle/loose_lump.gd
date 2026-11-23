class_name LooseLump
extends RigidBody3D
## A heavy part unbolted where it sits (0.2.68: the engine). It stays put on its mounts (frozen) until a chain, a
## strap or a hand pulls it; then it comes free of the car it was in without catching on the car's own collision,
## until it's clear of the bay. "kit" holds what it is (the engine kit dictionary).
## 0.2.70: it never touches its own car's collision while it's in the bay (sat frozen inside the body's box it shoved
## the car up off the ground), and the engine mounts hold it up while it's dragged about in there, so it can't drop
## through the chassis: it slides out across the mounts or comes up out of the bay.

var home: Car = null             # the car it came out of: no collision with it while it's still in the bay
var kit: Dictionary = {}
var _clear := false
var _home_y := 0.0               # its height in the car's frame as it sat on its mounts

func setup(car: Car, kit_d: Dictionary) -> void:
	home = car
	kit = kit_d
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	add_to_group("physgun")
	add_to_group("loose_engines")
	var pb := EngineKit.parse_block(str(kit.get("block", "")))
	set_meta("forge_name", ("Engine (%s)" % str(EngineKit.BLOCKS[pb[0]].name)) if not pb.is_empty() and EngineKit.BLOCKS.has(pb[0]) else "Engine")
	mass = float(EngineKit.BLOCKS[pb[0]].kg[1]) + 40.0 if not pb.is_empty() and EngineKit.BLOCKS.has(pb[0]) else 200.0
	if home and is_instance_valid(home):
		add_collision_exception_with(home)
		home.add_collision_exception_with(self)
		_home_y = home.to_local(global_position).y

## Something's pulling: off its mounts
func wake() -> void:
	if not freeze: return
	freeze = false
	sleeping = false

func _physics_process(_dt: float) -> void:
	if _clear or home == null: return
	if not is_instance_valid(home):
		_clear = true
		return
	var l := home.to_local(global_position)
	# clear of the bay: up over the body, or well off to one side or out the front
	var top := float(home.def.min[1]) + float(home.def.ext[1]) + float(home.design.cab_offset[1])
	var half := float(home.def.ext[2]) * 0.5
	var out_front: bool = l.z > float(home.def.min[0]) + float(home.def.ext[0]) + float(home.design.cab_offset[2]) + 0.4
	if l.y > top - 0.1 or absf(l.x) > half + 0.4 or out_front:
		remove_collision_exception_with(home)
		home.remove_collision_exception_with(self)
		_clear = true
		return
	if freeze: return
	# the mounts and crossmember under it: it can't sink below where it sat while it's over the chassis
	if absf(l.x) < half and l.y < _home_y + 0.02:
		var up := home.global_basis.y
		var v_rel := linear_velocity - home.linear_velocity
		var dy := _home_y - l.y
		var f := mass * (9.81 + 600.0 * maxf(dy, 0.0)) - mass * 40.0 * v_rel.dot(up)
		apply_central_force(up * maxf(f, 0.0))
		# scraping across the mounts: it drags rather than skates
		var lat := v_rel - up * v_rel.dot(up)
		apply_central_force(-lat * mass * 2.5)
