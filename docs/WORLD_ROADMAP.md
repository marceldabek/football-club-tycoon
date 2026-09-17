# World Roadmap — Sessions, Gaps & Open Questions

> Companion to [WORLD_VISION.md](WORLD_VISION.md). Written 2026-09-16.
> **Nothing here is decided until Marcel answers the questions in section 4.** Answered questions are marked **DECIDED**.
> Answer by number (e.g. "Q7: yes, your recommendation"; "Q12: option B, but …") — speech-to-text is fine.
> Each session below is sized to be one sitting: build it → test it in Studio → commit.

---

## 1. Where the game is today (why some of this is harder than it looks)

The current code was built for **one club alone in the world**. The town vision changes that in
places that matter:

| Today | What the town vision needs |
|---|---|
| One club per server; the first player to join owns it, everyone else is a read-only visitor (`Session.luau`) | 4–6 owners per server, each with their own session, save, match and plot |
| The pitch sits at the world origin; `WorldBuilder` builds everything around (0,0,0) | Each club builds at its own plot position and facing |
| `Scenery` sets **server** lighting and tweens to dusk during a match | Two players can be at different points in their day, so time of day must become **per player (client-side)** |
| Scenery is procedural code: hills, a "distant town" and trees | A real town built from an asset kit, mostly saved in the place file |
| All geometry is primitive Parts in code (in git) | Kit models live in the place file / `.rbxm` files; git can't diff them easily |
| No streaming; one small map | A dense town + 6 stadiums needs StreamingEnabled and a mobile part budget |
| Match = hidden sim + watch + Attack/Defend/Sub | PvP needs two humans controlling one match — "player skill" barely exists yet |

---

## 2. Gaps and logic problems found

These are problems the brief doesn't answer yet. Each one links to a question in section 4.

1. **Whose time is it?** In a shared server, player A may be mid-match at dusk while player B is
   managing at noon. Roblox `Lighting` is one value per server, but a client can override it
   locally. → Time of day, weather and fast-forwards should be client-side. (Q9, Q10)
2. **What does "time passing" mean?** Right now the game has matches, not days. A fast-forward
   needs a calendar model: does a match = a week? Is there anything to do between matches that
   uses days? (Q8)
3. **Whose matchday is it in town?** If three clubs have matches at different moments, the high
   street can't be "on matchday" for all of them. Options: matchday dressing only near that plot,
   or each client sees its own club's matchday. (Q21)
4. **Whose influence shows in the town?** "My club changed this place," but five other clubs share
   the place. Options: each plot has its own neighbourhood that reacts, or each player's client
   sees the town dressed for **their** club. (Q22)
5. **Plot size must be fixed now for the endgame.** A top-flight stadium + training ground + car
   park + club shop is much bigger than today's ground. If plots are too small, late-game stadiums
   won't fit. Today's club already reaches ~120 studs west of the wall line. (Q14, Q15)
6. **Empty plots.** With 1–3 players in a server, what fills the other plots? (Q16)
7. **Which plot is mine?** If you rejoin a different server, you get whatever plot is free. The
   town must not depend on a club always being in the same spot. (Q17)
8. **The save must be protected once clubs trade and teleport.** Trades between two players,
   teleports to match servers and joining a new server while an old one is still saving all need
   session locking. Otherwise duplicates and lost progress are real risks. (Q33)
9. **Trading is an exploit magnet.** An alt account can dump money or a star player into a main
   club. Needs limits (value caps, cooldowns, account age, no cash gifts?). (Q30, Q31)
10. **Online "skill" is undefined.** Outcomes today come mostly from squad strength plus
    Attack/Defend/Sub. MMR on top of that mostly measures squad strength, which the brief says not
    to do. PvP needs a real skill surface (tactics choices, timing, lineups, subs), or online stays
    casual. (Q35, Q36)
11. **Online rewards vs career economy.** If online wins pay career money, online becomes the best
    way to grind and bypasses career balance. (Q37)
12. **Friendlies: whose squad fitness, injuries, money?** (Q29)
13. **Asset kit sourcing.** Coherent British kits on the Creator Store are rare; many contain
    scripts (CLAUDE.md rule 9). Marketplace packs cost money. Commissioned or Blender work is
    slow. Today's stadium is procedural primitives, and a kit town next to it may clash in style.
    (Q23–Q27)
14. **Audio sourcing.** Roblox restricts audio to Roblox-uploaded or licensed library sounds, so
    each sound needs a source. (Q28)
15. **Mobile performance.** Traffic, pedestrians, crowd and a dense town all at once. Ambient life
    should run on the client, near the player only, with hard budgets. (Q18)
16. **Source of truth.** Rojo/git holds the code, but a hand-dressed town lives in the place file.
    We need a rule for what lives where so work isn't lost. (Q26)
17. **Scope vs CLAUDE.md.** CLAUDE.md lists multiplayer visits and big assets as *not* MVP, and says
    not to polish until the loop is fun. The town is a direction change; CLAUDE.md should be
    updated once confirmed. (Q1, Q2)
18. **Spawn and onboarding.** New players spawn at the office desk today. In a shared town, do they
    spawn at their office or in town? The first-5-minutes plan needs the first match reachable
    quickly even with a big town around it. (Q19)
19. **Getting around.** A dense town plus several plots may be a long walk. Sprint exists; is there
    fast travel, a bus, a map? (Q20)

---

## 3. Sessions (build order)

Each phase depends on the ones before it unless marked **(independent)**. Items marked **needs Q#**
can't start until those questions are answered.

### Phase A — Look & time (quick visible win, no multiplayer needed)

| # | Session | Delivers | Needs |
|---|---|---|---|
| A1 | **Lighting & grading pass** *(independent)* | Move lighting to a client controller; tune Atmosphere, ColorCorrection, Bloom, SunRays, shadows to the "blue-sky daytime" look; before/after screenshots | Q9, Q11 (Marcel sets `Lighting.Technology` by hand) |
| A2 | **Fast-forward transition** | Client plays sun sweep → sunset → lights on → night → morning (+ optional overcast/rain) between matches/seasons; skippable; ends on the daytime look | Q8, Q10, Q12 |
| A3 | **Cinematic depth-of-field hooks** | DoF only for menus, close-ups, match intro | Q13 |

### Phase B — Clubs become plots (the refactor everything else stands on)

| # | Session | Delivers | Needs |
|---|---|---|---|
| B1 | **Plot-relative club** | `WorldBuilder`/`Pitch` build at any plot CFrame; test the club at an offset and rotated; all 73 tests still pass; still one player | Q14 |
| B2 | **Multiple owners per server** | Replace the "first player owns the server" model with one session per player, plot assignment on join, plot release on leave, per-player save; test with 2 clients in Studio | Q2, Q16, Q17 |
| B3 | **Save locking & rejoin safety** | Session locks so the same club can't load in two servers; clean handover on leave or teleport | Q33 |
| B4 | **Empty-plot presentation** | Whatever fills unused plots (AI club / derelict ground / for-sale sign) | Q16 |

### Phase C — Town greybox (layout before art)

| # | Session | Delivers | Needs |
|---|---|---|---|
| C1 | **Town master plan doc** | Top-down map: districts, roads, river, elevation, plot sites, station, landmark sightlines, fan routes; you review it before anything is built | Q3–Q6, Q14, Q15 |
| C2 | **Greybox build** | Primitive blocks for roads and building volumes, terrain, river and plots; walkable; check scale, walking times and sightlines | C1 approved |
| C3 | **Performance baseline** | StreamingEnabled on, part/triangle budget per district, mobile test, numbers written down | Q18 |

### Phase D — Asset kit

| # | Session | Delivers | Needs |
|---|---|---|---|
| D1 | **Kit research** *(independent, no code)* | Shortlist of kits (store / paid / generated) with screenshots, style, script check, cost; you pick | Q23–Q25 |
| D2 | **Kit import & cleanup** | Strip scripts, fix pivots and scale (character ~5 studs), organise into `ServerStorage.Kit`, document ids in README | D1 pick |
| D3 | **Style test street** | One ~100-stud street fully dressed to lock the look (materials, density, lighting) before scaling up | A1, D2 |
| D4 | **Assembly & variation tools** | Scripts that place facade modules, vary colour/rotation within rules, avoid visible repeats, snap to the greybox | Q26 |

### Phase E — Districts (one session each, in the order you choose)

| # | Session | Delivers |
|---|---|---|
| E1 | Town square & centre core (square, monument/fountain, market stalls) |
| E2 | High street (shops, cafés, bakery, pub, barbers, takeaway, supermarket, flats above) |
| E3 | Terraced streets & alleys |
| E4 | Semi-detached houses & small apartment blocks |
| E5 | Industrial estate (warehouses, yards, loading bays) |
| E6 | Riverside, bridge & park |
| E7 | Train station, bus stops & car parks |
| E8 | Surroundings around each plot (where club and town meet) |
| E9 | Backdrop: hills, church spire, distant skyline, far floodlights (low detail) |
| E10 | **Imperfection pass**: road patches, faded markings, cracks, weeds, cables, dishes, posters, clutter scatter across all districts |

Needs Q4, Q5 for order and landmarks.

### Phase F — Life & sound

| # | Session | Delivers | Needs |
|---|---|---|---|
| F1 | **Ambient audio zones** | Town/café/pub/river/station/wind layers crossfading by position; church bell; distant crowd | Q28 |
| F2 | **Traffic** | Client-side cars and buses on road splines, stops at junctions, bus brakes; budgeted by distance | Q18 |
| F3 | **Pedestrians & cyclists** | Client-side walkers on pavement paths, café sitters | Q18 |
| F4 | **Small motion** | Flags, tree sway, birds, chimney smoke, shop doors, deliveries | — |

### Phase G — Matchday town

| # | Session | Delivers | Needs |
|---|---|---|---|
| G1 | **Matchday state around a plot** | Fans walking routes to the ground, queues, barriers, stewards, scarves/shirts, parked cars, extra traffic; fades after the match | Q21 |
| G2 | **Matchday atmosphere** | Pub crowds, banners, floodlights visible from town, chants carrying across town | Q21 |

### Phase H — The club changes the town

| # | Session | Delivers | Needs |
|---|---|---|---|
| H1 | **Club influence tiers** | Club progress → banners, murals, window scarves, stickers, bigger car park, media presence | Q22 |
| H2 | **Club shop building** | Physical shop that upgrades (merch revenue hook) | Q39 |
| H3 | **Training ground** | Physical training site on the plot that upgrades | Q39 |

### Phase I — Social in a shared town

| # | Session | Delivers | Needs |
|---|---|---|---|
| I1 | **Visit a club** | Read-only view of another club's office, stadium and squad board; club info card | B2 |
| I2 | **Watch their match** | Walk into a rival's stadium during their match and watch | B2 |
| I3 | **Local friendly** | Challenge → accept → both move to host stadium → play → no MMR | Q29 |
| I4 | **Trades & loans** | Offer/accept UI, server validation, anti-exploit limits, atomic save of both clubs | Q30–Q32, B3 |

### Phase J — Online

| # | Session | Delivers | Needs |
|---|---|---|---|
| J0 | **PvP design session** *(talk, no code)* | What each human controls in a 1v1 and what skill means | Q35, Q36 |
| J1 | **Queue & MMR** | MemoryStore queue, widening search, MMR storage | J0, Q34 |
| J2 | **Reserved match server & return** | Teleport both players in, play, teleport back to the previous town server (or a fallback) | B3 |
| J3 | **Rewards & leaderboards** | Online rewards kept separate from the career economy | Q37, Q38 |

### Suggested order

**A1 → B1 → B2 → B3 → C1 → C2 → D1 → D2 → D3 → C3 → E (by your priority) → F → A2 → G → H → I → J**

Why: A1 is cheap and makes everything after it look better. Plots (B) must exist before the town
layout can place them. Greybox (C) before art stops us dressing streets we later move. The style
test street (D3) locks consistency before we build ten districts. Online (J) comes last because it
needs a real PvP design and stable saves.

---

## 4. Open questions

Each has my recommendation so you can just say "agree" or give a different answer.

### Scope & priority
- **Q1.** Is the core loop (play → earn → upgrade) fun enough now to justify starting the town, or should some town work wait for more gameplay polish? *Rec: start A1 and B1 now (cheap and needed anyway); hold the big district work until you've done another fun check.*
  - **DECIDED (2026-09-16):** Town work has already started (another agent is building a town area similar to the concept art).
- **Q2.** Is the shared multi-club town (4–6 plots) confirmed, or still an idea? It forces Phase B, a big refactor. *Rec: confirm before B2; B1 is worth doing either way.*
  - **DECIDED (2026-09-16):** Confirmed. The game is multiplayer; the shared town is the direction. Phase B goes ahead.
- **Q3.** Name of the town/region? Is it the home town of all the player clubs, or just this map? *Rec: one fictional town name you pick; all plots are clubs "from" this town.*
  - **DECIDED (2026-09-16):** Town is **Rivermere** (from Marcel's concept art). Every player club is from Rivermere. The concept map's "Riverdale"/"River Dale" labels are wrong: the town is Rivermere, not Riverdale. River name: the **River Lune** (a real, calm-sounding English river), unless Marcel picks another.
- **Q4.** Which districts matter most, and in what order? *Rec: centre + high street, then terraces, riverside, station, industrial.*
  - **DECIDED (2026-09-16):** No strong preference. Start with a town district that uses the terraced houses we already have (terraced streets next to the town centre).
- **Q5.** Landmarks you definitely want (church spire, bridge, clock tower, viaduct, castle ruin, pier…)? *Rec: church spire + river bridge + railway viaduct as the three sightline anchors.*
  - **DECIDED (2026-09-16):** Church spire (definite), river bridge (definite), and a railway line cutting through town with a station (likely). Other landmarks not yet chosen.
- **Q6.** Is there a real British town you want as reference (like the Wham Stadium was for the ground)? *Rec: pick 1–2 real towns for photo reference only.*
  - **DECIDED (2026-09-16):** No real town. Reference is Marcel's AI concept art (four images, to be saved in `assets/references/town/`):
    1. **High street:** red-brick terraced shops (bakery, grocer, café, pub), navy club banners on lamp posts, bunting, A-boards, planters, double yellow lines, a bus stop, a church spire and hills with wind turbines in the distance.
    2. **Stadium frontage:** grey clad stand with a big crest sign, ticket office, numbered turnstiles, club shop, a player statue on a paved plaza with benches, bins and hedges, and a terraced street opposite.
    3. **Aerial:** stadium beside a river with a multi-arch bridge/viaduct, car park, training centre with pitches, a pub and club store on a corner, terraced rows, a church, a water tower and a community hub.
    4. **Town map:** river through the middle with 2–3 road bridges; railway and station on the north-west side; town centre with a round market square; Northfields and Westdale housing estates; industrial estate to the west; Riverside Park and a marina; a community sports centre; **four club grounds on the edges of town**, each with a car park and training pitches; ring road with roundabouts and exits to neighbouring towns.
- **Q7.** Should CLAUDE.md be updated to add the town/multiplayer direction and new milestones once you've answered these? *Rec: yes.*
  - **DECIDED (2026-09-16):** Yes. Update it once the question pass is finished.
- **Q2b.** The concept map shows 4 club grounds. Exactly 4 plots per server? *Rec: 4 — matches the map, cheaper on mobile, friendlier servers.*
  - **DECIDED (2026-09-16):** 4 plots per server for now.
- **Q3b.** The map is labelled "Riverdale" / "River Dale". *Rec: town = Rivermere, river = the River Dale.*
  - **DECIDED (2026-09-16):** Town is Rivermere; ignore "Riverdale"/"Dale" on the map. River = the River Lune (see Q3).
- **Q4b.** Use the concept map as the actual town plan (river + bridges, NW station, market-square centre, estates, industrial west, park/marina), scaled down? *Rec: yes — the art is ~3 km across, far too big to walk.*
  - **DECIDED (2026-09-16):** The concept map is the target idea: aim for a similar layout and feel, not an exact copy.
- **Q5b.** Also make the viaduct, water tower, hillside lettering or wind turbines landmarks? *Rec: viaduct carrying the railway over the river; turbines and hills as distant backdrop only.*
  - **DECIDED (2026-09-16):** Yes, the viaduct is a landmark (railway over the river).

### Time & lighting
- **Q8.** What does time mean in the game: 1 match = 1 week? Do days pass between matches, or is it purely visual? *Rec: 1 match = 1 week, visual only for now; no day-by-day mechanics.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation.
- **Q9.** Is time of day per player (client-side) in a shared town, as proposed? *Rec: yes.*
  - **DECIDED (2026-09-16):** Yes. Every player has their own client-side time of day.
- **Q10.** When does the fast-forward play: after every match, only at season end, or both (short vs long)? *Rec: short (~4 s) after every match, longer (~10 s) at season end; always skippable.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation.
- **Q11.** Should normal play be locked to one time of day, or drift slowly (morning → afternoon)? *Rec: locked to one "hero" afternoon.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation.
- **Q12.** Should matches stay at dusk with floodlights (like today) or be daytime? *Rec: vary — most matches afternoon; some evening fixtures under lights.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation.
- **Q13.** DepthOfField only in menus/close-ups/intro, as the brief says? *Rec: yes.*
  - **DECIDED (2026-09-16):** Yes.

### Map, plots & scale
- **Q14.** How big can the biggest endgame stadium get (e.g. 10k / 25k / 50k seats)? This sets plot size. *Rec: design plots for ~30k-seat equivalent, scaled for Roblox.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation (~30k-seat-equivalent endgame stadium, scaled for Roblox).
- **Q15.** What must fit on each plot: stadium, office, car park, training ground, club shop, fan zone? Or is the training ground elsewhere in town? *Rec: stadium + office + car park + shop on the plot; training grounds on the town edge.*
  - **DECIDED (2026-09-16):** Stadium, office, car park, club shop and a couple of training pitches beside the ground (as on the concept map). A bigger training centre can be a later upgrade on the same plot.
- **Q16.** Empty plots when fewer players are in the server? A) AI club ground B) derelict/for-sale site C) nothing/park. *Rec: B — a derelict site with "for sale" signage.*
  - **DECIDED (2026-09-16):** An empty lot with a "for sale" sign, trees and some rocks.
- **Q17.** Does a player always get the same plot position, or any free plot? *Rec: any free plot; the town is built so every plot looks good.*
  - **DECIDED (2026-09-16):** Any free plot, and the player picks it: when loading in they can switch between the free plots before choosing.
- **Q18.** Minimum device to support (low-end phone, mid phone, PC-first)? *Rec: mid-range phone as the target, with a quality setting.*
  - **DECIDED (2026-09-16):** Mid-range phone as the target, with quality settings.
- **Q19.** Where does a player spawn: their office (like today) or somewhere in town? *Rec: their own office.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation (own office).
- **Q20.** How do players get around: walk/sprint only, or fast travel (map teleports, bus rides)? *Rec: walk + sprint, plus a "go to my club" button and bus stops as fast travel.*
  - **DECIDED (2026-09-16):** Walk + sprint and a "go to my club" button. Bus stops are fast travel to other clubs, the town centre and other landmarks.
  - **Later idea (not scheduled):** players can buy a car and a house in town to show off how rich they are.

### Matchday & influence
- **Q21.** In a shared town, where does matchday dressing appear: A) only around that club's plot, visible to everyone B) whole town, but only on that player's screen C) both? *Rec: C — fans and stewards around the plot for everyone; town-wide banners and pubs only for the playing player.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation (C).
- **Q22.** How does "my club changed this place" work with 6 clubs: A) each player's client dresses the whole town in their club's identity B) each plot's neighbourhood changes C) both? *Rec: C.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation (C).

### Assets & art
- **Q23.** Budget for paid assets (Robux or real money)? *Rec: tell me a number, even £0.*
  - **DECIDED (2026-09-16):** $500 total, marketing money protected (see ASSET_KIT.md).
- **Q24.** Are Creator Store kits OK if scripts are stripped (as today), or only packs you've vetted? *Rec: store is fine, scripts stripped, you approve the style shortlist.*
  - **DECIDED (2026-09-16):** Store kits are fine with scripts stripped; Marcel approves the buy list.
- **Q25.** Should the existing procedural stadium be restyled to match the kit later, or stay primitive-built and have the town match it? *Rec: the kit sets the style; restyle the stadium in a later pass.*
  - **DECIDED (2026-09-16):** Yes — the kit sets the style. Restyling is already under way in the vertical-slice work.
- **Q26.** Source of truth for town geometry: A) place file only B) `.rbxm` model files in the repo via Rojo C) layout data in code that places kit models? *Rec: C for streets and props, B for hand-built hero pieces.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation (C for streets/props, B for hand-built showpiece pieces).
- **Q27.** Is AI mesh generation (`generate_mesh`) OK for hero assets, or kit-only? *Rec: OK for one-off hero props, not for buildings.*
  - **DECIDED (2026-09-16):** Mesh generation is fine for props. Buildings could work too, but prefer bought/downloaded building assets.
- **Q28.** Audio: Roblox's licensed sound library only, or will you upload your own recordings? *Rec: library first.*
  - **DECIDED (2026-09-16):** Roblox licensed sound library first.

### Social
- **Q29.** Friendlies: do they cause injuries, give money, or affect fitness? *Rec: no injuries, small attendance payout for the host, no effect on the league.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation.
- **Q30.** Can players send cash directly, or only swap players (+ cash as part of a deal)? *Rec: no cash gifts; cash only as part of a player deal.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation.
- **Q31.** Anti-abuse limits for trades (value-fairness check, cooldown, account age, max per season)? *Rec: all four, with soft values.*
  - **DECIDED (2026-09-16):** No anti-abuse limits for now; revisit later.
- **Q32.** Can you trade with a player who is offline / not in your server? *Rec: same-server only at first.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation (same server only at first).
- **Q33.** If a club is loaded in one server, what happens when the same player joins another? *Rec: new server waits for the save lock, then loads; old session is closed.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation. Also: a player's club despawns when they leave, freeing the plot (it goes back to the for-sale lot).

### Online
- **Q34.** Region/latency: does it matter for a mostly-simulated match? *Rec: low weight; queue time matters more.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation.
- **Q35.** In a 1v1, what does each human actually control? Only Attack/Defend/Sub and lineup, or new live decisions (press, formation changes, set-piece choices)? *Rec: needs its own talk (J0) — the most important unanswered design question for online.*
  - **DECIDED (2026-09-16):** Agreed: it gets its own design talk (J0) before any online work.
- **Q36.** Online squads: career squads as they are, normalised squads, or rating-band brackets? *Rec: career squads, matched within squad-strength bands.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation.
- **Q37.** Do online wins pay into the career economy? *Rec: no money — cosmetics, trophies and rating only (maybe a small capped weekly cash reward).*
  - **DECIDED (2026-09-16):** Online wins DO pay cash into the career, as well as trophies and rating. No weekly cap for now.
- **Q38.** Leaderboards: global, friends, seasonal resets? *Rec: seasonal rating ladder + friends board.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation.
- **Q39.** Should the club shop and training ground have real mechanics (merch revenue, player development) when built, or be visual first? *Rec: visual first, mechanics in a later gameplay milestone.*
  - **DECIDED (2026-09-16):** Agreed with the recommendation.

---

## 5. What I will NOT do until told

All of Q1–Q39 (plus Q2b–Q5b) were answered on 2026-09-16 and CLAUDE.md section 27 was updated.
Still held back:
- Any online/1v1 work until the J0 design talk (Q35).
- Trade anti-abuse (Q31) until it becomes a problem.
