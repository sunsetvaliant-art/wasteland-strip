extends Node
## Headless: stand in Murwillumbah's main street, let the streets stream in, and check what got built
## (add as an autoload line PT="*res://tools/_streettest.gd" under Settings= for a run). ST_X / ST_Z move it.
func _ready():
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	for _i in 30: await get_tree().physics_frame
	var main = get_tree().current_scene
	var x := float(OS.get_environment("ST_X")) if OS.get_environment("ST_X") != "" else -700.0
	var z := float(OS.get_environment("ST_Z")) if OS.get_environment("ST_Z") != "" else -60.0
	var f = main.forge
	f.teleport_to(Vector3(x, 0, z))
	var t0 := Time.get_ticks_msec()
	for _i in 900: await get_tree().physics_frame
	var s: Streets = Streets.inst
	var kerb_tris := 0; var furn := {}; var paint := 0; var bodies := 0
	for k in s._tiles:
		var t: Dictionary = s._tiles[k]
		kerb_tris += (t.faces as PackedVector3Array).size() / 3
		paint += (t.paint as Array).size()
		if t.body != null: bodies += 1
		for sh in t.shapes: furn[sh[0]] = furn.get(sh[0], 0) + 1
	print("STREETTEST tiles built %d of %d (%d ms), kerb/slab tris %d, paint meshes %d, colliding tiles %d" % [s._tiles.size(), s._index.size(), Time.get_ticks_msec() - t0, kerb_tris, paint, bodies])
	print("STREETTEST furniture by kind ", furn)
	var hard := 0; var n := 0
	for i in 40:
		for j in 40:
			n += 1
			if Streets.hard(x - 200 + i * 10, z - 200 + j * 10): hard += 1
	print("STREETTEST hard ground %d of %d samples" % [hard, n])
	# drop rays onto the first kerb near the player: the top should stand ~15 cm proud of the gutter
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var tested := 0
	for k in s._tiles:
		if tested >= 3: break
		var t: Dictionary = s._tiles[k]
		if t.body == null: continue
		var d := s._tile_data(k)
		for run in d.kerb:
			var pts: PackedVector2Array = run[1]
			if pts.size() < 3 or int(run[0]) != 1: continue
			var a := pts[1]; var b := pts[2]
			var tt := (b - a).normalized(); var nn := Vector2(tt.y, -tt.x)
			var hs := []
			for o in [-0.3, 0.12, 0.6]:
				var p := a + nn * float(o)
				var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 400, p.y), Vector3(p.x, -50, p.y))
				var r := space.intersect_ray(q)
				hs.append(snappedf(r.position.y, 0.01) if r else NAN)
			print("STREETTEST kerb at %s: gutter %s kerb top %s verge %s" % [a.round(), hs[0], hs[1], hs[2]])
			tested += 1
			break
	# how long one tile takes to build (the streamer does one per 0.12 s; over ~8 ms would show as a hitch)
	var worst := 0; var total := 0; var nb := 0
	print("STREETTEST while streaming: longest hold %.1f ms (%s)" % [s.worst_slice / 1000.0, s.worst_where])
	s.worst_slice = 0
	for k: Vector2i in s._tiles.keys().slice(0, 25):
		var t0b := Time.get_ticks_usec()
		var td: Dictionary = await s._build(k)
		var us := Time.get_ticks_usec() - t0b
		worst = maxi(worst, us); total += us; nb += 1
		s._free(td)
	print("STREETTEST build per tile (spread over frames): mean %.1f ms, worst %.1f ms over %d; longest hold of one frame %.1f ms (%s)" % [total / 1000.0 / maxi(nb, 1), worst / 1000.0, nb, s.worst_slice / 1000.0, s.worst_where])
	get_tree().quit()
