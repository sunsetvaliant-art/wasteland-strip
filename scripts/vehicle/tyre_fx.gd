class_name TyreFX
extends Node3D
## What the tyres leave behind: rubber marks on sealed ground and a screech that rises with slip and road speed,
## smoke off a spinning or locked tyre on bitumen / concrete, and dirt, grass, sand or mud thrown up off loose ground.
## One per car; the marks go into a shared multimesh in the world so they stay after the car's gone.

const SPRAY := {
	"grass": [Color(0.25, 0.38, 0.12), Color(0.36, 0.28, 0.17)],
	"dirt": [Color(0.36, 0.27, 0.17), Color(0.28, 0.22, 0.15)],
	"sand": [Color(0.78, 0.7, 0.52), Color(0.7, 0.62, 0.45)],
	"mud": [Color(0.22, 0.17, 0.11), Color(0.16, 0.13, 0.09)],
	"rock": [Color(0.45, 0.45, 0.42), Color(0.4, 0.38, 0.35)],
}

var car
var smoke: Array = []          # per wheel CPUParticles3D
var spray: Array = []
var last_mark: Array = []      # per wheel: last mark point (or null)
var screech: AudioStreamPlayer3D
var scrub: AudioStreamPlayer3D
static var marks: SkidMarks

func setup(c) -> void:
	car = c
	for w in car.wheels:
		smoke.append(_smoke())
		spray.append(_spray())
		last_mark.append(null)
	screech = _loop("tyre_screech")
	scrub = _loop("tyre_dirt")

func _loop(n: String) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	var st = load("res://assets/audio/sfx/%s.wav" % n)
	if st is AudioStreamWAV:
		st = st.duplicate()
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_end = st.get_length() * st.mix_rate if st.get_length() > 0 else 0
	a.stream = st
	a.unit_size = 9.0
	a.max_distance = 220.0
	a.volume_db = -80.0
	add_child(a)
	return a

func _smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 48
	p.lifetime = 2.4
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff_tex()
	q.material = m
	p.mesh = q
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.35, 0)
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 3.2))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.85, 0.85, 0.5))
	g.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
	p.color_ramp = g
	add_child(p)
	return p

func _spray() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 60
	p.lifetime = 0.9
	p.local_coords = false
	var b := BoxMesh.new()
	b.size = Vector3(0.05, 0.035, 0.05)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	b.material = m
	p.mesh = b
	p.spread = 25.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -9.8, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	add_child(p)
	return p

static func _puff_tex() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

func _physics_process(dt: float) -> void:
	if car == null:
		return
	if marks == null or not is_instance_valid(marks):
		marks = SkidMarks.new()
		get_tree().current_scene.add_child(marks)
	var hard_slip := 0.0
	var loose_slip := 0.0
	var spd: float = car.linear_velocity.length()
	for i in car.wheels.size():
		var w: Dictionary = car.wheels[i]
		var slip: float = w.slipv if w.contact else 0.0
		var hard: bool = w.kind in ["seal", "rock"]
		var sm: CPUParticles3D = smoke[i]
		var sp: CPUParticles3D = spray[i]
		var at: Vector3 = w.point + w.normal * 0.06
		sm.global_position = at
		sp.global_position = at
		# smoke off bitumen once the tyre's properly lit up
		var smoking: bool = hard and w.kind == "seal" and slip > 5.0
		sm.emitting = smoking
		sm.speed_scale = clamp(0.6 + (slip - 5.0) / 10.0, 0.6, 1.6)
		# spray off loose ground, thrown back from the tyre the way it's spinning
		var flinging: bool = not hard and w.kind != "flesh" and slip > 2.0
		sp.emitting = flinging
		if flinging:
			var col: Array = SPRAY.get(w.kind, SPRAY.dirt)
			sp.color = (col[0] as Color).lerp(col[1], randf())
			var back: Vector3 = -w.fwd * signf(w.omega * w.r - w.vx)
			sp.direction = (back + Vector3(0, 0.9, 0)).normalized()
		# rubber marks on hard ground
		if hard and slip > 3.0:
			var pt: Vector3 = w.point + w.normal * 0.012
			if last_mark[i] != null and (last_mark[i] as Vector3).distance_to(pt) > 0.25:
				marks.add(last_mark[i], pt, w.normal, float(w.a.get("tyre_w", 0.2)), clamp((slip - 3.0) / 8.0, 0.25, 0.8))
				last_mark[i] = pt
			elif last_mark[i] == null:
				last_mark[i] = pt
		else:
			last_mark[i] = null
		if hard: hard_slip = max(hard_slip, slip)
		elif w.kind != "flesh": loose_slip = max(loose_slip, slip)
	# screech: louder with slip, higher with road speed; the dirt scrub is a lower rush
	_level(screech, smoothstep(2.0, 9.0, hard_slip), 0.85 + clamp(spd / 40.0, 0.0, 0.35) + randf_range(-0.02, 0.02), dt)
	_level(scrub, smoothstep(1.5, 8.0, loose_slip), 0.8 + clamp(spd / 30.0, 0.0, 0.5), dt)

func _level(a: AudioStreamPlayer3D, k: float, pitch: float, dt: float) -> void:
	var want := linear_to_db(max(k, 0.0001)) + 2.0
	a.volume_db = lerpf(a.volume_db, want, clamp(dt * 10.0, 0.0, 1.0))
	a.pitch_scale = pitch
	if k > 0.01 and not a.playing: a.play()
	elif k <= 0.01 and a.volume_db < -50.0 and a.playing: a.stop()
