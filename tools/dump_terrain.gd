extends SceneTree
## 0.2.73: dump every Terrain3D region's height and control maps to /tmp/td/<rx>_<rz>_{h,c}.bin (float32 1024 x 1024)
## for tools/coast_fix.py. run: godot --headless --path . -s res://tools/dump_terrain.gd
func _init():
	var t := Terrain3D.new()
	t.vertex_spacing = 5.0
	t.data_directory = "res://terrain"
	root.add_child(t)
	for i in 5: await process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/td")
	print("TD region size ", t.region_size, " count ", t.data.get_region_count())
	for loc in t.data.get_region_locations():
		var r: Terrain3DRegion = t.data.get_region(loc)
		var hm: Image = r.get_height_map()
		var cm: Image = r.get_control_map()
		var f := FileAccess.open("/tmp/td/%d_%d_h.bin" % [loc.x, loc.y], FileAccess.WRITE); f.store_buffer(hm.get_data()); f.close()
		var g := FileAccess.open("/tmp/td/%d_%d_c.bin" % [loc.x, loc.y], FileAccess.WRITE); g.store_buffer(cm.get_data()); g.close()
		print("TD ", loc, " ", hm.get_format(), " ", cm.get_format(), " ", hm.get_size())
	quit()
