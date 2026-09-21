# Crest Builder Image Prompts

Art for the found-club crest builder. There are 12 images: 4 shield shapes and 8 emblems.

## How the layers work

Roblox can't clip one image with another, so the game builds a crest from stacked,
tinted white images:

1. **Shape fill** tinted with the club's main colour
2. **Pattern** (halves / stripes / sash) tinted with the second colour
3. **Rim**, a thin outline of the shape, tinted white or the second colour
4. **Emblem** in the centre, tinted white or the second colour

Only the **shape fills** and the **emblems** need generating. The rims and the pattern
layers are cut from each shape by a script, so they line up with it to the pixel.
Generated layers would never line up exactly.

Everything has to be **pure flat white on magenta**. The game tints white to any
colour, and any grey or shading shows up as muddy colour after tinting. Show detail
with **gaps cut into the white** (negative space), not with lines or shading.

## Settings

- Square, **1024×1024**
- If your tool can output a transparent PNG, replace the magenta sentence with
  `transparent background, PNG with alpha`. Otherwise the magenta is keyed out afterwards.
- Generate **shape 1** and **emblem 1** first. Attach them as the reference for the
  rest of their set so the line weight and proportions stay consistent.

## Save to

- `assets/ui/crest/shape_<name>.png`: `shape_classic.png`, `shape_round.png`,
  `shape_square.png`, `shape_pointed.png`
- `assets/ui/crest/emblem_<name>.png`: `emblem_ball.png`, `emblem_lion.png`, `emblem_castle.png`,
  `emblem_waves.png`, `emblem_star.png`, `emblem_oak.png`, `emblem_bridge.png`,
  `emblem_crown.png`

---

# Shapes

The shape is a solid silhouette with no rim, no inner line and no detail. The script
adds the rim.

## Shape 1: Classic shield (generate first)

```
A single football club crest blank shape, game UI mask asset. Classic heater shield silhouette: flat straight top edge with slightly rounded top corners, straight vertical sides for the upper half, then curving smoothly inward to a centred point at the bottom. Perfectly symmetrical left to right, perfectly front-on flat orthographic view, no perspective.

The shield is ONE solid flat pure white (#FFFFFF) shape, completely uniform fill: no outline, no border, no rim, no inner line, no bevel, no shading, no gradient, no texture, no highlight, no shadow. The shield fills about 85% of the frame height and is centred.

No text, no letters, no numbers, no logo, no emblem, no pattern, no watermark. Isolated on a plain solid pure magenta (#FF00FF) background, no glow, no drop shadow. Crisp clean vector edges, flat 2D.
```

## Shape 2: Round (attach shape 1 as reference)

```
Same style, size and pure flat white fill as the reference image, but the silhouette is a perfect circle, centred, filling about 85% of the frame. One solid flat pure white (#FFFFFF) shape: no outline, no border, no rim, no inner line, no shading, no gradient, no texture, no shadow.

No text, no letters, no logo, no emblem, no pattern, no watermark. Isolated on a plain solid pure magenta (#FF00FF) background. Crisp clean vector edges, flat 2D, perfectly front-on.
```

## Shape 3: Rounded square (attach shape 1 as reference)

```
Same style, size and pure flat white fill as the reference image, but the silhouette is a square with generously rounded corners (corner radius about 18% of the width), centred, filling about 85% of the frame. One solid flat pure white (#FFFFFF) shape: no outline, no border, no rim, no inner line, no shading, no gradient, no texture, no shadow.

No text, no letters, no logo, no emblem, no pattern, no watermark. Isolated on a plain solid pure magenta (#FF00FF) background. Crisp clean vector edges, flat 2D, perfectly front-on, perfectly symmetrical.
```

## Shape 4: Pointed shield (attach shape 1 as reference)

```
Same style, size and pure flat white fill as the reference image, but the silhouette is a traditional pointed football badge shield: the top edge has two small squared shoulders at the outer corners and a shallow upward peak in the middle, straight vertical sides for the top third, then tapering in straight lines to a sharp centred point at the bottom. Perfectly symmetrical, centred, about 85% of the frame height. One solid flat pure white (#FFFFFF) shape: no outline, no border, no rim, no inner line, no shading, no gradient, no texture, no shadow.

No text, no letters, no logo, no emblem, no pattern, no watermark. Isolated on a plain solid pure magenta (#FF00FF) background. Crisp clean vector edges, flat 2D, perfectly front-on.
```

---

# Emblems

Emblems sit in the middle of the crest and are often shown only 40–60 px across on
a phone. Keep them **bold and chunky**: few, thick shapes, with gaps no thinner than
about 4% of the image width. If it doesn't read as a small black-and-white icon, it's
too detailed.

## Emblem 1: Football (generate first)

```
A single bold emblem icon for a football club crest, game UI asset. A classic football (soccer ball): a circle with the traditional pentagon-and-hexagon panel pattern, shown as one solid flat pure white (#FFFFFF) silhouette with the panel seams cut out as thick clean gaps (negative space) so the background shows through. Chunky and simple, readable at 40 pixels wide.

Flat single-colour icon: pure white only, no outline in another colour, no shading, no gradient, no grey, no texture, no highlight, no shadow, no 3D. Centred, perfectly front-on, filling about 75% of the frame, symmetrical where the subject allows.

No text, no letters, no numbers, no shield, no border, no frame, no circle behind it, no watermark. Isolated on a plain solid pure magenta (#FF00FF) background. Crisp clean vector edges, flat 2D heraldic icon style.
```

## Emblems 2–8 (attach emblem 1 as reference)

Use the template below with each **subject** line pasted into `<SUBJECT>`.

```
Same style, line weight, size and pure flat white single-colour look as the reference image. A single bold emblem icon for a football club crest: <SUBJECT>. One solid flat pure white (#FFFFFF) silhouette, with interior detail shown only as thick clean gaps (negative space) where the background shows through. Chunky and simple, readable at 40 pixels wide.

No shading, no gradient, no grey, no second colour, no outline, no texture, no shadow, no 3D. Centred, perfectly front-on, filling about 75% of the frame.

No text, no letters, no numbers, no shield, no border, no frame, no background shape, no watermark. Isolated on a plain solid pure magenta (#FF00FF) background. Crisp clean vector edges, flat 2D heraldic icon style.
```

| # | File | Subject |
|---|---|---|
| 2 | `emblem_lion.png` | a heraldic lion rampant in side profile, standing on its hind legs facing left, front paws raised, mane and tail tuft as bold simple shapes, eye and claws as small cut-out gaps |
| 3 | `emblem_castle.png` | a small castle tower gatehouse seen straight on: a wide wall with three square crenellations on top, two short side turrets, and an arched gate cut out in the centre |
| 4 | `emblem_waves.png` | three stacked horizontal rolling river waves, each a thick curling band with a small curl at the crest, evenly spaced, forming a roughly square block |
| 5 | `emblem_star.png` | a single bold five-pointed star, slightly rounded points, with a smaller five-pointed star cut out of its centre as a thick gap |
| 6 | `emblem_oak.png` | an oak tree with a broad rounded crown made of three or four lobed clusters, a short thick trunk and a simple ground line, with two or three acorn-shaped gaps cut into the crown |
| 7 | `emblem_bridge.png` | a stone river bridge seen side on: a flat deck over three round arches, the arches cut out as gaps, with two short wavy water lines below |
| 8 | `emblem_crown.png` | a royal crown seen straight on: a solid band at the bottom with three small square gems cut out, five points on top each ending in a small ball, the gaps between the points open |

---

## After generating

Drop the files into `assets/ui/crest/` and tell me. The build step keys out the magenta,
checks that every shape is centred and the same size, cuts the rim and pattern layers,
and flags any emblem with grey pixels or gaps too thin to survive at phone size.
