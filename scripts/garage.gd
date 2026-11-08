class_name Garage
extends CanvasLayer
## The vehicle builder. Pick a cab, sit it on a ladder chassis of any length, and spec everything under it: engine,
## gearbox, diff ratio, how many axles and where, independent or live, coils or leaves, spring rate (as ride
## frequency), travel, damping, sway bars, track, tyres, brakes, which axles steer and drive and what diff they've got.
## The preview rebuilds as you change things. Save builds by name, load them back, then drive it out.
## Opened from the pause menu (creative).

const DIR := "user://designs/"
var main
var root: Control
var panel: VBoxContainer
var design: Dictionary
var preview: Car
var cam: Camera3D
var orbit := Vector2(0.7, 0.32)
var dist := 7.5
var spot := Vector3.ZERO
var open := false
var cab_on := true
var name_edit: LineEdit
var load_opt: OptionButton
var axle_tabs: TabContainer
var _rebuild_t := -1.0
var _dragging := false
var target: Car = null            # working on a car that's already out in the world (survival, with a shifter)

func setup(m) -> void:
	main = m
	layer = 15
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.theme = main.pause_menu.root.theme
	add_child(root)
	root.visible = false
	cam = Camera3D.new()
	cam.fov = 50
	cam.far = 3000
	main.add_child(cam)
	cam.add_to_group("cameras")

func toggle() -> void:
	if open: close()
	else: show_garage()

func show_garage(from: Dictionary = {}, on_car: Car = null) -> void:
	if open:
		return
	target = on_car
	open = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true                # the world waits while you build
	main.player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p: Player = main.player
	var fwd: Vector3 = -p.global_transform.basis.z
	spot = p.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 9.0
	spot.y = main.ground_at(spot.x, spot.z)
	if target:
		spot = target.global_position
		spot.y = main.ground_at(spot.x, spot.z)
		target.visible = false
		target.freeze = true
	design = (from if not from.is_empty() else VehicleSpecs.default_design("vjwagon")).duplicate(true)
	_build_ui()
	root.visible = true
	cam.current = true
	_rebuild()

func close() -> void:
	open = false
	if target and is_instance_valid(target):
		target.visible = true
		target.freeze = false
	target = null
	get_tree().paused = false
	root.visible = false
	if preview and is_instance_valid(preview):
		preview.queue_free()
	preview = null
	main.player.active = true
	main.player._apply_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func drive() -> void:
	var c := preview
	preview = null
	var old := target
	target = null
	var yaw := 0.0
	if old and is_instance_valid(old):
		# it replaces the car you worked on, where it stood, with what was in the boot
		yaw = old.rotation.y
		if old.has_meta("inv") and c.has_meta("container"): c.set_meta("inv", old.get_meta("inv"))
		for m in ["player_car", "home_name"]:
			if old.has_meta(m): c.set_meta(m, old.get_meta(m))
		old.queue_free()
	close()
	c.rotation.y = yaw
	c.process_mode = Node.PROCESS_MODE_INHERIT
	c.freeze = false
	c.global_position = spot + Vector3(0, float(design.axles[0].tyre_r) - float(design.ride) + 0.3, 0)
	var p: Player = main.player
	p.global_position = c.global_position + Vector3(1.5, 0, 0)
	p._try_get_in()

# ---------------------------------------------------------------- preview
func _rebuild() -> void:
	if preview and is_instance_valid(preview):
		preview.queue_free()
	preview = Car.new()
	preview.design = design.duplicate(true)
	preview.freeze = true
	preview.process_mode = Node.PROCESS_MODE_ALWAYS     # so the chassis parts get posed while paused
	main.add_child(preview)
	# body origin sits "ride" above the wheel centres, wheel centres a tyre radius off the ground
	preview.global_position = spot + Vector3(0, float(design.axles[0].tyre_r) - float(design.ride) + 0.02, 0)

	# let the suspension settle onto its static height for the picture: wheels at the static droop
	for w in preview.wheels:
		w.L = 0.6 * float(w.T)

func _process(dt: float) -> void:
	if not open:
		return
	if _rebuild_t >= 0.0:
		_rebuild_t -= dt
		if _rebuild_t < 0.0:
			_rebuild()
	if not cam.current:
		cam.current = true
	var target := spot + Vector3(0, 0.8, 0)
	var cp := target + Vector3(sin(orbit.x) * cos(orbit.y), sin(orbit.y), cos(orbit.x) * cos(orbit.y)) * dist
	cp.y = max(cp.y, main.ground_at(cp.x, cp.z) + 1.2)       # never inside the hill
	cam.global_position = cp
	cam.look_at(target)

func _unhandled_input(e: InputEvent) -> void:
	if not open:
		return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT or e.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = e.pressed
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			dist = max(dist * 0.9, 2.5)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			dist = min(dist * 1.1, 25.0)
	elif e is InputEventMouseMotion and _dragging:
		orbit.x -= e.relative.x * 0.006
		orbit.y = clamp(orbit.y + e.relative.y * 0.004, -0.15, 1.4)
	elif e.is_action_pressed("menu"):
		close()
		get_viewport().set_input_as_handled()

func _changed() -> void:
	_rebuild_t = 0.25          # rebuild once you stop dragging

# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	for c in root.get_children():
		c.queue_free()
	var bg := PanelContainer.new()
	bg.position = Vector2(16, 16)
	bg.custom_minimum_size = Vector2(430, 0)
	bg.size = Vector2(430, root.get_viewport_rect().size.y - 32)
	root.add_child(bg)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(sc)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 6)
	sc.add_child(panel)
	_title("GARAGE")
	_note("Right-drag to look around · wheel to zoom · Esc to leave")
	# --- cab
	_title("Cab")
	var cabs: Array = Car.catalog().keys()
	cabs.sort_custom(func(a, b): return str(Car.catalog()[a].name) < str(Car.catalog()[b].name))
	_choice("Body", cabs.map(func(k): return Car.catalog()[k].name), cabs.find(design.cab), func(i):
		var k: String = cabs[i]
		var keep := design.duplicate(true)
		design = VehicleSpecs.default_design(k)
		# keep the running gear you'd already picked
		for f in ["engine", "gearbox", "final"]: design[f] = keep[f]
		_build_ui()
		_changed())
	var off: Array = design.cab_offset
	_slider("Cab fore / aft", -1.5, 1.5, 0.01, off[2], func(v): off[2] = v; _changed())
	_slider("Cab height on frame", -0.3, 0.8, 0.01, off[1], func(v): off[1] = v; _changed())
	_slider("Cab sideways", -0.3, 0.3, 0.01, off[0], func(v): off[0] = v; _changed())
	_check("Body fitted (off = bare chassis)", not design.get("no_cab", false), func(v):
		design.no_cab = not v
		_changed())
	# --- chassis
	_title("Chassis")
	var fr: Dictionary = design.frame
	_slider("Frame length (m)", 2.5, 10.0, 0.05, fr.len, func(v): fr.len = v; _changed())
	_slider("Frame centre (m)", -3.0, 3.0, 0.05, fr.z, func(v): fr.z = v; _changed())
	_slider("Rail spacing (m)", 0.6, 1.4, 0.01, fr.width, func(v): fr.width = v; _changed())
	_slider("Body height over the axles (m)", -1.2, 0.6, 0.01, design.ride, func(v): design.ride = v; _changed())
	_slider("Kerb mass (kg)", 600.0, 9000.0, 10.0, design.mass, func(v): design.mass = v; _changed())
	_slider("Weight on the front axle", 0.3, 0.75, 0.01, design.front_share, func(v): design.front_share = v; _changed())
	# --- driveline
	_title("Driveline")
	var engines: Array = VehicleSpecs.ENGINES.keys()
	_choice("Engine", engines.map(func(k): return VehicleSpecs.ENGINES[k].name), engines.find(design.engine), func(i): design.engine = engines[i]; _changed())
	var boxes: Array = VehicleSpecs.GEARBOXES.keys()
	_choice("Gearbox", boxes.map(func(k): return VehicleSpecs.GEARBOXES[k].name), boxes.find(design.gearbox), func(i): design.gearbox = boxes[i]; _changed())
	_slider("Diff ratio (final drive)", 2.5, 6.5, 0.01, design.final, func(v): design.final = v; _changed())
	# --- wheels and tyres
	_title("Wheels")
	var wkeys: Array = VehicleRig.WHEEL_MODELS.keys()
	_choice("Wheels", wkeys.map(func(k): return VehicleRig.WHEEL_MODELS[k].name), wkeys.find(str(design.get("wheel_model", "stock"))), func(i): design.wheel_model = wkeys[i]; _changed())
	_slider("Tyre pressure (psi)", 12.0, 50.0, 1.0, float(design.get("tyre_psi", 32.0)), func(v): design.tyre_psi = v; _changed())
	# --- axles
	_title("Axles")
	var row := HBoxContainer.new()
	panel.add_child(row)
	var add := Button.new()
	add.text = "+ Add axle"
	add.pressed.connect(func():
		var last: Dictionary = design.axles[-1].duplicate(true)
		last.z = float(last.z) - 1.35
		last.steer = false
		design.axles.append(last)
		_build_ui()
		_changed())
	row.add_child(add)
	var rem := Button.new()
	rem.text = "- Remove last"
	rem.disabled = design.axles.size() <= 2
	rem.pressed.connect(func():
		design.axles.pop_back()
		_build_ui()
		_changed())
	row.add_child(rem)
	axle_tabs = TabContainer.new()
	axle_tabs.custom_minimum_size = Vector2(0, 620)
	panel.add_child(axle_tabs)
	for ai in design.axles.size():
		_axle_page(ai)
	# --- save / load / go
	_title("Your builds")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "name this build"
	name_edit.text = str(design.get("title", ""))
	panel.add_child(name_edit)
	var r2 := HBoxContainer.new()
	panel.add_child(r2)
	var save := Button.new()
	save.text = "Save build"
	save.pressed.connect(_save)
	r2.add_child(save)
	load_opt = OptionButton.new()
	load_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(load_opt)
	_refresh_saves()
	load_opt.item_selected.connect(func(i):
		if i <= 0: return
		var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + load_opt.get_item_text(i) + ".json"))
		if d is Dictionary:
			design = d
			_build_ui()
			_changed())
	var go := Button.new()
	go.text = "DRIVE IT"
	go.custom_minimum_size = Vector2(0, 48)
	go.pressed.connect(drive)
	panel.add_child(go)
	var cl := Button.new()
	cl.text = "Close"
	cl.pressed.connect(close)
	panel.add_child(cl)

func _axle_page(ai: int) -> void:
	var a: Dictionary = design.axles[ai]
	var page := VBoxContainer.new()
	page.name = ["Front", "Rear", "Third", "Fourth", "Fifth"][min(ai, 4)] if ai < 2 or design.axles.size() > 2 else "Axle %d" % (ai + 1)
	axle_tabs.add_child(page)
	var old := panel
	panel = page
	_slider("Position (m from centre, + = forward)", -6.0, 4.0, 0.01, a.z, func(v): a.z = v; _changed())
	_choice("Suspension", ["Independent (wishbones)", "Live axle"], 0 if a.type == "ifs" else 1, func(i): a.type = "ifs" if i == 0 else "live"; _changed())
	_choice("Springs", ["Coils", "Leaf packs"], 0 if a.spring == "coil" else 1, func(i): a.spring = "coil" if i == 0 else "leaf"; _changed())
	_slider("Spring rate (ride frequency, Hz)", 0.8, 2.6, 0.01, a.freq, func(v): a.freq = v; _changed())
	_slider("Wheel travel (m)", 0.08, 0.5, 0.01, a.travel, func(v): a.travel = v; _changed())
	_slider("Damping, bump", 0.1, 0.9, 0.01, a.zeta_b, func(v): a.zeta_b = v; _changed())
	_slider("Damping, rebound", 0.2, 1.2, 0.01, a.zeta_r, func(v): a.zeta_r = v; _changed())
	_slider("Sway bar (N/m, 0 = none)", 0.0, 40000.0, 500.0, a.arb, func(v): a.arb = v; _changed())
	_slider("Track (half, m)", 0.5, 1.2, 0.01, a.track, func(v): a.track = v; _changed())
	_slider("Tyre radius (m)", 0.26, 0.6, 0.005, a.tyre_r, func(v): a.tyre_r = v; _changed())
	_slider("Tyre width (m)", 0.14, 0.42, 0.005, a.tyre_w, func(v): a.tyre_w = v; _changed())
	_slider("Brake torque (Nm)", 300.0, 6000.0, 50.0, a.brake, func(v): a.brake = v; _changed())
	_check("Steers", a.steer, func(v): a.steer = v; _changed())
	_check("Driven", a.drive, func(v): a.drive = v; _changed())
	_choice("Diff", ["Open", "Limited slip", "Locked"], ["open", "lsd", "locked"].find(a.get("diff", "open")), func(i): a.diff = ["open", "lsd", "locked"][i]; _changed())
	panel = old

func _save() -> void:
	var n := name_edit.text.strip_edges().validate_filename()
	if n == "":
		n = "build_%d" % Time.get_unix_time_from_system()
	design.title = n
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR + n + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(design, "\t"))
	f.close()
	_refresh_saves()

func _refresh_saves() -> void:
	load_opt.clear()
	load_opt.add_item("Load a build…")
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			if f.ends_with(".json"):
				load_opt.add_item(f.get_basename())

## Saved builds (for the Forge palette and anything else that wants to spawn one)
static func saved_designs() -> Dictionary:
	var out := {}
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			if f.ends_with(".json"):
				var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + f))
				if d is Dictionary: out[f.get_basename()] = d
	return out

# ---------------------------------------------------------------- widgets
func _title(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 22 if t != "GARAGE" else 34)
	l.add_theme_color_override("font_color", PauseMenu.ACCENT)
	panel.add_child(l)

func _note(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.modulate = Color(1, 1, 1, 0.6)
	l.add_theme_font_size_override("font_size", 13)
	panel.add_child(l)

func _slider(label: String, lo: float, hi: float, step: float, val, cb: Callable) -> void:
	var l := Label.new()
	panel.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(val)
	s.custom_minimum_size = Vector2(380, 22)
	var fmt := func(v): l.text = "%s:  %s" % [label, ("%.0f" % v) if step >= 1.0 else ("%.2f" % v)]
	fmt.call(float(val))
	s.value_changed.connect(func(v):
		fmt.call(v)
		cb.call(v))
	panel.add_child(s)

func _choice(label: String, items: Array, sel: int, cb: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	h.add_child(l)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		o.add_item(str(it))
	o.select(max(sel, 0))
	o.item_selected.connect(cb)
	h.add_child(o)
	panel.add_child(h)

func _check(label: String, val: bool, cb: Callable) -> void:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = val
	c.toggled.connect(cb)
	panel.add_child(c)
