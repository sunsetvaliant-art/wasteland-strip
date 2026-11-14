extends Node
func _ready():
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	for _i in 20: await get_tree().process_frame
	var d = get_tree().current_scene.terrain.data
	var worst := 0.0; var wx := 0.0
	for x in range(8600, 15300, 5):
		# max height jump across the seam per 5 m step, looking at 6 rows either side
		for z in range(-16990, -16930, 5):
			var a: float = d.get_height(Vector3(x, 0, z)); var b: float = d.get_height(Vector3(x, 0, z + 5))
			if absf(a - b) > worst: worst = absf(a - b); wx = x
	var cmp := 0.0
	for x in range(8600, 15300, 5):
		for z in range(-17300, -17000, 5):
			cmp = maxf(cmp, absf(d.get_height(Vector3(x, 0, z)) - d.get_height(Vector3(x, 0, z + 5))))
	print("SEAMTEST worst 5m step near seam %.2f m at x=%d; worst step 40-300 m north (natural) %.2f m" % [worst, wx, cmp])
	var hist := {}
	for x in range(8600, 15300, 25):
		for z in range(-16950, -15000, 25):
			var id: int = d.get_control_base_id(Vector3(x, 0, z))
			hist[id] = hist.get(id, 0) + 1
	print("SEAMTEST south control ids ", hist)
	get_tree().quit()
