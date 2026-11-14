extends Node3D
## Mall lab: builds one mall's shell on flat ground (no world) and photographs it. Autoloads are there, so run it as
## a scene:  xvfb-run ... godot --path . res://tools/_polylab.tscn     env: MALL="TWIN CITY" W=378.3 D=244.7 SEED=...
## SHOTS="name:x,y,z:tx,ty,tz:fov[:top];..." OUT=/dir/     (top: looking straight down with north up the picture)
func _ready():
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.6, 0.72, 0.86)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.75
	add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, 30, 0); sun.light_energy = 1.1; sun.shadow_enabled = OS.get_environment("SHADOWS") != ""; add_child(sun)
	var g0 := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(900, 900); g0.mesh = pm; g0.position.y = -0.05
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.36, 0.42, 0.3); g0.material_override = gm; add_child(g0)
	var w := float(OS.get_environment("W")); var d := float(OS.get_environment("D"))
	var t0 := Time.get_ticks_msec()
	var p: Dictionary = BuildGen.plan("mall", w, d, int(OS.get_environment("SEED")), OS.get_environment("MALL"))
	var b: Node3D
	if OS.get_environment("LOD") != "":
		var g := BuildGen.Geo.new(); BuildGen.build_lod(p, g, func(_x, _z): return 0.0)
		var mi := MeshInstance3D.new(); mi.mesh = g.commit(); b = mi
	else:
		b = BuildGen.build(p, func(_x, _z): return 0.0)
	add_child(b)
	var body: Node = b.get_node_or_null("Body")
	print("POLYLAB built in ", Time.get_ticks_msec() - t0, " ms: rooms ", p.floors[0].rooms.size(), " collision boxes ", body.get_child_count() if body else 0, " labels ", p.get("_labels", []).size())
	var cam := Camera3D.new(); add_child(cam); cam.current = true; cam.far = 2000.0; cam.near = 0.1
	for sh in OS.get_environment("SHOTS").split(";"):
		var a := sh.split(":")
		var c := a[1].split(","); var t := a[2].split(",")
		cam.fov = float(a[3])
		var up := Vector3(-1, 0, 0) if a.size() > 4 else Vector3.UP
		cam.look_at_from_position(Vector3(float(c[0]), float(c[1]), float(c[2])), Vector3(float(t[0]), float(t[1]), float(t[2])), up)
		for _k in 6: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + a[0] + ".png")
		print("POLYLAB shot ", a[0])
	get_tree().quit()
