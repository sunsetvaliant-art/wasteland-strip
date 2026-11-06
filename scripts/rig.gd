class_name Rig
extends Node3D
## A Meshy/Mixamo character: the model, its skeleton and every animation clip we have, pooled from all the
## character files (they share the Mixamo skeleton, so a clip from one plays on any of them).
## set_motion(speed) blends idle -> walk -> run. Faces -Z like the player and NPC bodies.

const HEIGHT := 1.78
const CLIP_SOURCES := ["player", "warbringer", "scav_hooded", "warboy"]
static var clip_pool := {}       # clip name -> Animation

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
			var ps: PackedScene = load("res://assets/characters/%s.glb" % src)
			if ps == null: continue
			var n := ps.instantiate()
			var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0] if n.find_children("*", "AnimationPlayer", true, false).size() else null
			if ap:
				for a in ap.get_animation_list():
					if a != "RESET" and not clip_pool.has(a):
						var clip: Animation = ap.get_animation(a).duplicate()
						_strip_root_motion(clip)
						clip_pool[a] = clip
			n.free()
	return clip_pool

## Mixamo clips walk the hips forward; we move the body ourselves, so keep the hips over the feet
static func _strip_root_motion(a: Animation) -> void:
	for t in a.get_track_count():
		var p := str(a.track_get_path(t))
		if a.track_get_type(t) == Animation.TYPE_POSITION_3D and p.ends_with("Hips"):
			for k in a.track_get_key_count(t):
				var v: Vector3 = a.track_get_key_value(t, k)
				a.track_set_key_value(t, k, Vector3(0, v.y, 0))
	if a.resource_name.contains("Run") or a.resource_name.contains("Walk") or a.resource_name.contains("Idle"):
		a.loop_mode = Animation.LOOP_LINEAR

func load_model(key: String) -> void:
	model_path = "res://assets/characters/%s.glb" % key
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
	var aabb := _aabb()
	var s: float = HEIGHT / max(aabb.size.y, 0.01)
	model.scale = Vector3.ONE * s
	model.position.y = -aabb.position.y * s
	model.rotation.y = PI
	head_bone = skel.find_bone("mixamorig_Head")
	if head_bone < 0: head_bone = skel.find_bone("mixamorig:Head")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	play("Idle_8")
	mods = BodyMods.new()
	mods.rig = self
	skel.add_child(mods)

var _head_hidden := false
func _process(dt: float) -> void:
	if anim and not frozen:
		anim.advance(dt)
		if _head_hidden and head_bone >= 0:
			skel.set_bone_pose_scale(head_bone, Vector3.ONE * 0.001)

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
	var i := skel.find_bone("mixamorig_" + n)
	if i < 0: i = skel.find_bone("mixamorig:" + n)
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
		anim.play("pool/" + n, blend, speed_scale)
		_cur = n
	else:
		anim.speed_scale = speed_scale

## speed in m/s: 0 idle, ~1.6 walk, ~5.8 run
func set_motion(speed: float) -> void:
	_speed = speed
	if speed < 0.25:
		play("Idle_8" if has_clip("Idle_8") else "Idle_11")
	elif speed < 3.2:
		play("Walking", 0.25, clamp(speed / 1.5, 0.6, 1.6))
	else:
		play("Running", 0.25, clamp(speed / 5.5, 0.7, 1.4))

## First person: shrink the head so the camera sits inside an empty skull (the body still casts its full shadow)
func hide_head(on: bool) -> void:
	_head_hidden = on
	if head_bone >= 0 and not on:
		skel.set_bone_pose_scale(head_bone, Vector3.ONE)

func head_position() -> Vector3:
	if head_bone < 0:
		return global_position + Vector3(0, 1.65, 0)
	return skel.global_transform * skel.get_bone_global_pose(head_bone).origin
