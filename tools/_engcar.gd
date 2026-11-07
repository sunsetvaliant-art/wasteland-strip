extends SceneTree
## Each engine sat in a bare chassis (cab hidden), from the side and above, to check it's the right way round and sits right
func _init():
	await process_frame
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55,0.6,0.65); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.75,0.75,0.75); w.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); w.add_child(sun)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(400, 2, 400); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); w.add_child(g)
	var gm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); gm.mesh = pm; w.add_child(gm)
	var cam := Camera3D.new(); w.add_child(cam); cam.current = true
	for e in OS.get_environment("ENGS").split(","):
		var d := VehicleSpecs.default_design("vjwagon")
		d.engine = e
		var car := Car.new(); car.design = d; w.add_child(car); car.position = Vector3(0, 1.0, 0)
		for i in 90: await physics_frame
		if car.has_node("Cab"): car.get_node("Cab").visible = false
		var fz: float = d.axles[0].z
		for v in 2:
			if v == 0: cam.look_at_from_position(car.global_transform * Vector3(2.6, 1.0, fz - 0.4), car.global_transform * Vector3(0, 0.6, fz - 0.4))
			else: cam.look_at_from_position(car.global_transform * Vector3(1.6, 2.4, fz + 1.4), car.global_transform * Vector3(0, 0.5, fz - 0.6))
			for k in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/claude-0/-home-claude/b0119dc3-e5bf-538e-a527-b04b73bbc85a/scratchpad/ec_%s_%d.png" % [e, v])
		print("ENG ", e, " front axle z ", fz)
		car.queue_free(); await process_frame
	quit()
