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
	await _paint_only(main)

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
	# real mouse events, small brush, across the top of one end of the body (found by rays straight down)
	bt.pt_part = 3; bt.pt_rad = 0.12
	var lo := Vector3(INF, INF, INF); var hi := -lo
	for v in bt.pt_tris: lo = lo.min(v); hi = hi.max(v)
	print("T59 body box ", lo, " .. ", hi)
	var zf: float = lerpf(lo.z, hi.z, 0.86)
	var ha: Dictionary = bt.pt_tm.intersect_ray(Vector3(-0.35, hi.y + 1.0, zf), Vector3.DOWN)
	var hb: Dictionary = bt.pt_tm.intersect_ray(Vector3(0.35, hi.y + 1.0, zf), Vector3.DOWN)
	print("T59 top hits ", ha.get("position"), " ", hb.get("position"))
	var p0: Vector2 = bt.cam.unproject_position(sp0 + (ha.get("position", Vector3.ZERO) as Vector3))
	var p1: Vector2 = bt.cam.unproject_position(sp0 + (hb.get("position", Vector3.ZERO) as Vector3))
	p0 = spc; p1 = spc + Vector2(90, -15)      # across the middle of the screen, clear of the side panel
	print("T59 drag ", p0, " -> ", p1)
	var evp := InputEventMouseButton.new(); evp.button_index = MOUSE_BUTTON_LEFT; evp.pressed = true; evp.position = p0; evp.global_position = p0
	Input.parse_input_event(evp)
	await get_tree().process_frame
	var hov = get_viewport().gui_get_hovered_control()
	print("T59 hovered control at press: ", hov.get_path() if hov else null, " filter ", hov.mouse_filter if hov else -1)
	for i in 21:
		var mm := InputEventMouseMotion.new(); mm.position = p0.lerp(p1, i / 20.0); mm.global_position = mm.position; mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mm)
		await get_tree().process_frame
	var ev2 := InputEventMouseButton.new(); ev2.button_index = MOUSE_BUTTON_LEFT; ev2.pressed = false; ev2.position = p1; ev2.global_position = p1
	Input.parse_input_event(ev2)
	await get_tree().process_frame
	print("T59 after drag: ", bt.status.text)
	# fill a tub panel with a click
	bt.pt_fill = true; bt.pt_part = 2
	var t0 := Time.get_ticks_msec()
	var hc: Dictionary = bt.pt_tm.intersect_ray(Vector3(0.0, hi.y + 1.0, lerpf(lo.z, hi.z, 0.12)), Vector3.DOWN)
	print("T59 fill at ", hc.get("position"))
	bt._paint_at(bt.cam.unproject_position(sp0 + (hc.get("position", Vector3.ZERO) as Vector3)), true)
	print("T59 after fill (%d ms): %s" % [Time.get_ticks_msec() - t0, bt.status.text])
	var rr: Dictionary = bt.pt_tm.intersect_ray(Vector3(0.0, hi.y + 1.0, lerpf(lo.z, hi.z, 0.12)), Vector3.DOWN)
	var fi := int(rr.get("face_index", -1))
	if fi >= 0 and bt._pt_adj.size() > fi:
		var nb: Array = bt._pt_adj[fi]
		var dots := []
		for o in nb: dots.append(snappedf(bt.pt_nrm[o].dot(bt.pt_nrm[fi]), 0.01))
		print("T59 fill face ", fi, " n ", bt.pt_nrm[fi], " tri ", bt.pt_tris[fi * 3], bt.pt_tris[fi * 3 + 1], bt.pt_tris[fi * 3 + 2], " neighbours ", nb, " dots ", dots)
	var tot := 0
	for a in bt._pt_adj: tot += (a as PackedInt32Array).size()
	print("T59 adjacency mean ", float(tot) / maxf(bt._pt_adj.size(), 1))
	# bonnet by fill from its top, on a cleared model
	for i in bt.pt_lab.size(): bt.pt_lab[i] = 0
	bt.pt_part = 3
	bt._paint_at(bt.cam.unproject_position(sp0 + (ha.get("position", Vector3.ZERO) as Vector3)), true)
	bt._rebuild_model()
	for _i in 10: await get_tree().process_frame
	print("T59 painter: status %s" % [bt.status.text])
	await _shot("t59_paint")
	get_tree().quit()

func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % nm)
	print("SHOT ", nm)
