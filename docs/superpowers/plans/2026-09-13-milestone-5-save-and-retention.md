# Milestone 5 — Save & Retention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A player's club (cash, stadium, squad, season, history) survives leaving the game, and a first-time owner names their club.

**Architecture:** A pure `Profile` module defines the save schema and normalisation; every server service gains `serialize()` / `restore(data?)`; `SaveService` wraps a DataStore (or an in-memory backend in an unpublished Studio place) with retries, a dirty flag and an autosave loop; `Session` orchestrates boot (wait for the owner → load → restore → build world → Manage). `History` is a pure module recorded at season end and shown in the panel and as office trophies.

**Tech Stack:** Roblox Luau (strict), Rojo 7.4.4, Studio test runner (`tests/RunAll.luau` via MCP `execute_luau`), DataStoreService, TextService.

**Spec:** `docs/superpowers/specs/2026-09-13-milestone-5-save-and-retention-design.md`

## Global Constraints

- All new numbers go in `Config` and are labelled TEMP.
- Saved data must be JSON-safe: no `Random`, `Color3`, sparse arrays, or `nil` holes in arrays (`lineup.xi` gaps are stored as `0`).
- A save is refused until a load has succeeded. A failed load kicks the owner; it never creates a fresh club.
- Owner-only: every management remote and world prompt checks `ClubState.OwnerUserId`.
- Keep `--!strict`. Keep pure modules free of Instances and yields.
- Tests run in Studio (Edit mode): `print(loadstring(game.ServerStorage.Tests.RunAll.Source)()())`. Sync disk → Studio with the Rojo plugin, or `tools/studio-sync.luau` if the plugin is stale. Never run tests or debug commands inside Marcel's own Play session.
- Commit after each task once tests pass.

---

## File map

| File | Responsibility |
|---|---|
| `src/shared/Config.luau` (modify) | `Config.Save`, `Config.ClubNameMaxLength`, `Config.ClubNameMinLength`, `Config.DefaultClubNameSuffix`, `Config.TrophiesShown` |
| `src/shared/Profile.luau` (new) | Save schema v1, `new`, `normalize`, lineup packing helpers |
| `src/shared/History.luau` (new) | `new`, `recordSeason`, `honours` |
| `src/server/SaveService.luau` (new) | Backends, `load`/`save` with retries, dirty flag, autosave, flush |
| `src/server/Session.luau` (new) | Owner, boot flow, `snapshot()`, `restoreAll()`, naming remote, welcome |
| `src/server/HistoryService.luau` (new) | Holds the history table, publishes `ClubState.History`, rebuilds trophies |
| `src/server/ClubState.luau` (modify) | `Loading` phase, `OwnerUserId`, `NeedsName`, `History` attrs, `serialize`/`restore`, dirty hook |
| `src/server/ClubService.luau` (modify) | `init` only wires remotes; `restore(data?)`, `serialize()`, owner check, `setClubName` support |
| `src/server/SeasonService.luau` (modify) | `restore(data?)`, `serialize()`, records history at season end, `renameClub` |
| `src/server/MatchService.luau` (modify) | owner check on Tactic; `flush` after settlement |
| `src/server/UpgradeService.luau` (modify) | unchanged API; `markDirty` happens through `ClubState.set` |
| `src/server/WorldBuilder.luau` (modify) | `buildTrophies(count)` shelf in the office |
| `src/server/Main.server.luau` (modify) | Calls `Session.start()`; debug commands `save` / `reload` / `wipe` |
| `src/client/HUD.client.luau` (modify) | Loading card, Welcome back card, Loading-aware hints |
| `src/client/Onboarding.client.luau` (new) | Club naming card |
| `src/client/ClubPanel.client.luau` (modify) | History tab, visitor note |
| `src/client/Match.client.luau` (modify) | `Loading` treated as Manage |
| `tests/ProfileTest.luau`, `tests/HistoryTest.luau`, `tests/SaveServiceTest.luau` (new) | Unit suites |
| `README.md` (modify) | Persistence notes, publish steps, debug commands |

---

### Task 1: Config + Profile schema (pure)

**Files:** Create `src/shared/Profile.luau`, `tests/ProfileTest.luau`. Modify `src/shared/Config.luau`.

**Interfaces (produces):**
```lua
Config.Save = { storeName = "ClubProfiles", version = 1, autosaveSeconds = 30, loadRetries = 3, retryBackoffSeconds = 1 }
Config.ClubNameMinLength = 3; Config.ClubNameMaxLength = 24; Config.DefaultClubNameSuffix = " FC"; Config.TrophiesShown = 8

export type Profile = { version, clubName, named, cash, standLevel, amenityLevel, matchesPlayed, wins, draws, losses,
  club: table?, season: table?, history: { seasons: {} }, createdAt, updatedAt, saveCount }
Profile.VERSION = 1
Profile.new(clubName: string, now: number?) -> Profile
Profile.normalize(raw: any, now: number?) -> (Profile, boolean changed)
Profile.packXi(xi: {number}) -> {number}     -- nil slots -> 0, length #Pitch.ROLES
Profile.unpackXi(packed: {number}) -> {number} -- 0 -> nil
```

- [ ] Step 1: Add the Config values (TEMP comments).
- [ ] Step 2: Write `tests/ProfileTest.luau`:
  - `newHasDefaults`: `Profile.new("X FC")` → version 1, clubName "X FC", named false, cash = `Config.StartingCash`, standLevel 1, amenityLevel 0, club nil, season nil, history.seasons empty, saveCount 0.
  - `normalizeFillsMissing`: `Profile.normalize({ cash = 500 })` → cash 500, other fields default, changed true.
  - `normalizeDropsWrongTypes`: `{ cash = "lots", standLevel = 99, amenityLevel = -1, clubName = 5 }` → cash default, standLevel clamped to `#Config.StandLevels`, amenityLevel 0, clubName default `"Your Club"`.
  - `normalizeKeepsValidUnchanged`: a full valid profile → changed false, deep-equal.
  - `jsonRoundTrip`: profile with a club section (players from `Squad.generate`, lineup from `Squad.autoLineup` packed with `packXi`, shortlist) and a season section (`League.newSeason(1, 1, "X", 1)`) → `JSONDecode(JSONEncode(p))` deep-equals the original.
  - `packXiRoundTrip`: xi with slot 3 missing → packed[3] == 0, `#packed == 11`, `unpackXi(packed)[3] == nil`, other slots preserved.
  - `normalizeNonTable`: `Profile.normalize(nil)` and `Profile.normalize("junk")` return a fresh default profile with changed true.
- [ ] Step 3: Run the suite in Studio; expect ProfileTest to FAIL to load (module missing).
- [ ] Step 4: Implement `Profile.luau`. Normalisation rules: numbers are `type(v) == "number"` and finite, integers floored; booleans strict; strings strict with `clubName` length clamped to `Config.ClubNameMaxLength`; `standLevel` clamped 1..#StandLevels; `amenityLevel` 0..#AmenityLevels-1; `club`/`season` kept only if tables (deeper validation is the services' job on restore, they regenerate on any error); `history.seasons` kept only if a table of tables. `version` older than `Profile.VERSION` runs migrations (none yet) and sets it. `updatedAt`/`createdAt` default to `now` (`os.time()` when nil).
- [ ] Step 5: Run the suite; expect all ProfileTest cases to pass and existing suites unchanged.
- [ ] Step 6: Commit `feat(m5): Profile schema and Config.Save`.

### Task 2: History (pure) + HistoryService + trophies

**Files:** Create `src/shared/History.luau`, `tests/HistoryTest.luau`, `src/server/HistoryService.luau`. Modify `src/server/WorldBuilder.luau`.

**Interfaces (produces):**
```lua
export type SeasonRecord = { season, tier, division, position, outcome, played, won, drawn, lost, gf, ga, points, prize }
export type Honours = { seasons: number, titles: number, promotions: number, relegations: number, bestTier: number }
History.new() -> { seasons = {} }
History.recordSeason(history, record) -- appends (copy)
History.honours(history) -> Honours   -- title = position == 1; promotions = outcome "Promoted"; relegations = "Relegated"; bestTier = max tier seen (0 if none)
History.isTitle(record) -> boolean

HistoryService.init(); HistoryService.restore(data: table?); HistoryService.serialize() -> table
HistoryService.record(record: SeasonRecord)  -- appends, publishes ClubState.History (JSON), rebuilds trophies
HistoryService.honours() -> Honours
WorldBuilder.buildTrophies(count: number)  -- shelf on the office north wall, min(count, Config.TrophiesShown) cups; rebuild-safe
```

- [ ] Step 1: Write `tests/HistoryTest.luau`: `recordAppendsInOrder` (two records, seasons list length 2, second has season 2); `honoursCounts` (records: tier1 pos1 Promoted, tier2 pos5 Relegated, tier1 pos1 Promoted, tier2 pos3 Stayed → titles 2, promotions 2, relegations 1, bestTier 2, seasons 4); `emptyHonours` (all zeros).
- [ ] Step 2: Run; expect load failure. Implement `History.luau`. Run; expect pass.
- [ ] Step 3: `WorldBuilder.buildTrophies(count)`: remove existing `Trophies` model under `workspace.Club.Office`; a wooden shelf `Part` on the inside of the north wall at y ≈ ground + 7; each cup = a gold `Cylinder` base + a small gold `Ball`, spaced 3 studs, material `Metal`, colour `Color3.fromRGB(230, 190, 60)`. Export the office centre (`cx`, `cz`) as module locals so the shelf lands inside the office. Export `WorldBuilder.officeCenter()`.
- [ ] Step 4: `HistoryService.luau` as specified; publishing `ClubState.set("History", JSONEncode({ seasons = ..., honours = ... }))`.
- [ ] Step 5: Commit `feat(m5): club history and office trophy shelf`.

### Task 3: SaveService with backends

**Files:** Create `src/server/SaveService.luau`, `tests/SaveServiceTest.luau`.

**Interfaces (produces):**
```lua
export type Backend = { get: (key: string) -> any?, set: (key: string, value: any) -> () }  -- may error
export type LoadStatus = "ok" | "new" | "error"
SaveService.memoryBackend(store: { [string]: any }?) -> Backend
SaveService.dataStoreBackend(storeName: string) -> Backend           -- lazy GetDataStore
SaveService.autoBackend() -> (Backend, string kind)                   -- "datastore" unless Studio + unpublished ("memory"), warns once
SaveService.new(backend: Backend, opts: { retries: number?, backoff: number?, wait: ((number) -> ())? }) -> Saver
Saver:load(userId: number) -> (any?, LoadStatus)
Saver:save(userId: number, profile: any) -> boolean   -- refused (false) until a load returned "ok" or "new" for that userId
Saver:markDirty(); Saver:isDirty() -> boolean
Saver:flush(userId: number, snapshot: () -> any) -> boolean  -- saves if dirty (or force=true), clears dirty on success
Saver:startAutosave(userId: number, snapshot: () -> any, seconds: number)  -- task.spawn loop
```
Key is `"u" .. userId`. `save` stamps `updatedAt = os.time()` and `saveCount += 1` on the profile it writes.

- [ ] Step 1: Write `tests/SaveServiceTest.luau` using `memoryBackend` and a flaky backend wrapper (fails N calls then delegates), with `wait = function() end` so retries don't sleep:
  - `newThenSaveThenLoad`: load → (nil, "new"); save → true; load → (same table, "ok").
  - `flakyBackendRecovers`: fails 2 times, retries 3 → load returns "new" then save true.
  - `alwaysFailingIsError`: load → (nil, "error"); save → false.
  - `saveRefusedBeforeLoad`: fresh saver, save → false.
  - `flushOnlyWhenDirty`: after load, flush → false (not dirty); markDirty; flush → true and isDirty false; the stored value has saveCount 1.
- [ ] Step 2: Run; expect load failure. Implement. Run; expect pass.
- [ ] Step 3: Commit `feat(m5): SaveService with DataStore and memory backends`.

### Task 4: Serialize / restore on ClubState, ClubService, SeasonService

**Files:** Modify `src/server/ClubState.luau`, `src/server/ClubService.luau`, `src/server/SeasonService.luau`.

**Interfaces (produces):**
```lua
ClubState.init()                       -- Phase "Loading", OwnerUserId 0, NeedsName false, History "{}"
ClubState.restore(p: Profile.Profile)  -- cash, standLevel, capacity, amenityLevel, matches/W/D/L, clubName, NeedsName = not p.named
ClubState.serialize() -> { clubName, named, cash, standLevel, amenityLevel, matchesPlayed, wins, draws, losses }
ClubState.onDirty: (() -> ())?         -- called by set() for persisted keys
ClubState.isOwner(player: Player) -> boolean

ClubService.init()                     -- remotes only (owner check + Manage check)
ClubService.restore(data: table?)      -- nil → generate fresh with a random seed; invalid → warn + fresh
ClubService.serialize() -> { players, lineup = { xi = packed, bench }, autoSquad, coachLevel, scoutLevel, shortlist, nextId }

SeasonService.init()                   -- nothing but locals
SeasonService.restore(data: table?, clubName: string)  -- nil → tier 1 season 1 fresh; validates league via League.isValid
SeasonService.serialize() -> { tier, seasonNumber, round, popularity, league }
SeasonService.renameClub(name: string) -- updates league.teams[playerIndex].name and republishes
SeasonService.endSeason() -> records history via HistoryService.record(...)
League.isValid(season: any) -> boolean -- teams count == Config.TeamsPerDivision, fixtures present, playerIndex in range
```

- [ ] Step 1: `ClubState`: add persisted-key set `{ Cash, StandLevel, AmenityLevel, MatchesPlayed, Wins, Draws, Losses, ClubName }`; `set` calls `ClubState.onDirty` when the key is persisted and the value changed. Add `restore`, `serialize`, `isOwner`.
- [ ] Step 2: `ClubService`: move generation into `restore(nil)`; `restore(data)` validates each player has numeric id/overall/potential/age and a role in `Pitch.ROLES`, rebuilds `lineup` with `Profile.unpackXi`, recomputes if `autoSquad`, else `repairLineup()`. `publish()` calls `ClubState.markDirty()` (new helper that invokes `onDirty`). Remote handler: `if not ClubState.isOwner(player) then toast "You're visiting this club — only the owner can manage it" return end`.
- [ ] Step 3: `SeasonService`: `restore` as above; `serialize`; `renameClub`; in `endSeason` build the `SeasonRecord` from `League.standings(season)` row for `season.playerIndex` before rolling over, call `HistoryService.record(record)`; `publish()` marks dirty. Add `League.isValid` + a `LeagueTest` case `isValidRejectsGarbage`.
- [ ] Step 4: Run all suites; expect green. Commit `feat(m5): serialize/restore for club state, squad and season`.

### Task 5: Session boot + naming + welcome + Main wiring

**Files:** Create `src/server/Session.luau`. Modify `src/server/Main.server.luau`, `src/server/MatchService.luau`.

**Interfaces (produces):**
```lua
Session.start()                       -- boots per the spec; blocks until Manage
Session.snapshot() -> Profile.Profile -- assembles from all services via Profile.normalize
Session.restoreAll(p: Profile.Profile) -- ClubState → ClubService → SeasonService → HistoryService → WorldBuilder.build(...) → UpgradeService.init(...) → buildTrophies
Session.ownerId() -> number
Session.saveNow() -> boolean          -- flush(force)
Session.reload()                      -- Studio: snapshot → restoreAll (proves the round trip)
Session.wipe()                        -- Studio: Profile.new(default) → restoreAll → save
Remotes: "ClubName" (RemoteEvent, client → server, name: string), "Welcome" (server → client, data)
```
Boot: `ClubState.init()`; `MatchService.init()`; `ClubService.init()`; `HistoryService.init()`; then `waitForOwner()` = first of `Players:GetPlayers()[1]` or `PlayerAdded:Wait()`; load with `SaveService.new(SaveService.autoBackend(), { retries = Config.Save.loadRetries, backoff = Config.Save.retryBackoffSeconds })`; `"error"` → `owner:Kick("Your club could not be loaded. Please rejoin.")` and loop; `"new"` → `Profile.new(owner.DisplayName .. Config.DefaultClubNameSuffix)`; `Profile.normalize`; `restoreAll`; `ClubState.set("OwnerUserId", owner.UserId)`; `Phase = "Manage"`; `saver:startAutosave(...)`; `ClubState.onDirty = function() saver:markDirty() end`; if `matchesPlayed > 0` fire `Welcome` to the owner with `{ clubName, division, season, round, rounds, nextOpponent, cash }`; `PlayerRemoving` (owner) → `flush`; `game:BindToClose` → `flush` (skip in Studio if not loaded).
Naming: `ClubName.OnServerEvent(player, name)`: owner only, `NeedsName` true only; trim, length bounds, pattern `^[%w%s'%-%.]+$`; `TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)` in pcall → `GetNonChatStringForBroadcastAsync()`; on error use `if RunService:IsStudio() then name else default`; set `ClubName`, `named = true` (Session keeps `named` in a local mirrored into `ClubState.NeedsName = false`), `SeasonService.renameClub`, flush, toast "Welcome to <name>!".
World prompts (moved from Main into Session.wire(world)): each `Triggered` handler starts with the owner check and toasts visitors.
`MatchService`: Tactic remote checks `ClubState.isOwner`; after `SeasonService.recordPlayerResult` call `Session`?? — no (cycle). Instead `MatchService.onSettled: (() -> ())?` hook that Session sets to `saver:flush(...)`.
`Main.server.luau`: `Session.start()` then the debug block adds `"save"`, `"reload"`, `"wipe"`.

- [ ] Step 1: Implement `Session.luau` and slim `Main.server.luau`.
- [ ] Step 2: Sync to Studio (Edit mode), run all suites (green), start a Play session via MCP, check output: `[FCT] loaded new profile for <name>` then `[FCT] world ready`, Phase Manage, `NeedsName` true. Debug `("playMatch", 2, 0.5)` twice, `("expandStand")`, `("save")` → output shows `[FCT] saved (memory)`. `("reload")` → cash / StandLevel / MatchesPlayed unchanged, `Club` JSON identical, `LeagueTable` identical, stand model rebuilt at level 2.
- [ ] Step 3: Commit `feat(m5): session boot, load/restore, autosave, club naming`.

### Task 6: Client — loading, naming, welcome back, history tab, visitors

**Files:** Create `src/client/Onboarding.client.luau`. Modify `src/client/HUD.client.luau`, `src/client/ClubPanel.client.luau`, `src/client/Match.client.luau`.

- [ ] Step 1: `HUD`: a full-screen dark `Loading` frame with "Loading your club…" visible while `Phase == "Loading"`; hide cash / season / CLUB while loading; `refreshHint` returns "Loading…" for that phase. `Welcome` remote → a centre card (same style as Summary) titled "WELCOME BACK" with body lines: club, division · season, "Match X of 10 next vs Y", cash; Continue button named `Continue`.
- [ ] Step 2: `Onboarding.client.luau`: when `NeedsName` becomes true (and Phase is Manage and the local player is the owner: `OwnerUserId == LocalPlayer.UserId`), show a centre card "NAME YOUR CLUB" with a `TextBox` (prefilled with `ClubName`, `ClearTextOnFocus = false`, max length enforced client-side) and a "Found the club" button firing `ClubName`. Hides when `NeedsName` turns false. Escape closes nothing (must name; default is fine since Enter/button with the default works).
- [ ] Step 3: `ClubPanel`: add tab `History` (after League) rendering honours line, all-time record from `MatchesPlayed`/`Wins`/`Draws`/`Losses`, then rows per season from `ClubState.History`. If `OwnerUserId ~= LocalPlayer.UserId`, prepend a note "You're visiting this club" and skip action buttons (Auto toggle, Release, Sign, Hire).
- [ ] Step 4: `Match.client`: `onPhase` treats `"Loading"` as the else branch (already does). No change needed beyond confirming.
- [ ] Step 5: Play session via MCP: naming card appears, type a name with `user_keyboard_input`, click the button by path `Onboarding.Card.Found`; `ClubName` attribute updates and the league row renames. `("reload")` keeps the name. Commit `feat(m5): loading, naming, welcome and history UI`.

### Task 7: Docs, memory, final verification

- [ ] Step 1: README: persistence section (what is saved, when; publish + "Enable Studio Access to API Services" to test DataStores; 1 max player), new debug commands, History tab.
- [ ] Step 2: Full suite green; a fresh Play session end-to-end: name → match 1 → stand → match 2 → save → reload → welcome-back card on a second boot is simulated via `("reload")` output. Screenshot the trophy shelf after forcing a title (`("cash", 100000)` then play a season is too long; instead verify `WorldBuilder.buildTrophies(3)` in Edit mode renders).
- [ ] Step 3: Commit `Milestone 5: save & retention`. Update memory files.
