// 앱 전용 화면 (2026-10-18): 오늘의 할 일·연속 칸(일지 기록 탭 위 · 아침 보고 끝), 그날 밤의 기록 조각(일지 기록 탭), 인연(생존자 성장 탭).
import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'icons.dart';
import 'story_ui.dart';
import 'theme.dart';
import 'widgets.dart';

// ======================= 오늘의 할 일 =======================
/// 연속 칸: 7개, 7번째는 귀한 장비
Widget streakRow(Game g) {
  final n = g.streakShown, today = g.dayAllDone;
  return Row(children: [
    for (var k = 0; k < 7; k++) ...[
      if (k > 0) const SizedBox(width: 4),
      Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: k < n ? (k == 6 ? const Color(0xFFE0B441) : Ttc.amber) : null,
              border: Border.all(color: k < n ? const Color(0xFFB28540) : k == 6 ? const Color(0xFFC9861A) : const Color(0xFF9A824E), width: k == 6 ? 2 : 1.2),
            ),
            child: k == 6
                ? SvgIcon(Ico.gift, size: 12, color: k < n ? const Color(0xFF3B2A1A) : const Color(0xFFC9861A))
                : k < n
                    ? const SvgIcon(Ico.check, size: 12, color: Color(0xFF3B2A1A))
                    : null,
          ),
          const SizedBox(height: 2),
          Text('${k + 1}일', style: Ttc.t(10, color: k == n - 1 && today ? Ttc.rust : Ttc.sepia2, weight: k == n - 1 && today ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    ],
  ]);
}

/// 일지 기록 탭 맨 위: 오늘의 할 일 3개 + 연속 칸
List<Widget> dailySection(Game g) {
  if (!g.dayOn) return const [];
  final list = g.dayList;
  if (list.isEmpty) return const [];
  final done = list.where((x) => x.$4).length;
  return [
    Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF6DC), Color(0xFFF6E7C3)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x59B0452A), width: 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text('오늘의 할 일 $done/${list.length}', style: Ttc.t(15, color: const Color(0xFF7A3A1C), weight: FontWeight.w700))),
          Text('연속 ${g.streakShown}일', style: Ttc.t(13, color: Ttc.sepia2, weight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        for (final (t, p, n, ok) in list)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? Ttc.ok : null, border: Border.all(color: ok ? Ttc.ok : const Color(0xFF9A824E), width: 1.2)),
                child: ok ? const SvgIcon(Ico.check, size: 12, color: Color(0xFFFFFFFF)) : null,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(t, style: Ttc.t(13, color: ok ? Ttc.sepia2 : Ttc.sepia, weight: FontWeight.w600, height: 1.35))),
              const SizedBox(width: 6),
              Text(ok ? '완료' : '$p/$n', style: Ttc.t(12.5, color: ok ? Ttc.ok : Ttc.sepia2, weight: FontWeight.w700)),
            ]),
          ),
        const SizedBox(height: 8),
        streakRow(g),
        const SizedBox(height: 6),
        Text(g.dayAllDone ? '오늘 몫은 끝 · 내일 새 할 일이 와요' : '하나마다 건전지 1 · 셋 다 하면 연속 하루 · 7일째엔 귀한 장비 · 하루 걸러도 벌은 없어요',
            style: Ttc.t(13, color: Ttc.sepia2, height: 1.45)),
      ]),
    ),
  ];
}

/// 아침 보고 끝에 붙는 작은 오늘의 할 일 (앱 전용 2026-10-20). 아직 열리지 않았거나 목록이 없으면 null
Widget? dailyMini(Game g) {
  if (!g.dayOn) return null;
  final list = g.dayList;
  if (list.isEmpty) return null;
  final done = list.where((x) => x.$4).length;
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
    decoration: BoxDecoration(color: const Color(0xFFF6EBD0), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x59B0452A))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: Text('오늘의 할 일 $done/${list.length}', style: Ttc.t(14, color: const Color(0xFF7A3A1C), weight: FontWeight.w700))),
        Text('연속 ${g.streakShown}일', style: Ttc.t(13, color: Ttc.sepia2, weight: FontWeight.w700)),
      ]),
      for (final (t, p, n, ok) in list)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? Ttc.ok : null, border: Border.all(color: ok ? Ttc.ok : const Color(0xFF9A824E), width: 1.2)),
              child: ok ? const SvgIcon(Ico.check, size: 11, color: Color(0xFFFFFFFF)) : null,
            ),
            const SizedBox(width: 7),
            Expanded(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ttc.t(13, color: ok ? Ttc.sepia2 : Ttc.sepia, weight: FontWeight.w600, height: 1.3))),
            const SizedBox(width: 6),
            Text(ok ? '완료' : '$p/$n', style: Ttc.t(12.5, color: ok ? Ttc.ok : Ttc.sepia2, weight: FontWeight.w700)),
          ]),
        ),
    ]),
  );
}

// ======================= 그날 밤의 기록 조각 =======================
List<Widget> fragSection(BuildContext context, Game g) {
  final got = g.fragsGot;
  if (got.isEmpty && g.ugBest < ugDeep) return const [];
  return [
    sec('그날 밤의 기록 조각', '${got.length}/${frags.length}'),
    if (got.isEmpty) descText('지하 $ugDeep층보다 더 깊은 곳에 사람들의 그날 밤이 흩어져 있어요. 10층마다 깊은 곳의 재괴물이 하나씩 지켜요.'),
    for (var k = 0; k < frags.length; k++)
      if (got.contains(k))
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showTalk(context, g, g.fragTalk(k)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${got.indexOf(k) + 1}. ${frags[k].$2}', style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700, height: 1.4)),
                  Text('${survivors[frags[k].$1].name}의 그날 밤 · 눌러서 다시 읽기', style: Ttc.t(13, color: Ttc.sepia2, height: 1.4)),
                ]),
              ),
              Text('›', style: Ttc.t(20, color: Ttc.sepia2)),
            ]),
          ),
        ),
    if (got.isNotEmpty && got.length < frags.length)
      Opacity(
        opacity: .5,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text('남은 조각 ${frags.length - got.length}개 · 깊은 지하 어딘가', style: Ttc.t(12.5, color: Ttc.sepia2)),
        ),
      ),
  ];
}

// ======================= 인연 (생존자 성장 탭) =======================
Widget bondBox(BuildContext context, Game g, int id) {
  if (Game.trustLv(g.xpOf(id)) < 5) return const SizedBox.shrink();
  final b = g.bondLv(id), seen = g.bondSeen(id), nx = g.bondNext(id), gt = bondGearOf[id];
  return Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(color: const Color(0xFFFBF1E4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x59B0452A))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('인연 Lv.$b', style: Ttc.t(14, color: const Color(0xFF7A3A1C), weight: FontWeight.w700)),
        const SizedBox(width: 8),
        for (var k = 1; k <= 5; k++)
          Padding(
            padding: const EdgeInsets.only(right: 1.5),
            child: SvgIcon(k <= b ? Ico.heart : Ico.heartO, size: 13, color: k <= b ? const Color(0xFFC0503A) : const Color(0xFFB79A84)),
          ),
        const Spacer(),
        Text(nx == null ? '가장 깊은 인연' : '${fmt(nx.$1)}/${fmt(nx.$2)}', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
      ]),
      const SizedBox(height: 5),
      Container(
        height: 5,
        decoration: BoxDecoration(color: const Color(0x1A252E36), borderRadius: BorderRadius.circular(3)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: nx == null ? 1 : (nx.$1 / nx.$2).clamp(0, 1).toDouble(),
          child: Container(decoration: BoxDecoration(color: const Color(0xFFC0503A), borderRadius: BorderRadius.circular(3))),
        ),
      ),
      const SizedBox(height: 5),
      Text('일터에서 함께할수록, 하루 한 번 인연 선물(식량 ${bondGiftCost['food']} · 인연 +$bondGiftXp)로 깊어져요${gt != null && b < 3 ? ' · Lv.3에 고유 장비 ‘${gear[gt]?.n ?? ''}’' : ''}',
          style: Ttc.t(13, color: Ttc.sepia2, height: 1.45)),
      for (var lv = 1; lv <= seen; lv++)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showTalk(context, g, g.bondTalk(id, lv)),
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF8F3E6), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x2926333B))),
            child: Row(children: [
              SvgIcon(Ico.heart, size: 12, color: const Color(0xFFC0503A).withValues(alpha: .8)),
              const SizedBox(width: 6),
              Expanded(child: Text('$lv. ${g.bondScene(id, lv).$1}', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w600))),
              Text('다시 보기 ›', style: Ttc.t(12.5, color: Ttc.sepia2)),
            ]),
          ),
        ),
      if (b < 5)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('다음 이야기 · 인연 Lv.${b + 1}에 열려요', style: Ttc.t(13, color: const Color(0xFF8C7B5E))),
        ),
    ]),
  );
}
