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
		_try_get_in()

func _apply_camera() -> void:
	var c := active_camera()
	c.current = true
	body_mesh.visible = vehicle == null
	rig.hide_head(first_person)
	camera_changed.emit(c)

func _physics_process(dt: float) -> void:
	if not active:
		return
	if vehicle:
		global_position = vehicle.seat_position()
		return
	rotation.y = yaw
	head.rotation.x = pitch
	var target_h := 1.1 if crouching else 1.62
	head.position.y = lerp(head.position.y, target_h, 10 * dt)
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var speed := CROUCH if crouching else (RUN if Input.is_action_pressed("sprint") else WALK * 2.0)
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

func _process(_dt: float) -> void:
	if first_person and vehicle == null and rig:
		# eyes: just in front of the head bone, so looking down shows your own body
		cam_fp.global_position = rig.head_position() + global_transform.basis * Vector3(0, 0.07, -0.11)

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
