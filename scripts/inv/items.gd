class_name Items
extends RefCounted
## Every item there is. Size is in grid cells (w x h, can be turned 90°), stack is how many fit in one cell group.
## kind: gun / ammo / med / food / clothing / pack / misc.  slot: which equipment slot it goes in.
## grid: the pockets or bag it brings with it (w, h) when worn.  model: what it looks like on the ground.

const DEFS := {
	# guns: as long as they really are (about 29 cm a cell), one high, never stack. data.ammo = rounds in it
	"gun_enfield": {"name": "Lee-Enfield .303", "w": 5, "h": 1, "stack": 1, "kind": "gun", "gun": "enfield", "slot": "primary"},
	"gun_slr": {"name": "L1A1 SLR", "w": 4, "h": 1, "stack": 1, "kind": "gun", "gun": "slr", "slot": "primary"},
	"gun_rem870": {"name": "Remington 870", "w": 3, "h": 1, "stack": 1, "kind": "gun", "gun": "rem870", "slot": "primary"},
	"gun_dbshotgun": {"name": "Side-by-side 12g", "w": 4, "h": 1, "stack": 1, "kind": "gun", "gun": "dbshotgun", "slot": "primary"},
	"gun_sawnoff": {"name": "Sawn-off 12g", "w": 2, "h": 1, "stack": 1, "kind": "gun", "gun": "sawnoff", "slot": "secondary"},
	"gun_hunter": {"name": "Scoped .308 rifle", "w": 4, "h": 1, "stack": 1, "kind": "gun", "gun": "hunter", "slot": "primary"},
	"gun_magnum45": {"name": ".45 Magnum", "w": 2, "h": 1, "stack": 1, "kind": "gun", "gun": "magnum45", "slot": "secondary"},
	"gun_python": {"name": "Colt Python .357", "w": 2, "h": 1, "stack": 1, "kind": "gun", "gun": "python", "slot": "secondary"},
	# rounds, loose: one cell holds a box's worth
	"ammo_303": {"name": ".303 rounds", "w": 1, "h": 1, "stack": 30, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_762": {"name": "7.62 NATO rounds", "w": 1, "h": 1, "stack": 40, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_357": {"name": ".357 Magnum rounds", "w": 1, "h": 1, "stack": 36, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_45": {"name": ".45 rounds", "w": 1, "h": 1, "stack": 36, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_12g": {"name": "12 gauge shells", "w": 1, "h": 1, "stack": 20, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	# medical and food
	"bandage": {"name": "Bandage", "w": 1, "h": 1, "stack": 10, "kind": "med", "heal": 15.0, "use_time": 2.5},
	"medkit": {"name": "First aid kit", "w": 2, "h": 2, "stack": 1, "kind": "med", "heal": 60.0, "use_time": 6.0, "model": "res://assets/ph/survival/medical_box/medical_box.gltf"},
	"food_can": {"name": "Tinned food", "w": 1, "h": 1, "stack": 4, "kind": "food", "heal": 6.0, "eat": 35.0, "drink": 5.0, "use_time": 3.0, "model": "res://assets/ph/survival/russian_food_cans_01/russian_food_cans_01.gltf"},
	"long_life": {"name": "Ration pack", "w": 1, "h": 2, "stack": 2, "kind": "food", "heal": 12.0, "eat": 60.0, "use_time": 4.0, "model": "res://assets/ph/survival/long_life_food/long_life_food.gltf"},
	"thermos": {"name": "Thermos of tea", "w": 1, "h": 2, "stack": 1, "kind": "food", "heal": 8.0, "drink": 55.0, "use_time": 3.0, "model": "res://assets/ph/survival/modified_thermos/modified_thermos.gltf"},
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
	# held in your hands like a gun (primary or secondary): binoculars look (RMB), the torch lights the way (LMB)
	"binoculars": {"name": "Binoculars", "w": 2, "h": 1, "stack": 1, "kind": "gun", "gun": "binoculars", "slot": "secondary", "tool": true,
		"model": "res://assets/ph/survival/vintage_binocular/vintage_binocular.gltf"},
	"torch": {"name": "Torch", "w": 2, "h": 1, "stack": 1, "kind": "gun", "gun": "torch", "slot": "secondary", "tool": true,
		"model": "res://assets/ph/survival/small_plastic_torch/small_plastic_torch.gltf"},
	"tape": {"name": "Duct tape", "w": 1, "h": 1, "stack": 3, "kind": "misc", "model": "res://assets/props/items/duct_tape.tscn"},
	"hammer": {"name": "Hammer", "w": 2, "h": 1, "stack": 1, "kind": "misc", "model": "res://assets/ph/tools/cross_pein_hammer/cross_pein_hammer.gltf"},
	"nails": {"name": "Box of nails", "w": 1, "h": 1, "stack": 5, "kind": "misc", "model": "res://assets/props/items/nails_box.tscn"},
	"plank": {"name": "Timber plank", "w": 4, "h": 1, "stack": 6, "kind": "misc", "model": "res://assets/props/items/plank.tscn"},
	"radio": {"name": "Two-way radio", "w": 1, "h": 2, "stack": 1, "kind": "misc", "model": "res://assets/ph/survival/vintage_radio_transceiver/vintage_radio_transceiver.gltf"},
	"wrench": {"name": "Shifter", "w": 2, "h": 1, "stack": 1, "kind": "misc", "model": "res://assets/ph/tools/adjustable_wrench/adjustable_wrench.gltf"},
	"jerry_fuel": {"name": "Jerry can (fuel)", "w": 2, "h": 3, "stack": 1, "kind": "misc", "model": "res://assets/ph/carparts/metal_jerrycan/metal_jerrycan.gltf"},
	# things to hit with (the best one you carry is the one you swing, with the gun put away) and things to throw (X)
	"knife": {"name": "Knife", "w": 1, "h": 2, "stack": 1, "kind": "misc"},
	"tyre_iron": {"name": "Tyre iron", "w": 2, "h": 1, "stack": 1, "kind": "misc"},
	"pipe_wrench": {"name": "Pipe wrench", "w": 2, "h": 1, "stack": 1, "kind": "misc", "model": "res://assets/ph/tools/pipe_wrench/pipe_wrench.gltf"},
	"bat": {"name": "Cricket bat", "w": 3, "h": 1, "stack": 1, "kind": "misc"},
	"crowbar": {"name": "Crowbar", "w": 3, "h": 1, "stack": 1, "kind": "misc", "model": "res://assets/ph/weapons/crowbar_01/crowbar_01.gltf"},
	"machete": {"name": "Machete", "w": 3, "h": 1, "stack": 1, "kind": "misc", "model": "res://assets/ph/weapons/machete/machete.gltf"},
	"hatchet": {"name": "Axe", "w": 3, "h": 1, "stack": 1, "kind": "misc", "model": "res://assets/ph/weapons/wooden_axe/wooden_axe.gltf"},
	"sledge": {"name": "Sledgehammer", "w": 4, "h": 1, "stack": 1, "kind": "misc", "model": "res://assets/ph/weapons/sledgehammer_01/sledgehammer_01.gltf"},
	"bottle": {"name": "Empty bottle", "w": 1, "h": 2, "stack": 3, "kind": "misc"},
	"molotov": {"name": "Petrol bomb", "w": 1, "h": 2, "stack": 3, "kind": "misc"},
	# cars
	"car_key": {"name": "Car key", "w": 1, "h": 1, "stack": 1, "kind": "misc"},
	"car_battery": {"name": "Car battery", "w": 2, "h": 2, "stack": 1, "kind": "misc"},
	# water
	"water_bottle": {"name": "Bottle of water", "w": 1, "h": 2, "stack": 3, "kind": "food", "heal": 2.0, "use_time": 2.5, "drink": 45.0},
	"soft_drink": {"name": "Can of soft drink", "w": 1, "h": 1, "stack": 6, "kind": "food", "heal": 1.0, "use_time": 2.0, "drink": 22.0, "eat": 4.0},
	# what things are made of
	"scrap": {"name": "Scrap metal", "w": 2, "h": 1, "stack": 10, "kind": "misc"},
	"cloth": {"name": "Rags", "w": 1, "h": 1, "stack": 10, "kind": "misc"},
	"wire": {"name": "Wire", "w": 1, "h": 1, "stack": 5, "kind": "misc"},
	"rope": {"name": "Rope", "w": 2, "h": 1, "stack": 3, "kind": "misc"},
	"gunpowder": {"name": "Gunpowder", "w": 1, "h": 1, "stack": 5, "kind": "misc"},
	"brass": {"name": "Spent cases", "w": 1, "h": 1, "stack": 10, "kind": "misc"},
	"tin_sheet": {"name": "Sheet of tin", "w": 3, "h": 2, "stack": 6, "kind": "misc"},
	"brick": {"name": "Bricks", "w": 2, "h": 1, "stack": 12, "kind": "misc"},
	# fire, wood, food from the land (0.2.45)
	"lighter": {"name": "Lighter", "w": 1, "h": 1, "stack": 1, "kind": "misc"},
	"flint": {"name": "Flint and steel", "w": 1, "h": 1, "stack": 1, "kind": "misc"},
	"rock": {"name": "Rock", "w": 1, "h": 1, "stack": 8, "kind": "misc"},
	"wood": {"name": "Firewood", "w": 2, "h": 1, "stack": 10, "kind": "misc"},
	"stick": {"name": "Sticks", "w": 2, "h": 1, "stack": 10, "kind": "misc"},
	"meat_raw": {"name": "Raw meat", "w": 1, "h": 1, "stack": 4, "kind": "food", "use_time": 3.0, "eat": 6.0, "heal": -4.0},
	"meat_cooked": {"name": "Cooked meat", "w": 1, "h": 1, "stack": 4, "kind": "food", "use_time": 3.0, "eat": 38.0, "heal": 4.0},
	"water_dirty": {"name": "Creek water", "w": 1, "h": 2, "stack": 3, "kind": "food", "use_time": 2.5, "drink": 30.0, "heal": -6.0},
	"veg": {"name": "Vegies", "w": 1, "h": 1, "stack": 6, "kind": "food", "use_time": 2.5, "eat": 18.0, "heal": 1.0},
	"stew": {"name": "Hot stew", "w": 1, "h": 1, "stack": 2, "kind": "food", "use_time": 4.0, "eat": 55.0, "drink": 10.0, "heal": 8.0},
	"seeds": {"name": "Vegie seeds", "w": 1, "h": 1, "stack": 10, "kind": "misc"},
	"oil_can": {"name": "Engine oil", "w": 2, "h": 1, "stack": 2, "kind": "misc", "icon_rot": -90, "model": "res://assets/ph/carparts/small_oil_can_01/small_oil_can_01.gltf"},
}

# Making things (N). Everything's known from the start. needs are used up, tools aren't.
const RECIPES := {
	"bandage": {"out": "bandage", "n": 2, "needs": {"cloth": 2}},
	# fire and food (0.2.45): "station" is what has to be close by (BasePiece: bench, a lit fire)
	"flint": {"out": "flint", "needs": {"rock": 1, "scrap": 1}, "note": "Strike the steel on the rock to light a fire."},
	"wood": {"out": "wood", "needs": {"stick": 4}, "note": "A bundle of sticks does for firewood."},
	"axe": {"out": "hatchet", "needs": {"scrap": 3, "stick": 2, "tape": 1}, "station": "bench"},
	"cook_meat": {"out": "meat_cooked", "needs": {"meat_raw": 1}, "station": "fire"},
	"boil_water": {"out": "water_bottle", "needs": {"water_dirty": 1}, "station": "fire", "note": "Boiled, it's safe to drink."},
	"stew": {"out": "stew", "needs": {"veg": 2, "food_can": 1, "water_bottle": 1}, "station": "fire"},
	"campfire_kit": {"out": "rock", "n": 6, "needs": {"brick": 3}, "tools": ["hammer"], "note": "Broken bricks make fire-ring stones."},
	"medkit": {"out": "medkit", "needs": {"bandage": 3, "cloth": 2, "tape": 1}},
	"rope": {"out": "rope", "needs": {"cloth": 3}},
	"nails": {"out": "nails", "needs": {"scrap": 2}, "tools": ["hammer"]},
	"tin_sheet": {"out": "tin_sheet", "needs": {"scrap": 4}, "tools": ["hammer"]},
	"plank": {"out": "plank", "n": 2, "needs": {"scrap": 1, "rope": 1}, "note": "Lashed together from offcuts."},
	"torch": {"out": "torch", "needs": {"scrap": 2, "wire": 1}},
	"pack_small": {"out": "pack_small", "needs": {"cloth": 6, "rope": 1}},
	"molotov": {"out": "molotov", "needs": {"bottle": 1, "cloth": 1}, "tools": ["jerry_fuel"], "note": "Filled from a jerry can of fuel (the can isn't used up)."},
	"ammo_12g": {"out": "ammo_12g", "n": 6, "needs": {"gunpowder": 1, "brass": 2, "scrap": 1}},
	"ammo_303": {"out": "ammo_303", "n": 8, "needs": {"gunpowder": 1, "brass": 3}},
	"ammo_762": {"out": "ammo_762", "n": 8, "needs": {"gunpowder": 1, "brass": 3}},
	"ammo_357": {"out": "ammo_357", "n": 8, "needs": {"gunpowder": 1, "brass": 2}},
	"ammo_45": {"out": "ammo_45", "n": 8, "needs": {"gunpowder": 1, "brass": 2}},
}
const GUN_AMMO := {"enfield": "ammo_303", "slr": "ammo_762", "python": "ammo_357", "sawnoff": "ammo_12g", "dbshotgun": "ammo_12g", "rem870": "ammo_12g", "hunter": "ammo_762", "magnum45": "ammo_45"}
const KIND_COL := {"gun": Color(0.32, 0.3, 0.26), "ammo": Color(0.55, 0.45, 0.18), "med": Color(0.6, 0.18, 0.16), "food": Color(0.35, 0.45, 0.2),
	"clothing": Color(0.22, 0.32, 0.45), "pack": Color(0.3, 0.36, 0.22), "misc": Color(0.36, 0.33, 0.3)}

# what's in each kind of container prop (keys are Forge prop keys); [item, chance, min, max]
const LOOT := {
	"ammo": [["ammo_303", 0.6, 10, 30], ["ammo_762", 0.5, 10, 40], ["ammo_357", 0.5, 6, 36], ["ammo_45", 0.4, 6, 30], ["ammo_12g", 0.6, 6, 20], ["ammo_12g", 0.3, 4, 12]],
	"medical": [["bandage", 0.95, 2, 8], ["bandage", 0.4, 1, 5], ["medkit", 0.35, 1, 1]],
	"food": [["water_bottle", 0.5, 1, 2], ["food_can", 0.8, 1, 4], ["long_life", 0.5, 1, 2], ["thermos", 0.25, 1, 1]],
	"tools": [["car_battery", 0.1, 1, 1], ["tyre_iron", 0.3, 1, 1], ["pipe_wrench", 0.25, 1, 1], ["crowbar", 0.2, 1, 1], ["scrap", 0.5, 1, 3], ["wire", 0.3, 1, 2], ["tape", 0.3, 1, 1], ["hammer", 0.3, 1, 1], ["nails", 0.3, 1, 2], ["wrench", 0.6, 1, 1], ["oil_can", 0.5, 1, 2], ["torch", 0.3, 1, 1], ["radio", 0.15, 1, 1]],
	"crate": [["water_bottle", 0.4, 1, 2], ["machete", 0.05, 1, 1], ["scrap", 0.3, 1, 3], ["cloth", 0.3, 1, 3], ["food_can", 0.5, 1, 4], ["bandage", 0.4, 1, 4], ["ammo_12g", 0.3, 4, 12], ["ammo_303", 0.25, 5, 20], ["ammo_45", 0.15, 4, 12], ["gun_magnum45", 0.03, 1, 1], ["shirt_flanno", 0.2, 1, 1],
		["pants_cargo", 0.15, 1, 1], ["jacket_army", 0.08, 1, 1], ["pack_small", 0.1, 1, 1], ["binoculars", 0.08, 1, 1], ["torch", 0.15, 1, 1]],
	"military": [["machete", 0.25, 1, 1], ["water_bottle", 0.5, 1, 3], ["gunpowder", 0.5, 1, 3], ["brass", 0.5, 4, 10], ["ammo_762", 0.7, 15, 40], ["ammo_303", 0.5, 10, 30], ["gun_slr", 0.12, 1, 1], ["gun_enfield", 0.12, 1, 1], ["gun_hunter", 0.08, 1, 1], ["jacket_army", 0.3, 1, 1],
		["pack_large", 0.12, 1, 1], ["medkit", 0.25, 1, 1], ["long_life", 0.5, 1, 2], ["gas_mask", 0.2, 1, 1]],
	"fuel": [["jerry_fuel", 0.9, 1, 1]],
	"planks": [["tin_sheet", 0.4, 1, 3], ["brick", 0.3, 4, 12], ["plank", 1.0, 2, 6], ["nails", 0.25, 1, 1]],
	"none": [],
	# on the dead: what people had on them when it happened (pockets, a belt, a bag)
	"zombie": [["cloth", 0.6, 1, 2], ["lighter", 0.18, 1, 1], ["car_key", 0.07, 1, 1], ["bandage", 0.12, 1, 2], ["soft_drink", 0.08, 1, 1],
		["water_bottle", 0.06, 1, 1], ["food_can", 0.04, 1, 1], ["long_life", 0.04, 1, 1], ["torch", 0.04, 1, 1], ["knife", 0.04, 1, 1], ["tape", 0.03, 1, 1],
		["ammo_12g", 0.02, 2, 6], ["ammo_357", 0.015, 2, 6], ["radio", 0.01, 1, 1], ["seeds", 0.03, 1, 3]],
	"scav": [["cloth", 0.5, 1, 3], ["lighter", 0.35, 1, 1], ["bandage", 0.35, 1, 3], ["water_bottle", 0.3, 1, 1], ["food_can", 0.25, 1, 2],
		["knife", 0.15, 1, 1], ["tape", 0.15, 1, 1], ["scrap", 0.2, 1, 2], ["gunpowder", 0.1, 1, 2], ["brass", 0.15, 2, 6], ["car_key", 0.1, 1, 1], ["flint", 0.08, 1, 1]],
	# house and shed furniture
	"kitchen": [["lighter", 0.3, 1, 1], ["car_key", 0.18, 1, 1], ["knife", 0.5, 1, 1], ["bottle", 0.4, 1, 2], ["water_bottle", 0.35, 1, 2], ["tape", 0.08, 1, 1], ["food_can", 0.7, 1, 3], ["long_life", 0.3, 1, 1], ["thermos", 0.15, 1, 1], ["torch", 0.08, 1, 1], ["bandage", 0.1, 1, 2]],
	"fridge": [["meat_raw", 0.2, 1, 2], ["water_bottle", 0.6, 1, 3], ["soft_drink", 0.6, 1, 4], ["food_can", 0.35, 1, 2], ["thermos", 0.12, 1, 1], ["long_life", 0.1, 1, 1]],
	"pantry": [["water_bottle", 0.4, 1, 2], ["soft_drink", 0.4, 1, 3], ["food_can", 0.8, 1, 4], ["long_life", 0.45, 1, 2], ["oil_can", 0.1, 1, 1], ["torch", 0.06, 1, 1]],
	"bathroom": [["bandage", 0.75, 1, 4], ["medkit", 0.1, 1, 1], ["bandage", 0.2, 1, 2]],
	"wardrobe": [["bat", 0.08, 1, 1], ["cloth", 0.6, 1, 4], ["shirt_flanno", 0.5, 1, 1], ["pants_jeans", 0.5, 1, 1], ["shirt_work", 0.3, 1, 1], ["pants_cargo", 0.22, 1, 1], ["jacket_army", 0.08, 1, 1],
		["boots_rubber", 0.2, 1, 1], ["pack_small", 0.1, 1, 1], ["gun_dbshotgun", 0.02, 1, 1]],
	"drawers": [["lighter", 0.15, 1, 1], ["car_key", 0.15, 1, 1], ["cloth", 0.4, 1, 3], ["tape", 0.12, 1, 1], ["shirt_flanno", 0.3, 1, 1], ["pants_jeans", 0.25, 1, 1], ["torch", 0.2, 1, 1], ["binoculars", 0.05, 1, 1], ["ammo_357", 0.1, 6, 18], ["radio", 0.05, 1, 1], ["bandage", 0.15, 1, 2]],
	"nightstand": [["car_key", 0.15, 1, 1], ["torch", 0.3, 1, 1], ["bandage", 0.3, 1, 2], ["ammo_357", 0.12, 6, 12], ["ammo_45", 0.1, 6, 12], ["gun_python", 0.03, 1, 1], ["gun_magnum45", 0.02, 1, 1]],
	"bookshelf": [["binoculars", 0.1, 1, 1], ["radio", 0.08, 1, 1], ["torch", 0.1, 1, 1], ["bandage", 0.1, 1, 1]],
	"office": [["car_key", 0.2, 1, 1], ["radio", 0.3, 1, 1], ["torch", 0.3, 1, 1], ["binoculars", 0.1, 1, 1], ["thermos", 0.2, 1, 1], ["ammo_45", 0.05, 4, 12]],
	"shed_shelf": [["hatchet", 0.2, 1, 1], ["flint", 0.08, 1, 1], ["lighter", 0.12, 1, 1], ["seeds", 0.15, 1, 4], ["machete", 0.12, 1, 1], ["crowbar", 0.15, 1, 1], ["sledge", 0.06, 1, 1], ["bottle", 0.3, 1, 3], ["scrap", 0.5, 1, 4], ["wire", 0.3, 1, 2], ["brick", 0.2, 2, 8], ["tin_sheet", 0.2, 1, 2], ["gunpowder", 0.12, 1, 2], ["tape", 0.3, 1, 1], ["hammer", 0.15, 1, 1], ["nails", 0.3, 1, 2], ["plank", 0.2, 1, 3], ["oil_can", 0.5, 1, 2], ["wrench", 0.35, 1, 1], ["jerry_fuel", 0.15, 1, 1], ["torch", 0.15, 1, 1], ["ammo_12g", 0.15, 4, 12], ["ammo_303", 0.08, 5, 15], ["boots_rubber", 0.1, 1, 1]],
	"workbench": [["car_battery", 0.25, 1, 1], ["car_key", 0.15, 1, 1], ["wire", 0.4, 1, 3], ["tyre_iron", 0.3, 1, 1], ["pipe_wrench", 0.25, 1, 1], ["scrap", 0.6, 1, 4], ["wire", 0.3, 1, 2], ["brass", 0.25, 2, 8], ["gunpowder", 0.2, 1, 2], ["tape", 0.35, 1, 1], ["hammer", 0.3, 1, 1], ["nails", 0.35, 1, 2], ["wrench", 0.6, 1, 1], ["oil_can", 0.3, 1, 1], ["torch", 0.2, 1, 1], ["radio", 0.05, 1, 1]],
	"laundry": [["cloth", 0.7, 2, 5], ["tape", 0.25, 1, 1], ["bandage", 0.2, 1, 2], ["boots_rubber", 0.2, 1, 1], ["gas_mask", 0.05, 1, 1], ["shirt_work", 0.25, 1, 1]],
	"servo_shelf": [["lighter", 0.6, 1, 2], ["car_battery", 0.3, 1, 1], ["oil_can", 0.6, 1, 2], ["wire", 0.3, 1, 2], ["soft_drink", 0.8, 1, 5], ["water_bottle", 0.7, 1, 3], ["tyre_iron", 0.2, 1, 1], ["tape", 0.2, 1, 1], ["torch", 0.1, 1, 1], ["food_can", 0.6, 1, 4], ["long_life", 0.35, 1, 2], ["oil_can", 0.5, 1, 2], ["torch", 0.15, 1, 1], ["bandage", 0.25, 1, 3], ["jerry_fuel", 0.1, 1, 1], ["thermos", 0.1, 1, 1]],
	# the mall
	"super": [["water_bottle", 0.7, 1, 3], ["soft_drink", 0.7, 2, 6], ["food_can", 0.85, 1, 4], ["long_life", 0.55, 1, 3], ["food_can", 0.5, 1, 3], ["bandage", 0.15, 1, 3], ["tape", 0.1, 1, 1], ["thermos", 0.08, 1, 1]],
	"security": [["car_key", 0.3, 1, 1], ["bat", 0.3, 1, 1], ["water_bottle", 0.4, 1, 2], ["torch", 0.6, 1, 1], ["radio", 0.5, 1, 1], ["ammo_45", 0.35, 6, 18], ["gun_magnum45", 0.12, 1, 1], ["bandage", 0.4, 1, 4], ["binoculars", 0.1, 1, 1]],
	# main-street shops
	"chemist": [["bandage", 0.9, 2, 8], ["bandage", 0.5, 1, 5], ["medkit", 0.3, 1, 1], ["thermos", 0.05, 1, 1]],
	"hardware": [["car_battery", 0.3, 1, 1], ["seeds", 0.4, 2, 6], ["lighter", 0.3, 1, 2], ["hatchet", 0.35, 1, 1], ["crowbar", 0.35, 1, 1], ["sledge", 0.15, 1, 1], ["machete", 0.2, 1, 1], ["pipe_wrench", 0.3, 1, 1], ["scrap", 0.6, 2, 6], ["wire", 0.5, 1, 3], ["tin_sheet", 0.4, 1, 3], ["brick", 0.4, 4, 12], ["rope", 0.3, 1, 2], ["tape", 0.5, 1, 2], ["hammer", 0.35, 1, 1], ["nails", 0.55, 1, 3], ["plank", 0.35, 1, 4], ["wrench", 0.35, 1, 1], ["torch", 0.3, 1, 1], ["oil_can", 0.3, 1, 2], ["jerry_fuel", 0.08, 1, 1]],
	"grocer": [["water_bottle", 0.8, 1, 3], ["soft_drink", 0.8, 2, 6], ["food_can", 0.9, 1, 4], ["long_life", 0.5, 1, 2], ["food_can", 0.4, 1, 3], ["thermos", 0.1, 1, 1]],
	"newsagent": [["radio", 0.2, 1, 1], ["torch", 0.3, 1, 1], ["tape", 0.3, 1, 1], ["binoculars", 0.08, 1, 1], ["thermos", 0.1, 1, 1]],
	"clothes": [["cloth", 0.7, 2, 6], ["shirt_flanno", 0.5, 1, 1], ["pants_jeans", 0.45, 1, 1], ["shirt_work", 0.35, 1, 1], ["pants_cargo", 0.3, 1, 1], ["jacket_army", 0.12, 1, 1],
		["boots_rubber", 0.25, 1, 1], ["pack_small", 0.15, 1, 1], ["gas_mask", 0.03, 1, 1]],
	"sports": [["bat", 0.6, 1, 1], ["knife", 0.4, 1, 1], ["machete", 0.15, 1, 1], ["water_bottle", 0.4, 1, 2], ["gunpowder", 0.5, 1, 3], ["brass", 0.5, 3, 10], ["ammo_12g", 0.55, 6, 20], ["ammo_303", 0.3, 5, 20], ["ammo_762", 0.15, 5, 20], ["binoculars", 0.25, 1, 1], ["pack_small", 0.3, 1, 1], ["pack_large", 0.06, 1, 1],
		["torch", 0.3, 1, 1], ["boots_rubber", 0.2, 1, 1], ["gun_rem870", 0.04, 1, 1], ["gun_hunter", 0.03, 1, 1]],
	"general": [["water_bottle", 0.5, 1, 2], ["lighter", 0.3, 1, 1], ["soft_drink", 0.5, 1, 4], ["bat", 0.1, 1, 1], ["cloth", 0.4, 1, 3], ["wire", 0.2, 1, 2], ["food_can", 0.6, 1, 3], ["tape", 0.25, 1, 1], ["torch", 0.2, 1, 1], ["bandage", 0.3, 1, 3], ["oil_can", 0.2, 1, 1], ["long_life", 0.25, 1, 1], ["nails", 0.1, 1, 1]],
	"pub": [["bottle", 0.9, 2, 3], ["soft_drink", 0.6, 1, 4], ["water_bottle", 0.4, 1, 2], ["food_can", 0.4, 1, 2], ["thermos", 0.2, 1, 1], ["long_life", 0.2, 1, 1], ["ammo_12g", 0.08, 4, 10]],
	"till": [["car_key", 0.1, 1, 1], ["bandage", 0.2, 1, 2], ["torch", 0.2, 1, 1], ["tape", 0.15, 1, 1], ["radio", 0.06, 1, 1], ["ammo_45", 0.04, 4, 10]],
	"bank": [["ammo_45", 0.4, 6, 24], ["ammo_357", 0.35, 6, 24], ["gun_python", 0.12, 1, 1], ["gun_magnum45", 0.1, 1, 1], ["radio", 0.2, 1, 1], ["torch", 0.2, 1, 1]],
	"rack": [["scrap", 0.4, 1, 4], ["food_can", 0.4, 1, 4], ["long_life", 0.3, 1, 2], ["ammo_762", 0.08, 10, 30], ["jerry_fuel", 0.12, 1, 1], ["pack_small", 0.06, 1, 1], ["oil_can", 0.3, 1, 2]],
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
	"tools": ["tools", [5, 3]], "kitchen": ["kitchen", [6, 3]], "fridge": ["fridge", [4, 5]], "pantry": ["pantry", [5, 4]],
	"bathroom": ["bathroom", [4, 3]], "wardrobe": ["wardrobe", [6, 6]], "drawers": ["drawers", [5, 4]], "nightstand": ["nightstand", [3, 2]],
	"bookshelf": ["bookshelf", [6, 3]], "office": ["office", [5, 3]], "shed_shelf": ["shed_shelf", [7, 4]], "workbench": ["workbench", [6, 2]],
	"laundry": ["laundry", [4, 3]], "rack": ["rack", [8, 5]], "servo_shelf": ["servo_shelf", [7, 4]], "planks": ["planks", [8, 3]],
	"chemist": ["chemist", [7, 4]], "hardware": ["hardware", [8, 4]], "grocer": ["grocer", [7, 4]], "newsagent": ["newsagent", [6, 4]],
	"clothes": ["clothes", [7, 5]], "sports": ["sports", [8, 4]], "general": ["general", [7, 4]], "pub": ["pub", [6, 3]], "till": ["till", [4, 2]],
	"bank": ["bank", [5, 4]], "super": ["super", [8, 4]], "security": ["security", [6, 4]],
	"zombie": ["zombie", [4, 3]], "scav": ["scav", [5, 3]],
	"car_boot": ["none", [7, 4]], "car_wagon": ["none", [8, 5]], "car_tray": ["none", [10, 5]],
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
	if id == "car_key": s.data["cut"] = randi() % 3          # one key in three fits any one car
	if id == "car_battery": s.data["charge"] = randf_range(40.0, 100.0)
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
