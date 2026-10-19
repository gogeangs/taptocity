// 시즌 1 화면: 사건 창(.page.case), 까마귀 접촉, 사건 수첩·수상한 밤 목록, 사라진 3분 조각·찢어진 페이지,
// 회상 갤러리(.scene-grid), 엔딩 카드(#endcard), 기척 화면 효과. 웹 index.html 1182–1228, 5744–6003, qa.css 36–59.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/web_data.g.dart' as web;
import '../game/data.dart';
import '../game/engine.dart';
import 'atlas.dart';
import 'cuts_ui.dart';
import 'portrait.dart';
import 'profile_ui.dart';
import 'story_ui.dart';
import 'survivors.dart';
import 'sound.dart';
import 'theme.dart';
import 'widgets.dart';

// ======================= 사건 대사 줄 (웹 caseLines) =======================
/// 같은 사람이 잇달아 한 말은 말풍선 하나로 묶는다 (얼굴·이름은 한 번)
Widget caseLines(Game g, List<Line> ls) {
  final groups = <List<Line>>[];
  for (final l in g.talkLines(ls)) {
    if (groups.isNotEmpty && groups.last.first.who == l.who) {
      groups.last.add(l);
    } else {
      groups.add([l]);
    }
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    for (final gr in groups)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _csAv(g, gr.first.who),
          const SizedBox(width: 9),
          Expanded(child: _csP(g, gr)),
        ]),
      ),
  ]);
}

/// 사건·선택 창의 작은 얼굴. 나는 대화 창(_avatar)과 같이: 초상화를 골랐으면 그 얼굴, 아니면 랜턴 배지
Widget _csAv(Game g, Object who, {double sz = 38}) {
  final id = who is String && who.startsWith('npc:') ? null : g.speakerId(who);
  final me = who == 'me' || (id == null && !(who is String && who.startsWith('npc:')));
  if (me && !g.pfSet) return meLantern(sz);
  return Container(
    width: sz,
    height: sz,
    decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE6D8B6), border: Border.all(color: const Color(0x403B2A1A), width: 1.5)),
    clipBehavior: Clip.antiAlias,
    child: id != null ? Portrait(id, width: sz, height: sz * 44 / 38) : me ? pfPortrait(g.pfIndex()) : npcFace(who as String),
  );
}

/// 이름 있는 바깥사람 얼굴 (웹 chapter-design.js npc): 독수리는 crows-kids, 진은 survivors-scouts
Widget npcFace(String who) {
  final k = who.substring(4);
  if (k == 'jin') return CoverPic('survivors-scouts.webp', const Rect.fromLTWH(826, 6, 808, 946), alignY: 0);
  if (k == 'crow') return CoverPic('crows-kids.webp', const Rect.fromLTWH(6, 6, 674, 750), alignY: 0);
  final n = const {'desert': 0, 'factory': 1, 'snow': 2}[k];
  if (n != null) return CoverPic('regional-npcs.webp', Rect.fromLTWH(n * 686.0 + 6, 6, 674, 750), alignY: 0);
  return const SizedBox.shrink();
}

Widget _csP(Game g, List<Line> ls) {
  final who = ls.first.who;
  final me = who == 'me';
  final name = who is String && who.startsWith('npc:') ? npcName[who.substring(4)]?.$1 ?? '' : g.speakerName(who);
  List<Widget> lines(TextStyle st) => [
        for (var i = 0; i < ls.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 6), child: Text(ls[i].t, style: st)),
      ];
  if (me) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines(Ttc.t(14.5, color: Ttc.sepia, height: 1.55).copyWith(fontStyle: FontStyle.italic))),
    );
  }
  return Container(
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
    decoration: const BoxDecoration(color: Color(0x66FFFFFF), borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(12), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: Ttc.t(11.5, color: const Color(0xFFB0452A), weight: FontWeight.w700, height: 1.2)),
      const SizedBox(height: 2),
      ...lines(Ttc.t(14.5, color: const Color(0xFF4A3320), height: 1.55)),
    ]),
  );
}

Widget _stamp(bool ok) => Transform.rotate(
      angle: -6 * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 3),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: ok ? const Color(0xFFB0452A) : const Color(0xFF8A7A64), width: 2)),
        child: Text(ok ? '해결' : '미해결', style: Ttc.t(12, color: ok ? const Color(0xFFB0452A) : const Color(0xFF8A7A64), weight: FontWeight.w800, height: 1)),
      ),
    );

Widget _fxChips(List<String> fx) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(spacing: 5, runSpacing: 5, children: [
        for (final t in fx)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: RegExp(r'-\d|다침|통행료|더딤').hasMatch(t) ? const Color(0x1FB0452A) : const Color(0x246F9646), borderRadius: BorderRadius.circular(99)),
            child: Text(t, style: Ttc.t(13, color: RegExp(r'-\d|다침|통행료|더딤').hasMatch(t) ? const Color(0xFFB0452A) : Ttc.ok, weight: FontWeight.w600, height: 1)),
          ),
      ]),
    );

Widget _copt(String b, String small, VoidCallback? onTap, {bool hi = false}) => GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .6 : 1,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: hi ? const Color(0xFFFFF8EA) : const Color(0xFFF8F3E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hi ? const Color(0xFFB0452A) : const Color(0x2926333B), width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b, style: Ttc.t(15.5, color: const Color(0xFF26333B), weight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 4),
            Text(small, style: Ttc.t(12, color: const Color(0xFF56646A), height: 1.4)),
          ]),
        ),
      ),
    );

/// 사건 그림 (story-5 36~41번, 동네 사건 42~44번).
/// 풀리기 전(clue)에는 그림이 답을 보여 주지 않게 어둡게 흐린 '단서' 그림으로 (앱 2026-10-18)
Widget _caseArt(Game g, int k, {bool clue = false}) {
  g.markArt(36 + k);
  return Padding(padding: const EdgeInsets.only(bottom: 12), child: caseArtBox(k, clue: clue));
}

Widget caseArtBox(int k, {required bool clue, double aspect = 1.5, bool small = false}) {
  final n = 36 + k;
  return ValueListenableBuilder<int>(
    valueListenable: Atlas.version,
    builder: (c, _, __) {
      final r = storyRect(n);
      if (r == null) return const SizedBox.shrink();
      final pic = CoverPic(storyFile(n), r);
      return Container(
        decoration: BoxDecoration(color: const Color(0xFF35404A), borderRadius: BorderRadius.circular(small ? 8 : 10)),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: aspect,
          child: !clue
              ? pic
              : Stack(fit: StackFit.expand, children: [
                  // 가장자리가 비어 보이지 않게 조금 키워서 흐린다
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: small ? 8 : 14, sigmaY: small ? 8 : 14),
                    child: Transform.scale(scale: 1.18, child: pic),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(radius: .9, colors: [Color(0x8C10151B), Color(0xD910151B)]),
                    ),
                  ),
                  Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('?', style: Ttc.t(small ? 22 : 40, color: const Color(0xFFF3D9A0), weight: FontWeight.w700, height: 1)),
                      if (!small) ...[
                        const SizedBox(height: 8),
                        Text('무슨 일이 있었을까', style: Ttc.t(13, color: const Color(0xE6F3E6C6), weight: FontWeight.w600, height: 1.2)),
                      ],
                    ]),
                  ),
                ]),
        ),
      );
    },
  );
}

/// 사건·선택 창. foot(고르는 버튼들)이 있으면 창 아래에 붙여 두고 위 내용만 스크롤한다:
/// 작은 폰(320×640)에서도 고를 거리가 잘리지 않게. 스크롤 끝은 옅게 흐려 더 있다는 걸 보인다
Future<void> _casePage(BuildContext context, Widget Function(BuildContext ctx) body, {Widget Function(BuildContext ctx)? foot}) => showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xC70F161D),
      builder: (ctx) {
        final short = MediaQuery.of(ctx).size.height <= 700;
        final pad = short ? 14.0 : 18.0;
        return Dialog(
          backgroundColor: Ttc.paper,
          insetPadding: EdgeInsets.all(short ? 12 : 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x66EEE5D3))),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: foot == null
                ? SingleChildScrollView(padding: EdgeInsets.all(pad), child: body(ctx))
                : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Flexible(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (r) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
                          stops: [0, r.height <= 16 ? 0 : (r.height - 16) / r.height, 1],
                        ).createShader(r),
                        child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(pad, pad, pad, 16), child: body(ctx)),
                      ),
                    ),
                    Padding(padding: EdgeInsets.fromLTRB(pad, 2, pad, pad), child: foot(ctx)),
                  ]),
          ),
        );
      },
    );

// ======================= 사건 창 (웹 openCase · pickCase) =======================
Future<void> showCase(BuildContext context, Game g, int k) async {
  final c = caseOf(k);
  // 웹툰 컷 (앱 전용 2026-10-19): 처음 열 때 ①②③, 고른 결과를 본 뒤 ④
  final fresh = g.caseRec(k)?['p'] == null, cut = caseCut(k);
  if (fresh) await playCutOnce(context, g, cut, cut, const [0, 1, 2]);
  if (!context.mounted) return;
  String? picked;
  await _casePage(context, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _caseArt(g, k, clue: g.caseRec(k)?['solved'] == null),
        Text('사건 ${k + 1} · ${c.ch}', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
        Padding(padding: const EdgeInsets.fromLTRB(0, 2, 0, 6), child: Text(c.t, style: Ttc.t(19, color: Ttc.sepia, weight: FontWeight.w700))),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '${c.when} · 의심받는 사람: '),
            TextSpan(text: g.caseSus(k), style: const TextStyle(color: Color(0xFFB0452A))),
          ]), style: Ttc.t(12.5, color: Ttc.sepia2, weight: FontWeight.w600, height: 1.4)),
        ),
        caseLines(g, [for (final l in c.x(g)) if (l != null) l]),
      ]), foot: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('어떻게 할까요?', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final p in const ['a', 'b', 'c'])
          _copt(
              c.opt(p).l(g),
              p == 'a'
                  ? (c.tut ? '범인을 찾아봐요' : '진실에 다가가요 · 그 사람은 서운해해요')
                  : p == 'b'
                      ? '믿음이 깊어져요 · 단서를 놓칠 수 있어요'
                      : '조용히 넘어가요', () {
            picked = p;
            Navigator.pop(ctx);
          }, hi: p == 'a'),
      ]));
  if (picked == null || !context.mounted) return;
  final (ls, fx) = g.pickCase(k, picked!);
  Sound.buzzMid();
  await _casePage(context, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 풀린 사건이면 이제 그림을 그대로 보여 준다
        _caseArt(g, k, clue: g.caseRec(k)?['solved'] == null),
        Text('사건 ${k + 1} · ${c.ch}', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
        Padding(padding: const EdgeInsets.fromLTRB(0, 2, 0, 10), child: Text(c.t, style: Ttc.t(19, color: Ttc.sepia, weight: FontWeight.w700))),
        caseLines(g, ls),
        if (fx.isNotEmpty) _fxChips(fx),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [_stamp(c.solved), const SizedBox(width: 8), Text('사건 수첩에 적었어요', style: Ttc.t(13, color: Ttc.sepia2, height: 1.5))]),
        ),
        Row(children: [pageBtn('닫기', () => Navigator.pop(ctx))]),
      ]));
  if (!fresh || !context.mounted) return;
  await playCutOnce(context, g, '$cut:4', cut, const [3]);
}

// ======================= 정답 없는 선택 (앱 전용, game/tension.dart) =======================
Future<void> showChoice(BuildContext context, Game g) async {
  final v = g.choiceView();
  if (v == null) return;
  int? picked;
  await _casePage(context, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(v.tag, style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
        Padding(padding: const EdgeInsets.fromLTRB(0, 2, 0, 10), child: Text(v.title, style: Ttc.t(19, color: Ttc.sepia, weight: FontWeight.w700))),
        caseLines(g, v.lines),
      ]), foot: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('어떻게 할까요?', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (var k = 0; k < v.opts.length; k++)
          _copt(v.opts[k].$1, v.opts[k].$2, () {
            picked = k;
            Navigator.pop(ctx);
          }, hi: k == 0),
        Text('정답은 없어요. 해가 질 때까지 정하지 않으면 누군가 대신 정해요', style: Ttc.t(11.5, color: Ttc.sepia2, height: 1.4)),
      ]));
  if (picked == null || !context.mounted) return;
  final (ls, fx) = g.pickChoice(picked!);
  if (ls.isEmpty && fx.isEmpty) return;
  Sound.buzzMid();
  await _casePage(context, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(v.tag, style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
        Padding(padding: const EdgeInsets.fromLTRB(0, 2, 0, 10), child: Text(v.title, style: Ttc.t(19, color: Ttc.sepia, weight: FontWeight.w700))),
        caseLines(g, ls),
        if (fx.isNotEmpty) _fxChips(fx),
        Row(children: [pageBtn('닫기', () => Navigator.pop(ctx))]),
      ]));
}

// ======================= 까마귀 · 접촉 (웹 openCrowMeet) =======================
Future<void> showCrowMeet(BuildContext context, Game g) async {
  String? picked;
  final c = g.crowToll, ok = g.canPay(c);
  await _casePage(context, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('까마귀 · 접촉', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
        Padding(padding: const EdgeInsets.fromLTRB(0, 2, 0, 10), child: Text('길을 막은 사람들', style: Ttc.t(19, color: Ttc.sepia, weight: FontWeight.w700))),
        caseLines(g, const [
          Line('me', '원정대가 돌아오는 길목을 검은 옷의 무리가 막아섰다. 벽에서 보던 검은 새가 그들 팔에 그려져 있었다.'),
          Line('npc:crow', '이 길은 우리 길이오. 지나가려면 몫을 내시오.'),
          Line('npc:jin', '…대장, 저 사람들이 그 랜턴 가진 쪽이야.'),
        ]),
      ]), foot: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('어떻게 할까요?', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        _copt('통행료를 낸다', '${ok ? '' : '자재가 모자라요 · '}${g.lootText(c).replaceAll(' +', ' ')}', ok
            ? () {
                picked = 'deal';
                Navigator.pop(ctx);
              }
            : null, hi: true),
        _copt('맞선다', '누군가 다칠 수 있어요', () {
          picked = 'fight';
          Navigator.pop(ctx);
        }),
        _copt('돌아간다', '먼 길로 돌아와요', () {
          picked = 'avoid';
          Navigator.pop(ctx);
        }),
      ]));
  if (picked == null || !context.mounted) return;
  final (ls, fx) = g.pickCrow(picked!);
  await _casePage(context, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('까마귀 · 접촉', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
        Padding(padding: const EdgeInsets.fromLTRB(0, 2, 0, 10), child: Text('길을 막은 사람들', style: Ttc.t(19, color: Ttc.sepia, weight: FontWeight.w700))),
        caseLines(g, ls),
        if (fx.isNotEmpty) _fxChips(fx),
        Row(children: [pageBtn('닫기', () => Navigator.pop(ctx))]),
      ]));
}

// ======================= 사라진 3분: 조각과 찢어진 페이지 =======================
Future<void> showEgg(BuildContext context, {required String tag, required Widget body, String? note}) => _casePage(
    context,
    (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tag, style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          body,
          if (note != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(note, style: Ttc.t(13, color: Ttc.sepia2, height: 1.5))),
          Row(children: [pageBtn('닫기', () => Navigator.pop(ctx))]),
        ]));

Widget eggDark(List<String> ps) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFF2A1F16), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final p in ps) Text(p, style: Ttc.t(15, color: const Color(0xFFF3D9A0), height: 1.7))]),
    );

/// ① 실제 시각 03:11~03:14에 라디오를 열면 (웹 eggRadio)
void eggRadio(BuildContext context, Game g) {
  if (!g.lost3 || g.egg['a'] != null || (g.num_('gUses') == 0 && g.num_('gTotal') == 0)) return;
  final m = DateTime.now().minute;
  Future.delayed(const Duration(milliseconds: 500), () {
    if (!context.mounted) return;
    Sound.sfx('mystery');
    showEgg(context, tag: '03:$m · 잡음', body: eggDark(const ['…', '(한참 동안 아무 소리도 없다)', '“…여기는 한밤. 지금 바로 대피하—”']), note: '목소리는 거기서 뚝 끊겼다. 끊긴 시각은 3시 14분이었다.');
    g.eggGet('a', '끊긴 방송');
  });
}

/// ② 무전실이 서면 라디오 옆 작은 신호등이 ●●● ● ● 로 깜빡인다. 같은 박자로 두드려 답한다 (웹 mlamp)
class MorseLamp extends StatefulWidget {
  const MorseLamp(this.g, {super.key});
  final Game g;
  @override
  State<MorseLamp> createState() => _MorseLampState();
}

class _MorseLampState extends State<MorseLamp> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
  final List<int> taps = [];
  Timer? _to;
  int _hit = 0;
  @override
  void dispose() {
    a.dispose();
    _to?.cancel();
    super.dispose();
  }

  bool get _lit {
    if (DateTime.now().millisecondsSinceEpoch - _hit < 220) return true;
    final p = a.value * 100;
    return (p < 2) || (p >= 4 && p < 6) || (p >= 8 && p < 10) || (p >= 16 && p < 18) || (p >= 24 && p < 26);
  }

  void _tap() {
    _hit = DateTime.now().millisecondsSinceEpoch;
    taps.add(_hit);
    _to?.cancel();
    _to = Timer(const Duration(seconds: 2), () {
      final gs = <int>[];
      var n = 1;
      for (var i = 1; i < taps.length; i++) {
        if (taps[i] - taps[i - 1] > 700) {
          gs.add(n);
          n = 1;
        } else {
          n++;
        }
      }
      gs.add(n);
      taps.clear();
      if (gs.join(',') == '3,1,1' && mounted) {
        showEgg(context, tag: '신호등', body: eggDark(const ['● ● ●   ●   ●']), note: '깜빡임이 멈췄다. 3, 1, 1. 누군가 시각을 적어 둔 것 같았다.');
        widget.g.eggGet('b', '세 번, 한 번, 한 번');
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AnimatedBuilder(
            animation: a,
            builder: (c, _) {
              final on = _lit;
              return Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? const Color(0xFFFFD46A) : const Color(0xFF5A3A20),
                  border: Border.all(color: const Color(0xFF3B2A1A), width: 2),
                  boxShadow: on ? const [BoxShadow(color: Color(0xFFFFD46A), blurRadius: 12)] : null,
                ),
              );
            },
          ),
        ),
      );
}

/// ③ 태식의 손목시계 (신뢰도 2부터, 웹 watch)
Widget watchButton(BuildContext context, Game g) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: () {
          showEgg(context,
              tag: '문태식의 손목시계',
              body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                eggDark(const ['3시 11분.']),
                caseLines(g, const [Line(12, '다른 시계는 다 3시 14분에 섰는데, 이 녀석만 3분 먼저 멈췄지. 오래전 어느 연구원이 수리를 맡기고 끝내 찾으러 오지 않은 시계라오. 뒷면에 등불 문양이 있지. 이건 못 고치겠더군.')]),
              ]));
          g.eggGet('c', '3분 먼저 멈춘 시계');
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x47252E36))),
          child: Text('태식의 손목시계 살펴보기', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
        ),
      ),
    );

/// 찢어진 페이지 (웹 openEggPage)
void showEggPage(BuildContext context, Game g) {
  final c5 = g.caseRec(4)?['p'] != null;
  showEgg(context,
      tag: '찢어진 페이지',
      body: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        decoration: BoxDecoration(color: const Color(0xFFF4ECD8), border: Border.all(color: const Color(0x333B2A1A))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final p in const ['03:11 제어실 → 방송국 전화.', '대피 방송은 —', '(이 아래는 찢겨 나갔다)'])
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(p, style: Ttc.t(15, color: const Color(0xFF3B2A1A), height: 1.6))),
          const SizedBox(height: 6),
          Text('그날, 방송은 나가지 않았다.', style: Ttc.t(15, color: const Color(0xFF3B2A1A), weight: FontWeight.w700, height: 1.6)),
        ]),
      ),
      note: c5 ? '찢긴 자국이, 재혁의 노트에서 뜯겨 나간 자리와 꼭 맞는다.' : null);
}

// ======================= 일지 · 사건 탭 (웹 renderCases · renderOdd) =======================
List<Widget> casesTab(BuildContext context, Game g) {
  if (g.S.rest['caseNew'] != null) g.S.rest.remove('caseNew');
  final ks = g.caseKeys;
  final sol = ks.where((k) => g.caseRec(k)?['solved'] != null).length;
  final out = <Widget>[
    sec('사건 수첩', '풀린 사건 $sol / ${ks.length}'),
    Padding(padding: const EdgeInsets.only(bottom: 8), child: descText('쉘터에서 일어난 일을 적어 두는 수첩이에요. 단서는 사람을 추궁할 때만 모여요.')),
  ];
  for (final k in ks) {
    final c = caseOf(k), R = g.caseRec(k);
    if (R == null || R['p'] == null) {
      final gone = g.S.gen != 0 || g.mi >= steps.length;
      out.add(Opacity(opacity: .45, child: _entry('사건 ${k + 1} · ???', gone ? '이 쉘터에서는 적히지 않은 페이지예요.' : '${c.ch}에 무슨 일이 생길지도 몰라요.')));
      continue;
    }
    final p = R['p'] as String, solved = R['solved'] != null;
    final clues = [if (R['clue'] != null && c.opt(p).clue != null) c.opt(p).clue!, if (R['tail'] != null && c.tailClue != null) c.tailClue!];
    Widget cst(String a, String b) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 52, child: Text(a, style: Ttc.t(13, color: Ttc.sepia2, weight: FontWeight.w700, height: 1.55))),
            Expanded(child: Text(b, style: Ttc.t(13, color: const Color(0xFF4A3320), height: 1.55))),
          ]),
        );
    Widget csc(String t, {bool none = false}) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 5),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(color: none ? const Color(0x0F3B2A1A) : const Color(0x142F4A6A), borderRadius: BorderRadius.circular(6)),
          child: Text(t, style: Ttc.t(12.5, color: none ? Ttc.sepia2 : const Color(0xFF2F4A6A), weight: none ? FontWeight.w400 : FontWeight.w600, height: 1.5)),
        );
    out.add(Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.only(right: 64),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '사건 ${k + 1} · ${c.t} '),
              TextSpan(text: c.ch, style: Ttc.t(12, color: Ttc.sepia2)),
            ]), style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700, height: 1.45)),
            const SizedBox(height: 8),
            // 사건 그림: 풀렸으면 그대로, 아니면 흐린 단서 그림
            caseArtBox(k, clue: !solved, aspect: 2.4, small: true),
            const SizedBox(height: 8),
            cst('때', c.when),
            cst('의심', c.sus != null ? survivors[c.sus!].name : c.susN),
            if (c.alibi != null) cst('증언', c.alibi!),
            cst('내 선택', c.opt(p).l(g)),
            if (solved && c.log != null) cst('결말', c.log!) else if (clues.isNotEmpty) ...[for (final t in clues) csc('단서 · $t')] else csc('단서 없음', none: true),
            if (solved) cutReplayButton(context, caseCut(k), const [0, 1, 2, 3]),
          ]),
        ),
        Positioned(right: 4, top: 0, child: _stamp(solved)),
      ]),
    ));
  }
  // 수상한 밤
  final L = g.oddLogList;
  if (L.isNotEmpty) {
    out.add(sec('수상한 밤', '${L.length}번'));
    out.add(Padding(padding: const EdgeInsets.only(bottom: 6), child: descText('모두 새벽 3시 무렵이었어요.')));
    for (final o in L) {
      final m = o as Map;
      out.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${(m['r'] as String?)?.isNotEmpty == true ? '${m['r']} · ' : ''}${m['n']}번째 밤 · ${oddNames[m['k']] ?? ''}', style: Ttc.t(12.5, color: Ttc.sepia2, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${m['t']}', style: Ttc.t(13.5, color: Ttc.sepia2, height: 1.6)),
        ]),
      ));
    }
  }
  // 찢어진 페이지
  final got = ['a', 'b', 'c'].where((q) => g.egg[q] != null).length;
  if (got > 0) {
    out.add(g.egg['page'] != null
        ? GestureDetector(onTap: () => showEggPage(context, g), child: _entry('찢어진 페이지', '수첩 맨 뒤에 끼워져 있던 한 장.'))
        : Opacity(opacity: .45, child: _entry('찢어진 페이지 · $got/3', '어딘가에 나머지 조각이 있어요.')));
  }
  return out;
}

Widget _entry(String n, String p) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n, style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700, height: 1.45)),
        const SizedBox(height: 6),
        Text(p, style: Ttc.t(14, color: Ttc.sepia2, height: 1.7)),
      ]),
    );

// ======================= 회상 갤러리 (웹 renderScenes · openScene) =======================
List<Widget> scenesTab(BuildContext context, Game g) {
  g.artBackfill();
  if (g.S.rest['artNew'] != null) g.S.rest.remove('artNew');
  final order = [for (final n in web.storyArt['order'] as List) (n as num).toInt()];
  final cap = web.storyArt['cap'] as List;
  final seen = order.where((n) => g.artMap['$n'] != null).length;
  return [
    sec('회상', '$seen / ${order.length}'),
    Padding(padding: const EdgeInsets.only(bottom: 10), child: descText('지나온 장면을 다시 볼 수 있어요. 아직 보지 못한 장면은 이야기를 이어 가면 열려요.')),
    LayoutBuilder(builder: (c, box) {
      final cols = box.maxWidth >= 560 ? 3 : 2, w = (box.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (var k = 0; k < order.length; k++)
          SizedBox(
            width: w,
            child: g.artMap['${order[k]}'] != null
                ? GestureDetector(
                    onTap: () => showScene(context, g, order[k]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFF35404A), borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Color(0x2E171D24), blurRadius: 6, offset: Offset(0, 2))]),
                        clipBehavior: Clip.antiAlias,
                        child: AspectRatio(
                          aspectRatio: 1.5,
                          child: ValueListenableBuilder<int>(
                            valueListenable: Atlas.version,
                            builder: (c, _, __) {
                              final r = storyRect(order[k]);
                              return r == null ? const SizedBox.shrink() : CoverPic(storyFile(order[k]), r);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text('${cap[order[k]]}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ttc.t(12, color: const Color(0xFF26333B), weight: FontWeight.w600, height: 1.35)),
                    ]),
                  )
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AspectRatio(
                      aspectRatio: 1.5,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment(-.6, -.6),
                              colors: [Color(0xFFD9D3C4), Color(0xFFD9D3C4), Color(0xFFE2DCCD), Color(0xFFE2DCCD)],
                              stops: [0, .5, .5, 1],
                              tileMode: TileMode.repeated),
                        ),
                        child: Text('${k + 1}', style: Ttc.t(18, color: const Color(0xFF8A8F8C), weight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('아직 보지 못한 장면', style: Ttc.t(12, color: const Color(0xFF7D8789), weight: FontWeight.w500, height: 1.35)),
                  ]),
          ),
      ]);
    }),
    const SizedBox(height: 12),
  ];
}

void showScene(BuildContext context, Game g, int n) {
  final src = g.sceneSource(n), cap = (web.storyArt['cap'] as List)[n] as String;
  showPageOf(
      context,
      g,
      (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .4),
              decoration: BoxDecoration(color: const Color(0xFF35404A), borderRadius: BorderRadius.circular(10)),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 1.5,
                child: ValueListenableBuilder<int>(
                  valueListenable: Atlas.version,
                  builder: (c, _, __) {
                    final r = storyRect(n);
                    return r == null ? const SizedBox.shrink() : CoverPic(storyFile(n), r);
                  },
                ),
              ),
            ),
            Text(src?.$2 ?? '회상', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
            Padding(padding: const EdgeInsets.fromLTRB(0, 2, 0, 12), child: Text(cap, style: Ttc.t(23, color: Ttc.sepia, weight: FontWeight.w700))),
            if (src != null) ...[
              Row(children: [
                pageBtn('이 장면 다시 보기', () {
                  Navigator.pop(ctx);
                  final ending = identical(src.$1, endLines);
                  showTalk(context, g, FxTalk(g.talkLines(src.$1), tag: '회상 · ${src.$2}', noskip: ending, replay: true), onDone: () {
                    if (context.mounted) showScene(context, g, n);
                  });
                }),
              ]),
              const SizedBox(height: 8),
            ],
            Row(children: [pageBtn('닫기', () => Navigator.pop(ctx), alt: true)]),
          ]));
}

// ======================= 엔딩 카드 (웹 endCard · #endcard) =======================
class EndCard extends StatefulWidget {
  const EndCard({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<EndCard> createState() => _EndCardState();
}

class _EndCardState extends State<EndCard> {
  bool on = false, t = false, cut = false, go = false;
  String radio = '';
  final List<Timer> _ts = [];
  @override
  void initState() {
    super.initState();
    _ts.add(Timer(const Duration(milliseconds: 30), () => setState(() => on = true)));
    _ts.add(Timer(const Duration(milliseconds: 3200), () => setState(() => t = true)));
    _ts.add(Timer(const Duration(milliseconds: 6400), () {
      Sound.sfx('static');
      const txt = '…대피 방송은 —';
      var i = 0;
      _ts.add(Timer.periodic(const Duration(milliseconds: 110), (tm) {
        if (!mounted) {
          tm.cancel();
          return;
        }
        setState(() => radio = txt.substring(0, ++i));
        if (i >= txt.length) {
          tm.cancel();
          _ts.add(Timer(const Duration(milliseconds: 900), () => setState(() => cut = true)));
        }
      }));
    }));
    _ts.add(Timer(const Duration(milliseconds: 9000), () => setState(() => go = true)));
  }

  @override
  void dispose() {
    for (final x in _ts) {
      x.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: on ? 1 : 0,
        duration: const Duration(milliseconds: 1600),
        child: Container(
          color: const Color(0xFF050506),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedOpacity(
              opacity: t ? 1 : 0,
              duration: const Duration(milliseconds: 2200),
              child: Column(children: [
                Text('탭 투 시 티', style: Ttc.t(13, color: const Color(0xFF9A948A))),
                const SizedBox(height: 8),
                Text('시즌 1 끝', style: Ttc.t(26, color: const Color(0xFFE8E2D4), weight: FontWeight.w600).copyWith(letterSpacing: 4.7)),
              ]),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 22,
              child: AnimatedOpacity(
                opacity: cut ? 0 : 1,
                duration: const Duration(milliseconds: 80),
                child: Text(radio, style: const TextStyle(fontFamily: 'monospace', fontSize: 15, color: Color(0xFFB9C4C8), letterSpacing: .9)),
              ),
            ),
            const SizedBox(height: 28),
            AnimatedOpacity(
              opacity: go ? 1 : 0,
              duration: const Duration(milliseconds: 900),
              child: GestureDetector(
                onTap: go ? widget.onDone : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x66E8E2D4))),
                  child: Text('계속하기', style: Ttc.t(14, color: const Color(0xFFE8E2D4), weight: FontWeight.w600)),
                ),
              ),
            ),
          ]),
        ),
      );
}

// ======================= 기척: 화면 가장자리가 조여 오고 (웹 #stage.dread · .oddhit) =======================
class DreadLayer extends StatefulWidget {
  const DreadLayer(this.g, {super.key});
  final Game g;
  @override
  State<DreadLayer> createState() => _DreadLayerState();
}

class _DreadLayerState extends State<DreadLayer> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  Timer? _beat;
  int _hitAt = 0;

  @override
  void initState() {
    super.initState();
    widget.g.addListener(_check);
  }

  /// 조여 오는 동안·번쩍이는 동안만 움직인다 (평소엔 아무것도 그리지 않음)
  void _check() {
    final g = widget.g;
    if (g.oddHit != _hitAt && DateTime.now().millisecondsSinceEpoch - g.oddHit < 900) {
      _hitAt = g.oddHit;
      if (!a.isAnimating) a.repeat(reverse: true);
      Future.delayed(const Duration(milliseconds: 950), _check);
    }
    final need = g.dread || DateTime.now().millisecondsSinceEpoch - g.oddHit < 900;
    if (need && !a.isAnimating) a.repeat(reverse: true);
    if (!need && a.isAnimating) {
      a.stop();
      if (mounted) setState(() {});
    }
    // 심장 소리와 진동 (웹 tickDread: 두 번 쿵)
    if (g.dread && _beat == null) {
      _beat = Timer.periodic(const Duration(milliseconds: 1100), (_) {
        Sound.sfx('heart');
        Sound.buzz();
      });
    } else if (!g.dread && _beat != null) {
      _beat!.cancel();
      _beat = null;
    }
  }

  @override
  void dispose() {
    widget.g.removeListener(_check);
    a.dispose();
    _beat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: a,
          builder: (c, _) {
            final g = widget.g, now = DateTime.now().millisecondsSinceEpoch;
            final hit = now - g.oddHit < 900 ? 1 - (now - g.oddHit) / 900 : 0.0;
            if (!g.dread && hit <= 0) return const SizedBox.shrink();
            return Stack(children: [
              if (g.dread)
                Positioned.fill(
                  child: Opacity(
                    opacity: .55 + .45 * a.value,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(center: Alignment(0, -.08), radius: .9, colors: [Color(0x00000000), Color(0x8C140408), Color(0xF0040206)], stops: [.26, .62, 1]),
                      ),
                    ),
                  ),
                ),
              if (hit > 0) Positioned.fill(child: ColoredBox(color: Color.fromRGBO(5, 4, 10, hit.toDouble()))),
            ]);
          },
        ),
      );
}
