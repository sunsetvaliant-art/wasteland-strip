# Wasteland: master to-do list

This is the one list. Every Claude session reads it first and updates it before releasing a patch.
Tick `[x]` when shipped (with the patch number), never delete a line without the user saying so.
Newest requests at the top of each section. Last updated: patch 0051, 2026-11-15.

## Landmark buildings from the user's pictures (2026-11-15 night: "you don't get interiors" from Meshy)
- [x] 0052 Imperial Hotel (pink, three Dutch gables, arched verandah upstairs, the long lettered awning, stone piers;
      gelato shop, restaurant, bar, bottle shop, kitchen and cool rooms, stairs up to hotel rooms) (scripts/world/herogen.gd)
- [x] 0052 Austral Cafe & Bakery (art deco: tiled parapet band, steel window row under a hood, fluted panel, arched
      sign on the awning, tables out the front)
- [x] 0052 Riverview Hotel (on posts with a deck all round, solar panels, BREW WITH A VIEW, Bottlemart drive-through)
- [ ] Riverview: second storey over part of it, ramps and the stair up the side as in the picture
- [x] 0053 Ground key PILOT (1 km round Murwillumbah's main street): NSW imagery (~13 cm) read into a key, our own
      PBR textures painted where it says (road asphalt, car park asphalt, concrete, pavers, lawn, dirt, gravel; trees
      and water left to the terrain), painted lines traced from the photo and drawn sharp (white and yellow), kerb and
      gutter as real geometry along the streets, islands raised with grass/concrete/pavers, no grass on the paved
      ground (tools/sat_fetch.py, tools/sat_key.py, scripts/world/ground_key.gd)
- [x] Ground Tagger (artifact https://claude.ai/artifact/Lm32vhtFM7ebA9Pbvo2ZV1): paint/outline what the ground really
      is over the imagery, draw kerbs, "no kerb", painted lines, drop points (speed hump, crossing, roundabout
      garden, give way, stop) and notes; saved for Claude. tools/sat_key.py now learns from the tags and obeys them
- [ ] Ground key: pull the user's tags, re-run, ship; then the whole map (streamed tiles), the Queensland side
- [ ] Ground key bugs (2026-11-16 F9s): kerbs up the middle of streets; the roundabout at Wollumbin/Main (about
      -757, -108) has a garden in the middle; hard edges on the water
- [ ] Ground key: speed humps and raised crossings as bumps (OSM traffic calming), footpaths at kerb height,
      kerb ramps at crossings

## Back to the grassroots: rigs and raiders (asked 2026-11-15 evening)
User: "invest in the grassroots of what this game was ... making the sick rigs and how modular they were and the random
enemy patrol encounters. The ranged and melee is now up to scratch for some enemies other than the filler zombies."
Answers: enemies = raider gangs (local survivors in built utes / 4x4s, scav look), not War Boys. First rig parts:
engine bay parts, bolt-on accessories, mounted guns + crew. (Armour panels not picked for the first round.)
Patrol rate: not answered yet (default taken: a patrol every 10-15 min on main roads, more at night, plus roadblocks).
Reference: the three.js build (artifact "Wasteland Strip", HANDOVER.md there: u-wargen, r-attach, v-engbay, z2-brain,
owSpawnPatrol) still has the code; its strip game is still in it behind ?strip.
- [ ] Raider gangs in rigs: generated raider machines (cab + chassis + bolt-ons + a gun mount), a driver and 1-3
      gunners/passengers; they drive the real roads (road graph), spot you, chase, ram, shoot from the vehicle, bail
      out and fight on foot with guns and melee when stopped; loot the wreck
- [ ] Roadblocks on the main roads (wrecks across the road, raiders, a lookout)
- [ ] Mounted guns + crew: roof / tray mounts on any rig, a seat to man it, swap seats, NPC gunners
- [ ] Engine bay: blower, carbies, filters, injectors, alternator as fittable parts that change power and starting
- [ ] Bolt-ons: bull bars, side steps, drop tanks, roof racks, spare wheel carriers, roof chops
- [ ] The garage in survival (a garage work station, parts found and traded), not just creative

## Bug reports 2026-11-16 morning (9 reports)
- [ ] STUTTER FOUND: every slow frame in the F9 logs is the building streamer (Buildings._process: 26-60 ms in one
      frame when a building is built near you). Spread each build over several frames / build off the main thread
- [ ] Prospero St, Murwillumbah: put in each business; J&J Tyres was there, and a Toyota dealership on the same block
- [ ] Servo bowsers right on top of the entry: cars can't drive through between them
- [ ] Murwillumbah bridge (the town bridge, about -283, 18) needs straightening, both sides
- [ ] Wollumbin/Main roundabout: garden in the middle (tagger point or fixed)

## Bug reports 2026-11-15 (evening, 14 reports)
- [x] 0051 The home pub (Riverview Hotel) was a plain generated shop; the pub generator was only used for two OSM pubs.
      Every real hotel and tavern (Overture places) is now a pub with its name: CivicGen's pub (bar under a verandah,
      lounge, kitchen, cool room) or, on a main street, the two-storey shop pub. 14 pubs + 3 main-street pubs, 14
      motels by name (tools/place_pubs.py)
- [x] 0051 No terrain collision after DRIVE IT: the terrain's collision followed the car the garage had just
      replaced; it now always follows what you're in, and you're taken out of the old car first
- [x] 0051 A parked car's wheel slowly turning by itself: a car with nobody in it now has its handbrake on
- [x] 0051 Road flickers every second or two at speed: the painted-road picture was redrawn in place and showed a
      frame in the wrong spot each time it moved on; now drawn behind and swapped, and redrawn half as often
- [x] 0051 Error spam every frame in the log (a car's "care"/"inv" looked up when it had none)
- [x] 0051 Stutter at speed: not found yet; every F9 report now lists the slow frames (over 33 ms) and which jobs
      (buildings, plants, roads, NPCs, cars...) they were spent on. F9 at a stutter please
- [ ] Bowsers placed 1.5 m from a shop's front door; servo forecourt ground is grass (wants to talk about it)
- [ ] Tweed City: a mesh over the travelator entry seen from underneath; travelators not flush with the top; a wall
      in the middle of the cinema; the cinema lobby should look like one (roof, walls)
- [ ] Sexton Hill: the highway should run through the cutting under the connecting bridge (the mound has the road
      painted over it); terrain coming onto the highway further south
- [ ] Water over Tweed Valley Way
- [ ] Cane billboards go shiny; cane beside the road too distracting

## Bug reports 2026-11-15 (afternoon, 20 reports) and "paint the satellite onto the lidar"
- [x] 0050 Houses, sheds and shops on the roads and in the water round Tweed Heads, Kingscliff and the coast: the cause
      was the lat/long conversion every building tool used, 0.08% short east-west and 0.23% short north-south against
      the frame the roads and terrain are in (nothing at Murwillumbah, 10 m east and 37 m north out at Tweed Heads).
      Fitted against OpenStreetMap's roads over the whole map (median 0.5 m after) and checked against the coastline
      in the terrain. Every building, servo, wreckers' yard and caravan park moved onto the right ground
      (tools/realign.py, tools/geo.py); then the few still over a painted road pushed off it (tools/clear_roads.py).
      Buildings over a road seal: 6,455 before, about 100 after
- [x] 0050 Tweed City "terrain and mesh intertwining": the mall stood 30 m off its own flat ground (same cause)
- [x] 0050 Long stairs from a high shop door straight out across the footpath into the road: on a slope the door now
      gets a landing and the flight turns to run down along the wall
- [x] 0050 Caravan park: vans across the fence (each van, drawbar and annexe now fits inside); chain-wire fence with
      a top rail instead of solid panels
- [ ] Satellite imagery painted on the ground (user's idea): NSW Spatial Services imagery is CC BY (Google/Bing
      can't be used); as colour from mid-distance blended into the ground textures up close, 2-4 m a pixel (the
      1650 Ti can't hold 1 m). Needs a way to fetch it (the user's Chrome)
- [x] 0052 Shops on sloping streets float on a tall plinth above the footpath (Murwillumbah): front floor now at
      street level with the back cut into the hill (retaining wall, terrain conformed like the bridge ends)
- [ ] North strip (Queensland side, Coolangatta): ground has no texture (flat grey/white "blurry stuff"), towers lean
- [ ] North strip roads/buildings were baked in the old short lat/long frame; the main map's frame differs by up to
      38 m at the seam (z = -16960): re-bake the north strip in the game frame
- [ ] Draw calls: up to 4,700 in Murwillumbah's main street (22 fps, 17 fps at Tweed Heads) since the real footprints
      added buildings; needs merging / shorter detail range
- [ ] Wrong identities: a TAFE shown as a 100 m butcher (Murwillumbah); "The Ivory" pub/restaurant on the water
      (Tweed Heads); a two-screen multi-level cinema missing (Murwillumbah main street)
- [ ] Bridges: one section dips into the water (Tweed Heads); the bridge there has a footpath; a split carriageway
      shown as two separate bridges
- [ ] Grey untextured plant (a garden plant model missing its texture, Murwillumbah)
- [ ] Multi-storey buildings with one small stair as the entrance: proper entries (foyer, ramp, double doors)

## Survival buildings (asked 2026-11-15: "caravan parks, hardwares and car wreckers and mechanics are gonna do it")
- [x] 0049 Hardware stores from the real places (Overture Maps): Bunnings (big warehouse, red sign), Mitre 10, True
      Value, Brims, Village Hardware. hardware racks and shelves, pallet racking, trolleys; a roller door and loading dock
      out the back
- [x] 0049 Mitre 10 Murwillumbah: double storey, one building from Wollumbin St through to Cliffords Lane (49 m)
- [x] 0049 Main-street shops on deep lots (24 m or more) have a back store with a loading dock roller door or a back
      door onto the lane, as the Wollumbin St / Murwillumbah St shops do to Cliffords Lane
- [x] 0049 Mechanics, tyre shops and car parts shops (Repco, Supercheap, Autobarn, Burson...) at their real places:
      tool chests, tyres, parts shelves (search them for car parts)
- [x] 0049 Car wreckers' yards (6, real places): corrugated iron fence, the yard's sign, rows of wrecked cars, some
      stacked, every bottom one searchable for parts and scrap
- [x] 0049 Caravan parks (20, real places): fence, boom gate and sign at the road, the loop road, caravans with
      annexes on the sites (searchable), the cabins are real roofs
- [x] 0049 Two buildings stood in one place in about 450 spots (a named OSM shop put back on a roof another shop
      already had). One of each pair taken out; the shop type or the school / police station moved onto the real roof
- [ ] Wreck yards: wrecks look like clean cars (no rust, panels, missing wheels yet)
- [ ] Caravan parks: amenities block, camp kitchen

## Neighbourhoods from real footprints (asked 2026-11-15: "make neighbourhoods and buildings look believable")
- [x] 0048 Every building is now a real roof: 40,501 footprints from Overture Maps (OpenStreetMap merged with Microsoft's
      satellite-traced roofs, imagery about 2018-2023, so it's the valley as you left it in 2021), each at its real
      place and size, turned to face its street, storeys from the satellite height (tools/import_footprints.py).
      Named places (shops, schools, pubs, clubs, churches...) keep their identity on their real footprint; malls,
      servos and the Pearl Street block stay as built. Unnamed roofs are worked out from size, height and the
      neighbourhood (house / two-storey / units / garden shed / farm shed / warehouse / shop); the shacks, 70s units
      and estates are styled on top again. 40,730 buildings (was 34,003 mostly generated)
- [ ] Roofs the satellite traced as one shape where two buildings touch (a house and garage, a row of shops):
      split the obviously-too-long ones
- [ ] Yard dressing: driveways, letterboxes, wheelie bins, a car in the drive, Hills hoists, water tanks on rural
      blocks
- [ ] Malls: user will send annotated JPGs for the other centres (Tweed Mall etc.), like Tweed City

## Bug reports 2026-11-15 (morning, 9 reports)
- [x] 0047 Tweed City: couldn't drive in under it. The terrain hole for the car ramp ran 3 m out past the door, so
      cars fell through into nothing at the entrance. The hole now stops inside the building; a test drives a car from
      the street down the ramp into the car park (tools/_tcdrive.gd)
- [x] 0047 Tweed City: water showing downstairs. The car park is below sea level and the sea is one big plane; the
      water shader now skips "dry" boxes and Tweed City's lot is one
- [x] 0047 Tweed City: "concrete road in the cinema lobby": the Hoyts unit's roof at 7 m ran through the cinema
      lobby (1.8 m above the cinema floor). The cinema unit has no roof of its own now (the cinema building has one)
- [x] 0047 Tweed City: no car parks outside. Asphalt car parks with bay lines round Tweed City and the other big
      centres, laid on the ground out to 35 m, off the roads
- [ ] Tweed City: "terrain colliding visually with the mesh" outside the east side: should be gone with the dry box
      (it was the sea showing at the wall foot). Check in game
- [x] 0047 Fences: overlapping (both neighbours built the same fence) and running into houses. A shared fence is
      built once now, and panels keep 1.2 m clear of any building at both ends and the middle
- [x] 0047 Sheds on the road: big sheds and warehouses were left where OSM had them even when a road clipped them;
      now they're shortened off the road (7 trimmed), and the road clearing pass ran again for the newer roads
- [x] 0047 Servos generated from OpenStreetMap (asked: "paint some concrete and generate an accurate servo"; then
      "get rid of the Ampol model servo and generate servos now instead"). 24 servos: concrete forecourt on the real
      outline, canopies at their real size in brand colours with the name, bowsers, a pylon sign with prices, and a
      generated shop (ShopGen "servo") on the real shop footprint with shelves and loot. The Chinderah Ampol truck
      stop has its truck canopy, a 14 m sign and the whole site in concrete. The Ampol model is gone
- [ ] Servos: the "huge truck" at the Chinderah truck stop (needs a semi-trailer model)
- [x] 0047 Kingscliff centre moved onto the real Kingscliff Shopping Village footprint from OSM (about 64 x 104 m)
- [ ] Terrain poking through the ocean (report 08:15). The report didn't say where the camera was: bug reports now
      record the camera position, please F9 it again
- [x] 0047 Bug reports record the camera position and look direction (the Forge camera flies away from the player)
- [x] 0047 The in-game version said 0.2.45 on 0.2.46 (version.txt was written after the export)

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
- [ ] Sheds: check 107 Commercial Road, Murwillumbah in game (should be a real house now, from its footprint); user will F9 any more
### Features
- [x] 0045 Interaction menu like Vein (scripts/inv/interact_menu.gd), also on work stations and the ground: aim the crosshair at something and a small Windows-style right-click menu shows;
      mouse wheel picks, left click does the highlighted (default) option; right click hides it on that object for 5
      seconds so you can swing or shoot. Dead zombie: Open inventory. Car: Drive, Repair (opens the menu),
      Inventory. Window: Barricade, Open / Close
- [x] 0045 Zombies and scavs carry loot (rags, lighters, the odd key, bandage, drink, ammo); search the body
- [ ] More guns (2020-era, free or licensed models, good sounds). WAITING ON USER: this workspace can't download
      from model sites by itself. Like the Mixamo run: with your Chrome open, Claude picks the models and sounds on
      Sketchfab / freesound, you drop the downloads into Drive WASTELAND/guns, then they get built in
- [x] 0045 Work stations you build with M: workbench (axe recipe), campfire (light with a lighter or flint and steel
      plus 2 firewood; cook meat, boil creek water, hot stew), vegie garden (plant seeds, harvest vegies and seeds in
      20 minutes). Saved with the base
- [ ] More stations and recipes: kitchen stove, forge/welder, ammo press, water tank; animals for meat
- [x] 0045 Chop trees with an axe (4 hits, machete 8): firewood and sticks, the tree falls, stays down (saved).
      Crouch and look at the ground to forage rocks and sticks; flint and steel from a rock and scrap; lighters in
      kitchens, servos, drawers, on bodies; fill a bottle at the water's edge
- [x] 0046 House types (scripts/world/buildgen.gd styles, placed by Buildings._house_styles): 1,078 1960s beach
      shacks and 624 1970s sandstone-coloured two-storey units within a few hundred metres of the beach, 546 newer double
      brick estate homes where brick houses run in lined-up streets (each estate keeps a palette and Colorbond fascia
      colours, houses vary within it). No building height data in hand, so storeys aren't from real heights yet
      Asked for: House types: 0-20 year old double brick estate homes (style variations within an estate, "council approved
      fascia", shared fences); 1970s sandstone two-storey units along the beach (use building height data where
      there is some to place single and two storey); 1960s timber beach shacks
- [x] 0046 Fences: side and back yard fences between town houses, half way to the neighbour (Colorbond on brick and
      estate homes, timber palings on old houses, low brick round 70s units); a low brick front wall on some brick
      homes; none in the country
      Asked for: Fences: side and back yard fences between houses; most Australian houses have no front fence, some a low
      brick wall
- [x] 0046 Small centres: CABA VILLAGE on the west side of Tweed Coast Road (arcade level with the main street,
      supermarket at the back, shops both sides, toilets, a lift on the west side down to the car park underneath,
      which opens flush onto the Hastings Road side) and KINGS REEF VILLAGE on Pearl Street, one level
      Asked for: Small shopping centres for Cabarita and Kingscliff. Caba: the entry is flush with the main street, a lift on
      the west side of the mall goes down to the underground car park, which opens flush onto the road on the other
      side of the block (built into the hill)
- [x] 0046 Pearl Street, Kingscliff: five-storey block with garages across the ground floor, at the south-west end of
      Pearl Street (16531, -8512). USER: if No. 6 is at the other end (near the shops), F9 it and I'll move it
      Asked for: Pearl Street, Kingscliff (about No. 6): five-storey apartment block, two units long, garages on the ground
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
