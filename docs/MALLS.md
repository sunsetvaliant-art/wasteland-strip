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
