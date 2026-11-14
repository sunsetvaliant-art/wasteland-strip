extends Node
## Headless: the traced Twin City in the real world. Goes there, waits for it to build and fit out, then checks the
## floor's there to stand on, the malls are clear to walk, and counts what the fit-out put in.
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
	if not B.full.has(li):
		print("POLYTEST the mall never built"); get_tree().quit(); return
	for _i in 600: await get_tree().physics_frame          # the fit-out comes in over a few seconds
	var node: Node3D = B.full[li]
	var xf := node.global_transform
	print("POLYTEST built after %d frames; floor y %.2f, ground at centre %.2f; children %d" % [waited, xf.origin.y, main.height_at(float(l[1]), float(l[2])), node.get_child_count()])
	var props := node.get_node_or_null("Props")
	var conts := 0
	for c in node.find_children("*", "", true, false):
		if c.is_in_group("containers") or c.get_class() == "Container3D" or c.has_method("open_container") or str(c.get_script()).contains("container"): conts += 1
	print("POLYTEST props node %s with %d children; container-like nodes %d" % [props != null, props.get_child_count() if props else 0, conts])
	var space := p.get_world_3d().direct_space_state
	var ok := 0
	var spots := {"N-S mall": Vector2(-115, -42), "diagonal": Vector2(30, -24), "west wing": Vector2(-73, 58), "south mall": Vector2(112, -30), "food court": Vector2(-52, 5)}
	for nm in spots:
		var lp: Vector2 = spots[nm]
		var top := xf * Vector3(lp.x, 3.0, lp.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -8, 0), 1))
		var fy: float = hit.position.y - xf.origin.y if not hit.is_empty() else -99.0
		if absf(fy) < 0.2: ok += 1
		print("POLYTEST floor at %s: %s (y %.2f above the mall floor)" % [nm, "yes" if absf(fy) < 0.2 else "NO", fy])
	# clear walks at chest height
	for w in [["N-S mall, north to middle", Vector2(-170, -42), Vector2(-20, -42)], ["diagonal mall", Vector2(-12, -6), Vector2(70, -44)], ["west concourse", Vector2(-72, 85), Vector2(-72, -30)]]:
		var a: Vector3 = xf * Vector3(w[1].x, 1.2, w[1].y); var b: Vector3 = xf * Vector3(w[2].x, 1.2, w[2].y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))
		print("POLYTEST %s: %s" % [w[0], "clear for %.0f m" % a.distance_to(b) if hit.is_empty() else "blocked after %.0f m by %s" % [a.distance_to(hit.position), hit.collider.name]])
	# stand the player in the mall and see they stay on the floor
	p.global_position = xf * Vector3(-115, 0.5, -42)
	p.velocity = Vector3.ZERO
	for _i in 240: await get_tree().physics_frame
	print("POLYTEST player standing %.2f m above the mall floor, on floor %s" % [p.global_position.y - xf.origin.y, p.is_on_floor()])
	get_tree().quit()
