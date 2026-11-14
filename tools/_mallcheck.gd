extends SceneTree
## Prints each big mall's ways in, in world coordinates, with a spot 30 m out to stand and look at it from.
func _init():
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/buildings.json"))
	for l in d.lots:
		if str(l[0]) != "mall" or (l.size() > 7 and str(l[7]).ends_with("/P")): continue
		var p: Dictionary = BuildGen.plan("mall", float(l[4]), float(l[5]), int(l[6]), str(l[7]) if l.size() > 7 else "")
		var xf := Transform3D(Basis(Vector3.UP, float(l[3])), Vector3(float(l[1]), 0, float(l[2])))
		for r in p.floors[0].rooms:
			if r.type != "concourse": continue
			for side in ["N", "S", "W", "E"]:
				for op in r.ops[side]:
					if op.kind != "open" or float(op.y0) > 0.3 or not BuildGen._ext_side(p, r, side) and MallGen._bare(p.floors[0].rooms, r, side).is_empty(): continue
					var c := (float(op.a) + float(op.b)) * 0.5
					var pt: Vector3; var outv: Vector3
					match side:
						"N": pt = Vector3(c, 0, float(r.z0)); outv = Vector3(0, 0, -1)
						"S": pt = Vector3(c, 0, float(r.z1)); outv = Vector3(0, 0, 1)
						"W": pt = Vector3(float(r.x0), 0, c); outv = Vector3(-1, 0, 0)
						_: pt = Vector3(float(r.x1), 0, c); outv = Vector3(1, 0, 0)
					var w: Vector3 = xf * pt
					var st: Vector3 = xf * (pt + outv * 30.0)
					print("ENTRY %s %s width %.1f at %d %d  stand %d %d" % [l[7], side, float(op.b) - float(op.a), int(w.x), int(w.z), int(st.x), int(st.z)])
	quit()
