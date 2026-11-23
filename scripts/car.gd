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
var _wb := 0.0                                  # wheelbase, for the speed-sensitive steering limit
var brake_in := 0.0
var _brake_lim := 1.0                          # the pedal the driver's found locks the wheels (0.2.58)
var _brake_locked := false
var _thr_lim := 1.0                           # the throttle the driver's found spins the tyres (0.2.59)
var _thr_spun := false
var handbrake := false
# driveline state
var rpm := 750.0
var w_eng := 78.0                            # rad/s
var gear := 0                                # auto: 0 P, 1 R, 2 N, 3 D ; manual: 0 R, 1 N, 2.. = 1st..
var auto_gear := 0                           # which forward ratio the auto box is in
var shift_t := 0.0                           # time left in a shift (clutch out)
var gear_held := 0.0                         # auto: how long it's been in this gear (it won't flick through them)
var _park_at := Vector3.INF
var home_pos := Vector3.ZERO                 # where it was when the world was made (LAN: the same car on every machine)                  # parked with nobody in it: where the handbrake's holding it
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
var lamps := {}                 # 0.2.68: Lamps.build() of the body's placed lamps
var parts: Node3D                            # the visible chassis / suspension (VehicleRig)
var bonnet_pivot: Node3D = null              # the bonnet on its hinge, when the body has a bonnet line (0.2.55)
var bonnet_open := 0.0                       # 0 shut .. 1 open (animated toward bonnet_want)
var bonnet_want := 0.0
var tub_front := -1e9                        # where the cab ends, when the tub's off
var tray := {}                               # TrayGen.build result
var sides_down := false
var doors_open := false
var _side_t := 0.0
var _door_t := 0.0
var _seq_t := 0.0
var audio: Node                              # EngineAudio

static func catalog() -> Dictionary:
	if CATALOG.is_empty():
		CATALOG = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"))
	return CATALOG

## How much it carries: a tray (utes, pickups, trucks), a wagon's back, or a sedan's boot
static func storage_key(d: Dictionary) -> String:
	var n: String = str(d.get("name", "")).to_lower()
	for w in ["ute", "pickup", "flatbed", "truck", "workhorse"]:
		if n.contains(w): return "car_tray"
	for w in ["wagon", "hearse"]:
		if n.contains(w): return "car_wagon"
	return "car_boot"

func _ready() -> void:
	add_to_group("vehicles")
	add_to_group("physgun")
	if design.is_empty():
		design = VehicleSpecs.default_design(kind)
	kind = design.cab
	def = catalog().get(kind, catalog()["vjwagon"])
	# its storage (F at the back of it)
	if not design.get("no_cab", false):
		set_meta("container", storage_key(def))
		set_meta("container_name", {"car_tray": "tray", "car_wagon": "back of the wagon", "car_boot": "boot"}[storage_key(def)])
		set_meta("empty", true)
	# 0.2.55: every engine is built from the kit; old designs get their body's stock kit engine
	if not design.has("kit"): design["kit"] = EngineKit.stock(def)
	eng = EngineKit.stats(design.kit) if (design.kit as Dictionary).has("block") and str(design.kit.block) != "" else VehicleSpecs.ENGINES.get(str(design.get("engine", "202")), VehicleSpecs.ENGINES["202"])
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
	_aim_beams()
	parts = VehicleRig.new()
	add_child(parts)
	parts.setup(self)
	if def.has("forks"):
		forks = ForkRig.new()
		forks.name = "Forks"
		add_child(forks)
		forks.setup(self)
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
var forks: ForkRig                    # 0.2.66: the forklift's mast and forks
var _body_nodes: Array = []
func _build_body() -> void:
	var off: Array = design.cab_offset
	var holder := Node3D.new()
	holder.name = "Cab"
	holder.position = Vector3(off[0], off[1], off[2])
	add_child(holder)
	var _n0 := get_child_count() - 1
	var mn: Array = def.min
	var bare: bool = design.get("no_cab", false)          # a rolling chassis: no body on it yet
	var cut := BodyCut.of(str(def.glb))
	var tub_off: bool = str(design.get("tub", "stock")) != "stock" and cut.has("tub")
	var has_bonnet: bool = cut.has("bonnet") and (BodyCut.has_bonnet(cut.bonnet))
	var tub_lift := float(design.get("tub_h", 0.0))                  # 0.2.59: the tub up or down on the rails
	var split_tub: bool = cut.has("tub") and absf(tub_lift) > 0.001
	# 0.2.68: a respray (design "paint_col" over the faces marked paint in Body tools), parts taken off the car
	var col := Color(0, 0, 0, 0)
	if str(design.get("paint_col", "")) != "" and cut.has("respray"): col = Color.html(str(design.paint_col))
	var parts_off := not (design.get("parts_off", []) as Array).is_empty()
	for pp in cut.get("parts", []):
		if bool((pp as Dictionary).get("off", false)): parts_off = true
	if not bare and (tub_off or has_bonnet or split_tub or col.a > 0.0 or parts_off):
		# 0.2.55: the body in pieces from its cut lines (Body tools): the cab, maybe the tub, the bonnet on its hinge
		var pcs := BodyCut.pieces(str(def.glb), tub_off or split_tub, has_bonnet, col, design.get("parts_off", []))
		var keep: Array = pcs.cab.duplicate()
		for am in keep:
			var mi := MeshInstance3D.new(); mi.mesh = am
			holder.add_child(mi)
		if not tub_off:
			for am in pcs.tub:
				var mi := MeshInstance3D.new(); mi.mesh = am
				mi.position.y = tub_lift
				holder.add_child(mi)
		if has_bonnet:
			var hg := BodyCut.hinge(cut.bonnet)
			bonnet_pivot = Node3D.new()
			bonnet_pivot.name = "Bonnet"
			bonnet_pivot.position = hg[0]
			holder.add_child(bonnet_pivot)
			for am in pcs.bonnet + pcs.under:
				var mi := MeshInstance3D.new(); mi.mesh = am
				mi.position = -hg[0]
				bonnet_pivot.add_child(mi)
			bonnet_pivot.visible = not design.get("bonnet_off", false)
			var bay := BodyCut.bay_node(cut.bonnet, float(design.ride) + 0.2 - float(off[1]), (col if col.a > 0.0 else BodyCut.paint_of(str(def.glb))) * 0.82)
			if bay: holder.add_child(bay)
		if tub_off: tub_front = BodyCut.tub_front_z(cut.tub, float(design.ride) + 0.36 - float(off[1])) + float(off[2])
		# 0.2.56: another model's tub bolted on behind this cab, its front at the back of the cab, on the rails
		if tub_off and str(design.get("tub", "")) == "swap" and str(design.get("tub_from", "")) != "":
			var src := str(design.tub_from)
			var scut := BodyCut.of(src)
			var skind := ""
			for k in Car.catalog():
				if str(Car.catalog()[k].glb) == src: skind = k
			if scut.has("tub") and skind != "":
				var sd := VehicleSpecs.default_design(skind)
				var soff: Array = sd.cab_offset
				var dy := (float(design.ride) - float(off[1])) - (float(sd.ride) - float(soff[1]))
				var y_t := float(design.ride) + 0.36 - float(off[1])
				var dz := BodyCut.tub_front_z(cut.tub, y_t) - BodyCut.tub_front_z(scut.tub, y_t - dy) - 0.05
				for am in BodyCut.pieces(src, true, false, col).tub:
					var mi := MeshInstance3D.new(); mi.mesh = am
					mi.position = Vector3(0, dy + tub_lift, dz)
					holder.add_child(mi)
	elif not bare:
		var body: Node3D = load("res://assets/vehicles/%s.glb" % def.glb).instantiate()
		body.rotation_degrees.y = -90      # the model's nose is +X; this car drives towards +Z
		holder.add_child(body)
	# 0.2.68: lamps placed in Body tools
	lamps = {}
	if not bare and not (cut.get("lights", []) as Array).is_empty():
		lamps = Lamps.build(cut.lights)
		holder.add_child(lamps.node)
	var ext: Array = def.ext
	var lo: float = float(mn[1]) + 0.12 + float(off[1])
	var h: float = ext[1]
	if not bare:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		var z0b := float(mn[0]) + float(off[2])
		var z1b := float(mn[0]) + float(ext[0]) + float(off[2])
		if tub_front > -1e8: z0b = tub_front + 0.05          # the tub's off: the body ends at the back of the cab
		b.size = Vector3(ext[2] * 0.96, h * 0.55, (z1b - z0b) * 0.97)
		cs.shape = b
		cs.position = Vector3(off[0], lo + h * 0.275, (z0b + z1b) * 0.5)
		add_child(cs)
		var roof := CollisionShape3D.new()
		var rb := BoxShape3D.new()
		# 0.2.67: with the tub off the roof box stops at the back of the cab too (it hung out over the rails and shoved
		# the loose tub up)
		var rz0 := float(mn[0]) + float(ext[0]) * 0.2 + float(off[2])
		var rz1 := float(mn[0]) + float(ext[0]) * 0.7 + float(off[2])
		if tub_front > -1e8: rz0 = maxf(rz0, tub_front + 0.05)
		rb.size = Vector3(ext[2] * 0.82, h * 0.38, maxf(rz1 - rz0, 0.3))
		roof.shape = rb
		roof.position = Vector3(off[0], lo + h * 0.66, (rz0 + rz1) * 0.5)
		add_child(roof)
	# a custom tray where the tub was (0.2.55)
	if not bare and tub_front > -1e8 and str(design.get("tub", "")) == "tray":
		var fr0: Dictionary = design.frame
		var tcfg := TrayGen.cfg_of(design)
		var y_deck := float(design.ride) + 0.36 + float(tcfg.get("height", 0.0))      # 0.2.56: raise or drop the tray
		var tr := TrayGen.build(tcfg, tub_front - 0.04, y_deck, float(fr0.z) - float(fr0.len) * 0.5,
			float(ext[2]) * 0.96, float(mn[1]) + float(ext[1]) + float(off[1]))
		tray = tr
		add_child(tr.node)
		for shp in tr.shapes:
			var tcs := CollisionShape3D.new()
			var tb := BoxShape3D.new(); tb.size = shp[1]
			tcs.shape = tb; tcs.transform = shp[0]
			add_child(tcs)
	# the chassis rails, low and narrow, so a car with the cab lifted off still has something to land on
	var fr: Dictionary = design.frame
	var rail := CollisionShape3D.new()
	var rs := BoxShape3D.new()
	rs.size = Vector3(float(fr.width) + 0.16, 0.16, float(fr.len))
	rail.shape = rs
	rail.position = Vector3(0, float(design.ride) + 0.1, float(fr.z))
	add_child(rail)
	_body_nodes = get_children().slice(_n0)

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
				# 0.2.59: lift (ride height) per axle: the wheel hangs further below the body
				"mount": Vector3(side * float(a.track), float(design.ride) + L_static - float(a.get("lift", 0.0)), float(a.z)),
				"T": T, "k": k, "pre": pre_f, "cb": c_crit * float(a.zeta_b), "cr": c_crit * float(a.zeta_r),
				"r": float(a.tyre_r), "L": T, "L_prev": T, "Lg": T, "Lg_prev": T, "soft": null, "sink": 0.0, "belly": 0.0, "contact": false, "N": 0.0, "omega": 0.0, "spin": 0.0,
				"steer": 0.0, "point": Vector3.ZERO, "normal": Vector3.UP, "slip": 0.0, "slip_a": 0.0, "surf": 1.0,
				"vx": 0.0, "vy": 0.0, "fx": 0.0, "fy": 0.0, "drive_t": 0.0, "collider": null, "mu": 1.0, "crr": 0.015,
				"fwd": Vector3.FORWARD, "sidev": Vector3.RIGHT, "slide": 0.75, "kind": "seal", "defl": 0.0, "slipv": 0.0,
				"sr": 0.0, "dN": 0.0, "Ns": m_c * g,
			}
			wheels.append(w)

## The two headlight beams come from the outermost front lamps placed in Body tools (if any)
func _aim_beams() -> void:
	if lamps.is_empty() or lights.size() < 2: return
	var off: Array = design.cab_offset
	var o := Vector3(float(off[0]), float(off[1]), float(off[2]))
	var front: Array = (lamps.beams as Array).filter(func(q): return (q as Vector3).z > 0.0)
	if front.is_empty(): return
	var l_p: Vector3 = front[0]; var r_p: Vector3 = front[0]
	for q in front:
		if (q as Vector3).x > l_p.x: l_p = q
		if (q as Vector3).x < r_p.x: r_p = q
	lights[0].position = o + l_p + Vector3(0, 0, 0.06)
	lights[1].position = o + r_p + Vector3(0, 0, 0.06)

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
## Pull the body apart and put it back together from the design (the tub came off or went on, a tray was built)
func rebuild_body() -> void:
	for n in _body_nodes:
		if is_instance_valid(n): n.queue_free()
	_body_nodes = []
	bonnet_pivot = null
	tub_front = -1e9
	tray = {}
	_build_body()
	_lamp_state = -1
	_bonnet_front = -1
	_aim_beams()

func toggle_bonnet() -> void:
	bonnet_want = 0.0 if bonnet_want > 0.5 else 1.0

## The bonnet comes off whole, as its own heavy panel (an engine swap needs it out of the way)
func take_off_bonnet() -> RigidBody3D:
	if bonnet_pivot == null or design.get("bonnet_off", false): return null
	var rb := RigidBody3D.new()
	rb.mass = 18.0
	rb.add_to_group("physgun")
	rb.set_meta("bonnet_of", str(def.glb))
	rb.set_meta("forge_name", "Bonnet")
	var aabb := AABB()
	var first := true
	for mi in bonnet_pivot.get_children():
		if not (mi is MeshInstance3D): continue
		var m2 := MeshInstance3D.new(); m2.mesh = (mi as MeshInstance3D).mesh
		m2.position = (mi as MeshInstance3D).position
		rb.add_child(m2)
		var a := BodyCut.aabb_of((mi as MeshInstance3D).mesh)
		a.position += (mi as MeshInstance3D).position
		aabb = a if first else aabb.merge(a)
		first = false
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new(); bx.size = Vector3(maxf(aabb.size.x, 0.3), maxf(aabb.size.y, 0.05), maxf(aabb.size.z, 0.3))
	cs.shape = bx; cs.position = aabb.get_center()
	rb.add_child(cs)
	get_parent().add_child(rb)
	rb.global_transform = bonnet_pivot.global_transform
	rb.global_position += global_transform.basis.x * (float(def.ext[2]) * 0.5 + 1.0) + Vector3.UP * 0.2
	design["bonnet_off"] = true
	bonnet_pivot.visible = false
	return rb

func refit_bonnet() -> bool:
	for n in get_tree().get_nodes_in_group("physgun"):
		if n.get_meta("bonnet_of", "") == str(def.glb) and (n as Node3D).global_position.distance_to(global_position) < 6.0:
			n.queue_free()
			design["bonnet_off"] = false
			if bonnet_pivot: bonnet_pivot.visible = true
			return true
	return false

## The factory tub off: it's a part now (keep it, swap it onto another ute, scrap it)
func unbolt_tub() -> RigidBody3D:
	var cut := BodyCut.of(str(def.glb))
	var tub := str(design.get("tub", "stock"))
	if not cut.has("tub") or not (tub in ["stock", "swap"]): return null
	var src := str(def.glb) if tub == "stock" else str(design.get("tub_from", ""))
	if src == "": return null
	var pcol := Color.html(str(design.paint_col)) if str(design.get("paint_col", "")) != "" else Color(0, 0, 0, 0)
	var pcs := BodyCut.pieces(src, true, false, pcol)
	var rb := RigidBody3D.new()
	rb.mass = 110.0
	rb.add_to_group("physgun")
	rb.set_meta("tub_of", src)
	var aabb := AABB(); var first := true
	for am in pcs.tub:
		var mi := MeshInstance3D.new(); mi.mesh = am
		rb.add_child(mi)
		aabb = BodyCut.aabb_of(am) if first else aabb.merge(BodyCut.aabb_of(am))
		first = false
	if first: return null
	_loose_shapes(rb, aabb, float(design.cab_offset[1]), false)
	rb.set_meta("forge_name", "Tub")
	get_parent().add_child(rb)
	var off: Array = design.cab_offset
	# 0.2.66: it stays where it was, sitting loose on the rails: lift it off (forklift, hoist) or drag it away
	rb.global_transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(off[0], off[1], off[2]))
	design["tub"] = "none"
	rebuild_body()
	return rb

## Bolt a loose tub on: this model's own goes back on as factory; another model's (0.2.56) sits behind the cab
func bolt_tub() -> bool:
	if not BodyCut.of(str(def.glb)).has("tub") or str(design.get("tub", "stock")) in ["stock", "swap"]: return false
	var best: Node3D = null
	for n in get_tree().get_nodes_in_group("physgun"):
		if str(n.get_meta("tub_of", "")) == "": continue
		# 0.2.66: only one sat down on the rails where it goes (lowered on with the forklift or the hoist)
		if seated(n as Node3D, 0.3, 0.12): best = n
	if best == null: return false
	var src := str(best.get_meta("tub_of"))
	best.queue_free()
	if src == str(def.glb):
		design["tub"] = "stock"
	else:
		design["tub"] = "swap"
		design["tub_from"] = src
	rebuild_body()
	return true

# ---------------------------------------------------------------- 0.2.66: unbolting the body, bolting it back on
## Where the body sits on this chassis, in the world
func body_xform() -> Transform3D:
	var off: Array = design.cab_offset
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(off[0], off[1], off[2]))

## Is this loose piece sat on the rails where it bolts (within tol m sideways and along, up to the height, ~8 degrees)
func seated(n: Node3D, tol: float, htol: float) -> bool:
	if n == null or not is_instance_valid(n): return false
	var rel := body_xform().affine_inverse() * n.global_transform
	var o := rel.origin
	if Vector2(o.x, o.z).length() > tol or absf(o.y) > htol: return false
	return rel.basis.y.dot(Vector3.UP) > 0.99 and rel.basis.z.dot(Vector3.BACK) > 0.99

## Collision for a loose body or tub: a box from just above the rails (it sits on four mount pads, 7 cm up, so forks
## can slide in between) to its waist, and four pads over the rails. aabb in body space; y0 = cab offset height
func _loose_shapes(rb: RigidBody3D, aabb: AABB, y0: float, roofed := true) -> void:
	BodyCut.loose_shapes(rb, aabb, float(design.ride), y0, float(design.frame.width), roofed)

## The whole body off the chassis: it stays sat where it was, a heavy loose thing on its mounts, and the car is a
## rolling chassis. Lift it off with the forklift or a chain hoist.
func unbolt_body() -> RigidBody3D:
	if design.get("no_cab", false): return null
	var holder := get_node_or_null("Cab") as Node3D
	if holder == null: return null
	var rb := RigidBody3D.new()
	rb.mass = clampf(float(def.get("kg", 1200)) * 0.3, 140.0, 650.0)
	rb.add_to_group("physgun")
	rb.add_to_group("loose_bodies")
	rb.set_meta("body_of", kind)
	rb.set_meta("forge_name", str(def.name) + " body")
	var keep := {}
	for k in ["tub", "tub_from", "tub_h", "bonnet_off", "tray"]:
		if design.has(k): keep[k] = design[k]
	rb.set_meta("body_state", keep)
	var aabb := AABB(); var first := true
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		var m2 := MeshInstance3D.new(); m2.mesh = (mi as MeshInstance3D).mesh
		m2.material_override = (mi as MeshInstance3D).material_override
		var xf: Transform3D = holder.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform
		m2.transform = xf
		rb.add_child(m2)
		if mi.name == "EngineBay": continue
		var a: AABB = xf * BodyCut.aabb_of((mi as MeshInstance3D).mesh)
		aabb = a if first else aabb.merge(a)
		first = false
	if first: return null
	_loose_shapes(rb, aabb, float(design.cab_offset[1]))
	get_parent().add_child(rb)
	rb.global_transform = holder.global_transform
	design["no_cab"] = true
	rebuild_body()
	return rb

## A loose body sat on the mounts (lowered on square, within 25 cm): bolt it down. Another model's body goes on too:
## the car is rebuilt with it.
func bolt_body() -> bool:
	if not design.get("no_cab", false): return false
	for n in get_tree().get_nodes_in_group("loose_bodies"):
		if not seated(n as Node3D, 0.25, 0.15): continue
		var k := str(n.get_meta("body_of", kind))
		var st: Dictionary = n.get_meta("body_state", {})
		n.queue_free()
		design["no_cab"] = false
		for key in st: design[key] = st[key]
		if k == kind:
			rebuild_body()
			if not has_meta("container"):
				set_meta("container", storage_key(def))
				set_meta("empty", true)
		else:
			var d2 := design.duplicate(true)
			d2["cab"] = k
			var c2: Car = get_parent().spawn_vehicle(k, global_position, rotation.y, d2) if get_parent().has_method("spawn_vehicle") else null
			if c2:
				c2.global_transform = global_transform
				queue_free()
		return true
	return false

# ---------------------------------------------------------------- 0.2.70: your own parts off and on this car
## [[label, name, on]] for every part painted on this body in Body tools (not the ones taken off every car of it)
func own_parts() -> Array:
	var out := []
	var parts: Array = BodyCut.of(str(def.glb)).get("parts", [])
	var off: Array = design.get("parts_off", [])
	for i in parts.size():
		if bool((parts[i] as Dictionary).get("off", false)): continue
		out.append([4 + i, str((parts[i] as Dictionary).get("name", "part")), not off.has(4 + i)])
	return out

## Unbolt one: it comes off as a loose part beside the car
func take_off_part(label: int) -> RigidBody3D:
	var off: Array = design.get("parts_off", []).duplicate()
	if off.has(label): return null
	var rb := BodyCut.part_body(str(def.glb), "acc", label)
	if rb == null: return null
	for pp in own_parts():
		if int(pp[0]) == label: rb.set_meta("forge_name", str(pp[1]))
	get_parent().add_child(rb)
	# where it was on the car, then moved out to the side so it isn't inside the body
	rb.global_transform = body_xform()
	var side := global_basis.x * (float(def.ext[2]) * 0.5 + 0.8)
	rb.global_position += side + Vector3.UP * 0.15
	off.append(label)
	design["parts_off"] = off
	rebuild_body()
	return rb

## A loose one of this body's parts close by goes back on
func loose_part_near(label: int) -> RigidBody3D:
	for n in get_tree().get_nodes_in_group("physgun"):
		if str(n.get_meta("part_of", "")) == str(def.glb) and int(n.get_meta("part_label", -1)) == label and (n as Node3D).global_position.distance_to(global_position) < 5.0:
			return n
	return null

func fit_part(label: int) -> bool:
	var rb := loose_part_near(label)
	var off: Array = design.get("parts_off", []).duplicate()
	if rb == null or not off.has(label): return false
	rb.queue_free()
	off.erase(label)
	design["parts_off"] = off
	rebuild_body()
	return true

# ---------------------------------------------------------------- 0.2.68: the engine out as a lump
## Can the engine come out the top: bonnet off (or no bonnet panel cut, with the body off), the engine in it
func engine_out_ok() -> String:
	if parts == null or parts.engine_node == null: return "There's no engine in it."
	if design.get("no_cab", false): return ""
	if bonnet_pivot != null and design.get("bonnet_off", false): return ""
	if bonnet_pivot != null: return "Take the bonnet off first."
	return "Cut the bonnet in Body tools (or lift the body off) to get it out the top."

## Unbolted, the engine stays sat in the bay as a loose lump until a chain or strap pulls it out
func unbolt_engine() -> LooseLump:
	if engine_out_ok() != "": return null
	var k: Dictionary = design.get("kit", {})
	if str(k.get("block", "")) == "": return null
	var en: Node3D = parts.engine_node
	var lump := LooseLump.new()
	var vis := EngineKit.build_node(k)
	lump.add_child(vis)
	get_parent().add_child(lump)
	lump.global_transform = en.global_transform
	lump.setup(self, k.duplicate(true))
	# its box: from the engine as it sat (the kit's meshes come a frame later, so the size is measured on the car's)
	var ab: AABB = parts._aabb_of(en, Transform3D.IDENTITY)          # car frame
	var inv := en.transform.affine_inverse()
	var la: AABB = inv * ab
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new(); bx.size = la.size.max(Vector3(0.2, 0.2, 0.2)) * 0.96
	cs.shape = bx; cs.position = la.get_center()
	lump.add_child(cs)
	design.kit = {"block": "", "heads": [], "exhaust": [], "intake": "", "fuel": "", "ign": "", "ecu": "", "alt": false, "rolled": true}
	refresh_engine()
	return lump

## Where an engine sits in this car (car frame): over the front axle, as the rig puts one
func engine_home() -> Vector3:
	var fz: float = design.axles[0].z
	return Vector3(0, parts.frame_y + 0.4, fz - 0.4)

## A loose engine lowered back into the bay: bolt it in
func bolt_engine(lump: LooseLump) -> bool:
	if lump == null or not is_instance_valid(lump): return false
	if str(design.get("kit", {}).get("block", "")) != "": return false
	var l := to_local(lump.global_position)
	var h := engine_home()
	if absf(l.x) > 0.45 or absf(l.z - h.z) > 0.9 or l.y > h.y + 0.6 or l.y < h.y - 0.7: return false
	design.kit = lump.kit.duplicate(true)
	lump.queue_free()
	refresh_engine()
	return true

func loose_body_seated() -> bool:
	for n in get_tree().get_nodes_in_group("loose_bodies"):
		if seated(n as Node3D, 0.25, 0.15): return true
	return false

func loose_tub_seated() -> bool:
	for n in get_tree().get_nodes_in_group("physgun"):
		if str(n.get_meta("tub_of", "")) != "" and seated(n as Node3D, 0.3, 0.12): return true
	return false

## A spanner job on the car (body mounts): it takes a while, and you have to stay by it
var _job := {}
func start_job(label: String, mounts: int, secs_each: float, who: Node3D, done: Callable) -> void:
	_job = {"label": label, "n": mounts, "each": secs_each, "t": 0.0, "who": who, "done": done, "last": -1}
	if who and who.has_method("_toast"): who._toast("%s... 0/%d" % [label, mounts])

func _job_tick(dt: float) -> void:
	var who: Node3D = _job.who
	if who == null or not is_instance_valid(who) or who.global_position.distance_to(global_position) > 4.5 or linear_velocity.length() > 0.5:
		if who and is_instance_valid(who) and who.has_method("_toast"): who._toast("Left it half done.")
		_job = {}
		return
	_job.t += dt
	var k := int(_job.t / float(_job.each))
	if k != int(_job.last):
		_job.last = k
		if k < int(_job.n) and who.has_method("_toast"): who._toast("%s... %d/%d" % [_job.label, k, _job.n])
	if k >= int(_job.n):
		var cb: Callable = _job.done
		_job = {}
		cb.call()

func build_tray(cfg := {}) -> void:
	if not BodyCut.of(str(def.glb)).has("tub"): return
	design["tub"] = "tray"
	if not cfg.is_empty(): design["tray"] = cfg
	rebuild_body()

var _lamp_state := -1
var _bonnet_front := -1
## Bonnet, tray sides, box and canopy doors swinging; tray brake lights and sequential indicators (0.2.55)
func _body_anim(dt: float) -> void:
	if bonnet_pivot != null:
		bonnet_open = move_toward(bonnet_open, bonnet_want, dt * 1.6)
		# 0.2.68: the hinge side is looked up once per body (BodyCut.of() hashed the whole paint every frame per car)
		if _bonnet_front < 0: _bonnet_front = 1 if str(BodyCut.of(str(def.glb)).get("bonnet", {}).get("hinge", "rear")) == "front" else 0
		bonnet_pivot.rotation.x = -deg_to_rad(58.0) * smoothstep(0.0, 1.0, bonnet_open) * (-1.0 if _bonnet_front == 1 else 1.0)
	if not lamps.is_empty():
		var lit0 := not lights.is_empty() and lights[0].visible
		var brk0 := brake_in > 0.1 and driver != null
		var lk := int(lit0) * 2 + int(brk0)
		if lk != _lamp_state:
			_lamp_state = lk
			Lamps.set_lit(lamps, lit0, brk0)
	if tray.is_empty(): return
	_side_t = move_toward(_side_t, 1.0 if sides_down else 0.0, dt * 2.0)
	_door_t = move_toward(_door_t, 1.0 if doors_open else 0.0, dt * 1.5)
	for piv in tray.sides:
		var ax: Vector3 = piv.get_meta("hinge_axis"); var sg: float = piv.get_meta("drop_sign")
		piv.basis = Basis(ax, sg * deg_to_rad(95.0) * smoothstep(0.0, 1.0, _side_t))
	for piv in tray.doors:
		var ax: Vector3 = piv.get_meta("hinge_axis"); var sg: float = piv.get_meta("drop_sign")
		piv.basis = Basis(ax, sg * deg_to_rad(80.0) * smoothstep(0.0, 1.0, _door_t))
	var braking := brake_in > 0.1 and driver != null
	var lit := not lights.is_empty() and lights[0].visible
	for lm in tray.brake: (lm as StandardMaterial3D).emission_energy_multiplier = 3.0 if braking else (0.8 if lit else 0.0)
	if not tray.seq.is_empty():
		_seq_t += dt
		var sweeping := handbrake and running
		for e in tray.seq:
			var on: bool = sweeping and fmod(_seq_t, 0.8) > 0.12 * float(e[1])
			(e[0] as StandardMaterial3D).emission_energy_multiplier = 3.0 if on else 0.0

## A part went on or came off the engine: new numbers, new look (0.2.55)
func refresh_engine() -> void:
	if design.has("kit") and str(design.kit.get("block", "")) != "":
		eng = EngineKit.stats(design.kit)
	if parts and parts.has_method("rebuild_engine"): parts.rebuild_engine()
	var f := EngineKit.fault(design.get("kit", {}))
	if f != "" and running:
		running = false

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
			l.shadow_enabled = driver is Player          # 0.2.68: only your own beams throw shadows
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
var _why_t := 0.0
func _physics_process(dt: float) -> void:
	var _pt := Prof.t()
	if get_meta("lod_parked", false):
		_lod_check(dt)
	else:
		_physics_process_inner(dt)
		_lod_rest(dt)
	Prof.add("car physics", _pt)

## 0.2.55: a car sitting still with nobody in it and nobody near is parked out of the physics (frozen solid, still
## there to hit and loot) until someone or something moving comes within 40 m. Ten parked cars were 8 ms a frame.
var _rest_t := 0.0
var _lod_t := 0.0
func _lod_rest(dt: float) -> void:
	if freeze or driver != null or _tow or linear_velocity.length_squared() > 0.01 or angular_velocity.length_squared() > 0.01:
		_rest_t = 0.0
		return
	_rest_t += dt
	# 0.2.56: look round for company twice a second, not every physics frame (with a town full of still cars near
	# you that was every car checking every other car, 60 times a second)
	if _rest_t > 2.5:
		_lod_t -= dt
		if _lod_t > 0.0: return
		_lod_t = 0.5 + randf() * 0.2
		if not _active_near(20.0, 0.9):
			_rest_t = 0.0
			set_meta("lod_parked", true)
			freeze = true

## Out of the parked sleep (a strap pulling on it, 0.2.68)
func wake() -> void:
	if get_meta("lod_parked", false) or freeze:
		set_meta("lod_parked", false)
		freeze = false
		_rest_t = 0.0

func _lod_check(dt: float) -> void:
	_lod_t -= dt
	if _lod_t > 0.0 and driver == null: return
	_lod_t = 0.2
	if driver != null or not freeze or _active_near(10.0, 0.9):
		set_meta("lod_parked", false)
		freeze = false
		_rest_t = 0.0

## Anyone (on foot, driving, flying the Forge) within r metres, counting how far they'll come in `ahead` seconds
func _active_near(r: float, ahead := 0.0) -> bool:
	var m = get_tree().current_scene
	var who: Array = []
	if m and m.get("net") and m.net and m.net.online(): who = m.net.all_players()
	elif m and m.get("player") and m.player: who = [m.player]
	for pl in who:
		if not is_instance_valid(pl): continue
		var v: Vector3 = (pl.vehicle as RigidBody3D).linear_velocity if pl.get("vehicle") != null else Vector3.ZERO
		if (pl as Node3D).global_position.distance_to(global_position) - v.length() * ahead < r: return true
	if m and m.get("forge") and m.forge and m.forge.active and m.forge.cam.global_position.distance_to(global_position) < maxf(r, 25.0):
		return true
	for c in get_tree().get_nodes_in_group("vehicles"):
		if c == self or c.get("driver") == null: continue
		if (c as Node3D).global_position.distance_to(global_position) - (c as RigidBody3D).linear_velocity.length() * ahead < r: return true
	return false

func _physics_process_inner(dt: float) -> void:
	if running and driver: CarCare.burn(self, dt, throttle)
	if home_pos == Vector3.ZERO:
		home_pos = global_position
	if freeze:
		return
	if driver == null and Time.get_ticks_msec() - int(get_meta("stood_t", -100000)) < 400:
		angular_velocity = angular_velocity.limit_length(0.5)
		linear_velocity.y = clampf(linear_velocity.y, -6.0, 0.6)
	_read_controls(dt)
	# climb in and it cranks and catches; climb out and it's switched off
	if driver and not running:
		var why := CarCare.blocked(self)
		if why != "":
			crank = 0.0
			_why_t -= dt
			if _why_t <= 0.0 and driver.has_method("_toast"):
				_why_t = 4.0
				driver._toast(why)
		else:
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
		w.Lg_prev = w.Lg
		if hit:
			var d: float = (top + up * 0.15).distance_to(hit.position) - 0.15
			# 0.2.72: soft ground (mud, sand): the tyre rides down in the ruts it's pressed
			w.soft = null
			var hc = hit.collider
			if hc and hc.has_meta("soft_ground"):
				w.soft = hc.get_meta("soft_ground")
				d += (w.soft as SoftGround).depth_at(hit.position)
			var r_eff: float = w.r - w.defl                          # the tyre squats under load
			w.L = clamp(d - r_eff, -0.05, w.T)
			w.Lg = clamp(d - w.r, -0.15, w.T)
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
			w.Lg = w.T
		arb_c[str(w.axle) + str(w.side)] = w.T - w.L
	for w in wheels:
		w.N = 0.0
		if not w.contact:
			continue
		var comp: float = w.T - w.L
		# + = compressing. 0.2.67: from the hub's travel without the tyre's squat; with it in, the damper saw every
		# change in squat as a jolt and the load flipped between the axles every step (a parked car chattered, and
		# anything sat loose on one walked off)
		var vel: float = (w.Lg_prev - w.Lg) / dt
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
		# 0.2.72: on soft ground the tyre presses it down (and digs if it spins); deep enough and the axle bellies out
		if w.soft != null and is_instance_valid(w.soft):
			var slip_v: float = float(w.omega) * float(w.r) - float(w.get("vx", 0.0))
			w.sink = (w.soft as SoftGround).press(w.point, w.N, float(design.get("tyre_psi", 32.0)), w.r, float(w.r) * 0.72, slip_v, dt)
			var clear: float = float(w.r) - (0.13 if str(w.a.get("type", "")) == "live" else 0.07)
			w.belly = clampf((w.sink - clear) / 0.06, 0.0, 1.0)
		else:
			w.sink = 0.0
			w.belly = 0.0
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
			# 0.2.66: rear steer (the forklift) turns the other way and further
			var sk := float(w.a.get("steer_k", 1.0))
			if sk < 0.0:        # it'd tip over on full lock at a run, like a real one: the lock comes off above walking pace
				sk *= clampf(1.15 - absf(linear_velocity.dot(global_transform.basis.z)) / 7.0, 0.3, 1.0)
			w.steer = steer_l * ack * sk
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

## 0.2.68: a strap from this car to another car: it's on tow, handbrake off, in neutral (checked twice a second)
var _tow_t := 0.0
var _tow := false
func _on_tow() -> bool:
	var now := Time.get_ticks_msec() * 0.001
	if now - _tow_t > 0.5:
		_tow_t = now
		_tow = false
		for st in get_tree().get_nodes_in_group("straps"):
			var s2 := st as Strap
			if s2.touches(self) and ((s2.a_node is Car and s2.a_node != self) or (s2.b_node is Car and s2.b_node != self)): _tow = true
	return _tow

## Parked with nobody in it, the handbrake holds it where it stopped (the tyre model alone lets it creep down a
## slope a few millimetres a frame). Something big shoving it (more than the tyres could hold) moves it on.
func _park_hold() -> void:
	var hv := linear_velocity
	if driver != null or hv.length() > 1.5 or _on_tow():
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
		thr = Input.get_action_strength("move_forward") * CarCare.power(self)
		brk = Input.get_action_strength("move_back")
		steer_in = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		handbrake = Input.is_action_pressed("brake")
	# throttle filter: a keyboard is all or nothing, so the pedal goes down over about half a second (quicker the
	# further it's already in) and comes up fast. Shift held with W floors it at once, for a burnout.
	var floor_it := driver != null and thr > 0.0 and Input.is_action_pressed("sprint")
	# 0.2.59: without Shift the foot feathers it: the moment a driven tyre starts to spin it comes back off and holds
	# just under where it broke loose, feeling for more as the speed comes up (on any ground). Shift floors it.
	var feather := not floor_it and thr > 0.0 and bool(Settings.get_v("traction_foot") if Settings.get_v("traction_foot") != null else true)
	var spinning := false
	if feather:
		for w in wheels:
			if w.a.drive and w.contact and float(w.get("sr", 0.0)) > 0.16: spinning = true
		if spinning:
			if not _thr_spun: _thr_lim = maxf(throttle * 0.85, 0.08)
			throttle = move_toward(throttle, _thr_lim * 0.7, 6.0 * dt)
		else:
			_thr_lim = move_toward(_thr_lim, 1.0, 0.35 * dt)
	elif thr <= 0.0:
		_thr_lim = 1.0
	_thr_spun = spinning
	var thr_want: float = minf(thr, _thr_lim) if feather else thr
	if floor_it: throttle = thr
	elif spinning: pass
	elif thr_want > throttle: throttle = move_toward(throttle, thr_want, (1.6 + 2.4 * throttle) * dt)
	else: throttle = move_toward(throttle, thr_want, 6.0 * dt)
	# brake pedal (0.2.58): a keyboard is all or nothing, and every set of brakes here can lock its tyres (they could
	# all along: 2400 Nm a front wheel against the ~1100 Nm a loaded front tyre holds on bitumen). So S is a driver
	# squeezing the pedal on and easing off the moment a wheel starts to lock, the way you brake an old car with no
	# ABS: firm stops near the limit on any ground. Shift+S stomps it: everything locks and slides.
	var stomp := driver != null and brk > 0.0 and Input.is_action_pressed("sprint")
	if stomp:
		brake_in = brk
	elif brk > 0.0:
		var locking := false
		for w in wheels:
			if w.contact and absf(w.vx) > 1.5 and float(w.get("sr", 0.0)) < -0.2: locking = true
		# the foot remembers where the wheels locked and holds just under it, feeling for more as the load comes on
		if locking:
			if not _brake_locked: _brake_lim = brake_in * 0.9      # where it locked, once per lock-up
			brake_in = move_toward(brake_in, 0.0, 5.0 * dt)         # off it until the wheel turns again
		else:
			_brake_lim = move_toward(_brake_lim, 1.0, 0.3 * dt)
			brake_in = move_toward(brake_in, minf(brk, _brake_lim), 3.0 * dt)
		_brake_locked = locking
	else:
		brake_in = move_toward(brake_in, 0.0, 8.0 * dt)
		_brake_lim = 1.0
		_brake_locked = false
	var v: float = abs(linear_velocity.dot(global_transform.basis.z))
	# steering filter: the lock you can use falls with speed so the fronts stay near their best slip angle instead
	# of being thrown past it (that's the instant understeer): the angle that asks for about 0.9 g of cornering at
	# this speed, plus a little slip, never more than full lock. The wheel also winds on slower the faster you go,
	# and comes back to centre a bit quicker than it goes out.
	if _wb <= 0.0:
		var zs := []
		for w in wheels: zs.append(float(w.mount.z))
		_wb = maxf(2.0, zs.max() - zs.min()) if not zs.is_empty() else 2.7
	var grip_lock := atan(_wb * 8.8 / maxf(v * v, 1.0)) + 0.07
	var max_steer: float = clampf(grip_lock, 0.12, 0.62)
	var k := clampf(v / 30.0, 0.0, 1.0)
	var rate := lerpf(2.0, 0.7, k) if steer_in != 0.0 and signf(steer_in) == signf(steer_now) or steer_now == 0.0 else lerpf(3.2, 1.6, k)
	var want := steer_in * max_steer
	# drift assist (0.2.59, like BeamNG's): once the car's sliding, the front wheels follow the way the front is
	# actually travelling (the countersteer you'd wind on), and what you steer is added on top, up to full lock
	var da = Settings.get_v("drift_assist")
	if driver and (da == null or bool(da)) and v > 4.0:
		var xf := global_transform
		var front_z := -INF
		for w in wheels: front_z = maxf(front_z, float(w.mount.z))
		var vf: Vector3 = linear_velocity + angular_velocity.cross(xf.basis * Vector3(0, 0, front_z) - xf.basis * center_of_mass)
		var lz := vf.dot(xf.basis.z)
		if lz > 2.0:
			var align := atan2(vf.dot(xf.basis.x), lz)
			var beta := absf(atan2(linear_velocity.dot(xf.basis.x), maxf(linear_velocity.dot(xf.basis.z), 0.5)))
			var k2 := smoothstep(0.06, 0.2, beta)
			if k2 > 0.0:
				want = clampf(lerpf(want, align + steer_in * 0.62 * 0.6, k2), -0.62, 0.62)
				rate = maxf(rate, lerpf(rate, 5.0, k2))
	steer_now = move_toward(steer_now, want, rate * dt)
	if driver == null:
		throttle = 0.0
		handbrake = not _on_tow()          # 0.2.68: on a tow strap it rolls free

## Grip by ground: [peak mu, sliding / peak, rolling resistance, kind]. Terrain by its texture slot (main.GROUND).
## Loose stuff grips a lot less than bitumen and gives up more once the tyre's spinning (grass polishes, mud smears).
# [peak grip, share of it left when sliding, rolling drag, kind]: grass grips (it's slower, not ice)
const TERRAIN_SURF := [
	[0.8, 0.8, 0.085, "grass"],    # pasture
	[0.78, 0.8, 0.08, "dirt"],     # forest floor
	[0.74, 0.78, 0.08, "dirt"],    # cane trash
	[0.76, 0.8, 0.09, "dirt"],     # farm soil
	[0.6, 0.82, 0.13, "sand"],     # sand
	[0.7, 0.72, 0.02, "rock"],     # mossy rock
	[0.88, 0.76, 0.013, "seal"],   # concrete
	[0.45, 0.68, 0.14, "mud"],     # river mud
	[0.78, 0.8, 0.08, "grass"],    # rough grass
]
var _terrain: Terrain3D

func _surface(w: Dictionary) -> void:
	var c = w.collider
	var surf: Array = [0.85, 0.75, 0.02, "seal"]      # props, other cars, buildings: hard
	if c and c.has_meta("soft_ground"):
		surf = (c.get_meta("soft_ground") as SoftGround).surface(tread_k(), float(w.sink), float(w.r))
		surf[2] = float(surf[2]) + 0.6 * float(w.belly)            # bellied out: dragging the diff through it
	elif c and c.is_in_group("road"):
		surf = [0.95, 0.76, 0.013, "seal"]
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
		# the road skin has no collision: on the seal if the road mask says so
		var m2 = get_tree().current_scene
		if m2 and m2.get("roads") and m2.roads.has_method("on_road") and m2.roads.on_road(w.point.x, w.point.z):
			surf = [0.95, 0.76, 0.013, "seal"]
	elif c and (c.is_in_group("corpses") or c is PhysicalBone3D or (c is RigidBody3D and (c as RigidBody3D).mass < 120.0)):
		surf = [0.35, 0.6, 0.02, "flesh"]
	# tyre pressure: soft tyres bag out and grip loose ground better, roll heavier; hard ones skate on it
	var psi: float = float(design.get("tyre_psi", 32.0))
	var soft: float = clamp((32.0 - psi) / 20.0, -1.0, 1.0)
	var loose: bool = surf[3] in ["grass", "dirt", "sand", "mud"]
	w.mu = float(surf[0]) * (1.0 + (0.22 * soft if loose else -0.06 * abs(soft)))
	if SkyCycle.inst and SkyCycle.inst.wet > 0.0:
		w.mu *= 1.0 - SkyCycle.inst.wet * (0.18 if loose else 0.12)      # wet seal and wet grass both give less
	w.slide = float(surf[1])
	w.crr = float(surf[2]) * (1.0 + 0.5 * max(soft, 0.0))
	w.kind = surf[3]

## 0.2.72: how much bite the tread has in mud: mud terrains and tractor lugs 1, the 4x4 steelies' all-terrains 0.6,
## road tyres 0.25
var _tread := -1.0
func tread_k() -> float:
	if _tread >= 0.0: return _tread
	var wm := str(design.get("wheel_model", "stock"))
	for a in design.axles:
		var aw := str((a as Dictionary).get("wheel_model", ""))
		if aw != "": wm = aw
	var big: bool = float(design.axles[0].tyre_r) > 0.36
	if wm.contains("mt") or wm.contains("lug") or wm.begins_with("r6") or wm.begins_with("tractor"): _tread = 1.0
	elif wm == "rim4x4" or (wm == "stock" and big): _tread = 0.6
	else: _tread = 0.25
	return _tread

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
		for w in wheels: w.dN = 0.0
		for ai in axles_d:
			var pair := driven.filter(func(w): return w.axle == ai)
			var kind_d: String = pair[0].a.get("diff", "open")
			# a live axle's pinion torque tries to roll the housing: it loads one rear tyre and lifts the other
			# (the one-wheel peel: an open diff spins the light side and the loaded one keeps the car straight)
			if str(pair[0].a.get("type", "live")) == "live" and not pair[0].a.steer and R != 0.0:
				var t_ds: float = t_c * absf(R) / maxf(float(design.get("final", 3.5)), 1.0)
				var dn: float = clampf(t_ds / maxf(2.0 * float(pair[0].a.track), 0.8), -2500.0, 2500.0) * signf(R)
				for w in pair: w.dN = float(w.side) * dn
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
			# the proportioning valve: the light end gets less line pressure, so the rears don't lock first as the
			# weight comes forward under brakes
			if w.contact: tb *= clampf(w.N / maxf(float(w.Ns), 1.0), 0.35, 1.25)
			if handbrake and not w.a.steer: tb = max(tb, 3500.0)
			if gear == 0 and box.auto and w.a.drive and not _tow: tb = max(tb, 6000.0)        # park pawl
			if driver == null and not _tow: tb = max(tb, 1500.0)        # nobody in it: left in gear with the handbrake on (no wheel turning by itself)
			var fx := 0.0
			var fy := 0.0
			if w.contact and w.N > 0.0:
				var Ne: float = clampf(w.N + float(w.get("dN", 0.0)), w.N * 0.15, w.N * 1.85)
				var muN: float = w.mu * Ne * (1.0 - 0.7 * float(w.belly))       # 0.2.72: the axle's carrying it, not the tyre
				var vref: float = max(abs(w.vx), 1.5)
				var sr: float = (w.omega * w.r - w.vx) / vref
				var sa: float = atan2(w.vy, max(abs(w.vx), 1.0))
				# combined slip (0.2.58): one grip budget shared by how hard the tyre's spinning (or locked) and how
				# far it's sliding sideways, each measured against its own peak (12% slip, 8 degrees). The force
				# points along that combined slip, so a tyre that's lit up has almost nothing left sideways: the tail
				# steps out under power until the wheels slow to road speed and it bites and straightens. A locked
				# tyre won't steer. (It used to keep 70% of its side grip however hard it spun.)
				var nx: float = sr / 0.12
				var ny: float = tan(clampf(sa, -1.4, 1.4)) / 0.14
				var rho: float = sqrt(nx * nx + ny * ny)
				if rho > 0.0001:
					var f: float
					if rho <= 1.0: f = 1.0 - pow(1.0 - rho, 3.0)
					else: f = lerpf(1.0, w.slide, smoothstep(1.0, 6.0, rho))        # past the peak: sliding
					fx = muN * f * nx / rho
					fy = -muN * f * ny / rho
				var lowspd: float = clamp(1.0 - (abs(w.vx) + abs(w.vy)) / 2.5, 0.0, 1.0)
				fy = lerpf(fy, clamp(-w.vy * w.N * 0.9, -muN, muN), lowspd)       # don't skate about when stopped
				var mag := sqrt(fx * fx + fy * fy)
				if mag > muN:                                     # friction circle
					fx *= muN / mag
					fy *= muN / mag
				fx -= sign(w.vx) * w.N * w.crr * clamp(abs(w.vx), 0.0, 1.0)
			# 0.2.59: a big wheel's heavier (a tractor's rear is ~40 kg m2), and the tyre can pull the wheel to rolling
			# speed but not past it in one step (big, heavily loaded wheels shook back and forth at a standstill, which
			# read as wheelspin)
			var I_w: float = WHEEL_I * pow(float(w.r) / 0.33, 3.0)
			var om_d: float = w.omega + h * t_drive / I_w
			var om: float = om_d - h * fx * w.r / I_w
			if w.contact:
				var w0: float = w.vx / maxf(float(w.r), 0.05)
				if (om_d - w0) * (om - w0) < 0.0: om = w0
			# brakes act against spin but never reverse it
			var db: float = h * tb / I_w
			if abs(om) <= db: om = 0.0
			else: om -= sign(om) * db
			if not w.contact:
				om *= 0.995
			w.omega = om
			w.fx += fx / SUBSTEPS
			w.fy += fy / SUBSTEPS
			if s == SUBSTEPS - 1:
				w.slipv = Vector2(w.omega * w.r - w.vx, w.vy).length() if w.contact else 0.0
				w.sr = (w.omega * w.r - w.vx) / maxf(absf(w.vx), 1.5) if w.contact else 0.0
		# wheels on the ground that are free (no drive, no brake) follow the road closely
	rpm = w_eng * 60.0 / TAU
	engine_load = load_acc / SUBSTEPS

# ---------------------------------------------------------------- cameras
func _process(dt: float) -> void:
	if not _job.is_empty(): _job_tick(dt)
	for w in wheels:
		w.spin = fmod(w.spin + w.omega * dt, TAU)
	_body_anim(dt)
	_smoke(dt)
	_roost(dt)
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
	if cam_chase.global_position.distance_to(want) > 30.0: cam_chase.global_position = want      # never a long flight in
	cam_chase.global_position = cam_chase.global_position.lerp(want, clamp(9.0 * dt, 0, 1))
	cam_chase.look_at(target, Vector3.UP)


# ------------------------------------------------------------------ rooster tails (0.2.72)
## Spinning (or fast) tyres on mud, sand and loose ground throw it up behind them: clods and spray off the tread,
## up and back in the direction the tyre's turning, as much as it's slipping
var _roost_p: Array = []
static var _roost_mat: StandardMaterial3D
func _roost(dt: float) -> void:
	if _roost_p.is_empty():
		var any := false
		for w in wheels:
			if w.contact and (w.soft != null or str(w.kind) in ["mud", "sand", "dirt"]): any = true
		if not any: return
		for w in wheels: _roost_p.append(_roost_make())
	for i in wheels.size():
		var w: Dictionary = wheels[i]
		var p: CPUParticles3D = _roost_p[i]
		var soft: bool = w.soft != null and is_instance_valid(w.soft)
		var loose: bool = soft or str(w.kind) in ["mud", "sand", "dirt"]
		var surf_v: float = float(w.omega) * float(w.r)              # the tread's speed
		var slip: float = absf(surf_v - float(w.vx))
		var k := 0.0
		if w.contact and loose:
			k = clampf(slip / 6.0, 0.0, 1.0) + clampf(absf(surf_v) / 25.0, 0.0, 0.35)
			if not soft: k *= 0.45
		p.emitting = k > 0.12
		if not p.emitting: continue
		var col: Color
		if soft: col = SoftGround.TYPES[(w.soft as SoftGround).kind].spray
		elif str(w.kind) == "sand": col = Color(0.8, 0.7, 0.52)
		elif str(w.kind) == "mud": col = Color(0.24, 0.17, 0.1)
		else: col = Color(0.42, 0.33, 0.22)
		p.color = col
		var fwd: Vector3 = w.fwd
		var back := -fwd * signf(surf_v if absf(surf_v) > 0.1 else 1.0)
		p.global_position = (w.point as Vector3) + back * float(w.r) * 0.5 + Vector3.UP * 0.05
		p.direction = (back + Vector3.UP * 0.75).normalized()
		var sp := clampf(absf(surf_v) * 0.55, 2.0, 16.0)
		p.initial_velocity_min = sp * 0.55
		p.initial_velocity_max = sp
		# mud comes off in clods, sand in a finer spray
		p.scale_amount_min = 0.06 if (soft and (w.soft as SoftGround).kind == "mud") or str(w.kind) == "mud" else 0.035
		p.scale_amount_max = p.scale_amount_min * 2.6

func _roost_make() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 90
	p.lifetime = 1.2
	p.local_coords = false
	p.spread = 16.0
	p.gravity = Vector3(0, -9.8, 0)
	p.damping_min = 0.4; p.damping_max = 1.2
	p.angular_velocity_min = -400.0; p.angular_velocity_max = 400.0
	p.emitting = false
	var qm := BoxMesh.new(); qm.size = Vector3(1, 0.7, 0.8)
	if _roost_mat == null:
		_roost_mat = StandardMaterial3D.new()
		_roost_mat.vertex_color_use_as_albedo = true
		_roost_mat.roughness = 0.9
	qm.material = _roost_mat
	p.mesh = qm
	var sc := Curve.new(); sc.add_point(Vector2(0, 1.0)); sc.add_point(Vector2(1, 0.6)); p.scale_amount_curve = sc
	add_child(p)
	return p

# ------------------------------------------------------------------ diesel smoke (0.2.61)
## A turned-up pump (or too much fuel in the tune) blows black smoke out the back on the throttle, a haze at idle
var _smoke_p: CPUParticles3D
var _smoke_lvl := -1.0
var _smoke_t := 0.0
func _smoke(dt: float) -> void:
	_soot_tick(dt)
	_smoke_t -= dt
	if _smoke_t <= 0.0:
		_smoke_t = 0.5
		_smoke_lvl = EngineKit.smokes(design.get("kit", {})) if design.has("kit") else 0.0
	if _smoke_lvl <= 0.05 or not running:
		if _smoke_p: _smoke_p.emitting = false
		return
	if _smoke_p == null: _smoke_make()
	var ld := clampf(throttle, 0.0, 1.0) * clampf(rpm / maxf(float(eng.get("redline", 4500)), 1000.0) * 1.6, 0.3, 1.0)
	var k := _smoke_lvl * (0.18 + 0.82 * ld)
	_smoke_p.emitting = k > 0.06
	_smoke_p.color = Color(0.07, 0.07, 0.07, clampf(k * 1.3, 0.1, 0.92))
	_smoke_p.initial_velocity_min = 1.0 + 3.0 * ld
	_smoke_p.initial_velocity_max = 2.0 + 5.0 * ld
	_smoke_p.scale_amount_max = 1.0 + 1.6 * k
	# 0.2.72: volumetric soot: puffs of real fog that billow, drift and thin out (Forward+ renderer); the particles
	# stay for the dense bit right at the pipe
	if _soot_vol_ok():
		_soot_acc += dt * (4.0 + 14.0 * ld) * clampf(k, 0.0, 1.2)
		while _soot_acc >= 1.0:
			_soot_acc -= 1.0
			_soot_puff(k, ld)
		_smoke_p.color.a *= 0.55

# volumetric soot (0.2.72)
var _soot: Array = []            # [FogVolume, FogMaterial, age, life, velocity, start size, density]
var _soot_acc := 0.0
static var _soot_until := 0.0
static var _soot_forced := false
static var _vol_checked := false
static var _vol_ok := false

func _exit_tree() -> void:
	for e in _soot:
		if is_instance_valid(e[0]): (e[0] as Node).queue_free()
	_soot.clear()

static func _soot_vol_ok() -> bool:
	if not _vol_checked:
		_vol_checked = true
		_vol_ok = RenderingServer.get_current_rendering_method() == "forward_plus" and OS.get_environment("SOOT_OFF") == ""
	return _vol_ok

func _soot_puff(k: float, ld: float) -> void:
	if _smoke_p == null: return
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	var fm := FogMaterial.new()
	fm.albedo = Color(0.05, 0.05, 0.05)
	fm.edge_fade = 0.8
	fv.material = fm
	get_parent().add_child(fv)
	var origin := _smoke_p.global_position
	var back := -global_basis.z
	var vel := back * (1.2 + 3.5 * ld) + Vector3(randf_range(-0.4, 0.4), 0.5 + randf() * 0.6, randf_range(-0.4, 0.4)) + linear_velocity * 0.6
	fv.global_position = origin + back * 0.2
	var s0 := 0.45 + 0.25 * k
	fv.size = Vector3.ONE * s0
	_soot.append([fv, fm, 0.0, 2.6 + 1.6 * k, vel, s0, clampf(2.5 * k, 0.6, 4.0)])
	if _soot.size() > 28:
		var old: Array = _soot.pop_front()
		if is_instance_valid(old[0]): (old[0] as Node).queue_free()

func _soot_tick(dt: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if not _soot.is_empty():
		_soot_until = now + 1.5
		var keep: Array = []
		for e in _soot:
			var fv: FogVolume = e[0]
			if not is_instance_valid(fv): continue
			e[2] = float(e[2]) + dt
			var t := float(e[2]) / float(e[3])
			if t >= 1.0:
				fv.queue_free()
				continue
			var v: Vector3 = e[4]
			v = v * maxf(0.0, 1.0 - 1.6 * dt) + Vector3(0, 0.55 * dt, 0)        # slows in the air, the heat lifts it
			e[4] = v
			fv.global_position += v * dt
			var sz := lerpf(float(e[5]), 3.4, 1.0 - pow(1.0 - t, 2.0))
			fv.size = Vector3(sz, sz * 0.75, sz)
			(e[1] as FogMaterial).density = float(e[6]) * pow(1.0 - t, 1.6) * pow(float(e[5]) / sz, 1.2)
			keep.append(e)
		_soot = keep
	# the world's volumetric fog has to be on for the puffs to show: switched on while there's soot about (with no
	# fog of its own if you've got it off in the settings) and back off after
	var m = get_tree().current_scene
	if m == null or m.get("env") == null: return
	var env: Environment = m.env
	var setting_on: bool = bool(Settings.get_v("volumetric_fog"))
	if now < _soot_until and not setting_on and not _soot_forced:
		_soot_forced = true
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0
		env.volumetric_fog_length = 64.0
	elif _soot_forced and (now >= _soot_until or setting_on):
		_soot_forced = false
		env.volumetric_fog_density = 0.0035
		env.volumetric_fog_length = 160.0
		env.volumetric_fog_enabled = setting_on

func _smoke_make() -> void:
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 72
	p.lifetime = 2.4
	p.local_coords = false
	p.direction = Vector3(0, 0.25, -1)
	p.spread = 14.0
	p.gravity = Vector3(0, 0.6, 0)
	p.damping_min = 1.2; p.damping_max = 2.2
	p.scale_amount_min = 0.7
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.35)); sc.add_point(Vector2(1, 2.6)); p.scale_amount_curve = sc
	var gr := Gradient.new(); gr.set_color(0, Color(1, 1, 1, 0.9)); gr.set_color(1, Color(1, 1, 1, 0.0)); p.color_ramp = gr
	var qm := QuadMesh.new(); qm.size = Vector2(0.7, 0.7)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gt := GradientTexture2D.new(); gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5)
	var g2 := Gradient.new(); g2.set_color(0, Color(1, 1, 1, 1)); g2.set_color(1, Color(1, 1, 1, 0)); gt.gradient = g2
	m.albedo_texture = gt
	qm.material = m
	p.mesh = qm
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var zr := INF
	for a in design.axles: zr = minf(zr, float(a.z))
	p.position = Vector3(0.45, float(design.get("ride", 0.4)) + 0.05, zr - 1.0)
	add_child(p)
	_smoke_p = p
