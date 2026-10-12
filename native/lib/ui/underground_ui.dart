// 지하 구역 화면: 원정 탭의 카드(.ugc), 내려갈 준비(.ugprep), 탐사 창(.page.ug.ugv2), 지하 기록.
// 웹 index.html 3631–3800, 최종 모양은 design.css 51–103 · qa.css 106–125.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'gear.dart';
import 'people.dart';
import 'portrait.dart';
import 'story_ui.dart';
import 'survivors.dart';
import 'theme.dart';
import 'widgets.dart';

// ======================= 원정 탭의 지하 구역 카드 (웹 ugCard) =======================
Widget ugCard(BuildContext context, Game g) {
  if (!g.ugOpen) return const SizedBox.shrink();
  final best = g.ugBest, last = g.ugLast, diary = g.ugDiaryGot.length;
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Ttc.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Text('지하 구역', style: Ttc.t(16, color: Ttc.sepia, weight: FontWeight.w700, height: 1.35))),
        Text('최고 $best층 · ${g.ugRuns}번 탐험', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w500)),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
        child: Row(children: [
          for (var k = 0; k < ugThemes.length; k++) ...[
            if (k > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(color: best >= ugThemes[k].f ? const Color(0x29F3A53A) : const Color(0xFFE4E8DF), borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  Text('${ugThemes[k].f}층~', style: Ttc.t(11, color: best >= ugThemes[k].f ? Ttc.rust : const Color(0xFF334B41), weight: FontWeight.w700)),
                  Text(best >= ugThemes[k].f ? ugThemes[k].n : '???', style: Ttc.t(11.5, color: best >= ugThemes[k].f ? Ttc.sepia : const Color(0xFF4D635A), height: 1.3)),
                ]),
              ),
            ),
          ],
        ]),
      ),
      Text('기름이 버티는 만큼 깊이. ${last > 1 ? '다음엔 지난번 멈춘 $last층부터 시작해요.' : '다음엔 멈춘 층부터 다시 시작해요.'}', style: Ttc.t(13, color: Ttc.sepia2, height: 1.6)),
      const SizedBox(height: 8),
      Row(children: [
        hl('ugprep', BuyButton('내려갈 준비', width: 96, onTap: g.S.sv.isEmpty ? null : () => showUgPrep(context, g)), radius: 7),
        if (diary > 0) ...[const SizedBox(width: 6), ghostBtn('지하 기록 $diary/${ugDiaries.length}', () => showUgDiary(context, g))],
      ]),
    ]),
  );
}

// ======================= 내려갈 준비 (웹 renderPrep) =======================
class _Prep {
  static List<int> team = [];
  static int fuel = 0;
  static bool pet = false;
  static int? start; // 1이면 1층부터, 아니면 지난번 층
}

void showUgPrep(BuildContext context, Game g) {
  final free0 = [for (final id in g.svIds) if (!g.busy(id)) id];
  _Prep.team.removeWhere((id) => !free0.contains(id));
  _Prep.fuel = math.min(_Prep.fuel, g.have('fuel').toInt());
  showPageOf(context, g, (ctx) => StatefulBuilder(builder: (ctx, set) {
        final free = [for (final id in g.svIds) if (!g.busy(id)) id];
        final t = _Prep.team..removeWhere((id) => !free.contains(id));
        final fmax = g.ugFuelMax(t);
        _Prep.fuel = math.max(0, math.min(_Prep.fuel, math.min(fmax, g.have('fuel').toInt())));
        final oil = g.ugOil0(t, _Prep.fuel);
        final (pick, why) = g.ugRecommend(free, pet: _Prep.pet);
        final perks = {for (final id in t) ...g.roleOf(id)}.map((r) => ugPerk[r]).whereType<String>().toList();
        final last = g.ugLast, startF = _Prep.start == 1 ? 1 : last;
        void fuelStep(int d) => set(() => _Prep.fuel = math.max(0, math.min(_Prep.fuel + d, math.min(fmax, g.have('fuel').toInt()))));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('지하 구역 · 최고 ${g.ugBest}층', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('누구와 내려갈까요?', style: Ttc.t(23, color: Ttc.sepia, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (free.length > 3)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFFDF6DF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF8A5A12), width: 1.5)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('추천 세 명', style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700)),
                    Text('소방·정찰·연구·간호 역할을 한 명씩, 나머지는 등급 순', style: Ttc.t(12, color: Ttc.sepia2, height: 1.5)),
                  ]),
                ),
                const SizedBox(width: 8),
                BuyButton('추천으로 고르기', width: 104, onTap: () => set(() => _Prep.team = [...pick])),
              ]),
            ),
          if (free.isEmpty)
            descText('지금 함께 갈 수 있는 사람이 없어요')
          else
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final id in free)
                _ugMem(g, id,
                    on: t.contains(id),
                    rec: pick.contains(id),
                    why: why[id],
                    onTap: !t.contains(id) && t.length >= 3 ? null : () => set(() => t.contains(id) ? t.remove(id) : t.add(id))),
            ]),
          if (g.petOn != null && g.petHere(g.petOn!))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => set(() => _Prep.pet = !_Prep.pet),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                  decoration: BoxDecoration(
                    color: _Prep.pet ? const Color(0xFFE9B358) : const Color(0xFFFBF4E4),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _Prep.pet ? const Color(0xFF8A5A20) : const Color(0x403B2A1A), width: 1.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    PetPic(g.petOn!, size: 32, collar: ((g.pets[g.petOn!]!['c'] as num?) ?? 0).toInt()),
                    const SizedBox(width: 4),
                    Flexible(child: Text('${g.petName(g.petOn!)} · ${petInfo(g.petOn!)['ugd']}', style: Ttc.t(12.5, color: Ttc.sepia, weight: FontWeight.w600))),
                  ]),
                ),
              ),
            ),
          if (perks.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 4), child: Text(perks.join('\n'), style: Ttc.t(13, color: Ttc.sepia2, height: 1.6))),
          if (last > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('시작 층', style: Ttc.t(12.5, color: Ttc.sepia2, weight: FontWeight.w600)),
                for (final f in [1, last])
                  GestureDetector(
                    onTap: () => set(() => _Prep.start = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: startF == f ? Ttc.sepia : const Color(0x59FFFFFF), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x4D3B2A1A), width: 1.5)),
                      child: Text(f == 1 ? '1층부터' : '지난번 $f층 · ${ugTheme(f).n}', style: Ttc.t(12.5, color: startF == f ? Ttc.paper : Ttc.sepia, weight: FontWeight.w600)),
                    ),
                  ),
              ]),
            ),
          // 연료 챙기기 (웹 .fuelrow: 누르고 있으면 계속)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              ResIcon('fuel', size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  const TextSpan(text: '연료 챙기기 '),
                  TextSpan(text: '최대 $fmax · ${math.max(1, t.length)}명', style: Ttc.t(11, color: Ttc.sepia2)),
                ]), style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w600)),
              ),
              _HoldBtn('−', _Prep.fuel <= 0 ? null : () => fuelStep(-1)),
              SizedBox(width: 36, child: Text('${_Prep.fuel}', textAlign: TextAlign.center, style: Ttc.t(18, color: Ttc.sepia, weight: FontWeight.w700))),
              _HoldBtn('+', _Prep.fuel >= math.min(fmax, g.have('fuel').toInt()) ? null : () => fuelStep(1)),
            ]),
          ),
          Text.rich(TextSpan(children: [
            const TextSpan(text: '랜턴 기름 '),
            TextSpan(text: '$oil', style: const TextStyle(fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
            const TextSpan(text: ' · 어두운 칸을 한 번 두드릴 때마다 1씩 써요. 연료 1개 = 기름 3\n이번 탐사에서 칸을 밝힌 층마다 동료 신뢰 +15 · 바로 돌아오면 보상이 없어요'),
          ]), style: Ttc.t(13, color: Ttc.sepia2, height: 1.6)),
          const SizedBox(height: 12),
          Row(children: [
            pageBtn('취소', () => Navigator.pop(ctx), alt: true),
            const SizedBox(width: 8),
            pageBtn(
                '내려가기',
                t.isEmpty
                    ? null
                    : () {
                        if (g.ugStart(t, _Prep.fuel, startF, pet: _Prep.pet)) {
                          _Prep.start = null;
                          Navigator.pop(ctx);
                          showUg(context, g);
                        }
                      }),
          ]),
          if (t.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('함께 갈 사람을 골라 주세요 (최대 3명)', textAlign: TextAlign.center, style: Ttc.t(12, color: Ttc.sepia2))),
        ]);
      }));
}

Widget _ugMem(Game g, int id, {required bool on, required bool rec, String? why, VoidCallback? onTap}) {
  final rl = [for (final r in g.roleOf(id)) if (ugRoleShort[r] != null) ugRoleShort[r]!];
  return GestureDetector(
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null && !on ? .45 : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
        decoration: BoxDecoration(
          gradient: on ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4C267), Color(0xFFE0A24A)]) : null,
          color: on ? null : (rec ? const Color(0xFFFDF6DF) : const Color(0xFFFBF4E4)),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: on ? const Color(0xFF8A5A20) : rec ? const Color(0xFF8A5A12) : const Color(0x403B2A1A), width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE6D8B6)),
            clipBehavior: Clip.antiAlias,
            child: Portrait(id, width: 30, height: 35),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(survivors[id].name, style: Ttc.t(13.5, color: const Color(0xFF2A1D10), weight: on ? FontWeight.w700 : FontWeight.w600, height: 1.25)),
              Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${grades[g.gradeOf(id)].n}${rl.isNotEmpty ? ' · ${rl.join('·')}' : ''}'),
                    if (why != null) TextSpan(text: ' · $why', style: const TextStyle(color: Color(0xFF8A5A12))),
                  ]),
                  style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w500, height: 1.3)),
            ]),
          ),
          if (rec) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFE0B441), borderRadius: BorderRadius.circular(99)),
              child: Text('추천', style: Ttc.t(10, color: const Color(0xFF3B2A1A), weight: FontWeight.w700, height: 1)),
            ),
          ],
          if (on) ...[const SizedBox(width: 6), Text('✓', style: Ttc.t(13, color: const Color(0xFF5A3510), weight: FontWeight.w700))],
        ]),
      ),
    ),
  );
}

/// 누르면 한 번, 누르고 있으면 계속 (웹 ugf: 380ms 뒤 110ms마다)
class _HoldBtn extends StatefulWidget {
  const _HoldBtn(this.t, this.onStep);
  final String t;
  final VoidCallback? onStep;
  @override
  State<_HoldBtn> createState() => _HoldBtnState();
}

class _HoldBtnState extends State<_HoldBtn> {
  Timer? _t;
  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _stop() {
    _t?.cancel();
    _t = null;
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onStep != null;
    return Listener(
      onPointerDown: on
          ? (_) {
              widget.onStep!();
              _stop();
              _t = Timer(const Duration(milliseconds: 380), () {
                _t = Timer.periodic(const Duration(milliseconds: 110), (_) {
                  if (!mounted || widget.onStep == null) {
                    _stop();
                    return;
                  }
                  widget.onStep!();
                });
              });
            }
          : null,
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: Opacity(
        opacity: on ? 1 : .45,
        child: Container(
          width: 40,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x47252E36))),
          child: Text(widget.t, style: Ttc.t(18, color: Ttc.sepia, weight: FontWeight.w700, height: 1)),
        ),
      ),
    );
  }
}

// ======================= 탐사 창 (웹 renderUG) =======================
/// 테마 색 (웹 --lit · --acc)
(Color, Color) _themeLit(String k) => switch (k) {
      'sewer' => (const Color(0xFF96D264), const Color(0xFFC8E89A)),
      'bunker' => (const Color(0xFF96BEDC), const Color(0xFFBFE0F2)),
      'plant' => (const Color(0xFFFF783C), const Color(0xFFFFB080)),
      _ => (const Color(0xFFF3A53A), const Color(0xFFFFCF7A)),
    };

/// 아이콘 아틀라스 칸 번호 (웹 UGIA)
const _ugia = {'stairs': 0, 'loot': 1, 'rare': 2, 'gear': 3, 'oil': 4, 'hazard': 5, 'rest': 6, 'key': 7, 'door': 8, 'foe': 9, 'shop': 10, 'diary': 11, 'pet': 12, 'quest': 13, 'start': 14, 'who': 15};

Widget ugIcon(String c, {bool done = false}) {
  final n = _ugia[c];
  if (n == null) return const SizedBox.shrink();
  final src = Rect.fromLTWH((n % 4) * 256.0 + 8, (n ~/ 4) * 256.0 + 8, 240, 240);
  Widget pic = CoverPic('underground-icons.webp', src);
  if (done) pic = ColorFiltered(colorFilter: const ColorFilter.matrix([.39, .41, .08, 0, 0, .16, .64, .08, 0, 0, .16, .41, .31, 0, 0, 0, 0, 0, 1, 0]), child: pic);
  return pic;
}

Future<void> showUg(BuildContext context, Game g) => showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xD90F161D),
      builder: (ctx) => ListenableBuilder(listenable: g, builder: (c, _) => _UgPage(g)),
    );

class _UgPage extends StatefulWidget {
  const _UgPage(this.g);
  final Game g;
  @override
  State<_UgPage> createState() => _UgPageState();
}

class _UgPageState extends State<_UgPage> {
  Game get g => widget.g;
  bool ending = false;

  void _tap(int i) {
    if (ending) return;
    HapticFeedback.selectionClick();
    final out = g.ugTap(i);
    setState(() {});
    if (out) {
      ending = true;
      Future.delayed(const Duration(milliseconds: 650), () {
        g.ugEnd(false);
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = g.ug;
    if (u == null) return const SizedBox.shrink();
    final f = u.floor, th = ugTheme(f);
    final (lit, acc) = _themeLit(th.k);
    final hint = g.ugRole('scout') || g.ugRole('art'), sci = g.ugRole('sci');
    final oilP = (u.oil / math.max(1, u.max)).clamp(0.0, 1.0).toDouble();
    final foeAlive = g.ugFoeAlive;
    final scr = MediaQuery.of(context).size, short = scr.height <= 700;
    final seen = <String>{for (final c in u.cells) if (c.rev && ugLabel[c.c] != null && c.c != 'start') c.c}.toList();
    final page = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      // 머리: B층 · 이름 · 열쇠 · 동료
      Row(children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFE0C391), borderRadius: BorderRadius.circular(7)),
          child: Text('B$f', style: Ttc.t(17, color: const Color(0xFF252E36), weight: FontWeight.w800, height: 1)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('지하 $f층', style: Ttc.t(19, color: Ttc.paper, weight: FontWeight.w700, height: 1.2)),
            Text(th.n, style: Ttc.t(12, color: const Color(0xFFC9CFC9), weight: FontWeight.w600)),
          ]),
        ),
        if (u.keys > 0)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: const Color(0x24FFCF7A), borderRadius: BorderRadius.circular(99)),
            child: Text('🗝 ${u.keys}', style: Ttc.t(12.5, color: const Color(0xFFFFD98A), weight: FontWeight.w700)),
          ),
        for (final id in u.team)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE6D8B6), border: Border.all(color: u.hurt.contains(id) ? Ttc.no : lit.withValues(alpha: .7), width: 2)),
              clipBehavior: Clip.antiAlias,
              child: u.hurt.contains(id)
                  ? ColorFiltered(colorFilter: const ColorFilter.matrix([.18, .36, .06, 0, 0, .18, .36, .06, 0, 0, .18, .36, .06, 0, 0, 0, 0, 0, 1, 0]), child: Portrait(id, width: 30, height: 35))
                  : Portrait(id, width: 30, height: 35),
            ),
          ),
      ]),
      // 깊이 막대 (웹 .udep)
      SizedBox(height: 25, child: Padding(padding: const EdgeInsets.fromLTRB(4, 6, 4, 0), child: CustomPaint(painter: _DepthPainter(f, g.ugCkDone, acc, lit)))),
      Padding(
        padding: EdgeInsets.symmetric(vertical: short ? 5 : 8),
        child: Opacity(
          opacity: .9,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: short ? 36 : 78),
            child: ClipRRect(borderRadius: BorderRadius.circular(7), child: AspectRatio(aspectRatio: 3, child: sceneArtPic(th.k == 'plant' ? 'control' : th.k))),
          ),
        ),
      ),
      // 기름
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF2D3844), borderRadius: BorderRadius.circular(8), border: Border.all(color: Ttc.line17)),
        child: Row(children: [
          SizedBox(width: 28, height: 28, child: CustomPaint(painter: _LampIco(oilP < .25 ? const Color(0xFFFF8A70) : const Color(0xFFFFCF7A)))),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(color: const Color(0x73000000), borderRadius: BorderRadius.circular(5)),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: oilP, child: Container(decoration: BoxDecoration(color: Ttc.amber, borderRadius: BorderRadius.circular(5)))),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
              width: 32,
              child: Text('${u.oil}', textAlign: TextAlign.right, style: Ttc.t(16, color: oilP < .25 ? const Color(0xFFFF8A70) : const Color(0xFFFFE29A), weight: FontWeight.w800, height: 1))),
        ]),
      ),
      // 소식
      Container(
        margin: EdgeInsets.symmetric(vertical: short ? 5 : 8),
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: foeAlive ? const Color(0xFF563C39) : const Color(0xFF2B3742),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: foeAlive ? const Color(0xFFAB5145) : const Color(0x1AEEE5D3))),
        child: _msg(u.msg, acc),
      ),
      if (u.shop)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            pageBtn('식량 15 → 기름 +8', g.canPay({'food': 15}) ? () => setState(() => g.ugBuy(0)) : null, alt: true),
            const SizedBox(width: 6),
            pageBtn('부품 12 → 🗝 1', g.canPay({'parts': 12}) ? () => setState(() => g.ugBuy(1)) : null, alt: true),
          ]),
        ),
      // 칸들
      Center(
        child: Container(
          width: math.min(scr.width - 60, short ? 230.0 : 280.0),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: const Color(0xFF1C2630), borderRadius: BorderRadius.circular(8)),
          child: GridView.count(
            crossAxisCount: ugW,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            children: [for (var i = 0; i < u.cells.length; i++) _cell(i, u.cells[i], hint, sci, lit, acc)],
          ),
        ),
      ),
      if (seen.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 12, runSpacing: 4, children: [
            for (final k in seen)
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 22, height: 22, child: ugIcon(k)),
                const SizedBox(width: 5),
                Text(ugName[k]!, style: Ttc.t(11.5, color: const Color(0xFFC9D1D8), weight: FontWeight.w600, height: 1.2)),
              ]),
          ]),
        ),
      // 챙긴 것
      Container(
        margin: EdgeInsets.symmetric(vertical: short ? 5 : 10),
        padding: EdgeInsets.all(short ? 6 : 9),
        decoration: BoxDecoration(color: const Color(0xFF283440), borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0x1FEEE5D3))),
        child: Wrap(spacing: 5, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('챙긴 것', style: Ttc.t(11.5, color: const Color(0xFF9A8A70), weight: FontWeight.w600)),
          if (u.carry.values.every((v) => v <= 0) && u.gear.isEmpty) Text('아직 없어요', style: Ttc.t(12, color: const Color(0xFF9A8A70))),
          for (final e in u.carry.entries)
            if (e.value > 0)
              Container(
                padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
                decoration: BoxDecoration(color: const Color(0x12FFFFFF), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ResIcon(e.key, size: 14),
                  const SizedBox(width: 3),
                  Text('${e.value}', style: Ttc.t(12.5, color: Ttc.paper, weight: FontWeight.w700)),
                ]),
              ),
          for (final t in u.gear)
            Container(
              padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
              decoration: BoxDecoration(color: const Color(0x33B478F0), borderRadius: BorderRadius.circular(99)),
              child: Text(gear[t]!.n, style: Ttc.t(12, color: Ttc.paper, weight: FontWeight.w700)),
            ),
        ]),
      ),
      // 돌아가기
      GestureDetector(
        onTap: () {
          if (ending) return;
          g.ugEnd(true);
          Navigator.pop(context);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          margin: EdgeInsets.only(top: short ? 6 : 2),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Ttc.paper, borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('돌아가기 · 전리품 챙기기', style: Ttc.t(15, color: Ttc.sepia, weight: FontWeight.w700)),
            Text('기름이 다 떨어지면 자재 절반과 장비를 잃어요', style: Ttc.t(11, color: Ttc.sepia2)),
          ]),
        ),
      ),
    ]);
    return Dialog(
      backgroundColor: const Color(0xFF222D38),
      insetPadding: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0x66EEE5D3))),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: scr.height - 20),
        child: SingleChildScrollView(padding: EdgeInsets.all(short ? 10 : 14), child: page),
      ),
    );
  }

  Widget _msg(String m, Color acc) {
    // **굵게**만 지원 (지하 기록 제목)
    final parts = m.split('**');
    return Text.rich(
      TextSpan(children: [for (var k = 0; k < parts.length; k++) TextSpan(text: parts[k], style: k.isOdd ? TextStyle(color: acc, fontWeight: FontWeight.w700) : null)]),
      style: Ttc.t(13, color: const Color(0xFFE3DFD4), height: 1.5),
    );
  }

  Widget _cell(int i, UgCell c, bool hint, bool sci, Color lit, Color acc) {
    final u = g.ug!;
    if (c.rev) {
      final act = c.c == 'stairs' || (c.c == 'rest' && !c.used) || (c.c == 'door' && !c.open) || (c.c == 'foe' && c.fhp > 0) || c.c == 'shop';
      final done = c.used || c.open || (c.c == 'foe' && c.fhp <= 0);
      final hz = c.c == 'hazard';
      final bg = hz ? const Color(0xFF97594C) : act ? const Color(0xFFDFB168) : const Color(0xFF8B8C7D);
      final bd = act ? const Color(0xFFF0CA80) : const Color(0x47141A1F);
      final lc = hz ? const Color(0xFFFFF0DC) : act ? const Color(0xFF2A1C0C) : const Color(0xFF1D1712);
      Widget w = Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: bd)),
        child: Stack(children: [
          if (c.c != 'empty')
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.topCenter,
                widthFactor: .84,
                heightFactor: .70,
                child: Padding(padding: const EdgeInsets.only(top: 1), child: ugIcon(c.c, done: done)),
              ),
            ),
          if (c.c == 'foe' && c.fhp > 0)
            Positioned(left: 0, right: 0, bottom: 3, child: Text('●' * math.min(6, c.fhp), textAlign: TextAlign.center, style: Ttc.t(9, color: lit, height: 1)))
          else if (ugLabel[c.c] != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 3,
              child: Opacity(opacity: done ? .55 : 1, child: Text(ugLabel[c.c]!, textAlign: TextAlign.center, style: Ttc.t(9.5, color: lc, weight: FontWeight.w700, height: 1))),
            ),
        ]),
      );
      if (c.c == 'stairs') w = _Throb(child: w);
      if (c.fresh) {
        c.fresh = false;
        w = _Pop(key: ValueKey('p$i${u.floor}'), child: w);
      }
      return GestureDetector(onTap: act ? () => _tap(i) : null, child: w);
    }
    final fr = g.ugFront(i), can = fr && u.oil > 0;
    final mark = (fr && hint && c.c == 'hazard')
        ? Text('!', style: Ttc.t(20, color: const Color(0xFFFF8A70), weight: FontWeight.w800, height: 1).copyWith(shadows: const [Shadow(color: Color(0xCCFF5032), blurRadius: 8)]))
        : (sci && c.c == 'stairs')
            ? Opacity(opacity: .7, child: Text('▼', style: Ttc.t(16, color: acc, height: 1)))
            : null;
    Widget w = CustomPaint(
      painter: _DarkCell(can),
      child: Stack(children: [
        if (mark != null) Center(child: mark),
        if (fr && c.hp > 1) Positioned(left: 0, right: 0, bottom: 3, child: Text('●' * c.hp, textAlign: TextAlign.center, style: Ttc.t(9, color: lit, height: 1))),
      ]),
    );
    if (c.hit) {
      c.hit = false;
      w = _Shake(key: UniqueKey(), child: w);
    }
    return GestureDetector(onTap: can ? () => _tap(i) : null, child: w);
  }
}

/// 장소 그림 (story_ui.sceneArt와 같지만 둥근 모서리 없이)
Widget sceneArtPic(String key) {
  const scenes = {'mall': 0, 'road': 1, 'apt': 2, 'plant': 3, 'metro': 4, 'sewer': 5, 'bunker': 6, 'control': 7, 'shelter': 8};
  const ys = [0, 258, 494, 724];
  final n = scenes[key] ?? 4, row = n ~/ 3, col = n % 3;
  return CoverPic('world-panorama.webp', Rect.fromLTWH(col * 724.0 + 2, ys[row] + 2.0, 720, ys[row + 1] - ys[row] - 4.0));
}

class _DarkCell extends CustomPainter {
  _DarkCell(this.front);
  final bool front;
  @override
  void paint(Canvas canvas, Size s) {
    final r = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(6));
    canvas.drawRRect(r, Paint()..color = front ? const Color(0xFF34404B) : const Color(0xFF24313E));
    if (!front) {
      canvas.drawRRect(
          r.deflate(.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFF52606B));
      return;
    }
    // 점선 테두리 (웹 1.5px dashed #d3c5a3)
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFD3C5A3);
    final path = Path()..addRRect(r.deflate(.75));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, math.min(m.length, d + 4)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DarkCell old) => old.front != front;
}

class _DepthPainter extends CustomPainter {
  _DepthPainter(this.f, this.ck, this.acc, this.lit);
  final int f;
  final List<int> ck;
  final Color acc, lit;
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final bar = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, 4), const Radius.circular(2));
    canvas.drawRRect(
        bar,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFF6A5A44), Color(0xFF3F6A4A), Color(0xFF4A6070), Color(0xFF8A3A22), Color(0xFF8A3A22)], stops: [0, .22, .47, .74, 1])
              .createShader(Rect.fromLTWH(0, 0, w, 4)));
    for (final k in ugCks) {
      final x = (k - 1) / 19 * w, on = ck.contains(k);
      canvas.save();
      canvas.translate(x, 2);
      canvas.rotate(math.pi / 4);
      final rr = Rect.fromCenter(center: Offset.zero, width: 9, height: 9);
      canvas.drawRect(rr, Paint()..color = on ? const Color(0xFF6B8F4A) : const Color(0xFF3A3024));
      canvas.drawRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = on ? const Color(0xFFC8E89A) : const Color(0xFF8A7A60));
      canvas.restore();
    }
    for (final t in ugThemes) {
      final tp = TextPainter(text: TextSpan(text: t.n, style: Ttc.t(10.5, color: const Color(0xFFC9CFC9), weight: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
      var x = (t.f - 1) / 19 * w - 2;
      x = math.min(x, w - tp.width);
      tp.paint(canvas, Offset(x, 9));
    }
    final x = math.min(1.0, (f - 1) / 19) * w;
    canvas.drawCircle(Offset(x, 2), 9, Paint()..color = lit.withValues(alpha: .35));
    canvas.drawCircle(Offset(x, 2), 7, Paint()..color = const Color(0xFF1A120C));
    canvas.drawCircle(Offset(x, 2), 5, Paint()..color = acc);
  }

  @override
  bool shouldRepaint(_DepthPainter old) => old.f != f || old.ck.length != ck.length;
}

class _LampIco extends CustomPainter {
  _LampIco(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size s) {
    canvas.scale(s.width / 24);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    canvas.drawPath(
        Path()
          ..moveTo(9, 3)
          ..lineTo(15, 3)
          ..moveTo(10, 3)
          ..lineTo(10, 5)
          ..lineTo(14, 5)
          ..lineTo(14, 3)
          ..moveTo(8, 6)
          ..lineTo(16, 6)
          ..lineTo(15, 19)
          ..lineTo(9, 19)
          ..close(),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(12, 10)
          ..cubicTo(13.6, 11.6, 13.6, 13.4, 12, 14.6)
          ..cubicTo(10.4, 13.4, 10.4, 11.6, 12, 10),
        Paint()..color = c);
  }

  @override
  bool shouldRepaint(_LampIco old) => old.c != c;
}

class _Throb extends StatefulWidget {
  const _Throb({required this.child});
  final Widget child;
  @override
  State<_Throb> createState() => _ThrobState();
}

class _ThrobState extends State<_Throb> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: a, builder: (c, ch) => Transform.scale(scale: 1 + .06 * math.sin(a.value * math.pi), child: ch), child: widget.child);
}

class _Pop extends StatefulWidget {
  const _Pop({super.key, required this.child});
  final Widget child;
  @override
  State<_Pop> createState() => _PopState();
}

class _PopState extends State<_Pop> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..forward();
  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: a,
        builder: (c, ch) {
          final t = Curves.easeOutBack.transform(a.value);
          return Transform(alignment: Alignment.center, transform: Matrix4.identity()..scale(.6 + .4 * t, .6 + .4 * t), child: ch);
        },
        child: widget.child,
      );
}

class _Shake extends StatefulWidget {
  const _Shake({super.key, required this.child});
  final Widget child;
  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..forward();
  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: a,
        builder: (c, ch) {
          final v = a.value;
          final o = v < .25 ? const Offset(2, -1) : v < .5 ? const Offset(-2, 1) : v < .75 ? const Offset(1, 1) : Offset.zero;
          return Transform.translate(offset: o * (1 - v), child: ch);
        },
        child: widget.child,
      );
}

// ======================= 지하 기록 (웹 openUGDiary) =======================
void showUgDiary(BuildContext context, Game g) {
  final got = g.ugDiaryGot;
  showPageOf(context, g, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('지하 기록 ${got.length}/${ugDiaries.length}', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('깊은 곳에 남은 글', style: Ttc.t(23, color: Ttc.sepia, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (var k = 0; k < ugDiaries.length; k++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Ttc.line)),
            child: Opacity(
              opacity: got.contains(k) ? 1 : .5,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(got.contains(k) ? ugDiaries[k].$2 : '??? · 지하 ${ugDiaries[k].$1}층 즈음', style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700)),
                if (got.contains(k)) Padding(padding: const EdgeInsets.only(top: 4), child: Text(ugDiaries[k].$3, style: Ttc.t(13, color: Ttc.sepia2, height: 1.65))),
              ]),
            ),
          ),
        const SizedBox(height: 6),
        Row(children: [pageBtn('닫기', () => Navigator.pop(ctx))]),
      ]));
}
