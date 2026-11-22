# TODOwnload: staged vehicle downloads

Downloaded from Sketchfab for later. Not in the game yet: the `.gdignore` here keeps Godot from importing or
exporting any of it. Each one has been cut to roughly 45-55k triangles (gltfpack), stood upright in metres with
its length along Z (tools/glb_upright.py), its glass made see-through for Godot and its textures capped at
1024 px (tools/glb_slim_post.py). Named nodes are kept, so the wheels can still be cut off on import.

The rule for vehicles: clear windows, and either no interior or an accurate one, nothing in between.

| File | Model | Author | Licence | Triangles (was) | Size (m) W x H x L | Draw calls | Windows / interior |
|---|---|---|---|---|---|---|---|
| hilux_mk5_dualcab_1988.glb | [Toyota Hilux (Mk5) Double Cab 1988](https://sketchfab.com/3d-models/toyota-hilux-mk5-double-cab-1988-f8a557a46ff34a68893dce0136995408) | niev | CC Attribution | 52,422 (827,028) | 1.88 x 1.6 x 4.5 | 67 | Clear; full interior. Note: it's an extra cab, not a dual cab, whatever the title says |
| hilux_mk6_dualcab_2001.glb | [Toyota Hilux (Mk6) Double Cab 2001](https://sketchfab.com/3d-models/toyota-hilux-mk6-double-cab-2001-160692a5e0514d14aa2bd6498873345e) | niev | CC Attribution | 50,139 (1,195,696) | 1.96 x 1.79 x 4.89 | 66 | Clear; full interior |
| holden_vz_ute_2004.glb | [Holden Ute (VZ) 2004](https://sketchfab.com/3d-models/holden-ute-vz-2004-c367417953f0406bbc0342df2ab883b7) | niev | CC Attribution | 54,833 (943,412) | 2.15 x 1.5 x 5.06 | 48 | Clear; full interior |
| liaz_fire_truck.glb | [super rare LIAZ SA8-L110 cistern fire truck](https://sketchfab.com/3d-models/super-rare-liaz-sa8-l110-cistern-fire-truck-81a98bff59c4416082328001c07079c6) | orphanrtg | CC Attribution | 143,999 (1,750,029) | 3.17 x 3.08 x 7.73 | 26 | FAILS: a photo scan of a wreck, the glass is scanned in (not clear) and the cab is scanned junk |
| mazda_1000_1973.glb | [1973 Mazda 1000 2-Door Sedan](https://sketchfab.com/3d-models/1973-mazda-1000-2-door-sedan-3d716d34c019484f90cca00905ec0937) | Res1n | CC Attribution | 50,848 (811,564) | 1.59 x 1.38 x 3.73 | 54 | Clear; full interior |
| mazda_2_dy_2003.glb | [2003 Mazda 2 (DY)](https://sketchfab.com/3d-models/2003-mazda-2-dy-8435292e453f4c5e9d9f00785a645ca3) | Res1n | CC Attribution | 52,342 (1,146,362) | 2.02 x 1.62 x 4.11 | 74 | Clear; full interior |
| mazda_323_bj_1998.glb | [1998 Mazda 323 BJ Sedan](https://sketchfab.com/3d-models/1998-mazda-323-bj-sedan-85d9f66642ca4e309103cf33e48ec480) | Res1n | CC Attribution | 51,056 (536,741) | 2.07 x 1.43 x 4.48 | 41 | Clear; full interior |
| mazda_3_bk_hatch_2003.glb | [2003 Mazda 3 BK Hatchback](https://sketchfab.com/3d-models/2003-mazda-3-bk-hatchback-7d3ac0221bfa479eb920bd2c83417986) | Res1n | CC Attribution | 46,738 (1,015,459) | 1.86 x 1.85 x 4.41 | 67 | Clear; full interior |
| mazda_3_sedan_2003.glb | [2003 Mazda 3 MK1 Sedan](https://sketchfab.com/3d-models/2003-mazda-3-mk1-sedan-435114aa6a8b42d1b1e06d12bf38251b) | Res1n | CC Attribution | 46,380 (883,427) | 1.9 x 1.68 x 4.33 | 60 | Clear; full interior |
| mazda_5_2005.glb | [2005 Mazda 5 MK2 Sport](https://sketchfab.com/3d-models/2005-mazda-5-mk2-sport-2f4c797ca8da438b8d2bcfeb55883c89) | Res1n | CC Attribution | 56,227 (2,030,704) | 1.98 x 1.86 x 4.54 | 91 | Clear; full interior |
| mazda_616_1974.glb | [1974 Mazda 616 Sedan](https://sketchfab.com/3d-models/1974-mazda-616-sedan-7891e01b62bd4c66a3022ce0c1732845) | Res1n | CC Attribution | 57,329 (940,365) | 1.73 x 1.41 x 4.09 | 59 | Clear; full interior |
| mazda_626_gf_1997.glb | [1997 Mazda 626 GF Sedan](https://sketchfab.com/3d-models/1997-mazda-626-gf-sedan-5d1c556bbd5e47209cb8b1d667cee868) | Res1n | CC Attribution | 56,036 (717,138) | 2.13 x 1.52 x 4.85 | 55 | Clear; full interior |
| mazda_6_wagon_2011.glb | [2011 Mazda 6 Wagon](https://sketchfab.com/3d-models/2011-mazda-6-wagon-6f697b08d4bc49879ec58ccdce983b01) | Res1n | CC Attribution | 43,157 (1,247,096) | 1.99 x 1.48 x 4.76 | 66 | Clear; full interior |
| mazda_bseries_un_dualcab_2004.glb | [2004 Mazda B-Series UN 2500 Double Cab](https://sketchfab.com/3d-models/2004-mazda-b-series-un-2500-double-cab-e25bd7759aa5478b9ea3d0b1622bdcfc) | Res1n | CC Attribution | 51,449 (1,127,394) | 2.03 x 1.64 x 5.13 | 83 | Clear; full interior |
| mazda_cx30_2020.glb | [2020 Mazda CX-30](https://sketchfab.com/3d-models/2020-mazda-cx-30-e5260672b3614b6abb1e00c9d487ba6c) | Res1n | CC Attribution | 74,941 (3,283,346) | 2.13 x 1.54 x 4.33 | 257 | Clear; full interior. Couldn't get under 75k without spoiling it |
| mazda_cx5_2017.glb | [2017 Mazda CX-5](https://sketchfab.com/3d-models/2017-mazda-cx-5-a57b6861ac164e10847861c5b9a30ca3) | Res1n | CC Attribution | 42,574 (3,517,843) | 2.09 x 1.67 x 4.5 | 235 | Clear; full interior |
| mazda_mpv_lv_1997.glb | [1997 Mazda Mpv-LV](https://sketchfab.com/3d-models/1997-mazda-mpv-lv-828c2e79ef374c98b14f4f5ba57292d2) | Res1n | CC Attribution | 47,134 (1,264,297) | 2.07 x 1.77 x 4.64 | 50 | Clear; full interior |
| mazda_mpv_lw_2002.glb | [2002 Mazda MPV (LW)](https://sketchfab.com/3d-models/2002-mazda-mpv-lw-d1418e5b19b748b480e9fd19696a69ae) | Res1n | CC Attribution | 45,466 (1,159,208) | 2.09 x 1.77 x 4.78 | 56 | Clear; full interior |
| mazda_mx3_1993.glb | [1993 Mazda MX-3](https://sketchfab.com/3d-models/1993-mazda-mx-3-5966ffc44dce4375ba3c56c3e7dd9c09) | Res1n | CC Attribution | 50,851 (842,086) | 1.87 x 1.27 x 3.97 | 84 | Clear; full interior |
| mazda_mx5_na_1989.glb | [1989 Mazda MX-5 (NA)](https://sketchfab.com/3d-models/1989-mazda-mx-5-na-bd6429f3d02a426f9a714a66c33bb353) | Res1n | CC Attribution | 45,928 (1,145,851) | 1.87 x 1.23 x 3.96 | 66 | Clear; full interior |
| mazda_mx5_nb_1998.glb | [1998 Mazda MX 5 (Nb)](https://sketchfab.com/3d-models/1998-mazda-mx-5-nb-25fc4c8bd4494fe0b9e456644b269c6f) | Res1n | CC Attribution | 47,185 (764,939) | 1.88 x 1.23 x 3.93 | 72 | Clear; full interior |
| mazda_mx5_nc_2009.glb | [2009 Mazda Miata MX-5 Roadster](https://sketchfab.com/3d-models/2009-mazda-miata-mx-5-roadster-96056443d55c4afaa90099e9e1d45d9b) | Res1n | CC Attribution | 55,109 (1,089,965) | 1.89 x 1.2 x 3.99 | 62 | Clear; full interior |
| mazda_mx5_nd_2014.glb | [2014 Mazda MX-5 (ND)](https://sketchfab.com/3d-models/2014-mazda-mx-5-nd-35bd007e1bc549d580ccc208a6038ec1) | Res1n | CC Attribution | 57,987 (1,306,252) | 1.86 x 1.22 x 3.9 | 100 | Clear; full interior |
| mazda_rx7_concept_2018.glb | [2018 mazda rx-7](https://sketchfab.com/3d-models/2018-mazda-rx-7-cdc069c27e7d477b866605d522c86e8e) | Res1n | CC Attribution | 13,574 (15,698) | 1.95 x 1.23 x 4.52 | 13 | Clear; full interior with a roll cage (a widebody concept, not a road RX-7) |
| mazda_rx7_fc_1985.glb | [1985 Mazda RX-7 MK2 (FC) Coupe](https://sketchfab.com/3d-models/1985-mazda-rx-7-mk2-fc-coupe-a8fda6c208b147b6a6344b64a3292d8c) | Res1n | CC Attribution | 49,983 (785,121) | 1.9 x 1.27 x 4.28 | 61 | Clear; full interior |
| mazda_rx7_fd_1999.glb | [1999 Mazda RX-7 FD](https://sketchfab.com/3d-models/1999-mazda-rx-7-fd-ff9c8b4fd8124cb1b54211baff7d6444) | Res1n | CC Attribution | 34,746 (650,294) | 1.86 x 1.25 x 4.28 | 38 | Clear; full interior |
| mazda_rx7_mk1_1978.glb | [1978 Mazda RX-7 MK1 SA](https://sketchfab.com/3d-models/1978-mazda-rx-7-mk1-sa-0ac42a2b5e31470487177f7ee7df56f5) | Res1n | CC Attribution | 47,450 (1,573,077) | 1.86 x 1.31 x 4.3 | 80 | Clear; full interior |
| mazda_xedos6_1992.glb | [1992 Mazda Xedos 6](https://sketchfab.com/3d-models/1992-mazda-xedos-6-06be4801411f449b928bc2d1379ead98) | Res1n | CC Attribution | 66,226 (832,445) | 1.91 x 1.36 x 4.57 | 59 | Clear; full interior |
| pickup_lowpoly.glb | [Pickup Truck](https://sketchfab.com/3d-models/pickup-truck-047615f53e2d45b9a1a2a4dd203d459c) | 00amza | CC Attribution | 5,047 (5,047) | 1.88 x 2.26 x 5.2 | 2 | FAILS: black windows, no interior; wheels are part of the body; low detail |
| ranger_mk1_dualcab_2003.glb | [Ford Ranger Mk1 Double Cab 2003](https://sketchfab.com/3d-models/ford-ranger-mk1-double-cab-2003-a0c1230493a54275b47b9c40038fb614) | niev | CC Attribution | 46,797 (1,022,617) | 2.12 x 2.0 x 5.2 | 81 | Clear; full interior |
| truck_wheels.glb | [Truck Wheels](https://sketchfab.com/3d-models/truck-wheels-43876b554e364239baff169fbb40548c) | hgowl22 | CC Attribution | 5,986 (5,986) | 1.65 x 1.07 x 2.29 | 4 | n/a (a dual truck wheel set: two tyres on one hub) |

Credits: all CC Attribution unless the table says otherwise; credit the author and link the model when one
goes into the game (assets/credits.json).

Draw calls: the counts above are as staged (every named part kept separate so the wheels can be found). Importing
one merges the body by material, which brings it down to about 10-20.

Left out:
- GENERIC PICKUP TRUCK 28 (nn3d): not downloadable, it's a paid Standard-licence model.
- 2005 Toyota Hilux Double Cab (outpiston): the same model as niev's Hilux Mk6 2001 above (same triangle count,
  re-uploaded) under a non-commercial licence, so the Mk6 is the one kept.

Redo one: `gltfpack -i model.glb -o out.glb -si <45000/triangles> -noq -kn -km`, then
`python3 tools/glb_upright.py out.glb [--flip] [--other] [--len 4.8]` and `python3 tools/glb_slim_post.py out.glb`;
look at it with tools/_todlshot.tscn (TODL_FILES=..., loads a .glb at run time without importing it).
