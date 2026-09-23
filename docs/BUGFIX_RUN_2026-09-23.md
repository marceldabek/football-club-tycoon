# Bug-fix run — 2026-09-23 (playtest 0.1.1)

Ten lanes on five stations fixed every playtest item that needed no input from Marcel. The first pass
had 3 Opus lanes and 7 Sonnet lanes, and an Opus audit then re-checked and fixed each Sonnet lane.
Everything is merged on branch **`bugs/2026-09-23`** (not `master`).

- **Merged build:** RunAll 932 passed, 0 failed (baseline 885). `free_globals.py` is clean.
- **Play test (Studio 1):** claim plot 1, play a match (won 2-1, +£1,730), build the West stand to level 2,
  with no `failed to start` and no script errors.
- **Per-lane reports** (full detail, commit SHAs) were written during the run to
  `.claude/worktrees/_reports/` (git-ignored).

## What landed

| Playtest # | Lane | Status |
|---|---|---|
| 15 (P10), 12, 13 + 20 (P11), 21 | A1 ground structure | done: `GroundEnvelope` wall and gates, NW/SW turnstile blocks, huts, forecourt, statue/memorial garden, end stairs + rails, rear gates/vomitories (`StandAccess`), low wall, masts at (±140, ±200), concession window gone |
| 7, 14, 10, 11, 23a, 22 | A2 routes (audited) | done: `ConcourseLayout` catering tiers (burger van, kiosks, undercroft counters, fan zone), fans queue at the turnstiles and leave via the exits/loop and vanish only at the street/car park, coach-bay path, academy path + door, `GroundsPlanting.ZONES` |
| 6a-c, 9a-b, 35 | C NPC avatars | done: one Townsfolk avatar pipeline, stand fans built on the client from `CrowdSeats`, off the aisles, no clipping, walk/idle cycles, no floating or yellow-rig pedestrians |
| 18a, d, e/19d, f, h | E scout cards (audited) | done: generated flag icon set, hair fixed, kit-shirted torso (keeper shirt), 3D flip + hover/press, pack sounds. 18g skipped (needs a design call) |
| 2, 41 | B night lighting (audited) | done: SpotLight rig over the pitch on evening matches, glowing lenses on every street lamp with real lights on the nearest (Quality budget) |
| 8, 25, 36, 37, 38 | F vehicles (audited) | done: generated coach in the coach bay, TV van + dish in the media bay, train model, station car park link, per-kit car size fix |
| 30, 32, 34 | G town buildings | done: merged flats/parade meshes with windows all round, windows on every back and gable, generated parish church (always loaded) |
| 16, 28, 29, 31, 39 | H town streets (audited) | done: Supporters' Bar on town land opposite each gate, garden and street trees, roundabout oak, front paths, paved industrial yards with props scattered and the forklift sized |
| 27, 33 | I streaming (audited) | done: every town building gets a far stand-in (`TownStandIns`), landmarks always loaded. StreamingTargetRadius left alone |
| P9 | J club buildings spec (audited) | done: level tables + floor plans for all 7 buildings in `docs/CLUB_BUILDINGS.md` / `docs/club_buildings/` |

Not started (they need Marcel's input first): #17 away economy, #42 scooter, #43 monetization, #44 Robux cash button,
#18g squad comparison, #23b athletic-centre interior (waits for P9 answers), #5 stand over the clubhouse, and
the Club Map GUI.

## Must do before this ships

1. **Assets live in the station place files, not the main place.** Generated meshes were installed into
   each station's local `.rbxl`: the concourse props (st1, `tools/kit/install_concourse.luau`); the
   coach, satellite dish, train carriage and ClientKit van (st3, ids in `assets/kit/_export`); the church
   (st4, `install_church.luau`); and the merged flats/parade units (st4, `install_house_units.luau`).
   Without them the code falls back to primitives. **Save all four station Studios now (Ctrl+S, local files).**
   Then install them into the published place: run the install scripts in Edit, or copy the Kit folders
   across Studio windows.
2. **Turn "Enable Studio Access to API Services" back on** (Game Settings → Security). It was switched off
   so the stations' Play tests couldn't kick each other through the save lock.
3. **Streaming stand-ins (#27)** only prove themselves on the published game: from Plot 1's car park,
   look toward the church on a mid-range phone.
4. **Listen to the pack sounds** (#18h). Nobody could hear them, and the flip sound is an older Creator
   Store clip.
5. **Phone frame-rate check** (High): a Tier B semis street (garden trees), a full level-4 ground (fans
   + stairs + ~600 new ground parts), and an evening match (8 SpotLights + street lamps).

## Questions for Marcel (numbered, with a recommendation)

**Ground (A1/A2)**
1. Free-utility tier (turnstile lanes, toilets) = the best stand's map tier (TEMP). **Rec:** keep it; tier 4 = any corner stand once they exist.
2. Ground wall 8 studs high (TEMP). **Rec:** keep it; lower lets players hop into the ticketed ground.
3. End stairs are full-depth (the spec said 12), with rails instead of stairs at the west wings' clubhouse ends. **Rec:** accept (the maps are regenerated to match).
4. Level-2 "rear gates" are built the same as level-3 vomitories. **Rec:** keep; add iron gate leaves in a polish pass.
5. Catering = the amenity track (Nothing / Snack Bar / Merch Stand / Fan Zone → catering tiers 0-3, TEMP). **Rec:** keep; every purchase now changes the concourse visibly.
6. A covered stand serves from counters in its back wall from catering tier 2 (the spec said undercroft only at tier 3). **Rec:** accept and update spec §4.
7. The athletic-centre path in the spec crosses training pitch 2. **Rec:** door on the east wall, path down the 8-stud strip x 330..338 (same answer as J's Q15).
8. #23 "athletic centre" = today's academy hut (it got the door and the path). **Rec:** yes, until the cabin/athletic centre track is built.

**Crowd and avatars (C)**
9. Stand fans: 420 on High, 160 on Low (a sell-out looks thinner than the old 660 blocks). **Rec:** test on a phone; raise High to 480 if it holds.
10. Scarves/hats on stand fans? **Rec:** later, one Roblox-made scarf accessory, not a Part.
11. Move the park picnickers, KickAbout kids and pub drinkers to Townsfolk avatars too. **Rec:** yes, small follow-up.

**Cards (E)**
12. Prospects wear your club kit on their cards (TEMP, like the mockup). **Rec:** keep.
13. Fixed green keeper kit. **Rec:** keep for MVP; add a clash rule (orange when the club is green) later.

**Lights and vehicles (B/F)**
14. Club banners hang flush on the town lamp posts. **Rec:** keep.
15. Shorter lamp-lens radius on Low? **Rec:** not until a phone test.
16. Team coach keeps its white/blue livery. **Rec:** add a club-crest decal on each side (2 parts).
17. Coach length 34 in the 36-stud bay. **Rec:** keep.
18. The station car park link is a dressed stub, not a layout road. **Rec:** keep.
19. Make KitPlacer's relative scale the default (fixes stored-scale props like the forklift, bus, boats). **Rec:** yes, as its own small change.

**Town (G/H/I)**
20. Church mesh A (in use, parish tower + broach spire) vs B (taller needle spire). **Rec:** keep A.
21. Real door leaves on the flats and parades. **Rec:** yes, small follow-up.
22. Tree densities (751 garden trees, 234 street trees, TEMP). **Rec:** keep; halve the front-garden rate if a phone struggles.
23. Supporters' Bar is the kit house + pub dressing. **Rec:** accept; bake a proper pub front later like the terraces.
24. Paths stop 1-2 studs short at cul-de-sac heads. **Rec:** leave it.
25. Far stand-ins for trees and roads too? **Rec:** not until you've seen the published game.
26. What is Workspace.StreamingTargetRadius set to (scripts can't read it)? **Rec:** leave at 1024.

**Club buildings spec (J), full text in `docs/CLUB_BUILDINGS.md`**
27. Academy slot runs south to z 96 so today's hut never moves. **Rec:** yes.
28. About 23% of academy graduates are wonderkids. **Rec:** measure with a seeded test, then lower the base roll.
29. Beta save migration when buildings become bought tracks. **Rec:** one-time migration from the current fields.
30. Catering tiers vs the 4 amenity rows. **Rec:** split tier 3 into Undercroft Bars + Fan Zone.
31. Dressing rooms: home room only, home matches only, flat +1/+2/+3. **Rec:** yes.
32. First coach £1,800 / first scout £2,100 once they're gated behind buildings. **Rec:** accept with cabin £1,000 and scouting room £1,500 (TEMP).
33. Club Map row order. **Rec:** cabin at spawn, shop after match 1, office after the first purchase, scouting room with the cabin, concourse with the first Main Stand, academy with pitch 2, dressing rooms last.

## Known bugs (not fixed)

1. The churchyard yews don't fit beside the new church mesh (14 parts instead of 30); players can't enter the church.
2. Parade fronts (not backs) are still module-built, so faint seams can show. House_03 back windows show faint module edges up close.
3. #31: 61 of 2,738 front paths don't quite reach the paving (cul-de-sac heads, blunt terrace ends).
4. One industrial-estate street tree stands on a pavement corner (junction clearance uses raw polylines).
5. Stand-ins are plain boxes; roads, trees, park and riverside still vanish past the streaming radius.
6. StationDresser and EstateDresser lamp banners look in a dead folder, so they find nothing. The sports-centre floodlights only glow.
7. The evening floodlight rig lights for every player while that club's evening match runs, even players still on the afternoon look.
8. About 3 of the 12 avatar variants are bald, and some fixed spawns always get one. The first crowd of a session can take up to ~8 s to appear.
9. TownLife pub drinkers, park picnickers and KickAbout kids are still block figures (question 11).
10. MatchSummary development cards dress a GK in the outfield kit (no role field there).
11. Leaving crowds stay up to 110-150 s after the whistle (by design, so nobody vanishes mid-plot).
12. The end stairs' outer face is bare concrete; vomitories have no gate leaves or signs; the disabled platforms (spec §3) aren't built. At L4, the corner stands must absorb the end stairs.
13. The spec's big screen, if built at its spec position, sits on the north concourse lane (the route test will catch it).
14. Debug path only: after `DebugRun claim` the plot picker stays open, and `expandStand` via debug sometimes doesn't charge.
15. #18f touch press feedback is code-reviewed only (the MCP can only drive a mouse).
