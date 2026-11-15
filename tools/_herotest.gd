extends Node
## 0.2.52: plan and build the three landmark buildings off the map (flat ground), count rooms, doors, windows
func _ready() -> void:
	var flat := func(x: float, z: float) -> float: return -0.3
	for t in [["shop", 39.8, 30.7, "pub/2/3.5/IMPERIAL HOTEL/imperial"], ["shop", 8.6, 30.5, "cafe/2/3.0/AUSTRAL CAFE & BAKERY/austral"], ["pub", 38.9, 29.1, "RIVERVIEW HOTEL|riverview"]]:
		var p: Dictionary = BuildGen.plan(t[0], t[1], t[2], 1234, t[3])
		var n := 0; var ops := 0
		for f in p.floors:
			for r in f.rooms:
				n += 1
				for s in r.ops: ops += r.ops[s].size()
		var root: Node3D = BuildGen.build(p, flat)
		var lab := root.find_children("*", "Label3D", true, false).size()
		print("HT %s floors %d rooms %d openings %d ext_doors %d labels %d children %d" % [t[3], p.floors.size(), n, ops, p.ext_doors.size(), lab, root.get_child_count()])
		root.free()
	get_tree().quit()
