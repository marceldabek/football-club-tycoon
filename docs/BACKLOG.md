# Backlog — Rivermere shared town

> Built 2026-09-17 by the overnight lead agent from CLAUDE.md s27, `docs/WORLD_ROADMAP.md` (A–J),
> `docs/SLICE_PLAN.md`, `docs/SLICE_REVIEW.md` and the reference images in `assets/references/`.
> Tags: `[studio]` needs Studio to build or verify, `[disk]` code/data/docs/research only.
> Size: S < 30 min, M < 2 h, L = split it. `dep:` lists what must land first.
> Tick with `[x]`. Add new items at the end of the right phase; never delete, strike through instead.

## TEMP world frame (so every item agrees)

- Town centre (market square) at world **(0, 0, 0)**; +X east, +Z south; 2.75 studs per metre.
- Town extent TEMP: x −2400..2400, z −1700..1700. `Workspace.VerticalSlice` stays where it is
  (3000, 0, 2000), outside the town, as the style reference.
- 4 club plots on the town edge (layout data in `src/shared/TownLayout.luau`), each a TEMP
  **760 × 760** square in its own local frame: pitch centre at the plot origin, +X local = away from
  the main road. Plot 1 SE, Plot 2 NE, Plot 3 E, Plot 4 NW (numbering follows the concept map).

## Phase 0 — Setup
- [x] 0.1 Branch `overnight/2026-09-17`, Studio connected, baseline tests (76 pass) `[studio]` S
- [x] 0.2 Write this backlog `[disk]` S

## Phase A — Look & time
- [x] A1.1 Lighting moves to a client controller (`src/client/Sky.client.luau` + pure `src/shared/DayCycle.luau` presets); server `Scenery` no longer sets Lighting/ClockTime; hero afternoon look; floodlight on/off stays server (visible to all) `[studio]` M dep: DayCycle
- [x] A1.2 `DayCycle` pure module: named presets (hero afternoon, evening match, dusk, night, dawn, overcast), `lerp(a,b,t)`, `fastForward(kind)` keyframe track (short ~4 s, season ~10 s), with tests `[disk]` S
- [x] A1.3 Evening fixtures: TEMP 1 in 4 league matches is an evening kick-off (seeded by fixture index), match-start event carries `evening=true`; client tweens to the evening preset, floodlights on `[studio]` S dep: A1.1
- [x] A2.1 Post-match fast-forward: after the summary closes, client plays the ~4 s sweep (sun → sunset → lights → night → morning → hero afternoon); tap/click or key to skip `[studio]` S dep: A1.1
- [x] A2.2 (server season rollover verified 02:23 on the Studio store: two seasons, stayed then promoted; the client 10 s sweep itself not watched) Season-end long fast-forward (~10 s) hooked to the season rollover `[studio]` S dep: A2.1
- [x] A3.1 DepthOfField hooks: on for club panel / lineup board / intro, off otherwise `[studio]` S dep: A1.1
- [ ] A1.4 (blocked: the MCP screen_capture returns images to the agent only, and a desktop grab of the Studio window shows a stale, stretched viewport while it is not focused; the "before" look is also gone) Before/after screenshots of the hero look saved in `assets/screenshots/overnight/` `[studio]` S

## Phase B — Clubs become plots
- [x] B1.1 `PlotRegistry` pure module: 4 plots, `claim(userId, plot)`, `release(userId)`, `freePlots()`, `plotOf(userId)`, picker cycling `next/prev` over free plots, with tests `[disk]` S
- [x] B1.2 Plot-relative club: `WorldBuilder` builds the club into `workspace.Plots.PlotN.Club` then pivots it to the plot CFrame; everything that used world coordinates (presenter, crowd, cameras, spawn, scoreboard) goes through the plot CFrame; test at an offset **and** rotated plot; loop still works `[studio]` L → split:
  - [x] B1.2a Server builds the club at plot 1's CFrame (offset, no rotation); spawn, prompts, crowd OK `[studio]` M
  - [x] B1.2b Client presenter/camera/footballers read the plot CFrame attribute and transform Pitch coords `[studio]` M
  - [x] B1.2c Rotated plot (90°) passes a full match visually `[studio]` S
- [~] B2.1 Per-club services: each owner gets their own ClubState folder (`ReplicatedStorage.Clubs.<userId>`), match, upgrades, season, history, save; server remotes route by player; clients read `player:GetAttribute("ClubFolder")` `[studio]` L → split:
  - [x] B2.1a Design note `docs/PLOTS.md`: how services become per-club (module instancing vs context tables), remotes routing, what stays global `[disk]` S
  - [x] B2.1b Server: per-club service instances, save per player, loop works for one player `[studio]` M
  - [x] B2.1c Clients bind to their own club folder; visitors see other clubs read-only `[studio]` M
  - [ ] B2.1d Two-client Studio test (Players = 2): both play a match at the same time `[studio]` M
- [x] B2.2 Plot picker on load: camera flies between free plots (for-sale lots), Prev / Next / Choose buttons; choosing claims the plot, builds the club, spawns the player in their office `[studio]` M dep: B1.1, B2.1b
- [x] B2.3 Despawn on leave: flush save, destroy the club model, release the plot, rebuild the for-sale lot `[studio]` S dep: B2.1b
- [x] B3.1 Save lock: session lock record (`lockedBy jobId`, `lockedAt`), new server waits (bounded, TEMP 30 s) then steals a stale lock; old server closes on a newer lock; pure lock logic tested against the memory backend `[disk]` M
- [x] B3.2 Wire the lock into load/flush/leave; Studio memory-backend test `[studio]` S dep: B3.1, B2.1b
- [x] B4.1 For-sale lot: grass pad, "FOR SALE — Rivermere Borough Council" sign, a few trees and rocks, low fence posts; built from code per free plot `[studio]` S
- [x] B4.2 "Go to my club" HUD button: teleports the character to their office spawn (cooldown TEMP 5 s, blocked mid-match? no — allowed) `[studio]` S dep: B2.1c

## Phase C — Town greybox
- [x] C1.1 `docs/TOWN_PLAN.md`: master plan from `RivermereAImap.png` scaled down (TEMP numbers): ring road + roundabouts, River Lune W→E with 3 road bridges, railway NW with station + viaduct over the river, town centre market square, Northfields (N), Westdale (SW), Riverside + Riverside Park (E), industrial estate (W), community sports centre (S), 4 plot sites, walking times `[disk]` M
- [x] C1.2 `src/shared/TownLayout.luau` layout data (roads as polylines with widths, river polyline, bridges, rail line, district blocks, plot CFrames, bus stops, landmarks) + `TownLayoutTest` (plots don't overlap roads/river/each other, every plot touches the ring road, bridges cross the river) `[disk]` M dep: C1.1
- [x] C2.1 `src/server/TownBuilder.luau` greybox: terrain ground, river carved with water, roads (asphalt parts per segment), pavements, bridges, rail line + embankment, district building volumes (grey blocks), plot pads `[studio]` M dep: C1.2
- [x] C2.2 (estimated, not timed on foot: square to plots 2.1–2.9k studs by road, 2.2–3 min walking / 70–100 s sprinting; spire seen from the marina and the square) Walk test: spawn → centre → each plot, timings logged; sightlines to spire/viaduct screenshot `[studio]` S dep: C2.1
- [x] C3.1 (baseline numbers in the log; StreamingEnabled was already on) StreamingEnabled on (place setting via code check + note), models grouped per district with `ModelStreamingMode`, part/triangle counts per district logged `[studio]` S dep: C2.1
- [x] C3.2 Quality setting (Low/High) client toggle: hides decorative props and far detail on Low `[studio]` M dep: C3.1

## Phase D — Kit
- [x] D1.1 Free-model hunt (Creator Store via lead, CC0 via subagent): terraced houses, shopfronts, lamp posts, bus shelter, benches, bins, planters, railings, trees, cars, station and industrial pieces; shortlist with ids/links/licence in `docs/FREE_ASSETS.md` `[disk]` M
- [x] D1.2 Insert + strip + log keepers into `ServerStorage.Kit` and `assets/kit/MANIFEST.md` `[studio]` M dep: D1.1
- [x] D4.1 `src/server/KitPlacer.luau`: place a kit model by name at a CFrame with ground snap, random yaw/colour variant within rules, primitive fallback when the kit model is missing (fresh clone of repo still builds) `[disk]` S

## Phase E — Districts (terraced streets first, per Q4)
- [x] E3.1 Terraced street 1 beside the town centre: 12 houses (MEH kit), front walls, pavements, lamp posts, bins, parked cars; layout data + builder; reference `RiveremereWestdale.png`/`RivermereNorthfields.png` `[studio]` M dep: C2.1, D4.1
- [x] E3.2 Terraced street 2 + back alley with wheelie bins and garden walls `[studio]` M dep: E3.1
- [x] E1.1 Market square: round paved square, market stall ring, monument/clock, benches, planters, bunting; reference `RivermereCenter.png` `[studio]` M dep: C2.1
- [x] E2.1 (no A-boards yet, X23) High street frontage: red-brick shops with ground-floor shopfronts (bakery, grocer, café, pub, barbers), flats above, A-boards, club banners on lamp posts; reference `RivermereCenter.png` `[studio]` L
- [x] E6.1 River Lune banks, stone road bridge (multi-arch), riverside path with railings and benches; reference `RivermereRiverside.png` `[studio]` M dep: C2.1
- [x] E7.1 (frontage, platform, footbridge, viaduct arches; car park path not done) Station: platform, canopy, station building, footbridge, car park; railway viaduct over the river; reference `RivermereStation.png` `[studio]` M dep: C2.1
- [x] E7.2 Bus stops: shelter + flag at centre, station, each plot, park; bus-stop fast-travel UI (pick a destination → fade → teleport) `[studio]` M dep: C2.1
- [x] E9.1 Church with spire (landmark) near the centre, visible from every plot `[studio]` S dep: C2.1
- [x] E5.1 Industrial estate greybox → sheds, yards, fences, loading bays; reference `rivermer.industrialestate.png` `[studio]` M
- [x] E8.1 Plot surroundings: approach road, car park, club shop box, two training pitches per plot; reference `RivermereTurnstileEntrance.png` `[studio]` M dep: B1.2a, C2.1
- [x] E6.2 Riverside Park: paths, pond, playground, trees, bandstand `[studio]` M
- [x] E4.1 (semis; flats are ShopBuilder.flats) Northfields semis and small flats `[studio]` M
- [x] E9.2 Backdrop: hills, wind turbines, distant floodlights, low detail `[studio]` S
- [x] E10.1 (road patches, faded dashes, give-ways, weeds, bins, cones, skip, posters; 900 parts) Imperfection pass: patches, faded markings, weeds, posters, clutter `[studio]` M

## Phase F — Life & sound
- [x] F1.1 Ambient audio zones (town, river, station, park) from the Roblox library `[studio]` M
- [x] F2.1 Client-side traffic on road polylines, distance-budgeted `[studio]` M
- [x] F3.1 Client-side pedestrians on pavements, distance-budgeted `[studio]` M
- [x] F4.1 (turbines, square flags, chimney smoke) Small motion: flags, bunting sway, chimney smoke `[studio]` S

## Phase G/H — Matchday town & influence
- [x] G1.1 Matchday around a plot (all players): fans walking to the ground, stewards, barriers; fades after `[studio]` M dep: B2.1c
- [x] G2.1 (bunting and 10 pub drinkers verified in a match) Matchday town for the playing player only: banners on lamp posts, busy pub `[studio]` M
- [x] H1.1 Club identity banners in town (client-side, player's own club colours/name) `[studio]` S
- [x] H2.1 Club shop building on the plot (visual) `[studio]` S dep: E8.1
- [x] H3.1 Training pitches on the plot (visual) `[studio]` S dep: E8.1

## Phase I — Social (after B2)
- [x] I1.1 (card, not a board: View club prompt on the office computer) Visit a club: walk into another plot's office, read-only squad board + club card `[studio]` M
- [x] I2.1 (within TEMP 220 studs of their pitch centre; no scoreboard for spectators yet) Watch another club's match from their stands `[studio]` M
- [~] I3.1 Local friendly: challenge/accept, no injuries, small home payout, no league effect `[studio]` L → split:
  - [x] I3.1a Pure `Friendly` invite book (challenge/respond/expire/dropUser) + TEMP home payout, tests `[disk]` S
  - [x] I3.1b (DebugRun "friendly|20|3" plays one solo; remotes untested until I3.1d) Server `FriendlyService` (remotes, invites, calls the home plot's `MatchService.playFriendly(away)`: away squad + strength from the away plot, no league/injuries/development/W-D-L, TEMP payout) `[studio]` M
  - [x] I3.1c Client: "Challenge to a friendly" on the visitor club card, invite card with Accept/Decline for the other owner, FRIENDLY banner `[studio]` M
  - [ ] I3.1d Two-player friendly test (needs Players = 2) `[studio]` S
- [~] I4.1 Same-server player trades (cash only as part of a deal) `[studio]` L → split:
  - [x] I4.1a Pure `Trade` module: offer validation (a player must move, cash one way, affordability, squad min/max, keep a GK, max 3 each way), `move` with new ids + shirt numbers, offer book with expiry, tests `[disk]` S
  - [x] I4.1b (solo round trip via DebugRun "tradeRoundTrip|id"; remotes untested until I4.1d) Server `TradeService`: propose/respond remotes, re-validate on accept with both clubs in Manage, apply to both ClubServices + cash, save both, toasts `[studio]` M
  - [x] I4.1c Client trade screen from the visitor club card (both squads, pick up to 3 each way, cash either way) + offer card with Accept/Decline `[studio]` M
  - [ ] I4.1d Two-player trade test (needs Players = 2) `[studio]` S

## Phase J — Online
- Blocked until the J0 design talk (Q35). Nothing to do overnight.

## Bugs / follow-ups found while working
(append here)
- [x] X1 (TEMP Config.Save.studioStoreSuffix, question 1) Test matches in Studio write to Marcel's real DataStore save (place is published): prefer a Studio-only save key prefix (e.g. `studio_u<id>`) so agent playtests never touch the live club `[disk]` S
- [x] X2 (tag FloodHead; 72 heads lit in an evening match) `Sky.setFloodHeads` scans all of workspace; tag floodlight heads with CollectionService instead once the town is big `[disk]` S
- [x] X3 (kicked mid-match: saved, match loop finished, runtime removed, Plot1 back to Lot, no errors) A player who leaves mid-match: the old club copy finishes the match loop before the plot frees (up to 180 s); check no errors in that path `[studio]` S
- [x] X5 Districts are far too sparse next to `RivermereAImap.png`: add many more terraced rows / semis / shops so every block between roads is built up `[disk]` M
- [x] X6 Plot access lanes in TownLayout end at local z≈0 but the PlotGrounds vehicle gate is at local z 60..100: align the lane end with the gate `[disk]` S
- [x] X7 Picker viewpoint is too high and hazy; lower/closer view onto the FOR SALE board; reduce Atmosphere density for town scale (HeroAfternoon 0.32 hides anything past ~600 studs) `[studio]` S
- [x] X8 Town edge: terrain stops dead at x ±2800 / z ±2200; needs a backdrop (hills, tree belt) `[studio]` M
- [x] X9 (halved to 100x150) Car park (100 × 300) dominates the plot entrance; halve it or turn it `[disk]` S
- [ ] X10 (03:57 desktop: no flicker seen over the High Street and Bridge Street from 45 up; still needs a real phone) Roads z-fight risk: overlapping tops only 0.004–0.01 apart; check at distance on a mid phone `[studio]` S
- [x] X11 (TerraceStreetDresser: trees, walls/railings/hedges, street signs, kerb cars; Mill/Weaver full detail) Mill Street vs `RiveremereWestdale.png`: add street trees, front garden walls/railings + hedges, club banners on lamp posts, street name signs, cars on both kerbs `[studio]` M
- [x] X12 Low-part terrace row (≤ 25 parts: body, roof wedges, chimney stacks, door/window decals) so every terraced block in town can be dressed within the mobile budget `[disk]` M
- [x] X13 Kit lamp is 36 parts: build a ≤ 6-part Victorian lamp for town-wide use `[disk]` S
- [x] X14 TeamBus (Assets "Bus") is 587 parts per club; swap for a low-part coach or drop it `[studio]` S
- [x] X15 (card sized to screen; click-tested 03:06: Station button at the bottom of the list travels) Bus menu: clicking a destination scrolled out of view did nothing in the test; check ScrollingFrame input and make the card taller on desktop `[studio]` S
- [x] X16 Backdrop fields read as flat plastic slabs: use Grass/Ground materials with a texture, hedges on all four sides and taller, more tree clumps along hedges `[studio]` S
- [x] X17 Market square is an island in grass: pave the gap to the shop blocks, add a pedestrian zone and café seating (RivermereCenter.png) `[studio]` M
- [x] X18 (paved quay + pontoons + boats + riverside gardens) Marina block is a flat light-blue plastic slab on the grass; make it a water basin (carve terrain) or a paved quay with the boats; fill the grass between the riverside flats and the promenade (gardens, trees, paths) `[studio]` S
- [x] X19 (stone arches, cutwaters, string course; arches only ~2 high because decks sit 2.7 above water, X31) Road bridges are plain decks; add stone arch spandrels/cutwaters so the Lune Bridge reads like RivermereRiverside.png `[studio]` M
- [x] X20 (platform, footbridge, viaduct arches; no path from the car park yet) Station: platform-side dressing (yellow edge, benches, railings, name boards), footbridge, viaduct over the Lune, path from the car park `[studio]` M
- [x] X21 Station roofline is a flat box; the reference has a pitched slate roof with a gable/clock over the entrance `[studio]` S
- [x] X22 (shops paved; semis get front paths, 56 back onto the pavement) Grass strip between the pavement and shop/semi fronts; pave the forecourt up to the building line `[studio]` S
- [x] X23 High street A-boards and hanging baskets in front of ShopBuilder rows (RivermereCenter.png) `[studio]` S
- [x] X24 (bunting seen in a match 01:58, turbines spin after streaming fix) Watch bunting during a real match and turbines spinning; TownLife is only verified for banners so far `[studio]` S
- [x] X25 (gable roof) Semis hip-end roof wedges look tall from some angles; check against RivermereNorthfields.png and consider a plain gable `[studio]` S
- [x] X26 Hanging baskets are oversized balls placed at row corners, some on side walls; smaller bracket baskets centred over bays `[studio]` S
- [x] X27 Café chairs are solid blocks; thin seat + back + legs, or a kit chair `[studio]` S
- [ ] X28 Quality Low hides decor via LocalTransparencyModifier; measure real phone fps Low vs High and consider streaming radius per level `[studio]` M
- [x] X29 Semis garden walls/hedges have no gate gap where the new front paths cross them `[studio]` S
- [x] X30 Semis: pairs abut into a continuous terrace and the garden hedge stands on the pavement; leave a side gap between pairs (driveway) and pull the front garden inside the block `[studio]` M
- [x] X31 (humped decks: 40-stud ramps climb 6 over the ends, level over the water; arches now ~6 above the water) Road bridges: raise the decks (ramps on the approaches) or lower the water so the stone arches read; currently ~2 studs of arch `[studio]` M
- [x] X32 Marina boats: the white bow wedges look detached/rotated at the moorings; check RiverDresser.buildBoat bow orientation `[studio]` S
- [x] X33 (kit hatchback scaled to the drive, min 0.7; only the 13 wide 10.2 drives qualify, the rest keep block cars: see X44) Semis driveway cars are plain blocks; use the kit hatchback (KitPlacer) with the block as fallback `[studio]` S
- [ ] X34 (03:55: `rojo serve` IS running on 34872 and serves the branch; the Studio plugin shows NetFail, and the MCP sandbox now lacks the Network capability so tools/studio-sync.luau cannot run from MCP. Needs Marcel to click Connect in the Rojo panel) Syncing merged branches into Studio by pasting source is the night's bottleneck; get Rojo reconnected (X4) before the next big batch `[studio]` S
- [x] X35 (the showpiece cost was mostly vans: VanWhite is 71 parts, 6 vans = 426; vans now 1 in 6 there, showpiece 1,013 -> 733, light streets 1 -> 3) TerraceStreetDresser: Mill/Weaver showpiece uses 1,013 of its 1,200 parts, so only 1 light street got dressed (26 skipped); thin the railing bars or raise the budget after a phone perf check `[studio]` S
- [x] X36 (TerraceStreets ParkedStreets attribute; Mill Street, Weaver Street, Church Lane) Traffic drives through kerb-parked cars on streets with cars on both kerbs (single shared lane or skip those streets) `[disk]` S
- [x] X37 (16 nearest lamps get a PointLight when ClockTime is dark; 6 on Low) Evening fixtures: town streets away from the ground are nearly black during an evening match (street lamps don't light); either brighten the evening look's ambient or make lamp heads Neon/PointLight in the evening for the local player `[studio]` S
- [x] X38 (pill under PLAY MATCH: "Watching  A 2 - 1 B  ·  60'"; crowd audio level still own-club based) Spectators (I2.1) get no scoreboard, club names or crowd audio level of the watched club; show a small "Watching: A 1–0 B, 63'" pill from the watched folder `[studio]` S
- [ ] X39 Spectating needs a real two-player check (B2.1d): the solo test faked a live match by cloning the club folder onto the Plot2 lot `[studio]` S
- [x] X40 (hint hides while the summary or season card is open) The bottom hint pill (e.g. "Fans were turned away...") sits on top of the match summary's Back to Club button (seen on the friendly summary, also true for league matches); hide hints while the summary or season card is open, or raise the card's DisplayOrder `[studio]` S
- [x] X41 (a WedgePart under each of 6 slices; 128 parts per bridge) Bridge arches are stepped slices; replace each slice bottom with a pair of wedges (or a curved mesh) so the arch reads as a smooth curve from a distance like RivermereRiverside.png `[studio]` S
- [x] X42 (overlap query over every deck piece found only road and pavement ends under the ramps, no lamps or props) Street lamps / banners on road bridges: check none stand on the old flat deck height now that the decks are humped (none seen on the Lune Bridge) `[studio]` S
- [x] X43 (STONE 210,184,140 / dark 184,158,118 / coping 226,208,172) Road bridge stone reads pale grey; warm it to the honey sandstone of RivermereRiverside.png `[studio]` S
- [ ] X44 Semis driveways are mostly 5.1 (76) or ~3 (30) studs wide, narrower than a character-scale car (street kit cars are 9.8 wide); a 0.35-scale kit car looked like a toy at knee height. Widen the drive gap (fewer pairs per row) or drop cars from narrow drives (question 7) `[disk]` S
- [ ] X45 Parked cars are nearly all the orange one-mesh hatchback now (Mill Street reads monotone); it is one MeshPart with a TextureID (Color does not tint it), so a second colour needs a recoloured copy of its texture uploaded with tools/upload_kit.py (needs the texture file; not downloaded overnight) or another cheap free car kit; HatchbackWhite is 153 parts `[studio]` S
- [x] X46 (post at the square rim east side, blades to Station, Riverside, Lune Bridge, Church Spire; 10 parts) Town centre finger-post sign like RivermereCenter.png, pointing at real places `[studio]` S
- [x] X47 (planter flowers 04:09, shelter adverts 04:10, 30 lamp baskets 04:14; trees moved to X48) RivermereCenter.png vs the square: street tree pits are bare concrete boxes (reference: stone planters full of flowers), few hanging baskets on lamp posts, bus shelter has no advert panel, trees are lollipops `[studio]` M
- [x] X48 (full-detail street trees and town-centre planter trees get offset lobes; light-street, park and backdrop trees unchanged) Street and planter trees are lollipops (trunk + 1-2 balls); RivermereCenter.png has loose, leafy crowns. Try 3-4 overlapping smaller balls at offsets per tree within the tree part budget `[studio]` S
- [x] X49 (white mullion + transom on every station window, stone sills on the ground floor) Station windows read as dark blank panels next to RivermereStation.png `[studio]` S
- [x] X50 (04:21 verge paved in 14 strips; 04:23 yellow rank line + TAXIS marking; the kiosk already existed at the west end) Station frontage vs RivermereStation.png: a grass strip separates Station Road's pavement from the paved forecourt (reference: paved to the kerb), no newsagent kiosk, no taxi-rank / BUS STOP road markings `[studio]` M
- [ ] X51 (04:24: lane extended 10 studs east; a grass gap to Station Road's diagonal end remains, Station_lane_1. Proper fix: add a TownLayout point so Station Road turns along the forecourt; affects traffic and TownLayoutTest) The station drop-off lane and taxi rank sit in grass with no road link `[disk]` S
- [x] X52 (brick piers with stone caps, iron gate leaves folded on the piers; club-colour fascia kept) Turnstile block is a plain club-colour box next to RivermereTurnstileEntrance.png `[studio]` S
- [ ] X53 (04:28 lane signs done: HOME FANS / TICKETS / HOME FANS; still open: boundary wall, lamp banner) Turnstile entrance vs RivermereTurnstileEntrance.png: no HOME SUPPORTERS / TICKETS lane signs, no brick boundary wall running off either side, no club banner on a lamp post outside `[studio]` S
- [x] X54 (navy totem on the verge by the Industrial Estate bus stop: RIVERMERE INDUSTRIAL ESTATE + Units 1-6 / 7-12 / Deliveries / Trade Counter) Industrial estate has no entrance sign like rivermer.industrialestate.png `[studio]` S
- [ ] X55 (04:37 unit numbers + brick plinths; 04:39 lorries in the 4 wide warehouse yards; still open: palisade fencing, forklifts, entrance mini roundabout) Industrial estate vs rivermer.industrialestate.png: sheds have no unit numbers or brick plinth courses, no palisade yard fencing with gates, no lorries / pallets / forklifts in the yards, no small roundabout with a planted island at the estate road entrance `[studio]` M
- [x] X56 (limestone name stones for Northfields, Westdale and Riverside on the verge by the block nearest the square) District name signs like the NORTHFIELDS stone in RivermereNorthfields.png `[studio]` S
- [ ] X57 (04:44 porch hoods done; still open: play area, garden flower borders) Northfields vs RivermereNorthfields.png: no play area with swings/slide and railings, no porch canopies over the semis' doors, flower borders in front gardens are bare lawn `[studio]` M
- [x] X58 (white flag with red BUS band, stop name and TEMP route numbers on both faces; a litter bin by each pole) Bus stop signs were a small red square with tiny text; RiveremereWestdale.png shows a UK bus stop flag `[studio]` S
- [ ] X59 (04:49 red pillar post boxes outside the 10 corner shops; still open: side-street dressing, school greybox) Westdale vs RiveremereWestdale.png: its streets have no trees, lamps, parked cars or garden railings (only Mill Street gets full dressing within the part budget), no corner shop (Westdale Stores) with a post box, and a large white civic greybox block stands in the housing `[studio]` M
- [ ] X4 Studio copies of new modules are condensed (comments trimmed); reconnect Rojo to overwrite them from disk `[studio]` S
