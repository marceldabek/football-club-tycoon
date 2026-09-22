# Player Card Background Prompts

Generate **1. Gold** first and pick the shape you like. For 2–6, attach that gold card as the reference image so every tier keeps the same silhouette.

Export at 683×1024 (2:3). If your tool supports transparent PNG output, replace the magenta background sentence with `transparent background, PNG with alpha`; otherwise key out the magenta afterwards.

Save results to `assets/ui/cards/` as `card_gold.png`, `card_bronze.png`, etc.

---

## 1. Gold (generate first, text-only)

```
A single blank football trading card background, game UI asset, perfectly front-on flat orthographic view, no perspective, no tilt. Tall shield-shaped card silhouette: flat top with small notched shoulders at the upper corners, straight vertical sides, tapering to a soft centered point at the bottom. Aspect ratio 2:3, card fills 90% of the frame, centered, perfectly symmetrical.

Material: rich polished gold foil over black, deep amber to bright yellow-gold gradients, sharp glossy shard reflections, luxurious.

Thin bevelled metallic rim around the whole edge with a subtle inner stroke. The upper 60% of the card is a calmer, slightly darker open area (a portrait will be placed here); the lower 40% is a smoother, more uniform panel (stat text will be placed here), separated by a faint thin horizontal divider line. Diagonal shard / faceted light streak pattern running across the surface, subtle, not busy.

Completely empty: no text, no numbers, no letters, no logos, no flags, no character, no face, no icons, no watermark. Isolated on a plain solid pure magenta (#FF00FF) background, no shadow, no glow spilling outside the card edge, no floor, no scene. Clean crisp edges, high detail, stylised premium mobile game UI, 2D render.
```

---

## 2. Bronze (attach gold card as reference)

```
Keep the exact same silhouette, size, rim thickness and layout as the reference image. Change only the material and colours to: brushed dark bronze and copper metal, warm brown tones, matte with faint scratches, low shine, modest and plain. Keep the subtle diagonal shard pattern, the calmer upper portrait area, the smoother lower stat panel and the faint divider line.

Completely empty: no text, no numbers, no letters, no logos, no flags, no character, no face, no icons, no watermark. Perfectly front-on flat view, isolated on a plain solid pure magenta (#FF00FF) background, no shadow, no glow outside the card edge. Clean crisp edges, stylised premium mobile game UI, 2D render.
```

---

## 3. Silver (attach gold card as reference)

```
Keep the exact same silhouette, size, rim thickness and layout as the reference image. Change only the material and colours to: brushed steel and polished silver, cool grey-white tones, faint frosted glass facets, soft white highlights. Keep the subtle diagonal shard pattern, the calmer upper portrait area, the smoother lower stat panel and the faint divider line.

Completely empty: no text, no numbers, no letters, no logos, no flags, no character, no face, no icons, no watermark. Perfectly front-on flat view, isolated on a plain solid pure magenta (#FF00FF) background, no shadow, no glow outside the card edge. Clean crisp edges, stylised premium mobile game UI, 2D render.
```

---

## 4. Rare — Blue (attach gold card as reference)

```
Keep the exact same silhouette, size, rim thickness and layout as the reference image. Change only the material and colours to: deep royal blue crystal and sapphire facets, electric blue light streaks, thin silver-white rim, glowing cyan edge highlights. Keep the subtle diagonal shard pattern, the calmer upper portrait area, the smoother lower stat panel and the faint divider line.

Completely empty: no text, no numbers, no letters, no logos, no flags, no character, no face, no icons, no watermark. Perfectly front-on flat view, isolated on a plain solid pure magenta (#FF00FF) background, no shadow, no glow outside the card edge. Clean crisp edges, stylised premium mobile game UI, 2D render.
```

---

## 5. Epic — Purple (attach gold card as reference)

```
Keep the exact same silhouette, size, rim thickness and layout as the reference image. Change only the material and colours to: dark violet and magenta-purple crystalline facets, iridescent sheen, thin gold rim, faint energy streaks. Keep the subtle diagonal shard pattern, the calmer upper portrait area, the smoother lower stat panel and the faint divider line.

Completely empty: no text, no numbers, no letters, no logos, no flags, no character, no face, no icons, no watermark. Perfectly front-on flat view, isolated on a plain solid pure green (#00FF00) background, no shadow, no glow outside the card edge. Clean crisp edges, stylised premium mobile game UI, 2D render.
```

(Green background here, not magenta, so the purple card keys out cleanly.)

---

## 6. Legend — Pearl & Gold (attach gold card as reference)

```
Keep the exact same silhouette, size, rim thickness and layout as the reference image. Change only the material and colours to: pearl white and champagne gold marble with fine gold veins, ornate thin gold filigree rim, soft radiant inner glow, prestigious. Keep the subtle diagonal shard pattern, the calmer upper portrait area, the smoother lower stat panel and the faint divider line.

Completely empty: no text, no numbers, no letters, no logos, no flags, no character, no face, no icons, no watermark. Perfectly front-on flat view, isolated on a plain solid pure magenta (#FF00FF) background, no shadow, no glow outside the card edge. Clean crisp edges, stylised premium mobile game UI, 2D render.
```

---

## 7. Card back (attach gold card as reference)

One back for every tier, so the spin gives nothing away until the player flips it. It must be left-right symmetrical: the 2D spin squashes the card to a line and swaps the face, and a lopsided back would visibly jump.

```
Keep the exact same silhouette, size and rim thickness as the reference image. This is the BACK of the football trading card, so remove the portrait area, the stat panel and the divider line, and replace them with one single centred design covering the whole card.

Material: deep midnight navy enamel with a fine, dark tone-on-tone pattern of small football pitch markings (centre circles, halfway lines, penalty arcs) repeating across the surface, very subtle. Thin bevelled brushed-gunmetal rim with a fine pale gold inner stroke, neutral, neither gold, silver nor bronze.

Centre: a large circular emblem at the exact middle of the card, a stylised classic football made of embossed pale gold line work inside a thin double ring, with short radiating light rays behind it fading into the navy. Above and below the emblem, a small matching ornamental flourish, mirrored top to bottom. Soft glossy sheen sweeping diagonally across the card, faint, as if foil-stamped.

Perfectly mirror-symmetrical left to right. Completely empty of writing: no text, no numbers, no letters, no logos, no flags, no character, no face, no watermark. Perfectly front-on flat view, isolated on a plain solid pure magenta (#FF00FF) background, no shadow, no glow outside the card edge. Clean crisp edges, stylised premium mobile game UI, 2D render.
```

Save as `card_back.png`. Check that the outline lines up with `card_gold.png` when overlaid, or the flip will pop.

---

## Checklist

- [ ] 1. Gold
- [ ] 2. Bronze
- [ ] 3. Silver
- [ ] 4. Rare (blue)
- [ ] 5. Epic (purple)
- [ ] 6. Legend (pearl & gold)
- [ ] 7. Card back
