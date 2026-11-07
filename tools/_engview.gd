extends SceneTree
## Engines from above and from the side, red rod = +X, blue rod = +Z, to see which way the crank runs and the front faces
func _init() -> void:
	await process_frame
	var root := Node3D.new(); get_root().add_child(root)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.5, 0.56, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.75, 0.75, 0.75)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-60, -30, 0); root.add_child(sun)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true; cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.2
	for ax in [[Vector3.RIGHT, Color.RED], [Vector3.BACK, Color.BLUE]]:
		var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.02; cm.bottom_radius = 0.02; cm.height = 1.0; mi.mesh = cm
		var m := StandardMaterial3D.new(); m.albedo_color = ax[1]; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mi.material_override = m
		var d: Vector3 = ax[0]; mi.position = d * 0.5 + Vector3(0, 0.02, 0)
		if d == Vector3.RIGHT: mi.rotation_degrees.z = 90
		else: mi.rotation_degrees.x = 90
		root.add_child(mi)
	for f in OS.get_environment("FILES").split(","):
		var n: Node3D = (load(f) as PackedScene).instantiate()
		root.add_child(n)
		for v in 2:
			if v == 0: cam.look_at_from_position(Vector3(0, 5, 0.001), Vector3.ZERO, Vector3.FORWARD)
			else: cam.look_at_from_position(Vector3(5, 0.4, 0.001) * float(OS.get_environment("SIDE") if OS.get_environment("SIDE") != "" else "0") + Vector3(0.001, 0.4, 5) * (1.0 - abs(float(OS.get_environment("SIDE") if OS.get_environment("SIDE") != "" else "0"))), Vector3(0, 0.4, 0), Vector3.UP)
			for k in 3: await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("/tmp/claude-0/meshy/ev_%s_%d.png" % [f.get_file().get_basename(), v])
		n.queue_free(); await process_frame
	quit()
