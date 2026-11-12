extends SceneTree
func _init() -> void:
	var k: Array = Rig._pool().keys()
	k.sort()
	print("CLIPS ", k.size(), " ", k)
	quit()
