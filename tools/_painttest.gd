extends Node
## 0.2.68: respray, parts of your own and lamps on a test cut. PT_CAR (ranger_dc). Shots /tmp/shots/pt_*.png
func shot(n: String) -> void:
	for k in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/pt_%s.png" % n)

func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.25, 0.3, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.7, 0.7, 0.75); env.ambient_light_energy = 0.6
	env.glow_enabled = true
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 140, 0); sun.light_energy = 0.8; add_child(sun)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(200, 2, 200); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); fl.mesh = pm; add_child(fl)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 45; cam.current = true
	var key := OS.get_environment("PT_CAR") if OS.get_environment("PT_CAR") != "" else "ranger_dc"
	var glb := str(Car.catalog()[key].glb)
	# a test cut: respray on the outward body faces above the sills, a "Bull bar" part at the front, a tub plane, lamps
	var tris := PackedVector3Array()
	for m in BodyCut.meshes_of(glb):
		var mesh: Mesh = m.mesh
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var I = arr[Mesh.ARRAY_INDEX]
			var n: int = (I as PackedInt32Array).size() if I != null else V.size()
			for t in range(0, n, 3):
				for k in 3: tris.append((m.xf as Transform3D) * V[(I as PackedInt32Array)[t + k] if I != null else t + k])
	var nt := tris.size() / 3
	print("PT collected ", nt, " triangles")
	var res := PackedByteArray(); res.resize(nt)
	var lab := PackedByteArray(); lab.resize(nt)
	var mn: Array = Car.catalog()[key].min; var ext: Array = Car.catalog()[key].ext
	var zf := float(mn[0]) + float(ext[0])
	for i in nt:
		var c := (tris[i * 3] + tris[i * 3 + 1] + tris[i * 3 + 2]) / 3.0
		if c.y > 0.35 and c.y < 1.15: res[i] = 1
		if c.z > zf - 0.35 and c.y < 0.55: lab[i] = 4
	var n4 := 0
	for v in lab: n4 += int(v == 4)
	print("PT bull bar faces ", n4)
	var t0 := Time.get_ticks_msec()
	BodyCut.all()
	BodyCut._cuts[glb] = {"tub": {"z": -1.25}, "paint": {"n": nt, "runs": BodyCut.runs_of(lab)}, "parts": [{"name": "Bull bar", "off": false}],
		"respray": {"n": nt, "runs": BodyCut.runs_of(res)},
		"lights": [{"t": "round", "p": [0.62, 0.62, zf - 0.02], "n": [0, 0, 1], "s": 0.18}, {"t": "round", "p": [-0.62, 0.62, zf - 0.02], "n": [0, 0, 1], "s": 0.18},
			{"t": "tail", "p": [0.75, 0.75, float(mn[0]) + 0.05], "n": [0, 0, -1], "s": 0.12, "d": 0.02}, {"t": "tail", "p": [-0.75, 0.75, float(mn[0]) + 0.05], "n": [0, 0, -1], "s": 0.12, "d": 0.02}]}
	BodyCut._cache.clear()
	var d := VehicleSpecs.default_design(key)
	d["paint_col"] = "2a5fc0"
	var c1 := Car.new(); c1.design = d; c1.position = Vector3(0, 1.0, 0); add_child(c1)
	var c2 := Car.new(); c2.design = VehicleSpecs.default_design(key); c2.position = Vector3(3.2, 1.0, 0); add_child(c2)
	print("PT built two cars in ", Time.get_ticks_msec() - t0, " ms")
	for i in 30: await get_tree().physics_frame
	for l in c1.lights: l.visible = true
	print("PT beams at ", c1.lights[0].position, " ", c1.lights[1].position, " lamps ", c1.lamps.size())
	print("PT acc keys ", BodyCut.pieces(glb, false, false).acc.keys(), " ", BodyCut.pieces(glb, false, false).cab.size())
	var acc := BodyCut.part_body(glb, "acc", 4)
	var cab := BodyCut.part_body(glb, "cab")
	var tub := BodyCut.part_body(glb, "tub")
	print("PT part bodies ", acc != null, " ", cab != null, " ", tub != null, " cab loose_bodies ", cab.is_in_group("loose_bodies") if cab else false, " meta ", cab.get_meta("body_of", "") if cab else "")
	print("PT custom parts ", BodyCut.custom_parts())
	for n in [acc, cab, tub]:
		if n: add_child(n)
	acc.global_position = Vector3(-3, 0.5, 2); cab.global_position = Vector3(-4, 0.6, -4); tub.global_position = Vector3(-1.5, 0.6, -6)
	for i in 30: await get_tree().physics_frame
	cam.global_position = Vector3(5.5, 2.2, 7.5); cam.look_at(Vector3(1.0, 0.8, 0.5))
	await shot("front")
	cam.global_position = Vector3(-2.0, 2.2, -8.5); cam.look_at(Vector3(0.5, 0.8, 0))
	await shot("rear")
	cam.global_position = Vector3(-9, 4, 2); cam.look_at(Vector3(-2.5, 0.5, -2))
	await shot("parts")
	print("PT_DONE")
	get_tree().quit()
