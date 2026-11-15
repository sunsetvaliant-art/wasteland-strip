extends Node
## 0.2.49: teleport to a wreckers' yard and a caravan park, count what YardGen built (YT lines)
func _ready() -> void:
	await get_tree().create_timer(8.0).timeout
	var main = get_tree().root.get_node_or_null("Main")
	if main == null:
		for n in get_tree().root.get_children():
			if n.get("yards") != null: main = n
	if main == null: print("YT no main"); get_tree().quit(); return
	for spot in [Vector2(1326.8, 242.6), Vector2(-174, 1721)]:
		main.player.global_position = Vector3(spot.x, main.height_at(spot.x, spot.y) + 2.0, spot.y)
		for _i in 60: await get_tree().process_frame
		await get_tree().create_timer(2.0).timeout
		for y in main.yards.yards:
			if y.node != null:
				var cont := 0; var kids := 0
				for c in y.node.get_children():
					kids += 1
					if c.has_meta("container"): cont += 1
				print("YT %s %s kids %d containers %d" % [y.kind, y.name, kids, cont])
	get_tree().quit()
