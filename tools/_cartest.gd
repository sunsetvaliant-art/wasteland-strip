extends SceneTree
## Launch test: rear diff open / locked, full throttle from a standstill on bitumen; prints each rear wheel's spin
var car: Car
func _init():
	await process_frame
	var diff := OS.get_environment("DIFF") if OS.get_environment("DIFF") != "" else "locked"
	var w := Node3D.new(); root.add_child(w)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(4000, 2, 4000); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); w.add_child(g)
	var d := VehicleSpecs.default_design("vjwagon")
	for a in d.axles:
		if a.drive: a.diff = diff
	car = Car.new(); car.design = d; w.add_child(car); car.position = Vector3(0, 1.2, 0)
	var dummy := StaticBody3D.new(); w.add_child(dummy); car.driver = dummy
	for i in 240: await physics_frame
	if car.box.auto: car._shift(3)
	Input.action_press("move_forward")
	for i in 120 * 4:
		await physics_frame
		if i % 12 == 0:
			var s := ""
			for wh in car.wheels:
				if wh.a.drive: s += "  om %5.1f slip %4.1f N %5.0f" % [wh.omega, wh.slipv, wh.N]
			print("CT %s t=%.1f %5.1f km/h gear %s rpm %d%s" % [diff, i / 120.0, car.speed_kmh(), car.gear_name(), car.rpm, s])
	Input.action_release("move_forward")
	# parked on a slope: driver out, tilt the ground
	car.driver = null
	for i in 600: await physics_frame
	var p0 := car.global_position
	g.rotation_degrees.x = 8.0
	for i in 120 * 10:
		await physics_frame
		if i % 120 == 0:
			var oc := 0
			for wh in car.wheels: if wh.contact: oc += 1
			print("CT  park ", car._park_at, " v ", car.linear_velocity.length(), " contact ", oc, " pos ", car.global_position, " sleeping ", car.sleeping, " freeze ", car.freeze)
	print("CT parked creep on 8 deg over 10 s: %.3f m" % (car.global_position - p0).length())
	quit()
