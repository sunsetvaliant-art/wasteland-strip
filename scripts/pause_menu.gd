class_name PauseMenu
extends CanvasLayer
## Esc: pauses the game. Resume, Settings (graphics, display, controls, audio), Reset world, Multiplayer (later), Quit.

var main
var root: Control
var home: VBoxContainer
var settings_panel: Control
var open := false
var _building := false
var widgets := {}
var mode_btn: Button
var forge_btn: Button
var garage_btn: Button
var credits_panel: Control

const ACCENT := Color(0.94, 0.65, 0.23)

func setup(m) -> void:
	main = m
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = _theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.03, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	# left column: title + main buttons
	home = VBoxContainer.new()
	home.position = Vector2(80, 140)
	home.custom_minimum_size = Vector2(320, 0)
	home.add_theme_constant_override("separation", 10)
	root.add_child(home)
	var title := Label.new()
	title.text = "WASTELAND"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", ACCENT)
	home.add_child(title)
	var ver := Label.new()
	ver.text = "v%s%s" % [Boot.version, ("  ·  " + ", ".join(Boot.patches_loaded)) if Boot.patches_loaded.size() else ""]
	ver.modulate = Color(1, 1, 1, 0.6)
	home.add_child(ver)
	home.add_child(_spacer(24))
	_btn(home, "Resume", close)
	_btn(home, "Settings", func(): settings_panel.visible = not settings_panel.visible)
	mode_btn = _btn(home, "", _toggle_mode)
	forge_btn = _btn(home, "Forge mode  (O)", func(): close(); main.forge.toggle())
	garage_btn = _btn(home, "Garage: build a vehicle", func():
		close()
		if main.forge.active: main.forge.toggle()
		main.garage.show_garage())
	_btn(home, "Reset world", func(): main.reset_world())
	var mp := _btn(home, "Multiplayer  (coming)", func(): pass)
	mp.disabled = true
	_btn(home, "Credits", func(): credits_panel.visible = not credits_panel.visible)
	_btn(home, "Quit to desktop", func(): get_tree().quit())
	_build_credits()
	_build_settings()
	root.visible = false

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("menu"):
		if main.forge.active and main.forge.palette_open:
			return      # Forge closes its own palette first
		if open: close()
		else: show_menu()
		get_viewport().set_input_as_handled()

func _toggle_mode() -> void:
	Settings.set_value("game_mode", "survival" if Settings.creative() else "creative")
	if not Settings.creative():
		Settings.set_value("god_mode", false)
		if main.forge.active:
			main.forge.toggle()
	_refresh_mode()

func _refresh_mode() -> void:
	mode_btn.text = "Mode:  " + ("CREATIVE  (Forge on)" if Settings.creative() else "SURVIVAL  (no Forge)")
	forge_btn.disabled = not Settings.creative()
	garage_btn.disabled = not Settings.creative()

func show_menu() -> void:
	_refresh_mode()
	open = true
	root.visible = true
	settings_panel.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	open = false
	root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Settings.save()

# ---------------------------------------------------------------- settings
func _build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(460, 90)
	settings_panel.custom_minimum_size = Vector2(760, 820)
	root.add_child(settings_panel)
	var tabs := TabContainer.new()
	settings_panel.add_child(tabs)
	var g := _page(tabs, "Graphics")
	var row := HBoxContainer.new()
	var lab := Label.new()
	lab.text = "Preset"
	lab.custom_minimum_size.x = 240
	row.add_child(lab)
	for p in ["Low", "Medium", "High", "Ultra"]:
		var b := Button.new()
		b.text = p
		b.toggle_mode = true
		b.pressed.connect(func(): Settings.apply_preset(p); _refresh())
		row.add_child(b)
		widgets["preset_" + p] = b
	g.add_child(row)
	_slider(g, "render_scale", "Render scale", 0.5, 1.0, 0.05, "%d%%", 100.0)
	_option(g, "upscaler", "Upscaler", ["Bilinear", "AMD FSR 1", "AMD FSR 2 (sharp TAA)"])
	_option(g, "aa", "Anti-aliasing", ["Off", "FXAA", "TAA", "TAA + FXAA"])
	_slider(g, "view_distance", "View distance", 4000, 32000, 1000, "%d km", 0.001)
	_slider(g, "tree_distance", "Tree distance", 300, 1500, 50, "%d m")
	_slider(g, "grass_distance", "Grass distance", 20, 120, 5, "%d m")
	_slider(g, "grass_density", "Grass and scrub density", 0.25, 1.5, 0.05, "%d%%", 100.0)
	_option(g, "shadow_quality", "Shadow quality", ["Low", "Medium", "High", "Ultra"])
	_slider(g, "shadow_distance", "Shadow distance", 100, 800, 20, "%d m")
	_check(g, "ssao", "Ambient occlusion (SSAO)")
	_check(g, "ssil", "Bounce light (SSIL)")
	_check(g, "gi", "Global illumination (SDFGI, heavy)")
	_check(g, "ssr", "Screen-space reflections")
	_check(g, "volumetric_fog", "Volumetric fog and light shafts")
	_check(g, "glow", "Bloom")
	_slider(g, "brightness", "Brightness", 0.6, 1.6, 0.05, "%d%%", 100.0)
	var d := _page(tabs, "Display")
	_option(d, "window_mode", "Window", ["Windowed", "Borderless fullscreen", "Fullscreen"])
	_check(d, "vsync", "V-sync")
	_option(d, "fps_cap", "Frame-rate cap", ["Unlimited", "30", "60", "120", "144"], [0, 30, 60, 120, 144])
	_slider(d, "fov", "Field of view", 55, 100, 1, "%d°")
	_check(d, "show_fps", "Show FPS and position")
	var c := _page(tabs, "Controls")
	_slider(c, "motion_sensitivity", "Mouse sensitivity", 0.2, 3.0, 0.05, "%.2f", 1.0, true)
	_check(c, "invert_y", "Invert mouse Y")
	var keys := Label.new()
	keys.text = "On foot: WASD · Shift sprint · Ctrl/C crouch · Space jump · V shoulder / first person · F get in or out\nDriving: W gas · S brake · Space handbrake · Q / E gears (P R N D) · L lights · V cab view · [ ] seat height\nForge: O toggle · Tab palette · 1 place · 2 phys gun · 3 delete · 4 terrain · Ctrl+S save · Ctrl+Z undo"
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD
	keys.modulate = Color(1, 1, 1, 0.75)
	c.add_child(keys)
	var a := _page(tabs, "Audio")
	_slider(a, "master_volume", "Master volume", 0.0, 1.0, 0.05, "%d%%", 100.0)
	settings_panel.visible = false
	_refresh()

func _page(tabs: TabContainer, name: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	tabs.add_child(sc)
	return v

func _row(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 300
	row.add_child(l)
	parent.add_child(row)
	return row

func _slider(parent: Control, key: String, text: String, lo: float, hi: float, step: float, fmt: String, mul := 1.0, floaty := false) -> void:
	var row := _row(parent, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size.x = 300
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := Label.new()
	val.custom_minimum_size.x = 80
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(x):
		val.text = fmt % (x * mul) if floaty else fmt % roundi(x * mul)
		if not _building: Settings.set_value(key, x); _refresh_presets())
	row.add_child(s)
	row.add_child(val)
	widgets[key] = s

func _option(parent: Control, key: String, text: String, items: Array, values: Array = []) -> void:
	var row := _row(parent, text)
	var o := OptionButton.new()
	for it in items: o.add_item(it)
	o.custom_minimum_size.x = 300
	o.item_selected.connect(func(i): if not _building: Settings.set_value(key, values[i] if values.size() else i); _refresh_presets())
	row.add_child(o)
	widgets[key] = [o, values]

func _check(parent: Control, key: String, text: String) -> void:
	var cb := CheckButton.new()
	cb.text = text
	cb.toggled.connect(func(on): if not _building: Settings.set_value(key, on); _refresh_presets())
	parent.add_child(cb)
	widgets[key] = cb

func _refresh() -> void:
	_building = true
	for k in widgets:
		if k.begins_with("preset_"): continue
		var w = widgets[k]
		var val = Settings.get_v(k)
		if w is HSlider: w.value = float(val); w.value_changed.emit(w.value)
		elif w is CheckButton: w.button_pressed = bool(val)
		elif w is Array:
			var vals: Array = w[1]
			w[0].select(vals.find(int(val)) if vals.size() else int(val))
	_building = false
	_refresh_presets()

func _refresh_presets() -> void:
	for p in ["Low", "Medium", "High", "Ultra"]:
		widgets["preset_" + p].set_pressed_no_signal(Settings.get_v("preset") == p)

func _build_credits() -> void:
	credits_panel = PanelContainer.new()
	credits_panel.position = Vector2(460, 140)
	credits_panel.custom_minimum_size = Vector2(760, 500)
	credits_panel.visible = false
	root.add_child(credits_panel)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.custom_minimum_size = Vector2(740, 480)
	var s := "[b]Credits[/b]\n\nGuns from Sketchfab (CC BY 4.0):\n"
	var c = JSON.parse_string(FileAccess.get_file_as_string("res://assets/guns/credits.json"))
	if c is Dictionary:
		for k in c:
			s += "  • %s by %s\n" % [c[k].title, c[k].author]
	s += "\nTextures, grass and props: Poly Haven (CC0).\nCharacters: Meshy, animated with Mixamo.\nEngine: Godot (MIT), terrain: Terrain3D (MIT), physics: Jolt (MIT).\nEngine, gun and creature sounds: synthesised for this game."
	t.text = s
	credits_panel.add_child(t)

func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c

func _theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.88)
	sb.border_color = Color(1, 0.9, 0.75, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", sb)
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.12, 0.1, 0.08, 0.85)
	bn.border_color = Color(1, 0.9, 0.75, 0.2)
	bn.set_border_width_all(1)
	bn.set_corner_radius_all(3)
	bn.content_margin_left = 16
	bn.content_margin_right = 16
	var bh := bn.duplicate()
	bh.bg_color = Color(0.22, 0.16, 0.1, 0.95)
	bh.border_color = ACCENT
	var bp := bn.duplicate()
	bp.bg_color = ACCENT.darkened(0.25)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, bn)
		t.set_stylebox("hover", cls, bh)
		t.set_stylebox("pressed", cls, bp)
		t.set_stylebox("focus", cls, bh)
	t.set_color("font_color", "Label", Color(0.98, 0.93, 0.85))
	return t
