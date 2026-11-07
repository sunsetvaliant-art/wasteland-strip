extends SceneTree
## Bakes the Road Generator roads (assets/roads/rg_graph.json, tools/road_graph.py) into 1 km tiles of plain meshes
## (assets/roads_rg/rg_X_Z.res + index.json), so the game loads finished road surface instead of running the addon.
##   godot --headless --path . -s tools/bake_rg.gd          BOX=x0,z0,x1,z1 to bake just part of the map (testing)
const X0 := -8960.0
const Z0 := -16960.0
const TILE := 1024.0

func _init() -> void:
	await process_frame
	var t0 := Time.get_ticks_msec()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/roads/rg_graph.json"))
	var box := OS.get_environment("BOX").split(",", false)
	if box.size() == 4:
		var bx := [float(box[0]), float(box[1]), float(box[2]), float(box[3])]
		var inside := func(p) -> bool: return p[0] > bx[0] and p[0] < bx[2] and p[2] > bx[1] and p[2] < bx[3]
		var js := {}
		var jl := []
		for j in d.junctions:
			if inside.call(j.pos): js[j.id] = true; jl.append(j)
		var el := []
		for e in d.edges:
			if (e.pts as Array).all(func(p): return inside.call(p)):
				if not js.has(e.a): e.a = null
				if not js.has(e.b): e.b = null
				el.append(e)
		d = {"edges": el, "junctions": jl}
	print("RG baking ", d.edges.size(), " edges, ", d.junctions.size(), " junctions")
	# a block at a time (tools/road_graph.py cut the graph into 2 km blocks): the addon slows right down on big graphs
	var blocks := {}
	for e in d.edges:
		var k: String = str(e.get("block", [0, 0]))
		if not blocks.has(k): blocks[k] = {"edges": [], "junctions": []}
		blocks[k].edges.append(e)
	for j in d.junctions:
		var k: String = str(j.get("block", [0, 0]))
		if not blocks.has(k): blocks[k] = {"edges": [], "junctions": []}
		blocks[k].junctions.append(j)
	var tiles := {}
	var n_mi := 0
	var islands := []
	var bi := 0
	for k in blocks:
		bi += 1
		var rp := RoadPilot.new()
		rp.make_islands = false
		root.add_child(rp)
		rp.build(blocks[k])
		for e in rp.islands: islands.append([e[0].x, e[0].y, e[0].z, e[1]])
		# every piece of road surface, into the tile its middle falls in
		for mi: MeshInstance3D in rp.container.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null: continue
			var xf := mi.global_transform
			var c: Vector3 = xf * mi.mesh.get_aabb().get_center()
			var key := Vector2i(int(floor((c.x - X0) / TILE)), int(floor((c.z - Z0) / TILE)))
			if not tiles.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tiles[key] = st
			var origin := Vector3(X0 + (key.x + 0.5) * TILE, 0, Z0 + (key.y + 0.5) * TILE)
			for si in mi.mesh.get_surface_count():
				(tiles[key] as SurfaceTool).append_from(mi.mesh, si, Transform3D(xf.basis, xf.origin - origin))
			n_mi += 1
		rp.queue_free()
		await process_frame
		if bi % 10 == 0: print("RG block %d/%d  %.0f s" % [bi, blocks.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	DirAccess.make_dir_recursive_absolute("res://assets/roads_rg")
	var index := []
	for key in tiles:
		var st: SurfaceTool = tiles[key]
		var m := st.commit()
		var fn := "rg_%d_%d.res" % [key.x, key.y]
		ResourceSaver.save(m, "res://assets/roads_rg/" + fn, ResourceSaver.FLAG_COMPRESS)
		index.append({"file": fn, "x": X0 + (key.x + 0.5) * TILE, "z": Z0 + (key.y + 0.5) * TILE})
	var isl := islands
	var f := FileAccess.open("res://assets/roads_rg/index.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"tile": TILE, "tiles": index, "islands": isl}))
	f.close()
	print("RG tiles ", tiles.size(), " from ", n_mi, " meshes, total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()
