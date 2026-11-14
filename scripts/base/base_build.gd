class_name BaseBuild
extends Node3D
## Building (M, with a hammer): a see-through piece follows where you look, snapped to a 1.5 m grid and quarter turns.
## Left click nails it up, taking the planks, tin or bricks out of your pockets. Anywhere: open ground, or inside a
## house to wall off a doorway. What you've built is saved with the world.

static var busy := false          # build mode's on: the trigger's for placing, not shooting
var main
var active := false
var idx := 0
var tier_i := 0
var rot := 0
var lift := 0
var ghost: BasePiece
var _at := Vector3.ZERO
var _ok := false

func setup(m) -> void:
	main = m
	if OS.get_environment("BASE_TEST") != "":
		get_tree().create_timer(6.0).timeout.connect(_demo)

## A hut by the start, for looking at (BASE_TEST=1)
func _demo() -> void:
	var o := Vector3(21.0, main.ground_at(21.0, 21.0) + 0.25, 21.0)
	for t in 3:
		var b := o + Vector3(t * 7.5, 0, 0)
		var tr: String = BasePiece.TIERS[t]
		for i in 2:
			for j in 2:
				spawn("floor", tr, b + Vector3(i * 3.0, 0, j * 3.0), 0.0)
				spawn("floor", tr, b + Vector3(i * 3.0, 3.0, j * 3.0), 0.0)
		spawn("doorway", tr, b + Vector3(0, 0, -1.5), 0.0)
		spawn("window", tr, b + Vector3(3, 0, -1.5), 0.0)
		spawn("wall", tr, b + Vector3(0, 0, 4.5), 0.0)
		spawn("half", tr, b + Vector3(3, 0, 4.5), 0.0)
		spawn("wall", tr, b + Vector3(-1.5, 0, 0), PI / 2)
		spawn("wall", tr, b + Vector3(-1.5, 0, 3), PI / 2)
		spawn("wall", tr, b + Vector3(4.5, 0, 0), PI / 2)
		spawn("crate", tr, b + Vector3(1.0, 0, 1.0), 0.0)
	spawn("stairs", "wood", o + Vector3(-4.5, 0, 1.5), 0.0)
	if OS.get_environment("BASE_TEST") == "1": main.craft_ui.toggle()
	print("BASE demo ", get_tree().get_nodes_in_group("base_pieces").size(), " pieces, recipes ", Items.RECIPES.size())
	for id in Items.RECIPES:
		var rc: Dictionary = Items.RECIPES[id]
		Items.def(rc.out)
		for k in rc.needs: assert(Items.DEFS.has(k))

func toggle() -> void:
	var p = main.player
	if active:
		_stop()
		return
	if p == null or p.dead or p.vehicle: return
	if not Settings.creative() and p.inv.count("hammer") < 1:
		p._toast("You need a hammer to build")
		return
	active = true
	busy = true
	lift = 0
	_remake()

func _stop() -> void:
	active = false
	busy = false
	if ghost:
		ghost.queue_free()
		ghost = null
	if main.player: main.player._toast("")

func _remake() -> void:
	if ghost: ghost.queue_free()
	ghost = BasePiece.new()
	add_child(ghost)
	ghost.setup(BasePiece.KINDS[idx], BasePiece.TIERS[tier_i], true)

func _cost() -> Dictionary:
	return BasePiece.cost(BasePiece.KINDS[idx], BasePiece.TIERS[tier_i])

func _afford() -> bool:
	if Settings.creative(): return true
	var c := _cost()
	for k in c:
		if main.player.inv.count(k) < int(c[k]): return false
	return true

func _aim() -> Dictionary:
	var p = main.player
	var cam: Camera3D = p.active_camera()
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 9.0, 1, [p.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)

func _process(_dt: float) -> void:
	if not active: return
	var p = main.player
	if p == null or p.dead or p.vehicle or get_tree().paused:
		_stop()
		return
	var h := _aim()
	var pos: Vector3
	if h.is_empty():
		var cam: Camera3D = p.active_camera()
		pos = cam.global_position - cam.global_transform.basis.z * 5.0
		pos.y = main.ground_at(pos.x, pos.z)
	else:
		pos = h.position
	var k: String = BasePiece.KINDS[idx]
	var g := 0.5 if BasePiece.FIXED.has(k) else 1.5
	_at = Vector3(snappedf(pos.x, g), pos.y + lift * 0.35 + (0.22 if k == "floor" else 0.0), snappedf(pos.z, g))
	ghost.global_position = _at
	ghost.rotation.y = rot * PI / 2
	var ok := _afford() and _at.distance_to(p.global_position) < 11.0
	if ok != _ok or not ghost.has_meta("tinted"):
		ghost.tint(Color(0.4, 1.0, 0.5, 0.45) if ok else Color(1.0, 0.35, 0.3, 0.45))
		ghost.set_meta("tinted", true)
	_ok = ok
	var c := _cost()
	var parts := []
	for id in c:
		parts.append("%d %s" % [int(c[id]), Items.def(id).name.to_lower()])
	p.toast_text = "%s · %s · %s\nLMB build · wheel piece · Tab material · R turn · [ ] lower/raise · X pull down · M done" % [
		BasePiece.NAMES[k], "-" if BasePiece.FIXED.has(k) else BasePiece.TIERS[tier_i], "free" if Settings.creative() else ", ".join(parts)]
	p._toast_t = 0.5

func _input(e: InputEvent) -> void:
	if not active: return
	var used := true
	if e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_LEFT: _place()
			MOUSE_BUTTON_RIGHT: _stop()
			MOUSE_BUTTON_WHEEL_UP:
				idx = (idx + 1) % BasePiece.KINDS.size()
				_remake()
			MOUSE_BUTTON_WHEEL_DOWN:
				idx = (idx - 1 + BasePiece.KINDS.size()) % BasePiece.KINDS.size()
				_remake()
			_: used = false
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_R: rot = (rot + 1) % 4
			KEY_TAB:
				tier_i = (tier_i + 1) % BasePiece.TIERS.size()
				_remake()
			KEY_BRACKETRIGHT: lift += 1
			KEY_BRACKETLEFT: lift -= 1
			KEY_PAGEUP: lift += 8
			KEY_PAGEDOWN: lift -= 8
			KEY_X: _pull_down()
			_: used = false
	else:
		used = false
	if used: get_viewport().set_input_as_handled()

func _place() -> void:
	var p = main.player
	if not _ok:
		p._toast("Not enough to build that" if not _afford() else "Too far away")
		return
	if not Settings.creative():
		var c := _cost()
		for k in c:
			p.inv.take(k, int(c[k]))
	var b := spawn(BasePiece.KINDS[idx], BasePiece.TIERS[tier_i], _at, rot * PI / 2)
	var a := AudioStreamPlayer3D.new()
	a.stream = Gun.sfx("hammer_nails")
	b.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

func spawn(k: String, t: String, pos: Vector3, yaw: float, hp := -1.0, inv = null) -> BasePiece:
	var b := BasePiece.new()
	if inv != null: b.set_meta("inv", inv)
	main.add_child(b)
	b.setup(k, t)
	b.global_position = pos
	b.rotation.y = yaw
	if hp > 0.0: b.hp = hp
	return b

## X: take down the piece you're looking at; half of what it took comes back
func _pull_down() -> void:
	var h := _aim()
	if h.is_empty() or not (h.collider is BasePiece):
		main.player._toast("Look at something you built to pull it down")
		return
	var b: BasePiece = h.collider
	if b.kind == "crate" and b.has_meta("inv") and not (b.get_meta("inv").get("items", []) as Array).is_empty():
		main.player._toast("Empty the crate first")
		return
	if not Settings.creative():
		var c := BasePiece.cost(b.kind, b.tier)
		for k in c:
			var n := int(c[k]) / 2
			if n > 0: main.player.inv.add(Items.fresh(k, n))
	b.queue_free()

func save_state() -> Array:
	var out := []
	for b in get_tree().get_nodes_in_group("base_pieces"):
		if b is BasePiece and not b.is_queued_for_deletion():
			out.append({"k": b.kind, "t": b.tier, "p": b.global_position, "y": b.rotation.y, "hp": b.hp, "inv": b.get_meta("inv", null), "st": b.get_meta("st", null)})
	return out

func load_state(arr: Array) -> void:
	for d in arr:
		if not (str(d.get("k", "")) in BasePiece.KINDS): continue
		var b := spawn(str(d.k), str(d.get("t", "wood")), d.p, float(d.y), float(d.get("hp", -1.0)), d.get("inv", null))
		if b and d.get("st", null) is Dictionary:
			b.set_meta("st", d.st)
			b._refresh()
