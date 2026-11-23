class_name Strap
extends Node3D
## Ratchet straps (0.2.68): an orange 250 kg ribbon or a navy 2 t strap between two points, each on a body (the
## load, a car's tray or roof, another car, a loose engine) or on something fixed (a tree, a post, the ground). Two
## clicks make one (J with a strap on you, or Use it in the inventory): the first where it starts, the second where it
## ties off. A load tied to a vehicle is ratcheted up tight; between two vehicles (towing) or to anything else it's
## left at the length you laid it out, and only pulls once it goes taut. Pull past twice its rating and it lets go. F on a strapped thing takes the strap off and gives it back.

const KINDS := {
	"strap_250": {"name": "250 kg ratchet strap", "kg": 250.0, "col": Color(1.0, 0.45, 0.05), "k": 14000.0, "w": 0.025},
	"strap_2t": {"name": "2 tonne ratchet strap", "kg": 2000.0, "col": Color(0.08, 0.12, 0.32), "k": 70000.0, "w": 0.05},
}

var kind := "strap_2t"
var a_node: Node3D = null       # null: a fixed point in the world
var a_local := Vector3.ZERO     # local to a_node, or world if a_node is null
var b_node: Node3D = null
var b_local := Vector3.ZERO
var length := 1.0
var tension := 0.0              # N, for the HUD and tests
var _over := 0.0
var _vis: MeshInstance3D

static func make(parent: Node, kind_id: String, an: Node3D, ap: Vector3, bn: Node3D, bp: Vector3) -> Strap:
	var s := Strap.new()
	s.kind = kind_id
	s.a_node = an if (an is RigidBody3D) else null
	s.a_local = an.to_local(ap) if s.a_node else ap
	s.b_node = bn if (bn is RigidBody3D) else null
	s.b_local = bn.to_local(bp) if s.b_node else bp
	s.a_has = s.a_node != null
	s.b_has = s.b_node != null
	var dist := ap.distance_to(bp)
	# ratcheted down on a load tied to a vehicle; laid out slack for a tow or a pull
	var tie: bool = (s.a_node is Car) != (s.b_node is Car) and (s.a_node != null or s.b_node != null) and not (s.a_node is LooseLump or s.b_node is LooseLump)
	s.length = maxf(0.05, dist * (0.96 if tie else 1.0))
	s.add_to_group("straps")
	parent.add_child(s)
	return s

func pa() -> Vector3:
	return a_node.to_global(a_local) if a_has else a_local

func pb() -> Vector3:
	return b_node.to_global(b_local) if b_has else b_local

func _ready() -> void:
	_vis = MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(float(KINDS[kind].w), 0.004, 1.0)
	var m := StandardMaterial3D.new(); m.albedo_color = KINDS[kind].col; m.roughness = 0.85
	bm.material = m
	_vis.mesh = bm
	_vis.top_level = true
	_vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_vis)

func touches(n: Node) -> bool:
	return n != null and ((a_has and n == a_node) or (b_has and n == b_node))

static func _vel_at(rb: RigidBody3D, p: Vector3) -> Vector3:
	if rb == null or rb.freeze: return Vector3.ZERO
	return rb.linear_velocity + rb.angular_velocity.cross(p - rb.global_transform * rb.center_of_mass)

func _physics_process(dt: float) -> void:
	if not _ends_ok():
		queue_free()
		return
	var p1 := pa(); var p2 := pb()
	var d := p2 - p1
	var dist := d.length()
	tension = 0.0
	if dist <= length or dist < 0.001:
		return
	var n := d / dist
	var ra := a_node as RigidBody3D
	var rbb := b_node as RigidBody3D
	# a loose lump sat on its mounts comes free once something pulls on it
	for r in [ra, rbb]:
		if r and r.freeze and r.has_method("wake"): r.wake()
	var ma := ra.mass if ra and not ra.freeze else 1e9
	var mb := rbb.mass if rbb and not rbb.freeze else 1e9
	if ma >= 1e9 and mb >= 1e9: return
	var m_eff := ma * mb / (ma + mb)
	var k := float(KINDS[kind].k)
	var c := 2.0 * sqrt(k * m_eff) * 0.35
	var vrel := (_vel_at(rbb, p2) - _vel_at(ra, p1)).dot(n)
	var f := maxf(0.0, k * (dist - length) + c * vrel)
	f = minf(f, m_eff * 9.81 * 25.0)
	tension = f
	if ra and not ra.freeze: ra.apply_force(n * f, p1 - ra.global_position)
	if rbb and not rbb.freeze: rbb.apply_force(-n * f, p2 - rbb.global_position)
	if ra: ra.sleeping = false
	if rbb: rbb.sleeping = false
	# held well past its rating for a moment: it lets go
	if f > float(KINDS[kind].kg) * 9.81 * 2.0:            # twice its rating
		_over += dt
		if _over > 0.2:
			var pl = get_tree().current_scene.get("player") if get_tree().current_scene else null
			if pl and pl.has_method("_toast"): pl._toast("The %s snapped." % str(KINDS[kind].name).to_lower())
			queue_free()
	else:
		_over = 0.0

var a_has := false             # (a freed node compares equal to null, so whether there was one is kept apart)
var b_has := false
func _ends_ok() -> bool:
	return (not a_has or is_instance_valid(a_node)) and (not b_has or is_instance_valid(b_node))

func _process(_dt: float) -> void:
	if _vis == null: return
	if not _ends_ok():
		queue_free()
		return
	var p1 := pa(); var p2 := pb()
	var d := p2 - p1
	var l := d.length()
	_vis.visible = l > 0.02
	if not _vis.visible: return
	var z := d / l
	var x := z.cross(Vector3.UP)
	if x.length_squared() < 1e-4: x = z.cross(Vector3.RIGHT)
	x = x.normalized()
	var y := x.cross(z).normalized()
	_vis.global_transform = Transform3D(Basis(x, y, z * l), (p1 + p2) * 0.5)
