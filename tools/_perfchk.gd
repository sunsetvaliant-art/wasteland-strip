extends Node
func _ready():
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	for _i in 300: await get_tree().process_frame
	main.player.global_position = Vector3(-1035, main.height_at(-1035, -300) + 2.0, -300)
	for _i in 400: await get_tree().process_frame
	var dc := []
	for _i in 60:
		await get_tree().process_frame
		dc.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	dc.sort()
	print("PERF draw calls median %d max %d, buildings full %d" % [dc[30], dc[59], Buildings.inst.full.size()])
	get_tree().quit()
