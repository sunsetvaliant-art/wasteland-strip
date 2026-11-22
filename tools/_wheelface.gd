extends Node
## Every wheel model unturned in a row, shot from +Z (should show the rim face) and from -Z (the back). 0.2.61
## xvfb: godot --path . res://tools/_wheelface.tscn  -> /tmp/shots/wf_front.png, wf_back.png
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.65, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.8); env.ambient_light_energy = 0.9
	we.environment = env; add_child(we)
	var keys: Array = VehicleRig.WHEEL_MODELS.keys()
	keys.erase("stock")
	if OS.get_environment("WF_ONLY") != "": keys = Array(OS.get_environment("WF_ONLY").split(","))
	var cols := int(OS.get_environment("WF_COLS")) if OS.get_environment("WF_COLS") != "" else 6
	for i in keys.size():
		var p: String = VehicleRig.WHEEL_MODELS[keys[i]].path
		var m: Node3D = (load(p) as PackedScene).instantiate()
		add_child(m)
		m.position = Vector3((i % cols) * 1.3, -(i / cols) * 1.3, 0)
		m.rotation_degrees.y = float(OS.get_environment("WF_YAW")) if OS.get_environment("WF_YAW") != "" else 0.0
		var lb := Label3D.new(); lb.text = keys[i]; lb.font_size = 40; lb.pixel_size = 0.004; lb.position = m.position + Vector3(0, -0.6, 0)
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.no_depth_test = true; add_child(lb)
	var rows := ceili(keys.size() / float(cols))
	var ctr := Vector3((cols - 1) * 0.65, -(rows - 1) * 0.65, 0)
	var cam := Camera3D.new(); add_child(cam); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = rows * 1.3 + 0.4
	for side in [["front", 1.0], ["back", -1.0]]:
		var sun := DirectionalLight3D.new(); add_child(sun); sun.look_at_from_position(ctr + Vector3(2, 3, 6.0 * side[1]), ctr)
		cam.global_position = ctr + Vector3(0, 0, 10.0 * side[1]); cam.look_at(ctr); cam.current = true
		if OS.get_environment("WF_TOP") != "":
			cam.global_position = ctr + Vector3(0, 10.0 * side[1], 0.001); cam.look_at(ctr, Vector3(0, 0, -1))
		for k in 6: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/shots/wf_%s.png" % side[0])
		sun.queue_free()
	print("WF done ", keys)
	get_tree().quit()
