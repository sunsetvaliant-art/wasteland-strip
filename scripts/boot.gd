extends Node
## Runs before anything else. Loads every patch file sitting in the "patches" folder next to the game,
## so an update is just: drop the new .pck into that folder and restart. Later patches win over earlier ones
## (files are applied in name order: patch_0002 beats patch_0001), and a patch only needs to carry what changed.

var version := "0.2.0"
var patches_loaded: PackedStringArray = []

func _init() -> void:
	var dirs := [OS.get_executable_path().get_base_dir().path_join("patches"), "user://patches"]
	for d in dirs:
		if not DirAccess.dir_exists_absolute(d):
			continue
		var files := Array(DirAccess.get_files_at(d)).filter(func(f): return f.get_extension().to_lower() in ["pck", "zip"])
		files.sort()
		for f in files:
			if ProjectSettings.load_resource_pack(d.path_join(f), true):
				patches_loaded.append(f)
			else:
				push_warning("Patch failed to load: " + f)
	if FileAccess.file_exists("res://version.txt"):
		version = FileAccess.get_file_as_string("res://version.txt").strip_edges()
	_setup_inputs()

func _setup_inputs() -> void:
	InputSetup.ensure()
