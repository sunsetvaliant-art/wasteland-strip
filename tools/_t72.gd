extends Node
## 0.2.72 in the world (runpt): the test strips by Thornbill Drive; a ute driven down the mud and the soft sand with the
## player in it; shots of the strips, the spray and the ruts in /tmp/shots/t72_*.png
func _shot(n: String) -> void:
	for _i in 2: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	Settings.set_value("god_mode", true)
	var at := SoftGround.TEST_AT
	var p = main.player
	p.global_position = Vector3(at.x - 6, main.height_at(at.x - 6, at.z + 12) + 1.5, at.z + 12)
	for _i in 200: await get_tree().process_frame
	var strips := []
	for n in main.get_children():
		if n is SoftGround: strips.append(n)
	print("T72 strips ", strips.size(), " ", strips.map(func(s): return s.kind))
	var cam := Camera3D.new(); main.add_child(cam)
	cam.global_position = Vector3(at.x - 8, main.height_at(at.x, at.z) + 6, at.z - 10)
	cam.look_at(Vector3(at.x + 30, main.height_at(at.x + 30, at.z + 12), at.z + 12)); cam.current = true
	await _shot("t72_strips")
	for row in [[0, "mud"], [1, "sand"]]:
		var sg: SoftGround = strips[row[0]]
		var sp: Vector3 = sg.global_position + Vector3(4, 0, 2.5)
		var c: Car = main.spawn_vehicle("vhute", Vector3(sp.x, main.height_at(sp.x, sp.z) + 1.3, sp.z), PI * 0.5)
		c.design.tyre_psi = 32.0
		for _i in 60: await get_tree().physics_frame
		p.global_position = c.global_position + Vector3(0, 0, -3)
		p._try_get_in(c)
		for _i in 30: await get_tree().physics_frame
		c.running = true
		if c.box.auto: c.gear = 3
		Input.action_press("move_forward")
		for i in 240:
			await get_tree().physics_frame
		cam.current = true
		cam.global_position = c.global_position + Vector3(-7, 2.2, -5)
		cam.look_at(c.global_position + Vector3(0, 0.4, 0))
		await _shot("t72_%s_spray" % row[1])
		for i in 240: await get_tree().physics_frame
		Input.action_release("move_forward")
		var sink := 0.0
		for w in c.wheels: sink = maxf(sink, float(w.sink))
		print("T72 %s: at x %.1f along, deepest %.2f, speed %.1f km/h" % [row[1], c.global_position.x - sg.global_position.x, sink, c.linear_velocity.length() * 3.6])
		cam.global_position = sg.global_position + Vector3(1.0, main.height_at(sg.global_position.x, sg.global_position.z) + 2.5, -2.0)
		cam.look_at(sg.global_position + Vector3(12, main.height_at(sg.global_position.x + 12, sg.global_position.z), 2.5))
		await _shot("t72_%s_ruts" % row[1])
		p._get_out()
		for _i in 20: await get_tree().physics_frame
	print("T72_DONE")
	get_tree().quit()
