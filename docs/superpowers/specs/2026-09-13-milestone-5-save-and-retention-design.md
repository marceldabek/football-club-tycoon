# Milestone 5 — Save & Retention (design)

Goal (CLAUDE.md §19): DataStore persistence, club history, player persistence, stadium
persistence, reliable reconnect behaviour, first proper onboarding. After this, the club a
player builds is *theirs* and survives leaving.

Built on M4. All numbers are TEMP and live in `Config`. Decisions taken without Marcel's
sign-off are marked **(decision)**.

## Ownership model

**(decision)** One club per server, owned by the **first player to join**. The place should be
set to **1 max player** (Game Settings → Places) so every player gets their own server and
their own club. Multiplayer stadium visits are explicitly not MVP (CLAUDE.md §14), so this is
the cheapest correct model. If a second player does join (misconfigured place), they are a
*visitor*: they can walk around and watch, but every management remote and world prompt is
refused with a toast. Ownership never transfers within a server.

`ClubState.OwnerUserId` is published so services and clients can check it without a new
module dependency.

## Profile (what is saved)

`src/shared/Profile.luau` (pure): schema, defaults, normalisation.

```
Profile = {
  version = 1,
  clubName, named (bool),           -- onboarding: has the owner named the club?
  cash, standLevel, amenityLevel,
  matchesPlayed, wins, draws, losses,
  club   = { players, lineup = { xi (dense, 0 = empty), bench }, autoSquad,
             coachLevel, scoutLevel, shortlist, nextId },
  season = { tier, seasonNumber, round, popularity, league = League.Season },
  history = { seasons = { SeasonRecord... } },
  createdAt, updatedAt, saveCount,
}
SeasonRecord = { season, tier, division, position, outcome, played, won, drawn, lost,
                 gf, ga, points, prize }
```

- `Profile.new(clubName)` → fresh defaults (no squad / league; services generate those when
  the corresponding section is `nil`).
- `Profile.normalize(raw)` → `(profile, changed)`: fills every missing key from defaults,
  drops values of the wrong type, clamps levels to the `Config` tables, runs version
  migrations (v1 only today). A corrupt or partial save can never crash the boot; the worst
  case is a section regenerated fresh.
- Everything stored is plain JSON-safe data: no `Random`, no `Color3`, no sparse arrays
  (`lineup.xi` gaps are stored as `0`).

Each server service gains `serialize()` / `restore(data?)`:
`ClubState` (top-level scalars), `ClubService` (club), `SeasonService` (season),
`HistoryService` (history, new). `restore(nil)` means "start fresh" and does what `init`
did before (generate squad, new season at tier 1).

**(decision)** New clubs generate their squad from a random seed instead of
`Config.HomeSquadSeed`, since the squad now persists and every club having the same 16
players would be odd. The fixed seed stays for tests and as the player team's League seed.

## Storage

`src/server/SaveService.luau`: `SaveService.new(backend)` with two backends:

- `DataStoreBackend` — `DataStoreService:GetDataStore(Config.Save.storeName)`, key
  `"u" .. userId`, `GetAsync` / `UpdateAsync`.
- `MemoryBackend` — a table. Used automatically in Studio when the place is unpublished
  (DataStore errors with "must publish"), with one warning in the output. Also what tests use.

API: `load(userId) -> (profile?, status)` with status `"ok" | "new" | "error"`; retries
`Config.Save.loadRetries` times with backoff and never confuses "no data" with "error".
`save(userId, profile) -> ok` with the same retries. `markDirty()` + an autosave loop every
`Config.Save.autosaveSeconds` that saves only when dirty. `flush()` for the moments that
matter: after every match settlement, after season end, on the owner's `PlayerRemoving`, and
in `game:BindToClose`. A save is refused until a load has succeeded, so a failed load can
never be overwritten with a fresh club.

## Boot flow

`src/server/Session.luau` replaces the top of `Main.server.luau`:

1. `ClubState.init()` publishes `Phase = "Loading"`. Clients show a loading card and nothing
   else.
2. Wait for the first player; they become the owner (`OwnerUserId`).
3. `SaveService.load(owner)`. On `"error"` the owner is kicked with "Your club could not be
   loaded. Please rejoin." and the server waits for the next player. On `"new"` a fresh
   profile is created with a default name (`<DisplayName> FC`, TEMP) and `named = false`.
4. `Profile.normalize`, then `restore` on every service, then `WorldBuilder.build` with the
   saved stand / amenity / trophy levels. `Phase = "Manage"`.
5. Prompts and remotes are wired with an owner check.
6. A returning owner (`matchesPlayed > 0`) gets a **Welcome back** card: club, division,
   season, next opponent, cash.

Mid-match shutdown: the profile is saved *after* settlement, so a server that dies during a
match simply replays that fixture next time (result not yet applied, no money moved). If the
owner leaves mid-match the match still finishes and saves if the server is alive; otherwise
the same replay rule applies.

## Club naming (onboarding)

**(decision, TEMP)** On the first ever visit the owner names the club. `Onboarding.client`
shows a centred card with a TextBox pre-filled with the default and a "Found the club"
button when `ClubState.NeedsName` is true. Server `ClubName` remote (owner only, once):
trim, 3–24 characters, letters / digits / spaces / `'` / `-` / `.`, then
`TextService:FilterStringAsync(...):GetNonChatStringForBroadcastAsync()`. On a filter error
outside Studio the default name is kept (never show unfiltered text); inside Studio the name
is accepted so it can be tested. The name updates the active league table row too. Renaming
later is out of scope.

## Club history

`src/shared/History.luau` (pure): `new()`, `recordSeason(history, record)`,
`honours(history) -> { seasons, titles, promotions, relegations, bestTier }`.
**(decision)** A *title* is finishing 1st in any division, not only the top flight.

`SeasonService.endSeason` builds the record from the player's table row and calls
`HistoryService.record`. Club panel gains a **History** tab: honours line, all-time record
(P / W / D / L from `ClubState`), then one row per past season. New physical progression:
`WorldBuilder.buildTrophies(titles)` puts a shelf on the office's north wall with one small
gold cup per title (capped at 8 shown), rebuilt when a title is won.

## Client

- `HUD`: `Loading` phase card; "Welcome back" card (from the `Welcome` remote); the season
  line and hints treat `Loading` like a blank state.
- `Onboarding.client.luau` (new): naming card.
- `ClubPanel`: History tab; visitors see a "visiting" note instead of action buttons.
- `Match.client`: `Loading` behaves like `Manage`.

## Debug commands (Studio only)

`("save")` flush now, `("reload")` serialize → restore → rebuild world in one session (the
reconnect proof while DataStores are unavailable), `("wipe")` start a fresh profile.

## Tests

- `tests/ProfileTest.luau`: `new` shape; `normalize` fills missing sections, drops wrong
  types, clamps levels; a full profile survives `JSONEncode`/`JSONDecode` unchanged; a
  lineup with an empty XI slot round-trips.
- `tests/HistoryTest.luau`: records append in order; honours count titles, promotions,
  relegations and best tier.
- `tests/SaveServiceTest.luau`: with a `MemoryBackend`: new → save → load returns the same
  data; a backend failing twice then succeeding still loads; a backend that always fails
  returns `"error"` (not `"new"`); saving before a successful load is refused.
- Manual in Studio: play two matches, buy the stand, `reload`, confirm cash / squad / stand /
  table / history match. Then publish and repeat with real DataStores.

## Out of scope

Multiplayer visits, ownership transfer, session locking across servers (1 player per
server makes it moot), renaming, kit / stadium customisation, multiple save slots,
monetisation.
