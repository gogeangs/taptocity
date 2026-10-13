# Map walkers (2026-10-13)

People on the map (survivors at work, walking, visitors) are still drawn by code (`people.js`, small ink figures).
These two atlases replace them with hand-drawn standing figures. The code keeps the motion: a small bob and sway while walking,
mirrored when they face left, and a light work nod at their workplace.

- `walkers-1.webp`: 6 columns x 3 rows, 256px cells → 1536 x 768, transparent. Survivor ids 0–17 in order.
- `walkers-2.webp`: 6 columns x 3 rows, 256px cells → 1536 x 768, transparent. Ids 18–29 (town residents), then
  child boy, child girl (kids born or taken in), crow scout (까마귀), wandering trader woman (떠돌이 상인), 노친네 with his cart, refugee couple.
- Every figure: full body, feet on the same baseline near the bottom of its cell (about 92% down), centered, facing lower-right in the
  map's isometric 3/4 view. Adults about 80% of the cell height, teens 70%, children 58%.

## Prompt for ChatGPT (with GitHub access to gogeangs/taptocity)

```
GitHub 저장소 gogeangs/taptocity (브랜치 main)에 게임 그림 2장을 만들어 한 번에 커밋해 줘.

[참고 그림 — 저장소에서 직접 열어서 인물 얼굴·옷·색을 맞추고, 지도 소품의 그림체를 맞춰]
- 인물: assets/illustrated/survivors-founders.webp, survivors-neighbors.webp, survivors-signals.webp, survivors-scouts.webp, survivors-frontier.webp, residents.webp, crows-kids.webp, peddler.webp, guests.webp
- 그림체·크기감: assets/illustrated/terrain-props.webp, settlement-props.webp (지도 위 손그림 소품)

[공통 규칙 — 두 장 모두]
Use case: stylized-concept. Tiny full-body map character sprite atlas for a Korean post-apocalyptic indie comic survival game. Match the attached map-prop references in hand ink contour, muted gouache, light crosshatching, grey ash dust on clothes, no glossy render look, and match each character's face, hair and outfit colors to the attached portrait sheets. Transparent background (PNG alpha). A strict grid of 6 columns x 3 rows = 18 equal square cells, one isolated standing figure per cell, no cell borders, no ground tile, no text. Every figure: full body seen from the game's isometric 3/4 view, facing toward the lower right, relaxed standing pose with one foot slightly forward, feet resting on the same baseline about 92% down the cell, horizontally centered, with a tiny soft shadow under the feet. Scale: adults about 80% of the cell height, teens about 70%, children about 58%. Bold readable silhouettes that still read at 28 pixels tall: clear head, distinct outfit color and one signature prop each. No names, captions, lettering, logos or watermarks.

[그림 1] 파일: assets/illustrated/walkers-1.webp — 투명 WebP, 품질 90, 1536 x 768
Order left to right, top to bottom:
1 Park Mansu, 62, bus mechanic: navy work jacket, navy flat cap, grey stubble, wrench in hand.
2 Kang Doyun, 27, delivery rider: scuffed motorcycle helmet, dark windbreaker, square delivery bag on his back.
3 Choi Seojin, 34, ER nurse: teal scrubs under a jacket, face mask pulled down, hair in a bun, small first-aid pouch.
4 Yoon Haneul, 9, schoolgirl: red hooded raincoat, bob hair, holding a yellow umbrella.
5 Han Sunrye, 70, grandmother gardener: green cardigan, headscarf, grey bun, small hoe and seed pouch.
6 Kim Malsun, 55, soup restaurant owner: beige blouse, red apron, short permed curls, ladle.
7 Jang Cheolho, 48, construction foreman: stocky, dark work vest over a shirt, tape measure on belt.
8 Seo Yuna, 23, art student: slate-blue coat, beret, bob hair, sketchbook under her arm.
9 Jeong Woojin, 31, firefighter: rust-red turnout coat with reflective stripes, fire helmet, axe.
10 Oh Jaehyeok, 41, power-plant researcher: stained grey lab coat, glasses, messy hair, clipboard.
11 Cha Eunho, 36, late-night radio DJ: purple jacket, headphones around his neck, shoulder-length dark hair.
12 Baek Seolhwa, 29, former weather caster: teal long coat, long hair, shoulder bag, small weather vane brooch.
13 Moon Taesik, 77, watchmaker: thin and stooped, brown waistcoat, pocket watch chain, loupe on his forehead.
14 Tak Miyoung, 41, control-room operator: orange work uniform with a stripe, bob hair, keys at the belt.
15 Han Byeol, 32, desert herbalist: ochre headscarf and shawl, hair in a bun, herb bag.
16 Dojin, 38, welder: broad shoulders, slate jacket, welding goggles on the forehead, leather gloves.
17 Seola, 26, mountain rescuer: red rescue jacket, coiled rope over the shoulder, backpack, bob hair.
18 Jin, 15, former crow scout: slim teen, dark grey hoodie, black feather tucked in a scarf.

[그림 2] 파일: assets/illustrated/walkers-2.webp — 투명 WebP, 품질 90, 1536 x 768
Order left to right, top to bottom (1–12 match residents.webp in the same order):
1 Go Suhyeon, 34, harbor mechanic: rust-orange coverall, short hair, wrench.
2 Maria, 29, oasis cook: headscarf, white apron over a warm dress, cooking pot.
3 Bawi, 52, truck porter: very big and broad, sleeveless work shirt, sack on his shoulder.
4 Yoo Narae, 23, lighthouse assistant: navy pea coat, short hair, small lantern.
5 Kang Taeo, 41, press-factory foreman: hard hat, high-visibility vest.
6 Lee Bora, 27, factory canteen nutritionist: white kitchen cap and apron, clipboard.
7 Noh Minjae, 19, apprentice electrician: cap backwards, coil of wire, tool belt.
8 Han Jeongsuk, 58, factory clinic nurse aide: cardigan over a nurse top, short grey-streaked hair.
9 Park Seol, 31, mountain lodge keeper: knit hat, quilted parka, armful of firewood.
10 Choi Dohyeon, 45, snowplow driver: padded jacket, earflap hat, thick gloves.
11 Yoon Gaeul, 25, village hall assistant: long scarf, winter coat, notebook.
12 Seo Junho, 38, forest ranger: green parka, binoculars around the neck.
13 a small boy about 7, patched jacket, too-big boots.
14 a small girl about 7, braid, oversized sweater.
15 a crow raider scout: black long coat, black scarf over the face, crow feather on the hood.
16 the wandering cart trader woman from guests.webp: bandana, goggles on forehead, pack frame with pots.
17 Nochinne (노친네), the elderly peddler from peddler.webp: flat cloth cap, patched brown coat, pulling a small two-wheeled cart.
18 a refugee couple standing close under one grey blanket.

[커밋 규칙]
- 위 2개 파일만 추가. 다른 파일(index.html, sw.js, *.js, *.css, 기존 그림)은 절대 수정하지 마.
- 커밋 전에 최신 main을 받고, 충돌 없이 main에 바로 커밋·푸시.
- 커밋 메시지: "지도 위 인물 그림 추가 (walkers-1, walkers-2)"
- 끝나면 두 파일의 실제 픽셀 크기, 투명 여부, 파일 용량, 커밋 해시를 알려 줘.
```
