// 5단계 화면: 미션 띠(웹 #tape), 대화 창(.page.talk), 재혁의 고백, 길잡이 화살표(#guide)·강조(.hl),
// 등불 탑 카드(.tower), 일지의 이야기·업적 탭과 설정의 안내서. 웹 index.html 1880–2107, 4086–4104, 4372–4392, 5075–5106.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/web_data.g.dart' as web;
import '../game/data.dart';
import '../game/engine.dart';
import 'atlas.dart';
import 'daily_ui.dart';
import 'portrait.dart';
import 'profile_ui.dart';
import 'season_ui.dart';
import 'crisis_ui.dart' show sqShort;
import 'feat_ui.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';

// ======================= 열린 창 세기 =======================
/// 지금 떠 있는 창(대화·카드) 수. 이야기 장면은 창이 다 닫혔을 때만 연다 (웹 modal.hidden).
class PageWatch extends NavigatorObserver {
  int n = 0;
  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PopupRoute) n++;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (route is PopupRoute) n = math.max(0, n - 1);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    if (route is PopupRoute) n = math.max(0, n - 1);
  }
}

final pageWatch = PageWatch();

// ======================= 강조 (웹 .hl) =======================
/// 지금 눌러야 할 버튼 (미션의 hl). 버튼 쪽에서 hl(key, child)로 감싸 두면 깜빡인다.
final ValueNotifier<String?> hlKey = ValueNotifier(null);

/// 웹 hl 선택자 → 화면 키
String? hlOf(String? sel) {
  if (sel == null) return null;
  final m = RegExp(r'\[data-act="(\w+)"\](?:\[data-arg="(\w+)"\])?').firstMatch(sel);
  if (sel.contains('data-cb="0"')) return 'craft:0';
  if (m == null) return null;
  final a = m.group(1)!, arg = m.group(2);
  return sel.startsWith('#ring') ? 'ring:$a' : (arg == null ? a : '$a:$arg');
}

/// 새 기능 카드 '보러 가기'가 가리키는 버튼 (웹 featGo .fchl, 4.2초). 보이게 스크롤도 한다
final ValueNotifier<String?> featHlKey = ValueNotifier(null);

/// 새 기능 → 강조할 버튼 키 (웹 FEAT_GUIDE sel/txt)
const featHlOf = {
  'radio': 'pull:1', 'bag': 'bag', 'ug': 'ugprep', 'auto': 'svtool:auto', 'autoexp': 'autoexp', 'acraft': 'acr',
  'trade': 'sec:trade', 'migrate': 'migrate', 'line': 'lnprep', 'fire': 'firechip',
};

Widget hl(String key, Widget child, {double radius = 8}) => AnimatedBuilder(
      animation: Listenable.merge([hlKey, featHlKey]),
      builder: (c, _) => featHlKey.value == key
          ? _Pulse(radius: radius, scroll: true, child: child)
          : hlKey.value == key
              ? _Pulse(radius: radius, child: child)
              : child,
    );

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child, required this.radius, this.scroll = false});
  final Widget child;
  final double radius;
  final bool scroll; // 새 기능 안내: 화면 가운데로 굴려 보여 준다 (웹 scrollIntoView center)
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void initState() {
    super.initState();
    if (widget.scroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Scrollable.ensureVisible(context, alignment: .5, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: a,
        builder: (c, child) {
          final t = math.sin(a.value * math.pi); // 0 → 1 → 0 (웹 hlp 50%)
          return DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.radius), boxShadow: [
              BoxShadow(color: Color.fromRGBO(243, 165, 58, .75 * t), spreadRadius: 5 * t),
              BoxShadow(color: Color.fromRGBO(243, 165, 58, .8 * t), blurRadius: 18 * t),
            ]),
            child: child,
          );
        },
        child: widget.child,
      );
}

// ======================= 미션 띠 (웹 #tape, design.css 16–18) =======================
// 2026-11-03 대표님 결정 'A안': 위쪽은 쉘터 레벨(작게) · '지금 ›' 한 줄(두 줄까지 줄바꿈 · 말줄임 없음) · 오른쪽 배지 하나(할 일 수)만.
// 장 목표·생존자의 부탁·오늘의 할 일·노친네·새 동네로 같은 칩은 배지를 누르면 펼쳐지는 목록(TapePanel)으로 모았다.
// 목표를 다 하면 '지금' 줄이 그대로 '받기' 버튼이 된다. 모닥불은 살아 움직이는 눈금이라 띠 안에 작게 남긴다.

/// 장 이름 · 걸음 (예: ('3장', '2/5'))
(String, String) tapeChap(Game g) {
  final S = g.S, m = g.mission(), st = m.step, c = st == null ? null : chapters[st.ci];
  final tu = g.tut;
  if (tu != null) return ('그날 밤', '${((tu['i'] as num?) ?? 0) + 1}/${tutSteps.length}');
  if (c != null) return (c.ch, '${st!.si + 1}/${c.steps.length}');
  if (m.s2) return (g.s2StageName, '${g.s2I + 1}/${g.s2StepCount}');
  if (m.reg) return (g.reg?.n ?? '', '${g.rmi + 1}/${g.regionMis().length}');
  return ('끝없는 불빛', '${(((S.rest['eg'] as Map?)?['i'] as num?) ?? 0) + 1}');
}

/// 지금 할 일 한 줄 (길잡이 화살표와 같은 말): 목표 글만으로는 무엇을 누를지 모를 때 (2026-10-23 UX)
String? tapeStep(Game g) {
  if (g.tut != null || g.mission().done) return null;
  final t = guideTarget(g)?.label;
  if (t != null && t.isNotEmpty && t != '쉘터' && t != '모듈') return t;
  // 화살표가 쉘터·모듈만 가리킬 때는 이 걸음의 귀띔 (예: '밧줄은 작업대에서 천으로 만들어요')
  final sub = g.mission().sub;
  return sub.isEmpty ? null : uiWords(sub);
}

/// 돌아와 짐 풀기를 기다리는 원정대 수
int tapeExpBack(Game g) {
  final now = Game.nowMs();
  return g.expMap.values.where((x) => now >= ((x['end'] as num?) ?? 1e15)).length;
}

/// 시즌 2 아침의 흔적: 사건 수첩에 새로 적힌 것이 있나
bool tapeTrace(Game g) => g.s2On && g.S.rest['caseNew'] != null && g.s2Traces.isNotEmpty;

/// 시즌 2 아침의 흔적: 지도에서 아직 반짝이는 것이 있나
bool tapeTraceMap(Game g) => g.s2On && g.s2TraceTiles.isNotEmpty;

/// '지금' 줄에 올릴 것 (종류, 글). 우선순위: 받을 보상 → 위기(대형 재폭풍 · 정답 없는 선택) → 돌아온 원정(시즌 2)
/// → 장 목표의 다음 걸음 → 아침의 흔적(시즌 2) → 생존자의 부탁. 아무것도 없으면 장 목표 글 그대로
(String, String) tapeNow(Game g) {
  final m = g.mission();
  if (g.tut != null) return ('tut', m.txt);
  if (m.done) return ('claim', m.txt);
  final q0 = g.sq, t00 = q0 == null ? null : sqTypes[q0['k']];
  final (q, t0) = q0 != null && g.sqOn && t00 != null ? (q0, t00) : (null, null);
  if (q != null && t0 != null && g.sqDone) {
    final who = (q['who'] as num?)?.toInt() ?? -1;
    return ('sqclaim', '${g.hasSv(who) ? survivors[who].name : '쉘터'}의 부탁을 다 했어요 · ${sqShort(t0.t(((q['n'] as num?) ?? 1).toInt()))}');
  }
  if (g.defn != null) return ('storm', '대형 재폭풍 · 랜턴을 눌러 쉘터로 오는 괴물을 막아요');
  final cv = choiceShowing ? null : g.choiceView();
  if (cv != null) {
    final dl = duskLeft(g);
    return ('choice', '${cv.title} · 정답 없는 선택${dl != null ? ' · 해 질 때까지 $dl' : ''}');
  }
  if (g.s2On) {
    final n = tapeExpBack(g);
    if (n > 0) return ('exp', '원정대 $n팀이 돌아와 짐 풀기를 기다려요');
  }
  final st = tapeStep(g);
  if (st != null) return ('goal', st);
  if (tapeTraceMap(g)) return ('trace', '지도에 아침의 흔적이 반짝여요 · 눌러서 살펴봐요');
  if (tapeTrace(g)) return ('case', '아침의 흔적이 사건 수첩에 적혔어요');
  if (q != null && t0 != null) {
    final n = ((q['n'] as num?) ?? 1).toInt();
    return ('sq', '${sqShort(t0.t(n))} ${fmt(g.sqProg())}/${fmt(n)}');
  }
  return ('goal', m.txt);
}

/// 펼친 목록의 한 줄
class TapeItem {
  const TapeItem(this.k, this.title, {this.tag = '', this.sub = '', this.btn, this.hot = false, this.lead});
  final String k; // goal · choice · stories · sq · daily · ped · mig · exp · case
  final String tag, title, sub;
  final String? btn;
  final bool hot; // 받을 것 · 급한 것 (호박색 테두리)
  final Widget? lead;
}

/// 배지 목록: 장 목표가 맨 위, 그 아래 할 일. 튜토리얼 동안은 비어 있다
List<TapeItem> tapeItems(Game g) {
  if (g.tut != null) return const [];
  final m = g.mission(), st = m.step, c = st == null ? null : chapters[st.ci];
  final (cn, cp) = tapeChap(g);
  final out = <TapeItem>[
    TapeItem('goal', m.txt,
        tag: '${c != null ? '${c.ch} · ${c.title}' : cn}  $cp',
        sub: m.done ? '다 했어요 · 눌러서 보상을 받아요' : uiWords(m.sub),
        btn: m.done ? '받기' : '보기',
        hot: m.done,
        lead: _dot(m.done ? Ttc.amber : const Color(0xFF8FA3AE))),
  ];
  final cv = choiceShowing ? null : g.choiceView();
  if (cv != null) {
    final dl = duskLeft(g);
    out.add(TapeItem('choice', cv.title, tag: '선택 기다림', sub: dl != null ? '해 질 때까지 $dl · 안 고르면 누군가 대신 정해요' : '', btn: '고르기', hot: true, lead: _dot(Ttc.rust)));
  }
  if (g.s2On) {
    final n = tapeExpBack(g);
    if (n > 0) out.add(TapeItem('exp', '원정대 $n팀이 돌아왔어요', tag: '원정', sub: '원정 탭에서 짐을 풀어요', btn: '보기', hot: true, lead: _dot(Ttc.amber)));
  }
  final nq = g.qNew.length;
  if (nq > 0) out.add(TapeItem('stories', nq > 1 ? '새 이야기 $nq개' : '새 이야기', tag: '생존자', sub: '먼저 생긴 이야기부터 하나씩 열어요', btn: '보기', lead: _dot(Ttc.amber)));
  final q = g.sq, t0 = q == null ? null : sqTypes[q['k']];
  if (q != null && g.sqOn && t0 != null) {
    final n = ((q['n'] as num?) ?? 1).toInt(), p = g.sqProg(), who = (q['who'] as num?)?.toInt() ?? -1, hasWho = g.hasSv(who);
    out.add(TapeItem('sq', t0.t(n),
        tag: '${hasWho ? survivors[who].name : '쉘터'}의 부탁 ${g.num_('sqN').toInt() % 3 + 1}/3',
        sub: p >= n ? '다 모았어요' : '${fmt(p)}/${fmt(n)}',
        btn: p >= n ? '받기' : '하러 가기',
        hot: p >= n,
        lead: Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE6D8B6)),
          clipBehavior: Clip.antiAlias,
          child: hasWho ? Portrait(who, width: 26, height: 31) : null,
        )));
  }
  if (tapeTraceMap(g)) out.add(TapeItem('trace', '아침의 흔적', tag: '지도', sub: '밤사이 남은 흔적이 반짝여요', btn: '찾기', lead: _dot(const Color(0xFFFFE678))));
  if (tapeTrace(g)) out.add(TapeItem('case', '아침의 흔적', tag: '사건 수첩', sub: '밤사이 남은 흔적을 적어 뒀어요', btn: '보기', lead: _dot(const Color(0xFFC9A46A))));
  if (g.dayOn && g.dayList.isNotEmpty && !g.dayAllDone) {
    out.add(TapeItem('daily', '오늘의 할 일 ${g.dayList.where((x) => x.$4).length}/${g.dayList.length}', tag: '일지', sub: '셋을 다 하면 연속 보상', btn: '보기', lead: _dot(const Color(0xFFDFA54B))));
  }
  if (g.pedHere) out.add(TapeItem('ped', '노친네', tag: '손님', sub: '수레를 끌고 쉘터 앞에 와 있어요', btn: '보러 가기', lead: pedFace(size: 24)));
  if ((m.eg || m.go) && !m.done && g.canMigrate) {
    out.add(TapeItem('mig', '새 동네로', tag: '떠날 준비', sub: '다음 동네로 사람들과 함께 떠날 수 있어요', btn: '보기', lead: const ResIcon('hope', size: 22)));
  }
  return out;
}

Widget _dot(Color c) => Container(width: 10, height: 10, margin: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle, color: c));

class MissionTape extends StatefulWidget {
  const MissionTape(this.g, {super.key, required this.onLv, required this.onTap, required this.onMore, required this.ping, this.moreOpen = false});
  final Game g;
  final VoidCallback onLv, onMore;

  /// '지금' 줄을 눌렀을 때 (종류: claim · sqclaim · storm · choice · exp · goal · case · sq · tut)
  final void Function(String k) onTap;
  final bool moreOpen;
  final int ping; // 받기 줄을 잠깐 흔든다 (웹 pingEl)
  @override
  State<MissionTape> createState() => _MissionTapeState();
}

class _MissionTapeState extends State<MissionTape> {
  Game get g => widget.g;

  /// 증축까지 얼마나 모였나 (웹 6270: 자재마다 모인 비율과 모듈 수 비율의 평균)
  double get _lvFrac {
    final S = g.S;
    if (S.lv >= 5) return 1;
    final c = g.shelterUpCost!;
    final parts = [for (final e in c.entries) math.min(1.0, g.have(e.key) / e.value), math.min(1.0, S.mods.length / shupNeed[S.lv - 1])];
    return parts.fold(0.0, (a, v) => a + v) / parts.length;
  }

  @override
  Widget build(BuildContext context) {
    final S = g.S, m = g.mission();
    final (k, txt) = tapeNow(g);
    final claim = k == 'claim' || k == 'sqclaim', alarm = k == 'storm' || k == 'choice';
    final ready = S.lv < 5 && _lvFrac >= 1;
    // 쉘터 레벨 (작게) · 증축 막대는 굵게 (2026-11-03 대표님: 얇아서 안 보였다)
    final lvchip = GestureDetector(
      onTap: widget.onLv,
      child: Container(
        constraints: const BoxConstraints(minWidth: 58, maxWidth: 80),
        padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
        decoration: BoxDecoration(color: ready ? Ttc.amberBtn : Ttc.lvchip, borderRadius: BorderRadius.circular(7)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          // 짧은 이름만 ('판잣집 쉘터' → '판잣집'), 그래도 길면 글자를 줄인다 (말줄임 없이)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('Lv.${S.lv} ${shelterName[S.lv - 1].replaceAll(RegExp(r'\s*쉘터$'), '')}',
                maxLines: 1, style: Ttc.t(11, color: ready ? const Color(0xFF243039) : Ttc.lvText, weight: FontWeight.w700, height: 1)),
          ),
          const SizedBox(height: 4),
          if (ready)
            Text('증축 가능 ›', style: Ttc.t(10.5, color: const Color(0xFF243039), weight: FontWeight.w700, height: 1))
          else
            Container(
              width: 48,
              height: 7,
              decoration: BoxDecoration(color: const Color(0x2EF5EAD0), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x33F5EAD0), width: .6)),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _lvFrac.clamp(0, 1).toDouble(),
                child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), gradient: const LinearGradient(colors: [Color(0xFFC9A24A), Color(0xFFF3A53A)]))),
              ),
            ),
        ]),
      ),
    );
    final (cn, cp) = tapeChap(g);
    final head = switch (k) {
      'tut' => '$cn $cp › ',
      'claim' || 'sqclaim' => '받기 › ',
      'storm' => '위기 › ',
      'choice' => '선택 › ',
      'exp' => '원정 › ',
      'case' || 'trace' => '흔적 › ',
      'sq' => '부탁 › ',
      _ => '지금 › ',
    };
    final fg = claim ? const Color(0xFF252E36) : const Color(0xFFF0E7D6);
    final headC = claim ? const Color(0xFF523D24) : alarm ? const Color(0xFFFFB4A0) : const Color(0xFFE8C77A);
    // 두 줄 자리를 늘 잡아 둔다: 글이 한 줄↔두 줄로 바뀌어도 띠 높이(= 지도 크기)가 흔들리지 않게. 넘치면 줄바꿈 (말줄임 없음)
    final line = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 34),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: head, style: Ttc.t(12.5, color: headC, weight: FontWeight.w700, height: 1.35)),
            if (claim) TextSpan(text: '✓ ', style: Ttc.t(13, color: Ttc.rust, weight: FontWeight.w700, height: 1.35)),
            TextSpan(text: g.s2On ? keepWords(txt) : txt, style: Ttc.t(13, color: fg, weight: FontWeight.w600, height: 1.35)),
          ]),
        ),
      ),
    );
    final n = tapeItems(g).length - 1;
    final badge = g.tut != null
        ? null
        : GestureDetector(
            key: const ValueKey('tapeMore'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onMore,
            child: Container(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: widget.moreOpen ? Ttc.tabOn : claim ? const Color(0x33252E36) : const Color(0xFF3B4A55),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: widget.moreOpen ? Ttc.tabOnLine : Ttc.line20, width: .8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                // 시즌 2: 배지가 무엇을 세는지 (2026-11-08 UI)
                if (n > 0 && g.s2On) Padding(padding: const EdgeInsets.only(right: 4), child: Text('할 일', style: Ttc.t(11, color: claim ? const Color(0xFF3B2A1A) : const Color(0xFFC7CEC9), weight: FontWeight.w700, height: 1))),
                if (n > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Ttc.amber, borderRadius: BorderRadius.circular(99)),
                    child: Text('$n', style: Ttc.t(12, color: const Color(0xFF243039), weight: FontWeight.w800, height: 1)),
                  ),
                Padding(
                  padding: EdgeInsets.only(left: n > 0 ? 4 : 0),
                  child: Transform.rotate(angle: widget.moreOpen ? math.pi : 0, child: Text('▼', style: Ttc.t(10, color: claim ? const Color(0xFF3B2A1A) : const Color(0xFFC7CEC9), height: 1))),
                ),
              ]),
            ),
          );
    // 모닥불 (살아 움직이는 눈금이라 띠 안에 작게): 누르면 장작을 넣는다
    final fire = g.fireOn && g.warm != null
        ? hl(
            'firechip',
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => g.feedFire(),
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(colors: g.warmTier == 0 ? const [Color(0xFF2D3A45), Color(0xFF4B5D6B)] : const [Color(0xFF6B2F17), Color(0xFFC4652A)]),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SvgPicture.string(Ico.flame, width: 13, height: 13),
                  const SizedBox(width: 3),
                  Text('${g.warm!.round()}%', style: Ttc.t(12, color: g.warmTier == 0 ? const Color(0xFFDFE8EF) : const Color(0xFFFFE9C7), weight: FontWeight.w700, height: 1)),
                ]),
              ),
            ),
            radius: 14)
        : null;
    Widget tape = GestureDetector(
      onTap: () => widget.onTap(k),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, top: 4),
        padding: const EdgeInsets.fromLTRB(7, 6, 6, 6),
        decoration: BoxDecoration(
          color: claim ? const Color(0xFFDFAA56) : alarm ? const Color(0xFF433438) : Ttc.tape,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: claim ? const Color(0xFFEFC883) : alarm ? const Color(0xFFAB5145) : Ttc.line17, width: .8),
        ),
        child: Row(children: [
          lvchip,
          const SizedBox(width: 8),
          Expanded(child: line),
          // 받을 보상 (받기 줄의 오른쪽 끝)
          if (k == 'claim')
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Wrap(spacing: 2, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final e in m.rw.entries)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    ResIcon(e.key, size: 13),
                    Text('${e.value}', style: Ttc.t(11.5, color: const Color(0xFF302C26), weight: FontWeight.w700, height: 1.1)),
                  ]),
              ]),
            ),
          if (fire != null) fire,
          if (badge != null) badge,
        ]),
      ),
    );
    if (claim) tape = _Shake(ping: widget.ping, child: hl('claim', tape, radius: 8));
    return tape;
  }
}

/// 배지를 누르면 띠 아래로 펼쳐지는 목록 (지도 위에 떠 있어 지도 크기는 그대로)
class TapePanel extends StatelessWidget {
  const TapePanel(this.g, {super.key, required this.onItem});
  final Game g;
  final void Function(String k) onItem;
  @override
  Widget build(BuildContext context) {
    final items = tapeItems(g);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: Ttc.header,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Ttc.line25),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: math.max(160.0, MediaQuery.of(context).size.height * .55)),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final it in items) _row(it),
          ]),
        ),
      ),
    );
  }

  Widget _row(TapeItem it) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onItem(it.k),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(6, 7, 8, 7),
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: it.k == 'goal' ? Ttc.tape : const Color(0xFF29333D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: it.hot ? Ttc.amber : Ttc.line17, width: it.hot ? 1.2 : .8),
          ),
          child: Row(children: [
            SizedBox(width: 28, child: Center(child: it.lead)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (it.tag.isNotEmpty) Text(it.tag, style: Ttc.t(11.5, color: Ttc.glow, weight: FontWeight.w700, height: 1.3)),
                Text(it.title, style: Ttc.t(13.5, color: const Color(0xFFF0E7D6), weight: FontWeight.w700, height: 1.35)),
                if (it.sub.isNotEmpty) Text(it.sub, style: Ttc.t(12, color: const Color(0xFFC9D0CB), height: 1.4)),
              ]),
            ),
            if (it.btn != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: it.hot ? Ttc.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: it.hot ? const Color(0x73252E36) : Ttc.line25),
                ),
                child: Text(it.btn!, style: Ttc.t(12.5, color: it.hot ? const Color(0xFF252E36) : const Color(0xFFE7E4DC), weight: FontWeight.w700, height: 1.2)),
              ),
            ],
          ]),
        ),
      );
}

/// 게임 데이터의 옛 이름('미션')을 화면에서만 지금 이름('이야기')으로
/// 한글 줄바꿈을 낱말 단위로 (2026-11-08 UI: '랜턴으 / 로'처럼 낱말 가운데서 넘어갔다) — 낱말 안 글자 사이에 단어 이음표(U+2060)
String keepWords(String s) => s.split(' ').map((w) => w.runes.length < 2 ? w : w.runes.map(String.fromCharCode).join('\u2060')).join(' ');

String uiWords(String s) => s.replaceAll('미션을 눌러', '이야기 띠를 눌러').replaceAll('미션 띠', '이야기 띠').replaceAll('미션', '이야기');

class _Shake extends StatefulWidget {
  const _Shake({required this.ping, required this.child});
  final int ping;
  final Widget child;
  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  @override
  void didUpdateWidget(_Shake old) {
    super.didUpdateWidget(old);
    if (old.ping != widget.ping) a.forward(from: 0);
  }

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: a,
        builder: (c, child) => Transform.scale(scale: 1 + .12 * math.sin(a.value * math.pi * 3) * (1 - a.value), child: child),
        child: widget.child,
      );
}

// ======================= 그림 =======================
/// 아틀라스의 src 영역을 상자에 꽉 채워(넘치는 쪽은 잘라) 그린다. alignY: 0 = 위, .5 = 가운데 (웹 xMidYMin/xMidYMid slice)
class CoverPic extends StatelessWidget {
  const CoverPic(this.file, this.src, {super.key, this.alignY = .5});
  final String file;
  final Rect src;
  final double alignY;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: Atlas.version,
        builder: (c, _, __) => CustomPaint(painter: _CoverPainter(file, src, alignY, Atlas.version.value)),
      );
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.file, this.src, this.alignY, this.v);
  final String file;
  final Rect src;
  final double alignY;
  final int v;
  @override
  void paint(Canvas canvas, Size size) {
    final img = Atlas.lazy(file) ?? Atlas.image(file);
    if (img == null || size.isEmpty) return;
    final k = math.max(size.width / src.width, size.height / src.height);
    final w = size.width / k, h = size.height / k;
    final s = Rect.fromLTWH(src.left + (src.width - w) / 2, src.top + (src.height - h) * alignY, w, h);
    canvas.drawImageRect(img, s, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.v != v || old.src != src || old.file != file;
}

const _storyFiles = ['story-1.webp', 'story-2.webp', 'story-3.webp', 'story-4.webp', 'story-5.webp', 'story-6.webp', 'story-7.webp'];

/// 이야기 장면 n번 (웹 story-art.js panelSvg). 그림이 아직 없으면 null.
Rect? storyRect(int n) {
  final f = _storyFiles[n ~/ 9], img = Atlas.lazy(f);
  if (img == null) return null;
  final c = n % 9, w = img.width / 3, h = img.height / 3;
  return Rect.fromLTWH((c % 3) * w + 2, (c ~/ 3) * h + 2, w - 4, h - 4);
}

String storyFile(int n) => _storyFiles[n ~/ 9];

/// 대화의 그림 번호 (웹 artFor): 지금 줄에 딸린 그림, 없으면 이 대화에서 처음 그림이 정해진 줄
int? artFor(List<Line> lines, int k) {
  final line = web.storyArt['line'] as Map, talk = web.storyArt['talk'] as Map;
  final t = lines[k].t;
  // 시즌 2 장면 (45~62): 그 줄부터 다음 그림 줄 전까지 같은 그림
  for (var j = k; j >= 0; j--) {
    final n = s2ArtLine[lines[j].t];
    if (n != null) return n;
  }
  if (line[t] != null) return (line[t] as num).toInt();
  for (final l in lines) {
    if (talk[l.t] != null) return (talk[l.t] as num).toInt();
  }
  return null;
}

/// 장 첫머리 풍경 (웹 chapter-design.js scene, world-panorama 3×3)
Widget sceneArt(String key) {
  const scenes = {'mall': 0, 'road': 1, 'apt': 2, 'plant': 3, 'metro': 4, 'sewer': 5, 'bunker': 6, 'control': 7, 'shelter': 8};
  const ys = [0, 258, 494, 724];
  final n = scenes[key] ?? 8, row = n ~/ 3, col = n % 3;
  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: AspectRatio(
      aspectRatio: 3,
      child: CoverPic('world-panorama.webp', Rect.fromLTWH(col * 724.0 + 2, ys[row] + 2.0, 720, ys[row + 1] - ys[row] - 4.0)),
    ),
  );
}

const _meSvg =
    '<svg viewBox="0 0 40 40" width="40" height="40" fill="none" stroke="#efe3c4" stroke-width="2" stroke-linejoin="round"><path d="M14 11h12M16 11V8h8v3M13 13h14l-2 17H15z"/><path d="M16 30h8v3h-8z" fill="#efe3c4"/><path d="M20 17c3 3 3 6 0 8-3-2-3-5 0-8z" fill="#ffcf7a" stroke="none"/></svg>';

/// 나(초상화를 아직 고르지 않았을 때)의 작은 랜턴 배지: 대화 창·사건 창·선택 창이 같이 쓴다
Widget meLantern(double sz) => Container(
      width: sz,
      height: sz,
      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF3A2618), border: Border.all(color: const Color(0x403B2A1A), width: 1.5)),
      alignment: Alignment.center,
      child: SvgPicture.string(_meSvg, width: sz * .58, height: sz * .58),
    );

/// 대화 속 얼굴 (웹 speaker): 만수·유진·하늘·재혁은 표정 그림, 다른 사람은 초상화, 나는 랜턴
Widget talkFace(Game g, Object who, String t, String? mood, {double w = 84, double h = 98}) {
  if (who is String && who.startsWith('npc:')) {
    return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: const Color(0xFFE6D8B6), borderRadius: BorderRadius.circular(8), border: Border.all(color: Ttc.line)),
        clipBehavior: Clip.antiAlias,
        child: npcFace(who));
  }
  final id = g.speakerId(who);
  final box = BoxDecoration(color: id == null ? const Color(0xFF3A2618) : const Color(0xFFE6D8B6), borderRadius: BorderRadius.circular(8), border: Border.all(color: Ttc.line));
  if (id == null) {
    if (g.pfSet) return Container(width: w, height: h, decoration: box, clipBehavior: Clip.antiAlias, child: (w - h).abs() < 6 ? pfFace(g.pfIndex()) : pfPortrait(g.pfIndex()));
    return Container(width: w, height: h, decoration: box, alignment: Alignment.center, child: SvgPicture.string(_meSvg, width: 40, height: 40));
  }
  const exIds = {0: 0, 2: 1, 7: 2, 9: 3};
  final col = exIds[id];
  Widget pic = Portrait(id, width: w, height: h);
  if (col != null) {
    final md = mood ?? web.dialogueMood[t] ?? 'calm';
    final row = const {'calm': 0, 'worried': 1, 'resolved': 2}[md] ?? 0;
    final img = Atlas.lazy('founder-expressions.webp');
    if (img != null) {
      final cw = img.width / 4, ch = img.height / 3;
      pic = CoverPic('founder-expressions.webp', Rect.fromLTWH(col * cw + 3, row * ch + 3, cw - 6, ch - 6), alignY: 0);
    }
  }
  return Container(width: w, height: h, decoration: box, clipBehavior: Clip.antiAlias, child: pic);
}

String _speakerSub(Game g, Object who) {
  if (who is String && who.startsWith('npc:')) return npcName[who.substring(4)]?.$2 ?? '';
  final id = g.speakerId(who);
  if (id == null) return g.title != '등불지기' ? '등불지기 · ${g.title}' : '등불지기';
  if (who is String && who.startsWith('r:')) return '무전 · ${survivors[id].job}';
  return survivors[id].job;
}

// ======================= 대화 창 (웹 renderTalk 2061) =======================
Future<void> showTalk(BuildContext context, Game g, FxTalk t, {VoidCallback? onDone}) => showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Ttc.dim,
      builder: (ctx) => _TalkPage(g, t, onDone: () {
        Navigator.pop(ctx);
        onDone?.call();
      }),
    );

class _TalkPage extends StatefulWidget {
  const _TalkPage(this.g, this.t, {required this.onDone});
  final Game g;
  final FxTalk t;
  final VoidCallback onDone;
  @override
  State<_TalkPage> createState() => _TalkPageState();
}

/// 대사 한 줄이 열릴 때 (웹 openTalk의 onLine — 엔딩의 딸깍·잡음)
void Function(String t)? onTalkLine;

class _TalkPageState extends State<_TalkPage> {
  int k = 0, _said = -1;
  Game get g => widget.g;
  FxTalk get t => widget.t;

  @override
  Widget build(BuildContext context) => PopScope(canPop: false, child: _page(context));

  /// 마지막으로 줄을 넘긴 때: 연달아 두드린 손가락이 막 나타난 버튼을 누르지 않게
  int _advAt = 0;
  void _next() {
    if (k >= t.lines.length - 1) return;
    _advAt = DateTime.now().millisecondsSinceEpoch;
    setState(() => k++);
  }

  void _skip() {
    _advAt = DateTime.now().millisecondsSinceEpoch;
    setState(() => k = t.lines.length - 1);
  }

  /// 말하는 사람 작은 얼굴 (52px 동그라미). 나는 초상화가 없으면 작은 랜턴 배지
  Widget _avatar(Line l) {
    const sz = 52.0;
    final who = l.who;
    final npc = who is String && who.startsWith('npc:');
    final me = !npc && g.speakerId(who) == null;
    if (me && !g.pfSet) return meLantern(sz);
    return Container(
      width: sz,
      height: sz,
      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE6D8B6), border: Border.all(color: const Color(0x403B2A1A), width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: talkFace(g, who, l.t, l.mood, w: sz, h: sz),
    );
  }

  Widget _page(BuildContext context) {
    final lines = t.lines, l = lines[k], last = k == lines.length - 1, n = lines.length;
    if (_said != k) {
      _said = k;
      final h = onTalkLine;
      if (h != null) WidgetsBinding.instance.addPostFrameCallback((_) => h(l.t));
    }
    final art = artFor(lines, k);
    if (art != null && !t.replay) g.markArt(art);
    final rect = art == null ? null : storyRect(art);
    final card = t.card != null && k == 0;
    final scr = MediaQuery.of(context).size;
    final small = scr.height <= 700;
    final canSkip = !last && n > 2 && !t.noskip;
    final daily = last && (t.tag ?? '').startsWith('아침 보고') ? dailyMini(g) : null;
    return Dialog(
      backgroundColor: Ttc.paper,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x66EEE5D3))),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: scr.height - 32),
        // 창 어디를 두드려도 다음 줄로 (마지막 줄에서는 아래 버튼으로만 닫는다)
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: last ? null : _next,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              if (art != null)
                ValueListenableBuilder<int>(
                  valueListenable: Atlas.version,
                  builder: (c, _, __) {
                    final r = storyRect(art) ?? rect;
                    if (r == null) return card ? Padding(padding: const EdgeInsets.only(bottom: 16), child: sceneArt(t.scene ?? 'shelter')) : const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(maxHeight: scr.height * (scr.height <= 640 ? .26 : .34)),
                      decoration: BoxDecoration(color: const Color(0xFF35404A), borderRadius: BorderRadius.circular(10)),
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(aspectRatio: 1.5, child: CoverPic(storyFile(art), r)),
                    );
                  },
                )
              else if (card)
                Padding(padding: const EdgeInsets.only(bottom: 16), child: sceneArt(t.scene ?? 'shelter')),
              if (card)
                Container(
                  padding: const EdgeInsets.only(bottom: 14),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
                  child: Column(children: [
                    Text(t.card!.$1, style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(t.card!.$2, textAlign: TextAlign.center, style: Ttc.t(23, color: Ttc.sepia, weight: FontWeight.w700)),
                  ]),
                )
              else if (t.tag != null)
                Text(t.tag!, style: Ttc.t(13, color: Ttc.sepia2, weight: FontWeight.w600, height: 1.4)),
              // 말하는 사람: 작은 얼굴 + 이름 · 하는 일 한 줄
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
                child: Row(children: [
                  _avatar(l),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: _name(l.who), style: Ttc.t(17, color: Ttc.sepia, weight: FontWeight.w700, height: 1.3)),
                        TextSpan(text: '  ${_speakerSub(g, l.who)}', style: Ttc.t(13, color: Ttc.sepia2, height: 1.3)),
                      ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
              // 대사 칸은 지금 줄 높이만큼 (2026-10-21: 가장 긴 줄에 맞추던 것 → 짧은 줄에서 아래가 휑했음). 줄이 바뀔 때 높이는 부드럽게
              AnimatedSize(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: Alignment.topLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, if (cur != null) cur]),
                  child: SizedBox(key: ValueKey(k), width: double.infinity, child: Text(l.t, style: Ttc.t(small ? 18 : 20, color: Ttc.sepia, height: 1.6))),
                ),
              ),
              SizedBox(height: small ? 12 : 18),
              if (last && t.reward != null && t.reward!.isNotEmpty) _box(Text('보상 · ${g.lootText(t.reward!)}', style: Ttc.t(13, color: Ttc.sepia, height: 1.6))),
              if (last && t.goal != null)
                _box(Text.rich(TextSpan(children: [
                  const TextSpan(text: '할 일 ', style: TextStyle(fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
                  TextSpan(text: t.goal),
                ]), style: Ttc.t(13, color: Ttc.sepia, height: 1.6))),
              // 아침 보고 끝: 오늘의 할 일 셋 (앱 전용 2026-10-20)
              if (daily != null) daily,
              // 아래 줄: 옅은 선 하나 + (넘기는 중) 몇 번째 줄 · 탭해서 계속 · 건너뛰기 / (마지막) 행동 버튼
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.only(top: 12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ttc.line))),
                child: Row(children: [
                  if (n > 1) Text('${k + 1} / $n', style: Ttc.t(12.5, color: Ttc.sepia2)),
                  const Spacer(),
                  // 2026-10-21 대표님: 글자 버튼이 작아 누르기 불편 → 손가락 크기(높이 44) 버튼으로
                  if (canSkip)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _skip,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 84, minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Ttc.line, width: 1.2)),
                        child: Text('건너뛰기', style: Ttc.t(14, color: Ttc.sepia2, weight: FontWeight.w700)),
                      ),
                    ),
                  if (!last) ...[
                    if (canSkip) const SizedBox(width: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _next,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 90, minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFFEFE2C2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFC9A46A), width: 1.2)),
                        child: Text('다음 ›', style: Ttc.t(14, color: const Color(0xFF7A5A2E), weight: FontWeight.w700)),
                      ),
                    ),
                  ],
                  if (last)
                    GestureDetector(
                      onTap: () {
                        // 넘기던 손가락이 막 생긴 버튼을 바로 누르지 않게 잠깐 기다린다
                        if (DateTime.now().millisecondsSinceEpoch - _advAt < 350) return;
                        widget.onDone();
                      },
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 90, minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Ttc.amberBtn, borderRadius: BorderRadius.circular(8), border: Border.all(color: Ttc.amberBtnLine)),
                        child: Text(t.goal != null ? '해 보자' : '계속', style: Ttc.t(14, color: const Color(0xFF243039), weight: FontWeight.w700)),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _name(Object who) {
    if (who is String && who.startsWith('npc:')) return npcName[who.substring(4)]?.$1 ?? '';
    return g.speakerName(who);
  }

  Widget _box(Widget c) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFE5DDCC), borderRadius: BorderRadius.circular(7)),
        child: c,
      );
}

/// 시즌 2 장면 그림 (story-6 45~53, story-7 54~62): 이 줄이 나오면 그 그림
const Map<String, int> s2ArtLine = {
  '머리맡의 랜턴이 미지근했다. 밤새 꺼 두었는데.': 45,
  '탑 빛 안쪽은 이제 우리가 다녀올게. 넌 좀 앉아 있어.': 46,
  '탑 빛 안쪽은 이제 우리가 다녀올게요. 좀 앉아 있어요.': 46,
  '랜턴을 들어 올렸다. 지붕 위 작은 등이 숨을 쉬듯 켜졌다.': 47,
  '연구소는 산그늘에 엎드려 있었다. 철문에 녹슨 봉인 띠가 감겨 있었다.': 48,
  '원정 조가 그림을 떼어 왔다. 랜턴을 든 남자와, 그 손을 잡은 작은 아이.': 49,
  '이거 다 끼우면, 저수지 불빛이랑 이어질 거예요.': 50,
  '쓰러진 슈퍼 간판. 그날 밤, 여기 왼편에 텐트를 쳤다.': 51,
  '현관에 섰다. 문고리를 잡으려는데, 다른 손이 무거웠다.': 52,
  '탑 꼭대기에서 랜턴을 들었다. 빛줄기들이 둥글게 닫혔다.': 53,
  '새벽 방송은… 전부 전날 녹음한 거예요.': 54,
  '은호 씨. 아까… 손 떨린다는 거요.': 55,
  '새벽 세 시마다 밖에 있었던 것도 은호 씨, 방송도 은호 씨예요.': 56,
  '은호와 미영이 같은 자리에 서 있는 걸 처음 봤다.': 57,
  '판넬 아래, 먼지 덮인 운전 기록계가 있었다. 종이가 말려 있었다.': 58,
  '랜턴을 들고 계단을 내려갔다. 아무도 없었다.': 59,
  '해 질 녘, 독수리가 홀로 찾아왔다. 문설주 앞에서 옛 시그널을 흥얼거렸다. 알아듣는 사람이 없었다.': 60,
  '…잠깐 앉아도 돼요?': 61,
  '03:10. 하늘이 잠든 자리. 이불이 발치로 흘러내려 있었다.': 62,
};

/// 이름 있는 바깥사람 (웹 NPC)
const Map<String, (String, String)> npcName = {
  'crow': ('독수리', '까마귀 무리의 우두머리'),
  'jin': ('진', '까마귀 막내'),
  'desert': ('두식', '사막 급유탑지기'),
  'factory': ('마석', '녹슨 공단 반장'),
  'snow': ('은솔', '산골 분교 선생님'),
  // 시즌 2
  'ped': ('노친네', '떠돌이 장사꾼'),
  'keeper': ('하경수', '수문 관리인'),
};

// ======================= 6장: 재혁의 고백 (웹 openConf 5075) =======================
Future<void> showConf(BuildContext context, Game g) => showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Ttc.dim,
      builder: (ctx) {
        final s = survivors[9];
        Widget choice(String b, String small, bool a) => GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                g.chooseConf(a);
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x47252E36))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b, style: Ttc.t(14.5, color: Ttc.sepia, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(small, style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
                ]),
              ),
            );
        return Dialog(
          backgroundColor: Ttc.paper,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x66EEE5D3))),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('6장 · 재혁의 고백', style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
                  child: Row(children: [
                    talkFace(g, 9, '', null),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.name, style: Ttc.t(18, color: Ttc.sepia, weight: FontWeight.w700)),
                        Text(s.job, style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
                      ]),
                    ),
                  ]),
                ),
                Text('모두가 당신을 쳐다봐요. 재혁을 어떻게 할까요?', style: Ttc.t(16, color: Ttc.sepia, height: 1.85)),
                const SizedBox(height: 16),
                choice('감싸 준다', '“살아남으려 했을 뿐이잖아요. 여기서 같이 고쳐요.”', true),
                choice('지켜본다', '“당장 믿긴 어려워요. 행동으로 보여 줘요.”', false),
              ]),
            ),
          ),
        );
      },
    );

// ======================= 길잡이 (웹 focusTarget 2077 · #guide) =======================
/// 길잡이가 가리킬 곳: 화면 요소(el) 또는 지도 칸(tile)
class GuideTarget {
  const GuideTarget({this.el, this.tile = -1, this.label = '', this.z = 18});
  final String? el; // lamp · fExp · radio · fSurv · clock · ev · skills
  final int tile;
  final String label;
  final double z;
}

/// 이 걸음에서 지을 모듈·증축 비용 중 모자란 기본 자재 (웹 stepLack · LACK_RAW)
String? _stepLack(Game g, String? hl) {
  if (hl == null) return null;
  Cost? c;
  final mb = RegExp(r'mbuild"\]\[data-arg="(\d+)"').firstMatch(hl);
  if (mb != null) {
    final id = int.parse(mb.group(1)!);
    if (g.hasMod(id) || mods[id] == null) return null;
    c = g.modBuildCost(id);
  } else if (hl.contains('"shup"') && g.S.lv < 5) {
    c = g.shelterUpCost;
  }
  if (c == null || g.canPay(c)) return null;
  const raw = ['wood', 'scrap', 'cloth', 'food', 'parts', 'fuel'];
  for (final k in c.keys) {
    if (raw.contains(k) && g.have(k) < (c[k] ?? 0)) return k;
  }
  return null;
}

GuideTarget? guideTarget(Game g) {
  if (g.tut != null) return _tutTarget(g);
  // 보급 더미가 있으면 그쪽부터 (앱 시즌 1 다듬기)
  final sp = g.supply;
  if (sp != null) return GuideTarget(tile: (sp['i'] as num).toInt(), label: '${matOf[sp['k']]?.n ?? '자재'} 모으기');
  final m = g.mission();
  if (m.done || m.step == null || m.step!.focus == null) return null;
  final st = m.step!, f = st.focus!, S = g.S;
  // 지어야 할 것의 자재가 모자라면 쉘터 대신 자재를 모을 곳을 가리킨다 (웹 stepLack 2026-10-15)
  final lk = _stepLack(g, st.hl);
  if (lk != null) {
    final t = '${matOf[lk]?.n ?? '자재'} 모으기';
    var bi = -1;
    var bd = 1e9;
    for (var j = 0; j < N; j++) {
      if (g.siteLive(j) && S.rev[j] == 1) {
        final d = dist(j);
        if (d < bd) {
          bd = d;
          bi = j;
        }
      }
    }
    return bi >= 0 ? GuideTarget(tile: bi, label: t) : GuideTarget(el: 'lamp', label: t);
  }
  // 쉘터에서 만들 수 있는 재료(철판·밧줄)가 모자라면 쉘터를 가리키며 '작업대에서 만들기' (2026-10-23 QA: 고비에서 무엇을 할지 보이게)
  final gl = g.goalLack;
  if (f == 'center' && gl != null && matOf[gl.$1]?.tier == 1 && g.wbL >= 1) {
    return GuideTarget(tile: C0, label: '작업대에서 ${matOf[gl.$1]!.n} 만들기');
  }
  switch (f) {
    case 'lamp':
      return const GuideTarget(el: 'lamp', label: '랜턴으로 땅 밝히기');
    case 'fExp':
      return const GuideTarget(el: 'fExp', label: '원정');
    case 'radio':
      return const GuideTarget(el: 'radio', label: '라디오');
    case 'fSurv':
      return const GuideTarget(el: 'fSurv', label: '생존자');
    case 'clock':
      return g.isNight ? null : const GuideTarget(el: 'clock', label: '밤을 기다려요');
    case 'ev':
      return g.evCur < 0 ? null : const GuideTarget(el: 'ev', label: '부탁');
    case 'skills':
      return g.party.isEmpty ? null : const GuideTarget(el: 'skills', label: '스킬');
  }
  int near(bool Function(int i) ok) {
    var best = -1;
    var bd = 1e9;
    for (var i = 0; i < N; i++) {
      if (!ok(i)) continue;
      final d = dist(i);
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  var i = -1;
  var t = '';
  switch (f) {
    case 'center':
      i = C0;
      t = '쉘터';
    case 'module':
      i = g.modAt.isNotEmpty ? g.modAt.keys.first : C0;
      t = '모듈';
    case 'site':
      i = near(g.siteLive);
      t = '뒤지기';
      if (i < 0) {
        i = g.aim;
        t = '두드리기';
      }
    case 'signal':
      final want = st.goal == '오재혁 구하기' ? 9 : null;
      bool mt(Object? id) => want == null || id == want;
      i = near((j) => S.camp[j] != null && S.rev[j] == 1 && mt(S.camp[j]!['id']));
      t = '구조';
      if (i < 0) {
        i = near((j) => S.sig[j] != null && mt(S.sig[j]));
        t = '구조 신호';
      }
    case 'lm':
      i = near((j) => S.ter[j] == T.lm && S.lm[j] != null && !S.lm[j]!.ok && S.rev[j] == 1);
      if (i < 0) i = near((j) => S.ter[j] == T.lm && S.lm[j] != null && !S.lm[j]!.ok);
      t = '랜드마크';
  }
  if (i < 0) return null;
  return GuideTarget(tile: i, label: t, z: i == C0 ? 30 : (S.rev[i] == 1 ? 18 : 22));
}

/// 튜토리얼의 길잡이 (웹 focusTarget 덮어쓰기)
GuideTarget? _tutTarget(Game g) {
  if (g.tutEnd) return null;
  final f = tutSteps[((g.tut!['i'] as num?) ?? 0).toInt()].focus;
  if (f == 'lamp') return const GuideTarget(el: 'lamp', label: '랜턴으로 땅 밝히기');
  int near(bool Function(int i) ok) {
    var best = -1;
    var bd = 1e9;
    for (var i = 0; i < N; i++) {
      if (!ok(i)) continue;
      final d = dist(i);
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  var i = -1, t = '';
  if (f == 'site') {
    i = near((j) => g.S.rev[j] == 1 && g.siteLive(j));
    t = '뒤지기';
    if (i < 0) return const GuideTarget(el: 'lamp', label: '더 밝혀요');
  } else if (f == 'center') {
    i = C0;
    t = '텐트';
  } else if (f == 'ash') {
    i = near((j) => g.S.ash.containsKey('$j'));
    t = '재';
  }
  if (i < 0) return null;
  return GuideTarget(tile: i, label: t, z: i == C0 ? 20 : 18);
}

/// 화살표 (웹 #guide: 호박색 말풍선 + 아래 삼각형, 위아래로 까딱)
class GuideArrow extends StatefulWidget {
  const GuideArrow(this.label, {super.key, this.x = 0, this.screenW = 0, this.onTap});
  final String label;
  final VoidCallback? onTap; // 화면 밖을 가리킬 때만: 누르면 그쪽으로 (웹 #guide.off)
  final double x, screenW; // 말풍선이 화면 밖으로 나가지 않게 옆으로 민다 (꼬리는 그대로)
  @override
  State<GuideArrow> createState() => _GuideArrowState();
}

class _GuideArrowState extends State<GuideArrow> with SingleTickerProviderStateMixin {
  double _shift() {
    if (widget.screenW <= 0) return 0;
    final tp = TextPainter(text: TextSpan(text: widget.label, style: Ttc.t(13, weight: FontWeight.w700, height: 1)), textDirection: TextDirection.ltr)..layout();
    final w = tp.width + 24, left = widget.x - w / 2;
    final want = left.clamp(8.0, math.max(8.0, widget.screenW - 8 - w)).toDouble();
    return want - left;
  }
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: widget.onTap == null,
        child: GestureDetector(onTap: widget.onTap, child: AnimatedBuilder(
          animation: a,
          builder: (c, child) => Transform.translate(offset: Offset(0, -8 * math.sin(a.value * math.pi)), child: child),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.label.isNotEmpty)
              Transform.translate(
                offset: Offset(_shift(), 0),
                child: Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
                decoration: BoxDecoration(
                  color: Ttc.amber,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Ttc.sepia, width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 10, offset: Offset(0, 4))],
                ),
                // 글자는 그림으로 그린다 (화면의 다른 글자와 헷갈리지 않게)
                child: _PaintedText(widget.label, Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700, height: 1)),
              ),
              ),
            CustomPaint(size: const Size(20, 13), painter: _Tri()),
          ]),
        )),
      );
}

class _PaintedText extends StatelessWidget {
  const _PaintedText(this.text, this.style);
  final String text;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    return CustomPaint(size: tp.size, painter: _TextPaint(tp));
  }
}

class _TextPaint extends CustomPainter {
  _TextPaint(this.tp);
  final TextPainter tp;
  @override
  void paint(Canvas canvas, Size size) => tp.paint(canvas, Offset.zero);
  @override
  bool shouldRepaint(_TextPaint old) => old.tp.text != tp.text;
}

class _Tri extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    canvas.drawShadow(p, Colors.black, 2, false);
    canvas.drawPath(p, Paint()..color = Ttc.amber);
  }

  @override
  bool shouldRepaint(_Tri old) => false;
}

// ======================= 등불 탑 카드 (웹 towerHtml 5102) =======================
List<Widget> towerCard(Game g) {
  if (!g.towerOpen && g.towerN == 0) return const [];
  final n = g.towerN, t = g.towerNext(), c = g.towerCost, ok = g.towerOk, hi = n >= 5;
  return [
    hl(
      'tower',
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: hi ? const [Color(0xFFFFF8E4), Color(0xFFFFE9B0)] : const [Color(0xFFFFF6DC), Color(0xFFF6E7C3)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x59B0452A), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x40E0B441), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(hi ? '등불 탑 · ${t.n} 올리기' : '등불 탑 · ${n + 1}단계 ${t.n}', style: Ttc.t(16, color: const Color(0xFF7A3A1C), weight: FontWeight.w700))),
            Text(hi ? '지금 $n층 · 모든 생산 +${(g.towerBonus * 100).round()}%' : '$n/5', style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w700)),
          ]),
          if (!hi)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 7, 0, 6),
              child: Row(children: [
                for (var k = 0; k < 5; k++) ...[
                  if (k > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: k < n ? const Color(0xFFE0B441) : k == n ? null : const Color(0x243B2A1A),
                        gradient: k == n
                            ? const LinearGradient(colors: [Color(0xFFE0B441), Color(0xFFE0B441), Color(0x59E0B441), Color(0x59E0B441)], stops: [0, .5, .5, 1], tileMode: TileMode.repeated, end: Alignment(-.8, 0))
                            : null,
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          Text('${t.d}${hi && (n + 1) % 5 == 0 ? ' · 5층마다 특별한 선물이 있어요' : ''}', style: Ttc.t(13, color: Ttc.sepia2, height: 1.45)),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final r in t.req)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('${r.$2(g) ? '✓' : '·'} ${r.$1}', style: Ttc.t(12.5, color: r.$2(g) ? Ttc.ok : const Color(0xFF9A4A2A), weight: FontWeight.w600)),
                ),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(0, 4, 0, 10), child: costWrap(g, c)),
          BuyButton(n == 4 ? '스위치 올리기' : '${t.n} 쌓기', width: double.infinity, onTap: ok ? () => g.buildTower() : null),
        ]),
      ),
      radius: 14,
    ),
  ];
}

// ======================= 일지 · 이야기 탭 (웹 renderSheet diary 2612) =======================
List<Widget> storyLog(Game g) {
  final doneN = math.min(g.mi, steps.length), out = <Widget>[sec('등불 일지')];
  for (var ci = 0; ci < chapters.length; ci++) {
    final c = chapters[ci], d = c.steps.where((s) => s.i < doneN).toList();
    if (d.isEmpty) continue;
    final fin = d.length == c.steps.length;
    final txt = d.map((s) {
      final ol = s.outro.where(g.lineOk).toList();
      return ol.isEmpty ? '' : ol.last.t;
    }).join(' ');
    out.add(_entry(Text.rich(TextSpan(children: [
      TextSpan(text: '${c.ch} · ${c.title}'),
      if (!fin) TextSpan(text: ' ${d.length}/${c.steps.length}', style: Ttc.t(12, color: Ttc.sepia2)),
    ])), txt));
  }
  if (doneN == 0) out.add(Opacity(opacity: .45, child: _entry(null, '첫 이야기를 끝내면 여기에 적혀요.')));
  return out;
}

Widget _entry(Widget? head, String p, {VoidCallback? onTap}) {
  final w = Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (head != null) DefaultTextStyle(style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700, height: 1.45), child: head),
      if (head != null) const SizedBox(height: 6),
      Text(p, style: Ttc.t(14, color: Ttc.sepia2, height: 1.7)),
    ]),
  );
  return onTap == null ? w : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: w);
}

/// 목격자의 일기 목록 (잠긴 것까지 7칸)
List<Widget> diaryLog(Game g, void Function(int k) open) => [
      sec('목격자의 일기'),
      for (var k = 0; k < 7; k++)
        g.S.found.contains(k)
            ? _entry(Text('${k + 1}. ${diaries[k].$1}'), diaries[k].$2, onTap: () => open(k))
            : Opacity(opacity: .45, child: _entry(Text('${k + 1}. ???'), '쉘터에서 더 먼 어둠 속에 있어요.')),
    ];

// ======================= 업적 (웹 renderAch 4099) =======================
List<Widget> achTab(Game g) {
  final title = g.title;
  final out = <Widget>[
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(TextSpan(children: [
        const TextSpan(text: '지금 칭호 '),
        TextSpan(text: title, style: const TextStyle(color: Color(0xFFB0452A), fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
        const TextSpan(text: ' · 받은 업적의 칭호를 눌러 바꿀 수 있어요'),
      ]), style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
    ),
    _achRow(on: title == '등불지기', head: GestureDetector(onTap: () => g.title = '등불지기', child: Text('등불지기', style: _achB)), small: '처음부터 가진 칭호'),
  ];
  final rows = [
    for (var i = 0; i < achList.length; i++) (a: achList[i], i: i, st: g.achState(achList[i].$1), p: math.min(achList[i].$4, g.achVal(achList[i].$1)) / achList[i].$4)
  ]..sort((x, y) {
      int gr(int s) => s == 1 ? 0 : s == 0 ? 1 : 2;
      final a = gr(x.st) - gr(y.st);
      if (a != 0) return a;
      if (x.st == 0 && y.p != x.p) return y.p.compareTo(x.p);
      return x.i - y.i;
    });
  var grp = '';
  for (final r in rows) {
    final a = r.a, st = r.st, v = math.min(a.$4, g.achVal(a.$1));
    final gname = st == 1 ? '받을 수 있어요' : st == 0 ? '진행 중' : '받은 업적';
    if (gname != grp) {
      grp = gname;
      out.add(sec(gname));
    }
    out.add(Opacity(
      opacity: st == 0 ? .6 : 1,
      child: _achRow(
        on: st == 2 && title == a.$2,
        head: st == 2
            ? GestureDetector(onTap: () => g.title = a.$2, child: Text(a.$2, style: _achB.copyWith(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted)))
            : Text(st != 0 ? a.$2 : '???', style: _achB),
        small: '${a.$3} · $v/${a.$4}',
        bar: v / a.$4,
        side: st == 1
            ? BuyButton('받기 · 건전지 ${a.$5}', width: 112, onTap: () => g.achGet(a.$1))
            : st == 2
                ? Text('✓', style: Ttc.t(14, color: Ttc.ok, weight: FontWeight.w700))
                : null,
      ),
    ));
  }
  return out;
}

final _achB = Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700);

Widget _achRow({required bool on, required Widget head, required String small, double? bar, Widget? side}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(color: on ? const Color(0xFFFBECC4) : null, border: const Border(bottom: BorderSide(color: Color(0x333B2A1A)))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            head,
            const SizedBox(height: 2),
            Text(small, style: Ttc.t(12, color: Ttc.sepia2)),
            if (bar != null)
              Container(
                height: 6,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: const Color(0x263B2A1A), borderRadius: BorderRadius.circular(3)),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(widthFactor: bar.clamp(0, 1).toDouble(), child: Container(decoration: BoxDecoration(color: Ttc.amber, borderRadius: BorderRadius.circular(3)))),
              ),
          ]),
        ),
        if (side != null) ...[const SizedBox(width: 8), side],
      ]),
    );

// ======================= 안내서 (웹 renderGuide 4372) =======================
List<Widget> guideTab(BuildContext context, Game g) {
  Widget gs(String t, List<InlineSpan> body) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Ttc.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text.rich(TextSpan(children: body), style: Ttc.t(13, color: Ttc.sepia2, height: 1.65)),
        ]),
      );
  TextSpan b(String s) => TextSpan(text: s, style: const TextStyle(color: Ttc.sepia, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)]));
  TextSpan p(String s) => TextSpan(text: s);
  return [
    // 열린 기능 안내 (웹 renderGuide fclist)
    ...featListSection(context, g, go: (k) => FeatNav.go?.call(k)),
    gs('기본 조작', [
      p('· 빛이 새는 구름을 두드려 땅을 밝혀요. '),
      b('꾹 누르고 있으면'),
      p(' 계속 두드려요. 화면 안에 보이는 구름까지, 한 번에 최대 30개 걷혀요. 더 걷으려면 손을 뗐다 다시 누르거나 지도를 옮겨요.\n· 왼쪽 아래 '),
      b('랜턴 버튼'),
      p('은 조준한 칸(점선 원)을 두드려요.\n· 쉬지 않고 두드리면 랜턴이 차올라 '),
      b('피버'),
      p('가 켜지고, 그동안 모든 수확이 두 배예요.\n· 두 손가락으로 확대·축소, 끌어서 지도를 옮겨요.\n· 왼쪽 위 초상화를 누르면 내 프로필이 열려요. 이름과 초상화를 바꾸고 지금까지의 기록을 볼 수 있어요.'),
    ]),
    gs('자재와 창고', [
      p('· 무너진 집·폐차·상점·벙커를 두드리면 자재가 나와요. 털린 곳은 시간이 지나면 다시 쌓여요.\n· 기본 자재와 철판·밧줄은 창고 한도까지, 전선·약품은 그 1/4까지만 모여요(건전지는 한도 없음). 창고 모듈과 증축으로 늘려요.\n· 철판·밧줄은 작업대에서 만들고, 전선·약품은 벙커·원정·지하에서 나오고, 작업대에서 조립하거나 달여 만들 수도 있어요.\n· 남는 목재는 숯으로 구워 연료로, 남는 식량은 약초 달이기나 마을 잔치(쉘터 Lv.3)에 써요.'),
    ]),
    gs('쉘터와 모듈', [
      p('· 가운데 쉘터를 누르면 건설·가공·창고·꾸미기 화면이 열려요. 꾸미기는 첫 동네에서 컨테이너 쉘터(Lv.3)부터예요.\n· 모듈이 일정 수 이상 있어야 증축할 수 있어요. 텃밭·고물상·창고·랜턴탑은 여러 개 지을 수 있어요.\n· 지도의 모듈을 누르면 빠른 메뉴(강화·배치)가 떠요.'),
    ]),
    gs('생존자', [
      p('· 구조 신호를 따라가 잔해를 치우고 필요한 물자와 빈 침상이 있으면 구조해요.\n· 딱 맞는 모듈에 배치하면 효과가 커지고, 일할수록 신뢰가 쌓여 사연과 그 사람의 이야기가 열려요. 새로 열린 이야기는 위쪽 이야기 띠에 ‘새 이야기’로 떠요.\n· 생존자의 부탁: 지도 왼쪽 위 한 줄 띠예요. 누르면 펼쳐지고, 다 하면 ‘받기’로 보상을 받아요.\n· 일터가 없는 사람은 ‘쉴 때 할 일’을 해요: 주워 오기(자재 조금씩 · 기본), 훈련(신뢰 절반 속도), 순찰(밤에 재 걷기), 아이 돌보기(아이가 빨리 자라고 돌보는 사람을 닮아요).\n· 쉘터 Lv.3부터 생존자 수첩의 ‘자동 배치’로 딱 맞는 사람을 한 번에 앉힐 수 있어요. 스위치를 켜 두면 빈 일터를 알아서 채워요.\n· 쉘터 Lv.4부터 원정 탭의 ‘자동 원정’을 켜면, 쉬는 사람(순찰·아이 돌보기 제외)으로 가장 효율 좋은 팀을 꾸려 보내고 돌아오면 전리품을 알아서 챙겨요. 팀을 꾸릴 때 ‘자동 팀’ 버튼도 쓸 수 있어요.\n· 등급: ${[for (var i = 0; i < 4; i++) '${grades[i].n} ×${grades[i].m}'].join(' · ')} · 등급은 처음 정해진 그대로이고, 신뢰와 자재로 1~5성까지 올려요.'),
    ]),
    gs('밤과 재폭풍', [
      p('· 밤마다 가장자리에 붉은 재가 쌓여요. 제때 걷어내지 않으면 땅이나 모듈을 잃어요.\n· 세 번째 밤마다(공단은 두 번째) '),
      b('대형 재폭풍'),
      p('이 와요. 화면 어디든 두드리거나 문질러서 막아요. 랜턴탑·일하는 생존자·동맹이 함께 싸워요.'),
    ]),
    gs('날씨', [
      for (final w in wxInfo.values) ...[p('${w.ic} '), b(w.n), p(' ${w.d}\n')],
    ]),
    gs('원정·지하·라디오', [
      p('· 원정: 생존자를 보내 시간이 지나면 물자와 이야기를 가져와요.\n· 지하: 첫 동네에서는 5장(컨테이너 밑 맨홀)부터 열려요. 랜턴 기름이 버티는 만큼 내려가요. 기름이 떨어지면 전리품 절반을 잃어요. 5층부터는 계단참에서 그날 밤의 기록 조각을 줍기도 해요. $ugDeep층 아래로는 끝없이 이어지고, 10층마다 깊은 곳의 재괴물이 조각을 지켜요.\n· 라디오: 첫 동네에서는 4장(창고에서 찾은 낡은 라디오)부터 돌릴 수 있어요. 건전지로 탐색해요. 히든 생존자는 여기서만 만나요. ${pity}번 안에 한 번은 반드시 나와요.'),
    ]),
    gs('매일 할 거리', [
      p('· 오늘의 할 일: 첫 동네에서는 4장에 은호가 온 뒤부터 열려요. 날마다 세 가지가 일지 ‘기록’ 맨 위에 와요. 지도 왼쪽 위 ‘연속’ 칩을 눌러도 바로 열려요. 하나마다 건전지 1, 셋 다 하면 연속 하루. 7일째엔 귀한 장비를 받아요. 하루 걸러도 처음부터 다시 셀 뿐 벌은 없어요.\n· 아침 보고: 30분 넘게 비웠다 돌아오면 말순(없으면 만수)이 그동안의 일을 알려 줘요.\n· 인연: 신뢰도 5 뒤에도 정은 계속 쌓여요. 인연 선물은 하루 한 번, 단계마다 짧은 이야기가 열리고 3단계엔 고유 장비가 있어요.'),
    ]),
    gs('이주', [p('· 불빛의 도시를 완성하면 새 동네로 떠날 수 있어요. 사람·장비·유물은 함께 가고, 등불의 기억(생산·두드리기 +10%)이 쌓여요.')]),
    gs('펫', [
      p('· 첫 동네에서는 3장 사건이 풀려 떠돌이 개가 식구가 되면, 새 동네에서는 처음부터 지도에 떠돌이 동물의 발자국이 찍혀요. 눌러서 먹이를 두고 오기를 몇 번 하면 식구가 돼요.\n· 동행 펫 한 마리는 랜턴 곁을 따라다니며 효과를 모두 내고 재주를 부려요. 쉬는 펫은 효과가 절반이에요.\n· 지도에서 펫을 누르면 쓰다듬고, 한 번 더 누르면 자세히 볼 수 있어요. 쓰다듬기·먹이로 친밀도가 오르면 효과가 커지고 사연이 열려요.\n· 잘 맞는 생존자와 함께 있으면 희망이 오르고 더 빨리 친해져요. 원정·지하에도 데려갈 수 있어요.\n· 히든 펫 3마리는 특별한 곳과 때에만 나타나요.'),
    ]),
  ];
}

// ======================= 그날 밤 이후: 첫 동네 안내 카드 (웹 onboardHtml) =======================
Future<void> showOnboard(BuildContext context, Game g, {required VoidCallback onTour}) => showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Ttc.dim,
      builder: (ctx) {
        const st = [
          ('구름 두드리기', '빛이 새는 구름을 두드려 땅을 밝혀요.'),
          ('자재 모으기', '무너진 집·폐차를 두드려요.'),
          ('쉘터 짓기', '텐트를 눌러 모듈을 짓고 증축해요.'),
          ('사람 구하기', '깜빡이는 구조 신호를 따라가요.'),
          ('밤 버티기', '가장자리의 붉은 재를 걷어내요.'),
        ];
        return PopScope(canPop: false, child: Dialog(
          backgroundColor: Ttc.paper,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x66EEE5D3))),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Text('그날 밤 이후', style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                  child: Row(children: [
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: const Color(0xFF2C333B), borderRadius: BorderRadius.circular(14)),
                      child: CoverPic('underground-icons.webp', const Rect.fromLTWH(2 * 256.0 + 8, 3 * 256.0 + 8, 240, 240)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('마흔세 날 뒤,\n재 속의 텐트', style: Ttc.t(23, color: Ttc.sepia, weight: FontWeight.w700, height: 1.3))),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 2, 0, 12),
                  child: Text.rich(TextSpan(children: const [
                    TextSpan(text: '그날 밤은 끝났어요. 이제 랜턴 하나로 재 덮인 동네를 밝히고, 텐트를 쉘터로 키워 살아남은 사람들을 모아요. 쉘터가 '),
                    TextSpan(text: '불빛의 도시', style: TextStyle(fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
                    TextSpan(text: '가 되면 다음 동네로 떠날 수 있어요.'),
                  ]), style: Ttc.t(15, color: const Color(0xFF30281F), height: 1.6)),
                ),
                Text('이렇게 진행돼요', style: Ttc.t(12.5, color: const Color(0xFF73634E), weight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (var k = 0; k < st.length; k++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(color: const Color(0x0F3B2A1A), borderRadius: BorderRadius.circular(10)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 21,
                        height: 21,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2C333B)),
                        child: Text('${k + 1}', style: Ttc.t(12, color: const Color(0xFFFFDF9E), weight: FontWeight.w700, height: 1)),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: st[k].$1, style: const TextStyle(color: Color(0xFF2C333B), fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
                          TextSpan(text: ' · ${st[k].$2}'),
                        ]), style: Ttc.t(14, color: const Color(0xFF30281F), height: 1.5)),
                      ),
                    ]),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  _pbtn('바로 시작', () {
                    Navigator.pop(ctx);
                    g.onbEnd();
                  }, alt: true),
                  const SizedBox(width: 8),
                  _pbtn('화면 둘러보기', () {
                    Navigator.pop(ctx);
                    onTour();
                  }),
                ]),
              ]),
            ),
          ),
        ));
      },
    );

Widget _pbtn(String t, VoidCallback onTap, {bool alt = false}) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: alt ? Colors.transparent : Ttc.amberBtn,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: alt ? const Color(0x47252E36) : Ttc.amberBtnLine),
          ),
          child: Text(t, style: Ttc.t(14, color: const Color(0xFF243039), weight: FontWeight.w700)),
        ),
      ),
    );

// ======================= 화면 둘러보기 (웹 onbTour · #coach) =======================
const coachSteps = [
  ('모은 자재', '누르면 전체 자재와 창고 한도가 보여요.'),
  ('지금 할 일', '지금 할 일 한 줄이에요. 목표를 다 하면 이 줄이 ‘받기’가 돼요. 오른쪽 배지에 목표·부탁·오늘의 할 일이 모여 있고, 왼쪽 칩은 쉘터 레벨이에요.'),
  ('낮과 밤', '밤까지 남은 시간과 날씨가 보여요.'),
  ('랜턴 버튼', '조준한 칸을 두드려요. 연달아 두드리면 피버, 수확 두 배.'),
  ('메뉴', '기능은 차례로 열리고, 열릴 때 안내 카드가 떠요.'),
];

class CoachOverlay extends StatelessWidget {
  const CoachOverlay({super.key, required this.i, required this.hole, required this.onNext, required this.onSkip});
  final int i;
  final Rect hole;
  final VoidCallback onNext, onSkip;
  @override
  Widget build(BuildContext context) {
    final scr = MediaQuery.of(context).size, h = hole.inflate(6), below = hole.center.dy < scr.height / 2;
    final bub = Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(color: const Color(0xFFEFE3C4), borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(coachSteps[i].$1, style: Ttc.t(16, color: const Color(0xFF30281F), weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(coachSteps[i].$2, style: Ttc.t(14, color: const Color(0xFF30281F), height: 1.55)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          GestureDetector(
            onTap: onSkip,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), child: Text('건너뛰기', style: Ttc.t(13.5, color: const Color(0xFF73634E), weight: FontWeight.w700))),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: const Color(0xFF2C333B), borderRadius: BorderRadius.circular(99)),
              child: Text(i == coachSteps.length - 1 ? '시작하기' : '다음 (${i + 1}/${coachSteps.length})', style: Ttc.t(13.5, color: const Color(0xFFFFDF9E), weight: FontWeight.w700)),
            ),
          ),
        ]),
      ]),
    );
    return Stack(children: [
      Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}, child: CustomPaint(painter: _HolePainter(h)))),
      Positioned(
        left: 16,
        right: 16,
        top: below ? h.bottom + 14 : null,
        bottom: below ? null : scr.height - h.top + 14,
        child: Center(child: bub),
      ),
    ]);
  }
}

class _HolePainter extends CustomPainter {
  _HolePainter(this.hole);
  final Rect hole;
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(hole, const Radius.circular(12));
    canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(r)), Paint()..color = const Color(0xB8080A0E));
    canvas.drawRRect(
        r.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFF3A53A));
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.hole != hole;
}
