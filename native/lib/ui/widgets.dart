import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'atlas.dart';
import 'theme.dart';

/// 자원 그림 (resources.webp 12칸). 그림이 없으면 색 점.
class ResIcon extends StatelessWidget {
  const ResIcon(this.k, {super.key, this.size = 18});
  final String k;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _ResPainter(k)));
}

class _ResPainter extends CustomPainter {
  _ResPainter(this.k);
  final String k;
  @override
  void paint(Canvas canvas, Size size) {
    final img = Atlas.image('resources.webp');
    final idx = resIcon[k];
    if (img == null || idx == null) {
      canvas.drawCircle(size.center(Offset.zero), size.width * .38, Paint()..color = Color(matOf[k]?.color ?? 0xFFFFCF7A));
      return;
    }
    final src = Atlas.cell('resources.webp', idx, 12, 1)!;
    final s = size.width * 1.3;
    canvas.drawImageRect(img, src, Rect.fromCenter(center: size.center(Offset.zero), width: s, height: s), Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_ResPainter old) => old.k != k;
}

/// 비용 표시: 가진 만큼 차오르는 막대. 다 모이면 작게.
class CostRow extends StatelessWidget {
  const CostRow(this.g, this.cost, {super.key, this.dark = true});
  final Game g;
  final Cost cost;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final fg = dark ? Ttc.sepia : Ttc.paper;
    final items = cost.entries.toList()..sort((a, b) => (g.have(a.key) >= a.value ? 1 : 0) - (g.have(b.key) >= b.value ? 1 : 0));
    return Wrap(spacing: 6, runSpacing: 4, children: [
      for (final e in items)
        () {
          final h = g.have(e.key), ok = h >= e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ok ? fg.withValues(alpha: .25) : Ttc.rust.withValues(alpha: .7)),
              gradient: ok
                  ? null
                  : LinearGradient(colors: [Ttc.amber.withValues(alpha: .35), Colors.transparent], stops: [(h / e.value).clamp(0, 1).toDouble(), (h / e.value).clamp(0, 1).toDouble()]),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ResIcon(e.key, size: 14),
              const SizedBox(width: 3),
              Text(ok ? fmt(e.value) : '${matOf[e.key]?.n ?? e.key} ${fmt(h < e.value ? h : e.value)}/${fmt(e.value)}',
                  style: Ttc.body(12.5, color: ok ? fg.withValues(alpha: .75) : (dark ? Ttc.rust : Ttc.glow), weight: FontWeight.w600)),
            ]),
          );
        }(),
    ]);
  }
}

/// 종이 느낌 카드
class PaperCard extends StatelessWidget {
  const PaperCard({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.dim = false});
  final Widget child;
  final EdgeInsets padding;
  final bool dim;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: padding,
        decoration: BoxDecoration(
          color: dim ? const Color(0xFFD9CCAA) : Ttc.paper,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: child,
      );
}

class TtcButton extends StatelessWidget {
  const TtcButton(this.label, {super.key, this.onTap, this.primary = true, this.small = false});
  final String label;
  final VoidCallback? onTap;
  final bool primary, small;
  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14, vertical: small ? 6 : 9),
        decoration: BoxDecoration(
          color: !on ? const Color(0x33000000) : primary ? Ttc.sepia : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: on ? Ttc.sepia : Ttc.sepia2.withValues(alpha: .4), width: 1.5),
        ),
        child: Text(label, style: Ttc.body(small ? 13 : 14.5, color: !on ? Ttc.sepia2 : primary ? Ttc.paper : Ttc.sepia, weight: FontWeight.w700)),
      ),
    );
  }
}

/// 원 둘레 진행 막대 (랜턴 버튼)
class RingPainter extends CustomPainter {
  RingPainter(this.p, this.color);
  final double p;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 4);
    canvas.drawArc(r, 0, 6.2832, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0x55000000));
    canvas.drawArc(r, -1.5708, 6.2832 * p, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color);
  }

  @override
  bool shouldRepaint(RingPainter old) => old.p != p || old.color != color;
}

/// 아틀라스 한 칸을 그대로 보여 주는 썸네일
class AtlasThumb extends StatelessWidget {
  const AtlasThumb(this.file, this.index, this.cols, this.rows, {super.key, this.size = 52});
  final String file;
  final int index, cols, rows;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _ThumbPainter(file, index, cols, rows)));
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.file, this.index, this.cols, this.rows);
  final String file;
  final int index, cols, rows;
  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? img = Atlas.image(file);
    final src = Atlas.cell(file, index, cols, rows);
    if (img == null || src == null) return;
    final k = (size.width / src.width).clamp(0, size.height / src.height).toDouble();
    final dst = Rect.fromCenter(center: size.center(Offset.zero), width: src.width * k, height: src.height * k);
    canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.index != index || old.file != file;
}
