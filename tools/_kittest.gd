extends Node
## Headless: the engine kit (every block x head x fuel builds, stats, faults), and body cuts, trays, bonnet and tub
## on a real pickup. Add as PT="*res://tools/_kittest.gd" under Settings=.
func _ready():
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	for _i in 30: await get_tree().physics_frame
	var main = get_tree().current_scene
	# ---- every combination builds
	var t0 := Time.get_ticks_msec()
	var n := 0; var faults := {}
	for lay in EngineKit.BLOCKS:
		for big in [false, true]:
			for vt in EngineKit.VALVETRAIN:
				for comp in EngineKit.COMP:
					for fuel in EngineKit.FUELS:
						var k := EngineKit.make(lay, big, vt, comp, fuel)
						var node := EngineKit.build_node(k)
						var st := EngineKit.stats(k)
						var f := EngineKit.fault(k)
						faults[f] = faults.get(f, 0) + 1
						node.free()
						n += 1
	print("KITTEST %d builds in %d ms; faults: %s" % [n, Time.get_ticks_msec() - t0, faults])
	for spec in [["i4", false, "flat", "med", "carby"], ["i4", false, "dohc", "hi", "tb"], ["v8", true, "push", "med", "carby"], ["i6", true, "sohc", "hi", "mech"], ["v6", false, "dohc", "med", "tb"], ["i3", false, "sohc", "med", "carby"]]:
		var k := EngineKit.make(spec[0], spec[1], spec[2], spec[3], spec[4])
		var st := EngineKit.stats(k)
		var pk := 0.0; var pr := 0
		for c in st.curve:
			var kw: float = float(c[1]) * float(c[0]) / 9549.0
			if kw > pk: pk = kw; pr = int(c[0])
		print("KITTEST %-34s peak %3d Nm, ~%3d kW at %d, redline %d, %d kg, pings %.1f, sound %s" % [st.name, int(st.curve[3][1]), int(pk), pr, st.redline, st.kg, EngineKit.pings(k), st.sound])
	# rules
	var k2 := EngineKit.make("i4", false, "sohc", "med", "mech")
	print("KITTEST diesel pump on a medium head: ", EngineKit.fault(k2))
	k2 = EngineKit.make("i4", false, "sohc", "hi", "tb"); k2.ecu = EngineKit.ecu_id(true, 4)
	print("KITTEST petrol EFI with a diesel ECU: ", EngineKit.fault(k2))
	k2 = EngineKit.make("v8", false, "push", "med", "carby"); k2.ign = ""
	print("KITTEST carby, no dizzy: ", EngineKit.fault(k2))
	k2 = EngineKit.make("v8", false, "push", "med", "carby"); k2.heads[1] = EngineKit.head_id(6, "push", "med")
	print("KITTEST V8 with a six-cylinder head on one bank: ", EngineKit.fault(k2))
	print("KITTEST items: %d part ids, e.g. %s / %s" % [EngineKit.all_items().size(), Items.def("eh_4_dohc_hi").name, Items.def("ecu_d_6").name])
	# ---- a pickup: kit engine, cut lines, tray, bonnet, tub
	var p = main.player
	var glb := str(Car.catalog()["redpickup"].glb)
	BodyCut.all()
	BodyCut._cuts[glb] = {"tub": {"mode": "plane", "z": -0.55, "tilt": 0.0, "y": 0.6},
		"bonnet": {"pts": [[-0.72, 0.28, 1.2], [0.72, 0.28, 1.2], [0.78, 0.22, 1.9], [0.7, 0.15, 2.3], [-0.7, 0.15, 2.3], [-0.78, 0.22, 1.9]], "hinge": "rear"}}
	BodyCut._cache.clear()
	var t1 := Time.get_ticks_msec()
	var pcs := BodyCut.pieces(glb, true, true)
	print("KITTEST cut %s in %d ms: cab %d, tub %d, bonnet %d, underside %d meshes" % [glb, Time.get_ticks_msec() - t1, pcs.cab.size(), pcs.tub.size(), pcs.bonnet.size(), pcs.under.size()])
	var d := VehicleSpecs.default_design("redpickup")
	d.tub = "tray"
	d.tray = {"type": "alloy", "boxes": "gullwing", "canopy": true, "jerry": true, "tank": true, "lights": "seq", "sides": true, "head": true, "rack": true}
	var c: Car = main.spawn_vehicle("redpickup", p.global_position + p.global_transform.basis.x * 5.0 + Vector3.UP, 0.0, d)
	for _i in 30: await get_tree().physics_frame
	print("KITTEST car engine: %s | fault '%s' | tray sides %d doors %d brake lamps %d seq %d | tub_front %.2f" % [c.eng.name, EngineKit.fault(c.design.kit), c.tray.sides.size(), c.tray.doors.size(), c.tray.brake.size(), c.tray.seq.size(), c.tub_front])
	print("KITTEST bonnet pivot: ", c.bonnet_pivot != null, " children ", c.bonnet_pivot.get_child_count() if c.bonnet_pivot else 0)
	c.toggle_bonnet(); c.sides_down = true; c.doors_open = true
	for _i in 60: await get_tree().process_frame
	print("KITTEST bonnet open %.2f rot %.1f deg" % [c.bonnet_open, rad_to_deg(c.bonnet_pivot.rotation.x)])
	var rb := c.take_off_bonnet()
	print("KITTEST bonnet off: ", rb != null, " design ", c.design.get("bonnet_off"))
	await get_tree().process_frame
	print("KITTEST bonnet back on: ", c.refit_bonnet())
	c.design.tub = "stock"; c.rebuild_body()
	await get_tree().process_frame
	var tubrb := c.unbolt_tub()
	print("KITTEST tub off: ", tubrb != null, " tub=", c.design.tub, " tub_front ", snappedf(c.tub_front, 0.01))
	await get_tree().process_frame
	print("KITTEST tub back on: ", c.bolt_tub(), " tub=", c.design.tub)
	c.build_tray({"type": "steel", "boxes": "tapered", "lights": "round", "spare": true})
	await get_tree().process_frame
	print("KITTEST steel tray built: ", not c.tray.is_empty())
	# 0.2.56: a workhorse tub onto the AA-160 (both with tub lines)
	var wglb := str(Car.catalog()["r24workhorse"].glb)
	BodyCut._cuts[wglb] = {"tub": {"mode": "plane", "z": -0.4, "tilt": 0.0, "y": 0.6}}
	BodyCut._cuts["flatbed"] = {"tub": {"mode": "plane", "z": -0.3, "tilt": 0.0, "y": 0.6}}
	BodyCut._cache.clear()
	var wk: Car = main.spawn_vehicle("r24workhorse", p.global_position + p.global_transform.basis.x * 14.0 + Vector3.UP, 0.0)
	var fb: Car = main.spawn_vehicle("flatbed", p.global_position + p.global_transform.basis.x * 22.0 + Vector3.UP, 0.0)
	for _i in 20: await get_tree().physics_frame
	var wt := wk.unbolt_tub()
	print("KITTEST AA-160 length %.1f m; workhorse tub off: %s" % [float(fb.def.ext[0]), wt != null])
	var ft := fb.unbolt_tub()
	await get_tree().process_frame
	if ft: ft.global_position += Vector3(0, 0, 30)          # its own tub out of the way
	if wt: wt.global_position = fb.global_position + Vector3(0, 2, -4)
	print("KITTEST workhorse tub on the AA-160: ", fb.bolt_tub(), " tub=", fb.design.tub, " from ", fb.design.get("tub_from", ""))
	# take parts off the engine through the rules
	var k: Dictionary = c.design.kit
	k.fuel = ""
	c.refresh_engine()
	print("KITTEST no fuel system: ", CarCare.blocked(c))
	k.fuel = "ef_carby"; k.ign = "ign_dizzy"; k.alt = false
	c.refresh_engine()
	print("KITTEST back together: '%s' (%s)" % [CarCare.blocked(c), EngineKit.describe(k)])
	get_tree().quit()
