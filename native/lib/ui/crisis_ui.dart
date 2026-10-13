// 3단계 화면: 시계, 생존자의 부탁 버튼·창, 생존자 의뢰 띠, 대형 재폭풍 막대.
// 웹 #clock · #evBtn · .page.req · #sq · #defBar 의 마지막 스타일(design.css·qa.css)을 따랐다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/web_data.g.dart' as web;
import '../game/data.dart';
import '../game/engine.dart';
import 'portrait.dart';
import 'survivors.dart';
import 'theme.dart';
import 'widgets.dart';

/// 1초마다 다시 그리는 감싸개 (시계·남은 시간)
class Every extends StatefulWidget {
  const Every({super.key, required this.g, required this.builder, this.ms = 1000});
  final Game g;
  final WidgetBuilder builder;
  final int ms;
  @override
  State<Every> createState() => _EveryState();
}

class _EveryState extends State<Every> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(Duration(milliseconds: widget.ms), (_) => setState(() {}));
    widget.g.addListener(_on);
  }

  void _on() => setState(() {});
  @override
  void dispose() {
    _t?.cancel();
    widget.g.removeListener(_on);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

// ======================= 시계 (웹 renderClock) =======================
Widget clockChip(Game g) {
  final big = (g.bigNightNext && !g.isNight) || g.defn != null;
  final night = g.isNight;
  final b = g.S.buff;
  final buffOn = b != null && ((b['t'] as num?) ?? 0) > 0;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xF2202932),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: big ? const Color(0xFFAB5145) : const Color(0x2EEEE5D3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 13,
        height: 13,
        decoration: night
            ? const BoxDecoration(shape: BoxShape.circle)
            : const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(center: Alignment(-.2, -.2), colors: [Color(0xFFFFE7A0), Color(0xFFF3A53A)]),
                boxShadow: [BoxShadow(color: Color(0xCCF3A53A), blurRadius: 8)],
              ),
        child: night ? CustomPaint(painter: _Moon()) : null,
      ),
      const SizedBox(width: 7),
      Flexible(child: Text(g.clockText, overflow: TextOverflow.ellipsis, style: Ttc.t(11, color: big ? const Color(0xFFF4C1B6) : const Color(0xFFE8E4D9), weight: FontWeight.w500))),
      if (buffOn) ...[
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: const Color(0x38F3A53A), borderRadius: BorderRadius.circular(99)),
          child: Text('✦ ${b['label']} ${((b['t'] as num?) ?? 0).ceil()}초', style: Ttc.t(11, color: const Color(0xFFFFD98A), weight: FontWeight.w700, height: 1.2)),
        ),
      ],
    ]),
  );
}

class _Moon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2, c = Offset(r, r);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    // 안쪽 그림자 inset -5px -2px 0 0 #efe3c4 → 오른쪽 아래 초승달
    canvas.drawPath(
        Path.combine(PathOperation.difference, Path()..addOval(Rect.fromCircle(center: c, radius: r)), Path()..addOval(Rect.fromCircle(center: c.translate(-5, -2), radius: r))),
        Paint()..color = const Color(0xFFEFE3C4));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Moon old) => false;
}

// ======================= 생존자의 부탁 버튼 (웹 renderEvBtn) =======================
Widget eventButton(Game g, VoidCallback onTap) {
  final ev = g.evCur;
  if (ev < 0) return const SizedBox.shrink();
  final who = g.evWho(ev), e = web.events[ev], p = (g.evLeft / evTotal).clamp(0.0, 1.0).toDouble();
  return GestureDetector(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
      decoration: BoxDecoration(
        color: Ttc.paper,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: g.evLeft < 20 ? Ttc.no : Ttc.rust, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 14, offset: Offset(0, 5))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CustomPaint(
            painter: _Ring(p),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: Container(
                  color: const Color(0xFFE6D8B6),
                  // 이름 없는 손님은 손그림 초상 (웹 guestAv, guests.webp)
                  child: who != null ? Portrait(who, width: 34, height: 40) : guestFace(e['t'] as String, size: 34),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${who != null ? survivors[who].name : '손님'}의 부탁', style: Ttc.t(11, color: Ttc.rust, weight: FontWeight.w600, height: 1.1)),
            const SizedBox(height: 1),
            Text(e['t'] as String, overflow: TextOverflow.ellipsis, style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700, height: 1.2)),
          ]),
        ),
      ]),
    ),
  );
}

class _Ring extends CustomPainter {
  _Ring(this.p);
  final double p;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawCircle(r.center, size.width / 2, Paint()..color = const Color(0x263B2A1A));
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * p, true, Paint()..color = Ttc.rust);
  }

  @override
  bool shouldRepaint(_Ring old) => old.p != p;
}

Widget _fxChip((String, String?, bool) x, {bool big = false}) => Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 10 : 8, vertical: big ? 6 : 5),
      decoration: BoxDecoration(color: x.$3 ? const Color(0x1FB0452A) : const Color(0x246F9646), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (x.$2 != null) ...[ResIcon(x.$2!, size: 13), const SizedBox(width: 3)],
        Text(x.$1, style: Ttc.t(big ? 13 : 12, color: x.$3 ? Ttc.no : Ttc.ok, weight: FontWeight.w600, height: 1)),
      ]),
    );

Widget _reqHead(Game g, int ev, String tag) {
  final who = g.evWho(ev);
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE6D8B6), border: Border.all(color: const Color(0x403B2A1A), width: 2)),
        clipBehavior: Clip.antiAlias,
        child: who != null ? Portrait(who, width: 58, height: 68) : Center(child: guestFace(web.events[ev]['t'] as String, size: 54)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tag, style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(web.events[ev]['t'] as String, style: Ttc.t(19, color: Ttc.sepia, weight: FontWeight.w700, height: 1.25)),
        ]),
      ),
    ]),
  );
}

/// 부탁 창 (웹 openReq)
void showRequestPage(BuildContext context, Game g) {
  final ev = g.evCur;
  if (ev < 0) return;
  final who = g.evWho(ev), e = web.events[ev];
  final x = e['x'] as String, m = RegExp(r'^([^:：]+)[:：]\s*(.*)$').firstMatch(x);
  final say = m != null ? '“${m.group(2)!.replaceAll(RegExp(r'^“|”$'), '')}”' : x;
  showPageOf(context, g, (ctx) => Every(
      g: g,
      builder: (c) {
        if (g.evCur != ev) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          });
          return const SizedBox(height: 60);
        }
        final p = (g.evLeft / evTotal).clamp(0.0, 1.0).toDouble();
        Widget opt(int k) {
          final o = g.evOpt(ev, k), c0 = g.evCost(ev, k), ok = g.canPay(c0);
          return GestureDetector(
            onTap: ok
                ? () {
                    Navigator.pop(ctx);
                    g.chooseEv(k);
                  }
                : null,
            child: Opacity(
              opacity: ok ? 1 : .6,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: !ok ? const Color(0xFFEFE9DC) : k == 0 ? const Color(0xFFFFF8EA) : const Color(0xFFF8F3E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: k == 0 ? const Color(0xFFB0452A) : const Color(0x2926333B), width: 1.5),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o['l'] as String, style: Ttc.t(16, color: Ttc.sepia, weight: FontWeight.w700, height: 1.3)),
                  const SizedBox(height: 7),
                  if (c0.isEmpty)
                    Text('비용 없음', style: Ttc.t(12, color: const Color(0xFF56646A)))
                  else
                    Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      if (!ok) Text('자재 부족 ', style: Ttc.t(12, color: Ttc.no, weight: FontWeight.w700)),
                      costWrap(g, c0),
                    ]),
                  const SizedBox(height: 7),
                  Wrap(spacing: 5, runSpacing: 5, children: [for (final x in g.evFxList(ev, k)) _fxChip(x)]),
                ]),
              ),
            ),
          );
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _reqHead(g, ev, '${who != null ? survivors[who].name : '손님'}의 부탁'),
          Container(
            height: 22,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: const Color(0x1A3B2A1A), borderRadius: BorderRadius.circular(99)),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              FractionallySizedBox(
                widthFactor: p,
                child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFE8B25A), Color(0xFFF3A53A)]))),
              ),
              Center(child: Text('${g.evLeft.ceil()}초 남음', style: Ttc.t(12, color: Ttc.sepia, weight: FontWeight.w600, height: 1))),
            ]),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x59FFFFFF),
              borderRadius: BorderRadius.circular(4),
              border: const Border(left: BorderSide(color: Ttc.rust, width: 3)),
            ),
            child: Text(say, style: Ttc.t(15.5, color: const Color(0xFF4A3320), height: 1.6)),
          ),
          opt(0),
          opt(1),
        ]);
      }));
}

/// 부탁을 들어준 뒤 (웹 chooseEv 끝)
void showRequestDone(BuildContext context, Game g, int ev, int k, List<(String, String?, bool)> sum) {
  showPageOf(context, g, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _reqHead(g, ev, '부탁을 들어줬어요'),
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x59FFFFFF),
            borderRadius: BorderRadius.circular(4),
            border: const Border(left: BorderSide(color: Ttc.rust, width: 3)),
          ),
          child: Text(g.evOpt(ev, k)['r'] as String, style: Ttc.t(15.5, color: const Color(0xFF4A3320), height: 1.6)),
        ),
        Wrap(spacing: 5, runSpacing: 5, children: [for (final x in sum) _fxChip(x, big: true)]),
        const SizedBox(height: 14),
        Row(children: [pageBtn('좋아요', () => Navigator.pop(ctx))]),
      ]));
}

// ======================= 생존자 의뢰 (웹 renderSq) =======================
Widget sideQuest(Game g, {required VoidCallback onTap}) {
  final q = g.sq;
  if (q == null || !g.sqOn) return const SizedBox.shrink();
  final t0 = sqTypes[q['k']];
  if (t0 == null) return const SizedBox.shrink();
  final n = ((q['n'] as num?) ?? 1).toInt(), p = g.sqProg(), done = p >= n;
  final who = (q['who'] as num?)?.toInt() ?? -1, hasWho = g.hasSv(who);
  final mini = DateTime.now().millisecondsSinceEpoch >= g.sqOpenUntil && !done;
  final bar = Container(
    width: mini ? 46 : 64,
    height: 18,
    decoration: BoxDecoration(color: const Color(0x1F3B2A1A), borderRadius: BorderRadius.circular(99)),
    clipBehavior: Clip.antiAlias,
    child: Stack(children: [
      FractionallySizedBox(
        widthFactor: (p / n).clamp(0.0, 1.0).toDouble(),
        child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFC9A24A), Color(0xFFF3A53A)]))),
      ),
      Center(child: Text('${fmt(p)}/${fmt(n)}', style: Ttc.t(11, color: Ttc.sepia, weight: FontWeight.w600, height: 1))),
    ]),
  );
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.fromLTRB(4, 4, mini ? 8 : 10, 4),
      decoration: BoxDecoration(
        color: const Color(0xF5F1E5C6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: done ? Ttc.rust : const Color(0x403B2A1A), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: mini ? 30 : 32,
          height: mini ? 30 : 32,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE6D8B6)),
          clipBehavior: Clip.antiAlias,
          child: hasWho ? Portrait(who, width: 32, height: 38) : null,
        ),
        SizedBox(width: mini ? 6 : 8),
        if (!mini) ...[
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: '${hasWho ? survivors[who].name : '쉘터'}의 의뢰 '),
                TextSpan(text: '${g.num_('sqN').toInt() % 3 + 1}/3', style: const TextStyle(color: Ttc.sepia2, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)])),
              ]), style: Ttc.t(11.5, color: Ttc.rust, weight: FontWeight.w600, height: 1.1)),
              const SizedBox(height: 1),
              Text(t0.t(n), maxLines: 2, overflow: TextOverflow.ellipsis, style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700, height: 1.25)),
            ]),
          ),
          const SizedBox(width: 8),
        ],
        if (done)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: Ttc.rust, borderRadius: BorderRadius.circular(99)),
            child: Text('받기', style: Ttc.t(13, color: Colors.white, weight: FontWeight.w700, height: 1)),
          )
        else
          bar,
      ]),
    ),
  );
}

// ======================= 대형 재폭풍 막대 (웹 renderDefBar) =======================
Widget defenseBar(Game g) {
  final D2 = g.defn;
  if (D2 == null) return const SizedBox.shrink();
  final left = math.max(0, (D2.dur - D2.t).ceil()), danger = D2.hp < 30;
  final alive = D2.foes.where((f) => !f.dead && f.delay <= 0).length;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: danger ? const Color(0xFF433438) : const Color(0xFF26313B),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: danger ? const Color(0xFFE08E77) : const Color(0xFFAB5145)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: Text('대형 재폭풍 · ${D2.wave}/3번째 무리', style: Ttc.t(11, color: const Color(0xFFEFB6A8), weight: FontWeight.w700))),
        Text('$left초', style: Ttc.t(11, color: const Color(0xFFF4D19A))),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (var n = 1; n <= 3; n++) ...[
          if (n > 1) const SizedBox(width: 4),
          Expanded(child: Container(height: 3, decoration: BoxDecoration(color: D2.wave >= n ? const Color(0xFFE0B66C) : const Color(0xFF56616A), borderRadius: BorderRadius.circular(2)))),
        ],
      ]),
      const SizedBox(height: 6),
      Container(
        height: 20,
        decoration: BoxDecoration(color: const Color(0xFF3B4147), borderRadius: BorderRadius.circular(5)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          FractionallySizedBox(widthFactor: (D2.hp / 100).clamp(0.0, 1.0).toDouble(), child: Container(color: const Color(0xFFAB5145))),
          Center(child: Text('쉘터 내구도 ${math.max(0, D2.hp.round())}', style: Ttc.t(12, color: const Color(0xFFFFF4DF), weight: FontWeight.w700, height: 1))),
        ]),
      ),
      const SizedBox(height: 5),
      Text('${danger ? '쉘터 위험 · ' : ''}남은 괴물 $alive${D2.wave < 3 ? ' · 다음 무리까지 ${math.max(0, (D2.wave * 24 - D2.t).ceil())}초' : ''}',
          style: Ttc.t(11, color: const Color(0xFFE6D5C5))),
    ]),
  );
}
