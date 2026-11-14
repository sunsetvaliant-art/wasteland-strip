extends SceneTree
## Mixamo FBX clips (assets/characters/mx_src/*.fbx, imported with the humanoid retarget like every character) ->
## one small animation library the game ships: assets/characters/mx_clips.res. The FBX files themselves stay out of
## git and out of the export (they're on the user's Drive, WASTELAND/mixamo; names in TODO.md).
##   godot --headless --path . -s tools/bake_mixamo.gd
func _init():
	var lib := AnimationLibrary.new()
	var d := "res://assets/characters/mx_src/"
	for f in DirAccess.get_files_at(d):
		if not f.ends_with(".fbx"): continue
		var n: Node = (load(d + f) as PackedScene).instantiate()
		var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
		var nm := "mixamo_com" if ap.has_animation("mixamo_com") else ap.get_animation_list()[0]
		var a: Animation = ap.get_animation(nm).duplicate(true)
		a.resource_name = f.get_basename()
		lib.add_animation(f.get_basename(), a)
		print("MXBAKE ", f.get_basename(), " ", snappedf(a.length, 0.01), " s, ", a.get_track_count(), " tracks, first ", a.track_get_path(0))
		n.free()
	print("MXBAKE save ", ResourceSaver.save(lib, "res://assets/characters/mx_clips.res", ResourceSaver.FLAG_COMPRESS))
	quit()
