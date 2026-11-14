extends Node
## Headless checks for 0.2.45: the look-at menu (car, dead zombie), body loot, stations (fire, garden), chopping a
## tree, recipes at a station. Prints FT lines.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	for _i in 120: await get_tree().physics_frame
	var p = main.player
	Settings.set_value("god_mode", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var M: InteractMenu = InteractMenu.inst
	InteractMenu.test_any_mouse = true
	p.first_person = true
	p._apply_camera()
	var fwd := -Vector3(sin(p.yaw), 0, cos(p.yaw))
	# ---- a car in front
	var car: Car = null
	for c in get_tree().get_nodes_in_group("vehicles"):
		if c is Car: car = c; break
	if car:
		car.global_position = p.global_position + fwd * 2.6 + Vector3(0, 0.6, 0)
		car.rotation = Vector3(0, p.yaw + PI * 0.5, 0)
		car.linear_velocity = Vector3.ZERO
		for _i in 30: await get_tree().physics_frame
		p.pitch = -0.25
		for _i in 10: await get_tree().process_frame
		var labels := []
		for o in M.opts: labels.append(o.label)
		var cam: Camera3D = p.active_camera()
		var fr := cam.global_position; var dr := -cam.global_transform.basis.z
		var hh: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(fr, fr + dr * 6.0, 1 | 4 | 8 | 16, [p.get_rid()]))
		print("FT dbg free=%s active=%s dead=%s veh=%s carried=%s busy=%s cam=%s fp=%s ray=%s car at %s me %s" % [M._free(p), p.active, p.dead, p.vehicle, p.carried, BaseBuild.busy, fr, p.first_person, [hh.get("collider"), hh.get("position")], car.global_position, p.global_position])
		print("FT car menu shown=%s target=%s options=%s" % [M.shown, M.target == car, labels])
		car.global_position += Vector3(40, 0, 0)
	else:
		print("FT no car to test")
	# ---- a dead zombie in front
	var z := NPC.new()
	z.kind = "zombie"
	main.add_child(z)
	z.global_position = p.global_position + fwd * 1.6
	z.home = z.global_position; z.goal = z.global_position
	for _i in 20: await get_tree().physics_frame
	if z:
		z.global_position = p.global_position + fwd * 1.6
		for _i in 5: await get_tree().physics_frame
		z.die(Vector3.ZERO, z.global_position + Vector3.UP, "chest", [])
		for _i in 90: await get_tree().physics_frame
		p.pitch = -0.9
		var found := false
		for k in 40:
			p.pitch = -1.3 + k * 0.03
			await get_tree().process_frame
			await get_tree().process_frame
			if M.shown and M.target == z: found = true; break
		var labels := []
		for o in M.opts: labels.append(o.label)
		var g := InventoryUI.box_grid(z)
		var items := []
		for s in g.get("items", []): items.append("%s x%d" % [s.id, s.n])
		print("FT body menu found=%s options=%s container=%s loot=%s" % [found, labels, z.get_meta("container", ""), items])
	else:
		print("FT no zombie to test")
	# ---- stations: a campfire, light it, boil water; a garden, plant
	p.inv.add(Items.fresh("lighter", 1)); p.inv.add(Items.fresh("wood", 4)); p.inv.add(Items.fresh("water_dirty", 1)); p.inv.add(Items.fresh("seeds", 2))
	var fire: BasePiece = main.base.spawn("fire", "wood", p.global_position + fwd * 2.0, 0.0)
	var opts: Array = fire.menu(p)
	print("FT fire menu: %s ok=%s" % [opts[0][0], opts[0][2]])
	(opts[0][1] as Callable).call()
	print("FT fire lit=%s near=%s wood left=%d" % [fire.lit(), BasePiece.near(get_tree(), "fire", p.global_position) != null, p.inv.count("wood")])
	var cu = main.craft_ui
	var rc: Dictionary = Items.RECIPES["boil_water"]
	var was := Settings.creative()
	print("FT boil water can=%s (creative %s)" % [cu._can(rc), was])
	var garden: BasePiece = main.base.spawn("garden", "wood", p.global_position + fwd * 2.0 + Vector3(3, 0, 0), 0.0)
	var go: Array = garden.menu(p)
	(go[0][1] as Callable).call()
	print("FT garden: %s -> now %s" % [go[0][0], garden.menu(p)[0][0]])
	var saved: Array = main.base.save_state()
	var st_ok := false
	for d in saved:
		if d.k == "garden" and d.st is Dictionary and float(d.st.get("planted", 0)) > 0: st_ok = true
	print("FT station state saved: %s" % st_ok)
	# ---- chop the nearest tree
	var veg = main.veg
	var best: CollisionShape3D = null
	var bd := 1e9
	for b in veg.find_children("*", "StaticBody3D", true, false):
		if not b.has_meta("trees"): continue
		for cs in b.get_children():
			if cs is CollisionShape3D and cs.has_meta("tree") and not cs.disabled:
				var dd: float = (cs as CollisionShape3D).global_position.distance_to(p.global_position)
				if dd < bd: bd = dd; best = cs
	if best:
		var r := ""
		var n := 0
		while r != "felled" and n < 10:
			r = veg.chop(best, "hatchet", p); n += 1
		print("FT chop: %s after %d hits, disabled=%s, felled saved=%d, with a bat: '%s'" % [r, n, best.disabled, veg.save_felled().size(), veg.chop(best, "bat", p)])
	else:
		print("FT no tree near")
	# ---- steering limit at speed
	if car:
		car._wb = 0.0
		car.driver = p
		car.linear_velocity = car.global_transform.basis.z * 25.0
		Input.action_press("move_left")
		for _i in 120: await get_tree().physics_frame
		print("FT steer at %.0f km/h: %.3f rad (was up to ~0.33 before)" % [car.linear_velocity.length() * 3.6, absf(car.steer_now)])
		Input.action_release("move_left")
		car.driver = null
	get_tree().quit()
