extends Node
## 0.2.74 headless: an engine lowered back into an open bay from above goes in (no catching on the body) and sits on
## its mounts ready to bolt in.
func _ready():
	await get_tree().process_frame
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(400, 2, 400); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	for bonnet in [true, false]:
		var ch := Car.new(); var d := VehicleSpecs.default_design("ranger_dc")
		if bonnet: d["bonnet_off"] = true
		else: d["no_cab"] = true
		ch.design = d; ch.position = Vector3(0 if bonnet else 20, 1.0, 0); add_child(ch)
		for i in 240: await get_tree().physics_frame
		print("T74 bonnet pivot ", ch.bonnet_pivot != null, " out ok '", ch.engine_out_ok(), "'")
		var lump: LooseLump = ch.unbolt_engine()
		if lump == null:
			print("T74 FAIL no lump"); continue
		var h := ch.engine_home()
		var seat := ch.to_local(lump.global_position).y
		# lift it right out and away (as a hoist would), then bring it back over the bay 1.4 m up and let go
		lump.wake()
		lump.global_position = ch.to_global(Vector3(0, 4.0, h.z))
		for i in 30: await get_tree().physics_frame
		lump.global_position = ch.to_global(Vector3(0.05, h.y + 1.4, h.z + 0.1))
		lump.linear_velocity = Vector3.ZERO; lump.angular_velocity = Vector3.ZERO
		lump.global_basis = ch.global_basis
		var ymin := 99.0
		for i in 360:
			await get_tree().physics_frame
			ymin = minf(ymin, ch.to_local(lump.global_position).y)
		var l := ch.to_local(lump.global_position)
		print("T74 %s: dropped from %.2f, settled at y %.2f (seat %.2f, home %.2f, lowest %.2f) bay=%s clear=%s" % ["bonnet off" if bonnet else "no cab", h.y + 1.4, l.y, seat, h.y, ymin, lump.bay == ch, lump._clear])
		print("T74 bolts in: ", ch.bolt_engine(lump))
	get_tree().quit()
