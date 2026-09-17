# Asset Kit Research — Vertical Slice (Targets 1 & 2)

> Researched 2026-09-16 for the one-block vertical slice (club exterior, entrance, office, dressing
> room, one stand, concourse/kiosk, tunnel, parking/road, one British street, lighting).
> Prices are USD list prices on the day, **excluding VAT**. Nothing here is bought yet.

## Hard facts that shape every choice

| Constraint | Verified value | Source |
|---|---|---|
| Roblox import formats | `.fbx`, `.obj`, `.gltf` via the 3D Importer | create.roblox.com/docs/studio/importer |
| Triangles per mesh | max 20,000 (split bigger meshes in Blender) | create.roblox.com/docs/art/modeling/specifications |
| Textures | up to 4096², PBR via SurfaceAppearance: Color, Normal (OpenGL), Roughness, Metalness (separate greyscale maps) | create.roblox.com/docs/art/modeling/texture-specifications |
| One material per mesh | multi-material FBX is split into child MeshParts on import | same |
| Unreal-only packs (`.uasset`) | need Unreal Engine installed to export FBX + textures, so **avoided** unless FBX is included | listing "Included formats" |
| Unity packs (`.unitypackage`) | a tar.gz of raw FBX/PNG, extractable with a script, no Unity install needed | — |
| Unreal ORM textures | occlusion/roughness/metal packed in one PNG, split channels before upload | — |
| Fab Standard License | any engine ("usage is not limited to Unreal Engine"), commercial OK, no credit needed, Personal tier if under $100k revenue in 12 months, same rights as Professional; must not let end users extract content, so never republish imported meshes on the Creator Store | fab.com/eula |
| Unity Asset Store EULA | no engine restriction for non-Restricted assets; "Extension Asset" = single seat on 2 computers | unity.com/legal/as-terms |
| Poly Haven | CC0, no obligations | polyhaven.com |
| Creator Store free models | strip all scripts on import (CLAUDE.md rule 9) | — |

## Target 1 — the packs already identified

### Modular English Housing — Howard Coates — **BUY NOW** ($39.99)
- Fab: https://www.fab.com/listings/5ee7bfef-4d09-4623-b629-216a65d131db (buy here, not Unity: the Unity version is HDRP-only and package-only)
- Formats: OBJ, FBX, Blender, Unity, Unreal. 260+ modular pieces + 12 merged buildings.
- One trim-sheet texture set (4096 D/N/R/M) with 5 material variants, so one SurfaceAppearance per variant. Cheapest possible import.
- Style: contemporary English new-build estate (2000s semis, detached, small flats), clean and plain. Not Victorian terraces.
- Risks: merged-building triangle counts unpublished (fallback: use the modular pieces); downscale trim sheet to 2K for mobile.

### UK Street Props — Studio-Lab — **BUY NOW** ($29.99)
- Fab: https://www.fab.com/listings/7b36c3ef-351e-44d6-bd54-16c59572fbe2
- Formats: Unreal + FBX. PBR (Quixel Mixer / Substance). Published 2022, updated 2026-06. No ratings yet.
- Contents (from gallery): brick walls, wrought-iron railings and gates, chain-link fencing, wooden fences/gates, ~40 UK road signs, lamp posts, K6 phone boxes, pillar box, bus shelter, steel footbridge + stairs, flyover section, 2 skips, commercial bins, bin bags, pallets, concrete/jersey barriers, cones, sandbags, pylon, road/junction pieces.
- Risks: master materials are Unreal-only (irrelevant, we use FBX + maps); ORM textures need channel splitting.

### UK Asset Collection Part 1 — rik4000 — **WAIT** ($45, Unity)
- https://assetstore.unity.com/packages/3d/environments/urban/uk-asset-collection-part-1-79374
- 10 packs, 350+ buildings/props (terraces x3, bungalows, commercial x2, industrial, pubs, services, props). 1024 diffuse+normal only, 350–3,500 tris per building, 2017. Includes a small non-league ground.
- Looks like Cities: Skylines-era baked buildings; fine as mid-distance town filler (phase E), dated at street level next to PBR kits. Overlaps Modular English Housing on housing.
- Cheaper routes to the same author: free sample https://assetstore.unity.com/packages/3d/environments/urban/uk-terraced-houses-pack-free-63481 ; GameDev Market packs with FBX+PNG at $3–5 each, e.g. https://www.gamedevmarket.net/asset/uk-terraced-houses-pack-1-7450 (10 houses x 3 textures + mirrored = 60 variants, 350–850 tris).

### Vegetation / vehicles / props — no earlier list was found; substitutes
- Trees (free, Creator Store, PBR oaks by Letaij): 98950444096614 (6 oaks), 114023396228594 (3 oaks); Roblox's own "Oak Tree" 18717544. Hedge: 13364734150. Paid $2.99–3.99 packs exist (Hyper_verse 109768630881842, NyrexBLX 102819299862583) but are not needed for the slice.
- Vehicles: no British vehicle pack at kit quality anywhere checked. Try free Creator Store "2021 Ford Transit Van" 87089223661838 plus two hatchbacks, inspect in Target 4; fallback later: one generic hatchback + van from CGTrader (~$10–20).
- Props: Poly Haven CC0 (FBX/GLTF/Blend, 1K–4K PBR). Useful ids: metal_office_desk (6.9k tris), modern_arm_chair_01 (8.9k), classic_laptop, clipboard, office_notepads, stationery_supplies, vintage_stapler, Television_01, dartboard, football, dirty_football, CashRegister_01, CoffeeCart_01 (27.7k, decimate), painted_wooden_bench (630), modular_street_seating, plastic_monobloc_chair_01, steel_frame_shelves_01-03, worn_metal_rack, wooden_bookshelf_worn, drawer_cabinet, metal_trash_can, cardboard_box_01, plastic_crate_01-03, hand_truck, wooden_ladder, WetFloorSign_01, korean_fire_extinguisher_01, security_camera_01/02, utility_box_01/02, power_box_01, exterior_aircon_unit, rollershutter_door, rollershutter_window_01-03, modular_chainlink_fence, concrete_road_barrier, water_manhole_cover, street_lamp_01 (30.6k, decimate), modular_electricity_poles, modular_electric_cables, modular_fire_escape, mounted_fluorescent_lights, caged_hanging_light, wooden_picnic_table, old_tyre, propane_tank. Many are 5k–30k tris, so decimate to 5k or less.

## Target 2 — core club asset search (shortlist)

| Area | Candidate | Price | Format | Verdict |
|---|---|---|---|---|
| Concessions | Fast Food Restaurant Kit — Brick Project Studio (Unity) https://assetstore.unity.com/packages/3d/environments/fast-food-restaurant-kit-239419 | FREE | Unity pkg (FBX inside) | **USE**: 3 counters, register table, display case, drink machine, trays, food, 8 stools, 11 tables, 3 benches, lamps, modular walls; 12–5,000 tris; 5 stars (5 reviews), 1,013 favourites |
| Concessions | Food and Kitchen Props Pack — reach the enD (Unity) https://assetstore.unity.com/packages/3d/props/food-and-kitchen-props-pack-85050 | FREE | Unity pkg | USE as filler |
| Concessions | Grocery Props & Super Market Kit — Indus North https://www.fab.com/listings/941c66ff-b166-4c22-ad6e-9d40ce0b82b6 | $7.99 | Unreal only | SKIP (no FBX) |
| Office | Office furniture and more — 3D Models SCA https://www.fab.com/listings/e5f8e162-7901-4803-8856-8291591a47ed | $8.99 | FBX | OPTIONAL: 52 meshes, 4 desks, 3 chairs, 3 bookshelves, 4 filing cabinets, printer, 2 phones, water dispenser, coffee maker, clock, bin; 78–3,427 verts; 2K PBR (ORM) |
| Office | Retro Office props — JBronswijk https://www.fab.com/listings/c10bceaa-7db5-4157-89fd-394f28f56bf2 | $24.99 | FBX/OBJ/Blend | SKIP: lovely 1950s steel desk set, but Poly Haven's metal_office_desk + chair cover it free |
| Office | Office Pack Modular PBR — Enyra3D | $11.99 | Unreal/Unity | SKIP: sterile modern |
| Dressing room | Locker Room Asset Pack Vol.01 — Jake Dunlop (ArtStation) https://www.artstation.com/marketplace/p/POqDV/locker-room-asset-pack-vol-01 | $29.99 | not stated | WAIT: benches, locker + 9 doors, 3 showers, sinks, toilets, dispensers, mirrors; 4K/2K PBR; confirm FBX before buying |
| Dressing room | Locker Room Props Pack — Sat Productions (Unity) https://assetstore.unity.com/packages/3d/props/interior/locker-room-props-pack-308369 | $10 | Unity pkg | OPTIONAL: lockers, benches, wall hangers, racks; 2025; no reviews |
| Dressing room | Lockers Pack — Game-Ready (Fab) | $14.99 | Unreal | SKIP: they are safes |
| Stadium | Football Stadium — Studio-Lab https://www.fab.com/listings/2692985a-d021-4539-8fa5-ae43c9d1342e (Unity id 77218) | $49.99 | Unreal only / Unity pkg | WAIT for top-tier stadium phases (buy the Unity version then for FBX); 280k tris, modern all-seater |
| Stadium | Modular Stadium Kit — AFox1 | $10.99 | Unreal | SKIP: 2017, facade-only, 3.6 stars |
| Stadium | Sports Stadium — MANISPIN ($99.99); Football Modular Stadium — Lokiana ($25, cartoon); Stylised Sport Stadium — Oleg.Verenko ($39, low-poly) | — | — | SKIP |
| Stadium | Creator Store free: seat rows 208791661, floodlight tower 114304849826345, turnstiles 130179320229653 | FREE | rbxm | Inspect in Target 4; seats are the only likely keeper |

### Build-in-Roblox list (no purchase needed)
Terrace steps, crush barriers, covered stand + steel columns/trusses, dugouts, floodlight pylons, tunnel, turnstile housings, wooden bench + peg dressing-room units, physio bed, tactics whiteboard, kit skip, boot rack, shower area (tile material + heads), trophy cabinet, noticeboard, radiator, kiosk hatch + roller shutter, pie warmer, drinks fridge shell, menu boards (decals), club signage.

## Popularity check — other British housing / street packs (2026-09-16)

Every British-specific building pack on Fab or Unity has 0–7 ratings; the niche is small. Ratings
mainly screen for broken files. Fab's refund policy covers "not in conformity with the description"
and seller-approved technical issues even after download; Unity's automatic refund only applies
within 14 days if never downloaded. So unrated packs are safer bought on Fab.

| Pack | Rating | Price | Formats | Verdict |
|---|---|---|---|---|
| UK Housing – Terraced Set 1 / Set 2 — Macwelshman https://www.fab.com/listings/6ff1fd7a-0330-4404-b49d-14b2a0797c44 | 1.0 (1, no text) / none | $39.99 each | Blender, FBX, OBJ, glTF, GLB | **Real alternative for the slice street**: three Victorian bay-window terrace rows per set (basic / extended / re-fronted), 4K PBR, 1–2 MB .blend so light geometry; non-modular |
| Modular terrace houses — AmeliaTeale | none | $29.99 | Unreal only | WAIT: 405 meshes, avg 321 tris, watercolour-stylised Yorkshire terraces; needs an Unreal export step |
| British Modular Buildings — Lou Chevreux https://www.fab.com/listings/e4ac5ea4-9072-4e2a-b579-9709ea3ff089 | none | $27.99 | Unreal, Blender, FBX | WAIT: Georgian/Victorian 3–4 storey brick blocks, modular; good for flats-above-shops later |
| London – British Environment — Scans Factory | 4.8 (6) | $49.99 | Unreal, Unity, UEFN | SKIP: photoscanned Seven Dials, built for RTX 4080; far beyond Roblox/mobile budgets |
| London City Streets – Camden — CGHERO | 5.0 (2) | $29.99 | Unreal, Unity, UEFN | SKIP: 287 photoscanned meshes, photoreal and heavy |
| British – City Pack — PolySphere | 5.0 (7) | $169.99 | Unreal only | SKIP: over budget, no FBX |
| Stylized UK Modular House and Road — StarGameStudios | none | $69.99 | Unreal, UEFN | SKIP: right idea, too cartoony, no FBX |
| 60 houses pack UK Terrace — Minimaliano | none | $49.99 | Unreal only | SKIP: procedural in-engine materials |
| British Street Asset Pack — FuZzYar | none | $39.99 | Unreal only | SKIP: ~10 props |
| Modular British Buildings (Facades) — Nimikko | none | $19.99 | Unreal only | SKIP |
| Modular Victorian Houses — Studio-Lab | none | $9.99 | FBX, glTF | SKIP: looks Parisian |
| Modular Victorian Street — Ebgival | none | $19.99 | UE 4.26 only | SKIP: 1890s |
| UK Terraced Houses Pack FREE — rik4000 (Unity) | 4.6 (45) | free | Unity pkg | free style test only |

## Budget (total $500)
- Proposed cap on 3D assets for the slice: $120.
- Target 1 recommended: $69.98 (+VAT).
- Target 2 recommended: $0 (optional +$8.99 office, +$10 lockers).
- Reserved for marketing / thumbnails / launch ads: at least $380.
