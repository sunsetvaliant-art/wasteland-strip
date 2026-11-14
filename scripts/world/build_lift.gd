class_name BuildLift
extends StaticBody3D
## The call panel in a lift car. F takes you to the next stop (ground, a floor part-way up, the roof, and round again).
## There's no power: you're hauling the car on its emergency winder, so it takes a moment.

var stops: Array = []
var names: Array = []
var at := 0

func setup(s: Array, n: Array, i: int, depth: float, panel := Vector3.INF) -> void:
	stops = s
	names = n
	at = i
	collision_layer = 1
	collision_mask = 0
	var st: Vector3 = stops[i]
	position = Vector3(1.1, st.y + 1.2, -depth / 2 + 0.25) if panel == Vector3.INF else Vector3(panel.x, st.y + 1.2, panel.z)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.45, 0.06)
	mi.mesh = bm
	mi.material_override = BuildGen.mat("steel")
	add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 0.7, 0.2)
	cs.shape = bs
	add_child(cs)

func hint() -> String:
	return "Lift (%s)  ·  F wind it to %s" % [names[at], names[(at + 1) % stops.size()]]

func use(who: Node3D) -> void:
	var nxt := (at + 1) % stops.size()
	var root := get_parent() as Node3D
	who.global_position = root.to_global(stops[nxt]) + Vector3(0, 0.15, 0)
	if "velocity" in who: who.velocity = Vector3.ZERO
	if who.has_method("_toast"): who._toast("The car grinds its way to: %s" % names[nxt])
