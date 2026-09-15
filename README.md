# Football Club Tycoon

A 3D Roblox football-club management tycoon. See [CLAUDE.md](CLAUDE.md) for the full design and build plan.

## Layout

```
src/shared/   ModuleScripts shared by client and server  -> ReplicatedStorage.Shared
src/server/   Server modules + entry script              -> ServerScriptService.Server
src/client/   Client scripts                             -> StarterPlayer.StarterPlayerScripts.Client
tests/        Luau test suites (Studio only)             -> ServerStorage.Tests
tools/        Dev helpers run from the Studio command bar
```

`default.project.json` maps these folders for Rojo 7 (pinned in `aftman.toml`). The files on
disk are the source of truth.

## Working in Studio

```powershell
aftman install      # once, installs rojo
rojo plugin install # once, installs the Studio plugin
rojo serve          # every session, then click Connect in the Rojo plugin inside Studio
```

If the Rojo plugin stops applying changes (it happens after `default.project.json` changes),
paste `tools/studio-sync.luau` into the Studio command bar. It pulls the current tree from the
running `rojo serve` over HTTP. HttpService must be enabled in the place for this.

### Tests

Pure modules (`MatchSim`, `Pitch`, `TeamGen`, `Squad`, `League`, `Economy`, `Profile`, `History`)
and `SaveService` (with its memory backend) have suites in `tests/`. Run them from the
command bar (they recompile modules from source, so no stale `require` cache):

```lua
print(loadstring(game.ServerStorage.Tests.RunAll.Source)()())
```

### Debug hook

In Play mode the server exposes `ServerScriptService.Server.DebugCommand` (BindableFunction):

```lua
local dbg = game.ServerScriptService.Server.DebugCommand
dbg:Invoke("playMatch", 30, 3)   -- optional: match seconds, walkout seconds
dbg:Invoke("expandStand", "West") -- East | West | North | South; defaults to East
dbg:Invoke("amenity")            -- the concourse chain
dbg:Invoke("preview", "4,2,1,0") -- rebuild the ground at those plot levels (looking, not buying)
dbg:Invoke("tactic", "Attack")   -- "Attack" | "Defend" | "Balanced" | "Sub"
dbg:Invoke("club", "hireScout")  -- any ClubService action: setAutoSquad, swap, sign, release, hireCoach...
dbg:Invoke("cash", 5000)         -- add money
dbg:Invoke("save")               -- flush the profile now
dbg:Invoke("reload")             -- snapshot -> JSON -> restore: proves the save round trip
dbg:Invoke("wipe")               -- throw the club away and start fresh
```

The Studio MCP bridge runs in a sandboxed thread that cannot invoke a BindableFunction or
require these modules, so the same commands are also reachable by writing a string attribute
(arguments separated by `|`); the result comes back on `DebugResult`:

```lua
game.ServerScriptService.Server:SetAttribute("DebugRun", "preview|4,2,1,0")
game.ServerScriptService.Server:SetAttribute("DebugRun", "playMatch|20|3")
```

## Ground layout

Pitch centred on the origin, long axis along Z (`Pitch.luau` owns the numbers). Working
outward: the **turf run-off** carrying `Pitch.GRASS_MARGIN` past the markings (the nets, the
corner flags and the technical areas all stand on it), then the ad boards, then the
**hardstanding** — the paved ring fans walk on and the dugouts sit on — then the **perimeter
wall** on the line `Pitch.SIDE_EDGE` / `Pitch.END_EDGE`, then the stands.

Each of the four sides is an independent **plot** (`Config.StandPlots`) on the shared
`Config.StandLevels` chain, so the ground grows asymmetrically like a real lower-league
ground; capacity is the sum over plots and level 0 is an empty plot. Every plot is built in a
local frame where +X points away from the pitch and +Z runs along the stand, so one builder
serves all four sides. The wall stops short of all four corners: three are closed with a
diagonal panel, and the open north-west one is the turnstile entrance.

The **tunnel** runs from the middle of the west wall straight back through the gap in the
west stand to the **dressing rooms** and, at the far end, the **office**. The player spawns
at the desk and walks out down the tunnel onto the pitch, passing the matchday board on the
way — the same way the team comes out. The terrace stops against the tunnel's own side walls
and carries over its roof from the row that clears it, so the only hole in the west stand is
the mouth, and it closes itself as the stand is upgraded.

The **turnstiles** in the open north-west corner are the public way in, onto a paved
forecourt with the concourse, the car park and the team bus. Nothing the player needs is
there except what they choose to build.

## Architecture

- **Simulation** (`src/shared/MatchSim.luau`): pure. Decides the score and a timeline of
  GOAL / MISS / SAVE chances at football minutes. The score is authoritative.
- **Server** (`MatchService`): runs phases Manage -> PreMatch -> Match -> Manage, publishes the
  timeline and squads as a JSON attribute on `ReplicatedStorage.ClubState`, bumps the scoreboard
  on the minute, settles revenue.
- **Club** (`src/shared/Squad.luau` + `src/server/ClubService.luau`): persistent generated squad
  with ratings, auto/manual lineup, injuries, development, coach, scout shortlist. Published as
  one JSON attribute (`ClubState.Club`); the `ClubPanel` client shows it (office computer / CLUB
  button / Tab) and sends actions over the `ClubAction` remote.
- **Season** (`src/shared/League.luau` + `src/server/SeasonService.luau`): 6-team double round
  robin (10 matches), table, promotion / relegation through `Config.Divisions`, popularity and
  fan demand (`Economy.demand`). The other fixtures of each round are simulated with `MatchSim`.
- **Persistence** (`src/shared/Profile.luau` + `src/server/SaveService.luau` + `src/server/Session.luau`):
  one club per server, owned by the first player to join. `Session` loads the owner's profile,
  restores every service and builds the world, then saves after every match, on a 30s dirty
  timer, when the owner leaves and on shutdown. `Profile.normalize` repairs anything missing or
  malformed in a save. Club history (`History.luau`, `HistoryService`) records every finished
  season and puts a trophy on the office shelf per league title.
- **Presentation** (`src/client/MatchPresenter.luau`): each client replays the timeline locally,
  synced to the server's `KickoffAt`. Block footballers (`Footballer.luau`) with procedural run /
  kick / celebrate / dive poses. Nothing here affects the result.

## Status

- Milestone 1: ugly playable loop (play match -> earn -> buy one upgrade). Done.
- Milestone 2: matchday illusion (iris, walkout, 3D match playback, halftime with a change of
  ends, crowd, Attack / Defend / Sub). Done. Tactics are HUD hooks only; they change the visuals,
  not the sim, until squads exist.
- Polish pass: halftime with change of ends, dribbling and lead passes,
  inverted iris at kickoff, Shift to sprint, nets / centre circle / flags, grass surroundings.
- Audio: `Config.Sounds` (crowd, cheer, whistle) and `Config.Music` (shuffled APM tracks, ducked
  during matches, on/off button in the HUD) are free Roblox-licensed Creator Store assets.
  `MatchAudio` plays them.

- Milestone 3: club management. 16-player generated squad (OVR / potential / age), Auto Squad
  with optional manual swaps, injuries and development after each match, coach (strength +
  development), scout with a refreshing shortlist, signing and releasing. Home strength in the
  sim now comes from the XI; home goals get named scorers.

- Milestone 4: first season. Fixed opponents per division with division-driven strength, league
  table (Club panel → League), promotion / relegation, season-over summary with prize money,
  squad ageing, popularity-driven attendance, stand levels 3-4 and a concourse amenity chain
  (Snack Bar → Club Shop → Fan Zone) that adds per-fan revenue and demand. All of the player's
  fixtures are presented at home (one stadium) for now.

- Milestone 5: save & retention. DataStore persistence of cash, stadium, squad, season, table
  and history; loading screen; first-visit club naming (filtered); welcome-back card; Club
  panel → History tab; trophy shelf in the office. Visitors (a second player in the same
  server) can watch but not manage.

- Look pass: `Scenery` (lighting grade, dusk + floodlights on matchday, terrain hills, clouds,
  trees, distant town), pitch dressing (mowing stripes, six-yard boxes, penalty arcs, worn
  goalmouths, sponsor ad boards, dugouts, tunnel mouth with the club name), sectioned stands
  with aisles and a club-name roof fascia, seated crowd with heads. One `Theme` module
  styles every client screen. Set *Lighting → Technology* to **Future** in Studio by hand
  (not scriptable) for the shadows the grade was tuned for.

- Match visuals pass: footballers are R15 rigs built on the client from a per-player look
  seed (`Appearance.luau`: skin tone, height/build, Roblox-made hair, face, rare shades or
  headband, boot colour) with Roblox-owned idle / walk / run / celebrate animations and
  procedural kick / dive; `BlockFootballer` is the fallback if a rig fails to build. The ball
  rolls at 0.9 studs, sits at the carrier's feet, gets knocked ahead while dribbling and is
  only lofted for switches and shots; filler play is nearest-teammate build-up with
  interceptions. Fans are character-scale and leave at full time. The Club panel's Squad tab
  is a lineup board: headshot cards (`Headshot.luau`, classic mesh head with the face as a
  thumbnail decal) on a pitch, drag one card onto another or tap two to swap
  (`LineupBoard.luau`), which still goes through the server's `swap` rules.

All economy numbers in `src/shared/Config.luau` are TEMP placeholders.

## Assets

Creator Store and generated models live in the **place file** under `ServerStorage.Assets`, not in
git. `src/server/Assets.luau` clones them; every caller falls back to primitives when one is
missing, so a fresh clone still builds a complete (uglier) world. Store models are stripped of
scripts on insert and again on clone (CLAUDE.md agent rule 9). To rebuild the library in a new
place, insert these and name them as listed:

| Name | Source | Asset id |
|---|---|---|
| `Floodlight` | Creator Store, "Stadium Lights Floodlight Arena" | 114304849826345 |
| `Goal` | Creator Store, "Football Goal Post Stadium Field Net Arena" | 98791919057798 |
| `Bus` | Creator Store, "Coach bus" | 9127212780 |
| `Trees.Pine` | Creator Store, "Low Poly Tree" (Remadex) | 12549617200 |
| `Trees.Tree1..11` | Creator Store, "Low Poly Tree Pack" | 15217079919 |
| `Trophy` | Generated in Studio (mesh 80652460368685) | 123217619951714 |

Store inserts arrive with a rotated pivot; the library models were straightened so their
bounding boxes are axis aligned. `Assets.place` scales, faces and grounds a model; `flip` /
`yawOffset` correct models whose front is not their -Z.

## Persistence in Studio

DataStores only work in a **published** place with *Game Settings → Security → Enable Studio
Access to API Services* turned on. Until then the server logs
`DataStore unavailable in Studio` and saves to memory for the Play session only; use
`dbg:Invoke("reload")` to prove the round trip. Also set *Game Settings → Places → Max
players* to **1** (it is read-only from scripts) so every player gets their own server and club.
The DataStore name is `Config.Save.storeName`; bump it to reset all saves while prototyping.
