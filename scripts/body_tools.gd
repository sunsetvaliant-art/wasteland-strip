class_name BodyTools
extends CanvasLayer
## Body tools (pause menu, 0.2.55): set each body model's TUB line and BONNET line once, in game, and forget it.
##   Tub, plane:   slide and tilt a see-through cutting plane behind the cab; the preview shows cab and tub in two
##                 colours. Points: click along the seam on the model for tubs whose line isn't straight
##   Bonnet:       click points round the bonnet's shut line on the body; it previews the panel that'll come off.
##                 Hinge at the back (opens at the front, the usual) or the front
## Saving writes user://body_cuts.json. Put that file in the Drive folder and it ships in the next patch for everyone.

var main
var root: Control
var panel: VBoxContainer
var cam: Camera3D
var open := false
var orbit := Vector2(0.9, 0.35)
var dist := 7.0
var spot := Vector3.ZERO
var _drag := false
var glb := ""
var keys: Array = []
var model: Node3D                 # the preview: raw meshes, or the cut pieces tinted
var plane_mi: MeshInstance3D
var markers: Node3D
var tri: Array = []               # [TriangleMesh, Transform3D (body frame -> world)] per mesh for clicking
var mode := "tub"                 # tub / bonnet
var tub := {"mode": "plane", "z": -0.4, "tilt": 0.0, "y": 0.7}
var bon := {"pts": [], "hinge": "rear"}
var tub_pts: Array = []           # [[y, z]]
var status: Label
var _preview_t := -1.0

func setup(m) -> void:
	main = m
	layer = 16
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.theme = main.pause_menu.root.theme
	root.visible = false
	add_child(root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	cam = Camera3D.new()
	cam.fov = 45
	cam.far = 2000
	main.add_child(cam)

func show_tools() -> void:
	open = true
	main.interact_menu.clear()           # 0.2.56: the look-at menu stayed up over this screen
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p = main.player
	var fwd: Vector3 = -p.global_transform.basis.z
	spot = p.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 12.0 + Vector3(0, 30.0, 0)    # up in the air: nothing in the way
	keys = Car.catalog().keys()
	keys.sort_custom(func(a, b): return str(Car.catalog()[a].name) < str(Car.catalog()[b].name))
	if glb == "": glb = str(Car.catalog()[keys[0]].glb)
	_load_cut()
	_build_ui()
	_rebuild_model()
	root.visible = true
	cam.current = true

func close() -> void:
	open = false
	root.visible = false
	cam.current = false
	if model and is_instance_valid(model): model.queue_free()
	model = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _load_cut() -> void:
	var c := BodyCut.of(glb)
	tub = c.get("tub", {"mode": "plane", "z": -0.4, "tilt": 0.0, "y": 0.7}).duplicate(true)
	tub_pts = tub.get("pts", []).duplicate(true)
	bon = c.get("bonnet", {"pts": [], "hinge": "rear"}).duplicate(true)

func _process(dt: float) -> void:
	if not open: return
	if _preview_t >= 0.0:
		_preview_t -= dt
		if _preview_t < 0.0: _rebuild_model()
	var target := spot + Vector3(0, 0.7, 0)
	cam.global_position = target + Vector3(sin(orbit.x) * cos(orbit.y), sin(orbit.y), cos(orbit.x) * cos(orbit.y)) * dist
	cam.look_at(target)
	if plane_mi:
		plane_mi.visible = mode == "tub" and str(tub.get("mode", "plane")) == "plane"
		plane_mi.position = spot + Vector3(0, float(tub.get("y", 0.7)), float(tub.z))
		plane_mi.rotation = Vector3(-deg_to_rad(float(tub.get("tilt", 0.0))), 0, 0)

func _unhandled_input(e: InputEvent) -> void:
	if not open: return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT or e.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = e.pressed
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed: dist = maxf(dist * 0.9, 2.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed: dist = minf(dist * 1.1, 20.0)
		elif e.button_index == MOUSE_BUTTON_LEFT and e.pressed: _click(e.position)
	elif e is InputEventMouseMotion and _drag:
		orbit.x -= e.relative.x * 0.006
		orbit.y = clampf(orbit.y + e.relative.y * 0.004, -0.6, 1.45)
	elif e.is_action_pressed("menu") or e.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

## Click on the model: a point on the tub seam or the bonnet's shut line
func _click(sp: Vector2) -> void:
	var from := cam.project_ray_origin(sp)
	var dir := cam.project_ray_normal(sp)
	var best := INF
	var hit := Vector3.INF
	for t in tri:
		var tm: TriangleMesh = t[0]
		var xf: Transform3D = t[1]
		var inv := xf.affine_inverse()
		var r := tm.intersect_ray(inv * from, (inv.basis * dir).normalized())
		if r.is_empty(): continue
		var wp: Vector3 = xf * (r.position as Vector3)
		var d := wp.distance_to(from)
		if d < best: best = d; hit = wp
	if hit == Vector3.INF: return
	var bp := hit - spot              # body frame (the preview sits unturned at spot)
	if mode == "tub" and str(tub.get("mode", "plane")) == "points":
		tub_pts.append([snappedf(bp.y, 0.001), snappedf(bp.z, 0.001)])
		tub.pts = tub_pts
	elif mode == "bonnet":
		(bon.pts as Array).append([snappedf(bp.x, 0.001), snappedf(bp.y, 0.001), snappedf(bp.z, 0.001)])
	else:
		return
	_markers()
	_preview_t = 0.3

func _markers() -> void:
	if markers and is_instance_valid(markers): markers.queue_free()
	markers = Node3D.new()
	main.add_child(markers)
	var pts: Array = []
	if mode == "tub":
		for q in tub_pts: pts.append(spot + Vector3(0, float(q[0]), float(q[1])))
	else:
		for q in bon.get("pts", []): pts.append(spot + Vector3(float(q[0]), float(q[1]), float(q[2])))
	var sm := SphereMesh.new(); sm.radius = 0.025; sm.height = 0.05
	var mt := StandardMaterial3D.new(); mt.albedo_color = Color(1.0, 0.85, 0.1); mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mt.no_depth_test = true
	for p in pts:
		var mi := MeshInstance3D.new(); mi.mesh = sm; mi.material_override = mt; mi.position = p
		markers.add_child(mi)

func _rebuild_model() -> void:
	if model and is_instance_valid(model): model.queue_free()
	model = Node3D.new()
	model.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(model)
	model.global_position = spot
	tri.clear()
	# save into the live table temporarily so BodyCut.pieces sees the current lines
	var entry := {}
	if str(tub.get("mode", "plane")) == "plane" or tub_pts.size() >= 2: entry["tub"] = tub
	if (bon.get("pts", []) as Array).size() >= 3: entry["bonnet"] = bon
	var prev = BodyCut.all().get(glb)
	BodyCut._cuts[glb] = entry
	BodyCut._cache.clear()
	var pcs := BodyCut.pieces(glb, entry.has("tub"), entry.has("bonnet"))
	if prev == null: BodyCut._cuts.erase(glb)
	else: BodyCut._cuts[glb] = prev
	var tint := {"cab": Color(0.45, 0.65, 1.0), "tub": Color(1.0, 0.6, 0.25), "bonnet": Color(0.4, 1.0, 0.45), "under": Color(0.2, 0.2, 0.2)}
	for part in ["cab", "tub", "bonnet"]:
		for am in pcs[part]:
			var mi := MeshInstance3D.new(); mi.mesh = am
			if mode == "tub" and part == "tub" or mode == "bonnet" and part == "bonnet":
				var m := StandardMaterial3D.new(); m.albedo_color = tint[part]
				mi.material_override = m
			model.add_child(mi)
			tri.append([am.generate_triangle_mesh(), mi.global_transform])
	# the cutting plane
	if plane_mi == null or not is_instance_valid(plane_mi):
		plane_mi = MeshInstance3D.new()
		var pm := QuadMesh.new(); pm.size = Vector2(2.6, 2.4)
		plane_mi.mesh = pm
		var m2 := StandardMaterial3D.new(); m2.albedo_color = Color(1, 0.2, 0.2, 0.28); m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m2.cull_mode = BaseMaterial3D.CULL_DISABLED; m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plane_mi.material_override = m2
		main.add_child(plane_mi)
	_markers()
	var n_t := 0; var n_c := 0; var n_b := 0
	for am in pcs.tub: n_t += 1
	for am in pcs.bonnet: n_b += 1
	if status: status.text = "%s · tub pieces %d · bonnet pieces %d" % [glb, n_t, n_b]

func _save() -> void:
	var entry := {}
	if str(tub.get("mode", "plane")) == "plane": entry["tub"] = {"mode": "plane", "z": snappedf(float(tub.z), 0.001), "tilt": snappedf(float(tub.get("tilt", 0.0)), 0.1), "y": snappedf(float(tub.get("y", 0.7)), 0.001)}
	elif tub_pts.size() >= 2: entry["tub"] = {"mode": "points", "pts": tub_pts}
	if (bon.get("pts", []) as Array).size() >= 3: entry["bonnet"] = bon
	if not use_tub: entry.erase("tub")
	BodyCut.save(glb, entry)
	if status: status.text = "Saved to %s  (put that file in the Drive folder to ship it)" % BodyCut.user_file_path()

var use_tub := true

# ------------------------------------------------------------------------------------------------ UI
func _build_ui() -> void:
	for c in root.get_children(): c.queue_free()
	var bg := PanelContainer.new()
	bg.position = Vector2(16, 16)
	bg.custom_minimum_size = Vector2(420, 0)
	root.add_child(bg)
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	bg.add_child(panel)
	var t := Label.new(); t.text = "BODY TOOLS"; panel.add_child(t)
	var n := Label.new(); n.text = "Right-drag to look round · wheel to zoom · left-click on the body to place points · Esc to leave"
	n.autowrap_mode = TextServer.AUTOWRAP_WORD; n.custom_minimum_size = Vector2(400, 0); n.modulate.a = 0.7
	panel.add_child(n)
	var ob := OptionButton.new()
	var sel := 0
	for i in keys.size():
		var d: Dictionary = Car.catalog()[keys[i]]
		var mark := " *" if not BodyCut.of(str(d.glb)).is_empty() else ""
		ob.add_item(str(d.name) + mark)
		if str(d.glb) == glb: sel = i
	ob.selected = sel
	ob.item_selected.connect(func(i):
		glb = str(Car.catalog()[keys[i]].glb)
		_load_cut()
		_build_ui()
		_rebuild_model())
	panel.add_child(ob)
	var tabs := HBoxContainer.new(); panel.add_child(tabs)
	for md in [["tub", "Tub line"], ["bonnet", "Bonnet line"]]:
		var b := Button.new(); b.text = md[1]; b.toggle_mode = true; b.button_pressed = mode == md[0]
		b.pressed.connect(func():
			mode = md[0]
			_build_ui()
			_rebuild_model())
		tabs.add_child(b)
	if mode == "tub":
		var uc := CheckBox.new(); uc.text = "This model has a separate tub"; uc.button_pressed = use_tub
		uc.toggled.connect(func(v): use_tub = v)
		panel.add_child(uc)
		var mb := HBoxContainer.new(); panel.add_child(mb)
		for md in [["plane", "Cutting plane"], ["points", "Click the seam"]]:
			var b := Button.new(); b.text = md[1]; b.toggle_mode = true; b.button_pressed = str(tub.get("mode", "plane")) == md[0]
			b.pressed.connect(func():
				tub.mode = md[0]
				_build_ui(); _rebuild_model())
			mb.add_child(b)
		if str(tub.get("mode", "plane")) == "plane":
			_slider("Position along the car (m)", -3.5, 2.0, 0.005, float(tub.get("z", -0.4)), func(v): tub.z = v; _preview_t = 0.35)
			_slider("Tilt (degrees)", -30.0, 30.0, 0.5, float(tub.get("tilt", 0.0)), func(v): tub.tilt = v; _preview_t = 0.35)
			_slider("Tilt pivot height (m)", 0.0, 2.0, 0.01, float(tub.get("y", 0.7)), func(v): tub.y = v; _preview_t = 0.35)
		else:
			_button("Undo last point", func():
				if not tub_pts.is_empty(): tub_pts.pop_back()
				tub.pts = tub_pts; _markers(); _preview_t = 0.2)
			_button("Clear points", func():
				tub_pts.clear(); tub.pts = tub_pts; _markers(); _preview_t = 0.2)
	else:
		var hb := HBoxContainer.new(); panel.add_child(hb)
		for hg in [["rear", "Hinge at the back"], ["front", "Hinge at the front"]]:
			var b := Button.new(); b.text = hg[1]; b.toggle_mode = true; b.button_pressed = str(bon.get("hinge", "rear")) == hg[0]
			b.pressed.connect(func():
				bon.hinge = hg[0]; _build_ui())
			hb.add_child(b)
		_button("Undo last point", func():
			if not (bon.pts as Array).is_empty(): (bon.pts as Array).pop_back()
			_markers(); _preview_t = 0.2)
		_button("Clear the shut line", func():
			bon.pts = []; _markers(); _preview_t = 0.2)
		var l := Label.new(); l.text = "Click round the bonnet's edge in order (8-20 points). Green = what comes off."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size = Vector2(400, 0); panel.add_child(l)
	_button("SAVE this model's lines", _save)
	_button("Close", close)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD; status.custom_minimum_size = Vector2(400, 0)
	status.text = glb
	panel.add_child(status)

func _slider(label: String, lo: float, hi: float, step: float, val: float, cb: Callable) -> void:
	var l := Label.new(); l.text = "%s: %.3f" % [label, val]; panel.add_child(l)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = step; s.value = val
	s.custom_minimum_size = Vector2(400, 24)
	s.value_changed.connect(func(v):
		l.text = "%s: %.3f" % [label, v]
		cb.call(v))
	panel.add_child(s)

func _button(label: String, cb: Callable) -> void:
	var b := Button.new(); b.text = label; b.pressed.connect(cb); panel.add_child(b)
