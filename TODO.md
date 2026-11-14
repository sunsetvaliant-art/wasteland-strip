# Wasteland: master to-do list

This is the one list. Every Claude session reads it first and updates it before releasing a patch.
Tick `[x]` when shipped (with the patch number), never delete a line without the user saying so.
Newest requests at the top of each section. Last updated: patch 0042, 2026-11-14.

## Requested 2026-11-14
### Bugs
- [x] 0041 North strip seam: it was the ground texture and plants, not the height. The strip now has its own
      vegetation map (tools/bake_north_veg.py), ground textures mirrored from just south of the seam, beach sand only
      along the ocean, and its heights stitched to the live terrain at runtime
- [x] 0041 Zombies follow you into houses: track you inside, route round the house to the nearest door, through
      doors and up stairs, clamber onto raised doorsteps, shove past hall furniture (tools/_zhouse.gd: 12 of 12 houses
      in two test areas)
- [x] 0042 Hillside houses: high-set houses now sit low on the uphill side (floor = highest ground + 0.45 m, the full
      stump height only on the downhill side), flights can run to 70 steps, and 459 small buildings on cliff-steep
      lots (ground falling more than 7 m across the lot) are left out. tools/_zhouse.gd at x 11126, z -13366: 4 of 6
      (was 2 of 6)
- [ ] Still open there: 2 of 6 Queenslanders in the steepest streets, the zombie doesn't get from the street to the
      stair foot (stays ~10 m out front, 1.5 to 2 m below the floor). Lots 13725 and 10990
- [x] 0041 Houses off the roads: every lot checked against the painted road edges, 843 nudged clear, 1,025 small
      buildings that couldn't be cleared left out; malls, civic and big buildings never removed (baked into
      buildings.json, so cupboards start fresh once)
- [x] 0041 Twin City and Bay Mall entrances: the outside cladding was drawn solid over their doorways; now cut round
      every opening and window
- [ ] Tweed City not built to reality. Asked many times. STILL OPEN after 0042. What exists is a schematic traced
      from the directory plan (docs/tweed_city_plan.png): same anchors and malls, with the diagonal mall as two angled
      shop rows inside a glass court. docs/ref/twin_city_now_vs_real.png shows the in-game plan beside the Google map
      at the same scale. Differences seen: (1) the real west wing runs off at an angle to the south-west (dining
      precinct) and the west concourse sits right under the north-west anchor; in game it's a straight wing further
      south. (2) the real diagonal mall is about 150 m long and reaches the cinema; in game the court is about 95 m.
      (3) the east side steps in and out; in game it's squarer. (4) outside: car parks, roof and signage not checked.
      WAITING on the user: which of these (or what else) is the "not per reality" he means, now that 0041 gave it
      entrances and he can get inside
- [x] 0041 Clouds about 6x slower (a layer crosses the sky in about 90 s)
### Features
- [x] 0041 Forge palette opens on a "Time & Weather" tab: time slider, stop the clock, weather slider (clear to
      storm), fog slider, back to natural weather
- [x] 0041 Map tab in the palette: the whole valley (tools/make_map.gd bakes assets/world/map.png); click anywhere to
      teleport, red dot shows where you are
- [ ] 2020 setting: add guns from that period. USER (2026-11-14): Claude hunts for free/licensed models, and good
      sounds too. Candidates for Australia 2020: Glock 17/19, S&W M&P (police), EF88 Austeyr (army), AR-15 / M4,
      Remington 700, Ruger 10/22, Lithgow LA101, Beretta 92, Mossberg 500
- [ ] Bridges: no addon exists for Godot 4. USER (2026-11-14): build our own modular bridge kit (spans, piers,
      railings, abutments placed on the real bridge lines) and replace every code-built bridge with it
- [ ] Classic cars vs 2020 setting: USER (2026-11-14): leave the cars for the moment
- [x] 0042 Kick toned down: a standing kick is a shove (3 m/s, 1 in 4 go down), the flying kick floors them
- [x] 0042 Mixamo melee animations (downloaded through the user's Chrome 2026-11-14, baked into
      assets/characters/mx_clips.res by tools/bake_mixamo.gd): thrust kick and flying kick (the boot lands 0.2 s
      after the key), punches (cross, hook), one-handed swings (side, down, backhand), two-handed swings (bat, axe,
      sledge), knife (stab, downward); the weapon sits in the right hand (BoneAttachment, Melee.grip_xf) in shoulder
      view and during a swing in first person; zombies flinch when hit, stumble when booted, and get up off the
      ground with a clip (from the back or the front, turned to match how they lay). Hit moments tuned by eye in
      tools/_mxlab.gd; end-to-end test tools/_mxtest.gd
- [ ] Melee animation follow-ups: the user to check the grip and swing in first person; feet slide if you swing
      while running (the clip is full-body); scavs don't use the clips yet; LAN clients see the clip from its start;
      mx_stab and mx_swing_back spare. The FBX sources are NOT in git: Drive WASTELAND/mixamo (to rebake: copy to
      assets/characters/mx_src with the retarget import settings, import, run tools/bake_mixamo.gd, remove the folder)

## Older, still open
### World and buildings
- [ ] Multi-level car park for Twin City (Bay Mall has one since 0040)
- [ ] Sexton Hill cutting
- [ ] New downloaded plant models and ground textures (user approved downloading)
- [ ] Sliding shed doors (only roller doors exist)
- [ ] Kingscliff, Banora, Cabarita shopping centres as small single-level centres
- [ ] Sunnyvale ramp room: brown band on side walls, black ceiling
- [ ] ~10% of real buildings left out where OSM roads and outlines disagree
- [ ] Verandah deck renders too dark in one shot
### Cars
- [ ] Project-car chassis not appearing (user report, parked by user)
- [ ] Car damage model (spanner repairs have nothing to fix)
- [ ] Simulation-spec suspension with visible shocks, springs, arms, sway bars
- [ ] Waiting on user: car files Bare_Bones_Muscle and Rustbound_Chevy_Relic
### Survival, base, enemies (half 2 of the 0.3 design, docs/DESIGN_0.3.md)
- [ ] Work stations (bench, forge/welder, kitchen, garage, ammo press)
- [ ] Harvesting: trees, rocks, wrecks/junk, animals, plants/cane
- [ ] Doors and gates for base doorways; spikes, barbed wire, traps, turrets, lights, alarms
- [ ] Cooking, boiling water, farming
- [ ] Bite infection + antibiotics
- [ ] Traders (2-3 outposts, bottle caps) and trader jobs
- [ ] Airdrops / crashed convoys, about once a game day
- [ ] Bed respawn
- [ ] Scav tactical AI (cover, flank, call help, retreat) and armed scav vehicles on roads
- [ ] Animals: roos/wallabies, feral cattle and boar, ducks, chooks, rabbits
- [ ] Zombie hordes roaming and attacking bases
### Multiplayer
- [ ] LAN sync: doors, windows, boards, containers, mall shutters, base pieces
- [ ] Netcode interpolation and prediction for accurate two-client play
### Bugs and tech
- [ ] HARD CRASH: pressing I near a car cab/shell (0.2.23); need the crash log
- [ ] On start, zip the previous crashed session's log next to the F9 reports and tell the player
- [ ] Frame rate on the GTX 1650 Ti with dense plants and ~36k buildings: unmeasured
- [ ] Never confirmed in game: Sunnyvale ceilings/floors, zombies following up the ramp, T/G/K key fix
### Later
- [ ] Guns modelled by the user
- [ ] Clothing pieces modelled by the user, Mixamo animations
- [ ] Generated house pipeline polish; Queenslander variety

## Done (newest first)
- [x] 0040 North strip uses LiDAR where it has data; Bay Mall multi-level car park
- [x] 0039 Civic buildings (schools, churches, hospitals, police, fire, post, motels, halls, pubs)
- [x] 0038 Map 3 km north past the border, beachfront towers with lifts
- [x] 0037 Twin City diagonal mall, Bay Mall from the Tweed Mall plan
- [x] 0036 Towns re-laid, houses squared to streets
- [x] 0035 Green ground, sugar cane
- [x] 0034 Knockdown ragdolls, kicks, new sky
- [x] 0033 Mall levelling, Forge World tab
- [x] 0031 Cars as you find them (keys, hotwire, under the bonnet)
- [x] 0030 Melee, hunger/thirst, zombie breeds
- [x] 0029 Crafting and base building, first cut
