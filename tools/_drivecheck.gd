extends Node
## Quick handling numbers (0.2.67): settle chatter, 0-60, braking, steady turn, a kerb hit. DC_CARS=a,b
func _ready():
	await get_tree().process_frame
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(4000, 2, 4000); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	var kerb := StaticBody3D.new(); var kc := CollisionShape3D.new(); var kb := BoxShape3D.new(); kb.size = Vector3(40, 0.12, 0.4); kc.shape = kb; kerb.add_child(kc); kerb.add_to_group("road"); add_child(kerb)
	var dummy := StaticBody3D.new(); add_child(dummy); dummy.position = Vector3(0, -50, 0)
	for key in (OS.get_environment("DC_CARS") if OS.get_environment("DC_CARS") != "" else "vjwagon,ranger_dc").split(","):
		var c := Car.new(); c.design = VehicleSpecs.default_design(key); c.position = Vector3(0, 1.0, 0); add_child(c)
		for i in 240: await get_tree().physics_frame
		var chat := 0.0; var prevN := []
		for w in c.wheels: prevN.append(w.N)
		for i in 120:
			await get_tree().physics_frame
			for j in c.wheels.size():
				chat = maxf(chat, absf(c.wheels[j].N - prevN[j])); prevN[j] = c.wheels[j].N
		c.driver = dummy
		for i in 120: await get_tree().physics_frame
		c._shift(1)
		Input.action_press("move_forward")
		var t := 0.0; var t60 := -1.0
		while t < 15.0:
			await get_tree().physics_frame
			t += 1.0 / 120.0
			if t60 < 0 and c.linear_velocity.length() * 3.6 >= 60.0: t60 = t; break
		Input.action_release("move_forward")
		var p0 := c.global_position
		Input.action_press("move_back")
		var bt := 0.0
		while c.linear_velocity.length() > 0.5 and bt < 10.0:
			await get_tree().physics_frame
			bt += 1.0 / 120.0
		Input.action_release("move_back")
		var bd := (c.global_position - p0).length()
		for i in 120: await get_tree().physics_frame
		# steady turn at ~30
		Input.action_press("move_forward")
		var g2 := 0
		while c.linear_velocity.length() * 3.6 < 30.0 and g2 < 1800:
			await get_tree().physics_frame
			g2 += 1
		if g2 >= 1800: print("DC %s never got to 30 again: up %.2f v %.1f" % [key, c.global_transform.basis.y.y, c.linear_velocity.length() * 3.6])
		Input.action_release("move_forward")
		Input.action_press("move_left")
		var yr := 0.0; var roll := 0.0
		for i in 240:
			await get_tree().physics_frame
			if i > 120: yr = maxf(yr, absf(c.angular_velocity.y)); roll = maxf(roll, absf(rad_to_deg(c.rotation.z)))
		Input.action_release("move_left")
		# over the kerb square at ~25
		var fwd := c.global_transform.basis.z; fwd.y = 0; fwd = fwd.normalized()
		kerb.global_position = c.global_position + fwd * 12.0 + Vector3(0, 0.06, 0)
		kerb.look_at(kerb.global_position + fwd.cross(Vector3.UP), Vector3.UP)
		Input.action_press("move_forward")
		var bounce := 0.0
		for i in 360:
			await get_tree().physics_frame
			bounce = maxf(bounce, absf(c.linear_velocity.y))
			if c.linear_velocity.length() * 3.6 > 25.0: Input.action_release("move_forward")
		Input.action_release("move_forward")
		print("DC %s chatter %.0f N/step  0-60 %.2f s  brake 60-0 %.1f m  turn yaw %.2f rad/s roll %.1f deg  kerb vy %.2f" % [key, chat, t60, bd, yr, roll, bounce])
		c.driver = null
		c.queue_free()
		for i in 5: await get_tree().physics_frame
	get_tree().quit()
