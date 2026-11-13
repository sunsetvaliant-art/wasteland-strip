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
var look_yaw := 0.0                  # where the eyes are pointed relative to the body: + = left (radians)
var look_pitch := 0.0                # + = up
var hip_yaw := 0.0                   # legs swung toward the direction of travel, chest stays put
var hunch := 0.0                     # zombie stoop, radians
var head_tilt := Vector2.ZERO        # zombie head loll (roll, yaw)
var kick := 0.0                      # 0..1: the right leg thrown out in front, the body leaning back off it
var strike := 0.0                    # 0..1 through a swing of the right arm: wound up over the shoulder, then down across
var air := 0.0                       # 0 on the ground .. 1 in the air: knees come up, feet tuck, arms out a little
const AIR_SIGN := 1.0
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

## The look: yaw and pitch shared out up the spine so the head points where the eyes are and the chest comes
## round with it. The hips can swing toward the way we're walking (strafing) with the spine unwinding it.
const LOOK_SPLIT := [["Spine", 0.14, 0.18], ["Chest", 0.14, 0.18], ["UpperChest", 0.14, 0.14], ["Neck", 0.24, 0.22], ["Head", 0.34, 0.28]]
func _lean(sk: Skeleton3D) -> void:
	var up := Vector3.UP
	if abs(hip_yaw) > 0.001:
		var hb := _bone("Hips")
		if hb >= 0: _rotate_global(sk, hb, Basis(up, hip_yaw))
		var sb := _bone("Spine")
		if sb >= 0: _rotate_global(sk, sb, Basis(up, -hip_yaw * 0.55))
		var cb := _bone("Spine1")
		if cb >= 0: _rotate_global(sk, cb, Basis(up, -hip_yaw * 0.45))
	if air > 0.001:
		_air_pose(sk)
	if kick > 0.001:
		var hinge := Vector3(1, 0, 0)
		var th := _bone("RightUpLeg")
		var sh := _bone("RightLeg")
		var sp := _bone("Spine")
		if th >= 0: _rotate_global(sk, th, Basis(hinge, -1.45 * kick * AIR_SIGN))
		if sh >= 0: _rotate_global(sk, sh, Basis(hinge, 0.9 * (1.0 - kick) * kick * 4.0 * AIR_SIGN))
		if sp >= 0: _rotate_global(sk, sp, Basis(hinge, 0.28 * kick * AIR_SIGN))
	if strike > 0.001:
		var hinge2 := Vector3(1, 0, 0)
		var ua := _bone("RightArm")
		var fa := _bone("RightForeArm")
		var up2 := 1.0 - smoothstep(0.25, 0.6, strike)          # raised, then brought down
		var a := lerpf(0.9, -2.3 * AIR_SIGN, up2) if strike < 0.98 else 0.0
		if ua >= 0: _rotate_global(sk, ua, Basis(hinge2, a * sin(minf(strike * 1.2, 1.0) * PI) * 0.9))
		if fa >= 0: _rotate_global(sk, fa, Basis(hinge2, -0.5 * up2 * AIR_SIGN))
		var sp2 := _bone("Spine1")
		if sp2 >= 0: _rotate_global(sk, sp2, Basis(Vector3.UP, (0.5 - smoothstep(0.2, 0.7, strike)) * 0.7 * sin(strike * PI)))
	if abs(look_yaw) < 0.0005 and abs(look_pitch) < 0.0005 and hunch == 0.0 and head_tilt == Vector2.ZERO:
		return
	if OS.get_environment("NOCHAIN") != "":
		return
	var cum := 0.0
	for e in LOOK_SPLIT:
		var b: int = sk.find_bone(e[0])
		if b < 0:
			continue
		cum += look_yaw * float(e[1])
		var right := Basis(up, cum) * Vector3(-1, 0, 0)     # the body faces +Z in skeleton space
		var p: float = look_pitch * float(e[2])
		if e[0] in ["Spine", "Chest"]: p -= hunch * 0.5
		if e[0] == "Head": p += hunch * 0.6
		var q := Basis(up, look_yaw * float(e[1])) * Basis(right, p)
		if e[0] == "Head" and head_tilt != Vector2.ZERO:
			q = q * Basis(Vector3(0, 0, 1), head_tilt.x) * Basis(up, head_tilt.y)
		_rotate_global(sk, b, q)

## In the air: thighs come forward, knees bend so the feet tuck up behind, one leg a bit more than the other
## (a jump / falling pose instead of walking on nothing). Body faces +Z, so the hinge axis is X.
func _air_pose(sk: Skeleton3D) -> void:
	var hinge := Vector3(1, 0, 0)
	for e in [["Left", 1.0], ["Right", 0.65]]:
		var th := _bone(e[0] + "UpLeg")
		var sh := _bone(e[0] + "Leg")
		var ft := _bone(e[0] + "Foot")
		var k: float = air * float(e[1])
		if th >= 0: _rotate_global(sk, th, Basis(hinge, -1.0 * k * AIR_SIGN))
		if sh >= 0: _rotate_global(sk, sh, Basis(hinge, 1.55 * k * AIR_SIGN))
		if ft >= 0: _rotate_global(sk, ft, Basis(hinge, -0.35 * k * AIR_SIGN))
	for e in [["Left", 1.0], ["Right", -1.0]]:
		var ua := _bone(e[0] + "Arm")
		if ua >= 0: _rotate_global(sk, ua, Basis(Vector3(0, 0, 1), 0.35 * air * float(e[1])))

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
	# the target is the grip itself: back the wrist off so the palm sits on it and the fingers wrap round
	if s.has("fingers"):
		var tb: Basis = (inv.basis * t.global_transform.basis).orthonormalized()
		var sc: float = sk.global_transform.basis.get_scale().x
		var fw: Vector3 = (tb * (s.fingers as Vector3)).normalized()
		var pw: Vector3 = (tb * (s.palm as Vector3)).normalized()
		T -= (fw * float(s.get("reach", 0.085)) + pw * float(s.get("thick", 0.035))) / max(sc, 0.0001)
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
	# hand: turn it so the fingers and the palm face the way the grip wants (given in the target's own space)
	if s.has("fingers"):
		var t_basis: Basis = (inv.basis * t.global_transform.basis).orthonormalized()
		var f_w: Vector3 = (t_basis * (s.fingers as Vector3)).normalized()
		var p_w: Vector3 = (t_basis * (s.palm as Vector3)).normalized()
		p_w = (p_w - f_w * p_w.dot(f_w)).normalized()
		var hl := _hand_axes(sk, h, pre)
		var L := Basis(hl[0], hl[1], hl[0].cross(hl[1]))
		var W := Basis(f_w, p_w, f_w.cross(p_w))
		var want := (W * L.inverse()).orthonormalized()
		var hg := sk.get_bone_global_pose(h)
		var blend: float = clamp(float(s.w), 0.0, 1.0)
		var b := hg.basis.orthonormalized().slerp(want, blend)
		sk.set_bone_global_pose(h, Transform3D(b.scaled(hg.basis.get_scale()), hg.origin))

## The hand bone's own finger direction and palm normal (in its local space), from the rest pose:
## fingers = toward the middle knuckle, palm = straight down in the T-pose.
var _axes := {}
func _hand_axes(sk: Skeleton3D, h: int, pre: String) -> Array:
	if _axes.has(h):
		return _axes[h]
	var rest := sk.get_bone_global_rest(h)
	var m := sk.find_bone(pre + "MiddleProximal")
	var f := Vector3.UP
	if m >= 0:
		f = (rest.basis.inverse() * (sk.get_bone_global_rest(m).origin - rest.origin)).normalized()
	var p := (rest.basis.inverse() * Vector3.DOWN).normalized()
	p = (p - f * p.dot(f)).normalized()
	_axes[h] = [f, p]
	return _axes[h]

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
