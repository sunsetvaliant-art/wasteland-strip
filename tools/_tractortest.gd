extends Node
## The tractor on flat ground (0.2.59): settles upright? drives? Run: godot --headless --path . res://tools/_tractortest.tscn
func _ready():
	await get_tree().process_frame
	var w := Node3D.new(); add_child(w)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(2000, 2, 2000); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); w.add_child(g)
	var d := VehicleSpecs.default_design("tractor")
	var c := Car.new(); c.design = d; w.add_child(c); c.position = Vector3(0, 1.5, 0)
	var dummy := StaticBody3D.new(); w.add_child(dummy)
	for i in 240:
		await get_tree().physics_frame
		if i % 40 == 0:
			var s := ""
			for wh in c.wheels: s += " [%s L%.2f N%.0f]" % ["c" if wh.contact else "-", float(wh.L), float(wh.N)]
			print("TR t%d pos %s up %.2f%s" % [i, c.global_position, c.global_transform.basis.y.y, s])
	c.driver = dummy
	c._shift(1); c._shift(1)
	Input.action_press("move_forward")
	for i in Engine.physics_ticks_per_second * 6:
		await get_tree().physics_frame
		if i % Engine.physics_ticks_per_second == 0:
			var s2 := ""
			for wh in c.wheels: s2 += " sr%.2f" % float(wh.sr)
			print("TR  t%.0f thr %.2f lim %.2f clutch %.2f rpm %d kmh %.1f running %s crank %.2f%s why '%s'" % [i / float(Engine.physics_ticks_per_second), c.throttle, c._thr_lim, c.clutch, c.rpm, c.speed_kmh(), c.running, c.crank, s2, CarCare.blocked(c)])
	Input.action_release("move_forward")
	print("TR drove: %.1f km/h gear %s rpm %d up %.2f com %s mass %.0f" % [c.speed_kmh(), c.gear_name(), c.rpm, c.global_transform.basis.y.y, c.center_of_mass, c.mass])
	get_tree().quit()
