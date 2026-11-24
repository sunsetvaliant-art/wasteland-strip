extends Node
## 0.2.75: the character screen on its own (no world): /tmp/shots/charscreen.png
var player = null
var pause_menu = null
func _ready():
	await get_tree().process_frame
	var cs := CharacterScreen.new(); add_child(cs); cs.setup(self)
	cs.show_screen()
	cs._choose("height", 1.04); cs._choose("width", 1.1)
	for i in 20: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/charscreen.png")
	cs._choose("body", "mh_f_african")
	for i in 20: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/charscreen2.png")
	get_tree().quit()
