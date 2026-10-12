#!/usr/bin/env bash
# 저장소 원본 그림·글꼴을 네이티브 앱 폴더로 복사한다. (native/ 에서 실행)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/illustrated assets/fonts
for f in shelters modules module-upgrades exploration-sites landmarks settlement-props resources \
  survivors-founders survivors-neighbors survivors-signals survivors-frontier survivors-scouts residents survivors-silhouettes \
  gear-tools gear-wear gear-keep line-items; do
  cp "../assets/illustrated/$f.webp" assets/illustrated/
done
# 웹 글꼴(woff2)을 앱용(ttf)으로
python3 -m fontTools.ttLib.woff2 decompress -o assets/fonts/ttc-sans.ttf ../fonts/ttc-sans.woff2
# 이야기 글꼴: 고운바탕 (OFL)
for w in Regular Bold; do
  [ -f "assets/fonts/GowunBatang-$w.ttf" ] || curl -fsSL -o "assets/fonts/GowunBatang-$w.ttf" "https://github.com/google/fonts/raw/main/ofl/gowunbatang/GowunBatang-$w.ttf"
done
ls -la assets/illustrated assets/fonts
