# 동네별 랜드마크 아틀라스 (사막·공단·설원)

`landmarks.webp`와 같은 배치(5열 × 2행, 위=폐허, 아래=복구)로 동네마다 한 장씩 만든다.
ChatGPT에 `landmarks.webp`를 스타일 참고 이미지로 함께 올리고, 아래 프롬프트를 동네별로 하나씩 쓴다.
열 순서는 게임의 역할 순서(학교→급수→연료→기록→역)와 같아야 한다.

## 공통 머리말

Create a production game sprite atlas on fully transparent background, 5 columns and 2 rows of TEN separate isometric post-disaster landmarks. Match the attached reference exactly in art style: hand-inked comic contour, muted gouache, worn handmade materials, controlled detail, 30-degree isometric view, same object scale as the reference. Equal generously spaced cells; no overlap, no ground rectangle, no text, no letters, no people. Each object has a compact diamond footprint and fits inside its cell. TOP ROW: abandoned, damaged versions. BOTTOM ROW: the EXACT SAME buildings from the same angle, repaired by survivors, with small restrained warm amber lights and a few plants, still worn, not pristine. Very recognizable distinct silhouettes at small mobile-game scale. Wide 5:2 composition.

## 사막 (landmarks-desert)

Setting: reclaimed coastal land turned to desert, sand mixed with grey ash, sun-bleached concrete, rusty corrugated metal, faded turquoise paint. Columns left to right: (1) small boarding school with flat roof and courtyard arches, sand drifts against walls; (2) seawater desalination unit — two squat tanks, pipes and a filter rack; (3) tall rusty fuel-dispensing tower with hose arm on a concrete pad; (4) land-reclamation records office, low concrete building with a big map window; (5) half-buried ring-line railway station platform entrance with arched canopy. Top row: sand piled to the windows, torn awnings, cracked tanks. Bottom row: sand swept away, patched canvas shade cloths, clean water dripping, lit windows.

## 공단 (landmarks-factory)

Setting: rusted industrial estate, soot-stained brick, steel trusses, chain-link, hazard stripes faded to grey-orange. Columns left to right: (1) vocational training center, two-storey brick with a welding workshop bay; (2) large round cooling-water reservoir with catwalk and pipe; (3) fuel depot shed with stacked oil drums; (4) factory office block with filing-cabinet silhouettes in windows; (5) freight rail station with a short loading platform and a single boxcar. Top row: broken skylights, toppled drums, rust streaks. Bottom row: patched skylights, drums stacked neatly, catwalk repaired, lit office windows.

## 설원 (landmarks-snow)

Setting: mountain village under snow over grey ash, dark timber, slate roofs heavy with snow, icicles. Columns left to right: (1) village community hall with a wide gable roof and a chimney; (2) small timber-and-glass greenhouse; (3) mountain lodge boiler house with a squat chimney and oil tank; (4) small rural post office with a red postbox (no letters on it); (5) narrow-gauge railway station with a waiting room and a small stove pipe. Top row: roofs sagging under snow, broken glass, cold chimneys. Bottom row: snow shoveled into neat piles, smoke from chimneys, steamed greenhouse glass, warm lit windows.

## 넣는 법

이미지를 받으면 대화에 올려 주세요. 칸 자르기·투명 배경 확인·WebP 변환·동네별 연결은 Claude가 한다.

## 적용 (2026-10-12)

ChatGPT로 만든 세 장을 `landmarks-desert.webp` · `landmarks-factory.webp` · `landmarks-snow.webp`로 넣었다. 알파 16 미만 픽셀과 떠다니는 먼지 점은 지우고, 칸은 연결 영역으로 자동 검출해 `design.js`의 `LMR` 프레임에 적었다. 그 동네에 있을 때만 처음 쓸 때 받으며, 받기 전에는 첫 동네 그림에 동네 색을 입혀 보여 준다. 동네 색 입히기(SNOW_FILES)는 이 그림들에는 적용하지 않는다.
