class_name EngineAudio
extends Node3D
## Plays the synthesised engine: five rpm points, each an on-throttle and an off-throttle loop. The two nearest rpm
## points crossfade (equal power) and are pitched to the exact rpm; throttle load blends on <-> off. Exhaust pops
## when you lift off high in the revs, the starter when you climb in, a little mechanical shake at idle.
## Loops come from tools/engine_synth.py (assets/audio/engines).

const DIR := "res://assets/audio/engines/"
const RPMS := [800, 1500, 2500, 3600, 5000]
var car
var key := "i6_202"
var base_rpm: Array = []
var on: Array[AudioStreamPlayer3D] = []
var off: Array[AudioStreamPlayer3D] = []
var starter: AudioStreamPlayer3D
var pops: Array = []
var pop_player: AudioStreamPlayer3D
var load_s := 0.0
var last_thr := 0.0
var pop_budget := 0.0
var was_running := false
var level := 0.0                     # 0 = engine off, 1 = running (fades so it doesn't click)
static var _cache := {}

func setup(c) -> void:
	car = c
	key = str(car.eng.get("sound", "i6_202"))
	var idx: Dictionary = _index()
	base_rpm = idx.get(key, {}).get("rpms", RPMS)
	position = Vector3(0, float(car.design.ride) + 0.3, float(car.design.axles[0].z) - 0.3)
	for i in RPMS.size():
		on.append(_player("%s_%d_on" % [key, RPMS[i]]))
		off.append(_player("%s_%d_off" % [key, RPMS[i]]))
	starter = _player("%s_starter" % key, false)
	for i in 4:
		pops.append(_stream("pop_%d" % i, false))
	pop_player = AudioStreamPlayer3D.new()
	pop_player.max_db = 6.0
	pop_player.unit_size = 14.0
	pop_player.bus = _bus()
	add_child(pop_player)
	pop_player.position = Vector3(0.4, -0.2, -3.0)       # the tailpipe's at the back

static func _index() -> Dictionary:
	if _cache.has("index"):
		return _cache["index"]
	var f := FileAccess.open(DIR + "index.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text()) if f else {}
	_cache["index"] = d
	return d

static func _stream(nm: String, looped := true) -> AudioStream:
	if _cache.has(nm):
		return _cache[nm]
	var s: AudioStreamWAV = load(DIR + nm + ".wav")
	if s and looped:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	_cache[nm] = s
	return s

func _bus() -> StringName:
	return &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"

func _player(nm: String, looped := true) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(nm, looped)
	p.unit_size = 9.0
	p.max_db = 3.0
	p.max_distance = 260.0
	p.attenuation_filter_cutoff_hz = 9000.0
	p.attenuation_filter_db = -18.0
	p.volume_db = -80.0
	p.bus = _bus()
	add_child(p)
	return p

func _process(dt: float) -> void:
	if car == null:
		return
	var running: bool = car.running
	var cranking: bool = car.crank > 0.0
	if cranking and not was_running:
		starter.volume_db = -2.0
		starter.play()
	was_running = cranking or running
	level = move_toward(level, 1.0 if running or car.rpm > 300.0 else 0.0, dt * 2.5)
	var rpm: float = max(car.rpm, 1.0)
	# smoothed load: what the engine is doing, nudged by the pedal so blips sound instant
	var target_load: float = clamp(max(car.engine_load, 0.0) * 0.7 + car.throttle * 0.5, 0.0, 1.0)
	load_s = lerpf(load_s, target_load, clamp(dt * 12.0, 0.0, 1.0))
	# which two rpm points we're between
	var k := 0
	while k < base_rpm.size() - 2 and rpm > float(base_rpm[k + 1]):
		k += 1
	var r0: float = base_rpm[k]
	var r1: float = base_rpm[k + 1]
	var x: float = clamp((rpm - r0) / (r1 - r0), 0.0, 1.0)
	var vol: float = level * (0.42 + 0.58 * clamp(rpm / 4200.0, 0.0, 1.0)) * (0.62 + 0.38 * load_s)
	for i in base_rpm.size():
		var w := 0.0
		if i == k: w = cos(x * PI * 0.5)
		elif i == k + 1: w = sin(x * PI * 0.5)
		_drive(on[i], w * sqrt(load_s) * vol, rpm / float(base_rpm[i]))
		_drive(off[i], w * sqrt(1.0 - load_s) * vol, rpm / float(base_rpm[i]))
	# lift-off crackle: the mixture goes rich on the overrun and lights off in the pipe
	if last_thr > 0.6 and car.throttle < 0.2 and rpm > 2800.0:
		pop_budget = 0.9
	last_thr = car.throttle
	if pop_budget > 0.0:
		pop_budget -= dt
		if rpm > 1800.0 and car.throttle < 0.2 and randf() < dt * 9.0:
			pop_player.stream = pops[randi() % pops.size()]
			pop_player.pitch_scale = randf_range(0.85, 1.2)
			pop_player.volume_db = randf_range(-6.0, 1.0)
			pop_player.play()

func _drive(p: AudioStreamPlayer3D, amp: float, pitch: float) -> void:
	if amp < 0.003:
		if p.playing:
			p.stop()
		return
	if not p.playing:
		p.play(randf() * p.stream.get_length())
	p.volume_db = linear_to_db(amp)
	p.pitch_scale = clamp(pitch, 0.25, 4.0)
