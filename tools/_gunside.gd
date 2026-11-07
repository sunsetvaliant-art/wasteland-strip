extends SceneTree
## Each gun side-on as the game holds it (muzzle to -Z = screen left), with its grips (red right hand, blue left),
## muzzle (yellow) and the sight line (green) drawn on
func _init():
	await process_frame
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55,0.58,0.62); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.8,0.8,0.8); w.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 60, 0); w.add_child(sun)
	var cam := Camera3D.new(); w.add_child(cam); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.current = true
	cam.cull_mask = 0xFFFFF
	for k in OS.get_environment("GUNS").split(","):
		var g := Gun.new(); w.add_child(g); g.setup(k, null); g.set_process(false)
		var L: float = float(g.def.len)
		cam.size = L * 1.25
		cam.position = Vector3(3.0, 0, 0); cam.look_at(Vector3.ZERO)
		var dot := func(p: Vector3, c: Color, r := 0.012):
			var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2; mi.mesh = sm
			var m := StandardMaterial3D.new(); m.albedo_color = c; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.no_depth_test = true; mi.material_override = m
			mi.position = p; g.add_child(mi)
		dot.call(g.muzzle.position, Color.YELLOW); dot.call(g.grip_r.position, Color.RED, 0.015); dot.call(g.grip_l.position, Color.BLUE, 0.015)
		for i in 21: dot.call(Vector3(0, g.sight_h, -L * 0.5 + L * i / 20.0), Color.GREEN, 0.004)
		dot.call(Vector3(0, g.sight_h, g.sight_rear_z), Color.MAGENTA, 0.01)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/claude-0/-home-claude/b0119dc3-e5bf-538e-a527-b04b73bbc85a/scratchpad/side_%s.png" % k)
		print("GUN ", k, " sight_h ", g.sight_h, " rear ", g.sight_rear_z)
		g.queue_free(); await process_frame
	quit()
