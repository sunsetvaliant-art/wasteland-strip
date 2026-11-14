extends Node
## Headless: the Mixamo melee wiring. Swings each weapon class, kicks a zombie, knocks one down and watches it get up.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	var main = get_tree().current_scene
	for _i in 60: await get_tree().physics_frame
	var p: Player = main.player
	Settings.set_value("god_mode", true)
	var m = p.melee
	print("MXTEST clips: ", p.rig.has_clip("mx_kick"), " ", p.rig.has_clip("mx_two_down"), " ", p.rig.has_clip("mx_z_up_back"))
	for wpn in ["fists", "knife", "crowbar", "sledge"]:
		m.weapon = wpn
		var ok: bool = m._play_swing(Melee.WEAPONS[wpn])
		var act: String = p.rig.action
		var t := 0.0
		while p.rig.action != "" and t < 4.0:
			await get_tree().physics_frame
			t += 1.0 / 120.0
		print("MXTEST swing %s -> clip %s (%s), body busy %.2f s, weapon time %.2f" % [wpn, act, ok, t, Melee.WEAPONS[wpn].time])
	# a zombie in front of us: kick it
	var fwd := -p.global_transform.basis.z
	var n := NPC.new(); n.kind = "zombie"; main.add_child(n)
	n.global_position = p.global_position + fwd * 1.2
	for _i in 30: await get_tree().physics_frame
	n.face_dir = -fwd
	var p0 := n.global_position
	m.cool = 0.0; m.kick_t = -1.0
	m.kick()
	print("MXTEST kick: body clip %s, hit pending %s" % [p.rig.action, not m._kick_hit.is_empty()])
	for _i in 60: await get_tree().physics_frame
	print("MXTEST 0.5 s after kick: zombie moved %.2f m, down %s, action '%s', stagger %.2f" % [n.global_position.distance_to(p0), n.down_t > 0.0, n.rig.action, n.stagger])
	for _i in 240: await get_tree().physics_frame
	# knock it flat and watch it get up
	if n.down_t <= 0.0: n.knock_down(fwd * 5.0 + Vector3(0, 2, 0), 1.5)
	var t2 := 0.0
	var seen_rise := false
	while t2 < 14.0:
		await get_tree().physics_frame
		t2 += 1.0 / 120.0
		if n.rise_t > 0.0 and not seen_rise:
			seen_rise = true
			print("MXTEST down for %.1f s, getting up: clip '%s' face_up %s rise %.2f s hips y %.2f head y %.2f" % [t2, n.rig.action, n._face_up, n.rise_t, n.rig.bone_pos("Hips").y - n.global_position.y, n.rig.bone_pos("Head").y - n.global_position.y])
		if seen_rise and n.rise_t <= 0.0:
			break
	print("MXTEST up after %.1f s: hips y %.2f head y %.2f state %s tilt %.2f" % [t2, n.rig.bone_pos("Hips").y - n.global_position.y, n.rig.bone_pos("Head").y - n.global_position.y, n.state, n.rig.rotation.x])
	get_tree().quit()
