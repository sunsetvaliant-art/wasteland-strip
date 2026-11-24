"""0.2.75: make the game's people with MakeHuman (MPFB2 as a Blender module) and its CC0 system assets.
Each person: a body from the macro sliders (sex, age, weight, muscle, height, ancestry), a skin, eyes, brows, lashes and
hair, the Mixamo rig, and every garment fitted to that body as its own skinned mesh on the same skeleton (the suits are
split into their top and bottom pieces). The body carries, in its vertex colours, which garments hide each vertex
(so the game can drop the skin under whatever's worn and nothing pokes through). Exported as glTF with the textures
in one shared folder.
usage: python3 gen_people.py <out dir> [name ...]"""
import bpy, os, sys, json, math, bmesh, addon_utils
addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.targetservice import TargetService
from bl_ext.user_default.mpfb.services.locationservice import LocationService

OUT = sys.argv[1]
ONLY = sys.argv[2:]

def data(*p):
    return os.path.join(LocationService.get_user_data(), *p)

# garments: game id -> (mhclo, which part: "top" / "bottom" / "all", slot)
SUITS = {
    "male_casualsuit01": ("mh_denimshirt", "mh_jeans_a"),
    "male_casualsuit02": ("mh_longtee", "mh_jeans_b"),
    "male_casualsuit03": ("mh_checkshirt", "mh_jeans_c"),
    "male_casualsuit04": ("mh_tee_blue", None),
    "male_casualsuit05": ("mh_jacket", None),
    "male_casualsuit06": ("mh_tee_white", None),
    "female_casualsuit01": ("mh_tee_fitted", "mh_jeans_slim"),
    "female_casualsuit02": ("mh_tee_loose", "mh_denimshorts"),
    "female_sportsuit01": ("mh_croptop", "mh_leggings"),
}
WHOLE = {"male_worksuit01": "mh_overalls", "shoes01": "mh_shoes_brown", "shoes02": "mh_runners_camo", "shoes03": "mh_boots",
         "shoes04": "mh_shoes_black", "shoes05": "mh_runners_white", "shoes06": "mh_runners_blue", "fedora01": "mh_hat"}

PEOPLE = {
    # name: macro (gender 1 = male, age 0.5 = 25 yrs, 1 = 90), skin, hair, brows
    "mh_m_young": ({"gender": 1.0, "age": 0.45, "muscle": 0.6, "weight": 0.5, "height": 0.55, "race": {"caucasian": 1.0, "african": 0.0, "asian": 0.0}}, "young_caucasian_male", "short02", "eyebrow001"),
    "mh_m_mid": ({"gender": 1.0, "age": 0.68, "muscle": 0.5, "weight": 0.72, "height": 0.5, "race": {"caucasian": 1.0, "african": 0.0, "asian": 0.0}}, "middleage_caucasian_male", "short04", "eyebrow003"),
    "mh_m_old": ({"gender": 1.0, "age": 0.88, "muscle": 0.35, "weight": 0.6, "height": 0.42, "race": {"caucasian": 1.0, "african": 0.0, "asian": 0.0}}, "old_caucasian_male", "short01", "eyebrow005"),
    "mh_m_lean": ({"gender": 1.0, "age": 0.52, "muscle": 0.7, "weight": 0.3, "height": 0.7, "race": {"caucasian": 0.7, "african": 0.0, "asian": 0.3}}, "young_caucasian_male2", "short03", "eyebrow002"),
    "mh_m_african": ({"gender": 1.0, "age": 0.55, "muscle": 0.65, "weight": 0.55, "height": 0.6, "race": {"caucasian": 0.0, "african": 1.0, "asian": 0.0}}, "middleage_african_male", "short02", "eyebrow006"),
    "mh_m_asian": ({"gender": 1.0, "age": 0.5, "muscle": 0.5, "weight": 0.45, "height": 0.4, "race": {"caucasian": 0.0, "african": 0.0, "asian": 1.0}}, "young_asian_male", "short04", "eyebrow004"),
    "mh_f_young": ({"gender": 0.0, "age": 0.45, "muscle": 0.5, "weight": 0.45, "height": 0.5, "race": {"caucasian": 1.0, "african": 0.0, "asian": 0.0}}, "young_caucasian_female", "ponytail01", "eyebrow008"),
    "mh_f_mid": ({"gender": 0.0, "age": 0.68, "muscle": 0.4, "weight": 0.65, "height": 0.45, "race": {"caucasian": 1.0, "african": 0.0, "asian": 0.0}}, "middleage_caucasian_female", "bob02", "eyebrow009"),
    "mh_f_african": ({"gender": 0.0, "age": 0.55, "muscle": 0.5, "weight": 0.55, "height": 0.55, "race": {"caucasian": 0.0, "african": 1.0, "asian": 0.0}}, "young_african_female", "afro01", "eyebrow010"),
    "mh_f_asian": ({"gender": 0.0, "age": 0.5, "muscle": 0.45, "weight": 0.4, "height": 0.4, "race": {"caucasian": 0.0, "african": 0.0, "asian": 1.0}}, "young_asian_female", "long01", "eyebrow011"),
    "mh_f_old": ({"gender": 0.0, "age": 0.9, "muscle": 0.3, "weight": 0.6, "height": 0.35, "race": {"caucasian": 1.0, "african": 0.0, "asian": 0.0}}, "old_caucasian_female", "bob01", "eyebrow012"),
}

def mhclo(kind, name):
    d = data(kind, name)
    for f in os.listdir(d):
        if f.endswith(".mhclo") or f.endswith(".proxy"):
            return os.path.join(d, f)
    raise IOError(d)

def mhmat(kind, name):
    d = data(kind, name)
    for f in os.listdir(d):
        if f.endswith(".mhmat"):
            return os.path.join(d, f)
    raise IOError(d)

def clear():
    for ob in list(bpy.data.objects): bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials):
        for x in list(coll):
            if x.users == 0: coll.remove(x)

def split_suit(obj, waist_z):
    """a suit's top and bottom: its loose parts by where they sit; a part that runs right across the waist (a shirt
    sewn to its jeans) is cut there, face by face"""
    def sel_only(o):
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True); bpy.context.view_layer.objects.active = o
    sel_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = list(bpy.context.selected_objects)
    top, bot = [], []
    for p in parts:
        zs = [(p.matrix_world @ v.co).z for v in p.data.vertices]
        if not zs: continue
        if max(zs) > waist_z + 0.2 and min(zs) < waist_z - 0.25:
            # cut it at the waist
            sel_only(p)
            bpy.ops.object.mode_set(mode="EDIT")
            bm = bmesh.from_edit_mesh(p.data)
            for f in bm.faces:
                f.select = (p.matrix_world @ f.calc_center_median()).z > waist_z
            bmesh.update_edit_mesh(p.data)
            bpy.ops.mesh.separate(type="SELECTED")
            bpy.ops.object.mode_set(mode="OBJECT")
            for q in bpy.context.selected_objects:
                if q == p: continue
                top.append(q)
            bot.append(p)
            continue
        (top if sum(zs) / len(zs) > waist_z else bot).append(p)
    def join(lst):
        if not lst: return None
        bpy.ops.object.select_all(action="DESELECT")
        for p in lst: p.select_set(True)
        bpy.context.view_layer.objects.active = lst[0]
        if len(lst) > 1: bpy.ops.object.join()
        return bpy.context.view_layer.objects.active

    return join(top), join(bot)

def make(name, spec):
    clear()
    macro, skin, hair, brow = spec
    m = TargetService.get_default_macro_info_dict()
    m.update(macro)
    base = HumanService.create_human(macro_detail_dict=m, feet_on_ground=True, scale=0.1)
    base.name = name
    base["mh_female"] = macro["gender"] < 0.5
    HumanService.set_character_skin(mhmat("skins", skin), base, skin_type="GAMEENGINE")
    rig = HumanService.add_builtin_rig(base, "mixamo", import_weights=True)
    rig.name = name + "_rig"
    female = macro["gender"] < 0.5
    HumanService.add_mhclo_asset(mhclo("eyes", "low-poly"), base, asset_type="Eyes", subdiv_levels=0, material_type="GAMEENGINE")
    HumanService.add_mhclo_asset(mhclo("eyebrows", brow), base, asset_type="Eyebrows", subdiv_levels=0, material_type="GAMEENGINE")
    HumanService.add_mhclo_asset(mhclo("eyelashes", "eyelashes02"), base, asset_type="Eyelashes", subdiv_levels=0, material_type="GAMEENGINE")
    HumanService.add_mhclo_asset(mhclo("hair", hair), base, asset_type="Hair", subdiv_levels=0, material_type="GAMEENGINE")
    # where the waist is: the hips bone's height
    hips = rig.data.bones.get("mixamorig:Hips")
    waist_z = (rig.matrix_world @ hips.head_local).z + 0.08 if hips else 1.0
    garments = {}
    for suit, (top_id, bot_id) in SUITS.items():
        o = HumanService.add_mhclo_asset(mhclo("clothes", suit), base, asset_type="Clothes", subdiv_levels=0, material_type="GAMEENGINE")
        t, b = split_suit(o, waist_z)
        for gid, part in ((top_id, t), (bot_id, b)):
            if part is None: continue
            if gid is None:
                bpy.data.objects.remove(part, do_unlink=True)
                continue
            part.name = gid
            garments[gid] = (part, suit)
    for item, gid in WHOLE.items():
        o = HumanService.add_mhclo_asset(mhclo("clothes", item), base, asset_type="Clothes", subdiv_levels=0, material_type="GAMEENGINE")
        o.name = gid
        garments[gid] = (o, item)
    return base, rig, garments

def bake_hide_masks(base, garments):
    """each garment gets a bit; a body vertex's colour holds the bits of every garment that hides it"""
    order = sorted(garments.keys())
    assert len(order) <= 23, "23 garment bits (bit 23 is the underwear)"
    bits = {g: i for i, g in enumerate(order)}
    me = base.data
    vg = {g.name: g.index for g in base.vertex_groups}
    mask = [0] * len(me.vertices)
    for gid, (obj, src) in garments.items():
        gname = "Delete." + src
        if gname not in vg: continue
        gi = vg[gname]
        # a split suit's delete group covers both halves: keep the vertices within this piece's own height
        others = [o for g2, (o, s2) in garments.items() if s2 == src and g2 != gid]
        zs = [(obj.matrix_world @ v.co).z for v in obj.data.vertices]
        lo, hi = min(zs), max(zs)
        for v in me.vertices:
            for g in v.groups:
                if g.group == gi and g.weight > 0.5:
                    z = (base.matrix_world @ v.co).z
                    if not (lo - 0.03 <= z <= hi + 0.03): break      # (a suit whose trousers were dropped keeps a delete group down its legs)
                    mask[v.index] |= 1 << bits[gid]
                    break
    # underwear: bit 23 of the same colour (Godot drops vertex colour alpha on import). Briefs round the hips (between the hip
    # joints a little down the thighs and just under the navel), a bra round a woman's chest: only on the trunk and
    # the tops of the legs, never the hands hanging by them
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    def bz(n):
        b = arm.data.bones.get("mixamorig:" + n)
        return (arm.matrix_world @ b.head_local) if b else None
    hip_j = bz("LeftUpLeg"); hips = bz("Hips"); sp2 = bz("Spine2"); sp1 = bz("Spine1")
    region = [0] * len(me.vertices)
    gnames = {g.index: g.name for g in base.vertex_groups}
    trunk = {"mixamorig:Hips", "mixamorig:LeftUpLeg", "mixamorig:RightUpLeg", "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2"}
    female = any("female" in o.name for o in []) or base.get("mh_female", False)
    for v in me.vertices:
        best = max(v.groups, key=lambda g: g.weight if gnames.get(g.group, "").startswith("mixamorig:") else -1.0, default=None)
        bn = gnames.get(best.group, "") if best else ""
        if bn not in trunk: continue
        z = (base.matrix_world @ v.co).z
        if hip_j and hips and hip_j.z - 0.1 <= z <= hips.z + 0.06 and bn in ("mixamorig:Hips", "mixamorig:LeftUpLeg", "mixamorig:RightUpLeg", "mixamorig:Spine"):
            region[v.index] = 1
        elif female and sp2 and sp1 and sp1.z + 0.02 <= z <= sp2.z + 0.09 and bn in ("mixamorig:Spine1", "mixamorig:Spine2"):
            region[v.index] = 2
    if "hide" in me.color_attributes: me.color_attributes.remove(me.color_attributes["hide"])
    ca = me.color_attributes.new("hide", "FLOAT_COLOR", "POINT")     # float: a byte colour goes through sRGB and the bits are lost
    for i, mk in enumerate(mask):
        if region[i]: mk |= 1 << 23
        ca.data[i].color = ((mk & 0xFF) / 255.0, ((mk >> 8) & 0xFF) / 255.0, ((mk >> 16) & 0xFF) / 255.0, 1.0)
    me.color_attributes.active_color = ca
    return bits

def prep_export(base):
    """drop the clothes' delete masks (the game hides the skin itself), cut the helper geometry, and bake the body's
    shape (its macro targets are shape keys) into the mesh"""
    from bl_ext.user_default.mpfb.services.exportservice import ExportService
    for mod in list(base.modifiers):
        if mod.type == "MASK" and str(mod.vertex_group).startswith("Delete."):
            base.modifiers.remove(mod)
    bpy.ops.object.select_all(action="DESELECT")
    base.select_set(True); bpy.context.view_layer.objects.active = base
    ExportService.bake_modifiers_remove_helpers(base, bake_masks=True, bake_subdiv=False, remove_helpers=True)
    for ob in bpy.data.objects:
        if ob.type != "MESH" or ob.data.shape_keys is None: continue
        bpy.context.view_layer.objects.active = ob
        ob.shape_key_add(name="baked", from_mix=True)
        keys = ob.data.shape_keys.key_blocks
        baked = keys["baked"]
        for k in list(keys):
            if k.name != "baked": ob.shape_key_remove(k)
        ob.shape_key_remove(ob.data.shape_keys.key_blocks["baked"]) if False else None
        # the one that's left is the basis now; drop it so the mesh is plain
        ob.shape_key_clear()

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    index = {}
    for name, spec in PEOPLE.items():
        if ONLY and name not in ONLY: continue
        base, rig, garments = make(name, spec)
        from bl_ext.user_default.mpfb.services.exportservice import ExportService
        prep_export(base)
        bits = bake_hide_masks(base, garments)
        index[name] = {"female": spec[0]["gender"] < 0.5, "garments": bits}
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".gltf"), export_format="GLTF_SEPARATE",
            export_texture_dir="../mh_tex", use_selection=False, export_apply=True, export_skins=True,
            export_animations=False, export_morph=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False,
            export_image_format="AUTO")
        print("PEOPLE wrote", name, len(garments), "garments")
    ip = os.path.join(OUT, "people_index.json")
    old = json.load(open(ip)) if os.path.exists(ip) else {}
    old.update(index)
    json.dump(old, open(ip, "w"), indent=1)
