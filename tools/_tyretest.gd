extends Node
## Tyres and brakes on flat bitumen (0.2.58). Run: godot --headless --path . res://tools/_tyretest.tscn
##  1. braking from 80 km/h: S (the driver's foot) vs Shift+S (stomp): stopping distance, peak decel, time locked
##  2. a V8 RWD launch with a flick of steering: open / lsd / locked diff: each rear wheel's spin, the yaw it takes,
##     how far the tail swings out and whether it straightens up
var w: Node3D
var g: StaticBody3D

func _ready():
	await get_tree().process_frame
	w = Node3D.new(); add_child(w)
	g = StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(6000, 2, 6000); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); w.add_child(g)
	for mode in ["foot", "stomp"]:
		await _brake(mode)
	for diff in ["open", "lsd", "locked"]:
		await _launch(diff)
	get_tree().quit()

func _car(diff: String, v8: bool) -> Car:
	var d := VehicleSpecs.default_design("vjwagon")
	for a in d.axles:
		if a.drive: a.diff = diff
	if v8:
		d.kit = EngineKit.make("v8", true, "push", "hi", "carby")
		d.gearbox = "man4"
	var c := Car.new(); c.design = d; w.add_child(c); c.position = Vector3(0, 1.2, 0)
	var dummy := StaticBody3D.new(); w.add_child(dummy); c.driver = dummy
	for i in 240: await get_tree().physics_frame
	return c

func _brake(mode: String) -> void:
	var c := await _car("open", false)
	var fwd := c.global_transform.basis.z
	c.linear_velocity = fwd * (80.0 / 3.6)
	for wh in c.wheels: wh.omega = (80.0 / 3.6) / float(wh.r)
	if c.box.auto: c._shift(3)
	await get_tree().physics_frame
	var p0 := c.global_position
	Input.action_press("move_back")
	if mode == "stomp": Input.action_press("sprint")
	var t := 0.0; var locked_t := 0.0; var peak := 0.0; var v_prev := c.linear_velocity.length()
	while c.linear_velocity.length() > 0.5 and t < 12.0:
		await get_tree().physics_frame
		var dt := 1.0 / float(Engine.physics_ticks_per_second)
		t += dt
		var v := c.linear_velocity.length()
		peak = maxf(peak, (v_prev - v) / dt / 9.81)
		v_prev = v
		var any := false
		for wh in c.wheels:
			if wh.contact and float(wh.sr) < -0.3: any = true
		if any: locked_t += dt
	Input.action_release("move_back"); Input.action_release("sprint")
	print("TT brake %-5s 80-0: %.1f m in %.2f s, peak %.2f g, a wheel locked %.2f s, pedal ended %.2f" % [mode, (c.global_position - p0).length(), t, peak, locked_t, c.brake_in])
	c.queue_free()
	for i in 10: await get_tree().physics_frame

func _launch(diff: String) -> void:
	var c := await _car(diff, true)
	c.gear = 2           # first
	var yaw0 := c.global_rotation.y
	Input.action_press("move_forward"); Input.action_press("sprint")
	var max_yaw := 0.0; var max_beta := 0.0
	var line := ""
	for i in Engine.physics_ticks_per_second * 4:
		if i == 40: Input.action_press("move_left")
		if i == 64: Input.action_release("move_left")
		await get_tree().physics_frame
		var v := c.linear_velocity
		var fwd := c.global_transform.basis.z
		var side := c.global_transform.basis.x
		var beta := atan2(v.dot(side), maxf(absf(v.dot(fwd)), 0.5)) if v.length() > 1.0 else 0.0
		max_beta = maxf(max_beta, absf(beta))
		max_yaw = maxf(max_yaw, absf(c.angular_velocity.y))
		if i % 60 == 0:
			var s := ""
			for wh in c.wheels:
				if wh.a.drive: s += " %s om %5.1f sr %5.2f N %5.0f+%4.0f" % ["L" if float(wh.side) > 0 else "R", wh.omega, float(wh.sr), wh.N, float(wh.dN)]
			line += "\nTT   t=%.1f %5.1f km/h %s rpm %4d yaw %+5.2f slip angle %+5.1f deg%s" % [i / float(Engine.physics_ticks_per_second), c.speed_kmh(), c.gear_name(), c.rpm, c.angular_velocity.y, rad_to_deg(beta), s]
		if i == 240 and c.box.auto == false: c._shift(1)
	Input.action_release("move_forward"); Input.action_release("sprint")
	print("TT launch %-6s heading change %+.1f deg, peak yaw %.2f rad/s, peak tail-out %.1f deg%s" % [diff, rad_to_deg(wrapf(c.global_rotation.y - yaw0, -PI, PI)), max_yaw, rad_to_deg(max_beta), line])
	c.queue_free()
	for i in 10: await get_tree().physics_frame
