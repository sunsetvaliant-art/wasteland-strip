extends Node
## 0.2.74: look at downloaded animals: each .glb from disk, its clip list and size, a side view mid-walk.
## ANIM_FILES="a.glb:clip,b.glb:clip" (clip may be a part of the name) -> /tmp/shots/anim_<i>.png
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.62, 0.7, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.85, 0.85, 0.85); env.ambient_light_energy = 0.9
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); add_child(sun)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 40; cam.current = true
	var i := 0
	for spec in OS.get_environment("ANIM_FILES").split(","):
		var a := spec.split(":")
		var doc := GLTFDocument.new(); var st := GLTFState.new()
		if doc.append_from_file(a[0], st) != OK: print("ANIM fail ", a[0]); continue
		var n: Node3D = doc.generate_scene(st)
		add_child(n)
		var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0] if n.find_children("*", "AnimationPlayer", true, false).size() else null
		if ap:
			var want := ""
			for c in ap.get_animation_list():
				if a.size() > 1 and c.to_lower().contains(a[1].to_lower()): want = c; break
			print("ANIM ", a[0].get_file(), " clips ", ap.get_animation_list().size(), " playing ", want)
			if want != "":
				ap.play(want)
				ap.seek(float(OS.get_environment("ANIM_T")) if OS.get_environment("ANIM_T") != "" else 0.4, true)
				var an := ap.get_animation(want)
				print("ANIM   length ", an.length, " loop ", an.loop_mode)
		for k in 3: await get_tree().process_frame
		var ab := AABB(); var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			if first: ab = b; first = false
			else: ab = ab.merge(b)
		print("ANIM   size ", ab.size, " pos ", ab.position, " bones ", Animal.bone_box(n))
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for si in m.mesh.get_surface_count():
				var sm = m.mesh.surface_get_material(si)
				if sm is StandardMaterial3D and (sm as StandardMaterial3D).albedo_texture == null:
					var nm := (sm as StandardMaterial3D).duplicate() as StandardMaterial3D
					nm.vertex_color_use_as_albedo = true
					m.set_surface_override_material(si, nm)
		var c := ab.get_center(); var r := ab.size.length()
		cam.look_at_from_position(c + Vector3(r * 1.1, r * 0.25, r * 0.6), c, Vector3.UP)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/shots/anim_%d.png" % i)
		n.queue_free()
		i += 1
	get_tree().quit()
