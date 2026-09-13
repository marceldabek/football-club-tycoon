# Milestone 4 — First Season (design)

Goal (CLAUDE.md §19): completing a season creates a strong desire to play the next division.
Adds: a 10-match season with a table and fixed opponents, promotion / relegation through a
fictional pyramid, difficulty scaling by division, popularity-driven attendance, amenities.

Builds on M3: opponents now have division-driven strength; the club's squad, coach and
facilities are what let it keep up. All numbers are TEMP and live in `Config`.

## League structure

- 6 teams per division, double round robin = **10 matches** per team, 3 matches per round.
- The player's fixtures are all **presented at home** (one stadium; TEMP, labelled). The
  other two fixtures each round are simulated with `MatchSim` (fair, no bias).
- 5 divisions (TEMP names in `Config.Divisions`, bottom to top). Each has `baseStrength`,
  `demandBase` and `prizeMultiplier`. AI team strength = base + a fixed per-team offset
  (-4..+4) with a small per-match jitter.
- Top 2 go up, bottom 2 go down (not past the pyramid ends). Ties: points, goal difference,
  goals for.
- Match 1 / Match 2 onboarding bias is unchanged (global match index).

## Season end

After the 10th match: season summary (position, promoted / relegated / stayed, prize money by
position × division multiplier), every player ages a year (`ClubService.newSeason`),
popularity shifts, new division with newly generated opponents, `Season` counter +1.

## Attendance

`Popularity` 0..100 starts at `Config.StartingPopularity`. Win +3, draw +1, loss -2,
promotion +10, relegation -10 (TEMP). Demand:

```
demand = demandBase[tier] * (0.5 + popularity / 100) * (1 + amenityDemandBonus)
attendance = min(demand, capacity)
```

`Economy.settle` gains concessions: `attendance * amenityPerFan`.

## Physical upgrades

- Stand levels 3 and 4 (1000 / 2500 seats) so capacity keeps mattering as demand grows.
- One amenity chain on the concourse: Snack Bar → Club Shop (kiosk with a prompt). Each level
  adds per-fan revenue and a demand bonus.

## Modules

- `src/shared/League.luau` (pure): `newSeason(tier, seed, clubName)`, round-robin fixtures,
  `playerFixture`, `simulateRound` (other matches), `record`, `standings`, `positionOf`,
  `outcome`. Team name pools per division, kit colours.
- `src/shared/Economy.luau`: `demand(...)`, `popularityAfter(...)`, settle with concessions.
- `src/server/SeasonService.luau`: owns tier / season / round / popularity / league; publishes
  `Tier`, `DivisionName`, `Season`, `Round`, `Popularity`, `Demand`, `NextOpponent`,
  `LeagueTable` (JSON). `nextFixture()`, `recordPlayerResult()`, `endSeason()`.
- `MatchService`: opponent from `SeasonService`, away strength from the fixture, opponent
  visual squad seeded per team so names repeat on the second meeting, demand from `Economy`,
  summary carries league position and (at match 10) the season summary.
- `UpgradeService`: stand levels to 4, amenity prompt. `WorldBuilder`: bigger stands, kiosk.

## UI

- HUD: season line under cash ("Sunday Parks League · Match 3/10 · 4th"), banner shows the
  round, summary adds league position and concessions, a **Season Over** panel after the final
  match's summary.
- Club panel: **League** tab with the table (player row highlighted) and the next opponent.

## Tests

`tests/LeagueTest.luau`: fixture shape (10 per team, each pair twice, 3 per round), standings
order and tiebreaks, outcome at the pyramid ends, simulateRound leaves the player's fixture to
the caller. `tests/EconomyTest.luau`: demand scaling, popularity clamps, concessions.

## Out of scope

Cups, away matches, playoffs, ticket pricing, sponsorship, multiple stadium stands as separate
purchases, persistence (M5).
