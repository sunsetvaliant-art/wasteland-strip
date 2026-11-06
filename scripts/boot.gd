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
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C], "jump": [KEY_SPACE],
		"interact": [KEY_F], "camera": [KEY_V], "lights": [KEY_L],
		"gear_up": [KEY_Q], "gear_down": [KEY_E], "brake": [KEY_SPACE], "menu": [KEY_ESCAPE],
		"debug": [KEY_F3], "seat_up": [KEY_BRACKETRIGHT], "seat_down": [KEY_BRACKETLEFT],
		"forge": [KEY_O], "forge_menu": [KEY_TAB], "fly_up": [KEY_SPACE], "fly_down": [KEY_CTRL],
		"rotate": [KEY_E], "delete": [KEY_X], "undo": [KEY_Z],
		"reload": [KEY_R], "holster": [KEY_H], "slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3],
		"slot_4": [KEY_4], "slot_5": [KEY_5], "slot_6": [KEY_6],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	var mouse := {"fire": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT, "weapon_next": MOUSE_BUTTON_WHEEL_DOWN, "weapon_prev": MOUSE_BUTTON_WHEEL_UP}
	for a in mouse:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse[a]
		InputMap.action_add_event(a, mb)
