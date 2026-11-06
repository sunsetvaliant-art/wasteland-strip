class_name Player
extends CharacterBody3D
## On foot: over-the-shoulder or first person (V). Mouse look, sprint, crouch, jump. F gets into a vehicle close by.

signal camera_changed(cam: Camera3D)
signal vehicle_changed(v)

const WALK := 1.6
const RUN := 5.8
const CROUCH := 1.1
const JUMP := 4.6
var SENS := 0.0022

var yaw := 0.0
var pitch := -0.1
var first_person := false
var crouching := false
var vehicle = null
var cars: Array = []
var active := true      # false while the Forge Oracle has the controls

var head: Node3D
var arm: SpringArm3D
var cam_tp: Camera3D
var cam_fp: Camera3D
var body_mesh: Node3D
var rig: Rig
var shape: CollisionShape3D
# health and guns
var hp := 100.0
var dead := false
var hurt_flash := 0.0
var guns: Array = []
var gun_i := 0
var holstered := false
var ads := 0.0                         # 0 hip .. 1 down the sights
var recoil := 0.0                      # camera kick still to recover (rad)
var kick := 0.0                        # gun pushed back into the shoulder (m)
var sway_t := 0.0
var aim_point := Vector3.ZERO
var respawn_t := 0.0
var ragdoll: Ragdoll
signal hurt(amount: float)
signal died

func _ready() -> void:
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4
	shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.78
	shape.shape = cap
	shape.position.y = 0.89
	add_child(shape)
	# your body: the Meshy survivor on the Mixamo skeleton, seen in shoulder view and when you look down in first person
	rig = Rig.new()
	add_child(rig)
	rig.load_model("player")
	body_mesh = rig
	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	arm = SpringArm3D.new()
	arm.spring_length = 2.4
	arm.margin = 0.2
	arm.position = Vector3(0.55, 0.0, 0)
	arm.add_excluded_object(get_rid())
	head.add_child(arm)
	cam_tp = Camera3D.new()
	cam_tp.add_to_group("cameras")
	cam_tp.fov = 68
	cam_tp.far = 30000
	cam_tp.near = 0.05
	arm.add_child(cam_tp)
	cam_fp = Camera3D.new()
	cam_fp.add_to_group("cameras")
	cam_fp.fov = 74
	cam_fp.far = 30000
	cam_fp.near = 0.03
	cam_fp.position = Vector3(0, 0.04, -0.12)
	head.add_child(cam_fp)
	cam_tp.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func active_camera() -> Camera3D:
	if vehicle:
		return vehicle.active_camera()
	return cam_fp if first_person else cam_tp

func _unhandled_input(e: InputEvent) -> void:
	if not active or get_tree().paused:
		return
	if vehicle:
		if e.is_action_pressed("interact"):
			_get_out()
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = SENS * float(Settings.get_v("motion_sensitivity"))
		yaw -= e.relative.x * sens
		pitch = clamp(pitch - e.relative.y * sens * (-1.0 if Settings.get_v("invert_y") else 1.0), -1.45, 1.35)
	if e.is_action_pressed("camera"):
		first_person = not first_person
		_apply_camera()
	if e.is_action_pressed("crouch"):
		crouching = not crouching
	if e.is_action_pressed("interact"):
		if not _try_pickup():
			_try_get_in()
	if e.is_action_pressed("reload") and gun():
		gun().start_reload()
	if e.is_action_pressed("holster"):
		holstered = not holstered
	if e.is_action_pressed("weapon_next"): _select(gun_i + 1)
	if e.is_action_pressed("weapon_prev"): _select(gun_i - 1)
	for i in 6:
		if e.is_action_pressed("slot_%d" % (i + 1)) and i < guns.size():
			_select(i)

func _apply_camera() -> void:
	var c := active_camera()
	c.current = true
	body_mesh.visible = vehicle == null
	rig.hide_head(first_person)
	camera_changed.emit(c)

func _physics_process(dt: float) -> void:
	hurt_flash = max(hurt_flash - dt * 1.5, 0.0)
	if dead:
		respawn_t -= dt
		if respawn_t <= 0.0:
			_respawn()
		return
	if not active:
		return
	if vehicle:
		global_position = vehicle.seat_position()
		return
	if hp < 100.0:
		hp = min(hp + dt * (2.0 if Settings.creative() else 0.4), 100.0)
	rotation.y = yaw
	head.rotation.x = pitch
	var target_h := 1.1 if crouching else 1.62
	head.position.y = lerp(head.position.y, target_h, 10 * dt)
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var speed := CROUCH if crouching else (RUN if Input.is_action_pressed("sprint") else WALK * 2.0)
	if ads > 0.5: speed = min(speed, WALK * 1.3)
	_noise_t -= dt
	if _noise_t <= 0.0 and velocity.length() > 0.5:
		_noise_t = 0.5
		Hearing.emit(get_tree(), global_position, 14.0 if speed >= RUN else (6.0 if not crouching else 1.5), "steps", self)
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y)).normalized()
	var accel := 10.0 if is_on_floor() else 2.0
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * speed * dt)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * speed * dt)
	if not is_on_floor():
		velocity.y -= 9.8 * dt
	elif Input.is_action_just_pressed("jump") and not crouching:
		velocity.y = JUMP
	move_and_slide()
	rig.set_motion(Vector2(velocity.x, velocity.z).length())
	if global_position.y < -50:
		global_position.y = 50

var _noise_t := 0.0
func _process(dt: float) -> void:
	if first_person and vehicle == null and rig and not dead:
		# eyes: just in front of the head bone, so looking down shows your own body
		cam_fp.global_position = rig.head_position() + global_transform.basis * Vector3(0, 0.07, -0.11)
	_hold_gun(dt)

# ---------------------------------------------------------------- guns
func gun() -> Gun:
	return guns[gun_i] if gun_i < guns.size() else null

func give_gun(k: String, rounds := -1) -> Gun:
	for g in guns:
		if g.key == k:
			g.reserve += rounds if rounds > 0 else int(g.def.mag) * 3
			return g
	var g := Gun.new()
	add_child(g)
	g.setup(k, self)
	g.excludes = [get_rid()]
	g.reserve = rounds if rounds >= 0 else int(g.def.mag) * 4
	g.visible = false
	guns.append(g)
	if guns.size() == 1:
		_select(0)
	return g

func _select(i: int) -> void:
	if guns.is_empty():
		return
	gun_i = posmod(i, guns.size())
	holstered = false
	for j in guns.size():
		guns[j].visible = j == gun_i

## Where the gun sits and points this frame, and what the hands do about it
func _hold_gun(dt: float) -> void:
	var g := gun()
	var show := g != null and vehicle == null and active and not dead and not holstered
	for x in guns:
		x.visible = show and x == g
	var ik: Dictionary = rig.mods.ik
	if not show:
		ik.clear()
		rig.mods.lean_pitch = 0.0
		return
	var sprinting := Input.is_action_pressed("sprint") and velocity.length() > 3.0 and not crouching
	var aiming := Input.is_action_pressed("aim") and not sprinting and get_tree().paused == false
	ads = move_toward(ads, 1.0 if aiming else 0.0, dt * 6.0)
	recoil = move_toward(recoil, 0.0, dt * (0.6 + recoil * 8.0))
	kick = move_toward(kick, 0.0, dt * 0.9)
	sway_t += dt * (1.0 + velocity.length() * 0.9)
	var pistol: bool = g.def.get("pistol", false)
	var half: float = float(g.def.len) * 0.5
	# the eye and the look direction
	var cam := active_camera()
	var eye: Vector3 = cam_fp.global_position if first_person else head.global_position + global_transform.basis * Vector3(0.0, -0.02, 0.0)
	var look := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch + recoil)
	# in shoulder view, aim where the crosshair is
	if not first_person:
		var c_from := cam.global_position
		var c_dir := -cam.global_transform.basis.z
		var q := PhysicsRayQueryParameters3D.create(c_from, c_from + c_dir * 600.0, Gun.MASK, [get_rid()])
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		aim_point = h.position if h else c_from + c_dir * 600.0
		var to := (aim_point - eye).normalized()
		look = Basis.looking_at(to, Vector3.UP)
	else:
		aim_point = eye - look.z * 100.0
	# shoulder (hip) and sights positions, in eye space: x right, y up, z back
	# butt in the shoulder pocket, a bit behind the eye; down the sights the eye sits on the sight line
	var sh: float = float(g.def.get("sight", 0.05))
	var hip := Vector3(0.16, -0.2, 0.22 - half) if not pistol else Vector3(0.15, -0.19, -0.4)
	var sights := Vector3(0.0, -sh, 0.11 - half) if not pistol else Vector3(0.0, -sh, -0.46)
	var low := Vector3(0.2, -0.38, -0.1 - half * 0.6)
	var p := hip.lerp(sights, ads)
	if sprinting: p = low
	var bob := Vector3(sin(sway_t * 1.1) * 0.006, abs(sin(sway_t * 1.1)) * 0.008, 0) * (1.0 - ads * 0.8)
	var rl := g.reload_phase()
	var cyc: float = g.cycling / 0.9 if g.cycling > 0.0 else 0.0
	p += bob + Vector3(0, -0.1 * sin(rl * PI) - 0.03 * sin(cyc * PI), kick)
	var gb := look * Basis(Vector3.FORWARD, 0.7 * sin(rl * PI) + 0.25 * sin(cyc * PI)) * Basis(Vector3.RIGHT, -0.4 * sin(rl * PI))
	if sprinting: gb = look * Basis(Vector3.UP, 0.6) * Basis(Vector3.RIGHT, -0.5)
	g.global_transform = Transform3D(gb, eye + look * p)
	# hands on it: right hand on the wrist / grip, left hand on the fore-end (pistol: left cups the right).
	# The left hand goes as far up the fore-end as the arm actually reaches.
	if not pistol:
		var want_l := Vector3(-0.035, float(g.def.drop_y) * 0.5 - 0.085, half - float(g.def.fore) * float(g.def.len) + 0.03)
		var back := Vector3(-0.035, float(g.def.drop_y) * 0.5 - 0.085, g.grip_r.position.z - 0.12)
		var shl := rig.bone_pos("LeftArm")
		var reach := (shl.distance_to(rig.bone_pos("LeftForeArm")) + rig.bone_pos("LeftForeArm").distance_to(rig.bone_pos("LeftHand"))) * 0.96
		var lo := 0.0
		var hi := 1.0
		if g.to_global(want_l).distance_to(shl) > reach:
			for _k in 10:
				var mid := (lo + hi) * 0.5
				if g.to_global(want_l.lerp(back, mid)).distance_to(shl) > reach: lo = mid
				else: hi = mid
			g.grip_l.position = want_l.lerp(back, hi)
		else:
			g.grip_l.position = want_l
	var right := global_transform.basis.x
	ik["R"] = {"target": g.grip_r, "pole": (-global_transform.basis.y + right * 0.6 + global_transform.basis.z * 0.3), "w": 1.0, "rot": null}
	ik["L"] = {"target": g.grip_l if not pistol else g.grip_r, "pole": (-global_transform.basis.y - right * 0.8), "w": 1.0, "rot": null}
	rig.mods.lean_pitch = -pitch * 0.5 if first_person else -pitch * 0.4
	# pulling the trigger
	var want := Input.is_action_pressed("fire") if g.def.action == "semi" or g.def.action == "revolver" else Input.is_action_just_pressed("fire")
	if g.def.action == "semi": want = Input.is_action_just_pressed("fire")
	if want and not sprinting and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		var origin := eye
		var dir := (aim_point - eye).normalized()
		var spread := (0.012 if not pistol else 0.008) * (1.0 - ads) + velocity.length() * 0.003 + (0.0 if is_on_floor() else 0.03)
		if crouching: spread *= 0.7
		if g.fire(origin, dir, spread):
			recoil += float(g.def.recoil) * randf_range(0.8, 1.2)
			yaw += randf_range(-0.3, 0.3) * float(g.def.recoil) * 0.4
			kick = float(g.def.kick)
	if g.ammo <= 0 and g.reserve > 0 and g.reloading <= 0.0 and Input.is_action_just_pressed("fire"):
		g.start_reload()

## F near a dropped gun: take it (or its ammo)
func _try_pickup() -> bool:
	for pk in get_tree().get_nodes_in_group("pickups"):
		if (pk as Node3D).global_position.distance_to(global_position + Vector3(0, 0.5, 0)) < 2.2:
			give_gun(pk.get_meta("gun"), int(pk.get_meta("ammo", 10)))
			pk.queue_free()
			return true
	return false

# ---------------------------------------------------------------- getting hurt
## Bullets (Gun) call this with damage per body part
func take_hit(parts: Dictionary, dir: Vector3, point: Vector3, force: float, attacker: Node) -> void:
	var total := 0.0
	for k in parts:
		total += float(parts[k]) * (0.55 if k != "head" else 0.8)
	take_damage(total, point - dir, dir * force, point)

func take_damage(amount: float, from: Vector3, impulse := Vector3.ZERO, point := Vector3.ZERO) -> void:
	if dead or Settings.get_v("god_mode"):
		return
	if vehicle:
		amount *= 0.5
	hp -= amount
	hurt_flash = clamp(hurt_flash + amount / 40.0, 0.0, 1.0)
	hurt.emit(amount)
	if hp <= 0.0:
		_die(impulse, point)

func _die(impulse: Vector3, point: Vector3) -> void:
	if vehicle:
		_get_out()
	dead = true
	hp = 0.0
	respawn_t = 5.0
	shape.disabled = true
	rig.mods.ik.clear()
	rig.frozen = true
	rig.hide_head(false)
	ragdoll = Ragdoll.new()
	get_parent().add_child(ragdoll)
	ragdoll.owner_actor = self
	ragdoll.build(rig, velocity)
	rig.mods.ragdoll = ragdoll
	if impulse != Vector3.ZERO:
		ragdoll.push(rig.part_at(point), impulse * 8.0, point)
	for g in guns: g.visible = false
	# watch yourself drop from the shoulder camera
	first_person = false
	cam_tp.current = true
	camera_changed.emit(cam_tp)
	died.emit()

func _respawn() -> void:
	dead = false
	hp = 100.0
	if ragdoll and is_instance_valid(ragdoll):
		ragdoll.queue_free()
	ragdoll = null
	rig.mods.ragdoll = null
	rig.frozen = false
	shape.disabled = false
	var main = get_tree().current_scene
	var spot: Vector3 = main.PUB if main and "PUB" in main else Vector3.ZERO
	for m in get_tree().get_nodes_in_group("forge_markers"):
		if m.has_meta("forge") and m.get_meta("forge").key == "player_spawn":
			spot = m.global_position
	var gy: float = main.height_at(spot.x, spot.z) if main and main.has_method("height_at") else spot.y
	global_position = Vector3(spot.x, gy + 1.0, spot.z)
	velocity = Vector3.ZERO
	_apply_camera()

func _try_get_in() -> void:
	for c in get_tree().get_nodes_in_group("vehicles"):
		if c.global_position.distance_to(global_position) < 4.0 and c.driver == null:
			vehicle = c
			c.driver = self
			add_collision_exception_with(c)
			c.add_collision_exception_with(self)
			shape.disabled = true
			body_mesh.visible = false
			c.active_camera().current = true
			camera_changed.emit(c.active_camera())
			vehicle_changed.emit(c)
			return

func _get_out() -> void:
	var c = vehicle
	c.driver = null
	vehicle = null
	# step out the driver's side if it's clear, else the other side, else over the roof
	var spot: Vector3 = c.global_position + Vector3(0, 2.4, 0)
	for side in [-1.0, 1.0]:
		var p: Vector3 = c.global_transform * Vector3(side * 1.55, 0.0, 0.05)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape.shape
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.95, 0))
		q.exclude = [get_rid(), c.get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			spot = p
			break
	global_position = spot
	velocity = Vector3.ZERO
	get_tree().create_timer(0.6).timeout.connect(func():
		remove_collision_exception_with(c)
		c.remove_collision_exception_with(self))
	yaw = c.rotation.y
	shape.disabled = false
	_apply_camera()
	vehicle_changed.emit(null)
