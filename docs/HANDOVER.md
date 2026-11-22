# Wasteland Strip: handover for a new session

Written 2026-11-13 (Fri evening, Perth time). Read this first, then `README.md`, `docs/DESIGN_0.3.md` and
`updates/manifest.json` in the repo. Nothing here is a guess unless it says UNVERIFIED.

## 1. What it is
- Open-world survival + car-building game in Godot 4.7.2 (Terrain3D 1.1, Jolt physics, Windows only). DayZ-like, no
  fantasy: real Tweed Valley terrain (Uki to Kingscliff, now north past the NSW/QLD border), overgrown green
  post-apocalypse, own fictional universe with fictional town names, 80s-era guns, zombies, scavs, base building.
- Repo: https://github.com/sunsetvaliant-art/wasteland-strip (public). Current version **0.2.40** (patch 0040).
- Players get it via a launcher that downloads `updates/patch_0.2.0_####.pck` files listed in `updates/manifest.json`.
  Full base build is 0.2.0 (released 2026-11-05).
- The user plays on a Windows PC with a GTX 1650 Ti. Performance matters (Sunnyvale mall was 28 fps before the
  patch-0025 optimisation). He tests by playing and sending back what he sees; he is the bottleneck, so work in
  big chunks and self-test before handing over.

## 2. How we work (from the user)
- Wants big updates in one go, split across sessions only to save tokens. Don't re-ask decided things (section 5).
- Reports bugs in batches, often with F9 bug reports / crash logs (`%APPDATA%\Godot\app_userdata\Wasteland\logs\`).
- Likes the build order he sets himself and a master to-do list kept visible.
- Earlier commits are co-authored "Claude Fable 5.2"; the release tooling expects that workflow.

## 3. Bootstrap a fresh workspace (what I verified on 2026-11-13)
The sandbox is wiped between sessions. Scripts in `tools/` hard-code these paths:
`/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64` (engine), `/home/claude/game` (working copy, where you edit
and test), `/home/claude/wasteland-strip` (git clone used only to publish).

1. Engine (VERIFIED, 78 MB, works through the proxy):
   `mkdir -p /home/claude/godot && cd /home/claude/godot && curl -sSL -o g.zip https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip && unzip -qo g.zip && chmod +x Godot_v4.7.2-stable_linux.x86_64`
2. Repo: call the `add_repo` tool for `sunsetvaliant-art/wasteland-strip`. Read-only clone works anonymously:
   `GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 https://github.com/sunsetvaliant-art/wasteland-strip /home/claude/wasteland-strip`.
   To PUBLISH patches, call `add_repo` with `access: "push"` (the clone then lives at `/home/claude/wasteland-strip`).
   `gh` GraphQL is blocked; use `gh api repos/...` REST, and only once the repo is attached.
3. Working copy: `cp -r /home/claude/wasteland-strip /home/claude/game`, then import once:
   `cd /home/claude/game && /home/claude/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import --quit`
   (VERIFIED: about 1,150 reimport steps, finishes).
4. Missing from git (gitignored, must be restored or the world won't build). The headless boot on a fresh copy
   fails with "Resource file not found" for these:
   - `terrain/` (about 270 MB): README says it is the `terrain-data.zip` asset of the v0.2.0 release. I got a 404
     for `.../releases/download/v0.2.0/terrain-data.zip`, so the asset name or tag differs. UNVERIFIED: list the
     release assets with `gh api repos/sunsetvaliant-art/wasteland-strip/releases` after attaching the repo.
     Otherwise ask the user to upload it (he offered his 50 GB Google Drive) or rebuild with `tools/bake_terrain.gd`.
   - `assets/ph/` (Poly Haven CC0 models and textures): rebuilt by `tools/ph_fetch.py`. UNVERIFIED whether
     polyhaven.com is reachable from the sandbox network allowlist; test first.
   - `assets/roads/*.glb` and `assets/roadmask.png`: rebuilt by `tools/bake_roads.py`, whose inputs live in the
     gitignored `data/` folder (OSM and LiDAR). Also needs restoring from the user.
   - The user's own Meshy models and Sketchfab scans arrive as files he uploads.
5. Windows export (`export-patch`, `export-release`) needs Godot export templates for 4.7.2. UNVERIFIED that they
   can be fetched here (same godot-builds release has `Godot_v4.7.2-stable_export_templates.tpz`). Needs rcedit
   skipping (the scripts already filter that error).

### 3b. What actually worked on 2026-11-14 (patch 0041), use this
- There are NO GitHub releases (no terrain-data.zip, no base build). Everything needed is in the patches: extract
  every `updates/patch_0.2.0_*.pck` in order into an overlay (pck_strip.read_index), then copy it into the working
  copy WITHOUT overwriting git files (`cp -rn overlay/. game/`). That gives terrain/ (from patch 0005), the Poly
  Haven imports, road tiles, etc. THEN delete every `*.remap` and `*.gdc` outside .godot (exported compiled scripts
  that silently override your edited .gd files) and delete `~/.local/share/godot/app_userdata/Wasteland/patches`.
- Building a patch without the base build: (1) put the original files back for everything you changed (keep a tar of
  yours), `godot --headless --path . --export-pack Windows /home/claude/ref.pck` (no export templates needed, about
  900 MB), (2) restore your files, set version.txt, `--export-patch Windows new.pck --patches /home/claude/ref.pck`.
  The patch then holds exactly your changes. Check it by unpacking ref.pck + new.pck into a folder and booting it.
  Copy it to `updates/patch_0.2.0_NNNN.pck`, add the manifest entry, commit only the files you changed.
- Non-resource files (.bin) only ship if listed in export_presets.cfg include_filter. north_h.bin and
  lines_north.bin were missing until 0041, so the north strip never reached players before then.
- Test harnesses added: tools/_zhouse.gd (zombies into houses), tools/_seam.gd, tools/_tptest.gd (map teleport,
  weather), tools/_mallcheck.gd (mall entrances), tools/make_map.gd (bakes the Forge map), tools/bake_north_veg.py.
  Add one as an autoload line under Settings= in project.godot for a run, remove it after.
- Patch 0042 was exported with `--patches /home/claude/ref.pck,/home/claude/new.pck` (the base plus the 0041 patch), so
  it holds only its own changes. Keep each shipped patch file to chain the next one the same way (they are in updates/).
- Scripts run with `-s` can't see autoloads (Settings), so anything touching BuildGen/Melee has to run as a temporary
  autoload Node instead (see tools/_plandump.gd, tools/_mxtest.gd). A parse error in such a test script fails
  silently: the game just runs with no test output. Check the log for "Parse Error" first.
- tools/_mxlab.gd renders the player body in any clip at any moment with a stand-in weapon in hand (fast, a few
  seconds under xvfb): use it to tune animation timing and grips by eye.
- Files on the user's Drive in a link-shared folder download straight into the sandbox with
  `curl -L "https://drive.usercontent.google.com/download?id=FILE_ID&export=download&confirm=t"`; list a shared
  folder's file ids from `https://drive.google.com/embeddedfolderview?id=FOLDER_ID#list`. Don't pull binaries
  through the Drive connector (base64 into the conversation).
- Mixamo: driven through the user's Chrome (he must be signed in); downloads land in his Downloads folder, he drags
  them to Drive.
- Servos (0047): OSM fuel stations, canopies and shop outlines were fetched with Overpass through the user's Chrome
  (the workspace can't reach overpass-api.de; Claude in Chrome: open https://overpass-api.de/, run a POST fetch in
  javascript_tool, read the result back in ~950-character slices). The numbers live in tools/make_servos.py, which
  writes assets/world/servos.json, removes the old ampol_servo landmarks and adds ShopGen "servo/1/0/<brand>" lots.
  ServoGen (scripts/world/servo_gen.gd) builds forecourt, canopies, bowsers, pylon within 900 m.
- COORDINATES (0050): the game's roads and terrain use true metres per degree; the old tool conversion
  x = dlon * 111320 * cos(lat0), z = -dlat * 110574 is 0.075% / 0.227% short (37 m out at Tweed Heads). Use
  `tools/geo.py` ll(lon, lat) for anything new from lat/lon; fix(x, z) converts an old-frame position.
  tools/realign.py moved buildings.json / servos.json / yards.json once (ver "+geo1"); tools/clear_roads.py then
  pushed lots off the painted seals (lines.bin via tools/road_lines.py). EXCEPTION: the north strip (z < -16960:
  lines_north.bin, its terrain, its buildings, tools/bake_north.py) was baked in the old frame and is left as is.
  rg_graph.json (tools/road_graph.py) is also in the old frame: don't clear new lots against it, use lines.bin.
  import_footprints.py and place_trades.py now convert with geo.ll, but both still measure streets with rg_graph
  (old frame): switch those to lines.bin before re-running them. make_servos.py's numbers are old-frame (run
  realign's fix on its output). Never run realign.py on output that already used geo.ll.
- Ground key (0053 pilot): tools/sat_fetch.py X0 Z0 X1 Z1 NAME pulls NSW_Imagery zoom-20 tiles straight from
  maps.six.nsw.gov.au (reachable from the workspace; CC BY 4.0, credit Spatial Services) and reprojects to the game
  frame at 0.125 m (docs/ref/sat, gdignored). tools/sat_key.py NAME: random forest taught by OSM/Overture (seal from
  lines.bin, parking, parks, footways, water; overture extracts in docs/ref/sat/osm) -> assets/world/ground_key/
  NAME_class.bin.gz (R8 0.25 m), NAME_marks.bin.gz (R8 SDF 0.125 m), NAME_kerbs.json. GroundKey injects into the
  terrain shader before Roads' road_paint (which it switches off inside the key) and builds kerb tiles near you.
  Export include_filter carries assets/world/ground_key/*.gz.
- Ground Tagger (artifact slug a0039d09-9574-471d-a9a4-a13b2a635580; page source tools/tagger/index.html, tiles made from docs/ref/sat/NAME_rgb.png):
  the user's tags live in its db collection "tags" (db_list with that slug). Save them as
  docs/ref/sat/NAME_tags.json ([{kind, cls, pts [[x, z]], r, text}], game metres) and re-run tools/sat_key.py NAME.
- Landmarks (0052): scripts/world/herogen.gd builds the user's reference buildings with full interiors (Imperial,
  Austral as ShopGen heroes: sub part 5; Riverview as a CivicGen pub: "NAME|riverview"); tools/place_heroes.py
  puts them on their lots. Buildings._level_malls also drops shop/pub floors to the footpath on a slope and cuts the
  ground under them (not the street in front, not under roads).
- Pubs and motels (0051): tools/place_pubs.py (Overture places, geo.ll) after realign/clear_roads; civic lots take
  their real name as sub (CivicGen uses it for the sign), main-street pubs are shop "pub/2/3.0/NAME".
- Stutter hunting (0051): scripts/prof.gd. Wrap a per-frame job with `var t := Prof.t()` ... `Prof.add("job", t)`
  (or the _process -> _process_inner wrapper used in roads/buildings/servos/yards/camps/sky/cars/npcs); F9 reports
  carry "spikes" (frames over 33 ms and their top jobs) and "slowest" (worst time per job).
- Footprints (0048): `tools/import_footprints.py` turns Overture buildings (docs/ref/2026/overture_*.geojsonl.gz,
  downloaded in the workspace with `pip install overturemaps`; S3 is reachable) into lots; lots_ver starts "fp" and
  Buildings._real skips the old road / cliff passes. Run order after it: `tools/place_trades.py` (0049: hardware,
  parts, mechanics, tyres from Overture places; writes the wreckers / caravan parks to assets/world/yards.json) then
  `tools/dedupe_lots.py` (0049: drops lots standing on each other, joins Mitre 10 through to Cliffords Lane).
  Trade lots: workshop/warehouse sub "trade:NAME" (BuildGen sets p.trade and the sign; BuildProps.TRADE_RULES fits it
  out), shops "hardware/<storeys>/0/NAME". YardGen (scripts/world/yard_gen.gd) builds the wreckers' yards and caravan
  parks within 450 m; what's left in searched wrecks/vans is kept while you're in the session (not saved yet).
- Terrain3D get_height is the nearest 5 m vertex: anything laid on the ground (car parks, forecourts) uses
  ServoGen._h (bilinear) or it sinks under the drawn surface.
- Water: shaders/water.gdshader takes "dry" boxes (x0, z0, x1, z1; up to 4) where no water is drawn; set on both
  main.water_mat and main.sea_mat (Tweed City's basement).
- Write version.txt BEFORE exporting a patch (0046 shipped saying 0.2.45).
- Bridges (0045): `tools/bake_bridges.gd` (headless -s) pulled every deck centreline out of the old baked road tiles
  into assets/world/bridges.json; `BridgeKit` (scripts/world/bridge_kit.gd) rebuilds them at load (Roads._build_bridges)
  and reshapes the terrain at the ends (conform). BRIDGE_OLD=1 brings the old baked decks back for comparison. Test:
  `PT="*res://tools/_bridgetest.gd"` autoload (prints lips at every end; BRT_DUMP=ids dumps profiles). Terrain3D
  get_height returns the nearest 5 m vertex, not the drawn surface: interpolate yourself when measuring.
- 0045 features: InteractMenu (scripts/inv/interact_menu.gd), body loot (NPC._pockets, Items.LOOT zombie/scav),
  stations in BasePiece (bench / fire / garden, `menu()`, state in meta "st", saved), chopping (Vegetation.chop, felled
  saved in world.save), recipes with "station". Feature test: `PT="*res://tools/_featuretest.gd"` (FT lines;
  InteractMenu.test_any_mouse lets headless runs show the menu). tools/fix_sheds.py turned town sheds into houses.
- New class_name scripts need the class cache rebuilt before -s or autoload tests see them:
  `godot --headless --path . --editor --quit`.
- Tweed City v2 (0044): `python3 tools/trace_mall2.py docs/ref/2026/tweed_city_annotated.jpg assets/world/twin_city.json
  [debug.png]` reads the user's hand-coloured plan (key in the picture: red walls, green ways in, yellow toilet
  doors, purple covered, orange travelators down, pink cinema upstairs, grey stairs) and writes JSON v2; PolyMall.build2
  builds it (floor, covered walkways, travelators to the car park at -4, ramp, cinema floor at +5.2). The inside flood
  seeds at pixel row/col (520,480): if a re-annotated plan moves the food court, move the seed. Walk test: add
  `PT="*res://tools/_polytest2.gd"` under `Settings=` in project.godot and boot with
  `WASTELAND_NO_UPDATE=1 WASTELAND_AUTOPLAY=1 VEG_OFF=1` (remove the line afterwards). Floors that meet must abut
  flush: any overlap step of ~17 cm stops the player. `"lamp"` is an unshaded finish for fake lights (no cost).
- Export verify without the base build: chain `--patches /home/claude/ref.pck,new.pck,p42.pck,p43.pck,...`;
  ref.pck lacks the Poly Haven .gltf sources, so ~130 build_props "instantiate on null" errors at boot are expected
  there (players have them from the real base build).
- Traced malls (0043): `python3 tools/trace_mall.py <directory screenshot> assets/world/<name>.json [debug.png]`
  turns a centre's coloured directory plan into polygons; `PolyMall` (scripts/world/polymall.gd) builds from it.
  The colour thresholds and the crop at the top of the script are for the Tweed City screenshot; another centre
  needs its own. `tools/_polylab.tscn` builds one mall on flat ground and photographs it in seconds:
  `MALL="TWIN CITY" W=378.3 D=244.7 SEED=20261112 OUT=/tmp/shots/pl_ SHOTS="top:0,470,0.1:0,0,0:50:top" xvfb-run -a
  -s "-screen 0 1200x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility
  res://tools/_polylab.tscn` (a scene run this way has the autoloads, unlike `-s` scripts).
- tools/run_shots.sh adds a Shot autoload to project.godot while it runs: never export or run another Godot job
  against the project until it has finished.
- Screenshots render at about 1 fps here (software GL under xvfb): a two-shot run takes 5 to 10 minutes.

- Streets by the block (0054): `tools/make_streets.py [x0 z0 x1 z1]` (whole map ~100 s, needs shapely, scipy,
  mapbox-earcut, matplotlib via pip) reads lines.bin + lines_north.bin, buildings.json, bridges.json, servos.json and
  Overture extracts in docs/ref/streets (gitignored; `overturemaps download --bbox=153.28215,-28.47565,153.58502,-28.14179
  -f geojsonseq --type=segment|infrastructure|land_use -o docs/ref/streets/<type>.geojsonl`, S3 reachable) and writes
  assets/world/streets.bin (in the export include_filter). Blocks = the map minus the road surface (NOT polygonize:
  the painted centrelines don't always meet), big leftovers cut into 200 m cells. scripts/world/streets.gd streams 128 m
  tiles within 480 m, builds over several frames (2.5 ms slices), collision within 170 m; paint goes into Roads' overlay
  world (road.gdshader style > 0.9 = solid paint). Streets.hard() masks veg. Tests: `PT="*res://tools/_streettest.gd"`
  (counts, kerb heights by ray, build time per tile); `tools/_streetshots.gd` (ST_X, ST_Z, ST_ONLY) photographs a
  shopping / town / estate street, lights, bus stop, car park. GroundKey is off unless GROUND_KEY=1.
- 0055 engine kit / body cuts / trays: scripts/vehicle/engine_kit.gd (EngineKit: parts, item ids eb_/eh_/ex_/ei_/ef_/
  ecu_, faults, stats() in VehicleSpecs.ENGINES shape, code-made meshes; design.kit on every car, old designs get
  EngineKit.stock(def)), body_cut.gd (BodyCut: user://body_cuts.json over res://assets/vehicles/body_cuts.json,
  pieces() splits a model's index arrays into cab/tub/bonnet, bay_node() clipped by a polygon shader), tray_gen.gd
  (design.tray), scripts/body_tools.gd (pause menu). Car: rebuild_body(), take_off_bonnet()/refit_bonnet(),
  unbolt_tub()/bolt_tub(), build_tray(), refresh_engine(). Engine stand = BasePiece kind "stand". Tests:
  PT="*res://tools/_kittest.gd" (480 builds, rules, a pickup cut / tray / bonnet / tub); tools/_kitshots.gd (lineup,
  trays, the F9 spots). Parked-car LOD: meta "lod_parked" (car.gd); NPC LOD past 50 m (npc.gd).
- 0056 world data passes, in this order when redoing: tools/fill_roads.py (adds Overture roads to lines.bin where
  none are painted), tools/fix_footprints.py (houses inside their roof outline, off the roads; marks the file),
  tools/fix_types.py (businesses need proof; school campuses, big traced outlines cut into their own wings; marks the file; rerun from the 0055 buildings.json through fix_footprints first), then tools/make_streets.py (now STR3:
  index entries carry the plant-mask offset; fences per block parcel). Backups of 0055 state: /tmp/buildings_0055.json,
  /tmp/lines_0055.bin (gone in a fresh sandbox; the repo history has them). Buildings._yard fences are off while
  Streets has data.
- 0057 engine view: scripts/vehicle/engine_view.gd (EngineView, main.engine_view; open_for(kit, {title, changed,
  on_close, block_ok})). EngineKit's Mk tags every primitive with a part, so part_meshes(k) gives one mesh per slot
  (block, head0/1, exhaust0/1, intake, fuel, ign, ecu, alt) while commit() still merges by material for the car (same
  draw calls). Slot API: slots / slot_id / slot_label / ghost_kit / slot_for / fit / take_off / cant_take_off /
  part_info / part_mesh. Picking is TriangleMesh.intersect_ray per part in a SubViewport with its own world.
  EngineView.icon(id) renders engine-part pictures on demand and hands them to ItemIcons.put (inventory); WorldItem
  draws dropped engine parts with part_mesh. Test: PT="*res://tools/_engviewtest.gd" under xvfb (e_*.png shots).
- 0059: Car._read_controls has the throttle foot (_thr_lim) and drift assist (Settings traction_foot / drift_assist);
  tools/_tyretest.tscn tests brakes, launches, assist and feathering. BodyCut paint: entry.paint = {n, runs:
  [[start, len, part]]} over the model's triangles in meshes_of order (1 cab, 2 tub, 3 bonnet); BodyCut.of() derives
  a painted bonnet's pts (hull) and a painted tub's front. Catalog entries can carry ride, tyre_r, track, lift,
  wheels (per-axle wheel models), drive_f, gearbox, final, front_share (VehicleSpecs.default_design). Sketchfab
  token in /home/claude/.secrets/sketchfab_token (NOT in git; the user's, from an earlier chat); search/download
  helpers: tools/sketchfab_search.py, tools/sketchfab_dl.py (download to /home/claude/sf/dl/<name>). World data pass order now ends ... fix_types.py,
  fix_overlaps.py, then make_streets.py.
- 0060: tools/import_vehicle.py (src glb, key, glb name, title, length, kg, cls [--flip]) cuts the four wheels off a
  downloaded body (round parts at the corners and everything inside them), writes the body, a wheel model and the
  catalog entry (/tmp/<key>_entry.json). tools/import_wheel.py turns the rim face to +Z; import_jdm_rims.py lines
  the pack's tyres up. Catalog eng_y drops the engine under a low bonnet. Forge props can carry "scale".
- Release without the base build (0054, check_export.sh / release.sh need ../build/Wasteland.pck which a fresh sandbox
  doesn't have): do 3b's ref.pck route. Restore the repo's versions of every changed file, `--export-pack Windows
  /home/claude/ref.pck`, put yours back, write version.txt, `--export-patch Windows new.pck --patches /home/claude/ref.pck`.

## 4. Test and release loop (all scripts exist in `tools/`)
- `tools/smoke.sh`: boots the game headless 400 frames, prints script errors. Env flags used everywhere:
  `WASTELAND_NO_UPDATE=1 WASTELAND_AUTOPLAY=1 VEG_OFF=1`.
- `tools/check_export.sh`: builds the would-be patch exactly as players load it, runs it under `xvfb-run`
  (OpenGL, 960x540) and prints "EXPORT OK" or "EXPORT BROKEN". Run this before every publish.
- `tools/run_shots.sh` + `tools/shot.gd`: screenshots; `SHOT_PLAN="name:mode:x:z:yaw:pitch;..."`
  (mode foot | car | carcab | drive). Edit the hard-coded `out` path in shot.gd for the new session.
- `tools/mp_test.sh`: two headless copies, one hosts, one joins 127.0.0.1, prints what each sees (LAN sync test).
- Other self-tests: `CAR_TEST=1`, `MELEE_TEST=1` (PROBE lines), `BASE_TEST=1/2`, `tools/combat_test.gd`,
  `tools/test_drive.gd`, lab scenes `_malllab.gd`, `_shoplab.gd`, `_houselab.gd`, `_servolab`.
- Publish a patch: `tools/release.sh patch 0041 "notes"` (diffs against the base build and every earlier patch,
  splits files over 95 MB into 90 MB pieces, updates `updates/manifest.json`, commits and pushes; needs the push
  clone). A new full build: `tools/release.sh full 0.3.0 "notes"`. NOTE the script's commit trailers reference an old
  session URL; update them to the current session's attribution line.
- I have NOT run the headless game with real terrain in this session because the terrain data wasn't present.

## 5. Decisions already made (do not re-ask)
Full list in `docs/DESIGN_0.3.md` (50-question session, 2026-11-07). Headlines:
- Own fictional universe on the real Tweed terrain. Goal = base + car building + loose goals (trader jobs, airdrops).
- Hunger and thirst only. Lose nothing on death; respawn at bed or random. Bites infect (antibiotics).
- Rust-style base building (wood > tin > brick), build anywhere, no claim/upkeep, fortify existing buildings.
- Tools needed but no tiers, no blueprints, no durability. Many melee weapons. Craft ammo only; guns are found.
- 60 min day/night (45/15), more zombies at night, rain/storm/fog. Three zombie types. Scavs on foot and in vehicles.
- Cars: fuel only, parts found and traded, cab + chassis separate, found cars not drivable until fixed.
- LAN co-op only (no friendly fire), host's world save, joiners keep their character. Creative/Forge is a host
  toggle (Settings: game_mode creative or survival). One difficulty.
- Art: realistic, bleached/green-subtropical, eye-level camera; low poly is a no-go. Shoulder and first person only.
- Windows only, local download with the launcher patching it. No touch controls.
- Assets: Meshy for cars and characters (Mixamo skeleton), Poly Haven CC0 for the rest, user makes guns himself later.

## 6. What exists (as of 0.2.40; the docs only run to 0.2.36, the manifest has the rest)
- World: real terrain with painted-flush roads and bridges; about 33k generated buildings (houses incl. Queenslanders,
  sheds, farms, shop rows, pubs, schools, churches, hospitals, police, fire stations, post offices, motels, halls);
  Ampol servos; Sunnyvale Mall (real plans); Twin City (diagonal glass-roofed mall, cinema, supermarkets);
  Bay Mall (real Tweed Mall plan, multi-level drive-up car park); beachfront towers with a lift; map extended 3 km
  north past the border with LiDAR ground (about 60% of the new strip, rest on public elevation data).
  Tropical vegetation, sugar cane, green ground, sky shader (clouds, stars, moon), sea back in.
- Survival and combat: grid inventory with clothing pockets, 8 guns, melee (9 weapons, kicks, dodges, throws),
  stamina/hunger/thirst, zombie breeds with screams, knockdown ragdolls, gore, scav camps.
- Cars: found in states (engine, battery, fuel, keys, hotwire), garage and cab+chassis build, engine audio.
- Building and crafting: crafting menu (N), base build mode (M), boards and windows, roller doors.
- Tools: Forge/Oracle mode, pause menu with graphics presets, bug reporter (F9), save game (autosave 60 s), LAN host/join.

## 7. Outstanding (verify against the code before starting)
From the user's lists and the docs:
- LAN sync of doors, windows, boards, containers, mall shutters and base pieces (not synced). Netcode
  interpolation/prediction for accurate two-client play.
- Half 2 leftovers: work stations, harvesting (trees, rocks, wrecks, animals, plants), doors/gates for base
  doorways, spikes/wire/traps/lights, farming and cooking, infection, traders (2-3 outposts, bottle caps), airdrops,
  bed respawn, scav tactical AI (cover, flank, call help, retreat) and armed vehicles.
- Cars: no damage model yet; custom simulation suspension with visible shocks/springs/arms; project-car chassis
  not appearing (user report, parked); sliding shed doors; general house/shop/servo polish and the generated-house
  pipeline.
- Art/perf: new downloaded plant models and ground textures (user approved downloading); frame-rate cost of dense
  plants and 36k buildings on the GTX 1650 Ti is unmeasured; check Sunnyvale ramp room brown band and black ceiling.
- Known crash: pressing I (inventory) near a car cab/shell (0.2.23); the F9 crash-log zipping on next start (item 9
  in MALLS.md) may not be done.
- Never confirmed in the real game by the user: Sunnyvale ceilings/floors, zombies following up the ramp, the T/G/K key fix.
- Fix the docs: `docs/DESIGN_0.3.md` and `MALLS.md` say Twin City, Tweed Mall and the north extension are TODO, but
  patches 0.2.37 to 0.2.40 shipped them. Append a 0.2.37-0.2.40 section.

## 8. Suggested first moves for a new session
1. Do section 3 steps 1 to 4. Get terrain data and assets restored (ask the user for whatever is blocked).
2. Run `tools/smoke.sh`, then `tools/check_export.sh`. Fix anything red before new work.
3. Pick a big chunk from section 7 (LAN sync + netcode is the most self-testable with `mp_test.sh`).
4. Release with `tools/release.sh patch 0041 "..."` and keep `docs/` updated as you go so this file stays true.
