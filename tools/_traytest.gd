extends Node
## The player standing on a parked truck's tray (0.2.58 F9: the AA-160 flipped over). Spawns it, stands the player on
## the deck, and watches the truck for 8 s. Add as PT="*res://tools/_traytest.gd" under Settings=.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	for _i in 60: await get_tree().physics_frame
	var main = get_tree().current_scene
	var p = main.player
	for key in ["flatbed", "workhorse"]:
		var c: Car = main.spawn_vehicle(key, p.global_position + Vector3(8, 1.5, 0), 0.0)
		for _i in 240: await get_tree().physics_frame
		var p0 := c.global_position
		var deck := c.global_transform * Vector3(0, float(c.design.ride) + 1.2, float(c.def.min[0]) + 0.9)
		p.global_position = deck + Vector3(0, 0.6, 0)
		p.velocity = Vector3.ZERO
		var worst := 0.0
		var t := 0.0
		for i in Engine.physics_ticks_per_second * 8:
			await get_tree().physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			worst = maxf(worst, c.linear_velocity.length())
			if i % Engine.physics_ticks_per_second == 0:
				print("TRAY %s t=%.0f car moved %.2f m, up.y %.2f, v %.2f, ang %.2f, player y-off %.2f, frozen %s lod %s, on floor %s" % [key, t,
					(c.global_position - p0).length(), c.global_transform.basis.y.y, c.linear_velocity.length(), c.angular_velocity.length(),
					p.global_position.y - c.global_position.y, c.freeze, c.get_meta("lod_parked", false), p.is_on_floor()])
		print("TRAY %s worst speed %.2f m/s, ended upright %s" % [key, worst, c.global_transform.basis.y.y > 0.9])
		p.global_position = c.global_position + Vector3(-12, 2, 0)
		for _i in 30: await get_tree().physics_frame
		c.queue_free()
		for _i in 10: await get_tree().physics_frame
	get_tree().quit()
