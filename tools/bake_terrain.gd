extends SceneTree
## One-off: turns the stitched Tweed height map (5 m grid, 6401 px square) and the aerial colour map into
## Terrain3D region files under res://terrain. World coordinates match the browser game (the Riverview pub ~ 0,0).
## run: godot --headless --path . --script res://tools/bake_terrain.gd

const SPACING := 5.0
const X0 := -8960.0
const Z0 := -16960.0

func _init() -> void:
	var t := Terrain3D.new()
	t.vertex_spacing = SPACING
	root.add_child(t)
	await process_frame
	t.change_region_size(1024)
	print("region size ", t.region_size)
	var imgs: Array[Image] = []
	imgs.resize(Terrain3DRegion.TYPE_MAX)
	var h := Terrain3DUtil.load_image("res://data/height.r16", ResourceLoader.CACHE_MODE_IGNORE, Vector2(-60.0, 840.0), Vector2i(6401, 6401))
	print("height ", h.get_size(), " ", Terrain3DUtil.get_min_max(h))
	imgs[Terrain3DRegion.TYPE_HEIGHT] = h
	var c := Image.load_from_file(ProjectSettings.globalize_path("res://data/tint.png"))
	c.convert(Image.FORMAT_RGBA8)
	imgs[Terrain3DRegion.TYPE_COLOR] = c
	var ctrl := Image.create_from_data(6401, 6401, false, Image.FORMAT_RF, FileAccess.get_file_as_bytes("res://data/control.bin"))
	imgs[Terrain3DRegion.TYPE_CONTROL] = ctrl
	t.data.import_images(imgs, Vector3(X0, 0, Z0), 0.0, 1.0)
	for f in DirAccess.get_files_at("res://terrain"): DirAccess.remove_absolute("res://terrain/" + f)
	DirAccess.make_dir_recursive_absolute("res://terrain")
	t.data.save_directory("res://terrain")
	print("regions ", t.data.get_region_count())
	quit()
