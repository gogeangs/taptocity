# Duty icons and wall thumbnails (2026-10-13)

> 2026-10-13 연결 완료: duty-icons → 생존자 쉴 때 일 버튼·장비 자동 맞추기(.dico), walls → 건설 탭 방벽(wallTh), terrain-props → 첫 동네 지도 나무·풀·덤불·벽돌 더미(tpDraw).

Found by the full-screen art audit: the last places that still show system emoji or line drawings.

- `duty-icons.webp`: 5 equal square cells in one row (128px each → 640 x 128), transparent background, same look as
  `research-icons.webp` / `resources.webp`. Order: gather (주워 오기 🎒), train (훈련 💪), patrol (순찰 🔦),
  childcare (아이 돌보기 🧸), auto-equip (장비 자동 맞추기 🎒). Used on the survivor card's duty buttons and the gear sheet.
- `walls.webp`: 3 equal square cells in one row (418px each → 1254 x 418), transparent background, same isometric look
  and scale as `modules.webp`. Order: wooden fence (나무 울타리), sandbag barricade (모래주머니 방벽), riveted steel-plate
  wall (철판 성벽). Used as the thumbnail in Shelter → 건설 → 방벽.

## Prompt for ChatGPT (with GitHub access to gogeangs/taptocity)

```
GitHub 저장소 gogeangs/taptocity (브랜치 main)에 게임 그림 2장을 만들어 커밋해 줘.

[참고 그림 — 저장소에서 직접 열어서 스타일을 맞춰]
- assets/illustrated/research-icons.webp, assets/illustrated/resources.webp (손그림 아이콘, 투명 배경)
- assets/illustrated/modules.webp (쉘터 모듈 아이소메트릭 그림, 투명 배경)

[그림 1] 파일: assets/illustrated/duty-icons.webp
- 투명 배경(알파 유지) WebP, 품질 90, 크기 640 x 128 (128px 정사각형 5칸, 가로 한 줄, 칸 테두리 없음)
- 프롬프트: Use case: stylized-concept. Icon atlas for a Korean post-apocalyptic indie comic survival game. Match the attached icon references exactly in hand ink contour, restrained muted gouache, crosshatching, slate and amber palette, no glossy render look. Transparent background (PNG alpha). A strict grid of 5 columns x 1 row = 5 equal square cells, one isolated object per cell, centered, same scale, slight 3/4 view, bold readable silhouette that still reads clearly at 24 pixels, no cell borders, no text. Left to right: 1 a worn canvas scavenger sack half full of scrap and planks (gathering). 2 a pair of taped wooden training batons crossed over a rolled cloth hand wrap (training). 3 a dented metal flashlight casting a short warm amber beam (night patrol). 4 a small patched cloth teddy bear with one button eye (childcare). 5 an open leather tool satchel with a wrench, goggles and gloves sticking out (auto-equip gear). No names, captions, lettering, logos or watermarks.

[그림 2] 파일: assets/illustrated/walls.webp
- 투명 배경(알파 유지) WebP, 품질 90, 크기 1254 x 418 (418px 정사각형 3칸, 가로 한 줄)
- 프롬프트: Use case: stylized-concept. Isometric building-piece atlas for a Korean post-apocalyptic indie comic survival game. Match the attached shelter-module reference exactly in hand ink contour, muted gouache, crosshatching, isometric angle and scale, grey ash dust, warm amber accents, no glossy render look. Transparent background (PNG alpha). A strict grid of 3 columns x 1 row = 3 equal square cells, one isolated short wall section per cell, centered, same isometric angle and scale, no ground tile, no people, no text. Left to right: 1 a crooked wooden fence of salvaged planks and posts lashed with rope. 2 a low barricade of stacked grey sandbags with a few torn bags and a plank on top. 3 a sturdy wall of riveted rusty steel plates bolted to I-beams, with a small amber work lamp. No names, captions, lettering, logos or watermarks.

[커밋 규칙]
- 위 2개 파일만 추가. 다른 파일(index.html, sw.js, *.js, *.css, 기존 그림)은 절대 수정하지 마.
- 커밋 전에 최신 main을 받고, 충돌 없이 main에 바로 커밋·푸시.
- 커밋 메시지: "생존자 일 아이콘·방벽 그림 추가 (duty-icons, walls)"
- 끝나면 두 파일의 실제 픽셀 크기, 투명 여부, 파일 용량, 커밋 해시를 알려 줘.
```
