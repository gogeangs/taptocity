// 4단계 화면: 노친네·떠돌이 무리·아이·펫·떠돌이 동물·장식·잔치·유물
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/web_data.g.dart' as web;
import '../game/data.dart';
import '../game/engine.dart';
import 'atlas.dart';
import 'crisis_ui.dart';
import 'gear.dart';
import 'people.dart';
import 'survivors.dart';
import 'theme.dart';
import 'widgets.dart';

Widget _tag(String t) => Text(t, style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600));
Widget _h3(String t) => Padding(padding: const EdgeInsets.only(top: 4, bottom: 6), child: Text(t, textAlign: TextAlign.center, style: Ttc.t(20, color: Ttc.sepia, weight: FontWeight.w700)));
Widget _p(String t, {TextAlign align = TextAlign.left}) => Text(t, textAlign: align, style: Ttc.t(14, color: const Color(0xFF4A3320), height: 1.65));
Widget _trait(List<InlineSpan> s) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(color: const Color(0x0D3B2A1A), borderRadius: BorderRadius.circular(10)),
      child: Text.rich(TextSpan(children: s), style: Ttc.t(13, color: Ttc.sepia, height: 1.6)),
    );
TextSpan _b(String t) => TextSpan(text: '$t ', style: const TextStyle(color: Ttc.no, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)]));

// ======================= 노친네 =======================
void showPedPage(BuildContext context, Game g, void Function(String) toast) {
  showPageOf(context, g, (ctx) {
    if (!g.pedHere) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
      });
      return const SizedBox(height: 40);
    }
    final st = g.pedStock;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _tag('떠돌이 장사꾼 · ${g.pedVisits}번째 방문'),
      _h3('노친네'),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 방문 횟수에 맞는 표정 (2026-10-23 표정 그림)
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(color: const Color(0xFFEFE3C4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x593B2A1A), width: 2)),
          clipBehavior: Clip.antiAlias,
          child: pedExpr(pedMood(g.pedVisits), w: 76, h: 76),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text('“${g.pedLine}”', style: Ttc.t(13.5, color: const Color(0xFF8A7458), height: 1.6))),
      ]),
      const SizedBox(height: 10),
      for (var i = 0; i < st.length; i++)
        () {
          final x = st[i], sold = x['sold'] == 1;
          final price = {for (final e in (x['price'] as Map).entries) e.key as String: e.value as num};
          final mk = x['kind'] == 'mat' ? (x['m'] as Map).keys.first as String : null;
          final full = mk != null && g.have(mk) >= g.capOf(mk);
          final desc = x['kind'] == 'mat'
              ? (x['m'] as Map).entries.map((e) => '${matOf[e.key]!.n} ${e.value}').join(', ')
              : x['kind'] == 'gear'
                  ? '장비 가방에 들어가요'
                  : '유물 · 폐허 도감';
          return MCard(
            thumb: const SizedBox(width: 0),
            kind: x['rare'] == 1 ? CardKind.hero : CardKind.normal,
            title: x['n'] as String,
            tags: [
              if (x['rare'] == 1) smallTag('귀한 것'),
              if (x['free'] == 1) smallTag('하늘이 몫'),
            ],
            desc: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(x['d'] as String, style: Ttc.t(12, color: const Color(0xFF8A7458), height: 1.5)),
              descText('$desc${!sold && x['free'] == 1 ? ' · 값 없음' : ''}'),
            ]),
            costs: sold || x['free'] == 1 ? null : costWrap(g, price),
            button: sold
                ? const BuyButton('샀어요')
                : full
                    ? const BuyButton('창고 가득')
                    : BuyButton(x['free'] == 1 ? '받기' : '사기', onTap: g.canPay(price) ? () => toast(g.pedBuy(i)) : null, why: g.canPay(price) ? null : '자재 부족'),
          );
        }(),
      descText('해가 지면 떠나요. 이름은 아무도 몰라요 — 만수가 부른 대로 다들 ‘노친네’라고 불러요.'),
      const SizedBox(height: 12),
      Row(children: [
        pageBtn('더 둘러볼게요', () => Navigator.pop(ctx), alt: true),
        const SizedBox(width: 8),
        pageBtn('다음에 봐요', () {
          Navigator.pop(ctx);
          g.pedLeave(bye: true);
        }),
      ]),
    ]);
  });
}

// ======================= 떠돌이 무리 =======================
Widget _lootIcons(Map o, {bool plus = false}) => Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final e in o.entries)
        Row(mainAxisSize: MainAxisSize.min, children: [ResIcon(e.key as String, size: 16), const SizedBox(width: 2), Text('${plus ? '+' : ''}${e.value}', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700))]),
    ]);

void showBandPage(BuildContext context, Game g) {
  showPageOf(context, g, (ctx) {
    final B = g.band;
    if (B == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
      });
      return const SizedBox(height: 40);
    }
    final k = B['k'] as String;
    void act(String a, [int n = 0]) {
      if (g.bandAct(a, n)) Navigator.pop(ctx);
    }

    Cost c(Object? m) => {for (final e in (m as Map).entries) e.key as String: e.value as num};
    final body = <Widget>[];
    if (k == 'trader') {
      body.add(Text('교역', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)));
      final offers = B['offers'] as List;
      for (var n = 0; n < offers.length; n++) {
        final o = offers[n] as Map, left = ((o['left'] as num?) ?? 0).toInt();
        body.add(Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
          child: Row(children: [
            _lootIcons(o['give'] as Map),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('→', style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700))),
            Expanded(child: _lootIcons(o['get'] as Map, plus: true)),
            ghostBtn('바꾸기${left < 2 ? ' ($left)' : ''}', left > 0 && g.canPay(c(o['give'])) ? () => act('btr', n) : null),
          ]),
        ));
      }
      if (g.allies.contains(B['name'])) {
        body.add(Padding(padding: const EdgeInsets.only(top: 8), child: Text('이미 동맹이에요. 새벽마다 물자를 보내 줘요', style: Ttc.t(13, color: Ttc.ok))));
      } else {
        body.addAll([
          const SizedBox(height: 10),
          Text('동맹 맺기', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
          descText('선물을 건네면 동맹이 돼요. 새벽마다 물자를 보내 주고, 대형 재폭풍 때 함께 싸워요.'),
          const SizedBox(height: 4),
          needList(g, allyCost),
          const SizedBox(height: 6),
          Row(children: [pageBtn('동맹 맺기', g.canPay(allyCost) && g.allies.length < 3 ? () => act('bal') : null, alt: true)]),
        ]);
      }
    } else if (k == 'refugee') {
      body.addAll([
        descText('식량을 나눠 주면 희망이 오르고, 가끔 아이를 맡기거나 동물을 두고 가요.'),
        const SizedBox(height: 4),
        needList(g, {'food': 25}),
        const SizedBox(height: 6),
        Row(children: [pageBtn('식량 나눠 주기', g.canPay({'food': 25}) ? () => act('bref') : null, alt: true)]),
      ]);
    } else {
      body.addAll([
        descText('통행세를 내면 조용히 떠나요. 거절하면 오늘 밤 쳐들어와요. 막아내면 그들의 물자를 빼앗을 수 있어요.'),
        const SizedBox(height: 4),
        needList(g, c(B['tribute'])),
        const SizedBox(height: 8),
        Row(children: [
          pageBtn('거절하기', () => act('brf'), alt: true),
          const SizedBox(width: 8),
          pageBtn('통행세 내기', g.canPay(c(B['tribute'])) ? () => act('bpay') : null),
        ]),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _tag('${k == 'trader' ? '떠돌이 상인' : k == 'refugee' ? '피란민' : '약탈자'} · ${(((B['t'] as num?) ?? 0) / 60).ceil()}분 뒤 떠나요'),
      _h3(B['name'] as String),
      _p(B['say'] as String),
      const SizedBox(height: 10),
      ...body,
      if (k != 'raider') ...[
        const SizedBox(height: 12),
        Row(children: [pageBtn('돌려보내기', () => act('bye'), alt: true)]),
      ],
    ]);
  });
}

// ======================= 아이 =======================
void showKidGrown(BuildContext context, Game g, int n) {
  final ks = g.kids;
  if (n < 0 || n >= ks.length || ks[n]['job'] != null) return;
  final k = ks[n];
  final c = k['care'] is Map ? k['care'] as Map : const {};
  String? best;
  var bv = 0.0;
  c.forEach((j, v) {
    if ((v as num) > bv) {
      bv = v.toDouble();
      best = '$j';
    }
  });
  k['best'] = best;
  showPageOf(context, g, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _tag('아이들'),
        _h3('${jo(k['n'] as String, '이', '가')} 훌쩍 컸어요'),
        _p('이제 쉘터 일을 배울 나이예요. 무엇을 가르칠까요?'),
        if (best != null) Text('돌봐 준 사람들을 보고 자라서 ${kidJobs[best]!.$1}에 소질이 있어요 · 효과 1.5배', style: Ttc.t(12.5, color: Ttc.ok, height: 1.5)),
        const SizedBox(height: 10),
        for (final e in kidJobs.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              pageBtn('${e.key == best ? '★ ' : ''}${e.value.$1} · ${e.value.$2}${e.key == best ? ' ×1.5' : ''}', () {
                Navigator.pop(ctx);
                g.kidJob(n, e.key);
                g.fx.add(FxNote('${k['n']} · ${e.value.$1}', e.value.$2));
                g.poke();
              }, alt: e.key != best),
            ]),
          ),
      ]));
}

// ======================= 펫 =======================
Widget _petDots(int l) => Row(mainAxisSize: MainAxisSize.min, children: [
      for (var k = 1; k <= 5; k++)
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(shape: BoxShape.circle, color: k <= l ? Ttc.amber : null, border: Border.all(color: k <= l ? const Color(0xFFB28540) : const Color(0xFF9A824E))),
        ),
    ]);

void showPetPage(BuildContext context, Game g, String k0, {VoidCallback? onName}) {
  var k = k0;
  showPageOf(context, g, (ctx) => StatefulBuilder(builder: (ctx, set) {
        final P = petInfo(k), p = g.pets[k];
        if (p == null) return const SizedBox();
        final l = g.petLv(k), on = g.petOn == k, fedW = g.petFedLeft(k), fc = g.petFeedCost(k), pair = P['pair'] as int, pr = g.hasSv(pair);
        final nx = l < 5 ? petXp[l] : 0, pv = petXp[l - 1], xp = (p['xp'] as num?) ?? 0;
        final eds = ((on ? P['ed'] : P['edHalf']) as List);
        final others = petKeys.where(g.pets.containsKey).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (others.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final q in others)
                  GestureDetector(
                    onTap: () => set(() => k = q),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: q == k ? const Color(0xFFEDD6A6) : const Color(0xFFF5EEDF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: q == k ? const Color(0xFFB58B49) : Ttc.line),
                      ),
                      child: PetPic(q, size: 44, collar: ((g.pets[q]!['c'] as num?) ?? 0).toInt()),
                    ),
                  ),
              ]),
            ),
          Row(children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: const Color(0xFFEFE3C4), borderRadius: BorderRadius.circular(12)),
              child: PetPic(k, size: 96, collar: ((p['c'] as num?) ?? 0).toInt()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['n'] as String, style: Ttc.t(20, color: Ttc.sepia, weight: FontWeight.w700)),
                Text('${P['n']}${P['hidden'] == true ? ' · 히든' : ''}${p['away'] != null && p['away'] != false ? ' · 원정 중' : ''}', style: Ttc.t(12, color: Ttc.sepia2)),
                const SizedBox(height: 6),
                Row(children: [
                  _petDots(l),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0x1A252E36), borderRadius: BorderRadius.circular(3)),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(widthFactor: l < 5 ? ((xp - pv) / (nx - pv)).clamp(0.0, 1.0).toDouble() : 1, child: Container(color: Ttc.amber)),
                    ),
                  ),
                ]),
                Text('친밀도 $l/5', style: Ttc.t(11, color: Ttc.sepia2)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          _trait([
            _b(on ? '동행 효과' : '쉬는 동안 (절반)'),
            TextSpan(text: '${eds[l - 1]}'),
            if (on) ...[const TextSpan(text: '\n'), _b('재주'), TextSpan(text: '${P['act']}')],
            const TextSpan(text: '\n'),
            _b('원정'),
            TextSpan(text: '${P['expd']} · '),
            _b('지하'),
            TextSpan(text: '${P['ugd']}'),
          ]),
          _trait([
            _b('짝 · ${pr ? P['pairN'] : '???'}'),
            TextSpan(
                text: pr
                    ? '${jo(survivors[pair].name, '과', '와')} 함께 있어요 · 희망 +3 · 친밀도 1.5배'
                    : '${survivors[pair].hidden ? '아직 만나지 못한 누군가와' : jo(survivors[pair].name, '과', '와')} 잘 맞을 것 같아요'),
          ]),
          Text('사연', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700, height: 1.4)),
          for (var q = 0; q < 5; q++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
              child: q < l
                  ? Text(g.petStory(k, (P['story'] as List)[q] as String), style: Ttc.t(14, color: const Color(0xFF4A3320), height: 1.6))
                  : Text('친밀도 ${q + 1}에 열려요', style: Ttc.t(12.5, color: const Color(0xFFA8977A))),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(
                width: 130,
                child: Row(children: [
                  pageBtn('쓰다듬기', () {
                    if (!g.petPat(k)) g.fx.add(FxToast('${jo(p['n'] as String, '이', '가')} 기분 좋아해요'));
                    g.poke();
                  }, alt: true)
                ])),
            SizedBox(
                width: 150,
                child: Row(children: [
                  pageBtn(fedW > 0 ? (k == 'bot' ? '충전됨 $fedW초' : '배불러요 $fedW초') : (k == 'bot' ? '충전 · 연료 ${fc['fuel']}' : '먹이 · 식량 ${fc['food']}'),
                      fedW > 0 || !g.canPay(fc)
                          ? null
                          : () {
                              if (g.petFeed(k)) g.fx.add(FxToast(k == 'bot' ? '${jo(p['n'] as String, '이', '가')} 삐빅, 충전 완료 · 친밀도 +12' : '${jo(p['n'] as String, '이', '가')} 맛있게 먹었어요 · 친밀도 +12'));
                            },
                      alt: true)
                ])),
            SizedBox(
                width: 130,
                child: Row(children: [
                  pageBtn('이름·목걸이', () {
                    Navigator.pop(ctx);
                    showPetName(context, g, k, false);
                  }, alt: true)
                ])),
            SizedBox(
                width: 130,
                child: Row(children: [pageBtn(on ? '동행 중' : '동행하기', on || !g.petHere(k) ? null : () => g.petCompanion(k))])),
          ]),
        ]);
      }));
}

void showPetName(BuildContext context, Game g, String k, bool first) {
  final P = petInfo(k), p = g.pets[k];
  if (p == null) return;
  final ctl = TextEditingController(text: (p['n'] as String?) ?? '');
  var c = ((p['c'] as num?) ?? 0).toInt();
  showPageOf(context, g, (ctx) => StatefulBuilder(builder: (ctx, set) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _tag('${first ? (P['hidden'] == true ? '히든 펫을 만났어요!' : '새 식구') : '이름 바꾸기'} · ${P['n']}'),
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: const Color(0xFFEFE3C4), borderRadius: BorderRadius.circular(14)),
              child: PetPic(k, size: 120, collar: c),
            ),
          ),
          if (first) Padding(padding: const EdgeInsets.only(top: 8), child: _p(g.petStory(k, (P['story'] as List)[0] as String), align: TextAlign.center)),
          const SizedBox(height: 10),
          TextField(
            controller: ctl,
            maxLength: 8,
            textAlign: TextAlign.center,
            style: Ttc.t(16, color: Ttc.sepia, weight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: P['def'] as String,
              counterText: '',
              filled: true,
              fillColor: Ttc.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Ttc.line)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
            for (var i = 0; i < collarColors.length; i++)
              GestureDetector(
                onTap: () => set(() => c = i),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(collarColors[i]),
                    border: Border.all(color: i == c ? Ttc.sepia : const Color(0x403B2A1A), width: i == c ? 3 : 1.5),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            pageBtn(first ? '함께 가자' : '바꾸기', () {
              g.petRename(k, ctl.text, c);
              Navigator.pop(ctx);
            }),
          ]),
        ]);
      }));
}

void showStrayPage(BuildContext context, Game g) {
  showPageOf(context, g, (ctx) => Every(
      g: g,
      builder: (c0) {
        final s = g.stray;
        if (s == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          });
          return const SizedBox(height: 40);
        }
        final k = s['k'] as String, P = petInfo(k), n = ((s['n'] as num?) ?? 0).toInt(), need = ((s['need'] as num?) ?? 3).toInt();
        final c = g.strayCost(k), wait = g.strayWait, robo = k == 'bot';
        final moods = robo
            ? ['삐빅, 경계음을 내며 멀찍이 떨어져 있어요.', '조금 가까이 다가왔어요. 눈의 센서가 깜빡여요.', '이제 손을 내밀면 센서로 훑어봐요.']
            : ['낯선 사람을 경계하며 멀찍이 떨어져 있어요.', '조금 가까이 다가왔어요. 코를 킁킁거려요.', '이제 손을 내밀면 냄새를 맡아요.'];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _tag('떠돌이 ${P['hidden'] == true ? '???' : P['n']} · $n/$need'),
          const SizedBox(height: 8),
          Center(child: PetPic(k, size: 120, alpha: .45 + .5 * n / need)),
          const SizedBox(height: 8),
          _p('${moods[math.min(2, n)]}${k == 'fox' ? '\n밤에만 모습을 보여요.' : ''}', align: TextAlign.center),
          const SizedBox(height: 6),
          Text(robo ? '연료를 채워 주고 몇 번 찾아오면 따라와요' : '먹이를 두고 몇 번 찾아오면 마음을 열어요', textAlign: TextAlign.center, style: Ttc.t(12.5, color: Ttc.sepia2)),
          const SizedBox(height: 4),
          needList(g, c),
          const SizedBox(height: 12),
          Row(children: [
            pageBtn('돌아가기', () => Navigator.pop(ctx), alt: true),
            const SizedBox(width: 8),
            pageBtn(wait > 0 ? '$wait초 뒤에 다시' : robo ? '연료 채워 주기' : '먹이 두고 오기', g.canPay(c) && wait == 0
                ? () {
                    Navigator.pop(ctx);
                    g.strayFeed();
                  }
                : null),
          ]),
        ]);
      }));
}

/// 펫 시트 (웹 renderPets)
class PetsBody extends StatelessWidget {
  const PetsBody(this.g, {super.key, required this.onPet, required this.onStray});
  final Game g;
  final void Function(String k) onPet;
  final VoidCallback onStray;
  @override
  Widget build(BuildContext context) {
    final own = g.pets;
    final out = <Widget>[];
    final s = g.stray;
    if (s != null && g.strayVis) {
      final k = s['k'] as String;
      out.add(GestureDetector(
        onTap: onStray,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: const Color(0xFF29353F), borderRadius: BorderRadius.circular(9)),
          child: Row(children: [
            PetPic(k, size: 40, silhouette: true),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '떠돌이 ${petInfo(k)['hidden'] == true ? '???' : petInfo(k)['n']} · ${s['n']}/${s['need']}', style: Ttc.t(15, color: const Color(0xFFFFCF7A), weight: FontWeight.w700)),
                const TextSpan(text: '\n지도에서 발자국 쪽으로 가기 →'),
              ]), style: Ttc.t(12.5, color: Ttc.paper, height: 1.45)),
            ),
          ]),
        ),
      ));
    }
    if (own.isEmpty) {
      out.add(emptyBox(const Opacity(opacity: .85, child: PetPic('dog', size: 56, silhouette: true)), '아직 함께하는 펫이 없어요',
          g.petsOpen ? '구름을 걷다 보면 떠돌이 동물의 발자국이 지도에 찍혀요' : '해 질 녘이면 쉘터 뒤에서 개 짖는 소리가 나요. 3장에 무슨 일인지 알게 돼요'));
    }
    if (own.length > 1) {
      final hungry = petKeys.where((k) => own.containsKey(k) && g.petFedLeft(k) == 0).toList();
      final tot = <String, num>{};
      for (final k in hungry) {
        g.petFeedCost(k).forEach((r, v) => tot[r] = (tot[r] ?? 0) + v);
      }
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: BuyButton(
            hungry.isNotEmpty ? '모두 먹이 주기 · ${hungry.length}마리 · ${tot.entries.map((e) => '${e.key == 'fuel' ? '연료' : '식량'} ${e.value}').join(' · ')}' : '모두 배불러요',
            width: double.infinity,
            onTap: hungry.isEmpty || !g.canPay(tot)
                ? null
                : () {
                    var n = 0;
                    for (final k in hungry) {
                      if (g.petFeed(k)) n++;
                    }
                    if (n > 0) g.fx.add(FxToast('펫 $n마리가 맛있게 먹었어요 · 친밀도 +12'));
                  }),
      ));
    }
    out.add(sec('함께하는 펫 ${own.length}/${petKeys.length}'));
    out.add(LayoutBuilder(builder: (c, box) {
      final w = (box.maxWidth - 16) / 3;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in petKeys)
          () {
            final P = petInfo(k), p = own[k];
            final card = Container(
              width: w,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: p == null ? const Color(0xFFDED8CB) : (g.petOn == k ? const Color(0xFFEDD6A6) : Ttc.surface),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: g.petOn == k ? const Color(0xFFB58B49) : (P['hidden'] == true ? const Color(0xFFE0B441) : Ttc.line)),
              ),
              child: Column(children: [
                PetPic(k, size: 64, collar: p == null ? null : ((p['c'] as num?) ?? 0).toInt(), silhouette: p == null),
                Text(p == null ? (P['hidden'] == true ? '??? · 히든' : '???') : p['n'] as String,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Ttc.t(12.5, color: Ttc.sepia, weight: FontWeight.w700)),
                Text(p == null ? (P['hidden'] == true ? (P['how'] as String? ?? '') : '떠돌이 발자국을 찾아봐요') : '${P['n']} · 친밀도 ${g.petLv(k)}',
                    maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Ttc.t(10.5, color: Ttc.sepia2, height: 1.35)),
                if (g.petOn == k) Text('동행', style: Ttc.t(10.5, color: Ttc.ok, weight: FontWeight.w700)),
              ]),
            );
            return p == null ? card : GestureDetector(onTap: () => onPet(k), child: card);
          }(),
      ]);
    }));
    out.add(sec('펫과 짝'));
    final ownKeys = petKeys.where(own.containsKey).toList();
    if (ownKeys.isEmpty) out.add(descText('펫을 데려오면 잘 맞는 생존자를 알려 줘요'));
    for (final k in ownKeys) {
      final P = petInfo(k), pair = P['pair'] as int, on = g.hasSv(pair);
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text.rich(
            TextSpan(children: [
              TextSpan(text: on ? '${P['pairN']}' : '???', style: const TextStyle(fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
              TextSpan(text: ' · ${own[k]!['n']} + ${on || !survivors[pair].hidden ? survivors[pair].name : '???'} ${on ? '· 희망 +3 · 친밀도 1.5배' : '함께 모이면 열려요'}'),
            ]),
            style: Ttc.t(13, color: on ? Ttc.ok : Ttc.sepia2, height: 1.5)),
      ));
    }
    out.add(Padding(padding: const EdgeInsets.only(top: 10), child: descText('지도에서 펫을 누르면 쓰다듬고, 한 번 더 누르면 자세히 봐요.')));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 20), children: out);
  }
}

// ======================= 장식 (쉘터 꾸미기 탭) =======================
const decoIds = {'pot': 8, 'flag': 9, 'bench': 10, 'lamp': 11, 'chime': 12, 'string': 13, 'mural': 14, 'statue': 15};

List<Widget> decoTab(Game g, {required void Function(String k) onPick}) {
  // 앱 전용 (2026-10-20): 첫 동네는 컨테이너 쉘터(Lv.3)부터 (life.dart decoOpen)
  if (!g.decoOpen) {
    return [
      emptyBox(Opacity(opacity: .6, child: AtlasPic(file: 'settlement-props.webp', src: Atlas.fr(Atlas.propFrames[decoIds['bench']!]), width: 56, height: 56)), '아직 꾸밀 자리가 없어요',
          '지금 쉘터 둘레는 비바람을 막기에도 빠듯해요. 컨테이너 쉘터(Lv.3)로 키우면 장식을 놓을 수 있어요'),
    ];
  }
  final ds = g.decoSets();
  final total = g.decoHope + ds.keys.fold<int>(0, (a, q) => a + (setHope[q] ?? 0));
  final out = <Widget>[
    descText("장식은 희망을 올려요(같은 장식은 3개까지). 사람마다 좋아하는 장식이 있고, 가까이 놓은 장식끼리는 '장소'가 돼요. 지금 장식 희망 +$total"),
    sec('장소'),
  ];
  web.dsets.forEach((q, Z) {
    final on = ds.containsKey(q);
    out.add(Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: on ? const Color(0x1F4F6E2F) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: on ? const Color(0xFF6F8F4A) : Ttc.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${on ? '✓ ' : ''}${Z['n']}', style: Ttc.t(13.5, color: on ? Ttc.ok : Ttc.sepia, weight: FontWeight.w700)),
        Text('${(Z['need'] as List).map((n) => web.deco[n]!['n']).join(' + ')} 가까이 · ${Z['d']}', style: Ttc.t(13, color: Ttc.sepia2, height: 1.4)),
      ]),
    ));
  });
  out.add(const SizedBox(height: 8));
  web.deco.forEach((k, d) {
    final c = g.decoCost(k), lv = (d['lv'] as num?)?.toInt(), lock = lv != null && g.S.lv < lv;
    final n = g.deco.values.where((x) => x == k).length;
    final fans = g.decoFans(k).where(g.hasSv).toList();
    final favDone = g.S.rest['favDone'] is Map ? g.S.rest['favDone'] as Map : const {};
    final fanTxt = fans.isEmpty ? '' : ' · ${fans.map((id) => survivors[id].name).join('·')}${fans.any((id) => favDone['$id'] != 1) ? '이(가) 좋아해요' : '의 취향'}';
    out.add(MCard(
      thumb: SizedBox(
        width: 78,
        height: 78,
        child: AtlasPic(file: 'settlement-props.webp', src: Atlas.fr(Atlas.propFrames[decoIds[k]!]), width: 78, height: 78),
      ),
      kind: lock ? CardKind.locked : CardKind.normal,
      title: d['n'] as String,
      tags: [smallTag('희망 +${d['hope']}${n > 0 ? ' · 놓은 것 $n' : ''}$fanTxt')],
      desc: lock ? descText('쉘터 Lv.$lv에 열려요') : null,
      costs: lock ? null : costWrap(g, c),
      button: lock ? lockBadge('Lv.$lv') : BuyButton('놓기', onTap: g.canPay(c) ? () => onPick(k) : null, why: g.canPay(c) ? null : '자재 부족'),
    ));
  });
  return out;
}

void showDecoTile(BuildContext context, Game g, int i) {
  final k = g.deco['$i'];
  if (k == null) return;
  final d = web.deco['$k']!;
  showPageOf(context, g, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _tag('장식'),
        _h3(d['n'] as String),
        _p('쉘터 사람들이 오가며 한 번씩 쳐다봐요. 희망 +${d['hope']}'),
        const SizedBox(height: 12),
        Row(children: [
          pageBtn('그대로 두기', () => Navigator.pop(ctx), alt: true),
          const SizedBox(width: 8),
          pageBtn('치우기 (재료 절반 돌려받기)', () {
            Navigator.pop(ctx);
            g.removeDeco(i);
            g.fx.add(FxToast('${jo(d['n'] as String, '을', '를')} 치웠어요'));
          }),
        ]),
      ]));
}

/// 장식 놓는 중 띠 (웹 #placeBar)
Widget placeBar(Game g, String k, VoidCallback onCancel) {
  final d = web.deco[k]!;
  return Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(color: const Color(0xF2202932), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x66DFA54B))),
    child: Row(children: [
      Expanded(child: Text('${d['n']} 놓을 자리를 눌러요 · 쉘터 둘레 빛나는 칸', style: Ttc.t(12.5, color: Ttc.paper, weight: FontWeight.w600, height: 1.35))),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onCancel,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x55EEE5D3))),
          child: Text('그만', style: Ttc.t(12.5, color: Ttc.paper, weight: FontWeight.w700)),
        ),
      ),
    ]),
  );
}

// ======================= 잔치 (가공 탭 끝) =======================
List<Widget> feastCard(Game g) {
  if (!g.feastOpen) return const [];
  final c = g.feastCost, left = g.feastLeftMs, on = g.S.buff?['label'] == '마을 잔치';
  return [
    sec('마을 일'),
    MCard(
      thumb: icoThumbRes('food'),
      title: '마을 잔치',
      tags: [smallTag(on ? '잔치 중' : left > 0 ? '다음 잔치까지 ${(left / 60000).ceil()}분' : '열 수 있어요')],
      // 설명은 한 줄, 효과는 작은 칩 (2026-10-21 대표님: 설명이 너무 김)
      desc: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        descText('모두 모여 한 끼 크게 먹어요.'),
        const SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (final t in const ['10분 생산 +25%', '희망 +8', '신뢰 +40', '펫 +5'])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0xFF6F8F4A))),
              child: Text(t, style: Ttc.t(12, color: Ttc.ok, weight: FontWeight.w600, height: 1.3)),
            ),
        ]),
      ]),
      costs: left > 0 ? null : costWrap(g, c),
      button: left > 0 ? doneBadge(on ? '잔치 중' : '준비 중') : BuyButton('잔치 열기', width: 78, onTap: g.canPay(c) ? g.holdFeast : null, why: g.canPay(c) ? null : '자재 부족'),
    ),
  ];
}

Widget icoThumbRes(String k) => Container(
      width: 56,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 11, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const RadialGradient(center: Alignment(0, -.2), colors: [Color(0xFFF3E6C6), Color(0xFFDCC9A0)]),
      ),
      alignment: Alignment.center,
      child: ResIcon(k, size: 30),
    );

// ======================= 유물 (일지) =======================
List<Widget> relicsSection(Game g) {
  final own = g.relics;
  final out = <Widget>[
    sec('유물', '${own.length}/18'),
    descText('폐허를 뒤지거나 지하·원정에서 옛 세상의 물건을 찾아요. 세트를 모으면 영구 보너스가 생겨요.'),
    const SizedBox(height: 8),
  ];
  for (final s in web.rsets) {
    final done = g.relicSet(s['k'] as String);
    out.add(Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: done ? const Color(0x1F4F6E2F) : Ttc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: done ? const Color(0xFF6F8F4A) : Ttc.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(s['n'] as String, style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700))),
          Text('${done ? '✓ ' : ''}${s['fx']}', style: Ttc.t(12, color: done ? Ttc.ok : Ttc.sepia2, weight: FontWeight.w600)),
        ]),
        for (final it in s['items'] as List)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: own.contains(it)
                ? Text.rich(TextSpan(children: [
                    TextSpan(text: '$it\n', style: const TextStyle(fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)], color: Ttc.sepia)),
                    TextSpan(text: web.rstory[it] ?? ''),
                  ]), style: Ttc.t(13, color: Ttc.sepia2, height: 1.5))
                : Text('???', style: Ttc.t(12.5, color: const Color(0xFFA8977A), weight: FontWeight.w700)),
          ),
      ]),
    ));
  }
  return out;
}
