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
	if painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): painting = false
	if _drag and not (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)): _drag = false
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

## The mouse comes here after the GUI has had it (0.2.62: 0.2.61 read it ahead of the GUI, which swallowed the
## release of every click on the side panel, so no button worked, and every click on the F9 form)
func _unhandled_input(e: InputEvent) -> void:
	if not open: return
	if e.is_action_pressed("menu") or e.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT or e.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = e.pressed
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed: dist = maxf(dist * 0.9, 2.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed: dist = minf(dist * 1.1, 20.0)
		elif e.button_index == MOUSE_BUTTON_LEFT and mode == "paint":
			painting = e.pressed
			if e.pressed: _paint_at(e.position, true)
		elif e.button_index == MOUSE_BUTTON_LEFT and e.pressed: _click(e.position)
		else: return
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion:
		if painting:
			_paint_at(e.position)
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

func _paint_load() -> void:
	if pt_glb == glb and not pt_tris.is_empty(): return
	pt_glb = glb
	pt_tris = PackedVector3Array(); pt_ctr = PackedVector3Array(); pt_nrm = PackedVector3Array(); pt_grid = {}
	for m in BodyCut.meshes_of(glb):
		var mesh: Mesh = m.mesh
		var xf: Transform3D = m.xf
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var nt := (I.size() if not I.is_empty() else V.size()) / 3
			for t in nt:
				var a: Vector3 = xf * V[I[t * 3] if not I.is_empty() else t * 3]
				var b: Vector3 = xf * V[I[t * 3 + 1] if not I.is_empty() else t * 3 + 1]
				var c: Vector3 = xf * V[I[t * 3 + 2] if not I.is_empty() else t * 3 + 2]
				pt_tris.append(a); pt_tris.append(b); pt_tris.append(c)
				var ctr := (a + b + c) / 3.0
				pt_ctr.append(ctr)
				var n := (b - a).cross(c - a)
				pt_nrm.append(n.normalized() if n.length_squared() > 1e-14 else Vector3.UP)
				var ti := pt_ctr.size() - 1
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
	var raw: Dictionary = BodyCut.all().get(glb, {})
	pt_lab = BodyCut.labels_of(raw.get("paint", {})) if int(raw.get("paint", {}).get("n", -1)) == pt_ctr.size() else PackedByteArray()
	if pt_lab.size() != pt_ctr.size():
		pt_lab = PackedByteArray(); pt_lab.resize(pt_ctr.size())

## Start the paint from what the lines cut now (tub plane / seam, bonnet shut line)
func _paint_from_lines() -> void:
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
		var lv: int = pt_lab[a + t]
		if lv == 0: continue
		var col: Color = PT_COL[lv]
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
	# the model itself, textures and all
	for m in BodyCut.meshes_of(glb):
		var mi := MeshInstance3D.new()
		mi.mesh = m.mesh
		mi.transform = m.xf
		model.add_child(mi)
	if _pt_mat == null:
		_pt_mat = StandardMaterial3D.new()
		_pt_mat.vertex_color_use_as_albedo = true
		_pt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_pt_mat.render_priority = 1
	pt_chunks.clear()
	for ci in ceili(float(pt_ctr.size()) / PT_CH):
		var mi := MeshInstance3D.new()
		mi.mesh = _paint_mesh(ci)
		mi.material_override = _pt_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(mi)
		pt_chunks.append(mi)
	_paint_status()

func _paint_status() -> void:
	if status == null: return
	var n := [0, 0, 0, 0]
	for v in pt_lab: n[v] += 1
	status.text = "%s · %d triangles · tub %d · bonnet %d · cab (painted) %d" % [glb, pt_ctr.size(), n[2], n[3], n[1]]

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
	if pt_lab[i] != pt_part:
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
						if seen.has(i) or pt_lab[i] == pt_part: continue
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
	var seen := {f0: true}
	var q: Array[int] = [f0]
	while not q.is_empty():
		var t: int = q.pop_back()
		_paint_set(t, dirty)
		for o in (_pt_adj[t] as Array):
			if seen.has(o): continue
			seen[o] = true
			if pt_lab[o] != 0 and pt_lab[o] != pt_part: continue          # a brushed boundary
			if absf(pt_nrm[o].dot(pt_nrm[t])) < cosl: continue           # a crease (either winding)
			if absf(pt_nrm[o].dot(n0)) < cos_seed: continue              # curled too far round from where you clicked
			q.append(o)

func _paint_ui() -> void:
	var hb := HBoxContainer.new(); panel.add_child(hb)
	for pp in [[2, "Tub"], [3, "Bonnet"], [1, "Cab"], [0, "Erase"]]:
		var b := Button.new(); b.text = pp[1]; b.toggle_mode = true; b.button_pressed = pt_part == pp[0]
		b.pressed.connect(func():
			pt_part = pp[0]; _build_ui())
		hb.add_child(b)
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
			bon.hinge = h[0]; _build_ui())
		hg.add_child(b)
	_button("Start from the lines (tub cut, bonnet shut line)", _paint_from_lines)
	_button("Clear the tub paint", func():
		for i in pt_lab.size(): if pt_lab[i] == 2: pt_lab[i] = 0
		_rebuild_model())
	_button("Clear the bonnet paint", func():
		for i in pt_lab.size(): if pt_lab[i] == 3: pt_lab[i] = 0
		_rebuild_model())
	var l := Label.new()
	l.text = "Left-drag to paint the model's own faces (Fill: click a panel to take all of it up to its shut line; on a smooth one-piece body brush a line round it first in Cab and the fill stops there). Right-drag turns the view, wheel zooms. Orange = tub, green = bonnet, blue = kept as cab, no tint = left to the lines. Erase takes the paint off."
	l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size = Vector2(400, 0); panel.add_child(l)
