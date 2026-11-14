# Wasteland: master to-do list

This is the one list. Every Claude session reads it first and updates it before releasing a patch.
Tick `[x]` when shipped (with the patch number), never delete a line without the user saying so.
Newest requests at the top of each section. Last updated: patch 0041 work, 2026-11-14.

## Requested 2026-11-14 (patch 0041)
### Bugs
- [ ] The 3 km north extension doesn't stitch into the existing LiDAR terrain (visible step at z = -16960)
- [ ] Zombies don't pathfind into houses
- [ ] Houses still sit on roads
- [ ] Tweed Mall (Bay Mall) and Tweed City (Twin City) have no entrances
- [ ] Tweed City not built to reality, despite the screenshots (docs/ref, docs/tweed_city_plan.png). Asked many times.
- [ ] Clouds move too fast
### Features
- [ ] Time and weather sliders in the Forge palette
- [ ] Minimap in the palette: click to open, click anywhere to teleport
- [ ] Setting is 2020 now: add guns from that period
- [ ] Find a modular bridge-making addon and replace every code-built bridge with it
- [ ] Classic cars "a bit useless now, kinda" (2020 setting): QUESTION for the user: add modern cars, keep classics as rarer finds?

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
