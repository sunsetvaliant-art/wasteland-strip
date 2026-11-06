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
		elif mode == "rig":
			# cab lifted off: a low Forge camera beside the bare chassis, a[2] = side offset, a[3] = height, a[4] = hide cab
			if not main.forge.active: main.forge.toggle()
			main.forge._set_palette(false)
			main.forge.ui.visible = false
			var c = main.car
			if a.size() > 4 and a[4] == "1": c.get_node("Cab").visible = false
			var f = main.forge
			var xf: Transform3D = c.global_transform
			f.cam.global_position = xf * Vector3(float(a[2]), float(a[3]), float(a[5]) if a.size() > 5 else 0.6)
			f.cam.look_at(xf * Vector3(0, 0.45, 0.2))
			f.yaw = f.cam.rotation.y; f.pitch = f.cam.rotation.x
			for _i in 8: await get_tree().physics_frame
		elif mode in ["fpgun", "tpgun"]:
			# a[6] gun index, a[7] aim (1 = down the sights)
			p.first_person = mode == "fpgun"
			p._apply_camera()
			p._select(int(a[6]) if a.size() > 6 else 0)
			if a.size() > 7 and a[7] == "1": Input.action_press("aim")
			for _i in 40: await get_tree().physics_frame
		elif mode == "npcs":
			# a[6] kind, a[7] count, a[8] distance in front, then wait a[9] frames
			var fwd: Vector3 = -p.global_transform.basis.z
			for i in int(a[7]):
				var n := NPC.new()
				n.kind = a[6]
				var pos: Vector3 = p.global_position + fwd * float(a[8]) + p.global_transform.basis.x * ((i - (int(a[7]) - 1) * 0.5) * 1.6)
				pos.y = main.height_at(pos.x, pos.z) + 0.1
				main.add_child(n)
				n.global_position = pos
				n.look_at(Vector3(p.global_position.x, pos.y, p.global_position.z), Vector3.UP)
				n.face_dir = (p.global_position - pos).normalized()
				n.home = pos
				n.goal = pos
			for _i in int(a[9]): await get_tree().physics_frame
		elif mode == "shoot":
			# fire the current gun a[6] times at the nearest NPC's a[7] ("chest"/"head") and wait
			for k in int(a[6]):
				var best = null
				for n in get_tree().get_nodes_in_group("npcs"):
					if best == null or n.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position): best = n
				if best == null: break
				var tgt: Vector3 = best.rig.bone_pos("Head" if a[7] == "head" else "Spine2")
				var g = p.gun()
				g.cool = 0; g.cycling = 0; g.reloading = 0
				g.fire(p.cam_fp.global_position if p.first_person else p.head.global_position, (tgt - (p.cam_fp.global_position if p.first_person else p.head.global_position)).normalized(), 0.0)
				for _i in 20: await get_tree().physics_frame
			for _i in int(a[8]): await get_tree().physics_frame
		elif mode == "runover":
			# zombies in a line on the road ahead of the car, then floor it
			var c = main.car
			var fwd: Vector3 = c.global_transform.basis.z
			for i in 4:
				var n := NPC.new()
				n.kind = "zombie"
				var pos: Vector3 = c.global_position + fwd * (22.0 + i * 2.0) + c.global_transform.basis.x * randf_range(-0.8, 0.8)
				pos.y = main.height_at(pos.x, pos.z) + 0.1
				main.add_child(n)
				n.global_position = pos
			if p.vehicle == null:
				p.global_position = c.global_position + Vector3(1, 0, 0)
				p._try_get_in()
			c.gear = 3
			Input.action_press("move_forward")
			for _i in int(a[6]): await get_tree().physics_frame
			Input.action_release("move_forward")
			Input.action_press("move_back")
			for _i in int(a[7]): await get_tree().physics_frame
			Input.action_release("move_back")
		elif mode == "garage":
			# a[6]: "bare" = cab off, "6x6" = third axle
			main.garage.show_garage(VehicleSpecs.default_design(a[7] if a.size() > 7 else "ftruck"))
			if a.size() > 6 and a[6].contains("6x6"):
				var last: Dictionary = main.garage.design.axles[-1].duplicate(true)
				last.z = float(last.z) - 1.35
				main.garage.design.axles.append(last)
				main.garage.design.frame.len += 1.4
				main.garage.design.frame.z -= 0.7
			if a.size() > 6 and a[6].contains("bare"): main.garage.cab_on = false
			main.garage._build_ui()
			main.garage._rebuild()
			main.garage.orbit = Vector2(float(a[4]), float(a[5]))
			for _i in 30: await get_tree().physics_frame
			for _i in 30: await get_tree().process_frame
			var gc: Camera3D = get_viewport().get_camera_3d()
			var pv = main.garage.preview
			print("SHOT garage cam ", gc.global_position, " garage? ", gc == main.garage.cam, " preview ", pv.global_position, " visible ", pv.is_visible_in_tree(), " rig children ", pv.parts.get_child_count(), " in view ", gc.is_position_in_frustum(pv.global_position))
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
