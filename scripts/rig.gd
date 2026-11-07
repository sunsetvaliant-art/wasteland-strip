class_name Rig
extends Node3D
## A Meshy/Mixamo character: the model, its skeleton and every animation clip we have, pooled from all the
## character files (they share the Mixamo skeleton, so a clip from one plays on any of them).
## set_motion(speed) blends idle -> walk -> run. Faces -Z like the player and NPC bodies.

const HEIGHT := 1.78
## Every file with clips worth having. All characters are imported with Godot's humanoid retarget (one bone map,
## rests fixed), so a clip from any of them plays on any body.
const CLIP_SOURCES := ["player", "warbringer", "scav_hooded", "warboy", "aclip_army", "aclip_soldier", "zombie_hazmat",
	"zombie_runner", "zombie_soldier", "zombie_mx", "zclip_agony", "zclip_dying", "zombie_hollow"]
## Clip sets: which clip does what for each kind of body
const SETS := {
	"unarmed": {"idle": "Idle_8", "walk": "Walking", "run": "Running", "crouch_idle": "aclip_army__crouch_idle", "crouch_walk": "aclip_army__walk_crouch",
		"walk_speed": 1.4, "run_speed": 5.0, "crouch_speed": 1.1},
	"rifle": {"idle": "aclip_army__idle_simple", "walk": "aclip_army__simple_walk", "run": "aclip_soldier__Rifle_run", "crouch_idle": "aclip_army__crouch_idle",
		"crouch_walk": "aclip_army__walk_crouch", "shoot": "aclip_army__simple_shoot", "reload": "aclip_army__reload_idle", "reload_walk": "aclip_army__reload_walk",
		"walk_speed": 1.5, "run_speed": 5.0, "crouch_speed": 1.1},
	# Zombies move on the Hollow Walker's clips. Each set is a different kind of zombie, and its speeds match its
	# clips' strides (measured off the clips) so the feet don't skate: wander/chase_speed are how fast it goes.
	# walker: walks with purpose, breaks into a run when it's close
	"zombie_a": {"idle": "hollow__Head_Hold_in_Pain", "walk": "hollow__Walking", "run": "hollow__Running", "attack": "zombie_soldier__zombie_02_Attack",
		"spot": "hollow__Zombie_Scream", "walk_speed": 1.4, "run_speed": 4.2, "wander_speed": 0.75, "chase_speed": 1.35, "close_speed": 3.0},
	# shambler: an unsteady drag when it's wandering, a lurching walk when it's after you
	"zombie_b": {"idle": "hollow__Mummy_Stagger", "walk": "hollow__Unsteady_Walk", "run": "hollow__Walking", "attack": "zombie_runner__FEMALE_ZOMBIE_ATTACK",
		"spot": "hollow__Zombie_Scream", "walk_speed": 0.45, "run_speed": 1.4, "wander_speed": 0.4, "chase_speed": 1.15},
	# lurcher: a shaky old walk, then a head-down charge
	"zombie_c": {"idle": "zombie_runner__FEMALE_ZOMBIE_IDLE", "walk": "hollow__Elderly_Shaky_Walk_inplace", "run": "hollow__Male_Head_Down_Charge",
		"attack": "zombie_soldier__zombie_02_Attack", "spot": "hollow__Zombie_Scream", "walk_speed": 0.3, "run_speed": 4.8, "wander_speed": 0.3,
		"chase_speed": 3.2},
}
## Mixamo names (what the rest of the code asks for) -> Godot humanoid profile names (what the bones are now called)
const PROFILE := {"Spine1": "Chest", "Spine2": "UpperChest", "LeftArm": "LeftUpperArm", "LeftForeArm": "LeftLowerArm",
	"RightArm": "RightUpperArm", "RightForeArm": "RightLowerArm", "LeftUpLeg": "LeftUpperLeg", "LeftLeg": "LeftLowerLeg",
	"RightUpLeg": "RightUpperLeg", "RightLeg": "RightLowerLeg", "LeftToeBase": "LeftToes", "RightToeBase": "RightToes"}
static var clip_pool := {}       # clip name -> Animation

static func path_of(key: String) -> String:
	if ResourceLoader.exists("res://assets/characters/%s.glb" % key):
		return "res://assets/characters/%s.glb" % key
	return "res://assets/characters/%s/%s.gltf" % [key, key]

var model: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var head_bone := -1
var _cur := ""
var _speed := 0.0
var model_path := ""
var mods: BodyMods
var frozen := false                  # dead: the ragdoll has the bones now
var tint_mat_cache := {}             # original material -> tinted copy (zombies), shared with gibs
var _bone_cache := {}

static func _pool() -> Dictionary:
	if clip_pool.is_empty():
		for src in CLIP_SOURCES:
			var ps: PackedScene = load(path_of(src)) if ResourceLoader.exists(path_of(src)) else null
			if ps == null: continue
			var n := ps.instantiate()
			var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0] if n.find_children("*", "AnimationPlayer", true, false).size() else null
			if ap:
				for a in ap.get_animation_list():
					if a != "RESET" and not clip_pool.has(a):
						var clip: Animation = ap.get_animation(a).duplicate()
						clip.resource_name = a
						_strip_root_motion(clip)
						clip_pool[a] = clip
			n.free()
	return clip_pool

## Mixamo clips walk the hips forward; we move the body ourselves, so keep the hips over the feet
static func _strip_root_motion(a: Animation) -> void:
	for t in a.get_track_count():
		var p := str(a.track_get_path(t))
		if a.track_get_type(t) == Animation.TYPE_POSITION_3D and p.ends_with(":Hips"):
			for k in a.track_get_key_count(t):
				var v: Vector3 = a.track_get_key_value(t, k)
				a.track_set_key_value(t, k, Vector3(0, v.y, 0))
	var n := a.resource_name.to_lower()
	for w in ["run", "walk", "idle", "crouch", "stagger", "charge", "head_hold"]:
		if n.contains(w) and not n.contains("death") and not n.contains("to_") and not n.contains("reload"):
			a.loop_mode = Animation.LOOP_LINEAR

func load_model(key: String) -> void:
	model_path = path_of(key)
	var ps: PackedScene = load(model_path)
	model = ps.instantiate()
	add_child(model)
	skel = model.find_children("*", "Skeleton3D", true, false)[0]
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	anim = aps[0] if aps.size() else AnimationPlayer.new()
	if anim.get_parent() == null: model.add_child(anim)
	# every clip in the pool, retargeted by path: the tracks point at Skeleton3D:<bone>
	var lib := AnimationLibrary.new()
	var skel_path := anim.get_node(anim.root_node).get_path_to(skel)
	for name in _pool():
		var clip: Animation = clip_pool[name].duplicate()
		for t in clip.get_track_count():
			var p := str(clip.track_get_path(t))
			var colon := p.find(":")
			if colon >= 0:
				clip.track_set_path(t, NodePath(str(skel_path) + p.substr(colon)))
		lib.add_animation(name, clip)
	if anim.has_animation_library("pool"): anim.remove_animation_library("pool")
	anim.add_animation_library("pool", lib)
	# scale to a real person's height, feet on the ground, facing -Z
	# size from the skeleton, not the mesh (some exports carry odd mesh bounds): head bone to foot bone is about
	# 1.52 m on a 1.78 m person, and the ankle sits ~9 cm off the ground
	var into := model.global_transform.affine_inverse() * skel.global_transform if model.is_inside_tree() else _chain_xf(model, skel)
	var hb := skel.find_bone("Head")
	var fb := skel.find_bone("LeftFoot")
	if hb >= 0 and fb >= 0:
		var hy: float = (into * skel.get_bone_global_rest(hb).origin).y
		var fy: float = (into * skel.get_bone_global_rest(fb).origin).y
		var s: float = 1.52 / max(hy - fy, 0.01)
		model.scale = Vector3.ONE * s
		model.position.y = -fy * s + 0.09
	else:
		var aabb := _aabb()
		var s: float = HEIGHT / max(aabb.size.y, 0.01)
		model.scale = Vector3.ONE * s
		model.position.y = -aabb.position.y * s
	model.rotation.y = PI
	head_bone = skel.find_bone("Head")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	play("Idle_8")
	mods = BodyMods.new()
	mods.rig = self
	skel.add_child(mods)

var _head_hidden := false
func _process(dt: float) -> void:
	if action != "":
		_action_t -= dt
		if _action_t <= 0.15:
			action = ""
	if anim and not frozen:
		anim.advance(dt)
		if _head_hidden and head_bone >= 0:
			skel.set_bone_pose_scale(head_bone, Vector3.ONE * 0.001)

static func _chain_xf(top: Node3D, n: Node) -> Transform3D:
	var xf := Transform3D()
	var p: Node = n
	while p != top and p != null:
		if p is Node3D: xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf

func _aabb() -> AABB:
	var out := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		b = (model.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform) * b if mi.is_inside_tree() else b
		out = b if first else out.merge(b)
		first = false
	return out

## Mixamo bone by short name ("Hips", "LeftForeArm"), whichever prefix this export used
func bone(n: String) -> int:
	if _bone_cache.has(n):
		return _bone_cache[n]
	var i := skel.find_bone(PROFILE.get(n, n))
	if i < 0: i = skel.find_bone("mixamorig_" + n)
	if i < 0: i = skel.find_bone(n)
	_bone_cache[n] = i
	return i

## World position of a bone
func bone_pos(n: String) -> Vector3:
	var b := bone(n)
	return skel.global_transform * skel.get_bone_global_pose(b).origin if b >= 0 else global_position

## Every body part's bone, for working out what a bullet hit (nearest bone to the hit point)
const HIT_BONES := {"head": "Head", "chest": "Spine2", "pelvis": "Hips", "l_upperarm": "LeftArm", "l_forearm": "LeftForeArm",
	"r_upperarm": "RightArm", "r_forearm": "RightForeArm", "l_thigh": "LeftUpLeg", "l_shin": "LeftLeg", "r_thigh": "RightUpLeg", "r_shin": "RightLeg"}
const HIT_ENDS := {"head": "HeadTop_End", "chest": "Neck", "pelvis": "Spine", "l_upperarm": "LeftForeArm", "l_forearm": "LeftHand",
	"r_upperarm": "RightForeArm", "r_forearm": "RightHand", "l_thigh": "LeftLeg", "l_shin": "LeftFoot", "r_thigh": "RightLeg", "r_shin": "RightFoot"}
const HIT_RADIUS := {"head": 0.11, "chest": 0.17, "pelvis": 0.15, "l_upperarm": 0.055, "r_upperarm": 0.055, "l_forearm": 0.045,
	"r_forearm": 0.045, "l_thigh": 0.085, "r_thigh": 0.085, "l_shin": 0.06, "r_shin": 0.06}
## Which body part a shot hit: the bullet's path through the body (entry point p, direction dir) against each part
## as a capsule round its bone; the first part the line actually passes through wins.
func part_at(p: Vector3, dir := Vector3.ZERO) -> String:
	var best := "chest"
	var bd := 1e9
	var through := dir.length() > 0.01
	var a0 := p - dir.normalized() * 0.4 if through else p
	var a1 := p + dir.normalized() * 0.9 if through else p
	var first_t := 1e9
	for part in HIT_BONES:
		if mods and mods.crushed.has(bone(HIT_BONES[part])):
			continue
		var a := bone_pos(HIT_BONES[part])
		var b := bone_pos(HIT_ENDS[part])
		var r: float = HIT_RADIUS[part]
		var cp := Geometry3D.get_closest_points_between_segments(a0, a1, a, b)
		var d: float = cp[0].distance_to(cp[1]) - r
		if through and d <= 0.0:
			var t: float = a0.distance_to(cp[0])
			if t < first_t:
				first_t = t
				best = part
				bd = -1.0
		elif first_t == 1e9 and d < bd:
			bd = d
			best = part
	return best

## Remove a body part's bone chain from this skeleton (it's become a gib); leaves a stump
func sever(part: String) -> bool:
	if not Ragdoll.CHAIN.has(part):
		return false
	var b := bone(HIT_BONES[part])
	if b < 0 or mods.crushed.has(b):
		return false
	mods.severed[b] = true
	mods.crushed[b] = true
	for i in skel.get_bone_count():
		var pa := skel.get_bone_parent(i)
		if pa >= 0 and mods.crushed.has(pa):
			mods.crushed[i] = true
	Gore.stump(self, b, skel.get_bone_parent(b))
	return true

## Zombie skin: every material tinted grey-green and dirtied (copies, shared with this body's gibs)
func tint(c: Color, rough := 0.9) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(s)
			if not (src is BaseMaterial3D):
				continue
			if not tint_mat_cache.has(src):
				var t: BaseMaterial3D = src.duplicate()
				t.albedo_color = t.albedo_color * c
				t.roughness = rough
				tint_mat_cache[src] = t
			m.set_surface_override_material(s, tint_mat_cache[src])

func has_clip(n: String) -> bool:
	return anim.has_animation("pool/" + n)

func play(n: String, blend := 0.25, speed_scale := 1.0) -> void:
	if not has_clip(n):
		return
	if _cur != n:
		anim.play("pool/" + n, blend, 1.0)
		_cur = n
	anim.speed_scale = speed_scale

## speed in m/s: 0 idle, ~1.6 walk, ~5.8 run (old callers; uses the unarmed set)
func set_motion(speed: float) -> void:
	locomote("unarmed", speed, false, 0.0)

var action := ""                     # a one-shot playing over the locomotion (attack, reload, scream)
var _action_t := 0.0
## Pick the right clip from a set for how fast and which way we're going (move_angle: radians from the body's
## facing, + = to the left). Sideways the hips swing round toward the direction of travel and the chest stays
## facing forward; going backwards the walk runs in reverse.
func locomote(set_name: String, speed: float, crouch: bool, move_angle: float) -> void:
	_speed = speed
	var st: Dictionary = SETS.get(set_name, SETS.unarmed)
	if action != "":
		mods.hip_yaw = lerpf(mods.hip_yaw, 0.0, 0.2)
		return
	var back: bool = abs(move_angle) > deg_to_rad(110.0) and speed > 0.3
	var hip := 0.0
	if speed > 0.3:
		hip = move_angle if not back else wrapf(move_angle - PI, -PI, PI)
		hip = clamp(hip, -1.2, 1.2)
	mods.hip_yaw = lerpf(mods.hip_yaw, hip, 0.15)
	var dir := -1.0 if back else 1.0
	if crouch:
		if speed < 0.2: play(st.get("crouch_idle", st.idle), 0.3)
		else: play(st.get("crouch_walk", st.walk), 0.3, dir * clamp(speed / float(st.get("crouch_speed", 1.1)), 0.5, 1.6))
	elif speed < 0.2:
		play(st.idle, 0.3)
	elif speed < float(st.walk_speed) * 1.9:
		play(st.walk, 0.3, dir * clamp(speed / float(st.walk_speed), 0.4, 1.7))
	else:
		play(st.run, 0.3, dir * clamp(speed / float(st.run_speed), 0.6, 1.5))

## A one-shot clip (attack, reload, scream): plays once, then locomotion takes over again
func act(clip: String, speed := 1.0, blend := 0.2) -> float:
	if not has_clip(clip):
		return 0.0
	action = clip
	_cur = ""
	anim.play("pool/" + clip, blend, speed)
	_action_t = anim.current_animation_length / max(speed, 0.01)
	return _action_t

## First person: shrink the head so the camera sits inside an empty skull (the body still casts its full shadow)
func hide_head(on: bool) -> void:
	_head_hidden = on
	if head_bone >= 0 and not on:
		skel.set_bone_pose_scale(head_bone, Vector3.ONE)

func head_position() -> Vector3:
	if head_bone < 0:
		return global_position + Vector3(0, 1.65, 0)
	return skel.global_transform * skel.get_bone_global_pose(head_bone).origin
