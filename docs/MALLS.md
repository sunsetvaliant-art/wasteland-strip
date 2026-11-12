# Malls (planned, next after the valley)

Real ones from OSM: Sunnyside Mall (Murwillumbah), the Tweed Heads centres (Tweed City, Tweed Mall, Centro Tweed),
Kingscliff. Built by a MallGen in the same style as the house and shop generators (plan of rooms -> shell -> openings
-> props), so the look, doors, windows, boards, loot and zombie routing all carry over.

## Sunnyside (the model, from the user)
- Parking on the first level (the roof deck of the ground floor), reached by car from the street.
- Ground floor: a couple of cafes, a bank and a bottle shop facing the street/car park.
- A ramp wide enough for four trolleys side by side that turns 180 degrees gradually (a half-round switchback) up to the
  second floor, where the rest of the shops are.
- Lifts and stairs between levels as well.

## Generic mall
- Levels: ground (street shops + entries + loading dock), upper retail level, and/or a rooftop or first-level car park
  with cars left in it (some project cars, some lootable boots).
- Inside: a central concourse (wide walkway, skylights, columns, planter boxes, benches, bins), shop units either side
  with roller shutters (some down, some up, some jammed half way), a food court with tables and counters, toilets,
  a back-of-house service corridor running behind the shops to the loading dock and the bins.
- Anchors: supermarkets in the style of the big three (Coles, Woolworths, Aldi), but with made-up names and colours so
  they're not the real brands. Big floor with aisles of shelving, checkouts, fridges and freezers, a storeroom and dock
  behind. The best food loot in the valley, and the most dangerous.
- Getting about: stairs, a stuck escalator (walkable), lift shafts (a dead lift car you can climb through the hatch of),
  the trolley ramp, and the car park ramps.
- Mall props: shopping trolleys (pushable, carryable as cover), checkouts, the mall directory board, ATM, gumball and
  claw machines, kiosk carts, mannequins, clothes racks, food court tables, the big ceiling signs, security office.
- Loot tables: supermarket (cans, ration packs, bottled water once survival needs come in), chemist, sports/outdoors
  (ammo, packs, camping gear), hardware/discount store, food court (some), security office (torch, radio, handcuffs,
  the odd pistol), car boots in the car park.

## Gameplay
- Big hordes inside: zombies spawn as a crowd in the mall rather than a few at a time; they route through the concourse,
  stairs and the ramp (Buildings.route already handles rooms, doors and stairs).
- Raids: noise draws the horde along the concourse; roller shutters and boarded doors hold them; shutters can be
  dropped to cut the concourse into sections.
- Internal bases (with base building in half 2): claim a shop unit or the supermarket's storeroom, drop the shutters,
  board the back door; the roof car park is the way in and out.

## Built: Sunnyvale Mall (Sunnyside, Murwillumbah), 0.2.20
- scripts/world/mallgen.gd (MallGen): plan, openings, the ramp, roof/lantern/parapet/signs. tools/_malllab.gd to look at it.
- Corrected layout (user): the car park is the ground floor, under the mall, at street level; the street shops (cafes,
  bank, bottle shop...) and the double-height entry lobby face the street; the four-trolley ramp starts in the lobby's
  bay, climbs away from the street, turns 180 degrees and arrives on the first floor concourse.
- First floor: concourse under a glazed lantern (some panes gone), a made-up supermarket (FRESHWAY / GREENGATE /
  SAVEMART), a big-box furniture & electrical store, shop units with roller shutters and stockrooms, the food court
  with kitchens, toilets, security office, service corridor; lift doors (dead) and a stair in the core.
- Buildings._mall_life: wrecks in the car park bays and a horde (HORDE = 26) spread through the concourse,
  supermarket, food court and car park; killed off, they stay gone for 2 hours (saved).
- Placement: only OSM buildings named in place_buildings.MALL_NAMES become malls (Sunnyside -> SUNNYVALE).

## Tweed City
- docs/tweed_city_plan.png: the centre directory (user). Hoyts is drawn small there: in reality 5-7 big screens fill the bottom left, attached at that point.
- Second photo the user sent of the black ramp and glass balustrades is Sunnyside.
- Modern kit to build (user): rectangular bulkheads/soffits, high ceilings, polished floors, glass shopfronts, a sense of scale; no curves.

## NEXT (handoff, 2026-11-08)
1. Performance: Sunnyvale ran 28 fps / ~9.6k draw calls on a GTX 1650 Ti. Merge each room's fixtures (FIX props) into one mesh.
2. Modern 2020 mall kit (all malls, Sunnyvale first): 6-7 m concourse ceilings with a clerestory; rectangular bulkheads and soffits;
   downlight grid; glossy cream terrazzo with straight dark inlay bands; full-height glass shopfronts with aluminium frames, sign
   bands and see-through grilles; glass balustrades; white columns; black ribbed travelator ramps; dead escalators; made-up banners
   and wayfinding signs; fallen ceiling panels and survivor barricades.
3. Tweed City from docs/tweed_city_plan.png, scaled to the real satellite outline; Hoyts = 5-7 big screens bottom left; multi-level car park.
   Look for real plans: NSW Planning Portal (PPS-2019NTH002), Tweed Council DA tracker, owners' leasing brochures.
4. Tweed Mall.
5. Servos (real OSM fuel stations; generated canopy, bowsers, kiosk) and pubs, 2020-era look.
6. Known issue: user reports project-car chassis not appearing (cars spawn). Parked for now at the user's request.

## Building order the user set (3, 1, 2, 4), one patch per building type, for the Thursday session
- 3. Malls: Sunnyvale done (0.2.20). Still to do: the modern kit, Tweed Mall, then Tweed City (cinemas, IMAX, multi-level car park).
- 1. Servos (real OSM fuel stations, generated canopy over the bowsers, kiosk, workshop bay, car wash), then pubs (front bar,
     lounge/bistro, kitchen, cool room, TAB, toilets, beer garden, drive-through bottle shop; old corner hotels two storeys
     with verandah and rooms upstairs). 2020 era.
- 2. Civic: schools, churches, halls/community centres, clubs (bowls/RSL/surf), motels, fire stations, hospital/medical,
     police, post office, caravan park cabins, Condong sugar mill. Each with a sensible floor plan for its type.
- 4. Extend the map north to the border/Coolangatta; high-rises with enterable ground floors (upper floors sealed).
- 7. Houses: orient and nudge so none overlap a road or each other (user saw overlaps in game).
- 8. HARD CRASH: pressing I (inventory) near a car cab/shell (user, 0.2.23). Ask for the crash log from %APPDATA%\Godot\app_userdata\Wasteland\logs\.
- 9. Crash log: on start, if last session did not close cleanly, zip its log next to the F9 reports and tell the player.

## Also outstanding (from earlier sessions)
- Check in game (never seen): Sunnyvale's 6.5 m ceilings and polished floors (0.2.22/23), the horde and zombies following up the ramp, the T/G/K key fix (0.2.24).
- Waiting on the user: car files Bare_Bones_Muscle and Rustbound_Chevy_Relic, for the detail fix.
- LAN: doors, windows, boards (and now mall shutters/hordes) aren't synced between players.
- Cars have no damage model yet, so the spanner's "repairs" have nothing to fix.
- Sliding shed doors (only roller doors exist).
- A verandah deck rendered too dark in one shot.
- Performance: ~36k buildings now; ask how Tweed Heads runs; shorten the full-build radius if it stutters.
- ~10% of real buildings are left out where OSM roads and satellite outlines disagree (they'd sit on a road).
- Kingscliff, Banora and Cabarita shopping centres are plain shop rows: give them small single-level centres.
- Tweed Heads high-rises (inside the map) with enterable ground floors.
- Half 2 (the big one): base building, crafting, survival needs, scavs, traders; open design questions Q1-8, 10, 11,
  17-21, 23, 32, 34-37, 39-46 (start kit knife + water), 48 (creative as a host toggle). See docs/DESIGN_0.3.md.

## Facts found 2026-11-12
- Tweed City: OSM retail outline 62,063 m2, bbox 268 x 402 m, centre (13930, -14099), 114 pts. The directory map
  (docs/tweed_city_plan.png, 722x1069 px) has the same aspect (0.67), so it's close to scale: ~0.4 m per px.
- Tweed Mall sits at about (13522, -17036): just north of the map edge (z = -16960). It needs the northern map
  extension first (do it with Coolangatta).

## Done 2026-11-12 (patch 0025)
- Handoff items 1 and 2: fixture merging (BuildProps batches of 48 static fixtures -> one mesh), FULL_R 90 / FULL_DROP 120,
  cached sash windows, shadows off on small things. Mall lab draw calls: concourse 2375 -> 752, supermarket 1242 -> 261.
- Modern kit on Sunnyvale: MallGen._glaze (glass panes + matching "open" on the concourse side; also fixes the
  supermarket windows that were blocked), grille rollers (BuildRoller.setup(..., grille)), r["ceil"] dropped ceilings,
  MallGen._dress (bulkheads, downlights, floor inlays, hanging signs, banners, fallen panels), "rubber" ramp + glass sides.
- Not yet seen in the real game by the user. Known rough spot: ramp room has a brown band on its side walls and a black ceiling.
- Next: Tweed City (item 3).

## Sunnyvale redone from the real plans (patch 0027, 2026-11-12)
- The real Sunnyside floor plans are on the centre's own shop-guide page as SVG; rendered copies in docs/sunnyside_lower.png
  and docs/sunnyside_upper.png (north up; plan is ~0.25 m per SVG unit; block about 97.6 x 94.3 m).
- MallGen is now layout-driven: plan_into -> _sunnyside(), rooms written in metres east of the west wall / south of the
  street front and stretched to the lot. Add other malls as their own layout functions (_tweed_city, _tweed_mall).
- Generalised: any number of "concourse" rooms (arms) each get bulkheads/inlays/signs/lantern (_dress, _roof_room);
  wells ("void" with well=true) get balustrades from the openings recorded in r._edges; shop signs from r._fronts;
  bare upstairs walls get cladding + parapet (_bare); LOD is one block per room; footprint need not fill the lot upstairs.
- Tweed City: tweedcity.com.au/centre-map is a JS widget (no static plan); use docs/tweed_city_plan.png.
  Tweed Mall: site refuses automated fetches; known facts: single level, opened 1973, three supermarkets, 62 specialty
  shops, ~5 ha site, corner Wharf St and Bay St. Lay it out from the OSM outline.
- Shop flats (0026): ShopGen.upper_rooms has a passage (CORR) beside the stairwell so every room opens off it.

## Twin City = Tweed City (patch 0028, 2026-11-12)
- MallGen._twin_city: ONE level at ground (p.mall.fl = 0, p.mall.y = 0), written in the centre map's own pixels
  (docs/ref/tweed_city_centremap.jpg, 0.452 m/px; local x = north to south, front +z = west, the main road).
  Anchors FRESHWAY, GREENGATE, HOLLIS & CRANE, BIG VALUE, BIGMART, DJ HI-FI; REGAL CINEMAS (lobby, hall, 5 screens with
  stepped seats); food court. No multi-level car park yet (the real deck car park isn't modelled).
- It isn't named in OSM, so tools/add_malls.py puts it on the lot list (called at the end of place_buildings.py):
  ["mall", 13940.68, -14048.52, yaw -1.7325, 378.3, 244.7, seed, "TWIN CITY"]. The lot list's version changed, so
  saved cupboards/boards start fresh.
- Ocean: the released main.gd had the sea sheet at -0.05 m, under the flat 0 m seabed, so it never showed. Now at
  +0.1 m with base_depth 5 (water.gdshader) so it shades as deep water.
- Tweed Mall refs: docs/ref/tweed_mall_*.jpg (Google indoor map with 50 m scale bar, satellite, 3D). Still needs the
  map extended north (it's at about z = -17036, the map ends at -16960).
