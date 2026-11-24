extends SceneTree
func _init():
	for key in ["player", "survivor_female", "scav_2", "scav_hooded", "warboy", "zombie_hollow", "zombie_mx", "zombie_fuse", "zombie_female"]:
		var p := Rig.path_of(key)
		if not ResourceLoader.exists(p): print(key, " missing"); continue
		var n: Node = (load(p) as PackedScene).instantiate()
		var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
		var mis := n.find_children("*", "MeshInstance3D", true, false)
		var info := []
		for mi in mis:
			var m := mi as MeshInstance3D
			var vc := 0
			for s in m.mesh.get_surface_count():
				var a := m.mesh.surface_get_arrays(s)
				vc += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				var mat = m.mesh.surface_get_material(s)
				var tex = mat.albedo_texture if mat is BaseMaterial3D else null
				info.append("%s s%d v%d w%d tex=%s nrm=%s" % [m.name, s, (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (a[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).size() / max(1, (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()), tex.resource_path.get_file() if tex else "-", (mat.normal_texture != null) if mat is BaseMaterial3D else "-"])
		var bones := []
		for b in sk.get_bone_count(): bones.append(sk.get_bone_name(b))
		print(key, " bones ", sk.get_bone_count(), " ", bones.slice(0, 70))
		print("   ", info)
		n.free()
	quit()
