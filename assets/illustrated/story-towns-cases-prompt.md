# Story scenes — towns and casebook (story-4, story-5)

Two more opaque atlases in the same format as story-1..3: **3 columns × 3 rows of equal 3:2 panels**
(for example 1536 × 1024), clean hard boundaries, no borders, no gutters. Encode to WebP quality 88:

- `assets/illustrated/story-4.webp` (panels 27–35): the three new towns (row 1 desert, row 2 factory, row 3 snow)
- `assets/illustrated/story-5.webp` (panels 36–44): the nine casebook incidents

Rules are the same as `story-scenes-prompt.md`: first-person point of view, the protagonist's face, head and full
body are never shown; no writing, numbers or UI; survivors and town NPCs match their approved portraits.
Casebook panels show the evidence and the place, never who did it.

## Prompt for ChatGPT (send with story-1.webp and regional-npcs.webp attached as style/character references)

Please make TWO separate images, one after the other. Both must match the attached reference's style exactly.

Shared rules for both images: Nine story panels for a Korean indie comic post-apocalyptic survival game, EXACT 3 columns x 3 rows, all panels equal width and height in 3:2 landscape, clean hard boundaries without borders or gutters. Match the reference's hand ink crosshatching and muted gouache, warm ivory surfaces, slate blue ash, tiny amber lights, quiet human drama rather than photorealism. First-person point of view: the protagonist's face, head and full body are never shown; at most his hands, sleeve or the old brass lantern he carries. Characters match the attached portraits: Dusik (older desert fuel-tower keeper, short pale gray hair, sun-worn face, faded ochre work jacket, cloth scarf), Maseok (sturdy middle-aged industrial foreman, short black hair, slate blue work jacket), Eunsol (schoolteacher, dark brown chin-length hair, muted blue winter coat, wool scarf). No writing, numbers, captions, speech bubbles or UI; any paper or label shows only illegible scribbles.

IMAGE 1 (story-4, three new towns):
Row1 desert: (27) first-person arrival in a dusty desert town at dusk, rusty fuel towers in a row, hands holding a small warm ember box, Dusik running out toward the lantern light, one fuel tower's top light glowing by itself; (28) first-person, a heavy rusted iron hatch pulled open in the sand beneath a fuel tower, cool air and dark still water of a hidden underground cistern below, Dusik peering in beside the lantern; (29) night, a finished light tower in the middle of the desert town glowing warm amber under a sky full of stars, Dusik with two small grandchildren looking up, sand-colored shacks around.
Row2 factory: (30) a rusty industrial district with chimneys standing like a forest under the thickest ash, Maseok in his work jacket shielding his eyes from the lantern light, ash creatures' ember eyes far in the gloom; (31) inside an abandoned factory, a long production line still running by itself with gears and press machines spewing ash, the bespectacled researcher in a stained lab coat staring at it in guilt, the lantern held in the foreground; (32) a light tower frame rising between factory chimneys at night and its light switching on, Maseok and workers in gloves looking up, sparks and warm light reflected on steel.
Row3 snow: (33) a mountain village where snow has fallen on grey ash, everything a pale grey-white, Eunsol in her blue winter coat waving at the lantern light from a small school building, tiny footprints in the snow; (34) a warm small schoolroom with one iron stove, a dozen bundled children huddled together, Eunsol among them, a cheerful young girl with a yellow umbrella waving hello to them, small shoes lined up by the stove; (35) the snowy village glowing gold under a lit light tower, the ash clouds parted and stars visible, Eunsol and the children pointing at the stars.

IMAGE 2 (story-5, casebook incidents; show the evidence and the place, never the culprit):
Row1: (36) dusk behind a plank shelter, a storeroom door left ajar, a cheerful young girl with a yellow umbrella crouching to feed a canned meal to a thin stray dog; (37) 3 a.m. close-up of an old portable radio on a table, the tuning dial turned, a faint oily smudge on the knob larger than a child's hand, a dim lantern and an analog clock a little past three; (38) a coiled rope tied over an open underground hatch, the rope half severed, its strands melted, a small round soot ring scorched around the cut.
Row2: (39) night on a radio-room roof, a tall antenna with its cable cut and dangling, smooth grey ash on the roof with no footprints at all; (40) 3 a.m., a researcher's notebook open under a desk lamp with a jagged stub where one page was torn out, the bespectacled researcher's hands trembling over it; (41) early dawn, a folded paper note pinned to the base pillar of a tall light tower, ash drifting, a hand reaching for it.
Row3: (42) a desert fuel tower's old radio set opened, an empty vacuum tube socket in the dusty chassis, Dusik looking at it in dismay, sand blowing; (43) a factory loudspeaker on a tall pole, its cable melted through with a small round soot ring, Maseok looking up with a frown, chimney smoke behind; (44) a snowy schoolroom, an empty open desk drawer, Eunsol and a few children gathered around it in puzzlement, the stove glowing, a cassette recorder on the teacher's desk.

## After adding the files

Added 2026-10-12: `story-art.js` maps town arcs (3 beats each), next-town radio calls and town choices to 27–35, and casebook pages to 36–44 (`TTCStory.caseArt`, `into`). The gallery order and backfill include them.
