# Wasteland Strip 0.3.0 design (agreed 2026-11-07, 50 questions)
Our own universe on the real Tweed terrain. Goal: base + car + loose goals.
Delivery: two halves. Half 1 = world + loot. Half 2 = base/crafting/scavs/traders.

## World
- Roads flush with terrain (painted on ground, no raised mesh/edges). Off-road: grippy, slower (more rolling drag).
- House generator: floor plan -> rooms (BSP/treemap) -> extruded walls w/ door+window cuts -> roof -> room tags -> props by room.
  Types first: houses (incl. Queenslander under-house, two-storey), rural (sheds, tanks, dairies), industrial (mill, depot, workshop).
  Look: lived-in, abandoned. Doors open/close only (zombies push). Loot opens instantly; containers + loose items not chosen -> containers.
- Ampol servo (Meshy, incoming/ampol_servo.glb) as the enterable servo (replaces lost Golden Fleece).
- Density realistic: towns at real spots w/ fictional names, sparse farms between.
- Loot: room-realistic + rarer in dangerous areas; respawns over time when no player near.
- Day/night 60 min (45/15). Nights: more zombies. Weather: rain & storms, fog.
- Saves: host's world; joiners keep their character.

## Survival
- Hunger & thirst only. Food: tins/bottles, hunt & cook, rivers/tanks (boil), farming.
- Death: lose nothing. Respawn: bed at base else random.
- Bites: infection, needs antibiotics.
- Start: knife, water, food, bandage + pistol & few rounds. No car (find one).
- Animals: roos/wallabies, feral cattle & boar, ducks/chooks/rabbits. No infected animals.

## Base & crafting
- Rust-like: pieces on grid AND fortify existing buildings. Tiers wood > tin > brick. No claim/upkeep. Build anywhere.
- Defences: walls & gates, spikes & barbed wire, turrets/traps, lights & alarms. Storage: crafted boxes + found furniture.
- Harvest: trees & rocks, wrecks & junk (not building structure itself), animals, plants & cane.
- Tools needed, no tiers. Stations by job (bench, forge/welder, kitchen, garage, ammo press). Everything known (no blueprints).
- No durability. Melee: many (bat, machete, pipe, axe, crowbar, tyre iron). Craft ammo only; guns found.

## Enemies
- Zombies: keep 3 types; big hordes roam randomly; attack bases (with scavs).
- Scavs: foot squads + armed vehicles on roads; tactical AI (cover, flank, call help, retreat). Camps raidable, best loot, respawn.
- Hostile scavs + traders (2-3 outposts). Currency: bottle caps/coins. Trader jobs.
- Airdrops: parachute crates + crashed convoys, ~once per game day.

## Cars
- Fuel only (no wear). Parts found + traded.

## Modes
- LAN co-op only (no friendly fire). Creative/Forge = host toggle. One difficulty.

## Half 1 status (0.2.16)
- BuildGen (scripts/world/buildgen.gd): plans (hall / open layouts, stairs), shells with box collision, doors, windows, roofs (gable/hip/skillion), stumps/slabs, verandahs, LOD.
- BuildProps (scripts/world/build_props.gd): furnishing rules per room type, Poly Haven + built fixtures, containers, deferred model loading.
- Buildings (scripts/world/buildings.gd): 20.8k lots from tools/place_buildings.py (OSM buildings + street fill + industrial + farms), full builds < 135 m, threaded merged LOD cells to 1.15 km (dithered out < 110 m), loot store + respawn (30 min away), veg/zombie/camp exclusion.
- Roads: flush skin built at runtime from assets/roads/lines.bin (tools/bake_roads.py FLUSH=1 MESH_ONLY=1 PILOT_CUT=/nonexistent); bridges baked with collision; car surface from road mask; grass grippy.
- Ampol servo (Landmarks): doorway cut, plinth, furnished shop + workshop, at real fuel stations.
- SkyCycle: 45/15 min day/night, weather (clear/cloudy/rain/storm/fog), rain fx + sounds, lightning, night zombies x2.2, wet grip; LAN host sync.
- SaveGame: user://world.save (host), user://character.save (everyone), autosave 60 s + quit.
- Not yet: doors/containers not synced over LAN; main-street shopfronts; danger-scaled loot.
