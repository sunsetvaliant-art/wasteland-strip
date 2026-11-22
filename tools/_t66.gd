extends Node
## 0.2.66 in the world under xvfb: the player gets in a forklift and works the forks with the keys; the Forge's
## gantry spawns. PT="*res://tools/_t66.gd". Writes /tmp/shots/t66_*.png
func _shot(n: String) -> void:
	for _i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)

func _key(k: int, on: bool) -> void:
	var e := InputEventKey.new(); e.physical_keycode = k; e.keycode = k; e.pressed = on
	Input.parse_input_event(e)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	for _i in 60: await get_tree().physics_frame
	var main = get_tree().current_scene
	var p = main.player
	var at: Vector3 = p.global_position + p.global_transform.basis * Vector3(3.2, 0, 0)
	var f: Car = main.spawn_vehicle("forklift", Vector3(at.x, main.height_at(at.x, at.z) + 1.2, at.z), p.rotation.y)
	for _i in 120: await get_tree().physics_frame
	p._try_get_in(f)
	for _i in 160: await get_tree().physics_frame
	print("T66 in ", p.vehicle == f, " running ", f.running, " forks ", f.forks != null)
	_key(KEY_UP, true)
	for _i in 240: await get_tree().physics_frame
	_key(KEY_UP, false)
	print("T66 lift after 2 s held ", snappedf(f.forks.lift, 0.01))
	_key(KEY_LEFT, true)
	for _i in 120: await get_tree().physics_frame
	_key(KEY_LEFT, false)
	print("T66 tilt ", snappedf(f.forks.tilt, 0.02))
	var l0: float = f.forks.lift
	_key(KEY_ALT, true); _key(KEY_DOWN, true)
	for _i in 60: await get_tree().physics_frame
	_key(KEY_DOWN, false); _key(KEY_ALT, false)
	print("T66 fine lower 0.5 s: ", snappedf((l0 - f.forks.lift) * 1000.0, 1.0), " mm")
	await _shot("t66_cab")
	p._get_out()
	for _i in 30: await get_tree().physics_frame
	var h := Hoist.new(); main.add_child(h)
	var hp: Vector3 = p.global_position + p.global_transform.basis * Vector3(4, 0, 0)
	h.global_position = Vector3(hp.x, main.height_at(hp.x, hp.z), hp.z)
	var cam := Camera3D.new(); main.add_child(cam)
	cam.global_position = f.global_position + f.global_transform.basis * Vector3(4.5, 2.0, 3.0)
	cam.look_at(f.global_position + Vector3(0, 1.0, 0)); cam.current = true
	await _shot("t66_world")
	print("T66_DONE")
	get_tree().quit()
