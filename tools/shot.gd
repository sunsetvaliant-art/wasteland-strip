extends Node
## Test harness: loaded as an extra autoload in test runs only. Waits for the world, poses the camera, saves screenshots.
## env SHOT_PLAN = "name:mode:x:z:yaw:pitch;..." mode = foot | car | carcab | drive
var out := "/tmp/claude-0/-home-claude/b0119dc3-e5bf-538e-a527-b04b73bbc85a/scratchpad/"
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(0.5).timeout
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	for _i in 30: await get_tree().process_frame
	var plan := OS.get_environment("SHOT_PLAN").split(";", false)
	for step in plan:
		var a := step.split(":")
		var nm := a[0]; var mode := a[1]
		var p = main.player
		if a.size() > 3:
			var x := float(a[2]); var z := float(a[3])
			if mode.begins_with("car") or mode == "drive":
				main.car.global_position = Vector3(x, main.height_at(x, z) + 1.2, z)
				main.car.linear_velocity = Vector3.ZERO
			else:
				p.global_position = Vector3(x, main.height_at(x, z) + 0.2, z)
		if a.size() > 4: p.yaw = float(a[4])
		if a.size() > 5: p.pitch = float(a[5])
		if mode.begins_with("car") or mode == "drive":
			if p.vehicle == null:
				p.global_position = main.car.global_position + Vector3(1, 0, 0)
				p._try_get_in()
			if mode == "carcab" and not main.car.cab_view:
				main.car.cab_view = true; main.car.active_camera().current = true; p.camera_changed.emit(main.car.active_camera())
			if mode == "drive":
				main.car.gear = 3
				Input.action_press("move_forward")
				for _i in 360: await get_tree().physics_frame
				Input.action_release("move_forward")
		elif mode == "menu":
			main.pause_menu.show_menu()
			main.pause_menu.settings_panel.visible = true
		elif mode == "forge":
			if main.pause_menu.open: main.pause_menu.close()
			if not main.forge.active: main.forge.toggle()
			var f = main.forge
			f.cam.global_position = Vector3(30, main.height_at(30, 40) + 6, 40)
			f.yaw = PI * 0.75; f.pitch = -0.35
			for _i in 5: await get_tree().process_frame
			var spots = [Vector3(18, 0, 26), Vector3(24, 0, 20), Vector3(12, 0, 22), Vector3(20, 0, 32), Vector3(15, 0, 30)]
			var ents = [{"type":"vehicle","key":"hearse","name":"Hearse"}, {"type":"vehicle","key":"ftruck","name":"F-truck"}, {"type":"prop","key":"drum1","name":"Drum"}, {"type":"prop","key":"wcrate","name":"Crate"}, {"type":"marker","key":"zombie","name":"Zombie"}]
			for i in ents.size():
				var sp: Vector3 = spots[i]
				sp.y = main.height_at(sp.x, sp.z) + (1.2 if ents[i].type == "vehicle" else 0.5)
				f.spawn(ents[i], Transform3D(Basis(Vector3.UP, i * 0.7), sp))
			for _i in 120: await get_tree().physics_frame
			f.selected = {"type":"prop","key":"tyre","name":"Tyre"}
		elif mode == "fcam":
			# Forge camera at x z, looking yaw / pitch, a[6] m above the ground
			if not main.forge.active: main.forge.toggle()
			main.forge._set_palette(false)
			var f = main.forge
			var x := float(a[2]); var z := float(a[3])
			f.cam.global_position = Vector3(x, main.height_at(x, z) + float(a[6]), z)
			f.yaw = float(a[4]); f.pitch = float(a[5])
			f.ui.visible = false
			for _i in 8: await get_tree().physics_frame
		elif mode == "showcase":
			# a row of the new models on the ground in front of the Forge camera
			var f = main.forge
			f.ui.visible = false
			var keys := OS.get_environment("SHOWCASE").split(",")
			var fwd: Vector3 = -f.cam.global_transform.basis.z; fwd.y = 0; fwd = fwd.normalized()
			var right: Vector3 = f.cam.global_transform.basis.x; right.y = 0; right = right.normalized()
			for i in keys.size():
				var path: String = keys[i]
				var pos: Vector3 = f.cam.global_position + fwd * 4.5 + right * ((i - (keys.size() - 1) * 0.5) * 1.15)
				pos.y = main.height_at(pos.x, pos.z) + 0.6
				var n = f.spawn({"type": "prop", "key": path.get_file().get_basename(), "name": path, "path": path}, Transform3D(Basis(Vector3.UP, f.yaw + PI * 0.5), pos))
			for _i in 150: await get_tree().physics_frame
		elif mode == "palette":
			main.forge.ui.visible = true
			main.forge._set_palette(true)
			var tabs: TabContainer = main.forge.palette.get_child(0)
			tabs.current_tab = int(a[2]) if a.size() > 2 else 0
		elif mode == "physgun":
			var f = main.forge
			f._set_palette(false)
			f._set_tool(1)
			var drum = null
			for o in f.objects:
				if o.has_meta("forge") and o.get_meta("forge").key == "wcrate": drum = o
			f.cam.look_at(drum.global_position)
			f.yaw = f.cam.rotation.y; f.pitch = f.cam.rotation.x
			await get_tree().process_frame
			f._grab()
			f.held_dist = 6.0
			for _i in 90: await get_tree().physics_frame
		elif mode == "fp" and not p.first_person:
			p.first_person = true; p._apply_camera()
		for _i in 90: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + nm + ".png")
		print("SHOT ", nm, " fps ", Engine.get_frames_per_second(), " car ", main.car.global_position, " v ", main.car.speed_kmh())
	get_tree().quit()
