# Wasteland: master to-do list

This is the one list. Every Claude session reads it first and updates it before releasing a patch.
Tick `[x]` when shipped (with the patch number), never delete a line without the user saying so.
Newest requests at the top of each section. Last updated: patch 0045, 2026-11-15.

## Requested 2026-11-14 (late)
### Bugs
- [x] 0045 Bridges: terrain doesn't meet the decks, cars get stuck in the gap (bug report 2026-11-14 17:57 at x 474,
      z -469). All 232 bridges rebuilt by the modular kit (scripts/world/bridge_kit.gd); the ground is reshaped to meet
      each end and a 12 m approach slab runs down into the road. tools/_bridgetest.gd: lips over 8 cm at 27 of 464 ends
      (was 163; the bug-report end 0.46 m -> 0.01 m). The 27 left are motorway interchanges, mostly where another
      bridge passes overhead
- [x] 0045 Driving: steering lock now falls with speed to what the tyres can use (0.30 rad at 36 km/h, 0.12 at
      90+), winds on slower at speed and comes back quicker; throttle goes down over about half a second; Shift + W
      floors it at once for a burnout. User to try it and say if it wants more or less
- [x] 0045 Too many sheds where houses should be: 311 sheds in town streets turned into houses like their neighbours
      (tools/fix_sheds.py). Rural sheds and garden sheds stay
- [ ] Sheds: check 107 Commercial Road, Murwillumbah in game; user will F9 any more
### Features
- [x] 0045 Interaction menu like Vein (scripts/inv/interact_menu.gd), also on work stations and the ground: aim the crosshair at something and a small Windows-style right-click menu shows;
      mouse wheel picks, left click does the highlighted (default) option; right click hides it on that object for 5
      seconds so you can swing or shoot. Dead zombie: Open inventory. Car: Drive, Repair (opens the menu),
      Inventory. Window: Barricade, Open / Close
- [x] 0045 Zombies and scavs carry loot (rags, lighters, the odd key, bandage, drink, ammo); search the body
- [ ] More guns (2020-era, free or licensed models, good sounds)
- [x] 0045 Work stations you build with M: workbench (axe recipe), campfire (light with a lighter or flint and steel
      plus 2 firewood; cook meat, boil creek water, hot stew), vegie garden (plant seeds, harvest vegies and seeds in
      20 minutes). Saved with the base
- [ ] More stations and recipes: kitchen stove, forge/welder, ammo press, water tank; animals for meat
- [x] 0045 Chop trees with an axe (4 hits, machete 8): firewood and sticks, the tree falls, stays down (saved).
      Crouch and look at the ground to forage rocks and sticks; flint and steel from a rock and scrap; lighters in
      kitchens, servos, drawers, on bodies; fill a bottle at the water's edge
- [ ] House types: 0-20 year old double brick estate homes (style variations within an estate, "council approved
      fascia", shared fences); 1970s sandstone two-storey units along the beach (use building height data where
      there is some to place single and two storey); 1960s timber beach shacks
- [ ] Fences: side and back yard fences between houses; most Australian houses have no front fence, some a low
      brick wall
- [ ] Small shopping centres for Cabarita and Kingscliff. Caba: the entry is flush with the main street, a lift on
      the west side of the mall goes down to the underground car park, which opens flush onto the road on the other
      side of the block (built into the hill)
- [ ] Pearl Street, Kingscliff (about No. 6): five-storey apartment block, two units long, garages on the ground
      floor

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
- [x] 0043 Tweed City rebuilt from the user's 2026 directory screenshot (docs/ref/2026/tweed_city_directory_2026.png),
      checked against his satellite screenshot (docs/ref/2026/twin_city_trace_on_satellite.png). tools/trace_mall.py
      segments the picture by colour and writes assets/world/twin_city.json: 114 shops and anchors as polygons with
      their walls classed (outside / mall / next shop), the outline, 16 ways in, roof beams. scripts/world/polymall.gd
      builds the mall from that: angled and curved walls, the real diagonal mall, both west wings, Kmart / Coles /
      Woolworths / Big W / Best&Less / JB Hi-Fi / Hoyts where they really are (fictional names: HOLLIS & CRANE,
      FRESHWAY, GREENGATE, BIG VALUE, BETTER FOR LESS, VOLT ELECTRICAL, REGENT CINEMAS), glass roof on a frame over
      the malls, shop names over the fronts. Fit-out reuses BuildProps in the biggest square-on rectangle inside each
      shop. Test: tools/_polytest.gd; lab: tools/_polylab.tscn
- [x] 0044 Tweed City v2 from the user's annotated plan (docs/ref/2026/tweed_city_annotated.jpg, his colour key:
      red walls and shop fronts, green ways in, yellow toilet doors, purple covered walkways, orange travelators,
      pink cinema upstairs, grey stairs). tools/trace_mall2.py reads the colours: 113 units, 4 toilet blocks, 12
      ways in, covered walkways with posts round the outside shops, 3 travelators down to an underground car park at
      -4 m (lit, columns, bay lines), a car ramp down in the cinema building, stairs up to the REGENT CINEMAS lobby
      and three cinemas with raked seats at +5.2 m. Terrain holes cut over the travelators and ramp at load.
      Test: tools/_polytest2.gd (walks down a travelator and up to the cinema)
- [ ] Tweed City v2 questions for the user: where the real car park ramp comes in (placed in the cinema building
      opening south); Best&Less and Harris Scarfe came out as one store; is there anything on the cinema level
      besides Hoyts? The car park is one level under the whole centre
- [ ] Twin City follow-ups: zombies have no route graph inside it (they walk straight and slide on walls); shops
      are fitted out only in their inner rectangle (angled corners empty); no props on the mall floor itself
      (benches, planters, kiosks); the cinema is one hall; anchors have one way in each; no car parks, loading docks
      or roof plant; the three pad-site buildings west of Kmart aren't built; shop fronts have no shutters or glass;
      the same trace-and-build could redo Bay Mall (Tweed Mall) and Sunnyvale from their plans
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
- [x] 0044 Underground car park for Twin City, travelators and a car ramp down (Bay Mall has a multi-level one since 0040)
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
