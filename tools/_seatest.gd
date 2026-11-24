extends Node3D
## The sea shader on a patch of the real beach, without the whole world (which won't fit in the sandbox under Vulkan).
## Ground from /tmp/seatest_h.bin + _c.bin (float32 heights / RGB8, 5 m grid; /tmp/seatest.txt = "w h x0 z0"),
## made from tools/coast_fix.py's CF_DEBUG crop. env SEA_CAMS = "name:x:y:z:yaw:pitch;..." -> /tmp/shots/sea_<name>.png
## (two frames 3 s apart: _a and _b)
func _ready() -> void:
	var info := FileAccess.get_file_as_string("/tmp/seatest.txt").split(" ")
	var w := int(info[0]); var h := int(info[1]); var x0 := float(info[2]); var z0 := float(info[3])
	var hb := FileAccess.get_file_as_bytes("/tmp/seatest_h.bin")
	var cb := FileAccess.get_file_as_bytes("/tmp/seatest_c.bin")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in h:
		for i in w:
			var k := j * w + i
			st.set_color(Color8(cb[k * 3], cb[k * 3 + 1], cb[k * 3 + 2]))
			st.set_uv(Vector2(i, j) * 0.25)
			st.add_vertex(Vector3(x0 + i * 5.0, hb.decode_float(k * 4), z0 + j * 5.0))
	for j in h - 1:
		for i in w - 1:
			var a := j * w + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + w)
			st.add_index(a + 1); st.add_index(a + w + 1); st.add_index(a + w)
	st.generate_normals()
	var gm := MeshInstance3D.new()
	gm.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	var nz := NoiseTexture2D.new(); nz.noise = FastNoiseLite.new(); nz.noise.frequency = 0.2; nz.seamless = true
	mat.detail_enabled = true; mat.detail_albedo = nz; mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	gm.material_override = mat
	add_child(gm)
	var env := Environment.new()
	var sky := Sky.new(); sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 70, 0); sun.shadow_enabled = true; add_child(sun)
	# the sea, as main.gd builds it
	var rn := FastNoiseLite.new(); rn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; rn.frequency = 0.012; rn.fractal_octaves = 4
	var rt := NoiseTexture2D.new(); rt.width = 512; rt.height = 512; rt.seamless = true; rt.as_normal_map = true; rt.bump_strength = 6.0; rt.noise = rn
	var fn2 := FastNoiseLite.new(); fn2.frequency = 0.03
	var ft := NoiseTexture2D.new(); ft.width = 256; ft.height = 256; ft.seamless = true; ft.noise = fn2
	await rt.changed
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(80000, 80000); pm.subdivide_width = 64; pm.subdivide_depth = 64
	sea.mesh = pm
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/sea.gdshader")
	sm.set_shader_parameter("ripple_tex", rt); sm.set_shader_parameter("foam_tex", ft)
	var sd: Texture2D = load("res://assets/world/sea_dist.png")
	sm.set_shader_parameter("dist_tex", sd)
	sm.set_shader_parameter("dist_rect", Vector4(12000.0, -20480.0, sd.get_width() * 10.0, sd.get_height() * 10.0))
	sea.material_override = sm
	sea.position = Vector3(7040, 0.1, -960)
	add_child(sea)
	var cam := Camera3D.new(); cam.far = 20000.0; add_child(cam); cam.current = true
	for step in OS.get_environment("SEA_CAMS").split(";", false):
		var a := step.split(":")
		cam.position = Vector3(float(a[1]), float(a[2]), float(a[3]))
		cam.rotation = Vector3(float(a[5]), float(a[4]), 0)
		for _i in 20: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/shots/sea_%s_a.png" % a[0])
		await get_tree().create_timer(3.0).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/shots/sea_%s_b.png" % a[0])
		print("SEA shot ", a[0])
	get_tree().quit()
