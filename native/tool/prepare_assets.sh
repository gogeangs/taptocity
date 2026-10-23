#!/usr/bin/env bash
# 저장소 원본 그림·글꼴을 네이티브 앱 폴더로 복사한다. (native/ 에서 실행)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/illustrated assets/fonts
for f in shelters modules module-upgrades exploration-sites landmarks settlement-props resources \
  survivors-founders survivors-neighbors survivors-signals survivors-frontier survivors-scouts residents survivors-silhouettes \
  gear-tools gear-wear gear-keep line-items world-panorama radio companions peddler peddler-expressions \
  founder-expressions crows-kids regional-npcs story-1 story-2 story-3 story-4 story-5 underground-icons player-faceless \
  duty-icons walls research-icons guests survivors-signature-1 survivors-signature-2 \
  walkers-1 walkers-2 walkers-3 terrain-props ground-tiles lantern-tower line-stations line-stations-factory landmarks-desert landmarks-factory landmarks-snow ash-foes; do
  cp "../assets/illustrated/$f.webp" assets/illustrated/
done
# 웹툰 컷 (2×2 네 칸, 앱 전용): 사건·합류 장면
mkdir -p assets/illustrated/cuts
cp ../assets/illustrated/cuts/*.webp assets/illustrated/cuts/
# 웹 글꼴(woff2)을 앱용(ttf)으로
python3 -m fontTools.ttLib.woff2 decompress -o assets/fonts/ttc-sans.ttf ../fonts/ttc-sans.woff2
ls -la assets/illustrated assets/fonts
