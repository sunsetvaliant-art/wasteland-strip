class_name CraftUI
extends CanvasLayer
## Making things (N): every recipe is known from the start. Pick one, see what it takes and what you've got, make it.
## Tools are needed but not used up. What won't fit in your pockets lands at your feet.

var main
var player
var open := false
var root: Control
var list: ItemList
var info: RichTextLabel
var btn: Button
var ids: Array = []

func setup(m) -> void:
	main = m
	player = m.player
	layer = 21
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 470)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.1, 0.94)
	sb.set_content_margin_all(14)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	cc.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var title := Label.new()
	title.text = "  MAKE  ·  N or Esc to close"
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(hb)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(330, 400)
	list.item_selected.connect(func(_i): _show())
	list.item_activated.connect(func(_i): _make())
	hb.add_child(list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.custom_minimum_size = Vector2(400, 330)
	right.add_child(info)
	btn = Button.new()
	btn.text = "Make it"
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(_make)
	right.add_child(btn)

func toggle() -> void:
	if open:
		close()
		return
	if player == null: player = main.player
	if player == null or player.dead or player.vehicle: return
	if main.inv_ui and main.inv_ui.open: main.inv_ui.close()
	open = true
	root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fill()

func close() -> void:
	open = false
	root.visible = false
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(e: InputEvent) -> void:
	if not open: return
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("craft") or e.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()

func _can(rc: Dictionary) -> bool:
	if Settings.creative(): return true
	for k in rc.needs:
		if player.inv.count(k) < int(rc.needs[k]): return false
	for t in rc.get("tools", []):
		if player.inv.count(t) < 1: return false
	if rc.has("station") and BasePiece.near(get_tree(), str(rc.station), player.global_position) == null: return false
	return true

func _fill() -> void:
	var keep := list.get_selected_items()
	list.clear()
	ids = Items.RECIPES.keys()
	for id in ids:
		var rc: Dictionary = Items.RECIPES[id]
		var n := int(rc.get("n", 1))
		var i := list.add_item("%s%s" % [Items.def(rc.out).name, (" x%d" % n) if n > 1 else ""])
		list.set_item_custom_fg_color(i, Color(0.9, 0.95, 0.85) if _can(rc) else Color(0.5, 0.5, 0.5))
	if ids.size() > 0:
		list.select(keep[0] if keep.size() > 0 and keep[0] < ids.size() else 0)
	_show()

func _show() -> void:
	var sel := list.get_selected_items()
	if sel.is_empty():
		info.text = ""
		return
	var rc: Dictionary = Items.RECIPES[ids[sel[0]]]
	var t := "[b]%s[/b]\n\nTakes:\n" % Items.def(rc.out).name
	for k in rc.needs:
		var have: int = player.inv.count(k)
		var need := int(rc.needs[k])
		t += "   [color=%s]%s  %d / %d[/color]\n" % ["#9c6" if have >= need else "#d66", Items.def(k).name, have, need]
	if rc.get("tools", []).size() > 0:
		t += "\nWith:\n"
		for k in rc.tools:
			t += "   [color=%s]%s[/color]\n" % ["#9c6" if player.inv.count(k) > 0 else "#d66", Items.def(k).name]
	if rc.has("station"):
		var here := BasePiece.near(get_tree(), str(rc.station), player.global_position) != null
		var nm := "a workbench" if rc.station == "bench" else "a lit campfire"
		t += "\nAt:\n   [color=%s]%s%s[/color]\n" % ["#9c6" if here else "#d66", nm, "" if here else " (build one with M)"]
	if rc.has("note"): t += "\n[i]%s[/i]\n" % rc.note
	info.text = t
	btn.disabled = not _can(rc)

func _make() -> void:
	var sel := list.get_selected_items()
	if sel.is_empty(): return
	var rc: Dictionary = Items.RECIPES[ids[sel[0]]]
	if not _can(rc): return
	if not Settings.creative():
		for k in rc.needs:
			player.inv.take(k, int(rc.needs[k]))
	var s := Items.fresh(rc.out, int(rc.get("n", 1)))
	var left: int = player.inv.add(s)
	if left > 0 and main.inv_ui:
		main.inv_ui._drop_world([Items.fresh(rc.out, left)])
		player._toast("No room: the rest is at your feet")
	_fill()
