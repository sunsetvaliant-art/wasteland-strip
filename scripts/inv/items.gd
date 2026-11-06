class_name Items
extends RefCounted
## Every item there is. Size is in grid cells (w x h, can be turned 90°), stack is how many fit in one cell group.
## kind: gun / ammo / med / food / clothing / pack / misc.  slot: which equipment slot it goes in.
## grid: the pockets or bag it brings with it (w, h) when worn.  model: what it looks like on the ground.

const DEFS := {
	# guns: rifles and long guns 3 x 1, handguns 2 x 1, never stack. data.ammo = rounds in it
	"gun_enfield": {"name": "Lee-Enfield .303", "w": 3, "h": 1, "stack": 1, "kind": "gun", "gun": "enfield", "slot": "primary"},
	"gun_slr": {"name": "L1A1 SLR", "w": 3, "h": 1, "stack": 1, "kind": "gun", "gun": "slr", "slot": "primary"},
	"gun_rem870": {"name": "Remington 870", "w": 3, "h": 1, "stack": 1, "kind": "gun", "gun": "rem870", "slot": "primary"},
	"gun_dbshotgun": {"name": "Side-by-side 12g", "w": 3, "h": 1, "stack": 1, "kind": "gun", "gun": "dbshotgun", "slot": "primary"},
	"gun_sawnoff": {"name": "Sawn-off 12g", "w": 2, "h": 1, "stack": 1, "kind": "gun", "gun": "sawnoff", "slot": "secondary"},
	"gun_python": {"name": "Colt Python .357", "w": 2, "h": 1, "stack": 1, "kind": "gun", "gun": "python", "slot": "secondary"},
	# rounds, loose: one cell holds a box's worth
	"ammo_303": {"name": ".303 rounds", "w": 1, "h": 1, "stack": 30, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_762": {"name": "7.62 NATO rounds", "w": 1, "h": 1, "stack": 40, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_357": {"name": ".357 Magnum rounds", "w": 1, "h": 1, "stack": 36, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_12g": {"name": "12 gauge shells", "w": 1, "h": 1, "stack": 20, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	# medical and food
	"bandage": {"name": "Bandage", "w": 1, "h": 1, "stack": 10, "kind": "med", "heal": 15.0, "use_time": 2.5},
	"medkit": {"name": "First aid kit", "w": 2, "h": 2, "stack": 1, "kind": "med", "heal": 60.0, "use_time": 6.0, "model": "res://assets/ph/survival/medical_box/medical_box.gltf"},
	"food_can": {"name": "Tinned food", "w": 1, "h": 1, "stack": 4, "kind": "food", "heal": 6.0, "use_time": 3.0, "model": "res://assets/ph/survival/russian_food_cans_01/russian_food_cans_01.gltf"},
	"long_life": {"name": "Ration pack", "w": 1, "h": 2, "stack": 2, "kind": "food", "heal": 12.0, "use_time": 4.0, "model": "res://assets/ph/survival/long_life_food/long_life_food.gltf"},
	"thermos": {"name": "Thermos of tea", "w": 1, "h": 2, "stack": 1, "kind": "food", "heal": 8.0, "use_time": 3.0, "model": "res://assets/ph/survival/modified_thermos/modified_thermos.gltf"},
	# clothes: 2 x 2, two to a stack; worn, their pockets join your inventory
	"shirt_flanno": {"name": "Flannelette shirt", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "top", "grid": [4, 2]},
	"shirt_work": {"name": "Hi-vis work shirt", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "top", "grid": [5, 2]},
	"jacket_army": {"name": "Army field jacket", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "top", "grid": [5, 3]},
	"pants_jeans": {"name": "Jeans", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "bottom", "grid": [3, 2]},
	"pants_cargo": {"name": "Cargo pants", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "bottom", "grid": [5, 2]},
	"boots_rubber": {"name": "Rubber boots", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "feet", "model": "res://assets/ph/survival/rubber_boots/rubber_boots.gltf"},
	"gas_mask": {"name": "Gas mask", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "head", "model": "res://assets/ph/survival/old_gas_mask/old_gas_mask.gltf"},
	# bags
	"pack_small": {"name": "Small backpack", "w": 3, "h": 3, "stack": 1, "kind": "pack", "slot": "back", "grid": [5, 10], "model": "res://assets/props/pack.glb"},
	"pack_large": {"name": "Army pack", "w": 4, "h": 4, "stack": 1, "kind": "pack", "slot": "back", "grid": [8, 10], "model": "res://assets/props/pack.glb"},
	# odds and ends
	"binoculars": {"name": "Binoculars", "w": 2, "h": 1, "stack": 1, "kind": "misc", "model": "res://assets/ph/survival/vintage_binocular/vintage_binocular.gltf"},
	"torch": {"name": "Torch", "w": 1, "h": 2, "stack": 1, "kind": "misc", "model": "res://assets/ph/survival/vintage_flashlight/vintage_flashlight.gltf"},
	"radio": {"name": "Two-way radio", "w": 1, "h": 2, "stack": 1, "kind": "misc", "model": "res://assets/ph/survival/vintage_radio_transceiver/vintage_radio_transceiver.gltf"},
	"wrench": {"name": "Shifter", "w": 2, "h": 1, "stack": 1, "kind": "misc", "model": "res://assets/ph/tools/adjustable_wrench/adjustable_wrench.gltf"},
	"jerry_fuel": {"name": "Jerry can (fuel)", "w": 2, "h": 3, "stack": 1, "kind": "misc", "model": "res://assets/ph/carparts/metal_jerrycan/metal_jerrycan.gltf"},
	"oil_can": {"name": "Engine oil", "w": 1, "h": 2, "stack": 2, "kind": "misc", "model": "res://assets/ph/carparts/small_oil_can_01/small_oil_can_01.gltf"},
}

const GUN_AMMO := {"enfield": "ammo_303", "slr": "ammo_762", "python": "ammo_357", "sawnoff": "ammo_12g", "dbshotgun": "ammo_12g", "rem870": "ammo_12g"}
const KIND_COL := {"gun": Color(0.32, 0.3, 0.26), "ammo": Color(0.55, 0.45, 0.18), "med": Color(0.6, 0.18, 0.16), "food": Color(0.35, 0.45, 0.2),
	"clothing": Color(0.22, 0.32, 0.45), "pack": Color(0.3, 0.36, 0.22), "misc": Color(0.36, 0.33, 0.3)}

# what's in each kind of container prop (keys are Forge prop keys); [item, chance, min, max]
const LOOT := {
	"ammo": [["ammo_303", 0.6, 10, 30], ["ammo_762", 0.5, 10, 40], ["ammo_357", 0.5, 6, 36], ["ammo_12g", 0.6, 6, 20], ["ammo_12g", 0.3, 4, 12]],
	"medical": [["bandage", 0.95, 2, 8], ["bandage", 0.4, 1, 5], ["medkit", 0.35, 1, 1]],
	"food": [["food_can", 0.8, 1, 4], ["long_life", 0.5, 1, 2], ["thermos", 0.25, 1, 1]],
	"tools": [["wrench", 0.6, 1, 1], ["oil_can", 0.5, 1, 2], ["torch", 0.3, 1, 1], ["radio", 0.15, 1, 1]],
	"crate": [["food_can", 0.5, 1, 4], ["bandage", 0.4, 1, 4], ["ammo_12g", 0.3, 4, 12], ["ammo_303", 0.25, 5, 20], ["shirt_flanno", 0.2, 1, 1],
		["pants_cargo", 0.15, 1, 1], ["jacket_army", 0.08, 1, 1], ["pack_small", 0.1, 1, 1], ["binoculars", 0.08, 1, 1], ["torch", 0.15, 1, 1]],
	"military": [["ammo_762", 0.7, 15, 40], ["ammo_303", 0.5, 10, 30], ["gun_slr", 0.12, 1, 1], ["gun_enfield", 0.12, 1, 1], ["jacket_army", 0.3, 1, 1],
		["pack_large", 0.12, 1, 1], ["medkit", 0.25, 1, 1], ["long_life", 0.5, 1, 2], ["gas_mask", 0.2, 1, 1]],
	"fuel": [["jerry_fuel", 0.9, 1, 1]],
}
# which Forge props are containers, the loot table, and the grid size inside
const CONTAINERS := {
	"ammo": ["ammo", [4, 3]], "ammo_box": ["ammo", [4, 3]],
	"medical_box": ["medical", [4, 3]],
	"crate": ["crate", [6, 4]], "wcrate": ["crate", [6, 4]], "mcrate": ["crate", [6, 5]], "wooden_crate_01": ["crate", [6, 4]], "wooden_crate_02": ["crate", [6, 4]],
	"plastic_crate_01": ["crate", [5, 3]], "cardboard_box_01": ["food", [4, 3]],
	"old_military_crate": ["military", [8, 4]], "wooden_military_crate": ["military", [8, 4]],
	"toolbox": ["tools", [5, 3]], "htoolbox": ["tools", [4, 2]], "metal_toolbox": ["tools", [5, 3]], "metal_tool_chest": ["tools", [6, 5]], "tool_cart": ["tools", [6, 4]],
	"cabinet": ["crate", [5, 6]], "vintage_cabinet_01": ["food", [5, 5]], "steel_frame_shelves_01": ["crate", [8, 6]], "worn_metal_rack": ["crate", [8, 6]],
	"metal_trash_can": ["food", [4, 4]], "trashbag": ["food", [3, 3]], "pack": ["crate", [5, 6]],
	"jerry": ["fuel", [2, 3]], "metal_jerrycan": ["fuel", [2, 3]],
}
# small enough to pick up and carry (middle mouse) in survival, by Forge key prefix match or mass
const CARRY_MAX_KG := 45.0

static func def(id: String) -> Dictionary:
	return DEFS.get(id, {"name": id, "w": 1, "h": 1, "stack": 1, "kind": "misc"})

static func stack(id: String, n := 1, data := {}) -> Dictionary:
	return {"id": id, "n": n, "x": 0, "y": 0, "r": false, "data": data.duplicate(true)}

static func size_of(s: Dictionary) -> Vector2i:
	var d := def(s.id)
	return Vector2i(d.h, d.w) if s.get("r", false) else Vector2i(d.w, d.h)

## A new item as it'd come out of a box: guns partly loaded, clothes and bags empty
static func fresh(id: String, n := 1) -> Dictionary:
	var d := def(id)
	var s := stack(id, n)
	if d.kind == "gun":
		s.data["ammo"] = randi_range(0, int(Gun.DEFS[d.gun].mag))
	if d.has("grid"):
		s.data["grid"] = new_grid(d.grid[0], d.grid[1])
	return s

static func new_grid(w: int, h: int) -> Dictionary:
	return {"w": w, "h": h, "items": []}

static func roll_loot(table: String, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for e in LOOT.get(table, []):
		if rng.randf() < float(e[1]):
			out.append(fresh(e[0], rng.randi_range(int(e[2]), int(e[3]))))
	if out.is_empty() and LOOT.has(table):
		var e: Array = LOOT[table][0]
		out.append(fresh(e[0], rng.randi_range(int(e[2]), int(e[3]))))
	return out
