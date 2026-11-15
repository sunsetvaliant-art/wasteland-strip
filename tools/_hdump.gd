extends Node
## dump terrain heights on a grid (env HD="x0,z0,x1,z1,step") to /tmp/hdump.f32 (rows of z, columns of x)
func _ready() -> void:
	await get_tree().create_timer(6.0).timeout
	var main = get_tree().root.get_node_or_null("Main")
	var a := OS.get_environment("HD").split(",")
	var x0 := float(a[0]); var z0 := float(a[1]); var x1 := float(a[2]); var z1 := float(a[3]); var st := float(a[4])
	var f := FileAccess.open("/tmp/hdump.f32", FileAccess.WRITE)
	var nx := int((x1 - x0) / st) + 1; var nz := int((z1 - z0) / st) + 1
	f.store_32(nx); f.store_32(nz)
	for j in nz:
		for i in nx:
			var h: float = main.terrain.data.get_height(Vector3(x0 + i * st, 0, z0 + j * st))
			f.store_float(h if is_finite(h) else -999.0)
	f.close()
	print("HDUMP ", nx, "x", nz)
	get_tree().quit()
