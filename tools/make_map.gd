extends Node
## Bakes assets/world/map.png for the Forge Map tab: 20 m a pixel from (-8960, -19960), the old map and the north
## strip, coloured from the vegetation maps (sea, sand, bush, town, cane), the roads drawn from Roads' segments and
## every building a dark dot. Run as an extra autoload in a test run (the world has to be loaded):
##   sed -i 's|^Settings=.*|&\nMakeMap="*res://tools/make_map.gd"|' project.godot; godot --headless --path .; (remove the line)
const X0 := -8960.0
const Z0 := -19960.0
const MPX := 20.0
const W := 1601
const H := 1751

func _ready():
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	for _i in 10: await get_tree().process_frame
	var main = get_tree().current_scene
	var veg = main.veg
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var t0 := Time.get_ticks_msec()
	for py in H:
		for px in W:
			var x := X0 + (px + 0.5) * MPX
			var z := Z0 + (py + 0.5) * MPX
			var c := Color(0.1, 0.12, 0.14)
			var inside := z >= -16960.0 or (x >= 8480.0 and x < 15360.0)
			if inside and veg:
				var m: Color = veg.sample(x, z)
				var m2: Color = veg.sample2(x, z)
				var hgt: float = main.height_at(x, z)
				if m2.b > 0.45 or hgt < 0.15:
					c = Color(0.16, 0.33, 0.46)
				else:
					var g := Color(0.46, 0.58, 0.32).lerp(Color(0.17, 0.31, 0.15), clampf(m.r * 1.2, 0, 1))
					g = g.lerp(Color(0.56, 0.66, 0.3), clampf(m2.g, 0, 1) * 0.8)
					g = g.lerp(Color(0.86, 0.81, 0.6), clampf(m.g * 1.3, 0, 1))
					g = g.lerp(Color(0.6, 0.6, 0.57), clampf(m.b, 0, 1) * 0.55)
					# a touch of hill shading so the ranges read
					var e: float = main.height_at(x + MPX, z) - main.height_at(x - MPX, z) + main.height_at(x, z - MPX) - main.height_at(x, z + MPX)
					g = g.darkened(clampf(e * 0.012, -0.25, 0.25)) if e > 0 else g.lightened(clampf(-e * 0.008, 0, 0.15))
					c = g
			img.set_pixel(px, py, c)
	print("MAP ground in ", Time.get_ticks_msec() - t0, " ms")
	# buildings: a dark dot (two for the big ones)
	if Buildings.inst:
		for l in Buildings.inst.lots:
			var px := int((float(l[1]) - X0) / MPX); var py := int((float(l[2]) - Z0) / MPX)
			var r := 1 if float(l[4]) * float(l[5]) > 1500.0 else 0
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					if px + dx >= 0 and px + dx < W and py + dy >= 0 and py + dy < H:
						img.set_pixel(px + dx, py + dy, Color(0.3, 0.27, 0.25))
	# roads on top: the big ones lighter and wider
	var n := 0
	if main.roads:
		for k in main.roads._seg:
			var a: PackedFloat32Array = main.roads._seg[k]
			for i in range(0, a.size(), 5):
				var hw := a[i + 4]
				var col := Color(0.95, 0.88, 0.55) if hw > 4.0 else Color(0.88, 0.86, 0.8)
				_line(img, (a[i] - X0) / MPX, (a[i + 1] - Z0) / MPX, (a[i + 2] - X0) / MPX, (a[i + 3] - Z0) / MPX, col, hw > 4.0)
				n += 1
	var out := ProjectSettings.globalize_path("res://assets/world/map.png")
	img.save_png(out)
	print("MAP saved ", out, " roads ", n, " in ", Time.get_ticks_msec() - t0, " ms")
	get_tree().quit()

func _line(img: Image, x0: float, y0: float, x1: float, y1: float, c: Color, wide: bool) -> void:
	var steps := int(maxf(absf(x1 - x0), absf(y1 - y0)) * 2.0) + 1
	for s in steps + 1:
		var t := float(s) / steps
		var px := int(lerpf(x0, x1, t)); var py := int(lerpf(y0, y1, t))
		if px >= 0 and px < W and py >= 0 and py < H:
			img.set_pixel(px, py, c)
			if wide and px + 1 < W: img.set_pixel(px + 1, py, c)
