extends Node
## Dumps a mall's plan (rooms per floor) as JSON for drawing: env MALL=twin OUT=file.json
func _ready():
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/buildings.json"))
	var want := OS.get_environment("MALL")
	for l in d.lots:
		if str(l[0]) != "mall" or l.size() < 8 or str(l[7]) != want: continue
		var p: Dictionary = BuildGen.plan("mall", float(l[4]), float(l[5]), int(l[6]), str(l[7]))
		var out := {"lot": l, "floors": []}
		for fl in p.floors:
			var rs := []
			for r in fl.rooms:
				var ops := {}
				for side in ["N", "S", "W", "E"]:
					ops[side] = []
					for op in r.ops[side]: ops[side].append([op.kind, op.a, op.b, op.get("ext", false)])
				rs.append({"t": r.type, "n": r.get("name", ""), "x0": r.x0, "x1": r.x1, "z0": r.z0, "z1": r.z1, "ops": ops})
			out.floors.append({"y": fl.y, "rooms": rs})
		var f := FileAccess.open(OS.get_environment("OUT"), FileAccess.WRITE)
		f.store_string(JSON.stringify(out))
		print("PLAN ", want, " floors ", p.floors.size(), " rooms ", out.floors[0].rooms.size())
	get_tree().quit()
