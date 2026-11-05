class_name Car
extends VehicleBody3D
## The VJ Valiant wagon on Godot's vehicle physics: auto box (P R N D on Q / E), W gas, S brake, Space handbrake,
## L headlights, V swaps chase cam / cab view. Ported numbers: wheelbase 2.83 m, 185R14s, ~1400 kg running.

const GEARS := ["P", "R", "N", "D"]
static var CATALOG := {}

## Which body this is (a key from assets/vehicles/catalog.json, ported from the browser build's CABS table)
var kind := "vjwagon"
var def := {}
var AX_F := 1.417
var AX_R := -1.417
var TRACK_HALF := 0.74
var AXLE_Y := -0.46
var TYRE_R := 0.31
var seat := Vector3(-0.5, 0.25, -0.14)

var gear := 0
var driver = null
var cab_view := false
var steer_now := 0.0
var cam_chase: Camera3D
var cam_cab: Camera3D
var chase_yaw := 0.0
var chase_pitch := 0.22
var seat_h := 0.08
var cab_yaw := 0.0
var cab_pitch := 0.0
var lights: Array[SpotLight3D] = []
var wheels: Array[VehicleWheel3D] = []

static func catalog() -> Dictionary:
	if CATALOG.is_empty():
		CATALOG = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"))
	return CATALOG

func _ready() -> void:
	add_to_group("vehicles")
	add_to_group("physgun")
	def = catalog().get(kind, catalog()["vjwagon"])
	var big: bool = def.cls == "4x4"
	var mn: Array = def.min
	var ext: Array = def.ext
	AX_F = def.ax_f
	AX_R = def.ax_r
	TYRE_R = 0.39 if big else 0.31
	AXLE_Y = mn[1] + (0.24 if big else 0.15)
	TRACK_HALF = ext[2] * 0.5 - (0.2 if big else 0.18)
	mass = float(def.kg) * 2.3
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, AXLE_Y + 0.25, (AX_F + AX_R) * 0.5 + 0.15)
	var body: Node3D = load("res://assets/vehicles/%s.glb" % def.glb).instantiate()
	body.rotation_degrees.y = -90      # the model's nose is +X; Godot vehicles drive towards +Z
	add_child(body)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# lower body box from the sills to the belt line, a narrower one for the cabin
	var lo: float = mn[1] + 0.12
	var h: float = ext[1]
	box.size = Vector3(ext[2] * 0.96, h * 0.55, ext[0] * 0.97)
	cs.shape = box
	cs.position = Vector3(0, lo + h * 0.275, mn[0] + ext[0] * 0.5)
	add_child(cs)
	var roof := CollisionShape3D.new()
	var rb := BoxShape3D.new()
	rb.size = Vector3(ext[2] * 0.82, h * 0.38, ext[0] * 0.5)
	roof.shape = rb
	roof.position = Vector3(0, lo + h * 0.66, mn[0] + ext[0] * 0.45)
	add_child(roof)
	var wheel_scene: PackedScene = load("res://assets/vehicles/%s.glb" % ("wheel_4x4" if big else "wheel_car"))
	for front in [true, false]:
		for side in [1.0, -1.0]:
			var w := VehicleWheel3D.new()
			w.position = Vector3(side * TRACK_HALF, AXLE_Y + 0.17, AX_F if front else AX_R)
			w.wheel_radius = TYRE_R
			w.wheel_rest_length = 0.17
			w.suspension_travel = 0.2
			w.suspension_stiffness = 38.0
			w.suspension_max_force = 9000.0
			w.damping_compression = 2.4
			w.damping_relaxation = 3.0
			w.wheel_friction_slip = 2.6 if front else 2.3
			w.wheel_roll_influence = 0.25
			w.use_as_steering = front
			w.use_as_traction = not front
			var wm: Node3D = wheel_scene.instantiate()
			wm.scale = Vector3.ONE * TYRE_R * 2.0
			wm.rotation_degrees.y = 90
			w.add_child(wm)
			add_child(w)
			wheels.append(w)
	for side in [-0.6, 0.6]:
		var l := SpotLight3D.new()
		l.position = Vector3(side, AXLE_Y + 0.35, mn[0] + ext[0] - 0.05)
		l.rotation_degrees = Vector3(-4, 180, 0)
		l.spot_range = 70
		l.spot_angle = 32
		l.light_energy = 6
		l.light_color = Color(1, 0.92, 0.75)
		l.shadow_enabled = true
		l.visible = false
		add_child(l)
		lights.append(l)
	cam_chase = Camera3D.new()
	cam_chase.add_to_group("cameras")
	cam_chase.fov = 70
	cam_chase.far = 30000
	cam_chase.near = 0.1
	cam_chase.top_level = true
	add_child(cam_chase)
	cam_cab = Camera3D.new()
	cam_cab.add_to_group("cameras")
	cam_cab.fov = 78
	cam_cab.far = 30000
	cam_cab.near = 0.03
	var sd: Array = def.get("seat", [-0.14, -0.266, 0.526])
	seat = Vector3(-abs(sd[2]), sd[1], sd[0])           # driver's side: right-hand drive (this body's right is -X)
	cam_cab.position = seat + Vector3(0, 0.58 + seat_h, 0)
	cam_cab.rotation.y = PI                               # cameras look down -Z, this car drives towards +Z
	add_child(cam_cab)

func active_camera() -> Camera3D:
	return cam_cab if cab_view else cam_chase

func seat_position() -> Vector3:
	return global_transform * (seat + Vector3(0, -0.4, 0))

func gear_name() -> String:
	return GEARS[gear]

func speed_kmh() -> float:
	return linear_velocity.length() * 3.6

func _unhandled_input(e: InputEvent) -> void:
	if driver == null or get_tree().paused:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		chase_yaw -= e.relative.x * 0.003
		chase_pitch = clamp(chase_pitch + e.relative.y * 0.003, -0.2, 1.2)
		if cab_view:
			cab_yaw = clamp(cab_yaw - e.relative.x * 0.0025, -2.0, 2.0)
			cab_pitch = clamp(cab_pitch - e.relative.y * 0.0025, -0.9, 0.7)
			cam_cab.rotation = Vector3(cab_pitch, PI + cab_yaw, 0)
	if e.is_action_pressed("seat_up"):
		seat_h = min(seat_h + 0.04, 0.5)
		cam_cab.position.y = seat.y + 0.58 + seat_h
	if e.is_action_pressed("seat_down"):
		seat_h = max(seat_h - 0.04, -0.2)
		cam_cab.position.y = seat.y + 0.58 + seat_h
	if e.is_action_pressed("gear_up"):
		gear = min(gear + 1, 3)
	if e.is_action_pressed("gear_down"):
		gear = max(gear - 1, 0)
	if e.is_action_pressed("lights"):
		for l in lights:
			l.visible = not l.visible
	if e.is_action_pressed("camera"):
		cab_view = not cab_view
		active_camera().current = true
		driver.camera_changed.emit(active_camera())

func _physics_process(dt: float) -> void:
	var gas := 0.0
	var brk := 0.0
	var steer_in := 0.0
	if driver:
		gas = Input.get_action_strength("move_forward")
		brk = Input.get_action_strength("move_back")
		steer_in = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	var v := linear_velocity.dot(global_transform.basis.z)
	var max_steer: float = lerp(0.6, 0.18, clamp(abs(v) / 30.0, 0.0, 1.0))
	steer_now = move_toward(steer_now, steer_in * max_steer, (2.6 if steer_in != 0 else 4.0) * dt)
	steering = steer_now
	var force := 0.0
	match GEARS[gear]:
		"D":
			# a tired 245 Hemi and a 3-speed auto, flattened into a torque curve
			force = gas * 5200.0 * clamp(1.15 - abs(v) / 48.0, 0.15, 1.0)
		"R":
			force = -gas * 3200.0 * clamp(1.0 - abs(v) / 9.0, 0.0, 1.0)
	engine_force = force
	brake = brk * 38.0
	if GEARS[gear] == "P" or driver == null:
		brake = 30.0
	if Input.is_action_pressed("brake") and driver:
		wheels[2].brake = 60.0
		wheels[3].brake = 60.0

func _process(dt: float) -> void:
	if driver == null or cab_view:
		return
	# chase camera: sits behind and swings round with the car, mouse can look around
	chase_yaw = lerp(chase_yaw, 0.0, 1.2 * dt) if Input.get_last_mouse_velocity().length() < 5 else chase_yaw
	var back := global_transform.basis.z
	back.y = 0
	back = back.normalized()
	var dir := back.rotated(Vector3.UP, chase_yaw + PI)
	var dist := 6.8
	var target := global_position + Vector3(0, 1.2, 0)
	var want := target + dir * cos(chase_pitch) * dist + Vector3(0, sin(chase_pitch) * dist, 0)
	cam_chase.global_position = cam_chase.global_position.lerp(want, clamp(9.0 * dt, 0, 1))
	cam_chase.look_at(target, Vector3.UP)
