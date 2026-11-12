class_name SaveGame
extends Node
## Saves as you go (every minute, and when you quit):
##   user://world.save      the world: time of day, weather, what's been taken out of which cupboards. Only the
##                          machine running the world writes it (on a LAN game, the host: it's the host's world).
##   user://character.save  you: where you are, health, what you're carrying and wearing. Everyone keeps their own.
## Both come back next time you start.

const WORLD := "user://world.save"
const CHAR := "user://character.save"
const EVERY := 60.0
var main
var _t := EVERY

func setup(m) -> void:
	main = m
	get_tree().auto_accept_quit = false
	load_world()
	load_character()

func _process(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		_t = EVERY
		save_all()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_all()
		get_tree().quit()

func save_all() -> void:
	if OS.get_environment("NO_SAVE") != "":
		return
	if main.net == null or main.net.runs_world():
		_write(WORLD, world_state())
	_write(CHAR, char_state())

func world_state() -> Dictionary:
	var d := {"ver": 1, "saved": Time.get_unix_time_from_system()}
	if SkyCycle.inst:
		d["sky"] = SkyCycle.inst.state()
	if main.buildings:
		d["buildings"] = main.buildings.save_state()
	# every car someone's driven: what it is, where it is, what's in the back
	var cars := []
	for c in get_tree().get_nodes_in_group("vehicles"):
		if c is Car and c.has_meta("player_car") and c != main.garage.preview:
			var car: Car = c
			cars.append({"name": str(car.name), "home": car.home_pos if "home_pos" in car else car.global_position,
				"xf": car.global_transform, "design": car.design, "inv": car.get_meta("inv", null)})
	d["cars"] = cars
	if main.get("base"): d["base"] = main.base.save_state()
	return d

func char_state() -> Dictionary:
	var p = main.player
	if p == null:
		return {}
	return {"ver": 1, "pos": p.global_position, "yaw": p.rotation.y, "hp": p.hp, "dead": p.dead,
		"hands": p.inv.hands, "equip": p.inv.equip, "creative": Settings.creative()}

func load_world() -> void:
	var d := _read(WORLD)
	if d.is_empty() or OS.get_environment("NO_LOAD") != "":
		return
	if d.has("sky") and SkyCycle.inst:
		SkyCycle.inst.take_state(d.sky)
	if d.has("buildings") and main.buildings:
		main.buildings.load_state(d.buildings)
	if d.has("cars"):
		_restore_cars.call_deferred(d.cars)
	if d.has("base"):
		_restore_base.call_deferred(d.base)
	print("SAVE world loaded")

func _restore_base(arr: Array) -> void:
	if main.get("base"): main.base.load_state(arr)

## Put the saved cars back: the one that started there is moved to where it was left (and rebuilt as it was), anything
## else is made again
func _restore_cars(cars: Array) -> void:
	await get_tree().process_frame
	for e in cars:
		var found: Car = null
		for c in get_tree().get_nodes_in_group("vehicles"):
			if c is Car and str(c.name) == str(e.name) and ("home_pos" in c) and (c.home_pos as Vector3).distance_to(e.home) < 5.0:
				found = c
		if found:
			found.queue_free()
		var xf: Transform3D = e.xf
		var nc: Car = main.spawn_vehicle(str(e.design.get("cab", "vjwagon")), xf.origin + Vector3.UP * 0.4, 0.0, e.design)
		nc.global_transform = Transform3D(xf.basis, xf.origin + Vector3.UP * 0.4)
		nc.set_meta("player_car", true)
		if e.inv != null:
			nc.set_meta("inv", e.inv)

func load_character() -> void:
	var d := _read(CHAR)
	if d.is_empty() or OS.get_environment("NO_LOAD") != "":
		return
	if bool(d.get("creative", false)) != Settings.creative():
		return          # a different mode's kit: start fresh
	var p = main.player
	if d.get("dead", false):
		return
	var pos: Vector3 = d.get("pos", p.global_position)
	if pos.length() > 1.0 and absf(pos.x) < 30000.0 and absf(pos.z) < 30000.0:
		if main.buildings: main.buildings.build_near_now(pos, 30.0)    # so there's a floor under you if you were indoors
		p.global_position = pos + Vector3.UP * 0.3
		p.rotation.y = float(d.get("yaw", 0.0))
	p.hp = float(d.get("hp", 100.0))
	if d.has("hands"):
		p.inv.hands = d.hands
		p.inv.equip = d.get("equip", {})
		p.inv.sync_guns()
		p.inv.changed.emit()
	print("SAVE character loaded at ", p.global_position.round())

func _write(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_var(d, false)
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v = f.get_var(false)
	return v if typeof(v) == TYPE_DICTIONARY else {}
