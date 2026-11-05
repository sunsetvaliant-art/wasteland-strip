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
	var ps: PackedScene = load("res://assets/characters/%s.glb" % key)
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

var _head_hidden := false
func _process(dt: float) -> void:
	if anim:
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
