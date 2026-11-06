class_name WeaponHold
extends RefCounted
## How a body holds a gun, shared by the player, scavs and the hand lab.
##   place():  where the gun sits for an eye (camera-like transform, -Z forward): hip, down the sights, low ready
##             while sprinting, dipped and rolled through a reload, kicked back by recoil.
##   hands():  both hands onto it with IK: right hand wrapped round the wrist of the stock / pistol grip, left hand
##             under the fore-end as far forward as the arm actually reaches (pistols: left hand cups the right).
## Hand directions are in the gun's space: barrel -Z, up +Y, right +X.

const R_FINGERS := Vector3(-0.35, -0.25, -0.9)     # right hand: fingers wrap forward round the front of the grip
const R_PALM := Vector3(-1.0, 0.0, 0.1)            # palm against the right side of the grip
const L_FINGERS := Vector3(0.35, 0.1, -0.93)       # left hand: fingers along the fore-end, curling up its right side
const L_PALM := Vector3(0.0, 1.0, 0.0)             # palm up, under it
const LP_FINGERS := Vector3(0.25, -0.35, -0.9)     # pistol: left hand wrapped under and over the right
const LP_PALM := Vector3(1.0, 0.35, 0.0)

## st: {"ads", "low", "reload", "cycle", "kick", "bob": Vector3}
static func place(g: Gun, eye: Transform3D, st: Dictionary) -> Transform3D:
	var pistol: bool = g.def.get("pistol", false)
	var half: float = float(g.def.len) * 0.5
	var sh: float = g.sight_h
	# butt in the shoulder pocket, a bit behind the eye; down the sights the eye sits on the sight line
	var hip := Vector3(0.18, -0.26, 0.08 - half) if not pistol else Vector3(0.15, -0.21, -0.42)
	# down the sights: eye on the sight line, the rear sight / receiver a hand's width in front of it
	# (scoped rifles keep their eye relief behind the scope)
	var sights := Vector3(0.0, -sh, 0.11 - half) if not pistol else Vector3(0.0, -sh, -0.46)
	if not pistol and float(g.def.get("scope", 0.0)) <= 0.0 and g.sight_rear_z > -half:
		sights.z = min(-0.12 - g.sight_rear_z, 0.16 - half)
	var low := Vector3(0.18, -0.4, 0.02 - half * 0.7) if not pistol else Vector3(0.15, -0.42, -0.3)
	var ads: float = st.get("ads", 0.0)
	var p := hip.lerp(sights, ads)
	var lowr: float = st.get("low", 0.0)
	p = p.lerp(low, lowr)
	var rl: float = st.get("reload", 0.0)
	var cyc: float = st.get("cycle", 0.0)
	p += (st.get("bob", Vector3.ZERO) as Vector3) + Vector3(0, -0.1 * sin(rl * PI) - 0.03 * sin(cyc * PI), float(st.get("kick", 0.0)))
	var b := eye.basis * Basis(Vector3.FORWARD, 0.7 * sin(rl * PI) + 0.25 * sin(cyc * PI)) * Basis(Vector3.RIGHT, -0.4 * sin(rl * PI))
	b = b.slerp(eye.basis * Basis(Vector3.UP, 0.55) * Basis(Vector3.RIGHT, -0.55), lowr)
	return Transform3D(b.orthonormalized(), eye * p)

## Hands on. body_basis: the character's root basis (for elbow poles).
static func hands(rig, g: Gun, body_basis: Basis, weight := 1.0) -> void:
	var pistol: bool = g.def.get("pistol", false)
	var right := body_basis.x
	var down := -body_basis.y
	var back := body_basis.z
	var ik: Dictionary = rig.mods.ik
	ik["R"] = {"target": g.grip_r, "pole": down + right * 0.7 + back * 0.3, "w": weight, "fingers": R_FINGERS, "palm": R_PALM}
	if pistol:
		g.grip_l.position = g.grip_r.position + Vector3(-0.045, -0.035, 0.0)
		ik["L"] = {"target": g.grip_l, "pole": down - right * 0.8, "w": weight, "fingers": LP_FINGERS, "palm": LP_PALM}
		return
	# left hand as far up the fore-end as the arm reaches
	var want := Vector3(0.0, float(g.def.get("fore_y", -0.035)), float(g.def.len) * 0.5 - float(g.def.fore) * float(g.def.len))
	var back_pt := Vector3(want.x, want.y, g.grip_r.position.z - 0.2)
	var sh: Vector3 = rig.bone_pos("LeftArm")
	var reach: float = (sh.distance_to(rig.bone_pos("LeftForeArm")) + rig.bone_pos("LeftForeArm").distance_to(rig.bone_pos("LeftHand"))) * 0.97 + 0.07
	if g.to_global(want).distance_to(sh) > reach:
		var lo := 0.0
		var hi := 1.0
		for _k in 10:
			var mid := (lo + hi) * 0.5
			if g.to_global(want.lerp(back_pt, mid)).distance_to(sh) > reach: lo = mid
			else: hi = mid
		want = want.lerp(back_pt, hi)
	g.grip_l.position = want
	ik["L"] = {"target": g.grip_l, "pole": down - right * 0.9, "w": weight, "fingers": L_FINGERS, "palm": L_PALM}
