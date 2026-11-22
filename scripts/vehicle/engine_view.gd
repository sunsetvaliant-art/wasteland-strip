class_name EngineView
extends CanvasLayer
## The engine view (0.2.57, the user's idea). The engine floats in the middle of the screen, turning slowly, built
## part by part from the same code as the engine in the car, so each part can be picked:
##   hover a part      it lights up, its name by the cursor
##   click             select it: its name, what it does, and a button to take it off
##   double-click      the parts in your pack open on the right (the ones that fit the part you clicked go first)
##   empty spots       drawn as see-through ghosts of the part that goes there
##   drag and drop     a part from the list onto the engine fits it (onto a taken spot swaps the two); a selected
##                     part dragged onto the list comes off
##   drag / RMB drag   turn it   ·   wheel  zoom   ·   K or Esc  close
## Opened from under the bonnet (K beside a car) and from the engine stand. Also bakes the engine parts' inventory
## pictures (EngineView.icon), since they're built in code and have no model to render ahead of time.

static var inst: EngineView

var main
var open := false
var kit: Dictionary = {}
var ctx: Dictionary = {}         # title, changed: Callable, on_close: Callable, block_ok: bool
var root: Control
var vpc: SubViewportContainer
var pad: Control                 # over the view: takes the mouse and the drops (a SubViewportContainer hands drags to
                                 # the viewport inside it, so drops on it never reached the engine: 0.2.59)
var vp: SubViewport
var cam: Camera3D
var pivot: Node3D
var eng: Node3D
var parts := {}                  # slot -> {"mi": MeshInstance3D, "tri": TriangleMesh, "ghost": bool}
var hover := ""
var sel := ""
var drop_slot := ""
var drop_ok := false
var drop_live := false           # something's being dragged over the engine right now
var spin := 0.6
var tilt := 0.42
var dist := 1.8
var _idle := 0.0                 # seconds since the user last turned it: it turns on its own after a while
var _press := Vector2.INF
var _press_slot := ""
var _turning := false
var _msg := ""
var title_l: RichTextLabel
var info: RichTextLabel
var off_btn: Button
var parts_btn: Button
var tag: Label                   # the hovered part's name, by the cursor
var side: PanelContainer
var grid: GridContainer
var side_note: Label
var focus_slot := ""             # the slot the list was opened for (its parts go first)
var tiles := {}                  # id -> tile Control
var m_ghost: StandardMaterial3D
var m_hover: StandardMaterial3D
var m_sel: StandardMaterial3D
var m_ok: StandardMaterial3D
var m_bad: StandardMaterial3D
const SIDE_W := 400.0

func setup(m) -> void:
	main = m
	inst = self
	layer = 23
	process_mode = Node.PROCESS_MODE_ALWAYS
	m_ghost = _mat(Color(0.45, 0.75, 1.0, 0.16))
	m_hover = _mat(Color(1.0, 0.85, 0.35, 0.30))
	m_sel = _mat(Color(1.0, 0.55, 0.1, 0.42))
	m_ok = _mat(Color(0.3, 1.0, 0.45, 0.45))
	m_bad = _mat(Color(1.0, 0.25, 0.2, 0.40))
	_build_ui()

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m

# ------------------------------------------------------------------------------------------------ opening
## Open on a build (the Dictionary is changed in place). ctx: title, changed (called after every fit or take-off),
## on_close, block_ok (can the block itself go in or come out here)
func open_for(k: Dictionary, c: Dictionary) -> void:
	var p = main.player
	if p == null or p.dead: return
	main.interact_menu.clear()
	kit = k
	ctx = c
	open = true
	sel = ""; hover = ""; drop_slot = ""; drop_live = false; _msg = ""
	tag.visible = false
	spin = 0.6; tilt = 0.42; _idle = 3.0
	root.visible = true
	side.visible = false
	_layout()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_rebuild()

func close() -> void:
	if not open: return
	open = false
	root.visible = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for ch in eng.get_children(): ch.free()
	parts.clear()
	var cb = ctx.get("on_close")
	ctx = {}
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call()
	elif not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(e: InputEvent) -> void:
	if not open: return
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("work_on_car"):
		close()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------------------------------------ the window
func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	if main.get("pause_menu") and main.pause_menu.root: root.theme = main.pause_menu.root.theme
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.04, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	# the 3D: its own little world, see-through so the dark backing shows
	vpc = SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vpc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vpc.add_child(vp)
	_stage(vp)
	cam = Camera3D.new()
	cam.fov = 35.0
	cam.near = 0.05
	cam.far = 30.0
	vp.add_child(cam)
	cam.current = true
	pivot = Node3D.new()
	vp.add_child(pivot)
	eng = Node3D.new()
	pivot.add_child(eng)
	pad = Control.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(pad)
	pad.gui_input.connect(_view_input)
	pad.mouse_exited.connect(func():
		hover = ""
		tag.visible = false
		_overlays())
	pad.set_drag_forwarding(_drag_from_engine, _can_drop_engine, _drop_engine)
	# top left: what it is and whether it'll run
	title_l = RichTextLabel.new()
	title_l.bbcode_enabled = true
	title_l.fit_content = true
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_l.position = Vector2(24, 18)
	title_l.size = Vector2(760, 80)
	root.add_child(title_l)
	# bottom left: the selected part
	var ip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.1, 0.97)
	sb.set_content_margin_all(12)
	sb.set_corner_radius_all(6)
	ip.add_theme_stylebox_override("panel", sb)
	ip.anchor_top = 1.0; ip.anchor_bottom = 1.0
	ip.offset_left = 20; ip.offset_right = 540; ip.offset_top = -300; ip.offset_bottom = -20
	root.add_child(ip)
	var vb := VBoxContainer.new()
	ip.add_child(vb)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.custom_minimum_size = Vector2(490, 200)
	vb.add_child(info)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)
	off_btn = Button.new()
	off_btn.text = "Take it off"
	off_btn.pressed.connect(func():
		if sel != "": _off(sel))
	hb.add_child(off_btn)
	parts_btn = Button.new()
	parts_btn.text = "Your parts  >"
	parts_btn.pressed.connect(func(): _show_side(not side.visible, sel))
	hb.add_child(parts_btn)
	var cl := Button.new()
	cl.text = "Close (K)"
	cl.pressed.connect(close)
	hb.add_child(cl)
	# bottom middle: how it works
	var help := Label.new()
	help.text = "Drag to turn  ·  wheel to zoom  ·  click a part  ·  double-click for your parts  ·  drag parts on, and a selected part off onto the list"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.position = Vector2(24, 92)
	root.add_child(help)
	# the name by the cursor
	tag = Label.new()
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	tag.add_theme_constant_override("outline_size", 5)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.visible = false
	root.add_child(tag)
	# right: your parts
	side = PanelContainer.new()
	var sb2 := sb.duplicate() as StyleBoxFlat
	sb2.bg_color = Color(0.07, 0.08, 0.09, 0.95)
	side.add_theme_stylebox_override("panel", sb2)
	side.anchor_left = 1.0; side.anchor_right = 1.0; side.anchor_bottom = 1.0
	side.offset_left = -SIDE_W; side.offset_top = 0; side.offset_right = 0; side.offset_bottom = 0
	side.visible = false
	root.add_child(side)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	side.add_child(sv)
	var sh := HBoxContainer.new()
	sv.add_child(sh)
	var st := Label.new()
	st.text = "YOUR ENGINE PARTS"
	st.add_theme_font_size_override("font_size", 18)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(st)
	var x := Button.new()
	x.text = "x"
	x.pressed.connect(func(): _show_side(false, ""))
	sh.add_child(x)
	side_note = Label.new()
	side_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	side_note.add_theme_font_size_override("font_size", 12)
	side_note.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	side_note.custom_minimum_size = Vector2(SIDE_W - 30, 0)
	sv.add_child(side_note)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(grid)
	side.set_drag_forwarding(Callable(), _can_drop_side, _drop_side)
	sc.set_drag_forwarding(Callable(), _can_drop_side, _drop_side)

## Lights and a soft ambient for a little world of its own (the engine view and the icon renders)
static func _stage(v: SubViewport) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	v.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, 35, 0)
	key.light_energy = 1.25
	v.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 210, 0)
	rim.light_energy = 0.55
	rim.light_color = Color(0.75, 0.85, 1.0)
	v.add_child(rim)

func _layout() -> void:
	vpc.offset_right = -SIDE_W if side.visible else 0.0
	pad.offset_right = vpc.offset_right
	parts_btn.text = "Hide parts" if side.visible else "Your parts  >"

# ------------------------------------------------------------------------------------------------ the model
func _rebuild() -> void:
	for ch in eng.get_children(): ch.free()
	parts.clear()
	var g := EngineKit.ghost_kit(kit)
	var meshes := EngineKit.part_meshes(g)
	var bb := AABB()
	var first := true
	for slot: String in EngineKit.slots(kit):
		var am: ArrayMesh = meshes.get(slot)
		if am == null: continue
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ghost := EngineKit.slot_id(kit, slot) == ""
		if ghost: mi.material_override = m_ghost
		eng.add_child(mi)
		parts[slot] = {"mi": mi, "tri": am.generate_triangle_mesh(), "ghost": ghost}
		bb = am.get_aabb() if first else bb.merge(am.get_aabb())
		first = false
	eng.position = -bb.get_center()
	dist = clampf(bb.size.length() * 1.9, 1.2, 4.0)
	if sel != "" and not parts.has(sel): sel = ""
	_overlays()
	_title()
	_info()
	if side.visible: _fill_side()

func _process(dt: float) -> void:
	if not open: return
	_idle += dt
	if not _turning and hover == "" and _idle > 2.5 and drop_slot == "":
		spin += dt * 0.32
	pivot.rotation = Vector3(0, spin, 0)
	cam.position = Vector3(0, sin(tilt), cos(tilt)) * dist
	cam.look_at(Vector3.ZERO)
	# sit the engine right of and above the part panel in the bottom left
	cam.h_offset = -dist * (0.06 if side.visible else 0.11)
	cam.v_offset = -dist * 0.05
	# a drag that ended anywhere: clear the drop highlight
	if drop_live and not get_viewport().gui_is_dragging():
		drop_slot = ""; drop_live = false
		if not drop_ok: _msg = ""
		_overlays()
		_info()

func _overlays() -> void:
	for slot: String in parts:
		var mi: MeshInstance3D = parts[slot].mi
		var m: Material = null
		if slot == drop_slot: m = m_ok if drop_ok else m_bad
		elif slot == sel: m = m_sel
		elif slot == hover: m = m_hover
		mi.material_overlay = m

## The part under a point of the view ("" if none)
func _pick(at: Vector2) -> String:
	var from := cam.project_ray_origin(at)
	var dir := cam.project_ray_normal(at)
	var best := INF
	var out := ""
	for slot: String in parts:
		var mi: MeshInstance3D = parts[slot].mi
		var xf := mi.global_transform
		var inv := xf.affine_inverse()
		var r: Dictionary = (parts[slot].tri as TriangleMesh).intersect_ray(inv * from, (inv.basis * dir).normalized())
		if r.is_empty(): continue
		var d := (xf * (r.position as Vector3)).distance_to(from)
		if parts[slot].ghost: d += 0.03          # a real part just behind a ghost's skin wins
		if d < best:
			best = d; out = slot
	return out

func _view_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed: dist = maxf(dist * 0.9, 0.6)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed: dist = minf(dist * 1.1, 5.0)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_turning = mb.pressed
				_idle = 0.0
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_press = mb.position
					_press_slot = _pick(mb.position)
					if mb.double_click:
						sel = _press_slot
						_overlays(); _info()
						_show_side(true, _press_slot)
						_press = Vector2.INF
				else:
					if _press != Vector2.INF and not _turning:
						sel = _pick(mb.position)
						_msg = ""
						_overlays(); _info()
					_press = Vector2.INF
					if _turning: _idle = 0.0
					_turning = false
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		var held := (mm.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and _press != Vector2.INF and mm.position.distance_to(_press) > 5.0:
			_turning = true
		if _turning or held:
			spin += mm.relative.x * 0.008
			tilt = clampf(tilt + mm.relative.y * 0.006, -0.9, 1.35)
			_idle = 0.0
		var h := _pick(mm.position)
		if h != hover:
			hover = h
			_overlays()
		tag.visible = hover != ""
		if hover != "":
			var id := EngineKit.slot_id(kit, hover)
			tag.text = (Items.def(id).name if id != "" else "Empty: " + EngineKit.slot_label(kit, hover))
			tag.position = vpc.position + mm.position + Vector2(16, 10)

# ------------------------------------------------------------------------------------------------ words
func _title() -> void:
	var f := EngineKit.fault(kit)
	var nm := str(ctx.get("title", ""))
	title_l.text = "[font_size=26][b]%s[/b][/font_size]%s\n%s" % [EngineKit.describe(kit) if str(kit.get("block", "")) != "" else "No engine",
		("   [color=#8899aa]%s[/color]" % nm) if nm != "" else "", "[color=#9c6]It'll run.[/color]" if f == "" else "[color=#d66]%s[/color]" % f]

func _info() -> void:
	var t := ""
	var slot := drop_slot if drop_slot != "" else sel
	if drop_live and not drop_ok:
		t = "[color=#d66]%s[/color]" % _msg
	elif slot == "":
		t = "[color=#8899aa]Click a part to see what it is. Empty spots are the see-through ghosts.\nDouble-click for the engine parts in your pack, then drag one onto the engine.[/color]"
		if _msg != "": t += "\n\n[b]%s[/b]" % _msg
	else:
		var id := EngineKit.slot_id(kit, slot)
		if id != "":
			t = "[font_size=19][b]%s[/b][/font_size]\n[color=#8899aa]%s[/color]\n\n%s" % [Items.def(id).name, EngineKit.slot_label(kit, slot), EngineKit.part_info(id)]
		else:
			t = "[font_size=19][b]Empty: %s[/b][/font_size]\n\nTakes: %s" % [EngineKit.slot_label(kit, slot), _takes(slot)]
			var n := 0
			for hid: String in _have():
				if str(EngineKit.slot_for(kit, hid, slot)[0]) == slot: n += 1
			t += "\n\n%s" % ("[color=#9c6]You've got %d that fit%s. Double-click to see them.[/color]" % [n, "s" if n == 1 else ""] if n > 0 else "[color=#db5]Nothing in your pack fits.[/color]")
		if drop_live and drop_ok: t = "[color=#9c6]Let go to fit it here.[/color]\n\n" + t
		elif _msg != "" and not drop_live: t += "\n\n[b]%s[/b]" % _msg
	info.text = t
	var can := sel != "" and EngineKit.slot_id(kit, sel) != ""
	off_btn.visible = can
	off_btn.disabled = not can or not _spanner() or EngineKit.cant_take_off(kit, sel) != "" or (sel == "block" and not ctx.get("block_ok", true))
	off_btn.tooltip_text = "You need a shifter" if not _spanner() else EngineKit.cant_take_off(kit, sel) if sel != "" else ""

## What goes in an empty slot, in words
func _takes(slot: String) -> String:
	var pb := EngineKit.parse_block(str(kit.get("block", "")))
	if slot == "block" or pb.is_empty(): return "any engine block"
	var bc := EngineKit.bank_cyl(pb[0])
	if slot.begins_with("head"): return "any %d-cylinder head" % bc
	if slot.begins_with("exhaust"): return "a %d-cylinder exhaust manifold" % bc
	match slot:
		"intake": return "the %s" % str(Items.def(EngineKit.intake_id(pb[0])).name).to_lower()
		"fuel": return "a carby or EFI throttle body (petrol), or an injection pump (diesel)"
		"ign": return "a distributor and coil (a carby engine's spark)"
		"ecu":
			var fs := str(kit.get("fuel", "")).trim_prefix("ef_")
			return "an %s" % str(Items.def(EngineKit.ecu_id(fs == "epump", int(EngineKit.BLOCKS[pb[0]].cyl))).name)
		"alt": return "an alternator"
	return "?"

# ------------------------------------------------------------------------------------------------ fitting
func _free() -> bool: return Settings.creative()
func _spanner() -> bool: return _free() or main.player.inv.count("wrench") > 0

## The engine parts you've got: {id: count} (creative: everything that fits, count -1)
func _have() -> Dictionary:
	var out := {}
	if _free():
		for id: String in EngineKit.all_items():
			if str(EngineKit.item_def(id).get("part", "")) == "": continue
			if str(EngineKit.slot_for(kit, id)[0]) != "": out[id] = -1
		return out
	for g in main.player.inv.grids():
		for s2 in g[1].items:
			var id := str(s2.id)
			if EngineKit.item_def(id).is_empty() or str(EngineKit.item_def(id).get("part", "")) == "": continue
			out[id] = int(out.get(id, 0)) + int(s2.n)
	return out

func _give(id: String) -> void:
	if _free() or id == "": return
	var o := Items.fresh(id, 1)
	if main.player.inv.add(o) > 0 and main.inv_ui:
		main.inv_ui._drop_world([o])
		_msg += " (no room: it's on the ground)"

func _take(id: String) -> bool:
	if _free(): return true
	return main.player.inv.take(id, 1) > 0

func _fit(id: String, slot: String) -> void:
	if not _spanner(): _say("You need a shifter."); return
	if slot == "block" and not ctx.get("block_ok", true): _say("Get the bonnet off first, or use an engine stand."); return
	if not _take(id): _say("You haven't got one."); return
	var old := EngineKit.fit(kit, slot, id)
	_msg = "Bolted on: %s." % Items.def(id).name if old == "" else "Swapped: the %s came off." % str(Items.def(old).name).to_lower()
	_give(old)
	sel = slot
	# the list now puts first what fits the next empty spot
	focus_slot = ""
	for s2: String in EngineKit.slots(kit):
		if EngineKit.slot_id(kit, s2) == "":
			focus_slot = s2
			break
	_changed()

func _off(slot: String) -> void:
	if not _spanner(): _say("You need a shifter."); return
	var why := EngineKit.cant_take_off(kit, slot)
	if why != "": _say(why); return
	if slot == "block" and not ctx.get("block_ok", true): _say("Get the bonnet off first, or use an engine stand."); return
	var id := EngineKit.take_off(kit, slot)
	_msg = "Off it comes: %s." % Items.def(id).name
	_give(id)
	_changed()

func _changed() -> void:
	var cb = ctx.get("changed")
	if cb is Callable and (cb as Callable).is_valid(): (cb as Callable).call()
	_rebuild()

func _say(t: String) -> void:
	_msg = t
	_info()

# ------------------------------------------------------------------------------------------------ drag and drop
## A selected, fitted part dragged off the engine (onto the list takes it off)
func _drag_from_engine(_at: Vector2) -> Variant:
	if not side.visible or _press_slot == "" or _press_slot != sel or EngineKit.slot_id(kit, sel) == "": return null
	_turning = false
	var id := EngineKit.slot_id(kit, sel)
	var l := Label.new()
	l.text = "  %s  " % Items.def(id).name
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	pad.set_drag_preview(l)
	return {"from_slot": sel}

func _can_drop_engine(at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not (data as Dictionary).has("id"): return false
	var id := str(data.id)
	var under := _pick(at)
	var r := EngineKit.slot_for(kit, id, under)
	var slot := str(r[0])
	drop_slot = slot if slot != "" else under
	drop_ok = slot != "" and _spanner()
	drop_live = true
	_msg = str(r[1]) if slot == "" else ("You need a shifter." if not _spanner() else "")
	_overlays(); _info()
	return drop_ok

func _drop_engine(_at: Vector2, data: Variant) -> void:
	var slot := drop_slot
	var ok := drop_ok
	drop_slot = ""; drop_live = false
	if slot != "" and ok: _fit(str(data.id), slot)

func _can_drop_side(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("from_slot")

func _drop_side(_at: Vector2, data: Variant) -> void:
	_off(str(data.from_slot))

# ------------------------------------------------------------------------------------------------ the parts list
func _show_side(on: bool, slot: String) -> void:
	side.visible = on
	focus_slot = slot
	_layout()
	if on: _fill_side()

func _fill_side() -> void:
	var have := _have()
	var ids: Array = have.keys()
	# the ones that fit the slot you double-clicked first, then anything that fits somewhere, then the rest
	var rank := func(id: String) -> int:
		var r := EngineKit.slot_for(kit, id, focus_slot)
		if str(r[0]) == "": return 2
		if focus_slot != "" and str(r[0]) == focus_slot: return 0
		return 1
	ids.sort_custom(func(a, b):
		var ra: int = rank.call(a); var rb: int = rank.call(b)
		return ra < rb if ra != rb else str(Items.def(a).name) < str(Items.def(b).name))
	for ch in grid.get_children(): grid.remove_child(ch)
	for id: String in ids:
		var t: Control = tiles.get(id)
		if t == null:
			t = _tile(id)
			tiles[id] = t
		grid.add_child(t)
		var r := EngineKit.slot_for(kit, id, focus_slot)
		var fits := str(r[0]) != ""
		t.modulate = Color(1, 1, 1, 1.0 if fits else 0.4)
		var bg: StyleBoxFlat = (t as PanelContainer).get_theme_stylebox("panel")
		bg.border_color = Color(0.35, 0.95, 0.5, 0.9) if fits and focus_slot != "" and str(r[0]) == focus_slot else Color(1, 1, 1, 0.12)
		t.tooltip_text = "%s\n%s" % [Items.def(id).name, ("Fits: " + EngineKit.slot_label(kit, str(r[0]))) if fits else str(r[1])]
		var cnt: Label = t.get_meta("count")
		cnt.text = "" if int(have[id]) <= 1 else "x%d" % int(have[id])
	if ids.is_empty():
		side_note.text = "No engine parts in your pack. Wrecks are short a part or two, and parts turn up in sheds and workshops."
	elif focus_slot != "":
		side_note.text = "Green: fits the empty %s. Drag a part onto the engine to fit it." % EngineKit.slot_label(kit, focus_slot)
	else:
		side_note.text = "Drag a part onto the engine to fit it; dropped on a taken spot, the two swap. Faded parts don't fit this engine."

func _tile(id: String) -> PanelContainer:
	var t := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.13, 0.14, 0.16, 1.0)
	bg.set_border_width_all(2)
	bg.border_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(5)
	bg.set_content_margin_all(4)
	t.add_theme_stylebox_override("panel", bg)
	t.custom_minimum_size = Vector2((SIDE_W - 40.0) / 3.0, 118)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(v)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(112, 66)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tr)
	icon(id, func(tex: Texture2D) -> void:
		if is_instance_valid(tr): tr.texture = tex)
	var l := Label.new()
	l.text = str(Items.def(id).name)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", 11)
	l.custom_minimum_size = Vector2(100, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	var c := Label.new()
	c.add_theme_font_size_override("font_size", 12)
	c.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	c.position = Vector2(6, 4)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(c)
	t.set_meta("count", c)
	t.mouse_entered.connect(func():
		# show where it would go
		var r := EngineKit.slot_for(kit, id, focus_slot)
		if str(r[0]) != "" and not get_viewport().gui_is_dragging():
			hover = str(r[0]); _overlays())
	t.mouse_exited.connect(func():
		if not get_viewport().gui_is_dragging():
			hover = ""; _overlays())
	t.set_drag_forwarding(func(_at: Vector2) -> Variant:
		var pv := TextureRect.new()
		pv.texture = tr.texture
		pv.custom_minimum_size = Vector2(110, 78)
		pv.size = Vector2(110, 78)
		pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pv.modulate = Color(1, 1, 1, 0.85)
		var holder := Control.new()
		holder.add_child(pv)
		pv.position = -pv.size * 0.5
		t.set_drag_preview(holder)
		hover = ""
		return {"id": id}, Callable(), Callable())
	return t

# ------------------------------------------------------------------------------------------------ part pictures
## Rendered on demand, a couple a frame, cached for the inventory too (ItemIcons asks for them)
static var _icons := {}
static var _waiting := {}         # id -> [Callable]
var _queue: Array = []
var _baking := false
const ICON_CELL := 64

static func icon(id: String, cb := Callable()) -> Texture2D:
	if _icons.has(id):
		if cb.is_valid(): cb.call(_icons[id])
		return _icons[id]
	if inst == null: return null
	if not _waiting.has(id):
		_waiting[id] = []
		inst._queue.append(id)
		if not inst._baking: inst._bake()
	if cb.is_valid(): (_waiting[id] as Array).append(cb)
	return null

func _bake() -> void:
	_baking = true
	while not _queue.is_empty():
		var id: String = _queue.pop_front()
		var am := EngineKit.part_mesh(id)
		var d := Items.def(id)
		var tex: Texture2D = null
		if am != null:
			var sv := SubViewport.new()
			sv.own_world_3d = true
			sv.transparent_bg = true
			sv.msaa_3d = Viewport.MSAA_4X
			sv.size = Vector2i(ICON_CELL * maxi(int(d.get("w", 2)), 1), ICON_CELL * maxi(int(d.get("h", 2)), 1))
			sv.render_target_update_mode = SubViewport.UPDATE_ONCE
			add_child(sv)
			_stage(sv)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			var spinn := Node3D.new()
			sv.add_child(spinn)
			spinn.add_child(mi)
			spinn.rotation_degrees = Vector3(22, 58, 0)        # crank across the picture, a three-quarter look
			var bb: AABB = spinn.transform * am.get_aabb()
			# lie it along the icon's long side
			var wide := sv.size.x >= sv.size.y
			if (bb.size.x >= bb.size.y) != wide and sv.size.x != sv.size.y:
				spinn.rotation_degrees = Vector3(22, 58, 90)
				bb = spinn.transform * am.get_aabb()
			var c := Camera3D.new()
			c.projection = Camera3D.PROJECTION_ORTHOGONAL
			c.keep_aspect = Camera3D.KEEP_HEIGHT
			var aspect := float(sv.size.x) / float(sv.size.y)
			c.size = maxf(bb.size.y, bb.size.x / aspect) * 1.12
			c.position = bb.get_center() + Vector3(0, 0, 6)
			sv.add_child(c)
			c.current = true
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := sv.get_texture().get_image()
			if img: tex = ImageTexture.create_from_image(img)
			sv.queue_free()
		_icons[id] = tex
		for cb in _waiting.get(id, []):
			if (cb as Callable).is_valid(): (cb as Callable).call(tex)
		_waiting.erase(id)
		ItemIcons.put(id, tex)
		if main and main.get("inv_ui") and main.inv_ui.get("root"): main.inv_ui.root.queue_redraw()
	_baking = false
