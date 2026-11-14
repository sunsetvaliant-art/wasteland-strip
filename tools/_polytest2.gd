extends Node
## Headless: the v2 Twin City in the world: floor, travelators down, the car park, the car ramp, the stairs up to
## the cinema. Walks a player down each travelator and up the stairs, drives nothing (rays for the ramp).
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	for _i in 60: await get_tree().physics_frame
	var B = Buildings.inst
	var li := -1
	for i in B.lots.size():
		if B.lots[i].size() > 7 and str(B.lots[i][7]) == "TWIN CITY": li = i
	var l: Array = B.lots[li]
	var p: Player = main.player
	Settings.set_value("god_mode", true)
	p.global_position = Vector3(float(l[1]), main.height_at(float(l[1]), float(l[2])) + 3.0, float(l[2]))
	var waited := 0
	while not B.full.has(li) and waited < 3000:
		await get_tree().physics_frame; waited += 1
	for _i in 300: await get_tree().physics_frame
	var node: Node3D = B.full[li]
	var xf := node.global_transform
	var dt := PolyMall.data("twin_city")
	var space := p.get_world_3d().direct_space_state
	var down := func(lp: Vector2, from_y: float) -> float:
		var top := xf * Vector3(lp.x, from_y, lp.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -12, 0), 1))
		return hit.position.y - xf.origin.y if not hit.is_empty() else -99.0
	print("T2 built after %d frames, floor y %.2f" % [waited, xf.origin.y])
	# travelators: the ground under the middle of each, and walking down one
	for tr in dt.travelators:
		var a := Vector2(tr[0], tr[1]); var b := Vector2(tr[2], tr[3])
		print("T2 travelator: surface at 1/4 %.2f, 1/2 %.2f, 3/4 %.2f (want about -1, -2, -3); car park floor past the end %.2f" % [down.call(a.lerp(b, 0.25), 1.0), down.call(a.lerp(b, 0.5), 1.0), down.call(a.lerp(b, 0.75), 1.0), down.call(b + (b - a).normalized() * 3.0, -1.0)])
	var tr0: Array = dt.travelators[1]
	var ta := Vector2(tr0[0], tr0[1]); var tb := Vector2(tr0[2], tr0[3])
	p.global_position = xf * Vector3(ta.x - (tb - ta).normalized().x * 1.5, 0.3, ta.y - (tb - ta).normalized().y * 1.5)
	p.velocity = Vector3.ZERO
	for _i in 30: await get_tree().physics_frame
	var goal: Vector3 = xf * Vector3(tb.x + (tb - ta).normalized().x * 6.0, -4.0, tb.y + (tb - ta).normalized().y * 6.0)
	for f in 600:
		var d := goal - p.global_position; d.y = 0
		if f % 60 == 0:
			var lp: Vector3 = xf.affine_inverse() * p.global_position
			var hits := []
			for ci in p.get_slide_collision_count(): hits.append(str(p.get_slide_collision(ci).get_collider().name) + "@" + str((xf.affine_inverse() * p.get_slide_collision(ci).get_position()).snapped(Vector3.ONE * 0.1)))
			print("T2DBG trav f%d local %s hits %s" % [f, lp.snapped(Vector3.ONE * 0.1), hits])
		if d.length() < 0.6: break
		p.velocity.x = d.normalized().x * 4.0; p.velocity.z = d.normalized().z * 4.0
		p.move_and_slide()
		await get_tree().physics_frame
	print("T2 walked down a travelator: player %.2f m relative to the mall floor (car park is -4), %.1f m from the goal" % [p.global_position.y - xf.origin.y, Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z).length()])
	# the car ramp
	var rp: Dictionary = dt.ramp
	var rt := Vector2(rp.top[0], rp.top[1]); var rb := Vector2(rp.bottom[0], rp.bottom[1])
	print("T2 car ramp surface: door %.2f, top %.2f, half way %.2f, bottom %.2f, past the bottom %.2f" % [down.call(Vector2(rp.door[0], rp.door[1]), 2.0), down.call(rt, 2.0), down.call(rt.lerp(rb, 0.5), 2.0), down.call(rb, 2.0), down.call(rb + (rb - rt).normalized() * 4.0, -1.0)])
	# stairs up to the cinema
	var st: Dictionary = dt.cinema.stairs
	var sb := Vector2(st.bottom[0], st.bottom[1]); var stp := Vector2(st.top[0], st.top[1])
	p.global_position = xf * Vector3(sb.x - (stp - sb).normalized().x * 2.0, 0.3, sb.y - (stp - sb).normalized().y * 2.0)
	p.velocity = Vector3.ZERO
	for _i in 30: await get_tree().physics_frame
	var lnd := Vector2(st.landing[0], st.landing[1])
	var c0 := Vector2(dt.cinema.rect[0], dt.cinema.rect[1]); var c1 := Vector2(dt.cinema.rect[2], dt.cinema.rect[3])
	var into := Vector2(1, 0) if absf(lnd.x - minf(c0.x, c1.x)) < absf(lnd.x - maxf(c0.x, c1.x)) else Vector2(-1, 0)
	var g1: Vector3 = xf * Vector3(lnd.lerp(stp, 0.5).x, 5.2, lnd.lerp(stp, 0.5).y)
	for f in 900:
		var d := g1 - p.global_position; d.y = 0
		if f % 60 == 0:
			var lp: Vector3 = xf.affine_inverse() * p.global_position
			var hits := []
			for ci in p.get_slide_collision_count(): hits.append(str(p.get_slide_collision(ci).get_collider().name) + "@" + str((xf.affine_inverse() * p.get_slide_collision(ci).get_position()).snapped(Vector3.ONE * 0.1)))
			print("T2DBG stairs f%d local %s hits %s" % [f, lp.snapped(Vector3.ONE * 0.1), hits])
		if d.length() < 0.5: break
		p.velocity.x = d.normalized().x * 3.0; p.velocity.z = d.normalized().z * 3.0
		p.move_and_slide()
		await get_tree().physics_frame
	print("T2 stairs sb %s stp %s landing %s" % [sb, stp, lnd])
	print("T2 at the top of the stairs: %.2f above the mall floor" % (p.global_position.y - xf.origin.y))
	var g2: Vector3 = xf * Vector3(lnd.lerp(stp, 0.5).x + into.x * 6.0, 5.2, lnd.lerp(stp, 0.5).y)
	for f in 900:
		var d := g2 - p.global_position; d.y = 0
		if d.length() < 0.6: break
		p.velocity.x = d.normalized().x * 3.0; p.velocity.z = d.normalized().z * 3.0
		p.move_and_slide()
		await get_tree().physics_frame
	print("T2 walked up the stairs: player %.2f m above the mall floor (cinema is 5.2), %.1f m from the goal" % [p.global_position.y - xf.origin.y, Vector2(g2.x - p.global_position.x, g2.z - p.global_position.z).length()])
	get_tree().quit()
