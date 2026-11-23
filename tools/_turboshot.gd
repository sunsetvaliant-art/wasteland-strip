extends Node
## 0.2.68: an i6 with a plain, a low-mount and a high-mount turbo manifold; torque numbers; /tmp/shots/turbo.png
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.5, 0.55, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.8); env.ambient_light_energy = 0.8
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); add_child(sun)
	var cam := Camera3D.new(); add_child(cam); cam.current = true; cam.fov = 40
	var x := -1.2
	for ex in ["ex_6", "ex_6_tlow", "ex_6_thigh"]:
		var k := EngineKit.make("i6", false, "sohc", "med", "tb")
		k.exhaust = [ex]
		var st := EngineKit.stats(k)
		var c: Array = st.curve
		print("TS %s %s: torque at 800 %.0f, 2500 %.0f, peak %.0f" % [ex, st.name, float(c[1][1]), float(c[2][1]), float(c[3][1])])
		var n := EngineKit.build_node(k)
		add_child(n)
		n.position = Vector3(x, 0, 0)
		n.rotation_degrees.y = -90
		x += 1.2
	cam.position = Vector3(0.3, 1.4, 2.6); cam.look_at(Vector3(0, 0.35, 0))
	for i in 6: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/turbo.png")
	get_tree().quit()
