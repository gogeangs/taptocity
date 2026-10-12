// 끊긴 노선 화면 (웹 lnCard·lnPrepRender·lnRender 3518–3610)
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'gear.dart';
import 'portrait.dart';
import 'survivors.dart';
import 'theme.dart';
import 'underground_ui.dart';
import 'widgets.dart';

/// 원정 화면의 노선 카드 (웹 lnCard)
Widget lnCardWidget(BuildContext context, Game g) {
  if (!g.lnOpen) return const SizedBox.shrink();
  final T = g.lnTown, L = g.lnState(), m = g.lnMult, w = (g.lnNextRec / 60000).ceil();
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Ttc.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Text('끊긴 노선 · ${T.n}', style: Ttc.t(16, color: Ttc.sepia, weight: FontWeight.w700, height: 1.35))),
        Text('최고 ${L['best'] ?? 0}/12 · ${L['runs'] ?? 0}번', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w500)),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
        child: Row(children: [
          for (var k = 0; k < T.items.length; k++) ...[
            if (k > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(color: g.lnSeen(T.items[k]) ? const Color(0x29D9A34E) : const Color(0x0F3B2A1A), borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  g.lnSeen(T.items[k])
                      ? GearIcon(T.items[k], size: 22)
                      : Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x1F3B2A1A)),
                          child: Text('?', style: Ttc.t(15, color: const Color(0x733B2A1A), weight: FontWeight.w700)),
                        ),
                  const SizedBox(height: 4),
                  Text(g.lnSeen(T.items[k]) ? gear[T.items[k]]?.n ?? '' : '???',
                      textAlign: TextAlign.center, style: Ttc.t(11, color: g.lnSeen(T.items[k]) ? Ttc.sepia : Ttc.sepia2, weight: FontWeight.w600, height: 1.25)),
                ]),
              ),
            ),
          ],
        ]),
      ),
      Text.rich(
          TextSpan(children: [
            TextSpan(text: '지하철역 안쪽 터널. 갈림길마다 길을 골라 ${T.st[2]}까지 가요. 이 노선에서만 나오는 물건이 있어요.\n'),
            m < 1 ? bold('지금 보상 ×$m') : const TextSpan(text: '지금 보상 온전'),
            if (m < 1) TextSpan(text: ' · $w분 뒤 한 단계 회복'),
          ]),
          style: Ttc.t(13, color: Ttc.sepia2, height: 1.6)),
      const SizedBox(height: 8),
      Row(children: [BuyButton('노선 들어가기', width: 104, onTap: g.S.sv.isEmpty ? null : () => showLnPrep(context, g))]),
    ]),
  );
}

List<int> _lnTeam = [];

Future<void> showLnPrep(BuildContext context, Game g) async {
  if (!g.lnOpen) return;
  if (g.defn != null || g.ug != null) {
    g.fx.add(const FxToast('지금은 들어갈 수 없어요'));
    return;
  }
  _lnTeam = _lnTeam.where(g.lnFree.contains).toList();
  final navCtx = Navigator.of(context).context;
  var go = false;
  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xC70F161D),
    builder: (ctx) => Dialog(
      backgroundColor: Ttc.paper,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x66EEE5D3))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: StatefulBuilder(builder: (ctx, set) {
          final free = g.lnFree, t = _lnTeam, T = g.lnTown, m = g.lnMult, c = g.lnCost(t.length), pk = g.lnPerks(t);
          final (rp, why) = g.lnRecommend(free);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text('끊긴 노선 · ${T.n}', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
              Padding(padding: const EdgeInsets.fromLTRB(0, 4, 0, 8), child: Text('누구와 갈까요?', style: Ttc.t(20, color: Ttc.sepia, weight: FontWeight.w700))),
              if (free.length > 2)
                MCard(
                  thumb: const SizedBox(width: 0),
                  title: '추천 두 명',
                  desc: descText('소방·정찰을 먼저, 그다음 연구·요리 역할 · 같으면 등급 순'),
                  button: BuyButton('추천으로 고르기', width: 112, onTap: () => set(() => _lnTeam = [...rp])),
                ),
              if (free.isEmpty)
                descText('쉬는 생존자가 없어요')
              else
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final id in free)
                    ugMem(g, id,
                        on: t.contains(id),
                        rec: rp.contains(id),
                        why: rp.contains(id) ? why[id] : null,
                        onTap: !t.contains(id) && t.length >= 2
                            ? null
                            : () => set(() {
                                  if (t.contains(id)) {
                                    t.remove(id);
                                  } else {
                                    t.add(id);
                                  }
                                })),
                ]),
              if (pk.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: const Color(0xFFE5DDCC), borderRadius: BorderRadius.circular(7)),
                  child: Text(pk.join('\n'), style: Ttc.t(12.5, color: Ttc.sepia, height: 1.55)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
                  for (var k = 0; k < T.st.length; k++) ...[
                    if (k > 0) Text('—', style: Ttc.t(12, color: const Color(0x593B2A1A))),
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2C333B)),
                      child: Text('${k + 1}', style: Ttc.t(10.5, color: const Color(0xFFFFDF9E), weight: FontWeight.w700, height: 1)),
                    ),
                    Text(T.st[k], style: Ttc.t(12, color: Ttc.sepia, weight: FontWeight.w600)),
                  ],
                ]),
              ),
              Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: '체력 '),
                    bold('${g.lnHp0(t)}'),
                    const TextSpan(text: ' · 재 괴물에게 맞거나 무너진 선로를 지나면 줄어요. 0이 되면 챙긴 것의 절반만 들고 돌아와요.\n'),
                    TextSpan(text: '도시락 식량 ${c['food']} · 보상 '),
                    m < 1 ? bold('×$m') : const TextSpan(text: '온전'),
                    if (m < 1) const TextSpan(text: ' (연달아 들어가 줄었어요 · 15분마다 회복)'),
                    const TextSpan(text: ' · 최대 2명'),
                  ]),
                  style: Ttc.t(12.5, color: Ttc.sepia2, height: 1.55)),
              const SizedBox(height: 12),
              Row(children: [
                pageBtn('취소', () => Navigator.pop(ctx), alt: true),
                const SizedBox(width: 8),
                pageBtn('들어가기', t.isNotEmpty && g.canPay(c)
                    ? () {
                        go = g.lnStart(t);
                        Navigator.pop(ctx);
                      }
                    : null),
              ]),
              if (t.isEmpty || !g.canPay(c))
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(t.isEmpty ? '함께 갈 사람을 골라 주세요' : '식량이 모자라요', textAlign: TextAlign.center, style: Ttc.t(12, color: Ttc.no))),
            ]),
          );
        }),
      ),
    ),
  );
  if (go && navCtx.mounted) await showLnRun(navCtx, g);
}

Future<void> showLnRun(BuildContext context, Game g) => showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xC70F161D),
      builder: (ctx) => _LnPage(g),
    );

class _LnPage extends StatefulWidget {
  const _LnPage(this.g);
  final Game g;
  @override
  State<_LnPage> createState() => _LnPageState();
}

class _LnPageState extends State<_LnPage> with SingleTickerProviderStateMixin {
  Game get g => widget.g;
  late final Ticker _t = createTicker((_) {
    if (g.ln?.phase == 'fight') {
      g.lnTickFight();
      setState(() {});
    }
  });

  @override
  void initState() {
    super.initState();
    g.addListener(_on);
    _t.start();
  }

  bool _closed = false;
  void _on() {
    if (!mounted || _closed) return;
    if (g.ln == null) {
      _closed = true;
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    g.removeListener(_on);
    _t.dispose();
    super.dispose();
  }

  Widget _track(LnRun L, LnTownInfo T) {
    final kids = <Widget>[];
    for (var k = 1; k <= 12; k++) {
      final st = k % 4 == 0, si = k ~/ 4 - 1;
      if (st) {
        final on = L.step >= si * 3 + 3;
        kids.add(Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: on ? const Color(0xFF2C333B) : const Color(0xFFD8CCB1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFBF4E4), width: 2),
              boxShadow: [BoxShadow(color: on ? const Color(0xFFC9A24A) : const Color(0x403B2A1A), spreadRadius: 1.5)],
            ),
          ),
          const SizedBox(height: 2),
          Text(T.st[si], style: Ttc.t(9.5, color: Ttc.sepia2, weight: FontWeight.w600, height: 1)),
        ]));
      } else {
        final on = L.step >= k - k ~/ 4;
        kids.add(Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Stack(alignment: Alignment.center, children: [
              Container(height: 4, color: on ? const Color(0xFFC9A24A) : const Color(0x263B2A1A)),
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? const Color(0xFFC9A24A) : const Color(0xFFD8CCB1))),
            ]),
          ),
        ));
      }
    }
    return Padding(padding: const EdgeInsets.fromLTRB(4, 2, 4, 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: kids));
  }

  Widget _card(int k, LnCard c) {
    const bg = {'foe': Color(0xFF4A2A24), 'loot': Color(0xFF3A3422), 'rest': Color(0xFF25383A), 'trace': Color(0xFF33304A), 'hazard': Color(0xFF3D3328)};
    const ic = {'loot': 'loot', 'foe': 'foe', 'hazard': 'hazard', 'trace': 'diary', 'rest': 'rest'};
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          g.lnPick(k);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          decoration: BoxDecoration(
            color: c.hid ? const Color(0xFF181B20) : bg[c.c] ?? const Color(0xFF2C333B),
            borderRadius: BorderRadius.circular(12),
            border: c.hid ? Border.all(color: const Color(0x33EFE3C4), width: 1.5) : null,
          ),
          child: Column(children: [
            SizedBox(
                width: 52,
                height: 52,
                child: c.hid ? Center(child: Text('?', style: Ttc.t(30, color: const Color(0x66EFE3C4), weight: FontWeight.w700))) : ugIcon(ic[c.c] ?? 'loot')),
            const SizedBox(height: 4),
            Text(c.hid ? '어두운 터널' : lnCardName[c.c]!.$1, textAlign: TextAlign.center, style: Ttc.t(13.5, color: const Color(0xFFEFE3C4), weight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 2),
            Text(c.hid ? '안이 보이지 않아요' : lnCardName[c.c]!.$2, textAlign: TextAlign.center, style: Ttc.t(11.5, color: const Color(0xFFC4B5A0), height: 1.35)),
          ]),
        ),
      ),
    );
  }

  Widget _btn(String t, String? small, VoidCallback onTap, {bool alt = false}) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: alt ? Colors.transparent : Ttc.amber,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: alt ? const Color(0x47252E36) : const Color(0x73252E36)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(t, style: Ttc.t(13.5, color: const Color(0xFF252E36), weight: FontWeight.w700)),
              if (small != null) Text(small, style: Ttc.t(11.5, color: const Color(0xCC252E36))),
            ]),
          ),
        ),
      );

  Widget _arena(LnRun L) {
    final F = L.fight!, r = g.lnRing(), now = DateTime.now().microsecondsSinceEpoch / 1000;
    final near = (r - lnTgt).abs() <= 13 && now >= F.t0;
    final hurt = DateTime.now().millisecondsSinceEpoch - L.hurtAt < 300;
    final sz = math.min(240.0, MediaQuery.of(context).size.width * .7);
    return Column(children: [
      Listener(
        onPointerDown: (_) {
          HapticFeedback.lightImpact();
          g.lnStrike();
        },
        child: Transform.translate(
          offset: Offset(hurt ? math.sin(now / 18) * 5 : 0, 0),
          child: Container(
            width: sz,
            height: sz,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFF3A2A24), Color(0xFF1C1714)], stops: [0, .7])),
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(size: Size(sz, sz), painter: _RingPainter(r, near)),
              SizedBox(width: F.boss ? 72 : 54, height: F.boss ? 72 : 54, child: ugIcon('foe')),
              Positioned(
                top: sz * .12,
                child: Row(children: [
                  for (var k = 0; k < F.max; k++)
                    Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(color: k < F.hp ? const Color(0xFFE0614A) : const Color(0x33EFE3C4), borderRadius: BorderRadius.circular(2))),
                ]),
              ),
              Positioned(bottom: sz * .11, child: Text(F.res, style: Ttc.t(13, color: const Color(0xFFFFD36B), weight: FontWeight.w700))),
            ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('${F.boss ? lnTowns[L.reg]!.boss : '재 괴물'} · 고리가 금빛 테두리에 겹칠 때 아무 데나 두드려요', textAlign: TextAlign.center, style: Ttc.t(12.5, color: Ttc.sepia2, height: 1.5)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final L = g.ln;
    if (L == null) return const SizedBox.shrink();
    final T = lnTowns[L.reg]!;
    Widget body;
    switch (L.phase) {
      case 'pick':
        body = Row(children: [
          for (var k = 0; k < L.cards.length; k++) ...[if (k > 0) const SizedBox(width: 8), _card(k, L.cards[k])],
        ]);
      case 'hazard':
        body = Column(children: [
          Row(children: [_btn('기어서 지나가기', '체력 -${g.lnHazardDmg} · 고철', () => g.lnHazard(true))]),
          const SizedBox(height: 8),
          Row(children: [_btn('먼 길로 돌아가기', '체력 -1', () => g.lnHazard(false), alt: true)]),
        ]);
      case 'fight':
        body = _arena(L);
      case 'station':
        body = Row(children: [_btn('여기서 올라가기', null, () => g.lnEnd(true), alt: true), const SizedBox(width: 8), _btn('다음 구간으로', null, g.lnGoOn)]);
      default:
        body = Row(children: [_btn('가진 걸 들고 올라가기', null, () => g.lnEnd(true))]);
    }
    final carry = [
      for (final e in L.carry.entries)
        if (e.value > 0) Row(mainAxisSize: MainAxisSize.min, children: [ResIcon(e.key, size: 14), Text(' ${e.value}', style: Ttc.t(12.5, color: Ttc.sepia, weight: FontWeight.w700))]),
      for (final t in L.items) Row(mainAxisSize: MainAxisSize.min, children: [GearIcon(t, size: 18), Text(' ${gear[t]?.n ?? t}', style: Ttc.t(12, color: Ttc.sepia, weight: FontWeight.w600))]),
    ];
    return Dialog(
      backgroundColor: Ttc.paper,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x66EEE5D3))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text('끊긴 노선 · ${T.n}', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            _track(L, T),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
              child: Row(children: [
                for (final id in L.team)
                  Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE6D8B6)),
                    clipBehavior: Clip.antiAlias,
                    child: Portrait(id, width: 30, height: 35),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(color: const Color(0x1F3B2A1A), borderRadius: BorderRadius.circular(99)),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(children: [
                      FractionallySizedBox(
                        widthFactor: (math.max(0, L.hp) / L.max).clamp(0, 1).toDouble(),
                        child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), gradient: const LinearGradient(colors: [Color(0xFFB0452A), Color(0xFFD9743A)]))),
                      ),
                      Center(child: Text('체력 ${math.max(0, L.hp)}/${L.max}', style: Ttc.t(11.5, color: const Color(0xFF30281F), weight: FontWeight.w700, height: 1))),
                    ]),
                  ),
                ),
              ]),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(L.msg, style: Ttc.t(14, color: Ttc.sepia, height: 1.55))),
            ),
            body,
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x333B2A1A)))),
              child: carry.isEmpty ? Text('아직 챙긴 게 없어요', style: Ttc.t(12, color: Ttc.sepia2)) : Wrap(spacing: 10, runSpacing: 6, children: carry),
            ),
            if (L.phase == 'pick' || L.phase == 'hazard') ...[
              const SizedBox(height: 10),
              Row(children: [_btn('지금 돌아가기', L.step > 0 ? '챙긴 건 그대로' : '보상 없음', () => g.lnEnd(true), alt: true)]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.r, this.near);
  final double r;
  final bool near;
  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 240, o = Offset(s.width / 2, s.height / 2);
    // 금빛 점선 테두리 (r=46)
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * k
      ..color = const Color(0xE6E0B441);
    const n = 36;
    for (var q = 0; q < n; q++) {
      final a0 = q * 2 * math.pi / n, a1 = a0 + math.pi / n;
      c.drawArc(Rect.fromCircle(center: o, radius: lnTgt * k), a0, a1 - a0, false, gold);
    }
    c.drawCircle(
        o,
        math.max(.1, r) * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * k
          ..color = near ? const Color(0xFFFFD36B) : const Color(0xFFEFE3C4));
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.r != r || o.near != near;
}
