extends Node
## Every setting the game has, saved to user://settings.cfg and applied live. The pause menu edits these.

signal changed

const FILE := "user://settings.cfg"
const PRESETS := {
	"Low":    {"render_scale": 0.67, "upscaler": 1, "shadow_quality": 0, "shadow_distance": 160.0, "ssao": false, "ssil": false, "gi": false, "volumetric_fog": false, "ssr": false, "glow": true, "tree_distance": 450.0, "grass_distance": 30.0, "grass_density": 0.5, "view_distance": 9000.0, "aa": 1},
	"Medium": {"render_scale": 0.8, "upscaler": 1, "shadow_quality": 1, "shadow_distance": 260.0, "ssao": true, "ssil": false, "gi": false, "volumetric_fog": false, "ssr": false, "glow": true, "tree_distance": 650.0, "grass_distance": 45.0, "grass_density": 0.75, "view_distance": 16000.0, "aa": 2},
	"High":   {"render_scale": 1.0, "upscaler": 0, "shadow_quality": 2, "shadow_distance": 400.0, "ssao": true, "ssil": true, "gi": false, "volumetric_fog": true, "ssr": true, "glow": true, "tree_distance": 850.0, "grass_distance": 60.0, "grass_density": 1.0, "view_distance": 26000.0, "aa": 2},
	"Ultra":  {"render_scale": 1.0, "upscaler": 0, "shadow_quality": 3, "shadow_distance": 600.0, "ssao": true, "ssil": true, "gi": true, "volumetric_fog": true, "ssr": true, "glow": true, "tree_distance": 1200.0, "grass_distance": 80.0, "grass_density": 1.3, "view_distance": 32000.0, "aa": 3},
}

var v := {
	"preset": "Medium",
	"window_mode": 2,          # 0 windowed, 1 borderless fullscreen, 2 exclusive fullscreen
	"vsync": true,
	"fps_cap": 0,              # 0 = unlimited
	"fov": 72.0,
	"brightness": 1.0,
	"motion_sensitivity": 1.0,
	"invert_y": false,
	"master_volume": 0.8,
	"show_fps": false,
}

func _init() -> void:
	v.merge(PRESETS["Medium"])
	var cf := ConfigFile.new()
	if cf.load(FILE) == OK:
		for k in cf.get_section_keys("s"):
			v[k] = cf.get_value("s", k)

func save() -> void:
	var cf := ConfigFile.new()
	for k in v:
		cf.set_value("s", k, v[k])
	cf.save(FILE)

func set_value(k: String, val) -> void:
	v[k] = val
	if k != "preset" and PRESETS.has(v.preset) and PRESETS[v.preset].has(k) and PRESETS[v.preset][k] != val:
		v.preset = "Custom"
	save()
	changed.emit()

func apply_preset(name: String) -> void:
	if PRESETS.has(name):
		v.merge(PRESETS[name], true)
	v.preset = name
	save()
	changed.emit()

func get_v(k: String):
	return v.get(k)

## Pushes everything onto the running game. Safe to call any time.
func apply(main: Node) -> void:
	var vp := get_viewport()
	match int(v.window_mode):
		0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(v.fps_cap)
	vp.scaling_3d_scale = float(v.render_scale)
	vp.scaling_3d_mode = [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR, Viewport.SCALING_3D_MODE_FSR2][clampi(int(v.upscaler), 0, 2)] if float(v.render_scale) < 0.999 or int(v.upscaler) == 2 else Viewport.SCALING_3D_MODE_BILINEAR
	# 0 off, 1 FXAA, 2 TAA, 3 TAA + FXAA
	var aa := int(v.aa)
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa in [1, 3] else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = aa >= 2 and vp.scaling_3d_mode != Viewport.SCALING_3D_MODE_FSR2
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 8192, 8192][clampi(int(v.shadow_quality), 0, 3)], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][clampi(int(v.shadow_quality), 0, 3)])
	AudioServer.set_bus_volume_db(0, linear_to_db(max(float(v.master_volume), 0.0001)))
	if main == null or not main.is_inside_tree():
		return
	var env: Environment = main.env
	env.ssao_enabled = v.ssao
	env.ssil_enabled = v.ssil
	env.sdfgi_enabled = v.gi
	env.ssr_enabled = v.ssr
	env.glow_enabled = v.glow
	env.volumetric_fog_enabled = v.volumetric_fog
	env.tonemap_exposure = float(v.brightness)
	env.fog_depth_end = float(v.view_distance)
	main.sun.directional_shadow_max_distance = float(v.shadow_distance)
	main.veg.set_ranges(float(v.tree_distance), float(v.grass_distance), float(v.grass_density))
	for c in main.get_tree().get_nodes_in_group("cameras"):
		(c as Camera3D).far = float(v.view_distance) + 2000.0
		if not c.has_meta("fixed_fov"):
			(c as Camera3D).fov = float(v.fov)
