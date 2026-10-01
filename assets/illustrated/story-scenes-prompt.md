# Story scenes (main scenario illustrations)

Three opaque atlases, each **3 columns × 3 rows of equal 3:2 panels** (for example 1536 × 1024, panels 512 × 341),
clean hard boundaries, no borders, no gutters. Encode to WebP quality 88 and save as:

- `assets/illustrated/story-1.webp` (panels 0–8)
- `assets/illustrated/story-2.webp` (panels 9–17)
- `assets/illustrated/story-3.webp` (panels 18–26)

`story-art.js` already maps every chapter intro and outro, the tutorial "그날 밤" and the ending to these panels.
The game shows a panel at the top of the dialogue card as soon as the file exists; nothing else needs changing.
If the cell size differs, keep the 3 × 3 grid: the code measures each atlas and divides it by three.

## Rules for every panel

- Same world and style as the approved art: Korean indie comic, hand ink crosshatching, muted gouache,
  warm ivory paper, slate blue ash, restrained amber lantern light.
- **The protagonist "나" is never shown with a face.** Panels are first-person point of view:
  at most his hands, sleeve, the lantern he holds, or his shadow. Never his face, head or full figure.
- Other survivors may appear and must match their approved portraits (see README atlas table).
- No writing, numbers, captions, speech bubbles or UI in the image. Handwriting may appear only as illegible scribbles.
- Each panel reads as one clear story moment even when cropped to a shallow card.

## Exact prompt — story-1.webp

Use case: illustration-story. Nine story panels for a Korean indie comic post-apocalyptic survival game, EXACT 3 columns x 3 rows, all panels equal width and height in 3:2 landscape, clean hard boundaries without borders or gutters. Match the reference's hand ink crosshatching and muted gouache, warm ivory surfaces, slate blue ash, tiny amber lights, quiet human drama rather than photorealism. First-person point of view: the protagonist's face, head and full body are never shown; at most his hands, sleeve or the old brass lantern he carries. No writing, numbers, captions or UI.
Row1: (0) 3 a.m. blackout street between dark apartment blocks, first-person view of a hand holding an old brass lantern low, its warm glow the only light, distant power plant smokestacks on the horizon; (1) a collapsed house after a tremor, splintered timber and roof tiles lit by the lantern held in the foreground; (2) inside a small patched tent at night, an old portable radio on a crate beside the lantern, the radio dial glowing, an analog wall clock showing a little past three.
Row2: (3) seen from the tent entrance, the sky over the distant power plant flashes blinding white and grey ash begins to fall, a hand with the lantern in the foreground; (4) a grey world buried in ash forty-three days later, one lonely tent and a lantern on a crate, an orange glow seeping at the edge of the ash clouds; (5) first-person, the lantern raised toward a wall of ash cloud, the ash melting and parting only where its light touches, ruined houses appearing beneath.
Row3: (6) night, a flashlight blinking from inside ash clouds over rubble, an elderly mechanic in a worn work cap sitting against a broken wall holding the flashlight, relieved; (7) evening sky turning an alarming rust red over a small plank shack and a wooden fence, ash swirling in from the horizon; (8) grey dawn inside the plank shack, the portable radio crackling on a table, faint light through gaps in the boards, a cold mug and the lantern beside it.

## Exact prompt — story-2.webp

Use case: illustration-story. Nine story panels for a Korean indie comic post-apocalyptic survival game, EXACT 3 columns x 3 rows, all panels equal width and height in 3:2 landscape, clean hard boundaries without borders or gutters. Same style as story-1 and the approved character portraits. First-person point of view: the protagonist's face, head and full body are never shown; at most his hands, sleeve or the old brass lantern. No writing, numbers, captions or UI.
Row1: (9) the lantern blazing in a fever of light in the protagonist's hands, the whole ruined neighborhood lit bright as day for one instant; (10) first-person view across a small dinner table in a plank shelter: the elderly mechanic, a cheerful young girl with a yellow umbrella and an emergency-room nurse sharing a simple meal and laughing; (11) stacked rusty shipping containers reinforced with steel plates forming a sturdy shelter, warm windows, survivors carrying supplies at dusk.
Row2: (12) a dusty storage corner, a hand pulling a battered old radio out from under boxes, the dial faintly lit; (13) a gentle man in his thirties with headphones around his neck and a portable transmitter on his back arriving at the shelter gate at night, smiling, the lantern light on him; (14) an old school building and a water tower in the ruins with their lights coming back on, ash clouds thinning above.
Row3: (15) first-person, looking down an open manhole under a container, a rusty ladder disappearing into darkness, cold air, the lantern held over the hole; (16) underground, a soaked work log open on a metal shelf with technical diagrams of a light tower (no readable text), lantern light, dripping pipes; (17) the farthest point toward the power plant, a regular light blinking through dense ash cloud, an exhausted researcher in his thirties with glasses and a stained lab coat signaling from a locked maintenance building.

## Exact prompt — story-3.webp

Use case: illustration-story. Nine story panels for a Korean indie comic post-apocalyptic survival game, EXACT 3 columns x 3 rows, all panels equal width and height in 3:2 landscape, clean hard boundaries without borders or gutters. Same style as story-1 and the approved character portraits. First-person point of view: the protagonist's face, head and full body are never shown; at most his hands, sleeve or the old brass lantern. No writing, numbers, captions or UI.
Row1: (18) night confession at the shelter table seen in first person, the bespectacled researcher with his head lowered, the other survivors silent and tense around the lantern; (19) from a watchtower of a fortified shelter, the far horizon with the power plant smokestacks, a hand resting on the rail; (20) a great ash storm night, ash creatures with glowing ember eyes crawling toward sandbag walls, a lantern tower burning them back, survivors bracing.
Row2: (21) a quiet night close-up, an open handwritten casebook beside the lantern, the last page filled with an urgent scribble that cannot be read, the protagonist's hand resting near it, unsettling stillness; (22) a radio room with a tall antenna outside the window, the man with headphones speaking into a microphone, small warm lamps, listeners' silhouettes outside; (23) the shelter's light piercing the ash clouds up to the horizon, and far away toward the power plant a single small light blinking back in answer.
Row3: (24) a woman engineer in a soot-covered control room uniform arriving at dawn, facing the bespectacled researcher, both surprised and wary; (25) close-up of hands passing the old brass lantern to the woman engineer, who tilts it to read a serial plate on its base (plate shown without legible characters), a large tower lens behind; (26) the finished light tower igniting, a pillar of warm light punching through the ash clouds into a starry sky, small survivor figures gathered below.

## After adding the files

Add the three files to the `SHELL` list in `sw.js` and bump `CACHE`. Do not list them before the files exist:
a missing file makes the offline cache install fail.
