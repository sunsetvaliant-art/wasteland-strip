extends Node
func _ready():
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	await get_tree().process_frame
	var R: Roads = get_tree().current_scene.roads
	var B = Buildings.inst
	for i in B.lots.size():
		var l: Array = B.lots[i]
		if Vector2(float(l[1]) - 14830.73, float(l[2]) + 9199.57).length() < 30.0:
			var w := B._road_worst(R, l)
			print("RC lot %d %s %s worst %s, segs in cell: %d, centre edge_dist %.1f" % [i, l[0], l.slice(1, 6), w, R._seg.size(), R.edge_dist(float(l[1]), float(l[2]))])
			var b := Basis(Vector3.UP, float(l[3]))
			for t in 11:
				var p := Vector3(l[1], 0, l[2]) + b * Vector3(0, 0, (t / 10.0 - 0.5) * float(l[5]))
				print("RC   along %.0f m: edge_dist %.1f" % [(t / 10.0 - 0.5) * float(l[5]), R.edge_dist(p.x, p.z)])
	get_tree().quit()
