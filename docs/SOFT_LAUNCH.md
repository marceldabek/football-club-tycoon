# Soft Launch Readiness

Goal: publish a public **beta**, buy a small amount of ad traffic, and read retention and the first-session funnel to find out whether the loop works. Not a full launch. No monetization.

Written 2026-09-21 from a read-only audit of the repo. File references were correct on that date. Items reference `docs/BACKLOG.md` X-numbers where one exists.

Status key: `[ ]` open, `[x]` done, `[M]` needs Marcel (Studio setting, device, account or decision).

---

## What is already in good shape

- Saves: session lock, 3-try retry, versioned migrations, save refused before a successful load, owner kicked rather than given a blank club on load failure (`SaveService.luau`, `SaveLock.luau`, `Profile.luau`, `Session.luau`). No memory fallback outside Studio.
- Every remote validates on the server; the client never sends prices (`ClubService.luau:410-636`, `TradeService.luau:108-213`).
- Debug commands are only connected in Studio (`Main.server.luau:30-176`).
- Match 1 and 2 rigging, the rigged first pack and scout-hire guard are all in (`MatchSim.luau:86-93`, `ClubService.luau:157-161, 547-549`).
- World interactions are ProximityPrompts, UI scales to the viewport, quality defaults to Low on touch.
- A mid-match error returns the club to Manage instead of sticking (`MatchService.luau:554-573`).

---

## Gate 1 — Know what we are shipping

- [x] **SL1. Disk and place file agree.** (DONE 2026-09-21: Rojo live, `tools/parity_digest.py` reports all 247 scripts match, RunAll 879/879 at `b5917f3`. Re-run the digest right before publishing; Marcel must save the place so the synced scripts are in the file.) Originally 43 of 194 scripts differed (X347, X345).
- [x] **SL2. Commit the dirty working tree** (DONE 2026-09-21, `9b01ff8`: card art keyed PNGs, Clubhouse light shadows, goal on the line.) once stable, so the published build maps to a commit.
- [x] **SL3. Build label.** (DONE 2026-09-21: `Shared.Build` holds tag + version, shown faint bottom-right of the HUD and on the loading screen. Bump `Build.version` when publishing.) Small "BETA · <short commit or date>" text in a HUD corner, so a bug report names a build.

## Gate 2 — Saves are final

- [x] **SL4. Final DataStore name.** DECIDED 2026-09-21: `ClubProfiles` stays and is now final. The "bump to reset" comment in `Config.luau` is replaced with a never-rename note; save-shape changes go through `Profile.MIGRATIONS`.
- [x] **SL5. Beta save policy.** DECIDED 2026-09-21: beta saves carry over to the full game. Say so in the game description (SL27).
- [x] **SL6. Trade save is not atomic (X365).** (DONE 2026-09-21: on accept both sessions `saveNow` before anything moves - a refused write cancels the trade with nothing moved, `TradeSaveRefused` event; the offer is re-checked after the yield; after the swap a failed save is toasted to both owners, `TradeSaveFailed` event. Needs the SL12 two-client run to see it live.) Check both sessions can save before anything moves; surface a failed `saveNow` to both owners. Alternative for the beta: switch trades off (see SL10).
- [x] **SL7. LastRound lost on rejoin (X366).** (DONE 2026-09-21: `SeasonService.restore` rebuilds it from the played fixtures; verified with `reload` after a match.) Republish from `season.fixtures` on restore.
- [ ] **SL8. Published-place save test.** On the live place, not Studio: found a club, play, leave, rejoin; rejoin on a second device while the first is still in (lock handover); leave mid-match (180 s settle, `PlotService.luau:404-419`).
- [x] **SL9. Crest edit write spam.** (DONE 2026-09-21: one immediate save per 10 s per club; later changes inside the window still apply and ride the 30 s autosave.) General remote rate limiting is a nice-to-have.

## Gate 3 — Multiplayer is decided

- [x] **SL10. Pick the beta server shape.** DECIDED 2026-09-21: MaxPlayers 4 with trades and friendlies **on**, bugs accepted for the beta. SL6 (trade duplication) stays worth fixing because a duplicated player lives on in a save that carries over. Original options: No multiplayer path has been run with two real clients (B2.1d, I3.1d, I4.1d, X39; X206–X211 and X237 all "needs a two-player check").
  - Option A (recommended): **MaxPlayers = 4**, keep plots, and switch off trades and friendlies for the beta behind a Config flag. Removes X365 and the untested paths from the launch. Still needs one two-client test of claim, leave, re-claim and save lock.
  - Option B: MaxPlayers = 1. Safest, loses the shared town.
  - Option C: everything on. Needs the full two-player test list first.
- [x] **SL11. Set `MaxPlayers` on the place.** (DONE 2026-09-21: set to 4 by hand in the place settings.) DECIDED 2026-09-21: **4**. Not in the repo. With 4 plots, anyone past the fourth player is a spectator with no club, which wastes ad clicks.
- [ ] **SL12. Two-client test** of whatever SL10 keeps (Studio local server with 2 players, then the live place with two accounts).

## Gate 4 — The first five minutes survive cold traffic

- [x] **SL13. Cold-server join window.** (DONE 2026-09-21: `ReplicatedFirst.LoadingScreen` (new `src/first`, mapped in default.project.json - restart `rojo serve` once to pick the folder up) covers the screen from the first frame until Main sets `ReplicatedStorage.TownReady`; 90 s safety cap. Verified in Play. PlotService still starts last; moving it earlier is not needed now the cover hides the build.) `Main.server.luau:193-268` builds the whole town (10+ s) before `PlotService.start()`; until then there is no spawn, no picker and no UI, and there is no `ReplicatedFirst` loading screen. Add a ReplicatedFirst cover that holds until the picker is ready, and start PlotService as early as is safe.
- [x] **SL14. Founding card escape hatch.** (DONE 2026-09-21: "Suggest one" link on the name section fills the box from `Shared.ClubNames` (15 Rivermere names); the server accepts a listed name without the text filter, so it succeeds in an outage; the server's refusal reason is copied under the box with "Or tap Suggest one." `ClubNamesTest` proves every suggestion passes the length / charset / league-name rules. Checked in Play: refused a league name, founded as Lune Valley FC.) No cancel, non-ASCII names refused, filter outage loops the player.
- [x] **SL15. Round 1 at home.** (DONE 2026-09-21: `League.newSeason` swaps every fixture's ends when the player would open away; `LeagueTest.playerAlwaysOpensAtHome`.) About half of new players get an away first fixture and see roughly £120 instead of ~£1,230 at the first payout (`League.luau:64-72`, `Economy.luau:160-188`). Force the player's round 1 (ideally 1 and 2) to be home.
- [x] **SL16. Silent re-claim.** (DONE 2026-09-21: "Still loading your club" toast when a claim is in flight; the picker's button steps through BUILDING / LOADING YOUR CLUB / WAITING FOR YOUR LAST SESSION TO SAVE and its timeout is 60 s, since a lock handover alone can take 30 s.) Toast when a claim is already in flight and show progress during a slow club load.
- [M] **SL17. First stand is free on three of four plots** (OVERNIGHT_LOG question 18). Recommended: leave it for the beta; a free first upgrade is a fast visible win. Revisit with funnel data.
- [ ] **SL18. Fresh-account run-through** on the published place, timed against CLAUDE.md section 12.

## Gate 5 — It runs on a phone

- [x] **SL19. Set the six Workspace streaming properties by hand** (DONE 2026-09-21, set in Studio and the place saved.) (`docs/TOWN_V3_PERF.md:124-127`). Not script-accessible; the perf doc records them as unset when measured.
- [M] **SL20. Real-phone frame rate** at the Market Square, at a plot in Manage, and during a match with a full crowd. Frame time has never been measured (`TOWN_V3_PERF.md:7-9`). Target 30 fps on Low. If the town fails, thin the Low budgets before launch.
- [ ] **SL21. Touch sprint button.** (WRITTEN 2026-09-21: RUN toggle above the jump button, placement checked on desktop with a stand-in jump button. Tick after it is tapped on a real phone in SL22; it does not yet hide behind fullscreen menus.) `Sprint.client.luau` is Shift only; the town is a 2–3 minute walk.
- [M] **SL22. Touch pass** on the founding card, lineup drag and pack opening (X241, X252).

## Gate 6 — We can see what happens

- [x] **SL23. Onboarding funnel** (DONE 2026-09-21: `Shared.Telemetry`; the funnel is the linear steps only - Joined, GroundClaimed, ClubFounded, Match1Started, Match1Finished, Match2Finished, Match5Finished, Season1Finished - and first upgrade / pack / signing are custom events `UpgradeBought`, `PackRevealed`, `PlayerSigned`, since a player can do them in any order. Studio sends nothing; verify on the live place's dashboard.) Original plan: via `AnalyticsService:LogOnboardingFunnelStepEvent`, one small server module. There is no analytics of any kind today. Steps and hook points:
  1. joined — `PlotService.luau:613-620`
  2. ground claimed — `PlotService.luau:376-383`
  3. club founded — `Session.luau:367-372` (count refusal reasons at `:329, :334, :341, :355, :364` as custom events)
  4. match 1 started — `MatchService.luau:416-419`
  5. match 1 finished — `MatchService.luau:509`
  6. first upgrade bought — `UpgradeService.luau:134-138, 151-155`
  7. first pack opened — `ClubService.luau:473-481`
  8. match 2 finished — `MatchService.luau:509`
  9. first signing — `ClubService.luau:636`
  10. season finished — `SeasonService.luau:234`
- [x] **SL24. Economy events** (DONE 2026-09-21) from the one choke point `ClubState.addCash` (`ClubState.luau:81`), which already carries a category.
- [x] **SL25. Save health.** (DONE 2026-09-21: `SaveFailing`, `ClubLoadFailed`, `JoinedServerFull`, plus the five `NameRefused*` / `NameFilterOutage` events.) Custom event on failed flush (`Session.luau:270-278`) and on "server full, joined as visitor".
- [ ] **SL26. Feedback channel.** (2026-09-21: Marcel will set up a Roblox group eventually; Discord understood. The in-game button waits for a link.) A Roblox group or Discord link plus a small in-game feedback button. [M] to create the group/server.

## Gate 7 — Store page and ads

- [x] **SL27.** (DONE 2026-09-21.) Experience questionnaire (maturity and content), icon, thumbnails, description with BETA and the save policy, title with "[BETA]".
  - Questionnaire answers (2026-09-21): unplayable gambling **No** (packs are playable and free); paid item trading **No** (nothing is bought with Robux). Decision for later: when packs or anything else are sold for Robux, keep the answer No by design - Robux-bought players get a `paidOrigin` flag that `TradeService` refuses to trade, and Robux never buys cash. Saying Yes would hide the experience from under-13s and some regions.
- [M] **SL28.** Confirm every Creator Store asset in the place is script-free and licence-clean.
- [M] **SL29. Ad test.** Check current formats and minimums in Ads Manager (not verified here). Small daily budget for 3–5 days, mobile-weighted, aiming for a few hundred to a few thousand plays.
- [M] **SL30. Read a week of data before building anything new.** Decision numbers (temporary, adjust after the first read): D1 retention 15–20 %+, average session 10 min+, joined → match 1 finished 60 %+, match 1 finished → first upgrade 70 %+.

---

## Not blocking the beta

- Injuries never heal at season rollover (X367).
- Leaving mid-match and rejoining elsewhere can dodge a loss (OVERNIGHT_LOG question 17).
- A club that has never signed anybody cannot release or sell (X363).
- X360 "tactics are decoration" looks superseded by X271 (`MatchService.luau:97-122`); verify and close the entry.
- `ScoutReportNew` glow not persisted.
- General remote rate limiting and DataStore request-budget checks.
- Stale one-club-per-server comments (`ClubState.luau:3`, `WORLD_ROADMAP.md:17`); Phase B not marked done in the roadmap.
- Dead debug surface in live builds (`PlotService.debugModules`, `TradeService.debugRoundTrip`).
- Roundabout car overlap, streets without turning heads.

---

## Suggested order

1. SL1, SL2 (know the build)
2. SL4, SL5, SL10, SL11 decisions
3. SL23–SL25 analytics, SL3 build label
4. SL13–SL16 first-five-minutes fixes, SL21 sprint
5. SL6 or trades off, SL7, SL9
6. SL19, SL20, SL22 phone pass
7. Publish privately: SL8, SL12, SL18
8. SL26–SL29, go public, SL30

## What is left (2026-09-21, end of day)

Everything still open needs Marcel or the published place:

- **SL20, SL22** real-phone frame rate and touch pass.
- **SL8, SL12, SL18** published-place runs: save round trip, two clients (claim / leave / re-claim / lock handover / one trade), fresh-account timing.
- **SL17** decision on the free first stand (recommended: leave it).
- **SL26** group or Discord link for the feedback button.
- **SL28–SL30** asset licence check, ad test, read the data.
