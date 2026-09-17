# Plots — how one-club code becomes four clubs per server

> Written 2026-09-17 overnight (backlog B2.1a). Decided direction: CLAUDE.md s27 "Plots & players".

## Approach: one copy of the club services per plot ("module instancing")

Every server service was written for one club: module-level state, one `ReplicatedStorage.ClubState`
folder, one `workspace.Club` model. Rewriting ~4,000 lines into context objects overnight, with no
local Luau runner, is too risky. Instead:

- The per-club modules (`ClubState`, `WorldBuilder`, `MatchService`, `UpgradeService`, `ClubService`,
  `SeasonService`, `HistoryService`, `Session`, plus their helpers `Assets`, `SaveService`, `Scenery`)
  stay in `ServerScriptService.Server` exactly as Rojo syncs them.
- When a player claims plot N, `PlotService` clones those ModuleScripts into
  `ServerScriptService.ClubRuntime.PlotN` (a Folder carrying attributes `PlotIndex`, `OwnerUserId`) and
  requires the clone of `Session`. Because each clone's `require(script.Parent.X)` resolves to its own
  siblings, every plot gets its own module state for free.
- When the player leaves, the plot's session flushes its save, destroys its world and state folder,
  and `PlotService` destroys the `PlotN` runtime folder. The next claim clones fresh copies.

`Main.server.luau` and `PlotService.luau` are never cloned; they are the only global server code.

## What each clone reads to know which plot it is

`src/server/PlotContext.luau` (cloned too) reads `script.Parent:GetAttribute("PlotIndex")`:

| Thing | Global (old) | Per plot (new) |
|---|---|---|
| Replicated state | `ReplicatedStorage.ClubState` | `ReplicatedStorage.Clubs.PlotN` (Folder attributes, same keys) |
| World | `workspace.Club` | `workspace.Plots.PlotN.Club` |
| World transform | identity | `TownLayout.plotCFrame(N)` published as attribute `PlotCFrame` on the state folder |
| Owner | `OwnerUserId` attribute | same, and the player gets attribute `ClubPlot = N` |

When `PlotIndex` is absent (the un-cloned originals, the test runner) the context falls back to the
old global names and identity transform, so tests and single-club debugging keep working.

## Geometry

`WorldBuilder` still builds in pitch-local coordinates (pitch centre = origin). Every function that
creates geometry finishes by moving what it built through the plot CFrame (BaseParts' CFrame and
Models' WorldPivot), so the 1,600 lines of layout maths stay untouched. Identity = no-op.

Clients do the same: `src/client/ClubRef.luau` resolves the local player's club folder and its
`PlotCFrame`; the match presenter keeps simulating in pitch-local space and multiplies by the plot
CFrame only where it writes a CFrame (footballer roots, ball, walkout camera).

## Remotes

Remotes stay global (`ReplicatedStorage.Remotes`). Every clone connects its own handlers and ignores
players whose `ClubPlot` is not its plot (they are someone else's to answer), so a request is handled
exactly once. Visitors (no plot, or another plot) triggering a world prompt on this plot still get the
"You're visiting" toast from this plot's handler. `FireAllClients` for club-specific events became
`FireClient(owner)`.

## Global things

- `Scenery` lighting/terrain: set up once by `Main` (and moving to the client, backlog A1). The old
  procedural trees / distant town / pond are skipped once the town exists.
- Floodlight masts belong to each club's world and switch with that club's matchday.
- Studio `DebugRun` commands go to the first owned plot, or `plot=N|command|args`.

## Known limits (TEMP)

- Clients render only their own club's match. Watching another club's match is backlog I2.
- The Studio memory save backend is per clone, so leaving and rejoining the same Studio session
  starts a new club. A published place uses DataStores and is unaffected.
