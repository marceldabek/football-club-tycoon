# World Vision — The Town

> Captured from Marcel's brief on 2026-09-16. This is the *target*, not a build order.
> The build order, gaps and open questions live in [WORLD_ROADMAP.md](WORLD_ROADMAP.md).
> Where this file and CLAUDE.md disagree, CLAUDE.md wins until Marcel updates it.

---

## 1. The one-line goal

**A football management game where the club exists inside a town that feels like a place.**

The town is not decoration around the stadium. It is one of the reasons the game feels premium,
memorable and enjoyable to spend time in. Standing still in the town should be enjoyable.

Visual target: **a beautiful, slightly idealised version of a real British town.**

---

## 2. What kind of town

One believable small-to-medium British football town/region.

- Feels like a real English League One / League Two town
- Substantial enough to feel alive — not a giant city, not a tiny village
- Dense enough that the map feels busy and detailed
- Slightly stylised for Roblox readability
- Grounded and believable, not cartoony
- Polished, not hyper-realistic
- **A smaller town with excellent detail beats a giant empty map**

---

## 3. Look & lighting

### Normal gameplay look
- Bright blue-sky daytime, attractive clear weather
- Slightly warm sunlight, clean readable shadows
- Colourful but not oversaturated
- Strong contrast between sky, buildings, trees, roads and props
- Very mild atmospheric haze for distance
- Subtle colour grading — polished game lighting, not raw default Roblox lighting
- Something players are happy to stare at for a long time

**Avoid:** a dark, grey, rainy or overly gritty game.

### Post-processing (use carefully)
Use: ColorCorrection / colour grading, Atmosphere, subtle Bloom, slight SunRays if appropriate,
controlled shadow softness, realistic ambient light, very light distance haze.

Avoid: extreme saturation, excessive bloom, permanent strong DepthOfField, cinematic blur during
normal play.

DepthOfField is for: menus, close-ups, match intros, cinematic sequences.

### Time fast-forward
Normal play stays mostly in the daytime look. When time advances (between matches, days, weeks,
seasons) play a visual fast-forward:

- shadows move, sun position changes, clouds move quickly
- afternoon → sunset → lights switch on → night briefly passes → morning returns
- occasional rain / overcast during the transition
- then back to the strong daytime look

Purpose: it should feel like years are passing without sacrificing readability during play.

---

## 4. Town design philosophy

**The town looks real because it is imperfect.** Not every building clean, matching and branded.

Imperfections to include: mismatched storefronts, old brick beside newer construction, patched
roads, faded road markings, satellite dishes, antennas, bins, utility boxes, drains, alleys,
delivery areas, random parked vehicles, old walls, fences, weeds, pavement cracks, hanging cables,
window curtains, signs, posters, back entrances, pallets, dumpsters, bus stops, road signs,
bollards, benches, planters.

The imperfections make the prettier parts stand out.

### Football identity is subtle
**Not a football theme park.** Most of the town looks like a normal town. Football shows through:
occasional banners, scarves in pub windows, posters, club stickers, murals, matchday signage,
fans appearing on matchdays.

---

## 5. Map areas

| Area | Contents |
|---|---|
| **Town centre** | shops, cafés, bakery, pub, barbers, takeaway, small supermarket, flats above shops, benches, planters, town square, fountain or monument, market stalls |
| **Residential** | terraced houses, semi-detached houses, small apartment blocks, side streets, driveways, gardens, hedges, parked cars, alleys |
| **Industrial** | warehouses, workshops, loading areas, pallets, dumpsters, vans, fenced yards |
| **Riverside / scenic** | walking path, bridge, trees, railings, benches, possibly a small park |
| **Transport** | train station, bus stops, roads, intersections, car parks, delivery vehicles, bicycles |
| **Football** | stadium plots, training grounds, club offices, club shop, parking, fan routes, matchday gathering areas |

---

## 6. Detail layering

Busy without cluttered. Three layers:

- **Large forms:** streets, buildings, stadiums, parks
- **Medium detail:** fences, trees, awnings, cars, bus shelters, lamp posts
- **Small detail:** bins, drains, signs, weeds, posters, utility boxes, bollards, benches, pallets,
  satellite dishes, road repairs, window decorations

The player should constantly see small things that make the town feel lived-in.

### Composition
- interesting sightlines and landmarks
- dense storefronts, trees framing roads
- layered background buildings
- roads disappearing around corners
- distant hills / church spire / bridge / stadium floodlights
- **Never show the whole map at once** — curves, elevation, trees and buildings create depth

### Consistency is the biggest goal
Coherent materials, proportions, architecture, lighting and prop density.

---

## 7. Movement & life

The map must not feel frozen: occasional buses and cars, pedestrians, cyclists, fluttering flags,
moving trees, birds, chimney smoke, shop doors opening, deliveries, people sitting at cafés,
fans heading to matches.

## 8. Audio

Environmental sound used heavily, so the town feels alive even standing still: distant traffic,
birds, footsteps, shop ambience, café noise, pub noise, bus brakes, trains, church bell, river,
wind, distant stadium crowd, matchday chants, delivery vehicles.

---

## 9. Matchday changes

The same town feels different on matchday: more pedestrians, scarves and shirts, buses, parked
cars, temporary barriers, banners, queues, pub crowds, police/stewards where appropriate, distant
crowd noise, stadium floodlights, more traffic. After the match, activity fades.

## 10. The club changes the town

The base town stays recognisable, but the player's influence grows: stadium expansions, improved
club shop, upgraded training centre, more banners, more fans, bigger car parks, more media
presence, nicer offices, renovated club areas, more matchday traffic, more local club identity.

A player should eventually look back and see: **"my club changed this place."**

---

## 11. Shared town — club plots

Instead of fully solo, one town server hosts roughly **4–6 player clubs**.

- The town is fixed: roads, centre, houses, shops, river, transport, scenery.
- Around the map are modular football-club sites (plots).
- Each player brings their saved club into a plot: club name, squad, money, stadium progression,
  facilities, training ground, visual identity, season progress.
- Players see each other's evolving clubs in the same town.
- **Multiplayer is never required for progression.** The career works against AI teams.
- Friend servers could be especially fun.

### Interactions in the same town
Visit another stadium, view their club, inspect their squad, offer trades / transfers / loans,
challenge to friendlies, watch their matches, compare facilities and stadium growth, walk around
together.

### Local friendlies
Visit a club → Challenge Friendly → other player accepts → both moved into a match → no ranked MMR
change. Possibly played at the host club's real stadium.

---

## 12. Online matchmaking

Town servers and competitive match servers are separate.

- **Town server:** social, progression, management, stadium building, trades, friendlies, exploring.
- **Online:** press PLAY ONLINE → cross-server queue.

Matching considers online MMR / skill, squad strength, division, region/latency and queue time.
Search widens over time (e.g. near MMR first → wider after ~10 s → wider after 20–30 s).
**Never match on squad rating alone** — use both player skill and squad strength.

Once matched: create a temporary reserved 1v1 server → teleport both in → play → return both to
their previous town/hub.

### Career vs online stay separate
- **Career:** AI league, promotion/relegation, finances, facilities, stadium growth, transfers,
  progression.
- **Online:** matchmaking, rating, rewards, friendlies, leaderboards.
- The game remains fully playable solo.

---

## 13. Asset strategy

**Do not ask AI to model every building from scratch.** Use a coherent 3D asset kit as the visual
foundation; avoid mixing dozens of unrelated styles.

Look for: a British/European architecture pack, a street props pack, a vegetation pack, a vehicle
pack, and individual hero assets.

Kit should cover: terraced houses, semi-detached houses, apartments, storefronts, pubs, cafés,
industrial buildings, roads, pavements, kerbs, intersections, fences, brick walls, lamps, benches,
bollards, bins, bus shelters, utility boxes, trees, hedges, parked cars, vans, bicycles, dumpsters,
pallets, drains, chimneys, antennas, signs, planters, market stalls.

### Claude's role
Claude is **not** the main 3D artist. Claude is the world planner, assembler, scripting assistant,
procedural placement / prop scatter / layout system: assemble modular assets, build road grids and
neighbourhood layouts, reuse modules, vary rotation/scale carefully, place clutter, organise
assets, build matchday variants, manage repetition, script time progression and lighting, and
implement ambient traffic and NPC movement.

Give Claude an existing construction kit rather than "make me a beautiful town from scratch."
