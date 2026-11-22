extends Node
## Top-down of the tractor's tyres: which way the lugs point (0.2.61). xvfb: godot --path . res://tools/_treadshot.tscn
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.65, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.8); env.ambient_light_energy = 2.0
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-60, 90, 0); sun.light_energy = 1.5; add_child(sun)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(200, 2, 200); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); fl.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.35, 0.36, 0.33); fl.material_override = fm; add_child(fl)
	var c := Car.new(); c.design = VehicleSpecs.default_design(OS.get_environment("SHOT_CAR") if OS.get_environment("SHOT_CAR") != "" else "tractor"); c.position = Vector3(0, 1.4, 0)
	if OS.get_environment("SHOT_WM") != "":
		for a in c.design.axles: a.wheel_model = OS.get_environment("SHOT_WM")
	add_child(c)
	var cam := Camera3D.new(); add_child(cam); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 6.0
	for i in 120: await get_tree().physics_frame
	var fwd := -c.global_transform.basis.z
	var keep := {}
	for w in c.parts.wheel_nodes:
		for n in (w.spin as Node).find_children("*", "MeshInstance3D", true, false): keep[n] = true
	for n in c.find_children("*", "MeshInstance3D", true, false):
		if not keep.has(n): (n as MeshInstance3D).visible = false
	print("TREAD fwd ", fwd)
	cam.global_position = c.global_position + Vector3(0, 12, 0); cam.look_at(c.global_position, -Vector3.FORWARD.rotated(Vector3.UP, 0.0) * -1.0 if false else Vector3(fwd.x, 0, fwd.z)); cam.current = true
	cam.size = 2.6
	for k in 2:
		var w: Dictionary = c.parts.wheel_nodes[c.wheel_nodes_rear_idx(k) if false else (c.wheels.size() - 2 + k)]
		var wp: Vector3 = (w.spin as Node3D).global_position
		cam.global_position = wp + Vector3(0, 12, 0); cam.look_at(wp, Vector3(fwd.x, 0, fwd.z))
		for i in 6: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/shots/tread_%s%d.png" % [OS.get_environment("SHOT_WM"), k])
	print("TREAD done")
	get_tree().quit()
