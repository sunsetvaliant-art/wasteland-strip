extends Node
## 0.2.75: a lineup of dressed people: each model in DRESS_KEYS (default: all the human ones) in a random outfit,
## front and back. /tmp/shots/dress_front.png, dress_back.png. DRESS_SEED picks the outfits.
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.8); env.ambient_light_energy = 0.8
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 25, 0); add_child(sun)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 60); fl.mesh = pm; add_child(fl)
	var cam := Camera3D.new(); add_child(cam); cam.current = true; cam.fov = 35
	var keys := (OS.get_environment("DRESS_KEYS") if OS.get_environment("DRESS_KEYS") != "" else "player,survivor_female,scav_2,scav_hooded,zombie_hollow,zombie_mx,zombie_fuse,zombie_female").split(",")
	var rng := RandomNumberGenerator.new(); rng.seed = int(OS.get_environment("DRESS_SEED")) if OS.get_environment("DRESS_SEED") != "" else 7
	var rigs := []
	var x := -(keys.size() - 1) * 0.5 * 0.9
	var t0 := Time.get_ticks_msec()
	for k in keys:
		var r := Rig.new(); add_child(r); r.load_model(k)
		var zb: bool = k.begins_with("zombie") or OS.get_environment("DRESS_ZOMBIE") != ""
		var lk := Outfit.random_look(rng, k in Outfit.FEMALE, zb)
		if k == "player" and OS.get_environment("DRESS_SEED") == "": lk.merge({"top": "shirt_flanno", "top_c": Outfit.LOOKS.shirt_flanno.pal[0], "bottom": "pants_jeans", "bottom_c": Outfit.LOOKS.pants_jeans.pal[0], "feet": "boots_work", "feet_c": Outfit.LOOKS.boots_work.pal[0]}, true)
		var t1 := Time.get_ticks_msec()
		r.dress(lk)
		if zb: r.tint(Color(0.74, 0.82, 0.68) if not k.begins_with("zombie") else Color(0.92, 0.95, 0.9), 0.95)
		print("DRESS ", k, " ", lk.top, " ", lk.bottom, " ", lk.feet, " in ", Time.get_ticks_msec() - t1, " ms, skin ", Outfit.skin_of(r.model_path))
		r.position = Vector3(x, 0, 0); x += 0.9
		r.play("Idle_8")
		rigs.append(r)
	for i in 10: await get_tree().process_frame
	var w := keys.size() * 0.9
	cam.look_at_from_position(Vector3(0, 1.0, w * 1.25 + 1.0), Vector3(0, 0.9, 0))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/dress_front.png")
	cam.look_at_from_position(Vector3(0, 1.0, -(w * 1.25 + 1.0)), Vector3(0, 0.9, 0))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/dress_back.png")
	get_tree().quit()
