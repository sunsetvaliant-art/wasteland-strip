extends Node
## Test harness: loaded as an extra autoload in test runs only. Waits for the world, poses the camera, saves screenshots.
## env SHOT_PLAN = "name:mode:x:z:yaw:pitch;..." mode = foot | car | carcab | drive
var out := OS.get_environment("SHOT_OUT") if OS.get_environment("SHOT_OUT") != "" else "/tmp/shots/"
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
		if mode == "mphost" or mode == "mpjoin":
			# LAN test: a[2] = frames to run. Host hosts; join joins 127.0.0.1, walks forward and shoots the nearest puppet
			if mode == "mphost":
				main.net.my_name = "Host"
				print("MPTEST host: ", main.net.host())
			else:
				main.net.my_name = "Joiner"
				p.global_position += Vector3(4, 0, 0)
				print("MPTEST join: ", main.net.join("127.0.0.1"))
			var shot_done := false
			for f in int(a[2]):
				await get_tree().physics_frame
				if f % 120 == 0:
					var pups := 0
					for id in main.net.npcs:
						var n = main.net.npcs[id]
						if is_instance_valid(n) and n.get("puppet"): pups += 1
					var rps := []
					for id in main.net.players:
						var rp = main.net.players[id]
						if is_instance_valid(rp): rps.append([rp.display_name, rp.global_position.round(), rp.gun_key])
					print("MPTEST %s f=%d online=%s players=%s npcs=%d puppets=%d status=%s conn=%s same=%s" % [mode, f, main.net.online(), rps, main.net.npcs.size(), pups, main.net.status,
						main.net.peer.get_connection_status() if main.net.peer else -1, main.net.multiplayer.multiplayer_peer == main.net.peer])
				if mode == "mpjoin" and f == int(a[2]) - 240 and not shot_done:
					shot_done = true
					var best = null
					for id in main.net.npcs:
						var n = main.net.npcs[id]
						if is_instance_valid(n) and not n.dead and (best == null or n.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position)): best = n
					if best:
						print("MPTEST shooting puppet ", best.net_id, " at ", best.global_position.distance_to(p.global_position))
						best.take_hit({"head": 400.0}, Vector3.FORWARD, best.global_position + Vector3.UP * 1.6, 10.0, p)
			continue
		if mode == "probe2":
			# stand where a bug report was (a[2], a[3]) and fire level rays all round at knee, chest and head height
			p.global_position = Vector3(float(a[2]), main.height_at(float(a[2]), float(a[3])) + 1.0, float(a[3]))
			for _i in 120: await get_tree().physics_frame
			var space2: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
			var hits := {}
			for hgt in [0.5, 1.2, 1.7]:
				for deg in range(0, 360, 2):
					var dir := Vector3(sin(deg_to_rad(deg)), 0, cos(deg_to_rad(deg)))
					var o: Vector3 = p.global_position + Vector3(0, hgt - 0.9, 0)
					var q := PhysicsRayQueryParameters3D.create(o, o + dir * 70.0)
					q.exclude = [p.get_rid()]
					var h := space2.intersect_ray(q)
					if h:
						var c: Node = h.collider
						var gy: float = main.height_at(h.position.x, h.position.z)
						var k := "%s|%s" % [c.get_path() if c else "?", c.get_class() if c else ""]
						if not hits.has(k): hits[k] = [0, h.position, gy, deg, hgt]
						hits[k][0] += 1
			for k in hits:
				print("PROBE2 ", hits[k][0], " ", k, " first at ", hits[k][1], " ground ", snappedf(hits[k][2], 0.01), " deg ", hits[k][3], " h ", hits[k][4])
			continue
		if mode == "probe":
			# look for collision sticking up above the ground: rays straight down over a box of the map (a[2..5] = x0 z0 x1 z1)
			for _i in 60: await get_tree().physics_frame
			var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
			var found := {}
			var x0 := float(a[2]); var z0 := float(a[3]); var x1 := float(a[4]); var z1 := float(a[5])
			var x := x0
			while x <= x1:
				var z := z0
				while z <= z1:
					var g: float = main.height_at(x, z)
					var q := PhysicsRayQueryParameters3D.create(Vector3(x, g + 8.0, z), Vector3(x, g - 2.0, z))
					q.collision_mask = 0xFFFFFFFF
					var h := space.intersect_ray(q)
					if h and h.position.y > g + 0.6:
						var c: Node = h.collider
						var key := str(c.get_path()) if c else "?"
						if not found.has(key): found[key] = [0, Vector3(x, h.position.y, z), g, c.get_class() if c else ""]
						found[key][0] += 1
					z += 2.0
				x += 2.0
			for k in found:
				print("PROBE ", found[k][0], " ", k, " ", found[k][3], " at ", found[k][1], " ground ", snappedf(found[k][2], 0.01))
			print("PROBE done ", found.size())
			continue
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
		elif mode == "mpmenu":
			main.pause_menu.show_menu()
			main.pause_menu.mp_panel.visible = true
			main.net.found["192.168.1.23"] = {"name": "Dave", "version": Boot.version, "players": 2, "t": Time.get_ticks_msec() + 100000}
			main.pause_menu._refresh_mp()
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
			var dist := float(OS.get_environment("SHOWCASE_DIST")) if OS.get_environment("SHOWCASE_DIST") != "" else 4.5
			var xs := 0.0
			var made := []
			for i in keys.size():
				var path: String = keys[i]
				var pos: Vector3 = f.cam.global_position + fwd * dist
				var n = f.spawn({"type": "prop", "key": path.get_file().get_basename(), "name": path, "path": path}, Transform3D(Basis(Vector3.UP, f.yaw + PI * 0.5), pos))
				var w: float = max(f._aabb(n).size.x, f._aabb(n).size.z) if n else 1.0
				made.append([n, w])
				xs += w + 0.4
			var cur := -xs * 0.5
			for m in made:
				if m[0] == null: continue
				var pos2: Vector3 = f.cam.global_position + fwd * dist + right * (cur + m[1] * 0.5)
				pos2.y = main.height_at(pos2.x, pos2.z) + 0.05
				m[0].global_position = pos2
				cur += m[1] + 0.4
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
			if a.size() > 6 and not a[6].is_valid_int():
				var st := Items.fresh("gun_" + a[6])
				p.inv.set_slot("primary", st)
				p._select(0)
			else:
				p._select(int(a[6]) if a.size() > 6 else 0)
			if a.size() > 7 and a[7] == "1": Input.action_press("aim")
			for _i in 40: await get_tree().physics_frame
		elif mode == "cam":
			# free camera: x z are the camera, a[4] a[5] the point to look at (y from the ground)
			var fc := Camera3D.new()
			fc.far = 48000.0
			main.add_child(fc)
			var tx := float(a[4]); var tz := float(a[5])
			var ty: float = main.height_at(tx, tz)
			fc.look_at_from_position(Vector3(float(a[2]), ty + float(a[6]), float(a[3])), Vector3(tx, ty, tz), Vector3.UP)
			fc.current = true
			for _i in 20: await get_tree().process_frame
		elif mode == "cam2":
			# camera a[6] m above its own ground at (a[2], a[3]) looking at a point 1 m above the ground at (a[4], a[5])
			p.global_position = Vector3(float(a[2]), main.height_at(float(a[2]), float(a[3])) + 1.0, float(a[3])) + Vector3(0, 0, 6)
			for _i in 90: await get_tree().physics_frame
			var fc5 := Camera3D.new(); fc5.far = 48000.0; main.add_child(fc5)
			var cx := float(a[2]); var cz := float(a[3]); var tx2 := float(a[4]); var tz2 := float(a[5])
			fc5.look_at_from_position(Vector3(cx, main.height_at(cx, cz) + float(a[6]), cz), Vector3(tx2, main.height_at(tx2, tz2) + 1.0, tz2), Vector3.UP)
			fc5.current = true
			for _i in 30: await get_tree().process_frame
		elif mode == "env":
			# a[2] time of day, a[3] weather: set at once
			main.sky.tod = float(a[2])
			main.sky.set_weather(a[3], 900.0)
			main.sky.cloud = main.sky._target_cloud(); main.sky.rain = main.sky._target_rain(); main.sky.fogd = main.sky._target_fog()
			for _i in 30: await get_tree().process_frame
			continue
		elif mode == "servo":
			var L = main.landmarks
			var best = null
			for sp in L.spots:
				if sp.kind == "ampol_servo" and (best == null or Vector2(sp.x, sp.z).distance_to(Vector2(main.PUB.x, main.PUB.z)) < Vector2(best.x, best.z).distance_to(Vector2(main.PUB.x, main.PUB.z))): best = sp
			var sxf := Transform3D(Basis(Vector3.UP, float(best.yaw)), Vector3(float(best.x), 0, float(best.z)))
			var fp: Vector3 = sxf * Vector3(0, 0, 22)
			p.global_position = Vector3(fp.x, main.height_at(fp.x, fp.z) + 1.0, fp.z)
			for _i in 300:
				await get_tree().physics_frame
				if best.node != null: break
			for _i in 200: await get_tree().physics_frame
			sxf = best.node.global_transform
			var fc4 := Camera3D.new(); fc4.far = 48000.0; fc4.fov = 72; main.add_child(fc4)
			print("SHOT servo at ", best.x, ",", best.z, " node ", best.node)
			if a[2] == "out": fc4.look_at_from_position(sxf * Vector3(6, 3, 18), sxf * Vector3(0, 2, 0), Vector3.UP)
			elif a[2] == "shop": fc4.look_at_from_position(sxf * Vector3(-0.6, 1.7, 1.2), sxf * Vector3(-6, 0.8, -4.5), Vector3.UP)
			else: fc4.look_at_from_position(sxf * Vector3(2.0, 1.8, 1.0), sxf * Vector3(6, 0.6, -4.5), Vector3.UP)
			fc4.current = true
			for _i in 30: await get_tree().process_frame
		elif mode == "bld":
			# a generated building of kind a[2] (nth nearest the pub: a[4]); view a[3] = out | in | far
			var B = main.buildings
			var cands := []
			for i in B.lots.size():
				if a[2] == "" or B.lots[i][0] == a[2]:
					cands.append([Vector2(float(B.lots[i][1]) - main.PUB.x, float(B.lots[i][2]) - main.PUB.z).length(), i])
			cands.sort()
			var bi: int = cands[int(a[4]) if a.size() > 4 else 0][1]
			var bp: Dictionary = B._plan(bi)
			var bxf: Transform3D = B._xf(bi, bp)
			var outp: Vector3 = bxf * Vector3(0, 0, float(bp.d) / 2 + 14.0)
			p.global_position = Vector3(outp.x, main.height_at(outp.x, outp.z) + 1.0, outp.z)
			for _i in 400:
				await get_tree().physics_frame
				if B.full.has(bi): break
			for _i in 60: await get_tree().physics_frame
			print("SHOT bld ", bi, " ", B.lots[bi], " full=", B.full.has(bi), " fulls=", B.full.size(), " lods=", B.lod.size())
			var fc3 := Camera3D.new()
			fc3.far = 48000.0
			fc3.fov = 72
			main.add_child(fc3)
			var big: float = maxf(float(bp.w), float(bp.d))
			if a[3] == "out":
				fc3.look_at_from_position(bxf * Vector3(big * 0.7, 3.0, big * 1.1), bxf * Vector3(0, 2.0, 0), Vector3.UP)
			elif a[3] == "far":
				fc3.look_at_from_position(bxf * Vector3(big * 3, 40.0, big * 9), bxf * Vector3(0, 0, 0), Vector3.UP)
			else:
				var rr: Dictionary = {}
				for r in bp.floors[0].rooms:
					if r.type in ["lounge", "kitchen", "shed", "workshop", "warehouse", "milking"]: rr = r; break
				if rr.is_empty(): rr = bp.floors[0].rooms[0]
				var eye := Vector3(float(rr.x0) + 0.4, 1.6, float(rr.z1) - 0.4)
				var at := Vector3(float(rr.x1) - 0.4, 0.8, float(rr.z0) + 0.4)
				fc3.look_at_from_position(bxf * eye, bxf * at, Vector3.UP)
			fc3.current = true
			for _i in 30: await get_tree().process_frame
		elif mode == "campcam":
			# a camera over the nearest scav camp (a[6] = height), once it's been built
			p.global_position = main.camps.sites[0].pos + Vector3(30, 2, 0)
			for _i in 200: await get_tree().physics_frame
			var cc: Vector3 = main.camps.sites[0].pos
			var fc2 := Camera3D.new()
			fc2.far = 48000.0
			main.add_child(fc2)
			fc2.look_at_from_position(cc + Vector3(18, float(a[6]), 22), cc, Vector3.UP)
			fc2.current = true
			for _i in 60: await get_tree().process_frame
		elif mode == "inv":
			main.inv_ui.show_with(null)
			for _i in 10: await get_tree().process_frame
		elif mode == "box":
			var fwd2: Vector3 = -p.global_transform.basis.z
			var bx = main.forge.spawn({"type": "prop", "key": "old_military_crate", "name": "Military crate", "path": "res://assets/ph/weapons/old_military_crate/old_military_crate.gltf"}, Transform3D(Basis(), p.global_position + fwd2 * 1.5 + Vector3(0, 0.3, 0)))
			for _i in 30: await get_tree().physics_frame
			main.inv_ui.show_with(bx)
			for _i in 10: await get_tree().process_frame
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
		elif mode == "camp":
			# stand a[6] m off the nearest camp to the pub, looking at it, from the shoulder
			if main.camps.sites.is_empty(): main.camps._picked = true; main.camps._pick_sites()
			var site = main.camps.sites[0]
			if site.built == null: main.camps._build(site)
			var c: Vector3 = site.pos
			var off := Vector3(float(a[6]), 0, float(a[6]) * 0.4)
			p.global_position = Vector3(c.x + off.x, main.ground_at(c.x + off.x, c.z + off.z) + 0.2, c.z + off.z)
			var to: Vector3 = c - p.global_position
			p.yaw = atan2(-to.x, -to.z); p.body_yaw = p.yaw; p.pitch = -0.12
			p.first_person = false; p._apply_camera()
			for _i in 120: await get_tree().physics_frame
		elif mode == "scope":
			p.first_person = true; p._apply_camera()
			p._select(Gun.ORDER.find("enfield"))
			Input.action_press("aim")
			for _i in 60: await get_tree().physics_frame
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
		if main.veg:
			for ln in main.veg.layers:
				var cnt := 0
				for k in main.veg.layers[ln].cells:
					var nd = main.veg.layers[ln].cells[k]
					if nd: for mmi in nd.get_children(): if mmi is MultiMeshInstance3D: cnt += mmi.multimesh.instance_count
				if ln == "scan" or ln == "grass":
					var cam3 := get_viewport().get_camera_3d()
					for k in main.veg.layers[ln].cells:
						var nd = main.veg.layers[ln].cells[k]
						if nd and nd.get_child_count() > 0:
							var mmi = nd.get_child(0)
							var o: Vector3 = mmi.multimesh.get_instance_transform(0).origin
							break
				print("VEG ", ln, " cells ", main.veg.layers[ln].cells.size(), " inst ", cnt, " r ", main.veg.layers[ln].r)
		print("WHEELS ", main.car.wheels.map(func(w): return [w.kind, snappedf(w.mu, 0.01), snappedf(w.slipv, 0.1), snappedf(w.defl, 0.001)]))
		if main.road_pilot and main.road_pilot.get("container"):
			var ms: Array = (main.road_pilot.get("container") as Node).find_children("*", "MeshInstance3D", true, false)
			var cam4 := get_viewport().get_camera_3d()
			var near_d := 1e9
			var near_aabb := AABB()
			for mmi in ms:
				var ab: AABB = (mmi as MeshInstance3D).global_transform * (mmi as MeshInstance3D).get_aabb()
				var dd := ab.get_center().distance_to(cam4.global_position)
				if dd < near_d:
					near_d = dd
					near_aabb = ab
			print("PILOTDBG meshes ", ms.size(), " vis ", (ms[0] as MeshInstance3D).is_visible_in_tree() if ms.size() else false, " nearest ", near_aabb, " d ", near_d, " cam ", cam4.global_position, " layers ", (ms[0] as MeshInstance3D).layers if ms.size() else 0, " mat ", (ms[0] as MeshInstance3D).get_surface_override_material(0) if ms.size() else null)
		print("SHOT ", nm, " fps ", Engine.get_frames_per_second(), " car ", main.car.global_position, " v ", main.car.speed_kmh())
	get_tree().quit()
