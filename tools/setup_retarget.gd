extends SceneTree
## One humanoid bone map for every character, and import settings that rename the bones to Godot's humanoid
## profile and fix the rests, so any clip plays on any body. Run once after adding characters, then --import.
const MAP := {"Hips": "Hips", "Spine": "Spine", "Chest": "Spine1", "UpperChest": "Spine2", "Neck": "Neck", "Head": "Head",
	"LeftShoulder": "LeftShoulder", "LeftUpperArm": "LeftArm", "LeftLowerArm": "LeftForeArm", "LeftHand": "LeftHand",
	"RightShoulder": "RightShoulder", "RightUpperArm": "RightArm", "RightLowerArm": "RightForeArm", "RightHand": "RightHand",
	"LeftUpperLeg": "LeftUpLeg", "LeftLowerLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToes": "LeftToeBase",
	"RightUpperLeg": "RightUpLeg", "RightLowerLeg": "RightLeg", "RightFoot": "RightFoot", "RightToes": "RightToeBase"}
const FINGERS := {"Thumb": ["ThumbMetacarpal", "ThumbProximal", "ThumbDistal"], "Index": ["IndexProximal", "IndexIntermediate", "IndexDistal"],
	"Middle": ["MiddleProximal", "MiddleIntermediate", "MiddleDistal"], "Ring": ["RingProximal", "RingIntermediate", "RingDistal"],
	"Pinky": ["LittleProximal", "LittleIntermediate", "LittleDistal"]}
func _init():
	var bm := BoneMap.new()
	bm.profile = SkeletonProfileHumanoid.new()
	for p in MAP: bm.set_skeleton_bone_name(p, "mixamorig_" + MAP[p])
	for side in ["Left", "Right"]:
		for f in FINGERS:
			for i in 3: bm.set_skeleton_bone_name(side + FINGERS[f][i], "mixamorig_%sHand%s%d" % [side, f, i + 1])
	ResourceSaver.save(bm, "res://assets/characters/mixamo_bonemap.tres")
	var files := []
	var d := "res://assets/characters/"
	for f in DirAccess.get_files_at(d):
		if f.ends_with(".glb"): files.append(d + f)
	for sub in DirAccess.get_directories_at(d):
		for f in DirAccess.get_files_at(d + sub):
			if f.ends_with(".gltf"): files.append(d + sub + "/" + f)
	for f in files:
		var ps: PackedScene = load(f)
		if ps == null: print("RT skip ", f); continue
		var n := ps.instantiate()
		var sks := n.find_children("*", "Skeleton3D", true, false)
		if sks.is_empty(): print("RT no skeleton ", f); n.free(); continue
		var path := str(n.get_path_to(sks[0]))
		if path.ends_with("GeneralSkeleton"):
			path = path.trim_suffix("GeneralSkeleton") + "Skeleton3D"      # already retargeted: the import-time name
		n.free()
		var imp := ProjectSettings.globalize_path(f + ".import")
		var txt := FileAccess.get_file_as_string(imp)
		var sub := '_subresources={\n"nodes": {\n"PATH:%s": {\n"retarget/bone_map": Resource("res://assets/characters/mixamo_bonemap.tres"),\n"retarget/bone_renamer/rename_bones": true,\n"retarget/bone_renamer/unique_node/make_unique": true,\n"retarget/bone_renamer/unique_node/skeleton_name": "GeneralSkeleton",\n"retarget/remove_tracks/except_bone_transform": false,\n"retarget/remove_tracks/unimportant_positions": true,\n"retarget/remove_tracks/unmapped_bones": false,\n"retarget/rest_fixer/apply_node_transforms": true,\n"retarget/rest_fixer/normalize_position_tracks": true,\n"retarget/rest_fixer/reset_all_bone_poses_after_import": true,\n"retarget/rest_fixer/overwrite_axis": true,\n"retarget/rest_fixer/fix_silhouette/enable": true\n}\n}\n}' % path
		var lines := txt.split("\n")
		var out := []
		var skip := false
		for l in lines:
			if l.begins_with("_subresources="):
				skip = true
			if skip:
				if l == "}" or l.ends_with("={}") or (l.begins_with("_subresources={}")):
					skip = false
				continue
			out.append(l)
		txt = "\n".join(out).strip_edges() + "\n" + sub + "\n"
		var w := FileAccess.open(imp, FileAccess.WRITE)
		w.store_string(txt)
		w.close()
		print("RT ", f, "  skeleton at ", path)
	quit()
