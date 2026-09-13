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

Pure modules (`MatchSim`, `Pitch`, `TeamGen`, `Squad`) have suites in `tests/`. Run them from the
command bar (they recompile modules from source, so no stale `require` cache):

```lua
print(loadstring(game.ServerStorage.Tests.RunAll.Source)()())
```

### Debug hook

In Play mode the server exposes `ServerScriptService.Server.DebugCommand` (BindableFunction):

```lua
local dbg = game.ServerScriptService.Server.DebugCommand
dbg:Invoke("playMatch", 30, 3)   -- optional: match seconds, walkout seconds
dbg:Invoke("expandStand")
dbg:Invoke("tactic", "Attack")   -- "Attack" | "Defend" | "Balanced" | "Sub"
dbg:Invoke("club", "hireScout")  -- any ClubService action: setAutoSquad, swap, sign, release, hireCoach...
dbg:Invoke("cash", 5000)         -- add money
```

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

All economy numbers in `src/shared/Config.luau` are TEMP placeholders.
