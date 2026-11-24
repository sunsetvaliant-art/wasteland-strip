class_name CharacterScreen
extends CanvasLayer
## 0.2.75: your survivor. Pick a person (the MakeHuman people), your height and build, and see yourself turn round in what you're
## wearing (your clothes come from the inventory: put a shirt on and it's on you). Comes up the first time you play,
## and from the pause menu any time. Saved in Settings "char".

## the MakeHuman people (Outfit.MH_PEOPLE), and the original survivor
static func bodies() -> Array:
	var out := []
	for k in Outfit.MH_PEOPLE: out.append([k, Outfit.MH_PEOPLE[k]])
	out.append(["player", "The original survivor"])
	return out
var main
var root: Control
var vp: SubViewport
var pv_rig: Rig
var pv_holder: Node3D
var ch := {}
var _spin := 0.0
var _drag := false
var open := false

func setup(m) -> void:
	main = m
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.03, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 60; hb.offset_top = 50; hb.offset_right = -60; hb.offset_bottom = -50
	hb.add_theme_constant_override("separation", 40)
	root.add_child(hb)
	# the preview: you, turning round
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(460, 640)
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_drag_input)
	hb.add_child(svc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	svc.add_child(vp)
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.16, 0.17, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.75, 0.75, 0.72); env.ambient_light_energy = 0.7
	we.environment = env; vp.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 30, 0); sun.light_energy = 1.2; vp.add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-20, 200, 0); fill.light_energy = 0.4; vp.add_child(fill)
	var cam := Camera3D.new(); cam.fov = 30; vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.15, 4.4), Vector3(0, 0.95, 0))
	var floor_m := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.7; cm.bottom_radius = 0.7; cm.height = 0.02
	floor_m.mesh = cm; floor_m.position.y = -0.01; vp.add_child(floor_m)
	pv_holder = Node3D.new(); vp.add_child(pv_holder)
	# the choices
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(380, 0)
	col.add_theme_constant_override("separation", 14)
	hb.add_child(col)
	var title := Label.new(); title.text = "YOUR SURVIVOR"; title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.94, 0.65, 0.23)); col.add_child(title)
	var note := Label.new(); note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "What you wear is what's in your clothes slots (I): find a flanno, put it on, and it's on you."
	note.modulate = Color(1, 1, 1, 0.7); col.add_child(note)
	col.add_child(_label("Body"))
	var bh := GridContainer.new(); bh.columns = 2; col.add_child(bh)
	for b in bodies():
		var btn := Button.new(); btn.text = b[1]; btn.toggle_mode = true
		btn.pressed.connect(func(): _choose("body", b[0]))
		btn.set_meta("body", b[0])
		bh.add_child(btn)
	col.add_child(_slider("Height", "height", 0.92, 1.08))
	col.add_child(_slider("Build", "width", 0.92, 1.14))
	var done := Button.new(); done.text = "Done"; done.custom_minimum_size = Vector2(0, 44)
	done.pressed.connect(close)
	col.add_child(done)
	root.visible = false

func _label(t: String) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", 20)
	return l

func _slider(t: String, key: String, lo: float, hi: float) -> Control:
	var v := VBoxContainer.new()
	v.add_child(_label(t))
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = 0.005
	s.custom_minimum_size = Vector2(340, 24)
	s.set_meta("key", key)
	s.value_changed.connect(func(x): _choose(key, x))
	v.add_child(s)
	return v

func show_screen() -> void:
	ch = (Settings.v.get("char", {}) as Dictionary).duplicate()
	for k in [["body", "mh_m_young"], ["height", 1.0], ["width", 1.0], ["tone", 1.0]]:
		if not ch.has(k[0]): ch[k[0]] = k[1]
	for s in root.find_children("*", "HSlider", true, false):
		(s as HSlider).set_value_no_signal(float(ch.get(str(s.get_meta("key")), 1.0)))
	_mark_body()
	open = true
	root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_preview(true)

func close() -> void:
	open = false
	root.visible = false
	Settings.v["char"] = ch
	Settings.save()
	if main and main.player:
		main.player.set_body(str(ch.body))
		main.player.refresh_outfit()
	if pv_rig: pv_rig.queue_free(); pv_rig = null
	if main and main.pause_menu and main.pause_menu.open: return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _choose(k: String, val) -> void:
	var body_changed: bool = k == "body" and val != ch.get("body")
	ch[k] = val
	_mark_body()
	_preview(body_changed)

func _mark_body() -> void:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).has_meta("body"): (b as Button).button_pressed = str(b.get_meta("body")) == str(ch.get("body", "player"))

## the preview's you: your body and build, in your clothes
func _preview(rebuild: bool) -> void:
	if rebuild or pv_rig == null:
		if pv_rig: pv_rig.queue_free()
		pv_rig = Rig.new()
		pv_holder.add_child(pv_rig)
		pv_rig.load_model(str(ch.body))
		pv_rig.play("Idle_8")
	var eq: Dictionary = main.player.inv.equip if main and main.player and main.player.inv else {}
	var lk := Outfit.look_from_equip(eq, {"body": ch.body, "height": ch.height, "width": ch.width, "tone": ch.tone, "wear": 0.15})
	if pv_rig.look.is_empty(): pv_rig.dress(lk)
	lk["skin"] = Outfit.skin_of(pv_rig.model_path) * float(ch.tone)
	pv_rig.restyle(lk)
	pv_rig.set_build(float(ch.height), float(ch.width))

func _drag_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed
	elif e is InputEventMouseMotion and _drag:
		_spin += (e as InputEventMouseMotion).relative.x * 0.01

func _process(dt: float) -> void:
	if not open or pv_holder == null: return
	if not _drag: _spin += dt * 0.5
	pv_holder.rotation.y = _spin
