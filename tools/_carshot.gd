extends Node
## New bodies on flat ground, settled: 3/4 front, side, 3/4 rear (0.2.64). SHOT_CARS="a,b" -> /tmp/shots/car_<key>_N.png
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.62, 0.7, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.85, 0.85, 0.85); env.ambient_light_energy = 0.9
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); sun.light_energy = 1.2; add_child(sun)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(200, 2, 200); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); fl.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.4, 0.4, 0.38); fl.material_override = fm; add_child(fl)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 40; cam.current = true
	for key in OS.get_environment("SHOT_CARS").split(","):
		var c := Car.new(); c.design = VehicleSpecs.default_design(key); c.position = Vector3(0, 1.2, 0); add_child(c)
		for i in 150: await get_tree().physics_frame
		var t := c.global_transform
		var views := [Vector3(3.6, 1.6, 4.4), Vector3(4.2, 1.1, 0.0), Vector3(-3.4, 2.0, -4.6)]
		for vi in views.size():
			cam.global_position = t * views[vi]; cam.look_at(t * Vector3(0, 0.55, 0))
			for k in 4: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/shots/car_%s_%d.png" % [key, vi])
		# from the driver's seat (cab view)
		cam.global_transform = c.cam_cab.global_transform; cam.fov = 70
		for k in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/shots/car_%s_cab.png" % key)
		cam.fov = 40
		print("CAR ", key, " pos ", snapped(c.global_position, Vector3(0.01, 0.01, 0.01)), " up ", snapped(c.global_transform.basis.y, Vector3(0.01, 0.01, 0.01)))
		c.queue_free()
		await get_tree().process_frame
	print("CAR_DONE")
	get_tree().quit()
