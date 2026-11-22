extends Node
## Look at staged downloads without importing them (0.2.63): loads each .glb at run time, frames it by its bounds,
## shoots a 3/4 front and a close side view through the windows. TODL_FILES="a.glb,b.glb" TODL_OUT=/tmp/shots/todl_
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.62, 0.7, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.85, 0.85, 0.85); env.ambient_light_energy = 0.9
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); sun.light_energy = 1.2; add_child(sun)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 60); fl.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.4, 0.4, 0.38); fl.material_override = fm; add_child(fl)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 40; cam.current = true
	var out := OS.get_environment("TODL_OUT")
	for f in OS.get_environment("TODL_FILES").split(","):
		var doc := GLTFDocument.new(); var st := GLTFState.new()
		if doc.append_from_file(f, st) != OK: print("TODL fail ", f); continue
		var n: Node3D = doc.generate_scene(st)
		add_child(n)
		var ab := AABB(); var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			ab = b if first else ab.merge(b); first = false
		# long side along whichever of x/z is longer; sit it on the floor at the origin
		var long_x := ab.size.x > ab.size.z
		n.position -= Vector3(ab.get_center().x, ab.position.y, ab.get_center().z)
		var L := maxf(ab.size.x, ab.size.z); var H := maxf(ab.size.y, L * 0.3)
		var fwd := Vector3(1, 0, 0) if long_x else Vector3(0, 0, 1)
		var side := Vector3(0, 0, 1) if long_x else Vector3(1, 0, 0)
		var nm := f.get_file().get_basename()
		print("TODL ", nm, " size ", snapped(ab.size, Vector3(0.01, 0.01, 0.01)))
		var views := [[fwd * L * 0.75 + side * L * 0.75 + Vector3.UP * H * 0.9, Vector3.UP * H * 0.45, 40.0],
			[side * L * 0.55 + Vector3.UP * H * 0.62, Vector3.UP * H * 0.6 - side * L * 0.1, 40.0],
			[-fwd * L * 0.8 - side * L * 0.6 + Vector3.UP * H * 1.0, Vector3.UP * H * 0.45, 40.0]]
		for vi in views.size():
			cam.global_position = views[vi][0]; cam.look_at(views[vi][1]); cam.fov = views[vi][2]
			for k in 4: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s%s_%d.png" % [out, nm, vi])
		n.queue_free()
		await get_tree().process_frame
	print("TODL_DONE")
	get_tree().quit()
