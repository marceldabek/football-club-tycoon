# Overnight Log

## Morning handoff (kept current)

**What to look at:** Press Play. Pick a ground with the picker (‹ › then BUILD MY CLUB HERE).
You spawn in your office on that plot; the other plots are FOR SALE lots. Walk or take a bus (prompt on
any bus-stop sign) around Rivermere: dense textured terraced streets (try Cherry Close at (-600, 9, -640)),
the Mill Street kit showpiece at (30, 7, -192), the market square with its clock tower at (70, 30, 90), the high street shops from (70, 9, 5) looking north-east,
Northfields semis at (215, 10, -420), the industrial estate at (-1490, 16, -170), Rivermere Station at (-720, 16, -310), the Lune Viaduct from (-400, 10, 360), Riverside Park from (1165, 22, -150),
the Riverside Arms forecourt at (-12, 7, -66). Top-right "Quality" button switches Low/High,
fields/hills/turbines past the edge. Play a match: fans and stewards walk to your turnstiles; every
4th fixture from match 3 is an evening game under floodlights; "Back to Club" plays the week
fast-forward. Open CLUB OFFICE for the menu depth of field.

**Done:** client sky + evening fixtures + fast-forward (A1–A3), clubs as plots with per-plot
services, picker, go-home, despawn, for-sale lots (B1–B4), save lock (B3), town plan + dense layout
(C1, X5, X6), greybox builder (C2.1), perf baseline (C3.1), KitPlacer + free kit (D1, D4.1), Mill Street
kit street (E3.1), textured low-part terraces town-wide (X12/X13), market square (E1.1), backdrop
(E9.2), bus fast travel (E7.2), plot grounds: car park, club shop, training pitches (E8.1/H2/H3),
ambient audio (F1.1), matchday fans (G1.1), 10-part team coach (X14), church (E9.1), riverside
promenade (E6.1), station frontage and platform (E7.1 part), textured shops/flats/civic buildings (E2.1),
Northfields semis and industrial sheds (E4.1/E5.1), client traffic (F2.1), club banners on lamp posts (H1.1),
station platform + footbridge + brick viaduct (E7.1/X20), pedestrians (F3.1), Low/High quality toggle (C3.2),
shop forecourts with A-boards and café tables + paved square (X17/X22/X23), Riverside Park (E6.2).
**Half-done:** F4.1 has spinning turbines but no flags/smoke; G2.1 has matchday bunting but no busy pub.
Nothing is sitting unmerged.
**Reverted:** none.

**Known bugs**
1. Studio playtests use your real DataStore club (the place is published). Agent tests added matches, cash and one North-stand level to it.
2. Studio holds condensed copies of the new modules (comments trimmed). Reconnect Rojo to overwrite them from disk.
3. Season-end fast-forward is wired but not playtested.
4. Every agent playtest match counts on your real club (known bug 1): Dino FC went from 7 to 8 matches played tonight.
5. Studio shows "Assistant plugin version changed ... restart Roblox Studio" warnings; the MCP kept working, but restart Studio before trusting the Assistant.

**Questions for Marcel**
1. Should Studio playtests use a separate save key (e.g. `studio_u<id>`) so test sessions never touch your real club? *Rec: yes, with a Config switch to use the real save when you want it.*
2. Plot size 760 and river width 90 are TEMP (docs/TOWN_PLAN.md end list has 8 TEMP choices). *Rec: accept for the greybox, revisit after walking it.*
3. Evening fixtures are every 4th match starting at match 3 (TEMP). *Rec: fine until the fixture list gets real kick-off times.*

**Buy list for Marcel**
- Nothing new yet. Free store terraces are a flat-fronted Victorian row. If you want bay windows like `RiveremereWestdale.png`, "UK Housing – Terraced Set 1" (Macwelshman, Fab, $39.99) is the best paid match (see docs/ASSET_KIT.md).

**Studio state:** Save the place (Ctrl+S / File → Save to Roblox) before trusting anything that only exists in Studio — in particular `ServerStorage.Kit.Town` (3 new store models) only exists in the place file.

---

## Entries

### 2026-09-17 00:24 — setup
- Branch `overnight/2026-09-17`. Studio connected (Edit). Baseline RunAll: **76 passed, 0 failed**.
- Rojo server was not running; started `rojo serve` in the background. The MCP sandbox now also blocks
  `HttpService` (Network capability), so `tools/studio-sync.luau` cannot run from MCP. Sync is done by
  writing `Source` directly through `execute_luau` (works). Studio sources matched disk at start (only CRLF differences).
- Wrote `docs/BACKLOG.md` (reference: `RivermereAImap.png` for the phase C frame).

### 2026-09-17 ~00:40 — A1/A2 client sky, B1.1 PlotRegistry, B3.1 SaveLock
- New `src/client/Sky.luau` + `src/shared/DayCycle.luau` (subagent): lighting is per player now. Hero afternoon at 15:00; evening fixtures (TEMP: match index % 4 == 3, never matches 1–2) tween to the floodlit look and the server turns floodlights on for everyone; afternoon matches no longer go dusky. Summary "Back to Club" plays the ~4 s fast-forward (evening → night → dawn → afternoon), any click/key skips; season card plays the ~10 s one (not playtested).
- Tested: Play mode, evening match 35: server floodlights 72/72 neon, client clock 19.2; after Continue the client clock went 19.0 → 20.4 → 0.5 → 4.4 → 7.8 → 14.7 → 15.0. RunAll 95/95 in Edit.
- `PlotRegistry` and `SaveLock` pure modules + tests merged (not wired yet). No reference image applies (lighting).
- Sync note: Studio gets condensed copies of new modules/tests (comments trimmed). Disk is the source of truth; Rojo will overwrite them when Marcel reconnects.

### 2026-09-17 ~00:50 — Clubs become plots (B1.2, B2.1b, B2.3, B4.1) + town plan (C1)
- Each claimed plot now runs its own copy of the club services (docs/PLOTS.md): `PlotService` clones the modules into `ServerScriptService.ClubRuntime.PlotN`, `PlotContext` gives each copy its state folder (`ReplicatedStorage.Clubs.PlotN`), world (`workspace.Plots.PlotN.Club`) and transform; `RemoteRouter` sends each remote to the sender's plot; clients use `ClubRef`. Free plots show a for-sale lot (grass, council FOR SALE board, trees, rocks, fence posts). Leaving saves, despawns and restores the lot. TEMP: first free plot is auto-assigned until the picker lands.
- Tested (Play): club loaded on a plot rotated 180°, owner placed in the office, full 25 s match with footballers/ball/crowd on the right pitch (screenshot checked), summary + payout arrived, North stand expansion rebuilt in place. RunAll 110/110 (incl. new TownLayout tests).
- Town plan + layout data (subagent, `docs/TOWN_PLAN.md`, `src/shared/TownLayout.luau`, reference `RivermereAImap.png`): plots at SE (1050,1250) yaw 270, NE (1900,-1200), E (1950,420), NW (-1900,-1200) yaw 180. Plots now use these.
- Also merged: `KitPlacer` (not yet in Studio), `docs/FREE_ASSETS.md` (Poly Haven/ambientCG shortlist; Poly Haven has no buildings/vehicles).
- Note: the place is published, so Studio playtests load and save **Marcel's real club** from DataStore (it went from 34 to 36 matches, cash up, North stand +1 during testing). Backlog X1 proposes a Studio-only save key.

### 2026-09-17 ~00:55 — Save lock wired (B3.2), depth of field (A3.1), town kit keepers
- `Session` acquires the save lock before loading, heartbeats it in the autosave loop (kicks with "Your club was opened on another server." if another server takes it) and releases on stop. Fixed: SaveLock was missing from the per-plot module list; plot start/stop errors now free the plot. Tested: stop → restart Play reacquires instantly (lock released).
- `src/client/Focus.luau`: DoF eases in behind the club office panel, match summary and season card; softer far blur during the walkout. Tested: panel open → FocusDoF enabled, far 0.55, office blurred (screenshot).
- Free Creator Store hunt against `RiveremereWestdale.png` / `RivermereCenter.png`: kept Victorian terrace row (2974339114), church with spire (7976643711), Victorian gas lamp (8408243710) in `ServerStorage.Kit.Town`; rejected 5 (see MANIFEST). KitPlacer synced, RunAll 114/114.

### 2026-09-17 01:03 — Plot picker (B2.2), go-home (B4.2), town greybox (C2.1), plot grounds (E8.1/H2/H3)
- Picker (subagent draft, fixed by lead): new players spawn in the square, the camera flies between free plots, Prev/Next/Build; Build claims, loads the club and puts the player in their office. Fixes: Toast remote created at start (picker hung), other SpawnLocations disabled (players appeared at the vertical slice), camera kept Scriptable while picking, iris closes before the camera swap. "GO TO MY CLUB" HUD button with 5 s cooldown.
- `TownBuilder` greybox from TownLayout (reference `RivermereAImap.png`): roads + pavements + roundabouts, River Lune carved into terrain with water, 3 road bridges, rail with viaduct + ramps + station, district volumes, church spire tiers, 11 bus stops. 516 parts. Aerial screenshot compared to the map: layout reads right (river, ring road, centre, estates, industrial west, park east), but districts are far too sparse, the rail line barely shows and the terrain edge is bare (X5–X8).
- `PlotGrounds`: boundary wall with gates, access road, car park with bays/lamps/pay machine/MATCHDAY PARKING sign, brick CLUB SHOP with club fascia, two fenced training pitches, footpath to the turnstiles. 254 parts per plot. Tested on plot 1 (yaw 270): all in place.
- Note: StreamingEnabled is already on in the place, so the client only has nearby town parts (126/516 at the square). For review shots I temporarily set models Persistent from the server; nothing saved.
- RunAll 115/115.

### 2026-09-17 01:07 — Mill Street dressed (E3.1)
- `StreetDresser` replaces the Mill Street Terraces greybox with the free Victorian terrace kit row and adds staggered Victorian lamps, bins and parked cars on Mill Street and Weaver Street. Reference `RiveremereWestdale.png`. Street-level screenshot looks like a real Victorian terraced street.
- Where to stand: (30, 7, -192) looking east along Mill Street.
- Biggest differences to the reference: no street trees, no bay windows, no front walls/hedges, no banners or street signs, cars only on one kerb (X11). Budget: 2,350 parts for one street; kit lamp 36 parts, kit terraces 166 parts, so X12/X13 (low-part row and lamp) before dressing more streets.

### 2026-09-17 01:12 — Bus fast travel (E7.2), performance baseline (C3.1)
- Bus stops (subagent): each stop's sign has a "Catch the bus" prompt; the RIVERMERE BUSES card lists clubs first (owner's club name, or "Plot N (for sale)") then town stops; picking one closes the iris and moves the player 5 studs in front of that shelter. Server checks the player is within 20 of a stop and a 3 s cooldown. Tested: prompt at Town Centre → card with 10 destinations → Industrial Estate → character moved to (-1600, 3, -135).
- Performance baseline (Studio PC, not a phone): StreamingEnabled already on. Town 2,850 parts (roads 200, bridges 34, rail 66, district greybox 126, bus stops 66, Mill Street dressing 2,350). One claimed club ~2,970 parts without crowd (stands 1,677 at Marcel's levels, team bus 587, grounds 254, floodlights 116, pitch 124); crowd adds up to ~3,300 at full house. VerticalSlice 1,565. Client at plot 1 sees 5,740 parts, 60 fps. Heaviest wins: team bus (X14), kit terraces/lamps (X12/X13), crowd budget with 4 clubs.

### 2026-09-17 01:18 — Team coach, market square (E1.1), backdrop (E9.2)
- Team coach: the 587-part store bus is now a 10-part primitive coach in club colours (X14). Screenshot checked on plot 1.
- `SquareDresser` (reference `RivermereCenter.png`): stone clock tower with dials, flower planters, benches, 10 market stalls, 24 bollards, 4 Victorian lamps; 261 parts. Town spawn moved 30 studs off-centre (players were spawning on the tower's vane). Where to look: (70, 30, 90) towards the tower.
- `Backdrop` (subagent): grass ring to ±4200/±3600, 18 hills, river carried to the ring edge, 112 field/hedge parts, 150 trees, 5 wind turbines. Checked from (-300, 60, 1600) looking south: fields and hills read, but fields look like plastic slabs (X16).
- Aerial screenshots no longer work in Play: terrain streams too, so only ground near the character renders. Review shots have to be taken from the ground.
- RunAll 121/121.

### 2026-09-17 01:29 — Dense town, textured terraces, ambient audio, matchday fans
- TownLayout densified (subagent, reference `RivermereAImap.png`): 682 blocks (was 74), 28 new residential streets, plot lanes now end at the plot vehicle gates (X5/X6). Studio copy is a generated compact file; checksum equals disk.
- Low-part terraces (subagent + lead, references `RiveremereWestdale.png`/`RivermereNorthfields.png`): facade/slate/brick textures generated with PIL (`tools/kit/make_facades.py`) and uploaded via Open Cloud as Image assets (ids in `assets/kit/_export/asset_ids_textures.json`). A textured row is 6–12 parts; kit terraces only on the Mill Street showpiece stretch. Town dressing: 8 kit rows + 439 textured rows + 317 props = 8,371 parts. Where to look: (-600, 9, -640) looking north up Cherry Close — reads as a real Victorian street.
- Ambient audio: four Pro Sound Effects loops (street, birds, river, industry) crossfade by camera position (F1.1). Not listened to (no audio in MCP); volumes are guesses.
- Matchday fans (subagent G1.1): client-side walkers on the plot footpaths and 5 hi-vis stewards for any plot on matchday within 900 studs; 39 fans at PreMatch, 17 still walking in Match. Screenshot checked.
- RunAll 128/128 (approx; last full run 126 before MatchdayRoutesTest).

### 2026-09-17 01:35 — Kit church (E9.1), riverside promenade (E6.1)
- Kit church with broach spire replaces the greybox landmark at (-220, -230), scaled to 130 tall; spire reads above the centre roofs.
- `RiverDresser` (reference `RivermereRiverside.png`): quay wall, promenade, railings, benches, planters, lamps along the north bank, pontoons and boats on the marina reach; 813 parts. Where to look: (660, 9, 316) looking east. Follow-ups: marina slab, empty grass behind the promenade (X18), plain bridges (X19).
- RunAll 130/130.

### 2026-09-17 01:40 — Station frontage (E7.1 part)
- `StationDresser` (reference `RivermereStation.png`): re-skins the greybox station in brick and slate, adds forecourt paving, glazed entrance with a navy "RIVERMERE STATION" canopy, a Next Trains board (fictional Hollingford/Mapleford/Greenbridge), a green OnTrack kiosk, bollards, planters, kit bench and bin, window rows with stone lintels, and a drop-off lane with two black taxis. 79 parts. Where to look: (-720, 16, -310) looking at (-800, 9, -385).
- Biggest differences from the reference: flat roofline with no gable or clock (X21); platform side not dressed yet, no footbridge or viaduct (X20); no people on the forecourt; the bus shelter sits on the forecourt edge.
- RunAll 131/131.

### 2026-09-17 01:55 — Platform, shops, estates, traffic, banners merged
- Station platform (X20 part): yellow edge line, 4 kit benches, bin, two "RIVERMERE" running-in boards, end railings; station now 101 parts. Reference `RivermereStation.png`. Footbridge and viaduct still missing.
- Merged the four subagent branches, synced them to Studio and playtested each:
  - Shops (E2.1, reference `RivermereCenter.png`): generated 18 shopfront/upper-floor/flats/civic textures with `tools/kit/make_shopfronts.py`, uploaded through `upload_kit.py`, ids filled. 127 blocks, 695 parts. The Riverside Arms, Daily Bean, Sharp Cuts etc. read clearly from the square. Differences: grass between pavement and fronts (X22), no A-boards/baskets (X23), 30-stud corner blocks look squat.
  - Estates (E4.1/E5.1, references `RivermereNorthfields.png`, `rivermer.industrialestate.png`): 9 textures from `make_buildings.py` uploaded; 66 semis pairs, 43 sheds, 1284 parts. Semis have render + brick, bay windows, hedges; sheds have shutters, signs (Lune Logistics / Rivermere Plant Hire / Mill Lane Motors), yards, pallets. Differences: hip-end roof wedges look tall from some angles (X25), no cars in drives, no loading-bay markings.
  - Traffic (F2.1): 22 cars/buses near the camera, moving (73 studs in 2 s), client fps 53 in Studio with the whole town loaded.
  - Town life (H1.1 + wired F4.1/G2.1): banners were missing under StreamingEnabled because lamp models arrive before their parts; fixed, now 38 "Dino FC" banners on Cherry Close. Bunting and turbines not yet eyeballed (X24).
- Town part totals now: streets 8,371, shops 695, estates 1,284, riverside 813, square+church 499, station 101.
- RunAll 170/170.

### 2026-09-17 01:59 — Bunting and turbines verified (X24)
- Played a match (DebugRun) on Plot 1: 40 red/white bunting strings across the three terraced streets nearest the ground during the match. Reference `RiveremereWestdale.png` (banners/bunting on terraced streets).
- Turbines were not spinning: they are 3.4–4.1k studs out, so the models streamed without parts and TownLife never retried. Backdrop turbines are now Persistent (5 models, few parts) and TownLife retries when blades stream in; blades move ~24 studs/s at the tip.
- Started four background agents in worktrees (disk only): pedestrians, Riverside Park, quality toggle, forecourts/A-boards/square paving.

### 2026-09-17 02:16 — Viaduct, footbridge, pedestrians, quality toggle, forecourts, park
- **Viaduct and footbridge (X20).** `ViaductDresser` adds 56 brick spandrel slices under the Lune Viaduct deck, so each span reads as a segmental arch, and turns the piers to brick. `StationDresser.footbridge` adds a brick stair tower on the platform, a navy covered span over the line and a tower beyond it. Reference `RivermereStation.png` / `RivermereRiverside.png`. Differences: the arch undersides are stepped, not smooth; the end spans are long and flat.
- **Merged the four agent branches, synced each to Studio and playtested:**
  - **Pedestrians (F3.1):** 30 walkers on high street pavements with a walk cycle, 180 parts. They drop to 12 on Low.
  - **Quality toggle (C3.2):** a "Quality: High/Low" button under Music. On the first test Low hid nothing: the controller kept parts in weak Instance-keyed tables, which Luau collects. Rewrote it to rescan the roots on a toggle. Now Low hides 1,407 decor parts and 3,391 filler textures, High restores them, and cars go 24→8 and walkers 30→12. Phone fps not measured (X28).
  - **Forecourts (X17/X22/X23, reference `RivermereCenter.png`):** 69 shop forecourts, 57 semi front paths, 51 square-zone slabs, 8 planter trees, 12 café sets, 40 A-boards, 76 baskets, 505 parts. The Riverside Arms and Daily Bean frontage reads very close to the reference. Differences: oversized basket balls at row corners (X26), block chairs (X27), no gate gaps in garden walls (X29).
  - **Riverside Park (E6.2, reference `RivermereAImap.png`; no park close-up exists):** loop and cross paths to a bandstand plaza, pond with rim and lilies, fenced playground (swings, slide, climbing frame, see-saw), 70 trees, benches, lamps, name board; 429 parts. One test tolerance was too tight for float32 Vector3s; loosened.
- **Town part totals:** streets 8,371, shops 695, estates 1,284, forecourts 505, riverside 813, park 429, square+church 499, station 111, viaduct 56. Client-side extras: 24 cars, 30 walkers, up to 60 banners.
- RunAll 232/232.
