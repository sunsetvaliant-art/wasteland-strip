extends Node
## 0.2.68: where each body's engine ends up: bay span (firewall, front) and the engine's box after the fit
func _ready():
	await get_tree().process_frame
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(400, 2, 400); cs.shape = b; cs.position.y = -1; g.add_child(cs); add_child(g)
	var x := 0.0
	var cars := []
	var keys: Array = Car.catalog().keys() if OS.get_environment("FT_CARS") == "" else Array(OS.get_environment("FT_CARS").split(","))
	for k in keys:
		if Car.catalog()[k].has("forks"): continue
		var c := Car.new(); c.design = VehicleSpecs.default_design(k); c.position = Vector3(x, 1.0, 0); add_child(c)
		x += 7.0
		cars.append(c)
	for i in 30: await get_tree().process_frame
	for c in cars:
		var en: Node3D = c.parts.engine_node
		if en == null: print("FITT ", c.kind, " no engine"); continue
		var ab: AABB = c.parts._aabb_of(en, Transform3D.IDENTITY)
		var off: Array = c.design.cab_offset
		var bay := BodyCut.bay_span(str(c.def.glb))
		print("FITT %-14s bay %s  engine z %.2f..%.2f (body frame %.2f..%.2f)  y top %.2f" % [c.kind, str(bay), ab.position.z, ab.end.z, ab.position.z - float(off[2]), ab.end.z - float(off[2]), ab.end.y])
	get_tree().quit()
