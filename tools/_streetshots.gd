extends Node
## Screenshots of the street kit (run under xvfb with the GL renderer, as an autoload line PT="*res://tools/_streetshots.gd").
## Finds an example of each kind near ST_X, ST_Z from the streets data itself: a shopping street, an old-town
## street, an estate street, a car park (bay lines), the traffic lights, a bus stop, and an overhead view.
## Writes /tmp/shots/st_<name>.png. ST_ONLY=name,name limits it.
var out := "/tmp/shots/"
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var main = get_tree().current_scene
	for _i in 20: await get_tree().physics_frame
	var x0 := float(OS.get_environment("ST_X")) if OS.get_environment("ST_X") != "" else -700.0
	var z0 := float(OS.get_environment("ST_Z")) if OS.get_environment("ST_Z") != "" else -60.0
	var only := OS.get_environment("ST_ONLY").split(",", false)
	var f = main.forge
	if not f.active: f.toggle()
	f._set_palette(false)
	f.ui.visible = false
	if SkyCycle.inst:
		SkyCycle.inst.set_manual(0.42, 0.0); SkyCycle.inst.frozen = true
	var s: Streets = Streets.inst
	var shots := []
	# street-level shots along kerbs of each profile
	for want in [[0, "main"], [1, "town"], [2, "estate"]]:
		var ex := _find_kerb(s, x0, z0, int(want[0]))
		if ex.is_empty(): continue
		var p: Vector2 = ex.p; var t: Vector2 = ex.t; var n: Vector2 = ex.n
		var eye := p - n * 2.2 - t * 9.0          # in the road, back along the kerb
		var at := p + n * 1.5 + t * 6.0
		shots.append([want[1], Vector3(eye.x, 1.7, eye.y), Vector3(at.x, 0.4, at.y)])
		var eye2 := p - n * 4.0 + t * 1.0
		shots.append([want[1] + "_up", Vector3(eye2.x, 4.0, eye2.y), Vector3(p.x + n.x * 2.0, 0.0, p.y + n.y * 2.0)])
	var fk := {}
	for kind in [1, 3, 6]:
		var e := _find_furn(s, x0, z0, kind)
		if e.is_empty(): continue
		var fw := Vector2(sin(e.yaw), cos(e.yaw))
		var c: Vector2 = e.p + fw * 7.0 + Vector2(fw.y, -fw.x) * 3.0
		shots.append([{1: "lights", 3: "busstop", 6: "lamps"}[kind], Vector3(c.x, 1.8, c.y), Vector3(e.p.x, 1.6, e.p.y)])
	var cp := _find_bays(s, x0, z0)
	if cp.x < INF:
		shots.append(["carpark", Vector3(cp.x + 12, 9.0, cp.y + 12), Vector3(cp.x, 0, cp.y)])
	shots.append(["overhead", Vector3(x0 + 60, 110.0, z0 + 60), Vector3(x0, 0, z0)])
	for sh in shots:
		if not only.is_empty() and not (sh[0] in only): continue
		var eye: Vector3 = sh[1]; var at: Vector3 = sh[2]
		eye.y += main.height_at(eye.x, eye.z); at.y += main.height_at(at.x, at.z)
		f.cam.global_position = eye
		f.cam.look_at(at)
		f.yaw = f.cam.rotation.y; f.pitch = f.cam.rotation.x
		# let the streets, the road paint and the buildings come in round the new spot
		var t0 := Time.get_ticks_msec()
		for _i in 70: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(out + "st_%s.png" % sh[0])
		print("SHOT st_%s at %s (%d ms, %d street tiles)" % [sh[0], eye.round(), Time.get_ticks_msec() - t0, s._tiles.size()])
	get_tree().quit()

func _find_kerb(s: Streets, x0: float, z0: float, prof: int) -> Dictionary:
	var best := {}; var bd := 700.0
	for k: Vector2i in s._index:
		var cx := s._ox + (k.x + 0.5) * Streets.TILE; var cz := s._oz + (k.y + 0.5) * Streets.TILE
		if absf(cx - x0) > bd or absf(cz - z0) > bd: continue
		var d := s._tile_data(k)
		for run in d.kerb:
			if int(run[0]) != prof: continue
			var pts: PackedVector2Array = run[1]
			if pts.size() < 12: continue
			var a := pts[4]; var b := pts[10]
			if a.distance_to(b) < 9.0: continue           # want a straight-ish stretch
			var dd := Vector2(a.x - x0, a.y - z0).length()
			if dd < bd:
				var t := (b - a).normalized()
				bd = dd; best = {"p": a, "t": t, "n": Vector2(t.y, -t.x)}
	return best

func _find_furn(s: Streets, x0: float, z0: float, kind: int) -> Dictionary:
	var best := {}; var bd := 900.0
	for k: Vector2i in s._index:
		var cx := s._ox + (k.x + 0.5) * Streets.TILE; var cz := s._oz + (k.y + 0.5) * Streets.TILE
		if absf(cx - x0) > bd or absf(cz - z0) > bd: continue
		for fu in s._tile_data(k).furn:
			if int(fu[0]) != kind: continue
			var dd := Vector2(float(fu[1]) - x0, float(fu[2]) - z0).length()
			if dd < bd: bd = dd; best = {"p": Vector2(float(fu[1]), float(fu[2])), "yaw": float(fu[3])}
	return best

func _find_bays(s: Streets, x0: float, z0: float) -> Vector2:
	var best := Vector2.ZERO; var bd := 900.0; var found := false
	for k: Vector2i in s._index:
		var cx := s._ox + (k.x + 0.5) * Streets.TILE; var cz := s._oz + (k.y + 0.5) * Streets.TILE
		if absf(cx - x0) > bd or absf(cz - z0) > bd: continue
		for p in s._tile_data(k).paint:
			if float(p[1]) < 0.5: continue
			var tri: PackedFloat32Array = p[2]
			if tri.size() < 600: continue                 # lots of little rectangles: bay lines
			var c := Vector2(tri[0], tri[1])
			var dd := Vector2(c.x - x0, c.y - z0).length()
			if dd < bd: bd = dd; best = c; found = true
	return best if found else Vector2(INF, INF)
