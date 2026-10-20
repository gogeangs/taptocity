// 웹툰 컷 (앱 전용 2026-10-19): assets/illustrated/cuts/*.webp 는 2×2 네 칸(①좌상 ②우상 ③좌하 ④우하) 그림.
// 한 칸씩 크게, 어두운 바탕 위에 만화 칸처럼 보여 준다. 탭하면 다음 칸, '건너뛰기'로 끝.
// 효과 글자(소리)는 칸 모서리에 손글씨처럼 얹는다. 감정 표현 '…!'은 고비 세 곳에만(cutBeat). 본 컷은 S.rest['cutSeen']에 적어 한 번만 보여 준다.
// 그림을 못 불러오면 조용히 건너뛴다 — 게임 진행은 이 창을 기다리지 않는다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/engine.dart';
import 'atlas.dart';
import 'sound.dart';
import 'story_ui.dart';
import 'theme.dart';

/// 효과 글자 (글자, 모서리 tl·tr·bl·br). 칸마다 하나 또는 없음
typedef CutSfx = (String, String);

const Map<String, List<CutSfx?>> cutSfx = {
  'case1': [null, null, ('삐걱', 'tr'), ('킁킁', 'br')],
  'case2': [('지직—', 'tl'), null, null, ('째깍', 'tr')],
  'case3': [null, ('툭', 'tr'), ('저벅 저벅', 'br'), null],
  'case4': [('휘잉—', 'tr'), null, ('지지직', 'br'), null],
  'case5': [('부욱—', 'tr'), null, ('드르륵', 'bl'), null],
  'case6': [('펄럭', 'tl'), null, null, ('딸깍', 'tr')],
  'case7': [('쏴아—', 'tr'), null, null, ('지직', 'br')],
  'case8': [('끼익—', 'tr'), null, null, ('저벅', 'bl')],
  'case9': [('딸깍', 'tr'), null, null, ('사박 사박', 'br')],
  'join_mansu': [('치익—', 'br'), null, null, ('부릉', 'tr')],
  'join_haneul': [('토독 토독', 'tr'), null, null, ('슥슥', 'br')],
  'join_sunrye': [('휘이잉', 'tr'), ('툭', 'br'), null, null],
  'join_malsun': [null, ('보글보글', 'tr'), null, null],
  'join_cheolho': [null, null, ('쾅 쾅', 'tr'), null],
  'join_eunho': [('지직—', 'tr'), null, null, null],
  'join_jaehyuk': [null, null, null, null],
  'join_jin': [('쏴아—', 'tr'), null, null, null],
  'join_miyoung': [('쏴아—', 'tr'), null, ('화륵', 'br'), null],
  'join_jin_choice': [('쏴아—', 'tr'), null, null, ('저벅', 'bl')],
};

/// 감정 표현 '…!' (2026-10-21 대표님 결정: 효과 글자는 소리 중심, 감정 표현은 시즌 전체에서 고비 세 곳만).
/// 컷 이름 → (칸 번호, 모서리). 소리 글자와 같은 칸에 있으면 반대쪽 모서리에 둔다
const Map<String, (int, String)> cutBeat = {
  'case1': (2, 'tl'), // 랜턴 빛에 발자국과 노란 우산 — 누구인지 알아챈 순간
  'join_jin_choice': (1, 'tl'), // 진의 손목에 까마귀 문신
  'join_jaehyuk': (1, 'tl'), // 재혁 손에 발전소 출입증
};

/// 생존자 id → 합류 컷 (재혁 9는 합류가 아니라 6장 고백 컷이라 여기 없다)
const Map<int, String> joinCuts = {
  0: 'join_mansu',
  3: 'join_haneul',
  4: 'join_sunrye',
  5: 'join_malsun',
  6: 'join_cheolho',
  10: 'join_eunho',
  13: 'join_miyoung',
  17: 'join_jin',
};

/// 사건 번호 k(0~8) → 컷 이름
String caseCut(int k) => 'case${k + 1}';

String cutFile(String name) => 'cuts/$name.webp';

/// 본 컷 적기 (S.rest['cutSeen']: 이름 목록)
extension CutSeen on Game {
  List<String> get cutSeenList {
    final v = S.rest['cutSeen'];
    return v is List ? [for (final e in v) '$e'] : const <String>[];
  }

  bool cutSeen(String key) => cutSeenList.contains(key);

  void cutMark(String key) {
    final l = cutSeenList;
    if (l.contains(key)) return;
    S.rest['cutSeen'] = <Object?>[...l, key];
    dirty = true;
  }
}

/// 컷 장면을 한 번만: 본 적 없으면 적고 보여 준다. 튜토리얼 중에는 건너뛴다 (적지도 않는다)
Future<void> playCutOnce(BuildContext context, Game g, String key, String name, List<int> panels) async {
  if (g.tut != null || g.cutSeen(key)) return;
  g.cutMark(key);
  await showCuts(context, name, panels);
}

String? _lastCut;

/// 컷 보기: name의 panels(0~3)를 차례로. 그림을 못 불러오면 아무것도 하지 않는다
Future<void> showCuts(BuildContext context, String name, List<int> panels) async {
  if (panels.isEmpty) return;
  final f = cutFile(name);
  // 크고 가끔 보는 그림이라 하나만 들고 있는다: 지난번 컷 그림은 놓아준다
  final last = _lastCut;
  if (last != null && last != f) Atlas.forget(last);
  _lastCut = f;
  try {
    if (Atlas.image(f) == null) await Atlas.ensure(f);
  } catch (_) {}
  if (!context.mounted) return;
  if (Atlas.image(f) == null) return;
  Sound.sfx('ui');
  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xEB050607),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, a, b) => CutView(name: name, panels: panels),
      transitionBuilder: (ctx, a, b, child) => FadeTransition(opacity: a, child: child),
    );
  } catch (_) {}
}

/// 그림 속 칸 자리 (가장자리 검은 줄이 안 보이게 안쪽으로 10px)
Rect cutRect(String f, int p) {
  final im = Atlas.image(f);
  final w = (im?.width ?? 1536) / 2, h = (im?.height ?? 1024) / 2, k = w / 768 * 10;
  return Rect.fromLTWH((p % 2) * w + k, (p ~/ 2) * h + k, w - 2 * k, h - 2 * k);
}

class CutView extends StatefulWidget {
  const CutView({super.key, required this.name, required this.panels});
  final String name;
  final List<int> panels;
  @override
  State<CutView> createState() => _CutViewState();
}

class _CutViewState extends State<CutView> {
  int i = 0;
  bool _done = false;

  void _close() {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop();
  }

  void _next() {
    if (_done) return;
    if (i + 1 >= widget.panels.length) {
      _close();
      return;
    }
    Sound.sfx('click');
    setState(() => i++);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.panels.length, p = widget.panels[i];
    final sfxs = cutSfx[widget.name];
    final sfx = sfxs != null && p < sfxs.length ? sfxs[p] : null;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: SafeArea(
          child: LayoutBuilder(builder: (c, bc) {
            final maxW = math.min(bc.maxWidth - 32, 620.0);
            final maxH = bc.maxHeight - 124;
            var pw = math.max(60.0, maxW), ph = pw / 1.5;
            if (ph > maxH) {
              ph = math.max(40.0, maxH);
              pw = ph * 1.5;
            }
            return Stack(children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('cut$i'),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  builder: (c, t, child) => Opacity(
                    opacity: math.min(1.0, math.max(0.0, t)),
                    child: Transform.translate(offset: Offset(0, (1 - t) * 22), child: child),
                  ),
                  child: _panel(cutFile(widget.name), p, pw, ph, sfx),
                ),
              ),
              if (n > 1)
                Positioned(
                  left: 18,
                  top: 16,
                  child: Text('${i + 1} / $n', style: Ttc.t(12.5, color: const Color(0xB3F3E9D2), weight: FontWeight.w600, height: 1)),
                ),
              Positioned(
                right: 4,
                top: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Text('건너뛰기', style: Ttc.t(13.5, color: const Color(0xD9F3E9D2), weight: FontWeight.w600, height: 1.2)),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 22,
                child: Center(child: Text('탭해서 계속 ›', style: Ttc.t(12.5, color: const Color(0x99F3E9D2), weight: FontWeight.w500, height: 1.2))),
              ),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _panel(String f, int p, double pw, double ph, CutSfx? sfx) {
    final fs = (pw / 340 * 38).clamp(32.0, 44.0);
    final seed = widget.name.codeUnits.fold<int>(0, (a, b) => a + b) + p * 7;
    final deg = (seed % 13) - 6.0;
    Widget? word;
    if (sfx != null) {
      final (t, corner) = sfx;
      final left = corner == 'tl' || corner == 'bl', top = corner == 'tl' || corner == 'tr';
      word = Positioned(
        left: left ? pw * .05 : null,
        right: left ? null : pw * .05,
        top: top ? ph * .06 : null,
        bottom: top ? null : ph * .07,
        child: TweenAnimationBuilder<double>(
          key: ValueKey('sfx$i'),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 460),
          curve: const Interval(.35, 1, curve: Curves.easeOutBack),
          builder: (c, k, child) => Opacity(
            opacity: math.min(1.0, math.max(0.0, k)),
            child: Transform.rotate(angle: deg * math.pi / 180, child: Transform.scale(scale: .4 + .6 * k, child: child)),
          ),
          child: cutWord(t, fs),
        ),
      );
    }
    Widget? beat;
    final bt = cutBeat[widget.name];
    if (bt != null && bt.$1 == p) {
      final corner = bt.$2, left = corner == 'tl' || corner == 'bl', top = corner == 'tl' || corner == 'tr';
      beat = Positioned(
        left: left ? pw * .06 : null,
        right: left ? null : pw * .06,
        top: top ? ph * .06 : null,
        bottom: top ? null : ph * .07,
        child: TweenAnimationBuilder<double>(
          key: ValueKey('beat$i'),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 520),
          curve: const Interval(.45, 1, curve: Curves.easeOutBack),
          builder: (c, k, child) => Opacity(opacity: math.min(1.0, math.max(0.0, k)), child: Transform.scale(scale: .5 + .5 * k, child: child)),
          child: cutWord('…!', fs * 1.05),
        ),
      );
    }
    return Container(
      width: pw,
      height: ph,
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        border: Border.all(color: const Color(0xFFF3E9D2), width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          CoverPic(f, cutRect(f, p)),
          if (word != null) word,
          if (beat != null) beat,
        ]),
      ),
    );
  }
}

/// 손글씨 효과 글자: 짙은 윤곽 위에 상아색 글자
Widget cutWord(String t, double size) {
  TextStyle st() => TextStyle(
        fontFamily: Ttc.sans,
        fontFamilyFallback: const ['Noto Sans KR', 'sans-serif'],
        fontSize: size,
        fontWeight: FontWeight.w900,
        fontVariations: const [FontVariation('wght', 900)],
        height: 1.1,
        letterSpacing: -1,
      );
  return Stack(children: [
    Text(
      t,
      softWrap: false,
      style: st().copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * .22
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF1A130E),
      ),
    ),
    Text(t, softWrap: false, style: st().copyWith(color: const Color(0xFFF7EDD3))),
  ]);
}

/// 다시 보기 버튼 (일지 사건 수첩 · 생존자 이야기 탭)
Widget cutReplayButton(BuildContext context, String name, List<int> panels, {String label = '컷 다시 보기'}) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () => showCuts(context, name, panels),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x47252E36))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: Ttc.t(12.5, color: Ttc.sepia, weight: FontWeight.w700, height: 1.2))),
          ]),
        ),
      ),
    );

/// 생존자 이야기 탭에서 다시 볼 수 있는 컷 (이름, 칸, 버튼 글)
List<(String, List<int>, String)> survivorCuts(int id) => [
      if (joinCuts[id] != null) (joinCuts[id]!, const [0, 1, 2, 3], '합류 컷 다시 보기'),
      if (id == 9) ('join_jaehyuk', const [0, 1, 2, 3], '고백 컷 다시 보기'),
      if (id == 17) ('join_jin_choice', const [0, 1, 2], '탑 아래 컷 다시 보기'),
    ];
