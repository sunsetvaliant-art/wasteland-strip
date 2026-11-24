extends Node
## 0.2.75 in the world (runpt): a street of dressed zombies and scavs round you, you in third person in your clothes;
## a shirt swap; a zombie killed and searched for what it had on; draw calls dressed vs not. /tmp/shots/t75_*.png
func _shot(n: String) -> void:
	for _i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)

func _dc(frames: int) -> float:
	var t := 0.0
	for _i in frames:
		await get_tree().process_frame
		t += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return t / frames

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("T75 start ", Time.get_ticks_msec())
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	print("T75 main ", Time.get_ticks_msec(), " paused ", get_tree().paused)
	Settings.set_value("god_mode", true)
	var p = main.player
	var at := Vector3(60, 0, 40)
	p.global_position = Vector3(at.x, main.height_at(at.x, at.z) + 1.2, at.z)
	p.yaw = 0.0
	for _i in 20: await get_tree().process_frame
	print("T75 player look ", p.rig.look.get("top"), " ", p.rig.look.get("bottom"), " ", p.rig.look.get("feet"), " shell ", p.rig.model.find_children("*", "MeshInstance3D", true, false)[0].mesh.get_meta("outfit_shell", false))
	var dc0: float = await _dc(6)
	var npcs := []
	for i in 6:
		var n := NPC.new()
		n.kind = "zombie" if i < 4 else "scav"
		var q := at + Vector3(-6 + (i % 3) * 2.4, 0, -6 - (i / 3) * 2.6)
		main.add_child(n)
		n.global_position = Vector3(q.x, main.height_at(q.x, q.z) + 0.1, q.z)
		n.set_physics_process(false)
		npcs.append(n)
	for _i in 10: await get_tree().process_frame
	var dc1: float = await _dc(6)
	print("T75 draw calls: none %.0f, with 6 dressed %.0f" % [dc0, dc1])
	for n in npcs: print("T75 npc ", n.model_key, " ", n.rig.look.get("top", "-"), " ", n.rig.look.get("bottom", "-"), " ", n.rig.look.get("feet", "-"))
	var cam := Camera3D.new(); main.add_child(cam)
	cam.global_position = Vector3(at.x + 1.5, main.height_at(at.x, at.z) + 2.2, at.z + 4.5)
	cam.look_at(Vector3(at.x, main.height_at(at.x, at.z - 6) + 1.0, at.z - 6)); cam.current = true
	await _shot("t75_crowd")
	# a shirt swap: put a hi-vis on
	var s := Items.fresh("shirt_work"); s.data["v"] = 1
	p.inv.set_slot("top", s)
	p.inv.set_slot("bottom", Items.fresh("shorts_stubbies"))
	p.inv.set_slot("feet", Items.fresh("thongs"))
	for _i in 5: await get_tree().process_frame
	print("T75 after swap ", p.rig.look.get("top"), " ", p.rig.look.get("bottom"), " ", p.rig.look.get("feet"))
	cam.global_position = p.global_position + Vector3(0.6, 1.4, -2.6)
	cam.look_at(p.global_position + Vector3(0, 1.0, 0))
	await _shot("t75_me")
	# a zombie killed and searched
	var z: NPC = npcs[0]
	z.set_physics_process(true)
	z.take_hit({"head": 900.0}, Vector3.FORWARD, z.global_position + Vector3.UP * 1.6, 5.0, p)
	for _i in 20: await get_tree().process_frame
	var g: Dictionary = InventoryUI.box_grid(z)
	print("T75 the body had: ", g.items.map(func(it): return it.s.id if it is Dictionary and it.has("s") else it))
	await _shot("t75_dead")
	get_tree().quit()
