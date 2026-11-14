extends Node
## Headless: can zombies get into houses? Puts the player in a room of several built houses near the start, a
## zombie 14 m out the front, and watches for 40 s. Prints ZHOUSE lines. (autoload in test runs only)
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	for _i in 60: await get_tree().physics_frame
	var p: Player = main.player
	Settings.set_value("god_mode", true)
	var B = Buildings.inst
	var tried := 0; var reached := 0
	var start := Vector3(OS.get_environment("ZX").to_float(), 0, OS.get_environment("ZZ").to_float()) if OS.get_environment("ZX") != "" else p.global_position
	var seen := {}
	for attempt in 6:
		# the nearest house to here that isn't done yet
		var best := -1; var bd := 1e9
		for i in B.lots.size():
			var l: Array = B.lots[i]
			if seen.has(i) or not (str(l[0]) in ["house", "brick", "cottage", "qlder", "two_storey"]): continue
			var d := Vector2(float(l[1]) - start.x, float(l[2]) - start.z).length()
			if d < bd: bd = d; best = i
		if best < 0: break
		seen[best] = true
		if OS.get_environment("ZONLY") != "" and not (str(best) in OS.get_environment("ZONLY").split(",")): continue
		var l: Array = B.lots[best]
		var c := Vector3(float(l[1]), 0, float(l[2]))
		p.global_position = c + Vector3(0, main.height_at(c.x, c.z) + 6.0, 0)
		for _i in 240: await get_tree().physics_frame          # let it build near us
		if not B.full.has(best):
			print("ZHOUSE lot %d %s not built" % [best, l[0]]); continue
		var plan: Dictionary = B.full[best].get_meta("plan")
		var xf: Transform3D = B.full[best].global_transform
		# stand in the middle of the biggest room
		var room = null
		var fl = plan.floors[0]
		for r in fl.rooms:
			if str(r.get("type", "")) in ["void", "verandah", "hall", "under"]: continue
			if room == null or (float(r.x1) - float(r.x0)) * (float(r.z1) - float(r.z0)) > (float(room.x1) - float(room.x0)) * (float(room.z1) - float(room.z0)): room = r
		if room == null: continue
		room["tag"] = room.get("type", "?")
		var lp := Vector3((float(room.x0) + float(room.x1)) * 0.5, float(fl.y) + 0.3, (float(room.z0) + float(room.z1)) * 0.5)
		p.global_position = xf * lp
		p.velocity = Vector3.ZERO
		for _i in 60: await get_tree().physics_frame
		var n := NPC.new()
		n.kind = "zombie"
		main.add_child(n)
		var out: Vector3 = xf * Vector3(0, 0, float(l[5]) * 0.5 + 14.0)
		out.y = main.height_at(out.x, out.z) + 0.2
		n.global_position = out
		n.home = out; n.goal = p.global_position
		n.state = "chase"
		n.last_seen = p.global_position
		tried += 1
		var got := false
		var tmin := 1e9
		for f in 120 * 40:
			await get_tree().physics_frame
			if n.dead: break
			var d := n.global_position.distance_to(p.global_position)
			tmin = minf(tmin, d)
			if d < 1.8: got = true; break
			if f % 240 == 120:
				var rl := []
				for q in n._route: rl.append((xf.affine_inverse() * (q as Vector3)).snapped(Vector3.ONE * 0.1))
				var col := []
				for ci in n.get_slide_collision_count():
					var cc = n.get_slide_collision(ci).get_collider()
					col.append("%s:%s" % [cc.get_class(), cc.name] if cc else "?")
				if OS.get_environment("ZONLY") != "": print("ZDBG t=%ds z=%s vel=%s stuck=%.1f route=%s hits=%s" % [f / 120, (xf.affine_inverse() * n.global_position).snapped(Vector3.ONE * 0.1), n.velocity.snapped(Vector3.ONE * 0.01), n._stuck_t, rl.slice(0, 4), col])
				if false: print("%s%s%s%s%s" % [f / 120, (xf.affine_inverse() * n.global_position).snapped(Vector3.ONE * 0.1), n.velocity.snapped(Vector3.ONE * 0.01), rl, col])
		if got: reached += 1
		for sf in plan.get("flights", []):
			var fw: Vector3 = xf * (sf.foot as Vector3)
			var gy: float = main.height_at(fw.x, fw.z)
			print("ZSTAIR lot %d flight foot local y %.2f, ground under it local y %.2f (gap %.2f m)" % [best, float(sf.foot.y), (xf.affine_inverse() * Vector3(fw.x, gy, fw.z)).y, float(sf.foot.y) - (xf.affine_inverse() * Vector3(fw.x, gy, fw.z)).y])
		print("ZHOUSE lot %d %s room %s: reached=%s closest %.1f m, state %s, route %d pts, zombie at %s" % [best, l[0], room.get("tag", "?"), got, tmin, n.state, n._route.size(), (xf.affine_inverse() * n.global_position).snapped(Vector3.ONE * 0.1)])
		n.queue_free()
	print("ZHOUSE result %d of %d houses reached" % [reached, tried])
	get_tree().quit()
