extends Node
## A forklift lifts an unbolted body off a rolling chassis (0.2.66). xvfb: godot --path . res://tools/_forktest.tscn
## FT_CAR picks the car (default vhute). Screenshots in /tmp/shots/ft_*.png
var cam: Camera3D
func shot(n: String) -> void:
	for k in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/ft_%s.png" % n)

func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.62, 0.7, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.85, 0.85, 0.85); env.ambient_light_energy = 0.9
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); add_child(sun)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(200, 2, 200); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); fl.mesh = pm; add_child(fl)
	cam = Camera3D.new(); add_child(cam); cam.fov = 50; cam.current = true
	var key := OS.get_environment("FT_CAR") if OS.get_environment("FT_CAR") != "" else "vhute"
	var c := Car.new(); c.design = VehicleSpecs.default_design(key); c.position = Vector3(0, 1.2, 0); add_child(c)
	var f := Car.new(); f.design = VehicleSpecs.default_design("forklift"); f.position = Vector3(6, 1.2, 0); f.rotation_degrees.y = 90; add_child(f)
	f.contact_monitor = true; f.max_contacts_reported = 16
	for i in 150: await get_tree().physics_frame
	print("FT forks ", f.forks != null, " forklift y ", snappedf(f.global_position.y, 0.01))
	cam.global_position = f.global_transform * Vector3(2.6, 1.8, 0.5); cam.look_at(f.global_transform * Vector3(0, 0.5, 1.2))
	await shot("fl")
	# drive it: a stand-in driver, W for 3 s, then W+A for 3 s
	var dummy := StaticBody3D.new(); add_child(dummy); dummy.position = Vector3(50, -5, 50)
	f.driver = dummy
	var p0 := f.global_position
	for i in 120: await get_tree().physics_frame
	f._shift(3)
	var wsf := func() -> String:
		var ws := ""
		for w in f.wheels: ws += "[N %.0f L %.3f c %s] " % [w.N, w.L, w.contact]
		return ws
	var st := PhysicsServer3D.body_get_direct_state(f.get_rid())
	for ci in st.get_contact_count():
		var sh := f.shape_owner_get_owner(f.shape_find_owner(st.get_contact_local_shape(ci)))
		var cso := sh as CollisionShape3D
		print("FT contact ", sh.name, " ", cso.shape, " at ", cso.position, " world ", st.get_contact_local_position(ci))
	print("FT rest ", wsf.call(), " y ", f.global_position.y)
	Input.action_press("move_forward")
	for i in 360:
		await get_tree().physics_frame
		if i % 40 == 20: print("FT str v %.2f %s pitch %.3f" % [f.linear_velocity.length(), wsf.call(), f.global_rotation.x])
	print("FT drove ", snappedf((f.global_position - p0).length(), 0.01), " m in 3 s, ", snappedf(f.linear_velocity.length() * 3.6, 0.1), " km/h, running ", f.running)
	var yaw0 := f.global_rotation.y
	Input.action_press("move_left")
	for i in 360:
		await get_tree().physics_frame
		if i % 60 == 30:
			var ws := ""
			for w in f.wheels: ws += "[st %.2f N %.0f c %s] " % [w.steer, w.N, w.contact]
			print("FT turn v %.2f yawrate %.2f steer %.2f %s" % [f.linear_velocity.length(), f.angular_velocity.y, f.steer_now, ws])
	Input.action_release("move_left")
	Input.action_release("move_forward")
	print("FT turned ", snappedf(rad_to_deg(wrapf(f.global_rotation.y - yaw0, -PI, PI)), 0.1), " deg, tilt ", snappedf(rad_to_deg(acos(clampf(f.global_transform.basis.y.y, -1, 1))), 0.1))
	f._shift(-2)
	print("FT gear ", f.gear_name())
	Input.action_press("move_forward")
	for i in 240: await get_tree().physics_frame
	Input.action_release("move_forward")
	print("FT reversed to ", snappedf((f.global_position - p0).length(), 0.01))
	f.driver = null
	var rb: RigidBody3D = c.unbolt_body()
	for i in 200: await get_tree().physics_frame
	var y0 := rb.global_position.y
	print("FT unbolted ", rb != null, " mass ", rb.mass, " seated ", c.seated(rb, 0.25, 0.15))
	# the gap: just above the rails (ride + 0.18) up to the body's underside (+0.12)
	var gap_y := (c.global_transform * Vector3(0, float(c.design.ride) + 0.18 + 0.06, 0)).y
	# the body's middle along the car, from its biggest collision box
	var mid := rb.global_position
	var best := 0.0
	for ch in rb.get_children():
		if ch is CollisionShape3D and (ch as CollisionShape3D).shape is BoxShape3D:
			var sz: Vector3 = ((ch as CollisionShape3D).shape as BoxShape3D).size
			if sz.x * sz.z > best: best = sz.x * sz.z; mid = (ch as Node3D).global_position
	# line the forklift up square to the car's side, centred on the body
	f.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	f.freeze = true
	var start := Vector3(c.global_position.x + 4.2, 0.275, mid.z)
	f.global_transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), start)
	f.running = true
	# forks to the gap height (the tine's centre)
	var tine := func() -> float: return (f.global_transform * f.forks.shapes[0][0].transform.origin).y
	var guard := 0
	while absf(tine.call() - gap_y) > 0.008 and guard < 2000:
		f.forks.cmd.x = clampf((gap_y - tine.call()) * 8.0, -1.0, 1.0)
		await get_tree().physics_frame
		guard += 1
	f.forks.cmd.x = 0.0
	print("FT fork height ", snappedf(tine.call(), 0.001), " gap ", snappedf(gap_y, 0.001), " lift ", snappedf(f.forks.lift, 0.001))
	# creep in until the backrest is ~15 cm off the body's near side
	var near_x := mid.x + best / maxf(0.01, 1.0) * 0.0
	var reach := 0.0
	for i in 600:
		var p := f.global_position
		p.x -= 0.4 / 120.0
		f.global_position = p
		await get_tree().physics_frame
		reach = start.x - p.x
		if p.x < c.global_position.x + 0.55 + 1.0: break
	cam.global_position = c.global_transform * Vector3(-1.5, 1.3, 4.5); cam.look_at(c.global_position + Vector3(0.6, 0.5, 0))
	await shot("in")
	print("FT drove in ", snappedf(reach, 0.01), " body moved ", snappedf((rb.global_position - Vector3(rb.global_position.x, y0, rb.global_position.z)).length(), 0.003), " seated ", c.seated(rb, 0.25, 0.15))
	# lift 40 cm
	var t0 := f.forks.lift
	f.forks.cmd.x = 1.0
	for i in 400:
		await get_tree().physics_frame
		if f.forks.lift > t0 + 0.4: break
	f.forks.cmd.x = 0.0
	f.forks.cmd.y = 1.0        # tilt back a touch so it sits into the backrest
	for i in 60: await get_tree().physics_frame
	f.forks.cmd.y = 0.0
	for i in 120: await get_tree().physics_frame
	print("FT lifted: body rose ", snappedf(rb.global_position.y - y0, 0.01), " forks rose ", snappedf(f.forks.lift - t0, 0.01), " seated ", c.seated(rb, 0.25, 0.15))
	await shot("up")
	# back out with it
	for i in 360:
		var p := f.global_position
		p.x += 0.35 / 120.0
		f.global_position = p
		await get_tree().physics_frame
	for i in 60: await get_tree().physics_frame
	var off := Vector2(rb.global_position.x - c.global_position.x, rb.global_position.z - c.global_position.z).length()
	print("FT backed out: body ", snappedf(off, 0.01), " m off the chassis, still up ", snappedf(rb.global_position.y - y0, 0.01))
	cam.global_position = c.global_transform * Vector3(-3.5, 2.5, 5.5); cam.look_at(c.global_position + Vector3(2.0, 0.6, 0))
	await shot("out")
	# set it down
	f.forks.cmd.x = -1.0
	for i in 500:
		await get_tree().physics_frame
		if f.forks.lift <= 0.001: break
	f.forks.cmd.x = 0.0
	for i in 120: await get_tree().physics_frame
	print("FT set down at y ", snappedf(rb.global_position.y, 0.01), " up ", rb.global_transform.basis.y.dot(Vector3.UP))
	await shot("down")
	print("FT_DONE")
	get_tree().quit()
