extends Node
## 0.2.74: the animals in place: walking side on (nose to the left = heading -X... no: they head where they face),
## then shot dead. /tmp/shots/animals_walk.png, animals_dead.png
var player = null
func height_at(_x: float, _z: float) -> float: return 5.0     # (not water)
func _ready():
	await get_tree().process_frame
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.62, 0.7, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.85, 0.85, 0.85); env.ambient_light_energy = 0.9
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); add_child(sun)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(200, 2, 200); cs.shape = b; cs.position.y = -1; g.add_child(cs); add_child(g)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); fl.mesh = pm; add_child(fl)
	var cam := Camera3D.new(); add_child(cam); cam.current = true; cam.fov = 40
	var an := []
	var x := -3.0
	for sp in ["deer", "pig", "rabbit"]:
		var a := Animal.new(); a.setup(self, sp); add_child(a); a.global_position = Vector3(x, 0.3, 0)
		a._yaw = -PI / 2     # heading +x
		a.state = "walk"; a.state_t = 99.0; a.goal = Vector3(x + 50, 0, 0)
		an.append(a); x += 3.0
	for i in 40: await get_tree().physics_frame
	cam.look_at_from_position(Vector3(0, 1.2, 9), Vector3(0, 0.5, 0))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/animals_walk.png")
	for a in an:
		print("ANIMAL ", a.species, " clips ", a.clips, " pos ", a.global_position, " model scale ", a.model.scale.x)
		a.take_hit({"chest": 500.0}, Vector3.RIGHT, a.global_position, 5.0, null)
	for i in 90: await get_tree().physics_frame
	var c0: Vector3 = an[1].global_position
	cam.look_at_from_position(c0 + Vector3(0, 2.0, 8), c0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/animals_dead.png")
	print("ANIMAL dead ", an.map(func(a): return a.dead), " hint ", an[0].hint())
	get_tree().quit()
