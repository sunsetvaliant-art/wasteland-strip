extends Node
## lists clips with how far the hips travel per second (the stride speed a body should move at to match)
func _ready():
	for src in Rig.CLIP_SOURCES:
		var ps: PackedScene = load(Rig.path_of(src)) if ResourceLoader.exists(Rig.path_of(src)) else null
		if ps == null: continue
		var n := ps.instantiate()
		var aps := n.find_children("*", "AnimationPlayer", true, false)
		if aps.size():
			var ap: AnimationPlayer = aps[0]
			for a in ap.get_animation_list():
				var lo := a.to_lower()
				if not (lo.contains("walk") or lo.contains("stagger") or lo.contains("run")): continue
				var an := ap.get_animation(a)
				var sp := -1.0
				for t in an.get_track_count():
					if an.track_get_type(t) == Animation.TYPE_POSITION_3D and str(an.track_get_path(t)).ends_with(":Hips") and an.track_get_key_count(t) > 1:
						var v0: Vector3 = an.track_get_key_value(t, 0); var v1: Vector3 = an.track_get_key_value(t, an.track_get_key_count(t) - 1)
						sp = Vector2(v1.x - v0.x, v1.z - v0.z).length() / an.length
				print("CL %-14s %-40s %.2f s  hips %.2f m/s" % [src, a, an.length, sp])
		n.free()
	get_tree().quit()
