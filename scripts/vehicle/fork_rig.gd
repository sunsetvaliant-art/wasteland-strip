class_name ForkRig
extends Node3D
## The forklift's mast and forks (0.2.66): the mast tilts on its foot, the carriage runs up it (the inner channel
## rises through the top half of the lift), the forks side-shift. The tines and the backrest are collision boxes
## on the forklift itself, moved every physics step, so whatever sits on them is lifted by contact: slide them in
## under a loose body (it sits on its mounts with a gap underneath) and pick it up.
## Keys while driving it: R / G (or up / down arrow) lift and lower, T / Y (or left / right arrow) tilt back and
## forward, comma / full stop side-shift. They ease in: tap for a few millimetres, hold and it speeds up. Hold Alt for
## a quarter speed. Lifting needs the engine running; it lowers on its own weight.
const LIFT_V := 0.32        # m/s flat out
const TILT_V := 0.14        # rad/s
const SIDE_V := 0.12        # m/s
const SIDE_MAX := 0.1

var car
var cfg: Dictionary
var pivot: Node3D
var inner: Node3D
var carriage: Node3D
var lift := 0.0
var tilt := 0.0             # + back (towards the cab)
var side := 0.0
var _hold := {"lift": 0.0, "tilt": 0.0, "side": 0.0}     # how long each control's been held (eases the speed in)
var shapes: Array = []      # [CollisionShape3D, centre (pivot space), size]
var _told := false
var cmd := Vector3.ZERO     # lift / tilt / side-shift from a script (tests, a future AI) when no player's driving

func setup(c) -> void:
	car = c
	cfg = car.def.forks
	var pv: Array = cfg.pivot
	pivot = Node3D.new(); pivot.name = "Mast"
	pivot.position = Vector3(float(pv[0]), float(pv[1]), float(pv[2]))
	add_child(pivot)
	pivot.add_child((load("res://assets/vehicles/parts/fl_mast.glb") as PackedScene).instantiate())
	inner = Node3D.new(); inner.name = "Inner"
	pivot.add_child(inner)
	var im: Node3D = (load("res://assets/vehicles/parts/fl_inner.glb") as PackedScene).instantiate()
	im.scale = Vector3(0.92, 1.0, 0.92)          # nests inside the outer channel
	inner.add_child(im)
	carriage = Node3D.new(); carriage.name = "Carriage"
	pivot.add_child(carriage)
	carriage.add_child((load("res://assets/vehicles/parts/fl_carriage.glb") as PackedScene).instantiate())
	for t in cfg.tines + [cfg.back]:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(float(t[1][0]), float(t[1][1]), float(t[1][2]))
		cs.shape = bx
		cs.name = "Fork"
		car.add_child(cs)
		shapes.append([cs, Vector3(float(t[0][0]), float(t[0][1]), float(t[0][2]))])
	_pose()

func _pose() -> void:
	pivot.basis = Basis(Vector3.RIGHT, -tilt)
	var L := float(cfg.lift)
	inner.position = Vector3(0, maxf(0.0, lift - L * 0.5), 0)
	carriage.position = Vector3(side, lift, 0)
	var px := pivot.transform * Transform3D(Basis.IDENTITY, carriage.position)
	for s in shapes:
		(s[0] as CollisionShape3D).transform = Transform3D(px.basis, px * (s[1] as Vector3))

func _ramp(key: String, on: bool, dt: float) -> float:
	_hold[key] = (float(_hold[key]) + dt) if on else 0.0
	# 15 % of full speed for the first moment, all of it after a second held
	return lerpf(0.15, 1.0, clampf((float(_hold[key]) - 0.15) / 0.9, 0.0, 1.0)) if on else 0.0

func _physics_process(dt: float) -> void:
	if car == null: return
	var mine: bool = car.driver != null and car.driver is Player and not get_tree().paused
	if mine and not _told:
		_told = true
		car.driver._toast("Forks: up/down arrows lift, left/right tilt, comma/full stop side-shift, hold Alt for slow")
	if not mine: _told = car.driver != null
	var up := 0.0; var tl := 0.0; var sd := 0.0
	if mine:
		var k := func(a: int, b := 0) -> bool: return Input.is_physical_key_pressed(a) or (b != 0 and Input.is_physical_key_pressed(b))
		up = (1.0 if k.call(KEY_R, KEY_UP) else 0.0) - (1.0 if k.call(KEY_G, KEY_DOWN) else 0.0)
		tl = (1.0 if k.call(KEY_T, KEY_LEFT) else 0.0) - (1.0 if k.call(KEY_Y, KEY_RIGHT) else 0.0)
		sd = (1.0 if k.call(KEY_PERIOD) else 0.0) - (1.0 if k.call(KEY_COMMA) else 0.0)
	else:
		up = cmd.x; tl = cmd.y; sd = cmd.z
	var fine := 0.25 if (mine and Input.is_physical_key_pressed(KEY_ALT)) else 1.0
	up = clampf(up, -1.0, 1.0); tl = clampf(tl, -1.0, 1.0); sd = clampf(sd, -1.0, 1.0)
	if up > 0.0 and not car.running: up = 0.0          # the pump's driven off the engine
	var L := float(cfg.lift)
	var tr: Array = cfg.tilt
	lift = clampf(lift + up * LIFT_V * fine * _ramp("lift", up != 0.0, dt) * dt, 0.0, L)
	tilt = clampf(tilt + tl * TILT_V * fine * _ramp("tilt", tl != 0.0, dt) * dt, float(tr[0]), float(tr[1]))
	side = clampf(side + sd * SIDE_V * fine * _ramp("side", sd != 0.0, dt) * dt, -SIDE_MAX, SIDE_MAX)
	_pose()

## The tine tips' height above where the forklift stands (the HUD and tests read it)
func tine_height() -> float:
	return lift
