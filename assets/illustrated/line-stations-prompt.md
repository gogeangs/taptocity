# 노선 역 입구 (line-stations, 2026-10-14)


> 2026-10-14 연결 완료: design.js `LS` — 역(k=4)은 동네 열(첫 동네·사막·공단·설원) × 폐허/복구 칸으로 그림. 그림이 있으면 코드 선로는 그리지 않고 입구 빛만 더함.
The station landmark (`station`, Broken Line entrance) now uses the same atlas look as the other landmarks, so it blends in on the map.
This atlas gives every town its own subway/rail entrance with a silhouette no other building has:
a stairway going DOWN into the ground, a tall round sign post with a hanging ring lamp (no letters), and rail tracks running out of a tunnel mouth.

- `line-stations.webp`: 4 columns x 2 rows of equal 384px cells → 1536 x 768, transparent.
  Columns: first town (city subway), desert (모래언덕역), factory (제철소 화물역), snow (산골역).
  Top row: blocked / ruined. Bottom row: reopened, with warm amber light glowing up from below.
- Same isometric angle and map scale as `landmarks.webp`, but a larger footprint than the other landmarks (it is the minigame entrance).

## Prompt for ChatGPT (with GitHub access to gogeangs/taptocity)

```
GitHub 저장소 gogeangs/taptocity (브랜치 main)에 게임 그림 1장을 만들어 커밋해 줘.

[참고 그림 — 저장소에서 직접 열어서 그림체·각도·크기감을 맞춰]
- assets/illustrated/landmarks.webp, landmarks-desert.webp, landmarks-factory.webp, landmarks-snow.webp (동네별 랜드마크, 투명 배경, 아이소메트릭)
- assets/illustrated/lantern-tower.webp (호박색 불빛 표현)

[그림] 파일: assets/illustrated/line-stations.webp
- 투명 배경(알파 유지) WebP, 품질 90, 크기 1536 x 768 (384px 정사각형 4칸 x 2줄, 칸 테두리 없음)
- 프롬프트: Use case: stylized-concept. Isometric landmark sprite atlas for a Korean post-apocalyptic indie comic survival game. Match the attached landmark references exactly in hand-inked comic contour, muted gouache, crosshatching, worn handmade materials, 30-degree isometric view and map scale, grey ash dust settled on everything, no glossy render look. Transparent background (PNG alpha). A strict grid of 4 columns x 2 rows = 8 equal square cells, one isolated subway or rail station ENTRANCE per cell, compact diamond footprint, centered, no ground rectangle, no people, no text. These must be instantly distinguishable from ordinary buildings at small mobile scale, so every entrance shares three signature features: (a) a wide stairway descending DOWN into the ground under a low canopy, the dark opening clearly going below ground level; (b) a tall slim post beside it topped by a round sign disc and a hanging ring-shaped lamp (the disc is blank, no letters, no numbers, no symbols); (c) two short rail tracks emerging from a small arched tunnel mouth next to the stairs and ending abruptly, broken off. Columns left to right: (1) first town: a city subway entrance, cracked granite steps, bent steel handrails, glass-and-steel canopy, slate and ash colors; (2) desert: a half-buried ring-line station entrance, sun-bleached concrete arch, faded turquoise paint, sand mixed with grey ash drifting down the steps, rusty rails; (3) industrial estate: a freight rail station entrance, soot-stained brick and riveted steel truss canopy, hazard stripes faded to grey-orange, a short buffer stop at the end of the rails; (4) snowy mountain village: a narrow-gauge station entrance, dark timber canopy heavy with snow, icicles, small stove pipe, snow over grey ash on the steps. TOP ROW: blocked and dead — the stair opening barred with collapsed planks, rubble or a sagging rusty shutter, the ring lamp broken and dark, tracks buried. BOTTOM ROW: the EXACT SAME entrances from the same angle, reopened by survivors — debris cleared, the shutter rolled up, a strong warm amber glow rising out of the stairway from below, the ring lamp lit amber, rails swept clean and gleaming faintly, still worn, not pristine. Restrained palette: slate, ash grey, rust, muted local colors, the amber light is the only bright accent. No names, captions, lettering, logos or watermarks.

[커밋 규칙]
- 위 파일 1개만 추가. 다른 파일(index.html, sw.js, *.js, *.css, 기존 그림)은 절대 수정하지 마.
- 최신 main을 받고 충돌 없이 main에 바로 커밋·푸시.
- 커밋 메시지: "노선 역 입구 그림 추가 (line-stations)"
- 끝나면 실제 픽셀 크기, 투명 여부, 파일 용량, 커밋 해시를 알려 줘.
```

## After adding the file

Crop each cell by its connected alpha area, then in `design.js` draw the station with `line-stations.webp` (column = town, row = `lmOn('station')`) instead of the landmark atlas column 5, a little larger than other landmarks. Keep the old landmark art as the fallback while it loads.

## 공단 역 다시 그리기 (line-stations-factory, 2026-10-14)

The factory column of `line-stations.webp` has no freight car, but the story says "화물칸이 엉킨 역" and the line trace mentions 출근 카드 in a 화물칸.
This separate 2-cell atlas replaces only that column. Same look, angle and scale as `line-stations.webp`.

- `line-stations-factory.webp`: 2 columns x 1 row of 384px cells → 768 x 384, transparent. Left: blocked, right: reopened.

```
GitHub 저장소 gogeangs/taptocity (브랜치 main)에 게임 그림 1장을 만들어 커밋해 줘.

[참고 그림 — 저장소에서 직접 열어서 그림체·각도·크기감을 똑같이 맞춰]
- assets/illustrated/line-stations.webp (특히 세 번째 열: 공단 화물역 입구, 위=폐허, 아래=복구)
- assets/illustrated/landmarks-factory.webp (다섯 번째 열의 화물칸 모양)

[그림] 파일: assets/illustrated/line-stations-factory.webp
- 투명 배경(알파 유지) WebP, 품질 90, 크기 768 x 384 (384px 정사각형 2칸, 가로 한 줄, 칸 테두리 없음)
- 프롬프트: Use case: stylized-concept. Two-cell isometric landmark sprite atlas for a Korean post-apocalyptic indie comic survival game. Match the attached station-entrance reference (its third column) EXACTLY in hand-inked comic contour, muted gouache, crosshatching, 30-degree isometric view, map scale and footprint, grey ash dust settled on everything, no glossy render look. Transparent background (PNG alpha). A strict grid of 2 columns x 1 row = 2 equal square cells, one isolated freight rail station ENTRANCE per cell, compact diamond footprint, centered, no ground rectangle, no people, no text. Keep the same signature features as the reference: a wide stairway descending DOWN into the ground under a soot-stained brick and riveted steel truss canopy with hazard stripes faded to grey-orange; a tall slim post with a blank round sign disc and a hanging ring-shaped lamp (no letters, numbers or symbols); two short rail tracks coming out of a small arched tunnel mouth beside the stairs. NEW: one short rusty freight boxcar sits on those tracks right beside the entrance, derailed and tilted, its coupling tangled with a second broken car end and bent rails — clearly a freight station where cars got tangled. LEFT cell: blocked and dead — stair opening barred with collapsed planks and a sagging rusty shutter, ring lamp broken and dark, the boxcar half-buried in ash, rails twisted. RIGHT cell: the EXACT SAME entrance and boxcar from the same angle, reopened by survivors — debris cleared, shutter rolled up, a strong warm amber glow rising out of the stairway from below, ring lamp lit amber, the boxcar pushed upright onto the rails with its sliding door half open, still worn, not pristine. Restrained palette: slate, ash grey, rust, faded grey-orange; the amber light is the only bright accent. No names, captions, lettering, logos or watermarks.

[커밋 규칙]
- 위 파일 1개만 추가. 다른 파일(index.html, sw.js, *.js, *.css, 기존 그림)은 절대 수정하지 마.
- 최신 main을 받고 충돌 없이 main에 바로 커밋·푸시.
- 커밋 메시지: "공단 화물역 입구 그림 다시 (line-stations-factory)"
- 끝나면 실제 픽셀 크기, 투명 여부, 파일 용량, 커밋 해시를 알려 줘.
```

After adding: in `design.js` LS, use this file's two cells for the factory column (ruin / restored) and keep the `line-stations.webp` factory cells as the fallback while it loads.
