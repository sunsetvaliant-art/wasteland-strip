extends Node
## Headless: the Map tab's click-to-teleport, the weather slider and the stopped clock
func _ready():
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	for _i in 30: await get_tree().physics_frame
	var main = get_tree().current_scene
	var f = main.forge
	f.toggle()
	f._set_palette(true)
	await get_tree().process_frame
	# a click on the map at the pixel for Bay Mall (13798, -17250)
	var ts: Vector2 = f.map_rect.texture.get_size()
	var fr: Rect2 = f._map_frame()
	var px := fr.position + Vector2((13798.0 - f.MAP_X0) / f.MAP_MPX, (-17250.0 - f.MAP_Z0) / f.MAP_MPX) / ts * fr.size
	var w: Vector3 = f._map_to_world(px)
	f.teleport_to(w)
	for _i in 30: await get_tree().physics_frame
	print("TPTEST click -> world %s, player at %s, oracle at %s" % [w.round(), main.player.global_position.round(), f.cam.global_position.round()])
	SkyCycle.inst.set_manual(0.95, 0.2)
	SkyCycle.inst.frozen = true
	var t0: float = SkyCycle.inst.tod
	for _i in 120: await get_tree().physics_frame
	print("TPTEST weather %s cloud %.2f rain %.2f fog %.2f; clock stopped %s" % [SkyCycle.inst.weather, SkyCycle.inst.cloud, SkyCycle.inst.rain, SkyCycle.inst.fogd, is_equal_approx(t0, SkyCycle.inst.tod)])
	SkyCycle.inst.natural_weather()
	for _i in 10: await get_tree().physics_frame
	print("TPTEST natural again: manual %s weather %s" % [SkyCycle.inst.manual, SkyCycle.inst.weather])
	get_tree().quit()
