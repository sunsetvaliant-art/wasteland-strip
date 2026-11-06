class_name InputSetup
extends RefCounted
## Every key and button the game uses. Called from the launcher and the main scene as well as Boot: Boot runs from
## the original install before any update is loaded, so keys added in updates have to be registered by code that
## the updates actually replace.

static func ensure() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C], "jump": [KEY_SPACE],
		"interact": [KEY_F], "camera": [KEY_V], "lights": [KEY_L],
		"gear_up": [KEY_Q], "gear_down": [KEY_E], "brake": [KEY_SPACE], "menu": [KEY_ESCAPE],
		"debug": [KEY_F3], "seat_up": [KEY_BRACKETRIGHT], "seat_down": [KEY_BRACKETLEFT],
		"forge": [KEY_O], "forge_menu": [KEY_TAB], "fly_up": [KEY_SPACE], "fly_down": [KEY_CTRL],
		"rotate": [KEY_E], "delete": [KEY_X], "undo": [KEY_Z],
		"reload": [KEY_R], "holster": [KEY_H], "slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3],
		"slot_4": [KEY_4], "slot_5": [KEY_5], "slot_6": [KEY_6], "bug_report": [KEY_F9],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			if not InputMap.action_has_event(a, ev):
				InputMap.action_add_event(a, ev)
	var mouse := {"fire": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT, "weapon_next": MOUSE_BUTTON_WHEEL_DOWN, "weapon_prev": MOUSE_BUTTON_WHEEL_UP}
	for a in mouse:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse[a]
		if not InputMap.action_has_event(a, mb):
			InputMap.action_add_event(a, mb)
