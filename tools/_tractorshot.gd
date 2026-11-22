extends Node
## A picture of the tractor and the new wheels on a plain floor (0.2.59). xvfb: godot --path . res://tools/_tractorshot.tscn
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.65, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.7, 0.7, 0.7); env.ambient_light_energy = 0.6
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 40, 0); sun.shadow_enabled = true; add_child(sun)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(200, 2, 200); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); fl.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.35, 0.36, 0.33); fl.material_override = fm; add_child(fl)
	var c := Car.new(); c.design = VehicleSpecs.default_design(OS.get_environment("SHOT_CAR") if OS.get_environment("SHOT_CAR") != "" else "tractor"); add_child(c); c.position = Vector3(0, 1.4, 0)
	var keys: Array = OS.get_environment("SHOT_WHEELS").split(",") if OS.get_environment("SHOT_WHEELS") != "" else ["jag20", "stance_r13", "saab", "r33", "tractor_lug"]
	for i in keys.size():
		var d := VehicleSpecs.default_design("vhute")
		d.wheel_model = keys[i]
		var u := Car.new(); u.design = d; add_child(u); u.position = Vector3(-5.5 - i * 0.0, 1.2, -6.0 + i * 2.6) if false else Vector3(6.0, 1.2, -9.0 + i * 4.5)
		u.rotation.y = PI * 0.5
	var cam := Camera3D.new(); add_child(cam); cam.fov = 50
	for i in 200: await get_tree().physics_frame
	cam.global_position = Vector3(-5.5, 2.6, 6.5); cam.look_at(Vector3(0.5, 0.9, 0)); cam.current = true
	for i in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/t59_tractor2.png")
	cam.global_position = Vector3(2.0, 1.4, -10.0); cam.look_at(Vector3(6.0, 0.5, -3.0))
	for i in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/t59_wheels.png")
	print("SHOTS done up ", c.global_transform.basis.y.y)
	get_tree().quit()
