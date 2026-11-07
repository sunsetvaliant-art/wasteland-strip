# Downloads Poly Haven (CC0) models as glTF + textures into assets/ph/<category>/<id>/. Prints a url list for curl.
import json, sys, urllib.request, os
SETS = {
 "weapons": ("2k", "bolt_action_rifle_7_62 service_pistol stick_grenade machete hatchet wooden_axe sledgehammer_01 crowbar_01 picke_dirty_01 rusted_spade_01 ammo_box old_military_crate wooden_military_crate"),
 "tools": ("1k", "adjustable_wrench combination_wrench pipe_wrench ratchet_wrench pliers tongue_groove_pliers bolt_cutters_01 bench_vice_01 metal_tool_chest metal_toolbox tool_cart portable_welding_cart propane_torch brass_blowtorch drill_press_01 overhead_crane old_military_compressor portable_generator tire_pump rusted_hacksaw measuring_tape_01 vintage_hand_drill flathead_screwdriver cross_pein_hammer"),
 "carparts": ("1k", "old_tyre rusted_wheel_rim_01 rusted_wheel_rim_02 metal_jerrycan metal_jerrycan_green plastic_jerrycan small_oil_can_01 oil_tin lubricant_spray covered_car"),
 "survival": ("1k", "medical_box long_life_food russian_food_cans_01 can_rusted old_gas_mask vintage_binocular vintage_flashlight Lantern_01 vintage_oil_lamp vintage_radio_transceiver rubber_boots modified_thermos"),
 "world": ("1k", "street_lamp_01 street_lamp_02 modular_electricity_poles modular_chainlink_fence water_manhole_cover utility_box_01 utility_box_02 rollershutter_door metal_trash_can trashbag Barrel_01 Barrel_02 barrel_03 barrel_stove wooden_crate_01 wooden_crate_02 plastic_crate_01 propane_tank small_lpg_tank steel_frame_shelves_01 worn_metal_rack old_bed_frame metal_office_desk stone_fire_pit wooden_ladder hand_truck cardboard_box_01 painted_wooden_bench wooden_picnic_table plastic_monobloc_chair_01 Sofa_01 Television_01 vintage_cabinet_01 wooden_barrels_01"),
 "interior": ("1k", "sofa_02 modern_arm_chair_01 coffee_table_round_01 television_02 wooden_bookshelf_worn ceiling_fan electric_stove vintage_electric_kettle wooden_table_02 dining_chair_02 painted_wooden_chair_01 painted_wooden_cabinet painted_wooden_cabinet_02 painted_wooden_shelves painted_wooden_nightstand drawer_cabinet vintage_wooden_drawer_01 vintage_day_bed steel_frame_shelves_02 industrial_storage_cart compost_bags cement_bag plastic_container hanging_industrial_lamp metal_stool_01 SchoolChair_01 mounted_fluorescent_lights plastic_bottle_gallon side_table_01 wall_clock hanging_picture_frame_02 painted_wooden_table outdoor_table_chair_set_01 boombox"),
 "nature": ("1k", "tree_stump_01 tree_stump_02 root_cluster_01 rock_moss_set_01 rock_moss_set_02 moss_01 nettle_plant shrub_01 shrub_02 shrub_03 shrub_04 pachira_aquatica_01"),
}
TEX = {"asphalt_02": "2k", "asphalt_03": "2k", "aerial_asphalt_01": "2k"}
out = []
def get(u):
    req = urllib.request.Request(u, headers={"User-Agent": "WastelandAssetFetch/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r: return json.load(r)
for cat, (res, ids) in SETS.items():
    for i in ids.split():
        try:
            f = get("https://api.polyhaven.com/files/" + i)["gltf"]
            r = res if res in f else "1k"
            g = f[r]["gltf"]
            d = f"{cat}/{i}"
            out.append((g["url"], f"{d}/{i}.gltf"))
            for rel, inc in g.get("include", {}).items():
                out.append((inc["url"], f"{d}/{rel}"))
        except Exception as e:
            print("skip", i, e, file=sys.stderr)
for t, res in TEX.items():
    f = get("https://api.polyhaven.com/files/" + t)
    for m in ["Diffuse", "nor_gl", "Rough", "AO", "Displacement"]:
        if m in f and res in f[m]:
            x = f[m][res].get("jpg") or f[m][res].get("png")
            out.append((x["url"], f"tex/{t}/{t}_{m.lower()}.{x['url'].rsplit('.',1)[1]}"))
for u, p in out:
    print(u, p)
