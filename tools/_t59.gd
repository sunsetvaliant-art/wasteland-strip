extends Node
## 0.2.59 checks under xvfb: the tractor (spawn, drive, picture), a real mouse drag in the engine view, the body
## painter, the Forge palette's engine tab. Add as PT="*res://tools/_t59.gd" under Settings=. Writes /tmp/shots/t59_*.png
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	for _i in 60: await get_tree().physics_frame
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	var main = get_tree().current_scene
	var p = main.player
	if OS.get_environment("T59_ONLY") == "paint":
		await _paint_only(main)
		return
	# ---- the tractor
	var t: Car = main.spawn_vehicle("tractor", p.global_position + Vector3(7, 1.5, 3), 0.6)
	for _i in 200: await get_tree().physics_frame
	var wl := []
	for w in t.wheels: wl.append("%s r%.2f N%.0f" % ["c" if w.contact else "-", float(w.r), float(w.N)])
	print("T59 tractor up %.2f wheels %s mass %.0f eng %s" % [t.global_transform.basis.y.y, wl, t.mass, EngineKit.describe(t.design.kit)])
	var cam := Camera3D.new(); main.add_child(cam)
	cam.global_position = t.global_position + t.global_transform.basis * Vector3(4.5, 1.6, 4.5)
	cam.look_at(t.global_position + Vector3(0, 0.8, 0)); cam.current = true
	for _i in 30: await get_tree().process_frame
	await _shot("t59_tractor")
	cam.current = false
	p._try_get_in(t)
	for _i in 60: await get_tree().physics_frame
	t._shift(1); t._shift(1)
	Input.action_press("move_forward")
	for _i in Engine.physics_ticks_per_second * 5: await get_tree().physics_frame
	Input.action_release("move_forward")
	print("T59 tractor after 5 s of W: %.1f km/h gear %s rpm %d" % [t.speed_kmh(), t.gear_name(), t.rpm])
	if p.vehicle: p._get_out()
	for _i in 30: await get_tree().physics_frame
	# ---- a real drag in the engine view: from the first tile onto the engine
	var c: Car = main.spawn_vehicle("vjwagon", p.global_position + Vector3(-6, 1.0, 0), 0.3)
	for _i in 30: await get_tree().physics_frame
	var k: Dictionary = c.design.kit
	k.heads[0] = ""
	var ev: EngineView = main.engine_view
	ev.open_for(k, {"title": "test", "changed": func(): c.refresh_engine()})
	ev._show_side(true, "head0")
	for _i in 90: await get_tree().process_frame
	var tile: Control = ev.grid.get_child(0)
	var a := tile.get_global_rect().get_center()
	var b := ev.pad.get_global_rect().get_center()
	var vp := get_viewport()
	var mv := InputEventMouseMotion.new(); mv.position = a; mv.global_position = a; vp.push_input(mv)
	await get_tree().process_frame
	var pr := InputEventMouseButton.new(); pr.button_index = MOUSE_BUTTON_LEFT; pr.pressed = true; pr.position = a; pr.global_position = a; pr.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(pr)
	for i in 30:
		await get_tree().process_frame
		var q := a.lerp(b, (i + 1) / 30.0)
		var m := InputEventMouseMotion.new(); m.position = q; m.global_position = q; m.button_mask = MOUSE_BUTTON_MASK_LEFT; m.relative = (b - a) / 30.0
		vp.push_input(m)
	await get_tree().process_frame
	await _shot("t59_drag")
	var rl := InputEventMouseButton.new(); rl.button_index = MOUSE_BUTTON_LEFT; rl.pressed = false; rl.position = b; rl.global_position = b
	vp.push_input(rl)
	for _i in 10: await get_tree().process_frame
	print("T59 engine view drag: head0 now '%s' (tile was %s), fault '%s'" % [str(k.heads[0]), str(tile.get_meta("count", null) != null), EngineKit.fault(k)])
	await _shot("t59_dropped")
	ev.close()
	# ---- the body painter
	var bt = main.body_tools
	bt.glb = str(Car.catalog()["vhute"].glb)
	bt.mode = "paint"
	bt.show_tools()
	for _i in 30: await get_tree().process_frame
	bt.pt_part = 2; bt.pt_rad = 0.4
	var sp0: Vector3 = bt.spot
	print("T59 paint cam ", bt.cam.global_position, " current ", bt.cam.current, " spot ", sp0, " vis ", get_viewport().get_visible_rect().size)
	print("T59 straight down ", bt.pt_tm.intersect_ray(Vector3(0, 5, 0), Vector3(0, -1, 0)), " tris ", bt.pt_tris.size(), " model ", bt.model.global_position if bt.model else null)
	var spc: Vector2 = bt.cam.unproject_position(sp0)
	print("T59 centre ", spc, " origin ", bt.cam.project_ray_origin(spc), " dir ", bt.cam.project_ray_normal(spc), " to spot ", (sp0 - bt.cam.global_position).normalized())
	print("T59 centre ray ", bt.pt_tm.intersect_ray(bt.cam.project_ray_origin(spc) - sp0, bt.cam.project_ray_normal(spc)))
	for i in 12:
		var sp: Vector2 = bt.cam.unproject_position(sp0 + Vector3(0, 0.25, -2.4 + i * 0.1))
		if i == 0: print("T59 paint at ", sp, " ray ", bt.pt_tm.intersect_ray(bt.cam.project_ray_origin(sp) - sp0, bt.cam.project_ray_normal(sp)))
		bt._paint_at(sp)
	bt.pt_part = 3
	for i in 8:
		bt._paint_at(bt.cam.unproject_position(sp0 + Vector3(0, 0.4, 1.6 + i * 0.08)))
	for _i in 10: await get_tree().process_frame
	print("T59 painter: %d triangles, status %s" % [bt.pt_ctr.size(), bt.status.text if bt.status else ""])
	await _shot("t59_paint")
	bt.close()
	# ---- the Forge palette, engines tab
	var f = main.forge
	if not f.active: f.toggle()
	f._set_palette(true)
	var tabs: TabContainer = null
	for ch in f.palette.get_children():
		if ch is TabContainer: tabs = ch
	if tabs:
		for i in tabs.get_tab_count():
			if tabs.get_tab_title(i) == "Engines & parts": tabs.current_tab = i
		var page: ScrollContainer = tabs.get_node("Engines & parts")
		var vb: VBoxContainer = page.get_child(0)
		(vb.get_child(0) as Button).button_pressed = true
		(vb.get_child(2) as Button).button_pressed = true
	for _i in 90: await get_tree().process_frame
	await _shot("t59_palette")
	print("T59 done")
	get_tree().quit()

func _paint_only(main) -> void:
	var bt = main.body_tools
	bt.glb = str(Car.catalog()["vhute"].glb)
	bt.mode = "paint"
	bt.show_tools()
	for _i in 30: await get_tree().process_frame
	bt.pt_part = 2; bt.pt_rad = 0.4
	var sp0: Vector3 = bt.spot
	print("T59 paint cam ", bt.cam.global_position, " current ", bt.cam.current, " spot ", sp0, " vis ", get_viewport().get_visible_rect().size)
	print("T59 straight down ", bt.pt_tm.intersect_ray(Vector3(0, 5, 0), Vector3(0, -1, 0)), " tris ", bt.pt_tris.size(), " model ", bt.model.global_position if bt.model else null)
	var spc: Vector2 = bt.cam.unproject_position(sp0)
	print("T59 centre ", spc, " origin ", bt.cam.project_ray_origin(spc), " dir ", bt.cam.project_ray_normal(spc), " to spot ", (sp0 - bt.cam.global_position).normalized())
	print("T59 centre ray ", bt.pt_tm.intersect_ray(bt.cam.project_ray_origin(spc) - sp0, bt.cam.project_ray_normal(spc)))
	for i in 12:
		var sp: Vector2 = bt.cam.unproject_position(sp0 + Vector3(0, 0.25, -2.4 + i * 0.1))
		if i == 0: print("T59 paint at ", sp, " ray ", bt.pt_tm.intersect_ray(bt.cam.project_ray_origin(sp) - sp0, bt.cam.project_ray_normal(sp)))
		bt._paint_at(sp)
	bt.pt_part = 3
	for i in 8:
		bt._paint_at(bt.cam.unproject_position(sp0 + Vector3(0, 0.4, 1.6 + i * 0.08)))
	for _i in 10: await get_tree().process_frame
	print("T59 painter: status %s" % [bt.status.text])
	await _shot("t59_paint")
	get_tree().quit()

func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % nm)
	print("SHOT ", nm)
