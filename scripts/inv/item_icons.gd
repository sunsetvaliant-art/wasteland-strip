class_name ItemIcons
extends RefCounted
## Inventory pictures, rendered from each item's model by tools/make_icons.gd into assets/icons/<id>.png
static var _cache := {}

static func get_icon(id: String) -> Texture2D:
	if not _cache.has(id):
		var p := "res://assets/icons/%s.png" % id
		_cache[id] = load(p) if ResourceLoader.exists(p) else null
	return _cache[id]
