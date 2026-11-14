extends SceneTree
## Headless drive test on a flat plane: settle, 0-100, top end in 3rd, brake, then a steady turn.
var car: Car
var t := 0.0
func _init():
	await process_frame
	var w := Node3D.new(); root.add_child(w)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(4000, 2, 4000); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); w.add_child(g)
	var kind := OS.get_environment("KIND") if OS.get_environment("KIND") != "" else "vjwagon"
	car = Car.new(); car.kind = kind; w.add_child(car); car.position = Vector3(0, 1.2, 0)
	var dummy := StaticBody3D.new(); w.add_child(dummy); car.driver = dummy
	print("TD ", kind, " engine ", car.eng.name, " box ", car.box.name, " mass ", car.mass)
	for i in 240: await physics_frame
	var s := ""
	for wh in car.wheels: s += "L=%.3f/%.2f N=%.0f  " % [wh.L, wh.T, wh.N]
	print("TD settled  y=%.3f  %s" % [car.global_position.y, s])
	if car.box.auto: car._shift(3)
	else: car.gear = 2
	Input.action_press("move_forward")
	var hit100 := -1.0
	for i in 120 * 30:
		await physics_frame
		t = i / 120.0
		if not car.box.auto and car.rpm > car.eng.redline * 0.96 and car.shift_t <= 0.0 and car.gear < car.box.ratios.size() + 1: car._shift(1)
		if hit100 < 0 and car.speed_kmh() >= 100.0: hit100 = t
		if i % 240 == 0: print("TD t=%4.1f  %5.1f km/h  %4d rpm  gear %s  slip %.2f  load %.2f" % [t, car.speed_kmh(), car.rpm, car.gear_name(), car.wheels[2].omega * car.wheels[2].r - car.wheels[2].vx, car.engine_load])
	print("TD 0-100 km/h: %.1f s   top after 30 s: %.0f km/h" % [hit100, car.speed_kmh()])
	Input.action_release("move_forward")
	Input.action_press("move_back")
	var v0: float = car.speed_kmh(); var tb := 0.0
	while car.speed_kmh() > 1.0 and tb < 20.0:
		await physics_frame; tb += 1.0 / 120.0
	print("TD braking %.0f -> 0 km/h in %.1f s, %.0f m" % [v0, tb, 0])
	Input.action_release("move_back")
	# steady 50 km/h, full lock left
	Input.action_press("move_forward")
	while car.speed_kmh() < 50.0: await physics_frame
	Input.action_release("move_forward")
	Input.action_press("move_left")
	var yaw0: float = car.rotation.y
	for i in 240: await physics_frame
	var vv: float = car.linear_velocity.length()
	print("TD turn: steer %.3f rad, front slip angle %.3f / %.3f rad, rear %.3f, lateral %.2f g" % [car.steer_now, car.wheels[0].slip_a, car.wheels[1].slip_a, car.wheels[2].slip_a, vv * absf(car.angular_velocity.y) / 9.81])
	print("TD turning at %.0f km/h: yaw rate %.2f rad/s, roll %.1f deg, still upright: %s" % [car.speed_kmh(), car.angular_velocity.y, rad_to_deg(car.rotation.z), car.global_transform.basis.y.y > 0.8])
	quit()
