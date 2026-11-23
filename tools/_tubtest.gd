extends Node
## Unbolt a tub and watch it: does anything shove it? TT_CAR (ranger_dc), TT_RIDE list of ride offsets.
func _ready():
	await get_tree().process_frame
	var g := StaticBody3D.new(); g.name = "Ground"; var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(200, 2, 200); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	var key := OS.get_environment("TT_CAR") if OS.get_environment("TT_CAR") != "" else "ranger_dc"
	var rides := (OS.get_environment("TT_RIDE") if OS.get_environment("TT_RIDE") != "" else "0").split(",")
	var x := 0.0
	if BodyCut.of(str(Car.catalog()[key].glb)).is_empty():
		BodyCut.all()
		BodyCut._cuts[str(Car.catalog()[key].glb)] = {"tub": {"z": float(OS.get_environment("TT_Z")) if OS.get_environment("TT_Z") != "" else -1.25}}
		print("TT made a test tub cut")
	for rs in rides:
		var d := VehicleSpecs.default_design(key)
		d.ride = float(d.ride) + float(rs)
		var c := Car.new(); c.design = d; c.position = Vector3(x, 1.5, 0); add_child(c)
		x += 8.0
		for i in 200: await get_tree().physics_frame
		var ws := ""
		for w in c.wheels: ws += "%.3f " % w.L
		print("TT ride %s car y %.3f wheels L %s" % [rs, c.global_position.y, ws])
		var rb: RigidBody3D = c.unbolt_tub()
		if rb == null: print("TT no tub"); continue
		rb.contact_monitor = true; rb.max_contacts_reported = 16
		var y0 := (c.global_transform.affine_inverse() * rb.global_position).y
		for sh in rb.get_children():
			if sh is CollisionShape3D: print("TT  shape ", sh.position, " ", (sh.shape as BoxShape3D).size)
		for i in 360:
			await get_tree().physics_frame
			if i < 8 or (i % 20 == 0 and i > 140 and i < 280):
				var ns := ""
				for w in c.wheels: ns += "%.0f/%.3f " % [w.N, w.L]
				print("TT   i%d car v %s w %s N %s park %s" % [i, c.linear_velocity, c.angular_velocity, ns, c._park_at])
				var rel := c.global_transform.affine_inverse() * rb.global_transform
				print("TT   i%d rel o %s pitch %.1f car v %.2f carpitch %.1f tub v %s" % [i, rel.origin, rad_to_deg(rel.basis.get_euler().x), c.linear_velocity.length(), rad_to_deg(c.rotation.x), rb.linear_velocity])
			if i % 60 == 5:
				var st := PhysicsServer3D.body_get_direct_state(rb.get_rid())
				var hits := {}
				for ci in st.get_contact_count():
					var other = st.get_contact_collider_object(ci)
					var lsh := rb.shape_owner_get_owner(rb.shape_find_owner(st.get_contact_local_shape(ci))) as CollisionShape3D
					var nm := str(other.name) if other else "?"
					if other is CollisionObject3D:
						var osh = (other as CollisionObject3D).shape_owner_get_owner((other as CollisionObject3D).shape_find_owner(st.get_contact_collider_shape(ci)))
						nm += "/" + str(osh.name) + " " + str(((osh as CollisionShape3D).shape as BoxShape3D).size if (osh as CollisionShape3D).shape is BoxShape3D else "")
					hits["tub %s %s -> %s" % [lsh.position, (lsh.shape as BoxShape3D).size, nm]] = 1
				print("TT  t%d rel y %+.3f  %s" % [i, (c.global_transform.affine_inverse() * rb.global_position).y - y0, hits.keys()])
		c.queue_free(); rb.queue_free()
	print("TT_DONE")
	get_tree().quit()
