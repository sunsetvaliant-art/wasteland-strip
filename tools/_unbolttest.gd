extends Node
## Unbolt a body and tub in place, let them settle, bolt them back (0.2.66). xvfb: godot --path . res://tools/_unbolttest.tscn
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.62, 0.7, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.85, 0.85, 0.85); env.ambient_light_energy = 0.9
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); add_child(sun)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(200, 2, 200); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); fl.mesh = pm; add_child(fl)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 45; cam.current = true
	var key := OS.get_environment("UB_CAR") if OS.get_environment("UB_CAR") != "" else "vhute"
	var c := Car.new(); c.design = VehicleSpecs.default_design(key); c.position = Vector3(0, 1.2, 0); add_child(c)
	for i in 120: await get_tree().physics_frame
	var rb: RigidBody3D = c.unbolt_body()
	print("UB unbolted ", rb != null, " bare ", c.design.get("no_cab"), " mass ", rb.mass if rb else 0.0)
	var y0 := rb.global_position.y
	for i in 240: await get_tree().physics_frame
	print("UB body settled dy ", snappedf(rb.global_position.y - y0, 0.001), " seated ", c.seated(rb, 0.25, 0.15), " sleeping ", rb.sleeping)
	cam.global_position = c.global_transform * Vector3(4.5, 2.0, 4.0); cam.look_at(c.global_position + Vector3(0, 0.6, 0))
	for k in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/ub_loose.png")
	# lift it clear and drop it beside: not seated
	rb.global_position += Vector3(0, 1.0, 0) + c.global_transform.basis.x * 3.0
	for i in 200: await get_tree().physics_frame
	print("UB moved off: seated ", c.seated(rb, 0.25, 0.15), " resting y ", snappedf(rb.global_position.y, 0.01))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/ub_off.png")
	# back where it goes
	rb.global_transform = c.body_xform() * Transform3D(Basis.IDENTITY, Vector3(0.05, 0.04, -0.08))
	rb.linear_velocity = Vector3.ZERO
	for i in 120: await get_tree().physics_frame
	print("UB put back: seated ", c.seated(rb, 0.25, 0.15), " bolt ", c.bolt_body(), " bare ", c.design.get("no_cab"))
	for i in 30: await get_tree().physics_frame
	# the tub
	var tb: RigidBody3D = c.unbolt_tub()
	print("UB tub ", tb != null)
	if tb:
		for i in 200: await get_tree().physics_frame
		print("UB tub seated ", c.seated(tb, 0.3, 0.12), " bolt ", c.bolt_tub())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/ub_back.png")
	print("UB_DONE")
	get_tree().quit()
