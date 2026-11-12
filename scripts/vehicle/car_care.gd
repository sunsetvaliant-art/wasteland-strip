class_name CarCare
extends CanvasLayer
## What state a found car is in, and the window for doing something about it (K beside a car: "under the bonnet").
## Every car is rolled once from where it stood: how worn the engine is, whether the battery's flat, how much fuel is
## left, and where its key is (in the ignition, somewhere in the cab, or gone). No key: try one you've found, or
## hotwire it (a length of wire a go; the better a mechanic you are the likelier it takes). Looking it over, topping
## up the oil, cleaning the plugs and pouring in fuel need no tools; repairing the engine and swapping batteries need
## a shifter. Fixing cars makes you a better mechanic.

const TANK := 60.0
const LEVELS := [20, 60, 130, 240, 400]        # mechanic xp for levels 1..5
const HOTWIRE := [0.1, 0.3, 0.6, 0.85, 1.0, 1.0]

var main
var car: Car
var open := false
var root: Control
var info: RichTextLabel
var btns: VBoxContainer
var msg := ""

# ------------------------------------------------------------------------------------------------ the car's state
static func of(c: Node) -> Dictionary:
	if c.has_meta("care"):
		return c.get_meta("care")
	var rng := RandomNumberGenerator.new()
	var hp: Vector3 = c.home_pos if c.home_pos != Vector3.ZERO else c.global_position
	rng.seed = hash(Vector3i(hp.round())) + 77
	var st := {"engine": clampf(rng.randfn(55.0, 25.0), 8.0, 100.0), "battery": 0.0 if rng.randf() < 0.25 else rng.randf_range(30.0, 100.0),
		"fuel": 0.0 if rng.randf() < 0.3 else rng.randf_range(2.0, 28.0), "key": "none", "cut": absi(hash(str(c.name))) % 3,
		"hot": false, "checked": false, "plugs": false, "searched": false}
	var k := rng.randf()
	if k < 0.12: st.key = "ignition"
	elif k < 0.32: st.key = "cab"
	if Settings.creative():
		st = good()
	c.set_meta("care", st)
	return st

static func good() -> Dictionary:
	return {"engine": 100.0, "battery": 100.0, "fuel": TANK, "key": "ignition", "cut": 0, "hot": false, "checked": true, "plugs": true, "searched": true}

## Why it won't go ("" if it will)
static func blocked(c: Node) -> String:
	if Settings.creative(): return ""
	var st := of(c)
	if st.key != "ignition" and not st.hot: return "No key. K: look for it, try one, or hotwire it"
	if float(st.battery) < 5.0: return "The battery's flat"
	if float(st.fuel) <= 0.0: return "Out of fuel"
	if float(st.engine) <= 0.0: return "The engine's seized"
	return ""

static func power(c: Node) -> float:
	if Settings.creative(): return 1.0
	return lerpf(0.5, 1.0, clampf(float(of(c).engine) / 80.0, 0.0, 1.0))

## Running: burns fuel, wears a little, a worn one coughs and dies now and then
static func burn(c: Node, dt: float, throttle: float) -> void:
	if Settings.creative(): return
	var st := of(c)
	st.fuel = maxf(float(st.fuel) - dt * (0.0012 + 0.006 * throttle), 0.0)
	st.battery = minf(float(st.battery) + dt * 0.4, 100.0)
	if float(st.fuel) <= 0.0 or (float(st.engine) < 22.0 and throttle > 0.5 and randf() < dt * 0.06):
		c.running = false
		c.crank = -1.2             # a moment before it'll turn over again

static func level(p) -> int:
	var xp := int(p.melee.skills.get("mechanic", 0))
	var lv := 0
	for t in LEVELS:
		if xp >= int(t): lv += 1
	return lv

static func gain(p, xp: int) -> void:
	var before := level(p)
	p.melee.skills["mechanic"] = int(p.melee.skills.get("mechanic", 0)) + xp
	if level(p) > before: p._toast("Mechanic level %d" % level(p))

# ------------------------------------------------------------------------------------------------ the window
func setup(m) -> void:
	main = m
	layer = 22
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
	panel.custom_minimum_size = Vector2(780, 480)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.1, 0.94)
	sb.set_content_margin_all(14)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	cc.add_child(panel)
	var hb := HBoxContainer.new()
	panel.add_child(hb)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.custom_minimum_size = Vector2(380, 460)
	hb.add_child(info)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(380, 460)
	hb.add_child(sc)
	btns = VBoxContainer.new()
	btns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(btns)
	if OS.get_environment("CAR_TEST") != "":
		get_tree().create_timer(9.0).timeout.connect(_selftest)


func show_for(c: Car) -> void:
	var p = main.player
	if p == null or p.dead or p.vehicle: return
	car = c
	open = true
	msg = ""
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
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("work_on_car"):
		close()
		get_viewport().set_input_as_handled()

func _bar(v: float) -> String:
	var word := "good" if v > 75.0 else ("fair" if v > 45.0 else ("poor" if v > 15.0 else "wrecked"))
	return "[color=%s]%s (%d%%)[/color]" % ["#9c6" if v > 45.0 else ("#db5" if v > 15.0 else "#d66"), word, int(v)]

func _fill() -> void:
	if car == null or not is_instance_valid(car):
		close()
		return
	var p = main.player
	var st := CarCare.of(car)
	var free: bool = Settings.creative()
	var spanner: bool = free or p.inv.count("wrench") > 0
	var t := "[b]UNDER THE BONNET[/b]   (K or Esc to close)\n\n"
	if st.checked:
		t += "Engine:   %s\n" % _bar(float(st.engine))
		t += "Battery:  %s\n" % ("[color=#d66]flat[/color]" if float(st.battery) < 5.0 else _bar(float(st.battery)))
		t += "Fuel:     %d of %d litres\n" % [int(st.fuel), int(TANK)]
	else:
		t += "Engine:   ?\nBattery:  ?\nFuel:     ?\n[i]Look it over to find out.[/i]\n"
	t += "Key:      %s\n" % ("in the ignition" if st.key == "ignition" else ("hotwired" if st.hot else "[color=#d66]no key[/color]"))
	t += "\nMechanic level %d   ·   %s\n" % [CarCare.level(p), "shifter in hand" if spanner else "[color=#db5]no shifter: basic jobs only[/color]"]
	var why := CarCare.blocked(car)
	t += "\n" + ("[color=#9c6]It'll go.[/color]" if why == "" else "[color=#d66]%s[/color]" % why.split(".")[0])
	if msg != "": t += "\n\n[b]%s[/b]" % msg
	info.text = t
	for ch in btns.get_children():
		ch.queue_free()
	var add := func(label: String, ok: bool, fn: Callable) -> void:
		var b := Button.new()
		b.text = label
		b.disabled = not ok
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(func():
			fn.call()
			_fill())
		btns.add_child(b)
	var has := func(id: String, n := 1) -> bool: return free or p.inv.count(id) >= n
	add.call("Look it over", not st.checked, func():
		st.checked = true
		msg = "You've had a good look.")
	if st.key != "ignition" and not st.hot:
		add.call("Search the cab for the key", not st.searched, func():
			st.searched = true
			if st.key == "cab":
				st.key = "ignition"
				msg = "Behind the sun visor. It's in the ignition."
			else:
				msg = "No key in here.")
		add.call("Try a key (you have %d)" % p.inv.count("car_key"), p.inv.count("car_key") > 0, func():
			var fits := false
			for g in p.inv.grids():
				for s in g[1].items:
					if s.id == "car_key" and not fits and int(s.data.get("cut", -1)) == int(st.cut):
						fits = true
						g[1].items.erase(s)
			if fits:
				st.key = "ignition"
				p.inv.changed.emit()
				msg = "It fits."
			else:
				msg = "None of them fit this one.")
		add.call("Hotwire it  (1 wire, %d%% at your level)" % int(HOTWIRE[CarCare.level(p)] * 100.0), has.call("wire"), func():
			if not free: p.inv.take("wire", 1)
			CarCare.gain(p, 4)
			if randf() < float(HOTWIRE[CarCare.level(p)]) or free:
				st.hot = true
				CarCare.gain(p, 8)
				msg = "It's live: twist the wires and it'll turn over."
			else:
				msg = "Sparks, and nothing. The wire's burnt out.")
	add.call("Pour in a jerry can of fuel  (+20 L)", has.call("jerry_fuel") and float(st.fuel) < TANK - 1.0, func():
		if not free: p.inv.take("jerry_fuel", 1)
		st.fuel = minf(float(st.fuel) + 20.0, TANK)
		msg = "Twenty litres in.")
	add.call("Top up the oil  (1 engine oil, up to fair)", has.call("oil_can") and float(st.engine) < 70.0, func():
		if not free: p.inv.take("oil_can", 1)
		st.engine = minf(float(st.engine) + 10.0, 70.0)
		CarCare.gain(p, 2)
		msg = "Runs a bit sweeter.")
	add.call("Clean the plugs and the battery leads", not st.plugs, func():
		st.plugs = true
		st.engine = minf(float(st.engine) + 6.0, 100.0)
		if float(st.battery) >= 1.0: st.battery = minf(float(st.battery) + 12.0, 100.0)
		CarCare.gain(p, 3)
		msg = "Every little helps.")
	add.call("SHIFTER: repair the engine  (2 scrap metal, +%d%%)" % (18 + CarCare.level(p) * 4), spanner and has.call("scrap", 2) and float(st.engine) < 100.0, func():
		if not free: p.inv.take("scrap", 2)
		st.engine = minf(float(st.engine) + 18.0 + CarCare.level(p) * 4.0, 100.0)
		CarCare.gain(p, 10)
		msg = "Skinned knuckles, better engine.")
	add.call("SHIFTER: fit a battery you're carrying", spanner and p.inv.count("car_battery") > 0, func():
		var old := float(st.battery)
		for g in p.inv.grids():
			for s in g[1].items:
				if s.id == "car_battery":
					st.battery = float(s.data.get("charge", 80.0))
					g[1].items.erase(s)
					if old >= 5.0:
						var o := Items.fresh("car_battery", 1)
						o.data["charge"] = old
						p.inv.add(o)
					p.inv.changed.emit()
					CarCare.gain(p, 5)
					msg = "Battery fitted."
					return)
	add.call("SHIFTER: take the battery out", spanner and float(st.battery) >= 5.0, func():
		var o := Items.fresh("car_battery", 1)
		o.data["charge"] = float(st.battery)
		if p.inv.add(o) > 0 and main.inv_ui: main.inv_ui._drop_world([o])
		st.battery = 0.0
		CarCare.gain(p, 3)
		msg = "Battery's out.")
	add.call("SHIFTER: rebuild it (the garage)", spanner and main.get("garage") != null, func():
		var c := car
		close()
		main.garage.show_garage(c.design, c))

func _selftest() -> void:
	var p = main.player
	var c: Car = main.spawn_vehicle("vjwagon", p.global_position + Vector3(4, 1.0, 0), 0.3)
	await get_tree().create_timer(1.5).timeout
	c.remove_meta("care") if c.has_meta("care") else null
	var st := {"engine": 30.0, "battery": 0.0, "fuel": 0.0, "key": "cab", "cut": 1, "hot": false, "checked": false, "plugs": false, "searched": false}
	c.set_meta("care", st)
	print("PROBE car power ", snappedf(lerpf(0.5, 1.0, clampf(30.0 / 80.0, 0.0, 1.0)), 0.01), " level ", CarCare.level(p), " xp ", p.melee.skills)
	CarCare.gain(p, 25)
	print("PROBE car level after 25xp ", CarCare.level(p))
	show_for(c)
	for b in btns.get_children():
		if b is Button and not b.disabled and not b.text.contains("garage") and not b.text.contains("take the battery"): b.pressed.emit()
	await get_tree().process_frame
	print("PROBE car after buttons ", st)
