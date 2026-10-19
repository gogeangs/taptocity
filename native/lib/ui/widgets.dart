// 웹 시트의 부품(.row.mcard, .cost.cc, .buy, .segs, .sumchips, .sec …)을 같은 치수·색으로 옮겼다.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'atlas.dart';
import 'icons.dart';
import 'story_ui.dart';
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
  _PicPainter(this.file, this.src, this.gray) : super(repaint: Atlas.version); // 늦게 불러온 그림이 오면 다시 그림
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

// ---------- 손그림 작은 아이콘 (웹 qa.css 2026-10-13) ----------
/// 생존자 쉴 때 할 일 아이콘 (duty-icons.webp 5칸: 주워 오기·훈련·순찰·아이 돌보기·장비)
const dutyIcoIndex = {'gather': 0, 'train': 1, 'patrol': 2, 'care': 3, 'gear': 4};
Widget dutyIco(String k, {double size = 18}) => AtlasPic(file: 'duty-icons.webp', src: Atlas.cell('duty-icons.webp', dutyIcoIndex[k] ?? 0, 5, 1), width: size, height: size);

/// 글 안에 끼우는 할 일 아이콘
InlineSpan dutySpan(String k, {double size = 17}) => WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: const EdgeInsets.only(right: 2), child: dutyIco(k, size: size)));

/// 방벽 썸네일 (walls.webp 3칸: 나무 울타리·모래주머니·철판 성벽)
Widget wallThumb(int k) => Container(
      width: 78,
      height: 88,
      alignment: Alignment.center,
      child: AtlasPic(file: 'walls.webp', src: Atlas.cell('walls.webp', k.clamp(0, 2), 3, 1), width: 76, height: 76),
    );

/// 연구 썸네일 (research-icons.webp 3칸: 곡괭이·랜턴 불씨·정찰 드론) — 어두운 둥근 네모
Widget researchThumb(String k) => Container(
      width: 64,
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFF2B3138), borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: AtlasPic(file: 'research-icons.webp', src: Atlas.cell('research-icons.webp', const {'tap': 0, 'splash': 1, 'drone': 2}[k] ?? 0, 3, 1), width: 54, height: 54),
    );

/// 이름 없는 손님 초상 (guests.webp 2칸: 떠돌이 상인·길 잃은 가족), 동그랗게
const guestArt = {'떠돌이 상인': 0, '길 잃은 가족': 1};
Widget guestFace(String t, {double size = 40}) {
  final k = guestArt[t];
  final im = Atlas.image('guests.webp');
  if (k == null || im == null) return SvgIcon(Ico.truck, size: size * .5, color: const Color(0xFF3B2A1A));
  // 웹: background 200% auto, 위치 (k*100%, 18%) — 칸 너비만큼 정사각으로 자른 윗부분
  final cw = im.width / 2.0, y = (im.height - cw) * .18;
  return ClipOval(child: Container(color: const Color(0xFFE6D8B6), child: AtlasPic(file: 'guests.webp', src: Rect.fromLTWH(k * cw, y, cw, cw), width: size, height: size)));
}

/// 노친네 얼굴 (웹 .pedface: peddler.webp 50% 12% / 180%) 동그랗게
Widget pedFace({double size = 18}) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x99EFE3C4), spreadRadius: 1)]),
      child: ClipOval(child: AtlasPic(file: 'peddler.webp', src: const Rect.fromLTWH(227.6, 116, 568.9, 568.9), width: size, height: size)),
    );

/// 웹 UGI 선 아이콘 (열쇠·자물쇠·지도)
const keySvg = '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.2" stroke-linecap="round"><circle cx="8" cy="12" r="4"/><path d="M12 12h9M18 12v3M21 12v2"/></svg>';
const lockSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.2"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>';
const mapSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" stroke-linejoin="round"><path d="M3 6l6-2 6 2 6-2v14l-6 2-6-2-6 2z"/><path d="M9 4v14M15 6v14"/></svg>';
Widget lineIco(String svg, double size, Color c) => SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(c, BlendMode.srcIn));

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
    if (widget.hero && on) {
      bg = Ttc.amberBtn;
      bd = Ttc.amberBtnLine;
      fg = const Color(0xFF243039);
    } else if (widget.hero) {
      // 못 누르는 큰 버튼: 빛바랜 베이지 + 짙은 글자 (밝은 호박색이면 눌러도 될 것처럼 보인다)
      bg = const Color(0xFFE4DDCC);
      bd = const Color(0xFFCFC6B2);
      fg = const Color(0xFF5B5A52);
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
            if (widget.why != null)
              widget.hero
                  ? Text(widget.why!, textAlign: TextAlign.center, style: Ttc.t(12, color: fg, weight: FontWeight.w600, height: 1.3))
                  // 좁은 버튼: 두 줄 이유('철판 42\n더 필요')를 버튼 폭에 맞춰 줄인다
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(widget.why!, textAlign: TextAlign.center, style: Ttc.t(10.5, color: fg.withValues(alpha: .85), weight: FontWeight.w600, height: 1.2)),
                    ),
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
        Text(t, style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w700, height: 1)),
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

Widget descText(String t) => Text(t, style: Ttc.t(13, color: Ttc.sepia2, height: 1.5));
Widget smallTag(String t) => Text(t, style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w500));
Widget newTag() => Text('새로 짓기', style: Ttc.t(10, color: const Color(0xFF58716A), weight: FontWeight.w500));

/// 웹 .sec: 굵은 소제목 + 작은 설명 + 오른쪽으로 이어지는 선
Widget sec(String t, [String? small]) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
      child: Row(children: [
        Text(t, style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
        if (small != null) ...[const SizedBox(width: 8), Text(small, style: Ttc.t(12.5, color: Ttc.sepia2, weight: FontWeight.w500))],
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Ttc.line, height: 1, thickness: .8)),
      ]),
    );

/// 웹 .segs
class Segs extends StatelessWidget {
  const Segs({super.key, required this.items, required this.on, required this.onTap, this.dots = const [], this.hlKeys = const [], this.oneRow = false});
  final List<String> items;
  final List<String> hlKeys; // 칸마다 길잡이 강조 키 (story_ui hl)
  final List<bool> dots;
  final int on;
  final void Function(int) onTap;

  /// 칸이 많아도 한 줄에 같은 폭으로 (좁으면 글자를 줄인다)
  final bool oneRow;
  @override
  Widget build(BuildContext context) {
    Widget seg0(int k) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(k),
          child: Container(
            height: oneRow ? 38 : 40,
            alignment: Alignment.center,
            padding: oneRow ? const EdgeInsets.symmetric(horizontal: 3) : null,
            decoration: BoxDecoration(color: k == on ? Ttc.surface : Colors.transparent, borderRadius: BorderRadius.circular(6)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(items[k], style: Ttc.t(13, color: k == on ? const Color(0xFF22323B) : Ttc.segText, weight: FontWeight.w600)),
                if (k < dots.length && dots[k])
                  Container(width: oneRow ? 7 : 8, height: oneRow ? 7 : 8, margin: EdgeInsets.only(left: oneRow ? 4 : 5), decoration: const BoxDecoration(shape: BoxShape.circle, color: Ttc.amber)),
              ]),
            ),
          ),
        );
    Widget seg(int k) => k < hlKeys.length ? hl(hlKeys[k], seg0(k), radius: 6) : seg0(k);
    // 웹 .segs: 5칸이면 3칸씩 두 줄 (oneRow면 한 줄)
    final cols = oneRow ? items.length : (items.length >= 5 ? 3 : items.length);
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

/// 위 탭(Segs) 아래의 작은 둘째 칸 (앱 전용 2026-10-20: 일지 '기록'의 이야기·회상, '도감'의 도감·업적·노선도)
class SubTabs extends StatelessWidget {
  const SubTabs({super.key, required this.items, required this.on, required this.onTap, this.dots = const []});
  final List<String> items;
  final List<bool> dots;
  final int on;
  final void Function(int) onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (var k = 0; k < items.length; k++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(k),
              child: Container(
                constraints: const BoxConstraints(minHeight: 34),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: k == on ? Ttc.sepia : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: k == on ? Ttc.sepia : const Color(0x4026333B)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(items[k], style: Ttc.t(13, color: k == on ? const Color(0xFFF1E5C6) : Ttc.sepia, weight: FontWeight.w600, height: 1.2)),
                  if (k < dots.length && dots[k])
                    Container(width: 7, height: 7, margin: const EdgeInsets.only(left: 5), decoration: const BoxDecoration(shape: BoxShape.circle, color: Ttc.amber)),
                ]),
              ),
            ),
        ]),
      );
}

/// 웹 .sumchips 한 칸
Widget sumChip(List<InlineSpan> spans, {String? icon, bool bad = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[ResIcon(icon, size: 17), const SizedBox(width: 3)],
        Text.rich(TextSpan(children: spans), style: Ttc.t(12, color: bad ? Ttc.no : Ttc.sumText, weight: FontWeight.w500)),
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
        Text(d, textAlign: TextAlign.center, style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
      ]),
    );

/// 모자란 첫 자재를 '철판 42 더 필요'처럼 (좁은 버튼은 두 줄로). 다 있으면 null
String? lackText(Game g, Cost c, {bool short = false}) {
  for (final e in c.entries) {
    final have = g.have(e.key);
    if (have < e.value) {
      final n = '${matOf[e.key]?.n ?? e.key} ${fmt((e.value - have).ceil())}';
      return short ? '$n\n더 필요' : '$n 더 필요';
    }
  }
  return null;
}

/// 다친 사람이 다 낫기까지 남은 시간 ('3분' · '40초'). 안 다쳤으면 null
String? hurtLeft(Game g, int id) {
  final r = g.rec(id);
  final hurt = (r?['hurt'] as num?) ?? 0;
  if (r == null || hurt <= 0) return null;
  final rate = g.heal * (r['slow'] == 1 ? .5 : 1);
  final sec = rate <= 0 ? hurt : hurt / rate;
  return sec >= 60 ? '${(sec / 60).ceil()}분' : '${math.max(1, sec.ceil())}초';
}
