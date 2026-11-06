extends SceneTree
## Every clip in CLIPS on every model in MODELS, side by side, posed CT seconds in. Checks retargeting by eye.
func _init():
	await process_frame
	var out := "/tmp/claude-0/-home-claude/b0119dc3-e5bf-538e-a527-b04b73bbc85a/scratchpad/"
	var clips := OS.get_environment("CLIPS").split(",")
	var models := OS.get_environment("MODELS").split(",") if OS.get_environment("MODELS") != "" else PackedStringArray(["player"])
	var ct := float(OS.get_environment("CT")) if OS.get_environment("CT") != "" else 0.4
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.62, 0.66, 0.72)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.6
	w.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); w.add_child(sun)
	var rigs := []
	for mi in models.size():
		for ci in clips.size():
			var r := Rig.new(); w.add_child(r); r.load_model(models[mi])
			r.position = Vector3(ci * 1.6, 0, mi * -2.0)
			r.rotation.y = -0.6
			r.anim.play("pool/" + clips[ci], 0.0)
			r.anim.seek(ct, true)
			r.anim.speed_scale = 0.0
			var l := Label3D.new(); l.text = clips[ci].get_slice("__", 1) if clips[ci].contains("__") else clips[ci]; l.font_size = 40; l.position = Vector3(0, 2.05, 0); l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; r.add_child(l)
			rigs.append(r)
	var cam := Camera3D.new(); w.add_child(cam); cam.current = true
	var cx := (clips.size() - 1) * 0.8
	cam.fov = 40; cam.position = Vector3(cx, 1.5 + models.size() * 0.5, 2.0 + clips.size() * 1.25 + models.size() * 0.6); cam.look_at(Vector3(cx, 0.9 - models.size() * 0.15, -models.size() * 0.8))
	for i in 6: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "clips.png")
	print("GAL ok")
	quit()
