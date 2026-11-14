extends SceneTree
## Melee lab: the player body in each Mixamo clip at a chosen moment, weapon in hand, in a row. One picture.
## env SHOTS="clip:time:weapon,..." OUT=file.png CAM="x,y,z" MODEL=player
func _init():
	await process_frame
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.62, 0.66, 0.72)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.6
	w.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); sun.light_energy = 1.2; w.add_child(sun)
	var g0 := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); g0.mesh = pm; w.add_child(g0)
	var shots := OS.get_environment("SHOTS").split(";")
	var GRIP := OS.get_environment("GRIP") if OS.get_environment("GRIP") != "" else "-0.085,-0.03,0.02,0,3.14159,0"
	var i := 0
	for sh in shots:
		var a := sh.split(":")
		var body := Node3D.new(); w.add_child(body)
		body.position = Vector3((i - (shots.size() - 1) * 0.5) * 1.5, 0, 0)
		body.rotation.y = float(OS.get_environment("YAW")) if OS.get_environment("YAW") != "" else 0.0
		var rig := Rig.new(); body.add_child(rig); rig.load_model(OS.get_environment("MODEL") if OS.get_environment("MODEL") != "" else "player")
		rig.anim.play("pool/" + a[0]); rig.anim.seek(float(a[1]), true)
		rig.set_process(false)
		if a.size() > 2 and a[2] != "":
			var att := BoneAttachment3D.new(); rig.skel.add_child(att); att.bone_idx = rig.bone("RightHand")
			# a stand-in the same shape the game's weapons are built in: along -Z, gripped 15% from the near end
			var L := float(a[2])
			var m := Node3D.new(); var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.04, 0.04, L); mi.mesh = bm
			mi.position = Vector3(0, 0, -L * 0.35); m.add_child(mi)
			var tip := MeshInstance3D.new(); var tb := BoxMesh.new(); tb.size = Vector3(0.1, 0.1, 0.1); tip.mesh = tb; tip.position = Vector3(0, 0, -L * 0.85); m.add_child(tip)
			var mt := StandardMaterial3D.new(); mt.albedo_color = Color(0.9, 0.2, 0.1); mi.material_override = mt; tip.material_override = mt
			att.add_child(m)
			var rest: Transform3D = rig.skel.get_bone_global_rest(rig.bone("RightHand"))
			var k: float = 1.0 / maxf(rig.skel.global_transform.basis.get_scale().x, 0.001)
			var g := GRIP.split(",")
			m.transform = rest.affine_inverse() * Transform3D(Basis.from_euler(Vector3(float(g[3]), float(g[4]), float(g[5]))).scaled(Vector3.ONE * k), rest.origin + Vector3(float(g[0]), float(g[1]), float(g[2])) * k)
			if i == 0: print("MXLAB hand rest basis x ", rest.basis.x.snapped(Vector3.ONE * 0.01), " y ", rest.basis.y.snapped(Vector3.ONE * 0.01), " z ", rest.basis.z.snapped(Vector3.ONE * 0.01), " origin ", rest.origin.snapped(Vector3.ONE * 0.01), " k ", k)
		var l := Label3D.new(); l.text = "%s @%s" % [a[0], a[1]]; l.position = body.position + Vector3(0, 2.05, 0); l.pixel_size = 0.004; l.modulate = Color.BLACK; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; w.add_child(l)
		i += 1
	var cam := Camera3D.new(); w.add_child(cam); cam.current = true
	var cp := OS.get_environment("CAM").split(",") if OS.get_environment("CAM") != "" else PackedStringArray(["0", "1.2", "-6.5"])
	cam.look_at_from_position(Vector3(float(cp[0]), float(cp[1]), float(cp[2])), Vector3(0, 1.0, 0), Vector3.UP)
	cam.fov = 40
	for _k in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
	print("MXLAB saved")
	quit()
