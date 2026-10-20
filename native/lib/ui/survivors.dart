// 생존자: 수첩(시트), 상세·구조·손님 창, 배치 목록. 웹 renderSheet('surv'·'assign'), openSurv, openCamp, rescue 를 옮겼다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'cuts_ui.dart';
import 'daily_ui.dart';
import 'gear.dart';
import 'icons.dart';
import 'portrait.dart';
import 'region_ui.dart';
import 'season_ui.dart';
import 'story_ui.dart';
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
  const SurvBody(this.g, {super.key, required this.onOpen, required this.onFly, required this.onBag, required this.onRadio, required this.toast, this.onPets});
  final Game g;
  final void Function(int id) onOpen;
  final void Function(int tile) onFly;
  final VoidCallback onBag, onRadio;
  final VoidCallback? onPets;
  final void Function(String) toast;
  @override
  State<SurvBody> createState() => _SurvBodyState();
}

class _SurvBodyState extends State<SurvBody> {
  static String filter = 'all';
  bool freshOpen = false; // 새 이야기가 여럿이면 한 줄로 접어 둔다 (2026-10-20)
  static String? tool;
  Game get g => widget.g;

  List<int> get idleIds => [for (final id in g.svIds) if (g.atOf(id) < 0 && !g.busy(id) && !(((g.rec(id)?['hurt'] as num?) ?? 0) > 0)) id];

  Widget _svt(String? svg, String label, {String? count, bool on = false, bool onx = false, String? res, required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: on ? Ttc.sepia : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: on ? Ttc.sepia : const Color(0xFFB9C2BC)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (res != null) ResIcon(res, size: 17) else if (svg != null) SvgIcon(svg, size: 18, color: on ? const Color(0xFFF1E5C6) : Ttc.sepia),
            const SizedBox(width: 5),
            Text(label, style: Ttc.t(13, color: on ? const Color(0xFFF1E5C6) : Ttc.sepia, weight: FontWeight.w600, height: 1.2)),
            if (count != null) ...[const SizedBox(width: 5), Text(count, style: Ttc.t(13, color: on ? const Color(0xFFFFD98A) : Ttc.no, weight: FontWeight.w700, height: 1.2))],
            if (onx) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: Ttc.ok, borderRadius: BorderRadius.circular(6)),
                child: Text('켬', style: Ttc.t(11, color: Colors.white, weight: FontWeight.w700, height: 1.2)),
              ),
            ],
          ]),
        ),
      );

  static String _ti(String p) => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">$p</svg>';

  List<Widget> _tools() {
    final idle = idleIds, autoOn = g.S.rest['autoAsg'] == true;
    final bt = <Widget>[
      _svt(null, '라디오', res: 'batt', count: '${g.have('batt').toInt()}', onTap: widget.onRadio),
      hl('bag', _svt(_ti('<path d="M5 8h14l-1 12H6zM9 8V5a3 3 0 0 1 6 0v3"/>'), '장비', count: '${g.inv.length}', onTap: widget.onBag)),
      if (g.pets.isNotEmpty || g.stray != null)
        _svt(_ti('<circle cx="7" cy="9" r="2"/><circle cx="12" cy="6" r="2"/><circle cx="17" cy="9" r="2"/><path d="M8 17c0-3 2-5 4-5s4 2 4 5c0 2-2 3-4 3s-4-1-4-3z"/>'), '펫', count: '${g.pets.length}', onTap: widget.onPets ?? () {}),
      if (g.autoOpen)
        hl('svtool:auto', _svt(_ti('<circle cx="12" cy="12" r="3"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/>'), '자동',
            on: tool == 'auto', onx: autoOn, onTap: () => setState(() => tool = tool == 'auto' ? null : 'auto'))),
      if (idle.isNotEmpty)
        _svt(_ti('<path d="M4 20h16M7 20V10l5-5 5 5v10"/><path d="M10 20v-5h4v5"/>'), '쉬는 사람', count: '${idle.length}', on: tool == 'duty', onTap: () => setState(() => tool = tool == 'duty' ? null : 'duty')),
    ];
    final out = <Widget>[Padding(padding: const EdgeInsets.only(bottom: 10), child: Wrap(spacing: 6, runSpacing: 6, children: bt))];
    if (tool == 'auto' && g.autoOpen) {
      final tiles = g.modAt.length, used = g.S.asg.length;
      out.add(autoBox(
        title: '자동 배치',
        sub: '일터 $used/$tiles · 딱 맞는 사람을 먼저 앉혀요',
        button: BuyButton('지금 맞추기', width: 84, onTap: () {
          final r = g.autoAssign(true);
          widget.toast(r.n == 0 ? '앉힐 사람이나 빈 일터가 없어요' : '${r.n}명 배치 · 딱 맞는 자리 ${r.fit}명');
        }),
        trailing: toggle(autoOn, () {
          g.S.rest['autoAsg'] = !autoOn;
          g.dirty = true;
          widget.toast(!autoOn ? '빈 일터를 자동으로 채워요' : '자동 채우기를 껐어요');
          if (!autoOn) g.autoAssign(false);
          g.poke();
        }),
      ));
      out.add(autoGearBox(g, widget.toast));
    } else if (tool == 'duty' && idle.isNotEmpty) {
      final cnt = <String, int>{};
      for (final id in idle) {
        cnt[g.dutyOf(id)] = (cnt[g.dutyOf(id)] ?? 0) + 1;
      }
      out.add(Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0x0D3B2A1A), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(
              TextSpan(children: [
                TextSpan(text: '쉬는 ${idle.length}명 · '),
                for (final e in cnt.entries) ...[dutySpan(e.key), TextSpan(text: '${e.value} ')],
              ]),
              style: Ttc.t(12.5, color: Ttc.sepia2, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in duties.entries)
              GestureDetector(
                onTap: () {
                  for (final id in idle) {
                    g.rec(id)!['duty'] = e.key;
                  }
                  g.dirty = true;
                  widget.toast('쉬는 생존자 모두 ${e.value.$1}');
                  g.poke();
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 30),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(7), border: Border.all(color: Ttc.line)),
                  child: Text.rich(TextSpan(children: [dutySpan(e.key), TextSpan(text: ' ${e.value.$1}')]), style: Ttc.t(12, color: Ttc.sepia, weight: FontWeight.w500)),
                ),
              ),
          ]),
        ]),
      ));
    }
    return out;
  }

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
      'up': ((id) => g.canPromote(id), '강화 가능'),
    };
    final list = met.where(fl[filter]!.$1).toList();
    final fresh = g.qNew;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 20), children: [
      // 새로 열린 이야기 (앱 전용 2026-10-20: 지도 위 알림 카드 대신 여기와 이야기 띠의 '새 이야기')
      if (fresh.length > 1 && !freshOpen)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => freshOpen = true),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
            decoration: BoxDecoration(color: const Color(0xFFF6EBD0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x59B0452A))),
            child: Row(children: [
              SizedBox(
                width: 34 + 20.0 * (math.min(3, fresh.length) - 1),
                height: 34,
                child: Stack(children: [
                  for (var k = math.min(3, fresh.length) - 1; k >= 0; k--)
                    Positioned(
                      left: 20.0 * k,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE6D8B6), border: Border.all(color: const Color(0xFFF6EBD0), width: 2)),
                        clipBehavior: Clip.antiAlias,
                        child: Portrait(fresh[k], width: 34, height: 40),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '새 이야기 ${fresh.length}개', style: const TextStyle(fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
                    TextSpan(text: ' · ${survivors[fresh[0]].name} 외 ${fresh.length - 1}명', style: const TextStyle(color: Color(0xFF4F5A5F))),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ttc.t(13.5, color: Ttc.sepia, height: 1.35),
                ),
              ),
              Text('펼치기 ›', style: Ttc.t(13, color: Ttc.rust, weight: FontWeight.w700)),
            ]),
          ),
        ),
      if (fresh.length == 1 || (fresh.length > 1 && freshOpen)) ...[
        sec('새로 열린 이야기', '${fresh.length}'),
        for (final id in fresh)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              survTab = 'story';
              widget.onOpen(id);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
              decoration: BoxDecoration(color: const Color(0xFFF6EBD0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x59B0452A))),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE6D8B6)),
                  clipBehavior: Clip.antiAlias,
                  child: Portrait(id, width: 34, height: 40),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${survivors[id].name}의 이야기', style: const TextStyle(fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
                      if (quests[id] != null) TextSpan(text: ' · ${quests[id]!.t}', style: const TextStyle(color: Color(0xFF4F5A5F))),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ttc.t(13.5, color: Ttc.sepia, height: 1.35),
                  ),
                ),
                Text('읽기 ›', style: Ttc.t(13, color: Ttc.rust, weight: FontWeight.w700)),
              ]),
            ),
          ),
        const SizedBox(height: 6),
      ],
      ..._tools(),
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
                  ]), style: Ttc.t(12.5, color: Ttc.sepia, weight: FontWeight.w600)),
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
      ...memorialRows(g),
      if (unmet.isNotEmpty) ...[
        sec('아직 만나지 못한 사람 ${unmet.length}'),
        for (final id in unmet) _unmetRow(id),
      ],
      if (g.kids.isNotEmpty) ...[sec('아이들'), for (final k in g.kids) _kidRow(k)],
      // 등급 표 (2026-10-14: 등급은 처음 그대로, 성급만 오른다)
      sec('등급'),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (var i = 0; i < 4; i++)
            Row(mainAxisSize: MainAxisSize.min, children: [gradeChip(i), Text(' 효과 ×${fmtX(grades[i].m)}', style: Ttc.t(12.5, color: Ttc.sepia2))]),
          Text('등급은 처음 그대로 · 등급마다 1~5성', style: Ttc.t(13, color: Ttc.sepia2)),
        ]),
      ),
      sec('인연'),
      for (final b in bonds) _bondRow(b),
    ]);
  }

  /// 웹 renderSheet 아이들 줄
  Widget _kidRow(Map k) {
    final gr = ((k['g'] as num?) ?? 0).toDouble(), job = k['job'] as String?, look = (k['look'] as Map?) ?? const {};
    Color hx(Object? v, int d) => v is String && v.startsWith('#') && v.length == 7 ? Color(int.parse(v.substring(1), radix: 16) | 0xFF000000) : Color(d);
    const kidCell = {'봄이': 2, '다온': 3, '로운': 4, '하람': 5};
    final n = k['n'] as String? ?? '', ci = kidCell[n];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
      child: Row(children: [
        Container(
          width: 54,
          height: 63,
          decoration: BoxDecoration(color: hx(look['top'], 0xFF8A9A88), borderRadius: BorderRadius.circular(7), border: Border.all(color: Ttc.line)),
          clipBehavior: Clip.antiAlias,
          child: ci != null
              ? CoverPic('crows-kids.webp', Rect.fromLTWH(ci % 3 * 686 + 6, ci ~/ 3 * 764 + 6, 674, 750), alignY: 0)
              : Center(
                  child: Transform.translate(
                      offset: const Offset(0, -10),
                      child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(color: hx(look['skin'], 0xFFE0B48C), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF3B2A1A), width: 1.5))))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: Ttc.t(15, color: Ttc.sepia, weight: FontWeight.w700)),
            Text(
                gr < 1
                    ? '자라는 중 ${(gr * 100).round()}% · 희망 +2'
                    : job != null && kidJobs.containsKey(job)
                        ? '${kidJobs[job]!.$1} · ${kidJobs[job]!.$2}'
                        : '무엇을 배울지 정해 주세요',
                style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
            Container(
              margin: const EdgeInsets.only(top: 2),
              height: 4,
              decoration: BoxDecoration(color: const Color(0x1A252E36), borderRadius: BorderRadius.circular(3)),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: gr.clamp(0, 1).toDouble(), child: Container(decoration: BoxDecoration(color: Ttc.amber, borderRadius: BorderRadius.circular(3)))),
            ),
          ]),
        ),
      ]),
    );
  }

  /// 웹 renderSheet 인연 줄 (모이면 열림 · 누가 떠나면 끊어짐)
  Widget _bondRow(Bond b) {
    final on = b.ids.every(g.hasSv);
    final cut = b.ids.any(g.isDead) && b.ids.every((id) => g.hasSv(id) || g.isDead(id));
    final names = b.ids.map((id) => survivors[id].name).join(' + ');
    final head = cut ? '끊어진 인연 · ${b.name}' : on ? b.name : '???';
    final rest = cut ? ' · $names' : on ? ' · ${b.txt} ${b.d}' : ' · ${b.ids.map((id) => g.hasSv(id) ? survivors[id].name : '???').join(' + ')} 모두 모이면 열려요';
    return Opacity(
      opacity: cut ? .7 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(
            TextSpan(children: [
              TextSpan(text: head, style: TextStyle(fontWeight: FontWeight.w700, fontVariations: const [FontVariation('wght', 700)], color: cut ? Ttc.sepia2 : on ? const Color(0xFF4F6E2F) : Ttc.sepia)),
              TextSpan(text: rest),
            ]),
            style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
      ),
    );
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
              Text(s.job, style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
              Text(() {
                final st = g.statusOf(id), ht = hurtLeft(g, id);
                return st == '다쳐서 쉬는 중' && ht != null ? '$st · $ht 남음' : st;
              }(), style: Ttc.t(12, color: hurt ? Ttc.no : Ttc.ok, weight: FontWeight.w600, height: 1.4)),
            ]),
          ),
          if (g.canPromote(id))
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFFE7EDE3), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFB7C6BC))),
              child: Text('강화 가능', style: Ttc.t(9, color: const Color(0xFF4E6A5B), weight: FontWeight.w600, height: 1)),
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
              Text(hint, style: Ttc.t(13, color: Ttc.sepia2, height: 1.4)),
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
      // 2026-10-21 대표님: 창이 길어 닫는 법을 찾아야 했다 → 오른쪽 위에 늘 보이는 닫기(X), 위아래 여백, 바깥을 눌러도 닫힘
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Ttc.paper,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x66EEE5D3))),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Stack(children: [
            AnimatedBuilder(animation: g, builder: (c, _) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 18), child: body(ctx))),
            Positioned(top: 6, right: 6, child: CloseX(onTap: () => Navigator.of(ctx).maybePop())),
          ]),
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
    if (tag != null) Align(alignment: Alignment.centerLeft, child: Text(tag, style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600))),
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

/// 생존자 상세 (웹 openSurv 4604): 머리 + 정보·성장·장비·이야기 탭
String survTab = 'info';
String _pct(({double m, double w, double cd}) p) => '특기 효과 ×${p.m.toStringAsFixed(2)} · 딱 맞는 일터 ×${(2 + p.w).toStringAsFixed(2)} · 스킬 대기 -${((1 - p.cd) * 100).round()}%';

void showSurvPage(BuildContext context, Game g, int id0, {void Function(int id, String slot)? onGear}) {
  var id = id0;
  // 장비 맞추기 걸음에서는 장비 탭부터 (웹 4607)
  if (g.S.gen == 0 && g.mi == stepI('생존자에게 장비 하나 맞춰 주기') && survTab == 'info') survTab = 'gear';
  showPageOf(context, g, (ctx) => StatefulBuilder(builder: (ctx, set) {
        if (!g.hasSv(id)) return const SizedBox();
        final s = survivors[id], r = g.rec(id)!;
        final xp = g.xpOf(id), tl = Game.trustLv(xp), nx = tl < 5 ? trustXp[tl] : 0, pv = trustXp[tl - 1], gc = g.giftCost(id), at = g.atOf(id), p = g.pw(id);
        final hurt = ((r['hurt'] as num?) ?? 0) > 0;
        final hurtT = hurtLeft(g, id);
        final where = isAwayVal(r['away']) ? '원정 중' : hurt ? '다쳐서 치료 중${hurtT != null ? ' · $hurtT 남음' : ''}' : at >= 0 ? '${g.workName(at)}에서 일하는 중' : duties[g.dutyOf(id)]!.$2;
        final narrow = MediaQuery.of(ctx).size.width < 381;
        final pfW = narrow ? 104.0 : 116.0;
        final ids = g.svIds.toList();
        // 이야기 탭을 보면 '새 이야기'를 읽은 것으로 (다른 탭에 있으면 이야기 탭에 점)
        if (survTab == 'story') g.qSeen(id);
        final tabs = [('info', '정보', false), ('grow', '성장', g.canPromote(id)), ('gear', '장비', false), ('story', '이야기', g.qNew.contains(id))];
        final Widget body = switch (survTab) {
          'grow' => _growTab(g, id, p, ctx),
          'gear' => _gearTab(g, id, onGear == null ? null : (sl) {
              Navigator.pop(ctx);
              onGear(id, sl);
            }),
          'story' => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              questBox(g, id),
              for (var k = 0; k < s.story.length; k++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
                  child: k < tl
                      ? Text(s.story[k], style: Ttc.serif(14.5, color: const Color(0xFF4A3320), height: 1.6))
                      : Text('신뢰도 ${k + 1}에 열려요', style: Ttc.t(12.5, color: const Color(0xFFA8977A))),
                ),
              if (id == 12 && tl >= 2) watchButton(ctx, g),
              for (final c in survivorCuts(id))
                if (g.cutSeen(c.$1)) Align(alignment: Alignment.centerLeft, child: cutReplayButton(ctx, c.$1, c.$2, label: c.$3)),
            ]),
          _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _sline('특기', g.traitOf(id)),
              _sline('일터', s.match.map((b) => mods[b]!.n).join(', ')),
              _sline('스킬', '${skills[id].n} · ${skills[id].d}'),
              _dutyBox(g, id, set),
            ]),
        };
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: pfW,
              height: pfW * 1.17,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Ttc.line)),
              clipBehavior: Clip.antiAlias,
              child: faceBox(g, id, w: pfW, h: pfW * 1.17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: Ttc.t(narrow ? 22 : 24, color: Ttc.sepia, weight: FontWeight.w700, height: 1.15)),
                const SizedBox(height: 6),
                gradeTag(g, id),
                const SizedBox(height: 3),
                Text('${s.age}세 · ${s.job}', style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: hurt && !isAwayVal(r['away']) ? Ttc.noBg : const Color(0x0F252E36), borderRadius: BorderRadius.circular(5)),
                  child: Text(where,
                      style: Ttc.t(11, color: hurt && !isAwayVal(r['away']) ? Ttc.no : at >= 0 && !isAwayVal(r['away']) ? Ttc.ok : Ttc.sepia2, weight: FontWeight.w600, height: 1.2)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  for (var k = 1; k <= 5; k++)
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: k <= tl ? Ttc.amber : null, border: Border.all(color: k <= tl ? const Color(0xFFB28540) : const Color(0xFF9A824E))),
                    ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0x1A252E36), borderRadius: BorderRadius.circular(3)),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(widthFactor: tl < 5 ? ((xp - pv) / (nx - pv)).clamp(0, 1).toDouble() : 1, child: Container(color: Ttc.amber)),
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                Text('신뢰도 $tl/5', style: Ttc.t(11, color: Ttc.sepia2)),
              ]),
            ),
          ]),
          if (ids.length > 1)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              for (final d in const [-1, 1])
                GestureDetector(
                  onTap: () => set(() => id = ids[(ids.indexOf(id) + d + ids.length) % ids.length]),
                  child: Container(
                    width: 36,
                    height: 32,
                    margin: const EdgeInsets.only(left: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x333B2A1A), width: 1.5)),
                    child: Text(d < 0 ? '‹' : '›', style: Ttc.t(17, color: Ttc.sepia, weight: FontWeight.w700, height: 1)),
                  ),
                ),
            ])
          else
            const SizedBox(height: 14),
          const SizedBox(height: 4),
          Segs(
            items: [for (final t in tabs) t.$2],
            dots: [for (final t in tabs) t.$3],
            on: tabs.indexWhere((t) => t.$1 == survTab).clamp(0, 3),
            onTap: (k) => set(() => survTab = tabs[k].$1),
          ),
          body,
          const SizedBox(height: 12),
          Row(children: [
            pageBtn(g.party.contains(id) ? '스킬 바 빼기' : '스킬 바에 넣기', () {
              if (!g.party.contains(id) && g.party.length >= 3) {
                g.fx.add(const FxToast('스킬 바는 3명까지예요'));
                g.poke();
                return;
              }
              g.toggleParty(id);
            }, alt: true),
            if (tl < 5) ...[const SizedBox(width: 8), pageBtn('선물 · 식량 ${gc['food']}', g.canPay(gc) ? () => g.gift(id) : null)],
            // 신뢰도 5 뒤: 인연 선물 (하루 한 번)
            if (tl >= 5 && g.bondLv(id) < 5) ...[
              const SizedBox(width: 8),
              pageBtn(g.bondGiftedToday(id) ? '오늘 선물함 · 내일 또' : '인연 선물 · 식량 ${bondGiftCost['food']}',
                  !g.bondGiftedToday(id) && g.canPay(bondGiftCost) ? () => g.gift(id) : null),
            ],
          ]),
        ]);
      }));
}

Widget _sline(String b, String t) => Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 38, child: Text(b, style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700, height: 1.5))),
        const SizedBox(width: 12),
        Expanded(child: Text(t, style: Ttc.t(13, color: Ttc.sepia2, height: 1.6))),
      ]),
    );

Widget _dutyBox(Game g, int id, StateSetter set) {
  final cur = g.dutyOf(id), idle = g.atOf(id) < 0 && !g.busy(id);
  return Padding(
    padding: const EdgeInsets.only(top: 11),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 38, child: Padding(padding: const EdgeInsets.only(top: 9), child: Text('쉴 때', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)))),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(spacing: 5, runSpacing: 5, children: [
            for (final e in duties.entries)
              GestureDetector(
                onTap: () {
                  g.rec(id)!['duty'] = e.key;
                  g.dirty = true;
                  set(() {});
                  g.poke();
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 38),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: cur == e.key ? const Color(0xFFD9E3DB) : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: cur == e.key ? const Color(0xFF5D7667) : Ttc.line),
                  ),
                  child: Text.rich(TextSpan(children: [dutySpan(e.key), TextSpan(text: ' ${e.value.$1}')]),
                      style: Ttc.t(12.5, color: cur == e.key ? const Color(0xFF2E4438) : Ttc.sepia2, weight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(50, 4, 0, 0),
        child: Text('${duties[cur]!.$4}${idle ? ' · 지금 하는 중' : ''}', style: Ttc.t(13, color: Ttc.sepia2, height: 1.4)),
      ),
    ]),
  );
}

/// 웹 needHtml: 모자란 자재는 한 줄씩, 넉넉한 자재는 한 줄로
Widget needList(Game g, Cost c) {
  final no = c.entries.where((e) => g.have(e.key) < e.value).toList(), ok = c.entries.where((e) => g.have(e.key) >= e.value).toList();
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    for (final e in no)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          ResIcon(e.key, size: 13),
          const SizedBox(width: 4),
          Text(matOf[e.key]?.n ?? e.key, style: Ttc.t(12.5, color: Ttc.no, weight: FontWeight.w700, height: 1.5)),
          Text(' ${fmt(g.have(e.key))}/${fmt(e.value)}', style: Ttc.t(12.5, color: Ttc.sepia, height: 1.5)),
          const Spacer(),
          Text(matOf[e.key]?.s2 ?? '', style: Ttc.t(11, color: Ttc.sepia2)),
        ]),
      ),
    if (ok.isNotEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (var k = 0; k < ok.length; k++) ...[
            if (k > 0) Text(' · ', style: Ttc.t(12, color: Ttc.ok)),
            ResIcon(ok[k].key, size: 13),
            Text('${matOf[ok[k].key]?.n ?? ok[k].key} ${fmt(ok[k].value)}', style: Ttc.t(12, color: Ttc.ok)),
          ],
          Text(' ✓', style: Ttc.t(12, color: Ttc.ok)),
        ]),
      ),
  ]);
}

Widget _growTab(Game g, int id, ({double m, double w, double cd}) p, BuildContext ctx) {
  final gr = g.gradeOf(id), mg = gr, n = g.nextStep(id), tl = Game.trustLv(g.xpOf(id));
  Widget tile(String b, String s) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(7), border: Border.all(color: Ttc.line)),
          child: Column(children: [
            Text(b, style: Ttc.serif(17, color: Ttc.sepia, weight: FontWeight.w700, height: 1.1)),
            const SizedBox(height: 2),
            Text(s, style: Ttc.t(11, color: Ttc.sepia2)),
          ]),
        ),
      );
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const SizedBox(height: 4),
    Row(children: [
      tile('×${p.m.toStringAsFixed(2)}', '특기 효과'),
      const SizedBox(width: 6),
      tile('×${(2 + p.w).toStringAsFixed(2)}', '딱 맞는 일터'),
      const SizedBox(width: 6),
      tile('-${((1 - p.cd) * 100).round()}%', '스킬 대기'),
    ]),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Ttc.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [gradeTag(g, id), const Spacer(), Text('최대 ${grades[mg].n} 5성', style: Ttc.t(12, color: Ttc.sepia2))]),
        if (n == null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text('${grades[mg].n} 5성, 더 오를 곳이 없어요', style: Ttc.t(12.5, color: Ttc.sepia2)))
        else
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x4D3B2A1A)))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(n.$4, style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700, height: 1.4)),
              const SizedBox(height: 2),
              Text('→ ${_pct(n.$1 == 'star' ? g.pwAt(gr, g.starOf(id) + 1) : g.pwAt(gr + 1, 1))}', style: Ttc.t(13, color: Ttc.sepia2, height: 1.45)),
              const SizedBox(height: 4),
              Row(children: [
                Text('신뢰도', style: Ttc.t(12.5, color: tl >= n.$2 ? Ttc.ok : Ttc.no, weight: FontWeight.w700, height: 1.5)),
                Text(' $tl/${n.$2}${tl >= n.$2 ? ' ✓' : ''}', style: Ttc.t(12.5, color: tl >= n.$2 ? Ttc.ok : Ttc.sepia, height: 1.5)),
                const Spacer(),
                if (tl < n.$2) Text('일터에 배치하거나 선물해요', style: Ttc.t(11, color: Ttc.sepia2)),
              ]),
              needList(g, n.$3),
              const SizedBox(height: 8),
              Row(children: [
                pageBtn(n.$1 == 'star' ? '성급 올리기' : '등급 올리기', g.canPromote(id)
                    ? () {
                        if (g.promote(id) == 'grade') showGradeUp(ctx, g, id);
                      }
                    : null, alt: true),
              ]),
            ]),
          ),
      ]),
    ),
    bondBox(ctx, g, id),
  ]);
}

void showGradeUp(BuildContext context, Game g, int id) {
  final s = survivors[id], gr = g.gradeOf(id);
  const lines = ['“이 정도면 믿고 맡겨도 되겠죠?” {n}의 눈빛이 달라졌어요.', '{n}은(는) 이제 쉘터에 없어서는 안 될 사람이 됐어요.', '{n}의 이야기는 이제 쉘터의 전설이 됐어요.'];
  showPageOf(context, g, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('등급 승급', style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Center(child: faceBox(g, id, w: 116, h: 135)),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
          Text(s.name, style: Ttc.t(22, color: Ttc.sepia, weight: FontWeight.w700)),
          gradeTag(g, id),
        ]),
        const SizedBox(height: 8),
        Text(lines[(gr - 1).clamp(0, 2)].replaceAll('{n}', s.name), textAlign: TextAlign.center, style: Ttc.serif(15, color: Ttc.sepia, height: 1.6)),
        const SizedBox(height: 8),
        Text(_pct(g.pw(id)), textAlign: TextAlign.center, style: Ttc.t(12.5, color: Ttc.ok, weight: FontWeight.w600, height: 1.5)),
        const SizedBox(height: 14),
        Row(children: [pageBtn('좋아요', () => Navigator.pop(ctx))]),
      ]));
}

Widget _gearTab(Game g, int id, void Function(String slot)? onSlot) {
  final q = g.eqOf(id);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Ttc.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text.rich(TextSpan(children: [
        const TextSpan(text: '장비 '),
        TextSpan(text: ' 일터에 있을 때 효과가 나요', style: Ttc.t(11, color: Ttc.sepia2)),
      ]), style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700, height: 1.4)),
      const SizedBox(height: 4),
      for (final sl in slotKeys)
        () {
          final it = g.itemAt(q[sl]);
          final G = it == null ? null : gear[it['t']];
          final fit = G != null && G.fit.contains(id);
          return GestureDetector(
            onTap: onSlot == null ? null : () => onSlot(sl),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFF8F3E6), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x2926333B))),
              child: Row(children: [
                G == null ? const GearIcon(null, size: 30) : GearIcon(it!['t'] as String, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(G?.n ?? slotName[sl]!, style: Ttc.t(13.5, color: Ttc.sepia, weight: FontWeight.w700)),
                    Text(G == null ? '비어 있음' : '${effText({for (final e in G.eff.entries) e.key: e.value * (fit ? 1.5 : 1)})}${fit ? ' · 잘 맞음' : ''}',
                        style: Ttc.t(11.5, color: const Color(0xFF56646A), height: 1.4)),
                  ]),
                ),
                Text('›', style: Ttc.t(18, color: Ttc.sepia2)),
              ]),
            ),
          );
        }(),
    ]),
  );
}

/// 구조 대기·손님 (웹 openCamp 3087)
void showCampPage(BuildContext context, Game g, int tile) => showPageOf(context, g, (ctx) {
      final c = g.S.camp[tile];
      if (c == null) return const SizedBox();
      final id = (c['id'] as num).toInt(), need = g.campNeed(id), bf = g.bedFree(id), hp = (c['hp'] as num?) ?? 0, mx = (c['max'] as num?) ?? 1;
      final ok = g.canPay(need) && bf > 0 && hp <= 0;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _head(g, id, base: true, tag: c['visit'] == true ? '쉘터 앞의 손님' : '구조 대기'),
        const SizedBox(height: 10),
        Text(rescueNeed[id]!.$2, style: Ttc.t(13.5, color: const Color(0xFF5A3F24), height: 1.6)),
        if (hp > 0) ...[const SizedBox(height: 8), Text('잔해 치우기 ${((1 - hp / mx) * 100).round()}% · 신호 자리를 두드려요', style: Ttc.t(12.5, color: Ttc.sepia2, weight: FontWeight.w600))],
        sec('구조에 필요한 것'),
        costWrap(g, need, lead: [CostChip(label: '빈 침상', have: bf < 0 ? 0 : bf, need: 1)]),
        if (bf <= 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('쉘터를 키우면 침상이 늘어요', style: Ttc.t(13, color: Ttc.sepia2))),
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
Future<void> showRescuePage(BuildContext context, Game g, int id, String via) => showPageOf(context, g, (ctx) {
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
                Text('${s.job} · $where\n${g.traitOf(id)}', style: Ttc.t(13, color: Ttc.sepia2, height: 1.45)),
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

/// 1.0 → '1', 1.5 → '1.5' (웹 숫자 표기)
String fmtX(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
