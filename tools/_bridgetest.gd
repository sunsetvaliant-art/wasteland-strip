extends Node
## Headless: the step a wheel meets at each bridge end. For every bridge end, three wheel lines (left, centre, right)
## from 6 m on the deck to 30 m out; the surface is the higher of the terrain and the bridge (rays at the bridge
## alone); prints the worst steps. Same test with BRIDGE_OLD=1 measures the old baked decks.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	for _i in 30: await get_tree().physics_frame
	var R: Roads = main.roads
	for t in R.tiles:
		if t.mesh != null and t.body == null: R._make_body(t)
	for t in R.tiles:
		if t.body != null: (t.body as StaticBody3D).collision_layer = 1 << 19
	for _i in 5: await get_tree().physics_frame
	var data: Terrain3DData = main.terrain.data
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	if BridgeKit.bridges.is_empty(): BridgeKit.load_all()
	var res := []
	var dmp := OS.get_environment("BRT_DUMP").split(",")
	var dump := [72 * 2, 38 * 2]
	for bi in BridgeKit.bridges.size():
		var bb: Dictionary = BridgeKit.bridges[bi]
		if Vector2(bb.P[bb.P.size()-1].x - 473.8, bb.P[bb.P.size()-1].z + 468.4).length() < 3.0: dump.append(bi * 2 + 1)
	var bad := 0
	for bi in BridgeKit.bridges.size():
		var b: Dictionary = BridgeKit.bridges[bi]
		for e in 2:
			var en := BridgeKit._end(b, e)
			var c: Vector3 = en[0]; var t: Vector2 = en[1]
			var worst := 0.0
			var wa := 0.0; var wo := 0.0; var wh := []
			for o in [-0.6, 0.0, 0.6]:
				var lat: Vector2 = t.orthogonal() * float(b.hw) * o
				var hs := []
				var a := -4.0
				while a <= 16.0:
					var x: float = c.x + t.x * a + lat.x; var z: float = c.z + t.y * a + lat.y
					var h := _th(data, x, z)
					var top: float = c.y + 3.0 if a < 0.0 else (hs[hs.size() - 1] if not hs.is_empty() else c.y) + 0.6
					var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, top - 14.0, z), 1 << 19)
					var hit := space.intersect_ray(q)
					if not hit.is_empty() and hit.position.y < top - 0.02: h = maxf(h, hit.position.y)
					if dmp.has(str(bi)) and o == 0.0: print("BRD %d/%d a %5.2f terr %.2f hit %s top %.2f" % [bi, e, a, _th(data, x, z), str(hit.position.y) + " n" + str(hit.normal) if not hit.is_empty() else "-", top])
					hs.append(h)
					a += 0.25
				for k in range(2, hs.size() - 1):
					var d0: float = hs[k - 1] - hs[k - 2]; var d1: float = hs[k] - hs[k - 1]; var d2: float = hs[k + 1] - hs[k]
					var lip := absf(d1 - (d0 + d2) * 0.5)
					if lip > worst: worst = lip; wa = -4.0 + k * 0.25; wo = o; wh = [hs[k - 1], hs[k]]
			res.append([worst, bi, e, c, wa, wo, wh])
			if worst > 0.08: bad += 1
	res.sort_custom(func(p, q): return p[0] > q[0])
	print("BRT ends %d, lips over 8 cm: %d" % [res.size(), bad])
	for r in res.slice(0, 20): print("BRT  %.2f m  bridge %d end %d at %s  at a %.2f lane %.1f  %s  hw %.1f L %.0f" % [r[0], r[1], r[2], r[3], r[4], r[5], str(r[6]), BridgeKit.bridges[r[1]].hw, BridgeKit.bridges[r[1]].L])
	# the bug report's bridge
	for r in res:
		if Vector2(r[3].x - 473.8, r[3].z + 468.4).length() < 3.0: print("BRT bug-report end (473.8, -468.4): step %.2f m" % r[0])
	get_tree().quit()

## the terrain as drawn: bilinear between the 5 m vertices
func _th(data: Terrain3DData, x: float, z: float) -> float:
	var x0 := floorf(x / 5.0) * 5.0; var z0 := floorf(z / 5.0) * 5.0
	var fx := (x - x0) / 5.0; var fz := (z - z0) / 5.0
	var a := float(data.get_height(Vector3(x0, 0, z0))); var b := float(data.get_height(Vector3(x0 + 5, 0, z0)))
	var c := float(data.get_height(Vector3(x0, 0, z0 + 5))); var d := float(data.get_height(Vector3(x0 + 5, 0, z0 + 5)))
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)
