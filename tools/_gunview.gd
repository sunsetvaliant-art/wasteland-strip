extends SceneTree
## renders each gun, normalised, against axis rods (red +X, green +Y, blue +Z), from an oblique camera
func _init():
	await process_frame
	var out := "/tmp/claude-0/-home-claude/b0119dc3-e5bf-538e-a527-b04b73bbc85a/scratchpad/"
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.5,0.5,0.55); env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.6; env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; w.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); w.add_child(sun)
	var cam := Camera3D.new(); w.add_child(cam); cam.position = Vector3(0.0, 0.0, 1.0); cam.fov = 60; cam.current = true
	for ax in [[Vector3.RIGHT, Color.RED], [Vector3.UP, Color.GREEN], [Vector3.BACK, Color.BLUE]]:
		var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.01; cm.bottom_radius = 0.01; cm.height = 0.7; mi.mesh = cm
		var m := StandardMaterial3D.new(); m.albedo_color = ax[1]; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mi.material_override = m
		var d: Vector3 = ax[0]; mi.position = d * 0.35
		if d == Vector3.RIGHT: mi.rotation_degrees.z = 90
		elif d == Vector3.BACK: mi.rotation_degrees.x = 90
		w.add_child(mi)
	for g in ["python"]:
		var n: Node3D = load("res://assets/guns/%s/scene.gltf" % g).instantiate()
		var h := Node3D.new(); w.add_child(h); h.add_child(n)
		await process_frame
		var bb := AABB(); var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.global_transform * mi.get_aabb()
			bb = b if first else bb.merge(b); first = false
		var s: float = 1.0 / max(bb.size.x, max(bb.size.y, bb.size.z))
		# long axis -> screen X (so +X of the gun's long axis points right), then show it from the side and from above
		var L := bb.size; var ax := 0 if (L.x >= L.y and L.x >= L.z) else (1 if L.y >= L.z else 2)
		var b := Basis()
		if ax == 1: b = Basis(Vector3.BACK, PI * 0.5)       # y -> -x... rotate so y maps along x
		elif ax == 2: b = Basis(Vector3.UP, -PI * 0.5)      # z -> x
		h.basis = b.scaled(Vector3.ONE * s); h.position = -(h.basis * bb.get_center())
		print("GUN ", g, " long axis ", ax)
		print("GUN ", g, " aabb ", bb)
		for i in 4: await process_frame
		root.get_viewport().get_texture().get_image().save_png(out + "gun_" + g + "_a.png")
		cam.position = Vector3(0, 1.0, 0.001); cam.look_at(Vector3.ZERO, Vector3.FORWARD)
		for i in 4: await process_frame
		root.get_viewport().get_texture().get_image().save_png(out + "gun_" + g + "_b.png")
		cam.position = Vector3(0, 0, 1.0); cam.rotation = Vector3.ZERO
		h.queue_free()
	quit()
