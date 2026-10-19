// 6단계 화면: 이주(함께 갈 사람 고르기), 동네 선택·공장 작전, 잃은 사람 장면, 만수의 노선도, 무전 거래·교대, 잃은 사람들.
// 웹 index.html 3230–3248(거래·교대), 4244–4292(이주), 5326–5352(노선도), 5380–5410(작전·선택), 6033–6050(잃은 사람).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/web_data.g.dart' as web;
import '../game/data.dart';
import '../game/engine.dart';
import 'portrait.dart';
import 'season_ui.dart';
import 'story_ui.dart';
import 'survivors.dart';
import 'sound.dart';
import 'theme.dart';
import 'widgets.dart';

Widget _tag(String t) => Text(t, style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600));
Widget _h3(String t) => Padding(padding: const EdgeInsets.only(top: 4, bottom: 6), child: Text(t, style: Ttc.t(20, color: Ttc.sepia, weight: FontWeight.w700, height: 1.3)));
Widget _p(String t) => Text(t, style: Ttc.t(14, color: const Color(0xFF4A3320), height: 1.7));
Widget _d(String t) => Text(t, style: Ttc.t(13, color: Ttc.sepia2, height: 1.55));
Widget _sec2(String t, [String? small]) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: t),
        if (small != null) TextSpan(text: '  $small', style: Ttc.t(11.5, color: Ttc.sepia2, weight: FontWeight.w500)),
      ]), style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
    );
Widget _fx(String t) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFE5DDCC), borderRadius: BorderRadius.circular(7)),
      child: Text(t, style: Ttc.t(13, color: const Color(0xFF5A3F24), height: 1.6)),
    );

Widget _round(int id, double s, {Color border = const Color(0x4D3B2A1A)}) => Container(
      width: s,
      height: s,
      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE6D8B6), border: Border.all(color: border, width: 2)),
      clipBehavior: Clip.antiAlias,
      child: Portrait(id, width: s, height: s * 1.17),
    );

/// 웹 .migpick .mpk: 얼굴 + 이름 + 한 줄
Widget _mpk(int id, String small, {bool on = false, bool rec = false, String? em, VoidCallback? onTap}) {
  final s = survivors[id];
  final bg = on ? const Color(0xFF2F3F4B) : rec ? const Color(0xFFFDF6DF) : const Color(0xFFFBF7EE);
  final fg = on ? Colors.white : const Color(0xFF3B2A1A);
  return GestureDetector(
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null ? .55 : 1,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? (rec ? const Color(0xFFE0B441) : const Color(0xFF2F3F4B)) : rec ? const Color(0xFF8A5A12) : const Color(0x403B2A1A), width: 1.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _round(id, 44, border: on ? const Color(0xFFE0B441) : const Color(0x4D3B2A1A)),
            const SizedBox(height: 4),
            Text(s.name, style: Ttc.t(13, color: fg, weight: FontWeight.w700, height: 1.2)),
            Text(small, textAlign: TextAlign.center, style: Ttc.t(10.5, color: on ? const Color(0xFFD9D4C8) : Ttc.sepia2, height: 1.25)),
            if (em != null && em.isNotEmpty) Text(em, textAlign: TextAlign.center, style: Ttc.t(10.5, color: on ? const Color(0xFFF3D9A0) : const Color(0xFF8A5A12), weight: FontWeight.w500, height: 1.3)),
          ]),
        ),
        if (rec)
          Positioned(
            top: -7,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFE0B441), borderRadius: BorderRadius.circular(99)),
                child: Text('추천', style: Ttc.t(10, color: const Color(0xFF3B2A1A), weight: FontWeight.w700, height: 1)),
              ),
            ),
          ),
      ]),
    ),
  );
}

Widget _grid(List<Widget> kids) => LayoutBuilder(
      builder: (c, box) {
        final w = (box.maxWidth - 16) / 3;
        return Wrap(spacing: 8, runSpacing: 10, children: [for (final k in kids) SizedBox(width: w, child: k)]);
      },
    );

// ======================= 이주 =======================
/// 쉘터 '건설' 맨 위 띠 (웹 migrateHtml)
Widget? migrateBanner(Game g, VoidCallback onTap) {
  if (!g.canMigrate) return null;
  final nr = regions[g.nextRegion]!, n = g.S.gen + 1, nc = g.nextCaller;
  return hl('migrate', GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), gradient: const LinearGradient(colors: [Color(0xFF6B3A1A), Color(0xFFB0452A)])),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '(선택) ${nc != null ? '${nc.$1}의 신호를 따라 ' : ''}새 동네로 떠나기 →\n', style: Ttc.t(14, color: const Color(0xFFFFCF7A), weight: FontWeight.w700, height: 1.5)),
          TextSpan(text: '불씨를 들고 ${nr.n}에서 다시 시작해요 · 등불의 기억 $n단계 (생산·두드리기 +${n * 10}%)'),
        ]),
        style: Ttc.t(12.5, color: Ttc.paper, height: 1.45),
      ),
    ),
  ), radius: 6);
}

List<int>? _migPick;

Future<void> showMigrate(BuildContext context, Game g) {
  final ids = g.svIds.toList();
  if (_migPick == null || _migPick!.any((id) => !g.hasSv(id))) _migPick = ids.take(migMax).toList();
  return showPageOf(context, g, (ctx) => StatefulBuilder(builder: (ctx, set) {
        final region = g.nextRegion, nr = regions[region]!, n = g.S.gen + 1, all = g.svIds.toList(), many = all.length > migMax, nc = g.nextCaller;
        final sel = _migPick!;
        final (recPick, why) = g.migRecommend(region);
        final need = (web.regionMisc['migNeed'] as Map)[region] as Map? ?? const {};
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          _tag('이주 · $n번째 동네'),
          _h3(nr.n),
          _p('${nc != null ? '${nc.$2} ${nc.$1}의 신호를 따라, 불씨를 나누러 떠나요.' : '불씨를 들고 다음 동네로 떠나요.'} 이 동네의 불은 남는 사람들이 지켜요.'),
          _fx('${nr.d}\n구름이 조금 더 단단해요 (×${(1 + .2 * n).toStringAsFixed(1)})'),
          if (many) ...[
            _sec2('함께 갈 사람', '${sel.length}/$migMax'),
            _d('최대 $migMax명까지 데려가요. 남는 사람은 이 동네의 등불을 지키고, 나중에 무전으로 교대할 수 있어요.'),
            const SizedBox(height: 6),
            MCard(
              thumb: const SizedBox(width: 0),
              title: '추천 다섯 명',
              desc: descText('${need['why'] ?? ''} · 필요한 역할 한 명씩 + 등급·신뢰 순'),
              button: BuyButton('추천으로 고르기', width: 112, onTap: () {
                Sound.sfx('chime');
                set(() => _migPick = [...recPick]);
              }),
            ),
            _grid([
              for (final id in all)
                _mpk(id, '${grades[g.gradeOf(id)].n ?? ''} · ${survivors[id].job}', on: sel.contains(id), rec: recPick.contains(id), em: (why[id] ?? const []).join(' · '), onTap: () {
                  Sound.sfx('tap');
                  set(() {
                    if (sel.contains(id)) {
                      sel.remove(id);
                    } else if (sel.length < migMax) {
                      sel.add(id);
                    }
                  });
                }),
            ]),
          ],
          _sec2('함께 가는 것'),
          _d('생존자 ${many ? sel.length : all.length}명(등급·성급·신뢰·장비·이야기) · 장비 가방 · 유물 · 업적과 칭호 · 아이들과 등불 · 건전지 · 철판·밧줄·전선·약품 절반(새 창고에 들어가는 만큼)'),
          _sec2('처음부터 다시'),
          _d('지도 · 쉘터 단계 · 모듈 · 방벽 · 기본 자재 · 동맹'),
          _sec2('새로 얻는 것'),
          Text.rich(TextSpan(children: [bold('등불의 기억 $n단계'), TextSpan(text: ' · 모든 생산 +${n * 10}% · 두드리는 힘 +${n * 10}% (영구)\n함께 온 사람 수만큼 침상 추가')]),
              style: Ttc.t(13, color: Ttc.sepia2, height: 1.55)),
          const SizedBox(height: 14),
          Row(children: [
            pageBtn('조금 더 머물기', () => Navigator.pop(ctx), alt: true),
            const SizedBox(width: 8),
            pageBtn('떠나기', many && sel.isEmpty
                ? null
                : () {
                    Navigator.pop(ctx);
                    g.migrate(many ? [...sel] : all);
                    _migPick = null;
                  }),
          ]),
        ]);
      }));
}

/// 이주 직후 화면 가운데에 찍히는 도장 (웹 migrate의 stamp)
class MigStamp extends StatefulWidget {
  const MigStamp(this.g, this.region, {super.key, required this.onDone});
  final int g;
  final String region;
  final VoidCallback onDone;
  @override
  State<MigStamp> createState() => _MigStampState();
}

class _MigStampState extends State<MigStamp> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward().whenComplete(widget.onDone);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: c,
          builder: (ctx, _) {
            final t = c.value, a = t < .12 ? t / .12 : t > .8 ? (1 - t) / .2 : 1.0, s = t < .12 ? 1.6 - .6 * (t / .12) : 1.0;
            return Center(
              child: Opacity(
                opacity: a.clamp(0, 1).toDouble(),
                child: Transform.rotate(
                  angle: -.08,
                  child: Transform.scale(
                    scale: s,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xE63A2618), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFCF7A), width: 2.5)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${widget.g}번째 동네', style: Ttc.t(12, color: const Color(0xFFE9D9B8), weight: FontWeight.w600)),
                        Text(regions[widget.region]?.n ?? '', style: Ttc.t(22, color: const Color(0xFFFFCF7A), weight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}

// ======================= 동네 선택 (웹 openTownChoice) =======================
Widget _npcHead(String region) {
  final n = npcName[region];
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
    child: Row(children: [
      Container(
          width: 64,
          height: 74,
          decoration: BoxDecoration(color: const Color(0xFFE6D8B6), borderRadius: BorderRadius.circular(8), border: Border.all(color: Ttc.line)),
          clipBehavior: Clip.antiAlias,
          child: npcFace('npc:$region')),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n?.$1 ?? '', style: Ttc.t(18, color: Ttc.sepia, weight: FontWeight.w700)),
          Text(n?.$2 ?? '', style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
        ]),
      ),
    ]),
  );
}

Future<void> showTownChoice(BuildContext context, Game g) {
  final C = g.townChoice;
  if (C.isEmpty || g.rq['pick'] != null) return Future.value();
  g.townChoiceShown = g.S.gen;
  final region = g.S.region!;
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xC70F161D),
    builder: (ctx) {
      Widget opt(String x) {
        final o = C[x] as Map;
        return GestureDetector(
          onTap: () {
            Navigator.pop(ctx);
            final ls = g.pickTown(x);
            Future.delayed(const Duration(milliseconds: 250), () => g.talk(ls, tag: g.reg?.n));
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x47252E36))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o['n'] as String, style: Ttc.t(14.5, color: Ttc.sepia, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(g.choiceDesc(x), style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
            ]),
          ),
        );
      }

      return Dialog(
        backgroundColor: Ttc.paper,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x66EEE5D3))),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              _tag('${g.reg?.n ?? ''} · 선택'),
              _npcHead(region),
              Text(C['t'] as String, style: Ttc.t(16, color: Ttc.sepia, height: 1.85)),
              const SizedBox(height: 16),
              opt('a'),
              opt('b'),
            ]),
          ),
        ),
      );
    },
  );
}

// ======================= 공장 끄기 작전 (웹 openOp) =======================
const _opStep = ['정문을 뚫는 중', '재 배관을 막는 중', '마지막 스위치로 가는 중'];

Future<void> showOp(BuildContext context, Game g) {
  if (g.rq['op'] != null) return Future.value();
  Timer? tick;
  return showPageOf(context, g, (ctx) {
    return StatefulBuilder(builder: (ctx, set) {
      final Q = g.rq, now = DateTime.now().millisecondsSinceEpoch;
      final tot = ((Q['opDur'] as num?) ?? (g.opFast ? 50 : 100) * 1000).toDouble();
      final left = Q['opEnd'] == null ? 0 : math.max(0, (Q['opEnd'] as num) - now).toInt();
      final p = Q['opEnd'] == null ? 0.0 : math.min(1.0, 1 - left / tot);
      if (left > 0) {
        tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
          if (!ctx.mounted) {
            tick?.cancel();
            return;
          }
          if (g.rq['op'] != null || DateTime.now().millisecondsSinceEpoch >= ((g.rq['opEnd'] as num?) ?? 0)) {
            tick?.cancel();
            Navigator.pop(ctx);
            return;
          }
          set(() {});
        });
      }
      final c = g.opCost;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _tag('녹슨 공단 · 3공장'),
        _h3('공장 끄기 작전'),
        _p('재를 뿜으며 돌아가는 라인의 전원을 내려야 해요. 생존자들이 정문을 뚫고, 배관을 막고, 마지막 스위치를 내릴 거예요.'),
        const SizedBox(height: 8),
        if (left > 0) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFE5DDCC), borderRadius: BorderRadius.circular(7)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('${_opStep[math.min(2, (p * 3).floor())]}…', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700))),
                Text('${(left / 1000).ceil()}초', style: Ttc.t(13, color: Ttc.sepia)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: p, minHeight: 8, backgroundColor: const Color(0x263B2A1A), valueColor: const AlwaysStoppedAnimation(Color(0xFFC98A3A))),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Text.rich(TextSpan(children: [const TextSpan(text: '생존자들이 작전을 하고 있어요. '), bold('따로 할 일은 없어요'), const TextSpan(text: ' — 시간이 지나면 저절로 끝나고, 이야기 띠에서 보상을 받아요. 창을 닫고 다른 일을 해도 돼요.')]),
              style: Ttc.t(13, color: Ttc.sepia2, height: 1.55)),
        ] else ...[
          Text.rich(TextSpan(children: [bold('할 일:'), const TextSpan(text: ' 아래 자재를 보내 작전을 시작하세요. 그다음은 기다리기만 하면 돼요.')]), style: Ttc.t(13, color: Ttc.sepia2, height: 1.55)),
          const SizedBox(height: 6),
          needList(g, c),
          const SizedBox(height: 6),
          _d('걸리는 시간 ${g.opFast ? '50초 (도진·재혁이 길을 알아요)' : '100초'}'),
        ],
        const SizedBox(height: 12),
        Row(children: [
          pageBtn(left > 0 ? '닫기' : '돌아가기', () {
            tick?.cancel();
            Navigator.pop(ctx);
          }, alt: true),
          if (left <= 0) ...[
            const SizedBox(width: 8),
            pageBtn('자재 보내고 작전 시작', g.canPay(c)
                ? () {
                    if (g.startOp()) {
                      Navigator.pop(ctx);
                      g.fx.add(const FxToast('작전 시작! 기다리면 저절로 끝나요 · 남은 시간은 이야기 띠에'));
                    }
                  }
                : null),
          ],
        ]),
      ]);
    });
  });
}

// ======================= 잃은 사람 (웹 deathScene 6033) =======================
Future<void> showDeath(BuildContext context, Game g, FxDeath d) {
  Sound.buzzHeavy();
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 1200),
    pageBuilder: (ctx, a1, a2) => _DeathPage(g, d, onDone: () {
      Navigator.pop(ctx);
      Future.delayed(const Duration(milliseconds: 200), () => g.talk(g.deathLines(d), tag: '${g.reg != null ? '${g.reg!.n} · ' : ''}잃은 사람'));
    }),
    transitionBuilder: (ctx, a, b, child) => FadeTransition(opacity: a, child: child),
  );
}

class _DeathPage extends StatefulWidget {
  const _DeathPage(this.g, this.d, {required this.onDone});
  final Game g;
  final FxDeath d;
  final VoidCallback onDone;
  @override
  State<_DeathPage> createState() => _DeathPageState();
}

class _DeathPageState extends State<_DeathPage> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 6600))..forward();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  // CSS: dIn(t0, dur) → 0..1
  double _in(double t, double at, double dur) => ((t - at) / dur).clamp(0, 1).toDouble();

  @override
  Widget build(BuildContext context) => PopScope(canPop: false, child: _page(context));

  Widget _page(BuildContext context) {
    final g = widget.g, d = widget.d, s = survivors[d.id];
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.2), radius: 1.1, colors: [Color(0xF7181518), Color(0xFE050406)])),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: c,
          builder: (ctx, _) {
            final t = c.value * 6.6;
            final ready = t >= 5.4;
            // 불꽃: 3.4초에 꺼지고 5.2초에 다시 켜진다
            final fl = t < 3.4 ? 1.0 : t < 4.5 ? 1 - (t - 3.4) / 1.1 : t < 5.2 ? 0.0 : _in(t, 5.2, 1.4);
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Opacity(opacity: _in(t, .7, 1.4), child: Text('${g.reg != null ? '${g.reg!.n} · ' : ''}${g.num_('day') > 0 ? g.num_('day').toInt() : 1}일째 새벽', style: Ttc.t(12, color: const Color(0xFF9B927F)).copyWith(letterSpacing: 1))),
                const SizedBox(height: 16),
                Opacity(
                  opacity: _in(t, .2, 1.6),
                  child: Container(
                    width: 150,
                    height: 176,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 40, offset: Offset(0, 10))],
                      border: Border.all(color: const Color(0x2EE9E1D1)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(_gray(_in(t, .7, 3))),
                      child: Portrait(d.id, width: 150, height: 176),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Opacity(opacity: _in(t, .7, 1.2), child: Text(s.name, style: Ttc.t(28, color: const Color(0xFFE9E1D1), weight: FontWeight.w700, height: 1.2))),
                Opacity(opacity: _in(t, .7, 1.2), child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('${s.age}세 · ${s.job}', style: Ttc.t(13, color: const Color(0xFFA79E8A))))),
                const SizedBox(height: 20),
                Opacity(opacity: _in(t, 2.4, 1.8), child: Text(g.lastLine(d.id), textAlign: TextAlign.center, style: Ttc.t(15.5, color: const Color(0xFFE9E1D1), height: 1.7))),
                const SizedBox(height: 22),
                Opacity(opacity: _in(t, 2.4, 1), child: SizedBox(width: 34, height: 44, child: CustomPaint(painter: _LampPainter(fl, t)))),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: ready ? widget.onDone : null,
                  child: AnimatedOpacity(
                    opacity: ready ? 1 : .25,
                    duration: const Duration(milliseconds: 600),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 170),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x59E9E1D1))),
                      child: Text(ready ? '이름을 새긴다' : '…', textAlign: TextAlign.center, style: Ttc.t(14.5, color: const Color(0xFFE9E1D1), weight: FontWeight.w600, height: 1)),
                    ),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }

  /// CSS dFade: 사진이 점점 흑백으로
  List<double> _gray(double k) {
    final a = 1 - k * .85;
    const r = .2126, gg = .7152, b = .0722;
    return [
      r + (1 - r) * a, gg - gg * a, b - b * a, 0, 0, //
      r - r * a, gg + (1 - gg) * a, b - b * a, 0, 0,
      r - r * a, gg - gg * a, b + (1 - b) * a, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}

class _LampPainter extends CustomPainter {
  _LampPainter(this.fl, this.t);
  final double fl, t;
  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 40, s.height / 52);
    final st = Paint()
      ..color = const Color(0xFFC9B48C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
        Path()
          ..moveTo(13, 12)
          ..lineTo(27, 12)
          ..moveTo(15, 12)
          ..lineTo(15, 8)
          ..lineTo(25, 8)
          ..lineTo(25, 12)
          ..moveTo(12, 14)
          ..lineTo(28, 14)
          ..lineTo(26, 40)
          ..lineTo(14, 40)
          ..close(),
        st);
    c.drawRect(const Rect.fromLTWH(15, 40, 10, 4), Paint()..color = const Color(0xFFC9B48C));
    if (fl <= 0) return;
    final k = fl * (.92 + .08 * math.sin(t * 34));
    c.save();
    c.translate(20, 32);
    c.scale(k, k);
    c.translate(-20, -32);
    c.drawCircle(const Offset(20, 26), 10, Paint()..color = Color.fromRGBO(255, 190, 110, .25 * fl)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    c.drawPath(
        Path()
          ..moveTo(20, 20)
          ..cubicTo(24, 24, 24, 29, 20, 32)
          ..cubicTo(16, 29, 16, 24, 20, 20)
          ..close(),
        Paint()..color = const Color(0xFFFFCF7A));
    c.restore();
  }

  @override
  bool shouldRepaint(_LampPainter o) => o.fl != fl || o.t != t;
}

// ======================= 잃은 사람들 (웹 memorialHtml) =======================
List<Widget> memorialRows(Game g) {
  final L = g.S.rest['dead'];
  if (L is! List || L.isEmpty) return const [];
  return [
    sec('잃은 사람들 ${L.length}'),
    for (final d in L)
      if (d is Map && ((d['id'] as num?) ?? -1) >= 0 && (d['id'] as num) < survivors.length)
        Opacity(
          opacity: .75,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
            child: Row(children: [
              ColorFiltered(colorFilter: const ColorFilter.mode(Color(0xFF9A948A), BlendMode.saturation), child: faceBox(g, (d['id'] as num).toInt())),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(survivors[(d['id'] as num).toInt()].name, style: Ttc.t(15, color: Ttc.sepia, weight: FontWeight.w700)),
                  Text('${survivors[(d['id'] as num).toInt()].job}${(d['town'] as String? ?? '').isNotEmpty ? ' · ${d['town']}에서' : ''}', style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
                  Text(g.lastLine((d['id'] as num).toInt()), style: Ttc.t(13, color: Ttc.sepia2, height: 1.45).copyWith(fontStyle: FontStyle.italic)),
                ]),
              ),
            ]),
          ),
        ),
  ];
}

// ======================= 만수의 노선도 (웹 renderTowns 5335) =======================
List<int> _townIds(Game g, int gen) {
  if (gen == g.S.gen) return g.svIds.toList();
  final t = (g.S.rest['stay'] as Map?)?['$gen'] as Map?;
  return t == null ? const [] : [for (final k in (t['sv'] as Map).keys) int.parse('$k')];
}

Widget _dot({bool cur = false, bool next = false}) => Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(top: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cur ? const Color(0xFFE0B441) : next ? Colors.transparent : const Color(0xFFFBF7EE),
        border: Border.all(color: cur ? const Color(0xFF8A5A12) : const Color(0xFF3B2A1A).withValues(alpha: next ? .6 : 1), width: 2),
        boxShadow: cur ? const [BoxShadow(color: Color(0x47E0B441), spreadRadius: 4), BoxShadow(color: Color(0x8CE0B441), blurRadius: 14)] : null,
      ),
      child: cur ? const ResIcon('hope', size: 18) : null,
    );

Widget _stop(Widget body, {bool cur = false, bool next = false, bool first = false, bool last = false, VoidCallback? onTap}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(children: [
        Positioned(
          left: 11,
          top: first && next ? 22 : 0,
          bottom: last ? null : 0,
          height: last ? 22 : null,
          child: Container(width: 2, color: const Color(0x593B2A1A)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dot(cur: cur, next: next),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: next ? .75 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: next ? Colors.transparent : cur ? const Color(0xFFFDF6DF) : const Color(0xFFFBF7EE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cur ? const Color(0xFF8A5A12) : const Color(0x403B2A1A), width: 1.5),
                  ),
                  child: body,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );

Widget _stopT(String t, String small) => Text.rich(TextSpan(children: [TextSpan(text: t), TextSpan(text: '  $small', style: Ttc.t(11.5, color: Ttc.sepia2, weight: FontWeight.w500))]),
    style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700, height: 1.35));

List<Widget> routeTab(BuildContext context, Game g) {
  final G = g.S.gen;
  if (G == 0 && g.tlogList.isEmpty) {
    return [emptyBox(lineIco(mapSvg, 28, Ttc.sepia2), '아직 노선도가 없어요', '새 동네로 떠나면 만수가 지나온 길을 그려 줘요')];
  }
  final out = <Widget>[
    Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 0, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('만수의 노선도', style: Ttc.t(15, color: Ttc.sepia, weight: FontWeight.w700, height: 1.3)),
        const SizedBox(height: 3),
        Text('시운전하던 밤에 달린 길 · 정류장을 누르면 그 동네 기록과 남은 사람들을 봐요', style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
      ]),
    ),
    _stop(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _stopT('다음 정류장', '안개 속'),
          Text(regions[g.nextRegion]?.n ?? '', style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
        ]),
        next: true,
        first: true),
  ];
  for (var gen = G; gen >= 0; gen--) {
    Map? e;
    for (final x in g.tlogList) {
      if (x is Map && x['g'] == gen) e = x;
    }
    final t = [for (final s in (e?['t'] as List? ?? const [])) '$s'];
    final cur = gen == G, L = e?['left'] as Map?;
    final ids = _townIds(g, gen);
    final w = wayPts(gen + 1);
    if (gen < G && w.isNotEmpty) {
      out.add(Stack(children: [
        Positioned(left: 11, top: 0, bottom: 0, child: Container(width: 2, color: const Color(0x593B2A1A))),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 2, 0, 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final x in w) Text('· $x', style: Ttc.t(13, color: Ttc.sepia2, height: 1.6))]),
        ),
      ]));
    }
    final d = cur
        ? '생존자 ${g.S.sv.length}명 · 등불 탑 ${g.towerN}단계'
        : '${ids.isNotEmpty ? '남은 사람 ${ids.length}명' : '남은 사람 없음'} · 등불 탑 ${L?['tower'] ?? '?'}단계${L != null && (L['sets'] as List? ?? const []).isNotEmpty ? ' · ${(L['sets'] as List).join('·')}' : ''}';
    out.add(_stop(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stopT(townName(gen), '${gen > 0 ? '$gen번째 동네' : '출발지'}${cur ? ' · 지금' : L != null ? ' · ${L['day']}일째 떠남' : ''}'),
        Padding(padding: const EdgeInsets.only(top: 3), child: Text(d, style: Ttc.t(13, color: Ttc.sepia2, height: 1.5))),
        if (ids.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Row(children: [
              for (final id in ids.take(5)) Padding(padding: const EdgeInsets.only(right: 4), child: _round(id, 30)),
              if (ids.length > 5) Text('+${ids.length - 5}', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
            ]),
          ),
        if (t.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${t.last}”', style: Ttc.t(12.5, color: Ttc.sepia, height: 1.5).copyWith(fontStyle: FontStyle.italic))),
      ]),
      cur: cur,
      last: gen == 0,
      onTap: () => showTown(context, g, gen),
    ));
  }
  return out;
}

Future<void> showTown(BuildContext context, Game g, int gen) => showPageOf(context, g, (ctx) {
      Map? e;
      for (final x in g.tlogList) {
        if (x is Map && x['g'] == gen) e = x;
      }
      final t = [for (final s in (e?['t'] as List? ?? const [])) '$s'];
      final cur = gen == g.S.gen;
      final stay = (g.S.rest['stay'] as Map?)?['$gen'] as Map?;
      final ids = stay == null ? <int>[] : [for (final k in (stay['sv'] as Map).keys) int.parse('$k')];
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _tag('${gen > 0 ? '$gen번째 동네' : '출발지'}${cur ? ' · 지금' : ''}'),
        _h3(townName(gen)),
        if (ids.isNotEmpty) ...[
          _sec2('남은 사람들'),
          _grid([
            for (final id in ids)
              _mpk(id, '${grades[((stay!['sv'] as Map)['$id'] as Map)['g'] as int? ?? survivors[id].grade].n ?? ''} · ${survivors[id].job}',
                  onTap: cur || g.swap != null
                      ? null
                      : () {
                          if (!g.canPay(swapCost)) {
                            g.fx.add(const FxToast('건전지가 모자라요'));
                            return;
                          }
                          Navigator.pop(ctx);
                          showSwapOut(context, g, id);
                        }),
          ]),
          _d(g.swap != null ? '지금 교대가 진행 중이에요' : '얼굴을 누르면 무전으로 불러요 · 건전지 ${swapCost['batt']} · 대신 여기 한 명이 그 동네로 가요'),
        ] else
          _d(cur ? '여기가 지금 우리 동네예요. 떠날 때 남는 사람들이 이 자리에 남아요.' : '이 동네에는 아무도 남지 않았어요.'),
        _sec2('동네 기록'),
        _d(t.isEmpty ? '아직 기록이 없어요' : t.map((x) => '· $x').join('\n')),
        const SizedBox(height: 14),
        Row(children: [pageBtn('닫기', () => Navigator.pop(ctx), alt: true)]),
      ]);
    });

Future<void> showSwapOut(BuildContext context, Game g, int inId) {
  final L = g.stayList.where((x) => x.$1 == inId).firstOrNull;
  if (L == null) return Future.value();
  return showPageOf(context, g, (ctx) {
    final ids = [for (final id in g.svIds) if (!g.busy(id)) id];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      _tag('무전 교대'),
      _h3('${jo(survivors[inId].name, '을', '를')} 부르면, 누가 ${L.$3}으로 갈까요?'),
      _p('떠나는 사람은 그 동네의 등불을 지켜요. 원정 중이거나 다친 사람은 보낼 수 없어요.'),
      const SizedBox(height: 8),
      _grid([
        for (final id in ids)
          _mpk(id, '${grades[g.gradeOf(id)].n ?? ''} · ${survivors[id].job}${g.atOf(id) >= 0 ? ' · 일하는 중' : ''}', onTap: () {
            Navigator.pop(ctx);
            g.swapStart(inId, id);
          }),
      ]),
      const SizedBox(height: 12),
      Row(children: [pageBtn('그만두기', () => Navigator.pop(ctx), alt: true)]),
    ]);
  });
}

// ======================= 무전 거래·교대 (웹 tradeHtml·swapHtml) =======================
(String, Color?) _trTag(Map o) {
  final f = (o['f'] as num).toDouble();
  if (o['urgent'] == true) return ('급한 부탁', Ttc.no);
  if (f >= 1.3) return ('후한 편', Ttc.ok);
  if (f <= .95) return ('박한 편', const Color(0xFF8A7A64));
  return ('보통', null);
}

Widget _face(int id) => Container(
      width: 44,
      height: 50,
      decoration: BoxDecoration(color: const Color(0xFFE6D8B6), borderRadius: BorderRadius.circular(7), border: Border.all(color: Ttc.line)),
      clipBehavior: Clip.antiAlias,
      child: Portrait(id, width: 44, height: 50),
    );

List<Widget> radioRegion(BuildContext context, Game g, {VoidCallback? onRoute}) {
  final L = g.stayList, out = <Widget>[];
  if (L.isNotEmpty) {
    final T = g.trState(), used = ((T['used'] as num?) ?? 0).toInt(), offers = T['offers'] as List, pend = T['pend'] as List? ?? const [];
    out
      ..add(hl('sec:trade', sec('무전 거래 · 남은 사람들', '오늘 $used/$trMax')))
      ..add(Padding(padding: const EdgeInsets.only(bottom: 6), child: descText('이전 동네에 남은 사람들이 그 동네에 남는 걸 보내 줘요. 내 자재는 바로 나가고, 물건은 다음 새벽에 길을 건너와요.')));
    for (final p in pend) {
      final id = ((p as Map)['id'] as num).toInt();
      out.add(MCard(
        thumb: _face(id),
        title: survivors[id].name,
        tags: [smallTag('오는 중 · 새벽에 도착')],
        desc: descText((p['give'] as Map).entries.map((e) => '${matOf[e.key]!.n} ${e.value}').join(', ')),
      ));
    }
    if (used >= trMax) {
      out.add(descText('오늘 무전은 다 썼어요. 내일 새벽에 새 제안이 와요.'));
    } else if (offers.isEmpty) {
      out.add(descText('오늘은 더 제안이 없어요. 내일 새벽에 다시 와요.'));
    } else {
      for (var i = 0; i < offers.length; i++) {
        final o = offers[i] as Map, id = (o['id'] as num).toInt(), gk = (o['give'] as Map).keys.first as String, gn = ((o['give'] as Map)[gk] as num).toInt();
        final want = {for (final e in (o['want'] as Map).entries) e.key as String: e.value as num};
        final room = math.max(0, g.capOf(gk) - g.have(gk)), full = room <= 0, clip = room < gn;
        final (tn, tc) = _trTag(o);
        final town = L.where((x) => x.$1 == id).firstOrNull?.$3 ?? '';
        out.add(MCard(
          thumb: _face(id),
          title: survivors[id].name,
          tags: [
            smallTag(town),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: (tc ?? Ttc.sepia2).withValues(alpha: .12), borderRadius: BorderRadius.circular(4)),
              child: Text(tn, style: Ttc.t(10.5, color: tc ?? Ttc.sepia2, weight: FontWeight.w700, height: 1.1)),
            ),
          ],
          desc: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o['txt'] as String, style: Ttc.t(12.5, color: Ttc.sepia, height: 1.5).copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: 3),
            Text.rich(TextSpan(children: [
              const TextSpan(text: '받는 것 '),
              bold('${matOf[gk]!.n} $gn'),
              if (clip && !full) TextSpan(text: ' 창고에 ${fmt(room)}만 들어가요', style: const TextStyle(color: Ttc.no)),
            ]), style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
          ]),
          costs: costWrap(g, want, lead: [Text('보내는 것', style: Ttc.t(11.5, color: Ttc.sepia2))]),
          button: full
              ? const BuyButton('창고 가득')
              : g.canPay(want)
                  ? BuyButton('보내기', onTap: () {
                      final why = g.trAccept(i);
                      if (why != null && why.isNotEmpty) g.fx.add(FxToast(why));
                    })
                  : const BuyButton('보내기', why: '자재 부족'),
        ));
      }
    }
  }
  final w = g.swap;
  if (L.isNotEmpty || w != null) {
    out
      ..add(Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
        child: Row(children: [
          Text('무전 교대 · 남은 사람들', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
          const Spacer(),
          if (onRoute != null) GestureDetector(onTap: onRoute, child: Text('노선도 보기 →', style: Ttc.t(12, color: const Color(0xFF8A5A12), weight: FontWeight.w600))),
        ]),
      ))
      ..add(Padding(padding: const EdgeInsets.only(bottom: 6), child: descText('이전 동네에 남은 사람을 불러요. 대신 여기 한 명이 그 동네로 가서 자리를 지켜요 · 다음 새벽에 도착')));
    if (w != null) {
      final inId = (w['inId'] as num).toInt(), outId = (w['outId'] as num).toInt();
      out.add(MCard(
        thumb: _face(inId),
        title: survivors[inId].name,
        tags: [smallTag('오는 중 · 새벽에 도착')],
        desc: descText('${jo(survivors[outId].name, '이', '가')} 떠날 채비를 해요'),
        button: BuyButton('취소', onTap: g.swapCancel),
      ));
    } else {
      for (final x in L) {
        final s = survivors[x.$1], gr = (x.$4['g'] as num?)?.toInt() ?? s.grade;
        out.add(MCard(
          thumb: _face(x.$1),
          title: s.name,
          tags: [smallTag('${grades[gr].n ?? ''} · ${s.job}')],
          desc: descText('${x.$3}에 남아 있어요'),
          costs: costWrap(g, swapCost),
          button: g.canPay(swapCost) ? BuyButton('부르기', onTap: () => showSwapOut(context, g, x.$1)) : const BuyButton('부르기', why: '건전지 부족'),
        ));
      }
    }
  }
  return out;
}

// ======================= 생존자의 이야기 (웹 questHtml 3467 '개인 이야기') =======================
Widget questBox(Game g, int id) {
  final Q = quests[id];
  if (Q == null) return const SizedBox.shrink();
  final q = g.qOf(id);
  Widget box(List<Widget> kids, {bool lock = false, bool done = false}) => Opacity(
        opacity: lock ? .7 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E7CB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: done ? const Color(0xFF6F8F4A) : const Color(0x59B0452A), width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
        ),
      );
  if (q == null) {
    return box([_sec2('${survivors[id].name}의 이야기 · ???'), _d('신뢰도 $qUnlock이 되면 ${survivors[id].name}의 이야기가 열려요')], lock: true);
  }
  if (q['done'] == true) {
    return box([_sec2('${survivors[id].name}의 이야기 · ${Q.t} ✓'), _d(Q.end.last.t)], done: true);
  }
  final s = ((q['s'] as num?) ?? 0).toInt(), st = Q.steps[math.min(s, Q.steps.length - 1)];
  final c = g.qCost(st);
  return box([
    _sec2('${survivors[id].name}의 이야기 · ${Q.t}', '${s + 1}/${Q.steps.length}'),
    Padding(padding: const EdgeInsets.fromLTRB(0, 2, 0, 6), child: Text(g.qSay(st), style: Ttc.serif(16, color: const Color(0xFF5A3F24), height: 1.45))),
    Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(TextSpan(children: [TextSpan(text: '할 일 ', style: Ttc.t(13, color: Ttc.rust, weight: FontWeight.w700)), TextSpan(text: g.qStepTxt(st))]),
          style: Ttc.t(13, color: Ttc.sepia, height: 1.5)),
    ),
    if (st['k'] == 'give') ...[
      needList(g, c),
      const SizedBox(height: 8),
      Row(children: [pageBtn('건네기', g.canPay(c) ? () => g.qGive(id) : null, alt: true)]),
      const SizedBox(height: 6),
    ],
    _d('완결 보상: 전용 장비 ‘${gear[Q.gear]?.n ?? Q.gear}’'),
  ]);
}
