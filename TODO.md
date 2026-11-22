# Wasteland: master to-do list

This is the one list. Every Claude session reads it first and updates it before releasing a patch.
Tick `[x]` when shipped (with the patch number), never delete a line without the user saying so.
Newest requests at the top of each section. Last updated: patch 0066, 2026-11-23.

## Real chassis, suspension, engines under bonnets, physical lifting 2026-11-22 (0065+)
User: physically take vehicles apart: cabs, tubs, engines, gearboxes; lift a cab off with a block and tackle hung
somewhere decent, or straps on hydraulic gear (loader, tractor, forklift); suspension parts are cartoonish and too
big (the diff from the old artifact); a real ladder chassis (kicks up over the axles, widens); motors poke through
bonnets (maybe too big for them); engine bay sheet metal in the body's colour; a forklift with a mast and forks on
dialled-in controls to pluck a cab off an unbolted chassis (no teleport button); can a loader be rigged. Then: the
new Ranger and B2500 paint looks unlit; their wheels can't be changed; hubs left floating / coming away with the
body; do the forklift, block and tackle, unbolting and bolting tub/cab/chassis; finish 0.2.65.
- [x] 0065 Ladder chassis: rails kick up over each axle (clear of the housing at full bump), stay up behind the back
      axle, pinch in ahead of the cab; crossmembers at the front, engine, gearbox, ahead of the rear axle and the
      back; one mesh. Springs, leaf hangers, shocks and wishbone mounts bolt to it where it is
- [x] 0065 The live axle is the textured housing from the old game (diff centre, tubes, backing plates, perches),
      pinion to the gearbox; leaf packs 5 leaves on one line; coils 13-15 cm, slim sway bars, dull paint
- [x] 0065 Engines drop until they clear the bonnet (each body's skin measured, tools/bonnet_tops.py ->
      body_info.json). The Meshy bodies needed 30-49 cm: their bonnets sit low over the wheels
- [x] 0065 Engine bay walls in the body's own paint (sampled off its texture)
- [x] 0065 New utes: normals were lost on import (the flat, unlit look); wheels now swap from the garage's Wheels;
      hubs, brake discs and leftover tyre wall cut out of the bodies
- [x] 0066 Forklift (Mathieu Godard's ForkLift GameReady, CC BY): drives on the front wheels, steers the back ones
      (the lock comes off above walking pace so it doesn't tip), solid tyres, about 20 km/h. Mast tilts, inner channel
      and carriage run up 1.75 m, forks side-shift. Up/down arrows lift (needs the engine on), left/right tilt,
      comma/full stop side-shift, Alt for a quarter speed; taps move it millimetres, holding speeds it up. The tines
      and backrest really collide: slide them in between the rails and the body and lift. In the Forge's Vehicles,
      and sometimes in warehouses and workshops (never in a driveway)
- [x] 0066 Unbolt / bolt the body and the tub with a shifter (F menu on the car, 2.5 s a mount, 0.5 in creative): the
      body stays sat on four mount pads with a 12 cm gap over the rails for forks or strops; no teleporting. Sit it
      back square on the rails and Bolt on (from the car or the body). Another chassis's body bolted on makes that car
- [x] 0066 Gantry and chain hoist (Forge > Tools): straddle the car, push the load under the beam, F > Hook the chain
      on; on foot near it up/down arrows work the chain (10 cm/s), left/right run the trolley, Alt slow. The chain
      only pulls, the load hangs from over its middle so it comes up level; 2 t limit. Lifts bodies, tubs, engines,
      any loose prop
- [ ] Block and tackle from shed trusses and big branches (the gantry's chain, other anchors)
- [ ] Straps on the loader / tractor; a forklift jib for engines
- [ ] Engines and gearboxes as loose physical lumps to hoist out (still the engine stand's click-to-move)

## Modern utes in, body tools free cam 2026-11-22 (0064)
User: put the modern utes into the game; every imported vehicle gets its wheels cut off and put in the game for
every car; the body panels menu needs a very slow free cam to fly in and out of each vehicle's mesh.
- [x] 0064 New bodies: Toyota Hilux dual cab (2001), Mazda B-Series dual cab (2004), Ford Ranger dual cab (2003),
      Holden VZ Commodore ute (2004). 37-47k triangles, 14-15 draw calls each, clear glass and their interiors;
      they turn up in driveways like the rest and are in the garage's Body list and the Forge
- [x] 0064 Their wheels cut off as wheel models (Hilux alloys, B-Series alloys, Ranger alloys, VZ steelies), from the
      full-detail downloads so the tyres stay whole; fit any car, spawn in the Forge. Import fixes: a mesh holding
      two tyres is split; a tyre with no sidewall gets one made, and the body's leftover ring round the wheel is cut
- [x] 0064 Body tools FREE CAM (F): WASD, Q/E down/up, right-drag looks, wheel sets speed (starts at 0.35 m/s),
      Shift x4; the near clip is 1 cm so you can fly inside the mesh
- [ ] Mazdas and the 1988 Hilux from TODOwnload (sedans, wagons, MX-5s, RX-7s) when wanted

## Lift bonnet, TODOwnload utes 2026-11-22 (0063)
User: a LIFT BONNET button in body tools so the Meshy junk under the bonnet skin can be painted (the paint tool
works fantastic); get rid of some triangles; vehicles MUST have clear windows and either no interior or an accurate
one, nothing in between; put his links (VZ ute, Mazda B-Series dual cab, Res1n's Mazdas, Hiluxes, Ranger Mk1, truck
wheels, LIAZ fire truck, a low-poly pickup) in a TODOwnload asset folder.
- [x] 0063 LIFT BONNET: the faces painted bonnet swing 60 degrees up on the hinge; paint what's under them (Bonnet
      to lift with it, Cab to stay) and they move when you let go of the mouse
- [x] 0063 assets/TODOwnload: 31 models cut from 0.5-3.5 million triangles to ~45-55k, stood upright in metres,
      glass see-through, textures capped at 1024; every one looked at (README.md has the table and verdicts).
      Fails the window rule: the LIAZ (a photo scan) and the low-poly pickup (black windows)
- [x] 0064 Bring TODOwnload utes into the game: Hilux Mk6 dual cab, Mazda B-Series dual cab, Ranger Mk1 dual cab,
      VZ ute

## Body tools clicks, textures, wheels on the axle 2026-11-22 (0062)
User: can't left click in the F9 window; in body tools left click does nothing and the tub paint is stuck on; turn
the model textures back on for the cars; make sure wheels are fixed to their axle so they stay flat to the diff
flange. He's looking for 2000s and 2010s dual cab utes.
- [x] 0062 Body tools took every click before the rest of the screen (0061): no side-panel button worked (stuck on
      Tub) and the F9 form couldn't be clicked. Back to clicks after the screen's own buttons
- [x] 0062 Painting shows over the textured model (see-through tint) instead of plain grey; an Erase button
- [x] 0062 Wheels: the hub no longer drops off the axle end by half the tyre squash; live-axle wheels stay square
      to the housing (checked with one wheel up a block, tools/_flexshot.tscn)
- [x] 0063 2000s/2010s dual cab utes: user found Hilux, Ranger, B-Series, VZ links; staged in assets/TODOwnload

## Bonnet painter, wheels, zombies, stutter, F9 reports 2026-11-22 (0061)
User: the bonnet painter doesn't paint when you click and drag (the points method worked well; keep it); find more
zombie models; most of the wheels are backwards; make sure the Sketchfab tyre links are in; still stuttering badly
(4 fps at 123 km/h down Mount Ruin's main street); go through the TODO and do some.
- [x] 0061 Painter: the brush never painted (its lookup grid was filled through a copy and stayed empty). Fixed, and
      the face under the cursor always takes the paint, big low-poly faces included; "Fill panel" paints a whole
      panel in one click up to its shut line (stops at bends sharper than the slider). Bonnet line / tub line
      point tools are still there. The mouse is read ahead of the rest of the screen now
- [x] 0061 Wheels: lugged tractor tyres (tractor lugs, R6 front and rear) ran their chevrons backwards on one side:
      each side now wears its own hand, lugs pointing forward from above. Every wheel checked from both faces
      (tools/_wheelface.tscn, tools/_treadshot.tscn); the F100 steelies were drawing black (no material) and are fixed
- [x] 0061 The user's Sketchfab wheel links (wire, Nissan alloys, mud terrains, the JDM pack) went in with 0060
- [x] 0061 Zombies: nine bodies now (was one): the five Sketchfab ones are back (their stray collision has been
      stripped since 0021) plus three new (Zombie Walk Test, a Fuse female, a WWI-style screamer); loaded on a
      worker thread at the start so the first of each doesn't hitch
- [x] 0061 Stutter: over ~58 km/h no new building interiors are built (each was 40-90 ms, one a frame was the 4 fps):
      the far-off outsides show right up close and lots get a plain box to hit; under ~30 km/h the full builds
      come back, spaced out by what each one cost. Plants build one cell a frame when fast. At a low frame rate
      the physics no longer runs up to 8 steps a frame (the spiral down to 4 fps)
- [x] 0061 Garage: "set_current_tab out of bounds" error when an axle tab changed with matched settings
- [x] 0061 Cane: no more sun glint off whole paddocks; it stands 6.5 m back from the seal instead of right on it
- [x] 0061 Diesel smoke: a turned-up pump (or rich tune) blows black smoke out the back on the throttle, a haze at idle

## Wheel packs and the F100 (0060)
User: download these wheels (some packs have several in one file) as wheels to fit and spawnable models; add the
1976 F100 (orange) with its wheels cut off.
- [x] 0060 Wheels: wire spokes, Nissan factory alloys, mud terrains, and the JDM pack split into four (each tyre
      lined up on its rim); all in the garage's wheel list and in the Forge (Car parts > "Wheel: ...")
- [x] 0060 Ford F100: the 1976 "New Orange" one is Editorial-only on Sketchfab and the API won't download it, so the
      low-poly 1970s F100 (CC BY) went in instead: wheels cut off into "F100 steelies", factory V8, RHD
      (tools/import_vehicle.py works for other downloaded bodies too)
- [ ] A better F100: if the user downloads the orange 1976 one himself (Editorial licence: personal use), drop it in
      Drive and run tools/import_vehicle.py on it

## Driving aids, garage, body painter, Sketchfab, F9 reports 2026-11-22 (0059)
User: W should feather so the rear doesn't break traction unless Shift's held; a BeamNG-style drift assist; tub and
tray height; axle ride height and ticks to match axles; wheels square to the axle when it flexes; a mesh painter in
place of the point-to-point bonnet line; can't drag heads onto the engine; Forge tab for engines and parts with
categories; find more wheels; forklift and tractor with separate wheels (with the Sketchfab key).
- [x] 0059 W feathers the throttle short of wheelspin (and feels for more as speed comes up); Shift+W floors it.
      Pause menu > Controls has the switch
- [x] 0059 Drift assist: once the car's sliding the front wheels follow the way the front's travelling and your
      steering adds on top (pause menu > Controls, on by default)
- [x] 0059 Engine view: drops onto the engine work (the view handed drags to its own viewport)
- [x] 0059 Garage: tub height slider (factory or swapped tub); ride height (lift) per axle; "same on every axle"
      ticks for wheels, track, ride height, springs and dampers; wheels on each axle can differ
- [x] 0059 Live axle wheels stay square to the housing as it articulates
- [x] 0059 Body tools: a mesh painter (brush the model's own faces as tub, bonnet or cab; paint through both
      skins; start from the old lines). Saved with the cut; a painted bonnet's hinge and bay come from the paint
- [x] 0059 Forge palette: "Engines & parts" tab, categories that open and close, pictures of each part
- [x] 0059 Wheels from Sketchfab: 20-spoke mags, wide 13 inch steelies, turbine alloys, five-spoke alloys,
      tractor lugs (tools/import_wheel.py; credits in assets/credits.json)
- [x] 0059 Tractor: Lamborghini R6 (Sketchfab, CC BY) with its own front and rear wheels, 4WD farm diesel
      (tools/import_tractor.py)
- [x] 0066 Forklift: the free ones on Sketchfab have the wheels baked into the body; split them out (connected parts)
      or find one with separate wheels; rear steer and a working mast
- [x] 0059 Zombies can't grab you through a wall or up through a floor (they need a clear line and the same level)
- [x] 0059 Lots standing inside each other (the shed with a house in it): 26 dropped (tools/fix_overlaps.py)
- [x] 0059 Servo shops were turned 90 degrees into their canopies (the bowsers at the door): 17 fixed, and the
      script (tools/make_servos.py)
- [x] 0059 Roller-door workshops and warehouses on a slope get their floor at the street like shops (the garage
      door hung a storey up); a doorstep up to 0.5 m walks up without a jump

## Brakes, tyres, diffs, F9 reports 2026-11-22 (0058)
User: brakes lock every tyre the instant you press S; a RWD car with an LSD or locked diff should power-skid and wiggle
until wheel speed matches road speed; an open diff spins one wheel and the car goes where it's steered.
- [x] 0058 Brakes: S is a driver's foot (squeezes on, eases off the moment a wheel locks: firm stops near the limit
      on any ground, 80-0 in ~37 m); Shift+S stomps and locks. Proportioning by load so the rears don't lock first
- [x] 0058 Tyres: combined slip (one grip budget for spin and slide; a spinning or locked tyre has little left
      sideways); bitumen slides at 76% of its peak grip (was 85%)
- [x] 0058 Live axles: pinion torque loads one rear tyre and lifts the other, so an open diff spins the light side
      and goes straight; LSD / locked spin both and the tail steps out (tools/_tyretest.tscn)
- [x] 0058 Inventory search: a box in the middle; matches light up in the grids and list underneath, drag one out
      or shift + click to send it across
- [x] 0058 Fences: lanes and car parks come out of the yards first (no fences across back lanes or through Auto One's
      car park), fences stop 35 m behind a house, keep clear of verandahs; on a step between yards the fence is a
      retaining wall with the fence on top (the high yard's plants looked like they floated along it)
- [x] 0058 Pasture grass: a photo-scanned Poly Haven grass (sparse_grass, greened) instead of the cartoon blades
- [x] 0058 Standing on a parked truck's tray can't fling it any more (the AA-160 flipped); ENGINE VIEW is the first
      button under the bonnet
- [ ] Kingscliff (F9 "Kingscliff mainland ????"): in a fresh test the town loads; ask the user what's wrong there
      (the grass headland at the creek mouth? buildings not loaded after a long Forge flight?)
- [x] 0066 Forklift and tractor models with separate wheels: the user grabs them (Sketchfab needs a login) and drops
      them in the Drive folder; then add them as vehicles (forklift mast and forks to work)

## Houses, fences, building types, F9 reports 2026-11-22 (0056)
User: "why buildings have such massive footprints in the game, so large they sit on the road"; "fences really need to
share corners, with houses that use the same side fence"; "huge concrete footings"; "random business establishments
where a house sits irl"; "Murwillumbah high school ... just a massive shed. It's multiple buildings from varying decades
strung across a hill".
- [x] 0056 House footprints: the satellite outline is the roof edge now (walls inside it, less eaves; the verandah out
      of it, not added to it); real sizes by kind; the house at the street end; the back of long outlines becomes a
      shed / carport (1,065); checked with verandah + stairs against the painted roads (1,244 pushed back, 134 left
      out). Houses average 128 m2 of walls, down from 211 (tools/fix_footprints.py)
- [x] 0056 Back yard fences by the block: property parcels per block, one fence per shared boundary, shared corner
      posts, along side streets and open ground, never across the front (tools/make_streets.py, Streets)
- [x] 0056 Sloping blocks: brick piers and battens under the downhill side instead of a giant concrete plinth
- [x] 0056 Building types checked: businesses with no storefront, commercial footprint, name or business land under
      them, in among houses, are houses again (119)
- [x] 0056 Schools are campuses: every building in the grounds (36 schools, 251 buildings) from an era (1920s timber
      high-set, 1960s brick two-storey, 1970s besser block, modern), the name over the biggest (tools/fix_types.py).
      Where OSM traced a whole campus as one shape (Murwillumbah High was a 205 x 142 m shed), it's cut back into its
      own wings along the traced walls, long wings broken into separate buildings with walkway gaps
- [x] 0056 Missing roads filled from Overture: 164 km (Tweed Heads South, Banora Point, Chinderah...) (tools/fill_roads.py)
- [x] 0056 Falling through the ground after DRIVE IT (you were put into the old car as it was deleted)
- [x] 0056 Distant mountains gone through the scope / binoculars (the scope camera stopped at 6 km)
- [x] 0056 Driving frame drops: parked cars only wake for what will reach them; plant masks read straight from the
      index; street detail draws nearer (kerbs 260 m, furniture 160-380 m, fences 120 m)
- [x] 0056 Bonnet line not taking all the mesh inside it (workhorse); right-click menu stuck over the garage / tools
- [x] 0056 A tub off one model bolts onto another (the workhorse tub on the AA-160); the AA-160 scaled to size (6.5 m)
- [x] 0056 Tray height slider
- [x] 0057 Engine view (user's idea, 2026-11-22): the engine floats and turns; hover a part to light it up, click for
      its name and what it does, double-click for your engine parts on the right (what fits first); empty spots are
      see-through ghosts; drag a part onto the engine to fit it (onto a taken spot swaps them), drag a selected part
      onto the list to take it off. From under the bonnet (ENGINE VIEW button) and the engine stand
- [x] 0057 Engine parts have inventory pictures (drawn from the same code, on the fly) and look like themselves on the ground
- [ ] North strip (old frame) road gaps: check Tweed Heads CBD against Overture once the frames agree
- [ ] Shops in the main streets with no proof they're shops (399) stay shops for now: check against photos

## F9 reports 2026-11-21 (fixed in 0055)
- [x] 0055 Footpath / car park paint streaky (texture was stretched one way)
- [x] 0055 Paint and shopping-street footpaths climbing banks; footpath rising into a big ramp / wall behind the shops
      (the paved footpath now keeps the kerb's level; nothing painted up steep banks)
- [x] 0055 Wide paving in front of houses ("house on the road"): the 8 m paving only runs in front of shops now
- [x] 0055 Stairs into the water / into the road / long stairs on the ambulance depot: long flights are switchbacks now
- [x] 0055 Bridge turning both lanes 90 degrees at its ends (7 bridge ends had a hook baked in)
- [x] 0055 FPS drop near the main street (38 NPCs 16 ms, 10 parked cars 8 ms): far idle NPCs think every third frame,
      still cars nobody's near are parked out of the physics
- [x] 0056 Tall buildings on steep blocks: piers and battens instead of the high concrete base wall
- [x] 0061 Diesel smoke from a turned-up pump
- [ ] Turbos next (low-comp heads pay off then)

## Streets by the block (asked 2026-11-21: "gutters, road islands, road markings, parking lot logic, footpath infrastructure")
User: bracket each block with hard-edge gutters instead of reading the street off the photos; estates flush-ish.
- [x] 0054 Every block the sealed roads close off is found (the map with the road surface cut out; big leftovers in
      200 m cells) and given a profile from what's in it: MAIN (shops / retail), TOWN (older houses), EST (estate
      homes), IND, ISL (medians, traffic islands), RBT (roundabout centres), or rural (no kerb). Whole map: 5,027 town,
      354 estate, 126 shopping, 120 industrial blocks, 370 islands, 157 roundabouts (tools/make_streets.py)
- [x] 0054 Kerb and gutter as real geometry you can hit: barrier kerb in town and shopping streets, roll-top in the
      estates, mountable concrete on small roundabouts; kerb returns rounded at the corners (3-9 m by profile) with the
      corner sealed; turning bulbs at town dead ends; no kerb on bridges, gravel roads or where there's no building
      within 60 m (scripts/world/streets.gd)
- [x] 0054 Shopping streets: footpath paved at kerb height out to the shop fronts (up to 8 m), street lights every 26 m,
      bins and benches
- [x] 0054 Town and estate streets: grass nature strip and a concrete path (1.2-1.5 m); 14,074 driveway laybacks with a
      concrete crossover to the house; laybacks where every OSM driveway / service road / car park aisle meets the kerb
      (2,198); power poles along one side (OSM's where it has them), some with a street light
- [x] 0054 Crossings: kerb ramps both sides (1,811), zebras in shopping streets (200), stop-line pairs at the lights
      (170); traffic light poles on the junction corners (358); stop lines and signs (34), give-way lines and signs (122)
- [x] 0054 Bus stops: sign at the kerb, shelter behind it where there's room (362)
- [x] 0054 Car parks: every OSM car park sealed and laid out in 2.5 x 5.4 m bays with 6.4 m aisles, or painted from
      OSM's own bays (314 car parks, 10,617 bays); nothing grows on paths, kerbs, drives or car parks
- [x] 0054 The photo ground key is off (its kerbs up the middle of streets and the roundabout garden went with it);
      GROUND_KEY=1 brings it back
- [ ] Town footpaths at kerb height (only shopping-street paths are raised; town paths are painted on the ground)
- [ ] Car parks: kerbs round the edges and islands, wheel stops, disabled bays, trolley bays, entry/exit arrows
- [ ] Lane arrows, turn bays and painted medians; bus zone and no-standing markings; school zones
- [ ] Pedestrian fencing at the big intersections; guard rails on the highway; street name signs
- [ ] Check in game: kerbs on steep streets (Murwillumbah hills), roundabout shapes, laybacks lining up with drives
- [ ] Old-centre streets with angle parking down the middle or both sides (Murwillumbah main street)

## Modular engine kit, made in code (asked 2026-11-21: "my 3D engine models are absolute shite")
User: put the old engine models away. Every part is generated in code from one shared spacing so ports, decks and
bolt patterns always line up and everything interchanges. Decided so far: the FUEL SYSTEM decides diesel vs petrol
(heads only set compression: low / med / high, no exact ratios); engines are built both in the car (bolt-ons, click
install/remove for now) and on an engine stand at base (full rebuild, then drop it in).
- [x] 0055 Blocks: i3, i4, i6, V6, V8, small and big (all banks share one deck / bolt pattern) (scripts/vehicle/engine_kit.gd)
- [x] 0055 Heads: 3, 4, 6 cylinder, each as flathead, pushrod, SOHC, DOHC, low/med/high compression; any head on any block bank of the same count.
      V6 = two 3-cyl heads, V8 = two 4-cyl heads, mirrored (intake ports to the valley, exhaust out)
- [x] 0055 Exhaust manifolds: 3, 4, 6 cylinder (V6 uses a 3 per bank, V8 a 4 per bank, same parts as the inlines)
- [x] 0055 Intake manifolds: inline 3, inline 4, inline 6, V6 valley, V8 valley
- [x] 0055 Carby (no ECU, needs a distributor + coil) or EFI throttle body (needs ECU), bolts on any intake
- [x] 0055 Diesel: mechanical injection pump (no ECU, turn it up with a spanner) or electronic pump (needs ECU, tuneable); needs a high-compression head
- [x] 0055 ECU: silver box up top in the engine bay; must match fuel type and cylinder count; laptop tune (fuel, timing, rev limit)
- [x] 0055 Front of the engine: one belt crank > water pump > alternator; no alternator = battery drains, injected engines die
- [x] 0055 Head type shows (finned flathead, rocker cover, single-cam, wide twin-cam) and sets the rev range / power band; sound by layout
- [x] 0055 Engine stand (base building): pull an engine out (bonnet off first), strip and build it part by part, drop it
      into another car (click to move for now; the block and tackle replaces that when it's built)
Decisions (2026-11-21 Q&A):
- Build both this batch and the cab/tub tools in one go
- Blocks: i3, i4, i6, V6, V8, each in a SMALL and a BIG size; big = taller deck and wider sump, same bolt pattern, so
  heads still swap within a cylinder count. Universal engine mounts (any engine fits any car), and every engine bolts
  to every gearbox (no bellhousing rules)
- Head power: clear but fair. Flathead ~70% of DOHC power with the most low-down torque, pushrod torquey, SOHC middle,
  DOHC top end; rev limits about 4.5k / 5.5k / 6.5k / 7.5k
- Petrol on a high-compression head: more power, but it pings under load and wears the engine unless an ECU tune backs
  it off (carbies can't)
- Sound: tweak the existing engine sound by head type, cylinder count and V vs inline (V8 burble, i6 smooth, diesel
  clatter)
- Parts come from wrecks (strip them), sheds and wreckers' shelves, traders, and raider rigs
- NO condition on engine parts
- ECU tuning: a few sliders (fuel, timing, rev limit; boost later), too aggressive pings or smokes; needs a laptop
  item to plug in
- Diesel pumps: mechanical is tough (runs with no ECU or battery once going, turn it up with a spanner = smoke);
  electronic makes more power with a tune but needs the right ECU
- Carby engines need a distributor + coil; EFI's ECU does the spark
- Battery to start (flat or missing = no start; push start a manual); no alternator = battery drains, lights dim,
  ECU cars die
- Stock engines: era-correct from the kit (old US pickups pushrod V8 + carby, Falcons i6, Japanese 4x4s diesel...)
- Wrecks: engines are either missing a few parts (carby, ECU, alternator, battery) or complete but dead
- Turbos later (turbo manifolds, dump, intercooler pipe); low-comp heads pay off then

## Cab / tub cutting, bonnet tool, custom trays (asked 2026-11-21)
User's models (Drive, link-shared): all models folder 12PKYCZ4V7Hwj_KWWWw5breIX_AeXGvFe (Bare Bones Muscle, Rustbelt /
Rustbound relics, Rusty Blue Wagon, bikes); ute folder 1icHx0xIwXpd2HGmXcPZ18tq6WidFUxxx = vehicles that can be cut at
the C/B pillar to remove the styleside tub, or already have a clear cab / chassis line (Rustbound Cab, Rustbound
Chevy Relic, two Rustbound Relics, Rusty Pickup Bo, Rusty Red Pickup, Rusty White Pickup, Rusty Yellow Workhorse).
- [x] 0055 Pause-menu Body tools to do each model in game, set and forget: TUB line (plane or clicked seam) and BONNET shut line per model.
      Lines save to a file on his PC; he drops it in the Drive folder and it ships in the next patch for everyone
- [x] 0055 Cut tubs come off as their own part (unbolt, bolt back on, scrap); bonnet hinges open and comes off as a panel; engine bay
      under it is clipped to the bonnet's outline (user's idea)
- [ ] Cut faces aren't capped yet (the cab's back wall and the tub's front wall are open where Meshy fused them)
- [ ] No model has its lines yet: set them in Body tools, drop user://body_cuts.json in the Drive folder to ship them
- [x] 0055 Custom trays generated in code to fit the chassis: alloy / steel, headboard + ladder rack, drop sides that hinge,
      under-tray / double tapered / marine-carpet gullwing boxes, spare carrier, water tank, jerry holders, canopy with
      lift-up doors, round / LED / sequential / recessed tail lights (garage, or 12 scrap from the K menu)
- [ ] Dual cab ute: none in the game yet; user to make one in Meshy (cab-chassis photo) plus a tub on its own
Decisions (2026-11-21 Q&A):
- Tub cut: a see-through plane you slide and tilt (preview in two colours), or click points along the seam for odd ones
- Bonnet: click points round the shut line on the body; it cuts, thickens and hinges. Rear hinge to open it at the front
  for repairs; for an engine swap the bonnet unbolts and comes off as its own physics piece, then bolts back on
- Trays: steel (painted, timber or steel deck) and alloy (bare, checker-plate); fit the chassis behind the cab by
  default with length / width sliders. Custom Aussie tray builds: headboard + ladder rack, under-tray toolboxes,
  double tapered toolbox, marine-carpet lined with one gullwing box, spare wheel carrier, water tank and jerry
  holders, tray sides that hinge
- Canopies generated in code NOW (box canopy, lift-up doors, fits any tray)
- Tail lights: plain round, square LED bars, sequential indicators, recessed in the tray
- Cut-off tubs are real parts: keep, swap onto another ute, sell to traders, or scrap for metal

## Bikes (asked 2026-11-21: rideable, later)
- [ ] Rideable bikes from the user's models: Rustbound Scooter, Rusty Kawasaki Mini Bike, Rusty Mini Chopper
      (balance and lean; after the engines and the cab / tub work)

## Vehicles: the mechanic's dream (asked 2026-11-21, after the streets)
User: "a physics based block and tackle system allowing you to pull engines, gearboxes, cabs, tray or tubs and loads
to and from vehicles"; e.g. a BT-50 single cab on an 80 Series chassis keeping the 3.0 CRD, the 80's gearbox, transfer
and diffs, with a single cab tub and canopy.
- [ ] Modules: chassis, body (cab + front clip), tub / tray / canopy, engine, gearbox, transfer, diffs/axles,
      suspension. Bolted on they're one body (mass and centre of gravity recomputed); unbolted each is its own
- [ ] Block and tackle: anchor points on gantries, shed trusses, strong branches; hook lift points; chain it up and down;
      load limits; it swings (0066: the gantry and chain hoist do this; trusses and branches still to come)
- [ ] Pull a chassis out from under a hoisted cab with a tow rope / snatch strap from any vehicle; forklift and tractor
- [ ] Wireframe ghost of the body while lowering, red where the engine or gearbox would foul it
- [ ] Compatibility: bellhousing patterns and adapter plates, wheelbase vs tub length (cut / stretch the chassis at the
      welder), body mounts that don't line up need fabricated mounts, common-rail diesels need their loom and ECU
- [x] 0055 Under the bonnet: click to remove / install every engine part (K menu)
- [ ] Physical engine lifts first on cars that come without a bonnet (the Monaro project)
- [ ] Bonnet cut tool (Forge): draw the shut line on any car, it cuts the bonnet off as a hinged panel (thickened, with an
      underside), and a generic engine bay fills the hole. USER'S IDEA: never draw any of the bay outside the bonnet,
      guard and grille shell (stencil mask / clip to the body), so it can't poke through anywhere. Pilot on 2-3 cars
- [ ] Per-part damage (bent tie rod pulls, cracked shock mount, cooked head gasket), found by symptoms
- [ ] Tyres: road / AT / MT, pressures (air down for sand and mud), punctures, plug kits, spare carrier; alignment

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
      (0054: the key is OFF by default; the streets are built by the block now. Kept for reference)
- [x] 0054 (key off, streets by the block) Ground key bugs (2026-11-16 F9s): kerbs up the middle of streets; the roundabout at Wollumbin/Main (about
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
- [x] 0061 STUTTER FOUND: every slow frame in the F9 logs is the building streamer (Buildings._process: 26-60 ms in one
      frame when a building is built near you). 0061: none built while driving fast, spaced out when slow
- [ ] Build interiors off the main thread (or over several frames): still a 40-90 ms hitch walking up to a new one,
      and a big mall is ~2 s
- [ ] Prospero St, Murwillumbah: put in each business; J&J Tyres was there, and a Toyota dealership on the same block
- [ ] Servo bowsers right on top of the entry: cars can't drive through between them
- [ ] Murwillumbah bridge (the town bridge, about -283, 18) needs straightening, both sides
- [x] 0054 Wollumbin/Main roundabout: garden in the middle (ground key off; small roundabouts are a concrete dome now)

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
- [x] 0061 Cane billboards go shiny; cane beside the road too distracting

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
