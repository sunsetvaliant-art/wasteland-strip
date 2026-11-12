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
	var w := float(OS.get_environment("W")) if OS.get_environment("W") != "" else 90.0
	var d := float(OS.get_environment("D")) if OS.get_environment("D") != "" else 92.0
	var seed := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	var cut := OS.get_environment("CUT") != ""
	var p := BuildGen.plan("mall", w, d, seed, "SUNNYVALE")
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
		print("FLOOR y=", f.y, " ", f.rooms.map(func(r): return "%s[%.0f..%.0f x %.0f..%.0f]" % [r.type, r.x0, r.x1, r.z0, r.z1]))
	print("RAMP ", p.ramp)
	for _k in 60:
		BuildProps.work(300000)
		await process_frame
	var hw := w / 2
	var hd := d / 2
	if cut:
		cam.look_at_from_position(Vector3(0.01, 95, 1), Vector3(0, 0, 0), Vector3.UP)
		await _shot("plan" + ("_up" if OS.get_environment("UPPER") != "" else ""))
		quit()
		return
	var rp: Dictionary = p.ramp
	var shots := [
		["street", Vector3(-15, 2.0, hd + 30), Vector3(5, 5, hd)],
		["air", Vector3(-hw - 40, 45, hd + 50), Vector3(0, 0, 0)],
		["carpark", Vector3(-hw + 3, 1.7, -hd + 14), Vector3(hw, 1.2, -6)],
		["lobby", Vector3((float(rp.xa) + float(rp.xb)) / 2, 1.7, hd - 2), Vector3((float(rp.xa) + float(rp.xb)) / 2, 2.5, float(rp.zt))],
		["ramp_foot", Vector3(float(rp.xa), 1.7, float(rp.za) - 2.5), Vector3(float(rp.xa), 2.0, float(rp.zh))],
		["ramp_turn", Vector3(float(rp.xa), 3.0, float(rp.zh) - 4.0), Vector3(float(rp.xc), 3.0, float(rp.zh) + float(rp.r))],
		["ramp_top", Vector3(float(rp.xb), 5.6, float(rp.zh) - 2.0), Vector3(float(rp.xb), 4.5, float(rp.zt) - 3)],
		["concourse", Vector3(-hw + 3, ShopGenUY() + 1.7, 0), Vector3(hw, ShopGenUY() + 1.5, 0)],
		["concourse2", Vector3(hw - 3, ShopGenUY() + 1.7, 2), Vector3(-hw, ShopGenUY() + 1.5, -1)],
	]
	for r in p.floors[1].rooms:
		if r.type == "super":
			shots.append(["super", Vector3(float(r.x1) - 2, ShopGenUY() + 1.8, float(r.z1) - 2), Vector3(float(r.x0), ShopGenUY() + 0.8, float(r.z0))])
		if r.type == "foodcourt":
			shots.append(["foodcourt", Vector3(float(r.x0) + 1, ShopGenUY() + 1.8, float(r.z0) + 1), Vector3(float(r.x1), ShopGenUY() + 0.8, float(r.z1))])
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
