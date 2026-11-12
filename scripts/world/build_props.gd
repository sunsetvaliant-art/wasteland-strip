class_name BuildProps
extends RefCounted
## Furnishes a BuildGen building room by room: what a room is decides what goes in it, and each thing finds a spot
## against a wall, in a corner, in the middle or on top of something else, clear of doors (and of windows, for tall
## things). Cupboards, fridges, wardrobes, shelves and benches are loot containers (meta "container").
## Poly Haven models for the furniture; fridges, kitchen benches, baths, toilets, vanities, tubs, workbenches and
## pallet racking are built here from boxes.

const PH := "res://assets/ph/"
# key: [model path, height to scale it to, container key ("" for none), solid]
const CAT := {
	"sofa": [PH + "interior/sofa_02/sofa_02.gltf", 0.75, "", true],
	"sofa1": [PH + "world/Sofa_01/Sofa_01.gltf", 0.8, "", true],
	"armchair": [PH + "interior/modern_arm_chair_01/modern_arm_chair_01.gltf", 0.95, "", true],
	"coffee": [PH + "interior/coffee_table_round_01/coffee_table_round_01.gltf", 0.45, "", true],
	"tv": [PH + "interior/television_02/television_02.gltf", 0.42, "", false],
	"tvcab": [PH + "interior/painted_wooden_cabinet/painted_wooden_cabinet.gltf", 0.75, "drawers", true],
	"bookshelf": [PH + "interior/wooden_bookshelf_worn/wooden_bookshelf_worn.gltf", 1.95, "bookshelf", true],
	"fan": [PH + "interior/ceiling_fan/ceiling_fan.gltf", 0.45, "", false],
	"stove": [PH + "interior/electric_stove/electric_stove.gltf", 0.9, "kitchen", true],
	"kettle": [PH + "interior/vintage_electric_kettle/vintage_electric_kettle.gltf", 0.26, "", false],
	"ktable": [PH + "interior/wooden_table_02/wooden_table_02.gltf", 0.76, "", true],
	"dtable": [PH + "interior/painted_wooden_table/painted_wooden_table.gltf", 0.76, "", true],
	"dchair": [PH + "interior/dining_chair_02/dining_chair_02.gltf", 0.95, "", true],
	"pchair": [PH + "interior/painted_wooden_chair_01/painted_wooden_chair_01.gltf", 0.92, "", true],
	"pantry": [PH + "interior/painted_wooden_shelves/painted_wooden_shelves.gltf", 1.15, "pantry", true],
	"dresser": [PH + "world/vintage_cabinet_01/vintage_cabinet_01.gltf", 2.0, "pantry", true],
	"wardrobe": [PH + "interior/painted_wooden_cabinet_02/painted_wooden_cabinet_02.gltf", 2.0, "wardrobe", true],
	"nightstand": [PH + "interior/painted_wooden_nightstand/painted_wooden_nightstand.gltf", 0.6, "nightstand", true],
	"drawers": [PH + "interior/drawer_cabinet/drawer_cabinet.gltf", 1.3, "drawers", true],
	"drawers2": [PH + "interior/vintage_wooden_drawer_01/vintage_wooden_drawer_01.gltf", 0.95, "drawers", true],
	"bed": [PH + "world/old_bed_frame/old_bed_frame.gltf", 1.05, "", true],
	"daybed": [PH + "interior/vintage_day_bed/vintage_day_bed.gltf", 0.95, "", true],
	"shelf": [PH + "interior/steel_frame_shelves_02/steel_frame_shelves_02.gltf", 2.0, "shed_shelf", true],
	"shelf_wide": [PH + "world/steel_frame_shelves_01/steel_frame_shelves_01.gltf", 2.0, "shed_shelf", true],
	"rack": [PH + "world/worn_metal_rack/worn_metal_rack.gltf", 1.85, "shed_shelf", true],
	"toolcart": [PH + "tools/tool_cart/tool_cart.gltf", 0.95, "tools", true],
	"toolchest": [PH + "tools/metal_tool_chest/metal_tool_chest.gltf", 1.0, "tools", true],
	"scart": [PH + "interior/industrial_storage_cart/industrial_storage_cart.gltf", 1.3, "crate", true],
	"compost": [PH + "interior/compost_bags/compost_bags.gltf", 0.7, "", true],
	"cement": [PH + "interior/cement_bag/cement_bag.gltf", 0.18, "", false],
	"tub_box": [PH + "interior/plastic_container/plastic_container.gltf", 0.45, "laundry", true],
	"lamp_ind": [PH + "interior/hanging_industrial_lamp/hanging_industrial_lamp.gltf", 0.9, "", false],
	"fluoro": [PH + "interior/mounted_fluorescent_lights/mounted_fluorescent_lights.gltf", 0.05, "", false],
	"stool": [PH + "interior/metal_stool_01/metal_stool_01.gltf", 0.75, "", true],
	"schoolchair": [PH + "interior/SchoolChair_01/SchoolChair_01.gltf", 0.95, "", true],
	"desk": [PH + "world/metal_office_desk/metal_office_desk.gltf", 0.77, "office", true],
	"bottle": [PH + "interior/plastic_bottle_gallon/plastic_bottle_gallon.gltf", 0.27, "", false],
	"side_table": [PH + "interior/side_table_01/side_table_01.gltf", 0.55, "", true],
	"clock": [PH + "interior/wall_clock/wall_clock.gltf", 0.3, "", false],
	"picture": [PH + "interior/hanging_picture_frame_02/hanging_picture_frame_02.gltf", 0.5, "", false],
	"outdoor_set": [PH + "interior/outdoor_table_chair_set_01/outdoor_table_chair_set_01.gltf", 0.86, "", true],
	"boombox": [PH + "interior/boombox/boombox.gltf", 0.3, "", false],
	"drum": [PH + "world/Barrel_01/Barrel_01.gltf", 0.88, "", true],
	"drum2": [PH + "world/barrel_03/barrel_03.gltf", 0.92, "", true],
	"lpg": [PH + "world/propane_tank/propane_tank.gltf", 0.55, "", true],
	"generator": [PH + "tools/portable_generator/portable_generator.gltf", 0.6, "", true],
	"vice": [PH + "tools/bench_vice_01/bench_vice_01.gltf", 0.2, "", false],
	"welder": [PH + "tools/portable_welding_cart/portable_welding_cart.gltf", 1.1, "", true],
	"compressor": [PH + "tools/old_military_compressor/old_military_compressor.gltf", 0.9, "", true],
	"crate": [PH + "world/wooden_crate_02/wooden_crate_02.gltf", 0.46, "crate", true],
	"crate_s": [PH + "world/wooden_crate_01/wooden_crate_01.gltf", 0.35, "crate", true],
	"jerry": [PH + "carparts/metal_jerrycan/metal_jerrycan.gltf", 0.46, "jerry", true],
	"tyre": [PH + "carparts/old_tyre/old_tyre.gltf", 0.7, "", true],
	"trashbag": [PH + "world/trashbag/trashbag.gltf", 0.55, "trashbag", false],
	"cardboard": [PH + "world/cardboard_box_01/cardboard_box_01.gltf", 0.34, "cardboard_box_01", true],
	"monobloc": [PH + "world/plastic_monobloc_chair_01/plastic_monobloc_chair_01.gltf", 0.86, "", true],
	"handtruck": [PH + "world/hand_truck/hand_truck.gltf", 1.3, "", true],
	"mil_crate": [PH + "weapons/wooden_military_crate/wooden_military_crate.gltf", 0.46, "wooden_military_crate", true],
	"servo_rack": [PH + "world/worn_metal_rack/worn_metal_rack.gltf", 1.85, "servo_shelf", true],
	"servo_shelf": [PH + "interior/steel_frame_shelves_02/steel_frame_shelves_02.gltf", 2.0, "servo_shelf", true],
	"counter": [PH + "world/metal_office_desk/metal_office_desk.gltf", 0.9, "office", true],
	# shop shelving: the same shelves, what's on them depends on the shop
	"chem_shelf": [PH + "interior/steel_frame_shelves_02/steel_frame_shelves_02.gltf", 2.0, "chemist", true],
	"hw_rack": [PH + "world/worn_metal_rack/worn_metal_rack.gltf", 1.85, "hardware", true],
	"hw_shelf": [PH + "world/steel_frame_shelves_01/steel_frame_shelves_01.gltf", 2.0, "hardware", true],
	"grocer_shelf": [PH + "interior/steel_frame_shelves_02/steel_frame_shelves_02.gltf", 2.0, "grocer", true],
	"grocer_rack": [PH + "world/worn_metal_rack/worn_metal_rack.gltf", 1.85, "grocer", true],
	"news_shelf": [PH + "interior/wooden_bookshelf_worn/wooden_bookshelf_worn.gltf", 1.95, "newsagent", true],
	"clothes_shelf": [PH + "interior/painted_wooden_shelves/painted_wooden_shelves.gltf", 1.6, "clothes", true],
	"clothes_cab": [PH + "interior/painted_wooden_cabinet_02/painted_wooden_cabinet_02.gltf", 2.0, "clothes", true],
	"sports_rack": [PH + "world/worn_metal_rack/worn_metal_rack.gltf", 1.85, "sports", true],
	"gen_shelf": [PH + "world/steel_frame_shelves_01/steel_frame_shelves_01.gltf", 2.0, "general", true],
	"bar_shelf": [PH + "interior/painted_wooden_shelves/painted_wooden_shelves.gltf", 1.6, "pub", true],
	"shop_counter": [PH + "world/metal_office_desk/metal_office_desk.gltf", 0.95, "till", true],
	"bank_desk": [PH + "world/metal_office_desk/metal_office_desk.gltf", 0.77, "office", true],
}
# built here, not models: [width, depth, height, container]
const FIX := {
	"fridge": [0.72, 0.7, 1.75, "fridge"], "bath": [1.7, 0.76, 0.55, ""], "toilet": [0.42, 0.7, 0.8, ""],
	"vanity": [0.8, 0.48, 0.86, "bathroom"], "ltub": [0.62, 0.56, 0.9, ""], "wbench": [2.0, 0.75, 0.9, "workbench"],
	"pallet_rack": [2.7, 1.0, 3.6, "rack"], "vat": [2.4, 1.3, 1.5, ""], "bench_low": [1.6, 0.6, 0.9, "kitchen"],
	"safe": [0.75, 0.7, 1.1, "bank"],
	# the mall
	"gondola": [3.6, 1.1, 1.75, "super"], "gondola_gen": [3.6, 1.1, 1.75, "general"], "checkout": [2.2, 0.9, 1.0, "till"],
	"chiller": [3.0, 0.95, 2.0, "grocer"], "trolley": [0.62, 0.95, 1.0, ""], "planter": [1.8, 1.8, 0.65, ""], "mall_bench": [1.9, 0.6, 0.48, ""],
	"mall_bin": [0.55, 0.55, 0.95, ""], "directory": [1.2, 0.35, 2.1, ""], "atm": [0.75, 0.6, 1.7, "till"], "gumball": [0.45, 0.45, 1.25, ""],
	"kiosk": [2.6, 1.4, 2.5, "general"], "fc_counter": [2.6, 0.75, 1.05, "grocer"], "clothes_rack": [1.5, 0.55, 1.45, "clothes"],
	"mannequin": [0.5, 0.35, 1.8, ""], "sec_desk": [1.8, 0.8, 0.95, "security"], "bar": [3.2, 0.7, 1.05, "pub"], "drinks_fridge": [0.9, 0.7, 1.95, "grocer"],
}

# what goes in each kind of room: [key (a|b = one of), where, chance]
#   wall: back to a wall (tall: kept off windows)   corner: in a corner   center: out in the room
#   ceiling: hung from it   on:K on top of K   front:K in front of K   chairs:K round K   bench: the kitchen bench run
#   high: hung on a wall
const RULES := {
	"lounge": [["sofa|sofa1", "wall", 1.0], ["coffee", "front:sofa", 0.8], ["armchair", "corner", 0.8], ["tvcab", "wall", 0.85], ["tv", "on:tvcab", 0.9],
		["bookshelf", "wall", 0.5], ["fan", "ceiling", 0.6], ["picture", "high", 0.8], ["clock", "high", 0.4], ["side_table", "corner", 0.4], ["boombox", "on:side_table", 0.4]],
	"kitchen": [["bench", "bench", 1.0], ["fridge", "wall", 1.0], ["pantry|dresser", "wall", 0.8], ["ktable", "center", 0.75], ["dchair|pchair", "chairs:ktable", 1.0],
		["kettle", "on:bench", 0.8], ["bottle", "on:bench", 0.4], ["trashbag", "corner", 0.5], ["fluoro", "ceiling", 0.5], ["clock", "high", 0.5]],
	"dining": [["dtable|ktable", "center", 1.0], ["dchair|pchair", "chairs:dtable|ktable", 1.0], ["dresser|pantry", "wall", 0.8], ["picture", "high", 0.7], ["fan", "ceiling", 0.4]],
	"bed": [["bed|daybed", "wall", 1.0], ["nightstand", "beside:bed|daybed", 0.85], ["wardrobe", "wall", 0.8], ["drawers|drawers2", "wall", 0.75], ["fan", "ceiling", 0.5],
		["picture", "high", 0.5], ["cardboard", "corner", 0.3]],
	"bath": [["bath", "wall", 1.0], ["toilet", "wall", 0.9], ["vanity", "wall", 1.0]],
	"toilet": [["toilet", "wall", 1.0], ["vanity", "wall", 0.8]],
	"laundry": [["ltub", "wall", 1.0], ["tub_box", "wall", 0.7], ["pantry", "wall", 0.6], ["bottle", "on:pantry", 0.5], ["trashbag", "corner", 0.4]],
	"hall": [["side_table", "wall", 0.4], ["picture", "high", 0.6]],
	"study": [["desk", "wall", 1.0], ["schoolchair", "front:desk", 1.0], ["bookshelf", "wall", 0.8]],
	"office": [["desk", "wall", 1.0], ["schoolchair", "front:desk", 1.0], ["pantry|bookshelf", "wall", 0.7], ["cardboard", "corner", 0.6], ["fluoro", "ceiling", 0.9], ["clock", "high", 0.5]],
	"lunch": [["ktable", "center", 1.0], ["monobloc|pchair", "chairs:ktable", 1.0], ["fridge", "wall", 1.0], ["bench_low", "wall", 0.9], ["kettle", "on:bench_low", 0.8], ["fluoro", "ceiling", 0.8]],
	"shed": [["wbench", "wall", 1.0], ["vice", "on:wbench", 0.8], ["shelf|rack|shelf_wide", "wall", 1.0], ["shelf|rack", "wall", 0.8], ["toolcart|toolchest", "wall", 0.7],
		["drum|drum2", "corner", 0.8], ["drum|drum2", "corner", 0.5], ["jerry", "wall", 0.6], ["compost", "corner", 0.5], ["tyre", "corner", 0.6], ["lpg", "wall", 0.4],
		["generator", "wall", 0.4], ["crate|crate_s", "wall", 0.6], ["cement", "on:crate|crate_s", 0.4], ["lamp_ind", "ceiling", 0.7], ["handtruck", "wall", 0.3]],
	"store": [["shelf|rack", "wall", 1.0], ["shelf|rack", "wall", 0.8], ["crate|crate_s", "corner", 0.7], ["cardboard", "corner", 0.6], ["jerry", "wall", 0.5], ["mil_crate", "corner", 0.15]],
	"workshop": [["shelf_wide", "rows1", 0.6], ["wbench", "wall", 1.0], ["wbench", "wall", 0.7], ["vice", "on:wbench", 0.9], ["shelf_wide|shelf", "wall", 1.0], ["shelf_wide|rack", "wall", 1.0], ["shelf|rack", "wall", 0.7],
		["welder", "wall", 0.6], ["compressor", "wall", 0.6], ["toolchest", "wall", 0.8], ["toolcart", "center", 0.6], ["drum|drum2", "corner", 0.9], ["drum|drum2", "corner", 0.7],
		["scart", "center", 0.5], ["tyre", "corner", 0.6], ["crate", "wall", 0.6], ["lamp_ind", "ceiling", 1.0], ["generator", "wall", 0.4], ["jerry", "wall", 0.6]],
	"warehouse": [["pallet_rack", "rows", 1.0], ["handtruck", "center", 0.6], ["crate", "center", 0.8], ["crate", "center", 0.6], ["drum|drum2", "corner", 0.8],
		["scart", "center", 0.5], ["lamp_ind", "ceiling", 1.0], ["mil_crate", "corner", 0.2]],
	"machinery": [["drum|drum2", "corner", 0.9], ["drum|drum2", "corner", 0.7], ["tyre", "wall", 0.8], ["tyre", "corner", 0.6], ["shelf|rack", "wall", 0.6], ["jerry", "wall", 0.7],
		["wbench", "wall", 0.5], ["compost", "corner", 0.5], ["generator", "wall", 0.3]],
	"milking": [["drum|drum2", "corner", 0.8], ["shelf|rack", "wall", 0.7], ["crate", "wall", 0.5], ["ltub", "wall", 0.7], ["lamp_ind", "ceiling", 0.8]],
	"vat": [["vat", "center", 1.0], ["drum", "corner", 0.5]],
	"servo_shop": [["counter", "wall", 1.0], ["servo_rack|servo_shelf", "wall", 1.0], ["servo_rack|servo_shelf", "wall", 1.0], ["servo_rack|servo_shelf", "wall", 0.9],
		["servo_shelf", "center", 0.8], ["fridge", "wall", 1.0], ["fridge", "wall", 0.8], ["cardboard", "corner", 0.7], ["trashbag", "corner", 0.5], ["fluoro", "ceiling", 0.9]],
	"servo_bay": [["wbench", "wall", 1.0], ["vice", "on:wbench", 0.8], ["shelf_wide|rack", "wall", 1.0], ["toolchest", "wall", 0.9], ["tyre", "corner", 0.9], ["tyre", "corner", 0.7],
		["drum|drum2", "corner", 0.9], ["jerry", "wall", 0.9], ["jerry", "wall", 0.6], ["compressor", "wall", 0.5], ["lamp_ind", "ceiling", 0.8]],
	"under": [["wbench", "wall", 0.8], ["rack|shelf", "wall", 0.7], ["ltub", "wall", 0.6], ["sofa1", "wall", 0.3], ["tyre", "corner", 0.5], ["jerry", "wall", 0.4],
		["outdoor_set", "center", 0.4], ["drum", "corner", 0.4], ["crate_s", "corner", 0.5]],
}

# light enough to pick up and carry (middle mouse): kg
const CARRY := {"dchair": 6.0, "pchair": 5.0, "schoolchair": 6.0, "monobloc": 3.0, "stool": 5.0, "side_table": 8.0, "kettle": 1.0,
	"bottle": 2.0, "boombox": 3.0, "tyre": 12.0, "crate_s": 6.0, "cardboard": 4.0, "tub_box": 3.0, "cement": 20.0, "lpg": 12.0,
	"coffee": 12.0, "nightstand": 12.0, "trolley": 15.0, "mall_bin": 9.0, "gumball": 14.0, "drum2": 18.0, "jerry": 4.0, "toolcart": 25.0, "handtruck": 14.0, "compost": 20.0}
static var _dims := {}   # model key -> [scale, AABB (unscaled)]
static var pending: Array = []   # [node, key, offset, plan]: models still to be put in (a few each frame)

## Put in the models still waiting, for up to `budget_us` microseconds
static var batches := {}        # Props holder id -> {"holder", "left", "items": [[key, Transform3D]]}: fixtures waiting to be merged
static var _fix_mesh := {}      # fixture key -> its mesh (they're all the same)
const BATCH := 48
static var _nomerge := OS.get_environment("PROPS_NOMERGE") != ""

static func work(budget_us: int) -> void:
	var t0 := Time.get_ticks_usec()
	while not pending.is_empty() and Time.get_ticks_usec() - t0 < budget_us:
		var job: Array = pending.pop_front()
		var node = job[0]
		var hid: int = job[4]
		if not is_instance_valid(node):
			batches.erase(hid)
			continue
		var key: String = job[1]
		var bt: Dictionary = batches.get(hid, {})
		if FIX.has(key) and not _nomerge and key != "vat" and not (node is RigidBody3D) and not bt.is_empty():
			# a fixture that stays put: its mesh goes into one shared mesh for the building (a draw call per material,
			# not per shelf), a batch at a time
			bt.items.append([key, (node as Node3D).transform * Transform3D(Basis(), job[2])])
		else:
			var vis := _make(key, job[3])
			vis.position = job[2]
			if not job[5]:
				# indoors the sun's shadows off the furniture aren't worth a draw call in every shadow split
				for gi in vis.find_children("*", "GeometryInstance3D", true, false):
					(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(node as Node3D).add_child(vis)
			if key == "bed":
				var bb: AABB = dims("bed")[1]
				var g := BuildGen.Geo.new()
				g.aabb("fabric:white", Vector3(-bb.size.x / 2 + 0.06, 0.42, -bb.size.z / 2 + 0.12), Vector3(bb.size.x / 2 - 0.06, 0.6, bb.size.z / 2 - 0.12), false)
				g.aabb("fabric:blue", Vector3(-bb.size.x / 2 + 0.06, 0.6, -bb.size.z / 2 + 0.6), Vector3(bb.size.x / 2 - 0.06, 0.64, bb.size.z / 2 - 0.15), false)
				g.aabb("fabric:white", Vector3(-bb.size.x / 2 + 0.15, 0.6, -bb.size.z / 2 + 0.15), Vector3(bb.size.x / 2 - 0.15, 0.72, -bb.size.z / 2 + 0.5), false)
				var mi := MeshInstance3D.new()
				mi.mesh = g.commit()
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				(node as Node3D).add_child(mi)
		if not bt.is_empty():
			bt.left -= 1
			if bt.items.size() >= BATCH or bt.left <= 0:
				_flush(bt)
			if bt.left <= 0:
				batches.erase(hid)

## Merge a batch of fixtures into one mesh under the building's Props node
static func _flush(bt: Dictionary) -> void:
	if bt.items.is_empty() or not is_instance_valid(bt.holder):
		bt.items.clear()
		return
	var sts := {}
	for it in bt.items:
		var key: String = it[0]
		if not _fix_mesh.has(key):
			var tmp := _fixture(key, {})
			_fix_mesh[key] = (tmp.get_child(0) as MeshInstance3D).mesh
			tmp.free()
		var m: ArrayMesh = _fix_mesh[key]
		for si in m.get_surface_count():
			var mk := m.surface_get_name(si)
			if not sts.has(mk):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				sts[mk] = st
			(sts[mk] as SurfaceTool).append_from(m, si, it[1])
	var am := ArrayMesh.new()
	for mk in sts:
		(sts[mk] as SurfaceTool).commit(am)
		am.surface_set_material(am.get_surface_count() - 1, BuildGen.mat(mk))
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 150.0
	mi.visibility_range_end_margin = 10.0
	(bt.holder as Node3D).add_child(mi)
	bt.items.clear()

# ------------------------------------------------------------------------------------------------ a room being furnished
class Room:
	var x0: float
	var z0: float
	var x1: float
	var z1: float
	var fy: float
	var h: float
	var r: Dictionary
	var taken: Array = []      # Rect2 in (x, z)
	var placed := {}           # key -> [Node3D, Rect2, top y]

	func fits(rc: Rect2) -> bool:
		if rc.position.x < x0 - 0.001 or rc.position.y < z0 - 0.001 or rc.end.x > x1 + 0.001 or rc.end.y > z1 + 0.001:
			return false
		for t in taken:
			if (t as Rect2).grow(-0.01).intersects(rc):
				return false
		return true

## What a shop's got in it, by what kind of shop it is: the shelving's loot is that shop's
const SHOP_SHELF := {"chemist": "chem_shelf", "hardware": "hw_rack|hw_shelf", "grocer": "grocer_shelf|grocer_rack", "cafe": "grocer_shelf",
	"newsagent": "news_shelf|gen_shelf", "clothes": "clothes_shelf|clothes_cab", "sports": "sports_rack", "general": "gen_shelf|grocer_shelf", "pub": "bar_shelf", "bank": "bank_desk"}

static func _rules(p: Dictionary, r: Dictionary) -> Array:
	if MALL_RULES.has(r.type) and p.kind == "mall":
		return MALL_RULES[r.type]
	if r.type not in ["shop", "unit"]:
		return RULES.get(r.type, [])
	var sub: String = r.get("sub", p.get("sub", "general"))
	if sub == "bottlo":
		return [["shop_counter", "wall", 1.0], ["drinks_fridge", "wall", 1.0], ["drinks_fridge", "wall", 1.0], ["drinks_fridge", "wall", 0.8],
			["bar_shelf", "wall", 1.0], ["bar_shelf", "center", 0.8], ["cardboard", "corner", 0.7], ["fluoro", "ceiling", 1.0]]
	if sub == "clothes" and p.kind == "mall":
		return [["shop_counter", "wall", 1.0], ["clothes_rack", "center", 1.0], ["clothes_rack", "center", 1.0], ["clothes_rack", "center", 0.8],
			["clothes_shelf", "wall", 1.0], ["mannequin", "wall", 0.8], ["mannequin", "corner", 0.6], ["fluoro", "ceiling", 1.0]]
	var sh: String = SHOP_SHELF.get(sub, "gen_shelf")
	match sub:
		"pub":
			return [["bar", "wall", 1.0], [sh, "wall", 1.0], [sh, "wall", 0.8], ["dtable|ktable", "center", 1.0], ["dchair|pchair", "chairs:dtable|ktable", 1.0],
				["ktable", "center", 0.7], ["pchair|stool", "chairs:ktable", 0.9], ["stool", "front:bar", 1.0], ["fridge", "wall", 0.8], ["fan", "ceiling", 0.9],
				["picture", "high", 0.7], ["clock", "high", 0.6], ["trashbag", "corner", 0.4]]
		"cafe":
			return [["shop_counter", "wall", 1.0], ["drinks_fridge", "wall", 1.0], [sh, "wall", 0.8], ["ktable", "center", 1.0], ["pchair|dchair|monobloc", "chairs:ktable", 1.0],
				["dtable", "center", 0.7], ["pchair|monobloc", "chairs:dtable", 0.9], ["fan", "ceiling", 0.8], ["clock", "high", 0.5], ["trashbag", "corner", 0.5]]
		"bank":
			return [["shop_counter", "wall", 1.0], ["bank_desk", "wall", 1.0], ["schoolchair", "front:bank_desk", 0.9], ["safe", "corner", 1.0], ["drawers", "wall", 0.6],
				["fluoro", "ceiling", 1.0], ["clock", "high", 0.8], ["picture", "high", 0.5]]
	return [["shop_counter", "wall", 1.0], [sh, "wall", 1.0], [sh, "wall", 1.0], [sh, "wall", 0.9], [sh, "center", 0.8], [sh, "center", 0.6],
		["drinks_fridge" if sub in ["grocer", "general"] else "cardboard", "wall", 0.8], ["cardboard", "corner", 0.6], ["trashbag", "corner", 0.4],
		["fluoro", "ceiling", 1.0], ["fan", "ceiling", 0.4], ["clock", "high", 0.4]]

const MALL_RULES := {
	"carpark": [["trolley", "center", 0.9], ["trolley", "center", 0.7], ["trolley", "center", 0.5], ["trashbag", "corner", 0.5], ["cardboard", "corner", 0.4],
		["drum", "corner", 0.3], ["tyre", "corner", 0.3]],
	"dock": [["pallet_rack", "wall", 1.0], ["crate", "wall", 0.8], ["cardboard", "corner", 0.9], ["handtruck", "wall", 0.7], ["trashbag", "corner", 0.7], ["drum2", "corner", 0.5]],
	"lobby": [["planter", "center", 1.0], ["mall_bench", "center", 0.8], ["directory", "wall", 1.0], ["atm", "wall", 0.8], ["trolley", "center", 0.6], ["mall_bin", "wall", 0.7]],
	"concourse": [["planter", "center", 1.0], ["planter", "center", 1.0], ["planter", "center", 0.8], ["mall_bench", "center", 1.0], ["mall_bench", "center", 0.9],
		["mall_bench", "center", 0.7], ["mall_bin", "wall", 1.0], ["mall_bin", "wall", 0.8], ["directory", "wall", 1.0], ["atm", "wall", 0.8], ["gumball", "wall", 0.8],
		["kiosk", "center", 0.8], ["kiosk", "center", 0.5], ["trolley", "center", 0.8], ["trolley", "center", 0.6], ["trashbag", "center", 0.4], ["cardboard", "center", 0.3]],
	"super": [["checkout", "wall", 1.0], ["checkout", "wall", 1.0], ["checkout", "wall", 0.9], ["chiller", "wall", 1.0], ["chiller", "wall", 1.0], ["chiller", "wall", 0.9],
		["drinks_fridge", "wall", 0.9], ["gondola", "rows", 1.0], ["trolley", "center", 0.9], ["trolley", "center", 0.7], ["trolley", "center", 0.5],
		["cardboard", "center", 0.6], ["trashbag", "corner", 0.5], ["fluoro", "ceiling", 1.0]],
	"super_store": [["pallet_rack", "rows", 1.0], ["handtruck", "center", 0.8], ["crate", "center", 0.8], ["cardboard", "corner", 0.9], ["cardboard", "corner", 0.7],
		["chiller", "wall", 0.6], ["lamp_ind", "ceiling", 1.0]],
	"bigbox": [["shop_counter", "wall", 1.0], ["gondola_gen", "rows", 0.8], ["sofa|sofa1", "center", 1.0], ["sofa|sofa1", "center", 0.8], ["bed", "center", 0.8],
		["dtable", "center", 0.7], ["dchair", "chairs:dtable", 0.8], ["tvcab", "wall", 0.9], ["tv", "on:tvcab", 0.9], ["fridge", "wall", 0.9], ["fridge", "wall", 0.7],
		["wardrobe", "wall", 0.6], ["cardboard", "corner", 0.8], ["fluoro", "ceiling", 1.0]],
	"foodcourt": [["ktable", "center", 1.0], ["monobloc|pchair", "chairs:ktable", 1.0], ["dtable", "center", 1.0], ["monobloc|pchair", "chairs:dtable", 1.0],
		["ktable", "center", 1.0], ["monobloc|pchair", "chairs:ktable", 1.0], ["ktable", "center", 1.0], ["monobloc|pchair", "chairs:ktable", 1.0],
		["dtable", "center", 1.0], ["monobloc|pchair", "chairs:dtable", 1.0], ["ktable", "center", 0.9], ["monobloc|pchair", "chairs:ktable", 1.0],
		["ktable", "center", 0.8], ["monobloc|pchair", "chairs:ktable", 1.0], ["dtable", "center", 0.8], ["monobloc|pchair", "chairs:dtable", 1.0],
		["mall_bin", "wall", 1.0], ["mall_bin", "wall", 0.7], ["trashbag", "center", 0.5], ["planter", "corner", 0.6], ["planter", "corner", 0.6],
		["fluoro", "ceiling", 1.0]],
	"fc_kitchen": [["fc_counter", "wall", 1.0], ["bench_low", "wall", 1.0], ["fridge", "wall", 0.9], ["drinks_fridge", "wall", 0.6], ["trashbag", "corner", 0.6]],
	"service": [["shelf|rack", "wall", 1.0], ["cardboard", "corner", 0.8], ["trashbag", "corner", 0.7], ["drum2", "corner", 0.5], ["handtruck", "wall", 0.5]],
	"security": [["sec_desk", "wall", 1.0], ["schoolchair", "front:sec_desk", 1.0], ["drawers", "wall", 0.8], ["pantry", "wall", 0.5], ["fluoro", "ceiling", 1.0]],
	"store": [["shelf|rack", "wall", 1.0], ["shelf|rack", "wall", 0.8], ["cardboard", "corner", 0.9], ["cardboard", "corner", 0.6], ["crate_s", "corner", 0.5]],
	"hall": [["mall_bin", "wall", 0.4]],
	"toilet": [["toilet", "wall", 1.0], ["toilet", "wall", 0.9], ["vanity", "wall", 1.0], ["vanity", "wall", 0.7]],
}

static func furnish(p: Dictionary, root: Node3D, rng: RandomNumberGenerator) -> Array:
	var holder := Node3D.new()
	holder.name = "Props"
	root.add_child(holder)
	var boxes: Array = []
	for f in p.floors:
		for r in f.rooms:
			if r.type in ["void", "stair"]: continue
			var rm := _room(r, float(f.y))
			for rule in _rules(p, r):
				if rng.randf() > float(rule[2]): continue
				var keys: Array = str(rule[0]).split("|")
				_place(rm, keys[rng.randi() % keys.size()], str(rule[1]), holder, rng, boxes, p)
	# under a Queenslander: the junk and the laundry live down there
	if p.get("under", false):
		var w: float = p.w
		var d: float = p.d
		var r := {"x0": -w / 2 + 0.4, "z0": -d / 2 + 0.3, "x1": w / 2 - 0.4, "z1": -d / 2 + 3.4, "type": "under", "h": float(p.raised) - 0.4,
			"ops": {"N": [], "S": [], "W": [], "E": []}}
		var gy: float = p.get("under_y", -float(p.raised))
		var rm := _room(r, gy)
		rm.h = -gy - 0.4
		for rule in RULES["under"]:
			if rng.randf() > float(rule[2]): continue
			var keys: Array = str(rule[0]).split("|")
			_place(rm, keys[rng.randi() % keys.size()], str(rule[1]), holder, rng, boxes, p, true)
	return boxes

static func _room(r: Dictionary, fy: float) -> Room:
	var rm := Room.new()
	rm.r = r
	rm.x0 = float(r.x0) + BuildGen.T_IN
	rm.x1 = float(r.x1) - BuildGen.T_IN
	rm.z0 = float(r.z0) + BuildGen.T_IN
	rm.z1 = float(r.z1) - BuildGen.T_IN
	rm.fy = fy
	rm.h = minf(float(r.h), float(r.get("ceil", r.h)))
	# keep clear in front of doorways and openings
	for side in ["N", "S", "W", "E"]:
		for op in r.ops[side]:
			if op.kind in ["window"]: continue
			var dep := 1.0 if op.kind in ["door", "doorx"] else (float(op.get("recess", 0.0)) + 1.1 if op.kind == "bay" else 0.8)
			var a := float(op.a) - 0.12
			var b := float(op.b) + 0.12
			match side:
				"N": rm.taken.append(Rect2(a, rm.z0, b - a, dep))
				"S": rm.taken.append(Rect2(a, rm.z1 - dep, b - a, dep))
				"W": rm.taken.append(Rect2(rm.x0, a, dep, b - a))
				"E": rm.taken.append(Rect2(rm.x1 - dep, a, dep, b - a))
	return rm

## Size of a thing once scaled, and where its box sits relative to its origin: [scale, AABB scaled]
static func dims(key: String) -> Array:
	if _dims.has(key):
		return _dims[key]
	var out := [1.0, AABB(Vector3(-0.3, 0, -0.3), Vector3(0.6, 1, 0.6))]
	if FIX.has(key):
		var f: Array = FIX[key]
		out = [1.0, AABB(Vector3(-f[0] / 2.0, 0, -f[1] / 2.0), Vector3(f[0], f[2], f[1]))]
	elif CAT.has(key) and ResourceLoader.exists(CAT[key][0]):
		var n: Node3D = (load(CAT[key][0]) as PackedScene).instantiate()
		var bb := WorldItem._aabb(n)
		n.free()
		var k: float = float(CAT[key][1]) / maxf(bb.size.y, 0.01)
		out = [k, AABB(bb.position * k, bb.size * k)]
	_dims[key] = out
	return out

static func _make(key: String, p: Dictionary) -> Node3D:
	if FIX.has(key):
		return _fixture(key, p)
	var c: Array = CAT[key]
	var raw: Node3D = (load(c[0]) as PackedScene).instantiate()
	var dm := dims(key)
	raw.scale = Vector3.ONE * float(dm[0])
	for gi in raw.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).visibility_range_end = 80.0
		(gi as GeometryInstance3D).visibility_range_end_margin = 10.0
	return raw

## Put `key` somewhere sensible by `how`; returns true if it found a spot
static func _place(rm: Room, key: String, how: String, holder: Node3D, rng: RandomNumberGenerator, boxes: Array, p: Dictionary, outdoors := false) -> bool:
	if not CAT.has(key) and not FIX.has(key) and key != "bench":
		return false
	if key == "bench":
		return _bench_run(rm, holder, rng, boxes, p)
	var dm := dims(key)
	var bb: AABB = dm[1]
	var sx := bb.size.x
	var sz := bb.size.z
	var hh := bb.size.y
	var mode := how.split(":")[0]
	var ref := how.split(":")[1] if ":" in how else ""
	var spot := {}       # {pos: Vector2 centre of footprint, yaw, rect, y}
	match mode:
		"wall", "corner":
			spot = _wall_spot(rm, sx, sz, hh, rng, mode == "corner")
		"center":
			for _t in 24:
				var yaw := (PI / 2) * (rng.randi() % 4)
				var ex := sx if is_zero_approx(fmod(yaw, PI)) else sz
				var ez := sz if is_zero_approx(fmod(yaw, PI)) else sx
				var cx := lerpf(rm.x0 + ex / 2 + 0.6, rm.x1 - ex / 2 - 0.6, rng.randf())
				var cz := lerpf(rm.z0 + ez / 2 + 0.6, rm.z1 - ez / 2 - 0.6, rng.randf())
				if rm.x1 - rm.x0 < ex + 1.2: cx = (rm.x0 + rm.x1) / 2
				if rm.z1 - rm.z0 < ez + 1.2: cz = (rm.z0 + rm.z1) / 2
				var rc := Rect2(cx - ex / 2, cz - ez / 2, ex, ez)
				if rm.fits(rc.grow(0.35)) or (rm.fits(rc) and _t > 16):
					spot = {"pos": Vector2(cx, cz), "yaw": yaw, "rect": rc}
					break
		"rows", "rows1":
			# racking in rows down the long way with aisles between, a gap kept clear at each end
			var long_x := (rm.x1 - rm.x0) > (rm.z1 - rm.z0)
			var span := (rm.z1 - rm.z0) if long_x else (rm.x1 - rm.x0)       # across the rows
			var run := (rm.x1 - rm.x0) if long_x else (rm.z1 - rm.z0)        # along a row
			var pitch := sz * 2.0 + 3.2                                        # back-to-back pair + aisle
			var nrows := maxi(1, int((span - 3.0) / pitch)) if mode == "rows" else 1
			var count := 0
			for ri in nrows:
				var c0 := (-span / 2 + 2.0 + pitch * ri + sz) if mode == "rows" else 0.0
				for back in ([-1.0, 1.0] if mode == "rows" else [1.0]):
					var across: float = c0 + back * sz / 2
					var t := -run / 2 + 3.5
					while t + sx < run / 2 - 3.5:
						var cx: float = (rm.x0 + rm.x1) / 2 + (t + sx / 2 if long_x else across)
						var cz: float = (rm.z0 + rm.z1) / 2 + (across if long_x else t + sx / 2)
						var yaw := (0.0 if back > 0 else PI) if long_x else (PI / 2 if back > 0 else -PI / 2)
						var ex := sx if long_x else sz
						var ez := sz if long_x else sx
						var rc := Rect2(cx - ex / 2, cz - ez / 2, ex, ez)
						if rm.fits(rc) and _put(rm, key, {"pos": Vector2(cx, cz), "yaw": yaw, "rect": rc}, holder, boxes, p, outdoors):
							count += 1
						t += sx + 0.05
			return count > 0
		"ceiling":
			spot = {"pos": Vector2((rm.x0 + rm.x1) / 2, (rm.z0 + rm.z1) / 2), "yaw": 0.0, "rect": Rect2(), "y": rm.fy + rm.h - hh}
		"high":
			# on a wall at eye height, clear of openings
			var sides := ["N", "S", "W", "E"]
			sides.shuffle()
			for side in sides:
				var ops: Array = rm.r.ops[side]
				var a := rm.x0 if side in ["N", "S"] else rm.z0
				var b := rm.x1 if side in ["N", "S"] else rm.z1
				var c := lerpf(a + 0.4, b - 0.4, rng.randf())
				var ok := true
				for op in ops:
					if c > float(op.a) - 0.5 and c < float(op.b) + 0.5: ok = false
				if not ok: continue
				var y := rm.fy + 1.55
				match side:
					"N": spot = {"pos": Vector2(c, rm.z0 + sz / 2), "yaw": 0.0}
					"S": spot = {"pos": Vector2(c, rm.z1 - sz / 2), "yaw": PI}
					"W": spot = {"pos": Vector2(rm.x0 + sz / 2, c), "yaw": PI / 2}
					"E": spot = {"pos": Vector2(rm.x1 - sz / 2, c), "yaw": -PI / 2}
				spot["rect"] = Rect2()
				spot["y"] = y
				break
		"on":
			for k in ref.split("|"):
				if rm.placed.has(k):
					var base: Array = rm.placed[k]
					var brc: Rect2 = base[1]
					var bn: Node3D = base[0]
					var off := Vector2(rng.randf_range(-0.25, 0.25) * maxf(brc.size.x - sx, 0.0), rng.randf_range(-0.25, 0.25) * maxf(brc.size.y - sz, 0.0))
					spot = {"pos": brc.get_center() + off, "yaw": bn.rotation.y + rng.randf_range(-0.4, 0.4), "rect": Rect2(), "y": float(base[2])}
					break
		"front", "beside":
			for k in ref.split("|"):
				if not rm.placed.has(k): continue
				var base: Array = rm.placed[k]
				var bn: Node3D = base[0]
				var brc: Rect2 = base[1]
				var fwd := Vector2(sin(bn.rotation.y), cos(bn.rotation.y))
				var right := Vector2(fwd.y, -fwd.x)
				var cands := []
				if mode == "front":
					cands.append([brc.get_center() + fwd * ((brc.size.x if absf(fwd.x) > 0.5 else brc.size.y) / 2 + sz / 2 + 0.45), bn.rotation.y + PI])
				else:
					var half := (brc.size.y if absf(fwd.x) > 0.5 else brc.size.x) / 2
					var back := brc.get_center() - fwd * ((brc.size.x if absf(fwd.x) > 0.5 else brc.size.y) / 2 - sz / 2 - 0.02)
					cands.append([back + right * (half + sx / 2 + 0.05), bn.rotation.y])
					cands.append([back - right * (half + sx / 2 + 0.05), bn.rotation.y])
				for cd in cands:
					var yaw: float = cd[1]
					if mode == "front" and key in ["schoolchair", "pchair", "dchair"]:
						yaw = bn.rotation.y + PI
					var rot := absf(sin(yaw)) > 0.5
					var ex := sz if rot else sx
					var ez := sx if rot else sz
					var c: Vector2 = cd[0]
					var rc := Rect2(c.x - ex / 2, c.y - ez / 2, ex, ez)
					if rm.fits(rc):
						spot = {"pos": c, "yaw": yaw, "rect": rc}
						break
				break
		"chairs":
			for k in ref.split("|"):
				if not rm.placed.has(k): continue
				var base: Array = rm.placed[k]
				var brc: Rect2 = base[1]
				var n := 0
				var ctr := brc.get_center()
				var sides := [[Vector2(0, brc.size.y / 2 + 0.28), PI], [Vector2(0, -brc.size.y / 2 - 0.28), 0.0],
					[Vector2(brc.size.x / 2 + 0.28, 0), -PI / 2], [Vector2(-brc.size.x / 2 - 0.28, 0), PI / 2]]
				var extra := []
				if brc.size.x > 1.5:
					extra = [[Vector2(-brc.size.x / 4, brc.size.y / 2 + 0.28), PI], [Vector2(brc.size.x / 4, brc.size.y / 2 + 0.28), PI],
						[Vector2(-brc.size.x / 4, -brc.size.y / 2 - 0.28), 0.0], [Vector2(brc.size.x / 4, -brc.size.y / 2 - 0.28), 0.0]]
					sides = [sides[2], sides[3]] + extra
				elif brc.size.y > 1.5:
					sides = [sides[0], sides[1],
						[Vector2(brc.size.x / 2 + 0.28, -brc.size.y / 4), -PI / 2], [Vector2(brc.size.x / 2 + 0.28, brc.size.y / 4), -PI / 2],
						[Vector2(-brc.size.x / 2 - 0.28, -brc.size.y / 4), PI / 2], [Vector2(-brc.size.x / 2 - 0.28, brc.size.y / 4), PI / 2]]
				for sd in sides:
					if rng.randf() < 0.15: continue
					var c: Vector2 = ctr + (sd[0] as Vector2)
					var yaw: float = sd[1] + rng.randf_range(-0.25, 0.25)
					var rc := Rect2(c.x - 0.22, c.y - 0.22, 0.44, 0.44)
					if not rm.fits(rc): continue
					var nd := _put(rm, key, {"pos": c, "yaw": yaw, "rect": rc}, holder, boxes, p, outdoors)
					if nd: n += 1
				return n > 0
	if spot.is_empty():
		return false
	return _put(rm, key, spot, holder, boxes, p, outdoors) != null

## A spot against a wall: the thing's back to the wall, facing into the room
static func _wall_spot(rm: Room, sx: float, sz: float, hh: float, rng: RandomNumberGenerator, corner: bool) -> Dictionary:
	var sides := ["N", "S", "W", "E"]
	sides.shuffle()
	for side in sides:
		var along_x: bool = side in ["N", "S"]
		var a := rm.x0 if along_x else rm.z0
		var b := rm.x1 if along_x else rm.z1
		if b - a < sx + 0.1: continue
		var ops: Array = rm.r.ops[side]
		var cands := []
		if corner:
			cands = [a + sx / 2 + 0.03, b - sx / 2 - 0.03]
			cands.shuffle()
		else:
			for _i in 10:
				cands.append(lerpf(a + sx / 2 + 0.05, b - sx / 2 - 0.05, rng.randf()))
		for c in cands:
			var lo: float = c - sx / 2
			var hi: float = c + sx / 2
			var ok := true
			for op in ops:
				if lo < float(op.b) + 0.05 and hi > float(op.a) - 0.05:
					if op.kind == "window" and hh < float(op.y0) - 0.05: continue
					ok = false
					break
			if not ok: continue
			var spot := {}
			match side:
				"N": spot = {"pos": Vector2(c, rm.z0 + sz / 2 + 0.02), "yaw": 0.0, "rect": Rect2(lo, rm.z0, sx, sz + 0.02)}
				"S": spot = {"pos": Vector2(c, rm.z1 - sz / 2 - 0.02), "yaw": PI, "rect": Rect2(lo, rm.z1 - sz - 0.02, sx, sz + 0.02)}
				"W": spot = {"pos": Vector2(rm.x0 + sz / 2 + 0.02, c), "yaw": PI / 2, "rect": Rect2(rm.x0, lo, sz + 0.02, sx)}
				"E": spot = {"pos": Vector2(rm.x1 - sz / 2 - 0.02, c), "yaw": -PI / 2, "rect": Rect2(rm.x1 - sz - 0.02, lo, sz + 0.02, sx)}
			if rm.fits(spot.rect):
				spot["side"] = side
				return spot
	return {}

static func outdoors_on_top(_spot: Dictionary) -> bool:
	return false

## Make the thing and stand it at the spot (its footprint centre at pos, its bottom on the floor or at spot.y)
static func _put(rm: Room, key: String, spot: Dictionary, holder: Node3D, boxes: Array, p: Dictionary, outdoors: bool) -> Node3D:
	var dm := dims(key)
	var bb: AABB = dm[1]
	var solid := true
	var cont := ""
	if CAT.has(key):
		solid = CAT[key][3]
		cont = CAT[key][2]
	elif FIX.has(key):
		cont = FIX[key][3]
	var node: Node3D
	if CARRY.has(key) and not outdoors_on_top(spot):
		# a loose thing: a physics body, asleep (frozen) where it stands until someone picks it up
		var rb := RigidBody3D.new()
		rb.mass = float(CARRY[key])
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		rb.freeze = true
		rb.set_meta("carryable", true)
		rb.add_to_group("carryable")
		var rcs := CollisionShape3D.new()
		var rbs := BoxShape3D.new()
		rbs.size = bb.size.max(Vector3(0.05, 0.05, 0.05))
		rcs.shape = rbs
		rb.add_child(rcs)
		node = rb
	elif solid or cont != "":
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bb.size.max(Vector3(0.05, 0.05, 0.05))
		cs.shape = bs
		cs.position = bb.get_center()
		sb.add_child(cs)
		if not solid:
			sb.collision_layer = 1 << 4         # looked at (for F), not walked into
		node = sb
	else:
		node = Node3D.new()
	# the model itself comes a little later (BuildProps.work), its footprint centred on the node's origin
	var hid := holder.get_instance_id()
	if not batches.has(hid):
		batches[hid] = {"holder": holder, "left": 0, "items": []}
	batches[hid].left += 1
	pending.append([node, key, Vector3(-bb.get_center().x, -bb.position.y, -bb.get_center().z), p, hid, outdoors])
	if node is CollisionObject3D:
		(node.get_child(0) as CollisionShape3D).position = Vector3(0, bb.size.y / 2, 0)
	var y: float = spot.get("y", rm.fy)
	node.position = Vector3(spot.pos.x, y, spot.pos.y)
	node.rotation.y = spot.yaw
	holder.add_child(node)
	if key == "pallet_rack" and absi(hash(Vector2i(roundi(spot.pos.x * 10), roundi(spot.pos.y * 10)))) % 3 != 0:
		cont = ""        # not every bay of racking has anything worth a look
	if cont != "":
		node.set_meta("container", cont)
		node.set_meta("container_name", _nice(key))
		boxes.append(node)
	var rc: Rect2 = spot.get("rect", Rect2())
	if rc.has_area():
		rm.taken.append(rc)
	if not rm.placed.has(key) or rc.has_area():
		var top := y + bb.size.y
		var foot := rc if rc.has_area() else Rect2(spot.pos.x - 0.1, spot.pos.y - 0.1, 0.2, 0.2)
		rm.placed[key] = [node, foot, top]
	if key == "bed":
		rm.placed["bed"][2] = y + 0.64       # (the mattress goes on with the frame)
	return node

static func _nice(key: String) -> String:
	const N := {"tvcab": "cabinet", "pantry": "shelves", "dresser": "dresser", "wardrobe": "wardrobe", "nightstand": "bedside table",
		"drawers": "chest of drawers", "drawers2": "chest of drawers", "shelf": "shelves", "shelf_wide": "shelves", "rack": "rack",
		"toolcart": "tool cart", "toolchest": "tool chest", "scart": "trolley", "tub_box": "tub", "desk": "desk", "crate": "crate", "crate_s": "crate",
		"jerry": "jerry can", "trashbag": "rubbish bag", "cardboard": "box", "mil_crate": "army crate", "stove": "stove", "bookshelf": "bookshelf",
		"fridge": "fridge", "vanity": "bathroom cabinet", "safe": "safe", "bar": "bar", "drinks_fridge": "drinks fridge", "shop_counter": "counter",
		"chem_shelf": "shelves", "gondola": "shelves", "gondola_gen": "shelves", "checkout": "checkout", "chiller": "fridge", "atm": "ATM",
		"kiosk": "kiosk", "fc_counter": "counter", "clothes_rack": "clothes rack", "sec_desk": "security desk", "hw_rack": "rack", "hw_shelf": "shelves", "grocer_shelf": "shelves", "grocer_rack": "rack", "news_shelf": "shelves",
		"clothes_shelf": "shelves", "clothes_cab": "cupboard", "sports_rack": "rack", "gen_shelf": "shelves", "bar_shelf": "shelves", "bank_desk": "desk", "wbench": "workbench", "pallet_rack": "pallet rack", "bench_low": "cupboard", "bench": "kitchen cupboards"}
	return N.get(key, key)

# ------------------------------------------------------------------------------------------------ built-in fixtures
static func _fixture(key: String, p: Dictionary) -> Node3D:
	var f: Array = FIX[key]
	var w: float = f[0]
	var dd: float = f[1]
	var h: float = f[2]
	var g := BuildGen.Geo.new()
	# built centred on x, z; front at +z; bottom at y = 0 (then shifted by _put like a model: bb min y = 0)
	var hw := w / 2
	var hd := dd / 2
	match key:
		"fridge":
			g.aabb("enamel:cream", Vector3(-hw, 0.05, -hd), Vector3(hw, h, hd - 0.04), false)
			g.aabb("enamel:cream", Vector3(-hw + 0.01, 1.12, hd - 0.04), Vector3(hw - 0.01, h - 0.02, hd), false)
			g.aabb("enamel:cream", Vector3(-hw + 0.01, 0.07, hd - 0.04), Vector3(hw - 0.01, 1.1, hd), false)
			g.aabb("steel", Vector3(hw - 0.09, 1.2, hd), Vector3(hw - 0.06, 1.45, hd + 0.04), false)
			g.aabb("steel", Vector3(hw - 0.09, 0.8, hd), Vector3(hw - 0.06, 1.02, hd + 0.04), false)
			g.aabb("dark", Vector3(-hw + 0.03, 0.0, -hd + 0.03), Vector3(hw - 0.03, 0.05, hd - 0.06), false)
		"bench_low":
			_cupboards(g, -hw, hw, -hd, hd, h, false)
		"gondola", "gondola_gen":
			# supermarket shelving, both sides: a spine, shelves stepping in, a few things left on them
			g.aabb("steel", Vector3(-hw, 0, -0.04), Vector3(hw, h, 0.04), false)
			g.aabb("steel:white", Vector3(-hw, 0, -hd), Vector3(hw, 0.12, hd), false)
			for sd in [-1.0, 1.0]:
				for k in 4:
					var sy := 0.12 + k * 0.42
					var dep := hd - 0.05 - k * 0.04
					g.aabb("steel:white", Vector3(-hw, sy, minf(0.0, sd * dep)), Vector3(hw, sy + 0.025, maxf(0.0, sd * dep)), false)
					var seed := absi(hash(Vector3i(k, int(sd), int(w * 10))))
					for j in 7:
						if (seed >> j) & 3 == 0:
							var cx := -hw + 0.25 + j * (w - 0.5) / 6.0
							var col: String = "enamel:" + ["pink", "teal", "yellow", "green", "blue", "white", "cream"][(j + k + seed) % 7]
							g.aabb(col, Vector3(cx - 0.12, sy + 0.025, minf(sd * 0.1, sd * (dep - 0.05))), Vector3(cx + 0.12, sy + 0.025 + 0.18 + (seed % 3) * 0.04, maxf(sd * 0.1, sd * (dep - 0.05))), false)
			g.aabb("steel:white", Vector3(-hw, h - 0.06, -hd), Vector3(hw, h, hd), false)
		"checkout":
			g.aabb("trim:cream", Vector3(-hw, 0, -hd), Vector3(hw - 0.5, h - 0.15, hd), false)
			g.aabb("dark", Vector3(-hw + 0.05, h - 0.15, -hd + 0.1), Vector3(hw - 0.55, h - 0.1, hd - 0.1), false)      # the belt
			g.aabb("steel", Vector3(hw - 0.5, 0, -hd), Vector3(hw, h, hd), false)
			g.aabb("dark", Vector3(hw - 0.42, h, -0.15), Vector3(hw - 0.08, h + 0.25, 0.15), false)                     # the register
			g.aabb("steel", Vector3(-hw + 0.2, h - 0.15, -hd - 0.02), Vector3(-hw + 0.25, h + 0.9, -hd + 0.02), false)
			g.aabb("enamel:red", Vector3(-hw + 0.1, h + 0.75, -hd - 0.03), Vector3(-hw + 0.35, h + 0.95, -hd + 0.03), false) # lane number
		"chiller":
			g.aabb("enamel:white", Vector3(-hw, 0, -hd), Vector3(hw, h, -hd + 0.25), false)
			g.aabb("enamel:white", Vector3(-hw, 0, -hd), Vector3(hw, 0.45, hd), false)
			g.aabb("dark", Vector3(-hw + 0.05, 0.45, -hd + 0.25), Vector3(hw - 0.05, h - 0.3, hd - 0.1), false)
			for k in 3:
				g.aabb("steel", Vector3(-hw + 0.05, 0.85 + k * 0.4, -hd + 0.25), Vector3(hw - 0.05, 0.87 + k * 0.4, hd - 0.2 - k * 0.1), false)
			g.aabb("enamel:white", Vector3(-hw, h - 0.3, -hd), Vector3(hw, h, hd - 0.3), false)
			g.aabb("enamel:blue", Vector3(-hw, h - 0.3, hd - 0.32), Vector3(hw, h - 0.05, hd - 0.28), false)
			for sx in [-hw, hw - 0.04]:
				g.aabb("enamel:white", Vector3(sx, 0, -hd), Vector3(sx + 0.04, h, hd - 0.1), false)
		"trolley":
			g.aabb("steel", Vector3(-hw, 0.35, -hd + 0.1), Vector3(hw, 0.38, hd), false)
			for sx in [-hw, hw - 0.02]:
				g.aabb("steel", Vector3(sx, 0.35, -hd + 0.1), Vector3(sx + 0.02, h - 0.1, hd), false)
			g.aabb("steel", Vector3(-hw, 0.35, hd - 0.02), Vector3(hw, h - 0.1, hd), false)
			g.aabb("steel", Vector3(-hw + 0.05, 0.35, -hd + 0.1), Vector3(hw - 0.05, h - 0.15, -hd + 0.12), false)
			g.aabb("enamel:red", Vector3(-hw - 0.02, h - 0.05, -hd), Vector3(hw + 0.02, h, -hd + 0.05), false)          # the handle
			for sx in [-hw + 0.03, hw - 0.07]:
				for sz in [-hd + 0.15, hd - 0.08]:
					g.aabb("steel", Vector3(sx, 0.08, sz), Vector3(sx + 0.03, 0.35, sz + 0.03), false)
					g.aabb("dark", Vector3(sx - 0.01, 0.0, sz - 0.03), Vector3(sx + 0.04, 0.09, sz + 0.06), false)
		"planter":
			g.aabb("brick", Vector3(-hw, 0, -hd), Vector3(hw, h, hd), false)
			g.aabb("trim:cream", Vector3(-hw - 0.03, h, -hd - 0.03), Vector3(hw + 0.03, h + 0.05, hd + 0.03), false)
			g.aabb("dirt", Vector3(-hw + 0.1, h - 0.05, -hd + 0.1), Vector3(hw - 0.1, h + 0.02, hd - 0.1), false)
			# a dead palm in it
			g.aabb("timber:tan", Vector3(-0.1, h, -0.1), Vector3(0.1, h + 2.4, 0.1), false)
			for k in 5:
				var a := TAU * k / 5.0
				var tip := Vector3(cos(a) * 1.1, h + 1.9, sin(a) * 1.1)
				ShopGen._rod(g, Vector3(0, h + 2.4, 0), tip, 0.06, "timber:tan")
		"mall_bench":
			g.aabb("steel", Vector3(-hw, 0, -0.04), Vector3(-hw + 0.08, h, 0.04), false)
			g.aabb("steel", Vector3(hw - 0.08, 0, -0.04), Vector3(hw, h, 0.04), false)
			g.aabb("timber", Vector3(-hw, h - 0.06, -hd), Vector3(hw, h, hd), false)
		"mall_bin":
			g.aabb("steel:charcoal", Vector3(-hw, 0, -hd), Vector3(hw, h, hd), false)
			g.aabb("dark", Vector3(-hw + 0.06, h - 0.25, hd), Vector3(hw - 0.06, h - 0.1, hd + 0.005), false)
		"directory":
			g.aabb("steel:charcoal", Vector3(-hw, 0, -hd), Vector3(hw, h, hd), false)
			g.aabb("enamel:cream", Vector3(-hw + 0.08, 0.6, hd), Vector3(hw - 0.08, h - 0.15, hd + 0.01), false)
			for k in 8:
				g.aabb("enamel:" + ["blue", "pink", "green", "yellow"][k % 4], Vector3(-hw + 0.15 + (k % 2) * 0.48, 0.75 + (k / 2) * 0.32, hd + 0.01), Vector3(-hw + 0.55 + (k % 2) * 0.48, 0.95 + (k / 2) * 0.32, hd + 0.015), false)
			g.aabb("enamel:red", Vector3(-0.04, 1.3, hd + 0.015), Vector3(0.04, 1.38, hd + 0.02), false)
		"atm":
			g.aabb("steel:charcoal", Vector3(-hw, 0, -hd), Vector3(hw, h, hd - 0.15), false)
			g.aabb("steel", Vector3(-hw, 0, hd - 0.15), Vector3(hw, 0.9, hd), false)
			g.aabb("dark", Vector3(-hw + 0.12, 1.1, hd - 0.16), Vector3(hw - 0.12, 1.45, hd - 0.14), false)
			g.aabb("enamel:green", Vector3(-hw, h - 0.2, hd - 0.16), Vector3(hw, h, hd - 0.13), false)
		"gumball":
			g.aabb("enamel:red", Vector3(-0.12, 0, -0.12), Vector3(0.12, 0.85, 0.12), false)
			g.aabb("glass", Vector3(-hw, 0.85, -hd), Vector3(hw, h - 0.05, hd), false)
			g.aabb("enamel:red", Vector3(-hw, h - 0.05, -hd), Vector3(hw, h, hd), false)
			for k in 12:
				var gx := -hw + 0.08 + (k % 4) * 0.09
				var gz := -hd + 0.1 + (k / 4) * 0.12
				g.aabb("enamel:" + ["yellow", "pink", "teal", "blue", "green"][k % 5], Vector3(gx, 0.86, gz), Vector3(gx + 0.06, 0.92 + (k % 3) * 0.04, gz + 0.06), false)
		"kiosk":
			g.aabb("trim:cream", Vector3(-hw, 0, -hd), Vector3(hw, 1.0, hd), false)
			g.aabb("timber", Vector3(-hw - 0.05, 1.0, -hd - 0.05), Vector3(hw + 0.05, 1.05, hd + 0.05), false)
			for sx in [-hw + 0.05, hw - 0.1]:
				for sz in [-hd + 0.05, hd - 0.1]:
					g.aabb("steel", Vector3(sx, 1.05, sz), Vector3(sx + 0.05, h - 0.2, sz + 0.05), false)
			g.aabb("enamel:teal", Vector3(-hw - 0.15, h - 0.2, -hd - 0.15), Vector3(hw + 0.15, h, hd + 0.15), false)
			g.aabb("enamel:cream", Vector3(-hw + 0.1, 1.05, -0.3), Vector3(hw - 0.1, 1.6, 0.3), false)
		"fc_counter":
			g.aabb("steel", Vector3(-hw, 0, -hd), Vector3(hw, h - 0.05, hd), false)
			g.aabb("enamel:white", Vector3(-hw - 0.02, h - 0.05, -hd), Vector3(hw + 0.02, h, hd + 0.03), false)
			g.aabb("glass", Vector3(-hw + 0.1, h, hd - 0.35), Vector3(hw - 0.1, h + 0.35, hd - 0.05), false)
		"clothes_rack":
			g.aabb("steel", Vector3(-hw, 0, -0.03), Vector3(hw, 0.03, 0.03), false)
			for sx in [-hw, hw - 0.03]:
				g.aabb("steel", Vector3(sx, 0, -0.02), Vector3(sx + 0.03, h, 0.02), false)
			g.aabb("steel", Vector3(-hw, h - 0.03, -0.02), Vector3(hw, h, 0.02), false)
			var nh := int(w / 0.12)
			for k in nh:
				if absi(hash(k * 7 + int(w * 3))) % 3 == 0: continue
				var cx := -hw + 0.08 + k * (w - 0.16) / nh
				g.aabb("cloth:" + ["blue", "green", "pink", "tan", "grey", "teal"][k % 6], Vector3(cx - 0.015, h - 0.95, -hd + 0.03), Vector3(cx + 0.015, h - 0.05, hd - 0.03), false)
		"mannequin":
			g.aabb("enamel:white", Vector3(-0.15, 0, -0.15), Vector3(0.15, 0.04, 0.15), false)
			g.aabb("steel", Vector3(-0.015, 0.04, -0.015), Vector3(0.015, 0.8, 0.015), false)
			g.aabb("enamel:cream", Vector3(-0.18, 0.8, -0.1), Vector3(0.18, 1.45, 0.1), false)
			g.aabb("enamel:cream", Vector3(-0.08, 1.48, -0.08), Vector3(0.08, 1.7, 0.08), false)
			g.aabb("cloth:" + ["blue", "pink", "tan"][int(w * 10) % 3], Vector3(-0.19, 0.95, -0.11), Vector3(0.19, 1.42, 0.11), false)
		"sec_desk":
			g.aabb("trim:cream", Vector3(-hw, 0, -hd), Vector3(hw, h - 0.04, hd), false)
			g.aabb("timber", Vector3(-hw - 0.02, h - 0.04, -hd - 0.02), Vector3(hw + 0.02, h, hd + 0.02), false)
			for k in 3:
				g.aabb("dark", Vector3(-hw + 0.2 + k * 0.5, h, -hd + 0.05), Vector3(-hw + 0.6 + k * 0.5, h + 0.35, -hd + 0.4), false)
		"safe":
			g.aabb("steel", Vector3(-hw, 0, -hd), Vector3(hw, h, hd - 0.04), false)
			g.aabb("dark", Vector3(-hw + 0.04, 0.04, hd - 0.04), Vector3(hw - 0.04, h - 0.04, hd), false)
			g.aabb("steel", Vector3(-0.1, h * 0.55 - 0.1, hd), Vector3(0.1, h * 0.55 + 0.1, hd + 0.05), false)
			g.aabb("steel", Vector3(hw - 0.14, h * 0.3, hd), Vector3(hw - 0.1, h * 0.75, hd + 0.04), false)
		"bar":
			g.aabb("timber", Vector3(-hw, 0, -hd + 0.06), Vector3(hw, h - 0.05, hd - 0.04), false)
			g.aabb("door:dark", Vector3(-hw - 0.04, h - 0.05, -hd), Vector3(hw + 0.04, h, hd + 0.04), false)
			g.aabb("steel", Vector3(-hw, 0.12, hd - 0.04), Vector3(hw, 0.16, hd + 0.06), false)
			for k in 3:
				var tx := -hw + 0.5 + k * 0.18
				g.aabb("steel", Vector3(tx - 0.02, h, -0.05), Vector3(tx + 0.02, h + 0.32, -0.01), false)
		"drinks_fridge":
			g.aabb("enamel:white", Vector3(-hw, 0, -hd), Vector3(hw, h, hd - 0.03), false)
			g.aabb("glass", Vector3(-hw + 0.05, 0.25, hd - 0.03), Vector3(hw - 0.05, h - 0.2, hd), false)
			for k in 4:
				var sy := 0.35 + k * 0.38
				g.aabb("steel", Vector3(-hw + 0.06, sy, -hd + 0.05), Vector3(hw - 0.06, sy + 0.02, hd - 0.06), false)
				for j in 5:
					var cx := -hw + 0.12 + j * 0.16
					g.aabb("enamel:" + ["pink", "teal", "yellow", "green", "blue"][(j + k) % 5], Vector3(cx - 0.035, sy + 0.02, 0.0), Vector3(cx + 0.035, sy + 0.2, 0.12), false)
			g.aabb("enamel:pink", Vector3(-hw, h - 0.2, hd - 0.03), Vector3(hw, h, hd + 0.01), false)
		"bath":
			var t := 0.06
			g.aabb("enamel", Vector3(-hw, 0, -hd), Vector3(hw, 0.08, hd), false)
			g.aabb("enamel", Vector3(-hw, 0, -hd), Vector3(hw, h, -hd + t), false)
			g.aabb("enamel", Vector3(-hw, 0, hd - t), Vector3(hw, h, hd), false)
			g.aabb("enamel", Vector3(-hw, 0, -hd), Vector3(-hw + t, h, hd), false)
			g.aabb("enamel", Vector3(hw - t, 0, -hd), Vector3(hw, h, hd), false)
			g.aabb("steel", Vector3(-hw + 0.08, h - 0.05, -0.04), Vector3(-hw + 0.2, h + 0.12, 0.04), false)
		"toilet":
			g.aabb("enamel", Vector3(-0.18, 0, -hd + 0.2), Vector3(0.18, 0.4, hd - 0.02), false)
			g.aabb("enamel", Vector3(-0.2, 0.4, -hd + 0.18), Vector3(0.2, 0.43, hd), false)
			g.aabb("enamel", Vector3(-hw, 0.4, -hd), Vector3(hw, h, -hd + 0.18), false)
		"vanity":
			g.aabb("trim:cream", Vector3(-hw, 0.08, -hd), Vector3(hw, h - 0.04, hd), false)
			g.aabb("dark", Vector3(-hw + 0.02, 0, -hd + 0.02), Vector3(hw - 0.02, 0.08, hd - 0.04), false)
			g.aabb("enamel", Vector3(-hw - 0.02, h - 0.04, -hd), Vector3(hw + 0.02, h, hd + 0.02), false)
			g.aabb("steel", Vector3(-0.03, h, -hd + 0.04), Vector3(0.03, h + 0.18, -hd + 0.1), false)
			g.aabb("dark", Vector3(-0.002, 0.15, hd), Vector3(0.002, h - 0.1, hd + 0.005), false)
			g.aabb("mirror", Vector3(-hw + 0.05, 1.2, -hd - 0.01), Vector3(hw - 0.05, 1.9, -hd + 0.01), false)
		"ltub":
			for lx in [-hw + 0.03, hw - 0.06]:
				for lz in [-hd + 0.03, hd - 0.06]:
					g.aabb("steel", Vector3(lx, 0, lz), Vector3(lx + 0.03, h - 0.35, lz + 0.03), false)
			g.aabb("steel", Vector3(-hw, h - 0.35, -hd), Vector3(hw, h - 0.33, hd), false)
			for s in [[Vector3(-hw, h - 0.35, -hd), Vector3(hw, h, -hd + 0.02)], [Vector3(-hw, h - 0.35, hd - 0.02), Vector3(hw, h, hd)],
					[Vector3(-hw, h - 0.35, -hd), Vector3(-hw + 0.02, h, hd)], [Vector3(hw - 0.02, h - 0.35, -hd), Vector3(hw, h, hd)]]:
				g.aabb("steel", s[0], s[1], false)
			g.aabb("steel", Vector3(-0.03, h, -hd), Vector3(0.03, h + 0.25, -hd + 0.05), false)
		"wbench":
			g.aabb("timber", Vector3(-hw, h - 0.06, -hd), Vector3(hw, h, hd), false)
			for lx in [-hw + 0.05, hw - 0.12]:
				for lz in [-hd + 0.05, hd - 0.12]:
					g.aabb("timber", Vector3(lx, 0, lz), Vector3(lx + 0.07, h - 0.06, lz + 0.07), false)
			g.aabb("timber", Vector3(-hw + 0.05, 0.18, -hd + 0.05), Vector3(hw - 0.05, 0.22, hd - 0.05), false)
			g.aabb("timber", Vector3(-hw, h, -hd), Vector3(hw, h + 0.6, -hd + 0.02), false)   # pegboard
		"pallet_rack":
			for lx in [-hw, hw - 0.08]:
				for lz in [-hd, hd - 0.08]:
					g.aabb("steel:blue", Vector3(lx, 0, lz), Vector3(lx + 0.08, h, lz + 0.08), false)
			for ly in [0.12, h * 0.36, h * 0.7]:
				g.aabb("steel", Vector3(-hw, ly, -hd), Vector3(hw, ly + 0.1, -hd + 0.06), false)
				g.aabb("steel", Vector3(-hw, ly, hd - 0.06), Vector3(hw, ly + 0.1, hd), false)
				g.aabb("timber", Vector3(-hw + 0.08, ly + 0.1, -hd + 0.05), Vector3(hw - 0.08, ly + 0.13, hd - 0.05), false)
				# a load on most of the shelves
				var seed := absi(hash(Vector2(ly, w)))
				if seed % 3 != 0:
					g.aabb("timber:tan", Vector3(-hw + 0.2, ly + 0.13, -hd + 0.1), Vector3(-0.1, ly + 0.13 + 0.6 + (seed % 5) * 0.08, hd - 0.1), false)
				if seed % 4 != 1:
					g.aabb("fibro:tan", Vector3(0.1, ly + 0.13, -hd + 0.1), Vector3(hw - 0.2, ly + 0.13 + 0.5, hd - 0.15), false)
		"vat":
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = hd
			cm.bottom_radius = hd
			cm.height = w
			mi.mesh = cm
			mi.material_override = BuildGen.mat("steel")
			mi.rotation.z = PI / 2
			mi.position = Vector3(0, h - hd, 0)
			for lx in [-hw + 0.2, hw - 0.3]:
				g.aabb("steel", Vector3(lx, 0, -0.05), Vector3(lx + 0.1, h - hd, 0.05), false)
			var n := Node3D.new()
			var m2 := MeshInstance3D.new()
			m2.mesh = g.commit()
			n.add_child(m2)
			n.add_child(mi)
			return n
	var mi2 := MeshInstance3D.new()
	mi2.mesh = g.commit()
	var holder := Node3D.new()
	holder.add_child(mi2)
	return holder

## Kitchen cupboards with a benchtop: doors along the front
static func _cupboards(g: BuildGen.Geo, a: float, b: float, z0: float, z1: float, h: float, sink: bool) -> void:
	g.aabb("trim:cream", Vector3(a, 0.1, z0), Vector3(b, h - 0.04, z1 - 0.02), false)
	g.aabb("dark", Vector3(a, 0, z0), Vector3(b, 0.1, z1 - 0.06), false)
	g.aabb("enamel:tan", Vector3(a - 0.01, h - 0.04, z0), Vector3(b + 0.01, h, z1 + 0.02), false)
	var n := maxi(1, int((b - a) / 0.5))
	for k in n:
		var x := a + (b - a) * k / n
		g.aabb("dark", Vector3(x - 0.004, 0.12, z1 - 0.02), Vector3(x + 0.004, h - 0.08, z1 - 0.015), false)
		g.aabb("steel", Vector3(x + 0.05, h - 0.2, z1 - 0.02), Vector3(x + 0.08, h - 0.12, z1 + 0.01), false)
	if sink:
		var c := (a + b) / 2
		g.aabb("steel", Vector3(c - 0.4, h - 0.035, z0 + 0.08), Vector3(c + 0.4, h + 0.005, z1 - 0.1), false)
		g.aabb("dark", Vector3(c - 0.34, h - 0.03, z0 + 0.12), Vector3(c + 0.34, h + 0.008, z1 - 0.14), false)
		g.aabb("steel", Vector3(c - 0.02, h, z0 + 0.03), Vector3(c + 0.02, h + 0.3, z0 + 0.07), false)

## The kitchen: a run of cupboards along the longest clear wall, the stove in it, the sink under a window if there is one
static func _bench_run(rm: Room, holder: Node3D, rng: RandomNumberGenerator, boxes: Array, p: Dictionary) -> bool:
	var best := {}
	var best_len := 0.0
	for side in ["N", "S", "W", "E"]:
		var along_x: bool = side in ["N", "S"]
		var a := rm.x0 if along_x else rm.z0
		var b := rm.x1 if along_x else rm.z1
		var cuts := [[a, a]]
		for op in rm.r.ops[side]:
			if op.kind != "window":
				cuts.append([float(op.a) - 0.1, float(op.b) + 0.1])
		cuts.append([b, b])
		cuts.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
		for i in cuts.size() - 1:
			var s0: float = cuts[i][1]
			var s1: float = cuts[i + 1][0]
			# don't run the bench across the fridge's or anything else's spot
			if s1 - s0 > best_len:
				best_len = s1 - s0
				best = {"side": side, "a": s0, "b": s1}
	if best_len < 1.4:
		return false
	var dep := 0.6
	var h := 0.9
	var side: String = best.side
	var a: float = best.a
	var b: float = minf(best.b, best.a + 4.2)
	if rng.randf() < 0.5:
		b = best.b
		a = maxf(best.a, best.b - 4.2)
	var sink_c := (a + b) / 2
	for op in rm.r.ops[side]:
		if op.kind == "window" and float(op.b) > a and float(op.a) < b:
			sink_c = clampf((float(op.a) + float(op.b)) / 2, a + 0.5, b - 0.5)
	var stove_c := a + 0.32 if absf(sink_c - a) > absf(sink_c - b) else b - 0.32
	if b - a < 2.2: stove_c = INF
	# the run is built along local +x from 0 to L, back to the wall (local -z), and turned onto the wall
	var L := b - a
	var tolocal := func(c: float) -> float: return (c - a) if side in ["N", "E"] else (b - c)
	var g := BuildGen.Geo.new()
	var segs := [[0.0, L]]
	if stove_c != INF:
		var sl: float = tolocal.call(stove_c)
		segs = [[0.0, sl - 0.31], [sl + 0.31, L]]
	var sl_sink: float = tolocal.call(sink_c)
	for sg in segs:
		if float(sg[1]) - float(sg[0]) < 0.05: continue
		var has_sink: bool = sl_sink > float(sg[0]) + 0.42 and sl_sink < float(sg[1]) - 0.42
		_cupboards(g, float(sg[0]), float(sg[1]), -dep / 2, dep / 2, h, false)
		if has_sink:
			g.aabb("steel", Vector3(sl_sink - 0.4, h - 0.035, -dep / 2 + 0.08), Vector3(sl_sink + 0.4, h + 0.005, dep / 2 - 0.1), false)
			g.aabb("dark", Vector3(sl_sink - 0.34, h - 0.03, -dep / 2 + 0.12), Vector3(sl_sink + 0.34, h + 0.008, dep / 2 - 0.14), false)
			g.aabb("steel", Vector3(sl_sink - 0.02, h, -dep / 2 + 0.03), Vector3(sl_sink + 0.02, h + 0.3, -dep / 2 + 0.07), false)
	# overhead cupboards where there's no window
	var hy0 := 1.5
	var hy1 := 2.2
	var cuts2 := []
	for op in rm.r.ops[side]:
		if float(op.y1) > hy0:
			var la: float = tolocal.call(float(op.a))
			var lb: float = tolocal.call(float(op.b))
			cuts2.append([minf(la, lb) - 0.05, maxf(la, lb) + 0.05])
	cuts2.sort_custom(func(p1, p2): return float(p1[0]) < float(p2[0]))
	var x := 0.0
	for oc in cuts2 + [[L, L]]:
		var e := minf(float(oc[0]), L)
		if e - x > 0.4:
			g.aabb("trim:cream", Vector3(x, hy0, -dep / 2), Vector3(e, hy1, -dep / 2 + 0.34), false)
		x = maxf(x, float(oc[1]))
	var sb := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = g.commit()
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(L, h, dep)
	cs.shape = bs
	cs.position = Vector3(L / 2, h / 2, 0)
	sb.add_child(cs)
	var yaw := 0.0
	var origin := Vector3.ZERO
	match side:
		"N": yaw = 0.0; origin = Vector3(a, rm.fy, rm.z0 + dep / 2)
		"S": yaw = PI; origin = Vector3(b, rm.fy, rm.z1 - dep / 2)
		"W": yaw = PI / 2; origin = Vector3(rm.x0 + dep / 2, rm.fy, b)
		"E": yaw = -PI / 2; origin = Vector3(rm.x1 - dep / 2, rm.fy, a)
	sb.transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	holder.add_child(sb)
	sb.set_meta("container", "kitchen")
	sb.set_meta("container_name", "kitchen cupboards")
	boxes.append(sb)
	var rc: Rect2
	match side:
		"N": rc = Rect2(a, rm.z0, b - a, dep)
		"S": rc = Rect2(a, rm.z1 - dep, b - a, dep)
		"W": rc = Rect2(rm.x0, a, dep, b - a)
		"E": rc = Rect2(rm.x1 - dep, a, dep, b - a)
	rm.taken.append(rc)
	rm.placed["bench"] = [sb, rc, rm.fy + h]
	if stove_c != INF:
		var pos: Vector2
		match side:
			"N": pos = Vector2(stove_c, rm.z0 + dep / 2)
			"S": pos = Vector2(stove_c, rm.z1 - dep / 2)
			"W": pos = Vector2(rm.x0 + dep / 2, stove_c)
			"E": pos = Vector2(rm.x1 - dep / 2, stove_c)
		_put(rm, "stove", {"pos": pos, "yaw": yaw, "rect": Rect2()}, holder, boxes, p, false)
	return true
