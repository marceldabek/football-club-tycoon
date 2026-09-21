# Football Club Tycoon — Project Setup & Build Plan

> **Put this file at the root of the project folder as `CLAUDE.md`.**
> Claude Code should treat it as the source of truth for the game unless Marcel explicitly changes a decision.

---

# 1. Project Goal

Build a **3D Roblox football-club management tycoon** where the player starts with a tiny, rundown grassroots club and grows it into a major football club.

The main fantasy is:

**Run club → play match → earn money → make meaningful investments → physically see club grow → get promoted → repeat**

The game should combine:

- classic Roblox tycoon progression
- light Football Manager-style management
- physical 3D stadium/club growth
- generated fictional players
- promotion through a fictional UK-inspired football pyramid
- strong visual progression
- simple enough onboarding for younger Roblox players
- enough management depth to reward older players who want control

The game should **not** become a full Football Manager clone.

---

# 2. Core Design Principles

1. **Fast first-time experience**
   - Player should reach the first match almost immediately.
   - Player should receive a meaningful visible upgrade within the first few minutes.

2. **Physical progression matters**
   - Stadium, office, facilities, stands, locker rooms, amenities, etc. visibly improve.
   - Avoid making the game feel like menus with a 3D lobby attached.

3. **Management is optional depth**
   - Automatic systems should let casual players progress.
   - Manual control should be available for players who want it.

4. **Meaningful spending choices**
   - Money should not only unlock one linear upgrade chain.
   - Player chooses between:
     - players/transfers
     - stadium capacity
     - scouting
     - coaching
     - amenities
     - training facilities
     - office upgrades

5. **The game is forgiving early**
   - Early progression should feel successful.
   - Difficulty ramps as divisions improve.
   - Eventually poor club management should produce losses.

6. **Do not simulate more than necessary**
   - The match should *look* like football.
   - It does not need real FIFA-level football AI.

7. **Prototype before polishing**
   - Use primitive geometry and placeholder assets first.
   - Do not spend days modeling before the loop is fun.

---

# 3. Locked Core Gameplay Decisions

## Club Role

The player is effectively a fictional **club owner / chairman / manager hybrid**.

Realism is secondary to giving the player control over the interesting parts of running the club.

---

## Season Structure

Initial target:

- **10 league matches per season**
- approximately **90 seconds per match**
- approximately **20–30 minutes per season**
- optional cup matches can add variation
- fictional UK-inspired promotion pyramid
- early promotion should be relatively easy
- later divisions should become progressively more difficult

Do not use real club/player names for the initial game.

---

## Match Flow

The player controls when the next match begins.

There is **no automatic countdown forcing the next game**.

Flow:

1. Player manages/upgrades club.
2. Player presses **Play Match**.
3. Club upgrades are locked during matchday.
4. Screen performs an **iris-style fade/close transition**.
5. Short player walkout / matchday presentation.
6. 90-second match begins.
7. Player can walk around the stadium and watch from different positions.
8. Match finishes.
9. Post-match result/revenue summary.
10. Normal club-management mode resumes.

### Match Simulation

Do **not** build a complete real-time football simulation for MVP.

Use:

- hidden statistical match simulation
- simple movement between predefined football zones
- default Roblox run/idle animations
- simple kick/pass animations
- scripted passes
- scripted shots
- basic keeper dive sequences
- scripted celebrations
- crowd reactions

The visual football only needs to convincingly represent the hidden simulation.

Initial animation categories:

- idle
- run
- kick/pass
- goalkeeper dive
- celebrate

The ball can initially move using controlled scripted motion rather than advanced football physics.

---

## Match Interaction

The player should remain able to walk around during matches.

Use a lightweight HUD instead of locking the player into a management screen.

Initial controls:

- **Attack**
- **Defend**
- **Sub**

The coach can automate these decisions.

Do not require interaction during matches.

---

## Early Match Difficulty

Opening experience should be intentionally favorable.

Target:

### Match 1
- heavily weighted toward a narrow win
- teaches matchday
- provides first useful amount of money

### After Match 1
- guide player toward an obvious physical upgrade

### Match 2
- strong chance of winning
- show that the player's investment had a measurable benefit

### First season
- relatively easy promotion if player engages with core systems

### Later
- difficulty rises
- losses become normal
- squad, coach, facilities and investment decisions increasingly matter

Never make the early rigging obvious to the player.

---

# 4. Stadium & Physical World

## Stadium

The stadium is one of the primary progression displays.

Early club should feel poor and grassroots:

- small pitch
- tiny stand / bleachers
- basic fences
- minimal lighting
- cheap amenities
- rundown facilities

Later:

- larger stands
- roofs
- hospitality
- better entrances
- improved lighting
- larger capacity
- upgraded concourses
- premium areas
- major professional stadium

### Customization

Do **not** make every player's stadium identical.

Initial customization can include:

- seat color
- stand style choice
- roof choice
- facade style
- banners
- decorative pieces

Later versions can offer deeper placement/customization.

Do not build a completely freeform stadium editor for MVP.

---

## World-Based Upgrades

Avoid old-school glowing tycoon purchase pads.

Use subtle world interaction.

Example:

> Walk up to a stand → prompt appears → “Expand North Stand — £8,000” → hold/interact to confirm.

Deep management can remain in menus, but **physical club upgrades should usually happen in the world**.

---

# 5. Office

The **office is the player's home base and spawn location**.

Early office:

- worn walls
- old desk
- old computer
- cheap chair
- minimal decoration
- generally rundown

Upgrades physically change the office:

- repainting
- improved desk
- better computer
- chairs
- tactics board
- trophies
- club branding
- nicer lighting
- better windows/interior

Office can contain access to deeper management interfaces:

- squad
- transfers
- scouting
- coaching
- finance summaries
- club information

---

# 6. Other Club Spaces

Include physical spaces as the club grows:

- locker room
- training facilities
- scouting/football operations area
- concession areas
- ticket/entrance areas
- club offices
- trophy display

Not all must have mechanics in MVP.

They can begin as visual/world-building spaces and gain functionality later.

---

# 7. Players & Squad

Use **fictional procedurally generated players**.

Players should develop attachment over time without requiring Football Manager-level detail.

Initial attributes:

- name
- age
- position
- overall
- potential
- health/injury state
- optional simple personality/trait later

Players should persist across seasons.

Players can:

- improve
- decline with age later
- get injured
- transfer in/out
- become club favorites
- accumulate appearances/goals/history later

Generated names can have some Roblox humor, but should still feel like recognizable footballers rather than pure joke characters.

---

## Squad Control

Default behavior:

- **Auto Squad ON**
- game selects lineup automatically

Manual management is optional.

After early onboarding, allow player to:

- pick starting XI
- manage bench
- make substitutions
- manually evaluate transfers

Always preserve an automatic option.

---

# 8. Scouting

A scout report arrives as a 3-card pack after **every** match, from Match 1. It opens from the folder on the office desk or from the Scouting menu.

With no scout hired, the pack is still there: walk-in trialists, mostly weak.

The Match 1 pack is special: the player keeps one of the three free.

Scout quality determines:

- quality of players discovered
- reach abroad
- accuracy of the reported potential

A better scout never means a longer list — every pack is 3 cards.

There is one pin slot: pinning a card holds it (and its fee) until the season ends.

Tier odds live in `Config.PackOdds`, so they can be published if packs are ever sold.

Do not show hundreds of players at once.

---

# 9. Coach

The player can hire and upgrade a coach.

Coach can influence:

- automatic lineup quality
- automatic substitutions
- tactical decisions
- player development
- potentially match performance

Casual players can let the coach run much of the football side.

Players who want control can override the coach.

---

# 10. Attendance

Attendance is driven by:

- **club popularity**
- **recent performance**
- **stadium amenities**
- match importance/opponent later

Actual attendance is capped by stadium capacity.

This should create a clear investment problem:

> Demand is 1,400 fans but stadium only seats 700 → player is leaving revenue on the table.

Crowds should visibly reflect attendance.

For performance reasons:

- do NOT spawn tens of thousands of fully simulated NPCs
- use efficient crowd representations
- pre-populated/section-based crowd visuals
- limited animated crowd characters where useful
- crowd density should visually change

The crowd does not need to physically walk into the stadium for MVP.

---

# 11. Economy

Main revenue sources can eventually include:

- tickets
- concessions
- sponsorship
- merchandise
- cup/prize money
- later premium/hospitality revenue

Main spending choices:

- transfers/players
- stadium
- scouting
- coach
- amenities
- training
- office/facilities

The important design goal is **tradeoffs**.

Example:

> Spend £15,000 on a striker now, or increase stadium capacity and generate higher income every match?

Avoid an economy where one upgrade path is always obviously correct.

The game should be forgiving enough that one poor purchase does not permanently ruin a save.

---

# 12. First 5 Minutes

This is extremely important.

Target onboarding:

### Minute 0–1
- Spawn in poor office.
- Very short guidance.
- Walk outside and immediately see tiny grassroots club.

### Minute 1–3
- Player starts first match.
- Short matchday transition/walkout.
- First match occurs.
- Likely narrow win.

### Minute 3–4
- Show:
  - result
  - attendance
  - revenue
  - profit
- Point toward one obvious physical upgrade.

### Minute 4–5
- Player buys first upgrade.
- Upgrade physically changes club.
- Player sees immediate improvement.

Soon after:
- second match
- scouting/coach systems begin opening up
- deeper management becomes optional

Do not front-load squad setup, tactics setup or lengthy tutorials.

---

# 13. Long-Term Progression

Primary long-term goal:

**grassroots club → promotions → top domestic division → fictional Champions League-equivalent → repeated success / dynasty**

Endgame does not need a traditional Roblox rebirth mechanic.

Possible long-term reasons to continue:

- repeated league titles
- continental trophies
- club history
- stadium prestige
- rare/high-potential players
- record chasing
- building a dynasty
- social comparison/visiting other clubs
- difficult late-game competition

Exact endgame pressure is intentionally **not locked yet**.

Test the core game before designing complicated late-game failure systems.

---

# 14. MVP Scope

Build the smallest version that proves the loop.

## MVP MUST HAVE

- one physical grassroots stadium
- basic office
- one simple stadium upgrade
- cash
- 10-match league data structure
- first two-match onboarding
- hidden match simulator
- simple 3D match visualization
- 90-second match
- matchday transition
- simple crowds
- post-match summary
- attendance
- basic generated players
- automatic lineup
- Play Match button
- Attack / Defend / Sub HUD hooks
- persistent save data after core systems stabilize

## MVP DOES NOT NEED

- real clubs
- real players
- real leagues
- advanced animations
- realistic football physics
- complicated tactical system
- huge transfer market
- complete stadium customization
- multiplayer stadium visits
- monetization
- polished Blender assets
- huge crowd NPC simulation
- continental competition
- detailed contracts
- detailed staff system

Build those only after the MVP loop is genuinely fun.

---

# 15. Development Stack

## Primary

- **Roblox Studio**
- **Claude Code**
- **Roblox Studio MCP**
- **Git**
- **GitHub**

## Recommended Code Sync

Use **Rojo 7** once the disk-based project is established so scripts/source files are easy to version, diff and edit outside Studio.

The Studio MCP server should be used for:

- inspecting the live Roblox data model
- creating/editing instances
- running Luau
- playtesting
- inspecting the game during agent work

Rojo/Git should become the source of truth for maintainable code.

---

# 16. Windows Setup

## Step A — Create project folder

Open **PowerShell**:

```powershell
cd $HOME\Desktop
mkdir football-club-tycoon
cd football-club-tycoon
git init
```

Put this file in that folder as:

```text
CLAUDE.md
```

Then open the folder in VS Code:

```powershell
code .
```

---

## Step B — Roblox Studio

Install/update Roblox Studio.

Create a new **Baseplate** experience.

Save/publish it under a temporary project name such as:

```text
Football Club Tycoon Prototype
```

---

## Step C — Enable Roblox Studio MCP

Inside Roblox Studio:

1. Open **Assistant**.
2. Open the `...` menu.
3. Choose **Manage MCP Servers**.
4. Turn on **Enable Studio as MCP server**.
5. Use **Quick Connect** for **Claude Code** if it appears.
6. Confirm the MCP connection indicator is active.

Roblox currently supports Quick Connect for Claude Code.

If Quick Connect is unavailable, Roblox's Windows MCP command is:

```text
cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat
```

Prefer the built-in Quick Connect path.

---

## Step D — Claude Code

Start Claude Code from the project root.

Example:

```powershell
cd $HOME\Desktop\football-club-tycoon
claude
```

Claude should automatically read this `CLAUDE.md`.

Initial instruction:

> Read CLAUDE.md completely. Do not build the entire game. First inspect the open Roblox Studio baseplate through MCP and propose the smallest implementation plan for Milestone 1. Keep the first playable loop intentionally ugly and simple. Do not add systems that are not required for the milestone.

---

# 17. Rojo Setup

Do this early, but do not let setup block the first playable prototype.

Rojo 7 is recommended.

With Rojo installed:

```powershell
rojo init football-club-tycoon-rojo
```

If using the existing project directory, use the VS Code Rojo extension to initialize the current folder rather than accidentally nesting the project.

Typical development flow:

```powershell
rojo serve
```

Then connect the Rojo plugin inside Roblox Studio.

Goal:

```text
files on disk
    ↓
Rojo
    ↓
Roblox Studio
```

This makes Claude/Git edits much easier to manage.

---

# 18. Suggested Repository Structure

Target structure:

```text
football-club-tycoon/
│
├─ CLAUDE.md
├─ README.md
├─ .gitignore
├─ default.project.json
│
├─ docs/
│  ├─ DESIGN.md
│  ├─ ECONOMY.md
│  └─ MATCH_SIM.md
│
├─ src/
│  ├─ client/
│  ├─ server/
│  └─ shared/
│
├─ assets/
│  └─ references/
│
└─ tests/
```

Do not create lots of empty architecture just for appearance.

Let the structure grow with the game.

---

# 19. Development Milestones

## Milestone 1 — Ugly Playable Loop

Goal:

**Press Play Match → get a result → get money → purchase one visible upgrade.**

Build only:

- tiny pitch
- office block
- one basic stand
- cash value
- Play Match interaction
- 90-second placeholder timer
- hidden result calculation
- post-match payout
- one physical stadium upgrade

No real football visualization yet if it slows this milestone down.

### Success test

A brand-new player can understand:

> play → earn → upgrade

without an explanation.

---

## Milestone 2 — Matchday Illusion

Add:

- iris transition
- player walkout
- generated teams
- simple player movement
- pass/kick animation
- ball movement
- simple shot sequences
- keeper dive
- crowd reaction
- Attack / Defend / Sub interface

### Success test

Watching one 90-second match does not feel painfully boring.

---

## Milestone 3 — Club Management

Add:

- generated squad
- auto lineup
- simple player ratings
- injuries
- coach
- first scout
- three-player scout shortlist
- optional manual lineup
- optional manual recruitment

### Success test

Player can identify at least one footballer they care about.

---

## Milestone 4 — First Season

Add:

- 10-match season
- table
- opponents
- promotion
- difficulty scaling
- attendance
- performance/popularity system
- amenities

### Success test

Completing a season creates a strong desire to play the next division.

---

## Milestone 5 — Save & Retention

Add:

- DataStore persistence
- club history
- player persistence
- stadium persistence
- reliable reconnect behavior
- first proper onboarding

Only after this point should serious monetization planning begin.

---

# 20. Art / Modeling Strategy

Do **not** make custom 3D modeling the blocker.

Priority:

1. Roblox primitive Parts
2. safe Creator Store assets
3. Roblox AI-generated/model-generation tools
4. procedural Roblox construction
5. Blender/Astra only for assets where custom quality matters

Examples that can be primitives/procedural:

- stands
- office
- fences
- basic buildings
- entrances
- concourse
- field infrastructure

Examples that may eventually deserve custom assets:

- unique trophy
- club bus
- premium turnstiles
- distinctive training equipment
- signature stadium architecture

First prototype should look intentionally simple.

---

# 21. Agent Rules

Claude Code should follow these rules:

1. **Never build a giant feature batch without testing.**
2. Work milestone by milestone.
3. Keep Luau modules small and understandable.
4. Separate simulation logic from presentation.
5. Match outcome simulation must not depend on visual animation succeeding.
6. Use deterministic/random seeds where helpful for testing.
7. Preserve automatic management options.
8. Avoid unnecessary dependencies.
9. Do not insert random Creator Store models containing unknown scripts.
10. Before large structural changes, explain the plan.
11. After each meaningful feature:
    - test it
    - summarize what changed
    - list known bugs
    - commit once stable
12. Keep mobile Roblox performance in mind.
13. Prefer simple systems that can be expanded later.
14. Do not add realism just because real football has it.
15. Optimize for **fun, clarity, progression, retention**.

---

# 22. Architecture Rule: Simulation vs Presentation

This is important.

The match should have two layers.

## Simulation layer

Determines:

- possession abstraction
- scoring chances
- goals
- injuries
- substitutions
- final score

This should work even with no 3D animation.

## Presentation layer

Receives events such as:

```text
PASS
ATTACK
SHOT
GOAL
MISS
SAVE
FOUL
SUBSTITUTION
```

and turns them into simple 3D sequences.

This lets visual football improve later without rewriting the game logic.

---

# 23. First Implementation Prompt for Claude Code

After setup, send this:

> Read CLAUDE.md fully and inspect the currently open Roblox Studio experience through MCP. We are beginning Milestone 1 only. Build the smallest possible ugly playable prototype of the core loop: a rundown office/spawn, a small football pitch, one primitive stand, a cash system, a world-based Play Match interaction, a temporary match timer/result simulator, post-match revenue, and exactly one physical stadium upgrade that can be bought with earned money. Do not build scouting, transfers, animations, leagues, detailed UI, monetization, or advanced assets yet. Keep simulation logic separate from presentation. Test the complete loop in Studio before considering Milestone 1 finished. Ask me only when a design decision genuinely blocks implementation.

---

# 24. Definition of "Ready for Real Development"

Do not polish until all of these are true:

- [ ] starting the game is understandable
- [ ] player reaches first match quickly
- [ ] match completes reliably
- [ ] player gets money
- [ ] player understands what to spend it on
- [ ] physical upgrade visibly changes the club
- [ ] second match feels like progress
- [ ] loop is fun enough to repeat
- [ ] no major mobile-performance issue
- [ ] code structure can support later management systems

If the loop is boring, fix it before adding features.

---

# 25. Current Open Questions

These are intentionally undecided:

- exact fictional league/division names
- exact promotion/playoff rules
- first upgrade choice
- economy numbers
- club naming flow
- detailed player attributes
- exact injury frequency
- exact coach ratings
- exact scouting rarity/potential curves
- cup structure
- late-game difficulty pressure
- online 1v1 match controls (needs its own design talk, J0 in docs/WORLD_ROADMAP.md)
- monetization
- daily/returning-player systems
- final stadium customization depth

Do not silently decide these unless they are required for a prototype. Use temporary values where appropriate and label them clearly.

---

# 26. Current Priority

**Build one ugly but satisfying loop before trying to build the game.**

The first question is not:

> “Can we make a giant football management tycoon?”

It is:

> **“Is playing a match, earning money, and physically improving my tiny club satisfying enough that I want to do it again?”**

Everything else follows from that.

---

# 27. Town & Multiplayer Direction (decided 2026-09-16)

The game is moving from one club per server to a **shared multiplayer town**. Full answers live in `docs/WORLD_ROADMAP.md` section 4 (Q1–Q39, all **DECIDED**). Vision is in `docs/WORLD_VISION.md`. Concept art goes in `assets/references/town/`.

## Town

- The town is **Rivermere**. Many concept images say "Riverdale": always use Rivermere instead. The river is the **River Lune**.
- District names (from the concept map): **Northfields**, **Westdale**, **Riverside**, **Riverside Park**, plus Town Centre, Station and Industrial Estate.
- Every player club is from Rivermere.
- The concept map is the target idea, not an exact copy: a river through the middle with bridges, a railway and station, a town centre with a market square, terraced housing estates, an industrial estate, a riverside park, a community sports centre, and **club grounds on the edge of town**.
- Landmarks: church spire, river bridge, railway viaduct over the river.
- Scale it down so it can be walked on Roblox.
- **Use the reference images in `assets/references/` whenever possible.** Check the matching image before building or restyling anything in town, and compare the result against it.
- Build districts one at a time. Start with a terraced-housing district next to the town centre.

## Plots & players

- **4 club plots per server.**
- When loading in, the player switches between the free plots and picks one.
- A plot holds the stadium, office, car park, club shop and a couple of training pitches. The biggest endgame stadium should look like roughly 30k seats.
- An empty plot is a lot with a "for sale" sign, trees and some rocks.
- A player's club despawns when they leave, and the plot goes back to the for-sale lot.
- Players spawn in their own office.
- To get around: walk and sprint, a "go to my club" button, and bus stops that fast-travel to other clubs, the town centre and landmarks.
- Target device: a mid-range phone, with quality settings.
- Later idea (not scheduled): buy a car and a house to show off wealth.

## Time & lighting

- Time of day is **client-side, per player**.
- 1 match = 1 week, shown visually only.
- Normal play stays on one fixed afternoon look.
- Fast-forward is ~4 s after each match and ~10 s at season end, always skippable.
- Most matches are in the afternoon, with some evening games under floodlights.
- Depth of field is only used in menus, close-ups and the intro.

## Matchday & influence

- Fans and stewards around the playing club's ground are visible to everyone. Town-wide banners and busy pubs show only on that player's screen.
- Each player's screen shows the town in their club's identity. The neighbourhood around each ground changes for everyone as that club grows.

## Assets

- Budget is $500 (see `docs/ASSET_KIT.md`).
- Creator Store kits are fine with scripts stripped, and Marcel approves the buy list.
- The asset kit sets the style, and the stadium is restyled to match it.
- Streets and props are placed by code from layout data. Hand-built showpiece pieces are `.rbxm` files in the repo.
- AI mesh generation is fine for props. For buildings, prefer bought or downloaded assets.
- Audio comes from Roblox's licensed library first.
- Club shop and training ground are visual first, with mechanics in a later gameplay milestone.

## Social & online

- **Friendlies:** no injuries, a small payout to the home club, no effect on the league.
- No cash gifts; cash only moves as part of a player trade.
- Trades are same-server only at first, with no anti-abuse limits for now.
- **Save lock:** a new server waits for the save lock, then loads, and the old session closes.
- **Online matchmaking:** career squads matched within strength bands. Queue time matters more than region.
- Online wins pay cash into the career, plus trophies and rating, with no weekly cap for now.
- Leaderboards: a seasonal rating ladder and a friends board.
- What each human controls in a 1v1 is still undecided and needs its own design talk before any online work.
