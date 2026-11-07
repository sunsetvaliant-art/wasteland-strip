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
var body_yaw := 0.0                    # which way the body faces; the eyes (yaw) can be up to ~70° off it
var low_ready := 0.0
var scope_view: ScopeView
var respawn_t := 0.0
var ragdoll: Ragdoll
var inv: PlayerInv
var interact_hint := ""                # what F would do right now (the HUD shows it)
var interact_target: Node = null
var carried: RigidBody3D = null        # something picked up with the middle mouse button
var carry_dist := 1.5
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
	for mi in rig.model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = 4      # your own body: the scope camera doesn't see it
	body_mesh = rig
	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	arm = SpringArm3D.new()
	arm.spring_length = 2.4
	arm.margin = 0.2
	arm.position = Vector3(0.75, 0.12, 0)
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
	inv = PlayerInv.new()
	inv.name = "Inventory"
	add_child(inv)
	inv.setup(self)

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
		_interact()
	if e.is_action_pressed("inventory"):
		var ui = get_tree().current_scene.get("inv_ui")
		if ui: ui.toggle(null)
	if e.is_action_pressed("heal"):
		inv.quick_heal()
	if e.is_action_pressed("carry"):
		_carry_start()
	if e.is_action_released("carry"):
		_carry_drop(false)
	if e.is_action_pressed("aim") and carried:
		_carry_drop(true)
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("reload") and gun():
		gun().start_reload()
	if e.is_action_pressed("holster"):
		holstered = not holstered
	if e.is_action_pressed("weapon_next"): _select(gun_i + 1)
	if e.is_action_pressed("weapon_prev"): _select(gun_i - 1)
	for i in 2:
		if e.is_action_pressed("slot_%d" % (i + 1)):
			# 1 = primary, 2 = secondary
			var want = inv.equip.get("primary" if i == 0 else "secondary")
			for j in guns.size():
				if guns[j].get_meta("stack", null) == want: _select(j)

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
	_carry_tick(dt)
	if hp < 100.0:
		hp = min(hp + dt * (2.0 if Settings.creative() else 0.4), 100.0)
	# the body follows the eyes: straight away when moving or holding a gun up, otherwise only once you've
	# looked more than ~70° round (it shuffles round to keep up)
	var inp0 := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var diff := wrapf(yaw - body_yaw, -PI, PI)
	var limit := deg_to_rad(35.0 if armed() else 70.0)
	if inp0.length() > 0.1 or (armed() and (ads > 0.1 or Input.is_action_pressed("fire"))):
		body_yaw = lerp_angle(body_yaw, yaw, clamp(dt * 9.0, 0.0, 1.0))
	elif abs(diff) > limit:
		body_yaw = lerp_angle(body_yaw, yaw - sign(diff) * limit * 0.85, clamp(dt * 7.0, 0.0, 1.0))
		turning = 0.3
	turning = max(turning - dt, 0.0)
	rotation.y = body_yaw
	head.rotation = Vector3(pitch, wrapf(yaw - body_yaw, -PI, PI), 0.0)
	rig.mods.look_yaw = clamp(wrapf(yaw - body_yaw, -PI, PI), -1.3, 1.3)
	rig.mods.look_pitch = clamp(pitch, -1.1, 1.0) * 0.85
	var target_h := 1.1 if crouching else 1.62
	head.position.y = lerp(head.position.y, target_h, 10 * dt)
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var speed := CROUCH if crouching else (RUN if Input.is_action_pressed("sprint") else WALK * 2.0)
	if ads > 0.5: speed = min(speed, WALK * 1.3)
	_noise_t -= dt
	if _noise_t <= 0.0 and velocity.length() > 0.5:
		_noise_t = 0.5
		Hearing.emit(get_tree(), global_position, 14.0 if speed >= RUN else (6.0 if not crouching else 1.5), "steps", self)
	var dir := (Basis(Vector3.UP, yaw) * Vector3(inp.x, 0, inp.y)).normalized()
	var accel := 10.0 if is_on_floor() else 2.0
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * speed * dt)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * speed * dt)
	if not is_on_floor():
		velocity.y -= 9.8 * dt
	elif Input.is_action_just_pressed("jump") and not crouching:
		velocity.y = JUMP
	move_and_slide()
	# legs: which clip set, how fast, and which way we're going relative to the body
	var hv := Vector3(velocity.x, 0, velocity.z)
	var lv := Basis(Vector3.UP, body_yaw).inverse() * hv
	var ang := atan2(-lv.x, -lv.z)
	var spd := hv.length()
	if turning > 0.0 and spd < 0.2: spd = 0.6                 # shuffle the feet round
	var set_name := "unarmed"
	if armed() and not gun().def.get("pistol", false): set_name = "rifle"
	rig.locomote(set_name, spd, crouching, ang)
	# off the ground for more than a moment (a jump, a drop): legs up instead of walking on air
	air_t = 0.0 if is_on_floor() else air_t + dt
	rig.mods.air = move_toward(rig.mods.air, 1.0 if air_t > 0.12 else 0.0, dt * (5.0 if air_t > 0.12 else 9.0))
	if global_position.y < -50:
		global_position.y = 50

var _noise_t := 0.0
var turning := 0.0
var air_t := 0.0
func _process(dt: float) -> void:
	if first_person and vehicle == null and rig and not dead:
		# eyes: just in front of the head bone, so looking down shows your own body
		cam_fp.global_position = rig.head_position() + global_transform.basis * Vector3(0, 0.07, -0.11)
	inv.tick(dt)
	_hold_gun(dt)
	_update_interact()

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

## Is a gun out and in the hands?
func armed() -> bool:
	return gun() != null and vehicle == null and active and not dead and not holstered and carried == null and inv.using.is_empty()

## Where the gun sits and points this frame, and what the hands do about it
func _hold_gun(dt: float) -> void:
	var g := gun()
	var show := armed()
	for x in guns:
		x.visible = show and x == g
	var ik: Dictionary = rig.mods.ik
	if not show:
		ik.clear()
		return
	var sprinting := Input.is_action_pressed("sprint") and velocity.length() > 3.0 and not crouching
	var aiming := Input.is_action_pressed("aim") and not sprinting and not get_tree().paused
	ads = move_toward(ads, 1.0 if aiming else 0.0, dt * 6.0)
	low_ready = move_toward(low_ready, 1.0 if sprinting else 0.0, dt * 5.0)
	recoil = move_toward(recoil, 0.0, dt * (0.6 + recoil * 8.0))
	kick = move_toward(kick, 0.0, dt * 0.9)
	sway_t += dt * (1.0 + velocity.length() * 0.9)
	var pistol: bool = g.def.get("pistol", false)
	# the eye and where it's looking
	var cam := active_camera()
	var eye_pos: Vector3 = cam_fp.global_position if first_person else rig.head_position() + Basis(Vector3.UP, yaw) * Vector3(0, 0.07, -0.08)
	var look := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch + recoil)
	if not first_person:
		# shoulder view: the gun points at whatever's under the crosshair
		var c_from := cam.global_position
		var c_dir := -cam.global_transform.basis.z
		var q := PhysicsRayQueryParameters3D.create(c_from, c_from + c_dir * 600.0, Gun.MASK, [get_rid()])
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		aim_point = h.position if h else c_from + c_dir * 600.0
		var to := (aim_point - eye_pos).normalized()
		if to.length() > 0.5:
			look = Basis.looking_at(to, Vector3.UP)
	else:
		aim_point = eye_pos - look.z * 100.0
	var bob := Vector3(sin(sway_t * 1.1) * 0.006, abs(sin(sway_t * 1.1)) * 0.008, 0) * (1.0 - ads * 0.8)
	var cyc: float = g.cycling / 0.9 if g.cycling > 0.0 else 0.0
	g.global_transform = WeaponHold.place(g, Transform3D(look, eye_pos), {"ads": ads, "low": low_ready, "reload": g.reload_phase(), "cycle": cyc, "kick": kick, "bob": bob})
	WeaponHold.hands(rig, g, global_transform.basis)
	# scope: the magnified window while aiming down a scoped rifle
	if scope_view:
		scope_view.set_active(ads > 0.85 and g.def.get("scope", 0.0) > 0.0, g, look, eye_pos)
	# pulling the trigger
	var auto: bool = g.def.action in ["semi", "revolver"]
	var want := Input.is_action_just_pressed("fire")
	if want and low_ready < 0.3 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		var origin := eye_pos
		var dir := (aim_point - eye_pos).normalized()
		var spread := (0.012 if not pistol else 0.008) * (1.0 - ads) + velocity.length() * 0.003 + (0.0 if is_on_floor() else 0.03)
		if crouching: spread *= 0.7
		if g.fire(origin, dir, spread):
			var m = get_tree().current_scene
			if m and "net" in m and m.net: m.net.shot(origin, dir, g.key)
			recoil += float(g.def.recoil) * randf_range(0.8, 1.2) * (0.6 if crouching else 1.0)
			yaw += randf_range(-0.3, 0.3) * float(g.def.recoil) * 0.4
			kick = float(g.def.kick)
	if g.ammo <= 0 and g.reserve > 0 and g.reloading <= 0.0 and Input.is_action_just_pressed("fire"):
		g.start_reload()

## What's in front of you that F does something with: a box to open, something to pick up
func _look_target() -> Node:
	var cam := active_camera()
	if cam == null: return null
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var reach := 3.2 if first_person else 5.6           # the shoulder camera sits back behind you
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1 | (1 << 2) | (1 << 3) | (1 << 4), [get_rid()])
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty(): return null
	if (h.position as Vector3).distance_to(global_position + Vector3(0, 1.0, 0)) > 2.8: return null
	var n: Node = h.collider
	for _i in 4:
		if n == null: break
		if InventoryUI.is_container(n) or (n.is_in_group("pickups") and n.has_meta("items")): return n
		n = n.get_parent()
	return null

func _update_interact() -> void:
	interact_hint = ""
	interact_target = null
	if vehicle or dead or not active: return
	var t := _look_target()
	if t == null:
		# anything lying right at your feet
		for pk in get_tree().get_nodes_in_group("pickups"):
			if pk.has_meta("items") and (pk as Node3D).global_position.distance_to(global_position + Vector3(0, 0.4, 0)) < 1.4:
				t = pk
				break
	if t:
		interact_target = t
		if InventoryUI.is_container(t):
			var nm := "box"
			if t.has_meta("forge"): nm = str(t.get_meta("forge").get("name", "box")).replace(" (old scan)", "")
			elif t.has_meta("container_name"): nm = t.get_meta("container_name")
			interact_hint = "F  Open %s" % nm.to_lower()
		else:
			interact_hint = "F  Pick up %s" % WorldItem.label(t)
		return
	for c in get_tree().get_nodes_in_group("vehicles"):
		if c.global_position.distance_to(global_position) < 4.0 and c.driver == null:
			interact_hint = "F  Get in"
			return

func _interact() -> void:
	var t := interact_target
	var ui = get_tree().current_scene.get("inv_ui")
	if t and is_instance_valid(t):
		if InventoryUI.is_container(t):
			if ui: ui.show_with(t)
			return
		var items: Array = t.get_meta("items", [])
		for s in items.duplicate():
			var left := inv.add(s)
			if left > 0:
				s.n = left
			else:
				items.erase(s)
		if items.is_empty():
			t.queue_free()
		elif ui:
			ui.flash("No room for all of it")
			ui.show_with(null)
		return
	_try_get_in()

# ---------------------------------------------------------------- carrying things (middle mouse)
func _carry_start() -> void:
	if vehicle or dead or carried: return
	var cam := active_camera()
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * (3.0 if first_person else 5.5), 0xFFFF, [get_rid()])
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty() or not (h.collider is RigidBody3D): return
	var rb := h.collider as RigidBody3D
	if rb is VehicleBody3D or rb.is_in_group("vehicles") or rb.freeze or rb.mass > Items.CARRY_MAX_KG: return
	if (h.position as Vector3).distance_to(global_position + Vector3(0, 1.0, 0)) > 2.6: return
	carried = rb
	carry_dist = clamp(from.distance_to(rb.global_position), 1.1, 1.9) if first_person else 1.6
	add_collision_exception_with(rb)
	rb.sleeping = false
	rb.gravity_scale = 0.0

func _carry_drop(throw: bool) -> void:
	if carried == null: return
	var rb := carried
	carried = null
	if not is_instance_valid(rb): return
	rb.gravity_scale = 1.0
	if throw:
		var dir := -active_camera().global_transform.basis.z
		rb.linear_velocity = velocity + dir * clamp(260.0 / max(rb.mass, 1.0), 4.0, 16.0) + Vector3(0, 1.5, 0)
		rb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(rb): remove_collision_exception_with(rb))

func _carry_tick(dt: float) -> void:
	if carried == null: return
	if not is_instance_valid(carried) or vehicle or dead:
		carried = null
		return
	var cam := active_camera()
	var eye: Vector3 = head.global_position
	var target := eye - cam.global_transform.basis.z * carry_dist + Vector3(0, -0.25, 0)
	var err := target - carried.global_position
	if err.length() > 2.5:
		_carry_drop(false)           # snagged on something
		return
	carried.linear_velocity = err * 14.0 + velocity * 0.5
	carried.angular_velocity = carried.angular_velocity.lerp(Vector3.ZERO, clamp(dt * 8.0, 0.0, 1.0))

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
