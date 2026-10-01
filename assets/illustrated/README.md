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

## Settlement props and companion animals

`settlement-props.webp` provides 16 transparent sprites: tent, rescue rubble, searchable
and cleared rubble, three bunker entrances and a depleted hatch, then pot, flag, bench,
lamp, wind chime, string lights, mural and memorial statue. `settlement.js` stores measured
frames and physical map sizes. Decoration purchase rows use matching previews.
Wood, sandbag and metal perimeter walls retain connected canvas geometry with new colors,
material seams, grain, rivets and rust marks.

`companions.webp` provides all 11 pets in existing PKEYS order (dog, cat, crow, goat,
hedgehog, silver fox, turtle, owl, fennec, robot dog, bear cub). Map and UI share one
renderer; dynamic collar colors, facing, movement bounce, hidden silhouettes and the
silver fox's night glow are preserved. Pet tapping uses illustrated body height. Native
art remains the loading fallback, and the thumbnail cache separates loaded/fallback art.

Generation used the built-in image tool. Exact prompts: [settlement-props-prompt.md](settlement-props-prompt.md)
and [companions-prompt.md](companions-prompt.md). WebP quality 90, original alpha preserved.
No adoption rules, placement costs, exploration rewards, pet effects or save migrations changed.

## Final presentation pass: items 4–7

- `regional-npcs.webp`: Dusik, Maseok and Eunsol portraits; existing roles and dialogue preserved.
- `module-upgrades.webp`: 18 upgrade exteriors for nine facilities. Stage one uses the previous atlas;
  stages two and three use measured frames in `chapter-design.js`. Map picking and UI previews follow stage.
- `ash-foes.webp`: normal/brute idle and impact poses, facing the shelter. Existing damage rules remain.
- `world-scenes.webp`: nine locations shared by expedition cards, underground zones and chapter openings.

These four atlases were generated using the built-in image tool; exact prompts are in the corresponding
`*-prompt.md` files. WebP quality 90; alpha retained for facilities and enemies.
The customizable player portrait retains all saved indices, with native SVG ink contours and quieter colors.
The editor exposes selection state and larger controls. Underground controls use one readable Korean font,
consistent square tiles and compact layouts; scenes remain separate from actionable UI.

Verification: isolated Chromium at 390×844 and 320×640; all 82 profile options rendered, profile saved,
18 native facility upgrades charged the expected costs and retained picking, expedition team departed,
floors 1/5/10/15 consumed oil on exploration, and defense tapping reduced enemy HP. Chapter art appears
only on the opening line. No page errors in these paths. Production-shell offline reload loaded 29 cached
entries including all four new atlases. Corrected the existing navigation cache write to pass a Response.
No save schema or balance changes.

## Playability follow-up

The October 1 polish pass adds visual-viewport sizing, 44px camera/close targets, input sizing,
and contained panel scrolling. Faded buildings no longer intercept taps intended for the tile
behind them. Starting a second pointer cancels held actions; blur/visibility changes release
all gesture state. Settings includes a replayable control guide. Dialogue has a progress track,
short reduced-motion-aware transitions, and preserves focus on Next rather than Skip.
Critical font/shelter/portrait preloads begin earlier; service-worker writes retain their lifetime,
failed navigation responses do not replace the offline copy, and cleanup only removes game caches.

Verification: Chromium touch emulation at 390×844, 320×640 and 390×420, no horizontal guide
overflow, reachable guide action, occlusion picking, interrupted gesture cleanup, dialogue focus
and reduced motion. The prior profile/upgrade/expedition/underground/defense regression paths passed.
Offline production shell retained 29 entries. Physical iPhone Safari is not available in this
environment and remains an explicit verification limitation.
Fresh production play also retained progress across reload with no page errors.

## Cohesive interface and expressive dialogue

Facilities now use one bordered card with a larger illustration and separate effect, cost and action.
The panel palette uses a gray-green base, ivory cards and slate actions; amber is reserved for the
lantern, major upgrades and dialogue progression. Survivor rows prioritize portrait, name, role and
status; grade, trust and equipment remain in the existing detail screen. Player portraits retain
all saved customization indices with redrawn eyes, jaw planes, hair strokes and clothing folds,
a tighter portrait composition, and a subtle static ink edge filter. Selected frames and pets
fit the revised composition.

`world-panorama.webp` contains nine purpose-composed horizontal locations. Frame boundaries are
measured at x=0/724/1448/2172 and y=0/258/494/724; panels use a two-pixel inset to avoid seams.
`founder-expressions.webp` contains calm, worried and resolved portraits for Park Mansu (0),
Choi Seojin (2), Seo Yuna (7) and Oh Jaehyeok (9), in that column order. The three expression rows
are selected by an explicit authored-line table; unmatched lines remain calm. Other characters
keep their existing portraits. Loading failures retain the previous artwork.

Both atlases used the built-in image-generation tool with existing art as reference, encoded
as WebP quality 90. Exact prompts are in `world-panorama-prompt.md` and
`founder-expressions-prompt.md`. Player portrait updates are native SVG code, preserving customization.

Verification: 12 distinct expression views, preserved survivor detail information, hair/clothing
selection and saving, 82 customization options, 18 facility upgrades, expedition departure,
defense hit, four underground floors, save roundtrip and malformed import rejection. Mobile
Chromium views at 320/390px were inspected. Offline and HTTP 503 reload used 31 shell cache entries.
Physical iPhone Safari remains unverified. No balance, unlock or save schema changes.

## Story scenes

`story-1.webp`, `story-2.webp`, `story-3.webp`: 27 first-person story panels (3 × 3 each, 3:2) for the
main scenario, tutorial and ending. `story-art.js` maps them to the dialogue and shows one at the top of the
talk card once the atlas has loaded. The protagonist's face is never drawn. See
[story-scenes-prompt.md](story-scenes-prompt.md) for the panel list and exact prompts.
