extends SceneTree
## Thumbnails of loose GLB files (loaded at run time, no import): front and three-quarter views
func _init() -> void:
	await process_frame
	var root := Node3D.new(); get_root().add_child(root)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.5, 0.56, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.7, 0.7, 0.7)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -30, 0); root.add_child(sun)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true
	for f in OS.get_environment("FILES").split(","):
		var doc := GLTFDocument.new(); var st := GLTFState.new()
		if doc.append_from_file(f, st) != OK: print("THUMB fail ", f); continue
		var n: Node3D = doc.generate_scene(st)
		root.add_child(n)
		var bb := AABB(); var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bb = b if first else bb.merge(b); first = false
		var c := bb.get_center(); var r := bb.size.length()
		for v in 2:
			var dir := Vector3(0, 0.25, 1).normalized() if v == 0 else Vector3(1, 0.5, 1).normalized()
			cam.look_at_from_position(c + dir * r * 1.1, c, Vector3.UP)
			for k in 3: await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("/tmp/claude-0/meshy/th_%s_%d.png" % [f.get_file().get_basename(), v])
		print("THUMB ", f.get_file(), " size ", bb.size)
		n.queue_free()
		await process_frame
	quit()
