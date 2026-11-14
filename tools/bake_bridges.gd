extends SceneTree
## One-off: pulls every bridge out of the baked road tiles (assets/roads/road_X_Z.glb, which hold only bridges since
## the roads went flush) into assets/world/bridges.json, so the modular bridge kit (scripts/world/bridge_kit.gd) can
## rebuild them. Per bridge: the deck centreline [x, y, z] (world, top of the seal), seal half-width, marking style,
## wildness. Pieces cut by tile edges are joined back up.
##   godot --headless --path . -s tools/bake_bridges.gd
func _init():
	var idx = JSON.parse_string(FileAccess.get_file_as_string("res://assets/roads/index.json"))
	var pieces := []
	for t in idx.tiles:
		if str(t.get("file", "")) == "": continue
		var s: Node3D = (load("res://assets/roads/" + t.file) as PackedScene).instantiate()
		
		for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
			var xf := s.transform * _xf_to(s, mi)
			var m: Mesh = mi.mesh
			for k in m.get_surface_count():
				var mat := m.surface_get_material(k)
				if mat == null or mat.resource_name != "deck": continue
				var a := m.surface_get_arrays(k)
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
				var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
				var col: PackedColorArray = a[Mesh.ARRAY_COLOR]
				var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				# connected triangle groups = separate decks
				var par := PackedInt32Array(); par.resize(v.size())
				for i in v.size(): par[i] = i
				var find := func(i: int) -> int:
					while par[i] != i:
						par[i] = par[par[i]]; i = par[i]
					return i
				for i in range(0, ix.size(), 3):
					var r0: int = find.call(ix[i]); var r1: int = find.call(ix[i + 1]); var r2: int = find.call(ix[i + 2])
					par[r1] = r0; par[r2] = r0
				var groups := {}
				for i in v.size():
					if absf(uv[i].x) > 0.02: continue
					var r: int = find.call(i)
					if not groups.has(r): groups[r] = []
					groups[r].append(i)
				for r in groups:
					var ids: Array = groups[r]
					ids.sort_custom(func(p, q): return uv[p].y < uv[q].y)
					var pts := []
					var last := -1e9
					for i in ids:
						if uv[i].y - last < 0.05: continue
						last = uv[i].y
						var w := xf * v[i]
						pts.append([snappedf(w.x, 0.01), snappedf(w.y, 0.01), snappedf(w.z, 0.01)])
					if pts.size() < 2: continue
					var i0: int = ids[0]
					pieces.append({"pts": pts, "hw": snappedf(uv2[i0].x, 0.01), "mark": snappedf(col[i0].g, 0.01), "wild": snappedf(col[i0].a, 0.01)})
		s.free()
	print("BAKEBR pieces ", pieces.size())
	# join pieces whose ends meet (tile edges)
	var joined := true
	while joined:
		joined = false
		for i in pieces.size():
			for j in pieces.size():
				if i == j or pieces[i] == null or pieces[j] == null: continue
				var a: Array = pieces[i].pts; var b: Array = pieces[j].pts
				if absf(float(pieces[i].hw) - float(pieces[j].hw)) > 0.05: continue
				var ae := Vector3(a[-1][0], a[-1][1], a[-1][2])
				if ae.distance_to(Vector3(b[0][0], b[0][1], b[0][2])) < 1.0:
					pieces[i].pts = a + b.slice(1); pieces[j] = null; joined = true
				elif ae.distance_to(Vector3(b[-1][0], b[-1][1], b[-1][2])) < 1.0:
					var rb := b.duplicate(); rb.reverse()
					pieces[i].pts = a + rb.slice(1); pieces[j] = null; joined = true
	var out := []
	for p in pieces:
		if p != null: out.append(p)
	var f := FileAccess.open("res://assets/world/bridges.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": 1, "bridges": out}))
	f.close()
	print("BAKEBR bridges ", out.size())
	quit()

func _xf_to(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D()
	var c: Node = n
	while c != null and c != root:
		if c is Node3D: xf = (c as Node3D).transform * xf
		c = c.get_parent()
	return xf
