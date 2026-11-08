# Shop generator: Murwillumbah main street reference

Sources: Tweed DCP B22 (Murwillumbah town centre), Tweed heritage data cards, Echo "Look Up" article (2015),
photos of Murwillumbah St / Wollumbin St / Main St shops. (Street View itself couldn't be opened from this session.)

## What the street looks like
- Shops built hard to the footpath, zero setback, side by side with shared party walls. Narrow fronts (about 5-10 m),
  deep lots running back to a lane or yard.
- Mostly 1 and 2 storeys. Lots rebuilt after the 1907 fire: Federation, Interwar and some Art Deco, plus a few
  1950s-70s infills (flat parapet, aluminium, brick) and hotels on the corners.
- A tall parapet hides the roof. Styles to generate:
  - stepped / tiered (Deco)
  - flat with a moulded cornice
  - curved or segmental centre with a name panel
  - triangular pediment (Federation)
  - plain 60s box parapet with a sign band
  Many carry the building name and a date (e.g. "1925") in raised letters.
- A suspended cantilever awning over the whole footpath, about 3 m deep and 3.3 m up, hung from the facade on
  diagonal tie rods. Pressed-metal lined soffit; signs hang under the awning. The awnings run nearly continuous
  along the street.
- Highlight windows: a band of small panes (often leadlight or patterned glass) just above the awning line,
  under the upper floor.
- Upper floor (2-storey ones): 2-4 tall double-hung windows in a row, sometimes pilasters between them.
- Shopfront: big display windows on a tiled stall board (about 0.5 m high, dark glazed tiles), thin
  timber/bronze/aluminium frames, a recessed entry (door set back about 1-1.5 m between angled windows).
- Corner hotels: 2 storeys with a posted verandah and a balcony above (timber or cast iron), wider fronts.
- Banks: symmetrical, classical (pilasters, pediment over the entry), render.
- Colours: painted render. Cream, white, heritage greens, terracotta, pale blue, mustard. Some face brick
  (red or brown). Trim picked out in a second colour.

## Generator plan
- Kinds: general shop, cafe/milk bar, chemist, hardware, butcher, newsagent, bank, hotel (corner), servo
  (already exists), op shop.
- Inside: front shop floor with counters, shelves and racks, a back storeroom, toilet, and a rear door to the lane.
  Two-storey ones get stairs to an upstairs flat or offices.
- Loot by kind: chemist (meds, bandages), hardware (tools, nails, planks, tape), butcher/cafe (food, cans),
  newsagent (batteries, maps), hotel (bottles, food).
- Glass display windows can be shot out and climbed through, the front door locks, and a roller shutter
  sometimes covers the front.
- Placed where the map has shop/retail lots in the town centres (Murwillumbah, Kingscliff, Tweed Heads...),
  in rows along the street with shared walls and a continuous awning.

## Built (0.2.18)
- scripts/world/shopgen.gd (ShopGen): plan, openings, recessed entry, parapet/awning/verandah, lettering.
- Kinds of shop: general, chemist, hardware, grocer, cafe, newsagent, clothes, sports, pub, bank. Each has its own
  shelving and loot table (Items.LOOT: chemist, hardware, grocer, newsagent, clothes, sports, general, pub, till, bank).
- Parapets: flat, stepped (Deco, with the year), curved, pediment (Federation and the banks), box (60s sign band).
- Two-storey ones (about 3 in 10, pubs always, banks often): a street door, a side passage and a long stair up to a
  flat (lounge over the street, kitchen, bath, bedrooms).
- tools/place_buildings.py: OSM retail/commercial/pub/bank buildings become rows of shops fronting the best street
  nearby (the main street beats the lane), with wide blocks cut into 5-9 m shopfronts. OSM's shop type picks the
  kind of shop, and the awning depth is fitted to the room to the kerb. Lot field 8 is "sub/levels/awning".
- buildings.json carries a "ver": a save from a different lot list starts the cupboards and boards fresh.
- tools/_shoplab.gd: a row of shops for checking by eye (SEED, N, SUBS, CUT, UPPER).
