extends SceneTree
## 0.2.74: how many bathrooms are a way through to somewhere (a door in, and another door on to a room past it)
func _init():
	var kinds := [["qlder", ""], ["cottage", ""], ["cottage", "shack"], ["brick", ""], ["brick", "estate1"], ["two_storey", ""], ["two_storey", "units70"]]
	for kd in kinds:
		var through := 0; var baths := 0; var unreach := 0; var n := 0
		for seed in 300:
			var p: Dictionary = BuildGen.plan(kd[0], 9.0 + (seed % 5) * 1.5, 8.0 + (seed % 7) * 1.0, seed * 7919 + 13, kd[1])
			if p.floors.is_empty(): continue
			n += 1
			for f in p.floors:
				for r in f.rooms:
					if not (r.type in ["bath", "toilet"]): continue
					baths += 1
					var doors := 0
					for side in r.ops:
						for op in r.ops[side]:
							if op.kind in ["door", "doorx"]: doors += 1
					if doors > 1: through += 1
					if doors == 0: unreach += 1
		print("PLANS %s %s: %d plans, %d baths, %d with two doors or more, %d with none" % [kd[0], kd[1], n, baths, through, unreach])
	quit()
