// 손그림 아틀라스(assets/illustrated/*.webp)를 불러와 칸별로 잘라 쓰는 곳.
// 자르기 좌표는 웹의 design.js · settlement.js 값을 그대로 옮겼다.
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class Atlas {
  Atlas._();
  static final Map<String, ui.Image> _img = {};
  static Future<void>? _loading;

  static const files = [
    'shelters.webp', 'modules.webp', 'module-upgrades.webp', 'exploration-sites.webp', 'landmarks.webp', 'settlement-props.webp', 'resources.webp',
    'survivors-founders.webp', 'survivors-neighbors.webp', 'survivors-signals.webp', 'survivors-frontier.webp', 'survivors-scouts.webp',
    'residents.webp', 'survivors-silhouettes.webp',
  ];

  static Future<void> load() => _loading ??= () async {
        for (final f in files) {
          try {
            final data = await rootBundle.load('assets/illustrated/$f');
            final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
            _img[f] = (await codec.getNextFrame()).image;
          } catch (_) {
            // 그림이 없으면 그 부분만 단순한 도형으로 그린다
          }
        }
      }();

  static ui.Image? image(String f) => _img[f];

  /// cols × rows 격자의 index번째 칸
  static Rect? cell(String f, int index, int cols, int rows) {
    final im = _img[f];
    if (im == null) return null;
    final w = im.width / cols, h = im.height / rows;
    return Rect.fromLTWH(index % cols * w, (index ~/ cols) * h, w, h);
  }

  // design.js siteFrames: 폐차·무너진 집·털린 상점 줄마다 [살아 있음 0~4, 다 털림 5]
  static const siteFrames = [
    [17, 128, 278, 188], [304, 64, 283, 249], [597, 117, 284, 193], [892, 137, 286, 179], [1192, 57, 278, 253], [1482, 151, 278, 163],
    [14, 351, 286, 239], [306, 355, 306, 235], [614, 329, 272, 268], [892, 361, 290, 241], [1187, 365, 294, 231], [1484, 445, 278, 156],
    [16, 612, 281, 230], [308, 617, 301, 228], [618, 618, 273, 226], [896, 620, 290, 229], [1192, 631, 286, 217], [1482, 693, 279, 158],
  ];

  // design.js landmarkFrames: 0~4 폐허, 5~9 복구
  static const landmarkFrames = [
    [18, 83, 473, 334], [499, 53, 236, 362], [757, 173, 400, 255], [1169, 91, 443, 331], [1623, 180, 346, 256],
    [22, 437, 471, 328], [501, 424, 235, 335], [758, 524, 406, 246], [1164, 435, 449, 338], [1618, 525, 353, 256],
  ];
  static const landmarkWidth = [76.0, 44.0, 72.0, 76.0, 66.0];

  // chapter-design.js mf: 모듈마다 [2단계, 3단계] (MOD_ORDER 순서)
  static const moduleUpFrames = [
    [12, 85, 272, 239], [301, 32, 286, 287], [606, 79, 277, 242], [895, 40, 278, 284], [1193, 75, 265, 236], [1476, 35, 285, 283],
    [30, 330, 253, 252], [305, 324, 284, 258], [606, 347, 257, 235], [887, 337, 334, 260], [1273, 339, 145, 231], [1546, 322, 163, 248],
    [14, 597, 271, 259], [297, 597, 293, 268], [596, 604, 282, 246], [886, 597, 329, 266], [1218, 590, 242, 267], [1474, 590, 293, 272],
  ];

  // settlement.js props
  static const propFrames = [
    [14, 46, 337, 276], [376, 60, 331, 254], [726, 114, 319, 203], [1081, 168, 263, 145], [37, 352, 287, 209], [355, 335, 358, 243],
    [734, 350, 306, 231], [1087, 403, 273, 163], [68, 598, 214, 241], [445, 590, 225, 277], [728, 637, 282, 225], [1179, 586, 118, 279],
    [87, 863, 170, 255], [380, 870, 309, 232], [718, 882, 347, 231], [1139, 882, 188, 239],
  ];
  static const propWidth = [53.0, 58.0, 49.0, 44.0, 45.0, 57.0, 51.0, 44.0, 16.0, 24.0, 36.0, 15.0, 16.0, 44.0, 45.0, 21.0];

  static Rect fr(List<int> f) => Rect.fromLTWH(f[0].toDouble(), f[1].toDouble(), f[2].toDouble(), f[3].toDouble());
}
