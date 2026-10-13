# Terrain props (2026-10-13)

The map's buildings, sites and landmarks are hand-drawn, but trees, weeds and small ground clutter are still drawn by code.
On 2026-10-13 the code versions were toned down (muted ash-dusted greens, ink outlines, ink ripples on muted water, faint ground hatching,
rusty steel wall). This atlas replaces the code trees and weeds with drawn sprites.

- `terrain-props.webp`: 4 columns x 2 rows of equal square cells (256px each → 1024 x 512), transparent background,
  same isometric look and scale as `exploration-sites.webp` / `settlement-props.webp`.
  Order: 0 leafy tree A, 1 leafy tree B, 2 pine, 3 dead tree, 4 weed tuft A, 5 weed tuft B, 6 low shrub, 7 small stone-and-brick clutter.
  The code draws them on the first town's empty ground (other towns keep their own: desert dead shrubs, factory dead trees, snow pines).

## Prompt for ChatGPT (with GitHub access to gogeangs/taptocity)

```
GitHub 저장소 gogeangs/taptocity (브랜치 main)에 게임 그림 1장을 만들어 커밋해 줘.

[참고 그림 — 저장소에서 직접 열어서 스타일을 맞춰]
- assets/illustrated/exploration-sites.webp, assets/illustrated/settlement-props.webp (지도 위 손그림 소품, 투명 배경, 아이소메트릭)

[그림] 파일: assets/illustrated/terrain-props.webp
- 투명 배경(알파 유지) WebP, 품질 90, 크기 1024 x 512 (256px 정사각형 4칸 x 2줄, 칸 테두리 없음)
- 프롬프트: Use case: stylized-concept. Isometric map prop atlas for a Korean post-apocalyptic indie comic survival game. Match the attached map-prop references exactly in hand ink contour, muted gouache, crosshatching, isometric angle and small map scale, grey ash dust settled on everything, no glossy render look. Transparent background (PNG alpha). A strict grid of 4 columns x 2 rows = 8 equal square cells, one isolated prop per cell standing on its own tiny soft shadow, centered at the bottom of the cell, consistent scale (a tree is about 70% of the cell height), no ground tile, no people, no text. Order left to right, top to bottom: 1 a small broadleaf tree with a dusty olive-green crown dusted with grey ash. 2 a second broadleaf tree, thinner and leaning, sparse leaves. 3 a small dark pine, ash on its branches. 4 a dead bare tree with twisted grey branches. 5 a clump of dry weeds and grass. 6 a second weed clump with a few tiny pale yellow wildflowers. 7 a low scraggly shrub. 8 a small pile of broken bricks and pebbles. Palette restrained: olive, moss, ash grey, warm brown, tiny amber accents only. No names, captions, lettering, logos or watermarks.

[커밋 규칙]
- 위 파일 1개만 추가. 다른 파일은 절대 수정하지 마.
- 최신 main을 받고 충돌 없이 main에 바로 커밋·푸시.
- 커밋 메시지: "지도 나무·풀 그림 추가 (terrain-props)"
- 끝나면 실제 픽셀 크기, 투명 여부, 파일 용량, 커밋 해시를 알려 줘.
```
