extends Node
## Screenshots from fixed spots: SHOTS="name:ex:ey:ez:tx:ty:tz;..." (eye and target heights are above the ground there).
## Run under xvfb (GL) as PT="*res://tools/_viewshots.gd". Writes /tmp/shots/v_<name>.png
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	var main = get_tree().current_scene
	for _i in 20: await get_tree().physics_frame
	var f = main.forge
	if not f.active: f.toggle()
	f._set_palette(false)
	f.ui.visible = false
	if SkyCycle.inst:
		SkyCycle.inst.set_manual(0.42, 0.0); SkyCycle.inst.frozen = true
	for sh in OS.get_environment("SHOTS").split(";", false):
		var a := sh.split(":")
		var eye := Vector3(float(a[1]), 0, float(a[3])); var at := Vector3(float(a[4]), 0, float(a[6]))
		eye.y = main.height_at(eye.x, eye.z) + float(a[2]); at.y = main.height_at(at.x, at.z) + float(a[5])
		f.cam.global_position = eye
		f.cam.look_at(at)
		f.yaw = f.cam.rotation.y; f.pitch = f.cam.rotation.x
		var t0 := Time.get_ticks_msec()
		for _i in 110: await get_tree().process_frame
		eye.y = main.height_at(eye.x, eye.z) + float(a[2]); at.y = main.height_at(at.x, at.z) + float(a[5])
		f.cam.global_position = eye
		f.cam.look_at(at)
		for _i in 20: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/shots/v_%s.png" % a[0])
		print("SHOT v_%s (%d ms)" % [a[0], Time.get_ticks_msec() - t0])
	get_tree().quit()
