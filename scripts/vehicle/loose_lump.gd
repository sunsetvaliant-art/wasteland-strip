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
var _seat_off := 0.0             # that, against where Car says an engine sits (so it sits the same in another car)

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
		_seat_off = _home_y - home.engine_home().y

## Something's pulling: off its mounts
func wake() -> void:
	if not freeze: return
	freeze = false
	sleeping = false

## 0.2.74: an engine going back in. Coming down from above it caught on the car's body collision (only from under did
## it get in), so any car with an open, empty bay (bonnet off or no cab, no engine in it) lets it through while it's
## over that bay, and the mounts catch it at the height an engine sits, ready to bolt in.
var bay: Car = null              # the car whose bay it's in (or over) right now; no collision with that car
var _scan := 0

func _bay_open(c: Car) -> bool:
	if c == home and not _clear: return true
	if str(c.design.get("kit", {}).get("block", "")) != "": return false
	return bool(c.design.get("no_cab", false)) or (c.bonnet_pivot != null and bool(c.design.get("bonnet_off", false)))

func _over_bay(c: Car) -> bool:
	if c.parts == null: return false
	var l := c.to_local(global_position)
	var h := c.engine_home()
	var half := float(c.def.ext[2]) * 0.5
	var top := float(c.def.min[1]) + float(c.def.ext[1]) + float(c.design.cab_offset[1])
	if c == home and not _clear:
		return true
	return absf(l.x) < half + 0.1 and absf(l.z - h.z) < 1.2 and l.y > h.y - 0.8 and l.y < top + 1.8

func _seat_y(c: Car) -> float:
	return _home_y if c == home else c.engine_home().y + _seat_off

func _set_bay(c: Car) -> void:
	if c == bay: return
	if bay and is_instance_valid(bay):
		remove_collision_exception_with(bay)
		bay.remove_collision_exception_with(self)
	bay = c
	if bay:
		add_collision_exception_with(bay)
		bay.add_collision_exception_with(self)

func _physics_process(_dt: float) -> void:
	if home and not is_instance_valid(home):
		home = null
		_clear = true
	if home and not _clear:
		var l := home.to_local(global_position)
		# clear of the bay: up over the body, or well off to one side or out the front
		var top := float(home.def.min[1]) + float(home.def.ext[1]) + float(home.design.cab_offset[1])
		var half := float(home.def.ext[2]) * 0.5
		var out_front: bool = l.z > float(home.def.min[0]) + float(home.def.ext[0]) + float(home.design.cab_offset[2]) + 0.4
		if l.y > top - 0.1 or absf(l.x) > half + 0.4 or out_front:
			remove_collision_exception_with(home)
			home.remove_collision_exception_with(self)
			_clear = true
			bay = null
		else:
			bay = home
	if freeze: return
	_scan -= 1
	if _scan <= 0 and (_clear or home == null):
		_scan = 6
		var found: Car = null
		for n in get_tree().get_nodes_in_group("vehicles"):
			var c := n as Car
			if c == null or not is_instance_valid(c): continue
			if c.global_position.distance_squared_to(global_position) > 64.0: continue
			if _bay_open(c) and _over_bay(c):
				found = c
				break
		_set_bay(found)
	if bay == null or not is_instance_valid(bay): return
	# the mounts and crossmember under it: it can't sink below where it sits while it's over the chassis
	var lb := bay.to_local(global_position)
	var halfb := float(bay.def.ext[2]) * 0.5
	var sy := _seat_y(bay)
	if absf(lb.x) < halfb and lb.y < sy + 0.02:
		var up := bay.global_basis.y
		var v_rel := linear_velocity - bay.linear_velocity
		var dy := sy - lb.y
		var f := mass * (9.81 + 600.0 * maxf(dy, 0.0)) - mass * 40.0 * v_rel.dot(up)
		apply_central_force(up * maxf(f, 0.0))
		# scraping across the mounts: it drags rather than skates
		var lat := v_rel - up * v_rel.dot(up)
		apply_central_force(-lat * mass * 2.5)
