extends Node
## 0.2.68 perf probe: stand in a town with cars about; per-job CPU time, physics/process time, draw calls and what's
## in the scene. PT="*res://tools/_perfprobe.gd" (see /tmp/runpt.sh). PP_AT="x,z" picks the spot.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	Settings.set_value("god_mode", true)
	var at := Vector3(-760, 0, -89)
	if OS.get_environment("PP_AT") != "":
		var xs := OS.get_environment("PP_AT").split(",")
		at = Vector3(float(xs[0]), 0, float(xs[1]))
	var p = main.player
	p.global_position = at + Vector3(0, main.height_at(at.x, at.z) + 2.0, 0)
	var w0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - w0 < int(OS.get_environment("PP_WARM") if OS.get_environment("PP_WARM") != "" else "120000"): await get_tree().process_frame
	var t0 := Prof.totals.duplicate()
	var n := 0
	var phys := 0.0; var proc := 0.0; var dc := 0.0; var prims := 0.0; var objs := 0.0
	var f0 := Time.get_ticks_usec()
	while n < 20:
		await get_tree().process_frame
		n += 1
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		objs += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var wall := (Time.get_ticks_usec() - f0) / 1000.0 / n
	print("PP frame %.1f ms wall, process %.2f ms, physics %.2f ms, draw calls %.0f, objects %.0f, prims %.0fk" % [wall, proc / n, phys / n, dc / n, objs / n, prims / n / 1000.0])
	var jobs := []
	for k in Prof.totals: jobs.append([k, (float(Prof.totals[k]) - float(t0.get(k, 0.0))) / n])
	jobs.sort_custom(func(a, b): return a[1] > b[1])
	for j in jobs: print("PP job %-16s %.3f ms/frame" % [j[0], j[1]])
	# what's in the scene
	var counts := {}
	var vis_lights := 0; var shadow_lights := 0; var awake := 0; var cars := 0
	for nd in get_tree().root.find_children("*", "", true, false):
		var c := nd.get_class()
		counts[c] = int(counts.get(c, 0)) + 1
		if nd is Light3D and (nd as Light3D).is_visible_in_tree():
			vis_lights += 1
			if (nd as Light3D).shadow_enabled: shadow_lights += 1
		if nd is RigidBody3D and not (nd as RigidBody3D).freeze and not (nd as RigidBody3D).sleeping: awake += 1
		if nd is Car: cars += 1
	var top := []
	for k in counts: top.append([k, counts[k]])
	top.sort_custom(func(a, b): return a[1] > b[1])
	print("PP nodes ", top.slice(0, 12))
	# who the meshes belong to: Main's child they hang under; surfaces, shadow casters, ones with no visibility range
	var cats := {}
	var camp: Vector3 = get_viewport().get_camera_3d().global_position
	for nd in main.find_children("*", "GeometryInstance3D", true, false):
		var gi := nd as GeometryInstance3D
		if not gi.is_visible_in_tree(): continue
		var topn: Node = gi
		while topn.get_parent() != main and topn.get_parent() != null: topn = topn.get_parent()
		var key := str(topn.name).rstrip("0123456789@")
		var surf := 1
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh: surf = (gi as MeshInstance3D).mesh.get_surface_count()
		var e: Array = cats.get(key, [0, 0, 0, 0, 0])
		e[0] += 1; e[1] += surf
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: e[2] += surf
		if gi.visibility_range_end <= 0.0: e[3] += surf
		if gi.global_position.distance_to(camp) > 80.0: e[4] += surf
		cats[key] = e
	var cl := []
	for k in cats: cl.append([k] + cats[k])
	cl.sort_custom(func(a, b): return a[2] > b[2])
	for c in cl.slice(0, 14): print("PP meshes %-18s nodes %5d surfaces %5d shadow %5d no-range %5d beyond80m %5d" % c)
	var sun: DirectionalLight3D = null
	for nd in main.find_children("*", "DirectionalLight3D", true, false): sun = nd
	if sun: print("PP sun shadow max dist %.0f mode %d splits %s" % [sun.directional_shadow_max_distance, sun.directional_shadow_mode, [sun.directional_shadow_split_1, sun.directional_shadow_split_2, sun.directional_shadow_split_3]])
	print("PP lights visible %d (shadowed %d), awake rigid bodies %d, cars %d" % [vis_lights, shadow_lights, awake, cars])
	print("PP_DONE")
	get_tree().quit()
