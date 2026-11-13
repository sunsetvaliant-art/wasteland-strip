class_name SkyCycle
extends Node
## Day and night, an hour a full turn (45 minutes of daylight, 15 of night), and the weather: clear, cloudy, rain,
## storms with lightning, and valley fog of a morning. Moves the sun and a dim moon, colours the sky, fog and fill
## light, rains around the camera (not indoors), and tells the rest of the game how dark (`night`) and wet (`wet`)
## it is. On a LAN game the host's clock and weather are everyone's.

const DAY_S := 2700.0                 # 06:00 -> 18:00
const NIGHT_S := 900.0                # 18:00 -> 06:00
const WEATHERS := ["clear", "cloudy", "rain", "storm", "fog"]

static var inst: SkyCycle
var main
var tod := 7.5                        # hours
var weather := "clear"
var weather_left := 600.0             # seconds until it changes
var night := 0.0                      # 0 day .. 1 full night
var wet := 0.0                        # how wet the ground is (rain soaks in, dries off slowly)
# smoothed weather amounts
var cloud := 0.0
var rain := 0.0
var fogd := 0.0
var _flash := 0.0
var _next_strike := 10.0
var _thunder: Array = []              # [delay, stream]
var moon: DirectionalLight3D
var rain_fx: GPUParticles3D
var rain_snd: AudioStreamPlayer
var thunder_snd: AudioStreamPlayer
var _indoor := false
var _indoor_t := 0.0
var _rng := RandomNumberGenerator.new()
var _sky: ProceduralSkyMaterial
var sky_sh: ShaderMaterial

func setup(m) -> void:
	main = m
	inst = self
	_rng.randomize()
	_sky = main.env.sky.sky_material as ProceduralSkyMaterial
	# our own sky over the top of it: clouds that move, stars, a moon
	sky_sh = ShaderMaterial.new()
	sky_sh.shader = load("res://shaders/sky.gdshader")
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.fractal_octaves = 5
	fn.frequency = 0.006
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.noise = fn
	sky_sh.set_shader_parameter("noise", nt)
	main.env.sky.sky_material = sky_sh
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.7, 0.95)
	moon.light_energy = 0.0
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 120.0
	moon.rotation_degrees = Vector3(-62, 150, 0)
	moon.visible = false
	main.add_child(moon)
	_make_rain()
	rain_snd = AudioStreamPlayer.new()
	rain_snd.stream = load("res://assets/audio/weather/rain.wav")
	rain_snd.volume_db = -80.0
	rain_snd.bus = "Master"
	add_child(rain_snd)
	thunder_snd = AudioStreamPlayer.new()
	add_child(thunder_snd)
	if OS.get_environment("TOD") != "":
		tod = float(OS.get_environment("TOD"))
	if OS.get_environment("WEATHER") != "":
		set_weather(OS.get_environment("WEATHER"), 900.0)
		cloud = _target_cloud()
		rain = _target_rain()
		fogd = _target_fog()

func _make_rain() -> void:
	rain_fx = GPUParticles3D.new()
	rain_fx.amount = 7000
	rain_fx.lifetime = 1.4
	rain_fx.preprocess = 1.4
	rain_fx.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	rain_fx.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 1, 24)
	pm.direction = Vector3(0.08, -1, 0.04)
	pm.spread = 3.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 20.0
	pm.gravity = Vector3(0, -4, 0)
	rain_fx.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.8, 0.85, 0.32)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	q.material = mat
	rain_fx.draw_pass_1 = q
	rain_fx.emitting = false
	rain_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(rain_fx)

func set_weather(w: String, secs: float) -> void:
	weather = w
	weather_left = secs

func _target_cloud() -> float:
	return {"clear": 0.05, "cloudy": 0.7, "rain": 0.9, "storm": 1.0, "fog": 0.55}.get(weather, 0.0)
func _target_rain() -> float:
	return {"rain": 0.55, "storm": 1.0}.get(weather, 0.0)
func _target_fog() -> float:
	return {"fog": 1.0, "rain": 0.25, "storm": 0.35}.get(weather, 0.0)

func clock() -> String:
	var h := int(tod)
	var mi := int((tod - h) * 60.0)
	return "%02d:%02d" % [h, mi]

func _next_weather() -> void:
	var morning := tod > 4.5 and tod < 8.5
	if morning and _rng.randf() < 0.45:
		set_weather("fog", _rng.randf_range(300, 700))
		return
	var r := _rng.randf()
	var w := "clear"
	if r < 0.45: w = "clear"
	elif r < 0.7: w = "cloudy"
	elif r < 0.9: w = "rain"
	else: w = "storm"
	set_weather(w, _rng.randf_range(360, 1080))

func _process(dt: float) -> void:
	if main == null or main.sun == null:
		return
	var runs: bool = main.net == null or main.net.runs_world()
	if runs:
		# the clock: daylight hours pass slower than night ones
		var day := tod >= 6.0 and tod < 18.0
		tod += dt * (12.0 / DAY_S if day else 12.0 / NIGHT_S)
		if tod >= 24.0: tod -= 24.0
		weather_left -= dt
		if weather_left <= 0.0:
			_next_weather()
		if weather == "fog" and tod > 10.0:
			set_weather("cloudy", _rng.randf_range(200, 500))
	# ease the weather in and out over a minute or so
	var k := clampf(dt / 50.0, 0.0, 1.0)
	cloud = lerpf(cloud, _target_cloud(), k)
	rain = lerpf(rain, _target_rain(), clampf(dt / 25.0, 0.0, 1.0))
	fogd = lerpf(fogd, _target_fog(), k)
	wet = clampf(wet + (rain * dt / 60.0 if rain > 0.1 else -dt / 400.0), 0.0, 1.0)
	_apply_light(dt)
	_apply_rain(dt)
	_storm(dt)

func _apply_light(dt: float) -> void:
	# sun: rises in the east, crosses the northern sky (we're south of the tropic), sets in the west
	var u := (tod - 6.0) / 12.0 * PI
	var el := sin(u) * deg_to_rad(64.0)
	var az := deg_to_rad(90.0) - u                  # from north, clockwise: east 90 -> north 0 -> west -90
	var s := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	var up := sin(el)                                # below zero: down under the horizon
	var day_amt := clampf((up + 0.06) / 0.2, 0.0, 1.0)
	night = 1.0 - day_amt
	if up > -0.2:
		var dirv := -s
		if absf(dirv.y) > 0.99: dirv = Vector3(0.05, dirv.y, 0.05).normalized()
		main.sun.global_basis = Basis.looking_at(dirv, Vector3.UP)
	var low := clampf(1.0 - up / 0.35, 0.0, 1.0)     # near the horizon: warm, weak
	main.sun.light_energy = 1.35 * day_amt * (1.0 - 0.72 * cloud) * (1.0 - 0.45 * low * low) + _flash * 2.0
	main.sun.light_color = Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.62, 0.38), low * low * (1.0 - cloud))
	main.sun.visible = main.sun.light_energy > 0.01
	moon.visible = night > 0.05
	moon.light_energy = 0.32 * night * (1.0 - 0.55 * cloud)
	# sky colours: day, dusk, night, and grey under cloud
	var top := Color(0.13, 0.36, 0.78)
	var hor := Color(0.62, 0.76, 0.9)
	var dusk_t := low * day_amt * (1.0 - cloud)
	top = top.lerp(Color(0.16, 0.22, 0.48), dusk_t)
	hor = hor.lerp(Color(0.98, 0.6, 0.36), dusk_t)
	top = top.lerp(Color(0.42, 0.45, 0.5), cloud * 0.85)
	hor = hor.lerp(Color(0.6, 0.62, 0.64), cloud * 0.85)
	top = top.lerp(Color(0.025, 0.035, 0.08), night)
	hor = hor.lerp(Color(0.08, 0.1, 0.16), night)
	if _flash > 0.0:
		top = top.lerp(Color(0.7, 0.72, 0.85), _flash)
		hor = hor.lerp(Color(0.8, 0.82, 0.9), _flash)
	_sky.sky_top_color = top
	_sky.sky_horizon_color = hor
	_sky.ground_horizon_color = hor
	_sky.ground_bottom_color = Color(0.16, 0.2, 0.15).lerp(Color(0.02, 0.02, 0.02), night)
	_sky.sun_curve = 0.08
	if sky_sh:
		sky_sh.set_shader_parameter("top", top)
		sky_sh.set_shader_parameter("horizon", hor)
		sky_sh.set_shader_parameter("ground", Color(0.16, 0.2, 0.15).lerp(Color(0.02, 0.02, 0.02), night))
		sky_sh.set_shader_parameter("night", night)
		sky_sh.set_shader_parameter("cover", clampf(maxf(cloud, 0.16) + fogd * 0.2, 0.0, 1.0))
		sky_sh.set_shader_parameter("wind", 1.0 + rain * 2.5)
		var cc := Color(1.0, 1.0, 1.0).lerp(Color(0.5, 0.52, 0.56), cloud * 0.9).lerp(Color(1.0, 0.7, 0.5), dusk_t * 0.6)
		sky_sh.set_shader_parameter("cloud_col", cc.lerp(Color(0.06, 0.07, 0.1), night) + Color(_flash, _flash, _flash) * 0.6)
		sky_sh.set_shader_parameter("sun_col", main.sun.light_color)
		sky_sh.set_shader_parameter("moon_dir", moon.global_basis.z)
	var env: Environment = main.env
	env.ambient_light_energy = lerpf(1.0, 0.34, night) * (1.0 - 0.15 * cloud) + _flash * 1.5
	env.ambient_light_color = Color(0.58, 0.6, 0.58).lerp(Color(0.32, 0.36, 0.5), night)
	env.fog_light_color = hor
	# fog: valley fog closes right in; rain hazes the distance
	var vd := float(Settings.get_v("view_distance")) if Settings.has_method("get_v") else 26000.0
	var far_end := maxf(vd * 2.2, 30000.0)
	env.fog_depth_begin = lerpf(1500.0, 20.0, fogd)
	env.fog_depth_end = lerpf(far_end, 420.0, pow(fogd, 0.6))
	env.volumetric_fog_density = lerpf(0.0035, 0.03, fogd)

func _apply_rain(dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# under a roof? (no rain falls in here, and it's quieter)
	_indoor_t -= dt
	if _indoor_t <= 0.0:
		_indoor_t = 0.3
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + Vector3.UP * 25.0, 1)
		_indoor = not main.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	var amt := rain * (0.0 if _indoor else 1.0)
	rain_fx.emitting = amt > 0.03
	rain_fx.amount_ratio = clampf(amt, 0.05, 1.0)
	rain_fx.global_position = cam.global_position + Vector3(0, 14, 0) + (-cam.global_basis.z) * 8.0
	var want_db := -80.0 if rain < 0.03 else linear_to_db(rain) - (12.0 if _indoor else 2.0)
	rain_snd.volume_db = lerpf(rain_snd.volume_db, want_db, clampf(dt * 2.0, 0.0, 1.0))
	if rain > 0.03 and not rain_snd.playing:
		rain_snd.play()
	elif rain <= 0.03 and rain_snd.playing and rain_snd.volume_db < -60.0:
		rain_snd.stop()

func _storm(dt: float) -> void:
	_flash = maxf(_flash - dt * 6.0, 0.0)
	for th in _thunder:
		th[0] -= dt
		if th[0] <= 0.0:
			thunder_snd.stream = th[1]
			thunder_snd.volume_db = -2.0 - _rng.randf() * 6.0
			thunder_snd.play()
	_thunder = _thunder.filter(func(t): return t[0] > 0.0)
	if weather != "storm" or rain < 0.5:
		return
	_next_strike -= dt
	if _next_strike <= 0.0:
		_next_strike = _rng.randf_range(6.0, 22.0)
		_flash = 1.0
		get_tree().create_timer(0.12).timeout.connect(func(): _flash = 0.8)
		_thunder.append([_rng.randf_range(0.4, 4.0), load("res://assets/audio/weather/thunder%d.wav" % (_rng.randi() % 3))])

## For the LAN host to send round, and joiners to take
func state() -> Array:
	return [tod, weather, weather_left]

func take_state(st: Array) -> void:
	if st.size() < 3: return
	if absf(float(st[0]) - tod) > 0.05: tod = float(st[0])
	weather = str(st[1])
	weather_left = float(st[2])
