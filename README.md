# Wasteland

Open-world survival and vehicle building in an overgrown, post-apocalyptic Tweed Valley (Murwillumbah, NSW).
Godot 4.7.2 · Terrain3D 1.1 · Jolt physics · Windows.

## Playing
Download the latest **full** release, unzip, run `Wasteland.exe`. The game opens on its launcher, which downloads any
newer `patch_####.pck` releases into the `patches` folder and loads them. Patches only carry what changed.

## Building from this repo
1. Godot 4.7.2 (standard build) with export templates.
2. Terrain data (~270 MB) isn't in git: download `terrain-data.zip` from the v0.2.0 release and unzip it so the
   `terrain/` folder sits beside `project.godot` (or rebuild it with `tools/bake_terrain.gd`).
3. Open the project once in Godot to import assets, then export the "Windows" preset.

## Layout
- `scripts/` game code: `main` (world), `player`, `car`, `veg` (plants), `forge` (Forge mode), `pause_menu`, `settings`, `launcher`, `rig` (characters)
- `assets/` ground textures, vehicles, props, plants, water, characters
- `tools/` build scripts: terrain and plant bakes, model converter from the browser build, release and patch publishing, screenshot harness

## Controls
On foot: WASD · mouse · Shift sprint · Ctrl/C crouch · Space jump · V shoulder/first person · F get in/out · O Forge · Esc menu
Driving: W gas · S brake · Space handbrake · Q/E gears (P R N D) · L lights · V cab view · [ ] seat height
Forge: Tab palette · 1 place · 2 phys gun · 3 delete · 4 terrain · F inspect · P drop player · Ctrl+S save · Ctrl+Z undo
