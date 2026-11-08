extends SceneTree
## A row of generated shops along a footpath: from across the street, down the footpath under the awnings, the
## upstairs, a cut-away plan, and inside.
##   SEED=3 N=6 godot --path . -s tools/_shoplab.gd
const OUT := "/tmp/claude-0/shops/"
var slope := 0.02

func gh(x: float, z: float) -> float:
	return x * slope

func _init() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var root := Node3D.new(); get_root().add_child(root)
	var env := Environment.new()
	var sky := Sky.new(); var psm := ProceduralSkyMaterial.new(); sky.sky_material = psm
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_sky_contribution = 0.5; env.ambient_light_color = Color(0.58, 0.6, 0.58)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.ssao_enabled = true
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, -150, 0); sun.shadow_enabled = true; sun.light_energy = 1.35
	sun.directional_shadow_max_distance = 120; root.add_child(sun)
	# ground: footpath strip and a road
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(-60, 60, 2):
		for k in range(-40, 40, 2):
			var q := [Vector3(i, gh(i, k), k), Vector3(i + 2, gh(i + 2, k), k), Vector3(i + 2, gh(i + 2, k + 2), k + 2), Vector3(i, gh(i, k + 2), k + 2)]
			for t in [[0, 1, 2], [0, 2, 3]]:
				for j in t:
					st.set_normal(Vector3.UP); st.add_vertex(q[j])
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.4, 0.4, 0.38); gm.roughness = 1.0
	var gmi := MeshInstance3D.new(); gmi.mesh = st.commit(); gmi.material_override = gm; root.add_child(gmi)
	var road := MeshInstance3D.new(); var rb := BoxMesh.new(); rb.size = Vector3(120, 0.02, 12); road.mesh = rb
	var rm := StandardMaterial3D.new(); rm.albedo_color = Color(0.16, 0.16, 0.17); road.material_override = rm; road.position = Vector3(0, 0.05, 11); root.add_child(road)
	var cam := Camera3D.new(); cam.fov = 70; root.add_child(cam); cam.current = true; cam.far = 500
	var seed := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 6
	var subs: Array = OS.get_environment("SUBS").split(",") if OS.get_environment("SUBS") != "" else ["", "pub", "chemist/2", "", "bank", "hardware", "cafe/2", ""]
	var cut := OS.get_environment("CUT") != ""
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var x := -float(n) * 4.0
	var plans := []
	for i in n:
		var sub: String = subs[i % subs.size()]
		var w := rng.randf_range(5.5, 9.5) if not sub.begins_with("pub") else 14.0
		var d := rng.randf_range(14.0, 22.0)
		var p := BuildGen.plan("shop", w, d, seed * 7919 + i * 31, sub)
		if cut:
			p["cut"] = 1.25
			p["cut_floor"] = 0 if OS.get_environment("UPPER") == "" else 1
		var cx := x + w / 2
		x += w
		var top := maxf(gh(cx - w / 2, 0), gh(cx + w / 2, 0))
		var xf := Transform3D(Basis(), Vector3(cx, top + float(p.raised), 4.0 - d / 2))
		var ground := func(lx: float, lz: float) -> float:
			var wp := xf * Vector3(lx, 0, lz)
			return gh(wp.x, wp.z) - xf.origin.y
		var t0 := Time.get_ticks_msec()
		var b := BuildGen.build(p, ground)
		b.transform = xf
		root.add_child(b)
		var r2 := RandomNumberGenerator.new(); r2.seed = int(p.seed)
		var boxes := BuildProps.furnish(p, b, r2)
		print("BUILT shop ", p.sub, " two=", p.two, " ", p.front.style, " '", p.front.name, "' ", Time.get_ticks_msec() - t0, " ms rooms=",
			p.floors.map(func(f): return f.rooms.map(func(r): return r.type)), " containers=", boxes.size())
		plans.append([p, xf])
	for _k in 30:
		BuildProps.work(200000)
		await process_frame
	var mid := 0.0
	if cut:
		cam.look_at_from_position(Vector3(0.01, 40, 6), Vector3(0, 0, -6), Vector3.UP)
		await _shot("plan" + ("_up" if OS.get_environment("UPPER") != "" else ""))
		quit()
		return
	cam.look_at_from_position(Vector3(mid - 4, 3.0, 22), Vector3(mid, 4.0, 4), Vector3.UP)
	await _shot("street")
	cam.look_at_from_position(Vector3(-float(n) * 4.0 - 2, 1.7, 5.6), Vector3(0, 2.6, 5.0), Vector3.UP)
	await _shot("footpath")
	cam.look_at_from_position(Vector3(mid + 3, 9.0, 20), Vector3(mid, 4.5, 2), Vector3.UP)
	await _shot("high")
	# inside a couple
	for k in [0, 2]:
		if k >= plans.size(): continue
		var p: Dictionary = plans[k][0]
		var xf: Transform3D = plans[k][1]
		for r in p.floors[0].rooms:
			if r.type == "shop":
				cam.look_at_from_position(xf * Vector3(float(r.x0) + 0.5, 1.7, float(r.z1) - 0.6), xf * Vector3(float(r.x1) - 0.4, 0.9, float(r.z0) + 0.3), Vector3.UP)
				await _shot("in_%d_shop" % k)
				cam.look_at_from_position(xf * Vector3(float(r.x1) - 0.5, 1.7, float(r.z0) + 0.5), xf * Vector3(float(r.x0) + 0.4, 1.4, float(r.z1)), Vector3.UP)
				await _shot("in_%d_front" % k)
		if p.two:
			for r in p.floors[1].rooms:
				if r.type == "lounge":
					cam.look_at_from_position(xf * Vector3(float(r.x0) + 0.4, ShopGen.UY + 1.6, float(r.z0) + 0.4), xf * Vector3(float(r.x1) - 0.3, ShopGen.UY + 1.0, float(r.z1)), Vector3.UP)
					await _shot("in_%d_upstairs" % k)
			for r in p.floors[0].rooms:
				if r.type == "stair":
					cam.look_at_from_position(xf * Vector3((float(r.x0) + float(r.x1)) / 2, 1.6, float(r.z1) + 1.5), xf * Vector3((float(r.x0) + float(r.x1)) / 2, 3.0, float(r.z0)), Vector3.UP)
					await _shot("in_%d_stair" % k)
	quit()

func _shot(name: String) -> void:
	for k in 4: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OUT + name + ".png")
