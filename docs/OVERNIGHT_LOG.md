# Overnight Log

## Morning handoff (kept current)

**What to look at:** Press Play in Studio. You get a club plot automatically (picker is on its way),
spawn in your office, and your ground now sits on a town plot (Plot 1, south-east, rotated). The
other three plots are "FOR SALE" lots. Play a match: evening fixtures (every 4th match from match 3)
go floodlit; after the summary, click "Back to Club" to see the week fast-forward. Open CLUB OFFICE to
see the menu depth of field. (MCP screenshots can't be written to disk, so none are saved in
`assets/screenshots/overnight/`; camera spots are listed in the entries.)

**Done:** client-side sky + evening fixtures + fast-forward (A1, A2), depth of field (A3), clubs as
plots with per-plot services (B1, B2 server side, B2.3 despawn, B4.1 for-sale lot), save lock (B3),
town master plan + layout data (C1), KitPlacer (D4.1), free-asset research (D1.1) + 3 store keepers
in `ServerStorage.Kit.Town`.
**Half-done:** plot picker, town greybox builder, plot surroundings (subagents drafting).
**Reverted:** none.

**Known bugs**
1. Studio playtests use your real DataStore club (the place is published). Agent tests added matches, cash and one North-stand level to it.
2. Studio holds condensed copies of the new modules (comments trimmed). Reconnect Rojo to overwrite them from disk.
3. Season-end fast-forward is wired but not playtested.

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

### 2026-09-17 01:20 — Bus fast travel (E7.2), performance baseline (C3.1)
- Bus stops (subagent): each stop's sign has a "Catch the bus" prompt; the RIVERMERE BUSES card lists clubs first (owner's club name, or "Plot N (for sale)") then town stops; picking one closes the iris and moves the player 5 studs in front of that shelter. Server checks the player is within 20 of a stop and a 3 s cooldown. Tested: prompt at Town Centre → card with 10 destinations → Industrial Estate → character moved to (-1600, 3, -135).
- Performance baseline (Studio PC, not a phone): StreamingEnabled already on. Town 2,850 parts (roads 200, bridges 34, rail 66, district greybox 126, bus stops 66, Mill Street dressing 2,350). One claimed club ~2,970 parts without crowd (stands 1,677 at Marcel's levels, team bus 587, grounds 254, floodlights 116, pitch 124); crowd adds up to ~3,300 at full house. VerticalSlice 1,565. Client at plot 1 sees 5,740 parts, 60 fps. Heaviest wins: team bus (X14), kit terraces/lamps (X12/X13), crowd budget with 4 clubs.
