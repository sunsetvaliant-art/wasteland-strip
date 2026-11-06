extends SceneTree
func _init():
	await process_frame
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55, 0.65, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.6; w.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); w.add_child(sun)
	var g0 := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(2000, 2000); g0.mesh = pm; w.add_child(g0)
	for i in 12:
		var b := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1, 2, 1); b.mesh = bm
		var m := StandardMaterial3D.new(); m.albedo_color = Color.from_hsv(i / 12.0, 0.7, 0.9); b.material_override = m
		b.position = Vector3((i - 6) * 3.0, 1, -60 - i * 10); w.add_child(b)
	var cam := Camera3D.new(); w.add_child(cam); cam.current = true; cam.position = Vector3(0, 1.6, 0); cam.fov = 70
	var g := Gun.new(); w.add_child(g); g.setup("enfield", null)
	var eye := Transform3D(Basis(), Vector3(0, 1.6, 0))
	g.global_transform = WeaponHold.place(g, eye, {"ads": 1.0})
	var cl := CanvasLayer.new(); root.add_child(cl)
	var sv := ScopeView.new(); cl.add_child(sv)
	for i in 30:
		sv.set_active(true, g, eye.basis, eye.origin)
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-claude/b0119dc3-e5bf-538e-a527-b04b73bbc85a/scratchpad/scopelab.png")
	print("SCOPE ok fov ", sv.cam.fov)
	quit()
