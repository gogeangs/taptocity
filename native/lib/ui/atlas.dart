// 손그림 아틀라스(assets/illustrated/*.webp)를 불러와 칸별로 잘라 쓰는 곳.
// 자르기 좌표는 웹의 design.js · settlement.js 값을 그대로 옮겼다.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Atlas {
  Atlas._();
  static final Map<String, ui.Image> _img = {};
  static Future<void>? _loading;

  static const files = [
    'shelters.webp', 'modules.webp', 'module-upgrades.webp', 'exploration-sites.webp', 'landmarks.webp', 'settlement-props.webp', 'resources.webp',
    'survivors-founders.webp', 'survivors-neighbors.webp', 'survivors-signals.webp', 'survivors-frontier.webp', 'survivors-scouts.webp',
    'residents.webp', 'survivors-silhouettes.webp', 'gear-tools.webp', 'gear-wear.webp', 'gear-keep.webp', 'line-items.webp',
    'world-panorama.webp', 'radio.webp', 'companions.webp', 'peddler.webp',
    // 2026-10-13~14 웹 손그림: 일 아이콘·방벽·연구·손님·전용 도구 초상·지도 인물·땅 질감·나무와 풀·등불 탑·노선 역
    'duty-icons.webp', 'walls.webp', 'research-icons.webp',
    'walkers-1.webp', 'walkers-2.webp', 'walkers-3.webp', 'terrain-props.webp', 'ground-tiles.webp', 'lantern-tower.webp',
  ];

  /// 크고 가끔(또는 한 동네에서만) 쓰는 그림: 처음 필요할 때 불러온다 (웹 ttcLazy). 한꺼번에 풀면 메모리를 60MB 넘게 쓴다
  static const lazyFiles = {
    'guests.webp', 'survivors-signature-1.webp', 'survivors-signature-2.webp',
    'line-stations.webp', 'line-stations-factory.webp', 'landmarks-desert.webp', 'landmarks-factory.webp', 'landmarks-snow.webp',
  };

  static Future<void> load() => _loading ??= () async {
        // 한꺼번에 받아 첫 화면을 빨리 띄운다
        await Future.wait(files.map((f) async {
          try {
            final data = await rootBundle.load('assets/illustrated/$f');
            final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
            _img[f] = (await codec.getNextFrame()).image;
          } catch (_) {
            // 그림이 없으면 그 부분만 단순한 도형으로 그린다
          }
        }));
      }();

  static ui.Image? image(String f) {
    final im = _img[f];
    if (im == null && lazyFiles.contains(f)) return lazy(f);
    return im;
  }

  // ---------- 동네의 결: 지도 그림을 동네 색으로 (웹 WEATHER·makeSnowy 2114) ----------
  /// 지금 동네 (화면이 매 틱 맞춘다). 산골은 지붕마다 눈, 사막은 모래, 공단은 재와 녹
  static String? region;
  static VoidCallback? onTint;
  static const tintFiles = {'shelters.webp', 'modules.webp', 'exploration-sites.webp', 'landmarks.webp', 'settlement-props.webp', 'module-upgrades.webp'}; // 웹 SNOW_FILES와 같게
  static final Map<String, ui.Image?> _tinted = {};
  static String? _tintRegion;

  /// 지도에 그릴 그림: 새 동네면 그 동네 색으로 바꾼 것 (다 만들기 전엔 원본)
  static ui.Image? mapImage(String f) {
    final r = region, base = _img[f];
    if (r == null || base == null || !tintFiles.contains(f) || !_tints.containsKey(r)) return base;
    if (_tintRegion != r) {
      for (final im in _tinted.values) {
        im?.dispose();
      }
      _tinted.clear();
      _tintRegion = r;
    }
    if (_tinted.containsKey(f)) return _tinted[f] ?? base;
    _tinted[f] = null;
    _makeTint(f, r, base);
    return base;
  }

  static Future<void> _makeTint(String f, String r, ui.Image base) async {
    try {
      final bd = await base.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (bd == null) return;
      final px = await compute(tintPixels, (bd.buffer.asUint8List(), base.width, base.height, r));
      final done = Completer<ui.Image>();
      ui.decodeImageFromPixels(px, base.width, base.height, ui.PixelFormat.rgba8888, done.complete);
      final im = await done.future;
      if (_tintRegion != r) {
        im.dispose();
        return;
      }
      _tinted[f] = im;
      version.value++;
      onTint?.call();
    } catch (_) {}
  }

  /// 시험용: 그 동네 색 그림을 다 만들 때까지 기다린다
  static Future<void> tintAll(String r) async {
    region = r;
    for (final f in tintFiles) {
      mapImage(f);
    }
    for (final f in tintFiles) {
      final base = _img[f];
      if (base != null && _tinted[f] == null) await _makeTint(f, r, base);
    }
  }

  /// 처음 필요할 때 불러오는 그림 (이야기 장면·표정처럼 크고 가끔 쓰는 것). 다 불러오면 version이 오른다.
  static final ValueNotifier<int> version = ValueNotifier(0);
  static final Set<String> _want = {};
  static ui.Image? lazy(String f) {
    final im = _img[f];
    if (im != null) return im;
    if (_want.add(f)) ensure(f);
    return null;
  }

  /// 그림 하나를 지금 불러온다 (시험·미리 불러오기용)
  static Future<void> ensure(String f) async {
    if (_img[f] != null) return;
    _want.add(f);
    try {
      final data = await rootBundle.load('assets/illustrated/$f');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _img[f] = (await codec.getNextFrame()).image;
      version.value++;
    } catch (_) {}
  }

  // ---------- 손그림 소품의 실제 테두리 (웹 tpBoxes · wkBox · LT.box: 칸마다 불투명한 부분만) ----------
  static final Map<String, List<Rect?>?> _boxes = {};

  /// cols × rows 칸마다 알파가 thr 넘는 부분의 테두리. 다 재기 전엔 null (재기는 한 번만, 뒤에서)
  static List<Rect?>? boxes(String f, int cols, int rows, {int thr = 24}) {
    final key = '$f/$cols/$rows/$thr';
    if (_boxes.containsKey(key)) return _boxes[key];
    final im = _img[f];
    if (im == null) return null;
    _boxes[key] = null;
    () async {
      try {
        final bd = await im.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        if (bd == null) return;
        _boxes[key] = await compute(_trim, (bd.buffer.asUint8List(), im.width, im.height, cols, rows, thr));
        version.value++;
        onTint?.call();
      } catch (_) {}
    }();
    return null;
  }

  static List<Rect?> _trim((Uint8List, int, int, int, int, int) a) {
    final (px, w, h, cols, rows, thr) = a;
    final cw = w / cols, ch = h / rows, out = <Rect?>[];
    for (var k = 0; k < cols * rows; k++) {
      final ox = (k % cols) * cw, oy = (k ~/ cols) * ch;
      var x0 = cw, y0 = ch, x1 = 0.0, y1 = 0.0;
      for (var y = 0.0; y < ch; y += 2) {
        for (var x = 0.0; x < cw; x += 2) {
          final idx = (((oy + y).floor()) * w + (ox + x).floor()) * 4 + 3;
          if (idx < px.length && px[idx] > thr) {
            if (x < x0) x0 = x;
            if (x > x1) x1 = x;
            if (y < y0) y0 = y;
            if (y > y1) y1 = y;
          }
        }
      }
      out.add(x1 > x0 ? Rect.fromLTWH(ox + x0, oy + y0, x1 - x0 + 2, y1 - y0 + 2) : null);
    }
    return out;
  }

  // ---------- 땅·물 질감 (웹 gtPat: ground-tiles.webp 4×2, 256px 칸) ----------
  static final Map<int, ui.Image?> _gt = {};

  /// k번째 질감 칸 (0 흙 · 1 마른 풀 · 2 콘크리트 · 3 물 · 4 사막 · 5 공단 · 6 눈 · 7 언 물). 다 만들기 전엔 null
  static ui.Image? groundTile(int k) {
    if (_gt.containsKey(k)) return _gt[k];
    final im = _img['ground-tiles.webp'];
    if (im == null) return null;
    _gt[k] = null;
    () async {
      try {
        final cw = im.width / 4, ch = im.height / 2;
        final rec = ui.PictureRecorder();
        ui.Canvas(rec).drawImageRect(im, ui.Rect.fromLTWH((k % 4) * cw, (k ~/ 4) * ch, cw, ch), const ui.Rect.fromLTWH(0, 0, 256, 256), ui.Paint()..filterQuality = ui.FilterQuality.medium);
        _gt[k] = await rec.endRecording().toImage(256, 256);
        version.value++;
        onTint?.call();
      } catch (_) {}
    }();
    return null;
  }

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

/// (cap, shade, k, depth, tint, tk, sat)
const _tints = {
  'snow': ([243, 247, 249], [196, 210, 222], .93, 1.0, [225, 232, 238], .1, 1.0),
  'desert': ([226, 201, 152], [176, 140, 92], .78, .55, [228, 186, 126], .13, 1.0),
  'factory': ([58, 52, 50], [34, 29, 27], .72, .55, [118, 78, 56], .2, .62),
};

/// 웹 makeSnowy를 그대로: 위를 향한 면(어두운 윤곽 바로 아래 몇 줄)에 눈·모래·재를 얹고, 나머지는 살짝 물들인다
Uint8List tintPixels((Uint8List, int, int, String) a) {
  final (o, w, h, r) = a;
  final t = _tints[r]!;
  final cap = t.$1, sh = t.$2, k = t.$3, depth = t.$4, tint = t.$5, tk = t.$6, sat = t.$7;
  final p = Uint8List.fromList(o);
  final d0 = math.max(8, (w / 105).round() * depth);
  for (var x = 0; x < w; x++) {
    final nz = .62 + .62 * ((math.sin(x * .37) + math.sin(x * .113 + 1.7) + 2) / 4);
    final d1 = math.max(2, (d0 * nz).round()), d2 = math.max(2, (d1 * .75).round());
    var run = -1, dd = d1, dark = 0;
    for (var y = 0; y < h; y++) {
      final i = (y * w + x) * 4;
      if (o[i + 3] < 90) {
        run = -1;
        dd = d1;
        dark = 0;
        continue;
      }
      final lum = o[i] * .3 + o[i + 1] * .59 + o[i + 2] * .11;
      if (lum < 52) {
        dark++;
        if (run > d2 + 1 || run < 0) {
          run = 0;
          dd = d2;
        } else {
          run++;
        }
      } else {
        if (dark >= 1 && dark <= 3 && run > dd) {
          run = 1;
          dd = d2;
        }
        dark = 0;
        run++;
      }
      double rr = o[i].toDouble(), gg = o[i + 1].toDouble(), bb = o[i + 2].toDouble();
      if (sat < 1) {
        final l = rr * .3 + gg * .59 + bb * .11;
        rr = l + (rr - l) * sat;
        gg = l + (gg - l) * sat;
        bb = l + (bb - l) * sat;
      }
      if (run >= 1 && run <= dd && lum >= 52) {
        final tt = run <= dd * .7 ? 1.0 : 1 - (run - dd * .7) / (dd * .3 + .001), s = run >= dd - 1, kk = tt * k;
        final c = s ? sh : cap;
        rr += (c[0] - rr) * kk;
        gg += (c[1] - gg) * kk;
        bb += (c[2] - bb) * kk;
      } else {
        rr = rr * (1 - tk) + tint[0] * tk;
        gg = gg * (1 - tk) + tint[1] * tk;
        bb = bb * (1 - tk) + tint[2] * tk;
      }
      p[i] = math.min(255, math.max(0, rr.round()));
      p[i + 1] = math.min(255, math.max(0, gg.round()));
      p[i + 2] = math.min(255, math.max(0, bb.round()));
    }
  }
  return p;
}
