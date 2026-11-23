class_name LooseLump
extends RigidBody3D
## A heavy part unbolted where it sits (0.2.68: the engine). It stays put on its mounts (frozen) until a chain, a
## strap or a hand pulls it; then it comes free of the car it was in without catching on the car's own collision,
## until it's clear of the bay. "kit" holds what it is (the engine kit dictionary).

var home: Car = null             # the car it came out of: no collision with it while it's still in the bay
var kit: Dictionary = {}
var _clear := false

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

## Something's pulling: off its mounts
func wake() -> void:
	if not freeze: return
	if home and is_instance_valid(home):
		add_collision_exception_with(home)
		home.add_collision_exception_with(self)
	freeze = false
	sleeping = false

func _physics_process(_dt: float) -> void:
	if freeze or _clear or home == null: return
	if not is_instance_valid(home):
		_clear = true
		return
	# clear of the bay: up over the body, or well off to one side or out the front
	var l := home.to_local(global_position)
	var top := float(home.def.min[1]) + float(home.def.ext[1]) + float(home.design.cab_offset[1])
	var half := float(home.def.ext[2]) * 0.5
	if l.y > top - 0.1 or absf(l.x) > half + 0.4 or l.z > float(home.def.min[0]) + float(home.def.ext[0]) + float(home.design.cab_offset[2]) + 0.4:
		remove_collision_exception_with(home)
		home.remove_collision_exception_with(self)
		_clear = true
