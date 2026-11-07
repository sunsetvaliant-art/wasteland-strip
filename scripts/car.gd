class_name Car
extends RigidBody3D
## A simulated vehicle built from a design (VehicleSpecs.default_design or the builder):
##   suspension: a raycast per wheel; spring rate and preload from the corner weight and a ride frequency, separate
##               bump / rebound damping, bump stops, anti-roll bars per axle
##   tyres:      a Pacejka-style slip curve each way, combined in a friction circle; grip and rolling drag by surface
##   driveline:  engine torque curve + engine braking, clutch (auto-clutch), gearbox (auto with shift logic, or manual),
##               diffs (open / limited slip / locked), RWD or 4WD, wheel inertia; solved in sub-steps so it stays stable
## Controls: W throttle, S brake, A/D steer, Space handbrake, Q / E gear up / down, L lights, V chase / cab view, [ ] seat.

const SUBSTEPS := 8
const WHEEL_I := 1.1                         # kg m^2, wheel + tyre + brake disc
const AIR_CDA := 0.42 * 2.1                  # drag coefficient x frontal area
static var CATALOG := {}

var kind := "vjwagon"
var design: Dictionary = {}
var def := {}                                # the body's catalog entry
var eng: Dictionary
var box: Dictionary
var wheels: Array = []                       # Array of Dictionary (see _make_wheel)
var seat := Vector3(-0.5, 0.25, -0.14)

# driver and controls
var driver = null
var cab_view := false
var steer_now := 0.0
var throttle := 0.0
var brake_in := 0.0
var handbrake := false
# driveline state
var rpm := 750.0
var w_eng := 78.0                            # rad/s
var gear := 0                                # auto: 0 P, 1 R, 2 N, 3 D ; manual: 0 R, 1 N, 2.. = 1st..
var auto_gear := 0                           # which forward ratio the auto box is in
var shift_t := 0.0                           # time left in a shift (clutch out)
var gear_held := 0.0                         # auto: how long it's been in this gear (it won't flick through them)
var _park_at := Vector3.INF                  # parked with nobody in it: where the handbrake's holding it
var clutch := 1.0
var running := false
var crank := 0.0                             # > 0 while the starter is turning it over
var engine_load := 0.0                       # for the sound: how hard the engine is pulling
# cameras, lights
var cam_chase: Camera3D
var cam_cab: Camera3D
var chase_yaw := 0.0
var chase_pitch := 0.22
var seat_h := 0.08
var cab_yaw := 0.0
var cab_pitch := 0.0
var lights: Array[SpotLight3D] = []
var parts: Node3D                            # the visible chassis / suspension (VehicleRig)
var audio: Node                              # EngineAudio

static func catalog() -> Dictionary:
	if CATALOG.is_empty():
		CATALOG = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"))
	return CATALOG

func _ready() -> void:
	add_to_group("vehicles")
	add_to_group("physgun")
	if design.is_empty():
		design = VehicleSpecs.default_design(kind)
	kind = design.cab
	def = catalog().get(kind, catalog()["vjwagon"])
	eng = VehicleSpecs.ENGINES[design.engine]
	box = VehicleSpecs.GEARBOXES[design.gearbox]
	mass = float(design.mass)
	continuous_cd = true
	can_sleep = false
	contact_monitor = true                 # to notice bodies jammed under the chassis
	max_contacts_reported = 24
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE         # drag comes from the aero + rolling model, not a fudge
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.05
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	var axz: Array = design.axles.map(func(a): return float(a.z))
	var mid_z: float = (axz.max() + axz.min()) * 0.5
	var share: float = design.get("front_share", 0.55)
	var cz: float = lerpf(axz.min(), axz.max(), share)       # weight biased towards the front axle
	center_of_mass = Vector3(0, float(design.ride) + 0.32, cz)
	_build_body()
	_build_wheels()
	_build_lights_and_cameras()
	parts = VehicleRig.new()
	add_child(parts)
	parts.setup(self)
	audio = EngineAudio.new()
	add_child(audio)
	audio.setup(self)
	var fx := TyreFX.new()
	fx.name = "TyreFX"
	add_child(fx)
	fx.setup(self)
	rpm = float(eng.idle)
	w_eng = rpm * TAU / 60.0
	if box.auto: gear = 0
	else: gear = 1

# ---------------------------------------------------------------- build
func _build_body() -> void:
	var off: Array = design.cab_offset
	var holder := Node3D.new()
	holder.name = "Cab"
	holder.position = Vector3(off[0], off[1], off[2])
	add_child(holder)
	var body: Node3D = load("res://assets/vehicles/%s.glb" % def.glb).instantiate()
	body.rotation_degrees.y = -90      # the model's nose is +X; this car drives towards +Z
	holder.add_child(body)
	var mn: Array = def.min
	var ext: Array = def.ext
	var lo: float = float(mn[1]) + 0.12 + float(off[1])
	var h: float = ext[1]
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(ext[2] * 0.96, h * 0.55, ext[0] * 0.97)
	cs.shape = b
	cs.position = Vector3(off[0], lo + h * 0.275, float(mn[0]) + float(ext[0]) * 0.5 + float(off[2]))
	add_child(cs)
	var roof := CollisionShape3D.new()
	var rb := BoxShape3D.new()
	rb.size = Vector3(ext[2] * 0.82, h * 0.38, ext[0] * 0.5)
	roof.shape = rb
	roof.position = Vector3(off[0], lo + h * 0.66, float(mn[0]) + float(ext[0]) * 0.45 + float(off[2]))
	add_child(roof)
	# the chassis rails, low and narrow, so a car with the cab lifted off still has something to land on
	var fr: Dictionary = design.frame
	var rail := CollisionShape3D.new()
	var rs := BoxShape3D.new()
	rs.size = Vector3(float(fr.width) + 0.16, 0.16, float(fr.len))
	rail.shape = rs
	rail.position = Vector3(0, float(design.ride) + 0.1, float(fr.z))
	add_child(rail)

func _build_wheels() -> void:
	var g := 9.81
	var axles: Array = design.axles
	var n_ax := axles.size()
	# static load per axle from the centre of mass position along the wheelbase
	var zs: Array = axles.map(func(a): return float(a.z))
	var zmin: float = zs.min()
	var zmax: float = zs.max()
	for ai in n_ax:
		var a: Dictionary = axles[ai]
		var t := 0.5 if zmax == zmin else (float(a.z) - zmin) / (zmax - zmin)
		var load_share: float = 1.0 / n_ax
		if n_ax == 2:
			var fs: float = design.get("front_share", 0.55)
			load_share = fs if t > 0.5 else 1.0 - fs
		var m_c: float = mass * load_share * 0.5
		var k: float = m_c * pow(TAU * float(a.freq), 2.0)
		var T: float = a.travel
		var L_static := 0.6 * T
		var pre_f: float = m_c * g - k * (T - L_static)
		var c_crit := 2.0 * sqrt(k * m_c)
		for side in [-1.0, 1.0]:
			var w := {
				"axle": ai, "side": side, "a": a,
				"mount": Vector3(side * float(a.track), float(design.ride) + L_static, float(a.z)),
				"T": T, "k": k, "pre": pre_f, "cb": c_crit * float(a.zeta_b), "cr": c_crit * float(a.zeta_r),
				"r": float(a.tyre_r), "L": T, "L_prev": T, "contact": false, "N": 0.0, "omega": 0.0, "spin": 0.0,
				"steer": 0.0, "point": Vector3.ZERO, "normal": Vector3.UP, "slip": 0.0, "slip_a": 0.0, "surf": 1.0,
				"vx": 0.0, "vy": 0.0, "fx": 0.0, "fy": 0.0, "drive_t": 0.0, "collider": null, "mu": 1.0, "crr": 0.015,
				"fwd": Vector3.FORWARD, "sidev": Vector3.RIGHT, "slide": 0.75, "kind": "seal", "defl": 0.0, "slipv": 0.0,
			}
			wheels.append(w)

func _build_lights_and_cameras() -> void:
	var mn: Array = def.min
	var ext: Array = def.ext
	var off: Array = design.cab_offset
	for side in [-0.6, 0.6]:
		var l := SpotLight3D.new()
		l.position = Vector3(side, float(design.ride) + 0.35 + float(off[1]), float(mn[0]) + float(ext[0]) - 0.05 + float(off[2]))
		l.rotation_degrees = Vector3(-4, 180, 0)
		l.spot_range = 80
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
	seat = Vector3(-abs(sd[2]), sd[1], sd[0]) + Vector3(off[0], off[1], off[2])   # right-hand drive (this body's right is -X)
	cam_cab.position = seat + Vector3(0, 0.58 + seat_h, 0)
	cam_cab.rotation.y = PI
	add_child(cam_cab)

# ---------------------------------------------------------------- api used by the rest of the game
func active_camera() -> Camera3D:
	return cam_cab if cab_view else cam_chase

func seat_position() -> Vector3:
	return global_transform * (seat + Vector3(0, -0.4, 0))

func gear_name() -> String:
	if box.auto:
		return ["P", "R", "N", "D"][gear] + (str(auto_gear + 1) if gear == 3 else "")
	return "R" if gear == 0 else ("N" if gear == 1 else str(gear - 1))

func speed_kmh() -> float:
	return linear_velocity.length() * 3.6

## What the speedo reads: like a real one it's driven off the gearbox, so it's the driven wheels' speed (it runs
## away when you light the tyres up)
func speedo_kmh() -> float:
	var n := 0
	var v := 0.0
	for w in wheels:
		if w.a.drive:
			v += float(w.omega) * float(w.r)
			n += 1
	return abs(v / max(n, 1)) * 3.6

func ratio() -> float:
	## overall gear ratio, engine turns per wheel turn (negative in reverse, 0 in neutral / park / mid-shift)
	var fd: float = design.final
	if box.auto:
		match gear:
			1: return -float(box.reverse) * fd
			3: return float(box.ratios[auto_gear]) * fd
		return 0.0
	if gear == 0: return -float(box.reverse) * fd
	if gear == 1: return 0.0
	return float(box.ratios[gear - 2]) * fd

# ---------------------------------------------------------------- input
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
		_shift(1)
	if e.is_action_pressed("gear_down"):
		_shift(-1)
	if e.is_action_pressed("lights"):
		for l in lights:
			l.visible = not l.visible
	if e.is_action_pressed("camera"):
		cab_view = not cab_view
		active_camera().current = true
		driver.camera_changed.emit(active_camera())

func _shift(d: int) -> void:
	var top: int = 3 if box.auto else 1 + int(box.ratios.size())
	var ng := clampi(gear + d, 0, top)
	if ng == gear:
		return
	# the box won't go into reverse or park while you're rolling forward at speed
	var vz := linear_velocity.dot(global_transform.basis.z)
	if box.auto and ng <= 1 and vz > 2.0: return
	if not box.auto and ng == 0 and vz > 2.0: return
	gear = ng
	shift_t = float(box.shift_time)
	if box.auto and gear == 3:
		auto_gear = 0

# ---------------------------------------------------------------- simulation
func _physics_process(dt: float) -> void:
	if freeze:
		return
	_read_controls(dt)
	# climb in and it cranks and catches; climb out and it's switched off
	if driver and not running:
		crank += dt
		if crank > 0.85:
			running = true
			crank = 0.0
			w_eng = max(w_eng, float(eng.idle) * 1.5 * TAU / 60.0)    # catches with a flare
	elif driver == null:
		running = false
		crank = 0.0
	_unjam_bodies(dt)
	_park_hold()
	var space := get_world_3d().direct_space_state
	var xf := global_transform
	var up := xf.basis.y
	var com := xf * center_of_mass
	var ex := [get_rid()]
	if driver: ex.append(driver.get_rid())
	# ---- suspension: where's the ground under each wheel, and how hard is the spring pushing
	var arb_c := {}
	for w in wheels:
		var top: Vector3 = xf * w.mount
		var reach: float = w.T + w.r
		# wheels roll through bodies and loose bits rather than climbing onto them (layer 4: ragdolls, debris, pickups)
		var q := PhysicsRayQueryParameters3D.create(top + up * 0.15, top - up * reach, 0xFFFFFFFF & ~Ragdoll.layer_bits(), ex)
		var hit := space.intersect_ray(q)
		w.L_prev = w.L
		if hit:
			var d: float = (top + up * 0.15).distance_to(hit.position) - 0.15
			var r_eff: float = w.r - w.defl                          # the tyre squats under load
			w.L = clamp(d - r_eff, -0.05, w.T)
			w.contact = d - r_eff <= w.T
			w.point = hit.position
			w.normal = hit.normal
			w.collider = hit.collider
			_surface(w)
		else:
			w.L = w.T
			w.contact = false
		if not w.contact:
			w.L = w.T
		arb_c[str(w.axle) + str(w.side)] = w.T - w.L
	for w in wheels:
		w.N = 0.0
		if not w.contact:
			continue
		var comp: float = w.T - w.L
		var vel: float = (w.L_prev - w.L) / dt                  # + = compressing
		var f: float = w.k * comp + w.pre
		f += (w.cb if vel > 0.0 else w.cr) * vel
		var stop: float = 0.1 * w.T
		if w.L < stop:
			f += w.k * 9.0 * (stop - w.L)                       # rubber bump stop
		var a: Dictionary = w.a
		if a.arb > 0.0:
			var other: float = arb_c.get(str(w.axle) + str(-w.side), comp)
			f += float(a.arb) * (comp - other)
		w.N = max(f, 0.0)
	# sidewall deflection for next step: N over the tyre's vertical stiffness (about 200 kN/m at 32 psi)
	var psi: float = float(design.get("tyre_psi", 32.0))
	for w in wheels:
		var kt: float = 200000.0 * (psi / 32.0) * (float(w.r) / 0.33)
		w.defl = lerpf(w.defl, clamp(w.N / kt, 0.0, float(w.r) * 0.25), 0.3) if w.contact else w.defl * 0.8
	# ---- tyres: contact frame, velocities, then the driveline in sub-steps
	var steer_l := steer_now
	for w in wheels:
		w.steer = 0.0
		if w.a.steer:
			# Ackermann: the inside wheel turns tighter
			var ack: float = 1.0 + 0.12 * signf(steer_l) * (-float(w.side))
			w.steer = steer_l * ack
		if not w.contact:
			continue
		var n: Vector3 = w.normal
		var fwd_w: Vector3 = xf.basis * Vector3(sin(w.steer), 0, cos(w.steer))
		var fwd := (fwd_w - n * fwd_w.dot(n)).normalized()
		var side_v := fwd.cross(n)
		var v: Vector3 = linear_velocity + angular_velocity.cross(w.point - com)
		w.vx = v.dot(fwd)
		w.vy = v.dot(side_v)
		w.fwd = fwd
		w.sidev = side_v
	_driveline(dt)
	# ---- apply everything
	for w in wheels:
		if not w.contact or w.N <= 0.0:
			continue
		var p: Vector3 = w.point - global_position
		apply_force(up * w.N, p)
		apply_force(w.fwd * w.fx + w.sidev * w.fy, p)
	var v2 := linear_velocity.length_squared()
	if v2 > 1.0:
		apply_central_force(-linear_velocity.normalized() * 0.5 * 1.2 * float(design.get("cda", AIR_CDA)) * v2)

## Parked with nobody in it, the handbrake holds it where it stopped (the tyre model alone lets it creep down a
## slope a few millimetres a frame). Something big shoving it (more than the tyres could hold) moves it on.
func _park_hold() -> void:
	var hv := linear_velocity
	if driver != null or hv.length() > 1.5:
		_park_at = Vector3.INF
		return
	var on_ground := 0
	for w in wheels:
		if w.contact: on_ground += 1
	if on_ground < 3:
		_park_at = Vector3.INF
		return
	if _park_at == Vector3.INF:
		if hv.length() < 0.6: _park_at = global_position
		return
	var off := _park_at - global_position
	off.y = 0.0
	var f := (off * 60.0 - Vector3(hv.x, 0, hv.z) * 14.0) * mass
	var cap := mass * 9.8 * 0.7
	if f.length() > cap:
		_park_at = global_position          # shoved harder than the handbrake can hold: it slides, and holds again
		return
	apply_central_force(f)
	apply_torque(Vector3(0, -angular_velocity.y * 6.0, 0) * mass)

## A body (or a bit of one) under the chassis gets squeezed between the rails and the ground and jams the car on top
## of it. Anything ragdoll-light touching the underside is let through for a moment so the car rolls over it; bodies
## lying up on the bonnet or roof stay put.
var _let_through := {}
func _unjam_bodies(dt: float) -> void:
	for b in _let_through.keys():
		_let_through[b] -= dt
		if _let_through[b] <= 0.0:
			_let_through.erase(b)
			if is_instance_valid(b): remove_collision_exception_with(b)
	var floor_y: float = float(design.ride) + 0.45
	for b in get_colliding_bodies():
		if _let_through.has(b) or not (b is RigidBody3D) or b is VehicleBody3D or b.is_in_group("vehicles"):
			continue
		var rb := b as RigidBody3D
		if (rb.collision_layer & Ragdoll.layer_bits()) == 0 or rb.mass > 150.0:
			continue
		if to_local(rb.global_position).y < floor_y:
			add_collision_exception_with(rb)
			_let_through[rb] = 1.5

func _read_controls(dt: float) -> void:
	var steer_in := 0.0
	var thr := 0.0
	var brk := 0.0
	handbrake = false
	if driver and not get_tree().paused:
		thr = Input.get_action_strength("move_forward")
		brk = Input.get_action_strength("move_back")
		steer_in = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		handbrake = Input.is_action_pressed("brake")
	throttle = move_toward(throttle, thr, 6.0 * dt)
	brake_in = move_toward(brake_in, brk, 8.0 * dt)
	var v: float = abs(linear_velocity.dot(global_transform.basis.z))
	var max_steer: float = lerp(0.62, 0.2, clamp(v / 38.0, 0.0, 1.0))
	steer_now = move_toward(steer_now, steer_in * max_steer, (1.9 if steer_in != 0.0 else 2.6) * dt)
	if driver == null:
		throttle = 0.0
		handbrake = true

## Grip by ground: [peak mu, sliding / peak, rolling resistance, kind]. Terrain by its texture slot (main.GROUND).
## Loose stuff grips a lot less than bitumen and gives up more once the tyre's spinning (grass polishes, mud smears).
const TERRAIN_SURF := [
	[0.5, 0.55, 0.06, "grass"],    # pasture
	[0.55, 0.7, 0.06, "dirt"],     # forest floor
	[0.5, 0.66, 0.06, "dirt"],     # cane trash
	[0.6, 0.75, 0.07, "dirt"],     # farm soil
	[0.45, 0.8, 0.12, "sand"],     # sand
	[0.62, 0.62, 0.02, "rock"],    # mossy rock
	[0.88, 0.85, 0.013, "seal"],   # concrete
	[0.3, 0.6, 0.12, "mud"],       # river mud
	[0.5, 0.55, 0.05, "grass"],    # rough grass
]
var _terrain: Terrain3D

func _surface(w: Dictionary) -> void:
	var c = w.collider
	var surf: Array = [0.85, 0.75, 0.02, "seal"]      # props, other cars, buildings: hard
	if c and c.is_in_group("road"):
		surf = [0.95, 0.85, 0.013, "seal"]
	elif c is Terrain3D or (c and c.get_class() == "StaticBody3D" and c.get_parent() is Terrain3D) or (c and str(c.name).begins_with("Terrain")):
		if _terrain == null:
			var m = get_tree().current_scene
			if m and "terrain" in m: _terrain = m.terrain
		var id := 0
		if _terrain and _terrain.data:
			var t: Vector3 = _terrain.data.get_texture_id(w.point)
			if not is_nan(t.x):
				id = int(t.y) if t.z > 0.5 else int(t.x)
		surf = TERRAIN_SURF[clampi(id, 0, TERRAIN_SURF.size() - 1)]
	elif c and (c.is_in_group("corpses") or c is PhysicalBone3D or (c is RigidBody3D and (c as RigidBody3D).mass < 120.0)):
		surf = [0.35, 0.6, 0.02, "flesh"]
	# tyre pressure: soft tyres bag out and grip loose ground better, roll heavier; hard ones skate on it
	var psi: float = float(design.get("tyre_psi", 32.0))
	var soft: float = clamp((32.0 - psi) / 20.0, -1.0, 1.0)
	var loose: bool = surf[3] in ["grass", "dirt", "sand", "mud"]
	w.mu = float(surf[0]) * (1.0 + (0.22 * soft if loose else -0.06 * abs(soft)))
	w.slide = float(surf[1])
	w.crr = float(surf[2]) * (1.0 + 0.5 * max(soft, 0.0))
	w.kind = surf[3]

## The tyre's force curve up to its peak; past the peak it stays at the peak and the slide factor does the falling
## off (the raw curve dropped to half at big slip on top of that, so a spinning tyre had a third of its grip and
## a V8 would sit there doing a burnout at 15 km/h)
func _pac(x: float, B: float, C: float, E: float) -> float:
	var bx := B * x
	var a := C * atan(bx - E * (bx - atan(bx)))
	if abs(a) > PI * 0.5:
		return signf(a)
	return sin(a)

func _driveline(dt: float) -> void:
	var h := dt / SUBSTEPS
	var R := ratio()
	var driven := wheels.filter(func(w): return w.a.drive)
	var nd := maxi(1, driven.size())
	var eff := 0.88
	var idle_w: float = float(eng.idle) * TAU / 60.0
	var lim_w: float = float(eng.limiter) * TAU / 60.0
	var I_e: float = eng.inertia
	var Tcap: float = 1.6 * 480.0
	if shift_t > 0.0:
		shift_t -= dt
	gear_held += dt
	# auto box: pick the gear from road speed and throttle
	if box.auto and gear == 3 and shift_t <= 0.0:
		# the valve body shifts off output-shaft speed and throttle, never off engine revs. With the tyres lit up the
		# shaft's spinning fast too, so it holds each gear a good second before it'll go up another (it used to run
		# through to third in half a second), and won't hunt back down straight after a change
		var ratios: Array = box.ratios
		var w_out := 0.0
		for w in driven: w_out += w.omega
		w_out /= nd
		var fd: float = design.final
		var shaft_rpm: float = w_out * float(ratios[auto_gear]) * fd * 60.0 / TAU
		var up_rpm := lerpf(2000.0, float(eng.redline) * 0.93, throttle)
		var dn_rpm := lerpf(900.0, 2300.0, throttle)
		if shaft_rpm > up_rpm and auto_gear < ratios.size() - 1 and gear_held > 1.3:
			auto_gear += 1
			shift_t = float(box.shift_time)
			gear_held = 0.0
		elif auto_gear > 0 and gear_held > 0.6:
			var lower_rpm: float = w_out * float(ratios[auto_gear - 1]) * fd * 60.0 / TAU
			if shaft_rpm < dn_rpm and lower_rpm < float(eng.redline) * 0.8:
				auto_gear -= 1
				shift_t = float(box.shift_time)
				gear_held = 0.0
		R = ratio()
	for w in wheels:
		w.fx = 0.0
		w.fy = 0.0
	var load_acc := 0.0
	for s in SUBSTEPS:
		# wheel speed the gearbox sees (diff carrier average)
		var w_avg := 0.0
		for w in driven: w_avg += w.omega
		w_avg /= nd
		# clutch: the auto-clutch / torque converter slips at low revs so you can pull away; out during a shift
		var engage := 0.0
		var shifting := shift_t > 0.0
		if R != 0.0 and (not shifting or box.auto):
			engage = clamp((w_eng - idle_w * 1.05) / (idle_w * 0.9), 0.0, 1.0)
			if box.auto: engage = max(engage, 0.25) if throttle > 0.05 else engage * 0.6 + 0.08
			if abs(w_avg * R - w_eng) < 8.0 and w_eng > idle_w: engage = 1.0
			if shifting: engage *= 0.55                        # the auto's bands slip through a shift, they don't let go
		clutch = engage
		# engine torque: throttle on the curve, engine braking off it, a governor at idle, the limiter at the top
		var rpm_now: float = w_eng * 60.0 / TAU
		var thr := throttle if running else 0.0
		if shifting and not box.auto: thr = 0.0                  # you lift for the change
		if w_eng > lim_w: thr = 0.0
		var t_full: float = VehicleSpecs.torque(eng, rpm_now)
		var t_eng: float = t_full * thr - float(eng.friction) * (0.4 + rpm_now / 2000.0) * (1.0 - thr)
		if crank > 0.0: w_eng = lerpf(w_eng, 230.0 * TAU / 60.0, h * 8.0)   # starter motor
		if w_eng < idle_w and running:
			t_eng += (idle_w - w_eng) * 2.2                     # idle governor / carby idle circuit
		# clutch torque: the torque that would lock engine and wheels together this sub-step, capped by the clutch
		var t_c := 0.0
		if engage > 0.0:
			var I_w_tot: float = WHEEL_I * nd
			var dw: float = w_eng - w_avg * R
			var t_lock: float = dw / (h * (1.0 / I_e + R * R / I_w_tot))
			t_c = clamp(t_lock, -Tcap * engage, Tcap * engage)
		w_eng += h * (t_eng - t_c) / I_e
		w_eng = max(w_eng, 0.0)
		load_acc += clamp(t_c / max(t_full, 1.0), -1.0, 1.0)
		# torque to the wheels through the diffs
		var t_axle_total: float = t_c * R * eff
		var axles_d := {}
		for w in driven:
			axles_d[w.axle] = true
		var per_axle: float = t_axle_total / max(1, axles_d.size())
		for ai in axles_d:
			var pair := driven.filter(func(w): return w.axle == ai)
			var kind_d: String = pair[0].a.get("diff", "open")
			if pair.size() == 2:
				var wl: Dictionary = pair[0]
				var wr: Dictionary = pair[1]
				var d_omega: float = wl.omega - wr.omega
				var bias := 0.0
				if kind_d == "lsd":
					bias = clamp(d_omega * 60.0, -abs(per_axle) * 0.6 - 150.0, abs(per_axle) * 0.6 + 150.0)
				elif kind_d == "locked":
					bias = d_omega * WHEEL_I / (h * 2.0)        # holds both wheels together
				wl.drive_t = per_axle * 0.5 - bias
				wr.drive_t = per_axle * 0.5 + bias
			else:
				for w in pair: w.drive_t = per_axle / pair.size()
		# each wheel: drive torque, brake torque, tyre force back through the contact patch
		for w in wheels:
			var t_drive: float = w.drive_t if w.a.drive else 0.0
			var tb: float = float(w.a.brake) * brake_in
			if handbrake and not w.a.steer: tb = max(tb, 3500.0)
			if gear == 0 and box.auto and w.a.drive: tb = max(tb, 6000.0)        # park pawl
			var fx := 0.0
			var fy := 0.0
			if w.contact and w.N > 0.0:
				var muN: float = w.mu * w.N
				var vref: float = max(abs(w.vx), 1.5)
				var sr: float = (w.omega * w.r - w.vx) / vref
				var sa: float = atan2(w.vy, max(abs(w.vx), 1.0))
				# past the peak the tyre's sliding: grip falls to the surface's sliding share (big drop on grass / mud)
				var slide_x: float = lerpf(1.0, w.slide, smoothstep(0.12, 0.7, abs(sr)))
				var slide_y: float = lerpf(1.0, w.slide, smoothstep(0.14, 0.6, abs(sa)))
				fx = muN * _pac(sr, 11.0, 1.65, 0.3) * slide_x
				fy = -muN * _pac(sa, 15.0, 1.35, -0.2) * slide_y        # peaks about 8 deg of slip, like a real tyre
				var lowspd: float = clamp(1.0 - (abs(w.vx) + abs(w.vy)) / 2.5, 0.0, 1.0)
				fy = lerpf(fy, clamp(-w.vy * w.N * 0.9, -muN, muN), lowspd)       # don't skate about when stopped
				var mag := sqrt(fx * fx + fy * fy)
				if mag > muN:                                     # friction circle
					fx *= muN / mag
					fy *= muN / mag
				fx -= sign(w.vx) * w.N * w.crr * clamp(abs(w.vx), 0.0, 1.0)
			var spin_t: float = t_drive - fx * w.r
			var om: float = w.omega + h * spin_t / WHEEL_I
			# brakes act against spin but never reverse it
			var db: float = h * tb / WHEEL_I
			if abs(om) <= db: om = 0.0
			else: om -= sign(om) * db
			if not w.contact:
				om *= 0.999
			w.omega = om
			w.fx += fx / SUBSTEPS
			w.fy += fy / SUBSTEPS
			if s == SUBSTEPS - 1:
				w.slipv = Vector2(w.omega * w.r - w.vx, w.vy).length() if w.contact else 0.0
		# wheels on the ground that are free (no drive, no brake) follow the road closely
	rpm = w_eng * 60.0 / TAU
	engine_load = load_acc / SUBSTEPS

# ---------------------------------------------------------------- cameras
func _process(dt: float) -> void:
	for w in wheels:
		w.spin = fmod(w.spin + w.omega * dt, TAU)
	if driver == null or cab_view:
		return
	chase_yaw = lerp(chase_yaw, 0.0, 1.2 * dt) if Input.get_last_mouse_velocity().length() < 5 else chase_yaw
	var back := global_transform.basis.z
	back.y = 0
	back = back.normalized()
	var dir := back.rotated(Vector3.UP, chase_yaw + PI)
	var dist := 6.8 + float(design.frame.len) * 0.25
	var target := global_position + Vector3(0, 1.2, 0)
	var want := target + dir * cos(chase_pitch) * dist + Vector3(0, sin(chase_pitch) * dist, 0)
	cam_chase.global_position = cam_chase.global_position.lerp(want, clamp(9.0 * dt, 0, 1))
	cam_chase.look_at(target, Vector3.UP)
