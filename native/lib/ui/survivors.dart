// 생존자: 수첩(시트), 상세·구조·손님 창, 배치 목록. 웹 renderSheet('surv'·'assign'), openSurv, openCamp, rescue 를 옮겼다.
import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'icons.dart';
import 'portrait.dart';
import 'theme.dart';
import 'widgets.dart';

/// 등급 표 (웹 gradeTag): 등급 이름 칩 + 별
Widget gradeTag(Game g, int id, {bool base = false}) {
  final gr = base ? survivors[id].grade : g.gradeOf(id);
  final st = base ? 0 : g.starOf(id);
  final legend = gr >= 3;
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 2),
      decoration: BoxDecoration(
        color: legend ? null : Color(grades[gr].color),
        gradient: legend ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF3C34A), Color(0xFFC9861A)]) : null,
        borderRadius: BorderRadius.circular(4),
        boxShadow: legend ? const [BoxShadow(color: Color(0xCCE0B441), blurRadius: 6)] : null,
      ),
      child: Text(grades[gr].n ?? '', style: Ttc.t(11, color: legend ? const Color(0xFF3B2A1A) : Colors.white, weight: FontWeight.w700, height: 1)),
    ),
    if (!base) ...[
      const SizedBox(width: 3),
      Text.rich(TextSpan(children: [
        TextSpan(text: '★' * st, style: const TextStyle(color: Color(0xFFE0A020))),
        TextSpan(text: '★' * (5 - st), style: const TextStyle(color: Color(0x383B2A1A))),
      ]), style: const TextStyle(fontSize: 12, letterSpacing: -1)),
    ],
  ]);
}

/// 초상 테두리 (웹 .svrow .fc, 등급마다 배경)
Widget faceBox(Game g, int id, {double w = 54, double h = 63, bool locked = false, bool hid = false}) {
  final gr = locked ? 0 : g.gradeOf(id);
  final bg = switch (gr) {
    1 => const RadialGradient(center: Alignment(0, -.3), colors: [Color(0xFFE3EEF3), Color(0xFFB8CFDC)]),
    2 => const RadialGradient(center: Alignment(0, -.3), colors: [Color(0xFFEFE3F5), Color(0xFFCDB2DC)]),
    3 || 4 => const RadialGradient(center: Alignment(0, -.3), colors: [Color(0xFFFFF3CF), Color(0xFFE8C77A)]),
    _ => const RadialGradient(colors: [Color(0xFFE6D8B6), Color(0xFFE6D8B6)]),
  };
  return Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      gradient: bg,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: hid ? const Color(0xFFE0B441) : Ttc.line),
      boxShadow: gr >= 3 ? const [BoxShadow(color: Color(0x8CD99A1E), blurRadius: 8)] : null,
    ),
    clipBehavior: Clip.antiAlias,
    child: Portrait(id, width: w, height: h, locked: locked),
  );
}

// ======================= 생존자 수첩 =======================
class SurvBody extends StatefulWidget {
  const SurvBody(this.g, {super.key, required this.onOpen, required this.onFly});
  final Game g;
  final void Function(int id) onOpen;
  final void Function(int tile) onFly;
  @override
  State<SurvBody> createState() => _SurvBodyState();
}

class _SurvBodyState extends State<SurvBody> {
  static String filter = 'all';
  Game get g => widget.g;

  int? signalTile(int id) {
    for (final e in g.S.camp.entries) {
      if (e.value['id'] == id) return e.key;
    }
    for (final e in g.S.sig.entries) {
      if (e.value == id) return e.key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ids = g.svIds.toList();
    final met = [for (final s in survivors) if (g.hasSv(s.id)) s.id];
    final unmet = [for (final s in survivors) if (!g.hasSv(s.id) && !g.isDead(s.id) && !g.inStay(s.id) && !(s.src == 'town' && g.S.gen == 0)) s.id];
    final fl = <String, (bool Function(int), String)>{
      'all': ((_) => true, '전체'),
      'work': ((id) => g.atOf(id) >= 0 && !g.busy(id), '일하는 중'),
      'rest': ((id) => g.atOf(id) < 0 && !g.busy(id), '쉬는 사람'),
    };
    final list = met.where(fl[filter]!.$1).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 20), children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final e in fl.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => filter = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                  decoration: BoxDecoration(
                    color: filter == e.key ? const Color(0xFFE1C58E) : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: filter == e.key ? const Color(0xFFBD9554) : Ttc.line),
                  ),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${e.value.$2} '),
                    TextSpan(text: '${met.where(e.value.$1).length}', style: const TextStyle(color: Ttc.sepia2)),
                  ]), style: Ttc.t(11, color: Ttc.sepia, weight: FontWeight.w600)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      if (ids.isEmpty)
        emptyBox(SvgIcon(Ico.surv, size: 28, color: Ttc.sepia2), '아직 구조한 생존자가 없어요', '구름 위로 솟은 흰 빛기둥을 찾아가 잔해를 치우면 만날 수 있어요')
      else if (list.isEmpty)
        Padding(padding: const EdgeInsets.all(10), child: Text('여기에 해당하는 생존자가 없어요', style: Ttc.t(12.5, color: Ttc.sepia2))),
      for (final id in list) _row(id),
      if (unmet.isNotEmpty) ...[
        sec('아직 만나지 못한 사람 ${unmet.length}'),
        for (final id in unmet) _unmetRow(id),
      ],
    ]);
  }

  Widget _row(int id) {
    final s = survivors[id], hurt = ((g.rec(id)?['hurt'] as num?) ?? 0) > 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onOpen(id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
        child: Row(children: [
          faceBox(g, id, hid: s.hidden),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(s.name, overflow: TextOverflow.ellipsis, style: Ttc.t(15, color: Ttc.sepia, weight: FontWeight.w700))),
                const SizedBox(width: 6),
                gradeTag(g, id),
              ]),
              Text(s.job, style: Ttc.t(12, color: Ttc.sepia2, height: 1.5)),
              Text(g.statusOf(id), style: Ttc.t(12, color: hurt ? Ttc.no : Ttc.ok, weight: FontWeight.w600, height: 1.4)),
            ]),
          ),
          Text('›', style: Ttc.t(22, color: Ttc.sepia2)),
        ]),
      ),
    );
  }

  Widget _unmetRow(int id) {
    final s = survivors[id], where = signalTile(id), camp = where != null && g.S.camp.containsKey(where);
    final String hint;
    if (where != null) {
      hint = camp ? '구조를 기다리고 있어요 · 눌러서 지도에서 보기 ›' : '구름 속에서 신호가 와요 · 눌러서 지도에서 보기 ›';
    } else if (s.hidden) {
      hint = s.hint ?? (s.src == 'deep' ? '쉘터 불빛이 발전소까지 닿으면, 누군가 답할지도 몰라요' : '주파수 탐색에서만 만나요');
    } else if (s.src == 'sig') {
      hint = '구름 속 구조 신호를 따라가 보세요';
    } else if (s.src == 'town') {
      hint = s.region == g.S.region ? '구름 속 구조 신호를 따라가 보세요' : (s.hint ?? '');
    } else {
      hint = '희망 ${(s.hope * (1 - g.visitDisc)).ceil()} 이상이면 찾아와요${s.need != null && !g.hasSv(s.need!) ? ' · 먼저 만나야 할 사람이 있어요' : ''}';
    }
    final row = Opacity(
      opacity: .75,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
        child: Row(children: [
          faceBox(g, id, locked: true, hid: s.hidden),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [gradeTag(g, id, base: true), const SizedBox(width: 6), Text(s.hidden ? (s.alias ?? '???') : '???', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700))]),
              const SizedBox(height: 3),
              Text(hint, style: Ttc.t(12, color: Ttc.sepia2, height: 1.4)),
            ]),
          ),
          if (where != null) Text('›', style: Ttc.t(22, color: Ttc.sepia2)),
        ]),
      ),
    );
    return where == null ? row : GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => widget.onFly(where), child: row);
  }
}

// ======================= 창(웹 .page) =======================
Future<void> showPageOf(BuildContext context, Game g, Widget Function(BuildContext ctx) body) => showDialog(
      context: context,
      barrierColor: const Color(0xC70F161D),
      builder: (ctx) => Dialog(
        backgroundColor: Ttc.paper,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x66EEE5D3))),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AnimatedBuilder(animation: g, builder: (c, _) => SingleChildScrollView(padding: const EdgeInsets.all(18), child: body(ctx))),
        ),
      ),
    );

Widget pageBtn(String t, VoidCallback? onTap, {bool alt = false}) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onTap == null ? const Color(0xFFDED8CC) : alt ? Colors.transparent : Ttc.amber,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: onTap == null ? const Color(0xFFC9C5BA) : alt ? const Color(0x47252E36) : const Color(0x73252E36)),
          ),
          child: Text(t, textAlign: TextAlign.center, style: Ttc.t(13, color: onTap == null ? const Color(0xFF7F8585) : const Color(0xFF252E36), weight: FontWeight.w700)),
        ),
      ),
    );

Widget _head(Game g, int id, {bool base = false, String? tag}) {
  final s = survivors[id];
  return Column(children: [
    if (tag != null) Align(alignment: Alignment.centerLeft, child: Text(tag, style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600))),
    const SizedBox(height: 6),
    faceBox(g, id, w: 116, h: 135),
    const SizedBox(height: 8),
    Wrap(crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.center, spacing: 6, children: [
      Text(s.name, style: Ttc.t(23, color: Ttc.sepia, weight: FontWeight.w700)),
      gradeTag(g, id, base: base),
    ]),
    Text('${s.age}세 · ${s.job}', style: Ttc.t(12, color: Ttc.sepia2)),
  ]);
}

/// 생존자 상세 (웹 openSurv 4604)
void showSurvPage(BuildContext context, Game g, int id) => showPageOf(context, g, (ctx) {
      final s = survivors[id];
      if (!g.hasSv(id)) return const SizedBox();
      final xp = g.xpOf(id), tl = Game.trustLv(xp), nx = tl < 5 ? trustXp[tl] : 0, pv = trustXp[tl - 1], gc = g.giftCost(id), at = g.atOf(id);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _head(g, id),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var k = 1; k <= 5; k++)
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(shape: BoxShape.circle, color: k <= tl ? Ttc.amber : null, border: Border.all(color: k <= tl ? Ttc.amber : const Color(0xFFC98A2C), width: 1.5)),
            ),
        ]),
        Container(
          height: 5,
          margin: const EdgeInsets.fromLTRB(0, 4, 0, 10),
          decoration: BoxDecoration(color: const Color(0x263B2A1A), borderRadius: BorderRadius.circular(3)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: tl < 5 ? ((xp - pv) / (nx - pv)).clamp(0, 1).toDouble() : 1, child: Container(color: Ttc.amber)),
        ),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '특기: ${g.traitOf(id)} (일터에 있을 때)\n'),
            TextSpan(text: '딱 맞는 일터: ${s.match.map((b) => mods[b]!.n).join(', ')}\n'),
            TextSpan(text: at >= 0 ? '지금 ${g.workName(at)}에서 일하는 중' : '지금은 쉬는 중이에요. 쉘터 모듈을 눌러 배치해 주세요.'),
          ]),
          style: Ttc.t(13, color: Ttc.ok, height: 1.5),
        ),
        const SizedBox(height: 12),
        Text('쉴 때 할 일', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in duties.entries)
            GestureDetector(
              onTap: () {
                g.rec(id)!['duty'] = e.key;
                g.dirty = true;
                g.poke();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: g.dutyOf(id) == e.key ? const Color(0xFFEDD6A6) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: g.dutyOf(id) == e.key ? const Color(0xFFB58B49) : Ttc.line),
                ),
                child: Text('${e.value.$3} ${e.value.$1}', style: Ttc.t(12, color: g.dutyOf(id) == e.key ? Ttc.sepia : Ttc.sepia2, weight: FontWeight.w600)),
              ),
            ),
        ]),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(duties[g.dutyOf(id)]!.$4, style: Ttc.t(11.5, color: Ttc.sepia2))),
        const SizedBox(height: 12),
        for (var k = 0; k < s.story.length; k++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x385A4628)))),
            child: k < tl
                ? Text(s.story[k], style: Ttc.t(14.5, color: const Color(0xFF4A3320), height: 1.5))
                : Text('신뢰도 ${k + 1}에 열려요', style: Ttc.t(12.5, color: const Color(0xFFA8977A))),
          ),
        const SizedBox(height: 14),
        Row(children: [
          if (tl < 5) ...[pageBtn('선물하기 · 식량 ${gc['food']}', g.canPay(gc) ? () => g.gift(id) : null, alt: true), const SizedBox(width: 8)],
          pageBtn('닫기', () => Navigator.pop(ctx)),
        ]),
      ]);
    });

/// 구조 대기·손님 (웹 openCamp 3087)
void showCampPage(BuildContext context, Game g, int tile) => showPageOf(context, g, (ctx) {
      final c = g.S.camp[tile];
      if (c == null) return const SizedBox();
      final id = (c['id'] as num).toInt(), need = g.campNeed(id), bf = g.bedFree, hp = (c['hp'] as num?) ?? 0, mx = (c['max'] as num?) ?? 1;
      final ok = g.canPay(need) && bf > 0 && hp <= 0;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _head(g, id, base: true, tag: c['visit'] == true ? '쉘터 앞의 손님' : '구조 대기'),
        const SizedBox(height: 10),
        Text(rescueNeed[id]!.$2, style: Ttc.t(13.5, color: const Color(0xFF5A3F24), height: 1.6)),
        if (hp > 0) ...[const SizedBox(height: 8), Text('잔해 치우기 ${((1 - hp / mx) * 100).round()}% · 신호 자리를 두드려요', style: Ttc.t(12.5, color: Ttc.sepia2, weight: FontWeight.w600))],
        sec('구조에 필요한 것'),
        costWrap(g, need, lead: [CostChip(label: '빈 침상', have: bf < 0 ? 0 : bf, need: 1)]),
        if (bf <= 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('쉘터를 키우면 침상이 늘어요', style: Ttc.t(12, color: Ttc.sepia2))),
        const SizedBox(height: 14),
        Row(children: [
          pageBtn('나중에', () => Navigator.pop(ctx), alt: true),
          const SizedBox(width: 8),
          pageBtn('구조하기', ok
              ? () {
                  Navigator.pop(ctx);
                  g.doRescue(tile);
                }
              : null),
        ]),
      ]);
    });

/// 새 식구 (웹 rescue 2643)
void showRescuePage(BuildContext context, Game g, int id, String via) => showPageOf(context, g, (ctx) {
      final s = survivors[id];
      final bond = bonds.where((b) => b.ids.contains(id) && b.ids.every(g.hasSv)).firstOrNull;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _head(g, id, tag: via == 'visit' ? '누군가 문을 두드려요' : '구조 신호 · 생존자 발견'),
        const SizedBox(height: 10),
        Text(s.story.first, style: Ttc.t(16, color: Ttc.sepia, height: 1.7)),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '특기: ${g.traitOf(id)}\n딱 맞는 일터: ${s.match.map((b) => mods[b]!.n).join(', ')} (효과 ×2)'),
            if (bond != null) ...[
              const TextSpan(text: '\n'),
              TextSpan(text: '인연 ‘${bond.name}’ ', style: const TextStyle(fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
              TextSpan(text: '${bond.txt} ${bond.d}'),
            ],
          ]),
          style: Ttc.t(13, color: Ttc.ok, height: 1.5),
        ),
        const SizedBox(height: 14),
        Row(children: [pageBtn('마을로 맞이하기', () => Navigator.pop(ctx))]),
      ]);
    });

// ======================= 배치 =======================
Widget assignBody(Game g, int tile, {required VoidCallback onDone}) {
  final m = g.modAtTile(tile), b = m?.id ?? -1;
  final ids = g.svIds.toList()..sort((a, c) => (survivors[c].match.contains(b) ? 1 : 0) - (survivors[a].match.contains(b) ? 1 : 0));
  return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 20), children: [
    if (ids.isEmpty) Padding(padding: const EdgeInsets.all(10), child: Text('아직 구조한 생존자가 없어요. 구름 위로 솟은 흰 빛을 찾아가 보세요.', style: Ttc.t(13, color: Ttc.sepia2, height: 1.5))),
    for (final id in ids)
      () {
        final s = survivors[id], ok = s.match.contains(b), here = g.atOf(id) == tile, at = g.atOf(id);
        final where = g.busy(id) && g.rec(id)?['away'] != null ? '원정 중' : here ? '여기서 일하는 중' : at >= 0 ? '${g.workName(at)}에서 일하는 중' : '쉬는 중';
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x333B2A1A)))),
          child: Row(children: [
            faceBox(g, id, w: 46, h: 54),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 2, children: [
                  Text(s.name, style: Ttc.t(15, color: Ttc.sepia, weight: FontWeight.w700)),
                  gradeTag(g, id),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: ok ? const Color(0xFF6F8F4A) : const Color(0xFFB8A680), borderRadius: BorderRadius.circular(99)),
                    child: Text(ok ? '딱 맞음 ×${(2 + g.pw(id).w).toStringAsFixed(2)}' : '×1.3', style: Ttc.t(11, color: Colors.white)),
                  ),
                ]),
                Text('${s.job} · $where\n${g.traitOf(id)}', style: Ttc.t(12, color: Ttc.sepia2, height: 1.45)),
              ]),
            ),
            const SizedBox(width: 8),
            here
                ? GestureDetector(
                    onTap: () {
                      g.unassign(tile);
                      g.recalc();
                      g.dirty = true;
                      g.poke();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0x47252E36))),
                      child: Text('해제', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
                    ),
                  )
                : BuyButton('배치', width: 56, onTap: g.busy(id)
                    ? null
                    : () {
                        g.assign(tile, id);
                        onDone();
                      }),
          ]),
        );
      }(),
  ]);
}
