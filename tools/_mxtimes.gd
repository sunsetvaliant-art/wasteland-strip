extends SceneTree
## For each Mixamo clip: when the right hand / either foot is furthest forward and when it's moving fastest
func _init():
	await process_frame
	var rig := Rig.new(); root.add_child(rig); rig.load_model("player")
	var sk := rig.skel
	var names := ["mx_kick", "mx_flying_kick", "mx_swing_side", "mx_swing_down", "mx_swing_back", "mx_stab", "mx_two_power", "mx_two_down", "mx_cross", "mx_hook", "mx_z_stumble", "mx_z_flinch", "mx_z_up_back", "mx_z_up_front"]
	for n in names:
		if not rig.has_clip(n): print("MXT missing ", n); continue
		rig.anim.play("pool/" + n)
		var L: float = rig.anim.current_animation_length
		var out := {}
		for b in ["RightHand", "LeftHand", "RightFoot", "LeftFoot"]:
			var bi := rig.bone(b); var hi := rig.bone("Hips")
			var best_z := -1e9; var tz := 0.0; var best_v := 0.0; var tv := 0.0
			var prev := Vector3.ZERO
			var t := 0.0
			while t <= L:
				rig.anim.seek(t, true)
				var p: Vector3 = sk.get_bone_global_pose(bi).origin - sk.get_bone_global_pose(hi).origin
				if p.z > best_z: best_z = p.z; tz = t
				if t > 0.0 and (p - prev).length() / 0.02 > best_v: best_v = (p - prev).length() / 0.02; tv = t
				prev = p
				t += 0.02
			out[b] = "fwd %.2f@%.2fs fast %.1f@%.2fs" % [best_z, tz, best_v, tv]
		rig.anim.seek(0.0, true)
		var hy0: float = sk.get_bone_global_pose(rig.bone("Hips")).origin.y
		var up: Vector3 = sk.get_bone_global_pose(rig.bone("Spine2")).basis.z
		print("MXT %s len %.2f hipsY0 %.2f chestZ0 %s | RH %s | LH %s | RF %s | LF %s" % [n, L, hy0, up.snapped(Vector3.ONE * 0.1), out.RightHand, out.LeftHand, out.RightFoot, out.LeftFoot])
	quit()
