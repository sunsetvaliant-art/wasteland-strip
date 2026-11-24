extends Node
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.5, 0.55, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.8); env.ambient_light_energy = 0.9
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 20, 0); add_child(sun)
	var cam := Camera3D.new(); add_child(cam); cam.current = true; cam.fov = 40
	var keys := ["zombie_hollow", "zombie_walker2", "zombie_ww", "zombie_soldier", "zombie_mx", "zombie_hazmat", "zombie_fuse", "zombie_female", "zombie_runner"]
	var x := -float(keys.size() - 1) * 0.5 * 1.1
	for k in keys:
		var r := Rig.new(); add_child(r); r.load_model(k); r.position = Vector3(x, 0, 0); r.rotation.y = PI
		var l := Label3D.new(); l.text = k; l.position = Vector3(x, 2.05, 0); l.pixel_size = 0.004; add_child(l)
		x += 1.1
	cam.position = Vector3(0, 1.1, 8.2); cam.look_at(Vector3(0, 1.0, 0))
	for i in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/zlineup.png")
	get_tree().quit()
