class_name Outfit
extends RefCounted
## 0.2.75: clothes on the bodies. Every character's skinned mesh is remade once per model ("the shell"): the head and
## hands stay as they were painted, the rest is drawn by shaders/outfit.gdshader, which puts on it whatever that
## person's wearing (any top, bottoms and footwear, any colours, dirt and blood) from per-instance values. Same
## skeleton, same skin weights: it moves exactly with the body, never clips, costs no more to draw than the body did,
## and changing clothes is just changing those values.
## A look: {"top": item id or "", "top_c": [Color, Color], "bottom": .., "bottom_c": [..], "feet": .., "feet_c": [..],
##          "skin": Color, "wear": 0..1, "blood": 0..1, "height": 1.0, "width": 1.0}

const TOPS := {"": 0, "tee": 1, "singlet": 2, "flanno": 3, "workshirt": 4, "hivis": 5, "hoodie": 6, "jacket": 7}
const BOTTOMS := {"": 0, "jeans": 1, "shorts": 2, "cargo": 3, "trackies": 4}
const FEET := {"": 0, "workboots": 1, "gumboots": 2, "runners": 3, "thongs": 4}

## What each clothing item looks like on: its kind, how long its sleeves / legs are, where a shirt hangs to, and the
## colours a found one can come in (sRGB)
const LOOKS := {
	"shirt_flanno": {"slot": "top", "kind": "flanno", "sleeve": 1.0, "bottom": 0.05, "pal": [
		[Color("8e1b1b"), Color("16161a")], [Color("23407a"), Color("121624")], [Color("2f5a33"), Color("16241a")],
		[Color("9a7a2a"), Color("2a2418")], [Color("6e6e70"), Color("26262a")], [Color("b03a22"), Color("e0d2b0")]]},
	"shirt_work": {"slot": "top", "kind": "hivis", "sleeve": 1.0, "bottom": 0.06, "pal": [
		[Color("e8f000"), Color("1a2440")], [Color("ff7a00"), Color("1a2440")], [Color("e8f000"), Color("e8f000")]]},
	"shirt_drill": {"slot": "top", "kind": "workshirt", "sleeve": 1.0, "bottom": 0.07, "pal": [
		[Color("1e2a4a"), Color("1e2a4a")], [Color("8a7a55"), Color("8a7a55")], [Color("5d6a4a"), Color("5d6a4a")]]},
	"shirt_tee": {"slot": "top", "kind": "tee", "sleeve": 0.42, "bottom": 0.09, "pal": [
		[Color("e8e6e0"), Color("e8e6e0")], [Color("1a1a1c"), Color("1a1a1c")], [Color("3a4a6a"), Color("3a4a6a")],
		[Color("7a2a2a"), Color("7a2a2a")], [Color("6a7a5a"), Color("6a7a5a")], [Color("9a9a9c"), Color("9a9a9c")], [Color("c07a30"), Color("c07a30")]]},
	"shirt_singlet": {"slot": "top", "kind": "singlet", "sleeve": 0.0, "bottom": 0.12, "pal": [
		[Color("ecebe6"), Color("ecebe6")], [Color("1f2a44"), Color("1f2a44")], [Color("1a1a1c"), Color("1a1a1c")]]},
	"hoodie": {"slot": "top", "kind": "hoodie", "sleeve": 1.0, "bottom": 0.02, "pal": [
		[Color("5a5a5e"), Color("5a5a5e")], [Color("1a1a1e"), Color("1a1a1e")], [Color("1e2a4a"), Color("1e2a4a")], [Color("5a2a2a"), Color("5a2a2a")]]},
	"jacket_army": {"slot": "top", "kind": "jacket", "sleeve": 1.0, "bottom": -0.02, "pal": [
		[Color("4e5236"), Color("4e5236")], [Color("5c5640"), Color("5c5640")]]},
	"pants_jeans": {"slot": "bottom", "kind": "jeans", "leg": 1.0, "pal": [
		[Color("2c3e66"), Color("2c3e66")], [Color("4a5f8a"), Color("4a5f8a")], [Color("1c1c22"), Color("1c1c22")], [Color("6a7fa6"), Color("6a7fa6")]]},
	"pants_cargo": {"slot": "bottom", "kind": "cargo", "leg": 1.0, "pal": [
		[Color("7a6c4c"), Color("7a6c4c")], [Color("4a4e38"), Color("4a4e38")], [Color("26262a"), Color("26262a")], [Color("1e2a44"), Color("1e2a44")]]},
	"shorts_stubbies": {"slot": "bottom", "kind": "shorts", "leg": 0.36, "pal": [
		[Color("1e2a4a"), Color("1e2a4a")], [Color("8a7a55"), Color("8a7a55")], [Color("1a1a1c"), Color("1a1a1c")], [Color("4a5a3a"), Color("4a5a3a")]]},
	"pants_trackies": {"slot": "bottom", "kind": "trackies", "leg": 1.0, "pal": [
		[Color("6a6a6e"), Color("6a6a6e")], [Color("1e2440"), Color("1e2440")], [Color("1a1a1c"), Color("1a1a1c")]]},
	"boots_work": {"slot": "feet", "kind": "workboots", "pal": [[Color("8a5a2a"), Color("8a5a2a")], [Color("4a2e1a"), Color("4a2e1a")], [Color("1c1a18"), Color("1c1a18")]]},
	"boots_rubber": {"slot": "feet", "kind": "gumboots", "pal": [[Color("141414"), Color("141414")], [Color("2a3a22"), Color("2a3a22")]]},
	"shoes_runners": {"slot": "feet", "kind": "runners", "pal": [[Color("dcdcd8"), Color("dcdcd8")], [Color("3a3a40"), Color("3a3a40")], [Color("1e2a4a"), Color("1e2a4a")]]},
	"thongs": {"slot": "feet", "kind": "thongs", "pal": [[Color("1a1a1c"), Color("1a1a1c")], [Color("2a4a8a"), Color("2a4a8a")], [Color("c03030"), Color("c03030")]]},
}
const FEMALE := ["survivor_female", "zombie_female"]
## raiders keep their painted gear (Mad Max kit), and the hooded scav his pack and hood (they're part of his body);
## everyone else gets dressed
const UNDRESSED := ["warboy", "warboy_enforcer", "warbringer", "scav_hooded"]

static var _shells := {}         # model path | mesh node path -> ArrayMesh
static var _skins := {}          # model path -> Color (the painted hands' tone)
static var _shader: Shader

# ---------------------------------------------------------------- looks
static func slot_of(id: String) -> String:
	return str(LOOKS[id].slot) if LOOKS.has(id) else ""

## a stack's colours: the variant it was found in
static func colours(s: Dictionary) -> Array:
	var id := str(s.id)
	if not LOOKS.has(id): return [Color.GRAY, Color.GRAY]
	var pal: Array = LOOKS[id].pal
	return pal[int(s.get("data", {}).get("v", 0)) % pal.size()]

## What the player (or anyone carrying an inventory) has on, from their equipped stacks
static func look_from_equip(equip: Dictionary, base: Dictionary) -> Dictionary:
	var lk := base.duplicate()
	for sl in ["top", "bottom", "feet"]:
		var s = equip.get(sl)
		lk[sl] = str(s.id) if s and (LOOKS.has(str(s.id)) or MH_ITEMS.has(str(s.id))) else ""
		lk[sl + "_c"] = colours(s) if s and LOOKS.has(str(s.id)) else [Color.GRAY, Color.GRAY]
		lk[sl + "_v"] = int(s.data.get("v", 0)) if s else 0
	var hs = equip.get("head")
	lk["head"] = str(hs.id) if hs and MH_ITEMS.has(str(hs.id)) else ""
	return lk

## Somebody off the street: everyday clothes, the way people round here dress. A zombie's are filthy and bloody.
static func random_look(rng: RandomNumberGenerator, female: bool, zombie: bool) -> Dictionary:
	var tops := [["shirt_tee", 5.0], ["shirt_flanno", 3.0], ["shirt_singlet", 1.5 if not female else 0.8], ["shirt_work", 2.0], ["shirt_drill", 1.5], ["hoodie", 1.5], ["jacket_army", 0.4]]
	var bots := [["pants_jeans", 4.0], ["shorts_stubbies", 3.0], ["pants_cargo", 1.5], ["pants_trackies", 1.5]]
	var feet := [["boots_work", 3.0], ["shoes_runners", 3.0], ["thongs", 2.0], ["boots_rubber", 1.0], ["shoes_leather", 1.0], ["", 0.4]]
	if rng.randf() < 0.05: bots = [["overalls", 1.0]]
	var lk := {}
	for pr in [["top", tops], ["bottom", bots], ["feet", feet]]:
		var id := _pick_w(rng, pr[1])
		lk[pr[0]] = id
		var v := rng.randi() % 7
		lk[pr[0] + "_v"] = v
		lk[pr[0] + "_c"] = (LOOKS[id].pal as Array)[v % (LOOKS[id].pal as Array).size()] if LOOKS.has(id) else [Color.GRAY, Color.GRAY]
	if rng.randf() < 0.08 and not female:
		lk["head"] = "hat_fedora"
	lk["wear"] = rng.randf_range(0.55, 0.95) if zombie else rng.randf_range(0.1, 0.45)
	lk["blood"] = rng.randf_range(0.35, 0.9) if zombie else 0.0
	lk["zombie"] = zombie
	lk["height"] = rng.randf_range(0.93, 1.06) if not female else rng.randf_range(0.9, 1.0)
	lk["width"] = rng.randf_range(0.94, 1.12)
	return lk

static func _pick_w(rng: RandomNumberGenerator, opts: Array) -> String:
	var tot := 0.0
	for o in opts: tot += float(o[1])
	var r := rng.randf() * tot
	for o in opts:
		r -= float(o[1])
		if r <= 0.0: return str(o[0])
	return str(opts[0][0])

## The clothes a look stands for, as inventory stacks (what you find on the body)
static func worn_stacks(lk: Dictionary, rng: RandomNumberGenerator) -> Array:
	var out := []
	for sl in ["top", "bottom", "feet", "head"]:
		var id := str(lk.get(sl, ""))
		if id == "" or Items.def(id).is_empty(): continue
		var s := Items.fresh(id)
		s.data["v"] = int(lk.get(sl + "_v", 0))
		if rng.randf() < 0.85: out.append(s)        # now and then it's too torn up to be worth taking
	return out

## Build the shells of these bodies now (at load), so the first of each to walk in doesn't hitch
static func warm(keys: Array) -> void:
	for k in keys:
		if is_mh(k) or not dresses(k) or not ResourceLoader.exists(Rig.path_of(k)): continue
		var n: Node3D = (load(Rig.path_of(k)) as PackedScene).instantiate()
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.skin == null: continue
			var sk := m.get_node_or_null(m.skeleton) as Skeleton3D
			if sk: _shell(m, sk, Rig.path_of(k), k)
		n.free()

# ---------------------------------------------------------------- putting it on
# ---------------------------------------------------------------- the MakeHuman people (0.2.75)
## Generated with MakeHuman's own add-on (tools/mh/gen_people.py): each person has every garment fitted to their own
## body as a mesh of its own on the same skeleton. Wearing one shows it; the body's skin under it drops away.
## Clothing item -> the garments it can be (by its colour variant), per sex, and which take a dye (white tees)
const MH_PEOPLE := {"mh_m_young": "Young bloke", "mh_m_mid": "Middle-aged bloke", "mh_m_old": "Old fella", "mh_m_lean": "Lean bloke",
	"mh_m_african": "Bloke (African)", "mh_m_asian": "Bloke (Asian)", "mh_f_young": "Young woman", "mh_f_mid": "Middle-aged woman",
	"mh_f_african": "Woman (African)", "mh_f_asian": "Woman (Asian)", "mh_f_old": "Old woman"}
const MH_ITEMS := {
	"shirt_flanno": {"m": ["mh_checkshirt"], "f": ["mh_checkshirt"]},
	"shirt_tee": {"m": ["mh_tee_white", "mh_tee_white", "mh_tee_blue", "mh_tee_white", "mh_tee_white", "mh_tee_white", "mh_tee_white"],
		"f": ["mh_tee_fitted", "mh_tee_loose"], "dye": true},
	"shirt_singlet": {"m": ["mh_tee_white"], "f": ["mh_croptop"], "dye": true},
	"shirt_drill": {"m": ["mh_denimshirt"], "f": ["mh_denimshirt"]},
	"shirt_work": {"m": ["mh_tee_white"], "f": ["mh_tee_fitted"], "dye": true},
	"hoodie": {"m": ["mh_longtee"], "f": ["mh_longtee"]},
	"jacket_army": {"m": ["mh_jacket"], "f": ["mh_jacket"]},
	"pants_jeans": {"m": ["mh_jeans_a", "mh_jeans_b", "mh_jeans_c", "mh_jeans_b"], "f": ["mh_jeans_slim", "mh_jeans_b"]},
	"pants_cargo": {"m": ["mh_jeans_c"], "f": ["mh_jeans_c"], "dye": true},
	"shorts_stubbies": {"m": ["mh_denimshorts"], "f": ["mh_denimshorts"]},
	"pants_trackies": {"m": ["mh_leggings"], "f": ["mh_leggings"]},
	"overalls": {"m": ["mh_overalls"], "f": ["mh_overalls"], "covers_top": true},
	"boots_work": {"m": ["mh_boots"], "f": ["mh_boots"]},
	"boots_rubber": {"m": ["mh_boots"], "f": ["mh_boots"]},
	"shoes_runners": {"m": ["mh_runners_white", "mh_runners_blue", "mh_runners_camo"], "f": ["mh_runners_white", "mh_runners_blue", "mh_runners_camo"]},
	"shoes_leather": {"m": ["mh_shoes_brown", "mh_shoes_black"], "f": ["mh_shoes_brown", "mh_shoes_black"]},
	"thongs": {"m": [], "f": []},
	"hat_fedora": {"m": ["mh_hat"], "f": ["mh_hat"]},
}
static var _mh_bits := {}
static var _mh_mat_cache := {}
static var _mh_shader: Shader

static func is_mh(key: String) -> bool:
	return key.begins_with("mh_")

static func _bits() -> Dictionary:
	if _mh_bits.is_empty():
		var f := FileAccess.open("res://assets/characters/mh/people/people_index.json", FileAccess.READ)
		if f:
			var j = JSON.parse_string(f.get_as_text())
			for k in j: _mh_bits = j[k].garments; break
	return _mh_bits

## Which garment meshes a look puts on this person, with their dye (Color.WHITE = none)
static func mh_garments(lk: Dictionary, female: bool) -> Dictionary:
	var out := {}
	var covers_top := false
	for sl in ["bottom", "top", "feet", "head"]:
		var id := str(lk.get(sl, ""))
		if id == "" or not MH_ITEMS.has(id): continue
		var d: Dictionary = MH_ITEMS[id]
		var opts: Array = d["f" if female else "m"]
		if opts.is_empty(): continue
		if sl == "top" and covers_top: continue
		var v := int(lk.get(sl + "_v", 0))
		var g: String = opts[v % opts.size()]
		var dye := Color.WHITE
		if d.get("dye", false) and LOOKS.has(id):
			dye = (lk.get(sl + "_c", [Color.WHITE]) as Array)[0]
		out[g] = dye
		if d.get("covers_top", false): covers_top = true
	return out

static func dress_mh(model: Node3D, key: String, lk: Dictionary) -> void:
	if _mh_shader == null: _mh_shader = load("res://shaders/mh_cloth.gdshader")
	var wear := _mh_garments_cached(lk, is_female(key))
	var bits := _bits()
	var mask := 0
	for g in wear:
		if bits.has(g): mask |= 1 << int(bits[g])
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var nm := str(m.name)
		if nm == "mh_shadow": continue
		var body := nm == key
		var garment := nm.begins_with("mh_") and not nm.begins_with(key)
		if not body and not garment:
			# hair, eyes, brows, lashes: as they are; the small bits only drawn up close, and no shadows off them
			if not nm.ends_with("_hair") and not m.get_meta("mh_small", false):
				m.set_meta("mh_small", true)
				if not (nm.contains("short") or nm.contains("long") or nm.contains("bob") or nm.contains("afro") or nm.contains("ponytail") or nm.contains("braid")):
					m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					m.visibility_range_end = 14.0
			continue
		if garment:
			m.visible = wear.has(nm)
			if not m.visible: continue
		_mh_materials(m, body)
		m.set_instance_shader_parameter("worn", mask if body else 0)
		m.set_instance_shader_parameter("mul", wear.get(nm, Color.WHITE) if garment else Color.WHITE)
		m.set_instance_shader_parameter("tint", (lk.get("tint", Color.WHITE) as Color))
		m.set_instance_shader_parameter("wear", float(lk.get("wear", 0.15)))
		m.set_instance_shader_parameter("blood", float(lk.get("blood", 0.0)))
		m.set_instance_shader_parameter("pale", 0.8 if body and lk.get("zombie", false) else 0.0)
	_mh_shadow(model, key)

## One shadow for the lot: the bare body, drawn into the shadow maps only, on a plain material. Everything else (the
## body on its cloth shader, hair, eyes, each garment) casts none, so a person costs one draw per shadow cascade
## instead of eight or nine (0.2.75 measured ~60 draw calls a person in the world before this)
static var _shadow_mat: StandardMaterial3D
static func _mh_shadow(model: Node3D, key: String) -> void:
	var body: MeshInstance3D = null
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if str(m.name) == key: body = m
		if str(m.name) != "mh_shadow": m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if body == null or body.get_parent().has_node("mh_shadow"): return
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sh := MeshInstance3D.new()
	sh.name = "mh_shadow"
	sh.set_meta("mh_mat", true)          # (Rig.tint leaves it be)
	sh.mesh = body.mesh
	sh.skin = body.skin
	sh.material_override = _shadow_mat
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	sh.transform = body.transform
	sh.layers = body.layers
	body.get_parent().add_child(sh)
	sh.skeleton = sh.get_path_to(body.get_node(body.skeleton))

static func _mh_garments_cached(lk: Dictionary, female: bool) -> Dictionary:
	return mh_garments(lk, female)

## the body's and the garments' own materials, remade on the cloth shader (once each, shared)
static func _mh_materials(m: MeshInstance3D, body: bool) -> void:
	if m.get_meta("mh_mat", false): return
	m.set_meta("mh_mat", true)
	for si in m.mesh.get_surface_count():
		var src: Material = m.mesh.surface_get_material(si)
		if not _mh_mat_cache.has(src):
			var sm := ShaderMaterial.new()
			sm.shader = _mh_shader
			var bm := src as BaseMaterial3D
			if bm:
				if bm.albedo_texture: sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
				sm.set_shader_parameter("albedo", bm.albedo_color)
				if bm.normal_enabled and bm.normal_texture:
					sm.set_shader_parameter("normal_tex", bm.normal_texture)
					sm.set_shader_parameter("has_nrm", true)
				sm.set_shader_parameter("rough", clampf(bm.roughness, 0.45, 0.95))
			sm.set_shader_parameter("is_body", body)
			_mh_mat_cache[src] = sm
		m.set_surface_override_material(si, _mh_mat_cache[src])

static func is_female(key: String) -> bool:
	return key in FEMALE or key.begins_with("mh_f_")

static func dresses(key: String) -> bool:
	return not key in UNDRESSED

## Dress a model (a Rig's, or a gib's copy of it) in a look
static func dress(model: Node3D, model_path: String, key: String, lk: Dictionary) -> void:
	if is_mh(key):
		dress_mh(model, key, lk)
		return
	if not dresses(key): return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null: continue
		var sk := m.get_node_or_null(m.skeleton) as Skeleton3D
		if sk == null: continue
		var sh := _shell(m, sk, model_path, key)
		if sh == null: continue
		m.mesh = sh
		apply(m, lk, model_path)

## The look's values onto one mesh instance (cheap: call it whenever clothes change)
static func apply(m: MeshInstance3D, lk: Dictionary, model_path: String) -> void:
	var top := str(lk.get("top", ""))
	var bot := str(lk.get("bottom", ""))
	var ft := str(lk.get("feet", ""))
	var tl: Dictionary = LOOKS.get(top, {})
	var bl: Dictionary = LOOKS.get(bot, {})
	var fl: Dictionary = LOOKS.get(ft, {})
	var tc: Array = lk.get("top_c", [Color.GRAY, Color.GRAY])
	var bc: Array = lk.get("bottom_c", [Color.GRAY, Color.GRAY])
	var fc: Array = lk.get("feet_c", [Color.GRAY, Color.GRAY])
	m.set_instance_shader_parameter("top_kind", float(TOPS.get(str(tl.get("kind", "")), 0)))
	m.set_instance_shader_parameter("top_col", (tc[0] as Color))
	m.set_instance_shader_parameter("top_col2", (tc[1] as Color))
	m.set_instance_shader_parameter("sleeve", float(tl.get("sleeve", 0.0)))
	m.set_instance_shader_parameter("top_bottom", float(tl.get("bottom", 0.1)))
	m.set_instance_shader_parameter("bot_kind", float(BOTTOMS.get(str(bl.get("kind", "")), 0)))
	m.set_instance_shader_parameter("bot_col", (bc[0] as Color))
	m.set_instance_shader_parameter("leg_len", float(bl.get("leg", 0.0)))
	m.set_instance_shader_parameter("feet_kind", float(FEET.get(str(fl.get("kind", "")), 0)))
	m.set_instance_shader_parameter("feet_col", (fc[0] as Color))
	var skin: Color = lk.get("skin", _skins.get(model_path, Color(0.62, 0.45, 0.36)))
	m.set_instance_shader_parameter("skin_col", skin)
	m.set_instance_shader_parameter("wear", float(lk.get("wear", 0.2)))
	m.set_instance_shader_parameter("blood", float(lk.get("blood", 0.0)))
	m.set_instance_shader_parameter("tint", (lk.get("tint", Color.WHITE) as Color))
	m.set_instance_shader_parameter("keep_tone", float(lk.get("tone", 1.0)))

static func set_tint(model: Node3D, c: Color) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if (m.mesh and m.mesh.get_meta("outfit_shell", false)) or m.get_meta("mh_mat", false):
			m.set_instance_shader_parameter("tint", c)

## the painted skin tone of a model (its hands)
static func skin_of(model_path: String) -> Color:
	return _skins.get(model_path, Color(0.62, 0.45, 0.36))

# ---------------------------------------------------------------- the shell (built once per model and mesh)
enum G { TORSO, NECK, HEAD, ARM_L, ARM_R, HAND_L, HAND_R, LEG_L, LEG_R, FOOT_L, FOOT_R }

static func _groups(sk: Skeleton3D) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(sk.get_bone_count())
	var order := [["Head", G.HEAD], ["LeftHand", G.HAND_L], ["RightHand", G.HAND_R], ["LeftFoot", G.FOOT_L], ["RightFoot", G.FOOT_R],
		["LeftLowerLeg", G.LEG_L], ["RightLowerLeg", G.LEG_R], ["LeftUpperLeg", G.LEG_L], ["RightUpperLeg", G.LEG_R],
		["LeftLowerArm", G.ARM_L], ["RightLowerArm", G.ARM_R], ["LeftUpperArm", G.ARM_L], ["RightUpperArm", G.ARM_R],
		["LeftShoulder", G.TORSO], ["RightShoulder", G.TORSO], ["Neck", G.NECK]]
	for b in sk.get_bone_count():
		var g := int(G.TORSO)
		var c := b
		var found := false
		while c >= 0 and not found:
			var nm := sk.get_bone_name(c)
			for o in order:
				if nm == o[0]:
					g = int(o[1]); found = true
					break
			c = sk.get_bone_parent(c)
		out[b] = g
	return out

static func _shell(m: MeshInstance3D, sk: Skeleton3D, model_path: String, key: String) -> ArrayMesh:
	var ck := model_path + "|" + str(m.owner.get_path_to(m) if m.owner else m.name)
	if _shells.has(ck): return _shells[ck]
	var src: Mesh = m.mesh
	if src.has_meta("outfit_shell"):
		return src as ArrayMesh
	var skin: Skin = m.skin
	var groups := _groups(sk)
	var nb := skin.get_bind_count()
	var bxf: Array[Transform3D] = []
	var bgrp := PackedInt32Array()
	for i in nb:
		var b := skin.get_bind_bone(i)
		if b < 0: b = sk.find_bone(skin.get_bind_name(i))
		if b < 0:
			bxf.append(Transform3D()); bgrp.append(G.TORSO); continue
		bxf.append(sk.get_bone_global_rest(b) * skin.get_bind_pose(i))
		bgrp.append(groups[b])
	var gr := func(n: String) -> Vector3:
		var b := sk.find_bone(n)
		return sk.get_bone_global_rest(b).origin if b >= 0 else Vector3.ZERO
	var head: Vector3 = gr.call("Head")
	var foot_l: Vector3 = gr.call("LeftFoot")
	var foot_r: Vector3 = gr.call("RightFoot")
	var k := 1.52 / maxf(head.y - foot_l.y, 0.001)
	var ground := foot_l.y - 0.09 / k
	var hips: Vector3 = gr.call("Hips")
	var hip_l: Vector3 = gr.call("LeftUpperLeg")
	var hip_r: Vector3 = gr.call("RightUpperLeg")
	var hip_y := (hip_l.y + hip_r.y) * 0.5
	var neck_y: float = (gr.call("Neck") as Vector3).y
	var sh_l: Vector3 = gr.call("LeftUpperArm"); var wr_l: Vector3 = gr.call("LeftHand")
	var sh_r: Vector3 = gr.call("RightUpperArm"); var wr_r: Vector3 = gr.call("RightHand")
	var female := key in FEMALE
	var out := ArrayMesh.new()
	out.set_meta("outfit_shell", true)
	var hand_px: Array = []
	var mpu := 0.01
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var N: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var B: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var W: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var UVs = arr[Mesh.ARRAY_TEX_UV]
		var n := V.size()
		if n == 0 or B.size() < n * 4: continue
		var per := B.size() / n
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(n)
			for i in n: idx[i] = i
		var c0 := PackedFloat32Array(); c0.resize(n * 4)
		var c1 := PackedFloat32Array(); c1.resize(n * 4)
		var c2 := PackedFloat32Array(); c2.resize(n * 4)
		var keep := PackedByteArray(); keep.resize(n)
		var gw := PackedFloat32Array(); gw.resize(11)
		for i in n:
			var p := Vector3.ZERO
			var nn := Vector3.ZERO
			gw.fill(0.0)
			for j in per:
				var w: float = W[i * per + j]
				if w <= 0.0: continue
				var bi: int = B[i * per + j]
				if bi < 0 or bi >= nb: continue
				p += (bxf[bi] * V[i]) * w
				nn += (bxf[bi].basis * N[i]) * w
				gw[bgrp[bi]] += w
			var dom := 0
			for g in 11:
				if gw[g] > gw[dom]: dom = g
			var kept := gw[G.HEAD] + gw[G.HAND_L] + gw[G.HAND_R] > 0.5
			# auto-weighting gives hand bones bits of the thighs the hands hang beside: only what's really by the hand
			if kept and gw[G.HEAD] < gw[G.HAND_L] + gw[G.HAND_R]:
				var wr: Vector3 = wr_l if gw[G.HAND_L] >= gw[G.HAND_R] else wr_r
				if (p - wr).length() * k > 0.24: kept = false
			elif kept and (p - head).length() * k > 0.36:
				kept = false
			keep[i] = 1 if kept else 0
			if (dom == G.HAND_L or dom == G.HAND_R) and UVs != null and hand_px.size() < 400 and i % 5 == 0:
				hand_px.append((UVs as PackedVector2Array)[i])
			var arm_t := 0.0
			var leg_t := 0.0
			if dom in [G.ARM_L, G.HAND_L, G.ARM_R, G.HAND_R]:
				var a: Vector3 = sh_l if dom in [G.ARM_L, G.HAND_L] else sh_r
				var b2: Vector3 = wr_l if dom in [G.ARM_L, G.HAND_L] else wr_r
				var t := (p - a).dot(b2 - a) / maxf((b2 - a).length_squared(), 1e-6)
				arm_t = clampf(t, 0.001, 1.3) if t > 0.0 else 0.0
			elif dom in [G.LEG_L, G.FOOT_L, G.LEG_R, G.FOOT_R]:
				var a: Vector3 = hip_l if dom in [G.LEG_L, G.FOOT_L] else hip_r
				var b2: Vector3 = foot_l if dom in [G.LEG_L, G.FOOT_L] else foot_r
				var t := (p - a).dot(b2 - a) / maxf((b2 - a).length_squared(), 1e-6)
				if dom in [G.FOOT_L, G.FOOT_R]: t = maxf(t, 1.0)
				leg_t = clampf(t, 0.001, 1.3) if t > 0.0 else 0.0
			var h := (p.y - hip_y) / maxf(neck_y - hip_y, 1e-6)
			if dom == G.NECK or dom == G.HEAD: h = maxf(h, 1.0)
			c0[i * 4] = arm_t; c0[i * 4 + 1] = leg_t; c0[i * 4 + 2] = h; c0[i * 4 + 3] = 1.0 if female else 0.0
			c1[i * 4] = (p.x - hips.x) * k; c1[i * 4 + 1] = (p.y - ground) * k; c1[i * 4 + 2] = (p.z - hips.z) * k
			var nr := nn.normalized()
			c2[i * 4] = nr.x; c2[i * 4 + 1] = nr.y; c2[i * 4 + 2] = nr.z
			c2[i * 4 + 3] = 1.0 if kept else 0.0
		mpu = k          # skinned vertices are in the skeleton's space by the time the shader sees them
		# one surface for one: the head and hands are drawn from the painted texture by the same shader (keep = 1),
		# so a dressed body is no more draws than a bare one
		var mat: Material = src.surface_get_material(s)
		var fmt: int = src.surface_get_format(s)
		var a2 := arr.duplicate()
		for ci in [Mesh.ARRAY_CUSTOM3]:
			a2[ci] = null
		a2[Mesh.ARRAY_INDEX] = idx
		a2[Mesh.ARRAY_CUSTOM0] = c0
		a2[Mesh.ARRAY_CUSTOM1] = c1
		a2[Mesh.ARRAY_CUSTOM2] = c2
		var fl := _keep_flags(fmt) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2, [], {}, fl)
		out.surface_set_material(out.get_surface_count() - 1, _shell_mat(mat, mpu))
	if out.get_surface_count() == 0: return null
	# the painted skin tone: the hands' pixels
	if not _skins.has(model_path):
		_skins[model_path] = _avg_px(src.surface_get_material(0), hand_px)
	_shells[ck] = out
	return out

## keep the vertex compression and skinning flags of the source, nothing about custom channels
static func _keep_flags(fmt: int) -> int:
	var keep := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
	return fmt & keep

static func _shell_mat(src: Material, mpu: float) -> ShaderMaterial:
	if _shader == null: _shader = load("res://shaders/outfit.gdshader")
	var sm := ShaderMaterial.new()
	sm.shader = _shader
	var bm := src as BaseMaterial3D
	if bm and bm.albedo_texture:
		sm.set_shader_parameter("base_tex", bm.albedo_texture)
		sm.set_shader_parameter("base_lum", _tex_lum(bm.albedo_texture))
	if bm and bm.normal_enabled and bm.normal_texture:
		sm.set_shader_parameter("nrm_tex", bm.normal_texture)
		sm.set_shader_parameter("has_nrm", true)
	sm.set_shader_parameter("m_per_unit", mpu)
	if bm:
		sm.set_shader_parameter("base_col", bm.albedo_color)
	return sm

static var _lum_cache := {}
static func _small(tex: Texture2D) -> Image:
	var img := tex.get_image()
	if img == null: return null
	if img.is_compressed(): img.decompress()
	img = img.duplicate()
	img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	return img

static func _tex_lum(tex: Texture2D) -> float:
	if _lum_cache.has(tex): return _lum_cache[tex]
	var img := _small(tex)
	var tot := 0.0
	if img:
		for y in 64:
			for x in 64:
				var c := img.get_pixel(x, y)
				tot += c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var v := tot / 4096.0 if img else 0.4
	_lum_cache[tex] = v
	return v

static func _avg_px(mat: Material, uvs: Array) -> Color:
	var bm := mat as BaseMaterial3D
	if bm == null or bm.albedo_texture == null or uvs.is_empty(): return Color(0.62, 0.45, 0.36)
	var img := _small(bm.albedo_texture)
	if img == null: return Color(0.62, 0.45, 0.36)
	var acc := Color(0, 0, 0, 0)
	for uv in uvs:
		var u: Vector2 = uv
		var c := img.get_pixel(clampi(int(fposmod(u.x, 1.0) * 64), 0, 63), clampi(int(fposmod(u.y, 1.0) * 64), 0, 63))
		acc += c
	acc /= float(uvs.size())
	return Color(acc.r, acc.g, acc.b) * bm.albedo_color
