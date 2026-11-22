extends Node
## 0.2.61 stutter check: hold still in Mount Ruin's main street till it's built, then move the player through town at
## 34 m/s (123 km/h) for 15 s and time the building streamer and plants every frame. NO_FAST_BUILD=1 for the old way.
## Add as PT="*res://tools/_speedperf.gd" under Settings= (see /tmp/runpt.sh)
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	Settings.set_value("god_mode", true)
	var a := Vector3(-760, 0, -89); var b := Vector3(-300, 0, -89)
	var p = main.player
	p.global_position = a + Vector3(0, main.height_at(a.x, a.z) + 2.0, 0)
	var w0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - w0 < 150000: await get_tree().process_frame
	print("SP warm: full %d fps %d" % [Buildings.inst.full.size(), Engine.get_frames_per_second()])
	var bms: Array = []; var vms: Array = []; var fts: Array = []
	var t := 0.0
	var built0: int = Buildings.inst.full.size()
	var fast_frames := 0
	var last := Time.get_ticks_usec()
	while t < 15.0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1e6
		last = now
		fts.append(dt * 1000.0)
		bms.append(float(Prof.cur.get("buildings", 0.0)))
		vms.append(float(Prof.cur.get("plants", 0.0)))
		if Buildings.inst.fast: fast_frames += 1
		t += minf(dt, 0.1)
		var x := a.lerp(b, clampf(t * 34.0 / a.distance_to(b), 0.0, 1.0))
		p.global_position = Vector3(x.x, main.height_at(x.x, x.z) + 2.0, x.z)
		p.velocity = Vector3.ZERO
	var stat := func(arr: Array) -> String:
		var s := arr.duplicate(); s.sort()
		var tot := 0.0
		for v in s: tot += v
		var over := s.filter(func(v): return v > 30.0).size()
		return "mean %.1f p95 %.1f max %.1f over30 %d" % [tot / s.size(), s[int(s.size() * 0.95)], s[-1], over]
	print("SP frames %d fast %d builds during %d" % [fts.size(), fast_frames, Buildings.inst.full.size() - built0])
	print("SP frame ms ", stat.call(fts))
	print("SP buildings ms ", stat.call(bms))
	print("SP plants ms ", stat.call(vms))
	# stop, and the full builds come back
	var w1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - w1 < 60000: await get_tree().process_frame
	print("SP after stop: fast %s full %d boxes %d" % [Buildings.inst.fast, Buildings.inst.full.size(), Buildings.inst._boxes.size()])
	print("SP_DONE")
	get_tree().quit()
