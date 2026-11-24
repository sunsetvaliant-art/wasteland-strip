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
	"gun_ruger1022": {"name": "Ruger 10/22 .22", "w": 3, "h": 1, "stack": 1, "kind": "gun", "gun": "ruger1022", "slot": "primary"},
	"gun_lever": {"name": "Henry .44 lever action", "w": 4, "h": 1, "stack": 1, "kind": "gun", "gun": "lever", "slot": "primary"},
	"gun_glock": {"name": "Glock 17", "w": 1, "h": 1, "stack": 1, "kind": "gun", "gun": "glock", "slot": "secondary"},
	"gun_sks": {"name": "SKS", "w": 4, "h": 1, "stack": 1, "kind": "gun", "gun": "sks", "slot": "primary"},
	# rounds, loose: one cell holds a box's worth
	"ammo_303": {"name": ".303 rounds", "w": 1, "h": 1, "stack": 30, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_762": {"name": "7.62 NATO rounds", "w": 1, "h": 1, "stack": 40, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_357": {"name": ".357 Magnum rounds", "w": 1, "h": 1, "stack": 36, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_45": {"name": ".45 rounds", "w": 1, "h": 1, "stack": 36, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_12g": {"name": "12 gauge shells", "w": 1, "h": 1, "stack": 20, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_22": {"name": ".22 LR rounds", "w": 1, "h": 1, "stack": 100, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_9mm": {"name": "9 mm rounds", "w": 1, "h": 1, "stack": 50, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_44": {"name": ".44 Magnum rounds", "w": 1, "h": 1, "stack": 30, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	"ammo_762x39": {"name": "7.62x39 rounds", "w": 1, "h": 1, "stack": 40, "kind": "ammo", "model": "res://assets/ph/weapons/ammo_box/ammo_box.gltf"},
	# medical and food
	"bandage": {"name": "Bandage", "w": 1, "h": 1, "stack": 10, "kind": "med", "heal": 15.0, "use_time": 2.5},
	"medkit": {"name": "First aid kit", "w": 2, "h": 2, "stack": 1, "kind": "med", "size": 0.35, "heal": 60.0, "use_time": 6.0, "model": "res://assets/ph/survival/medical_box/medical_box.gltf"},
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
	# 0.2.75: more everyday clothes (they show on you: Outfit.LOOKS), each found in one of a few colours
	"shirt_tee": {"name": "T-shirt", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "top"},
	"shirt_singlet": {"name": "Singlet", "w": 1, "h": 2, "stack": 2, "kind": "clothing", "slot": "top"},
	"shirt_drill": {"name": "Drill work shirt", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "top", "grid": [4, 2]},
	"hoodie": {"name": "Hoodie", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "top", "grid": [4, 1]},
	"shorts_stubbies": {"name": "Stubbies (work shorts)", "w": 2, "h": 1, "stack": 2, "kind": "clothing", "slot": "bottom", "grid": [3, 1]},
	"pants_trackies": {"name": "Trackies", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "bottom", "grid": [2, 1]},
	"boots_work": {"name": "Work boots", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "feet"},
	"shoes_runners": {"name": "Runners", "w": 2, "h": 1, "stack": 2, "kind": "clothing", "slot": "feet"},
	"overalls": {"name": "Overalls", "w": 2, "h": 3, "stack": 1, "kind": "clothing", "slot": "bottom", "grid": [4, 2]},
	"shoes_leather": {"name": "Leather shoes", "w": 2, "h": 1, "stack": 2, "kind": "clothing", "slot": "feet"},
	"hat_fedora": {"name": "Hat", "w": 2, "h": 1, "stack": 1, "kind": "clothing", "slot": "head"},
	"thongs": {"name": "Thongs", "w": 1, "h": 1, "stack": 2, "kind": "clothing", "slot": "feet"},
	"gas_mask": {"name": "Gas mask", "w": 2, "h": 2, "stack": 2, "kind": "clothing", "slot": "head", "model": "res://assets/ph/survival/old_gas_mask/old_gas_mask.gltf"},
	# bags
	"pack_small": {"name": "Small backpack", "w": 3, "h": 3, "stack": 1, "kind": "pack", "slot": "back", "grid": [5, 10], "model": "res://assets/props/pack.glb"},
	"pack_large": {"name": "Army pack", "w": 4, "h": 4, "stack": 1, "kind": "pack", "slot": "back", "grid": [8, 10], "model": "res://assets/props/pack.glb"},
	# odds and ends
	# held in your hands like a gun (primary or secondary): binoculars look (RMB), the torch lights the way (LMB)
	"binoculars": {"name": "Binoculars", "w": 2, "h": 1, "stack": 1, "kind": "gun", "size": 0.18, "gun": "binoculars", "slot": "secondary", "tool": true,
		"model": "res://assets/ph/survival/vintage_binocular/vintage_binocular.gltf"},
	"torch": {"name": "Torch", "w": 2, "h": 1, "stack": 1, "kind": "gun", "size": 0.18, "gun": "torch", "slot": "secondary", "tool": true,
		"model": "res://assets/ph/survival/small_plastic_torch/small_plastic_torch.gltf"},
	"tape": {"name": "Duct tape", "w": 1, "h": 1, "stack": 3, "kind": "misc", "size": 0.1, "model": "res://assets/props/items/duct_tape.tscn"},
	"hammer": {"name": "Hammer", "w": 2, "h": 1, "stack": 1, "kind": "misc", "size": 0.33, "model": "res://assets/ph/tools/cross_pein_hammer/cross_pein_hammer.gltf"},
	"nails": {"name": "Box of nails", "w": 1, "h": 1, "stack": 5, "kind": "misc", "size": 0.12, "model": "res://assets/props/items/nails_box.tscn"},
	"plank": {"name": "Timber plank", "w": 4, "h": 1, "stack": 6, "kind": "misc", "model": "res://assets/props/items/plank.tscn"},
	"radio": {"name": "Two-way radio", "w": 1, "h": 2, "stack": 1, "kind": "misc", "size": 0.25, "model": "res://assets/ph/survival/vintage_radio_transceiver/vintage_radio_transceiver.gltf"},
	"wrench": {"name": "Shifter", "w": 2, "h": 1, "stack": 1, "kind": "misc", "size": 0.25, "model": "res://assets/ph/tools/adjustable_wrench/adjustable_wrench.gltf"},
	"jerry_fuel": {"name": "Jerry can (fuel)", "w": 2, "h": 3, "stack": 1, "kind": "misc", "size": 0.47, "model": "res://assets/ph/carparts/metal_jerrycan/metal_jerrycan.gltf"},
	# things to hit with (the best one you carry is the one you swing, with the gun put away) and things to throw (X)
	"knife": {"name": "Knife", "w": 1, "h": 2, "stack": 1, "kind": "misc"},
	"tyre_iron": {"name": "Tyre iron", "w": 2, "h": 1, "stack": 1, "kind": "misc"},
	"pipe_wrench": {"name": "Pipe wrench", "w": 2, "h": 1, "stack": 1, "kind": "misc", "size": 0.35, "model": "res://assets/ph/tools/pipe_wrench/pipe_wrench.gltf"},
	"bat": {"name": "Cricket bat", "w": 3, "h": 1, "stack": 1, "kind": "misc"},
	"crowbar": {"name": "Crowbar", "w": 3, "h": 1, "stack": 1, "kind": "misc", "size": 0.6, "model": "res://assets/ph/weapons/crowbar_01/crowbar_01.gltf"},
	"machete": {"name": "Machete", "w": 3, "h": 1, "stack": 1, "kind": "misc", "size": 0.6, "model": "res://assets/ph/weapons/machete/machete.gltf"},
	"hatchet": {"name": "Axe", "w": 3, "h": 1, "stack": 1, "kind": "misc", "size": 0.7, "model": "res://assets/ph/weapons/wooden_axe/wooden_axe.gltf"},
	"sledge": {"name": "Sledgehammer", "w": 4, "h": 1, "stack": 1, "kind": "misc", "size": 0.9, "model": "res://assets/ph/weapons/sledgehammer_01/sledgehammer_01.gltf"},
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
	# 0.2.68: ratchet straps (J, or Use: click the load, click where it ties off). Tie loads down, tow, pull engines
	"strap_250": {"name": "250 kg ratchet strap (orange)", "w": 1, "h": 1, "stack": 4, "kind": "strap", "size": 0.12},
	"strap_2t": {"name": "2 t ratchet strap (navy)", "w": 2, "h": 1, "stack": 2, "kind": "strap", "size": 0.2},
	# 0.2.68: more hand tools to find (real size on the ground)
	"ratchet": {"name": "Socket ratchet", "w": 2, "h": 1, "stack": 1, "kind": "misc", "size": 0.26, "model": "res://assets/ph/tools/ratchet_wrench/ratchet_wrench.gltf"},
	"spanner": {"name": "Ring spanner", "w": 2, "h": 1, "stack": 1, "kind": "misc", "size": 0.22, "model": "res://assets/ph/tools/combination_wrench/combination_wrench.gltf"},
	"pliers": {"name": "Pliers", "w": 1, "h": 1, "stack": 1, "kind": "misc", "size": 0.2, "model": "res://assets/ph/tools/pliers/pliers.gltf"},
	"multigrips": {"name": "Multigrips", "w": 2, "h": 1, "stack": 1, "kind": "misc", "size": 0.25, "model": "res://assets/ph/tools/tongue_groove_pliers/tongue_groove_pliers.gltf"},
	"screwdriver": {"name": "Flat screwdriver", "w": 1, "h": 1, "stack": 1, "kind": "misc", "size": 0.22, "model": "res://assets/ph/tools/flathead_screwdriver/flathead_screwdriver.gltf"},
	"hacksaw": {"name": "Hacksaw", "w": 2, "h": 1, "stack": 1, "kind": "misc", "size": 0.4, "model": "res://assets/ph/tools/rusted_hacksaw/rusted_hacksaw.gltf"},
	"bolt_cutters": {"name": "Bolt cutters", "w": 3, "h": 1, "stack": 1, "kind": "misc", "size": 0.6, "model": "res://assets/ph/tools/bolt_cutters_01/bolt_cutters_01.gltf"},
	"tape_measure": {"name": "Tape measure", "w": 1, "h": 1, "stack": 1, "kind": "misc", "size": 0.08, "model": "res://assets/ph/tools/measuring_tape_01/measuring_tape_01.gltf"},
	"gas_torch": {"name": "Gas torch", "w": 1, "h": 2, "stack": 1, "kind": "misc", "size": 0.3, "model": "res://assets/ph/tools/propane_torch/propane_torch.gltf"},
	"hand_drill": {"name": "Hand drill", "w": 2, "h": 1, "stack": 1, "kind": "misc", "size": 0.35, "model": "res://assets/ph/tools/vintage_hand_drill/vintage_hand_drill.gltf"},
	"oil_can": {"name": "Engine oil", "w": 2, "h": 1, "stack": 2, "kind": "misc", "size": 0.2, "icon_rot": -90, "model": "res://assets/ph/carparts/small_oil_can_01/small_oil_can_01.gltf"},
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
	"ammo_9mm": {"out": "ammo_9mm", "n": 10, "needs": {"gunpowder": 1, "brass": 2}},
	"ammo_44": {"out": "ammo_44", "n": 8, "needs": {"gunpowder": 1, "brass": 2}},
	"ammo_762x39": {"out": "ammo_762x39", "n": 8, "needs": {"gunpowder": 1, "brass": 3}},
}
const GUN_AMMO := {"enfield": "ammo_303", "slr": "ammo_762", "python": "ammo_357", "sawnoff": "ammo_12g", "dbshotgun": "ammo_12g", "rem870": "ammo_12g", "hunter": "ammo_762", "magnum45": "ammo_45",
	"ruger1022": "ammo_22", "lever": "ammo_44", "glock": "ammo_9mm", "sks": "ammo_762x39"}
const KIND_COL := {"strap": Color(0.9, 0.45, 0.1), "gun": Color(0.32, 0.3, 0.26), "ammo": Color(0.55, 0.45, 0.18), "med": Color(0.6, 0.18, 0.16), "food": Color(0.35, 0.45, 0.2),
	"clothing": Color(0.22, 0.32, 0.45), "pack": Color(0.3, 0.36, 0.22), "misc": Color(0.36, 0.33, 0.3)}

# what's in each kind of container prop (keys are Forge prop keys); [item, chance, min, max]
const LOOT := {
	"ammo": [["ammo_303", 0.6, 10, 30], ["ammo_762", 0.5, 10, 40], ["ammo_357", 0.5, 6, 36], ["ammo_45", 0.4, 6, 30], ["ammo_12g", 0.6, 6, 20], ["ammo_12g", 0.3, 4, 12],
		["ammo_22", 0.6, 25, 100], ["ammo_9mm", 0.4, 10, 50], ["ammo_44", 0.3, 6, 24], ["ammo_762x39", 0.25, 10, 30]],
	"medical": [["bandage", 0.95, 2, 8], ["bandage", 0.4, 1, 5], ["medkit", 0.35, 1, 1]],
	"food": [["water_bottle", 0.5, 1, 2], ["food_can", 0.8, 1, 4], ["long_life", 0.5, 1, 2], ["thermos", 0.25, 1, 1]],
	"tools": [["car_battery", 0.1, 1, 1], ["tyre_iron", 0.3, 1, 1], ["pipe_wrench", 0.25, 1, 1], ["crowbar", 0.2, 1, 1], ["scrap", 0.5, 1, 3], ["wire", 0.3, 1, 2], ["tape", 0.3, 1, 1], ["hammer", 0.3, 1, 1], ["nails", 0.3, 1, 2], ["wrench", 0.6, 1, 1], ["oil_can", 0.5, 1, 2], ["torch", 0.3, 1, 1], ["radio", 0.15, 1, 1]],
	"crate": [["water_bottle", 0.4, 1, 2], ["machete", 0.05, 1, 1], ["scrap", 0.3, 1, 3], ["cloth", 0.3, 1, 3], ["food_can", 0.5, 1, 4], ["bandage", 0.4, 1, 4], ["ammo_12g", 0.3, 4, 12], ["ammo_303", 0.25, 5, 20], ["ammo_45", 0.15, 4, 12], ["gun_magnum45", 0.03, 1, 1], ["shirt_flanno", 0.2, 1, 1],
		["pants_cargo", 0.15, 1, 1], ["jacket_army", 0.08, 1, 1], ["pack_small", 0.1, 1, 1], ["binoculars", 0.08, 1, 1], ["torch", 0.15, 1, 1]],
	"military": [["machete", 0.25, 1, 1], ["water_bottle", 0.5, 1, 3], ["gunpowder", 0.5, 1, 3], ["brass", 0.5, 4, 10], ["ammo_762", 0.7, 15, 40], ["ammo_303", 0.5, 10, 30], ["gun_slr", 0.12, 1, 1], ["gun_enfield", 0.12, 1, 1], ["gun_hunter", 0.08, 1, 1], ["jacket_army", 0.3, 1, 1],
		["pack_large", 0.12, 1, 1], ["medkit", 0.25, 1, 1], ["long_life", 0.5, 1, 2], ["gas_mask", 0.2, 1, 1], ["gun_sks", 0.08, 1, 1], ["ammo_762x39", 0.4, 10, 30]],
	"fuel": [["jerry_fuel", 0.9, 1, 1]],
	"planks": [["tin_sheet", 0.4, 1, 3], ["brick", 0.3, 4, 12], ["plank", 1.0, 2, 6], ["nails", 0.25, 1, 1]],
	"none": [],
	# on the dead: what people had on them when it happened (pockets, a belt, a bag)
	# car parts stores, mechanics' shelves, wrecks (0.2.49)
	"carparts": [["laptop", 0.1, 1, 1], ["strap_250", 0.3, 1, 2], ["strap_2t", 0.2, 1, 1], ["ratchet", 0.25, 1, 1], ["car_battery", 0.4, 1, 1], ["oil_can", 0.7, 1, 3], ["tyre_iron", 0.35, 1, 1], ["wrench", 0.4, 1, 1], ["pipe_wrench", 0.2, 1, 1],
		["tape", 0.5, 1, 2], ["wire", 0.5, 1, 3], ["scrap", 0.5, 1, 4], ["jerry_fuel", 0.12, 1, 1], ["torch", 0.25, 1, 1], ["crowbar", 0.12, 1, 1]],
	"engine_parts": [],          # filled from EngineKit by roll_loot (0.2.55)
	"wreck": [["scrap", 0.9, 2, 6], ["wire", 0.5, 1, 3], ["car_battery", 0.2, 1, 1], ["oil_can", 0.25, 1, 1], ["cloth", 0.3, 1, 2], ["tyre_iron", 0.15, 1, 1], ["jerry_fuel", 0.05, 1, 1]],
	# caravans: holidays interrupted
	"caravan": [["food_can", 0.6, 1, 3], ["long_life", 0.4, 1, 2], ["water_bottle", 0.6, 1, 3], ["soft_drink", 0.5, 1, 4], ["lighter", 0.4, 1, 1],
		["torch", 0.35, 1, 1], ["rope", 0.3, 1, 1], ["bandage", 0.35, 1, 2], ["cloth", 0.4, 1, 3], ["knife", 0.2, 1, 1], ["car_key", 0.2, 1, 1],
		["radio", 0.08, 1, 1], ["jerry_fuel", 0.08, 1, 1], ["seeds", 0.05, 1, 2]],
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
	"wardrobe": [["shoes_leather", 0.25, 1, 1], ["hat_fedora", 0.1, 1, 1], ["overalls", 0.08, 1, 1], ["bat", 0.08, 1, 1], ["cloth", 0.6, 1, 4], ["shirt_flanno", 0.5, 1, 1], ["pants_jeans", 0.5, 1, 1], ["shirt_tee", 0.6, 1, 2], ["shirt_singlet", 0.3, 1, 1], ["hoodie", 0.3, 1, 1], ["shorts_stubbies", 0.4, 1, 1], ["pants_trackies", 0.3, 1, 1], ["shirt_drill", 0.2, 1, 1], ["shoes_runners", 0.25, 1, 1], ["thongs", 0.3, 1, 1], ["boots_work", 0.15, 1, 1], ["shirt_work", 0.3, 1, 1], ["pants_cargo", 0.22, 1, 1], ["jacket_army", 0.08, 1, 1],
		["boots_rubber", 0.2, 1, 1], ["pack_small", 0.1, 1, 1], ["gun_dbshotgun", 0.02, 1, 1]],
	"drawers": [["shirt_tee", 0.4, 1, 2], ["shirt_singlet", 0.2, 1, 1], ["shorts_stubbies", 0.2, 1, 1],["lighter", 0.15, 1, 1], ["car_key", 0.15, 1, 1], ["cloth", 0.4, 1, 3], ["tape", 0.12, 1, 1], ["shirt_flanno", 0.3, 1, 1], ["pants_jeans", 0.25, 1, 1], ["torch", 0.2, 1, 1], ["binoculars", 0.05, 1, 1], ["ammo_357", 0.1, 6, 18], ["radio", 0.05, 1, 1], ["bandage", 0.15, 1, 2]],
	"nightstand": [["car_key", 0.15, 1, 1], ["torch", 0.3, 1, 1], ["bandage", 0.3, 1, 2], ["ammo_357", 0.12, 6, 12], ["ammo_45", 0.1, 6, 12], ["gun_python", 0.03, 1, 1], ["gun_magnum45", 0.02, 1, 1], ["gun_glock", 0.02, 1, 1], ["ammo_9mm", 0.08, 6, 17]],
	"bookshelf": [["binoculars", 0.1, 1, 1], ["radio", 0.08, 1, 1], ["torch", 0.1, 1, 1], ["bandage", 0.1, 1, 1]],
	"office": [["laptop", 0.15, 1, 1], ["car_key", 0.2, 1, 1], ["radio", 0.3, 1, 1], ["torch", 0.3, 1, 1], ["binoculars", 0.1, 1, 1], ["thermos", 0.2, 1, 1], ["ammo_45", 0.05, 4, 12]],
	"shed_shelf": [["overalls", 0.12, 1, 1], ["boots_work", 0.12, 1, 1], ["shirt_drill", 0.1, 1, 1], ["strap_250", 0.3, 1, 2], ["strap_2t", 0.15, 1, 1], ["spanner", 0.15, 1, 1], ["pliers", 0.15, 1, 1], ["screwdriver", 0.2, 1, 1], ["hacksaw", 0.12, 1, 1], ["hatchet", 0.2, 1, 1], ["flint", 0.08, 1, 1], ["lighter", 0.12, 1, 1], ["seeds", 0.15, 1, 4], ["machete", 0.12, 1, 1], ["crowbar", 0.15, 1, 1], ["sledge", 0.06, 1, 1], ["bottle", 0.3, 1, 3], ["scrap", 0.5, 1, 4], ["wire", 0.3, 1, 2], ["brick", 0.2, 2, 8], ["tin_sheet", 0.2, 1, 2], ["gunpowder", 0.12, 1, 2], ["tape", 0.3, 1, 1], ["hammer", 0.15, 1, 1], ["nails", 0.3, 1, 2], ["plank", 0.2, 1, 3], ["oil_can", 0.5, 1, 2], ["wrench", 0.35, 1, 1], ["jerry_fuel", 0.15, 1, 1], ["torch", 0.15, 1, 1], ["ammo_12g", 0.15, 4, 12], ["ammo_303", 0.08, 5, 15], ["boots_rubber", 0.1, 1, 1], ["gun_ruger1022", 0.03, 1, 1], ["ammo_22", 0.15, 20, 50]],
	"workbench": [["strap_250", 0.25, 1, 2], ["strap_2t", 0.15, 1, 1], ["ratchet", 0.3, 1, 1], ["spanner", 0.3, 1, 1], ["multigrips", 0.2, 1, 1], ["car_battery", 0.25, 1, 1], ["car_key", 0.15, 1, 1], ["wire", 0.4, 1, 3], ["tyre_iron", 0.3, 1, 1], ["pipe_wrench", 0.25, 1, 1], ["scrap", 0.6, 1, 4], ["wire", 0.3, 1, 2], ["brass", 0.25, 2, 8], ["gunpowder", 0.2, 1, 2], ["tape", 0.35, 1, 1], ["hammer", 0.3, 1, 1], ["nails", 0.35, 1, 2], ["wrench", 0.6, 1, 1], ["oil_can", 0.3, 1, 1], ["torch", 0.2, 1, 1], ["radio", 0.05, 1, 1]],
	"laundry": [["cloth", 0.7, 2, 5], ["shirt_tee", 0.4, 1, 2], ["shorts_stubbies", 0.25, 1, 1], ["shirt_singlet", 0.25, 1, 1], ["shirt_drill", 0.2, 1, 1], ["tape", 0.25, 1, 1], ["bandage", 0.2, 1, 2], ["boots_rubber", 0.2, 1, 1], ["gas_mask", 0.05, 1, 1], ["shirt_work", 0.25, 1, 1]],
	"servo_shelf": [["lighter", 0.6, 1, 2], ["car_battery", 0.3, 1, 1], ["oil_can", 0.6, 1, 2], ["wire", 0.3, 1, 2], ["soft_drink", 0.8, 1, 5], ["water_bottle", 0.7, 1, 3], ["tyre_iron", 0.2, 1, 1], ["tape", 0.2, 1, 1], ["torch", 0.1, 1, 1], ["food_can", 0.6, 1, 4], ["long_life", 0.35, 1, 2], ["oil_can", 0.5, 1, 2], ["torch", 0.15, 1, 1], ["bandage", 0.25, 1, 3], ["jerry_fuel", 0.1, 1, 1], ["thermos", 0.1, 1, 1]],
	# the mall
	"super": [["water_bottle", 0.7, 1, 3], ["soft_drink", 0.7, 2, 6], ["food_can", 0.85, 1, 4], ["long_life", 0.55, 1, 3], ["food_can", 0.5, 1, 3], ["bandage", 0.15, 1, 3], ["tape", 0.1, 1, 1], ["thermos", 0.08, 1, 1]],
	"security": [["car_key", 0.3, 1, 1], ["bat", 0.3, 1, 1], ["water_bottle", 0.4, 1, 2], ["torch", 0.6, 1, 1], ["radio", 0.5, 1, 1], ["ammo_45", 0.35, 6, 18], ["gun_magnum45", 0.12, 1, 1], ["bandage", 0.4, 1, 4], ["binoculars", 0.1, 1, 1], ["gun_glock", 0.12, 1, 1], ["ammo_9mm", 0.35, 10, 34]],
	# main-street shops
	"chemist": [["bandage", 0.9, 2, 8], ["bandage", 0.5, 1, 5], ["medkit", 0.3, 1, 1], ["thermos", 0.05, 1, 1]],
	"hardware": [["boots_work", 0.25, 1, 1], ["shirt_work", 0.2, 1, 1], ["boots_rubber", 0.15, 1, 1], ["strap_250", 0.6, 1, 4], ["strap_2t", 0.35, 1, 2], ["ratchet", 0.3, 1, 1], ["spanner", 0.3, 1, 1], ["pliers", 0.3, 1, 1], ["multigrips", 0.25, 1, 1], ["screwdriver", 0.35, 1, 1], ["hacksaw", 0.25, 1, 1], ["bolt_cutters", 0.12, 1, 1], ["tape_measure", 0.3, 1, 1], ["gas_torch", 0.15, 1, 1], ["hand_drill", 0.1, 1, 1], ["car_battery", 0.3, 1, 1], ["seeds", 0.4, 2, 6], ["lighter", 0.3, 1, 2], ["hatchet", 0.35, 1, 1], ["crowbar", 0.35, 1, 1], ["sledge", 0.15, 1, 1], ["machete", 0.2, 1, 1], ["pipe_wrench", 0.3, 1, 1], ["scrap", 0.6, 2, 6], ["wire", 0.5, 1, 3], ["tin_sheet", 0.4, 1, 3], ["brick", 0.4, 4, 12], ["rope", 0.3, 1, 2], ["tape", 0.5, 1, 2], ["hammer", 0.35, 1, 1], ["nails", 0.55, 1, 3], ["plank", 0.35, 1, 4], ["wrench", 0.35, 1, 1], ["torch", 0.3, 1, 1], ["oil_can", 0.3, 1, 2], ["jerry_fuel", 0.08, 1, 1]],
	"grocer": [["water_bottle", 0.8, 1, 3], ["soft_drink", 0.8, 2, 6], ["food_can", 0.9, 1, 4], ["long_life", 0.5, 1, 2], ["food_can", 0.4, 1, 3], ["thermos", 0.1, 1, 1]],
	"newsagent": [["radio", 0.2, 1, 1], ["torch", 0.3, 1, 1], ["tape", 0.3, 1, 1], ["binoculars", 0.08, 1, 1], ["thermos", 0.1, 1, 1]],
	"clothes": [["cloth", 0.7, 2, 6], ["shirt_flanno", 0.5, 1, 1], ["pants_jeans", 0.45, 1, 1], ["shirt_tee", 0.6, 1, 3], ["hoodie", 0.4, 1, 1], ["shorts_stubbies", 0.4, 1, 2], ["pants_trackies", 0.35, 1, 1], ["shoes_runners", 0.4, 1, 1], ["thongs", 0.4, 1, 2], ["shirt_singlet", 0.3, 1, 2], ["shirt_work", 0.35, 1, 1], ["pants_cargo", 0.3, 1, 1], ["jacket_army", 0.12, 1, 1],
		["boots_rubber", 0.25, 1, 1], ["pack_small", 0.15, 1, 1], ["gas_mask", 0.03, 1, 1]],
	"sports": [["bat", 0.6, 1, 1], ["knife", 0.4, 1, 1], ["machete", 0.15, 1, 1], ["water_bottle", 0.4, 1, 2], ["gunpowder", 0.5, 1, 3], ["brass", 0.5, 3, 10], ["ammo_12g", 0.55, 6, 20], ["ammo_303", 0.3, 5, 20], ["ammo_762", 0.15, 5, 20], ["binoculars", 0.25, 1, 1], ["pack_small", 0.3, 1, 1], ["pack_large", 0.06, 1, 1],
		["torch", 0.3, 1, 1], ["boots_rubber", 0.2, 1, 1], ["gun_rem870", 0.04, 1, 1], ["gun_hunter", 0.03, 1, 1], ["gun_ruger1022", 0.05, 1, 1], ["gun_lever", 0.03, 1, 1], ["ammo_22", 0.3, 25, 100], ["ammo_44", 0.15, 6, 20]],
	"general": [["water_bottle", 0.5, 1, 2], ["lighter", 0.3, 1, 1], ["soft_drink", 0.5, 1, 4], ["bat", 0.1, 1, 1], ["cloth", 0.4, 1, 3], ["wire", 0.2, 1, 2], ["food_can", 0.6, 1, 3], ["tape", 0.25, 1, 1], ["torch", 0.2, 1, 1], ["bandage", 0.3, 1, 3], ["oil_can", 0.2, 1, 1], ["long_life", 0.25, 1, 1], ["nails", 0.1, 1, 1]],
	"pub": [["bottle", 0.9, 2, 3], ["soft_drink", 0.6, 1, 4], ["water_bottle", 0.4, 1, 2], ["food_can", 0.4, 1, 2], ["thermos", 0.2, 1, 1], ["long_life", 0.2, 1, 1], ["ammo_12g", 0.08, 4, 10]],
	"till": [["car_key", 0.1, 1, 1], ["bandage", 0.2, 1, 2], ["torch", 0.2, 1, 1], ["tape", 0.15, 1, 1], ["radio", 0.06, 1, 1], ["ammo_45", 0.04, 4, 10]],
	"bank": [["ammo_45", 0.4, 6, 24], ["ammo_357", 0.35, 6, 24], ["gun_python", 0.12, 1, 1], ["gun_magnum45", 0.1, 1, 1], ["radio", 0.2, 1, 1], ["torch", 0.2, 1, 1], ["ammo_9mm", 0.3, 10, 34]],
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
	"zombie": ["zombie", [7, 4]], "scav": ["scav", [7, 4]],
	"carparts": ["carparts", [7, 4]], "wreck": ["wreck", [6, 4]], "caravan": ["caravan", [7, 5]],
	"car_boot": ["none", [7, 4]], "car_wagon": ["none", [8, 5]], "car_tray": ["none", [10, 5]],
}
# small enough to pick up and carry (middle mouse) in survival, by Forge key prefix match or mass
const CARRY_MAX_KG := 45.0

static func def(id: String) -> Dictionary:
	if DEFS.has(id): return DEFS[id]
	var k := EngineKit.item_def(id)              # engine kit parts (0.2.55)
	if not k.is_empty(): return k
	var t := TrayGen.item_def(id)                # trays, canopies, tubs (0.2.55)
	if not t.is_empty(): return t
	return {"name": id, "w": 1, "h": 1, "stack": 1, "kind": "misc"}

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
	if Outfit.LOOKS.has(id) or Outfit.MH_ITEMS.has(id): s.data["v"] = randi() % 7     # which colour / cut it is
	if id == "car_battery": s.data["charge"] = randf_range(40.0, 100.0)
	return s

static func new_grid(w: int, h: int) -> Dictionary:
	return {"w": w, "h": h, "items": []}

static func roll_loot(table: String, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	# engine kit parts: on mechanics' and wreckers' shelves, workbenches, sheds and in wrecks (0.2.55)
	var ep := {"carparts": 0.45, "workbench": 0.25, "shed_shelf": 0.12, "wreck": 0.3, "hardware": 0.08, "servo_shelf": 0.1}
	if ep.has(table) and rng.randf() < float(ep[table]):
		out.append(fresh(_engine_part(rng), 1))
	for e in LOOT.get(table, []):
		if rng.randf() < float(e[1]):
			out.append(fresh(e[0], rng.randi_range(int(e[2]), int(e[3]))))
	if out.is_empty() and LOOT.has(table):
		var e: Array = LOOT[table][0]
		out.append(fresh(e[0], rng.randi_range(int(e[2]), int(e[3]))))
	return out

## A loose engine part, weighted toward the small stuff (blocks are rare: they're mostly in cars)
static func _engine_part(rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	if r < 0.16: return "alternator"
	if r < 0.28: return "ign_dizzy"
	if r < 0.38: return EngineKit.fuel_id(["carby", "carby", "tb", "mech", "epump"][rng.randi() % 5])
	if r < 0.50: return EngineKit.ecu_id(rng.randf() < 0.35, [3, 4, 4, 6, 6, 8][rng.randi() % 6])
	if r < 0.62: return EngineKit.exhaust_id([3, 4, 4, 6][rng.randi() % 4])
	if r < 0.72: return EngineKit.intake_id(["i3", "i4", "i6", "v6", "v8"][rng.randi() % 5])
	if r < 0.92: return EngineKit.head_id([3, 4, 4, 6][rng.randi() % 4], ["flat", "push", "push", "sohc", "dohc"][rng.randi() % 5], ["lo", "med", "med", "hi"][rng.randi() % 4])
	if r < 0.97: return "laptop"
	return EngineKit.block_id(["i3", "i4", "i6", "v6", "v8"][rng.randi() % 5], rng.randf() < 0.4)
