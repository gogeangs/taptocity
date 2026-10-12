// 4단계 화면: 원정 시트·원정 일지 (웹 renderExp 2914, claimExp 창)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'atlas.dart';
import 'crisis_ui.dart';
import 'gear.dart';
import 'portrait.dart';
import 'survivors.dart';
import 'theme.dart';
import 'widgets.dart';

/// 장소 그림 (chapter-design.js scene: world-panorama 3×3, 행 높이 258·236·230)
class SceneArt extends StatelessWidget {
  const SceneArt(this.k, {super.key, this.height = 86});
  final String k;
  final double height;
  static const _scenes = {'mall': 0, 'road': 1, 'apt': 2, 'plant': 3, 'metro': 4, 'sewer': 5, 'bunker': 6, 'control': 7, 'shelter': 8};
  @override
  Widget build(BuildContext context) {
    final n = _scenes[k];
    if (n == null) return const SizedBox.shrink();
    const ys = [0.0, 258, 494, 724];
    final row = n ~/ 3, col = n % 3;
    final src = Rect.fromLTWH(col * 724 + 2, ys[row] + 2, 720, ys[row + 1] - ys[row] - 4);
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFF35404A), borderRadius: BorderRadius.circular(7)),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: _CoverPainter('world-panorama.webp', src), size: Size.infinite),
    );
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.file, this.src);
  final String file;
  final Rect src;
  @override
  void paint(Canvas canvas, Size size) {
    final img = Atlas.image(file);
    if (img == null) return;
    // xMidYMid slice: 가운데 맞춰 꽉 채움
    final k = math.max(size.width / src.width, size.height / src.height);
    final w = size.width / k, h = size.height / k;
    final s = Rect.fromLTWH(src.left + (src.width - w) / 2, src.top + (src.height - h) / 2, w, h);
    canvas.drawImageRect(img, s, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.src != src;
}

Widget _avatar(int id, {double size = 32}) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE6D8B6)),
      clipBehavior: Clip.antiAlias,
      child: Portrait(id, width: size, height: size * 1.17),
    );

Widget _mem(int id, {bool on = false, VoidCallback? onTap}) => GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null && !on ? .4 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.fromLTRB(6, 6, 9, 6),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFEDD6A6) : const Color(0xFFF5EEDF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? const Color(0xFFB58B49) : Ttc.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _avatar(id),
            const SizedBox(width: 6),
            Text(survivors[id].name, style: Ttc.t(12, color: Ttc.sepia, weight: FontWeight.w600, height: 1.3)),
          ]),
        ),
      ),
    );

Widget _card(List<Widget> kids) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Ttc.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
    );

Widget _top(String b, String meta) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Text(b, style: Ttc.t(16, color: Ttc.sepia, weight: FontWeight.w700, height: 1.35))),
      const SizedBox(width: 8),
      Text(meta, style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w500, height: 1.4)),
    ]);

class ExpBody extends StatefulWidget {
  const ExpBody(this.g, {super.key, required this.toast});
  final Game g;
  final void Function(String) toast;
  @override
  State<ExpBody> createState() => _ExpBodyState();
}

class _ExpBodyState extends State<ExpBody> {
  static String? planKey;
  static List<int> team = [];
  Game get g => widget.g;

  @override
  Widget build(BuildContext context) {
    return Every(
        g: g,
        builder: (context) {
          final now = DateTime.now().millisecondsSinceEpoch, out = <Widget>[], locks = <String>[];
          if (g.S.sv.isEmpty) out.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: descText('생존자를 먼저 구조해야 원정을 보낼 수 있어요.')));
          if (g.autoExpOpen) {
            final on = g.S.rest['autoExp'] == true;
            out.add(autoBox(
              title: '⚙ 자동 원정',
              sub: on ? '켜짐 · 보낼 수 있는 사람 ${g.expPool.length}명' : '쉬는 사람으로 팀을 꾸려 보내고, 돌아오면 알아서 챙겨요',
              button: const SizedBox.shrink(),
              trailing: toggle(on, () {
                g.S.rest['autoExp'] = !on;
                g.dirty = true;
                widget.toast(!on ? '자동 원정을 켰어요 · 순찰·아이 돌보기 중인 사람은 남겨 둬요' : '자동 원정을 껐어요');
                g.poke();
              }),
            ));
          }
          final em = g.expMap;
          for (final e in exps) {
            if (!g.expOpen(e)) {
              locks.add('🔒 ${e.name} · ${e.lock}');
              continue;
            }
            final x = em[e.key];
            if (x != null) {
              final dur = (x['dur'] as num).toDouble(), left = math.max(0.0, ((x['end'] as num) - now) / 1000), done = left <= 0;
              final tm = [for (final v in x['team'] as List) (v as num).toInt()];
              out.add(_card([
                SceneArt(e.key),
                _top(e.name, done ? '돌아왔어요!' : '남은 시간 ${g.mmss(left)}'),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final id in tm) if (g.hasSv(id)) _mem(id, on: false, onTap: () {})]),
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: const Color(0x1A252E36), borderRadius: BorderRadius.circular(3)),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(widthFactor: (1 - left / dur).clamp(0.0, 1.0).toDouble(), child: Container(color: Ttc.amber)),
                ),
                if (done) BuyButton('원정 일지 보기', width: double.infinity, onTap: () => g.claimExp(e.key)),
              ]));
              continue;
            }
            if (planKey == e.key) {
              team.removeWhere((id) => !g.hasSv(id) || g.busy(id));
              final c = g.expCalc(e, team);
              final free = [for (final id in g.svIds) if (!g.busy(id)) id];
              out.add(_card([
                SceneArt(e.key),
                _top(e.name, '최소 ${e.min}명 · 최대 3명'),
                Padding(padding: const EdgeInsets.fromLTRB(0, 3, 0, 8), child: Text(e.desc, style: Ttc.t(13, color: Ttc.sepia2, height: 1.6))),
                Wrap(spacing: 4, runSpacing: 4, children: [
                  for (final k in e.loot.keys)
                    Container(
                      padding: const EdgeInsets.fromLTRB(5, 3, 8, 3),
                      decoration: BoxDecoration(color: const Color(0x09252E36), borderRadius: BorderRadius.circular(5), border: Border.all(color: Ttc.line)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [ResIcon(k, size: 13), const SizedBox(width: 2), Text(matOf[k]!.n, style: Ttc.t(11, color: Ttc.sepia2))]),
                    ),
                ]),
                const SizedBox(height: 8),
                if (free.isEmpty)
                  descText('보낼 수 있는 생존자가 없어요')
                else
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final id in free)
                      _mem(id,
                          on: team.contains(id),
                          onTap: !team.contains(id) && team.length >= 3
                              ? null
                              : () => setState(() => team.contains(id) ? team.remove(id) : team.add(id))),
                  ]),
                Container(
                  margin: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0x0A252E36), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                      team.isEmpty
                          ? '함께 갈 사람을 골라 주세요'
                          : '소요 ${g.mmss(c.t.toDouble())} · 부상 위험 ${(c.risk * 100).round()}%${c.perks.isNotEmpty ? '\n${c.perks.join(' · ')}' : ''}\n원정 중에는 일터에서 빠지고 스킬도 못 써요',
                      style: Ttc.t(13, color: Ttc.sepia2, height: 1.6)),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (g.autoExpOpen) ...[
                    ghostBtn('⚙ 자동 팀', () {
                      final t = g.autoTeam(e, [for (final id in g.svIds) if (!g.busy(id) && !(((g.rec(id)!['hurt'] as num?) ?? 0) > 0)) id]);
                      if (t == null) {
                        widget.toast('보낼 수 있는 사람이 모자라요');
                        return;
                      }
                      setState(() => team = [...t]);
                    }),
                    const SizedBox(width: 6),
                  ],
                  ghostBtn('취소', () => setState(() => planKey = null)),
                  const SizedBox(width: 6),
                  BuyButton('출발', onTap: team.length < e.min
                      ? null
                      : () {
                          if (g.sendExp(e.key, team) != null) setState(() => planKey = null);
                        }),
                ]),
              ]));
              continue;
            }
            out.add(_card([
              SceneArt(e.key),
              _top(e.name, '${g.mmss(e.t)} · 위험 ${(e.risk * 100).round()}%'),
              const SizedBox(height: 6),
              Row(children: [
                Opacity(opacity: .85, child: Row(children: [for (final k in e.loot.keys) Padding(padding: const EdgeInsets.only(right: 5), child: ResIcon(k, size: 16))])),
                const Spacer(),
                BuyButton('팀 꾸리기', width: 76, onTap: g.S.sv.isEmpty
                    ? null
                    : () => setState(() {
                          planKey = e.key;
                          team = [];
                        })),
              ]),
            ]));
          }
          if (locks.isNotEmpty) {
            out.add(Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x333B2A1A), width: 1.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final l in locks) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l, style: Ttc.t(12.5, color: Ttc.sepia2, height: 1.4))),
              ]),
            ));
          }
          return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 20), children: out);
        });
  }
}

/// 원정 일지 (웹 claimExp 창)
void showExpBack(BuildContext context, Game g, FxExpBack f) {
  final e = expOf(f.key);
  showPageOf(context, g, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('원정 일지 · ${e?.name ?? ''}', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final id in f.team) Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: faceBox(g, id, w: 56, h: 65)),
        ]),
        const SizedBox(height: 10),
        Text('${f.team.map((id) => survivors[id].name).join(', ')}의 원정', textAlign: TextAlign.center, style: Ttc.t(20, color: Ttc.sepia, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(f.lines.join(' '), style: Ttc.t(14, color: const Color(0xFF4A3320), height: 1.65)),
        const SizedBox(height: 10),
        Text(f.sum.join(' · '), style: Ttc.t(13, color: Ttc.ok, height: 1.6)),
        const SizedBox(height: 14),
        Row(children: [pageBtn('좋아요', () => Navigator.pop(ctx))]),
      ]));
}
