// 생존자 초상 (웹 design.js portrait / silhouette). 그림 칸을 상자에 위쪽 맞춤으로 꽉 채운다.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'atlas.dart';

class _Src {
  const _Src(this.file, this.cols, this.rows, this.index, {this.inset = const [0, 0, 0, 0]});
  final String file;
  final int cols, rows, index;
  final List<double> inset; // 왼, 위, 가로 줄임, 세로 줄임
}

const _sheets = {
  'founders': ('survivors-founders.webp', 4, 1),
  'neighbors': ('survivors-neighbors.webp', 2, 2),
  'signals': ('survivors-signals.webp', 2, 2),
  'frontier': ('survivors-frontier.webp', 2, 2),
  'scouts': ('survivors-scouts.webp', 2, 1),
};
const _map = [
  ('founders', 0), ('neighbors', 0), ('founders', 1), ('neighbors', 1), ('neighbors', 2), ('neighbors', 3), ('signals', 0), ('founders', 2), ('signals', 1),
  ('founders', 3), ('signals', 2), ('signals', 3), ('frontier', 0), ('frontier', 1), ('frontier', 2), ('frontier', 3), ('scouts', 0), ('scouts', 1),
];

_Src? _srcFor(int id) {
  if (id >= 0 && id < _map.length) {
    final (k, n) = _map[id];
    final (f, c, r) = _sheets[k]!;
    return _Src(f, c, r, n);
  }
  if (id >= 18 && id < 30) return _Src('residents.webp', 4, 3, id - 18, inset: const [6, 6, 12, 14]);
  return null;
}

class Portrait extends StatelessWidget {
  const Portrait(this.id, {super.key, this.width = 54, this.height = 63, this.locked = false});
  final int id;
  final double width, height;
  final bool locked;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height, child: CustomPaint(painter: _PortraitPainter(id, locked)));
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.id, this.locked);
  final int id;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    if (locked) {
      // 아직 못 만난 사람: 실루엣 (survivors-silhouettes.webp, 6×5)
      canvas.drawRect(box, Paint()..color = const Color(0xFFE6D8B6));
      final img = Atlas.image('survivors-silhouettes.webp');
      final src = Atlas.cell('survivors-silhouettes.webp', id, 6, 5);
      if (img != null && src != null && id < 30) _cover(canvas, img, src, Rect.fromLTWH(0, size.height * .03, size.width, size.height * .97), .86);
      return;
    }
    final s = _srcFor(id);
    if (s == null) return;
    final img = Atlas.image(s.file);
    final cell = Atlas.cell(s.file, s.index, s.cols, s.rows);
    if (img == null || cell == null) return;
    final src = Rect.fromLTWH(cell.left + s.inset[0], cell.top + s.inset[1], cell.width - s.inset[2], cell.height - s.inset[3]);
    _cover(canvas, img, src, box, 1);
  }

  /// preserveAspectRatio="xMidYMin slice": 가로 가운데, 위쪽 맞춤으로 꽉 채움
  void _cover(Canvas canvas, ui.Image img, Rect src, Rect dst, double alpha) {
    final k = (dst.width / src.width) > (dst.height / src.height) ? dst.width / src.width : dst.height / src.height;
    final w = dst.width / k, h = dst.height / k;
    final s = Rect.fromLTWH(src.left + (src.width - w) / 2, src.top, w, h);
    canvas.save();
    canvas.clipRect(dst);
    canvas.drawImageRect(img, s, dst, Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, alpha));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortraitPainter old) => old.id != id || old.locked != locked;
}
