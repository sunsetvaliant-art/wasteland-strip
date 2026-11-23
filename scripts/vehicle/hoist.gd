class_name Hoist
extends StaticBody3D
## A workshop gantry with a chain hoist on a trolley (0.2.66). Straddle a car with it (the car fits between the
## legs, under the beam), push a loose body, tub, engine or anything else loose under the beam, look at it or the
## gantry and Hook the chain on. Then, standing near it: up / down arrows work the chain, left / right arrows run the
## trolley along the beam, hold Alt for slow. The chain only pulls (it goes slack if you sit the load on something)
## and a load hangs from above its middle, so it comes up level. Lift the body, push the chassis out from under it.
const SPAN := 3.7           # between the legs, along the beam
const HIGH := 3.3           # underside of the beam
const SPLAY := 0.95         # the legs' feet, either side of the beam
const CHAIN_V := 0.1        # m/s
const TROLLEY_V := 0.2
const MAX_KG := 2000.0
const STEEL := Color(0.72, 0.55, 0.12)

var load_rb: RigidBody3D = null
var attach := Vector3.ZERO  # on the load, in its own space: above its centre of mass
var corners: Array = []     # where the four strops hold it, load space
var length := 2.0           # chain from the trolley to the hook
var trolley := 0.0          # along the beam (local x)
var _held := 0.0
var _old_damp := Vector2.ZERO
var _vis_chain: MeshInstance3D
var _vis_trolley: MeshInstance3D
var _vis_hook: MeshInstance3D
var _strops: Array = []
var _hint_t := 0.0

static func steel_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = STEEL
	m.roughness = 0.6
	m.metallic = 0.3
	return m

## The gantry's frame as boxes: [Transform3D, size]. Shared by the meshes, the collision and the Forge's ghost.
static func frame_boxes() -> Array:
	var out := []
	out.append([Transform3D(Basis.IDENTITY, Vector3(0, HIGH + 0.1, 0)), Vector3(SPAN + 0.3, 0.2, 0.12)])     # the beam
	for sx in [-1.0, 1.0]:
		var top := Vector3(sx * SPAN * 0.5, HIGH + 0.05, 0)
		for sz in [-1.0, 1.0]:
			var foot := Vector3(sx * SPAN * 0.5, 0.1, sz * SPLAY)
			var mid := (top + foot) * 0.5
			var up := (top - foot).normalized()
			out.append([Transform3D(_basis_y(up), mid), Vector3(0.1, (top - foot).length(), 0.1)])
		out.append([Transform3D(Basis.IDENTITY, Vector3(sx * SPAN * 0.5, 0.05, 0)), Vector3(0.12, 0.1, SPLAY * 2.0 + 0.2)])   # the foot
		out.append([Transform3D(Basis.IDENTITY, Vector3(sx * SPAN * 0.5, 1.1, 0)), Vector3(0.06, 0.06, SPLAY * 1.4)])           # a brace
	return out

static func _basis_y(up: Vector3) -> Basis:
	var x := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := x.cross(up).normalized()
	x = up.cross(z).normalized()
	return Basis(x, up, z)

## The frame's meshes alone (the Forge's ghost uses this)
static func make_visual() -> Node3D:
	var root := Node3D.new()
	var mat := steel_mat()
	for fb in frame_boxes():
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = fb[1]; bm.material = mat
		mi.mesh = bm
		mi.transform = fb[0]
		root.add_child(mi)
	return root

func _ready() -> void:
	add_to_group("physgun")
	add_to_group("hoists")
	add_child(make_visual())
	for fb in frame_boxes():
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new(); bx.size = fb[1]
		cs.shape = bx
		cs.transform = fb[0]
		add_child(cs)
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.12, 0.12, 0.13); dark.metallic = 0.6; dark.roughness = 0.45
	_vis_trolley = MeshInstance3D.new()
	var tm := BoxMesh.new(); tm.size = Vector3(0.22, 0.32, 0.26); tm.material = dark
	_vis_trolley.mesh = tm
	add_child(_vis_trolley)
	_vis_chain = MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.012; cm.bottom_radius = 0.012; cm.height = 1.0; cm.radial_segments = 6; cm.rings = 1; cm.material = dark
	_vis_chain.mesh = cm
	add_child(_vis_chain)
	_vis_hook = MeshInstance3D.new()
	var hm := BoxMesh.new(); hm.size = Vector3(0.1, 0.16, 0.06); hm.material = dark
	_vis_hook.mesh = hm
	add_child(_vis_hook)
	var strap := StandardMaterial3D.new(); strap.albedo_color = Color(0.85, 0.6, 0.1); strap.roughness = 0.9
	for i in 4:
		var s := MeshInstance3D.new()
		var sm := CylinderMesh.new(); sm.top_radius = 0.015; sm.bottom_radius = 0.015; sm.height = 1.0; sm.radial_segments = 5; sm.rings = 1; sm.material = strap
		s.mesh = sm
		s.visible = false
		add_child(s)
		_strops.append(s)
	_draw()

## Where the trolley's hook hangs from, world space
func top_point() -> Vector3:
	return global_transform * Vector3(trolley, HIGH - 0.18, 0)

func _rb_aabb(rb: RigidBody3D) -> AABB:
	var inv := rb.global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for mi in rb.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.visible: continue
		var a: AABB = (inv * m.global_transform) * BodyCut.aabb_of(m.mesh)
		out = a if first else out.merge(a)
		first = false
	if first:
		for cs in rb.get_children():
			if cs is CollisionShape3D and (cs as CollisionShape3D).shape is BoxShape3D:
				var sz: Vector3 = ((cs as CollisionShape3D).shape as BoxShape3D).size
				var a2 := AABB((cs as Node3D).position - sz * 0.5, sz)
				out = a2 if first else out.merge(a2)
				first = false
	return out

## Something loose under the beam that the chain will reach, or null
func candidate() -> RigidBody3D:
	var best: RigidBody3D = null
	var bd := 1e9
	var inv := global_transform.affine_inverse()
	for n in get_tree().get_nodes_in_group("physgun"):
		if not (n is RigidBody3D) or n is Car or not is_instance_valid(n): continue
		var rb := n as RigidBody3D
		var l := inv * rb.global_position
		if absf(l.z) > 0.9 or absf(l.x) > SPAN * 0.5 - 0.2 or l.y > HIGH - 0.4 or l.y < -0.5: continue
		var d := absf(l.z) + absf(l.x - trolley) * 0.3
		if d < bd: bd = d; best = rb
	return best

func hook(rb: RigidBody3D) -> String:
	if rb == null: return "Push it in under the beam first."
	if rb.mass > MAX_KG: return "That's over the hoist's two tonne."
	var st := PhysicsServer3D.body_get_direct_state(rb.get_rid())
	var com: Vector3 = st.center_of_mass_local if st else Vector3.ZERO
	var a := _rb_aabb(rb)
	attach = Vector3(com.x, a.end.y + 0.45, com.z)
	var hx := a.size.x * 0.32; var hz := a.size.z * 0.32
	corners = [Vector3(com.x - hx, a.end.y, com.z - hz), Vector3(com.x + hx, a.end.y, com.z - hz),
		Vector3(com.x - hx, a.end.y, com.z + hz), Vector3(com.x + hx, a.end.y, com.z + hz)]
	var lw := global_transform.affine_inverse() * (rb.global_transform * attach)
	trolley = clampf(lw.x, -SPAN * 0.5 + 0.3, SPAN * 0.5 - 0.3)          # you push the trolley over it by hand
	length = maxf(0.2, top_point().distance_to(rb.global_transform * attach))
	if length > HIGH: return "The chain won't reach down that far."
	load_rb = rb
	if rb.has_method("wake"): rb.wake()           # an unbolted engine comes off its mounts
	_old_damp = Vector2(rb.linear_damp, rb.angular_damp)
	rb.linear_damp = maxf(rb.linear_damp, 0.4)          # it swings, but it settles
	rb.angular_damp = maxf(rb.angular_damp, 2.0)
	rb.sleeping = false
	return ""

func unhook() -> void:
	if load_rb and is_instance_valid(load_rb):
		load_rb.linear_damp = _old_damp.x
		load_rb.angular_damp = _old_damp.y
		load_rb.sleeping = false
	load_rb = null

## The interact menu's options, looking at the gantry or at something hanging under it: [label, callable, ok, why]
func menu(p) -> Array:
	if load_rb and is_instance_valid(load_rb):
		return [["Unhook the chain", func():
			unhook()
			p._toast("Chain's off."), true, ""]]
	var c := candidate()
	return [["Hook the chain on" + ("" if c == null else " (%s)" % str(c.get_meta("forge_name", "the load"))), func():
		var why := hook(c)
		p._toast(why if why != "" else "Hooked on. Up/down arrows: chain. Left/right: trolley. Alt: slow."), c != null, "Push something loose in under the beam first"]]

func _player():
	var cs = get_tree().current_scene
	return cs.get("player") if cs else null

func _physics_process(dt: float) -> void:
	if load_rb != null and not is_instance_valid(load_rb): load_rb = null
	if load_rb == null:
		_draw()
		return
	# the controls: whoever's stood by it on foot
	var p = _player()
	var mine: bool = p != null and is_instance_valid(p) and p.get("vehicle") == null and not get_tree().paused \
		and (p as Node3D).global_position.distance_to(global_position) < 7.0 and not InteractMenu.blocking()
	var up := 0.0; var tr := 0.0
	if mine:
		up = (1.0 if Input.is_physical_key_pressed(KEY_UP) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_DOWN) else 0.0)
		tr = (1.0 if Input.is_physical_key_pressed(KEY_RIGHT) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_LEFT) else 0.0)
		_hint_t -= dt
		if _hint_t <= 0.0 and p.has_method("_toast") and (p as Node3D).global_position.distance_to(global_position) < 4.0 and up == 0.0 and tr == 0.0:
			_hint_t = 1e9
			p._toast("Hoist: up/down arrows chain, left/right trolley, Alt slow")
	if cmd != Vector2.ZERO: up = cmd.x; tr = cmd.y
	var fine := 0.3 if Input.is_physical_key_pressed(KEY_ALT) else 1.0
	_held = (_held + dt) if (up != 0.0 or tr != 0.0) else 0.0
	var ease := lerpf(0.2, 1.0, clampf((_held - 0.1) / 0.6, 0.0, 1.0))
	length = clampf(length - up * CHAIN_V * fine * ease * dt, 0.15, HIGH + 0.5)
	trolley = clampf(trolley + tr * TROLLEY_V * fine * ease * dt, -SPAN * 0.5 + 0.3, SPAN * 0.5 - 0.3)
	if up != 0.0 or tr != 0.0: load_rb.sleeping = false
	# the chain: a stiff spring that only pulls
	var a := load_rb.global_transform * attach
	var t := top_point()
	var d := t - a
	var dist := d.length()
	if dist > length and dist > 0.001:
		var n := d / dist
		var st := PhysicsServer3D.body_get_direct_state(load_rb.get_rid())
		var va: Vector3 = st.get_velocity_at_local_position(a - load_rb.global_position) if st else load_rb.linear_velocity
		var m := load_rb.mass
		var k := m * pow(TAU * 3.0, 2.0)
		var c := 2.0 * sqrt(k * m) * 0.8
		var f := maxf(0.0, k * (dist - length) - c * va.dot(n))
		f = minf(f, m * 9.81 * 4.0)
		load_rb.apply_force(n * f, a - load_rb.global_position)
	_draw()

var cmd := Vector2.ZERO     # chain / trolley from a script (tests) when nobody's at the controls

func _seg(mi: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var inv := global_transform.affine_inverse()
	var a := inv * from; var b := inv * to
	var sl := a.distance_to(b)
	mi.visible = sl > 0.01
	if not mi.visible: return
	mi.transform = Transform3D(_basis_y((b - a) / sl) * Basis.from_scale(Vector3(1, sl, 1)), (a + b) * 0.5)

func _draw() -> void:
	if _vis_trolley == null: return
	_vis_trolley.position = Vector3(trolley, HIGH - 0.06, 0)
	var t := top_point()
	var hook_at := t + global_transform.basis * Vector3(0, -0.6, 0)
	if load_rb != null and is_instance_valid(load_rb):
		hook_at = load_rb.global_transform * attach          # the hook's on the strops' ring
		for i in 4:
			_seg(_strops[i], hook_at, load_rb.global_transform * (corners[i] as Vector3))
	else:
		for s in _strops: (s as Node3D).visible = false
	_seg(_vis_chain, t, hook_at)
	_vis_hook.global_position = hook_at
