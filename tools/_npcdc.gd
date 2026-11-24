extends Node
func _dc() -> float:
	var t := 0.0
	for i in 5:
		await get_tree().process_frame
		t += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return t / 5.0
func _ready():
	await get_tree().process_frame
	var sun := DirectionalLight3D.new(); sun.shadow_enabled = true; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS; sun.rotation_degrees = Vector3(-50, 30, 0); add_child(sun)
	var cam := Camera3D.new(); add_child(cam); cam.current = true
	cam.look_at_from_position(Vector3(0, 2, 10), Vector3(0, 1, 0))
	var base := await _dc()
	for kind in ["zombie", "scav"]:
		var ns := []
		for i in 4:
			var n := NPC.new(); n.kind = kind; add_child(n); n.position = Vector3(-3 + i * 2, 0, 0); n.set_physics_process(false); ns.append(n)
		for i in 5: await get_tree().process_frame
		var d := await _dc()
		print("NPCDC ", kind, " per npc %.1f" % ((d - base) / 4.0))
		for n in ns:
			var names := []
			for g in n.find_children("*", "GeometryInstance3D", true, false):
				if (g as GeometryInstance3D).is_visible_in_tree(): names.append("%s(%d)" % [g.name, (g as GeometryInstance3D).cast_shadow])
			print("NPCDC  ", n.model_key, " ", names.size(), " ", names)
			n.queue_free()
		for i in 5: await get_tree().process_frame
	get_tree().quit()
