// 4단계 화면: 원정 시트·원정 일지 (웹 renderExp 2914, claimExp 창)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'atlas.dart';
import 'crisis_ui.dart';
import 'gear.dart';
import 'people.dart';
import 'portrait.dart';
import 'region_ui.dart';
import 'lines_ui.dart';
import 'survivors.dart';
import 'story_ui.dart';
import 'season_ui.dart';
import 'theme.dart';
import 'underground_ui.dart';
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
  static bool withPet = false;
  Game get g => widget.g;

  @override
  Widget build(BuildContext context) {
    return Every(
        g: g,
        builder: (context) {
          final now = DateTime.now().millisecondsSinceEpoch, out = <Widget>[], locks = <String>[]; // 잠긴 원정 (앞에 자물쇠 선 아이콘)
          if (g.S.sv.isEmpty) out.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: descText('생존자를 먼저 구조해야 원정을 보낼 수 있어요.')));
          if (g.autoExpOpen) {
            final on = g.S.rest['autoExp'] == true;
            out.add(hl('autoexp', autoBox(
              title: '자동 원정',
              sub: on ? '켜짐 · 보낼 수 있는 사람 ${g.expPool.length}명' : '쉬는 사람으로 팀을 꾸려 보내고, 돌아오면 알아서 챙겨요',
              button: const SizedBox.shrink(),
              trailing: toggle(on, () {
                g.S.rest['autoExp'] = !on;
                g.dirty = true;
                widget.toast(!on ? '자동 원정을 켰어요 · 순찰·아이 돌보기 중인 사람은 남겨 둬요' : '자동 원정을 껐어요');
                g.poke();
              }),
            )));
          }
          out.add(ugCard(context, g));
          out.add(lnCardWidget(context, g));
          final em = g.expMap;
          for (final e in exps) {
            if (!g.expOpen(e)) {
              locks.add('${e.name} · ${e.lock}');
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
              final pk = withPet && g.petOn != null && g.petHere(g.petOn!) ? g.petOn : null;
              final c = g.expCalc(e, team, pk);
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
                    if (g.petOn != null && g.petHere(g.petOn!))
                      GestureDetector(
                        onTap: () => setState(() => withPet = !withPet),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 42),
                          padding: const EdgeInsets.fromLTRB(4, 4, 9, 4),
                          decoration: BoxDecoration(
                            color: pk != null ? const Color(0xFFEDD6A6) : const Color(0xFFF5EEDF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: pk != null ? const Color(0xFFB58B49) : Ttc.line),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            PetPic(g.petOn!, size: 32, collar: ((g.pets[g.petOn!]!['c'] as num?) ?? 0).toInt()),
                            const SizedBox(width: 4),
                            Text('${g.petName(g.petOn!)} 데려가기', style: Ttc.t(12, color: Ttc.sepia, weight: FontWeight.w600)),
                          ]),
                        ),
                      ),
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
                    ghostBtn('자동 팀', () {
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
                          if (g.sendExp(e.key, team, pet: pk) != null) setState(() => planKey = null);
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
                for (final l in locks)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text.rich(
                          TextSpan(children: [
                            WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: const EdgeInsets.only(right: 4), child: lineIco(lockSvg, 12, Ttc.sepia2))),
                            TextSpan(text: l),
                          ]),
                          style: Ttc.t(13, color: Ttc.sepia2, height: 1.4))),
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
        Text('원정 일지 · ${e?.name ?? ''}', style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600)),
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

// ======================= 라디오 (웹 renderRadio 3249) =======================
Widget radioArt({double width = 230}) => SizedBox(
      width: width,
      height: width * 180 / 240,
      child: AtlasPic(file: 'radio.webp', src: Atlas.image('radio.webp') == null ? null : Rect.fromLTWH(0, 0, 1448, 1086), width: width, height: width * 180 / 240),
    );

class RadioBody extends StatelessWidget {
  const RadioBody(this.g, {super.key, this.onRoute});
  final Game g;
  final VoidCallback? onRoute;
  @override
  Widget build(BuildContext context) {
    final b = g.batt, c = g.exchangeCost;
    Widget pullBtn(int n) => Expanded(child: hl('pull:$n', BuyButton('$n번 탐색 · 건전지 $n', width: double.infinity, onTap: b < n ? null : () => showPull(context, g, n)), radius: 7));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 20), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Ttc.line)),
        child: Column(children: [
          Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            radioArt(width: math.min(230, MediaQuery.of(context).size.width * .6)),
            // 무전실이 서면 깜빡이는 작은 신호등 (사라진 3분 · 웹 mlamp)
            if (g.hasMod(7) && g.egg['b'] == null) Positioned(top: -2, left: math.min(230, MediaQuery.of(context).size.width * .6) / 2 + 58, child: MorseLamp(g)),
          ]),
          const SizedBox(height: 12),
          Text.rich(TextSpan(children: [const TextSpan(text: '건전지로 다이얼을 돌려 물자와 장비를 찾아요. 가끔 '), bold('히든 생존자'), const TextSpan(text: '의 목소리도 잡혀요.')]),
              style: Ttc.t(14, color: Ttc.sepia2, height: 1.7)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: const Color(0xFFE8DFCD), borderRadius: BorderRadius.circular(7), border: Border.all(color: Ttc.line)),
            child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 5, runSpacing: 4, children: [
              ResIcon('batt', size: 18),
              Text.rich(TextSpan(children: [const TextSpan(text: '건전지 '), bold('$b')]), style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text.rich(TextSpan(children: [const TextSpan(text: '히든 신호까지 최대 '), bold('${g.pityLeft}'), const TextSpan(text: '번')]), style: Ttc.t(11, color: Ttc.sepia2)),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [pullBtn(1), const SizedBox(width: 8), pullBtn(5)]),
          const SizedBox(height: 6),
          Text('5번 탐색에는 희귀 자재 이상이 하나는 꼭 들어 있어요', textAlign: TextAlign.center, style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
        ]),
      ),
      MCard(
        thumb: const SizedBox(width: 0),
        title: '건전지 만들기',
        costs: costWrap(g, c),
        button: BuyButton('만들기', onTap: g.canPay(c) ? g.exchange : null, why: g.canPay(c) ? null : '자재 부족'),
      ),
      descText('건전지는 목표·밤·원정·부탁에서 얻어요.'),
      sec('히든 생존자'),
      Row(children: [
        for (final id in hiddenSv) ...[
          if (id != hiddenSv.first) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: g.hasSv(id) ? const Color(0xFFFBECC4) : const Color(0xFFDED8CB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: g.hasSv(id) ? const Color(0xFFE0B441) : Ttc.line),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                faceBox(g, id, w: double.infinity, h: 150, locked: !g.hasSv(id), hid: true),
                const SizedBox(height: 4),
                Text(g.hasSv(id) ? survivors[id].name : '???', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
                Text(g.hasSv(id) ? survivors[id].job : (survivors[id].alias ?? ''), style: Ttc.t(11, color: Ttc.sepia2, height: 1.4)),
              ]),
            ),
          ),
        ],
      ]),
      ...radioRegion(context, g, onRoute: onRoute),
      sec('확률'),
      for (final (_, p, n) in gTable)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(children: [Expanded(child: Text(n, style: Ttc.t(13, color: Ttc.sepia))), Text('${(p * 100).round()}%', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700))]),
        ),
      const SizedBox(height: 4),
      descText('히든 생존자를 모두 만나면 그 몫은 희귀 자재가 돼요. $pity번 안에 한 번은 반드시 히든 신호가 잡혀요.'),
    ]);
  }
}

/// 탐색: 지지직 → 결과 (웹 pull·showPull)
void showPull(BuildContext context, Game g, int n) {
  final res = g.pull(n);
  if (res == null) return;
  showPageOf(context, g, (ctx) => _PullPage(g, res, n));
}

class _PullPage extends StatefulWidget {
  const _PullPage(this.g, this.res, this.n);
  final Game g;
  final List<Pull> res;
  final int n;
  @override
  State<_PullPage> createState() => _PullPageState();
}

class _PullPageState extends State<_PullPage> {
  int phase = 0; // 0 지지직, 1 잡힘, 2 결과
  late List<Pull> res = widget.res;
  bool get hid => res.any((x) => x.k == 'hidden');
  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() {
    phase = 0;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => phase = 1);
    });
    Future.delayed(Duration(milliseconds: hid ? 1900 : 1500), () {
      if (!mounted) return;
      setState(() => phase = 2);
      for (final x in res.where((x) => x.k == 'hidden')) {
        widget.g.hiddenArrive(x.id!);
      }
    });
  }

  Widget _card(Pull x) {
    final g = widget.g;
    Color bg = const Color(0xFFF7EED6), bd = const Color(0x403B2A1A);
    final kids = <Widget>[];
    switch (x.k) {
      case 'hidden':
        bg = const Color(0xFFF8E3A8);
        bd = const Color(0xFFE0B441);
        kids.addAll([
          faceBox(g, x.id!, w: double.infinity, h: 120),
          Text(survivors[x.id!].name, style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
          Text(survivors[x.id!].job, style: Ttc.t(12, color: Ttc.sepia2)),
        ]);
      case 'memo':
        kids.addAll([
          Center(child: faceBox(g, x.id!, w: 56, h: 65)),
          Text('${survivors[x.id!].name}의 사연', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
          Text('신뢰 +60', style: Ttc.t(12, color: Ttc.sepia2)),
        ]);
      case 'gear':
        final G = gear[x.t]!;
        bg = [const Color(0xFFF7EED6), const Color(0xFFE6EFF6), const Color(0xFFEFE4F6), const Color(0xFFF8E3A8)][G.g];
        bd = Color(grades[G.g].color);
        kids.addAll([
          Center(child: GearIcon(x.t, size: 46)),
          Text(G.n, textAlign: TextAlign.center, style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
          Center(child: gradeChip(G.g)),
          Text('${slotName[G.slot]}\n${effText(G.eff)}', textAlign: TextAlign.center, style: Ttc.t(13, color: Ttc.sepia2, height: 1.45)),
        ]);
      case 'voice':
        bg = const Color(0xFFECE2F2);
        bd = const Color(0xFF8A6AA0);
        kids.addAll([
          Text('먼 곳의 목소리', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
          Text(x.t!, style: Ttc.t(13, color: Ttc.sepia2, height: 1.45)),
          Text('희망 +2', style: Ttc.t(12, color: Ttc.sepia2)),
        ]);
      default:
        if (x.k == 'rare') {
          bg = const Color(0xFFE3EEEE);
          bd = const Color(0xFF5D8FA0);
        }
        kids.addAll([
          Text(x.k == 'rare' ? '희귀 자재' : '잡음 속 물자', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
          if (x.got.isEmpty) Text('창고가 가득 찼어요', style: Ttc.t(13, color: Ttc.sepia2)),
          for (final e in x.got.entries)
            Row(children: [ResIcon(e.key, size: 13), const SizedBox(width: 3), Text('${matOf[e.key]!.n} ${e.value}', style: Ttc.t(13, color: Ttc.sepia2, height: 1.45))]),
        ]);
    }
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: bd, width: x.k == 'hidden' ? 2 : 1.5),
          boxShadow: x.k == 'hidden' ? const [BoxShadow(color: Color(0xBFE0B441), blurRadius: 18)] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [for (final k in kids) Padding(padding: const EdgeInsets.only(bottom: 3), child: k)]),
      ),
      if (x.k == 'hidden')
        Positioned(
          top: -9,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.rotate(
              angle: -.05,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Ttc.no, borderRadius: BorderRadius.circular(3)),
                child: Text('HIDDEN · 전설', style: Ttc.t(11, color: const Color(0xFFFFF4E0), weight: FontWeight.w700)),
              ),
            ),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    if (phase < 2) {
      return Column(children: [
        Align(alignment: Alignment.centerLeft, child: Text('주파수 탐색', style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600))),
        const SizedBox(height: 8),
        radioArt(width: 220),
        const SizedBox(height: 6),
        Text(phase == 0 ? '지지직… 지지…' : (hid ? '…!! 선명한 목소리가 잡혔어요!' : '…신호가 잡혔어요'), textAlign: TextAlign.center, style: Ttc.t(20, color: Ttc.sepia, weight: FontWeight.w700, height: 1.3)),
        const SizedBox(height: 12),
      ]);
    }
    final hs = res.where((x) => x.k == 'hidden').toList();
    final n = widget.n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('탐색 결과', style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600)),
      const SizedBox(height: 10),
      if (res.length == 1)
        Center(child: SizedBox(width: 180, child: _card(res.first)))
      else
        LayoutBuilder(builder: (c, box) {
          final cols = math.max(1, (box.maxWidth + 8) ~/ 100), w = (box.maxWidth - (cols - 1) * 8) / cols;
          return Wrap(spacing: 8, runSpacing: 10, children: [for (final x in res) SizedBox(width: w, child: _card(x))]);
        }),
      const SizedBox(height: 12),
      Text(
          hs.isNotEmpty ? hs.map((x) => '${jo(survivors[x.id!].name, '이', '가')} 신호를 따라 쉘터로 오고 있어요!').join('\n') : '히든 신호까지 최대 ${g.pityLeft}번',
          style: Ttc.t(13, color: hs.isNotEmpty ? Ttc.ok : const Color(0xFF6E5638), height: 1.6)),
      const SizedBox(height: 12),
      Row(children: [
        pageBtn('한 번 더 (건전지 $n)', g.batt < n
            ? null
            : () {
                final r = g.pull(n);
                if (r == null) return;
                setState(() {
                  res = r;
                  _run();
                });
              }, alt: true),
        const SizedBox(width: 8),
        pageBtn('확인', () => Navigator.pop(context)),
      ]),
    ]);
  }
}
