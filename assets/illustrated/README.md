# 재 속의 등불 — illustrated presentation

Approved direction: expressive Korean indie comic characters, irregular ink contours,
muted gouache colors, slate blue ash, warm ivory paper, restrained amber light.
Controls and text remain HTML/CSS so they can adapt to the real game state and small screens.

## Assets

All images were created with the built-in image generation tool from the approved
character and screen concepts, then encoded as WebP quality 88. Portrait backgrounds
are intentionally opaque; shelter, module and radio assets retain alpha transparency.

| Atlas | Grid | Cells in reading order (survivor ID) |
| --- | --- | --- |
| survivors-founders.webp | 4 × 1 | 박만수 (0), 최서진 (2), 서유나 (7), 오재혁 (9) |
| survivors-neighbors.webp | 2 × 2 | 강도윤 (1), 윤하늘 (3), 한순례 (4), 김말순 (5) |
| survivors-signals.webp | 2 × 2 | 장철호 (6), 정우진 (8), 차은호 (10), 백설화 (11) |
| survivors-frontier.webp | 2 × 2 | 문태식 (12), 탁미영 (13), 한별 (14), 도진 (15) |
| survivors-scouts.webp | 2 × 1 | 설아 (16), 진 (17) |
| shelters.webp | 3 × 2 | Shelter levels 1–5, lantern |
| modules.webp | 3 × 3 | Module IDs 1, 2, 9, 3, 4, 8, 5, 6, 7 |
| radio.webp | Single | Radio |

Production brief: distinct age and facial structure, hand inked comic expression,
flat restrained gouache, no glossy photorealistic faces; isometric shelter and facility
sprites with clear silhouettes, warm light and transparent backgrounds; isolated radio.

`design.js` owns atlas mapping and rendering. Canvas buildings and thumbnails fall back
to native drawings while images load. Locked survivor portraits retain the original
silhouettes. `design.css` loads after the existing styles and provides the new presentation.
No save migration or balance changes are required. `sw.js` caches all production assets.

## Palette

- Ink: #171d24
- Slate controls: #242d36
- Reading paper: #eee5d3
- Amber action: #dfa54b
- Warning: #ab5145

For future assets, preserve the equal cell boundaries and ordering above. Small avatars
must remain identifiable at 32–54 px. Gameplay copy and buttons must never be baked into
an image. Keep fixture/debug state setters outside the production repository.

## Exploration sites

`exploration-sites.webp` adds five vehicle, five ruined-house, and five shop variants,
plus one depleted state for each category. See [exploration-prompt.md](exploration-prompt.md)
for the exact built-in generation prompt, source dimensions and mapping. The renderer uses
measured frames to avoid clipping at the generated atlas gutters.

## Landmarks and regional landscapes

`landmarks.webp` contains five columns (school, water tower, gas station, library,
subway entrance) and two rows (ruined, restored). Measured frames in `design.js`
account for unequal generated gutters. The restored atlas is selected from existing
`S.lm[i].ok`; hit heights follow the displayed sprite, with native art as loading fallback.
See [landmarks-prompt.md](landmarks-prompt.md) for the exact generation prompt.

Regional ground, water, background, fog and vegetation use the native canvas renderer:
muted sand and dry shrubs for desert, cool concrete and sparse growth for factory,
pale ground and snowy pines for snow. Fog caching includes the region and zoom.
No saved-state schema or resource balance changes are required.

Verification: five roof touch targets, restoration costs/effects, occlusion,
320 px and 390 px layouts, same-zoom regional fog changes, and offline reload with
all 20 shell entries. Temporary test fixtures are kept outside the production repository.

## Map inhabitants

`people.js` renders articulated canvas figures using the 18 approved portrait palettes,
hair silhouettes and accessories. Native vector shapes preserve legibility at map scale.
Walking follows facing direction; children have smaller proportions and quicker steps.
Workers use repair tools, a hoe, water bucket or notes according to assigned facility.
Reduced motion freezes all figure animation. Generated children retain their saved colors;
no survivor, movement, productivity or save schema changes are made by the renderer.
