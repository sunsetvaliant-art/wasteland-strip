extends Node
## A live axle with one wheel up a 0.35 m block: do the wheels sit square to the housing (0.2.62)
## xvfb: SHOT_CAR=vhute godot --path . res://tools/_flexshot.tscn -> /tmp/shots/flex_rear.png
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.65, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.8); env.ambient_light_energy = 1.2
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 160, 0); add_child(sun)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(200, 2, 200); cs.shape = b; cs.position.y = -1; g.add_child(cs); g.add_to_group("road"); add_child(g)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); fl.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.35, 0.36, 0.33); fl.material_override = fm; add_child(fl)
	var c := Car.new(); c.design = VehicleSpecs.default_design(OS.get_environment("SHOT_CAR") if OS.get_environment("SHOT_CAR") != "" else "vhute")
	var zr := INF; var tr := 0.8
	for a in c.design.axles:
		if float(a.z) < zr: zr = float(a.z); tr = float(a.track)
	# a block under the left rear wheel (side -1 is -X)
	var blk := StaticBody3D.new(); var bc := CollisionShape3D.new(); var bb := BoxShape3D.new(); bb.size = Vector3(0.6, 0.35, 1.2); bc.shape = bb; blk.add_child(bc); blk.add_to_group("road")
	blk.position = Vector3(-tr, 0.175, zr); add_child(blk)
	var bm := MeshInstance3D.new(); var bx := BoxMesh.new(); bx.size = bb.size; bm.mesh = bx; blk.add_child(bm)
	c.position = Vector3(0, 1.3, 0); add_child(c)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 40
	for i in 240: await get_tree().physics_frame
	for n in c.find_children("*", "MeshInstance3D", true, false):
		if not c.parts.is_ancestor_of(n): (n as MeshInstance3D).visible = false
	var ctr := c.global_transform * Vector3(0, 0.3, zr)
	cam.global_position = c.global_transform * Vector3(0, 0.35, zr - 3.2); cam.look_at(ctr); cam.current = true
	for i in 6: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/flex_rear.png")
	for w in c.wheels: print("FLEX axle ", w.axle, " side ", w.side, " centre y ", snappedf((c.parts._wheel_centre(w) as Vector3).y, 0.001), " type ", w.a.get("type"))
	get_tree().quit()
