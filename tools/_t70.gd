extends Node
## 0.2.70 headless: unbolting an engine leaves the car where it is; dragged sideways the engine stays on its mounts
## till it's out; a part of your own comes off and goes back on; turbo sizes
var dummy: StaticBody3D
func _ready():
	await get_tree().process_frame
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(400, 2, 400); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	dummy = StaticBody3D.new(); add_child(dummy); dummy.position = Vector3(0, -50, 0)
	var ch := Car.new(); var d := VehicleSpecs.default_design("ranger_dc"); d["no_cab"] = true; ch.design = d; ch.position = Vector3(0, 1.0, 0); add_child(ch)
	for i in 240: await get_tree().physics_frame
	var y0 := ch.global_position.y
	var lump: LooseLump = ch.unbolt_engine()
	for i in 120: await get_tree().physics_frame
	print("T70 car moved %.3f m on unbolting, engine frozen %s at local y %.2f" % [ch.global_position.y - y0, lump.freeze, ch.to_local(lump.global_position).y])
	# drag it sideways with a strap to a post 6 m off to the side
	var post := StaticBody3D.new(); add_child(post); post.global_position = ch.global_position + ch.global_basis.x * 6.0
	var ly0 := ch.to_local(lump.global_position).y
	var st := Strap.make(self, "strap_2t", lump, lump.global_position + Vector3(0, 0.2, 0), post, post.global_position + Vector3(0, 0.6, 0))
	st.length = 4.0          # pull it in
	var miny := 99.0
	for i in 360:
		await get_tree().physics_frame
		var l := ch.to_local(lump.global_position)
		if absf(l.x) < 1.0: miny = minf(miny, l.y)
	print("T70 dragged out sideways: lowest in the bay %.2f (sat at %.2f), now %.1f m out, car moved %.3f" % [miny, ly0, absf(ch.to_local(lump.global_position).x), ch.global_position.y - y0])
	st.queue_free()
	# a part of your own on the Ranger
	var glb := "ranger_dc2003"
	BodyCut.all()
	var cut: Dictionary = BodyCut._cuts.get(glb, {}).duplicate(true)
	var nt := 0
	for m in BodyCut.meshes_of(glb):
		for si in (m.mesh as Mesh).get_surface_count():
			var arr := (m.mesh as Mesh).surface_get_arrays(si)
			nt += ((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	var lab := PackedByteArray(); lab.resize(nt)
	for i in range(0, 600): lab[i] = 4
	cut["paint"] = {"n": nt, "runs": BodyCut.runs_of(lab)}; cut["parts"] = [{"name": "Side steps", "off": false}]
	BodyCut._cuts[glb] = cut; BodyCut._cache.clear(); BodyCut._dref.clear()
	var c := Car.new(); c.design = VehicleSpecs.default_design("ranger_dc"); c.position = Vector3(20, 1.0, 0); add_child(c)
	for i in 60: await get_tree().physics_frame
	print("T70 own parts ", c.own_parts())
	var rb := c.take_off_part(4)
	for i in 30: await get_tree().physics_frame
	print("T70 took off: ", rb != null, " parts_off ", c.design.get("parts_off"), " own ", c.own_parts(), " near ", c.loose_part_near(4) != null)
	print("T70 bolted back: ", c.fit_part(4), " parts_off ", c.design.get("parts_off"))
	for ex in ["ex_4_tlow_s", "ex_4_tlow_m", "ex_4_tlow_l", "ex_4_thigh_l"]:
		var k := EngineKit.make("i4", false, "sohc", "med", "tb"); k.exhaust = [ex]
		var sc: Array = EngineKit.stats(k).curve
		print("T70 %s: %s  1800 rpm %.0f, peak %.0f" % [ex, EngineKit.item_def(ex).name, float(sc[2][1]), float(sc[3][1])])
	print("T70_DONE")
	get_tree().quit()
