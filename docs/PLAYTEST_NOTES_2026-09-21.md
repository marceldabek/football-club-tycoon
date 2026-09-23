# Playtest notes — 2026-09-21

Marcel's bug and feedback list from a playtest of build 0.1.1. Listed only; nothing here is fixed yet.
Numbers are stable so they can be referenced in commits and later notes.

**Suggested order:** do #26 (2D layout plan) first. It turns #5, #7, #11, #12, #14, #15, #20–#23 and #25 from guesswork into build-to-plan work.

---

## Match presentation

1. **Iris transition gets stuck on ultrawide.** ✅ Done 2026-09-23 (X370): Marcel chose to remove the iris entirely; every transition is now a plain fade to black. On an ultrawide screen, the iris zoom effect stays on screen for the whole match. There's a round black mask cutting off the left and right edges, so you only see the middle of the view. It looks like the iris is sized for a normal screen shape and never opens wide enough for a very wide one.
2. **Floodlights don't light the pitch at night.** In evening matches the floodlight heads glow, but the pitch is still almost black. You can barely see the players, the ball or the lines. Either the lights' range and brightness can't reach the grass, or they're pointed in the wrong direction. May be partly #21.
3. **Player names should show more often.** Name labels over players' heads should stay visible the whole match, or at least appear much more often than they do now.
4. **Assistant referees need flags and should follow the defensive line.** The linesmen should hold a flag. They should also move up and down the touchline level with the last defender, so it looks like they're watching for offside.

## Stadium and ground layout

5. **Fill the gap in the west stand above the clubhouse (plan for later).** The two west stand wings stop on either side of the brick clubhouse, and above it there's just open sky. Plan a stand section that sits over the clubhouse/office roof and joins the two wings, so it looks like one continuous stand. This is a design and planning item, not an urgent fix.
7. **The concourse is in the wrong place.** The concourse should be inside the ground, past the turnstiles and behind or under the stands. Right now it's outside, in the corner against the stand's brick wall. Its pieces are also basic primitive blocks: the food kiosk, counter, flags and "CONCOURSE" sign. It needs to move inside the ground and get proper models.
12. **The clubhouse concession window doesn't work.** The concession window in the main clubhouse building looks good, but nothing ever uses it. No path leads to it, and it faces a side where it doesn't make sense. The gap between the clubhouse and the stand wing could fit an access route, but it's a weird spot. The long-term plan is to put concessions inside the stands, with fans using each stand's own tunnels.
    - **Suggestion:** take the window off the clubhouse for now, and handle concessions as part of #7's move inside the ground.
13. **Stand ends have no side railings.** The far left and right ends of every stand are open. The rows of seats just stop, so a player could walk or jump straight off the side. Each stand needs an end railing or side wall running from the bottom row to the top, on all four stands and at every upgrade tier.
15. **The ground's layout doesn't make sense.** Going through the corner turnstile puts you straight onto the pitchside paving, right next to the grass. There's also no way up into the stands: the backs are solid brick walls with no stairs, entrances or tunnels. The ground needs a clear inside and outside, with a real path from the entrance to the seats.
    - **Marcel's idea:** move the turnstiles out towards the road entrance.
    - **Suggestion instead:** leave the turnstiles near the stadium, not at the road. If they sit at the road, the whole plot becomes the ticketed area, and the car park, club shop and clubhouse lawn would all end up "inside the ground". Real grounds work like this:
      - a perimeter wall or fence wraps the stadium, meaning the stands plus a strip of paving behind them;
      - the turnstiles are set into that wall, facing the plot paths;
      - just inside the wall is the concourse strip (#7), with food, drinks and toilets;
      - stairs or tunnels (vomitories) at the back or ends of each stand lead up to the seats;
      - a low wall or fence keeps fans off the pitchside paving.
    - On that layout, the car park, club shop, clubhouse front and team coach all stay outside, where they make sense.
20. **Add a short wall behind the advertising boards.** Put a low wall around the pitch, just behind the line of sponsor boards, between them and the stands. Right now the boards stand on their own, and the paved strip behind them is open. It ties into #15: this is the same low wall that keeps fans off the pitchside paving.
21. **Move the floodlight towers much closer to the pitch.** The tall floodlight masts stand too far out from the ground. Bring them right in, to just behind the stands or at the corners of the ground. This probably ties into #2.
26. **Plan the whole ground on 2D maps first (planning task).** ✅ Done 2026-09-22: maps in `docs/ground_plan/`, approved spec in `docs/superpowers/specs/2026-09-22-ground-plan-design.md`. Before building any more of the layout, spawn an agent to draw a top-down 2D map of the plot as an SVG, one map per stadium upgrade level. Marcel reviews the maps and agrees on one version, and only then does anyone build it. Each map should show:
    - the stands, pitch, ad boards and low wall (#20), and the floodlight masts (#21);
    - the perimeter wall, turnstiles, concourse (#7) and the stairs or tunnels up into each stand (#15);
    - the interiors, including the clubhouse/office (#24), the concourse under the stands as it grows, and the stand over the clubhouse (#5);
    - the paths, including the car park path (#11), the athletic centre (#23) and the fan walking routes in and out (#10, #14);
    - the car park with the coach bay (#25), the club shop, the planting areas (#22) and the Supporters' Bar across the street (#16).

## Crowd and fans

6. **Crowd fans look wrong:**
   - a. **Fans sit in the aisles.** Fans get placed on the stairways between seat blocks. Those spots should always be left empty.
   - b. **Neighbouring fans overlap.** When fans sit shoulder to shoulder, their shoulders blend into each other. Each fan needs enough room that they don't clip.
   - c. **Crowd models don't match our NPC style.** Swap the blocky crowd figures for the API-based models (HumanoidDescription avatars) so they match the other NPCs. Fewer fans in the stands is fine if that's the cost.
9. **Walking fans outside the ground look wrong:**
   - a. **Blocks on their shoulders.** The fans queueing on the paths and around the concourse have square blocks stuck on top of their shoulders. That's true even for the ones that should be API avatars. The guess is an old scarf or shoulder part left over from the previous crowd build, or accessories that don't fit the rig.
   - b. **No walking animation.** These fans slide along the paths without moving their legs. They need a walk cycle, and idle animations when they stop.
   - The stand fans and the walking fans may be built by two separate systems. Make sure they both use the same avatar pipeline so they look the same.
10. **Leaving fans vanish before they're off the plot.** After the match, fans walking out disappear partway along the plot paths. They should reach the street or plot edge first, like the car park exit or the road by the bus stop, and only disappear once they're off the grounds or out of view.
14. **Fans never go through the turnstiles.** Arriving fans skip the corner turnstiles. They should queue at a turnstile, pass through it into the concourse (#7), and then head to their stand. Leaving fans should go back out the same way, which ties into #10.

## Plot and grounds

8. **Team coach and TV van need reworking.** The team bus and the white van (the TV/broadcast van, with the satellite dish on top) are plain primitive boxes. Both need proper models.
11. **Add a path from the clubhouse path to the car park.** Add a short footpath across the lawn. It starts at the main path coming out of the clubhouse front door and runs to the car park. It'll need a gap in the hedge row where it meets the car park, and the planting keep-out areas need updating so trees and bushes don't grow on it.
16. **Move the Supporters' Bar across the street and give it a proper model.** The bar works well as an idea, but it's a primitive-block building sitting on the club plot. It should become a real asset and move to the other side of the street, so it reads as the local pub near the ground rather than part of the club's grounds.
    - **Assets:** paid assets are off for now, so this would come from the free kit, an AI-generated mesh, or a baked model like the terraced houses.
    - **Across the street is town land, not the plot:** that means it's shared by everyone on the server. It could fit the existing plan that pubs get busy on matchday (only on that player's screen) and that the neighbourhood changes as each club grows.
22. **More planting around the club grounds.** There are trees, hedges and groves already, but some patches of lawn around the plot are still bare grass. Fill them with more planting: shrubs, flower beds, extra trees or small groves. The new planting has to leave the paths clear, including the new car park path from #11, and stay out of wherever the fan route and concourse from #7/#15 end up.
23. **The athletic centre isn't finished:**
    - a. **No paths lead to it.** The athletic centre has no footpaths. Add paths that run all the way from the club's main path network to its door.
    - b. **The building is empty.** It has nothing inside. It needs an interior, even just a visual one for now, such as gym equipment, a changing area and a reception desk. It could also link to training mechanics later.
    - Assumed to mean the training ground building on the club plot, not the community sports centre in town.
25. **The team coach isn't parked in the car park.** It sits on the paving next to the stand. Move it into the car park, maybe into a marked coach bay. This goes with #8, where the coach gets its new model.

## Office

24. **The office needs a layout and scale pass:**
    - a. **Laptop screen in the wrong place.** The laptop's screen sits in the middle of the keyboard instead of at the back edge.
    - b. **Desk too small and in the wrong spot.** Make the desk bigger and move it to the far side of the room, away from the doors.
    - c. **Door hits the trophy shelf.** When the office door swings open, it hits the shelf with the trophies on it.
    - d. **Bin in the middle of the floor.** The rubbish bin sits in the middle of the room. Put it next to the desk or in a corner.
    - e. **Two chairs.** Remove the primitive-block chair. The other chair faces away from the desk, so it needs turning round.
    - f. **Everything is too small.** The cardboard boxes, footballs, boot, tyre and fire extinguisher all look undersized. The code says these kit props are "at real scale", so either the room itself is oversized or the props were scaled against the wrong reference. Check that before scaling anything up.
    - g. **Fixtures sheet is blurry.** The fixtures notice on the wall is ours. The fixture list fills it in (`src/server/Clubhouse.luau:792`, `src/server/SeasonService.luau:94`). It's blurry because it renders at a low resolution. While there:
      - Opponent names are cut off at 9 letters, so you get "Greyfriar" and "Harrowgat".
      - Longer lines wrap, so "Kingsmere" and "3pm" end up on separate lines.

## Scout packs

18. **Pack cards need visual work:**
    - a. **Swap the flags for a clean icon pack.** Replace the hand-made nation flags with a clean, consistent set of flag icons used as assets.
    - b. **Player name sits too high.** On the card, the name isn't centred in its band. It sits too high and pokes above the divider line.
    - c. **Accented letters don't capitalise.** Names with accents come out mixed-case: "Y. LEFèVRE" instead of "Y. LEFÈVRE".
    - d. **Hair hidden behind the head.** Some players' hair renders behind their head instead of on top of it. The goalkeeper in the screenshot has hair, but you can only see it poking out from behind.
    - e. **Shoulders look like a flat block.** The portrait is a grey block with a Roblox head sitting on it, which looks odd. It needs proper shoulders, or a torso wearing the kit.
    - f. **Better card animation.** Make the flip or spin-reveal feel more 3D, and add a hover animation such as a tilt, lift or shine. Right now the cards feel flat and stiff.
    - g. **Show which players you already have.** When picking a card, let the player compare it with their current squad, for example by showing who they'd replace or how the card ranks at that position. That way it's an informed pick, not a random one.
    - h. **Sound effects for pack opening (later).** Add sounds for the pack opening: tearing it open, each card flipping, a bigger sting for a gold or rare card, and a sound when you pick one. These would come from Roblox's licensed audio library first.
19. **Signed cards disappear, and the pack screen needs to match Marcel's mockup:**
    - a. **Signed cards vanish.** When you sign a player, their card disappears and the other cards slide over to fill the gap.
    - b. **What it should do:** the signed card stays in its slot, turns grey, and gets a clear "SIGNED" stamp or banner. It should also play a small animation, such as a stamp thump, a little shrink or a slide. Its Sign and Pin buttons turn off.
    - c. **Match the mockup layout:**
      - Header: "SCOUT REPORT" with a "3 PLAYERS DISCOVERED" line under it.
      - Under each card: a big green "SIGN £X" button, with a small square pin icon button beside it. The mockup uses a star; ours will be a pin.
      - A caption under the buttons. The mockup says "ADD TO SHORTLIST", which would change to something like "PIN UNTIL SEASON END".
      - A pinned card gets a gold glow around it.
      - A "CONTINUE >" button replaces "DONE".
    - d. **Players wear the kit on their cards.** The mockup shows shirts, including a green goalkeeper shirt, where we currently have grey blocks. That's the same fix as #18e.

## Economy

17. **Away matches pay almost nothing (economy rework).**
    - **How it works now:** 5 of the 10 league matches are away. An away match earns only the result bonus (win £400, draw £150, loss £0) and the shirt sponsor fee: no tickets, food or shop money. Wages are still worked out from what the match would have earned at home (`src/shared/Economy.luau:151`), so in the first season an away win pays about nothing and a loss costs money.
    - **Suggestion:** away matches pay less than home matches, but always pay something:
      - **Gate share:** the away club gets a share of the gate, based on the home club's ground size for the division, not the player's own stadium.
      - **Travelling fans:** away-end ticket money, scaled by the club's popularity and form.
      - **Broadcast money:** a small TV payment every match, home or away. It gives the TV van (#8) a purpose.
      - **Fixed wages:** one flat wage bill per match instead of the home-match figure.
      - **Target:** an away match earns about 40–50% of what a home match does.
    - **Open questions for Marcel:**
      1. How much should an away match earn compared with a home match? Suggested 40–50%; the alternatives are about 25% or about 70%.
      2. Should travelling fans depend on popularity? Suggested yes.
      3. A TV/broadcast payment every match, bigger in higher divisions? Suggested yes.
      4. Keep showing away matches at the player's own ground for now? Suggested yes; travelling to another ground is a much bigger job.
      5. Show a breakdown for away games on the match summary ("Gate share £X · Away fans £Y · TV £Z")? Suggested yes.

## Town and rendering

27. **You can't see the town very far.** When you look out from the ground, only the nearby area shows; the rest of Rivermere is missing.
    - **Place check:** `StreamingEnabled` is on. Every town model uses the default streaming mode, except 195 set to always stay loaded, like the for-sale lots. Workspace `LevelOfDetail` is Automatic. Atmosphere density is 0.30 and haze is 1.3, and fog is off, so the haze isn't what's hiding the town. Studio wouldn't let a script read `StreamingTargetRadius`; Roblox's default is 1024 studs, so check it in Workspace's properties.
    - **Graphics slider is at maximum**, so Roblox's automatic quality reduction is ruled out. The cause is streaming.
    - **Why it's happening:** streaming unloads models past the target radius, and our town models have no far-away version, so nothing is drawn in their place. Distant ground also turns into a rough low-detail version.
    - **Fixes Roblox recommends, in suggested order:**
      1. **Streaming meshes (Roblox's built-in LOD).** Set each large town model's detail setting (`Model.LevelOfDetail`) to StreamingMesh. When the model unloads, Roblox shows a cheap low-detail copy that it builds itself. The setting only works on whole models, so the building blocks need grouping sensibly: a whole terrace row or a street block, not single parts. These copies may only show on the published game, not in Studio playtests, so test there.
      2. **Keep landmarks always loaded.** Set the church spire, viaduct, station and a few big skyline pieces to always stay loaded. It's cheap if kept to a handful.
      3. **A bigger target radius**, only if 1 and 2 aren't enough. It costs memory and slows down phones, so maybe tie it to the quality setting.
      4. **Painted-on distance.** A low-detail skyline ring or backdrop behind the real town (`src/server/Backdrop.luau` already does something similar), with haze blending the edge where the real town stops.

28. **Plant the grounds' trees across the town.** Use the same trees as the club grounds (the OakPack6 oaks and bushes) around the houses and terrace rows: front and back gardens, the ends of rows and open grass patches. Add them along the streets as street trees wherever there's a grass verge. They have to keep clear of roads, pavements, driveways and bus stops. Watch the part and phone budget too: streaming (#27) and the dresser part budgets both matter here.
29. **A tree in the middle of the roundabout.** Plant a single oak, or a small planted bed with a tree, on the roundabout's centre island.

30. **Commercial district apartment blocks show panel lines.** From a distance, you can see the seams between the wall panels on the flat blocks.
    - **Suggestion:** fix this the way the terraced houses were fixed (merged unit meshes with tileable brick; see the house rework notes) rather than buying new models.
    - While there:
      - Some blocks have blank side walls, the grey ends with no windows.
      - One block in the screenshot looks like it's leaning. Check it isn't rotated.
31. **Houses need doors and front paths.** Every house and block should have a door and a footpath from that door to the pavement. Right now the doors open straight onto grass. It's a big job across the whole town, but worth trying. It could be generated from the layout data: door position to nearest pavement.
32. **Buildings only have windows facing the street.** Many buildings have windows on the street side only, and their backs and sides are blank. The riverside houses in particular should have windows facing the water, and those should be normal windows, not a whole wall of glass.
33. **Group town buildings into models for streaming LOD.** Same as #27 fix 1: group buildings into whole-row or whole-block models so StreamingMesh can give them low-detail stand-ins when they're far away. Check whether it's already done first.
34. **Replace the church/chapel spire with a real model.** If it's built from primitive blocks, swap it for a proper model. It's a key landmark, so it should also stay always loaded (#27 fix 2).
35. **Town centre pedestrians are floating.** People in the town centre hover above the ground. Possibly the same issue as the plots floating over low-detail distant ground (see the streaming notes). Some pedestrians also still use the classic yellow "noob" rig and look like they're lying flat. They should match the NPC avatar style (#6c, #9).
36. **Find a free asset for the train.** Replace the current train with a proper free model.
37. **Station car park problems.** The station car park isn't joined to the road. Its parked cars are the wrong size.
38. **Street-parked cars are the wrong size too.** The same problem as #37 on the streets around it.
39. **The industrial estate needs reworking:**
    - a. **Far too much grass.** It should be mostly tarmac and concrete yards.
    - b. **Props in a straight line.** A load of props are laid out in one row in front of the buildings, which looks placed rather than lived-in. Scatter them into yards, loading bays and stacks.
    - c. **Forklift is the wrong size.**

**Assets:** use free assets for all of #30–#39 where possible.

40. **You can press Play Match away from your club.** The Play Match button works when the player is out in town or at another club. Pressing it should bring the player back to their own ground, using the same move as the "go to my club" button, before the iris transition and walkout start.
41. **Street lamps give no light at night.** The town street lamps are just models: nothing lights up after dark. They need real lights: a PointLight or SpotLight on each lamp head, with a glowing lens. Keep phones in mind: hundreds of lamps with real lights is expensive. So light only the nearest lamps, or those on higher quality settings, and give the rest just the glowing lens. This goes with #2, the floodlights not lighting the pitch.

45. **Goal nets need back supports.** The nets form a square box, but there's nothing behind them to hold them up. A box net needs a back frame: two rear uprights at the back corners, joined by rear stanchions (support bars) to the crossbar and down to the ground. Either change the goal model or add the missing frame pieces. Keep the posts on the goal line (commit 9b01ff8).

## New features (need a design talk)

42. **A scooter or other quick way to get around.** Something faster than walking and sprinting for crossing Rivermere: a kick scooter, e-scooter or bike. It sits between walking and the bus stops. It ties into the later idea of buying a car to show off wealth (CLAUDE.md s27). Questions:
    - Free for everyone, earned, or bought?
    - Can the player ride it inside the ground?
    - It needs to work with streaming (#27), because riding fast outruns what's loaded.
43. **A way to monetize the game.** Monetization is still an open question (CLAUDE.md s25), and M5 persistence is done, so now is the right time to plan it. The soft launch already runs an ad test.
    - **Options to discuss:**
      - Buying packs, with odds already published in `Config.PackOdds` (s8).
      - Cosmetic game passes: stadium styles, seat colours, kits, office decor, scooter skins (#42).
      - A VIP pass: bigger save slots, a faster fast-forward, or a bigger scout pin slot.
      - Small cash boosts.
      - Private servers.
      - Rewarded ads.
    - **Rule to agree first:** nothing that makes promotion pay-to-win. Keep it cosmetic, convenience or luck (packs).

44. **A "+" button next to the cash to buy money with Robux.** Put a plus sign beside the cash display on the HUD. Pressing it opens a small shop of cash packs. Each pack is a Roblox Developer Product (bought with `MarketplaceService`, and granted in `ProcessReceipt` so it's saved safely).
    - **Marcel's call:** for now the amounts are deliberately absurd, as a reward for early players. Label them TEMP in `Config` so they're easy to rebalance later.
    - **Before it's built:**
      - Developer Products only work on the published place, so they need testing there.
      - A big cash buy skips the early upgrade loop, which is the core fun. It also goes against the "no pay-to-win" rule suggested in #43, so decide on purpose whether early players get this as a one-off.
      - Grant the cash in `ProcessReceipt` and save it straight away, so a crash can't eat a purchase.

---

*More items to come.*
