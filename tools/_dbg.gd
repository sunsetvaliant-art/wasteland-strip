extends SceneTree
func _init():
	await process_frame
	var w := Node3D.new(); root.add_child(w)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(4000, 2, 4000); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); w.add_child(g)
	var car := Car.new(); w.add_child(car); car.position = Vector3(0, 1.2, 0)
	var dummy := StaticBody3D.new(); w.add_child(dummy); car.driver = dummy
	for i in 120: await physics_frame
	car._shift(3)
	Input.action_press("move_forward")
	for i in 400:
		await physics_frame
		if i % 40 == 0:
			print("DB i=%d gear=%s shift_t=%.2f clutch=%.2f R=%.2f rpm=%d thr=%.2f w_rear=%.1f N=%.0f fx=%.0f drive_t=%.0f" % [i, car.gear_name(), car.shift_t, car.clutch, car.ratio(), car.rpm, car.throttle, car.wheels[2].omega, car.wheels[2].N, car.wheels[2].fx, car.wheels[2].drive_t])
	quit()
