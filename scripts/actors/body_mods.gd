class_name BodyMods
extends SkeletonModifier3D
## Everything we do to a character's skeleton on top of its animation, in one modifier so the order is fixed:
##   1. ragdoll: bones follow the physics bodies (nothing else applies once dead, except severing)
##   2. lean: bend the spine (aim pitch for gunmen, a hunch and head loll for zombies)
##   3. hands: analytic two-bone IK for each arm to a target (holding a gun, or a zombie's grasping reach)
##   4. severed limbs: the bone is crushed to nothing at its joint, so the limb disappears into a stump
## In "gib" mode it does the opposite of 4: only one limb chain shows, steered by its own rigid body.

var rig                              # Rig
var ragdoll                          # Ragdoll, when dead
var lean_pitch := 0.0                # radians, + = look down
var hunch := 0.0                     # zombie stoop, radians
var head_tilt := Vector2.ZERO        # zombie head loll (roll, yaw)
var ik := {}                         # "L"/"R" -> {"target": Node3D, "pole": Vector3 (world dir), "w": float, "rot": Basis (hand basis offset) or null}
var severed := {}                    # bone index -> true (root of a removed chain)
var crushed := {}                    # every bone index inside a removed chain
# gib mode
var gib_root := -1
var gib_bodies := {}                 # bone index -> [RigidBody3D, Transform3D offset]
var gib_chain := {}

func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if gib_root >= 0:
		_gib_pose(sk)
		return
	if ragdoll:
		ragdoll.drive(sk, crushed)
	else:
		_lean(sk)
		for side in ik:
			_arm_ik(sk, side, ik[side])
	for b in severed:
		var g := sk.get_bone_global_pose(b)
		sk.set_bone_global_pose(b, Transform3D(g.basis.scaled(Vector3.ONE * 0.001), g.origin))

func _bone(n: String) -> int:
	return rig.bone(n)

func _rotate_global(sk: Skeleton3D, b: int, q: Basis) -> void:
	var g := sk.get_bone_global_pose(b)
	sk.set_bone_global_pose(b, Transform3D(q * g.basis, g.origin))

func _lean(sk: Skeleton3D) -> void:
	# spine bends about the body's right axis (skeleton space: the model faces +Z, so right is -X)
	var right := Vector3(-1, 0, 0)
	var p := lean_pitch * 0.5 + hunch
	if abs(p) > 0.001:
		for n in ["Spine1", "Spine2"]:
			var b := _bone(n)
			if b >= 0: _rotate_global(sk, b, Basis(right, p * 0.5))
	if head_tilt != Vector2.ZERO or abs(lean_pitch) > 0.001:
		var h := _bone("Head")
		if h >= 0:
			_rotate_global(sk, h, Basis(Vector3(0, 0, 1), head_tilt.x) * Basis(Vector3.UP, head_tilt.y) * Basis(right, lean_pitch * 0.4 - hunch * 0.6))

## Two-bone IK in skeleton space: shoulder (Arm) - elbow (ForeArm) - wrist (Hand). Elbow bends towards the pole.
func _arm_ik(sk: Skeleton3D, side: String, s: Dictionary) -> void:
	var t: Node3D = s.target
	if t == null or not is_instance_valid(t) or float(s.w) <= 0.0:
		return
	var pre := "Left" if side == "L" else "Right"
	var a := _bone(pre + "Arm")
	var e := _bone(pre + "ForeArm")
	var h := _bone(pre + "Hand")
	if a < 0 or e < 0 or h < 0:
		return
	var inv := sk.global_transform.affine_inverse()
	var T: Vector3 = inv * t.global_position
	var S := sk.get_bone_global_pose(a).origin
	var E := sk.get_bone_global_pose(e).origin
	var H := sk.get_bone_global_pose(h).origin
	var la := S.distance_to(E)
	var lb := E.distance_to(H)
	T = H.lerp(T, clamp(float(s.w), 0.0, 1.0))
	var d: float = clamp(S.distance_to(T), abs(la - lb) + 0.001, la + lb - 0.001)
	var dir := (T - S).normalized()
	var pole: Vector3 = (inv.basis * (s.pole as Vector3)).normalized()
	var perp := (pole - dir * pole.dot(dir)).normalized()
	if perp.length() < 0.5:
		perp = Vector3.DOWN
	var cos_a: float = clamp((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var E2 := S + dir * la * cos_a + perp * la * sqrt(1.0 - cos_a * cos_a)
	# upper arm: swing so it points at the new elbow
	_rotate_global(sk, a, _swing(E - S, E2 - S))
	# forearm: swing so it points at the target (positions re-read after the parent moved)
	var E_now := sk.get_bone_global_pose(e).origin
	var H_now := sk.get_bone_global_pose(h).origin
	_rotate_global(sk, e, _swing(H_now - E_now, T - E_now))
	# hand: copy the target's orientation if it has one
	if s.get("rot") != null:
		var hg := sk.get_bone_global_pose(h)
		var want: Basis = inv.basis * t.global_transform.basis * (s.rot as Basis)
		var sc := hg.basis.get_scale()
		sk.set_bone_global_pose(h, Transform3D(want.orthonormalized().scaled(sc), hg.origin))

static func _swing(from: Vector3, to: Vector3) -> Basis:
	var f := from.normalized()
	var t := to.normalized()
	var ax := f.cross(t)
	if ax.length() < 1e-5:
		return Basis()
	return Basis(ax.normalized(), f.angle_to(t))

# ---------------------------------------------------------------- gib mode
func setup_gib(root_bone: int, bodies: Dictionary) -> void:
	gib_root = root_bone
	gib_bodies = bodies
	var sk := get_skeleton()
	gib_chain = {root_bone: true}
	for i in sk.get_bone_count():
		var p := sk.get_bone_parent(i)
		if p >= 0 and gib_chain.has(p):
			gib_chain[i] = true

func _gib_pose(sk: Skeleton3D) -> void:
	var inv := sk.global_transform.affine_inverse()
	var first: Array = gib_bodies[gib_root]
	var root_world: Transform3D = (first[0] as Node3D).global_transform * (first[1] as Transform3D)
	var anchor := (inv * root_world).origin
	# everything outside the chain shrinks to nothing at the cut
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) < 0 and not gib_chain.has(i):
			sk.set_bone_global_pose(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), anchor))
	for b in gib_bodies:
		var e: Array = gib_bodies[b]
		if not is_instance_valid(e[0]):
			continue
		sk.set_bone_global_pose(b, inv * ((e[0] as Node3D).global_transform * (e[1] as Transform3D)))
