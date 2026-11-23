extends Node
## 0.2.72 soft ground, headless: each strip, a road-tyred ute aired up (32 psi) and down (14), and a 4x4 on mud
## terrains; full throttle for 10 s from a standstill. Prints how far it got, how deep the tyres sank, bellied or not
var dummy: StaticBody3D
func height_at(_x: float, _z: float) -> float: return 0.0

func run(kind: String, sg: SoftGround, car_key: String, psi: float, wm: String) -> void:
	var d := VehicleSpecs.default_design(car_key)
	d["tyre_psi"] = psi
	if wm != "":
		d["wheel_model"] = wm
		for a in d.axles: (a as Dictionary).erase("wheel_model")
	var c := Car.new(); c.design = d
	add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), sg.global_position + Vector3(6.0, 1.2, 2.5))      # nose along the strip (+X)
	for i in 180: await get_tree().physics_frame
	var p0 := c.global_position
	c.driver = dummy
	c.running = true
	if c.box.auto: c.gear = 3
	else: c.gear = 2
	Input.action_press("move_forward")
	var maxsink := 0.0; var bel := 0.0; var t_stuck := 0.0
	for i in 1200:
		await get_tree().physics_frame
		for w in c.wheels:
			maxsink = maxf(maxsink, float(w.sink)); bel = maxf(bel, float(w.belly))
		if i > 240 and c.linear_velocity.length() < 0.3: t_stuck += 1.0 / 120.0
	var em := 0
	for rp in c._roost_p: if (rp as CPUParticles3D).emitting: em += 1
	var om := ""
	for w in c.wheels: om += "%.1f/%.1f " % [float(w.omega) * float(w.r), float(w.vx)]
	print("SOFT   roost emitting %d of %d, tread/ground speeds %s" % [em, c._roost_p.size(), om])
	Input.action_release("move_forward")
	c.driver = null
	var dist := (c.global_position - p0).length()
	print("SOFT %-11s %-10s %4.0f psi tread %.2f: %5.1f m in 10 s, %4.1f km/h at the end, deepest %.2f m, bellied %.1f, stuck %.1f s" % [kind, car_key, psi, c.tread_k(), dist, c.linear_velocity.length() * 3.6, maxsink, bel, t_stuck])
	c.queue_free()
	for i in 5: await get_tree().physics_frame

func _ready():
	await get_tree().process_frame
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(800, 2, 800); cs.shape = b; cs.position.y = -1; g.add_child(cs); add_child(g)
	dummy = StaticBody3D.new(); add_child(dummy); dummy.position = Vector3(0, -50, 0)
	var strips := {}
	var z := 0.0
	for k in ["mud", "soft_sand", "packed_sand", "wet_sand"]:
		for rep in 4:                 # a fresh strip for each run
			var sg := SoftGround.new(); sg.kind = k; add_child(sg); sg.global_position = Vector3(0, 0, z); sg.build(self)
			strips[k + str(rep)] = sg
			z += 8.0
	var only := OS.get_environment("SOFT_ONLY")
	for k in ["mud", "soft_sand", "packed_sand", "wet_sand"]:
		if only != "" and not k.begins_with(only): continue
		await run(k, strips[k + "0"], "vhute", 32.0, "")
		await run(k, strips[k + "1"], "vhute", 14.0, "")
		await run(k, strips[k + "2"], "redpickup", 26.0, "offroad_mt")
		await run(k, strips[k + "3"], "redpickup", 15.0, "offroad_mt")
	print("SOFT_DONE")
	get_tree().quit()
