extends Node
func _ready():
	await get_tree().process_frame
	var sun := DirectionalLight3D.new(); sun.shadow_enabled = true; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS; sun.rotation_degrees = Vector3(-50, 30, 0); add_child(sun)
	var cam := Camera3D.new(); add_child(cam); cam.current = true
	cam.look_at_from_position(Vector3(0, 1, 12), Vector3(0, 1, 0))
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var x := -5.0
	for k in Outfit.MH_PEOPLE.keys():
		var r := Rig.new(); add_child(r); r.load_model(k); r.dress(Outfit.random_look(rng, Outfit.is_female(k), false)); r.position.x = x; x += 1.0
	for i in 5: await get_tree().process_frame
	print("MHMEM tex=", int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) >> 20, "MB buf=", int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)) >> 20, "MB static=", OS.get_static_memory_usage() >> 20, "MB dc=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objs=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	get_tree().quit()
