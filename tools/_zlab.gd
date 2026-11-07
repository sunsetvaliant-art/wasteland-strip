extends SceneTree
## Pose sheet: four zombie bodies side by side playing one clip, a few frames each, for checking retargets
func _init() -> void:
	await process_frame
	var root := Node3D.new(); get_root().add_child(root)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.6, 0.6, 0.6)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -30, 0); root.add_child(sun)
	var gp := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(20, 20); gp.mesh = pm; root.add_child(gp)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true
	cam.look_at_from_position(Vector3(1.0, 1.2, 3.2), Vector3(1.0, 0.85, -0.3), Vector3.UP)
	var bodies := ["zombie_hollow", "zombie_mx", "zombie_female", "zombie_hazmat"]
	var rigs := []
	for i in bodies.size():
		var r := Rig.new(); root.add_child(r); r.load_model(bodies[i])
		r.position = Vector3(i * 1.1 - 0.4, 0, -i * 0.3); r.rotation.y = -0.9
		rigs.append(r)
	var clips := OS.get_environment("CLIPS").split(",")
	for c in clips:
		for fr in 3:
			for r in rigs:
				r.anim.play("pool/" + c, 0.0); r.anim.seek(r.anim.current_animation_length * (0.15 + 0.3 * fr), true)
			for k in 3: await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("/tmp/claude-0/zlab/%s_%d.png" % [c, fr])
		print("ZLAB ", c)
	quit()
