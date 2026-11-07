class_name RemotePlayer
extends CharacterBody3D
## Another player on the LAN, as seen on this machine: their body (one of the survivor models), walking and looking
## where their snapshots say, their gun in their hands, their name over their head. Shoot them and their machine
## takes the damage; zombies here go for them as they go for you. When they drive, the car they're in follows them.

var peer_id := 0
var display_name := ""
var body_key := "player"
var net
var rig: Rig
var shape: CollisionShape3D
var label: Label3D
var gun_node: Gun
var gun_key := ""
var dead := false
var crouching := false
var vehicle = null            # the car they're driving here (for the zombies: "in a car")
var hp := 100.0
var yaw := 0.0
var pitch := 0.0
var _target := Vector3.ZERO
var _body_yaw := 0.0
var _vel := Vector3.ZERO
var _have := false
var _car_target := Transform3D()
var _car_vel := Vector3.ZERO
var _spawned_car: Car = null  # a car we had to make because there wasn't one like it here

func _ready() -> void:
	add_to_group("players")
	collision_layer = NPC.LAYER            # bullets find them like any other body
	collision_mask = 0
	shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.78
	shape.shape = cap
	shape.position.y = 0.89
	add_child(shape)
	rig = Rig.new()
	add_child(rig)
	rig.load_model(body_key if ResourceLoader.exists(Rig.path_of(body_key)) else "player")
	label = Label3D.new()
	label.text = display_name
	label.position.y = 2.15
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.outline_size = 12
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0009
	label.modulate = Color(0.75, 0.95, 1.0)
	add_child(label)

func apply_state(pos: Vector3, body_yaw: float, y: float, p: float, crouch: bool, is_dead: bool, vel: Vector3,
		gk: String, ads: float, car_info: Array, h: float) -> void:
	_target = pos
	_body_yaw = body_yaw
	yaw = y
	pitch = p
	crouching = crouch
	_vel = vel
	hp = h
	if not _have:
		global_position = pos
		_have = true
	if is_dead != dead:
		dead = is_dead
		visible = not dead
		shape.disabled = dead
	if gk != gun_key:
		_set_gun(gk)
	# driving
	if car_info.size() >= 9:
		var c := _find_car(str(car_info[0]), car_info[1], car_info[8])
		if c != vehicle:
			release_car()
			vehicle = c
			if c:
				c.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				c.freeze = true
				c.set_meta("net_driven", peer_id)
		if vehicle:
			_car_target = car_info[2]
			_car_vel = car_info[3]
			vehicle.steer_now = float(car_info[5])
			vehicle.rpm = float(car_info[6])
			vehicle.throttle = float(car_info[7])
			vehicle.running = true
	elif vehicle:
		release_car()
	visible = not dead and vehicle == null
	shape.disabled = dead or vehicle != null

## The car they've got: one here with the same name that started near the same spot, or else one made to match
func _find_car(nm: String, home: Vector3, design: Dictionary) -> Car:
	if vehicle and is_instance_valid(vehicle) and str(vehicle.name) == nm:
		return vehicle
	var best: Car = null
	var bd := 40.0
	for v in get_tree().get_nodes_in_group("vehicles"):
		if not (v is Car) or v.driver != null:
			continue
		if v.has_meta("net_driven") and int(v.get_meta("net_driven")) != peer_id:
			continue
		var h: Vector3 = v.home_pos if "home_pos" in v else v.global_position
		var d := h.distance_to(home)
		if str(v.name) == nm and d < bd * 3.0:
			return v
		if d < bd and v.design.get("cab", "") == design.get("cab", "?"):
			bd = d
			best = v
	if best:
		return best
	if _spawned_car == null or not is_instance_valid(_spawned_car):
		_spawned_car = net.main.spawn_vehicle(str(design.get("cab", "vjwagon")), home + Vector3.UP, 0.0, design)
	return _spawned_car

func release_car() -> void:
	if vehicle and is_instance_valid(vehicle):
		vehicle.freeze = false
		vehicle.running = false
		vehicle.throttle = 0.0
		vehicle.remove_meta("net_driven")
		vehicle.linear_velocity = _car_vel
	vehicle = null

func _set_gun(gk: String) -> void:
	gun_key = gk
	if gun_node:
		gun_node.queue_free()
		gun_node = null
	if gk == "" or not Gun.DEFS.has(gk):
		rig.mods.ik.clear()
		return
	gun_node = Gun.new()
	add_child(gun_node)
	gun_node.setup(gk, self)
	gun_node.set_process(false)
	gun_node.top_level = true

func _physics_process(dt: float) -> void:
	if not _have:
		return
	if vehicle and is_instance_valid(vehicle):
		# the car follows their snapshots: glide to where it should be, a touch ahead by its speed
		var xf: Transform3D = vehicle.global_transform
		var want := Transform3D(_car_target.basis, _car_target.origin + _car_vel * 0.05)
		vehicle.global_transform = Transform3D(xf.basis.slerp(want.basis.orthonormalized(), clamp(dt * 12.0, 0.0, 1.0)).orthonormalized(),
			xf.origin.lerp(want.origin, clamp(dt * 12.0, 0.0, 1.0)))
		global_position = vehicle.global_position
		return
	# walk to where they are (snap if they've jumped a long way: respawned, got out of a car)
	if global_position.distance_to(_target) > 6.0:
		global_position = _target
	else:
		global_position = global_position.lerp(_target + _vel * 0.05, clamp(dt * 10.0, 0.0, 1.0))
	velocity = _vel
	rotation.y = lerp_angle(rotation.y, _body_yaw, clamp(dt * 10.0, 0.0, 1.0))
	rig.mods.look_yaw = clamp(wrapf(yaw - _body_yaw, -PI, PI), -1.3, 1.3)
	rig.mods.look_pitch = clamp(pitch, -1.1, 1.0) * 0.85
	var hv := Vector3(_vel.x, 0, _vel.z)
	var lv := Basis(Vector3.UP, _body_yaw).inverse() * hv
	var set_name := "unarmed"
	if gun_node and not gun_node.def.get("pistol", false): set_name = "rifle"
	rig.locomote(set_name, hv.length(), crouching, atan2(-lv.x, -lv.z))
	if gun_node:
		var eye := rig.head_position() + Basis(Vector3.UP, yaw) * Vector3(0, 0.07, -0.08)
		var look := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		gun_node.global_transform = WeaponHold.place(gun_node, Transform3D(look, eye), {"ads": 0.0, "low": 0.0, "reload": 0.0, "cycle": 0.0, "kick": 0.0, "bob": Vector3.ZERO})
		WeaponHold.hands(rig, gun_node, global_transform.basis)

func show_shot(origin: Vector3, dir: Vector3, gk: String) -> void:
	if gun_node == null or gun_key != gk:
		_set_gun(gk)
	if gun_node:
		gun_node.audio.stream = Gun.sfx(gun_node.def.sound)
		gun_node.audio.pitch_scale = randf_range(0.94, 1.06)
		gun_node.audio.play()
		gun_node.flash.light_energy = 6.0
		gun_node.flash_mesh.visible = true
		get_tree().create_timer(0.06).timeout.connect(func(): if is_instance_valid(gun_node): gun_node.flash_mesh.visible = false)

## Hit by your bullets: their machine does the damage
func take_hit(parts: Dictionary, dir: Vector3, point: Vector3, force: float, attacker: Node) -> void:
	var total := 0.0
	for k in parts: total += float(parts[k])
	if net: net.hit_player(self, total, dir, point)

## Bitten or shot by an NPC that thinks on this machine (the host)
func take_damage(amount: float, from: Vector3, impulse := Vector3.ZERO, point := Vector3.ZERO) -> void:
	if net: net.npc_hurt_player(self, amount, from)
