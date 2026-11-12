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

## 0.2.17 (bug round after half 1)
- Step-up for everyone who walks (StepUp.slide); stair ramps run past the bottom tread; zombie model stray colliders stripped.
- Zombies/scavs route through doors, openings and stairs (Buildings.route, a room graph per full building).
- Roads painted into the terrain: road skins drawn top-down into 3 cascades (512 m / 2 km / 8 km, 2048 px), blended in Terrain3D's shader (override). Grass kept off the seal by exact centreline distance (Roads.edge_dist).
- Grass: per-clump thinning/hand-over in the shaders, no per-cell visibility ranges.
- Windows (BuildWindow): open (F), climb (Space), shoot to break, board up. Roller doors (BuildRoller): F; zombies can't. Boards: G with hammer + nails (3 jobs a box) + planks (2 window / 3 door); zombies beat them in; F with a hammer prises them off. Boards and broken windows saved.
- Furniture: chairs, stools, side tables, small boxes etc. are carryable (frozen RigidBody until picked up).
- Items: binoculars and torch are held tools (gun slots); T tapes a torch to the gun in hand (uses a torch + duct tape) and switches it; tape, hammer, nails, plank with models + icons; oil can 2x1.
- Cars: rolling chassis and loose bodies at sheds/workshops/yards (Buildings._project_car); K with a shifter opens the garage on the car you're at (survival); "Body fitted" switch; boots/trays/wagon backs (F at the back); cars you've driven are saved with the world (with their boot).
- 50-question audit fixes: LAN co-op has no friendly fire (Q24); survival starts with no car (Q47).
- Still for half 2: Q1-8, 10, 11, 17-21, 23, 32, 34-37, 39-46, 48 (creative as a host toggle).

## 0.2.29: first cut of half 2 (crafting and base building)
- Crafting (N): scripts/craft/craft_ui.gd, Items.RECIPES (all known, tools not used up, no stations yet). New materials
  in the loot tables: scrap, rags (cloth), wire, rope, gunpowder, spent cases (brass), sheets of tin, bricks.
  Makes: bandages, first aid kit, rope, nails, tin sheets, planks, torch, small pack, all five kinds of ammo.
- Building (M, needs a hammer): scripts/base/base_build.gd + base_piece.gd. Pieces: wall, doorway, window wall, half wall,
  floor/roof, stairs (a 2-cell ramp), storage crate (8x5). Tiers wood (3 planks + nails) / tin (2 sheets, plank, nails) /
  brick (6 bricks), hp 250/500/1000. Snaps to a 1.5 m grid and quarter turns; [ ] and PgUp/PgDn raise and lower;
  X pulls a piece down for half back. Zombies beat pieces down (npc.gd). Saved in world.save ("base").
- Not yet: work stations, harvesting trees/rocks/wrecks, doors and gates for doorways, spikes/wire/traps/lights,
  melee weapons, LAN sync of pieces, hunger/thirst/cooking/farming, infection, traders, airdrops, bed respawn.
- BASE_TEST=1/2 spawns three demo huts by the start (and opens the craft menu with 1).

## 0.2.30: fighting, the body, zombie breeds
- scripts/combat/melee.gd (Melee, a child of the player): stamina, hunger, thirst; melee with the best weapon carried
  when the gun's away (H): fists, knife, tyre iron, pipe wrench, bat, crowbar, machete, axe, sledgehammer (WEAPONS);
  Q kick (flying kick off a sprint jump), Alt dodge, crouch at a sprint slides, jump at a ledge 0.75-2.45 m climbs it,
  X throws brick / bottle / petrol bomb / the weapon (thrown.gd, fire.gd). MELEE_TEST=1 runs a self test (PROBE lines).
- Food has "eat", drinks "drink"; water bottles and soft drink in kitchens, fridges, shops; hp drains at zero.
- Zombies: breeds (walker, 14% runner, 6% brute), a scream that brings others within 28 m, 1.3x faster at night,
  grabs (Q to break), knockback (knock_t).
- Still to do from the user's list of 2026-11-12: vehicle keys / hotwiring / engine repair window / Zomboid-style car
  and loot spawns; tropical foliage variety; ground and grass textures; dedicated swing animations.

## 0.2.31: cars as you find them
- scripts/vehicle/car_care.gd (CarCare): each car's state rolled once from where it stood (engine 8-100, battery flat
  1 in 4, fuel often empty, key in ignition 12% / in the cab 20% / none). K opens "under the bonnet": look it over,
  search the cab, try a found key (1 in 3 fits), hotwire (1 wire a go; 10/30/60/85/100% by mechanic level), pour
  fuel, top up oil, clean plugs (no tools); repair engine, fit / take battery, the old garage rebuild (shifter).
  Fuel burns, a worn engine is down on power and stalls. Mechanic xp in player.melee.skills. CAR_TEST=1 self test.
- Family cars in driveways (Buildings.DRIVE_CHANCE), keys and batteries in the loot. Creative: every car just goes.
