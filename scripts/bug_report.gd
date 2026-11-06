class_name BugReport
extends CanvasLayer
## F9: grab a screenshot and everything about the moment (where you are, what you're driving or holding, the AI
## round you, settings, frame rate, the end of the log), pause, let you type what went wrong, then pack it all into
## one zip in your bug_reports folder, ready to drag into the chat with Claude.

const DIR := "user://bug_reports/"
const TOKEN_FILE := "user://bug_report_github.cfg"     # stays on this PC; never part of the game files
const DEFAULT_REPO := "sunsetvaliant-art/wasteland-reports"
var main
var panel: PanelContainer
var shot: Image
var state: Dictionary
var notes: TextEdit
var kind_opt: OptionButton
var thumb: TextureRect
var status: Label
var open_btn: Button
var save_btn: Button
var was_paused := false
var was_mouse := Input.MOUSE_MODE_CAPTURED
var last_zip := ""
var last_stamp := ""
var send_btn: Button
var token_box: LineEdit
var token_row: HBoxContainer
var http: HTTPRequest
var _uploads: Array = []

func setup(m) -> void:
	main = m
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	panel.visible = false

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("bug_report"):
		get_viewport().set_input_as_handled()
		if panel.visible: _close()
		else: _capture()
	elif panel.visible and e.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()

func _capture() -> void:
	# the picture first, before the form covers it
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	shot = get_viewport().get_texture().get_image()
	if shot == null or shot.is_empty():
		shot = Image.create(16, 9, false, Image.FORMAT_RGB8)      # headless / no renderer
	state = _gather()
	was_paused = get_tree().paused
	was_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var small := shot.duplicate()
	small.resize(480, int(480.0 * shot.get_height() / max(shot.get_width(), 1)))
	thumb.texture = ImageTexture.create_from_image(small)
	notes.text = ""
	status.text = "What happened? What did you expect? Anything you did just before?"
	open_btn.visible = false
	save_btn.disabled = false
	send_btn.disabled = false
	last_zip = ""
	token_row.visible = false
	panel.visible = true
	notes.grab_focus()

func _close() -> void:
	panel.visible = false
	get_tree().paused = was_paused
	Input.mouse_mode = was_mouse

# ---------------------------------------------------------------- what's going on right now
func _v3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]

func _gather() -> Dictionary:
	var d := {}
	d.time = Time.get_datetime_string_from_system()
	d.version = Boot.version
	d.patches = Array(Boot.patches_loaded)
	d.os = OS.get_name() + " " + OS.get_version()
	d.gpu = RenderingServer.get_video_adapter_name() + " / " + RenderingServer.get_video_adapter_vendor()
	d.renderer = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	d.fps = Engine.get_frames_per_second()
	d.frame_ms = snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01)
	d.physics_ms = snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01)
	d.memory_mb = int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	d.draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	d.objects = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	d.window = [get_viewport().size.x, get_viewport().size.y]
	d.settings = Settings.v.duplicate()
	d.mode = "creative" if Settings.creative() else "survival"
	if main == null:
		return d
	d.forge_active = main.forge.active if main.forge else false
	d.garage_open = main.garage.open if main.garage else false
	var p: Player = main.player
	if p:
		var pd := {"pos": _v3(p.global_position), "yaw": snappedf(p.yaw, 0.01), "pitch": snappedf(p.pitch, 0.01), "body_yaw": snappedf(p.body_yaw, 0.01),
			"hp": snappedf(p.hp, 0.1), "dead": p.dead, "crouching": p.crouching, "first_person": p.first_person, "on_floor": p.is_on_floor(),
			"velocity": _v3(p.velocity), "ground_h": snappedf(main.height_at(p.global_position.x, p.global_position.z), 0.01)}
		var g: Gun = p.gun()
		if g: pd.gun = {"key": g.key, "ammo": g.ammo, "reserve": g.reserve, "reloading": g.reloading > 0.0, "holstered": p.holstered, "ads": snappedf(p.ads, 0.01)}
		pd.anim = p.rig.anim.current_animation if p.rig and p.rig.anim else ""
		if p.vehicle:
			var c: Car = p.vehicle
			pd.vehicle = {"kind": c.kind, "kmh": snappedf(c.speed_kmh(), 0.1), "gear": c.gear_name(), "rpm": int(c.rpm), "throttle": snappedf(c.throttle, 0.01),
				"pos": _v3(c.global_position), "up": snappedf(c.global_transform.basis.y.y, 0.01), "engine": c.design.get("engine", ""), "gearbox": c.design.get("gearbox", ""),
				"wheels": c.wheels.map(func(w): return {"contact": w.contact, "load_N": int(w.N), "compress": snappedf(w.L, 0.01)})}
		d.player = pd
		# who's about
		var near: Array = []
		for n in get_tree().get_nodes_in_group("npcs") + get_tree().get_nodes_in_group("corpses"):
			if not is_instance_valid(n): continue
			var dist: float = (n as Node3D).global_position.distance_to(p.global_position)
			if dist < 150.0:
				near.append({"kind": n.kind, "model": n.model_key, "state": n.state, "dist": snappedf(dist, 0.1), "hp": snappedf(n.hp, 0.1), "dead": n.dead,
					"suspicion": snappedf(n.suspicion, 0.01), "anim": n.rig.anim.current_animation if n.rig and n.rig.anim else ""})
		near.sort_custom(func(a, b): return a.dist < b.dist)
		d.npcs_near = near.slice(0, 30)
		d.npc_total = get_tree().get_nodes_in_group("npcs").size()
		if main.camps:
			var cs: Dictionary = main.camps.nearest(p.global_position)
			if not cs.is_empty(): d.nearest_camp = {"dist": snappedf((cs.pos as Vector3).distance_to(p.global_position), 1.0), "built": cs.built != null, "scavs": cs.scavs.size()}
		d.vehicles_in_world = get_tree().get_nodes_in_group("vehicles").size()
	return d

## The end of Godot's own log (errors and warnings land here)
func _log_tail(lines := 400) -> String:
	var path := "user://logs/godot.log"
	if not FileAccess.file_exists(path):
		return "(no log file)"
	var all := FileAccess.get_file_as_string(path).split("\n")
	return "\n".join(all.slice(max(all.size() - lines, 0)))

# ---------------------------------------------------------------- saving
func _save() -> void:
	if shot == null:
		shot = Image.create(16, 9, false, Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var name := "bug_%s.zip" % stamp
	last_stamp = stamp
	var zp := ZIPPacker.new()
	if zp.open(DIR + name) != OK:
		status.text = "Couldn't write the report file."
		return
	var report := "Wasteland bug report\n%s\nType: %s\n\n%s\n" % [state.get("time", ""), kind_opt.get_item_text(kind_opt.selected), notes.text]
	zp.start_file("notes.txt"); zp.write_file(report.to_utf8_buffer()); zp.close_file()
	zp.start_file("state.json"); zp.write_file(JSON.stringify(state, "  ").to_utf8_buffer()); zp.close_file()
	zp.start_file("screenshot.png"); zp.write_file(shot.save_png_to_buffer()); zp.close_file()
	zp.start_file("log_tail.txt"); zp.write_file(_log_tail().to_utf8_buffer()); zp.close_file()
	zp.close()
	last_zip = ProjectSettings.globalize_path(DIR + name)
	DisplayServer.clipboard_set(last_zip)
	status.text = "Saved:  %s\n(path copied) Drag that file into the chat with Claude, or hit Send." % last_zip
	open_btn.visible = true
	save_btn.disabled = true

# ---------------------------------------------------------------- straight to Claude, through GitHub
## Uploads into reports/<time>/ of a private repo: the zip, plus notes and state as plain files you can read on
## GitHub. Needs a fine-grained token that can only write to that one repo, pasted in once.
func _cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(TOKEN_FILE)
	return c

func _send() -> void:
	var c := _cfg()
	var tok: String = token_box.text.strip_edges() if token_box.text.strip_edges() != "" else str(c.get_value("github", "token", ""))
	if tok == "":
		token_row.visible = true
		status.text = "Paste your GitHub token once (it's saved on this PC only), then hit Send again."
		token_box.grab_focus()
		return
	if token_box.text.strip_edges() != "":
		c.set_value("github", "token", tok)
		c.save(TOKEN_FILE)
		token_box.text = ""
		token_row.visible = false
	if last_zip == "":
		_save()
		if last_zip == "":
			return
	var repo: String = str(c.get_value("github", "repo", DEFAULT_REPO))
	var base := "reports/%s" % last_stamp
	var report := "# %s\n\n%s  ·  v%s\n\n%s\n" % [kind_opt.get_item_text(kind_opt.selected), state.get("time", ""), state.get("version", "?"), notes.text]
	_uploads = [
		[base + "/notes.md", report.to_utf8_buffer()],
		[base + "/state.json", JSON.stringify(state, "  ").to_utf8_buffer()],
		[base + "/screenshot.png", shot.save_png_to_buffer()],
		[base + "/report.zip", FileAccess.get_file_as_bytes(last_zip)],
	]
	send_btn.disabled = true
	status.text = "Sending…"
	_next_upload(tok, repo)

func _next_upload(tok: String, repo: String) -> void:
	if _uploads.is_empty():
		status.text = "Sent. Tell Claude \"check the bug reports\" (it's in %s, folder reports/%s)." % [repo, last_stamp]
		return
	var u: Array = _uploads.pop_front()
	var body := JSON.stringify({"message": "Bug report %s: %s" % [last_stamp, kind_opt.get_item_text(kind_opt.selected)], "content": Marshalls.raw_to_base64(u[1])})
	var headers := ["Authorization: Bearer " + tok, "Accept: application/vnd.github+json", "User-Agent: Wasteland-bug-report", "X-GitHub-Api-Version: 2022-11-28", "Content-Type: application/json"]
	if http == null:
		http = HTTPRequest.new()
		http.process_mode = Node.PROCESS_MODE_ALWAYS
		http.timeout = 60.0
		add_child(http)
	for cn in http.request_completed.get_connections():
		http.request_completed.disconnect(cn.callable)
	http.request_completed.connect(func(result, code, _h, resp_body):
		if result != HTTPRequest.RESULT_SUCCESS or code >= 300:
			var msg := ""
			if code == 401: msg = "the token was refused (expired or mistyped). Paste a new one."
			elif code == 404: msg = "can't see the repo %s. Check it exists and the token is allowed to write to it." % repo
			elif code == 403: msg = "the token doesn't have permission to write files (Contents: Read and write)."
			else: msg = "error %d / %d %s" % [result, code, resp_body.get_string_from_utf8().substr(0, 160)]
			status.text = "Couldn't send: " + msg + "\nThe report's still saved on your PC."
			send_btn.disabled = false
			if code == 401:
				var c2 := _cfg(); c2.set_value("github", "token", ""); c2.save(TOKEN_FILE)
				token_row.visible = true
			return
		_next_upload(tok, repo), CONNECT_ONE_SHOT)
	var err := http.request("https://api.github.com/repos/%s/contents/%s" % [repo, u[0]], headers, HTTPClient.METHOD_PUT, body)
	if err != OK:
		status.text = "Couldn't start the upload (%d). The report's still saved on your PC." % err
		send_btn.disabled = false

# ---------------------------------------------------------------- the form
func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.065, 0.06, 0.96)
	sb.border_color = Color(0.85, 0.45, 0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var t := Label.new()
	t.text = "BUG REPORT  (F9)"
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color(0.95, 0.55, 0.2))
	v.add_child(t)
	thumb = TextureRect.new()
	thumb.custom_minimum_size = Vector2(528, 297)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(thumb)
	var h := HBoxContainer.new()
	v.add_child(h)
	var kl := Label.new()
	kl.text = "What sort:"
	h.add_child(kl)
	kind_opt = OptionButton.new()
	for k in ["Bug", "Looks wrong", "Driving / physics", "Zombies / scavs", "Guns", "Forge / Garage", "Performance", "Idea"]:
		kind_opt.add_item(k)
	kind_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(kind_opt)
	notes = TextEdit.new()
	notes.custom_minimum_size = Vector2(528, 140)
	notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	notes.placeholder_text = "Type here…"
	v.add_child(notes)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(528, 0)
	status.modulate = Color(1, 1, 1, 0.75)
	v.add_child(status)
	var b := HBoxContainer.new()
	b.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(b)
	token_row = HBoxContainer.new()
	token_row.visible = false
	v.add_child(token_row)
	var tl := Label.new()
	tl.text = "GitHub token:"
	token_row.add_child(tl)
	token_box = LineEdit.new()
	token_box.secret = true
	token_box.placeholder_text = "github_pat_…"
	token_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	token_row.add_child(token_box)
	open_btn = Button.new()
	open_btn.text = "Show the file"
	open_btn.pressed.connect(func(): OS.shell_show_in_file_manager(last_zip))
	b.add_child(open_btn)
	save_btn = Button.new()
	save_btn.text = "Save report"
	save_btn.pressed.connect(_save)
	b.add_child(save_btn)
	send_btn = Button.new()
	send_btn.text = "Send to Claude"
	send_btn.pressed.connect(_send)
	b.add_child(send_btn)
	var close := Button.new()
	close.text = "Back to the game"
	close.pressed.connect(_close)
	b.add_child(close)
