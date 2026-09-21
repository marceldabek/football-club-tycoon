# Free Asset Shortlist — Rivermere Town (backlog D1.1)

> Researched 2026-09-17 against the reference images in `assets/references/` (RivermereCenter,
> RiveremereWestdale, RivermereNorthfields, RivermereRiverside, RivermereStation,
> rivermer.industrialestate, RivermereTurnstileEntrance). Every image says "Riverdale" — the
> town is always **Rivermere** in the game.
>
> **Hard constraint used throughout:** only sources that need no login and no account —
> Poly Haven (CC0), ambientCG (CC0), Kenney (CC0), and Quaternius/Kay Lousberg CC0 packs
> (mirrored on the no-login site poly.pizza). Nothing here has been downloaded yet; this is a
> shortlist to approve, not a buy list of purchases already made.
>
> **Style reality check:** the kit style (see `docs/ASSET_KIT.md`, `assets/kit/MANIFEST.md`) is
> **realistic PBR** — the Modular English Housing and UK Street Props Fab packs, plus Poly Haven
> props. Kenney and Quaternius/Kay Lousberg packs are **flat-shaded / vertex-coloured low-poly
> stylised** models with no PBR texture maps. They read fine at a distance (skyline filler, far
> background traffic, background trees on a hill) but will visibly clash with the realistic brick
> terraces and photoreal materials if placed anywhere the player can walk up to. Every stylised
> entry below is marked **background/distant use only**.
>
> Poly Haven has almost no street furniture, vehicles, or buildings — it is a props/materials
> library. That gap is real, not a research miss: I queried its full model list (521 models,
> 44 categories) and there is no bus shelter, wheelie bin, hedge, car, railway, church,
> playground, or wind turbine in the catalogue at all.

---

## 1. Red-brick terraced houses / British house facades

| Name | Source | Licence | Format | Poly/tris | Texture | Style fit | Verdict |
|---|---|---|---|---|---|---|---|
| Modular English Housing — Howard Coates | fab.com/listings/5ee7bfef-4d09-4623-b629-216a65d131db | Fab Standard License ($39.99, not free) | OBJ/FBX/Blender | 260+ pieces, 12 merged buildings | 4096 trim sheet, 5 variants | Contemporary English new-build semis/detached, not Victorian terraces. Realistic PBR — matches kit style. | Already owned (see MANIFEST.md) — not a free find, listed for contrast only |
| UK Housing – Terraced Set 1/2 — Macwelshman | fab.com/listings/6ff1fd7a-0330-4404-b49d-14b2a0797c44 | Fab Standard License ($39.99, not free) | Blender/FBX/OBJ/glTF/GLB | not published | 4K PBR | Victorian bay-window terraces — the actual Westdale/Northfields look. Paid, already flagged in ASSET_KIT.md. | Not free — SKIP for this doc |
| No free red-brick British terrace mesh found | — | — | — | — | — | Poly Haven, ambientCG, and Kenney do not publish building facades of any kind (Kenney's "houses" are cartoon low-poly boxes, see §2). Quaternius has no British housing pack. | **SKIP — build terraces from ambientCG brick/render materials on primitive Roblox facades instead** (matches CLAUDE.md §20 "Roblox primitives first") |

**Verdict for this need:** no usable free terrace *mesh* exists anywhere that meets the no-login/CC0 rule. The realistic path is procedural box facades (bay windows, chimneys, sash windows as inset parts) textured with the brick + render + slate materials in §3 below, which are free, 1K-ready, and already the right style. Reserve the paid Macwelshman set only if procedural facades read too flat.

---

## 2. Shopfronts / high street buildings

| Name | Source | Licence | Format | Poly/tris | Texture | Style fit | Verdict |
|---|---|---|---|---|---|---|---|
| City Kit (Commercial) — Kenney | kenney.nl/assets/city-kit-commercial | **CC0 1.0** (Kenney site) | glTF/FBX/OBJ | ~50 modular pieces | none — flat vertex colours | Cartoon low-poly shopfronts/skyscraper pieces, no textures at all. Nothing like the Georgian/Victorian stone high street in RivermereCenter.png. | **MAYBE — distant skyline block-out only**, e.g. far side of the market square before it is dressed |
| City Kit (Suburban) — Kenney | kenney.nl/assets/city-kit-suburban | **CC0 1.0** | glTF/FBX/OBJ | ~40 pieces | none | Cartoon suburban houses/garages — useful only as a **grey-box stand-in** while laying out Northfields street plots before real facades go in. | MAYBE — temporary block-out only, replace before ship |
| No free realistic shopfront mesh found | — | — | — | — | — | Same gap as §1: no CC0 site publishes PBR shopfront buildings. | **SKIP — build shopfronts procedurally**: plain box + door/window cut-outs, dressed with ambientCG brick/render + a Decal signboard, same approach as terraces |

**Verdict:** the high street (clock tower, bay windows, hanging shop signs, awnings in RivermereCenter.png) has to be procedural + ambientCG materials + hand-authored signage decals. Kenney's commercial kit is only good for a first-pass grey-box of the market square layout.

---

## 3. Brick / stone / render / slate / tarmac / paving PBR materials

All 1K/2K/4K/8K JPG+PNG, CC0. The kit already caches everything at 1K per `MANIFEST.md`'s
"SurfaceAppearance maps must be 1024×1024 or smaller" rule, so any of these work as-is.

### ambientCG (licence for every entry below: **Creative Commons CC0 1.0 Universal**, confirmed at docs.ambientcg.com/license)

| Material ID | Look | Resolutions | Style fit | Verdict |
|---|---|---|---|---|
| Bricks097 | red, weathered, sharp mortar lines | 1K–8K | Matches Westdale/Northfields red-brick terrace fronts | **USE** |
| Bricks060 | orange-red, uniform Flemish bond | 1K–8K | Good for newer Northfields estate brick | **USE** |
| Bricks089 | reclaimed/mixed red-brown | 1K–8K | Good for older Riverside/Town Centre buildings | **USE** |
| Bricks051 | honey/buff sandstone-brick blend | 1K–8K | Matches the sandy stone buildings in RivermereCenter.png clock-tower row | **USE** |
| PavingStones151 / 150 / 128 | grey rectangular interlocking pavers | 1K–8K | High-street pedestrian paving (RivermereCenter, RivermereRiverside) | **USE** |
| PavingStones070 | warm buff flagstone | 1K–8K | Market-square flagstone look | **USE** |
| Asphalt033 | clean dark tarmac | 1K–8K | Road surface, all districts | **USE** |
| Road012A / Road008A | worn/patched tarmac with lane paint residue | 1K–8K | Westdale Avenue and Industrial Estate access roads | **USE** |
| RoofingTiles013A / 014A | grey slate, overlapping | 1K–8K | Terrace roofs (visible in Westdale/Northfields skyline) | **USE** |
| RoofingTiles012A | red clay pantile | 1K–8K | Alternate roof for variety between houses | **USE** |
| Plaster001 / PaintedPlaster017 | smooth painted render, cream/white | 1K–8K | Render finish seen on some Town Centre shopfronts and Riverside Georgian buildings | **USE** |
| Concrete024 / Concrete019 | grey render, slightly textured | 1K–8K | Rougher pebbledash-style render alternative | **USE** |

Full ambientCG catalogue: 31 brick materials, 13 paving-stone, 14 asphalt/road, 22 roofing-tile, 35 plaster/concrete render results as of this search — the above are the closest visual matches, not the only options; browse `ambientcg.com/list?type=material&q=<term>` for more variants if a district needs extra colour variety.

### Poly Haven (licence: **CC0**, no obligations)

| Texture ID | Look | Max resolution | Style fit | Verdict |
|---|---|---|---|---|
| red_brick | red, rough, weathered, 16K source | 16384² (cache to 1K) | General red terrace brick, more weathered than ambientCG Bricks097 | **USE** |
| brown_brick_02 | sandy brown-yellow, coarse | 8192² | Cotswold-ish stone-brick blend for Town Centre | **USE** |
| worn_asphalt | gritty, cracked, leaf litter | 16384² | Back streets / car park | **USE** |
| red_slate_roof_tiles_01 | weathered red slate, moss | 8192² | Roof variant with moss for older Riverside buildings | **USE** |
| roof_slates_02 | grey slate, chipped edges | 8192² | Standard terrace roof | **USE** |
| square_brick_paving / brick_pavement | red interlocking brick paving | 8192² | Driveways, Northfields paths | **USE** |
| cobblestone_pavement | worn grey-brown cobbles | 16384² | Riverside promenade / market square texture variety | **USE** |
| painted_plaster_wall | discoloured painted exterior plaster | 16384² | Weathered render finish | **USE** |
| white_plaster_rough_01 | rough, even white render | 8192² | Cleaner render finish (newer Northfields builds) | **USE** |

All of the above are new picks beyond what's already cached in `assets/kit/` (the current kit's Poly Haven set is all small props, not architectural materials — see MANIFEST.md). None of the resolutions are a problem: every source ships at 1K minimum and the exporter pipeline already downsamples to 1K per the kit's Roblox SurfaceAppearance limit.

---

## 4. Street lamps

| Name | Source | Licence | Format | Tris | Texture | Style fit | Verdict |
|---|---|---|---|---|---|---|---|
| Street Lamp 01 — Poly Haven | polyhaven.com/a/street_lamp_01 | **CC0** | FBX/GLTF/Blend | 30,610 (decimate for mobile, kit rule is ≤20k/mesh) | 8192² source, cache 1K | Ornate black cast-iron lamppost — matches every reference image's black period-style lamp posts closely | **USE** (already flagged in ASSET_KIT.md substitutes list, not yet downloaded — add to kit) |
| Street Lamp 02 — Poly Haven | polyhaven.com/a/street_lamp_02 | **CC0** | FBX/GLTF/Blend | 20,338 | 8192² | Simpler black lamppost, good second variant for suburban streets | **USE** |
| Streetlight / Post Lantern — Kay Lousberg (via poly.pizza) | poly.pizza/u/Kay%20Lousberg | **CC0** (KayKit packs, itch.io) | GLTF/FBX/OBJ | low-poly | flat-shaded | Stylised, no PBR | MAYBE — background streets only |

**Verdict:** Poly Haven's street_lamp_01/02 are an excellent match and already free — just not downloaded into the kit yet. This is the strongest single win in this document.

---

## 5. Bus shelter

| Name | Source | Licence | Verdict |
|---|---|---|---|
| — | Poly Haven / ambientCG / Kenney | n/a | **Not available on any no-login CC0 source.** Poly.pizza has "Bus Stop" (Zsky) and "Bus stop sign" (dook), both individual community uploads on the Google-Poly-era archive — licence must be checked per model on the page (many are CC-BY 3.0, not CC0), and neither matches the black steel-and-glass Rivermere shelter in RivermereWestdale.png / RivermereStation.png. |
| **Recommendation** | — | — | **SKIP the search — build it from primitives**: 4 steel posts + glass panel (Decal or transparent part) + flat roof, matches CLAUDE.md §20 guidance to build simple street furniture procedurally rather than import risky meshes. |

---

## 6. Benches

| Name | Source | Licence | Format | Tris | Texture | Style fit | Verdict |
|---|---|---|---|---|---|---|---|
| Painted Wooden Bench — Poly Haven | polyhaven.com/a/painted_wooden_bench | **CC0** | FBX/GLTF/Blend | 630 | 4096² | Already in the kit (MANIFEST.md) — dark green slatted park bench, matches the benches in RivermereCenter/RivermereRiverside exactly | **USE (already owned)** |
| Modular Street Seating — Poly Haven | polyhaven.com/a/modular_street_seating | **CC0** | FBX/GLTF/Blend | 25,156 (decimate) | 4096² | Contemporary bolted-slat public seating, good for the modern Riverside Park benches | **USE** — new, not yet in kit |
| Wooden Picnic Table — Poly Haven | polyhaven.com/a/wooden_picnic_table | **CC0** | FBX/GLTF/Blend | 10,210 | 4096² | Riverside Park / community sports centre picnic tables | **USE** |
| Plastic Monobloc Chair 01 — Poly Haven | polyhaven.com/a/plastic_monobloc_chair_01 | **CC0** | FBX/GLTF/Blend | 3,356 | 4096² | Café outdoor seating for RivermereCenter's "The Daily Bean" street tables | **USE** |

---

## 7. Litter bins and wheelie bins

| Name | Source | Licence | Format | Tris | Texture | Style fit | Verdict |
|---|---|---|---|---|---|---|---|
| Metal Trash Can — Poly Haven | polyhaven.com/a/metal_trash_can | **CC0** | FBX/GLTF/Blend | 13,960 | 8192² | Already in the kit — round municipal litter bin, close to the "LITTER" branded bins in every reference image (those are black with gold text; this is unbranded metal, needs a re-colour/decal pass) | **USE (already owned)** |
| Trashcan / Trashcan Large — Quaternius (poly.pizza) | poly.pizza/u/Quaternius | **CC0** | GLTF/FBX/OBJ | low-poly | flat-shaded | Stylised bin shapes, no textures | MAYBE — background only |
| Wheelie bin | — | — | — | **Not found on any CC0 no-login source.** Not on Poly Haven, ambientCG (materials only), or Kenney. Quaternius/community poly.pizza results returned generic "Dumpster"/"Garbage Bin" shapes, not a UK two-wheel domestic bin. | **SKIP — build a wheelie bin from primitives** (a box + hinged lid + two cylinder wheels is a five-minute Studio part, not worth an import) |

---

## 8. Planters

| Name | Source | Licence | Format | Tris | Texture | Style fit | Verdict |
|---|---|---|---|---|---|---|---|
| Planter Box 01 — Poly Haven | polyhaven.com/a/planter_box_01 | **CC0** | FBX/GLTF/Blend | 8,094 | 8192² | Old wooden planter — matches the dark timber/stone planter boxes with flowers seen in every Rivermere street photo | **USE** |
| Planter Box 02 — Poly Haven | polyhaven.com/a/planter_box_02 | **CC0** | FBX/GLTF/Blend | 10,944 | 8192² | Worn wood variant | **USE** |
| Planter Box 03 — Poly Haven | polyhaven.com/a/planter_box_03 | **CC0** | FBX/GLTF/Blend | 13,112 | 8192² | Farm/shed-style wood crate planter, third variant for street-to-street variety | **USE** |
| Potted Plant 01 / 02 — Poly Haven | polyhaven.com/a/potted_plant_01, potted_plant_02 | **CC0** | FBX/GLTF/Blend | not published (small props) | varies | Fills the hanging-basket/flower-box colour the reference images lean on heavily — pair with the planter boxes above, not a replacement for the hanging baskets themselves (no CC0 hanging-basket mesh found anywhere) | **USE** |

---

## 9. Railings / fences

| Name | Source | Licence | Format | Tris | Texture | Style fit | Verdict |
|---|---|---|---|---|---|---|---|
| Modular Chainlink Fence — Poly Haven | polyhaven.com/a/modular_chainlink_fence | **CC0** | FBX/GLTF/Blend | 89,232 (decimate hard — well over kit's 20k/mesh rule, split panels) | 8192² | Industrial Estate perimeter fencing (rivermer.industrialestate.png shows exactly this) | **USE for industrial estate only** |
| UK Street Props — wrought-iron railings/gates — Studio-Lab (already owned) | fab.com/listings/7b36c3ef-351e-44d6-bd54-16c59572fbe2 | Fab Standard License (already purchased, see MANIFEST.md) | FBX | not published | UKSP texture set | This is the correct black wrought-iron railing for Westdale/Northfields front gardens and the club's turnstile-entrance railings — already owned, no free equivalent needed | **Already covered — no gap** |
| Modular Electricity Poles / Electric Cables — Poly Haven | polyhaven.com/a/modular_electricity_poles | **CC0** | FBX/GLTF/Blend | 200,610 (decimate hard, split into single-pole pieces) | 8192² | Background utility poles for Industrial Estate and residential back streets | **USE**, needs heavy per-piece decimation given the huge tri count |
| Iron Fence — Kay Lousberg (poly.pizza) | poly.pizza | **CC0** | GLTF/FBX/OBJ | low-poly | flat-shaded | Stylised alternative if the Poly Haven mesh proves too heavy after decimation | MAYBE — fallback only |

**Verdict:** the low garden brick walls + black iron railings that dominate Westdale/Northfields fronts (RiveremereWestdale.png, RivermereNorthfields.png) are already solved by the owned UK Street Props pack. The only genuine free gap is chain-link for the Industrial Estate, which Poly Haven covers.

---

## 10. Trees and hedges (mobile budget: aim under 5k tris)

| Name | Source | Licence | Format | Tris | Style fit | Verdict |
|---|---|---|---|---|---|---|
| Oak Pack 6 / Oak Tree — Letaij (Creator Store, already owned) | Roblox id 98950444096614 | Creator Store terms | rbxm | not published | Already in kit; MANIFEST flags the creator re-uploads Sketchfab models — provenance unverified, treat as placeholder | Already owned, flagged risky |
| HedgeLong / HedgeBright — Creator Store (already owned) | Roblox ids 14355085874 / 13364734150 | Creator Store terms | rbxm | not published | Already in kit for front-garden hedges seen in every reference street | Already owned |
| Fir Tree 01 / Pine Tree 01 — Poly Haven | polyhaven.com/a/fir_tree_01, pine_tree_01 | **CC0** | FBX/GLTF/Blend | not published (typically 10k+ with leaf cards, needs decimation) | Wrong species — conifers, not the deciduous street trees (lime/plane-type) lining Rivermere's roads in every image | SKIP for street trees; MAYBE for a pine-forest backdrop hill |
| Island Tree 01–03, Jacaranda — Poly Haven | polyhaven.com | **CC0** | FBX/GLTF/Blend | varies | Tropical/subtropical canopy shapes, don't match an English street tree silhouette | SKIP |
| Hedge — Quaternius (poly.pizza) | poly.pizza | **CC0** | GLTF/FBX/OBJ | low-poly, likely <1k tris | Flat-shaded stylised hedge block; usable as a cheap LOD/background hedge where the owned HedgeLong/HedgeBright Creator Store meshes are too expensive to place at scale (e.g. hundreds of Northfields front gardens) | **MAYBE — good candidate for a low-tri LOD variant, worth testing** |
| Textured LowPoly Trees (45 models) — Quaternius | quaternius.itch.io/textured-lowpoly-trees | **CC0** | FBX/OBJ/Blend | low-poly | 18 textures, actual leaf-colour variation unlike flat-shaded Kenney trees; still stylised, not photoreal, but closer to usable at mid-distance than pure vertex-colour packs | **MAYBE — best stylised tree fallback if the Letaij oak pack gets dropped for provenance reasons** |

**Verdict:** Poly Haven has no suitable English deciduous street tree at all (its `trees` category is 20 models, all conifers/tropical/desert). The existing Creator Store oak + hedge selection remains the only close visual match; the two Quaternius packs above are the best fallback if those get dropped over the unverified-provenance note in MANIFEST.md.

---

## 11. Cars / vans

| Name | Source | Licence | Format | Tris | Style fit | Verdict |
|---|---|---|---|---|---|---|
| Car Kit — Kenney | kenney.nl/assets/car-kit | **CC0** | FBX/OBJ/GLTF | low-poly, 8 separate wheel meshes | Flat-shaded cartoon sedan/van/ambulance/race car — RivermereCenter/Westdale/Station all show realistic modern hatchbacks and estate cars with number plates and paint reflections; total style mismatch | **MAYBE — background/parked traffic only, at a distance where the mismatch is less visible** |
| Cars Bundle (Taxi, Cop, SUV, 2 Sports, 2 Normal) — Quaternius | poly.pizza/bundle/Cars-Bundle-FE5IWe6OMk | **CC0** | FBX/OBJ/GLTF | low-poly | Same stylised look, slightly more rounded/toy-like than Kenney's boxier set | MAYBE — background only |
| No free realistic UK hatchback/estate/van mesh found | — | — | — | — | Every realistic-PBR car pack found requires purchase (this matches ASSET_KIT.md's own conclusion: "no British vehicle pack at kit quality anywhere checked") | **SKIP for foreground use** — the already-owned Creator Store VanWhite/HatchbackWhite/HatchbackOrange (see MANIFEST.md) remain the only foreground-quality option, with the same unverified-provenance caveat as the oak pack |

---

## 12. Railway pieces (track, platform, station canopy)

| Name | Source | Licence | Format | Tris | Style fit | Verdict |
|---|---|---|---|---|---|---|
| Train Kit — Kenney | kenney.nl/assets/train-kit | **CC0** | FBX/OBJ/GLTF (confirm per download) | ~50 train models + straight/curve track, low-poly | Flat-shaded cartoon trains and rail, no platform or canopy pieces found in the pack (only trains + track, confirmed by checking the pack page) | **MAYBE — track only, background/toy-scale, and only if a stylised train reads OK moving past in the far distance** |
| Station building, platform canopy, footbridge | — | — | — | — | **Not available on any CC0 no-login source.** RivermereStation.png's brick station building with a glass-roofed platform canopy and steel footbridge is a bespoke look; UK Street Props (already owned) has a steel footbridge + stairs that covers part of this need. | **SKIP the search for station building/canopy — build procedurally + reuse the owned UK Street Props footbridge** |

---

## 13. Industrial sheds, shipping containers, pallets, forklifts

| Name | Source | Licence | Format | Tris | Style fit | Verdict |
|---|---|---|---|---|---|---|
| City Kit (Industrial) — Kenney | kenney.nl/assets/city-kit-industrial | **CC0** | glTF/FBX/OBJ | ~40 pieces, low-poly | Flat-shaded cartoon industrial units — rivermer.industrialestate.png shows realistic corrugated steel-clad sheds with roller shutters and branded signage | MAYBE — background block-out only |
| Factory Kit — Kenney | kenney.nl/assets/factory-kit | **CC0** | glTF/FBX/OBJ | ~140 pieces, low-poly | Larger prop set (pipes, crates, conveyor-style pieces); same style caveat | MAYBE — background/interior filler only |
| Pallet / Pallet Broken — Quaternius (poly.pizza) | poly.pizza | **CC0** | GLTF/FBX/OBJ | low-poly | Simple enough shape that the flat-shading is barely noticeable at ground clutter scale | **USE — good enough even close-up as clutter, unlike buildings/vehicles** |
| Forklift — KolosStudios (poly.pizza) | poly.pizza | Check per-model licence on page (KolosStudios is an individual contributor, not confirmed CC0 — verify before use) | GLTF/FBX/OBJ | low-poly | Matches the yellow forklift in rivermer.industrialestate.png reasonably well in silhouette | **MAYBE — verify licence text on the model page before importing** |
| Rollershutter Door / Window 01-03 — Poly Haven | polyhaven.com/a/rollershutter_door | **CC0** | FBX/GLTF/Blend | not published | Realistic PBR roller shutters — exact match for the industrial estate unit doors | **USE** — already flagged as a possible add in ASSET_KIT.md substitutes list |
| Modular Factory Facade — Poly Haven | polyhaven.com/a/modular_factory_facade | **CC0** | FBX/GLTF/Blend | not published | Realistic PBR industrial facade pieces — better style fit than any Kenney kit for foreground industrial units | **USE — best find in this category** |

---

## 14. Market stalls and bunting

| Name | Source | Licence | Format | Tris | Style fit | Verdict |
|---|---|---|---|---|---|---|
| Market Stand / Market Stalls / Market Stalls Compact — Quaternius (poly.pizza) | poly.pizza | **CC0** | GLTF/FBX/OBJ | low-poly | Simple tent/awning shapes with flat colour panels — bunting and awning colours can be reskinned via Roblox materials, so the stylisation matters less here than on buildings | **USE — reasonable stand-in, re-texture the awning panels to match kit palette** |
| Bunting (string of triangular flags) | — | — | — | Not found as a standalone mesh anywhere searched | **SKIP the search — build in Roblox**: a MeshPart or even a textured Beam/particle strip of triangle flags is trivial to author directly and avoids importing anything for such a simple shape | **Build in-engine** |

---

## 15. Church / spire

| Name | Source | Licence | Verdict |
|---|---|---|---|
| — | Sketchfab has several ("Small simple low poly chapel" by MrZeuglodon, "Low Poly Church" by Yanez Designs) | Sketchfab requires a free account to download and licences are mixed CC-BY/CC-BY-SA/Standard, not CC0 | **SKIP — violates the no-login rule**, and Poly Haven/ambientCG/Kenney/Quaternius have no church model at all |
| **Recommendation** | — | — | The church spire is a skyline landmark (CLAUDE.md §27), not something the player walks into — build a simple procedural tower + spire in Roblox using the ambientCG stone materials from §3, same approach as the terraces |

---

## 16. River pieces (boats, pontoons)

| Name | Source | Licence | Verdict |
|---|---|---|---|
| — | Poly Haven's `ships` category exists but only contains 4 models: `dutch_ship_large_01`, `dutch_ship_large_02`, `dutch_ship_medium`, `ship_pinnace` (all CC0, all part of the "smugglers_cove" collection) | **CC0** | These are 17th-century galleons with full rigging and sails — nothing like the small leisure cabin cruisers and yachts moored in RivermereRiverside.png. **SKIP for realism**, wrong era entirely |
| Modular Wooden Pier — Poly Haven | polyhaven.com/a/modular_wooden_pier | **CC0** | FBX/GLTF/Blend, structures category, part of smugglers_cove collection | Generic wooden pier/pontoon planking — usable for the riverside jetty even though the collection theme is piratical, the geometry itself is just planks and posts | **USE — for pontoons/jetty only, not boats** |
| Small leisure boats/cabin cruisers | — | — | **Not found free anywhere with a no-login CC0 licence.** | **SKIP — build simple hull shapes procedurally**, or leave river boats as a later paid purchase if the riverside district needs them to look convincing up close |

### Creator Store boat search (2026-09-20)

Marcel wants the primitive `RiverDresser.buildBoat` boats replaced. Nothing boat-like is in the user inventory. Free candidates were loaded with `game:GetObjects` and measured, then destroyed; paid ones were judged from thumbnails only.

| Name | Asset id | Price | Measured / seen | Verdict |
|---|---|---|---|---|
| Low Poly Boats Pack — FreeflowStore | 109063229458367 | $2.99 | Thumbnail: white cabin cruiser, fishing trawler, rowboat, orange RIB, canoe, small motor boat; clean low poly | **BUY — best match for the cruisers in RivermereRiverside.png** |
| Low Poly Boat Dock Pack x40 — Lukami_th | 100886767972531 | $2.99 | 40 MeshParts, one palette texture, no scripts: sloop, sailing dinghy, cabin fishing boat, rowboat, tug, plus dock segments, buoys, life ring post | **BUY — sailboats + marina props; skip the pirate pieces** |
| Boat & Ship Pack — ThePaparazziGamer | 70480610338573 | $2.99 | 6 static boats: sailboat, cabin cruiser, speedboat, tug, raft, galleon | MAYBE — only if the two above fall short |
| Realistic Boat Props — NyrexBLX | 70910961574456 | $4.99 | 20+ realistic yachts, catamarans, Zodiacs | SKIP — realistic style clashes with the kit, likely heavy |
| Boat Kit — OrcaCreations | 128770210037289 | $7.99 | Futuristic yacht, speedboat, jet ski, with scripts | SKIP — wrong look |
| Sailboat Mesh — EthanTheBigGuy22 | 13217041580 | free | **1 MeshPart**, no scripts, 10 x 50 x 35 studs, modern sloop with furled sails | **USE — free sailing yacht, scale to ~0.5** |
| Sodor Canal Boats | 3068964802 | free | 45 parts, 13 unions, no scripts, 85 studs long (several boats) | MAYBE — proper British narrowboat look, but parts/unions not meshes |
| Narrow boat — Powering_Manipulatn | 9451707268 | free | 117 parts, 4 unions, no scripts, 8 x 9 x 49 | SKIP — too many parts per boat, has an interior |
| X-Scow Sailboat | 9818814242 | free | 111 parts, 1 mesh | SKIP — part count |
| Bayliner — Spitter1212 | 15355071615 | free | 1,454 parts, 1 script | SKIP |

### Free-only deep sweep (2026-09-20, later)

Marcel: no more paid assets, no primitives, realistic river boats. Swept 37 keywords through the Creator Store toolbox API (1,726 models, 1,707 free), filtered on the store's own technical details (MeshParts, triangles, scripts), checked thumbnails on contact sheets, then measured the survivors with `game:GetObjects`. The paid rows above are dead.

| Role on the river | Name | Asset id | Measured | Verdict |
|---|---|---|---|---|
| Sailing yacht | Sailboat Mesh | 13217041580 | 1 mesh, 2,532 tris, no scripts, 10 x 50 x 35 | **USE** |
| Classic wooden launch | Riva Aquarama Classic Yacht | 15676599201 | 2 meshes, 3,984 tris, textured, 43 x 11 x 13 | **USE** (rename, drop the brand) |
| Cabin cruiser | yacht (fajnygosciu1234) | 4959431139 | 1 mesh, 332 tris, textured, huge (scale ~0.25) | **USE** — low poly, only clean free cruiser found |
| Rowing boat | Victorian Row Boat | 116487004496295 | 1 mesh, 7,046 tris, textured, 8 x 7 x 22 | **USE** |
| Rowing boat with oars | Sketchfab boat | 12997707753 | 1 mesh, 4,743 tris, textured | MAYBE — name says Sketchfab, licence unknown |
| Kayak | surf rescue X2 kayak | 14477799492 | 2 meshes, 4,244 tris, textured | **USE** — riverside park / pontoon dressing |
| Open day boat | LightBleuBoat | 6954360328 | 1 mesh, 1,054 tris, textured, 14 x 12 x 55 | **USE** — scale down |
| Inflatable | Inflatable Boat | 18948715302 | 3 meshes, 4,986 tris, tiny (scale up) | MAYBE |
| Sailing dinghy | optimist dinghy | 110556433742403 | 10 meshes, 4,372 tris, untextured grey | MAYBE — needs colouring |
| Narrowboat | Canal boat (TiagoMay14) | 10637705416 | right look, but 230 parts + 2 scripts | SKIP — mostly primitives |
| Small trawler | Fishing Boat | 14398379816 | 369 parts | SKIP |
| Cabin cruiser / yacht / speedboat | L4D2 Speedboat 8713310648, L4D "One 4 All" Sailboat 8713461501, Fishing Boat 1614127059 | — | good-looking single meshes | **SKIP — ripped from Valve games, not safe to ship** |

**Installed 2026-09-20:** the six USE rows live in `ServerStorage.Kit.Boats` as `BoatSailYacht`, `BoatLaunch`, `BoatCruiser`, `BoatRowing`, `BoatDayBoat`, `BoatKayak` (pivot on the waterline, bow to -Z, `SourceAssetId` attribute). Rebuild them with `tools/kit/install_boats.luau` in Edit mode. `RiverDresser.buildBoat` clones them for the river moorings and the marina; `ClientKit` publishes `BoatCruiser` for `Cruiser.client`. The primitive boats are gone. A kayak sits on each river mooring pontoon. Sizes (2026-09-20, felt out against a standard R15 character, which is 5.2 tall but 4 wide, so true 2.75 studs/m boats looked like toys): yacht 38 long, cruiser 40 x 14.6 (river moorings only, too wide for a marina berth), launch 32, day boat 27, rowing boat 16, kayak about 16.

Gap: no free mesh narrowboat exists. Options: Studio `generate_mesh` (free, allowed for props by CLAUDE.md s27), or leave narrowboats out.

---

## 17. Playground

| Name | Source | Licence | Verdict |
|---|---|---|---|
| Swing set / Slide / Jungle gym / Seesaw — "Poly by Google" (poly.pizza) | poly.pizza | **Mostly CC-BY 3.0, not CC0** — Poly by Google's archived catalogue on poly.pizza is ~69% CC-BY (attribution required); each model's licence must be checked individually on its page | MAYBE only if a specific model's page confirms CC0; do not bulk-assume |
| — | Kenney has no dedicated playground kit (confirmed: searched kenney.nl directly, no such pack exists) | — | Gap confirmed, not a miss |
| **Recommendation** | — | — | Northfields' playground (visible in RivermereNorthfields.png: slide, climbing frame, swings) is low priority per CLAUDE.md ("not all spaces need mechanics in MVP") — **build simple primitive playground equipment in Roblox** rather than chase CC-BY attribution requirements for a background detail |

---

## 18. Wind turbines (distant backdrop)

| Name | Source | Licence | Verdict |
|---|---|---|---|
| — | Not on Poly Haven, ambientCG (materials only), Kenney, or Quaternius/poly.pizza in any useful form | — | Sketchfab has several, all requiring login and mostly CC-BY/CC-BY-SA. **No free no-login CC0 wind turbine exists.** |
| **Recommendation** | — | — | It's explicitly a **distant backdrop** silhouette — three or four thin cylinders + rotating blade cross on a hill horizon is a two-part procedural Roblox build, cheaper than importing and licensing a mesh for something the player never approaches |

---

## 19. Bicycle (the town cyclists)

| Asset | Source | Licence | Notes | Verdict |
|---|---|---|---|---|
| "Bicycle bike cycle" by Wish Game, asset `91358100215341` | Roblox Creator Store, free | Creator Store standard | Low-poly mountain bike: 3 MeshParts (`Metal`, `Body` = frame, `Black` = tyres / saddle / grips), no scripts, no textures, so the frame takes any colour. `15022611108` is the same mesh in orange. | **USED** (2026-09-20): `tools/kit/install_bicycle.luau` installs it as `ServerStorage.Kit.Vehicles.Bicycle` (4.8 studs long, front to -Z, pivot on the ground); `ClientKit` publishes it and `Traffic.client` seats a pedalling rider on it. |

Looked at and passed over: `5075243985` Japanese-style bike (176 parts), `10416886834` BMX (22 scripts),
`3368927099` animated bicycle (15 parts, a script), `15989546761` (two bikes in one mesh).

---

## Summary: top USE items (concrete, licence-verified, add to the kit)

1. `street_lamp_01` — Poly Haven, CC0, ornate cast-iron lamppost, 30.6k tris (decimate)
2. `street_lamp_02` — Poly Haven, CC0, simpler lamppost, 20.3k tris
3. `modular_street_seating` — Poly Haven, CC0, contemporary public bench, 25.2k tris (decimate)
4. `wooden_picnic_table` — Poly Haven, CC0, Riverside Park seating, 10.2k tris
5. `plastic_monobloc_chair_01` — Poly Haven, CC0, café outdoor chair, 3.4k tris
6. `planter_box_01` / `_02` / `_03` — Poly Haven, CC0, wooden street planters, 8.1k/10.9k/13.1k tris
7. `rollershutter_door` + `rollershutter_window_01-03` — Poly Haven, CC0, industrial estate unit doors
8. `modular_factory_facade` — Poly Haven, CC0, realistic industrial facade pieces
9. ambientCG `Bricks097`, `Bricks051`, `PavingStones151`, `Asphalt033`, `RoofingTiles013A`, `Plaster001` — CC0 materials, 1K–8K, for procedural terrace/shopfront/church facades and street surfaces
10. `modular_wooden_pier` — Poly Haven, CC0, riverside jetty/pontoon planking

---

## Paid candidates to put on Marcel's buy list

None. Every free item above that scored USE is a strong enough match that no paid purchase is
needed to fill these specific gaps right now. The known paid gaps (realistic red-brick Victorian
terraces, a realistic UK car pack, a bespoke station/church/bus-shelter/playground) are all either
already covered by owned Fab packs (see `docs/ASSET_KIT.md`) or better solved by building simple
shapes procedurally in Roblox per CLAUDE.md §20 ("do not make custom 3D modeling the blocker") —
none of them cleared the bar of "obviously better paid match" worth spending part of the
$500 budget on today.
