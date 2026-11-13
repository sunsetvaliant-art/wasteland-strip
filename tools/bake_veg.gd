extends SceneTree
## One-off: each plant GLB -> one Mesh (every part merged, scaled to its real height, base at y=0, LODs generated),
## saved to res://assets/veg/<key>.res for MultiMesh scattering. Heights are the browser game's VEG_DEF values.
## run: godot --headless --path . --script res://tools/bake_veg.gd

const HEIGHTS := {"jungle": 18.0, "island1": 13.0, "rubberfig": 13.0, "ghostgum": 20.0, "tree2": 11.0, "coconut": 15.0,
	"palms": 12.0, "palm4": 9.0, "banana": 4.5, "bamboo": 10.0, "jacaranda": 12.0, "fern": 1.3, "fern2": 1.1,
	"monstera": 2.4, "elephant": 1.7, "bush1": 1.5, "shrub1": 1.9, "shrub4": 1.4, "weed": 0.9}

# Poly Haven plants (CC0) added 2026-11-13: key -> [model id under assets/ph/nature, height in metres]
const PH := {"pachira": ["pachira_aquatica_01", 3.2], "calathea": ["calathea_orbifolia_01", 0.9],
	"anthurium": ["anthurium_botany_01", 0.8], "fern3": ["fern_02", 1.0], "periwinkle": ["periwinkle_plant", 0.45],
	"shrub2": ["shrub_02", 1.6], "shrub3": ["shrub_03", 1.2], "nettle": ["nettle_plant", 0.7], "stump": ["tree_stump_01", 0.7], "mossrock": ["rock_moss_set_01", 0.8]}

func _init() -> void:
	await process_frame
	var only := OS.get_environment("VEG_ONLY")
	var todo := {}
	for key in HEIGHTS: todo[key] = ["", HEIGHTS[key]]
	for key in PH: todo[key] = PH[key]
	for key in todo:
		if only == "new" and not PH.has(key): continue
		var src: String = "res://assets/veg/%s.glb" % key if str(todo[key][0]) == "" else "res://assets/ph/nature/%s/%s.gltf" % [todo[key][0], todo[key][0]]
		var ps: PackedScene = load(src) if ResourceLoader.exists(src) else null
		if ps == null:
			print("missing ", key); continue
		var inst := ps.instantiate()
		root.add_child(inst)
		await process_frame
		var by_mat := {}     # material -> SurfaceTool
		var aabb := AABB()
		var first := true
		var mis := inst.find_children("*", "MeshInstance3D", true, false)
		for mi: MeshInstance3D in mis:
			var xf := mi.global_transform
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(s)
				var arr := mi.mesh.surface_get_arrays(s)
				var st: SurfaceTool = by_mat.get(mat)
				if st == null:
					st = SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					st.set_material(mat)
					by_mat[mat] = st
				var tmp := ArrayMesh.new()
				tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				st.append_from(tmp, 0, xf)
				var b := xf * tmp.get_aabb()
				aabb = b if first else aabb.merge(b)
				first = false
		var scale: float = float(todo[key][1]) / max(aabb.size.y, 0.001)
		var fix := Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3(-aabb.get_center().x * scale, -aabb.position.y * scale, -aabb.get_center().z * scale))
		var im := ImporterMesh.new()
		for mat in by_mat:
			var st: SurfaceTool = by_mat[mat]
			var m2 := st.commit()
			var st2 := SurfaceTool.new()
			st2.begin(Mesh.PRIMITIVE_TRIANGLES)
			st2.append_from(m2, 0, fix)
			st2.index()
			var a := st2.commit_to_arrays()
			var m3: Material = mat
			if m3 is BaseMaterial3D:
				m3 = m3.duplicate()
				m3.cull_mode = BaseMaterial3D.CULL_DISABLED
				if m3.albedo_texture is ImageTexture:      # spec-gloss materials (the fern) come in as a baked white texture: use the diffuse image
					var idx := 0
					var alt := "res://assets/veg/%s_%d.png" % [key, idx]
					if ResourceLoader.exists(alt):
						m3.albedo_texture = load(alt)
				m3.emission_enabled = false           # some fronds carry a full-white emissive factor
				if m3.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					var cut: float = m3.alpha_scissor_threshold if m3.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.3
					m3.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					m3.alpha_scissor_threshold = clamp(cut, 0.2, 0.35)
				if m3.albedo_texture and m3.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
					m3.backlight_enabled = true
					m3.backlight = Color(0.22, 0.28, 0.12)
				m3.roughness = max(m3.roughness, 0.7)
				m3.metallic = 0.0
				m3.vertex_color_use_as_albedo = false
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, m3)
		im.generate_lods(25.0, 60.0, [])
		var mesh := im.get_mesh()
		ResourceSaver.save(mesh, "res://assets/veg/%s.res" % key, ResourceSaver.FLAG_COMPRESS)
		var tris := 0
		for s in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(s) / 3
		print(key, " parts ", mis.size(), " surfaces ", mesh.get_surface_count(), " tris ", tris, " raw height ", snapped(aabb.size.y, 0.01))
		inst.queue_free()
	quit()
