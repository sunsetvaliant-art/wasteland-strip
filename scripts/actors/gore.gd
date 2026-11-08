class_name Gore
extends RefCounted
## Blood and bits. Sprays, pools and splats on the ground, spurting stumps, and gibs: a second copy of the character
## that only shows the torn-off limb, steered by that limb's rigid body.

static var _blood_mat: StandardMaterial3D
static var _drop_mesh: SphereMesh
static var _splat_tex: Texture2D
static var _stump_mat: StandardMaterial3D
static var decals: Array = []
const MAX_DECALS := 90

static func blood_mat() -> StandardMaterial3D:
	if _blood_mat == null:
		_blood_mat = StandardMaterial3D.new()
		_blood_mat.albedo_color = Color(0.32, 0.015, 0.01)
		_blood_mat.roughness = 0.25
		_blood_mat.metallic_specular = 0.7
		_blood_mat.vertex_color_use_as_albedo = false
	return _blood_mat

static func stump_mat() -> StandardMaterial3D:
	if _stump_mat == null:
		_stump_mat = StandardMaterial3D.new()
		_stump_mat.albedo_color = Color(0.42, 0.04, 0.03)
		_stump_mat.roughness = 0.4
	return _stump_mat

static func splat_tex() -> Texture2D:
	if _splat_tex == null:
		# a lumpy splat with droplets round it, drawn once
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var noise := FastNoiseLite.new()
		noise.frequency = 0.06
		noise.seed = 3
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		var drops: Array = []
		for i in 14:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.42, 0.85) * n * 0.5
			drops.append([Vector2(n * 0.5, n * 0.5) + Vector2(cos(a), sin(a)) * r, rng.randf_range(1.5, 4.5)])
		for y in n:
			for x in n:
				var p := Vector2(x, y)
				var d := p.distance_to(Vector2(n * 0.5, n * 0.5)) / (n * 0.5)
				var v := 1.0 - smoothstep(0.35, 0.55, d + noise.get_noise_2d(x, y) * 0.35)
				for dr in drops:
					v = max(v, 1.0 - smoothstep(dr[1] * 0.6, dr[1], p.distance_to(dr[0])))
				var dark := 0.75 + 0.25 * noise.get_noise_2d(x * 3.0, y * 3.0)
				img.set_pixel(x, y, Color(0.3 * dark, 0.01, 0.008, v * 0.92))
		img.generate_mipmaps()
		_splat_tex = ImageTexture.create_from_image(img)
	return _splat_tex

## A burst of droplets in a cone around dir, with a splat where it lands
static func spray(parent: Node, pos: Vector3, dir: Vector3, amount := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = int(clamp(18.0 * amount, 6.0, 90.0))
	p.lifetime = 0.9
	if _drop_mesh == null:
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 0.012
		_drop_mesh.height = 0.024
		_drop_mesh.radial_segments = 4
		_drop_mesh.rings = 2
		_drop_mesh.material = blood_mat()
	p.mesh = _drop_mesh
	p.direction = Vector3(0, 0, -1)
	p.spread = 28.0
	p.initial_velocity_min = 1.5 * amount + 1.0
	p.initial_velocity_max = 4.5 * amount + 2.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 2.2 * clamp(amount, 0.5, 2.0)
	parent.add_child(p)
	p.global_position = pos
	if dir.length() > 0.01:
		p.look_at(pos + dir, Vector3.UP if abs(dir.normalized().y) < 0.95 else Vector3.RIGHT)
	p.emitting = true
	parent.get_tree().create_timer(1.6).timeout.connect(p.queue_free)
	# where it lands
	var space := (parent as Node3D).get_world_3d().direct_space_state if parent is Node3D else null
	if space:
		var land := pos + dir.normalized() * 0.8 * amount + Vector3(0, -0.3, 0)
		var q := PhysicsRayQueryParameters3D.create(land + Vector3.UP * 1.5, land + Vector3.DOWN * 4.0, 1)
		var hit := space.intersect_ray(q)
		if hit:
			splat(parent, hit.position, hit.normal, 0.35 + 0.35 * amount)

static func splat(parent: Node, pos: Vector3, normal: Vector3, size := 0.6) -> void:
	var d := Decal.new()
	d.texture_albedo = splat_tex()
	d.size = Vector3(size, 0.6, size)
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.cull_mask = 1
	parent.add_child(d)
	d.global_position = pos
	var up := normal.normalized()
	var x := up.cross(Vector3.FORWARD if abs(up.z) < 0.9 else Vector3.RIGHT).normalized()
	d.global_basis = Basis(x, up, x.cross(up)).rotated(up, randf() * TAU)
	decals.append(d)
	while decals.size() > MAX_DECALS:
		var o = decals.pop_front()
		if is_instance_valid(o): o.queue_free()

## A stump: dark red cap at the joint, spurting in pulses for a few seconds
static func stump(rig, bone: int, parent_bone: int) -> void:
	# hang it off the parent bone at the joint: the cut bone itself has been crushed to nothing
	var at := BoneAttachment3D.new()
	rig.skel.add_child(at)
	at.bone_idx = parent_bone
	var joint: Vector3 = rig.skel.get_bone_pose_position(bone)
	var holder := Node3D.new()
	holder.position = joint
	at.add_child(holder)
	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.055
	sm.height = 0.07
	cap.mesh = sm
	cap.material_override = stump_mat()
	holder.add_child(cap)
	cap.scale = Vector3.ONE / max(rig.model.scale.x, 0.0001)
	var spurt := CPUParticles3D.new()
	spurt.amount = 40
	spurt.lifetime = 0.7
	if _drop_mesh == null: spray(rig, rig.global_position, Vector3.UP, 0.1)
	spurt.mesh = _drop_mesh
	spurt.spread = 12.0
	spurt.direction = Vector3(0, 1, 0)
	spurt.initial_velocity_min = 1.0
	spurt.initial_velocity_max = 2.8
	spurt.gravity = Vector3(0, -9.8, 0)
	spurt.local_coords = false
	spurt.scale_amount_max = 1.6
	holder.add_child(spurt)
	spurt.scale = Vector3.ONE / max(rig.model.scale.x, 0.0001)
	spurt.emitting = true
	# pulse with a heartbeat that fades out
	var tw := spurt.create_tween()
	for i in 8:
		tw.tween_property(spurt, "initial_velocity_max", 3.2 - i * 0.3, 0.15)
		tw.tween_property(spurt, "initial_velocity_max", 0.6, 0.35)
	tw.tween_callback(func(): spurt.emitting = false)

## A copy of the character showing only the limb chain from root_bone down, following the given bodies
static func make_gib(rig, root_bone: int, bodies: Dictionary, parent: Node) -> Node3D:
	if rig == null or rig.model_path == "":
		return null
	var holder := Node3D.new()
	holder.name = "Gib"
	parent.add_child(holder)
	holder.global_transform = rig.global_transform
	var model: Node3D = load(rig.model_path).instantiate()
	for co in model.find_children("*", "CollisionObject3D", true, false):     # the model's own collision: never
		co.get_parent().remove_child(co)
		co.free()
	holder.add_child(model)
	model.transform = rig.model.transform
	for ap in model.find_children("*", "AnimationPlayer", true, false):
		ap.queue_free()
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var mods := BodyMods.new()
	mods.rig = rig
	sk.add_child(mods)
	mods.setup_gib(root_bone, bodies)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if rig.tint_mat_cache.size():
			for s in m.get_surface_override_material_count():
				var src: Material = rig.tint_mat_cache.get(m.mesh.surface_get_material(s))
				if src: m.set_surface_override_material(s, src)
	# blood trails off the cut end for a moment
	var first = bodies.get(root_bone)
	if first and is_instance_valid(first[0]):
		spray(parent, (first[0] as Node3D).global_position, Vector3.UP, 0.8)
	# a gib that's been lying around long enough goes away
	parent.get_tree().create_timer(120.0).timeout.connect(func():
		if is_instance_valid(holder): holder.queue_free()
		for b in bodies.values():
			if is_instance_valid(b[0]): b[0].queue_free())
	return holder

## Tear a limb off someone still walking (a zombie losing an arm): make a body for it and fling it
static func sever_live(rig, part: String, impulse: Vector3, parent: Node) -> void:
	var spec: Array = []
	for p in Ragdoll.PARTS:
		if p[0] == part: spec = p
	if spec.is_empty():
		return
	var sk: Skeleton3D = rig.skel
	var sxf := sk.global_transform
	var b: int = rig.bone(spec[1])
	var e: int = rig.bone(spec[2])
	if b < 0 or e < 0:
		return
	var a: Vector3 = sxf * sk.get_bone_global_pose(b).origin
	var z: Vector3 = sxf * sk.get_bone_global_pose(e).origin
	# a limb with a forearm on it: use the whole chain's length
	var chain: Array = Ragdoll.CHAIN.get(part, [part])
	if chain.size() > 1:
		for p in Ragdoll.PARTS:
			if p[0] == chain[-1]:
				z = sxf * sk.get_bone_global_pose(rig.bone(p[2])).origin
	var axis := z - a
	var L: float = max(axis.length(), 0.15)
	axis = axis.normalized()
	var rb := RigidBody3D.new()
	rb.mass = 3.0
	rb.collision_layer = Ragdoll.layer_bits()
	rb.collision_mask = 1 | Ragdoll.layer_bits()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = spec[3]
	cap.height = max(L, spec[3] * 2.2)
	cs.shape = cap
	rb.add_child(cs)
	parent.add_child(rb)
	var x := axis.cross(Vector3.FORWARD if abs(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var bx := Transform3D(Basis(x, axis, x.cross(axis)), a + axis * L * 0.5)
	rb.global_transform = bx
	rb.apply_central_impulse(impulse)
	rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 1.5)
	rb.add_to_group("ragdoll_parts")
	var off := bx.affine_inverse() * (sxf * sk.get_bone_global_pose(b))
	make_gib(rig, b, {b: [rb, off]}, parent)
	spray(parent, a, -axis + Vector3.UP * 0.5, 1.6)
