// 웹 시트의 부품(.row.mcard, .cost.cc, .buy, .segs, .sumchips, .sec …)을 같은 치수·색으로 옮겼다.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'atlas.dart';
import 'icons.dart';
import 'theme.dart';

/// 자원 그림 (resources.webp 12칸)
class ResIcon extends StatelessWidget {
  const ResIcon(this.k, {super.key, this.size = 18, this.dim = false});
  final String k;
  final double size;
  final bool dim;
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _ResPainter(k, dim)));
}

class _ResPainter extends CustomPainter {
  _ResPainter(this.k, this.dim);
  final String k;
  final bool dim;
  @override
  void paint(Canvas canvas, Size size) {
    final img = Atlas.image('resources.webp');
    final idx = resIcon[k];
    if (img == null || idx == null) {
      canvas.drawCircle(size.center(Offset.zero), size.width * .38, Paint()..color = Color(matOf[k]?.color ?? 0xFFFFCF7A));
      return;
    }
    final src = Atlas.cell('resources.webp', idx, 12, 1)!;
    final p = Paint()..filterQuality = FilterQuality.medium;
    if (dim) {
      p.colorFilter = const ColorFilter.matrix([.33, .33, .33, 0, 0, .33, .33, .33, 0, 0, .33, .33, .33, 0, 0, 0, 0, 0, .55, 0]);
    }
    canvas.drawImageRect(img, src, Offset.zero & size, p);
  }

  @override
  bool shouldRepaint(_ResPainter old) => old.k != k || old.dim != dim;
}

/// 아틀라스 그림 한 칸 (src 영역을 상자 안에 맞춰 그림)
class AtlasPic extends StatelessWidget {
  const AtlasPic({super.key, required this.file, required this.src, this.width = 78, this.height = 88, this.gray = false});
  final String file;
  final Rect? src;
  final double width, height;
  final bool gray;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height, child: CustomPaint(painter: _PicPainter(file, src, gray)));
}

class _PicPainter extends CustomPainter {
  _PicPainter(this.file, this.src, this.gray);
  final String file;
  final Rect? src;
  final bool gray;
  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? img = Atlas.image(file);
    if (img == null || src == null) return;
    final k = (size.width / src!.width) < (size.height / src!.height) ? size.width / src!.width : size.height / src!.height;
    final dst = Rect.fromCenter(center: size.center(Offset.zero), width: src!.width * k, height: src!.height * k);
    final p = Paint()..filterQuality = FilterQuality.medium;
    if (gray) p.colorFilter = const ColorFilter.matrix([.3, .59, .11, 0, 0, .3, .59, .11, 0, 0, .3, .59, .11, 0, 0, 0, 0, 0, .55, 0]);
    canvas.drawImageRect(img, src!, dst, p);
  }

  @override
  bool shouldRepaint(_PicPainter old) => old.src != src || old.file != file || old.gray != gray;
}

/// 모듈 그림: 1단계는 modules.webp, 2·3단계는 module-upgrades.webp (웹 chapter-design.js)
Widget moduleThumb(int id, int l, {double w = 78, double h = 88, bool gray = false}) {
  final n = modOrder.indexOf(id);
  if (l >= 1 && Atlas.image('module-upgrades.webp') != null) {
    return AtlasPic(file: 'module-upgrades.webp', src: Atlas.fr(Atlas.moduleUpFrames[n * 2 + (l - 1).clamp(0, 1)]), width: w, height: h, gray: gray);
  }
  return AtlasPic(file: 'modules.webp', src: Atlas.cell('modules.webp', n, 3, 3), width: w, height: h, gray: gray);
}

Widget coreThumb(int lv, {double w = 78, double h = 88}) => AtlasPic(file: 'shelters.webp', src: Atlas.cell('shelters.webp', (lv - 1).clamp(0, 4), 3, 2), width: w, height: h);

/// 아이콘 썸네일 (웹 .th.ico)
Widget icoThumb(String svg) => Container(
      width: 56,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 11, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const RadialGradient(center: Alignment(0, -.2), colors: [Color(0xFFF3E6C6), Color(0xFFDCC9A0)]),
      ),
      alignment: Alignment.center,
      child: SvgIcon(svg, size: 26, color: Ttc.sepia),
    );

/// 비용 칩 (.cost.cc): 가진 만큼 아래 막대가 차오른다
class CostChip extends StatelessWidget {
  const CostChip({super.key, required this.label, required this.have, required this.need, this.icon});
  final String label;
  final num have, need;
  final String? icon;
  @override
  Widget build(BuildContext context) {
    final ok = have >= need;
    final p = need <= 0 ? 1.0 : (have / need).clamp(0, 1).toDouble();
    return Container(
      decoration: BoxDecoration(
        color: ok ? const Color(0x09252E36) : Ttc.noBg,
        borderRadius: BorderRadius.circular(5),
        border: ok ? Border.all(color: Ttc.line) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(5, 3, 8, 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[ResIcon(icon!, size: 17), const SizedBox(width: 2)],
            Text(ok ? '$label ' : '$label ', style: Ttc.t(11, color: ok ? Ttc.sepia2 : Ttc.noText, weight: FontWeight.w500)),
            Text(fmt(ok ? need : have), style: Ttc.t(11, color: ok ? Ttc.ok : Ttc.noText, weight: FontWeight.w700)),
            if (!ok) Text('/${fmt(need)}', style: Ttc.t(11, color: Ttc.noText.withValues(alpha: .65), weight: FontWeight.w500)),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 3,
          child: Container(
            color: const Color(0x1A3B2A1A),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: p, child: Container(color: ok ? Ttc.ok : Ttc.no)),
          ),
        ),
      ]),
    );
  }
}

/// 비용 묶음 (모자란 것 먼저)
Widget costWrap(Game g, Cost c, {List<Widget> lead = const []}) {
  final items = c.entries.toList()..sort((a, b) => (g.have(a.key) >= a.value ? 1 : 0) - (g.have(b.key) >= b.value ? 1 : 0));
  return Wrap(spacing: 5, runSpacing: 4, children: [
    ...lead,
    for (final e in items) CostChip(label: matOf[e.key]?.n ?? e.key, have: g.have(e.key), need: e.value, icon: e.key),
  ]);
}

/// 웹 .buy 버튼. 켜짐: 짙은 청록, 꺼짐: 회색 + 이유
class BuyButton extends StatefulWidget {
  const BuyButton(this.label, {super.key, this.onTap, this.why, this.hero = false, this.width = 64});
  final String label;
  final VoidCallback? onTap;
  final String? why;
  final bool hero;
  final double width;
  @override
  State<BuyButton> createState() => _BuyButtonState();
}

class _BuyButtonState extends State<BuyButton> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    final Color bg, bd, fg;
    if (widget.hero) {
      bg = Ttc.amberBtn;
      bd = Ttc.amberBtnLine;
      fg = const Color(0xFF243039);
    } else if (on) {
      bg = Ttc.darkBtn;
      bd = Ttc.darkBtn;
      fg = Ttc.darkBtnText;
    } else {
      bg = Ttc.offBtn;
      bd = Ttc.offBtnLine;
      fg = Ttc.offBtnText;
    }
    return GestureDetector(
      onTapDown: on ? (_) => setState(() => down = true) : null,
      onTapUp: on ? (_) => setState(() => down = false) : null,
      onTapCancel: on ? () => setState(() => down = false) : null,
      onTap: widget.onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 80),
        opacity: down ? .8 : 1,
        child: Container(
          width: widget.hero ? double.infinity : widget.width,
          constraints: BoxConstraints(minHeight: widget.hero ? 56 : 44),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: bd, width: .8)),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.label, style: Ttc.t(widget.hero ? 15.5 : (on ? 13 : 12), color: fg, weight: FontWeight.w700, height: 1.2)),
            if (widget.why != null) Text(widget.why!, style: Ttc.t(10.5, color: fg.withValues(alpha: .85), weight: FontWeight.w600, height: 1.2)),
          ]),
        ),
      ),
    );
  }
}

Widget pips(int l, [int n = 3]) => Row(mainAxisSize: MainAxisSize.min, children: [
      for (var k = 0; k < n; k++)
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(shape: BoxShape.circle, color: k <= l ? Ttc.amber : const Color(0x2E3B2A1A)),
        ),
    ]);

Widget doneBadge([String t = '완성']) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: const Color(0x1F4F6E2F), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SvgIcon(Ico.check, size: 13, color: Ttc.ok),
        const SizedBox(width: 4),
        Text(t, style: Ttc.t(12, color: Ttc.ok, weight: FontWeight.w700, height: 1)),
      ]),
    );

Widget lockBadge(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: const Color(0x143B2A1A), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SvgIcon(Ico.lock, size: 13, color: Ttc.sepia2),
        const SizedBox(width: 4),
        Text(t, style: Ttc.t(11.5, color: Ttc.sepia2, weight: FontWeight.w700, height: 1)),
      ]),
    );

enum CardKind { normal, hero, locked, more }

/// 웹 .row.mcard: [그림 78] [제목·설명·비용] [버튼 64]
class MCard extends StatelessWidget {
  const MCard({super.key, required this.thumb, required this.title, this.tags = const [], this.desc, this.costs, this.button, this.kind = CardKind.normal});
  final Widget thumb;
  final String title;
  final List<Widget> tags;
  final Widget? desc;
  final Widget? costs;
  final Widget? button;
  final CardKind kind;

  @override
  Widget build(BuildContext context) {
    final hero = kind == CardKind.hero;
    final dim = kind == CardKind.locked;
    final head = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
        Text(title, style: Ttc.t(15, color: Ttc.sepia, weight: FontWeight.w700, height: 1.4)),
        ...tags,
      ]),
      if (desc != null) Padding(padding: const EdgeInsets.only(top: 3), child: desc!),
      if (costs != null) Padding(padding: const EdgeInsets.only(top: 7), child: costs!),
    ]);
    final body = hero
        ? Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [thumb, const SizedBox(width: 10), Expanded(child: head)]),
            if (button != null) ...[const SizedBox(height: 10), button!],
          ])
        : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Opacity(opacity: dim ? .5 : 1, child: thumb),
            const SizedBox(width: 10),
            Expanded(child: Opacity(opacity: dim ? .6 : 1, child: head)),
            if (button != null) ...[const SizedBox(width: 10), button!],
          ]);
    // 둥근 모서리에는 한 가지 색 테두리만 그릴 수 있어서, 영웅 카드의 왼쪽 띠는 따로 얹는다
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: hero ? Ttc.heroCard : dim ? Ttc.lockedCard : kind == CardKind.more ? Colors.transparent : Ttc.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Ttc.line, width: .8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: body),
        if (hero) const Positioned(left: 0, top: 0, bottom: 0, width: 2.4, child: ColoredBox(color: Ttc.heroLine)),
      ]),
    );
  }
}

Widget descText(String t) => Text(t, style: Ttc.t(12, color: Ttc.sepia2, height: 1.5));
Widget smallTag(String t) => Text(t, style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w500));
Widget newTag() => Text('새로 짓기', style: Ttc.t(10, color: const Color(0xFF58716A), weight: FontWeight.w500));

/// 웹 .sec: 굵은 소제목 + 작은 설명 + 오른쪽으로 이어지는 선
Widget sec(String t, [String? small]) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
      child: Row(children: [
        Text(t, style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
        if (small != null) ...[const SizedBox(width: 8), Text(small, style: Ttc.t(11.5, color: Ttc.sepia2, weight: FontWeight.w500))],
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Ttc.line, height: 1, thickness: .8)),
      ]),
    );

/// 웹 .segs
class Segs extends StatelessWidget {
  const Segs({super.key, required this.items, required this.on, required this.onTap, this.dots = const []});
  final List<String> items;
  final List<bool> dots;
  final int on;
  final void Function(int) onTap;
  @override
  Widget build(BuildContext context) {
    Widget seg(int k) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(k),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: k == on ? Ttc.surface : Colors.transparent, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(items[k], style: Ttc.t(13, color: k == on ? const Color(0xFF22323B) : Ttc.segText, weight: FontWeight.w600)),
              if (k < dots.length && dots[k])
                Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 5), decoration: const BoxDecoration(shape: BoxShape.circle, color: Ttc.amber)),
            ]),
          ),
        );
    // 웹 .segs: 5칸이면 3칸씩 두 줄
    final cols = items.length >= 5 ? 3 : items.length;
    final rows = <Widget>[];
    for (var r = 0; r * cols < items.length; r++) {
      rows.add(Row(children: [
        for (var c = 0; c < cols; c++) Expanded(child: r * cols + c < items.length ? seg(r * cols + c) : const SizedBox()),
      ]));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Ttc.segs, borderRadius: BorderRadius.circular(9)),
      child: Column(children: rows),
    );
  }
}

/// 웹 .sumchips 한 칸
Widget sumChip(List<InlineSpan> spans, {String? icon, bool bad = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[ResIcon(icon, size: 17), const SizedBox(width: 3)],
        Text.rich(TextSpan(children: spans), style: Ttc.t(11, color: bad ? Ttc.no : Ttc.sumText, weight: FontWeight.w500)),
      ]),
    );
TextSpan bold(String t) => TextSpan(text: t, style: const TextStyle(fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)], color: Ttc.sepia));

/// 웹 .empty
Widget emptyBox(Widget icon, String t, String d) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x333B2A1A))),
      child: Column(children: [
        Container(width: 56, height: 56, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x123B2A1A)), alignment: Alignment.center, child: icon),
        const SizedBox(height: 6),
        Text(t, style: Ttc.t(14.5, color: Ttc.sepia, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(d, textAlign: TextAlign.center, style: Ttc.t(12.5, color: Ttc.sepia2, height: 1.5)),
      ]),
    );
