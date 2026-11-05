extends Control
## The first screen: checks GitHub Releases for patches you don't have, downloads them into the "patches"
## folder beside the game (with progress), loads them straight in, then Play. Offline? It just lets you play.
## A release counts as a patch when it carries a file named patch_####.pck. Its release notes show as "What's new".

const API := "https://api.github.com/repos/sunsetvaliant-art/wasteland-strip/releases?per_page=50"
const ACCENT := Color(0.94, 0.65, 0.23)

var status: Label
var bar: ProgressBar
var notes: RichTextLabel
var play: Button
var http: HTTPRequest
var queue: Array = []     # [{name, url, size, notes}]
var dir := ""
var current := {}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	dir = OS.get_executable_path().get_base_dir().path_join("patches")
	if OS.has_feature("editor") or not _writable(dir):
		dir = ProjectSettings.globalize_path("user://patches")
	DirAccess.make_dir_recursive_absolute(dir)
	_build_ui()
	http = HTTPRequest.new()
	http.timeout = 12.0
	http.max_redirects = 10
	add_child(http)
	if OS.get_environment("WASTELAND_NO_UPDATE") != "" or OS.has_feature("editor"):
		_ready_to_play("Updates skipped")
		return
	status.text = "Checking for updates…"
	http.request_completed.connect(_on_list, CONNECT_ONE_SHOT)
	var err := http.request(API, ["User-Agent: WastelandLauncher", "Accept: application/vnd.github+json"])
	if err != OK:
		_ready_to_play("Couldn't check for updates (offline?)")

func _writable(d: String) -> bool:
	DirAccess.make_dir_recursive_absolute(d)
	var f := FileAccess.open(d.path_join(".write_test"), FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(d.path_join(".write_test"))
	return true

func _on_list(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_ready_to_play("Couldn't reach the update server (code %d), playing what you have" % code)
		return
	var rel = JSON.parse_string(body.get_string_from_utf8())
	if typeof(rel) != TYPE_ARRAY:
		_ready_to_play("Update list unreadable, playing what you have")
		return
	var have := Array(DirAccess.get_files_at(dir))
	var news := ""
	for r in rel:
		if r.get("draft", false):
			continue
		for a in r.get("assets", []):
			var n: String = a.get("name", "")
			if n.begins_with("patch_") and n.ends_with(".pck"):
				if not have.has(n):
					queue.append({"name": n, "url": a.browser_download_url, "size": int(a.get("size", 0))})
				news += "[b]%s[/b]  [color=#999]%s[/color]\n%s\n\n" % [r.get("name", n), str(r.get("published_at", "")).left(10), str(r.get("body", ""))]
	notes.text = news if news != "" else "No patch notes yet."
	queue.sort_custom(func(a, b): return a.name < b.name)
	_next()

func _next() -> void:
	if queue.is_empty():
		_ready_to_play("Up to date  ·  v%s" % _version())
		return
	current = queue.pop_front()
	status.text = "Downloading %s (%.1f MB)…" % [current.name, current.size / 1048576.0]
	http.download_file = dir.path_join(current.name + ".part")
	http.request_completed.connect(_on_file, CONNECT_ONE_SHOT)
	http.request(current.url, ["User-Agent: WastelandLauncher"])

func _on_file(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	http.download_file = ""
	var part: String = dir.path_join(current.name + ".part")
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(part)
		_ready_to_play("Download of %s failed (code %d), try again later" % [current.name, code])
		return
	DirAccess.rename_absolute(part, dir.path_join(current.name))
	if ProjectSettings.load_resource_pack(dir.path_join(current.name), true):
		Boot.patches_loaded.append(current.name)
		if FileAccess.file_exists("res://version.txt"):
			Boot.version = FileAccess.get_file_as_string("res://version.txt").strip_edges()
	_next()

func _process(_dt: float) -> void:
	if not current.is_empty() and http.get_body_size() > 0:
		bar.value = 100.0 * http.get_downloaded_bytes() / max(1, http.get_body_size())

func _version() -> String:
	return Boot.version

func _ready_to_play(msg: String) -> void:
	current = {}
	status.text = msg
	bar.value = 100
	play.disabled = false
	play.grab_focus()
	if OS.get_environment("WASTELAND_AUTOPLAY") != "":
		_play()

func _play() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if not play.disabled and e is InputEventKey and e.pressed and e.keycode in [KEY_ENTER, KEY_SPACE]:
		_play()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.custom_minimum_size = Vector2(900, 640)
	v.position = -v.custom_minimum_size * 0.5
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var t := Label.new()
	t.text = "WASTELAND"
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", ACCENT)
	v.add_child(t)
	var sub := Label.new()
	sub.text = "The Tweed, a few decades after   ·   v%s" % _version()
	sub.modulate = Color(1, 1, 1, 0.6)
	v.add_child(sub)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 20)
	v.add_child(status)
	bar = ProgressBar.new()
	bar.custom_minimum_size.y = 14
	bar.show_percentage = false
	v.add_child(bar)
	var wn := Label.new()
	wn.text = "What's new"
	wn.add_theme_color_override("font_color", ACCENT)
	v.add_child(wn)
	notes = RichTextLabel.new()
	notes.bbcode_enabled = true
	notes.custom_minimum_size.y = 300
	notes.add_theme_font_size_override("normal_font_size", 16)
	v.add_child(notes)
	play = Button.new()
	play.text = "PLAY"
	play.disabled = true
	play.custom_minimum_size = Vector2(260, 56)
	play.add_theme_font_size_override("font_size", 26)
	play.pressed.connect(_play)
	v.add_child(play)
