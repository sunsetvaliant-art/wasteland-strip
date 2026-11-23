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
# 0.2.64: free cam to fly in and out of the mesh: WASD, Q/E (or Ctrl/Space) down/up, right-drag looks, wheel sets the
# speed (starts slow), Shift x4. F toggles it.
var freecam := false
var fc_yaw := 0.0
var fc_pitch := 0.0
var fc_speed := 0.35
var dist := 7.0
var spot := Vector3.ZERO
var _drag := false
var glb := ""
var keys: Array = []
var model: Node3D                 # the preview: raw meshes, or the cut pieces tinted
var plane_mi: MeshInstance3D
var markers: Node3D
var tri: Array = []               # [TriangleMesh, Transform3D (body frame -> world)] per mesh for clicking
var mode := "paint"               # paint (0.2.59) / tub / bonnet
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
	var c: Dictionary = BodyCut.all().get(glb, {})          # the saved entry itself, not what paint works out from it
	tub = c.get("tub", {"mode": "plane", "z": -0.4, "tilt": 0.0, "y": 0.7}).duplicate(true)
	tub_pts = tub.get("pts", []).duplicate(true)
	bon = c.get("bonnet", {"pts": [], "hinge": "rear"}).duplicate(true)

func _process(dt: float) -> void:
	if not open: return
	# a button let go over the side panel goes to the panel, not here: don't stay painting / turning
	if painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		painting = false
		if _lift_dirty: _lift_refresh()
	if _drag and not (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)): _drag = false
	if _preview_t >= 0.0:
		_preview_t -= dt
		if _preview_t < 0.0: _rebuild_model()
	var target := spot + Vector3(0, 0.7, 0)
	if freecam:
		_freecam_move(dt)
	else:
		cam.global_position = target + Vector3(sin(orbit.x) * cos(orbit.y), sin(orbit.y), cos(orbit.x) * cos(orbit.y)) * dist
		cam.look_at(target)
	if plane_mi:
		plane_mi.visible = mode == "tub" and str(tub.get("mode", "plane")) == "plane"
		plane_mi.position = spot + Vector3(0, float(tub.get("y", 0.7)), float(tub.z))
		plane_mi.rotation = Vector3(-deg_to_rad(float(tub.get("tilt", 0.0))), 0, 0)

## The mouse comes here after the GUI has had it (0.2.62: 0.2.61 read it ahead of the GUI, which swallowed the
## release of every click on the side panel, so no button worked, and every click on the F9 form)
func set_freecam(on: bool) -> void:
	freecam = on
	cam.near = 0.01 if on else 0.05
	if on:
		# start where the orbit camera is, looking the same way
		var f := -cam.global_transform.basis.z
		fc_yaw = atan2(-f.x, -f.z)
		fc_pitch = asin(clampf(f.y, -1.0, 1.0))
	if panel: _build_ui()

func _freecam_move(dt: float) -> void:
	var b := Basis(Vector3.UP, fc_yaw) * Basis(Vector3.RIGHT, fc_pitch)
	var mv := Vector3.ZERO
	if not (get_viewport().gui_get_focus_owner() is LineEdit):
		if Input.is_physical_key_pressed(KEY_W): mv.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S): mv.z += 1.0
		if Input.is_physical_key_pressed(KEY_A): mv.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): mv.x += 1.0
		if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE): mv.y += 1.0
		if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_CTRL): mv.y -= 1.0
	var sp := fc_speed * (4.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	var d := b * Vector3(mv.x, 0.0, mv.z) + Vector3(0.0, mv.y, 0.0)
	if d.length_squared() > 0.0: cam.global_position += d.normalized() * sp * dt
	cam.global_basis = b

func _unhandled_input(e: InputEvent) -> void:
	if not open: return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F and not (get_viewport().gui_get_focus_owner() is LineEdit):
		set_freecam(not freecam)
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("menu") or e.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT or e.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = e.pressed
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			if freecam: fc_speed = minf(fc_speed * 1.25, 8.0)
			else: dist = maxf(dist * 0.9, 2.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			if freecam: fc_speed = maxf(fc_speed / 1.25, 0.05)
			else: dist = minf(dist * 1.1, 20.0)
		elif e.button_index == MOUSE_BUTTON_LEFT and mode == "paint" and pt_layer == "lights":
			if e.pressed: _light_click(e.position)
		elif e.button_index == MOUSE_BUTTON_LEFT and mode == "paint":
			painting = e.pressed
			if e.pressed: _paint_at(e.position, true)
			elif _lift_dirty: _lift_refresh()
		elif e.button_index == MOUSE_BUTTON_LEFT and e.pressed: _click(e.position)
		else: return
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion:
		if painting:
			_paint_at(e.position)
		elif _drag and freecam:
			fc_yaw -= e.relative.x * 0.004
			fc_pitch = clampf(fc_pitch - e.relative.y * 0.004, -1.5, 1.5)
		elif _drag:
			orbit.x -= e.relative.x * 0.006
			orbit.y = clampf(orbit.y + e.relative.y * 0.004, -0.6, 1.45)
		else:
			return
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
	if mode == "paint":
		_paint_build()
		if plane_mi and is_instance_valid(plane_mi): plane_mi.visible = false
		_markers()
		return
	# save into the live table temporarily so BodyCut.pieces sees the current lines
	var entry := {}
	if str(tub.get("mode", "plane")) == "plane" or tub_pts.size() >= 2: entry["tub"] = tub
	if (bon.get("pts", []) as Array).size() >= 3: entry["bonnet"] = bon
	if pt_glb == glb and pt_lab.size() > 0: entry["paint"] = {"n": pt_lab.size(), "runs": BodyCut.runs_of(pt_lab)}
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
	# 0.2.59: the paint, as runs of triangles; a painted bonnet keeps its hinge side
	if pt_glb == glb and pt_lab.size() > 0:
		var runs := BodyCut.runs_of(pt_lab)
		if not runs.is_empty():
			entry["paint"] = {"n": pt_lab.size(), "runs": runs}
			var has_t := false; var has_b := false
			for r in runs:
				if int(r[2]) == 2: has_t = true
				if int(r[2]) == 3: has_b = true
			if has_t: entry.erase("tub")                         # a painted tub is the tub, no plane behind it
			if has_b: entry["bonnet"] = {"hinge": str(bon.get("hinge", "rear")), "pts": []}
	if pt_glb == glb:
		if not pt_parts.is_empty(): entry["parts"] = pt_parts.duplicate(true)
		var rr := BodyCut.runs_of(pt_res)
		if not rr.is_empty(): entry["respray"] = {"n": pt_res.size(), "runs": rr}
		if not pt_lights.is_empty(): entry["lights"] = pt_lights.duplicate(true)
	BodyCut.save(glb, entry)
	if status: status.text = "Saved to %s  (put that file in the Drive folder to ship it)" % BodyCut.user_file_path()

var use_tub := true
var bg_panel: Control

# ------------------------------------------------------------------------------------------------ UI
func _build_ui() -> void:
	for c in root.get_children(): c.queue_free()
	var bg := PanelContainer.new()
	bg_panel = bg
	bg.position = Vector2(16, 16)
	bg.custom_minimum_size = Vector2(420, 0)
	root.add_child(bg)
	# 0.2.61: it scrolls (the painter's help pushed Save and Close off the bottom of a 720 p screen)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(430, maxf(get_viewport().get_visible_rect().size.y - 40.0, 300.0))
	bg.add_child(sc)
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	sc.add_child(panel)
	var t := Label.new(); t.text = "BODY TOOLS"; panel.add_child(t)
	var fcb := Button.new(); fcb.toggle_mode = true; fcb.button_pressed = freecam
	fcb.text = ("FREE CAM on: WASD fly, Q/E down/up, right-drag look, wheel speed %.2f m/s, Shift x4 · F" % fc_speed) if freecam else "FREE CAM (F): fly in and out of the mesh"
	fcb.autowrap_mode = TextServer.AUTOWRAP_WORD
	fcb.pressed.connect(func(): set_freecam(not freecam))
	panel.add_child(fcb)
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
	for md in [["paint", "Paint"], ["tub", "Tub line"], ["bonnet", "Bonnet line"]]:
		var b := Button.new(); b.text = md[1]; b.toggle_mode = true; b.button_pressed = mode == md[0]
		b.pressed.connect(func():
			mode = md[0]
			_build_ui()
			_rebuild_model())
		tabs.add_child(b)
	if mode == "paint":
		_paint_ui()
	elif mode == "tub":
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
	_button("SAVE this model's cut", _save)
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

# ------------------------------------------------------------------------------------------------ the mesh painter (0.2.59)
## Brush the model's own triangles: tub, bonnet, or back to cab. Works on any shape of tub or bonnet, both skins of a
## panel at once ("through"), and starts from whatever the lines already cut if you like.
var pt_lab := PackedByteArray()          # per triangle: 0 unpainted, 1 cab, 2 tub, 3 bonnet
var pt_tris := PackedVector3Array()      # body frame, 3 a triangle, in BodyCut's triangle order
var pt_ctr := PackedVector3Array()
var pt_nrm := PackedVector3Array()
var pt_grid := {}                        # Vector3i (25 cm cells) -> Array of triangles: every one whose box touches the cell
## (0.2.61: these were PackedInt32Arrays appended through a cast, which appends to a copy: the grid stayed empty and
## the brush found nothing to paint. Plain Arrays are shared, so append sticks)
const PT_CELL := 0.25
var pt_tm: TriangleMesh
var pt_glb := ""
var pt_part := 2
var pt_rad := 0.12
var pt_through := true
var painting := false
var pt_chunks: Array = []
const PT_CH := 4096
const PT_COL := [Color(0.62, 0.62, 0.64), Color(0.45, 0.65, 1.0), Color(1.0, 0.6, 0.25), Color(0.4, 1.0, 0.45)]

var pt_lights: Array = []                  # 0.2.68: lamps (Lamps): [{t, p, n, s, a, d}]
var lt_type := "round"
var lt_size := 0.18
var lt_aspect := 0.55
var lt_depth := 0.0
var lt_mirror := true
var _lt_node: Node3D
var pt_parts: Array = []                   # 0.2.68: your own parts, labels 4+: [{name, off}]
var pt_res := PackedByteArray()            # 0.2.68: the respray mask, 1 = takes the car's paint colour
var pt_layer := "parts"                    # parts (cab / tub / bonnet / yours) or respray
var pt_res_val := 1
var pt_prev_col := Color(0.12, 0.3, 0.7)
var _new_part_name := ""
var pt_base := PackedVector3Array()        # the model's triangles as they are (pt_tris is what's shown: bonnet lifted or not)
var pt_hide := -1                          # 0.2.71: faces painted as this part are hidden (and can't be picked) so you can see under them
var pt_lift := false                       # 0.2.63: "Lift bonnet": the bonnet faces swing up on the hinge so you can paint under
var _lift_dirty := false
const LIFT_DEG := 60.0

func _paint_load() -> void:
	if pt_glb == glb and not pt_base.is_empty(): return
	pt_glb = glb
	pt_hide = -1
	pt_base = PackedVector3Array()
	for m in BodyCut.meshes_of(glb):
		var mesh: Mesh = m.mesh
		var xf: Transform3D = m.xf
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var nt := (I.size() if not I.is_empty() else V.size()) / 3
			for t in nt:
				for k in 3:
					pt_base.append(xf * V[I[t * 3 + k] if not I.is_empty() else t * 3 + k])
	var ntri := pt_base.size() / 3
	var raw: Dictionary = BodyCut.all().get(glb, {})
	pt_lab = BodyCut.labels_of(raw.get("paint", {})) if int(raw.get("paint", {}).get("n", -1)) == ntri else PackedByteArray()
	if pt_lab.size() != ntri:
		pt_lab = PackedByteArray(); pt_lab.resize(ntri)
	pt_parts = (raw.get("parts", []) as Array).duplicate(true)
	pt_lights = (raw.get("lights", []) as Array).duplicate(true)
	pt_res = BodyCut.labels_of(raw.get("respray", {})) if int(raw.get("respray", {}).get("n", -1)) == ntri else PackedByteArray()
	if pt_res.size() != ntri:
		pt_res = PackedByteArray(); pt_res.resize(ntri)
	_paint_geom()

## The bonnet's hinge from the faces painted bonnet: across the car at its back edge (front edge if it hinges at
## the front), at the top of that edge; swung LIFT_DEG open
func _lift_xf() -> Transform3D:
	var front := str(bon.get("hinge", "rear")) == "front"
	var zz := -INF if front else INF
	var any := false
	for i in pt_lab.size():
		if pt_lab[i] != 3: continue
		any = true
		for k in 3:
			var z := pt_base[i * 3 + k].z
			zz = maxf(zz, z) if front else minf(zz, z)
	if not any: return Transform3D.IDENTITY
	var yy := -INF
	for i in pt_lab.size():
		if pt_lab[i] != 3: continue
		for k in 3:
			var v := pt_base[i * 3 + k]
			if absf(v.z - zz) < 0.2: yy = maxf(yy, v.y)
	var piv := Vector3(0, yy, zz)
	var ang := deg_to_rad(LIFT_DEG) * (1.0 if front else -1.0)
	return Transform3D(Basis.IDENTITY, piv) * Transform3D(Basis(Vector3.RIGHT, ang), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -piv)

## What's shown and picked: the base triangles, the bonnet ones swung open when lifted; grid and picking mesh to match
func _paint_geom() -> void:
	var L := _lift_xf() if pt_lift else Transform3D.IDENTITY
	pt_tris = pt_base.duplicate()
	if pt_lift:
		for i in pt_lab.size():
			if pt_lab[i] == 3:
				for k in 3: pt_tris[i * 3 + k] = L * pt_base[i * 3 + k]
	if pt_hide > 0:
		# hidden: squashed to a point far below, where neither the brush nor a click can find them
		for i in pt_lab.size():
			if pt_lab[i] == pt_hide:
				for k in 3: pt_tris[i * 3 + k] = Vector3(0, -1000, 0)
	pt_ctr = PackedVector3Array(); pt_nrm = PackedVector3Array(); pt_grid = {}
	var ntri := pt_tris.size() / 3
	pt_ctr.resize(ntri); pt_nrm.resize(ntri)
	for ti in ntri:
		var a := pt_tris[ti * 3]; var b := pt_tris[ti * 3 + 1]; var c := pt_tris[ti * 3 + 2]
		pt_ctr[ti] = (a + b + c) / 3.0
		var n := (b - a).cross(c - a)
		pt_nrm[ti] = n.normalized() if n.length_squared() > 1e-14 else Vector3.UP
		var lo := Vector3i((a.min(b).min(c) / PT_CELL).floor())
		var hi := Vector3i((a.max(b).max(c) / PT_CELL).floor())
		if (hi.x - lo.x + 1) * (hi.y - lo.y + 1) * (hi.z - lo.z + 1) > 400: hi = lo     # a stray giant face: one cell (the hit face still paints)
		for gx in range(lo.x, hi.x + 1):
			for gy in range(lo.y, hi.y + 1):
				for gz in range(lo.z, hi.z + 1):
					var k := Vector3i(gx, gy, gz)
					if not pt_grid.has(k): pt_grid[k] = []
					(pt_grid[k] as Array).append(ti)
	_pt_adj = []
	pt_tm = TriangleMesh.new()
	pt_tm.create_from_faces(pt_tris)
	_lift_dirty = false

## Lift / drop the bonnet, or after a stroke that changed what's bonnet while it's up
func _lift_refresh() -> void:
	_paint_geom()
	_rebuild_model()

## Start the paint from what the lines cut now (tub plane / seam, bonnet shut line)
func _paint_from_lines() -> void:
	if pt_lift:                                  # the lines are drawn on the closed body
		pt_lift = false
		_paint_geom()
		_build_ui()
	var poly := BodyCut.bonnet_poly(bon)
	var fy := BodyCut.bonnet_floor(bon)
	for i in pt_ctr.size():
		if pt_lab[i] != 0: continue
		var c := pt_ctr[i]
		if poly.size() >= 3 and c.y > fy - 0.1 and Geometry2D.is_point_in_polygon(Vector2(c.x, c.z), poly) and pt_nrm[i].y > -0.7: pt_lab[i] = 3
		elif use_tub and not tub.is_empty() and BodyCut.behind_tub(tub, c): pt_lab[i] = 2
	_rebuild_model()

## 0.2.62: the painted faces are a see-through coat over the textured model (the plain grey hid the shut lines):
## each chunk holds only its painted triangles, lifted 4 mm off the panel
func _paint_mesh(ci: int) -> ArrayMesh:
	var a := ci * PT_CH
	var b := mini(a + PT_CH, pt_ctr.size())
	if b <= a: return null
	var V := PackedVector3Array(); var N := PackedVector3Array(); var C := PackedColorArray()
	for t in b - a:
		var col: Color
		if pt_layer == "respray":
			if pt_res[a + t] == 0: continue
			col = pt_prev_col
			col.a = 0.85
		else:
			var lv: int = pt_lab[a + t]
			if lv == 0 or lv == pt_hide: continue
			col = _lab_col(lv)
			col.a = 0.55
		var n := pt_nrm[a + t]
		# lifted both ways: a model's winding can point its normals inward, and the copy inside the panel just hides
		for sgn in [1.0, -1.0]:
			for k in 3:
				V.append(pt_tris[(a + t) * 3 + k] + n * (0.004 * sgn)); N.append(n * sgn); C.append(col)
	if V.is_empty(): return null
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V; arr[Mesh.ARRAY_NORMAL] = N; arr[Mesh.ARRAY_COLOR] = C
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

var _pt_mat: StandardMaterial3D
func _paint_build() -> void:
	_paint_load()
	# the model itself, textures and all (the bonnet's faces in their own pieces, swung up, when it's lifted)
	if not pt_lift and pt_hide <= 0:
		for m in BodyCut.meshes_of(glb):
			var mi := MeshInstance3D.new()
			mi.mesh = m.mesh
			mi.transform = m.xf
			model.add_child(mi)
	else:
		_paint_textured_lifted()
	if _pt_mat == null:
		_pt_mat = StandardMaterial3D.new()
		_pt_mat.vertex_color_use_as_albedo = true
		_pt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_pt_mat.render_priority = 1
	_lt_node = null
	if not pt_lights.is_empty():
		var info := Lamps.build(pt_lights)
		_lt_node = info.node
		model.add_child(_lt_node)
		Lamps.set_lit(info, true, false)
	pt_chunks.clear()
	if pt_layer == "lights": return
	for ci in ceili(float(pt_ctr.size()) / PT_CH):
		var mi := MeshInstance3D.new()
		mi.mesh = _paint_mesh(ci)
		mi.material_override = _pt_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(mi)
		pt_chunks.append(mi)
	_paint_status()

func _paint_textured_lifted() -> void:
	var L := _lift_xf() if pt_lift else Transform3D.IDENTITY
	var lid := Node3D.new(); lid.transform = L; model.add_child(lid)
	var ti := 0
	for m in BodyCut.meshes_of(glb):
		var mesh: Mesh = m.mesh
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if I.is_empty():
				I.resize(V.size())
				for i in V.size(): I[i] = i
			var keep := PackedInt32Array(); var up := PackedInt32Array()
			for t in range(0, I.size(), 3):
				var lv := pt_lab[ti] if ti < pt_lab.size() else 0
				ti += 1
				if pt_hide > 0 and lv == pt_hide: continue
				if lv == 3 and pt_lift: up.append_array([I[t], I[t + 1], I[t + 2]])
				else: keep.append_array([I[t], I[t + 1], I[t + 2]])
			for pair in [[keep, model], [up, lid]]:
				if (pair[0] as PackedInt32Array).is_empty(): continue
				var a2 := arr.duplicate()
				a2[Mesh.ARRAY_INDEX] = pair[0]
				a2[Mesh.ARRAY_TANGENT] = null
				var am := ArrayMesh.new()
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
				am.surface_set_material(0, mesh.surface_get_material(si))
				var mi := MeshInstance3D.new(); mi.mesh = am; mi.transform = m.xf
				(pair[1] as Node3D).add_child(mi)

# ------------------------------------------------------------------------------------------------ lamps (0.2.68)
func _light_click(sp: Vector2) -> void:
	if pt_tm == null: return
	var from := cam.project_ray_origin(sp) - spot
	var dir := cam.project_ray_normal(sp)
	var r := pt_tm.intersect_ray(from, dir)
	if r.is_empty(): return
	var hit: Vector3 = r.position
	var n: Vector3 = r.normal
	if n.dot(-dir) < 0.0: n = -n                  # face it at you (models wind both ways)
	var e := {"t": lt_type, "p": [snappedf(hit.x, 0.001), snappedf(hit.y, 0.001), snappedf(hit.z, 0.001)],
		"n": [snappedf(n.x, 0.001), snappedf(n.y, 0.001), snappedf(n.z, 0.001)], "s": snappedf(lt_size, 0.005),
		"a": snappedf(lt_aspect, 0.01), "d": snappedf(lt_depth, 0.002)}
	pt_lights.append(e)
	if lt_mirror and absf(hit.x) > 0.05:
		var m := e.duplicate(true)
		m.p[0] = -float(e.p[0]); m.n[0] = -float(e.n[0])
		pt_lights.append(m)
	_rebuild_model()
	_paint_status()

func _lights_ui() -> void:
	var tb := HFlowContainer.new(); tb.custom_minimum_size = Vector2(400, 0); panel.add_child(tb)
	for ty in Lamps.TYPES:
		var b := Button.new(); b.text = ty[1]; b.toggle_mode = true; b.button_pressed = lt_type == ty[0]
		b.pressed.connect(func():
			lt_type = ty[0]; _build_ui())
		tb.add_child(b)
	_slider("Size (m across)", 0.04, 0.35, 0.005, lt_size, func(v): lt_size = v)
	if lt_type == "rect": _slider("Height / width", 0.25, 1.0, 0.01, lt_aspect, func(v): lt_aspect = v)
	_slider("Sunk into the panel (m)", -0.02, 0.12, 0.002, lt_depth, func(v): lt_depth = v)
	var mc := CheckBox.new(); mc.text = "Mirror to the other side"; mc.button_pressed = lt_mirror
	mc.toggled.connect(func(v): lt_mirror = v)
	panel.add_child(mc)
	_button("Undo the last lamp", func():
		if not pt_lights.is_empty():
			pt_lights.pop_back()
			if lt_mirror and not pt_lights.is_empty(): pt_lights.pop_back()
		_rebuild_model())
	_button("Clear all lamps", func():
		pt_lights.clear(); _rebuild_model())
	var l := Label.new()
	l.text = "Click on the body to put a lamp there, facing out of the panel. Round / rectangle headlights are generic units to stick on a body that has none; Bulb sits in the model's own housing (sink it in a few cm) and lights it up; Tail bulbs glow red with the lights and flare on the brakes. The car's headlight beams come from the outermost headlights at the front. %d lamps on this body." % pt_lights.size()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size = Vector2(400, 0); panel.add_child(l)

func _lab_name(lv: int) -> String:
	match lv:
		1: return "cab"
		2: return "tub"
		3: return "bonnet"
	if lv >= 4 and lv - 4 < pt_parts.size(): return str(pt_parts[lv - 4].name)
	return "part"

## The tint a label shows in: cab blue, tub orange, bonnet green, your own parts round the colour wheel
func _lab_col(lv: int) -> Color:
	if lv < PT_COL.size(): return PT_COL[lv]
	return Color.from_hsv(fmod(0.83 + 0.37 * float(lv - 4), 1.0), 0.75, 1.0)

func _paint_status() -> void:
	if status == null: return
	var n := {}
	for v in pt_lab: n[v] = int(n.get(v, 0)) + 1
	var nr := 0
	for v in pt_res: nr += v
	var own := ""
	for i in pt_parts.size(): own += " · %s %d" % [str(pt_parts[i].name), int(n.get(4 + i, 0))]
	status.text = "%s · %d triangles · tub %d · bonnet %d · cab (painted) %d%s · respray %d" % [glb, pt_ctr.size(), int(n.get(2, 0)), int(n.get(3, 0)), int(n.get(1, 0)), own, nr]

## Closest point on triangle abc to p (Ericson, Real-Time Collision Detection 5.1.5)
static func _tri_closest(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a; var ac := c - a; var ap := p - a
	var d1 := ab.dot(ap); var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0: return a
	var bp := p - b; var d3 := ab.dot(bp); var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3: return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0: return a + ab * (d1 / (d1 - d3))
	var cp := p - c; var d5 := ab.dot(cp); var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6: return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0: return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0: return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var den := 1.0 / (va + vb + vc)
	return a + ab * (vb * den) + ac * (vc * den)

var pt_fill := false                       # 0.2.61: a click fills the whole smooth panel instead of brushing
var pt_fill_deg := 20.0
var _pt_adj: Array = []                    # per triangle: Array of edge neighbours (built on first fill)

func _paint_set(i: int, dirty: Dictionary) -> void:
	if pt_layer == "respray":
		if pt_res[i] != pt_res_val:
			pt_res[i] = pt_res_val
			dirty[i / PT_CH] = true
		return
	if pt_lab[i] != pt_part:
		if pt_lift and (pt_lab[i] == 3 or pt_part == 3): _lift_dirty = true
		if pt_hide > 0 and pt_part == pt_hide: _lift_dirty = true          # it vanishes with the rest when you let go
		pt_lab[i] = pt_part
		dirty[i / PT_CH] = true

func _paint_at(sp: Vector2, click := false) -> void:
	if pt_tm == null: return
	var from := cam.project_ray_origin(sp) - spot
	var dir := cam.project_ray_normal(sp)
	var r := pt_tm.intersect_ray(from, dir)
	if r.is_empty(): return
	var hit: Vector3 = r.position
	var dirty := {}
	var fi := int(r.get("face_index", -1))
	if pt_fill:
		if click and fi >= 0 and fi < pt_lab.size(): _paint_fill(fi, dirty)
	else:
		if fi >= 0 and fi < pt_lab.size(): _paint_set(fi, dirty)     # the face under the cursor always takes it, however big
		var lo := Vector3i(((hit - Vector3.ONE * pt_rad) / PT_CELL).floor())
		var hi := Vector3i(((hit + Vector3.ONE * pt_rad) / PT_CELL).floor())
		var seen := {}
		var r2 := pt_rad * pt_rad
		for gx in range(lo.x, hi.x + 1):
			for gy in range(lo.y, hi.y + 1):
				for gz in range(lo.z, hi.z + 1):
					var ids = pt_grid.get(Vector3i(gx, gy, gz))
					if ids == null: continue
					for i in (ids as Array):
						if seen.has(i) or (pt_lab[i] == pt_part if pt_layer == "parts" else pt_res[i] == pt_res_val): continue
						seen[i] = true
						if not pt_through and pt_nrm[i].dot(-dir) < 0.05: continue
						var q := _tri_closest(hit, pt_tris[i * 3], pt_tris[i * 3 + 1], pt_tris[i * 3 + 2])
						if q.distance_squared_to(hit) <= r2: _paint_set(i, dirty)
	for ci in dirty:
		if ci < pt_chunks.size(): (pt_chunks[ci] as MeshInstance3D).mesh = _paint_mesh(ci)
	if not dirty.is_empty(): _paint_status()

## Neighbours across shared edges, welding vertices to the millimetre (models come split at UV seams)
func _paint_adj() -> void:
	var nt := pt_ctr.size()
	_pt_adj = []; _pt_adj.resize(nt)
	var edges := {}
	for t in nt: _pt_adj[t] = []
	for t in nt:
		if pt_hide > 0 and pt_lab[t] == pt_hide: continue          # hidden faces are all squashed to one point
		var k: Array[Vector3i] = []
		for j in 3: k.append(Vector3i((pt_tris[t * 3 + j] * 1000.0).round()))
		for j in 3:
			var e0: Vector3i = k[j]; var e1: Vector3i = k[(j + 1) % 3]
			if e1 < e0:
				var tmp := e0
				e0 = e1
				e1 = tmp
			var key := Vector2i(hash(e0), hash(e1))
			if edges.has(key):
				var lst: Array = edges[key]
				for o in lst:
					(_pt_adj[t] as Array).append(o)
					(_pt_adj[o] as Array).append(t)
				lst.append(t)
			else:
				edges[key] = [t]

## Flood from the clicked face across edges that bend less than pt_fill_deg, never further than twice that from the
## face you clicked, and never into faces painted as another part: one click takes a panel up to its shut line (the
## groove bends sharply) or up to a line you've brushed round it first (a smooth one-piece body has no groove)
func _paint_fill(f0: int, dirty: Dictionary) -> void:
	if _pt_adj.size() != pt_ctr.size(): _paint_adj()
	var cosl := cos(deg_to_rad(pt_fill_deg))
	var cos_seed := cos(deg_to_rad(minf(pt_fill_deg * 2.0, 89.0)))
	var n0 := pt_nrm[f0]
	var seed_lab := pt_lab[f0]
	var seen := {f0: true}
	var q: Array[int] = [f0]
	while not q.is_empty():
		var t: int = q.pop_back()
		_paint_set(t, dirty)
		for o in (_pt_adj[t] as Array):
			if seen.has(o): continue
			seen[o] = true
			if pt_layer == "parts" and pt_lab[o] != 0 and pt_lab[o] != pt_part: continue          # a brushed boundary
			if pt_layer == "respray" and pt_lab[o] != seed_lab: continue        # the respray stops where the part changes
			if absf(pt_nrm[o].dot(pt_nrm[t])) < cosl: continue           # a crease (either winding)
			if absf(pt_nrm[o].dot(n0)) < cos_seed: continue              # curled too far round from where you clicked
			q.append(o)

func _paint_ui() -> void:
	# 0.2.68: two layers: what each face IS (cab, tub, bonnet, parts of your own) and which faces take a respray
	var ly := HBoxContainer.new(); panel.add_child(ly)
	for lm in [["parts", "Parts"], ["respray", "Respray (paint colour)"], ["lights", "Lights"]]:
		var b := Button.new(); b.text = lm[1]; b.toggle_mode = true; b.button_pressed = pt_layer == lm[0]
		b.pressed.connect(func():
			pt_layer = lm[0]
			_build_ui()
			_rebuild_model())
		ly.add_child(b)
	if pt_layer == "lights":
		_lights_ui()
		return
	if pt_layer == "respray":
		var rb2 := HBoxContainer.new(); panel.add_child(rb2)
		for rv in [[1, "Paint it"], [0, "Leave it (glass, trim, rubber)"]]:
			var b := Button.new(); b.text = rv[1]; b.toggle_mode = true; b.button_pressed = pt_res_val == rv[0]
			b.pressed.connect(func():
				pt_res_val = rv[0]; _build_ui())
			rb2.add_child(b)
		var cp := ColorPickerButton.new(); cp.color = pt_prev_col; cp.custom_minimum_size = Vector2(400, 28)
		cp.text = "Preview colour"
		cp.color_changed.connect(func(c2):
			pt_prev_col = c2
			for ci in pt_chunks.size(): (pt_chunks[ci] as MeshInstance3D).mesh = _paint_mesh(ci))
		panel.add_child(cp)
		_button("Clear the respray", func():
			for i in pt_res.size(): pt_res[i] = 0
			_rebuild_model())
	else:
		var hb := HBoxContainer.new(); panel.add_child(hb)
		for pp in [[2, "Tub"], [3, "Bonnet"], [1, "Cab"], [0, "Erase"]]:
			var b := Button.new(); b.text = pp[1]; b.toggle_mode = true; b.button_pressed = pt_part == pp[0]
			b.pressed.connect(func():
				pt_part = pp[0]; _build_ui())
			hb.add_child(b)
		# parts of your own: name one, paint it, it's an item (Forge palette "My parts", found in sheds)
		var own := HFlowContainer.new(); own.custom_minimum_size = Vector2(400, 0); panel.add_child(own)
		for i in pt_parts.size():
			var b := Button.new(); b.text = str(pt_parts[i].name); b.toggle_mode = true; b.button_pressed = pt_part == 4 + i
			b.modulate = _lab_col(4 + i).lightened(0.3)
			b.pressed.connect(func():
				pt_part = 4 + i; _build_ui())
			own.add_child(b)
		var nb := HBoxContainer.new(); panel.add_child(nb)
		var le := LineEdit.new(); le.placeholder_text = "New part: side steps, bull bar, spotlights..."; le.custom_minimum_size = Vector2(300, 0)
		le.text = _new_part_name
		le.text_changed.connect(func(t2): _new_part_name = t2)
		nb.add_child(le)
		var ab := Button.new(); ab.text = "Add part"
		ab.pressed.connect(func():
			var nm := _new_part_name.strip_edges()
			if nm == "" or pt_parts.size() >= 200: return
			pt_parts.append({"name": nm, "off": false})
			pt_part = 4 + pt_parts.size() - 1
			_new_part_name = ""
			_build_ui())
		nb.add_child(ab)
		if pt_part >= 4 and pt_part - 4 < pt_parts.size():
			var cur: Dictionary = pt_parts[pt_part - 4]
			var off := CheckBox.new(); off.text = "Take \"%s\" off this car (it's still an item)" % str(cur.name); off.button_pressed = bool(cur.get("off", false))
			off.toggled.connect(func(v): cur["off"] = v)
			panel.add_child(off)
			var rn := HBoxContainer.new(); panel.add_child(rn)
			var le2 := LineEdit.new(); le2.text = str(cur.name); le2.custom_minimum_size = Vector2(250, 0)
			rn.add_child(le2)
			var rb3 := Button.new(); rb3.text = "Rename"
			rb3.pressed.connect(func():
				if le2.text.strip_edges() != "": cur["name"] = le2.text.strip_edges()
				_build_ui())
			rn.add_child(rb3)
			_button("Clear \"%s\" paint" % str(cur.name), func():
				for i in pt_lab.size(): if pt_lab[i] == pt_part: pt_lab[i] = 0
				_rebuild_model())
	var lb := Button.new(); lb.toggle_mode = true; lb.button_pressed = pt_lift
	lb.text = "DROP BONNET" if pt_lift else "LIFT BONNET (paint what's under it)"
	lb.pressed.connect(func():
		pt_lift = not pt_lift
		_lift_refresh()
		_build_ui())
	panel.add_child(lb)
	# 0.2.71: hide the part you're painting (or any other) to get at the junk under it, like the bonnet lift
	if pt_layer == "parts" or pt_layer == "respray":
		var hid_name := _lab_name(pt_hide) if pt_hide > 0 else ""
		var hb2 := Button.new(); hb2.toggle_mode = true; hb2.button_pressed = pt_hide > 0
		if pt_hide > 0: hb2.text = "SHOW %s again" % hid_name.to_upper()
		elif pt_part > 0: hb2.text = "HIDE %s (paint what's under it)" % _lab_name(pt_part).to_upper()
		else: hb2.text = "HIDE a part: pick one above first"
		hb2.disabled = pt_hide <= 0 and pt_part <= 0
		hb2.pressed.connect(func():
			pt_hide = -1 if pt_hide > 0 else pt_part
			_lift_refresh()
			_build_ui())
		panel.add_child(hb2)
	var hf := HBoxContainer.new(); panel.add_child(hf)
	for fm in [[false, "Brush (drag)"], [true, "Fill panel (click)"]]:
		var b := Button.new(); b.text = fm[1]; b.toggle_mode = true; b.button_pressed = pt_fill == fm[0]
		b.pressed.connect(func():
			pt_fill = fm[0]; _build_ui())
		hf.add_child(b)
	if pt_fill:
		_slider("Fill stops at bends over (deg)", 5.0, 80.0, 1.0, pt_fill_deg, func(v): pt_fill_deg = v)
	else:
		_slider("Brush size (m)", 0.02, 0.6, 0.01, pt_rad, func(v): pt_rad = v)
	var th := CheckBox.new(); th.text = "Paint through (both skins of a panel)"; th.button_pressed = pt_through
	th.toggled.connect(func(v): pt_through = v)
	panel.add_child(th)
	var hg := HBoxContainer.new(); panel.add_child(hg)
	for h in [["rear", "Bonnet hinge at the back"], ["front", "at the front"]]:
		var b := Button.new(); b.text = h[1]; b.toggle_mode = true; b.button_pressed = str(bon.get("hinge", "rear")) == h[0]
		b.pressed.connect(func():
			bon.hinge = h[0]
			if pt_lift: _lift_refresh()
			_build_ui())
		hg.add_child(b)
	_button("Start from the lines (tub cut, bonnet shut line)", _paint_from_lines)
	_button("Clear the tub paint", func():
		for i in pt_lab.size(): if pt_lab[i] == 2: pt_lab[i] = 0
		_rebuild_model())
	_button("Clear the bonnet paint", func():
		for i in pt_lab.size(): if pt_lab[i] == 3: pt_lab[i] = 0
		if pt_lift: _lift_refresh()
		else: _rebuild_model())
	var l := Label.new()
	if pt_layer == "respray":
		l.text = "Paint the faces that take the car's colour (body panels; leave glass, chrome, rubber, lights and the interior). Fill stops where one part meets another. Pick the colour per car in the garage (Paint colour)."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size = Vector2(400, 0); panel.add_child(l)
		return
	l.text = "Your own parts (side steps, bumpers, racks, spotlights): type a name, Add part, paint its faces. Saved, it's in the Forge's palette under My parts, and turns up in sheds and yards. Tick Take it off to leave it off this car. Left-drag to paint the model's own faces (Fill: click a panel to take all of it up to its shut line; on a smooth one-piece body brush a line round it first in Cab and the fill stops there). Right-drag turns the view, wheel zooms. Orange = tub, green = bonnet, blue = kept as cab, no tint = left to the lines. Erase takes the paint off. LIFT BONNET swings the green faces up on the hinge so you can paint the junk under the skin: paint it Bonnet to lift with it, Cab to stay, and it moves when you let go."
	l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size = Vector2(400, 0); panel.add_child(l)
