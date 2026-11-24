extends Node
## 0.2.74: the live axle links, from under and the side: leaf rear (shackles), coil rear 4-link, 3-link, coil front radius arms
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.5, 0.55, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.8); env.ambient_light_energy = 0.9
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); add_child(sun)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(400, 2, 400); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	var cam := Camera3D.new(); add_child(cam); cam.current = true; cam.fov = 50
	var cars := []
	var i := 0
	for cfg in [["leaf", "leaf", ""], ["coil", "coil", "4link"], ["coil", "coil", "3link"]]:
		var ch := Car.new(); var d := VehicleSpecs.default_design("ranger_dc"); d["no_cab"] = true
		d.axles[0].type = "live"; d.axles[0].spring = cfg[0]
		d.axles[1].type = "live"; d.axles[1].spring = cfg[1]
		if cfg[2] != "": d.axles[1]["links"] = cfg[2]
		ch.design = d; ch.position = Vector3(i * 4.0, 1.0, 0); add_child(ch); cars.append(ch)
		i += 1
	for k in 240: await get_tree().physics_frame
	# articulate one: lift a rear wheel
	var shots := [["links_under_leaf", Vector3(0.0, -3.2, -0.3), Vector3(0, 0.4, -0.3)], ["links_under_4l", Vector3(4.0, -3.2, -0.3), Vector3(4.0, 0.4, -0.3)],
		["links_under_3l", Vector3(8.0, -3.2, -0.3), Vector3(8.0, 0.4, -0.3)], ["links_side", Vector3(-3.5, 0.5, -1.0), Vector3(0, 0.4, -0.8)], ["links_coil", Vector3(4.0 + 2.6, 0.35, -2.6), Vector3(4.0, 0.3, -1.0)],
		["links_3l", Vector3(8.0 + 2.4, 0.3, -2.4), Vector3(8.0, 0.35, -1.0)], ["links_front", Vector3(4.0 + 2.6, 0.35, 2.2), Vector3(4.0, 0.3, 1.2)]]
	for sh in shots:
		cam.position = sh[1]; cam.look_at(sh[2], Vector3.FORWARD if str(sh[0]).contains("under") else Vector3.UP)
		for k in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % sh[0])
	get_tree().quit()
