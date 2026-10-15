# Ground and water textures (2026-10-13)

The map's flat ground and water are still painted by code (flat colors + a few ink strokes). These top-down textures are mapped onto
each isometric diamond tile, then lightly tinted by the code so greenness, region mood and day/night still work.

- `ground-textures.webp`: 4 columns x 2 rows of 512px squares → 2048 x 1024, opaque.
  Order: 0 ash-dusted dirt (first town), 1 dry grass on dirt, 2 cracked concrete plaza (around the shelter), 3 dark water,
  4 desert sand, 5 factory soot ground, 6 snow over ash, 7 frozen water.
- Each square must tile seamlessly with itself (left edge matches right, top matches bottom). After receiving the file the edges are
  blended once more in code so tiling seams do not show.

> 2026-10-15: 게임에 쓰지 않는 원본 `ground-textures.webp`는 저장소에서 삭제. 게임은 다듬은 `ground-tiles.webp`만 쓴다(원본은 git 이력에 남아 있음).
