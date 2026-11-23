extends Node
## 0.2.73 (runpt): a beach (T73_TAG names the shots, COAST_OFF=1 for the old one) and the raised test strips with a
## bogged ute's ruts. /tmp/shots/t73_*.png
func _shot(n: String) -> void:
	for _i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	Settings.set_value("god_mode", true)
	var tag := OS.get_environment("T73_TAG")
	var p = main.player
	var cam := Camera3D.new(); main.add_child(cam); cam.far = 4000
	for spot in [[Vector3(17120, 0, -8120), Vector3(17230, 0, -8260), "a"], [Vector3(16990, 0, -7600), Vector3(17120, 0, -7700), "b"]]:
		var a: Vector3 = spot[0]; var b: Vector3 = spot[1]
		p.global_position = Vector3(a.x, main.height_at(a.x, a.z) + 3.0, a.z)
		for _i in 150: await get_tree().process_frame
		cam.global_position = Vector3(a.x, maxf(main.height_at(a.x, a.z), 0.0) + 9.0, a.z)
		cam.look_at(Vector3(b.x, 0.0, b.z)); cam.current = true
		await _shot("t73_beach_%s_%s" % [spot[2], tag])
		var line := ""
		for k in 9:
			var q := a.lerp(b, float(k) / 8.0)
			line += "%.2f " % main.height_at(q.x, q.z)
		print("T73 %s heights along: %s" % [spot[2], line])
	if tag == "after":
		var at := SoftGround.TEST_AT
		p.global_position = Vector3(at.x - 6, main.height_at(at.x - 6, at.z + 12) + 1.5, at.z + 12)
		for _i in 150: await get_tree().process_frame
		var sg: SoftGround = null
		for n in main.get_children():
			if n is SoftGround and n.kind == "soft_sand": sg = n
		var sp: Vector3 = sg.global_position + Vector3(14, 0, 2.5)
		var c: Car = main.spawn_vehicle("vhute", Vector3(sp.x, main.height_at(sp.x, sp.z) + 1.9, sp.z), PI * 0.5)
		for _i in 60: await get_tree().physics_frame
		p.global_position = c.global_position + Vector3(0, 0, -3)
		p._try_get_in(c)
		for _i in 30: await get_tree().physics_frame
		c.running = true
		if c.box.auto: c.gear = 3
		Input.action_press("move_forward")
		for i in 600: await get_tree().physics_frame
		Input.action_release("move_forward")
		p._get_out()
		for _i in 20: await get_tree().physics_frame
		c.global_position += Vector3(0, 3, 0)
		c.freeze = true
		c.visible = false
		var g: float = main.height_at(sp.x, sp.z)
		cam.global_position = sg.global_position + Vector3(9, g + 2.0 - sg.global_position.y, -1.5)
		cam.look_at(sg.global_position + Vector3(16, g - sg.global_position.y, 2.5)); cam.current = true
		await _shot("t73_ruts")
		cam.global_position = sg.global_position + Vector3(-6, g + 4.0, -6)
		cam.look_at(sg.global_position + Vector3(20, g, 8)); cam.current = true
		await _shot("t73_beds")
	print("T73_DONE")
	get_tree().quit()
