extends Node3D
## Builds the world: sky and light, the real Tweed terrain (Terrain3D), rivers and sea, then drops you at the
## Riverview pub with a VJ wagon parked out front.

const PUB := Vector3(4.4, 0, 3.3)
const GROUND := ["pasture", "forest_floor", "cane_trash", "farm_soil", "sand", "mossy_rock", "concrete", "river_mud", "rough_grass"]
# Poly Haven PBR scans (CC0) and the BlendKit "Grass 01" lawn (slot 0), tinted only a touch towards the Tweed's colours
# (2026-11-13: the open country read as dry gold; this is the wet subtropics, so the rough grass and the litter under
# the trees are pulled green and the lawn lifted)
const TINT := [Color(0.95, 0.9, 0.9), Color(0.5, 0.6, 0.42), Color(0.95, 1.0, 0.9), Color(1, 1, 1), Color(1.05, 1.02, 0.95), Color(0.9, 1.0, 0.9), Color(1, 1, 1), Color(0.95, 0.95, 0.9), Color(0.66, 0.84, 0.5)]
# texture repeats per metre = 1 / the scan's real size (sizes: lawn 1 m, 2 m, 2 m, 3 m, 1.5 m, 3 m, 3 m, 1.3 m, 2.5 m)
const UV_SCALE := [1.0, 0.5, 0.5, 0.333, 0.667, 0.333, 0.333, 0.77, 0.4]

var terrain: Terrain3D
var player: Player
var car: Car
var sun: DirectionalLight3D
var water_mat: ShaderMaterial
var hud: Label
var veg: Vegetation
var roads: Roads
var show_debug := false
var env: Environment
var pause_menu: PauseMenu
var forge: Forge
var combat_hud: CombatHUD
var garage: Garage
var camps: ScavCamps
var buildings: Buildings
var sky: SkyCycle
var saves: SaveGame
var landmarks: Landmarks
var net: Net
var rg_roads: RgRoads
var interact_menu: InteractMenu
var zombies: ZombieDirector
var inv_ui: InventoryUI
var craft_ui: CraftUI
var car_care: CarCare
var base: BaseBuild
var road_pilot: Node3D        # RoadPilot, loaded by path so a broken road addon can't stop the game starting

func _ready() -> void:
	InputSetup.ensure()
	# keys added in updates: InputSetup may be the copy Boot loaded from the original install (scripts already in memory
	# aren't replaced when an update's pack is mounted), so register them here too
	for e in [["torch", KEY_T], ["board", KEY_G], ["work_on_car", KEY_K], ["inventory", KEY_I], ["heal", KEY_B], ["craft", KEY_N], ["build", KEY_M], ["kick", KEY_Q], ["throw", KEY_X], ["dodge", KEY_ALT]]:
		if not InputMap.has_action(e[0]):
			InputMap.add_action(e[0])
			var ev := InputEventKey.new()
			ev.physical_keycode = e[1]
			InputMap.action_add_event(e[0], ev)
	_build_environment()
	sky = SkyCycle.new()
	sky.name = "SkyCycle"
	add_child(sky)
	sky.setup(self)
	_build_terrain()
	_extend_north()
	if OS.get_environment("WATER_OFF") == "":
		_build_water()
	_build_backdrop()
	roads = Roads.new()
	roads.name = "Roads"
	add_child(roads)
	roads.setup(self)
	if OS.get_environment("RG_ROADS") != "" and RgRoads.available():      # the Road Generator roads (raised, with edges) only on request now
		rg_roads = RgRoads.new()
		rg_roads.name = "RgRoads"
		add_child(rg_roads)
		rg_roads.setup(self)
	elif OS.get_environment("ROAD_PILOT") != "":
		var rps: Script = load("res://scripts/world/road_pilot.gd")
		if rps != null and rps.can_instantiate():
			road_pilot = rps.new()
			road_pilot.name = "RoadPilot"
			add_child(road_pilot)
			road_pilot.call("setup")
		else:
			push_error("Road pilot didn't load; carrying on without it")
	if Buildings.available():
		buildings = Buildings.new()
		buildings.name = "Buildings"
		add_child(buildings)
		buildings.setup(self)
	veg = Vegetation.new()
	veg.name = "Vegetation"
	add_child(veg)
	veg.setup(terrain)
	if OS.get_environment("VEG_OFF") != "":
		veg.layers.clear()
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = PUB + Vector3(0, height_at(PUB.x, PUB.z) + 1.2, 0)
	var cp := PUB + Vector3(6, 0, 3)
	if Settings.creative():          # in survival you find your own
		car = spawn_vehicle("vjwagon", cp + Vector3(0, height_at(cp.x, cp.z) + 1.0, 0), 0.6)
	player.camera_changed.connect(func(cam): terrain.set_camera(cam))
	terrain.set_camera(player.active_camera())
	terrain.set_collision_target(player)
	player.vehicle_changed.connect(func(v): terrain.set_collision_target(v if v else player))
	_build_hud()
	forge = Forge.new()
	forge.name = "Forge"
	add_child(forge)
	forge.setup(self)
	net = Net.new()
	add_child(net)
	net.setup(self)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.setup(self)
	garage = Garage.new()
	garage.name = "Garage"
	add_child(garage)
	garage.setup(self)
	Settings.changed.connect(func(): Settings.apply(self))
	Settings.apply(self)
	# what you're carrying: the lot in creative, a revolver and a handful of rounds in survival
	player.inv.loadout(Settings.creative())
	inv_ui = InventoryUI.new()
	inv_ui.name = "InventoryUI"
	add_child(inv_ui)
	inv_ui.setup(self)
	craft_ui = CraftUI.new()
	craft_ui.name = "CraftUI"
	add_child(craft_ui)
	craft_ui.setup(self)
	car_care = CarCare.new()
	car_care.name = "CarCare"
	add_child(car_care)
	car_care.setup(self)
	interact_menu = InteractMenu.new()
	interact_menu.name = "InteractMenu"
	add_child(interact_menu)
	interact_menu.setup(self)
	base = BaseBuild.new()
	base.name = "BaseBuild"
	add_child(base)
	base.setup(self)
	var bug := BugReport.new()
	bug.name = "BugReport"
	add_child(bug)
	bug.setup(self)
	camps = ScavCamps.new()
	camps.name = "ScavCamps"
	add_child(camps)
	camps.setup(self)
	landmarks = Landmarks.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	landmarks.setup(self)
	zombies = ZombieDirector.new()
	zombies.name = "ZombieDirector"
	add_child(zombies)
	zombies.setup(self)
	saves = SaveGame.new()
	saves.name = "SaveGame"
	add_child(saves)
	saves.setup(self)

func spawn_vehicle(kind: String, pos: Vector3, yaw := 0.0, design := {}) -> Car:
	var c := Car.new()
	c.kind = kind
	if not design.is_empty():
		c.design = design.duplicate(true)
	c.name = kind
	add_child(c)
	c.global_position = pos
	c.rotation.y = yaw
	return c

## Reset (pause menu): reload the whole world as it was saved
func reset_world() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

## Ground collision only exists near whoever the terrain is following, so anything physical left far away is put to
## sleep (frozen) until someone comes back, instead of falling through the world.
var _sleep_t := 0.0
var collision_centre := Vector3.ZERO
func _physics_process(dt: float) -> void:
	_sleep_t -= dt
	if _sleep_t > 0.0:
		return
	_sleep_t = 0.25
	for b in get_tree().get_nodes_in_group("physgun"):
		if not (b is RigidBody3D) or b == forge.held:
			continue
		var rb := b as RigidBody3D
		var near := Vector2(rb.global_position.x - collision_centre.x, rb.global_position.z - collision_centre.z).length() < 350.0
		if not near and not rb.freeze:
			rb.freeze = true
			rb.set_meta("auto_frozen", true)
		elif near and rb.get_meta("auto_frozen", false):
			rb.set_meta("auto_frozen", false)
			rb.freeze = false

# ---------------------------------------------------------------- zombies and scavs
## If the saved layout has no zombie or scav spawns yet, put a few round the pub (they show and save in the Forge)
func _default_spawns() -> void:
	for o in forge.objects:
		var e: Dictionary = o.get_meta("forge", {})
		if e.get("type") == "marker" and e.get("key") in ["zombie", "scav"]:
			return
	var spots := [["zombie", Vector3(70, 0, 45)], ["zombie", Vector3(-85, 0, 95)], ["zombie", Vector3(130, 0, -70)],
		["zombie", Vector3(-40, 0, -120)], ["scav", Vector3(210, 0, 140)], ["scav", Vector3(-190, 0, -60)]]
	for sp in spots:
		var p: Vector3 = PUB + sp[1]
		p.y = height_at(p.x, p.z)
		if p.y < 1.0:
			continue          # that's in the river
		forge.spawn({"type": "marker", "key": sp[0], "name": sp[0].capitalize() + " spawn"}, Transform3D(Basis(), p))

## Spawns come alive when you're near and go back to sleep when you leave
var _npc_t := 0.0
func _npc_director(dt: float) -> void:
	_npc_t -= dt
	if _npc_t > 0.0:
		return
	_npc_t = 1.0
	if forge.active or OS.get_environment("NPC_OFF") != "":
		return
	var me: Vector3 = player.vehicle.global_position if player.vehicle else player.global_position
	for o in forge.objects:
		if not is_instance_valid(o):
			continue
		var e: Dictionary = o.get_meta("forge", {})
		if e.get("type") != "marker" or not (e.get("key") in ["zombie", "scav"]):
			continue
		var d: float = (o as Node3D).global_position.distance_to(me)
		var live: Array = o.get_meta("npcs", [])
		live = live.filter(func(n): return is_instance_valid(n))
		if d < 190.0 and not o.get_meta("spawned", false):
			o.set_meta("spawned", true)
			var count := 4 if e.key == "zombie" else 3
			for i in count:
				var n := NPC.new()
				n.kind = e.key
				var off := Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
				var p: Vector3 = (o as Node3D).global_position + off
				p.y = height_at(p.x, p.z) + 0.1
				add_child(n)
				n.global_position = p
				n.rotation.y = randf() * TAU
				n.home = p
				n.goal = p
				live.append(n)
		elif d > 300.0 and o.get_meta("spawned", false):
			for n in live:
				if not n.dead: n.free_body()
			live = []
			o.set_meta("spawned", false)
		o.set_meta("npcs", live)

## The real ground (roads, bridges, anything solid) under a point, falling back to the heightmap
func ground_at(x: float, z: float) -> float:
	var h := height_at(x, z)
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 60.0, z), Vector3(x, h - 5.0, z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return max(h, hit.position.y) if hit else h

func height_at(x: float, z: float) -> float:
	var h := terrain.data.get_height(Vector3(x, 0, z))
	return 0.0 if is_nan(h) else h

# ---------------------------------------------------------------- sky, sun, post
func _build_environment() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.13, 0.36, 0.78)
	sm.sky_horizon_color = Color(0.62, 0.76, 0.9)
	sm.sky_curve = 0.12
	sm.ground_bottom_color = Color(0.16, 0.2, 0.15)
	sm.ground_horizon_color = Color(0.62, 0.76, 0.9)
	sm.sun_angle_max = 30.0
	sm.sun_curve = 0.08
	sky.sky_material = sm
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Half the fill light from the sky, half a neutral grey: all-sky ambient tinted anything grey or pale (roads,
	# concrete, dry ground) sky blue
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_color = Color(0.58, 0.6, 0.58)
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.68, 0.78, 0.92)
	env.fog_depth_begin = 1500.0
	env.fog_depth_end = 26000.0
	env.fog_depth_curve = 1.6
	env.fog_aerial_perspective = 0.75
	env.fog_sky_affect = 0.25
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 6
	env.sdfgi_max_distance = 800.0
	env.ssr_max_steps = 48
	env.volumetric_fog_density = 0.0035
	env.volumetric_fog_albedo = Color(0.85, 0.9, 1.0)
	env.volumetric_fog_length = 160.0
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 450.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 0.6
	add_child(sun)

## North of the old map edge (z = -16960): three kilometres more, the border towns and their beaches. The heights
## come from assets/world/north_h.bin (tools/bake_north.py: public elevation tiles until the lidar for it is in hand),
## written into the terrain as the game starts; the region files already reach that far.
func _extend_north() -> void:
	var data = terrain.data
	var f := FileAccess.open("res://assets/world/north_h.bin", FileAccess.READ)
	if data == null or f == null: return
	var t0 := Time.get_ticks_msec()
	var xa := f.get_float()
	var zn := f.get_float()
	var w := f.get_32()
	var h := f.get_32()
	var sp := f.get_float()
	var buf := f.get_buffer(w * h * 2)
	var sand: bool = data.has_method("set_control_base_id")
	# Stitch: the strip's southern rows must meet the ground that's really in the terrain at the old edge (the bake
	# matched a copy of it that has since drifted). Per column, the step between the old edge and the strip's last
	# row is carried north and faded out with a smoothstep over STITCH metres, so the join has no lip.
	const STITCH := 220.0
	var edge_z := zn + h * sp                      # the old map's first row (the strip ends 5 m north of it)
	var step := PackedFloat32Array(); step.resize(w)
	var worst := 0.0; var mean := 0.0
	for c in w:
		var last := (float(buf.decode_u16(((h - 1) * w + c) * 2)) - 1000.0) * 0.01
		var x := xa + c * sp
		# the old ground a step further south too, so the slope carries on rather than just the level
		var e0: float = data.get_height(Vector3(x, 0, edge_z))
		var e1: float = data.get_height(Vector3(x, 0, edge_z + sp))
		var want := e0 + (e0 - e1)                 # where the old slope says the next row north should be
		if is_nan(e0) or is_nan(e1): want = last
		step[c] = want - last
		worst = maxf(worst, absf(step[c])); mean += absf(step[c])
	var vm: Image = load("res://assets/vegmask_north.png") if ResourceLoader.exists("res://assets/vegmask_north.png") else null
	var i := 0
	for r in h:
		var z := zn + r * sp
		var t := clampf((edge_z - z) / STITCH, 0.0, 1.0)
		var keep := 1.0 - t * t * (3.0 - 2.0 * t)   # 1 at the seam, 0 by STITCH north
		for c in w:
			var v := (float(buf.decode_u16(i)) - 1000.0) * 0.01 + step[c] * keep
			i += 2
			var p := Vector3(xa + c * sp, 0, z)
			data.set_height(p, v)
			if sand: data.set_control_base_id(p, _north_ground(data, p, v, edge_z, vm))
	data.update_maps(Terrain3DRegion.TYPE_HEIGHT)
	if sand: data.update_maps(Terrain3DRegion.TYPE_CONTROL)
	print("PROBE terrain north: ", w * h, " points in ", Time.get_ticks_msec() - t0, " ms, at the mall ", data.get_height(Vector3(13798, 0, -17250)),
		" seam step mean %.2f m worst %.2f m (now stitched)" % [mean / maxf(w, 1), worst])

## The ground texture for a point of the north strip: the texture of the ground the same distance south of the seam
## (mirrored, so the pattern runs straight across the join with no line), then beach sand along the ocean, forest
## litter under thick bush, and mud under water, from the strip's own vegetation map (tools/bake_north_veg.py).
func _north_ground(data, p: Vector3, v: float, edge_z: float, vm: Image) -> int:
	var id: int = data.get_control_base_id(Vector3(p.x, 0, edge_z + (edge_z - p.z) + 5.0))
	if v < 0.25: return 7
	if vm == null: return 4 if v < 2.2 else id
	var px := clampi(int((p.x - 8480.0) / 10.0), 0, vm.get_width() - 1)
	var pz := clampi(int((p.z + 19960.0) / 10.0), 0, vm.get_height() - 1)
	var m := vm.get_pixel(px, pz)
	if m.g > 0.35: return 4
	if m.r > 0.5: return 1
	if id == 4: return 8                 # mirrored beach sand from down south isn't beach up here
	return id

# ---------------------------------------------------------------- terrain
func _build_terrain() -> void:
	terrain = Terrain3D.new()
	terrain.name = "Terrain"
	terrain.vertex_spacing = 5.0
	var mat := Terrain3DMaterial.new()
	mat.world_background = Terrain3DMaterial.NONE
	mat.auto_shader_enabled = false
	mat.dual_scaling_enabled = true
	mat.macro_variation_enabled = true
	terrain.material = mat
	var assets := Terrain3DAssets.new()
	for i in GROUND.size():
		var ta := Terrain3DTextureAsset.new()
		ta.name = GROUND[i]
		ta.albedo_texture = load("res://assets/ground/%s_alb_h.png" % GROUND[i])
		ta.normal_texture = load("res://assets/ground/%s_nrm_r.png" % GROUND[i])
		ta.uv_scale = UV_SCALE[i]
		ta.albedo_color = TINT[i]
		ta.detiling_rotation = 0.3
		ta.detiling_shift = 0.3
		assets.set_texture_asset(i, ta)
	terrain.assets = assets
	terrain.collision_radius = 96
	terrain.mesh_size = 48
	terrain.mesh_lods = 7
	# Forge terrain edits are saved to user://terrain; use them when they exist
	terrain.data_directory = "user://terrain" if FileAccess.file_exists("user://terrain/terrain3d_00_00.res") else "res://terrain"
	add_child(terrain)
	if OS.get_environment("TERRAIN_DEBUG") != "":
		mat.set("show_" + OS.get_environment("TERRAIN_DEBUG"), true)
	mat.set_shader_param("blend_sharpness", 0.75)
	mat.set_shader_param("dual_scale_texture", 8)
	mat.set_shader_param("dual_scale_reduction", 0.3)
	mat.set_shader_param("dual_scale_far", 300.0)
	mat.set_shader_param("dual_scale_near", 60.0)

# ---------------------------------------------------------------- the country past the map edge
## Wollumbin (Mt Warning), the caldera rim and the ranges round it, out to 26 km past the edge of the map, so the
## skyline is the real one (tools/bake_backdrop.py). Seen from a long way off only: no collision, no shadows.
func _build_backdrop() -> void:
	if not ResourceLoader.exists("res://assets/backdrop/backdrop.glb"):
		return
	var n: Node3D = (load("res://assets/backdrop/backdrop.glb") as PackedScene).instantiate()
	n.name = "Backdrop"
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m: Material = (mi as MeshInstance3D).mesh.surface_get_material(0)
		if m is StandardMaterial3D:
			var sm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
			sm.roughness = 1.0
			sm.metallic_specular = 0.2
			(mi as MeshInstance3D).material_override = sm
	add_child(n)

# ---------------------------------------------------------------- rivers and sea
func _build_water() -> void:
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	var rn := FastNoiseLite.new()
	rn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rn.frequency = 0.012
	rn.fractal_octaves = 4
	var rt := NoiseTexture2D.new()
	rt.width = 512
	rt.height = 512
	rt.seamless = true
	rt.as_normal_map = true
	rt.bump_strength = 6.0
	rt.noise = rn
	water_mat.set_shader_parameter("ripple_tex", rt)
	var fn2 := FastNoiseLite.new()
	fn2.frequency = 0.03
	var ft := NoiseTexture2D.new()
	ft.width = 256
	ft.height = 256
	ft.seamless = true
	ft.noise = fn2
	water_mat.set_shader_parameter("foam_tex", ft)
	for f in DirAccess.get_files_at("res://assets/water"):
		var fn := f.trim_suffix(".import").trim_suffix(".remap")
		if not fn.ends_with(".glb") or (f != fn and FileAccess.file_exists("res://assets/water/" + fn)):
			continue
		var scene: PackedScene = load("res://assets/water/" + fn)
		if scene == null:
			continue
		var n := scene.instantiate()
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = water_mat
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
	# the sea: one big flat sheet at 0 m, out past the map edge
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80000, 80000)
	pm.subdivide_width = 64
	pm.subdivide_depth = 64
	sea.mesh = pm
	# the height map has the sea bed dead flat at 0 m: the sheet sits just over it and is shaded as deep water
	var sea_mat: ShaderMaterial = water_mat.duplicate()
	sea_mat.set_shader_parameter("base_depth", 5.0)
	sea_mat.set_shader_parameter("foam_max", 0.07)
	sea.material_override = sea_mat
	sea.position = Vector3(7040, 0.1, -960)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)

# ---------------------------------------------------------------- hud
func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	hud = Label.new()
	hud.position = Vector2(14, 10)
	hud.add_theme_font_size_override("font_size", 15)
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hud.add_theme_constant_override("outline_size", 4)
	cl.add_child(hud)
	if OS.get_environment("NO_SCOPE") == "":
		var scope := ScopeView.new()
		cl.add_child(scope)
		player.scope_view = scope
	combat_hud = CombatHUD.new()
	cl.add_child(combat_hud)
	combat_hud.setup(self)
	var hint := Label.new()
	hint.text = "WASD move · mouse look · Shift sprint · Ctrl crouch · Space jump · V camera · F get in/out · O Forge · Esc menu\nGuns: LMB fire · RMB aim · R reload · wheel switch · H gun away / out   Hand to hand (gun away): LMB swing · Q kick · X throw · Alt dodge\nI inventory · N make · M build · K under the bonnet · F pick up / open · B bandage · MMB carry · F9 bug report\nDriving: W gas (Shift+W floors it) · S brake · Space handbrake · Q / E gears · L lights · V cab view · [ ] seat height · F3 debug"
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.position = Vector2(14, -90)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 4)
	cl.add_child(hint)
	var t := create_tween().set_loops()
	t.tween_interval(12.0)
	t.tween_callback(func(): hint.visible = false)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("debug"):
		show_debug = not show_debug

func _process(_dt: float) -> void:
	_npc_director(_dt)
	var cam := get_viewport().get_camera_3d()
	if cam:
		veg.update(cam.global_position)
		var tgt: Node3D = forge.cam if forge.active else (player.vehicle if player.vehicle else player)
		collision_centre = tgt.global_position
	var s := "WASTELAND  v%s  ·  %s" % [Boot.version, "creative" if Settings.creative() else "survival"]
	if sky:
		s += "  ·  %s %s" % [sky.clock(), sky.weather if sky.weather != "clear" else ""]
	if buildings and player:
		var tn: String = buildings.town_at(player.global_position.x, player.global_position.z, 1600.0)
		if tn != "": s += "  ·  " + tn
	if Boot.patches_loaded.size():
		s += "  ·  patches: " + ", ".join(Boot.patches_loaded)
	if player.vehicle:
		s += "\n%s  %d km/h" % [player.vehicle.gear_name(), roundi(player.vehicle.speedo_kmh())]
	if show_debug or Settings.get_v("show_fps"):
		var p: Vector3 = player.global_position if not player.vehicle else player.vehicle.global_position
		s += "\n%d fps · x %.0f z %.0f · h %.1f m" % [Engine.get_frames_per_second(), p.x, p.z, p.y]
	hud.text = s
