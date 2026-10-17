// 내 프로필 (웹 renderProfile·openPfName 4626–4680): 얼굴 없는 등불지기 초상화 넷, 이름, 기록.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'icons.dart';
import 'sound.dart';
import 'story_ui.dart';
import 'survivors.dart';
import 'theme.dart';
import 'widgets.dart';

const pfPortraits = [
  ('잿빛 탐색자', '방진 마스크와 고글'),
  ('이름 없는 등불지기', '깊은 후드 속의 그림자'),
  ('길 위의 뒷모습', '배낭을 메고 다음 동네로'),
  ('황혼의 나그네', '챙 넓은 모자와 목도리'),
];

/// 초상화 i번 (player-faceless.webp 4칸)
Widget pfPortrait(int i) => CoverPic('player-faceless.webp', Rect.fromLTWH(i * 514.5 + 8, 8, 498.5, 748), alignY: 0);

/// 머리 단추·대화 속 내 얼굴: 정했으면 초상화, 아니면 랜턴
Widget pfAvatar(Game g, {double size = 34}) => g.pfSet
    ? Container(
        width: size,
        height: size * 1.17,
        decoration: BoxDecoration(color: const Color(0xFFE6D8B6), borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: pfPortrait(g.pfIndex()))
    : SvgPicture.string(Ico.profileLamp, width: size, height: size);

String _fmtT(num s0) {
  final s = s0.floor(), h = s ~/ 3600, m = s % 3600 ~/ 60;
  return h > 0 ? '$h시간 $m분' : '$m분';
}

class ProfileBody extends StatefulWidget {
  const ProfileBody(this.g, {super.key});
  final Game g;
  @override
  State<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<ProfileBody> {
  Game get g => widget.g;
  String tab = 'me';
  int? draft;

  Widget _btn(String t, VoidCallback? onTap, {bool dark = false}) => GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .45 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF3E5C4C) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dark ? const Color(0xFF3E5C4C) : const Color(0x47252E36)),
            ),
            child: Text(t, style: Ttc.t(12.5, color: dark ? const Color(0xFFFFFDF5) : Ttc.sepia, weight: FontWeight.w700)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final S = g.S;
    final kids = <Widget>[
      Segs(items: const ['프로필', '꾸미기'], on: tab == 'me' ? 0 : 1, onTap: (k) => setState(() {
            tab = k == 0 ? 'me' : 'edit';
            draft = g.pfIndex();
            Sound.sfx('tap');
          })),
      const SizedBox(height: 10),
    ];
    if (tab == 'me') {
      final achN = g.achMap.values.where((v) => v == 2).length;
      kids.addAll([
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: Ttc.line)),
          child: Row(children: [
            Container(
              width: 112,
              height: 112 * 140 / 120,
              decoration: BoxDecoration(color: Ttc.sepia, borderRadius: BorderRadius.circular(10)),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: g.pfSet ? SizedBox.expand(child: pfPortrait(g.pfIndex())) : SvgPicture.string(Ico.profileLamp, width: 56, height: 56),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('칭호 · ${g.title}', style: Ttc.t(12, color: const Color(0xFF68766E), weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(g.pfName, style: Ttc.serif(22, color: Ttc.sepia, weight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 4),
                Text('Lv.${S.lv} ${shelterName[S.lv - 1]}${S.gen > 0 ? ' · ${S.gen + 1}번째 동네' : ''}', style: Ttc.t(12.5, color: Ttc.sepia2)),
                const SizedBox(height: 8),
                _btn('이름 바꾸기', () => showPfName(context, g, first: false).then((_) => setState(() {}))),
              ]),
            ),
          ]),
        ),
        sec('기록'),
        LayoutBuilder(builder: (c, box) {
          final w = (box.maxWidth - 6) / 2;
          final st = [
            ('플레이 시간', _fmtT(g.num_('playT'))),
            ('밝힌 땅', '${g.revCount}칸'),
            ('함께하는 생존자', '${S.sv.length}명'),
            ('막아낸 대형 재폭풍', '${g.num_('defWins').toInt()}번'),
            ('버틴 밤', '${g.num_('nights').toInt()}밤'),
            ('이주', '${S.gen}번'),
            ('모은 유물', '${g.relics.length}개'),
            ('받은 업적', '$achN/${achList.length}'),
            ('가장 깊이', '지하 ${g.ugBest}층'),
            ('그날 밤의 기록 조각', '${g.fragsGot.length}/${frags.length}'),
            ('오늘의 의뢰 연속', '${g.streakShown}일'),
            ('인연을 맺은 사람', '${g.bondN}명'),
          ];
          return Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (a, b) in st)
              Container(
                width: w,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(7), border: Border.all(color: Ttc.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b, style: Ttc.serif(16, color: Ttc.sepia, weight: FontWeight.w700, height: 1.2)),
                  const SizedBox(height: 2),
                  Text(a, style: Ttc.t(12, color: Ttc.sepia2)),
                ]),
              ),
          ]);
        }),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() {
            tab = 'edit';
            draft = g.pfIndex();
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF4A3A28), borderRadius: BorderRadius.circular(6)),
            child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '초상화 꾸미기 →\n', style: Ttc.t(14, color: const Color(0xFFFFCF7A), weight: FontWeight.w700, height: 1.5)),
                  const TextSpan(text: '얼굴이 드러나지 않는 네 가지 초상화 중에서 골라 보세요'),
                ]),
                style: Ttc.t(12.5, color: Ttc.paper, height: 1.45)),
          ),
        ),
      ]);
    } else {
      final sel = draft ?? g.pfIndex(), dirty = sel != g.pfIndex() || !g.pfSet;
      kids.addAll([
        Row(children: [
          Container(
            width: 100,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFB7BBAE))),
            child: ClipRRect(borderRadius: BorderRadius.circular(5), child: AspectRatio(aspectRatio: 498.5 / 748, child: pfPortrait(sel))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('얼굴 없는 등불지기', style: Ttc.t(10, color: const Color(0xFF68736B))),
              Text(pfPortraits[sel].$1, style: Ttc.t(17, color: const Color(0xFF2D393C), weight: FontWeight.w700)),
              Text(dirty ? '아직 저장하지 않은 모습이에요' : '현재 선택된 모습이에요', style: Ttc.t(11.5, color: Ttc.sepia2)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _btn('다른 모습', () => setState(() {
                      draft = g.pfRandom(sel);
                      Sound.sfx('tap');
                    }))),
                const SizedBox(width: 6),
                Expanded(child: _btn('되돌리기', dirty ? () => setState(() => draft = g.pfIndex()) : null)),
              ]),
              const SizedBox(height: 6),
              _btn('이 모습으로 저장', () {
                g.setPfPortrait(sel);
                g.fx.add(const FxToast('초상화를 저장했어요'));
                setState(() => tab = 'me');
              }, dark: true),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text('얼굴 대신, 당신의 여정을 보여 주세요.\n마음에 드는 초상화를 고르면 프로필과 대화에 함께 적용됩니다.', textAlign: TextAlign.center, style: Ttc.t(12.5, color: Ttc.sepia2, height: 1.5)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (c, box) {
          final w = (box.maxWidth - 8) / 2;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < pfPortraits.length; i++)
              GestureDetector(
                onTap: () => setState(() {
                  draft = i;
                  Sound.sfx('tap');
                }),
                child: Container(
                  width: w,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: sel == i ? const Color(0xFFFDF6DF) : Ttc.surface,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: sel == i ? const Color(0xFF3E5C4C) : Ttc.line, width: sel == i ? 2 : 1),
                  ),
                  child: Column(children: [
                    Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(6), child: AspectRatio(aspectRatio: 498.5 / 640, child: pfPortrait(i))),
                      if (sel == i)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF3E5C4C)),
                            child: Text('✓', style: Ttc.t(12, color: Colors.white, weight: FontWeight.w700, height: 1)),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Text(pfPortraits[i].$1, style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
                    Text(pfPortraits[i].$2, style: Ttc.t(11, color: Ttc.sepia2)),
                  ]),
                ),
              ),
          ]);
        }),
      ]);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 20), children: kids);
  }
}

/// 이름 창 (웹 openPfName). first면 프롤로그 뒤 처음 묻는 창: 초상화와 '다른 모습'
Future<void> showPfName(BuildContext context, Game g, {required bool first}) {
  final ctrl = TextEditingController(text: (g.pf['name'] as String?) ?? '');
  return showPageOf(context, g, (ctx) => StatefulBuilder(builder: (ctx, set) {
        void ok() {
          g.setPfName(ctrl.text);
          Navigator.pop(ctx);
          Sound.sfx('chime');
          g.fx.add(FxNote('반가워요, ${g.pfName}', '왼쪽 위 초상화를 누르면 프로필과 기록을 볼 수 있어요'));
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(first ? '등불지기의 이름' : '이름 바꾸기', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
          if (first) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 110,
                decoration: BoxDecoration(color: Ttc.sepia, borderRadius: BorderRadius.circular(10)),
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(aspectRatio: 120 / 140, child: pfPortrait(g.pfIndex())),
              ),
            ),
            const SizedBox(height: 10),
            Text('랜턴을 든 당신을 뭐라고 부를까요?\n초상화는 왼쪽 위 초상화를 눌러 언제든 꾸밀 수 있어요.', textAlign: TextAlign.center, style: Ttc.t(13, color: Ttc.sepia2, height: 1.55)),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            autofocus: !first,
            maxLength: 10,
            textAlign: TextAlign.center,
            style: Ttc.t(17, color: Ttc.sepia, weight: FontWeight.w700),
            onSubmitted: (_) => ok(),
            decoration: InputDecoration(
              hintText: '등불지기',
              counterText: '',
              hintStyle: Ttc.t(17, color: Ttc.sepia2),
              filled: true,
              fillColor: Ttc.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Ttc.line)),
            ),
          ),
          if (first) ...[
            const SizedBox(height: 8),
            Row(children: [
              pageBtn('다른 모습', () => set(() {
                    g.pf['portrait'] = g.pfRandom();
                    Sound.sfx('tap');
                  }), alt: true),
            ]),
          ],
          const SizedBox(height: 12),
          Row(children: [
            pageBtn(first ? '나중에' : '취소', () => Navigator.pop(ctx), alt: true),
            const SizedBox(width: 8),
            pageBtn(first ? '이 이름으로' : '바꾸기', ok),
          ]),
        ]);
      }));
}
