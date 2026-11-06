class_name Gun
extends Node3D
## A real gun from the period, used by you and by scavs alike. The model is normalised on load: barrel along -Z,
## the right length, centred on its middle. Grip markers give the hands somewhere to hold (BodyMods IK).
## Firing is hitscan per pellet with bullet drop, damage by body part, gore, impacts, tracers, muzzle flash and noise
## that zombies and scavs can hear.

const DEFS := {
	"enfield": {"sight": 0.05, "name": "Lee-Enfield No.1 Mk III (.303)", "len": 1.45, "flip": true, "action": "bolt", "dmg": 110.0, "pellets": 1, "spread": 0.0012,
		"interval": 1.25, "mag": 10, "reload": 3.4, "recoil": 0.075, "vel": 740.0, "range": 900.0, "loud": 330.0, "sound": "shot_303",
		"grip": 0.24, "fore": 0.5, "drop_y": -0.035, "kick": 0.09, "force": 9.0},
	"slr": {"sight": 0.085, "name": "L1A1 SLR (7.62 NATO)", "len": 1.14, "flip": false, "action": "semi", "dmg": 85.0, "pellets": 1, "spread": 0.0018,
		"interval": 0.13, "mag": 20, "reload": 2.7, "recoil": 0.05, "vel": 820.0, "range": 800.0, "loud": 320.0, "sound": "shot_slr",
		"grip": 0.33, "fore": 0.62, "drop_y": -0.03, "kick": 0.06, "force": 8.0},
	"python": {"sight": 0.055, "name": "Colt Python (.357 Magnum)", "len": 0.3, "flip": false, "action": "revolver", "dmg": 62.0, "pellets": 1, "spread": 0.004,
		"interval": 0.28, "mag": 6, "reload": 3.2, "recoil": 0.09, "vel": 440.0, "range": 250.0, "loud": 220.0, "sound": "shot_357",
		"grip": 0.12, "fore": 0.1, "drop_y": -0.06, "kick": 0.05, "force": 5.0, "pistol": true},
	"dbshotgun": {"sight": 0.035, "name": "Side-by-side 12 gauge", "len": 1.12, "flip": false, "action": "break", "dmg": 15.0, "pellets": 9, "spread": 0.038,
		"interval": 0.22, "mag": 2, "reload": 2.6, "recoil": 0.13, "vel": 400.0, "range": 90.0, "loud": 280.0, "sound": "shot_12g",
		"grip": 0.28, "fore": 0.56, "drop_y": -0.03, "kick": 0.1, "force": 4.0},
	"sawnoff": {"sight": 0.04, "name": "Sawn-off 12 gauge", "len": 0.6, "flip": false, "action": "break", "dmg": 14.0, "pellets": 10, "spread": 0.085,
		"interval": 0.2, "mag": 2, "reload": 2.3, "recoil": 0.17, "vel": 380.0, "range": 45.0, "loud": 300.0, "sound": "shot_sawn",
		"grip": 0.14, "fore": 0.55, "drop_y": -0.04, "kick": 0.12, "force": 4.5, "pistol": true},
	"rem870": {"sight": 0.035, "name": "Remington 870 pump (12 gauge)", "len": 1.0, "flip": false, "action": "pump", "dmg": 14.0, "pellets": 8, "spread": 0.045,
		"interval": 0.85, "mag": 5, "reload": 0.55, "recoil": 0.12, "vel": 400.0, "range": 80.0, "loud": 280.0, "sound": "shot_12g",
		"grip": 0.27, "fore": 0.63, "drop_y": -0.025, "kick": 0.1, "force": 4.0},
}
const ORDER := ["python", "sawnoff", "dbshotgun", "rem870", "slr", "enfield"]
const BODY_MULT := {"head": 3.6, "chest": 1.0, "pelvis": 0.9, "l_upperarm": 0.55, "r_upperarm": 0.55, "l_forearm": 0.45, "r_forearm": 0.45,
	"l_thigh": 0.65, "r_thigh": 0.65, "l_shin": 0.5, "r_shin": 0.5}
const MASK := 1 | (1 << 2) | (1 << 3)       # world, actors, ragdolls

var key := "enfield"
var def: Dictionary
var model: Node3D
var muzzle: Node3D
var grip_r: Node3D                  # right hand target (wrist of the stock / pistol grip)
var grip_l: Node3D                  # left hand target (fore-end / pump)
var butt: Node3D
var ammo := 0
var reserve := 60
var cool := 0.0                     # time until it can fire again
var reloading := 0.0
var cycling := 0.0                  # bolt / pump being worked
var shooter: Node                   # who's holding it (excluded from its own shots)
var excludes: Array = []
var flash: OmniLight3D
var flash_mesh: MeshInstance3D
var audio: AudioStreamPlayer3D
var mech_audio: AudioStreamPlayer3D
static var _streams := {}

static func sfx(n: String) -> AudioStream:
	if not _streams.has(n):
		_streams[n] = load("res://assets/audio/sfx/%s.wav" % n)
	return _streams[n]

func setup(k: String, who: Node) -> void:
	key = k
	def = DEFS[k]
	shooter = who
	ammo = int(def.mag)
	var ps: PackedScene = load("res://assets/guns/%s/scene.gltf" % k)
	var raw: Node3D = ps.instantiate()
	for h in def.get("hide", []):
		var n := raw.find_child(h, true, false)
		if n:
			n.get_parent().remove_child(n)
			n.free()
	var holder := Node3D.new()
	add_child(holder)
	holder.add_child(raw)
	# normalise: longest axis -> -Z with the muzzle forward, scaled to the real length, centred
	var bb := _aabb(raw)
	var L := bb.size
	var ax := 0 if (L.x >= L.y and L.x >= L.z) else (1 if L.y >= L.z else 2)
	var b := Basis()
	if ax == 1: b = Basis(Vector3.BACK, PI * 0.5)
	elif ax == 2: b = Basis(Vector3.UP, -PI * 0.5)
	b = Basis(Vector3.UP, (-PI * 0.5) if def.flip else (PI * 0.5)) * b
	var s: float = float(def.len) / max(L[ax], 0.0001)
	holder.basis = b.scaled(Vector3.ONE * s)
	holder.position = -(holder.basis * bb.get_center())
	model = holder
	for mi in raw.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var half: float = float(def.len) * 0.5
	muzzle = _marker(Vector3(0, 0.02, -half))
	butt = _marker(Vector3(0, -0.02, half))
	grip_r = _marker(Vector3(0.02, float(def.drop_y) - 0.075, half - float(def.grip) * float(def.len) + 0.05))
	grip_l = _marker(Vector3(-0.035, float(def.drop_y) * 0.5 - 0.085, half - float(def.fore) * float(def.len) + 0.03))
	flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.72, 0.38)
	flash.omni_range = 7.0
	flash.light_energy = 0.0
	flash.shadow_enabled = false
	muzzle.add_child(flash)
	flash_mesh = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.28)
	flash_mesh.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = _flash_tex()
	fm.albedo_color = Color(1.0, 0.75, 0.4)
	flash_mesh.material_override = fm
	flash_mesh.visible = false
	flash_mesh.position = Vector3(0, 0, -0.1)
	muzzle.add_child(flash_mesh)
	audio = AudioStreamPlayer3D.new()
	audio.unit_size = 30.0
	audio.max_db = 6.0
	audio.max_distance = 900.0
	audio.attenuation_filter_cutoff_hz = 5000.0
	muzzle.add_child(audio)
	mech_audio = AudioStreamPlayer3D.new()
	mech_audio.unit_size = 4.0
	add_child(mech_audio)

func _marker(p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	return n

static func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := Transform3D()
		var p: Node = m
		while p != n and p != null:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * m.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

static var _ftex: Texture2D
static func _flash_tex() -> Texture2D:
	if _ftex == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var p := Vector2(x - n * 0.5, y - n * 0.5) / (n * 0.5)
				var a := atan2(p.y, p.x)
				var star := 0.35 + 0.65 * pow(abs(cos(a * 2.5)), 6.0)
				var v: float = clamp(1.0 - p.length() / star, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, v * v))
		_ftex = ImageTexture.create_from_image(img)
	return _ftex

func _process(dt: float) -> void:
	cool = max(cool - dt, 0.0)
	cycling = max(cycling - dt, 0.0)
	if reloading > 0.0:
		reloading -= dt
		if reloading <= 0.0:
			_finish_reload()
	if flash.light_energy > 0.0:
		flash.light_energy = max(flash.light_energy - dt * 120.0, 0.0)
		if flash.light_energy <= 0.0:
			flash_mesh.visible = false

func ready_to_fire() -> bool:
	return cool <= 0.0 and reloading <= 0.0 and cycling <= 0.0

## Pull the trigger. origin/dir: where the bullet starts and goes (the eye for the player, the muzzle for NPCs).
## extra_spread adds to the gun's own (moving, hip fire, a scav's nerves). Returns true if it went bang.
func fire(origin: Vector3, dir: Vector3, extra_spread := 0.0) -> bool:
	if not ready_to_fire():
		return false
	if ammo <= 0:
		_mech("dry")
		cool = 0.3
		return false
	ammo -= 1
	cool = float(def.interval)
	audio.stream = sfx(def.sound)
	audio.pitch_scale = randf_range(0.94, 1.06)
	audio.play()
	flash.light_energy = 6.0
	flash_mesh.visible = true
	flash_mesh.rotation.z = randf() * TAU
	var space := get_world_3d().direct_space_state
	var ex: Array = excludes.duplicate()
	var hits := {}                         # target -> {"parts": {part: dmg}, "point", "dir"}
	for i in int(def.pellets):
		var sp: float = float(def.spread) + extra_spread
		var d := _cone(dir, sp)
		var hit := _cast(space, origin, d, float(def.range), ex)
		if hit.is_empty():
			_tracer(origin, origin + d * min(float(def.range), 300.0))
			continue
		# bullet drop over that distance: aim a hair lower and look again
		var dist: float = origin.distance_to(hit.position)
		var tof: float = dist / float(def.vel)
		var drop: float = 0.5 * 9.8 * tof * tof
		if drop > 0.03:
			var d2 := (d * dist + Vector3.DOWN * drop).normalized()
			var h2 := _cast(space, origin, d2, float(def.range), ex)
			if not h2.is_empty():
				hit = h2
				d = d2
		_tracer(origin, hit.position)
		_resolve(hit, d, hits)
	for t in hits:
		var h: Dictionary = hits[t]
		if is_instance_valid(t):
			t.take_hit(h.parts, h.dir, h.point, float(def.force) * float(def.pellets) * 0.5 + 4.0, shooter)
	Hearing.emit(get_tree(), global_position, float(def.loud), "gunshot", shooter)
	# work the action
	match def.action:
		"bolt":
			cycling = 0.9
			get_tree().create_timer(0.35).timeout.connect(func(): if is_instance_valid(self): _mech("bolt"))
			_casing(0.65)
		"pump":
			cycling = 0.55
			get_tree().create_timer(0.25).timeout.connect(func(): if is_instance_valid(self): _mech("pump"))
			_casing(0.45)
		"semi":
			_casing(0.05)
	return true

func _cone(dir: Vector3, sp: float) -> Vector3:
	if sp <= 0.0:
		return dir.normalized()
	var x := dir.cross(Vector3.UP if abs(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var y := x.cross(dir).normalized()
	var r := sqrt(randf()) * sp
	var a := randf() * TAU
	return (dir.normalized() + x * cos(a) * r + y * sin(a) * r).normalized()

func _cast(space: PhysicsDirectSpaceState3D, o: Vector3, d: Vector3, rng: float, ex: Array) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(o, o + d * rng, MASK, ex)
	q.collide_with_areas = false
	return space.intersect_ray(q)

func _resolve(hit: Dictionary, d: Vector3, hits: Dictionary) -> void:
	var c = hit.collider
	var p: Vector3 = hit.position
	var dmg: float = float(def.dmg)
	if c and c.has_method("take_hit"):
		var part: String = c.rig.part_at(p, d) if "rig" in c and c.rig else "chest"
		if not hits.has(c):
			hits[c] = {"parts": {}, "point": p, "dir": d}
		var parts: Dictionary = hits[c].parts
		parts[part] = float(parts.get(part, 0.0)) + dmg * float(BODY_MULT.get(part, 1.0))
		Gore.spray(c.get_parent(), p, d + Vector3.UP * 0.2, 0.7 if int(def.pellets) > 1 else 1.0)
		_impact_sound(p, "hit_flesh")
	elif c is RigidBody3D and c.has_meta("ragdoll"):
		var rd = c.get_meta("ragdoll")
		var part: String = rd.part_of(c)
		rd.push(part, d * float(def.force) * 2.5, p)
		Gore.spray(rd.get_parent(), p, d + Vector3.UP * 0.2, 0.8)
		_impact_sound(p, "hit_flesh")
		if rd.owner_actor and is_instance_valid(rd.owner_actor) and rd.owner_actor.has_method("corpse_hit"):
			rd.owner_actor.corpse_hit(part, dmg * float(BODY_MULT.get(part, 1.0)), d)
	elif c is RigidBody3D:
		(c as RigidBody3D).apply_impulse(d * float(def.force) * (6.0 if c.is_in_group("vehicles") else 2.0), p - c.global_position)
		_impact(p, hit.normal, true)
	else:
		_impact(p, hit.normal, false)

func _impact(p: Vector3, n: Vector3, metal: bool) -> void:
	var parent := get_tree().current_scene
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.amount = 14 if not metal else 10
	puff.lifetime = 0.7 if not metal else 0.25
	var sm := SphereMesh.new()
	sm.radius = 0.04 if not metal else 0.008
	sm.height = sm.radius * 2.0
	sm.radial_segments = 4
	sm.rings = 2
	var m := StandardMaterial3D.new()
	if metal:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.8, 0.4)
	else:
		m.albedo_color = Color(0.45, 0.38, 0.3)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = m
	puff.mesh = sm
	puff.direction = Vector3(0, 0, -1)
	puff.spread = 35.0
	puff.initial_velocity_min = 1.0 if not metal else 4.0
	puff.initial_velocity_max = 3.0 if not metal else 9.0
	puff.gravity = Vector3(0, -3.0 if not metal else -9.8, 0)
	puff.scale_amount_max = 2.5 if not metal else 1.0
	parent.add_child(puff)
	puff.global_position = p
	puff.look_at(p - n, Vector3.UP if abs(n.y) < 0.95 else Vector3.RIGHT)
	puff.emitting = true
	get_tree().create_timer(1.2).timeout.connect(puff.queue_free)
	_impact_sound(p, "hit_metal" if metal else ("ricochet" if randf() < 0.12 else "hit_dirt"))

func _impact_sound(p: Vector3, n: String) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = sfx(n)
	a.unit_size = 6.0
	a.pitch_scale = randf_range(0.9, 1.15)
	get_tree().current_scene.add_child(a)
	a.global_position = p
	a.play()
	a.finished.connect(a.queue_free)

func _tracer(a: Vector3, b: Vector3) -> void:
	if randf() > 0.6:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, 1.0)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.55, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(mi)
	var start := a.lerp(b, 0.08)
	var L := start.distance_to(b)
	if L < 0.5:
		mi.queue_free()
		return
	mi.global_position = (start + b) * 0.5
	mi.look_at(b, Vector3.UP if abs((b - start).normalized().y) < 0.95 else Vector3.RIGHT)
	mi.scale = Vector3(1, 1, L)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.07)
	tw.tween_callback(mi.queue_free)

func _casing(delay: float) -> void:
	get_tree().create_timer(delay + 0.35).timeout.connect(func():
		if is_instance_valid(self): _mech("casing_%d" % (randi() % 3)))

func _mech(n: String) -> void:
	mech_audio.stream = sfx(n)
	mech_audio.pitch_scale = randf_range(0.95, 1.05)
	mech_audio.play()

func start_reload() -> bool:
	if reloading > 0.0 or ammo >= int(def.mag) or reserve <= 0:
		return false
	reloading = float(def.reload)
	match def.action:
		"break":
			_mech("break_open")
			get_tree().create_timer(reloading - 0.3).timeout.connect(func(): if is_instance_valid(self): _mech("break_close"))
		"revolver":
			_mech("cylinder")
		"pump":
			_mech("shell_in")
		"bolt":
			_mech("bolt")
		_:
			_mech("mag_out")
			get_tree().create_timer(reloading - 0.6).timeout.connect(func(): if is_instance_valid(self): _mech("mag_in"))
	return true

func _finish_reload() -> void:
	if def.action == "pump":
		# one shell at a time; keeps going while you let it
		ammo += 1
		reserve -= 1
		if ammo < int(def.mag) and reserve > 0:
			reloading = float(def.reload)
			_mech("shell_in")
		else:
			_mech("pump")
		return
	var need: int = int(def.mag) - ammo
	var take: int = min(need, reserve)
	ammo += take
	reserve -= take
	if def.action == "bolt":
		_mech("bolt")

## How far through the reload (0..1), for the hands-and-gun dip
func reload_phase() -> float:
	if reloading <= 0.0:
		return 0.0
	return 1.0 - reloading / float(def.reload)
