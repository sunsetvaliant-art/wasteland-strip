class_name CombatHUD
extends Control
## Crosshair (opens up with spread), gun and ammo, health, red edges when you're hit, and the scav "eye":
## how close the nearest scav is to spotting you.

var main
var font: Font

func setup(m) -> void:
	main = m
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main == null or main.player == null:
		return
	var p: Player = main.player
	var sz := size
	var c := sz * 0.5
	# hurt: red closing in from the edges
	if p.hurt_flash > 0.01 or p.hp < 35.0:
		var a: float = max(p.hurt_flash * 0.55, (1.0 - p.hp / 35.0) * 0.3 if p.hp < 35.0 else 0.0)
		for i in 10:
			var w := 18.0 + i * 14.0
			var col := Color(0.55, 0.0, 0.0, a * (1.0 - i / 10.0) * 0.4)
			draw_rect(Rect2(0, 0, w, sz.y), col)
			draw_rect(Rect2(sz.x - w, 0, w, sz.y), col)
			draw_rect(Rect2(0, 0, sz.x, w * 0.6), col)
			draw_rect(Rect2(0, sz.y - w * 0.6, sz.x, w * 0.6), col)
	if p.dead:
		_text(Vector2(c.x, c.y - 40), "You're dead.", 42, Color(0.9, 0.15, 0.1), true)
		_text(Vector2(c.x, c.y + 10), "Back at the pub in %d…" % ceili(p.respawn_t), 20, Color(1, 1, 1, 0.8), true)
		return
	if not p.active or p.vehicle:
		return
	# health
	var hb := Rect2(24, sz.y - 70, 220, 12)
	draw_rect(hb, Color(0, 0, 0, 0.45))
	draw_rect(Rect2(hb.position, Vector2(hb.size.x * p.hp / 100.0, hb.size.y)), Color(0.75, 0.12, 0.08).lerp(Color(0.35, 0.75, 0.3), p.hp / 100.0))
	_text(Vector2(24, sz.y - 78), "HEALTH", 12, Color(1, 1, 1, 0.7))
	# stealth eye: the most suspicious scav who can see you
	var sus := 0.0
	var alarm := false
	for n in main.get_tree().get_nodes_in_group("scavs"):
		if is_instance_valid(n) and not n.dead and n.global_position.distance_to(p.global_position) < 90.0:
			sus = max(sus, n.suspicion)
			alarm = alarm or n.state == "combat"
	if sus > 0.02 or alarm:
		var ec := Vector2(c.x, 46)
		var col := Color(1, 0.2, 0.15) if alarm else Color(1, 0.85, 0.25)
		draw_arc(ec, 18, PI, TAU, 24, Color(1, 1, 1, 0.5), 2.0)
		draw_arc(ec, 18, 0, PI, 24, Color(1, 1, 1, 0.5), 2.0)
		draw_circle(ec, 7.0 * clamp(sus, 0.2, 1.0) + 1.0, col)
		draw_arc(ec, 24, -PI * 0.5, -PI * 0.5 + TAU * clamp(sus, 0.0, 1.0), 32, col, 3.0)
		if p.crouching:
			_text(ec + Vector2(0, 40), "crouched", 12, Color(1, 1, 1, 0.6), true)
	var g: Gun = p.gun()
	if g == null or p.holstered:
		return
	if p.scope_view and p.scope_view.visible:
		_ammo(g, sz)
		return
	# crosshair: four ticks pushed out by the spread you'd get right now
	var spread: float = (0.012 if not g.def.get("pistol", false) else 0.008) * (1.0 - p.ads) + p.velocity.length() * 0.003 + float(g.def.spread)
	var r: float = clamp(spread * sz.y * 1.2, 3.0, 80.0)
	var cc := Color(1, 1, 1, 0.85 - p.ads * 0.5)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(c + d * r, c + d * (r + 7.0), cc, 2.0)
	draw_circle(c, 1.5, cc)
	_ammo(g, sz)

func _ammo(g: Gun, sz: Vector2) -> void:
	# gun and rounds
	var tx := "%s" % g.def.name
	_text(Vector2(sz.x - 24, sz.y - 82), tx, 14, Color(1, 1, 1, 0.75), false, true)
	var am := "%d  /  %d" % [g.ammo, g.reserve]
	if g.reloading > 0.0: am = "reloading…"
	elif g.ammo == 0: am = "EMPTY  ·  R to reload"
	_text(Vector2(sz.x - 24, sz.y - 52), am, 26, Color(1, 0.9, 0.7) if g.ammo > 0 else Color(1, 0.4, 0.3), false, true)

func _text(at: Vector2, t: String, sz: int, col: Color, centre := false, right := false) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var p := at
	if centre: p.x -= w * 0.5
	if right: p.x -= w
	draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, 0.7))
	draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
