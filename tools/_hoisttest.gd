extends Node
## The gantry's chain hoist lifts an unbolted body off its chassis (0.2.66). xvfb: godot --path . res://tools/_hoisttest.tscn
func shot(n: String) -> void:
	for k in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/ht_%s.png" % n)

func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.62, 0.7, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.85, 0.85, 0.85); env.ambient_light_energy = 0.9
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); add_child(sun)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(200, 2, 200); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); fl.mesh = pm; add_child(fl)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 50; cam.current = true
	var key := OS.get_environment("FT_CAR") if OS.get_environment("FT_CAR") != "" else "vhute"
	var c := Car.new(); c.design = VehicleSpecs.default_design(key); c.position = Vector3(0, 1.2, 0); add_child(c)
	for i in 150: await get_tree().physics_frame
	var rb: RigidBody3D = c.unbolt_body()
	for i in 120: await get_tree().physics_frame
	var y0 := rb.global_position.y
	var st := PhysicsServer3D.body_get_direct_state(rb.get_rid())
	var com: Vector3 = rb.global_transform * st.center_of_mass_local
	var h := Hoist.new(); add_child(h); h.global_position = Vector3(0, 0, com.z)
	for i in 10: await get_tree().physics_frame
	print("HT candidate ", h.candidate() == rb, " menu ", h.menu(null)[0][0])
	var why := h.hook(rb)
	print("HT hook '", why, "' chain ", snappedf(h.length, 0.01))
	cam.global_position = Vector3(5.5, 2.6, com.z + 5.0); cam.look_at(Vector3(0, 1.3, com.z))
	await shot("hooked")
	h.cmd = Vector2(1, 0)
	for i in 900:
		await get_tree().physics_frame
		if rb.global_position.y > y0 + 0.5: break
	h.cmd = Vector2.ZERO
	for i in 240: await get_tree().physics_frame
	var up := rb.global_transform.basis.y
	print("HT raised ", snappedf(rb.global_position.y - y0, 0.01), " level ", snappedf(rad_to_deg(acos(clampf(up.y, -1, 1))), 0.1), " deg, seated ", c.seated(rb, 0.25, 0.15))
	await shot("up")
	# roll the chassis out from under it
	c.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC; c.freeze = true
	for i in 480:
		c.global_position += Vector3(0, 0, 4.5 / 480.0)
		await get_tree().physics_frame
	c.freeze = false
	for i in 120: await get_tree().physics_frame
	print("HT chassis out, body still hanging ", snappedf(rb.global_position.y - y0, 0.01))
	await shot("out")
	h.cmd = Vector2(-1, 0)
	for i in 1200:
		await get_tree().physics_frame
		if h.length > 2.8: break
	h.cmd = Vector2.ZERO
	for i in 240: await get_tree().physics_frame
	print("HT lowered: body at y ", snappedf(rb.global_position.y, 0.01), " level ", snappedf(rad_to_deg(acos(clampf(rb.global_transform.basis.y.y, -1, 1))), 0.1))
	await shot("down")
	h.unhook()
	print("HT_DONE")
	get_tree().quit()
