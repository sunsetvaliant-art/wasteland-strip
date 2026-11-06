extends Node
## Headless combat checks (autoload in test runs only): zombie notices + attacks, headshot, corpse gibbing,
## scav suspicion -> alarm -> shooting, car run-over.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	for _i in 30: await get_tree().physics_frame
	var p: Player = main.player
	Settings.set_value("god_mode", false)
	# a big flat test pad up in the sky, nothing in the way
	var pad := StaticBody3D.new()
	var pcs := CollisionShape3D.new()
	var pb := BoxShape3D.new()
	pb.size = Vector3(600, 2, 600)
	pcs.shape = pb
	pad.add_child(pcs)
	pad.add_to_group("road")
	main.add_child(pad)
	pad.global_position = Vector3(0, 399, 0)
	p.global_position = Vector3(0, 401, 0)
	for _i in 30: await get_tree().physics_frame
	p.yaw = 0.0
	p.rotation.y = 0.0
	var fwd := -p.global_transform.basis.z
	var spawn := func(kind: String, d: float, side := 0.0) -> NPC:
		var n := NPC.new()
		n.kind = kind
		var pos: Vector3 = p.global_position + fwd * d + p.global_transform.basis.x * side
		pos.y = 400.1
		main.add_child(n)
		n.global_position = pos
		n.home = pos; n.goal = pos
		n.face_dir = (p.global_position - pos).normalized()
		return n
	# 1. zombie
	var z: NPC = spawn.call("zombie", 7.0)
	for _i in 120 * 3: await get_tree().physics_frame
	print("CT zombie after 3 s: state=%s dist=%.1f vis=%.2f" % [z.state, z.global_position.distance_to(p.global_position), z.vis])
	var hp0 := p.hp
	for _i in 120 * 6: await get_tree().physics_frame
	print("CT zombie after 9 s: state=%s dist=%.1f player hp %.0f -> %.0f" % [z.state, z.global_position.distance_to(p.global_position), hp0, p.hp])
	# 2. headshot with the Enfield
	p._select(Gun.ORDER.find("enfield"))
	var g := p.gun()
	var eye: Vector3 = p.head.global_position
	var head: Vector3 = z.rig.bone_pos("Head")
	g.cool = 0; g.cycling = 0
	g.fire(eye, (head - eye).normalized(), 0.0)
	await get_tree().physics_frame
	print("CT headshot: zombie dead=%s hp=%.0f ragdoll parts=%d severed=%s" % [z.dead, z.hp, z.ragdoll.bodies.size() if z.ragdoll else 0, z.rig.mods.severed.keys()])
	for _i in 120 * 2: await get_tree().physics_frame
	if z.ragdoll:
		print("CT corpse pelvis height above the pad %.2f" % (z.ragdoll.bodies.pelvis.global_position.y - 400.0))
	# 3. shotgun into the corpse's arm
	p._select(Gun.ORDER.find("sawnoff"))
	g = p.gun()
	for k in 3:
		g.cool = 0; g.ammo = 2; g.reloading = 0
		var arm: Vector3 = z.ragdoll.bodies.r_upperarm.global_position
		eye = p.head.global_position
		g.fire(eye, (arm - eye).normalized(), 0.0)
		for _i in 10: await get_tree().physics_frame
	print("CT corpse after 3 sawn-off blasts: cut=%s corpse dmg=%s gibs=%d" % [z.ragdoll.cut.keys(), z.corpse_dmg, main.find_children("Gib", "", false, false).size()])
	# 4. scav at 35 m
	var s: NPC = spawn.call("scav", 35.0, 3.0)
	s.pausing = true
	s.goal = s.global_position
	s.goal_t = 30.0
	p.hp = 100.0
	var t := 0.0
	var alarm_t := -1.0
	while t < 14.0:
		await get_tree().physics_frame
		t += 1.0 / 120.0
		if alarm_t < 0 and s.state == "combat": alarm_t = t
	print("CT scav (%s): suspicion %.2f state %s alarmed at %.1f s, player hp %.0f, ammo %d" % [s.gun.key, s.suspicion, s.state, alarm_t, p.hp, s.gun.ammo])
	# crouched and far: should take longer
	var s2: NPC = spawn.call("scav", 60.0, -20.0)
	s2.face_dir = -s2.face_dir
	p.crouching = true
	for _i in 120 * 3: await get_tree().physics_frame
	print("CT scav2 facing away at 60 m, crouched: suspicion %.2f state %s" % [s2.suspicion, s2.state])
	s.free_body(); s2.free_body()
	p.crouching = false
	Settings.set_value("god_mode", true)
	# 5. run-over
	var c: Car = main.car
	c.global_position = Vector3(-60, 401.0, -150)
	c.rotation = Vector3.ZERO
	c.linear_velocity = Vector3.ZERO
	await get_tree().physics_frame
	var zs: Array = []
	for i in 3:
		var n := NPC.new(); n.kind = "zombie"
		var pos: Vector3 = c.global_position + c.global_transform.basis.z * (14.0 + i * 1.5)
		pos.y = 400.1
		main.add_child(n); n.global_position = pos; n.home = pos; n.goal = pos
		zs.append(n)
	p.global_position = c.global_position + Vector3(1.5, 0, 0)
	p._try_get_in()
	c.gear = 3
	Input.action_press("move_forward")
	var vmax := 0.0
	for _i in 120 * 5:
		await get_tree().physics_frame
		vmax = max(vmax, c.speed_kmh())
	Input.action_release("move_forward")
	var dead := zs.filter(func(n): return n.dead).size()
	var cuts := 0
	for n in zs: if n.ragdoll: cuts += n.ragdoll.cut.size()
	print("CT run-over at up to %.0f km/h: %d of 3 dead, %d limbs off, car still upright: %s" % [vmax, dead, cuts, c.global_transform.basis.y.y > 0.8])
	Settings.set_value("god_mode", false)
	get_tree().quit()
