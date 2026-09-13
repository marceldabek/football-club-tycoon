# Milestone 3 — Club Management (design)

Goal (CLAUDE.md §19): the player can identify at least one footballer they care about.
Adds: persistent generated squad with ratings, auto lineup, injuries, development,
coach, first scout with a 3-player shortlist, optional manual lineup and recruitment.

Everything stays server-authoritative and one-club-per-server (persistence is M5).
All numbers are TEMP and live in `Config`.

## Data

`src/shared/Squad.luau` (pure, deterministic with a seed):

```
Player = { id, name, number, role, age, overall, potential, injured, apps, goals }
  role      GK | DEF | MID | FWD (Pitch.Role)
  overall   30..99, starting squad averages ~45
  injured   matches still out, 0 = fit
Prospect = Player + { fee }
```

Functions:
- `generate(seed, avgOverall)` -> 16 players: 2 GK, 5 DEF, 5 MID, 4 FWD, shirt numbers 1..16.
- `autoLineup(players)` -> `{ xi = {id x11 by Pitch.ROLES}, bench = {id x<=5} }`.
  Best fit overall per role slot, injured excluded, out-of-role fill if a role runs out.
- `strength(players, xi)` -> mean overall of the XI, -6 per out-of-role starter.
- `matchSquad(players, xi, bench)` -> ordered list (XI then bench) in TeamGen.Player
  shape plus `overall`, so the presenter and HUD keep working unchanged.
- `nextSub(matchSquad, made)` -> lowest-overall outfield starter off, best unused bench
  player of the same role on (any role if none). Max `Config.MaxSubs`.
- `assignScorers(events, matchSquad, rng)` -> adds `scorer` (XI slot) to Home GOAL events,
  weighted FWD 5 / MID 3 / DEF 1. The presenter uses it as the shooter.
- `afterMatch(players, xi, scorers, coachLevel, rng)` -> mutates players; returns `news`
  (strings). Apps +1 for the XI, goals for scorers, injuries (`Config.InjuryChance` per
  starter, 1..3 matches), development (+1 overall with `Config.DevelopChance` x coach
  multiplier while age < 24 and overall < potential; -1 with small chance at 31+),
  injuries tick down for everyone who did not play.
- `prospects(seed, count, avgOverall, scoutLevel)` -> shortlist with fees.
- `fee(player)` -> TEMP formula from overall and headroom.

## Server

`src/server/ClubService.luau` (new) owns: `players`, `lineup` (xi/bench ids), `autoSquad`
(default true), `coachLevel`, `scoutLevel`, `shortlist`, `nextId`, `nextNumber`.
Publishes one JSON attribute `ClubState.Club` with all of it. Handles the `ClubAction`
RemoteEvent (Manage phase only):

- `setAutoSquad(bool)` — turning it on recomputes the lineup.
- `swap(idA, idB)` — refused while Auto Squad is on; swaps two ids between xi/bench/reserves,
  injured players cannot enter the XI.
- `hireScout` / `upgradeScout`, `hireCoach` / `upgradeCoach` — pay `Config.ScoutLevels` /
  `Config.CoachLevels` costs. Hiring a scout immediately generates a shortlist.
- `sign(prospectId)` — pay fee, squad cap `Config.SquadMax`, gets the next free shirt number.
- `release(playerId)` — free, not allowed below 14 players or for a current starter.

`prepareMatch()` -> `{ matchSquad, strength }`: with Auto on it recomputes; with Auto off it
replaces any injured starter with the best fit alternative. `finishMatch(result, scorers)`
runs `Squad.afterMatch`, refreshes the shortlist (new prospects every match) and republishes.

`MatchService` changes: home strength from `ClubService` + coach bonus (`Config.AwayStrength`
stays until M4's divisions), scorers assigned into the timeline, `Sub` via `Squad.nextSub`,
summary gains `news` lines. Match 1/2 bias unchanged.

`TeamGen` keeps generating away squads; `TeamGen.nextSub` is removed (replaced).

## Client

`src/client/ClubPanel.client.luau` (new): a centre panel opened from the office computer
prompt (client-side via `ProximityPromptService.PromptTriggered`) or a small `CLUB` HUD
button. Tabs:
- **Squad**: Auto Squad toggle; XI rows (slot role, #, name, age, OVR, INJ badge), then bench
  and reserves. Click one player then another to swap (Auto must be off).
- **Scouting**: locked until Match 1 is played; then Hire Scout; then shortlist with Sign
  buttons, fee, level/upgrade.
- **Staff**: coach level, effects text, hire/upgrade button.

The panel hides itself when the phase leaves Manage. `HUD` hint gains one step: after the
stand is expanded and before a scout exists, point at the office computer.

`MatchPresenter`: if an event carries `scorer`, that XI slot takes the shot.

## World

`WorldBuilder`: the office computer gets a ProximityPrompt "Club Office — Open".

## Tests

`tests/SquadTest.luau`: generation shape, lineup picks best fit per role and skips injured,
strength penalises out-of-role, nextSub caps at 3, scorers only on Home goals, afterMatch
development never exceeds potential and injuries tick down, prospects respect count and fee > 0.

## Out of scope (later milestones)

Tactic influence on the sim, contracts, wages, selling players for money, staff beyond one
coach and one scout, player traits, away matches.
