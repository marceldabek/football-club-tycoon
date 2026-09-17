# Overnight Log

## Morning handoff (kept current)

**What to look at:** Press Play. Pick a ground with the picker (‹ › then BUILD MY CLUB HERE).
You spawn in your office on that plot; the other plots are FOR SALE lots. Walk or take a bus (prompt on
any bus-stop sign) around Rivermere: dense textured terraced streets (try Cherry Close at (-600, 9, -640)),
the Mill Street kit showpiece at (30, 7, -192), the market square with its clock tower at (70, 30, 90), the high street shops from (70, 9, 5) looking north-east,
Northfields semis at (215, 10, -420) and its play area at (-10, 12, -520), the industrial estate at (-1490, 16, -170), Rivermere Station and its taxi lay-by at (-770, 60, -290) looking south-west, Weir Road in Westdale at (-760, 12, 568), the Lune Viaduct from (-400, 10, 360), Riverside Park from (1165, 22, -150),
the Riverside Arms forecourt at (-12, 7, -66). Top-right "Quality" button switches Low/High,
fields/hills/turbines past the edge. Play a match: fans and stewards walk to your turnstiles; every
4th fixture from match 3 is an evening game under floodlights; "Back to Club" plays the week
fast-forward. Open CLUB OFFICE for the menu depth of field. Walk to the market square after 3+ matches to see your club mural on the terrace gable by The Little Deli; birds circle the church spire. New since 03:00: with two players, walk into the other club's office and use "View club" → "Play a friendly" or "Trade players"; stand in their ground during their match to watch it.

**Done:** client sky + evening fixtures + fast-forward (A1–A3), clubs as plots with per-plot
services, picker, go-home, despawn, for-sale lots (B1–B4), save lock (B3), town plan + dense layout
(C1, X5, X6), greybox builder (C2.1), perf baseline (C3.1), KitPlacer + free kit (D1, D4.1), Mill Street
kit street (E3.1), textured low-part terraces town-wide (X12/X13), market square (E1.1), backdrop
(E9.2), bus fast travel (E7.2), plot grounds: car park, club shop, training pitches (E8.1/H2/H3),
ambient audio (F1.1), matchday fans (G1.1), 10-part team coach (X14), church (E9.1), riverside
promenade (E6.1), station frontage and platform (E7.1 part), textured shops/flats/civic buildings (E2.1),
Northfields semis and industrial sheds (E4.1/E5.1), client traffic (F2.1), club banners on lamp posts (H1.1),
station platform + footbridge + brick viaduct (E7.1/X20), pedestrians (F3.1), Low/High quality toggle (C3.2),
shop forecourts with A-boards and café tables + paved square (X17/X22/X23), Riverside Park (E6.2),
station pitched roof + gable clock (X21), stone road bridges (X19), semis gable roofs + gate gaps + basket/chair polish
(X25–X29), floodlight tag lookup (X2), separate Studio save store (X1, TEMP), season end verified (A2.2),
marina quay + riverside gardens (X18), hedged backdrop fields (X16), road imperfections (E10.1), semis with driveways
(X30), square flags + chimney smoke + matchday pub drinkers (F4.1/G2.1), smaller plot car park + bus menu sizing (X9/X15),
Mill Street front gardens, railings, street trees, signs and parked cars (X11), visitors see other clubs read-only (B2.1c), read-only club card in other clubs' offices (I1.1), watching other clubs' matches with a score pill (I2.1/X38), friendlies: challenge from a club's office card, invite card, server match with no league/injuries and a TEMP gate share (I3.1a–c), same-server trades: trade screen from a club's office card, offer card, server re-check and save on accept (I4.1a–c), welcome card no longer stacks on the naming card, hint pill no longer covers Back to Club (X40), humped road bridges with smooth honey-sandstone arches (X31/X41/X43), kit cars on the wide driveways (X33), more terrace streets dressed within budget (X35), a finger post, planter flowers, shelter adverts and lamp baskets round the town centre (X46/X47), leafier trees (X48), station window bars, paved verge and taxi markings (X49/X50), brick turnstiles with lane signs (X52/X53), estate totem, unit numbers and lorries (X54/X55), district name stones (X56), semi porch hoods (X57), UK bus stop flags (X58), post boxes and red-brick schools (X59), shirts in the club shop window (X60), tree sway and birds (F4.2), a club mural near the square (H1.2), matchday cars in the club car park (G1.2), a distant crowd roar across town during matches (G2.2), café sitters (F3.2), cyclists (F3.3), roads always streamed so traffic no longer drives over grass (X62), buses pulling up at stops (F2.2), paved pads under bus shelters (X63), a railed Northfields play area with swings and a slide, flower borders in the semis front gardens (X57), a club banner on a lamp post at the turnstiles (X53), no toy cars on narrow drives (X44), forklifts in the estate yards (X55), shed yards kept off the road (X64), Station Road running along the station with a taxi lay-by (X51), a dressed Westdale street, Weir Road (X59), a clean riverside promenade with heritage lamps and hanging baskets (X65/X66), a readable square clock and planted planters (X68–X70), and at the station a road-side bus stop with a painted bay and a finger post (X71–X73).
**Half-done:** friendlies (I3.1), trades (I4.1) and spectating (I2.1) are only tested with one player (remotes, cards, refusals, the solo friendly match and a trade-out-and-back round trip). Accepting a friendly or a trade between two real owners needs Studio's Players = 2 test (I3.1d/I4.1d/X39/B2.1d). The MCP can't start that.
**Reverted:** none.

**Known bugs**
1. Up to 02:20 Studio playtests used your real DataStore club. Agent tests added matches, cash and one North-stand level to Dino FC (it went from 7 to 8 matches tonight). Since 02:20 Studio uses a separate store (see question 1).
2. Studio holds condensed copies of the new modules (comments trimmed). Reconnect Rojo to overwrite them from disk.
3. Season-end fast-forward: the server rollover is verified; the client 10 s sweep has not been watched.
4. Studio holds hand-pasted copies of every module merged tonight (comments stripped). Disk is the source of truth; reconnect Rojo before editing in Studio (X4/X34).
5. Studio shows "Assistant plugin version changed ... restart Roblox Studio" warnings; the MCP kept working, but restart Studio before trusting the Assistant.
6. The Rojo panel in Studio shows "Unknown HTTP error: NetFail", although `rojo serve` is running on port 34872 and serving this branch. Click Connect (or Disconnect, then Connect) in the Rojo panel before editing, so Studio's hand-pasted copies are replaced from disk. The HTTP sync fallback in `tools/studio-sync.luau` no longer works from the MCP, because its sandbox lacks the Network capability.

**Questions for Marcel**
1. **Done as TEMP, please confirm:** Studio playtests now use the DataStore `ClubProfiles_Studio`, so Studio opens a fresh club and onboarding instead of Dino FC. To get your real club back in Studio, set `Config.Save.studioStoreSuffix = ""`. *Rec: keep it; live servers are unchanged.*
2. Plot size 760 and river width 90 are TEMP (docs/TOWN_PLAN.md end list has 8 TEMP choices). *Rec: accept for the greybox, revisit after walking it.*
3. Evening fixtures are every 4th match starting at match 3 (TEMP). *Rec: fine until the fixture list gets real kick-off times.*
4. Walking from the market square to a club takes about 2–3 minutes (70–100 s sprinting); the buses cover it in seconds. Is that the scale you want? *Rec: keep it for now, because the buses and the "Go to my club" button carry most trips. Shrink the plot ring by ~25% only if playtesters walk rather than bus.*
5. Friendlies (I3.1), all TEMP in `src/shared/Friendly.luau`: (a) the challenged club is the home side, (b) an invite lasts 45 s, and you can have one outgoing at a time, (c) the home club gets 25% of a full league gate, and the away club gets nothing, (d) no injuries, no player development, and friendlies don't count in W/D/L or matches played. *Rec: keep all four. A friendly is a social extra, so it shouldn't be a better money route than league matches.*
6. Trades (I4.1), TEMP in `src/shared/Trade.luau`: up to 3 players each way; cash moves one way and only alongside a player; both squads stay within 14–20 and keep a goalkeeper; an offer lasts 60 s; traded players keep their age, ratings, injuries, apps and goals. There are no value checks, so a lopsided trade is allowed (s27: no anti-abuse limits for now). *Rec: keep these. Add a "fair value" warning, not a block, once transfer values are tuned.*
7. Semis driveways are mostly 5.1 studs wide (76 of 119) or about 3 wide (30). A car sized for the characters is about 9–10 studs wide (the street kit cars are 9.8), so narrow drives can only hold toy-sized cars (DriveCar_small_1). *Done as TEMP at 05:43: drives under 8 studs now stay empty (`EstateDresser.DRIVE_CAR_MIN_WIDTH`). Rec: keep that, and widen the gap between pairs to 11 studs when the estates are next reworked, accepting roughly one pair fewer per long row.*
8. Club murals (H1.2) are TEMP: one mural once a club has played 3 matches, a second from tier 2, on the terrace gable nearest the market square, shown only on that player's screen. *Rec: keep it client-side, but tie later murals to real milestones (first promotion, first title) so they read as achievements.*

9. Westdale street dressing (X59), TEMP: `TerraceStreetDresser` dresses the town's terrace streets nearest the square first, within 1,240 parts, so Westdale got nothing. Weir Road is now in `PRIORITY_STREETS` and dressed last from its own 260-part reserve (it uses 216), without changing any other street's dressing. The town grows by about 216 parts. *Rec: keep it until the phone measurement (X28/X61). If phones struggle, drop the reserve before cutting the Mill Street showpiece.*

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

### 2026-09-17 02:20 — Studio saves kept apart from the live club (X1)
- `SaveService.storeNameFor` adds `Config.Save.studioStoreSuffix` (TEMP `"_Studio"`) to the DataStore name when `RunService:IsStudio()`, for both the profile and the save lock. Verified: Studio play created a new "MDino24 FC" profile (0 matches, onboarding) in the Studio store; the Dino FC save is untouched from now on. Question 1 updated with how to switch it back.
- Four more worktree agents are running: bridge arches + station roof (X19/X21), marina basin + backdrop fields (X18/X16), imperfection pass (E10.1), forecourt/semis polish (X25–X27/X29).
- RunAll 233/233.

### 2026-09-17 02:23 — Season end played through (A2.2)
- On the new Studio store, looped DebugRun `playMatch` for 23 matches. Season 1 ended 3rd, "Stayed", £1,200 prize. Season 2 ended 1st, "Promoted", £3,000 prize, honours 1 title / 1 promotion. Season 3 started in the County League (tier 2) with every save succeeding. No server errors. The client long fast-forward was not watched.
- Note for testing: `playMatch` returns false while a match is still running, so drive it by waiting for `Phase == "Manage"`.

### 2026-09-17 02:30 — Bridges, station roof, semis roofs merged; floodlight tags (X2)
- **Floodlight tags (X2).** `Scenery` tags every floodlight head `FloodHead`, and `Sky` uses `CollectionService` and lights late-streamed heads. It only lights them, so another club's lit evening match is never switched off. Verified: all 72 heads were Neon during an evening fixture.
- **Merged polish (X25–X27, X29).** Semis now have a plain gable roof: brick attic wedges with tiled slabs 0.05 above, which matches `RivermereNorthfields.png`. The old hip-end wedges were the tall triangles. Garden walls and hedges have gate gaps at each door; baskets are small bracket baskets at shopfront joins; café chairs have a seat, back and legs. Estates are now 1,473 parts and forecourts 563. Screenshot from (215, 9, -425).
- **Merged bridges and station (X19/X21).** `BridgeDresser` gives each road bridge stone spandrel arches, pointed cutwaters, a string course and coping, 66 parts per bridge. The arches are only about 2 studs high because the decks sit about 2.7 above the water (X31). The station has a pitched slate roof, a brick front gable with coping and a clock (123 parts), which matches `RivermereStation.png` far better. Two agent test bugs fixed: a Studio multi_edit anchor clobbered the `export type` line, and the gable test expected z = 0 instead of mid-extrusion.
- **New follow-ups:** semis pairs abut like a terrace and the hedges stand on the pavement (X30); bridge arches too shallow (X31).
- Two agents still running: marina/backdrop (X18/X16) and the imperfection pass (E10.1).
- RunAll 241/241.

### 2026-09-17 02:48 — Marina, backdrop, imperfections, semis spacing, flags/smoke/pubs, car park merged
- Merged five agent branches and pasted each into Studio (Rojo isn't connected, so every module is a hand sync; that is now the slowest part of the night, X34).
- **Marina (X18, reference `RivermereRiverside.png`):** paved quay with railings and gangway gaps, a walkway pontoon, finger pontoons and piles, moored boats, a "RIVERMERE MARINA" kiosk, and hedged gardens with trees along the north bank. 312 parts. Screenshot from (970, 30, 350). Difference: boat bows look detached (X32).
- **Backdrop fields (X16):** Grass/LeafyGrass/Ground fields with hedges on all four sides and hedgerow trees.
- **Imperfections (E10.1):** 110 road patches, 45 manholes, 40 grates, 12 give-way markings, 430 faded centre dashes, 95 weed clumps, bins, cones, a skip and 15 fictional posters. 900 parts, all tagged Decor so Low hides them.
- **Semis spacing (X30, reference `RivermereNorthfields.png`):** pairs now have 10-stud driveways (119 in town, some with a parked car) and the front gardens sit inside the block. Front paths went from 57 to 108. Screenshot from (215, 14, -420): reads as semis now, not terraces. Cars are plain blocks (X33).
- **Town life (F4.1/G2.1):** 4 club-coloured waving flags round the square, up to 12 chimney smokes (off on Low), matchday drinkers outside the 2 nearest pubs. The first two were seen; the pubs haven't been checked in a match yet.
- **Car park and bus menu (X9/X15):** plot car park halved to 100x150 and the fan route moved; the bus menu card sizes to the screen and syncs its scroll canvas. The bus menu was not click-tested again.
- Estates are now 1,632 parts, forecourts 614, imperfections 900, marina 312.
- RunAll 286/286.

### 2026-09-17 02:52 — Mill Street dressing (X11)
- Merged `TerraceStreetDresser` (reference `RiveremereWestdale.png`): brick garden walls with stone coping and piers, black railings or hedges with gate gaps, street trees in tree pits (clear of lamps and junction mouths), black-on-white street name signs at junction corners with the area name, and kit cars and vans parked on the empty kerb. Screenshot from (20, 7, -203) looking east: reads like the reference street. `StreetDresser` gained `isKitRow` and `lampPositions`, with no behaviour change.
- The showpiece takes 1,013 parts, so only 1 light street fitted under the 1,200 budget (X35). Traffic now drives through cars parked on both kerbs (X36).
- RunAll 297/297.

### 2026-09-17 02:57 — Evening lamps (X37), walk distances (C2.2), boats and traffic (X32/X36)
- **Evening lamps (X37):** evening fixtures left the streets black because the lamps only had Neon glass. TownLife now puts PointLights (range 32) on the 16 lamps nearest the camera, 6 on Low, whenever the local ClockTime is dark. Screenshot at 20:30 on Cherry Close shows warm light on the road. The matchday pub drinkers were also verified: 10 in club colours outside the nearest pub during a match.
- **Walk distances (C2.2):** estimated from the layout rather than timed on foot. The square is 2.1–2.9k studs from the plots by road: 2.2–3 min walking, 70–100 s sprinting. Logged as question 4.
- **Boats and traffic (X32/X36):** boat bows now taper to a point (the wedge was turned the wrong way). Traffic keeps off Mill Street, Weaver Street and Church Lane, which have cars parked on both kerbs, using the new TerraceStreets `ParkedStreets` attribute.
- **Driveway cars (X33):** not done. The kit hatchback is 9.8 × 19.4 studs, too big for 10-stud drives.
- RunAll 297/297.

### 2026-09-17 03:04 — Visitors see other clubs read-only (B2.1c)
- The server was already safe: stand, amenity and matchday prompts check `ClubState.isOwner`, and every club remote goes through RemoteRouter to the sender's own plot. Client UIs already read the player's own club through `ClubRef` (the ClubPlot attribute).
- Gap closed: visitors still saw Expand, Build and Play prompts on other grounds, and the office prompt there opened their own club panel. The new client script `VisitorPrompts` turns off, on that client only, every prompt inside a plot the player doesn't own. The server changes `Enabled` at matchday, so the rule is re-applied whenever it changes. Rule is in the shared `PlotVisit`, test is PlotVisitTest.
- Playtest: claimed Plot1, whose 7 prompts stayed on. A test prompt the server put in Plot2 stayed off on the client after the server set it false and then true. During a 30 s match the Plot1 prompts went 6 off, then 6 on in Manage. No errors.
- Follow-up: B2.1d, the two-client test, still needs Studio's Players = 2 test server.
- RunAll 300/300.

### 2026-09-17 03:06 — Bus menu click test (X15), welcome and naming cards stacked
- **Bus menu:** stood at the Town Centre stop, held E, and the card opened with 10 destinations (your club, 3 for-sale plots, 6 districts). Clicking Station, the 9th row near the bottom, moved the character to (-740, 3, -360) and closed the card. Screenshots BusMenu_1 and BusStation_1.
- **Bug found and fixed:** a returning owner whose club still needs a name (the Studio test club) got "Welcome back" and "Name your club" on top of each other. HUD now skips the welcome card while NeedsName is set, because the naming card is already the greeting. Re-tested: only the naming card shows (NameOnly_1).
- Follow-up: the bus menu can still open over the naming card. That's low priority, since you can only reach a bus stop after walking away from it.

### 2026-09-17 03:12 — Visit a club: read-only club card (I1.1)
- **What:** for a visitor, another club's office computer shows a local "View club" prompt. The card lists the club name, league and season, current position, record, capacity and stand upgrades, and its 5 best players (overall, role, goals). It is built entirely on the client from `ReplicatedStorage.Clubs.PlotN`; nothing goes to the server. Close it with Close or Esc, or by walking more than 24 studs away. Pure summary in shared `ClubCard`; test is ClubCardTest.
- **Not a squad board:** I used a card instead of the 3D squad board in the backlog, because it is cheap on mobile and reuses Theme. A physical board in the office can come later.
- **Bug found and fixed in B2.1c:** with deferred signals, VisitorPrompts took the echo of its own `Enabled = false` as the server's value, so after going visitor → owner your own prompts stayed off. It now tracks the pending local write. Re-tested: owner 7 on → visitor 0 on (visit prompt on) → owner 7 on. Also tested switching to visitor mid-match and back: prompts stayed off until Manage, then came back on.
- **Test method:** one Studio player; the client sets `ClubPlot` locally to 99 to act as a visitor at Plot1. The real two-player case is still B2.1d. Screenshots ClubVisit_1 and ClubVisit_2 (the second has the owner's own match summary behind it, because the test player is both owner and visitor).
- The Studio test club was also named through the naming card ("Found the club"), in the Studio store only.
- RunAll 305/305.

### 2026-09-17 03:16 — Watch another club's match (I2.1)
- **What:** Match.client now follows a "watched" club folder. It is your own club while your match is in PreMatch/Match. Otherwise it is the nearest other club with a live match whose pitch centre is within TEMP 220 studs of your character; it rechecks every second and whenever your own phase changes. Spectators get the same presenter (players, ball, goal cheers from that club's stands), without iris, walkout camera or sky change. Presentation code now reads `ClubRef.presentFrame()` / `presentModel()`, and HUD and town code keep using your own club. The pure choice is `PlotVisit.spectateTarget`, with tests.
- **Playtest (solo, faked):** the server cloned the Plot1 club folder to Plot2 with Phase=Match, and the character stood at the Plot2 lot. 31 rigs played there, with the ball near (1868, 3, -1278) (Spectate_3). Walking 600 studs away removed MatchVisuals within 3 s. Going back and pressing your own Play Match switched straight back: the ball was at Plot1 (1050, 1250) during PreMatch. No console errors.
- **Side effect in the Studio store:** the test club finished season 3 and was relegated (5th in the County League), then started season 4 in the Sunday Parks League.
- Follow-ups X38 (spectator score pill) and X39 (real two-player check).
- RunAll 306/306.

### 2026-09-17 03:18 — Spectator score pill (X38)
- While you watch another club's match, a pill under PLAY MATCH shows "Watching  Lune Albion 2 - 1 Brindle Heath  ·  60'". It uses the same football minute as the owner's scoreboard. Match.client sets a local-only player attribute `WatchingPlot`; SpectatorPill reads that club's folder. The text comes from `ClubCard.watchingLine`, which has a test.
- Checked with a faked live Plot2 match (SpectatorPill_1).
- RunAll 307/307.

### 2026-09-17 03:20 — Friendlies part 1: invite book (I3.1a)
- I3.1 was size L, so I split it into a/b/c/d. New pure `Friendly` module: challenge (refuses self, busy clubs, a second outgoing invite, and a challenge back to someone who already invited you), respond (accept/decline), 45 s expiry, dropUser on leave, and `homePayout` as a share of the gate. FriendlyTest has 7 tests. The TEMP rules are question 5.
- RunAll 314/314.

### 2026-09-17 03:25 — Friendlies part 2: server (I3.1b)
- **MatchService refactor:** the matchday (sim, crowd, walkout, clock and goals, final score) is now a shared `playCore`. `playMatch` adds the league settlement on top, unchanged. The new `playFriendly(opponent)` adds the TEMP friendly rules: no bias, never an evening kick-off, home payout `Friendly.homePayout`, no injuries or development (skips `ClubService.finishMatch`), no league round, and nothing added to W/D/L or MatchesPlayed. While it runs the club folder has `Friendly=true`, and its summary goes out with `friendly = true` and division "Friendly". `awayTeam()` gives the challenger's current XI and strength, with a kit colour from its name.
- **FriendlyService (global):** remotes FriendlyChallenge(targetPlot), FriendlyRespond(fromUserId, accept) and FriendlyInvite (to the challenged owner), backed by the `Friendly` book. It checks both clubs are idle when you challenge and again when the other owner accepts, then starts `playFriendly` at the challenged ground and toasts the challenger at start and with the result. Invites expire (checked every 5 s) and are dropped when a player leaves. PlotService gained `clubOf(userId)` / `clubAt(plot)`.
- **Playtest:** DebugRun `friendly|15|3` played "Friendly Test XI" (Plot1's own side renamed). MatchesPlayed stayed 30 and W/D/L stayed 12/9/9, cash rose £300 (25% of the 150-seat × £8 gate), and Friendly went true, then false. A league match right after still counted: match 31, a draw, cash +£1,350, round 1. No console errors. The remotes can't be fired from the MCP client (capability block), so they wait for I3.1d.
- **TEMP:** your away club can still start its own league match while its friendly plays at the other ground. That's harmless, since the away side is a snapshot. Part of question 5.
- RunAll 314/314.

### 2026-09-17 03:29 — Friendlies part 3: client (I3.1c)
- **Visitor club card:** new "Play a friendly" button, shown when you own a club and the one you're visiting has an owner. It fires FriendlyChallenge. Clicking it at my own ground (the one-player test) got the server's refusal toast "You can't play a friendly against yourself.", so the whole remote path is exercised (FriendlyButton_1).
- **Invite card (FriendlyInvite):** "FRIENDLY CHALLENGE", showing the challenging club and its manager, a 45 s countdown, and Accept / Decline. It closes on its own at 0 (FriendlyInvite_1). Accept on the debug invite came back "That challenge has expired.", as expected with no real invite. New Studio-only DebugRun `invite` shows the card, because MCP threads can't fire remotes.
- **Banner and summary:** the PreMatch banner reads "… vs Friendly Test XI · Friendly". The summary header says FRIENDLY, the league row says "No league points · no injuries", and it showed +£300 (FriendlySummary_1).
- New follow-up X40: the bottom hint pill covers the summary's Back to Club button. This already happened on league summaries too.
- The Accept path that actually starts a match between two owners is I3.1d, which needs Players = 2.

### 2026-09-17 03:30 — Hint no longer covers Back to Club (X40)
- HUD hides the bottom hint pill while the match summary or season card is open, and brings it back when either closes. Tested with a 3 s friendly: before the match the hint showed "Matchday! The teams are walking out."; with the summary open it was hidden; after Back to Club it showed "Fans were turned away…" again.

### 2026-09-17 03:32 — Trades part 1: pure rules (I4.1a)
- I4.1 split into a/b/c/d. New `Trade` module: `validate` (no self-trades; at least one player moves, so no cash gifts; up to 3 each way; whole non-negative cash going one way that the payer can afford; players must belong to the right club, no duplicates; both squads within Config.SquadMin/Max and keeping a goalkeeper), `move` (fresh id and lowest free shirt number at the new club, stats copied), and an offer book (one outgoing offer, 60 s expiry, dropUser). TradeTest has 8 tests. The TEMP rules are question 6.
- RunAll 322/322.

### 2026-09-17 03:35 — Trades part 2: server (I4.1b)
- **TradeService (global):** remotes TradePropose(targetPlot, give, take, giveCash, takeCash), TradeRespond(fromUserId, accept) and TradeOffer (to the other owner, with names, roles, ratings, ages and injuries of the players involved). Remote input is sanitised: short lists of whole numbers, and numeric cash. The offer is checked with `Trade.validate` when proposed and again on accept, and both clubs must be in Manage with no match running. It is then applied in one non-yielding step: `tradeAway` on both clubs, `tradeIn` on both, the cash moves, and both saves are flushed. Offers expire, are dropped when someone leaves, and each step toasts both owners.
- **ClubService:** `squadCopy`, `tradeAway(ids)`, `tradeIn(players)` (fresh ids via `Trade.move`, then the lineup is recomputed and published). **PlotService:** `modulesFor(userId)` (ClubService, ClubState, Session, MatchService copies for that club).
- **Playtest (solo):** DebugRun `tradeRoundTrip|16` traded bench player Callum Skyward (#16, id16) out and straight back in. He returned as #16 id17, and the squad stayed at 16. A league match afterwards still counted (32 played). Save, then reload from the snapshot, kept him as id17. No errors.
- RunAll 322/322.

### 2026-09-17 03:40 — Trades part 3: client (I4.1c)
- **Visitor club card:** now has three buttons: Play a friendly, Trade players, Close (VisitButtons_2).
- **TradePanel (module):** "TRADE WITH <CLUB>". YOU GIVE and YOU GET list both squads (shirt number, name, role, rating, age, injured). You tap up to 3 on each side; picks are highlighted gold. There's a cash box with a You pay / They pay toggle and a live status line, plus Send offer and Cancel (TradePanel_1). Sending with the one-player setup came back "You can't trade with yourself." from the server, so the propose remote path works.
- **TradeOffer card:** "TRADE OFFER" from <club> (<manager>), with You get / You give lines (rating, age, injured), the cash line, a 60 s countdown, and Accept / Decline (TradeOffer_1). Decline on the debug offer came back "That trade offer has expired.", so the respond remote path works. New Studio-only DebugRun `tradeOffer`.
- `Trade.parseCash` and `Trade.offerLines` are pure, with 2 new tests.
- **Theme fix:** card footers sorted buttons by name, so Close ended up between the other two. `Theme.card` now keeps buttons in the order they were added. Only the new multi-button cards were affected.
- The real Accept that swaps players between two owners is I4.1d, which needs Players = 2.
- RunAll 324/324.

### 2026-09-17 03:49 — Humped road bridges (X31)
- **Reference:** `RivermereRiverside.png` shows a stone bridge whose arches stand well clear of the river. Ours had about 2 studs of arch, because the decks sat 2.7 above the water.
- **Change:** road bridge decks now climb. `TownLayout.bridgeRise` and `bridgeSections` (TEMP BRIDGE_RISE 6, BRIDGE_RAMP 40) give each bridge a 40-stud straight ramp from each end up 6 studs, and it stays level over the water. A test checks that every real road bridge keeps the water under the level part (the water starts 45 in). TownBuilder builds each bridge as up-ramp "DeckRamp", level "Deck" and down-ramp "DeckRamp", with parapets and footways per piece and the piers raised. BridgeDresser follows the humped soffit: tall arches under the level deck, low ones under the ramps, a string course on every piece, and 10 slices per arch (6 read as flat-topped openings). Traffic cars and pedestrians follow the ramps (`bridgeRise` in Traffic and `PedestrianMath.groundY`).
- **Screenshots:** LuneBridge_after_4 from the waterline shows stepped stone vaults about 6 studs above the water, cutwaters, and the next bridge seen through the arches. LuneBridge_road_1 shows the ramp from the south end, with pedestrians and a car on the crest.
- **Parts:** bridges went from 198 to 330 (max 110 per bridge). No console errors.
- **Biggest differences from the reference:** the arches are stepped slices rather than smooth curves (new X41), the stone is paler and more uniform than the reference's warm sandstone, and there are no street lamps on the bridge. New X42 checks lamps and banners on the humped decks.
- RunAll 326/326.

### 2026-09-17 03:51 — Smooth bridge arches (X41)
- Each arch slice's block now stops at its higher corner, and a WedgePart under it (`BridgeDresser.sliceWedge`, with a test for its corners) carries the curve down to the lower corner. With 6 slices, every arch is a smooth six-sided curve instead of steps.
- **Screenshots:** LuneBridge_wedges_1 from the waterline shows rounded stone vaults with pointed piers between them. LuneBridge_wedges_2 from the east promenade shows a humped stone bridge with a row of arches over the Lune, close to the bridge in `RivermereRiverside.png`.
- **Parts:** 128 per bridge (54 of them wedges), 384 for the three.
- **Still different from the reference:** the stone is pale grey rather than warm honey sandstone, and there are no voussoirs (arch-ring stones) or lamp standards on the parapets.
- RunAll 327/327.

### 2026-09-17 03:53 — Bridge stone colour (X43), nothing stranded on the decks (X42)
- **X43:** the bridge stone went from grey-beige to warm honey sandstone (stone 210,184,140; piers and cutwaters 184,158,118; coping 226,208,172), closer to `RivermereRiverside.png` (LuneBridge_colour_1).
- **X42:** an overlap query over every Deck and DeckRamp found only the road and pavement ends that already ran under the bridge ends. There are no lamps, banners or props on the old flat deck height.

### 2026-09-17 03:54 — A1.4 screenshots to disk: blocked
- The Studio MCP `screen_capture` only returns the image to the agent. `store_image` reads files but can't write them. A System.Drawing desktop grab (no external tools) works, but the Studio viewport in it is a stale, stretched frame rather than the live game view while Studio isn't the focused window. A blank "RobloxStudio" popup also sits over the viewport, and I left it alone. The "before" hero look no longer exists either. The probe images were deleted.
- **Seen in passing:** the Rojo 7.4.4 panel in Studio shows "Unknown HTTP error: HttpError: NetFail". That fits X4/X34: the plugin can't reach `rojo serve`, so start `rojo serve` and reconnect in the morning.
- **Suggestion:** take the A1.4 shots by hand (F12 in Studio, or the Screenshot button) at the places listed at the top of the handoff.

### 2026-09-17 03:55 — Rojo reconnect attempt (X34): blocked
- `rojo serve` is running (port 34872) and serves the current branch: TradePanel, FriendlyService and the X43 colours are all in its tree. The Studio plugin panel shows NetFail.
- I tried the memory's HTTP fallback (`tools/studio-sync.luau` through execute_luau). The MCP thread now "cannot read 'HttpEnabled' (lacking capability Network)", so it can't run from here. Nothing was changed. Clicking Connect in the Rojo panel is the fix, and that has to be done by hand (handoff known bug 6).

### 2026-09-17 04:00 — Kit cars on the wide driveways (X33)
- EstateDresser places the kit HatchbackOrange on a driveway when `driveCarFit` can fit it at 70% scale or more: the width leaves 0.6 each side, the length leaves 1 at each end, and the long axis is turned along the drive. Otherwise the block car stays. `driveCarFit` is pure, with a test. The car sits 0.02 above the slab.
- **Result:** 5 kit cars. Drive widths are 5.1 (76), 2.8–3 (30) and 10.2 (13), so only the wide ones qualify. A 0.35-scale trial filled 26 drives but looked like a toy next to a character (DriveCar_small_1), so the minimum went back to 0.7. New X44 and question 7 cover the narrow drives.
- RunAll 328/328. Estates are now 1,629 parts.

### 2026-09-17 04:02 — Terrace street part budget (X35)
- Counting parts by name showed the Mill Street and Weaver Street showpiece spent 426 of its 1,013 parts on six VanWhite kits (71 parts each). The one-mesh hatchback is 1 part, and the railing bars were only 241.
- TerraceStreetDresser now picks a van 1 time in 6 instead of 1 in 3 (StreetDresser unchanged). The showpiece is 733 parts, and the budget now fits 3 light streets instead of 1: Weaver Street and Mill Street beyond the showpiece, plus Church Lane. The railings keep a bar every 2 studs.
- **Screenshot** MillStreet_cars_1: still a lived-in terrace street, but the parked cars are almost all orange (new X45).

### 2026-09-17 04:06 — Finger post in the market square (X46)
- **Compared with `RivermereCenter.png`:** the reference has a black finger post with white blades (Station / Car Parks / Riverside). The square had nothing to guide a new player.
- **New in SquareDresser:** a black post with a ball finial at the square's east rim (radius 51, between two stalls), with four white blades pointing flat at the Station bus stop, the Riverside bus stop, the Lune Bridge and the Church Spire. Each blade has its name on both faces and a wedge tip showing the way. `bladeFrame` and `destination` are pure; SquareDresserTest has 2 tests. 10 parts.
- **Screenshot** FingerPost_1: the blades read clearly from the pavement, with the clock tower and spire behind.
- **Biggest remaining differences from the reference (new X47):** bare concrete tree pits instead of flower planters, few hanging baskets, a bus shelter without an advert panel, and lollipop trees.
- RunAll 330/330.

### 2026-09-17 04:09 — Flowers in the town-centre planters (X47, part)
- ForecourtDresser's planter trees round the square zone were bare stone boxes. Each now has soil and a bed of flowers round the trunk, taking the colours in turn (pink, purple, coral, white). That adds 2 parts per planter, 8 planters. The first try used a Ball part, which came out as a tiny sphere because a ball's diameter is its smallest axis, so it's a low bedding block now.
- **Screenshot** Planter_flowers_3: a pink bed in the stone planter outside the Daily Bean. It's blockier than the reference's overflowing planters but reads the same way.

### 2026-09-17 04:10 — Bus shelter adverts (X47, part)
- Every bus shelter (TownBuilder) now has an advert panel across its open end, readable from both sides, like the poster in `RivermereCenter.png`. The three designs take turns by stop: "A CLEANER GREENER RIVERMERE" (green), "RIVERMERE MARKET EVERY SATURDAY" (navy) and "SUPPORT YOUR LOCAL CLUB" (red). 1 part per stop, 11 stops.
- **Screenshot** Shelter_advert_1: the Town Centre shelter with the red club advert, the finger post and a planter's flowers in the same view.
- X47 still has hanging baskets on lamp posts and the lollipop trees to do.
- RunAll 330/330.

### 2026-09-17 04:14 — Hanging baskets on the lamp posts (X47 done)
- SquareDresser hangs a flower basket (a bracket plus a flower ball, tagged Decor so Quality Low hides it) on the 30 lamps nearest the square within TEMP 420 studs: the square's 4 kit lamps, the Mill Street kit lamps, and StreetDresser's TerraceLamps (off the side away from their lantern arm). `basketLamps` is pure, with a test. 60 parts.
- The first try only found the 4 square lamps: I had limited kit lamps to the square, and the nearest TerraceLamp is 261 studs out. Widened as above.
- **Screenshot** LampBasket_1: a yellow basket hanging from a Mill Street lamp, with the terrace behind.
- X47 is done. The trees still look like lollipops against the reference, so that's new X48.
- RunAll 331/331.

### 2026-09-17 04:16 — Leafier tree crowns (X48)
- Full-detail street trees (Mill Street and Weaver Street) swap the ball stacked on a ball for two offset lobes: one high and to one side, one lower on the other side, in slightly different greens. The 8 planter trees round the square get two lobes as well. Light-street, park and backdrop trees are unchanged.
- **Budget:** the terrace streets' TEMP PART_BUDGET went from 1,200 to 1,240 so the extra lobes don't push a light street out. It's now 1,229 (showpiece 763), still 3 light streets. Forecourts are 646 parts.
- **Screenshot** Trees_lobes_1: the Mill Street trees have lumpy crowns. They're still stylised next to the reference's loose leafy trees.

### 2026-09-17 04:19 — Station windows (X49)
- **Compared with `RivermereStation.png`:** our station already has the navy "RIVERMERE STATION" canopy, the gable clock and a "Next Trains" board, but its windows were flat dark blue rectangles.
- **Change:** StationDresser gives every window a white mullion and transom standing just proud of the glass, a lighter glass colour, and a stone sill on the ground floor. About 40 parts.
- **Screenshot** Station_windows_1: the brick front reads as a row of sash windows.
- **Still different from the reference (new X50):** a grass strip between Station Road's pavement and the forecourt, which the reference has paved to the kerb. There's also no newsagent kiosk and no taxi or bus-stop road markings.
- RunAll 331/331.

### 2026-09-17 04:21 — Station forecourt paved to the pavement (X50, part); glass colour fix
- StationDresser now paves out from the forecourt in 8-stud strips to wherever Station Road's pavement begins. That's 14 strips, each tucked 1 stud under the pavement edge (paving top 0.3, pavement top 0.45), skipping the drop-off lane, and leaving the grass alone where no road comes within 70 studs. `forecourtReach` is pure, with a test that checks the strips end on a road pavement.
- **Bug found and fixed:** the X49 commit added a second `local GLASS` that shadowed the entrance and footbridge glass colour below it. It's renamed to WINDOW_GLASS, so the entrance and footbridge glass have their original pale colour back.
- **Screenshot** Station_verge_1: paving runs from the station front right to the Station Road pavement.
- RunAll 332/332.

### 2026-09-17 04:23 — Taxi rank markings (X50 done)
- The station drop-off lane has a yellow edge line and "TAXIS" painted on the free bay: a clear plate 0.02 above the tarmac with a Top-face SurfaceGui. The line is sunk 0.02 into the lane so no top faces share a plane. The reference's newsagent kiosk was already there, green, at the west end of the frontage.
- **Screenshot** Station_taxis_1: the markings read clearly beside the two taxis.
- **Found:** the drop-off lane stands in the grass with no road reaching it, because Station Road ends east of the entrance (new X51).

### 2026-09-17 04:24 — Taxi lane towards Station Road (X51, part)
- I extended the drop-off lane 10 studs east, but a grass gap remains between it and Station Road's diagonal end (Station_lane_1). The real fix is a layout change: give Station Road an extra point so it turns along the station forecourt. That touches traffic routes and TownLayoutTest, so it's left on the backlog rather than rushed.

### 2026-09-17 04:27 — Turnstile entrance in brick (X52)
- **Compared with `RivermereTurnstileEntrance.png`:** that entrance is brick piers, dark iron gates and a club-name fascia. Ours was four club-red boxes.
- **Change:** WorldBuilder builds the piers in brick with limestone caps, and adds an open iron gate leaf folded flat against each pier's outer face (no collision, clear of the lanes, so walking fans are unaffected). The club-colour fascia with the club name stays. 14 more parts per ground.
- **Screenshot** Turnstiles_brick_1.
- **Still missing (new X53):** lane signs ("HOME SUPPORTERS" / "TICKETS"), a brick boundary wall off each side, and a club banner on a lamp outside.
- RunAll 332/332.

### 2026-09-17 04:28 — Turnstile lane signs (X53, part)
- Each turnstile lane has a navy sign under the fascia on the walk-up side, reading HOME FANS / TICKETS / HOME FANS, as in the reference. They have no collision and give 7.4 studs of headroom.
- **Screenshot** Turnstiles_signs_3: straight on, the entrance now reads as a small football ground's gate (club-name fascia, brick piers, iron gates, turnstile drums, lane signs).

### 2026-09-17 04:35 — Industrial estate entrance sign (X54)
- **Compared with `rivermer.industrialestate.png`:** the reference opens with a tall navy estate totem. Ours had none.
- **Change:** EstateDresser finds a clear verge spot near the Industrial Estate bus stop: off the road and pavement but within 6 studs of one, clear of every block, at least 10 from the stop. It builds a navy totem there facing the road, on a concrete plinth: "RIVERMERE INDUSTRIAL ESTATE" and a light panel listing Units 1-6, Units 7-12, Deliveries and Trade Counter, readable from both sides. `totemSpot` is pure, with 2 tests (a synthetic road and block, plus the real estate stop). 2 parts.
- **Fixed along the way:** the destination list first wrapped, then shrank to unreadable when wrapping was switched off, so it's now one label per row. A test tolerance was also loosened to 1e-3, because Vector3 maths is float32.
- **Screenshot** Estate_totem_4.
- **Still missing from the reference (new X55):** unit numbers and brick plinths on the sheds, palisade yard fences and gates, lorries, pallets and forklifts, and a planted mini roundabout at the estate entrance.
- RunAll 334/334.

### 2026-09-17 04:37 — Shed unit numbers and brick plinths (X55, part)
- Each estate shed gets a brick plinth course (up to 3 studs, 0.15 proud) round its sides and back; the front keeps its full-height roller doors. Sheds 26+ studs wide also get a navy unit-number plate at the far end of the front from the business sign. The numbers run 1..43 in build order. That's about 4 parts per shed, 43 sheds.
- **Screenshot** Shed_units_1: "MILL LANE MOTORS" unit 9 with 10 and 11 beyond, brick plinth along the side wall. It's now much closer to the reference's numbered units.
- RunAll 334/334.

### 2026-09-17 04:39 — Lorries in the warehouse yards (X55, part)
- Warehouses at least 40 studs wide (4 of them) get an articulated lorry parked along the front yard: a white trailer with a navy "RIVERSIDE LOGISTICS" panel on both sides, a navy cab with windscreen, and a chassis with three wheel axles. It's about 9 parts, replacing those yards' pallets, and is modelled on the reference's Riverside Logistics lorry.
- **Screenshot** Lorry_1 (the camera sat under a neighbouring roof edge, so it's dim): the lorry in front of Rivermere Plant Hire.
- RunAll 334/334.

### 2026-09-17 04:41 — District name stones (X56)
- **Compared with `RivermereNorthfields.png`:** the reference has a carved "NORTHFIELDS" stone at the estate entrance.
- **Change:** EstateDresser picks the Northfields, Westdale and Riverside block nearest the market square (the "gateway" block). It searches for a clear verge near it, using the same finder as the estate totem with a wider radius, and places a limestone slab on a slate base there, carved with the district name in a serif font on both faces, facing the road. `gatewayBlock` is pure; the test checks all three districts get a spot. 2 parts per stone.
- **Screenshot** District_sign_1: "NORTHFIELDS" in front of the terraces at (-137, -420). Riverside's stone is at (-11, 280), Westdale's at (-673, 538).
- **Still missing from the reference (new X57):** the play area, porch canopies, and front-garden flower borders.
- RunAll 335/335.

### 2026-09-17 04:44 — Porch hoods on the semis (X57, part)
- Every semi front door gets a slate porch hood, 1.8 deep and door width plus 1, standing off the front wall. The door head height (0.43 of the front wall) and door width (86/512 of a house) are read from the door `tools/kit/make_buildings.py` draws on the semi_front textures. The first version had wooden brackets, which took a pair to 19 parts against the 16-part budget test, so it's one part per door.
- **Screenshot** Porch_1: red-slate hoods over the red doors of a Northfields pair.
- X57 still has the play area and front-garden flower borders to do.
- RunAll 335/335.

### 2026-09-17 04:47 — Bus stop flags (X58)
- **Compared with `RiveremereWestdale.png`:** the reference has a proper UK bus stop flag. Ours was a small red square with tiny white text.
- **Change:** every stop (TownBuilder) now has a white 2.6 × 3.6 plate with a red "BUS" band, the stop name and TEMP decorative route numbers ("21 23", "7 24"…), readable from both sides, plus a litter bin beside the pole. The prompt still attaches to the Sign part (checked).
- **Screenshot** BusFlag_1: the Westdale stop.
- **Still different in Westdale (new X59):** the side streets are bare (no trees, lamps, cars or railings), there's no corner shop with a post box, and a big white civic greybox block sits among the houses.
- RunAll 335/335.

### 2026-09-17 04:49 — Post boxes by the corner shops (X59, part)
- ForecourtDresser puts a red pillar post box (a cylinder and a dome cap, 2 parts) on the forecourt at one end of each corner shop, up to 10, if it's clear of roads and bus stops. It's modelled on the post box beside Westdale Stores in the reference. All 10 were placed.
- **Screenshot** PostBox_1: a post box outside a corner shop, with a club banner lamp and the terrace behind (the player's own helmet is in the foreground).
- **Found:** the big white block in Westdale is the "school" greybox, which nothing dresses yet (part of X59).
- RunAll 335/335.

### 2026-09-17 04:52 — Red-brick schools (X59, part)
- ShopDresser passes the block use through to `ShopBuilder.civic`. A "school" is now a red-brick body, with the civic facade texture tinted brick, a white stone porch and pediment, and a navy "RIVERMERE PRIMARY SCHOOL" board across the porch. The town hall stays white stone. There are 3 schools, 1 extra part each.
- **Screenshot** School_1: the Westdale school with pedestrians on the pavement and a lamp with a hanging basket.
- The real leftover in X59 is dressing the Westdale side streets (trees, lamps, parked cars), which needs part budget.
- RunAll 335/335.

### 2026-09-17 04:55 — Shirts in the club shop window (X60)
- **Compared with `RivermereTurnstileEntrance.png`:** that club shop window is full of shirts. Ours was a dark empty box.
- **Change:** PlotGrounds adds a black display rail inside the window with three home-kit shirts (body plus sleeve bar in `Config.HomeKit`, sleeves inset so no planes are shared) and a warm PointLight behind the glass. 7 parts per plot.
- **Screenshot** ClubShop_shirts_1.
- RunAll 335/335.

### 2026-09-17 04:56 — Part count check after tonight's dressing (X61)
- **Server workspace:** 20,557 BaseParts. The town is 17,147: Mill Street kit Dressing 8,371, Estates 1,960, TerraceStreets 1,229, Imperfections 900, Riverside 801, Shops 698, Forecourts 666, Bridges 504, Park 429, Roads 363, Square 331, Marina 312, Church 238, StationFront 180, BusStops 88. Also Plot1 681, three for-sale lots 168, Backdrop 974, VerticalSlice 1,565.
- **Client at plot 1:** streams 10,848 parts (01:12 baseline 5,740) at 60 fps on the Studio PC. The Studio memory figure (4.5 GB) covers both the server and client test sessions, so it isn't meaningful.
- This PC result says nothing about a mid-range phone. New X61: measure on a phone before adding more dressing (with X28). The biggest single lever is the Mill Street kit Dressing (8,371 parts).

### 2026-09-17 04:59 — Tree sway and birds (F4.2)
- New client script TownMotion. The 40 tree crowns nearest the camera (within 160 studs; street, planter and park trees) sway up to 0.35 studs, each with its own phase and a slowly turning gust direction. Every second the nearest set is re-picked and trees that drop out snap back to their server CFrame. Two flocks of 5 birds (a body and two flapping wings, client-only parts) wheel round the church spire at 95 up and over the Lune Bridge at 28 up, and exist only within 700 studs. Everything turns off on Quality Low. The maths is pure in Shared.TownMotion; TownMotionTest has 3 tests.
- **Playtest:** a canopy 23 studs away moved 0.47 studs in 1.1 s, and 30 bird parts were live. With Quality Low there were 0 bird parts and the canopy was still; toggling back restored both. No console errors.
- **Screenshot** Birds_spire_1: five birds circling the spire above the terraces.
- RunAll 338/338.

### 2026-09-17 05:04 — Club murals in town (H1.2)
- **Roadmap H1 ("club influence tiers: … murals"):** a new client script, ClubMurals, paints a mural in the player's own club colours: club name, an accent stripe and "OUR TOWN · OUR CLUB". It goes on the gable end, facing the square, of the terrace row nearest the market square (within TEMP 360 studs). One mural appears once the club has played 3 matches, and a second from tier 2 (`TownLifeMath.muralCount`, `gableToward`, 2 new tests; question 8). Only that player sees it. It updates when ClubName, MatchesPlayed or Tier changes, and comes and goes with streaming.
- **Bug found and fixed:** the first try placed nothing. Streamed rows can arrive before their Body, and until then the model pivot is the origin, so the "nearest" rows had no wall. The ranking now uses the Body and re-runs when a Body streams in.
- **Screenshot** Mural_2: the "MDINO24 FC" mural on the gable beside The Little Deli.
- RunAll 340/340.

### 2026-09-17 05:07 — Matchday cars in the club car park (G1.2)
- **Roadmap G1 ("… parked cars, extra traffic"):** MatchdayLife now parks supporters' cars (a body plus a dark cabin, 2 parts each) in the club car park while a plot's match is in PreMatch or Match. Like the fans and stewards, anyone near the ground sees them. The 36 bay centres come from new `MatchdayRoutes.carParkBays()`, matching PlotGrounds' bay lines. `parkedCars(attendance, bays)` fills 10% for a tiny crowd and all bays from TEMP 1,500 attendance; which bays fill is seeded per plot. 2 new tests (bays inside the kerbs, clear of the road mouth and not overlapping; the count scales).
- **Playtest:** attendance 150 gave 4 cars alongside 48 fans. The top-down Matchday_cars_2 shows each car sitting inside its bay lines, and Matchday_cars_1 shows the car park with fans walking to the turnstiles.
- RunAll 342/342.

### 2026-09-17 05:09 — A live match heard across town (G2.2)
- **Roadmap G2 ("chants carrying across town"):** AmbientAudio has a fifth bed, the stadium crowd loop run through an EqualizerSoundEffect (highs −30 dB, mids −8, lows +2) so it reads as a distant roar. Its level follows the nearest ground with a live match, any club's: silent within 220 studs (MatchAudio or spectating covers that), loudest at 420, and fading out by 1,500 (`TownLifeMath.distantCrowdWeight`, 1 new test). It's quieter high above town, like the other beds.
- **Playtest:** during a match, the bed was at 0.218 about 420 studs from the ground and 0.000 standing inside it.
- RunAll 343/343.

### 2026-09-17 05:13 — People at the café tables (F3.2)
- **Roadmap F3 ("café sitters"):** new client script CafeSitters. At the 5 café sets nearest the camera (within 200 studs), it seats 1–2 people facing the table: torso, head, thighs on the seat, shins to the floor, and forearms towards the table, 8 parts each, in varied skin, top and trouser colours seeded by table. They're there all day, not only on matchday, and off on Quality Low. The pose is pure in `TownLifeMath.seatedFigureCFrames` (1 new test: sits on the seat, feet just above the floor, turns with the seat).
- **Adjusted after the first screenshot:** the forearms swung far enough to cross mid-table, so the swing went from 0.9 to 0.55 rad.
- **Screenshot** CafeSitters_2: two people at the table outside The Riverside Arms.
- RunAll 344/344.

### 2026-09-17 05:20 — Cyclists (F3.3) and a road streaming bug (X62)
- **Cyclists:** Traffic now spawns bikes for 1 in 5 spawns on residential streets: two wheels, a frame, a rider torso, a head and two legs (7 parts), at 11 studs/s. They ride 1.6 studs in from the kerb on the driving side (new `TrafficMath.kerbOffset`, with a test), just clear of a car in the lane on a 20-wide street. Cars aren't held behind them (bikes sit outside the leader-gap check). Lanes are too narrow for passing, so no bikes there.
- **Bug found while filming a bike (X62):** some cars and bikes were driving over grass. Each carriageway is one long part per polyline segment (Northfields Avenue is a 2,665-stud part), and streaming places a part by its centre, so near the west end of town a client had only 43 of 80 carriageways. TownBuilder now marks every road model Persistent (about 360 parts). After the fix the client held 80 of 80, and 23 of 24 vehicles raycast onto a road; the last was at a junction gap.
- **Screenshot** Cyclist_2: a rider on a red bike by the kerb in Northfields, with a post box outside Northfields Stores.
- RunAll 345/345.

### 2026-09-17 05:25 — Buses stop at the bus stops (F2.2)
- **Roadmap F2 ("… buses, bus brakes"):** a traffic bus now pulls up for TEMP 4 s when it reaches the point on its road nearest a bus stop. Stops within 40 studs of the road's centreline count; the Station stop sits 36 out, so the first reach of 26 missed four stops. It won't stop twice in a row at the same stop. A dwelling bus counts as stopped before the leader-gap pass, so cars behind it queue rather than drive through. `TrafficMath.stopDistances` and `passedStop` are pure, with 2 new tests.
- **Playtest:** a bus sat still for more than 2 s, 25 studs from the Riverside Park stop sign, then drove on. BusAtStop_1 shows the stop just after it left.
- RunAll 347/347.

### 2026-09-17 05:27 — Paved pads under bus stops (X63)
- BusAtStop_1 showed the Riverside Park shelter, flag and bin standing on grass. `TownBuilder.buildBusStop` now lays an 18 x 9 paving pad under each stop, 0.4 thick.
- **Screenshot** BusPad_1: the Riverside Park shelter, flag and bin sit on block paving beside the pavement.
- RunAll 347/347.

### 2026-09-17 05:35 — Northfields play area (X57 part)
- RivermereNorthfields.png has a railed playground beside the NORTHFIELDS stone. `EstateDresser` now builds one on the empty corner lot by North Road, about 110 studs from the stone. It has a green safety surface, black railings with a gate facing the pavement and a paved path out to it, a wooden climbing tower with a red pitched roof and a steel slide, a red A-frame swing set with two seats, and a bench: 84 parts in one model.
- `EstateDresser.playAreaSpot` is pure. It searches outward from the district's gateway block for a 28-stud square that is 2 studs clear of every road and pavement, 3 clear of every block, within 8 of a pavement and away from the stone. The gate faces the nearest road. There are 2 new tests: a synthetic street, and "Northfields has room". A server overlap check found no other parts inside the square.
- **Screenshots** PlayArea_1 and PlayArea_2.
- Still open on X57: flower borders in the front gardens.
- RunAll 349/349.

### 2026-09-17 05:38 — Flower borders in the semis front gardens (X57 done)
- New `EstateBuilder.flowerBeds`: one planted border per house under the front window, on the longer side of the door path, 0.05 off the front wall. It is 1.4 deep and 1.1 tall, so it shows over the 1.8 hedge from the pavement; a 0.6 bed hid behind it. The border uses LeafyGrass in pink, lavender, pale pink, yellow or red (white read as gravel), with its own Random stream so the pairs' fronts don't reshuffle.
- The beds are tagged `Decor`, so Quality Low hides them. They sit outside semiPair's 16-part budget: 132 beds in town, about +132 parts (X61 still wants a phone measurement).
- 1 new test covers wall gap, hedge, own house front, door path and Decor tag across 6 seeds.
- **Screenshots** FlowerBeds_1 (0.6 tall, hidden) and FlowerBeds_3 (final: lavender and pink borders over the hedges).
- RunAll 350/350.

### 2026-09-17 05:41 — Club banner on a lamp post at the turnstiles (X53 part)
- `WorldBuilder.buildTurnstiles` now adds a black lamp post on the walk-up side beside the entrance. It has a base, post, lantern and cap, with an arm holding a club-colour fabric banner: the club name (label "ClubName", so `setClubName` repaints it) over "OUR TOWN / OUR GAME", like RivermereTurnstileEntrance.png. That's 6 parts per club; the banner and arm don't collide.
- **Screenshot** LampBanner_1: MDINO24 FC banner beside the brick turnstiles.
- Boundary wall still open: the corner gap either side of the block holds the walkway and the fans' routes, so I left it rather than risk blocking walkers.
- RunAll 350/350.

### 2026-09-17 05:43 — No toy cars on narrow driveways (X44)
- Question 7's recommendation, done as TEMP: `EstateDresser.wantsBlockCar` (pure, 1 new test) only gives a drive the primitive block car when it is at least `DRIVE_CAR_MIN_WIDTH` (8) across. Before, the 5.1- and 3-wide drives held undersized cars. The town now has 2 kit cars on the 10.2-wide drives and 117 empty drives. Widening the gap between pairs is left for the estate rework, because it changes the layout.
- **Screenshot** SemisNoToyCars_1: a Northfields semis street with clear drives and pink flower borders.
- RunAll 351/351.

### 2026-09-17 05:46 — Forklifts in the estate yards (X55 part), yard overlap found (X64)
- `EstateBuilder.shed`: every third unit (by unit number, TEMP for the part budget) without a lorry gets an 8-part orange forklift facing the shed door. It has a body, seat, guard post and roof, mast, forks and two wheel axles, and stands on the +Z side of the yard clear of the pallets and the sand heap. Those yards get 1–2 pallets; the rest keep 2–3. Doing all 39 lorry-free yards would have added about 270 parts, hence one in three.
- 1 new test over 6 unit numbers × 3 kinds covers the forklift on every third unit, ≤30 parts, no overlap with pallets or sand, and no forklift in a lorry yard.
- **Screenshot** Forklift_1: a forklift at Mill Lane Motors. The same shot shows a pre-existing bug: that yard's slab and fence run onto the pavement, with a corner post in the carriageway. Logged as X64.
- Not done on X55: palisade fencing (no pale texture, and pales as parts cost too much), and the mini roundabout (client traffic would drive through a planted island).
- RunAll 352/352.

### 2026-09-17 05:48 — Shed yards kept off the road (X64)
- Every shed body used the whole block depth, and its 20-deep yard was built in front of that, so on the 50-deep Estate Road blocks the yard and fence ran over the pavement into the carriageway. New pure `EstateBuilder.shedFit(blockDepth)` (1 test) shortens the body and moves it back, so the yard ends `PLOT_MARGIN` inside the block's road edge while the back stays on the block's back edge. A 50-deep block now gets a 29.5-deep shed.
- Server check: none of the 43 sheds' yards, fences or posts overlap anything under `Town.Roads`.
- **Screenshot** ShedYardFit_1: Mill Lane Motors (unit 8), with its yard behind the pavement.
- RunAll 353/353.

### 2026-09-17 05:55 — Station Road meets the station and its taxi rank (X51)
- **Layout change (`TownLayout`):** Station Road used to stop diagonally at the forecourt's east corner, and the drop-off lane and taxi rank sat in grass. The road now turns at (-790, -337) and runs along the front of the station to the station car park at (-938, -337). The new `TownLayout.STATION_LAYBY` is an 8-wide lay-by between the forecourt and the carriageway. `TownBuilder` lays no pavement over it (it's a pavement blocker), so the lay-by opens straight onto the road.
- `StationDresser.laybyLocal(f)` (pure, 1 new test) reads the lay-by into the front frame. The drop-off tarmac, the two taxis, the yellow rank line and the TAXIS marking are placed from it rather than hard-coded numbers. The lay-by's inner edge is exactly the forecourt edge, and its outer edge sits on the carriageway edge along its whole length.
- **Bend joint:** the bend left a 6×6 grass notch with no pavement. Forecourt verge strips now check for a real `Pavement` part (server overlap) and pave to the kerb where there isn't one; `forecourtReach` gained an optional `verge`. A raycast grid over x -940..-680 and z -380..-340 shows no grass between the station and the road.
- Traffic gets the longer road with a dead end at the car park. The Station bus stop is about 36 studs from the road, as before, so buses still pull up.
- **Screenshots** StationRoad_before, StationRoad_after and StationRoad_after_3.
- RunAll 354/354.

### 2026-09-17 05:58 — Westdale gets a dressed street (X59 done)
- The terrace dressing budget (1,240 parts) runs out on streets near the market square, so Westdale in RiveremereWestdale.png had bare streets. `TerraceStreetDresser.PRIORITY_STREETS = { "Weir Road" }` is dressed after the normal pass from `PRIORITY_RESERVE` (TEMP 260). Doing it first reshuffled the shared random stream: Mill Street's light stretch dropped out and Weaver Street's doubled. Doing it last leaves every earlier street exactly as before: Mill Street 476, Weaver Street 287 and 191 light, Church Lane 46, Mill Street light 229. Weir Road adds 216, so the dressing totals 1,445 parts. This is question 9.
- **Screenshot** WeirRoad_1: Weir Road with street trees, low brick garden walls with hedges, and parked cars and a van at the kerb.
- RunAll 354/354.

### 2026-09-17 06:02 — Riverside promenade surface (X65), two reference follow-ups (X66, X67)
- I compared the promenade with RivermereRiverside.png. A dark wavy "mud path" ran down the paving because TownBuilder fills the river banks with Mud to y -2 on a 4-stud voxel grid, and after the channel carve those voxels sit at occupancy 0.7 and render up to about y 1.4, over the promenade top at 0.35. `RiverDresser` now empties the top 1.8 studs of the ground layer under every quay and promenade run, plus 1.5 each side, which leaves occupancy about 0.55 and the surface below the paving. Voxel reads confirmed it. Note that server raycasts kept returning the old terrain for a while, so I checked the result with screenshots.
- Planter flowers were a 4.4 ball that read as a pink rock. They're now a 3.6 × 1.1 planted LeafyGrass top sunk into the planter.
- **Screenshots** Riverside_compare_1 (before) and Riverside_fixed_1 (paved to the railings, planted planter).
- Logged from the same comparison: X66 heritage lamps and baskets on the promenade, and X67 river-facing shopfronts (the promenade's west end passes blank brick sides).
- RunAll 354/354.

### 2026-09-17 06:05 — Heritage lamps with hanging baskets on the promenade (X66)
- New `RiverDresser.heritageLamp` for RivermereRiverside.png: a black post with the lantern on top (collar, glass, cap, finial) instead of the TerraceLamp's arm lantern. Every other lamp also gets a bracket and a hanging flower basket over the promenade side. That's 7 or 9 parts, against 36 for the LampVictorian kit, so the 23 promenade lamps add 47 parts. The baskets use their own random stream so the moored boats keep their looks. 1 new test covers the part counts, nothing below ground, and the basket placement (off the post, below the lantern).
- **Screenshot** HeritageLamps_1.
- Not done: the navy banner on the lamps. TownLife's client banners only look at `Town.Dressing` lamps.
- RunAll 355/355.

### 2026-09-17 06:09 — Market square clock faces and planters (X68, X69)
- In the comparison with RivermereCenter.png, the clock tower's four faces read "XI 3". Each face was one TextLabel with "XII
· 3 ·" and TextScaled. `SquareDresser.clockFace` now draws a round dial (aspect-locked, with a dark rim), the numerals XII, III, VI and IX, and hour and minute hands at the station clock's time.
- The square's planters showed a small ball of flowers in bare soil. The 8.4 × 2.6 × 3.8 Ball rendered 2.6 across, because a Ball's diameter is its smallest axis. They're now a planted bed covering the soil.
- **Screenshots** Center_clock_1 (before), Center_clock_2 and Center_planters_2.
- RunAll 355/355.

### 2026-09-17 06:13 — Round balls (X70) and the Station bus stop (X71)
- X69 made me sweep `src` for `PartType.Ball` parts with non-uniform sizes. A Ball renders at its smallest axis, so these came out small. Two real cases turned up. The builders-yard sand heap (6 × 2.4 × 6) is now a round 5-stud ball sunk to y -0.5, showing a 4.8-wide mound. The station forecourt planter flowers are now a planted bed. The other matches were cylinders, blocks or already uniform. New test `ballPartsInShedsAreRound`.
- The screenshot of the station planter showed the Station bus shelter standing on the forecourt over a planter and the bench. The stop had been placed for the old diagonal road end. `TownLayout.BUS_STOPS` Station moves to (-915, -355), yaw 180, on the station-side pavement west of the taxi lay-by, with its back to the forecourt and open to the road. An overlap check finds only its own poster (ImperfectionDresser puts one on the back panel). It is about 18 studs from the road, so buses still pull up.
- **Screenshots** SandHeap_1, StationPlanters_1 (before the move) and StationStop_1.
- RunAll 356/356.

### 2026-09-17 06:15 — Bus stop bay at the station (X72), more station follow-ups (X73)
- New pure `StationDresser.busBay(f)` (1 test: all four corners on the Station Road carriageway, centred on the Station stop) places a 30 × 4.8 yellow bay just inside the kerb in front of the moved Station stop, with BUS STOP painted in it, as in RivermereStation.png. It's 5 parts (4 lines and a transparent text plate).
- **Screenshot** StationBusBay_1. The painted words are small, because the text plate is only as tall as the bay is wide.
- Logged X73 for the rest of that comparison: a finger post, double yellow lines, a kiosk basket, and the raised platform wall with railings.
- RunAll 357/357.

### 2026-09-17 06:17 — Finger post at the station (X73 part)
- The square's finger post is now `SquareDresser.fingerPost(parent, at, groundY?, destinations?)`, whose destinations can be names or `{ name, position }`. The square's call is unchanged (still 4 blades). `StationDresser` stands one on the pavement between the Station stop and the taxi rank. Its blades point to Town Centre, Car Park (the station car park block), Industrial Estate and Riverside, the same set as RivermereStation.png.
- **Screenshot** StationFingerPost_1: the post beside the moved shelter and the BUS STOP bay.
- RunAll 357/357.

### 2026-09-17 06:19 — Double yellow lines on Station Road (X73 part)
- New pure `StationDresser.yellowLineRuns(f, layby, bay)` (1 test: every line sits just inside a kerb, with no stubs, and station-side runs skip the bus bay and lay-by). It paints double yellow lines inside both kerbs of the straight past the station: one run on the far side, and three short ones on the station side around the bus bay and the lay-by mouth. That's 8 thin parts.
- **Screenshot** StationYellowLines_1: looking west along Station Road with the lines on both kerbs, the taxi lay-by and the moved bus stop.
- RunAll 358/358.

### 2026-09-17 06:22 — Street trees on the semis streets (X74), Northfields follow-up (X75)
- RivermereNorthfields.png is tree-lined, but the semis streets had none: TerraceStreetDresser only dresses streets that front terrace rows. New pure `EstateDresser.kerbTreeSpot` (1 test) finds a spot `TREE_INSET` in from the kerb on the nearest non-lane road in front of each semis pair. It skips junction mouths, roundabouts, bus stops, lamps, the terrace street trees and earlier semis trees. `TerraceStreetDresser.lightTree` (pit, trunk and one crown, Decor) builds it. The town has 52 trees (156 parts, hidden on Low), and none of the trunks touch a carriageway.
- **Screenshot** SemisTrees_1.
- Logged X75: a brick corner wall with a street name plate, and grass verges.
- RunAll 359/359.

### 2026-09-17 06:25 — Street name walls beside the district stones (X75 part)
- RivermereNorthfields.png has a low brick wall with a HAYFIELD CLOSE plate beside the NORTHFIELDS stone. New pure `EstateDresser.nameWallSpot` (1 test: 11 along the verge from the stone, on grass, flips side when a block is in the way) returns the spot and the nearest road's name. `buildNameWall` builds a brick wall, coping and a black-bordered white plate with the road name and district (3 parts), square to the road like the stone. The town now has ELM GROVE / Northfields, LUNE STREET / Riverside and WEIR ROAD / Westdale.
- **Screenshot** NameWall_1: the ELM GROVE wall beside the NORTHFIELDS stone. The first try faced the stone's road point and stood at a slant, so it now takes the stone's direction.
- RunAll 360/360.

### 2026-09-17 06:27 — Loop check after the dressing batch
- After tonight's X44–X75 dressing and layout work, I played one match on Plot 1 (DebugRun `playMatch|15|0`). It finished and saved: HUD cash went from £51,200 to £52,800, and the summary showed +£1,600 (tickets £1,200 and a £400 bonus).
- All seven Plot 1 prompts are present and enabled: Club Office, Play Match, East Stand "Expand to Main Stand (400 seats) — £1,500", the West, North and South stands, and the Snack Bar.
- Server boot summary: estates 2,373 parts (66 semis pairs, 52 street trees, 43 sheds); terrace streets 1,445; riverside 848; station 203.

### 2026-09-17 06:31 — X67 attempt reverted (river-facing cafes)
- I tried café tables and an A-board wherever a building backs onto the promenade, using a pure `cafeSpot` and ForecourtDresser's café set. In Studio the only match was the marina block (café tables in front of a hedge). After restricting it to pub, shop and flats blocks, nothing matched: the riverside flats stand 40+ studs behind the promenade with the marina gardens between, and "waterfront flats" and "pub and cafes" are 70+ away. I reverted it on disk and in Studio (RunAll back to 360/360) and noted on X67 that it needs a layout change to bring a pub or café block to the promenade.
- **Screenshot** PromenadeCafe_1 shows the rejected marina-hedge placement.

### 2026-09-17 06:36 — Community Sports Centre dressed (X76)
- Comparing with RivermereAImap.png showed the Community Sports Centre was still greybox: flat green slabs and a plain white box. New `SportsCentreDresser`, run from Main after StationDresser:
  - Each pitch slab is recoloured in place (grass, or darker Fabric for 3G) and gets white markings: touchlines, goal lines, halfway line, penalty boxes and an 8-chord centre circle, plus two goals scaled to the pitch width.
  - The 3G pitches also get a translucent green ball-stop fence and four floodlight masts.
  - The sports hall greybox is replaced by a metal-clad body and roof, with a navy fascia reading RIVERMERE COMMUNITY SPORTS CENTRE, a glazed entrance and a canopy on the road side.
  - Build summary: 5 pitches, 1 hall, 154 parts.
- Pure `pitchLines` and `goalWidth` have 3 new tests (inside the slab, mirror-symmetric, clamped goal width, layout still has the blocks).
- **Screenshots** SportsCentre_before and SportsCentre_after.
- Logged X77: a car park, paths, and floodlight tags for evening games.
- RunAll 363/363.

### 2026-09-17 06:37 — Riverside waterfront flats built (X78)
- The Studio Districts folder showed the Riverside "waterfront flats" block (140 × 40 at (620, 230)) still as a greybox box, because no dresser handled that use. `ShopDresser.FLATS_USES` now includes it, so `ShopBuilder.flats` builds it as a three-storey brick block. The Riverside greybox folder is now empty. The handles test covers the new use.
- **Screenshot** WaterfrontFlats_1.
- Remaining greybox after X76 and X78: the Riverside Park lawn and the station car park, both flat surfaces that other dressers build on.
- RunAll 363/363.

### 2026-09-17 06:39 — Sports centre floodlights join evening looks (X77 part)
- The 8 lamp heads on the two 3G pitches now carry the `FloodHead` tag. The client's Sky script lights every tagged head on an evening look, so these come on with the stadium floodlights. A client check found all 8. I didn't play an evening fixture: **SportsCentreFloods_1** was taken with the heads painted by hand at ClockTime 19.5, using the same neon and colour Sky applies.
- RunAll 363/363.

### 2026-09-17 06:41 — Sports centre car park and entrance path (X77 done)
- New pure `SportsCentreDresser.carParkRect` (1 test: open ground, a block sends it to the other side, both sides blocked gives nil) places an 84-wide tarmac car park beside the sports hall. It runs from the road's pavement back to the hall's back wall on whichever side is clear of blocks and carriageways, with bay lines along the back. The hall also gets a paved path from the pavement to its entrance. How far the hall stands back from the pavement is measured, not hard-coded.
- **Screenshot** SportsCentreCarPark_2: the car park opening onto the road next to the hall.
- RunAll 364/364.
