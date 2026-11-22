class_name ItemIcons
extends RefCounted
## Inventory pictures, rendered from each item's model by tools/make_icons.gd into assets/icons/<id>.png
static var _cache := {}

static func get_icon(id: String) -> Texture2D:
	if not _cache.has(id):
		var p := "res://assets/icons/%s.png" % id
		if not ResourceLoader.exists(p) and str(EngineKit.item_def(id).get("part", "")) != "":
			return EngineView.icon(id)          # engine parts are built in code: drawn on the fly (0.2.57), put() fills the cache
		_cache[id] = load(p) if ResourceLoader.exists(p) else null
	return _cache[id]

static func put(id: String, tex: Texture2D) -> void:
	_cache[id] = tex
