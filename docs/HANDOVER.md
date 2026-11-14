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
