extends Node
## 0.2.68 straps, headless: tow, tie-down, a 250 kg strap snapping, an engine pulled out of a chassis
var dummy: StaticBody3D
func drive(c: Car, secs: float, back := false) -> void:
	c.driver = dummy
	c._shift(-9); c._shift(1 if not back else 0)
	if c.box.auto: c.gear = 3 if not back else 1
	Input.action_press("move_forward")
	for i in int(secs * 120): await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_press("move_back")
	for i in 240: await get_tree().physics_frame
	Input.action_release("move_back")
	c.driver = null

func _ready():
	await get_tree().process_frame
	var g := StaticBody3D.new(); g.name = "Ground"; var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(600, 2, 600); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	dummy = StaticBody3D.new(); add_child(dummy); dummy.position = Vector3(0, -50, 0)
	# --- tow: A pulls B 8 m behind on a 2 t strap
	var a := Car.new(); a.design = VehicleSpecs.default_design("vjwagon"); a.position = Vector3(0, 1.0, 0); add_child(a)
	var bb := Car.new(); bb.design = VehicleSpecs.default_design("vhute"); bb.position = Vector3(0, 1.0, -9.0); add_child(bb)
	for i in 200: await get_tree().physics_frame
	var pa: Vector3 = a.global_transform * Vector3(0, 0.3, float(a.def.min[0]) + 0.1)
	var pb: Vector3 = bb.global_transform * Vector3(0, 0.3, float(bb.def.min[0]) + float(bb.def.ext[0]) - 0.1)
	var st := Strap.make(self, "strap_2t", a, pa, bb, pb)
	var b0 := bb.global_position
	var maxt := 0.0
	a.driver = dummy; a.gear = 3 if a.box.auto else 2
	Input.action_press("move_forward")
	for i in 600:
		await get_tree().physics_frame
		if is_instance_valid(st): maxt = maxf(maxt, st.tension)
	Input.action_release("move_forward")
	a.driver = null
	print("ST tow: towed car moved %.1f m, strap %s, peak %.0f N (%.0f kg)" % [(bb.global_position - b0).length(), "held" if is_instance_valid(st) else "SNAPPED", maxt, maxt / 9.81])
	if is_instance_valid(st): st.queue_free()
	# --- the same on a 250 kg strap: it should let go
	for i in 240: await get_tree().physics_frame
	pa = a.global_transform * Vector3(0, 0.3, float(a.def.min[0]) + 0.1)
	pb = bb.global_transform * Vector3(0, 0.3, float(bb.def.min[0]) + float(bb.def.ext[0]) - 0.1)
	bb.global_position += (pa - pb).normalized() * maxf(0.0, (pa - pb).length() - 6.0)
	for i in 30: await get_tree().physics_frame
	pb = bb.global_transform * Vector3(0, 0.3, float(bb.def.min[0]) + float(bb.def.ext[0]) - 0.1)
	var st2 := Strap.make(self, "strap_250", a, pa, bb, pb)
	a.driver = dummy; a.gear = 3 if a.box.auto else 2
	Input.action_press("move_forward")
	for i in 600: await get_tree().physics_frame
	Input.action_release("move_forward")
	a.driver = null
	print("ST orange tow: strap ", "held" if is_instance_valid(st2) else "snapped")
	a.queue_free(); bb.queue_free()
	for i in 10: await get_tree().physics_frame
	# --- tie-down: a 40 kg crate in a ute's tub, strapped, accelerate and brake hard
	for strapped in [false, true]:
		var u := Car.new(); u.design = VehicleSpecs.default_design("vhute"); u.position = Vector3(30, 1.0, 0); add_child(u)
		for i in 200: await get_tree().physics_frame
		var crate := RigidBody3D.new(); crate.mass = 40.0
		var cc := CollisionShape3D.new(); var cb := BoxShape3D.new(); cb.size = Vector3(0.5, 0.4, 0.5); cc.shape = cb; crate.add_child(cc)
		add_child(crate)
		var bedz := float(u.def.min[0]) + 0.7
		# drop it on whatever's in the tub (the body collision's top)
		var q := PhysicsRayQueryParameters3D.create(u.global_transform * Vector3(0, 3, bedz), u.global_transform * Vector3(0, -1, bedz), 0xFFFFFFFF)
		var h := get_viewport().world_3d.direct_space_state.intersect_ray(q)
		crate.global_position = (h.position as Vector3) + Vector3(0, 0.25, 0) if not h.is_empty() else u.global_transform * Vector3(0, 1.2, bedz)
		for i in 120: await get_tree().physics_frame
		var s3: Strap = null
		if strapped:
			var top: Vector3 = crate.global_position + Vector3(0, 0.2, 0)
			s3 = Strap.make(self, "strap_250", crate, top, u, u.global_transform * Vector3(0.7, 0.55, bedz))
			Strap.make(self, "strap_250", crate, top, u, u.global_transform * Vector3(-0.7, 0.55, bedz))
		var rel0: Vector3 = u.to_local(crate.global_position)
		u.driver = dummy; u.gear = 3 if u.box.auto else 2
		Input.action_press("move_forward")
		for i in 480: await get_tree().physics_frame
		Input.action_release("move_forward")
		Input.action_press("move_back")
		for i in 360: await get_tree().physics_frame
		Input.action_release("move_back")
		u.driver = null
		var rel1: Vector3 = u.to_local(crate.global_position)
		print("ST tie-down %s: crate moved %.2f m in the tub (now %s)" % ["strapped" if strapped else "loose", (rel1 - rel0).length(), rel1])
		for n in get_tree().get_nodes_in_group("straps"): n.queue_free()
		crate.queue_free(); u.queue_free()
		for i in 10: await get_tree().physics_frame
	# --- an engine out of a rolling chassis: unbolt it, strap it to a car, drive off
	var ch := Car.new(); var dch := VehicleSpecs.default_design("vhute"); dch["no_cab"] = true; ch.design = dch; ch.position = Vector3(60, 1.0, 0); add_child(ch)
	var tw := Car.new(); tw.design = VehicleSpecs.default_design("vjwagon"); tw.position = Vector3(60, 1.0, 12.0); add_child(tw)
	for i in 240: await get_tree().physics_frame
	print("ST engine out ok: '", ch.engine_out_ok(), "'")
	var lump: LooseLump = ch.unbolt_engine()
	print("ST unbolted: ", lump != null, " frozen ", lump.freeze if lump else false, " mass ", lump.mass if lump else 0.0, " car block now '", ch.design.kit.block, "'")
	for i in 60: await get_tree().physics_frame
	var l0 := lump.global_position
	var c0 := ch.global_position
	var s4 := Strap.make(self, "strap_2t", lump, lump.global_position + Vector3(0, 0.25, 0.3), tw, tw.global_transform * Vector3(0, 0.3, float(tw.def.min[0]) + 0.1))
	tw.driver = dummy; tw.gear = 3 if tw.box.auto else 2
	Input.action_press("move_forward")
	for i in 480: await get_tree().physics_frame
	Input.action_release("move_forward")
	tw.driver = null
	for i in 120: await get_tree().physics_frame
	print("ST pulled: engine moved %.1f m, chassis moved %.2f m, strap %s, engine at y %.2f" % [(lump.global_position - l0).length(), (ch.global_position - c0).length(), "held" if is_instance_valid(s4) else "snapped", lump.global_position.y])
	if is_instance_valid(s4): s4.queue_free()
	# back in: put it where it was and bolt it
	lump.freeze = true
	lump.global_transform = Transform3D(ch.global_basis, ch.global_transform * (ch.engine_home()))
	print("ST bolted back in: ", ch.bolt_engine(lump), " block '", ch.design.kit.block, "'")
	print("ST_DONE")
	get_tree().quit()
