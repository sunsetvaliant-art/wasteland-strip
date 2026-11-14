# Wasteland: master to-do list

This is the one list. Every Claude session reads it first and updates it before releasing a patch.
Tick `[x]` when shipped (with the patch number), never delete a line without the user saying so.
Newest requests at the top of each section. Last updated: patch 0041 work, 2026-11-14.

## Requested 2026-11-14
### Bugs
- [x] 0041 North strip seam: it was the ground texture and plants, not the height. The strip now has its own
      vegetation map (tools/bake_north_veg.py), ground textures mirrored from just south of the seam, beach sand only
      along the ocean, and its heights stitched to the live terrain at runtime
- [x] 0041 Zombies follow you into houses: track you inside, route round the house to the nearest door, through
      doors and up stairs, clamber onto raised doorsteps, shove past hall furniture (tools/_zhouse.gd: 12 of 12 houses
      in two test areas)
- [ ] NEW: Queenslanders on steep hillsides: the stairs stop metres above the ground (zombies and players can't get
      in). Found by tools/_zhouse.gd at x 11126, z -13366 (4 of 6 failed there)
- [x] 0041 Houses off the roads: every lot checked against the painted road edges, 843 nudged clear, 1,025 small
      buildings that couldn't be cleared left out; malls, civic and big buildings never removed (baked into
      buildings.json, so cupboards start fresh once)
- [x] 0041 Twin City and Bay Mall entrances: the outside cladding was drawn solid over their doorways; now cut round
      every opening and window
- [ ] Tweed City not built to reality, despite the screenshots (docs/ref, docs/tweed_city_plan.png). Asked many times.
      NOT done in 0041. Plan: trace the current outline from docs/ref/tweed_city_gmaps_indoor.jpg (about 0.665 m a
      pixel at 540 px wide; the mall sits about 9 degrees off north), use it as the footprint instead of the lot
      rectangle, lay out today's tenants (gmaps), angled west wing and food court, cinemas mid-west, big store south;
      check by drawing the plan over the gmaps picture before building
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
- [x] Kick too powerful (2026-11-14): standing kick is now a shove (3 m/s, 1 in 4 go down), flying kick floors them
      (7.5 m/s). In source, ships with patch 0042
- [ ] Kick and melee swing animations look off ("a bit how ya goin"): replace the procedural leg/arm (BodyMods.kick /
      strike) with Mixamo clips. Mixamo needs the user's Adobe sign-in: either Claude drives his Chrome or he downloads
      a list Claude gives him, then drops the FBX files in Drive WASTELAND folder for Claude to pull

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
