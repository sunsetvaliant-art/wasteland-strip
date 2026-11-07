extends SceneTree
## Generated buildings on a sloping yard: outside, a cut-away from above, and a look inside the rooms.
##   KINDS=qlder,brick SEED=3 godot --path . -s tools/_houselab.gd
const OUT := "/tmp/claude-0/houses/"
const SIZES := {"qlder": [12.0, 10.5], "cottage": [9.0, 8.0], "brick": [13.0, 10.0], "two_storey": [11.0, 10.0], "shed": [10.0, 14.0],
	"machine_shed": [15.0, 8.0], "dairy": [16.0, 9.0], "workshop": [16.0, 24.0], "warehouse": [24.0, 36.0]}
var slope := 0.05

func gh(x: float, z: float) -> float:
	return x * slope + sin(z * 0.15) * 0.3

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
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-48, -35, 0); sun.shadow_enabled = true; sun.light_energy = 1.35
	sun.directional_shadow_max_distance = 120; root.add_child(sun)
	# the yard: a sloping grid of quads
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var R := 90
	for i in range(-R, R, 3):
		for k in range(-R, R, 3):
			var q := [Vector3(i, gh(i, k), k), Vector3(i + 3, gh(i + 3, k), k), Vector3(i + 3, gh(i + 3, k + 3), k + 3), Vector3(i, gh(i, k + 3), k + 3)]
			for t in [[0, 1, 2], [0, 2, 3]]:
				for j in t:
					st.set_normal(Vector3(-slope, 1, 0).normalized()); st.add_vertex(q[j])
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.32, 0.38, 0.2); gm.roughness = 1.0
	var gmi := MeshInstance3D.new(); gmi.mesh = st.commit(); gmi.material_override = gm; root.add_child(gmi)
	var cam := Camera3D.new(); cam.fov = 70; root.add_child(cam); cam.current = true; cam.far = 500
	var kinds: Array = OS.get_environment("KINDS").split(",") if OS.get_environment("KINDS") != "" else BuildGen.KINDS
	var seed := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	for kind in kinds:
		for cutv in [false, true]:
			var sz: Array = SIZES[kind]
			var p := BuildGen.plan(kind, sz[0], sz[1], seed * 7919 + hash(kind))
			if cutv:
				p["cut"] = 1.25
				p["cut_floor"] = 0 if OS.get_environment("UPPER") == "" else 1
			var yaw := 0.35
			var basis := Basis(Vector3.UP, yaw)
			# floor height: the top of the ground under the footprint plus how high it's raised
			var top := -INF
			for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var wp := basis * Vector3(c.x * sz[0] / 2, 0, c.y * sz[1] / 2)
				top = maxf(top, gh(wp.x, wp.z))
			var origin := Vector3(0, top + float(p.raised), 0)
			var xf := Transform3D(basis, origin)
			var ground := func(lx: float, lz: float) -> float:
				var wp := xf * Vector3(lx, 0, lz)
				return gh(wp.x, wp.z) - origin.y
			var t0 := Time.get_ticks_msec()
			var b := BuildGen.build(p, ground)
			b.transform = xf
			root.add_child(b)
			var rng := RandomNumberGenerator.new(); rng.seed = int(p.seed)
			var boxes := BuildProps.furnish(p, b, rng)
			print("BUILT ", kind, " ", Time.get_ticks_msec() - t0, " ms  rooms=", p.floors.map(func(f): return f.rooms.map(func(r): return r.type)), " containers=", boxes.size())
			var big: float = maxf(sz[0], sz[1])
			if not cutv:
				for v in [[Vector3(0.9, 0.45, 1.25), "front"], [Vector3(-1.2, 0.5, -0.9), "back"]]:
					var eye: Vector3 = xf * ((v[0] as Vector3) * big * 1.25)
					cam.look_at_from_position(eye, xf * Vector3(0, 2.5, 0), Vector3.UP)
					await _shot("%s_%s" % [kind, v[1]])
				# inside: from each of a few rooms, looking at the far corner
				var n := 0
				for f in p.floors:
					for r in f.rooms:
						if r.type in ["void", "stair", "hall"] or n >= 4: continue
						var c := Vector3((float(r.x0) + float(r.x1)) / 2, float(f.y) + 1.6, (float(r.z0) + float(r.z1)) / 2)
						var eye := Vector3(float(r.x0) + 0.35, float(f.y) + 1.6, float(r.z1) - 0.35)
						var at := Vector3(float(r.x1) - 0.3, float(f.y) + 0.7, float(r.z0) + 0.3)
						cam.look_at_from_position(xf * eye, xf * at, Vector3.UP)
						await _shot("%s_in_%d_%s" % [kind, n, r.type])
						n += 1
			else:
				cam.look_at_from_position(xf * Vector3(0.01, big * 1.35, big * 0.35), xf * Vector3(0, 0, 0), Vector3.UP)
				await _shot("%s_plan" % kind)
			b.queue_free()
			await process_frame
	quit()

func _shot(name: String) -> void:
	for k in 4: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OUT + name + ".png")
