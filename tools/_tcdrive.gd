extends Node
## Headless: drive a car from the street down the Twin City ramp into the car park. Was: the v2 Twin City in the world: floor, travelators down, the car park, the car ramp, the stairs up to
## the cinema. Walks a player down each travelator and up the stairs, drives nothing (rays for the ramp).
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	for _i in 60: await get_tree().physics_frame
	var B = Buildings.inst
	var li := -1
	for i in B.lots.size():
		if B.lots[i].size() > 7 and str(B.lots[i][7]) == "TWIN CITY": li = i
	var l: Array = B.lots[li]
	var p: Player = main.player
	Settings.set_value("god_mode", true)
	p.global_position = Vector3(float(l[1]), main.height_at(float(l[1]), float(l[2])) + 3.0, float(l[2]))
	var waited := 0
	while not B.full.has(li) and waited < 3000:
		await get_tree().physics_frame; waited += 1
	for _i in 300: await get_tree().physics_frame
	var node: Node3D = B.full[li]
	var xf := node.global_transform
	var dt := PolyMall.data("twin_city")
	var space := p.get_world_3d().direct_space_state
	var down := func(lp: Vector2, from_y: float) -> float:
		var top := xf * Vector3(lp.x, from_y, lp.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -12, 0), 1))
		return hit.position.y - xf.origin.y if not hit.is_empty() else -99.0
	print("T2 built after %d frames, floor y %.2f" % [waited, xf.origin.y])
	var rp: Dictionary = dt.ramp
	var door := Vector2(rp.door[0], rp.door[1]); var rt := Vector2(rp.top[0], rp.top[1]); var rb := Vector2(rp.bottom[0], rp.bottom[1])
	var out := (door - rt).normalized()
	if out.length() < 0.1: out = (rt - rb).normalized()
	print("TD ramp door %s top %s bottom %s out %s; surface door %.2f, 10 m out %.2f, 20 m out %.2f" % [door, rt, rb, out, down.call(door, 3.0), down.call(door + out * 10.0, 6.0), down.call(door + out * 20.0, 6.0)])
	for xx in [118.0, 116.0, 114.0, 113.0, 112.0, 111.0, 110.0, 108.0, 106.0, 104.0]:
		var row := []
		for zz in [-3.0, -1.5, 0.0, 1.5, 3.0]:
			var top := xf * Vector3(xx, 3.0, door.y + zz)
			var hh := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -12, 0), 0xFFFFFFFF))
			row.append("%s:%s" % [str(snappedf(hh.position.y - xf.origin.y, 0.01)) if not hh.is_empty() else "-", (str(hh.collider.name).left(8) if not hh.is_empty() else "")])
		print("TD x %.0f  %s" % [xx, "  ".join(row)])
	# what's along the way in, at car height
	for k in range(-24, 1, 2):
		var a := xf * Vector3(door.x + out.x * -k, 1.0, door.y + out.y * -k)
		var b := xf * Vector3(door.x + out.x * (-k - 2), 1.0, door.y + out.y * (-k - 2))
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))
		if not h.is_empty(): print("TD blocked at %d m out: %s @ %s" % [-k, h.collider.name, (xf.affine_inverse() * h.position).snapped(Vector3.ONE * 0.1)])
	var car: Car = null
	for c in get_tree().get_nodes_in_group("vehicles"):
		if c is Car: car = c; break
	var start := door + out * 18.0
	car.global_position = xf * Vector3(start.x, down.call(start, 6.0) + 1.0, start.y)
	car.global_rotation = Vector3(0, atan2(-out.x * xf.basis.x.x - out.y * xf.basis.z.x, -out.x * xf.basis.x.z - out.y * xf.basis.z.z), 0)
	car.linear_velocity = Vector3.ZERO
	p.global_position = car.global_position + Vector3(2.5, 0, 0)
	for _i in 10: await get_tree().physics_frame
	p._try_get_in(car)
	for _i in 30: await get_tree().physics_frame
	car.gear = 3 if car.box.auto else 2
	print("TD in the car: %s, gearbox auto %s, gear %s" % [car.driver == p, car.box.auto, car.gear_name()])
	var path := [door, rt, rb, rb + (rb - rt).normalized() * 8.0]
	var wi := 0
	for f in 1500:
		var lp: Vector3 = xf.affine_inverse() * car.global_position
		var tgt: Vector2 = path[wi]
		if Vector2(lp.x, lp.z).distance_to(tgt) < 3.0:
			wi += 1
			if wi >= path.size(): break
			tgt = path[wi]
		var fwd3: Vector3 = xf.basis.inverse() * car.global_transform.basis.z
		var to := (tgt - Vector2(lp.x, lp.z)).normalized()
		var side := Vector2(fwd3.x, fwd3.z).normalized().cross(to)
		Input.action_release("move_left"); Input.action_release("move_right")
		if side > 0.08: Input.action_press("move_left")
		elif side < -0.08: Input.action_press("move_right")
		if car.linear_velocity.length() < 4.0: Input.action_press("move_forward")
		else: Input.action_release("move_forward")
		if f % 90 == 0: print("TD f%d car local %s speed %.1f wp %d" % [f, lp.snapped(Vector3.ONE * 0.1), car.linear_velocity.length(), wi])
		await get_tree().physics_frame
	Input.action_release("move_forward"); Input.action_release("move_left"); Input.action_release("move_right")
	var lp2: Vector3 = xf.affine_inverse() * car.global_position
	print("TD end: car at %s (car park floor is y -4), reached waypoint %d of %d" % [lp2.snapped(Vector3.ONE * 0.1), wi, path.size()])
	get_tree().quit()
