extends SceneTree
## A mall on its own: from the street, the car park, the ramp, the concourse, the supermarket, and cut-away plans.
##   W=90 D=92 SEED=1 godot --path . -s tools/_malllab.gd      (CUT=1 [UPPER=1] for a plan)
const OUT := "/tmp/claude-0/mall/"

func _init() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var root := Node3D.new(); get_root().add_child(root)
	var env := Environment.new()
	var sky := Sky.new(); var psm := ProceduralSkyMaterial.new(); sky.sky_material = psm
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_sky_contribution = 0.6; env.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -140, 0); sun.shadow_enabled = true; sun.light_energy = 1.3
	sun.directional_shadow_max_distance = 200; root.add_child(sun)
	var gnd := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(400, 400); gnd.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.36, 0.4, 0.3); gnd.material_override = gm; gnd.position.y = -0.02; root.add_child(gnd)
	var cam := Camera3D.new(); cam.fov = 70; root.add_child(cam); cam.current = true; cam.far = 800
	var w := float(OS.get_environment("W")) if OS.get_environment("W") != "" else 97.58
	var d := float(OS.get_environment("D")) if OS.get_environment("D") != "" else 94.28
	var seed := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	var cut := OS.get_environment("CUT") != ""
	var nm := OS.get_environment("NAME") if OS.get_environment("NAME") != "" else "SUNNYVALE"
	var p := BuildGen.plan("mall", w, d, seed, nm)
	if cut:
		p["cut"] = 2.2
		p["cut_floor"] = 0 if OS.get_environment("UPPER") == "" else 1
	var t0 := Time.get_ticks_msec()
	var ground := func(_x: float, _z: float) -> float: return -float(p.raised)
	var b := BuildGen.build(p, ground)
	root.add_child(b)
	var r2 := RandomNumberGenerator.new(); r2.seed = int(p.seed)
	var boxes := BuildProps.furnish(p, b, r2)
	print("BUILT mall ", Time.get_ticks_msec() - t0, " ms, containers ", boxes.size(), " rollers ", p._rollers.size(), " windows ", p._windows.size(), " doors ", b.find_children("*", "BuildDoor", true, false).size())
	for f in p.floors:
		var ne := 0
		var shut := 0
		for r in f.rooms:
			var any := false
			for side in ["N", "S", "W", "E"]:
				for op in r.ops[side]:
					if op.kind in ["open", "door", "doorx", "roller"] and float(op.y0) < 0.3: any = true
					if r.type == "concourse" and op.get("ext", false) and op.kind == "open": ne += 1
			if not any and r.type != "void": shut += 1
		print("CHECK floor ", f.y, " rooms ", f.rooms.size(), " mall entrances ", ne, " rooms with no way in ", shut)
	for f in p.floors:
		print("FLOOR y=", f.y, " ", f.rooms.map(func(r): return "%s[%.0f..%.0f x %.0f..%.0f]" % [r.type, r.x0, r.x1, r.z0, r.z1]))
	
	for _k in 60:
		BuildProps.work(300000)
		await process_frame
	var hw := w / 2
	var hd := d / 2
	if cut:
		cam.look_at_from_position(Vector3(0.01, maxf(w, d) * 1.08, 1), Vector3(0, 0, 0), Vector3.UP)
		await _shot("plan" + ("_up" if OS.get_environment("UPPER") != "" else ""))
		quit()
		return
	if not p.has("ramp"):
		var P := func(px: float, py: float, y: float) -> Vector3: return Vector3((px - 1303.5) * 0.452, y, (py - 637.5) * 0.452)
		var sh := [
			["tc_air", Vector3(-hw - 60, 150, hd + 160), Vector3(0, 0, 0)],
			["tc_front", P.call(1230, 1010, 2.0), P.call(1230, 900, 4.0)],
			["tc_mall", P.call(880, 516, 1.7), P.call(1590, 516, 2.0)],
			["tc_mall2", P.call(1230, 920, 1.7), P.call(1230, 640, 2.5)],
			["tc_food", P.call(1105, 598, 1.8), P.call(1020, 532, 1.0)],
			["tc_cine_lobby", P.call(1372, 620, 1.7), P.call(1420, 578, 1.5)],
			["tc_cinema", P.call(1437, 636, 3.6), P.call(1437, 584, 3.0)],
			["tc_bigmart", P.call(1018, 620, 1.8), P.call(862, 865, 1.0)],
			["tc_super", P.call(1380, 460, 1.8), P.call(1560, 340, 1.0)],
		]
		for s2 in sh:
			cam.look_at_from_position(s2[1], s2[2], Vector3.UP)
			await _shot(s2[0])
			print("DRAWS ", s2[0], " ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		quit()
		return
	var rp: Dictionary = p.ramp
	var shots := [
		["street", Vector3(10, 2.0, hd + 30), Vector3(15, 5, hd)],
		["air", Vector3(hw + 45, 60, hd + 55), Vector3(0, 0, 0)],
		["air2", Vector3(-hw - 45, 60, -hd - 55), Vector3(0, 0, 0)],
		["carpark", Vector3(-hw + 3, 1.7, -hd + 14), Vector3(hw, 1.2, -6)],
		["lobby", Vector3(hw - 47.0, 1.7, hd + 3), Vector3(float(rp.xc), 1.5, float(rp.zt))],
		["ramp_foot", Vector3(float(rp.xa), 1.7, float(rp.zt) - 3.0), Vector3(float(rp.xa), 2.0, float(rp.zh))],
		["ramp_top", Vector3(float(rp.xb), 5.6, float(rp.zh) - 2.0), Vector3(float(rp.xb), 4.5, float(rp.zt) - 3)],
		["arm_s", Vector3(hw - 3, MallGen.UY + 1.7, float(rp.zt) - 3.5), Vector3(-hw, MallGen.UY + 1.5, float(rp.zt) - 3.5)],
		["arm_s2", Vector3(hw - 76, MallGen.UY + 1.7, float(rp.zt) - 3.5), Vector3(hw, MallGen.UY + 1.5, float(rp.zt) - 3.5)],
		["arm_n", Vector3(hw - 18, MallGen.UY + 1.7, hd - 15.5), Vector3(-hw, MallGen.UY + 1.5, hd - 15.5)],
		["well", Vector3(hw - 20, MallGen.UY + 1.7, hd - 22), Vector3(float(rp.xc), MallGen.UY - 1.0, float(rp.zh))],
	]
	for r in p.floors[1].rooms:
		if r.type == "super":
			shots.append(["super", Vector3(float(r.x1) - 2, MallGen.UY + 1.8, float(r.z1) - 2), Vector3(float(r.x0), MallGen.UY + 0.8, float(r.z0))])
	for s in shots:
		cam.look_at_from_position(s[1], s[2], Vector3.UP)
		await _shot(s[0])
		print("DRAWS ", s[0], " ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " objs ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	quit()

func ShopGenUY() -> float:
	return MallGen.UY

func _shot(name: String) -> void:
	for k in 4: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OUT + name + ".png")
