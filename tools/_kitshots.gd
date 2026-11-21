extends Node
## Screenshots for 0.2.55: the engine kit lineup, trays, an open bonnet with its bay, and the F9 fix spots.
## Run under xvfb (GL) as PT="*res://tools/_kitshots.gd". ST_ONLY=name,name limits it. Writes /tmp/shots/k_<name>.png
var out := "/tmp/shots/"
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var main = get_tree().current_scene
	for _i in 20: await get_tree().physics_frame
	var only := OS.get_environment("ST_ONLY").split(",", false)
	var f = main.forge
	if not f.active: f.toggle()
	f._set_palette(false)
	f.ui.visible = false
	if SkyCycle.inst:
		SkyCycle.inst.set_manual(0.42, 0.0); SkyCycle.inst.frozen = true
	var p = main.player
	var base := Vector3(-700.0, 0.0, -60.0)          # out in the main street (the player starts inside the pub)
	base.y = main.height_at(base.x, base.z)
	f.cam.global_position = base + Vector3(0, 3, 6)
	for _i in 120: await get_tree().process_frame
	# the lineup: five engines on a slab
	var lineup := Node3D.new()
	main.add_child(lineup)
	lineup.global_position = base + Vector3(0, 0.6, 0)
	var specs := [["i3", false, "sohc", "med", "carby"], ["i4", false, "dohc", "hi", "tb"], ["i6", true, "push", "med", "carby"], ["v6", false, "dohc", "med", "tb"], ["v8", true, "push", "med", "carby"], ["i6", true, "sohc", "hi", "mech"], ["v8", false, "flat", "med", "carby"]]
	for i in specs.size():
		var s: Array = specs[i]
		var n := EngineKit.build_node(EngineKit.make(s[0], s[1], s[2], s[3], s[4]))
		n.position = Vector3(i * 1.0 - 3.0, 0, 0)
		n.rotation.y = 0.5
		lineup.add_child(n)
	# a pickup with a tray, and one with its bonnet up
	var glb := str(Car.catalog()["redpickup"].glb)
	BodyCut.all()
	BodyCut._cuts[glb] = {"tub": {"mode": "plane", "z": -0.55, "tilt": 0.0, "y": 0.6},
		"bonnet": {"pts": [[-0.72, 0.28, 1.2], [0.72, 0.28, 1.2], [0.78, 0.22, 1.9], [0.7, 0.15, 2.3], [-0.7, 0.15, 2.3], [-0.78, 0.22, 1.9]], "hinge": "rear"}}
	BodyCut._cache.clear()
	var d := VehicleSpecs.default_design("redpickup")
	d.tub = "tray"
	d.tray = {"type": "alloy", "boxes": "gullwing", "canopy": false, "jerry": true, "tank": true, "lights": "seq", "sides": true, "head": true, "rack": true}
	var c1: Car = main.spawn_vehicle("redpickup", base + Vector3(0, 1.2, 8), PI * 0.75, d)
	var d2 := VehicleSpecs.default_design("redpickup")
	d2.tub = "tray"
	d2.tray = {"type": "steel", "boxes": "tapered", "canopy": true, "lights": "round", "spare": true}
	var c2: Car = main.spawn_vehicle("redpickup", base + Vector3(5, 1.2, 8), PI * 0.75, d2)
	for _i in 40: await get_tree().physics_frame
	c1.freeze = true; c2.freeze = true
	c1.sides_down = false
	c2.doors_open = true
	c1.toggle_bonnet()
	for _i in 60: await get_tree().process_frame
	var lp: Vector3 = lineup.global_position
	var cp1: Vector3 = c1.global_position
	var cp2: Vector3 = c2.global_position
	var shots := [
		["lineup", lp + Vector3(0.3, 1.3, 3.4), lp + Vector3(0, 0.2, 0)],
		["lineup_close", lp + Vector3(1.3, 0.9, 1.4), lp + Vector3(1.0, 0.25, 0)],
		["tray_alloy", cp1 + c1.global_transform.basis * Vector3(3.2, 1.6, -4.0), cp1 + c1.global_transform.basis * Vector3(0, 0.6, -1.4)],
		["bonnet_open", cp1 + c1.global_transform.basis * Vector3(1.6, 2.0, 4.0), cp1 + c1.global_transform.basis * Vector3(0, 0.3, 1.5)],
		["tray_steel", cp2 + c2.global_transform.basis * Vector3(-3.4, 1.8, -4.2), cp2 + c2.global_transform.basis * Vector3(0, 0.7, -1.4)],
		# the F9 spots
		["fix_stairs_water", Vector3(-170.6, 0, -100.1), Vector3(-182.5, 0, -113.1)],
		["fix_house_road", Vector3(-188.5, 0, -143.5), Vector3(-184.6, 0, -160.4)],
		["fix_bank_paint", Vector3(-108.5, 0, -151.9), Vector3(-113.0, 0, -153.7)],
		["fix_carpark", Vector3(-337.7, 0, -191.7), Vector3(-342.1, 0, -195.4)],
		["fix_ambulance", Vector3(-337.7, 0, -286.5), Vector3(-340.9, 0, -307.7)],
		["fix_stairs_road", Vector3(-393.0, 0, -264.5), Vector3(-401.5, 0, -273.2)],
		["fix_slab_ramp", Vector3(-750.6, 0, -240.9), Vector3(-753.7, 0, -237.6)],
		["fix_bridge", Vector3(-451.1, 0, -65.8), Vector3(-444.6, 0, -62.3)],
	]
	var heights := {"fix_stairs_water": [4.4, 4.4], "fix_house_road": [7.0, 8.6], "fix_bank_paint": [2.1, 9.3], "fix_carpark": [4.0, 4.75], "fix_ambulance": [4.0, 15.3],
		"fix_stairs_road": [5.5, 7.6], "fix_slab_ramp": [1.7, 7.3], "fix_bridge": [2.5, 6.5]}
	for sh in shots:
		if not only.is_empty() and not (sh[0] in only): continue
		var eye: Vector3 = sh[1]; var at: Vector3 = sh[2]
		if heights.has(sh[0]):
			var hh: Array = heights[sh[0]]
			eye.y = main.height_at(eye.x, eye.z) + float(hh[0])
			at.y = float(hh[1])
			# from the F9 camera: back off a little so the thing is in frame
			eye += (eye - at).normalized() * 6.0
			eye.y += 2.0
		f.cam.global_position = eye
		f.cam.look_at(at)
		f.yaw = f.cam.rotation.y; f.pitch = f.cam.rotation.x
		var t0 := Time.get_ticks_msec()
		for _i in (90 if sh[0].begins_with("fix") else 25): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "k_%s.png" % sh[0])
		print("SHOT k_%s (%d ms)" % [sh[0], Time.get_ticks_msec() - t0])
	get_tree().quit()
