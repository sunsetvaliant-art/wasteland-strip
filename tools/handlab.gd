extends SceneTree
## Hand lab: the player body holding each gun the way the game does it (WeaponHold), photographed from the eye
## (hip and sights), from the side and from in front. Fast to render, so grips can be tuned by eye.
## env: GUNS="slr,enfield,python" SET=rifle OUT=dir PITCH=-0.05 LOOKYAW=0
func _init():
	await process_frame
	var out := OS.get_environment("OUT")
	if out == "": out = "/tmp/claude-0/-home-claude/b0119dc3-e5bf-538e-a527-b04b73bbc85a/scratchpad/"
	var guns := OS.get_environment("GUNS").split(",") if OS.get_environment("GUNS") != "" else PackedStringArray(["slr", "enfield", "python"])
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.62, 0.66, 0.72)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.55
	w.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); sun.light_energy = 1.2; w.add_child(sun)
	var g0 := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(20, 20); g0.mesh = pm; w.add_child(g0)
	var body := Node3D.new(); w.add_child(body)
	var rig := Rig.new(); body.add_child(rig); rig.load_model(OS.get_environment("MODEL") if OS.get_environment("MODEL") != "" else "player")
	var cam := Camera3D.new(); w.add_child(cam); cam.current = true; cam.near = 0.02
	var dots := []
	for c in [Color.RED, Color.GREEN, Color.BLUE]:
		var d := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.04; sm.height = 0.08; d.mesh = sm
		var m := StandardMaterial3D.new(); m.albedo_color = c; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.no_depth_test = true; d.material_override = m
		w.add_child(d); dots.append(d)
	var pitch := float(OS.get_environment("PITCH")) if OS.get_environment("PITCH") != "" else -0.05
	var lyaw := float(OS.get_environment("LOOKYAW")) if OS.get_environment("LOOKYAW") != "" else 0.0
	var shots := []
	for gk in guns:
		var g := Gun.new(); w.add_child(g); g.setup(gk, null)
		var set_name := "unarmed" if g.def.get("pistol", false) else "rifle"
		for view in ["fp", "ads", "side", "front", "tp"]:
			var ads := 1.0 if view == "ads" else 0.0
			for i in 24:
				rig.locomote(set_name, 0.0, false, 0.0)
				rig.mods.look_yaw = lyaw
				rig.mods.look_pitch = pitch * 0.9
				var eye_pos := rig.head_position() + body.global_basis * Vector3(0, 0.07, -0.11)
				var look := body.global_basis * Basis(Vector3.UP, lyaw) * Basis(Vector3.RIGHT, pitch)
				var eye := Transform3D(look, eye_pos)
				g.global_transform = WeaponHold.place(g, eye, {"ads": ads})
				WeaponHold.hands(rig, g, body.global_basis)
				if OS.get_environment("NOIK") != "": rig.mods.ik.clear()
				if OS.get_environment("NOLOOK") != "": rig.mods.look_yaw = 0.0; rig.mods.look_pitch = 0.0
				match view:
					"fp", "ads":
						cam.global_transform = eye; cam.fov = 74 if view == "fp" else 60
						rig.hide_head(true)
					"side":
						rig.hide_head(false); cam.fov = 40
						cam.global_position = body.global_position + Vector3(2.4, 1.4, -0.5); cam.look_at(body.global_position + Vector3(0, 1.3, -0.35))
					"front":
						cam.global_position = body.global_position + Vector3(0.5, 1.5, -2.2); cam.look_at(body.global_position + Vector3(0, 1.3, -0.3))
					"tp":
						cam.global_position = body.global_position + Vector3(0.6, 1.75, 2.3); cam.look_at(body.global_position + Vector3(0.2, 1.45, -3.0))
				dots[0].global_position = rig.head_position(); dots[1].global_position = rig.bone_pos("Hips"); dots[2].global_position = rig.bone_pos("LeftHand")
				await process_frame
			print("LAB %s %s head %s eye-ish %s gun %s hips %s lhand %s anim %s" % [gk, view, rig.head_position(), rig.head_position() + Vector3(0, 0.07, -0.11), g.global_position, rig.bone_pos("Hips"), rig.bone_pos("LeftHand"), rig.anim.current_animation])
			var img := root.get_viewport().get_texture().get_image()
			img.resize(480, 270)
			shots.append(img)
		g.queue_free()
	var cols := 5
	var grid := Image.create(480 * cols, 270 * guns.size(), false, Image.FORMAT_RGBA8)
	for i in shots.size():
		grid.blit_rect(shots[i], Rect2i(0, 0, 480, 270), Vector2i((i % cols) * 480, (i / cols) * 270))
	grid.save_png(out + "handlab.png")
	print("LAB saved")
	quit()
