extends SceneTree
## Renders an icon for every item that has a model (guns: their gun model) into assets/icons/<id>.png
func _init() -> void:
	await process_frame
	var sv := SubViewport.new()
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(sv)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	sv.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.4
	sv.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	sv.add_child(cam)
	cam.current = true
	for id in Items.DEFS:
		var d: Dictionary = Items.DEFS[id]
		var holder := Node3D.new()
		sv.add_child(holder)
		var vis: Node3D
		if d.kind == "gun":
			var g := Gun.new()
			holder.add_child(g)
			g.setup(d.gun, null)
			g.set_process(false)
			g.rotation.y = PI * 0.5          # barrel to the right
			vis = g
		elif d.has("model"):
			vis = (load(d.model) as PackedScene).instantiate()
			holder.add_child(vis)
			vis.rotation_degrees = Vector3(20, -30, 0)
		else:
			holder.queue_free()
			continue
		var aspect := float(d.w) / float(d.h)
		sv.size = Vector2i(int(128 * d.w), int(128 * d.h))
		await process_frame
		var bb := WorldItem._aabb(holder)
		cam.keep_aspect = Camera3D.KEEP_HEIGHT if aspect <= 1.0 else Camera3D.KEEP_WIDTH
		cam.size = max(bb.size.y, bb.size.x / aspect) * 1.12 if aspect <= 1.0 else max(bb.size.x, bb.size.y * aspect) * 1.12
		cam.position = bb.get_center() + Vector3(0, 0, 10)
		cam.look_at(bb.get_center())
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://assets/icons/%s.png" % id))
		print("ICON ", id, " ", img.get_size())
		holder.queue_free()
		await process_frame
	quit()
