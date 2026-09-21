# Club Crest Generation Prompts

Image-generation prompts for all 40 fictional clubs in `Config.TeamNamePools`
(`src/shared/Config.luau`). Eight clubs per division, five divisions.

Every club here is fictional but rooted in a recognisable UK region — Pennine mill
towns, Fenland villages, South Wales mining valleys, City of London gates — so the
pyramid reads as British without borrowing a real club's name or badge.

**Crest style escalates with the division.** A Sunday Parks League badge should look
handmade and cheap; a Premier Division badge should look like a 2017-era rebrand. That
visual gap is the point: when the player is promoted, the opposition badges get better.

---

## How to use this

1. Paste the **Master Style Prompt** below as its own message first, to set the style.
2. Then paste club prompts **one at a time**. Each is self-contained enough to work alone.
3. Image generators rate-limit hard — expect to wait a minute or so between images, and
   longer after a run of them. Generating a full division (8 crests) in one sitting is
   a realistic target.

**DALL-E 3 settings:** `style: natural`, `size: 1024x1024`

**Save each file as** `tier<N>_<club-name-in-kebab-case>.png`, e.g.
`tier1_bramblewick-rovers.png`, `tier5_old-aldgate.png`. That naming maps directly onto
the club entries in `Config.TeamNamePools`, so wiring them up later is mechanical.

---

## Master Style Prompt

```text
You are generating a set of football club crests that must look like they belong to the
same universe. For every crest, follow these rules exactly:

Modern football club crest, clean vector illustration, flat design with no gradients,
symmetric composition, simple geometric forms, pure white background, no shadow, no 3D
effects, no photorealism, no text or lettering anywhere in the image, legible at small
sizes, SVG-ready aesthetic.

The crest must fill the frame with a small even margin. Exactly two colours plus white.
Never add a third colour. Never add a drop shadow, bevel, glow or outline effect.
Never include letters, numbers, words, banners with text, or scrolls with text.

The level of polish varies by division and will be specified in each prompt. Obey the
polish instruction as strictly as the style rules above.
```

---

# Division 1 — Sunday Parks League

Village greens, park pitches, pub teams and rec grounds. These clubs have no money and
no designer. Badges should look screen-printed onto a cheap polo shirt by whoever in the
squad owned a computer.

**Tier style modifier (already included in each prompt below):** deliberately unpolished,
thick clumsy line weights, a plain circle or basic shield, one dominant colour plus one
accent, slightly naive drawing, charming rather than professional.

### 1. Bramblewick Rovers — North Yorkshire fishing village

```text
Deliberately amateurish grassroots football club crest, plain circular badge, thick
clumsy line weights, flat vector with no gradients, pure white background, no text or
lettering. Bramble maroon and cream as the only two colours. A simple bramble sprig with
three blackberries and two leaves, drawn naively with chunky outlines. Looks homemade,
like a village pub team badge screen-printed on a cheap shirt.
```

### 2. Oakhollow United — Midlands woodland village

```text
Deliberately amateurish grassroots football club crest, plain circular badge, thick
clumsy line weights, flat vector with no gradients, pure white background, no text or
lettering. Forest green and mustard yellow as the only two colours. A single chunky oak
leaf with one acorn beside it, drawn simply with heavy outlines and no fine detail.
Looks homemade, like a village pub team badge.
```

### 3. Fenmoor Athletic — Cambridgeshire fens

```text
Deliberately amateurish grassroots football club crest, plain circular badge, thick
clumsy line weights, flat vector with no gradients, pure white background, no text or
lettering. Peat brown and pale sky blue as the only two colours. A simple fenland
windpump silhouette with three straight reeds beside it, drawn naively with chunky
outlines. Looks homemade, like a village pub team badge.
```

### 4. Kestrel Green FC — suburban recreation ground

```text
Deliberately amateurish grassroots football club crest, plain circular badge, thick
clumsy line weights, flat vector with no gradients, pure white background, no text or
lettering. Grass green and white as the only two colours. A kestrel hovering with wings
spread, reduced to a blocky simple silhouette with heavy outlines and no feather detail.
Looks homemade, like a park league team badge.
```

### 5. Ashby Wanderers — Leicestershire market town

```text
Deliberately amateurish grassroots football club crest, basic shield shape with a flat
top, thick clumsy line weights, flat vector with no gradients, pure white background, no
text or lettering. Navy blue and white as the only two colours. A simple ash tree with a
thick trunk and a rounded lumpy canopy, drawn naively. Looks homemade, like a village pub
team badge.
```

### 6. Millpond Town — old mill village

```text
Deliberately amateurish grassroots football club crest, plain circular badge, thick
clumsy line weights, flat vector with no gradients, pure white background, no text or
lettering. Slate grey and duck egg blue as the only two colours. A watermill wheel seen
from the side with four chunky paddles and three simple wavy water lines beneath it.
Looks homemade, like a village pub team badge.
```

### 7. Sunday Legends — pub team with no heritage whatsoever

```text
Deliberately amateurish grassroots football club crest, wonky circular badge, very thick
clumsy line weights, flat vector with no gradients, pure white background, no text or
lettering. Red and black as the only two colours. A pint glass and a football boot
crossed like heraldic weapons, drawn crudely and comically with heavy outlines. Should
look like a joke badge designed by a pub team in ten minutes, charmingly bad.
```

### 8. Hedgerow FC — rural lane club

```text
Deliberately amateurish grassroots football club crest, plain circular badge, thick
clumsy line weights, flat vector with no gradients, pure white background, no text or
lettering. Hedge green and hawthorn red as the only two colours. A dense hedgerow section
drawn as a simple rounded green mass with three small red berries, naive and chunky.
Looks homemade, like a village pub team badge.
```

---

# Division 2 — County League

Market towns and county FA sides. Somebody's cousin who does graphic design made these.
Competent, plain, unambitious.

**Tier style modifier:** simple traditional shield, two flat colours, clean but basic
shapes, no ornamentation, slightly dated club badge look.

### 9. Thornbury Town — Gloucestershire market town

```text
Simple traditional football club crest, classic shield shape with a rounded base, flat
vector with no gradients, pure white background, no text or lettering. Claret and sky
blue as the only two colours. A square market town tower with crenellations, with a
single thorn branch crossing beneath it. Clean but basic shapes, plain and unornamented,
like a modest county league club badge.
```

### 10. Redcliffe Rangers — Bristol red sandstone cliffs

```text
Simple traditional football club crest, classic shield shape with a rounded base, flat
vector with no gradients, pure white background, no text or lettering. Red sandstone red
and pale sand as the only two colours. A blocky cliff face rendered as three stacked
angular chevrons suggesting rock strata. Clean but basic shapes, plain and unornamented,
like a modest county league club badge.
```

### 11. Saltmarsh United — estuary coast

```text
Simple traditional football club crest, classic shield shape with a rounded base, flat
vector with no gradients, pure white background, no text or lettering. Estuary grey green
and white as the only two colours. A long-legged wader bird standing in profile above two
simple horizontal marsh lines. Clean but basic shapes, plain and unornamented, like a
modest county league club badge.
```

### 12. Wexford Vale — river valley club

```text
Simple traditional football club crest, classic shield shape with a rounded base, flat
vector with no gradients, pure white background, no text or lettering. Bottle green and
gold as the only two colours. Two overlapping rounded hills with a river running down
between them as a single tapering band. Clean but basic shapes, plain and unornamented,
like a modest county league club badge.
```

### 13. Brindle Heath — Lancashire moorland mill town

```text
Simple traditional football club crest, classic shield shape with a rounded base, flat
vector with no gradients, pure white background, no text or lettering. Heather purple and
soot grey as the only two colours. A tall mill chimney standing behind a sprig of
heather. Clean but basic shapes, plain and unornamented, like a modest county league club
badge.
```

### 14. Copperfield Celtic — Welsh borders smelting town

```text
Simple traditional football club crest, classic shield shape with a rounded base, flat
vector with no gradients, pure white background, no text or lettering. Copper orange and
emerald green as the only two colours. A Celtic ring cross centred on the shield with a
simple copper ingot shape beneath it. Clean but basic shapes, plain and unornamented,
like a modest county league club badge.
```

### 15. Norbury Athletic — Midlands suburb

```text
Simple traditional football club crest, classic shield shape with a rounded base, flat
vector with no gradients, pure white background, no text or lettering. Royal blue and
white as the only two colours. A church bell tower with a pointed roof, flanked by two
simple vertical stripes. Clean but basic shapes, plain and unornamented, like a modest
county league club badge.
```

### 16. Larkspur Rovers — chalk downland

```text
Simple traditional football club crest, classic shield shape with a rounded base, flat
vector with no gradients, pure white background, no text or lettering. Larkspur blue and
cream as the only two colours. A skylark rising with wings angled upward, above a single
tall larkspur flower spike. Clean but basic shapes, plain and unornamented, like a modest
county league club badge.
```

---

# Division 3 — Regional Premier

Proper cities with industrial and civic heritage. Badges here look like municipal coats
of arms adapted for football — traditional, detailed, a bit old-fashioned.

**Tier style modifier:** traditional heraldic crest, roundel or ornate shield, civic
coat-of-arms influence, more detailed linework, confident and historic.

### 17. Harrowgate City — Yorkshire spa city

```text
Traditional heraldic football club crest with civic coat of arms influence, circular
roundel badge with a decorative inner ring, flat vector with no gradients, pure white
background, no text or lettering. Spa turquoise and gold as the only two colours. An
ornamental spa water pump with a curved spout at the centre, framed by the ring. Detailed
confident linework, historic and municipal in feel.
```

### 18. Blackwater Albion — Essex river estuary

```text
Traditional heraldic football club crest with civic coat of arms influence, ornate shield
with a scalloped top edge, flat vector with no gradients, pure white background, no text
or lettering. Black and white as the only two colours. A rearing white horse above three
horizontal wave bands representing the estuary. Detailed confident linework, historic and
municipal in feel.
```

### 19. Ironbridge FC — Shropshire industrial heritage

```text
Traditional heraldic football club crest with civic coat of arms influence, ornate shield
with a pointed base, flat vector with no gradients, pure white background, no text or
lettering. Iron black and furnace orange as the only two colours. A single cast iron
bridge arch with radiating spoke ribs spanning the width of the shield, a river line
beneath. Detailed confident linework, historic and industrial in feel.
```

### 20. Greyfriars United — monastic cathedral city

```text
Traditional heraldic football club crest with civic coat of arms influence, ornate shield
with a scalloped top edge, flat vector with no gradients, pure white background, no text
or lettering. Friar grey and burgundy as the only two colours. A hooded friar in profile
standing within a pointed gothic arch. Detailed confident linework, historic and
ecclesiastical in feel.
```

### 21. Stonemoor Town — Pennine millstone grit

```text
Traditional heraldic football club crest with civic coat of arms influence, circular
roundel badge with a decorative inner ring, flat vector with no gradients, pure white
background, no text or lettering. Millstone grey and moss green as the only two colours.
A circular millstone with a square central hole and radiating grooves, set against a low
moorland ridge. Detailed confident linework, historic and industrial in feel.
```

### 22. Kingsmere Rovers — royal hunting lake

```text
Traditional heraldic football club crest with civic coat of arms influence, ornate shield
with a pointed base, flat vector with no gradients, pure white background, no text or
lettering. Regal blue and silver as the only two colours. A crown floating above three
horizontal lake ripple lines, with reeds at either side. Detailed confident linework,
historic and regal in feel.
```

### 23. Eastwick Athletic — East London docklands

```text
Traditional heraldic football club crest with civic coat of arms influence, ornate shield
with a flat top, flat vector with no gradients, pure white background, no text or
lettering. Claret and amber as the only two colours. A dockside crane in profile with its
jib extended over the water, two crossed mooring ropes beneath. Detailed confident
linework, historic and industrial in feel.
```

### 24. Dunmore Wanderers — northern moorland hill fort

```text
Traditional heraldic football club crest with civic coat of arms influence, circular
roundel badge with a decorative inner ring, flat vector with no gradients, pure white
background, no text or lettering. Dark tartan green and white as the only two colours. A
stepped hill fort silhouette on a rounded hill, with a sprig of heather at the base.
Detailed confident linework, historic and rugged in feel.
```

---

# Division 4 — National League

Big professional clubs. Badges are clean, modern and properly designed — restrained,
balanced, made by an actual agency.

**Tier style modifier:** clean modern professional football badge, balanced geometry,
restrained detail, confident negative space, contemporary but not radical.

### 25. Northgate United — northern walled city

```text
Clean modern professional football club crest, balanced geometry with confident negative
space, flat vector with no gradients, pure white background, no text or lettering. Steel
blue and white as the only two colours. A city gate arch reduced to a bold symmetrical
archway with two flanking towers, simplified to essential shapes. Contemporary and
restrained, like a well-designed professional club badge.
```

### 26. Silverton City — lead and silver mining city

```text
Clean modern professional football club crest, balanced geometry with confident negative
space, flat vector with no gradients, pure white background, no text or lettering. Silver
grey and deep navy as the only two colours. A mine winding tower reduced to a clean
triangular headframe with a circular wheel at its apex. Contemporary and restrained, like
a well-designed professional club badge.
```

### 27. Marlow Park FC — Thames-side town

```text
Clean modern professional football club crest, balanced geometry with confident negative
space, flat vector with no gradients, pure white background, no text or lettering. Thames
green and white as the only two colours. A swan with its neck curved into a clean
geometric S, floating above a single horizontal river band. Contemporary and restrained,
like a well-designed professional club badge.
```

### 28. Whitcombe Town — Dorset chalk valley

```text
Clean modern professional football club crest, balanced geometry with confident negative
space, flat vector with no gradients, pure white background, no text or lettering. Chalk
white and ox blood red as the only two colours. A chalk hill figure horse in mid-gallop,
reduced to a flowing angular silhouette on a rounded hillside. Contemporary and
restrained, like a well-designed professional club badge.
```

### 29. Ravensmoor — northern moorland

```text
Clean modern professional football club crest, balanced geometry with confident negative
space, flat vector with no gradients, pure white background, no text or lettering. Raven
black and storm grey as the only two colours. A raven in flight reduced to a single bold
angular wing-and-beak silhouette, sharp and graphic. Contemporary and restrained, like a
well-designed professional club badge.
```

### 30. Castlebridge Albion — castle and river crossing

```text
Clean modern professional football club crest, balanced geometry with confident negative
space, flat vector with no gradients, pure white background, no text or lettering. Stone
gold and deep red as the only two colours. A castle keep sitting directly on a single
bridge arch, both reduced to clean rectangular and semicircular forms. Contemporary and
restrained, like a well-designed professional club badge.
```

### 31. Ferndale Athletic — South Wales mining valley

```text
Clean modern professional football club crest, balanced geometry with confident negative
space, flat vector with no gradients, pure white background, no text or lettering. Valley
green and coal black as the only two colours. A colliery winding wheel with clean radial
spokes, with a single fern frond curving around one side. Contemporary and restrained,
like a well-designed professional club badge.
```

### 32. Highfield Rovers — hilltop urban ground

```text
Clean modern professional football club crest, balanced geometry with confident negative
space, flat vector with no gradients, pure white background, no text or lettering. Royal
purple and white as the only two colours. A floodlight pylon standing on a rounded hill
crest, the lamp array reduced to a clean rectangular grid. Contemporary and restrained,
like a well-designed professional club badge.
```

---

# Division 5 — Premier Division

Elite clubs with global brands. These are the 2017-Juventus-tier rebrands: one bold idea,
executed ruthlessly, stripped of everything inessential.

**Tier style modifier:** radical minimalist rebrand, a single bold reductive mark, extreme
simplification, sophisticated and iconic, the kind of badge that works as an app icon.

### 33. Royal Kingsbury — royal London borough

```text
Radically minimalist football club crest, a single bold reductive mark, shield shape with
a pointed base, flat vector with no gradients, pure white background, no text or
lettering. Imperial purple and antique gold as the only two colours. A lion's head in
profile facing right, reduced to a handful of clean geometric planes, with a small
five-pointed crown motif above. Extreme simplification, sophisticated and iconic, the kind
of badge that works as an app icon.
```

### 34. Meridian City — Greenwich meridian

```text
Radically minimalist football club crest, a single bold reductive mark, circular badge,
flat vector with no gradients, pure white background, no text or lettering. Meridian navy
and laser green as the only two colours. A perfect vertical line bisecting a circle, with
two subtle latitude arcs crossing it, suggesting a globe and the prime meridian. Extreme
simplification, sophisticated and iconic, the kind of badge that works as an app icon.
```

### 35. Old Aldgate — City of London, one of the oldest clubs

```text
Radically minimalist football club crest, a single bold reductive mark, tall narrow shield
shape, flat vector with no gradients, pure white background, no text or lettering. Deep
claret and ivory as the only two colours. An ancient city gate reduced to a single bold
horseshoe arch form cut from the shield as negative space. Extreme simplification,
sophisticated and iconic, the kind of badge that works as an app icon.
```

### 36. Wentworth United — northern industrial dynasty

```text
Radically minimalist football club crest, a single bold reductive mark, tall narrow shield
shape, flat vector with no gradients, pure white background, no text or lettering. Jet
black and champagne gold as the only two colours. A stag's head facing forward with
antlers reduced to a symmetrical arrangement of straight angular lines. Extreme
simplification, sophisticated and iconic, the kind of badge that works as an app icon.
```

### 37. Crownhill FC — hilltop city

```text
Radically minimalist football club crest, a single bold reductive mark, rounded shield
shape, flat vector with no gradients, pure white background, no text or lettering. Crimson
and white as the only two colours. A crown reduced to exactly three triangles sitting on a
single horizontal band, resting on a shallow hill curve. Extreme simplification,
sophisticated and iconic, the kind of badge that works as an app icon.
```

### 38. Lancaster Park — red rose county

```text
Radically minimalist football club crest, a single bold reductive mark, circular badge,
flat vector with no gradients, pure white background, no text or lettering. Lancaster red
and slate grey as the only two colours. A heraldic rose reduced to five identical
geometric petals arranged with perfect radial symmetry around a small centre. Extreme
simplification, sophisticated and iconic, the kind of badge that works as an app icon.
```

### 39. Westbrook Athletic — west London riverside

```text
Radically minimalist football club crest, a single bold reductive mark, hexagonal badge
shape, flat vector with no gradients, pure white background, no text or lettering. Sky
blue and graphite as the only two colours. Three nested chevrons pointing upward,
suggesting both flowing water and forward motion. Extreme simplification, sophisticated
and iconic, the kind of badge that works as an app icon.
```

### 40. Sovereign Town — mint and coinage heritage

```text
Radically minimalist football club crest, a single bold reductive mark, circular badge
resembling a struck coin, flat vector with no gradients, pure white background, no text or
lettering. Sovereign gold and midnight blue as the only two colours. A monarch's head in
profile facing left, reduced to a single continuous geometric silhouette, set within a
plain raised rim. Extreme simplification, sophisticated and iconic, the kind of badge that
works as an app icon.
```

---

## Notes for later

- **The art is in (2026-09-21).** All 40 crests were checked against their prompts
  and each one matches its own club, so no club was renamed. `tools/prep_crests.py`
  matches the generated files to `Config.Clubs`, keys out the white background,
  pads to 256px and writes `assets/ui/crests/keyed/tier<N>_<kebab-name>.png` plus
  `contact_sheet.png`. The uploaded ids are in `assets/ui/crests/asset_ids.json` and
  on each club's `crest` field, and `Crest.applyArt` draws them in every UI crest.
  To replace one crest: regenerate it, run the script, upload that keyed PNG through
  Studio MCP, then update the id in both places. Crests in the 3D world are a planned follow-up.
- Club names live in `Config.Clubs` (previously `Config.TeamNamePools`).
- Two colours per crest is deliberate: it matches the procedural crest fallback in
  `MatchSummary.luau` and `ClubPanel.client.luau`, which fills a shield with a kit colour
  and draws initials over it. When the PNGs land, the same two colours can drive the kit
  so a club's shirt and badge agree.
- No lettering in any prompt. Club names are drawn by the UI in the game font, so baked-in
  text would clash and would look wrong at small sizes.
