extends Node
## 0.2.75: MakeHuman people in a row, each in MH_LOOK clothes (or random), front and side. /tmp/shots/mh_*.png
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.8); env.ambient_light_energy = 0.7
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 25, 0); sun.shadow_enabled = true; add_child(sun)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 60); fl.mesh = pm; add_child(fl)
	var cam := Camera3D.new(); add_child(cam); cam.current = true; cam.fov = 35
	var keys := (OS.get_environment("MH_KEYS") if OS.get_environment("MH_KEYS") != "" else "mh_m_young,mh_m_mid,mh_m_old,mh_m_lean,mh_m_african,mh_m_asian,mh_f_young,mh_f_mid,mh_f_african,mh_f_asian,mh_f_old").split(",")
	var rng := RandomNumberGenerator.new(); rng.seed = int(OS.get_environment("MH_SEED")) if OS.get_environment("MH_SEED") != "" else 3
	var x := -(keys.size() - 1) * 0.5 * 0.85
	for k in keys:
		var r := Rig.new(); add_child(r); r.load_model(k)
		if OS.get_environment("MH_RAW") == "":
			var lk := Outfit.random_look(rng, Outfit.is_female(k), OS.get_environment("MH_ZOMBIE") != "")
			r.dress(lk)
			print("MH ", k, " ", lk.get("top"), " ", lk.get("bottom"), " ", lk.get("feet"))
			if OS.get_environment("MH_ZOMBIE") != "": r.tint(Color(0.74, 0.82, 0.68), 0.95)
		else:
			print("MH ", k, " bones ", r.skel.get_bone_count(), " ", r.skel.get_bone_name(0), " ", r.skel.find_bone("Hips"), " meshes ", r.model.find_children("*", "MeshInstance3D", true, false).map(func(m): return m.name))
		r.position = Vector3(x, 0, 0); x += 0.85
		r.play("Idle_8")
	for i in 10: await get_tree().process_frame
	var w := keys.size() * 0.85
	cam.look_at_from_position(Vector3(0, 1.0, w * 1.2 + 1.0), Vector3(0, 0.9, 0))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/mh_front.png")
	cam.look_at_from_position(Vector3(-w * 0.5 - 1.5, 1.2, 2.4), Vector3(-w * 0.5 + 1.2, 0.9, 0))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/mh_close.png")
	get_tree().quit()
