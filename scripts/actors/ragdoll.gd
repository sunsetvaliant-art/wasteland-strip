class_name Ragdoll
extends Node3D
## A ragdoll built on the fly from whatever pose the character died in: a capsule rigid body per body part, cone-twist
## joints between them, and the skeleton driven from the bodies every frame (BodyMods calls drive()).
## Parts can be torn off (sever) and keep flying on their own, carrying a copy of the limb mesh (gib).

const PARTS := [
	# name, bone, end bone, radius, parent, mass, length stretch, swing limit deg, twist limit deg
	["pelvis", "Hips", "Spine", 0.14, "", 14.0, 1.6, 0, 0],
	["chest", "Spine1", "Neck", 0.16, "pelvis", 18.0, 1.0, 30, 20],
	["head", "Head", "HeadTop_End", 0.105, "chest", 5.0, 1.0, 40, 40],
	["l_upperarm", "LeftArm", "LeftForeArm", 0.052, "chest", 2.5, 1.0, 80, 40],
	["l_forearm", "LeftForeArm", "LeftHand", 0.045, "l_upperarm", 1.8, 1.4, 70, 20],
	["r_upperarm", "RightArm", "RightForeArm", 0.052, "chest", 2.5, 1.0, 80, 40],
	["r_forearm", "RightForeArm", "RightHand", 0.045, "r_upperarm", 1.8, 1.4, 70, 20],
	["l_thigh", "LeftUpLeg", "LeftLeg", 0.08, "pelvis", 8.0, 1.0, 60, 20],
	["l_shin", "LeftLeg", "LeftFoot", 0.058, "l_thigh", 4.5, 1.15, 70, 10],
	["r_thigh", "RightUpLeg", "RightLeg", 0.08, "pelvis", 8.0, 1.0, 60, 20],
	["r_shin", "RightLeg", "RightFoot", 0.058, "r_thigh", 4.5, 1.15, 70, 10],
]
## which parts go with a cut at each part
const CHAIN := {"head": ["head"], "l_upperarm": ["l_upperarm", "l_forearm"], "l_forearm": ["l_forearm"],
	"r_upperarm": ["r_upperarm", "r_forearm"], "r_forearm": ["r_forearm"], "l_thigh": ["l_thigh", "l_shin"], "l_shin": ["l_shin"],
	"r_thigh": ["r_thigh", "r_shin"], "r_shin": ["r_shin"]}

var rig                              # Rig
var owner_actor                      # whoever this body was (NPC or Player), gets hit() forwarded
var bodies := {}                     # part -> RigidBody3D
var bones := {}                      # part -> bone index
var offsets := {}                    # part -> Transform3D body->bone (world)
var joints := {}                     # part -> Joint3D (to its parent)
var cut := {}                        # part -> true once torn off
var age := 0.0

static func layer_bits() -> int:
	return 1 << 3                    # layer 4: debris / ragdolls

func build(r, vel: Vector3) -> void:
	rig = r
	var sk: Skeleton3D = rig.skel
	var sxf := sk.global_transform
	for p in PARTS:
		var b: int = rig.bone(p[1])
		var e: int = rig.bone(p[2])
		if b < 0 or e < 0:
			continue
		var a: Vector3 = sxf * sk.get_bone_global_pose(b).origin
		var z: Vector3 = sxf * sk.get_bone_global_pose(e).origin
		var axis := (z - a)
		var L: float = max(axis.length() * float(p[6]), float(p[3]) * 2.2)
		axis = axis.normalized() if axis.length() > 0.001 else Vector3.UP
		var rb := RigidBody3D.new()
		rb.mass = p[5]
		rb.collision_layer = layer_bits()
		rb.collision_mask = 1 | layer_bits()
		rb.continuous_cd = true
		rb.linear_damp = 0.15
		rb.angular_damp = 1.2
		rb.add_to_group("ragdoll_parts")
		rb.set_meta("ragdoll", self)
		rb.set_meta("part", p[0])
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = p[3]
		cap.height = L
		cs.shape = cap
		rb.add_child(cs)
		add_child(rb)
		# body frame: Y along the bone, centred halfway down it
		var x := axis.cross(Vector3.FORWARD if abs(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var bx := Transform3D(Basis(x, axis, x.cross(axis)), a + axis * L * 0.5)
		rb.global_transform = bx
		rb.linear_velocity = vel
		bodies[p[0]] = rb
		bones[p[0]] = b
		offsets[p[0]] = bx.affine_inverse() * (sxf * sk.get_bone_global_pose(b))
	# keep a body's own parts from fighting each other
	var list := bodies.values()
	for i in list.size():
		for j in range(i + 1, list.size()):
			(list[i] as RigidBody3D).add_collision_exception_with(list[j])
	for p in PARTS:
		if p[4] == "" or not bodies.has(p[0]) or not bodies.has(p[4]):
			continue
		var j := ConeTwistJoint3D.new()
		var child: RigidBody3D = bodies[p[0]]
		var pivot: Vector3 = sxf * sk.get_bone_global_pose(bones[p[0]]).origin
		# the joint's X axis is the twist axis: along the child bone
		var ax: Vector3 = child.global_transform.basis.y
		var jx := Vector3.UP.cross(ax)
		if jx.length() < 0.1: jx = Vector3.RIGHT.cross(ax)
		j.global_transform = Transform3D(Basis(ax, jx.normalized(), ax.cross(jx.normalized())), pivot)
		add_child(j)
		j.global_transform = Transform3D(Basis(ax, jx.normalized(), ax.cross(jx.normalized())), pivot)
		j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(p[7]))
		j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(p[8]))
		j.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, 0.8)
		j.node_a = j.get_path_to(bodies[p[4]])
		j.node_b = j.get_path_to(child)
		joints[p[0]] = j

func _physics_process(dt: float) -> void:
	age += dt
	# far from the player there's no ground under it: put it to sleep where it lies
	var main = get_tree().current_scene
	if main and "collision_centre" in main and bodies.has("pelvis"):
		var far: bool = (bodies["pelvis"] as Node3D).global_position.distance_to(main.collision_centre) > 85.0
		for b in bodies.values():
			if is_instance_valid(b): b.freeze = far

## Pose the skeleton from the bodies. Bones inside a cut chain are left for the stump to crush.
func drive(sk: Skeleton3D, skip: Dictionary) -> void:
	var inv := sk.global_transform.affine_inverse()
	for p in PARTS:
		var n: String = p[0]
		if not bodies.has(n) or cut.has(n) or skip.has(bones[n]):
			continue
		var rb: RigidBody3D = bodies[n]
		if not is_instance_valid(rb):
			continue
		sk.set_bone_global_pose(bones[n], inv * (rb.global_transform * offsets[n]))

func part_of(body: Node) -> String:
	return str(body.get_meta("part", ""))

func push(part: String, impulse: Vector3, at: Vector3) -> void:
	if bodies.has(part) and is_instance_valid(bodies[part]):
		var rb: RigidBody3D = bodies[part]
		rb.freeze = false
		rb.apply_impulse(impulse, at - rb.global_position)

## Tear a limb (or the head) off: unhook its joint, hand its bodies to a gib that carries a copy of that limb.
func sever(part: String, impulse: Vector3) -> Node3D:
	if not CHAIN.has(part) or cut.has(part) or not bodies.has(part):
		return null
	var chain: Array = CHAIN[part]
	if joints.has(part) and is_instance_valid(joints[part]):
		joints[part].queue_free()
		joints.erase(part)
	var gib_bodies := {}
	for c in chain:
		cut[c] = true
		if bodies.has(c):
			var rb: RigidBody3D = bodies[c]
			# no more ignoring the rest of the body: the limb can land on its old owner
			for o in bodies.values():
				if o != rb and not (chain.has(part_of(o))):
					rb.remove_collision_exception_with(o)
			rb.apply_central_impulse(impulse)
			rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 2.0)
			gib_bodies[bones[c]] = [rb, offsets[c]]
	return Gore.make_gib(rig, bones[part], gib_bodies, get_parent())
