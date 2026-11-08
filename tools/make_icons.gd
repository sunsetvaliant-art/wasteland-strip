extends SceneTree
## Renders an icon for every item into assets/icons/<id>.png at exactly the item's grid shape (128 px a cell), the
## model turned so it lies along the item's long side and framed to fill it: a 5 x 1 rifle is a long thin picture,
## a 1 x 2 thermos a tall one. Items with no model (bandages, clothes) get a simple built stand-in.
##   godot --path . -s tools/make_icons.gd        (ONLY=id,id to redo a few)

const CELL := 128

func _init() -> void:
	await process_frame
	var only := OS.get_environment("ONLY").split(",", false)
	var sv := SubViewport.new()
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_8X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(sv)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.62, 0.66)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	sv.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.5
	sv.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.5
	sv.add_child(rim)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	sv.add_child(cam)
	cam.current = true
	for id in Items.DEFS:
		if only.size() and not id in only:
			continue
		if not Items.DEFS[id].has("model") and Items.DEFS[id].kind != "gun":
			continue          # hand-drawn (bandage, clothes): tools/draw_icons.py
		var d: Dictionary = Items.DEFS[id]
		var holder := Node3D.new()
		sv.add_child(holder)
		var spin := Node3D.new()          # turns the item to lie along the icon
		holder.add_child(spin)
		var vis: Node3D
		if d.kind == "gun":
			var g := Gun.new()
			spin.add_child(g)
			g.setup(d.gun, null)
			g.set_process(false)
			if g.flash_mesh: g.flash_mesh.free()     # the hidden muzzle-flash card would pad the framing (a lot, on a pistol)
			g.rotation.y = PI * 0.5        # side on, barrel to the right
			vis = g
		elif d.has("model"):
			vis = (load(d.model) as PackedScene).instantiate()
			spin.add_child(vis)
			vis.rotation_degrees = Vector3(18, -28, 0)
		else:
			vis = _stand_in(id, d)
			spin.add_child(vis)
		await process_frame
		# lie the model's long side along the icon's long side
		var bb := WorldItem._aabb(holder)
		var wide: bool = d.w >= d.h
		if d.has("icon_rot"):
			spin.rotation.z = deg_to_rad(float(d.icon_rot))
			await process_frame
			bb = WorldItem._aabb(holder)
		elif d.kind != "gun" and d.w != d.h and (bb.size.x >= bb.size.y) != wide:
			spin.rotation.z = PI * 0.5
			await process_frame
			bb = WorldItem._aabb(holder)
		# fill the icon: orthographic, framed on the tighter of width and height
		var aspect := float(d.w) / float(d.h)
		sv.size = Vector2i(CELL * int(d.w), CELL * int(d.h))
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		var margin := 1.06 if d.kind == "gun" else 1.12
		cam.size = max(bb.size.y, bb.size.x / aspect) * margin
		cam.position = bb.get_center() + Vector3(0, 0, 10)
		cam.look_at(bb.get_center())
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://assets/icons/%s.png" % id))
		print("ICON ", id, " ", img.get_size())
		holder.queue_free()
		await process_frame
	quit()

## Simple built stand-ins for things there's no model of
func _stand_in(id: String, d: Dictionary) -> Node3D:
	var root := Node3D.new()
	var mat := func(c: Color, rough := 0.95) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		return m
	if id == "bandage":
		# a rolled crepe bandage with its tail unwound
		var roll := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.035
		cy.bottom_radius = 0.035
		cy.height = 0.07
		roll.mesh = cy
		roll.material_override = mat.call(Color(0.93, 0.9, 0.84))
		roll.rotation_degrees = Vector3(70, 0, 20)
		root.add_child(roll)
		var core := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 0.012
		cc.bottom_radius = 0.012
		cc.height = 0.072
		core.mesh = cc
		core.material_override = mat.call(Color(0.75, 0.7, 0.62))
		core.rotation_degrees = roll.rotation_degrees
		root.add_child(core)
		var tail := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.07, 0.002, 0.06)
		tail.mesh = bx
		tail.material_override = roll.material_override
		tail.position = Vector3(0.04, -0.03, 0.02)
		tail.rotation_degrees = Vector3(10, 30, -10)
		root.add_child(tail)
		return root
	# clothes: a folded garment, colour by item, a collar or waistband stripe, a couple of buttons
	var col: Color = {"shirt_flanno": Color(0.62, 0.16, 0.12), "shirt_work": Color(0.95, 0.55, 0.08), "jacket_army": Color(0.3, 0.33, 0.2),
		"pants_jeans": Color(0.2, 0.28, 0.45), "pants_cargo": Color(0.42, 0.38, 0.27)}.get(id, Color(0.4, 0.4, 0.4))
	var body := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.3, 0.05, 0.3)
	body.mesh = b
	body.material_override = mat.call(col)
	root.add_child(body)
	if id == "shirt_flanno":
		# tartan: darker bands across the fold
		for i in 4:
			var band := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(0.302, 0.052, 0.025)
			band.mesh = bb
			band.material_override = mat.call(Color(0.1, 0.08, 0.08))
			band.position.z = -0.11 + i * 0.075
			root.add_child(band)
			var vb := MeshInstance3D.new()
			var vbb := BoxMesh.new()
			vbb.size = Vector3(0.025, 0.053, 0.302)
			vb.mesh = vbb
			vb.material_override = mat.call(Color(0.12, 0.1, 0.1))
			vb.position.x = -0.11 + i * 0.075
			root.add_child(vb)
	var stripe := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.3, 0.056, 0.05)
	stripe.mesh = sb
	stripe.material_override = mat.call(col.darkened(0.35) if id.begins_with("pants") else col.lightened(0.15))
	stripe.position.z = -0.125
	root.add_child(stripe)
	if id == "shirt_work":
		var refl := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.302, 0.054, 0.03)
		refl.mesh = rb
		refl.material_override = mat.call(Color(0.85, 0.88, 0.9), 0.3)
		refl.position.z = 0.04
		root.add_child(refl)
	for i in 2:
		var btn := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.008
		cm.bottom_radius = 0.008
		cm.height = 0.004
		btn.mesh = cm
		btn.material_override = mat.call(Color(0.75, 0.68, 0.5) if id.begins_with("pants") else Color(0.9, 0.88, 0.8), 0.4)
		btn.position = Vector3(0.0 if id.begins_with("pants") else -0.06 + i * 0.12, 0.028, -0.125 if id.begins_with("pants") else 0.0)
		root.add_child(btn)
	root.rotation_degrees = Vector3(62, 0, 0)          # tilted towards the camera so the top shows
	return root
