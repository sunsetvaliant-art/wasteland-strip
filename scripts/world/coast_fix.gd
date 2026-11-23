class_name CoastFix
## 0.2.73: the open coast's beaches, reshaped and sanded (tools/coast_fix.py works it out from the survey; this lays it
## onto the terrain at start, before anything's built on it). Sand bars and lumps that poked up through the surf go
## under, the beach runs up from the water at an even 4.5 % for about 40 m, and it's all sand (half the beach had
## been painted concrete from the aerial colours). Works on Forge-edited terrain too (only those spots change).

const PATH := "res://assets/world/coast_fix.bin"

static func apply(terrain: Terrain3D) -> void:
	if terrain == null or terrain.data == null or not FileAccess.file_exists(PATH): return
	var t0 := Time.get_ticks_msec()
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f.get_buffer(4).get_string_from_ascii() != "CFX1": return
	var n_all := 0
	while f.get_position() < f.get_length():
		var rx := f.get_32(); var rz := f.get_32(); var n := f.get_32()
		if rx >= 0x80000000: rx -= 0x100000000
		if rz >= 0x80000000: rz -= 0x100000000
		var idx := f.get_buffer(n * 4).to_int32_array()
		var hh := f.get_buffer(n * 4).to_float32_array()
		var cc := f.get_buffer(n * 4).to_int32_array()
		var reg: Terrain3DRegion = terrain.data.get_region(Vector2i(rx, rz))
		if reg == null: continue
		var hm: Image = reg.get_height_map()
		var cm: Image = reg.get_control_map()
		if hm == null or cm == null: continue
		var w := hm.get_width()
		var hd := hm.get_data().to_float32_array()
		var cd := cm.get_data().to_int32_array()
		for i in n:
			var k: int = idx[i]
			if k < hd.size():
				hd[k] = hh[i]
				cd[k] = cc[i]
		hm.set_data(w, hm.get_height(), false, hm.get_format(), hd.to_byte_array())
		cm.set_data(w, cm.get_height(), false, cm.get_format(), cd.to_byte_array())
		reg.set_height_map(hm)
		reg.set_control_map(cm)
		reg.calc_height_range()
		n_all += n
	terrain.data.update_maps(Terrain3DRegion.TYPE_MAX, true, false)
	terrain.data.calc_height_range(true)
	print("COAST fix: %d points in %d ms" % [n_all, Time.get_ticks_msec() - t0])
