class_name InventoryUI
extends CanvasLayer
## The inventory screen (I, or F on a box). Left: what you're wearing and holding, then your hands, pockets and bag.
## Right: the box you opened, or what's on the ground near you.
##   drag to move · R while dragging turns it · drop on a slot to wear / hold it · drop outside to throw it down
##   right click: use (bandages, food) or put on / take off · shift + click: straight across to the other side

var main
var player
var inv: PlayerInv
var root: Control
var open := false
var container: Node3D = null          # the box being looked in, or null for "nearby"
var held := {}                        # {"stack", "src": {...}, "off": Vector2i}
var regions: Array = []               # built each draw: {"type": "grid"/"slot"/"near", ...}
var near_map := {}                    # stack (by instance id) -> world item it came from
var near_grid := Items.new_grid(6, 8)
var hover := {}
var font: Font
var C := 40.0
var msg := ""
var msg_t := 0.0

func setup(m) -> void:
	main = m
	player = m.player
	inv = player.inv
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.focus_mode = Control.FOCUS_ALL
	root.draw.connect(_draw_all)
	root.gui_input.connect(_gui)
	add_child(root)
	root.visible = false
	inv.changed.connect(func(): if open: root.queue_redraw())

func toggle(box: Node3D = null) -> void:
	if open and box == container:
		close()
	else:
		show_with(box)

func show_with(box: Node3D) -> void:
	if player.dead or player.vehicle:
		return
	container = box
	if box: _fill(box)
	else: _build_near()
	open = true
	root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	root.grab_focus()
	root.queue_redraw()

func close() -> void:
	if not held.is_empty():
		_return_held()
	open = false
	root.visible = false
	container = null
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func flash(t: String) -> void:
	msg = t
	msg_t = 2.5

## A container's grid, rolled from its loot table the first time anyone opens it
static func box_grid(box: Node) -> Dictionary:
	if box.has_meta("inv"):
		return box.get_meta("inv")
	var key: String = box.get_meta("container", "")
	if key == "" and box.has_meta("forge"):
		key = box.get_meta("forge").key
	var c: Array = Items.CONTAINERS.get(key, ["crate", [5, 4]])
	var g := Items.new_grid(c[1][0], c[1][1])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(box.global_position.round()))
	if not box.get_meta("empty", false):
		for s in Items.roll_loot(c[0], rng):
			Inventory.add(g, s)
	box.set_meta("inv", g)
	return g

static func is_container(n: Node) -> bool:
	if n == null: return false
	if n.has_meta("container") or n.has_meta("inv"): return true
	return n.has_meta("forge") and Items.CONTAINERS.has(str(n.get_meta("forge").get("key", "")))

func _fill(box: Node3D) -> void:
	box_grid(box)

func _process(dt: float) -> void:
	msg_t = max(msg_t - dt, 0.0)
	if not open:
		return
	# walked away from the box
	if container and (not is_instance_valid(container) or container.global_position.distance_to(player.global_position) > 4.0):
		container = null
	if container == null:
		_build_near()
	root.size = root.get_viewport_rect().size
	C = clamp(root.size.y / 27.0, 30.0, 48.0)
	root.queue_redraw()

func _input(e: InputEvent) -> void:
	if not open:
		return
	if e.is_action_pressed("inventory") or e.is_action_pressed("menu") or (e.is_action_pressed("interact") and container):
		get_viewport().set_input_as_handled()
		close()
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_R and not held.is_empty():
		held.stack.r = not held.stack.r
		get_viewport().set_input_as_handled()
		root.queue_redraw()

# ---------------------------------------------------------------- what's near you on the ground
func _build_near() -> void:
	near_map.clear()
	near_grid = Items.new_grid(6, 8)
	for pk in get_tree().get_nodes_in_group("pickups"):
		if not (pk as Node3D).has_meta("items"): continue
		if (pk as Node3D).global_position.distance_to(player.global_position) > 3.0: continue
		for s in pk.get_meta("items"):
			var spot := Inventory.free_spot(near_grid, s)
			if spot.is_empty(): break
			s.x = spot.x; s.y = spot.y; s.r = spot.r
			near_grid.items.append(s)
			near_map[s] = pk

# ---------------------------------------------------------------- layout
func _layout() -> void:
	regions.clear()
	var vs := root.size
	var top := vs.y * 0.09
	var x0 := vs.x * 0.06
	# equipment column
	var ey := top + 30.0
	for sl in PlayerInv.SLOTS:
		var w := C * 3.0 if sl in ["primary", "secondary"] else C * 2.0
		var h := C * 1.2 if sl in ["primary", "secondary"] else C * 1.6
		regions.append({"type": "slot", "slot": sl, "rect": Rect2(x0, ey, w, h)})
		ey += h + 18.0
	# your grids, flowed down and across
	var gx := x0 + C * 3.0 + 40.0
	var gy := top + 30.0
	var colw := 0.0
	for pair in inv.grids():
		var g: Dictionary = pair[1]
		var r := Rect2(gx, gy + 20.0, g.w * C, g.h * C)
		if r.end.y > vs.y - 60.0 and gy > top + 31.0:
			gx += colw + 30.0
			gy = top + 30.0
			colw = 0.0
			r = Rect2(gx, gy + 20.0, g.w * C, g.h * C)
		regions.append({"type": "grid", "grid": g, "rect": r, "label": pair[0], "side": "me"})
		gy = r.end.y + 16.0
		colw = max(colw, r.size.x)
	# the other side
	var rx := vs.x * 0.94
	if container:
		var g := box_grid(container)
		var r := Rect2(rx - g.w * C, top + 50.0, g.w * C, g.h * C)
		regions.append({"type": "grid", "grid": g, "rect": r, "label": _box_name(container), "side": "box"})
		regions.append({"type": "takeall", "rect": Rect2(r.position.x, r.end.y + 12.0, 150.0, 34.0)})
	else:
		var r := Rect2(rx - near_grid.w * C, top + 50.0, near_grid.w * C, near_grid.h * C)
		regions.append({"type": "grid", "grid": near_grid, "rect": r, "label": "On the ground nearby", "side": "near"})

func _box_name(b: Node) -> String:
	if b.has_meta("forge"):
		var f = b.get_meta("forge")
		return str(f.get("name", f.get("key", "Box"))).replace(" (old scan)", "")
	return str(b.get_meta("container_name", "Box"))

func _region_at(p: Vector2) -> Dictionary:
	for r in regions:
		if (r.rect as Rect2).has_point(p): return r
	return {}

# ---------------------------------------------------------------- input
func _gui(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		hover = _region_at(e.position)
		root.queue_redraw()
		return
	if not (e is InputEventMouseButton) or not e.pressed and e.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = e.position
	var r := _region_at(p)
	if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		if r.get("type") == "takeall":
			_take_all()
			return
		var s = _stack_at(r, p)
		if s == null: return
		if e.shift_pressed:
			_quick_move(s, r)
			return
		_pick(s, r, p)
	elif e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and not held.is_empty():
		_drop_held(r, p)
	elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
		var s = _stack_at(r, p)
		if s != null: _context(s, r)
	root.queue_redraw()

func _cell(r: Dictionary, p: Vector2) -> Vector2i:
	var q: Vector2 = (p - (r.rect as Rect2).position) / C
	return Vector2i(floori(q.x), floori(q.y))

func _stack_at(r: Dictionary, p: Vector2):
	match r.get("type", ""):
		"grid":
			var c := _cell(r, p)
			return Inventory.at(r.grid, c.x, c.y)
		"slot":
			return inv.equip.get(r.slot)
	return null

func _pick(s: Dictionary, r: Dictionary, p: Vector2) -> void:
	var off := Vector2i.ZERO
	if r.type == "grid":
		off = _cell(r, p) - Vector2i(s.x, s.y)
		_remove_from(s, r)
	else:
		inv.equip.erase(r.slot)
		inv.sync_guns()
	held = {"stack": s, "src": r, "sx": s.x, "sy": s.y, "sr": s.r, "off": off}

func _remove_from(s: Dictionary, r: Dictionary) -> void:
	(r.grid.items as Array).erase(s)
	if r.get("side") == "near" and near_map.has(s):
		var wi: Node = near_map[s]
		var lst: Array = wi.get_meta("items")
		lst.erase(s)
		if lst.is_empty(): wi.queue_free()

func _drop_held(r: Dictionary, p: Vector2) -> void:
	var s: Dictionary = held.stack
	var t: String = r.get("type", "")
	if t == "grid" and r.side != "near":
		var c: Vector2i = _cell(r, p) - (held.off as Vector2i)
		var other = Inventory.at(r.grid, _cell(r, p).x, _cell(r, p).y)
		if other != null and other != s and other.id == s.id and int(Items.def(s.id).stack) > 1:
			var room: int = int(Items.def(s.id).stack) - other.n
			var mv: int = min(room, s.n)
			other.n += mv
			s.n -= mv
			if s.n <= 0:
				held.clear(); inv.changed.emit(); return
		elif Inventory.fits(r.grid, Items.size_of(s), c.x, c.y):
			s.x = c.x; s.y = c.y
			r.grid.items.append(s)
			held.clear(); inv.changed.emit(); return
		elif r.grid != held.src.get("grid"):
			if Inventory.add(r.grid, s) == 0:
				held.clear(); inv.changed.emit(); return
	elif t == "slot":
		if inv.can_equip(s, r.slot) and s.n == 1:
			var old = inv.equip.get(r.slot)
			inv.equip[r.slot] = s
			held.clear()
			if old != null and inv.add(old) > 0:
				_drop_world([old])
			inv.sync_guns()
			inv.changed.emit()
			return
		elif s.n > 1 and inv.can_equip(s, r.slot):
			flash("One at a time")
	elif t == "" or (t == "grid" and r.side == "near"):
		# off the panels, or onto the ground list: throw it down
		_drop_world([s])
		held.clear()
		inv.changed.emit()
		return
	_return_held()

func _return_held() -> void:
	if held.is_empty(): return
	var s: Dictionary = held.stack
	var src: Dictionary = held.src
	s.r = held.sr
	if src.type == "slot":
		if not inv.equip.has(src.slot):
			inv.equip[src.slot] = s
			inv.sync_guns()
		elif inv.add(s) > 0: _drop_world([s])
	elif src.side == "near" and near_map.has(s) and is_instance_valid(near_map[s]):
		(near_map[s].get_meta("items") as Array).append(s)
	else:
		s.x = held.sx; s.y = held.sy
		if Inventory.fits(src.grid, Items.size_of(s), s.x, s.y): src.grid.items.append(s)
		elif Inventory.add(src.grid, s) > 0: _drop_world([s])
	held.clear()
	inv.changed.emit()

func _drop_world(stacks: Array) -> void:
	var f: Vector3 = -player.global_transform.basis.z
	WorldItem.spawn(main, stacks, player.global_position + f * 0.7 + Vector3(0, 1.0, 0), f * 1.5)

func _quick_move(s: Dictionary, r: Dictionary) -> void:
	if r.type == "slot":
		inv.equip.erase(r.slot)
		inv.sync_guns()
		var dest = box_grid(container) if container else null
		if dest == null or Inventory.add(dest, s) > 0:
			if inv.add(s) > 0: inv.equip[r.slot] = s
		inv.sync_guns()
	elif r.side == "me":
		if container == null: return
		_remove_from(s, r)
		var left := Inventory.add(box_grid(container), s)
		if left > 0:
			s.n = left
			Inventory.add(r.grid, s)
	else:
		_remove_from(s, r)
		var left := inv.add(s)
		if left > 0:
			s.n = left
			if r.side == "near": _drop_world([s])
			else: Inventory.add(r.grid, s)
			flash("No room")
	inv.changed.emit()

func _take_all() -> void:
	if container == null: return
	var g := box_grid(container)
	for s in g.items.duplicate():
		g.items.erase(s)
		var left := inv.add(s)
		if left > 0:
			s.n = left
			Inventory.add(g, s)
			flash("No room for the rest")
	inv.changed.emit()

func _context(s: Dictionary, r: Dictionary) -> void:
	var d := Items.def(s.id)
	if r.type == "slot":
		inv.equip.erase(r.slot)
		if inv.add(s) > 0:
			inv.equip[r.slot] = s
			flash("No room to take it off")
		inv.sync_guns()
		inv.changed.emit()
		return
	if d.kind in ["med", "food"] and r.side != "near":
		if inv.use(s, r.grid): flash("Using %s…" % d.name)
		return
	if d.has("slot"):
		var slot: String = d.slot
		if d.kind == "gun" and inv.equip.has(slot) and not inv.equip.has("secondary" if slot == "primary" else "primary"):
			slot = "secondary" if slot == "primary" else "primary"
		_remove_from(s, r)
		var single := s
		if s.n > 1:
			single = s.duplicate(true)
			single.n = 1
			s.n -= 1
			r.grid.items.append(s)
		var old = inv.equip.get(slot)
		inv.equip[slot] = single
		if old != null and inv.add(old) > 0: _drop_world([old])
		inv.sync_guns()
		inv.changed.emit()

# ---------------------------------------------------------------- drawing
func _draw_all() -> void:
	_layout()
	var vs := root.size
	root.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.02, 0.02, 0.72))
	_text(Vector2(vs.x * 0.06, vs.y * 0.09), "INVENTORY", 26, Color(0.95, 0.6, 0.25))
	var hint := "drag to move · R turn · right click use / wear · shift click send across · drop off the panel to throw it down · I / Esc close"
	_text(Vector2(vs.x * 0.06, vs.y - 24.0), hint, 14, Color(1, 1, 1, 0.55))
	for r in regions:
		match r.type:
			"slot": _draw_slot(r)
			"grid": _draw_grid(r)
			"takeall":
				root.draw_rect(r.rect, Color(0.85, 0.45, 0.15, 0.85))
				_text(r.rect.position + Vector2(14, 23), "Take everything", 15, Color(1, 1, 1))
	# health and what's being used
	var hp_r := Rect2(vs.x * 0.06 + 200.0, vs.y * 0.09 - 12.0, C * 4.0, 8.0)
	root.draw_rect(hp_r, Color(0, 0, 0, 0.6))
	root.draw_rect(Rect2(hp_r.position, Vector2(hp_r.size.x * player.hp / 100.0, 8.0)), Color(0.75, 0.12, 0.08).lerp(Color(0.35, 0.75, 0.3), player.hp / 100.0))
	if not inv.using.is_empty():
		_text(hp_r.position + Vector2(hp_r.size.x + 12.0, 9.0), "using %s %d%%" % [Items.def(inv.using.stack.id).name, int(100.0 * inv.using.t / inv.using.total)], 13, Color(1, 1, 1, 0.8))
	# tooltip
	if held.is_empty() and not hover.is_empty():
		var s = _stack_at(hover, root.get_local_mouse_position())
		if s != null: _tooltip(s)
	# the thing in your hand
	if not held.is_empty():
		var s: Dictionary = held.stack
		var sz := Items.size_of(s)
		var p := root.get_local_mouse_position() - Vector2(held.off) * C - Vector2(C, C) * 0.5
		var r := _region_at(root.get_local_mouse_position())
		var ok := true
		if r.get("type") == "grid" and r.side != "near":
			var c: Vector2i = _cell(r, root.get_local_mouse_position()) - (held.off as Vector2i)
			p = (r.rect as Rect2).position + Vector2(c) * C
			ok = Inventory.fits(r.grid, sz, c.x, c.y)
			var under = Inventory.at(r.grid, _cell(r, root.get_local_mouse_position()).x, _cell(r, root.get_local_mouse_position()).y)
			if under != null and under.id == s.id and int(Items.def(s.id).stack) > 1: ok = true
		_draw_item(s, Rect2(p, Vector2(sz) * C), 0.85, ok)
	if msg_t > 0.0:
		_text(Vector2(vs.x * 0.5 - 80.0, vs.y * 0.06), msg, 18, Color(1, 0.85, 0.5, min(msg_t, 1.0)))

func _draw_slot(r: Dictionary) -> void:
	var rect: Rect2 = r.rect
	var hl: bool = not held.is_empty() and inv.can_equip(held.stack, r.slot)
	root.draw_rect(rect, Color(0.12, 0.12, 0.11, 0.9))
	root.draw_rect(rect, Color(0.95, 0.6, 0.25, 0.9) if hl else Color(1, 1, 1, 0.18), false, 2.0 if hl else 1.0)
	_text(rect.position + Vector2(0, -5), PlayerInv.SLOT_NAMES[r.slot], 13, Color(1, 1, 1, 0.6))
	var s = inv.equip.get(r.slot)
	if s != null:
		_draw_item(s, rect.grow(-3.0), 1.0, true, true)

func _draw_grid(r: Dictionary) -> void:
	var rect: Rect2 = r.rect
	var g: Dictionary = r.grid
	_text(rect.position + Vector2(0, -6), "%s  (%d x %d)" % [r.label, g.w, g.h], 14, Color(1, 1, 1, 0.7))
	root.draw_rect(rect, Color(0.1, 0.1, 0.09, 0.9))
	for y in int(g.h):
		for x in int(g.w):
			root.draw_rect(Rect2(rect.position + Vector2(x, y) * C, Vector2(C, C)), Color(1, 1, 1, 0.07), false, 1.0)
	for s in g.items:
		if not held.is_empty() and s == held.stack: continue
		_draw_item(s, Rect2(rect.position + Vector2(s.x, s.y) * C, Vector2(Items.size_of(s)) * C), 1.0, true)

func _draw_item(s: Dictionary, rect: Rect2, alpha: float, ok: bool, fit := false) -> void:
	var d := Items.def(s.id)
	var col: Color = Items.KIND_COL.get(d.kind, Color.GRAY)
	if not ok: col = Color(0.6, 0.1, 0.1)
	col.a = 0.92 * alpha
	var rr := rect.grow(-2.0)
	root.draw_rect(rr, col)
	root.draw_rect(rr, Color(1, 1, 1, 0.25 * alpha), false, 1.0)
	var ic := ItemIcons.get_icon(s.id)
	if ic:
		var isz := ic.get_size()
		var k: float = min(rr.size.x / isz.x, rr.size.y / isz.y) * 0.92
		var turned: bool = s.get("r", false) and not fit
		if turned:
			k = min(rr.size.x / isz.y, rr.size.y / isz.x) * 0.92
			root.draw_set_transform(rr.get_center(), PI * 0.5, Vector2.ONE)
			root.draw_texture_rect(ic, Rect2(-isz * k * 0.5, isz * k), false, Color(1, 1, 1, alpha))
			root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			root.draw_texture_rect(ic, Rect2(rr.get_center() - isz * k * 0.5, isz * k), false, Color(1, 1, 1, alpha))
	var fs := 11 if rr.size.x < C * 1.5 else 12
	var nm: String = d.name
	if rr.size.x < C * 1.5 and nm.length() > 7: nm = nm.substr(0, 6) + "…"
	_text(rr.position + Vector2(3, fs + 1), nm, fs, Color(1, 1, 1, 0.9 * alpha))
	if s.n > 1:
		_text(rr.end - Vector2(4, 4), "%d" % s.n, 13, Color(1, 0.92, 0.6, alpha), true)
	if d.kind == "gun":
		_text(rr.end - Vector2(4, 4), "%d/%d" % [int(s.data.get("ammo", 0)), int(Gun.DEFS[d.gun].mag)], 12, Color(1, 0.92, 0.6, alpha), true)

func _tooltip(s: Dictionary) -> void:
	var d := Items.def(s.id)
	var lines: Array = [d.name]
	match d.kind:
		"gun":
			var gd: Dictionary = Gun.DEFS[d.gun]
			lines.append("%s · %d/%d loaded · takes %s" % [gd.name, int(s.data.get("ammo", 0)), int(gd.mag), Items.def(Items.GUN_AMMO[d.gun]).name])
		"med", "food":
			lines.append("Heals %d · right click to use" % int(d.get("heal", 0)))
		"clothing", "pack":
			if d.has("grid"): lines.append("Adds %d x %d of storage" % [d.grid[0], d.grid[1]])
	if s.n > 1: lines.append("%d of %d in this stack" % [s.n, int(d.stack)])
	lines.append("%d x %d" % [d.w, d.h])
	var p := root.get_local_mouse_position() + Vector2(18, 18)
	var w := 0.0
	for l in lines: w = max(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
	var box := Rect2(p, Vector2(w + 16.0, lines.size() * 19.0 + 10.0))
	if box.end.x > root.size.x: box.position.x -= box.size.x + 30.0
	root.draw_rect(box, Color(0.04, 0.04, 0.04, 0.95))
	root.draw_rect(box, Color(0.95, 0.6, 0.25, 0.6), false, 1.0)
	for i in lines.size():
		_text(box.position + Vector2(8, 20 + i * 19), lines[i], 14, Color(1, 1, 1, 0.95 if i == 0 else 0.7))

func _text(at: Vector2, t: String, sz: int, col: Color, right := false) -> void:
	var p := at
	if right: p.x -= font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	root.draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 3, Color(0, 0, 0, 0.8))
	root.draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
