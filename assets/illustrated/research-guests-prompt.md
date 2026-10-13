# Research icons and guest portraits (2026-10-13)

The last two spots that still use line-drawn placeholders instead of hand-drawn art.

- `research-icons.webp`: 3 equal square cells in one row, transparent background (same look as `resources.webp`).
  Order: pickaxe (곡괭이), lantern ember (랜턴 불씨), scout drone (정찰 드론). Shelter → 연구 tab.
- `guests.webp`: 2 equal vertical portrait panels, opaque cream background (same look as `regional-npcs.webp`).
  Order: wandering cart trader (떠돌이 상인), lost family of three (길 잃은 가족). The '손님의 부탁' chip and request card.
  The trader must NOT look like 노친네 (`peddler.webp`, elderly man in a flat cap): this is a different, younger traveller.

## Prompt for ChatGPT (attach resources.webp and regional-npcs.webp as style references)

Please make TWO separate images, one after the other.

IMAGE 1 — Use case: stylized-concept. Icon atlas for a Korean post-apocalyptic indie comic survival game. Match the attached resource-icon reference exactly in hand ink contour, restrained muted gouache, crosshatching, slate and amber palette, no glossy render look. Transparent background (PNG alpha). A strict grid of 3 columns x 1 row = 3 equal square cells, one isolated object per cell, centered, same scale, slight 3/4 view, bold readable silhouette that still reads clearly at 32 pixels, no cell borders, no text. Left to right: 1 a worn steel pickaxe with a wrapped wooden handle, chipped edge, a little grey ash on the head. 2 a small old brass lantern with its lid open and a bright amber ember spark leaping out of the flame. 3 a small battered quadcopter scout drone patched with tape, one tiny amber light, propellers slightly blurred. No names, captions, lettering, logos or watermarks.

IMAGE 2 — Use case: stylized-concept. Character portrait sheet for a Korean post-apocalyptic indie comic survival game. Match the attached portrait reference exactly in hand ink contour, restrained muted gouache, expressive imperfect faces, crosshatching, warm ivory paper, slate colors, no glossy AI-face look. TWO equally wide vertical portrait panels side by side, shoulders to waist, thin ink borders, opaque cream backgrounds, no writing. LEFT: a wandering cart trader, a Korean woman in her forties with a weathered sun-browned face, short practical hair under a faded bandana, dust goggles pushed up on her forehead, layered travel coat with many pockets, a wooden pack frame strapped with pots, cans and coiled wire behind her shoulder, shrewd but friendly half-smile. RIGHT: a lost Korean family of three huddled together under one grey blanket — a tired father and mother in ash-dusted coats and a small child between them clutching a cloth bag, the parents' eyes hopeful toward the viewer, the child shy. Natural asymmetry, each face clearly different. No names, captions, lettering, logos or watermarks.

## After adding the files

Encode to WebP (icons: quality 90 with alpha; portraits: quality 90). Wire `research-icons.webp` into the 연구 tab rows (UPG keys tap, splash, drone)
and `guests.webp` into `renderEvBtn` / `openReq` for events with no survivor (`who: []`): 떠돌이 상인 → panel 0, 길 잃은 가족 → panel 1.
Keep the line icons as the fallback while the atlas loads (`swapLateArt` replaces them when it arrives).
