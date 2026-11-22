extends Node
## Under xvfb (GL): the engine view on a real car. Opens it with parts missing (ghosts), picks, fits by the same path a
## drop takes, tries a part that doesn't fit, bakes the part pictures, and writes /tmp/shots/e_*.png.
## Add as PT="*res://tools/_engviewtest.gd" under Settings=.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	for _i in 60: await get_tree().physics_frame
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	var main = get_tree().current_scene
	var p = main.player
	var c: Car = main.spawn_vehicle("vjwagon", p.global_position + Vector3(5, 1.0, 0), 0.3)
	for _i in 20: await get_tree().process_frame
	var k: Dictionary = c.design.kit
	print("PROBE stock ", EngineKit.describe(k), " slots ", EngineKit.slots(k))
	k.heads[0] = ""; k.fuel = ""; k.alt = false; k.ign = ""
	c.refresh_engine()
	var ev: EngineView = main.engine_view
	ev.open_for(k, {"title": str(c.def.name), "changed": func(): c.refresh_engine()})
	for _i in 30: await get_tree().process_frame
	print("PROBE parts ", ev.parts.keys(), " ghosts ", ev.parts.keys().filter(func(s): return ev.parts[s].ghost))
	var mid: Vector2 = Vector2(ev.vp.size) * 0.5
	print("PROBE pick centre ", ev._pick(mid), " vp ", ev.vp.size)
	# hover sweep across the middle: which parts can be hit
	var seen := {}
	for y in range(0, ev.vp.size.y, 12):
		for x in range(0, ev.vp.size.x, 12):
			var s := ev._pick(Vector2(x, y))
			if s != "": seen[s] = int(seen.get(s, 0)) + 1
	print("PROBE pickable ", seen)
	ev.hover = "intake"; ev._overlays()
	await _shot("e_ghosts")
	ev.sel = "head0"; ev._overlays(); ev._info()
	ev._show_side(true, "head0")
	for _i in 120: await get_tree().process_frame
	await _shot("e_parts")
	# drop path: a wrong part, then the right ones
	var ok: bool = ev._can_drop_engine(mid, {"id": "ex_4"})
	print("PROBE drop ex_4 ok=", ok, " why=", ev._msg)
	ok = ev._can_drop_engine(mid, {"id": EngineKit.head_id(6, "dohc", "hi")})
	print("PROBE drop head ok=", ok, " slot=", ev.drop_slot)
	ev._drop_engine(mid, {"id": EngineKit.head_id(6, "dohc", "hi")})
	ev._fit("ef_tb", "fuel")
	print("PROBE after fits ", EngineKit.describe(k), " fault=", EngineKit.fault(k), " slots ", EngineKit.slots(k))
	ev.sel = "ecu"; ev._overlays(); ev._info()
	for _i in 20: await get_tree().process_frame
	await _shot("e_fitted")
	ev._off("head0")
	var wi := WorldItem.spawn(main, [Items.fresh(EngineKit.head_id(6, "sohc", "med"), 1)], p.global_position + Vector3(0, 1, 2))
	print("PROBE dropped part ", wi != null)
	print("PROBE off head ", k.heads, " block off why=", EngineKit.cant_take_off(k, "block"))
	print("PROBE icons baked ", EngineView._icons.size(), " inventory icon ", ItemIcons.get_icon("alternator") != null)
	# a V8 on an empty stand
	var sk := {"block": "", "heads": [], "exhaust": [], "intake": "", "fuel": "", "ign": "", "ecu": "", "alt": false, "rolled": true, "tune": {}}
	ev.close()
	ev.open_for(sk, {"title": "On the engine stand", "block_ok": true})
	ev._fit("eb_v8_big", "block")
	ev._fit(EngineKit.head_id(4, "push", "med"), str(EngineKit.slot_for(sk, EngineKit.head_id(4, "push", "med"))[0]))
	print("PROBE stand ", sk.heads, " ", EngineKit.slots(sk))
	ev.spin = 2.2
	for _i in 20: await get_tree().process_frame
	await _shot("e_v8")
	ev.close()
	print("PROBE ENGVIEW done")
	get_tree().quit()

func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % nm)
	print("SHOT ", nm)
