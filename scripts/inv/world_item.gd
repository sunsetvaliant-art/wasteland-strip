class_name WorldItem
extends RefCounted
## Things lying on the ground: a small physics body carrying stacks (meta "items"), in the "pickups" group.
## F picks it up (or opens it in the inventory if there's a pile). Dropped guns keep their rounds.

const SIZE := {"ammo": 0.22, "med": 0.32, "food": 0.18, "clothing": 0.4, "pack": 0.55, "misc": 0.35}

static func spawn(parent: Node, stacks: Array, pos: Vector3, vel := Vector3.ZERO) -> RigidBody3D:
	if stacks.is_empty():
		return null
	var s: Dictionary = stacks[0]
	var d := Items.def(s.id)
	var rb := RigidBody3D.new()
	rb.mass = 3.0
	rb.collision_layer = Ragdoll.layer_bits()
	rb.collision_mask = 1
	rb.continuous_cd = true
	var vis: Node3D
	var box := Vector3(0.3, 0.12, 0.3)
	if d.kind == "gun":
		var g := Gun.new()
		rb.add_child(g)
		g.setup(d.gun, null)
		rb.remove_child(g)
		g.set_process(false)
		vis = g
		box = Vector3(0.1, 0.15, float(g.def.len))
	elif d.has("model") and ResourceLoader.exists(d.model):
		var raw: Node3D = (load(d.model) as PackedScene).instantiate()
		vis = Node3D.new()
		vis.add_child(raw)
		var bb := _aabb(raw)
		var want: float = SIZE.get(d.kind, 0.3)
		var k: float = want / max(bb.size.x, max(bb.size.y, bb.size.z), 0.01)
		raw.scale = Vector3.ONE * k
		raw.position = -bb.get_center() * k
		box = bb.size * k
	else:
		# folded clothes / a plain packet
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		box = Vector3(0.36, 0.08, 0.3) if d.kind == "clothing" else Vector3(0.12, 0.06, 0.09)
		bm.size = box
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Items.KIND_COL.get(d.kind, Color.GRAY).lightened(0.15)
		m.roughness = 0.95
		mi.material_override = m
		vis = mi
	rb.add_child(vis)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.max(Vector3(0.05, 0.05, 0.05))
	cs.shape = bs
	rb.add_child(cs)
	rb.add_to_group("pickups")
	rb.set_meta("items", stacks)
	parent.add_child(rb)
	rb.global_position = pos
	rb.rotation.y = randf() * TAU
	rb.linear_velocity = vel
	return rb

static func label(n: Node) -> String:
	var st: Array = n.get_meta("items", [])
	if st.is_empty(): return ""
	var s: Dictionary = st[0]
	var t: String = Items.def(s.id).name
	if s.n > 1: t += " x%d" % s.n
	if st.size() > 1: t += " (+%d more)" % (st.size() - 1)
	return t

static func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var p: Node = mi
		while p and p != n:
			if p is Node3D: xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * (mi as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
