class_name InteractMenu
extends CanvasLayer
## The look-at menu (like Vein's): point the crosshair at something you can use and a small menu, styled like the
## Windows right-click menu, opens beside the crosshair. Mouse wheel moves the highlight, left click does the
## highlighted option (the first one is highlighted to start with). Right click shuts it on that thing for 5 seconds,
## so you can swing or shoot at it without picking an option by accident. F still does the first option.
##   dead body: Open inventory
##   car:       Drive, Repair, Inventory (boot / tray)
##   window:    Open / Close, Barricade (or Remove boards), Climb through
##   door:      Open / Close, Barricade (or Remove boards)
##   box:       Open,  loose item: Pick up,  boards: Remove boards,  lift: Use
const HIDE_MS := 5000
const FIRE_BLOCK_MS := 250

static var inst: InteractMenu
static var _block_until := 0
static var test_any_mouse := false     # headless tests can't capture the mouse

var main
var root: Control
var target: Node = null
var opts: Array = []          # [{label, act: Callable, ok: bool, why: String}]
var sel := 0
var hidden := {}              # instance id -> time (ms) the menu may show on it again
var shown := false

## Gun and melee ask this before acting on a left click: true just after a click went to the menu
static func blocking() -> bool:
	return Time.get_ticks_msec() < _block_until

func setup(m) -> void:
	main = m
	inst = self
	layer = 6
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.draw.connect(_draw_menu)
	add_child(root)

func _process(_dt: float) -> void:
	var p = main.player if main else null
	var t: Node = null
	var o: Array = []
	if p and _free(p):
		var r := _pick(p)
		t = r[0]; o = r[1]
	if t != target:
		target = t
		sel = 0
	opts = o
	if sel >= opts.size(): sel = 0
	var hid: bool = t != null and Time.get_ticks_msec() < int(hidden.get(t.get_instance_id(), 0))
	shown = t != null and not opts.is_empty() and not hid
	root.queue_redraw()

func _free(p) -> bool:
	if p.dead or p.vehicle or not p.active or get_tree().paused: return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not test_any_mouse: return false
	if BaseBuild.busy or p.carried != null: return false
	return true

func _input(e: InputEvent) -> void:
	if not shown or target == null or not is_instance_valid(target):
		return
	if e.is_action_pressed("weapon_next"):
		sel = (sel + 1) % opts.size()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("weapon_prev"):
		sel = (sel - 1 + opts.size()) % opts.size()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("fire"):
		_block_until = Time.get_ticks_msec() + FIRE_BLOCK_MS
		get_viewport().set_input_as_handled()
		run(sel)
	elif e.is_action_pressed("aim"):
		hidden[target.get_instance_id()] = Time.get_ticks_msec() + HIDE_MS
		shown = false
		get_viewport().set_input_as_handled()

## Does option i (F calls it with 0)
func run(i: int) -> void:
	if i < 0 or i >= opts.size(): return
	var o: Dictionary = opts[i]
	if not o.ok:
		if o.why != "" and main.player: main.player._toast(o.why)
		return
	(o.act as Callable).call()

# ---------------------------------------------------------------- what's under the crosshair, and what you can do
func _pick(p) -> Array:
	var cam: Camera3D = p.active_camera()
	if cam == null: return [null, []]
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var reach := 3.4 if p.first_person else 5.8
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1 | (1 << 2) | (1 << 3) | (1 << 4), [p.get_rid()])
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty(): return [null, []]
	var hp: Vector3 = h.position
	var n: Node = h.collider
	for _i in 6:
		if n == null: break
		# a dead body: the ragdoll's bones belong to the Ragdoll node, which knows whose body it is
		if n is Ragdoll:
			var who = (n as Ragdoll).owner_actor
			if is_instance_valid(who) and who.get("dead") and InventoryUI.is_container(who) and hp.distance_to(p.global_position) < 3.0:
				return [who, [_o("Open inventory", _open.bind(who))]]
			return [null, []]
		if n is Car:
			var c := n as Car
			if c.driver != null or c.has_meta("net_driven") or c.global_position.distance_to(p.global_position) > 5.0: return [null, []]
			var o := [_o("Drive", func(): p._try_get_in(c))]
			o.append(_o("Repair", _repair.bind(c)))
			if InventoryUI.is_container(c): o.append(_o("Inventory", _open.bind(c)))
			return [c, o]
		if hp.distance_to(p.global_position + Vector3(0, 1.0, 0)) > 2.8:
			return [null, []]
		if n is BasePiece and n.is_in_group("stations"):
			var o := []
			for m in (n as BasePiece).menu(p): o.append(_o(m[0], m[1], m[2], m[3]))
			return [n, o]
		if n is Terrain3D:
			# crouched and looking at the ground: forage; at the water's edge: fill a bottle
			var o := []
			if p.crouching: o.append(_o("Forage for rocks and sticks", _forage.bind(p, hp)))
			if hp.y < 0.6 and hp.distance_to(p.global_position) < 3.0:
				o.append(_o("Fill a bottle", _fill.bind(p), p.inv.count("bottle") > 0, "You need an empty bottle"))
			if o.is_empty(): return [null, []]
			return [_ground, o]
		if n is BuildWindow or n is BuildDoor:
			var is_open: bool = (n.get("open") == true) if n is BuildDoor else (str(n.get("state")) == "open")
			if n is BuildWindow and (n as BuildWindow).fixed: is_open = false
			var o := []
			if not (n is BuildWindow and ((n as BuildWindow).fixed or str(n.get("state")) == "broken")):
				o.append(_o(("Close" if is_open else "Open"), _toggle.bind(p, n)))
			if n.get("boards") == null:
				var ok: bool = p._can_board(n)
				o.append(_o("Barricade", _board.bind(p, n), ok, "To board it up: a hammer, a box of nails and %d planks" % p._planks_for(n)))
			else:
				var b = n.get("boards")
				o.append(_o("Remove boards", _use.bind(p, b), p.inv.count("hammer") > 0, "You need a hammer to prise the planks off"))
			if n is BuildWindow and (n as BuildWindow).passable():
				o.append(_o("Climb through", func(): (n as BuildWindow).climb(p)))
			return [n, o]
		if n is Boards:
			return [n, [_o("Remove boards", _use.bind(p, n), p.inv.count("hammer") > 0, "You need a hammer to prise the planks off")]]
		if n is BuildLift:
			return [n, [_o("Use the lift", func(): (n as BuildLift).use(p))]]
		if n is BuildRoller:
			return [n, [_o("Open / close", func(): n.toggle())]]
		if InventoryUI.is_container(n):
			var nm := "box"
			if n.has_meta("forge"): nm = str(n.get_meta("forge").get("name", "box")).replace(" (old scan)", "")
			elif n.has_meta("container_name"): nm = n.get_meta("container_name")
			return [n, [_o("Open " + nm.to_lower(), _open.bind(n))]]
		if n.is_in_group("pickups") and n.has_meta("items"):
			return [n, [_o("Pick up " + WorldItem.label(n), _use.bind(p, n))]]
		n = n.get_parent()
	return [null, []]

var _ground := Node.new()        # stands in for "the ground" as a menu target
var _foraged := {}               # Vector2i (8 m) -> when it was last picked over (ms)

func _forage(p, at: Vector3) -> void:
	var k := Vector2i(floori(at.x / 8.0), floori(at.z / 8.0))
	if Time.get_ticks_msec() < int(_foraged.get(k, 0)):
		p._toast("Nothing more here. Try somewhere else")
		return
	_foraged[k] = Time.get_ticks_msec() + 600000
	var got := []
	if randf() < 0.7: got.append(Items.fresh("rock", randi_range(1, 2)))
	if randf() < 0.6: got.append(Items.fresh("stick", randi_range(1, 3)))
	if got.is_empty():
		p._toast("Nothing useful")
		return
	var names := []
	for g in got:
		p.inv.add(g)
		names.append("%d %s" % [int(g.n), Items.def(g.id).name.to_lower()])
	p._toast("Found " + ", ".join(names))

func _fill(p) -> void:
	p.inv.take("bottle", 1)
	p.inv.add(Items.fresh("water_dirty", 1))
	p._toast("Filled a bottle. Boil it on a fire before you drink it")

func _open(n: Node) -> void:
	var ui = main.get("inv_ui")
	if ui: ui.show_with(n)

func _repair(c: Car) -> void:
	if main.get("car_care"): main.car_care.show_for(c)

func _board(p, n: Node) -> void:
	p.interact_target = n
	p._board_up()

## the player's own F action on n (pick up, prise boards off)
func _use(p, n: Node) -> void:
	p.interact_target = n
	p._interact()

func _toggle(p, n: Node) -> void:
	if n is BuildDoor: (n as BuildDoor).toggle(p.global_position)
	else: n.toggle()

func _o(label: String, act: Callable, ok := true, why := "") -> Dictionary:
	return {"label": label, "act": act, "ok": ok, "why": why}

# ---------------------------------------------------------------- drawing: a Windows-style context menu
const ROW_H := 24.0
const PAD := 3.0
func _draw_menu() -> void:
	if not shown: return
	var font := ThemeDB.fallback_font
	var fs := 14
	var w := 120.0
	for o in opts: w = maxf(w, font.get_string_size(o.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 46.0)
	var c := root.get_viewport_rect().size * 0.5
	var pos := c + Vector2(26, -6)
	var size := Vector2(w, opts.size() * ROW_H + PAD * 2)
	# shadow, body, border
	root.draw_rect(Rect2(pos + Vector2(3, 3), size), Color(0, 0, 0, 0.25))
	root.draw_rect(Rect2(pos, size), Color(0.95, 0.95, 0.95))
	root.draw_rect(Rect2(pos, size), Color(0.6, 0.6, 0.6), false, 1.0)
	for i in opts.size():
		var o: Dictionary = opts[i]
		var r := Rect2(pos + Vector2(PAD, PAD + i * ROW_H), Vector2(w - PAD * 2, ROW_H))
		var col := Color(0.08, 0.08, 0.08) if o.ok else Color(0.55, 0.55, 0.55)
		if i == sel:
			root.draw_rect(r, Color(0.0, 0.47, 0.84) if o.ok else Color(0.8, 0.85, 0.9))
			if o.ok: col = Color.WHITE
		root.draw_string(font, r.position + Vector2(28, ROW_H * 0.5 + fs * 0.36), o.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		if i == 0:
			root.draw_string(font, r.position + Vector2(10, ROW_H * 0.5 + fs * 0.36), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	var tip := "wheel: choose · left click: do · right click: hide"
	root.draw_string(font, pos + Vector2(0, size.y + 15), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.75))
