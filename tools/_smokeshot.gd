extends Node
## A turned-up diesel idling and on the throttle: is the smoke drawn (0.2.61). xvfb: godot --path . res://tools/_smokeshot.tscn
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.65, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.8); env.ambient_light_energy = 0.8
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 40, 0); add_child(sun)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(200, 2, 200); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); fl.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.35, 0.36, 0.33); fl.material_override = fm; add_child(fl)
	var c := Car.new(); c.design = VehicleSpecs.default_design("tractor"); c.position = Vector3(0, 1.4, 0)
	c.design.kit["spanner"] = 1.0
	add_child(c)
	print("SMOKE level ", EngineKit.smokes(c.design.kit), " diesel ", EngineKit.is_diesel(c.design.kit))
	var cam := Camera3D.new(); add_child(cam); cam.fov = 55
	for i in 60: await get_tree().physics_frame
	c.running = true
	cam.global_position = Vector3(-6.0, 2.4, -7.0); cam.look_at(Vector3(0, 1.0, -1.0)); cam.current = true
	for i in 90:
		c.running = true; c.rpm = 1800.0; c.throttle = 0.8 if i > 40 else 0.0
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/smoke_idle.png")
	print("SMOKE emitter ", c._smoke_p != null, " emitting ", c._smoke_p.emitting if c._smoke_p else false)
	get_tree().quit()
