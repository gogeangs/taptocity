// 지도 위로 올라오는 시트 (웹 #sheet). 머리(아이콘·제목·닫기)는 짙은 색, 몸은 종이색.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'atlas.dart';
import 'cloud_ui.dart';
import 'daily_ui.dart';
import 'icons.dart';
import 'life_ui.dart';
import 'season_ui.dart';
import 'sound.dart';
import 'story_ui.dart';
import 'region_ui.dart';
import 'lines_ui.dart';
import 'theme.dart';
import 'widgets.dart';

/// 열린 시트의 종류
class SheetSpec {
  const SheetSpec(this.kind, {this.tile = -1, this.arg});
  final String kind; // shelter, module, landmark, camp, diary, settings, surv, exp, radio, party, gear
  final int tile;
  final String? arg;
  @override
  bool operator ==(Object o) => o is SheetSpec && o.kind == kind && o.tile == tile && o.arg == arg;
  @override
  int get hashCode => Object.hash(kind, tile, arg);
}

class SheetPanel extends StatelessWidget {
  const SheetPanel({super.key, required this.icon, required this.title, required this.onClose, required this.child});
  final String icon;
  final String title;
  final VoidCallback onClose;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Ttc.paper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14), bottom: Radius.circular(10)),
          border: Border.all(color: const Color(0x40EEE5D3), width: .8),
          boxShadow: const [BoxShadow(color: Color(0x470A1016), blurRadius: 28, offset: Offset(0, -8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            color: Ttc.btn,
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: Ttc.tabOn, borderRadius: BorderRadius.circular(7), boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, -2), blurRadius: 0, spreadRadius: -1)]),
                alignment: Alignment.center,
                child: SvgIcon(icon, size: 20, color: Ttc.hudText),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: Ttc.t(17, weight: FontWeight.w700))),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x173C2B1A)),
                  child: Text('×', style: Ttc.t(20, weight: FontWeight.w600, height: 1)),
                ),
              ),
            ]),
          ),
          Expanded(child: child),
        ]),
      );
}

EdgeInsets get _bodyPad => const EdgeInsets.fromLTRB(14, 14, 14, 20);

// ======================= 쉘터 =======================
class ShelterBody extends StatefulWidget {
  const ShelterBody(this.g, {super.key, this.onDeco});
  final Game g;
  final void Function(String k)? onDeco;
  static int get tab => _ShelterBodyState.tab;
  static set tab(int v) => _ShelterBodyState.tab = v;
  @override
  State<ShelterBody> createState() => _ShelterBodyState();
}

class _ShelterBodyState extends State<ShelterBody> {
  static int tab = 0; // 웹처럼 마지막으로 본 탭을 기억
  Game get g => widget.g;
  Timer? _hold;

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final S = g.S;
    return ListView(padding: _bodyPad, children: [
      Wrap(spacing: 5, runSpacing: 4, children: [
        sumChip([const TextSpan(text: '보관 한도 '), bold(fmt(g.cap))], icon: 'scrap'),
        sumChip([const TextSpan(text: '침상 '), bold('${S.sv.length}/${g.bedsMax}')]),
        sumChip([const TextSpan(text: '희망 '), bold('${g.hope}')], icon: 'hope'),
        sumChip([bold('+${fmt(g.prod['food'] ?? 0)}'), TextSpan(text: ' / -${fmt(g.eat)}')], icon: 'food', bad: g.hungry),
        if (g.modLv(5) >= 0) sumChip([TextSpan(text: '-${fmt(g.fuelUse)}${g.have('fuel') > 0 ? '' : ' 멈춤'}')], icon: 'fuel', bad: g.have('fuel') <= 0),
      ]),
      if (g.hungry) Padding(padding: const EdgeInsets.only(top: 6), child: Text('배고파서 생산이 절반으로 줄었어요 · 텃밭을 늘리거나 식량을 모아요', style: Ttc.t(13, color: Ttc.no, weight: FontWeight.w600))),
      const SizedBox(height: 12),
      Segs(
          items: const ['건설', '가공', '연구', '창고', '꾸미기'],
          on: tab,
          // 새 기능 표시 (웹 segNew: 꾸미기·가공 등)
          dots: [for (final k in const ['build', 'craft', 'research', 'store', 'deco']) g.segNew('shelter', k)],
          onTap: (k) => setState(() {
                tab = k;
                g.seeFeat('shelter', const ['build', 'craft', 'research', 'store', 'deco'][k]);
              }),
          hlKeys: const ['seg:0', 'seg:1'],
          oneRow: true),
      ...switch (tab) {
        0 => _build(),
        1 => [..._craft(), ...feastCard(g)],
        2 => _research(),
        4 => decoTab(g, onPick: (k) => widget.onDeco?.call(k)),
        _ => _store(),
      },
    ]);
  }

  List<Widget> _build() {
    final S = g.S, L = S.lv, mb = migrateBanner(g, () => showMigrate(context, g)), out = <Widget>[if (mb != null) mb, ...towerCard(g)];
    if (L < 5) {
      final c = g.shelterUpCost!, need = shupNeed[L - 1], ok = S.mods.length >= need;
      out.add(hl('shup', MCard(
        kind: CardKind.hero,
        thumb: coreThumb(L + 1),
        title: '${jo(shelterName[L], '으로', '로')} 증축',
        tags: [smallTag('Lv.${L + 1}')],
        desc: descText('빈 자리 +${slotsByLv[L] - slotsByLv[L - 1]} · 침상 +${const [1, 3, 5, 8, 12][L] - const [1, 3, 5, 8, 12][L - 1]} · 랜턴 빛이 더 멀리 닿아요'),
        costs: costWrap(g, c, lead: [CostChip(label: '모듈', have: S.mods.length, need: need)]),
        button: BuyButton('증축', hero: true, why: !ok ? '모듈 ${need - S.mods.length}개 더 필요' : (!g.canPay(c) ? (lackText(g, c) ?? '자재 부족') : null), onTap: ok && g.canPay(c) ? () => g.upShelter() : null),
      ), radius: 12));
    }
    final fs = g.freeSlot();
    out.add(sec('모듈', '빈 자리 ${fs < 0 ? 0 : slotsByLv[L - 1] - S.mods.length}'));
    for (final id in modOrder) {
      final d = mods[id]!;
      final ks = (S.mods.keys.where((k) => S.mods[k]!.id == id).toList()..sort());
      if (ks.isNotEmpty) {
        for (final k in ks) {
          out.add(ModuleCard(g, k));
        }
        if (repeatable.contains(id)) {
          final c = g.modBuildCost(id);
          out.add(MCard(
            kind: CardKind.more,
            thumb: Stack(children: [
              moduleThumb(id, 0),
              Positioned(
                right: 4,
                bottom: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Ttc.amber, boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))]),
                  alignment: Alignment.center,
                  child: Text('+', style: Ttc.t(15, color: Ttc.sepia, weight: FontWeight.w700, height: 1)),
                ),
              ),
            ]),
            title: '${d.n} 하나 더',
            tags: [smallTag('${ks.length}개 있음')],
            desc: descText('같은 모듈을 여러 개 지으면 효과가 더해져요'),
            costs: costWrap(g, c),
            button: _btn('짓기', c, () => g.buildMod(id), dis: fs < 0, why: '빈 자리 없음'),
          ));
        }
      } else if (S.lv < d.req) {
        out.add(MCard(kind: CardKind.locked, thumb: moduleThumb(id, 0, gray: true), title: d.n, desc: descText(d.fx[0]), button: lockBadge('Lv.${d.req}')));
      } else {
        final c = g.modCost(id, 0);
        out.add(hl('mbuild:$id', MCard(
          thumb: moduleThumb(id, 0),
          title: d.n,
          tags: [newTag(), if (S.gen != 0) smallTag('지어 본 설계 · 비용 절반')],
          desc: descText(d.fx[0]),
          costs: costWrap(g, c),
          button: _btn('짓기', c, () => g.buildMod(id), dis: fs < 0, why: '빈 자리 없음'),
        ), radius: 12));
      }
    }
    out.add(sec('방벽'));
    if (S.walls >= 3) {
      out.add(MCard(thumb: wallThumb(2), title: wallsInfo[2].$1, tags: [pips(2)], desc: descText('밤에 쉘터를 덮치는 재를 거의 다 막아요'), button: doneBadge()));
    } else {
      final c = g.wallCost(S.walls);
      out.add(hl('wall', MCard(
        kind: S.lv < 2 ? CardKind.locked : CardKind.normal,
        thumb: wallThumb(S.walls),
        title: wallsInfo[S.walls].$1,
        tags: [if (S.walls > 0) pips(S.walls - 1)],
        desc: descText(S.lv < 2 ? '쉘터 Lv.2에 열려요' : '밤마다 쉘터 모듈을 덮치는 재를 줄여요'),
        costs: S.lv < 2 ? null : costWrap(g, c),
        button: S.lv < 2 ? lockBadge('Lv.2') : _btn('세우기', c, () => g.upWalls()),
      ), radius: 12));
    }
    return out;
  }

  Widget _btn(String label, Cost c, VoidCallback act, {bool dis = false, String? why}) {
    final poor = !g.canPay(c);
    return BuyButton(label, why: dis ? why : (poor ? (lackText(g, c, short: true) ?? '자재 부족') : null), onTap: dis || poor ? null : act);
  }

  List<Widget> _craft() {
    final out = <Widget>[sec('작업대 가공')];
    if (g.wbL == 0) {
      out.add(emptyBox(moduleThumb(1, 0, w: 52, h: 52, gray: true), '작업대가 아직 없어요', '작업대를 세우면 고철로 철판을, 천으로 밧줄을 만들 수 있어요'));
      return out;
    }
    // 웹 craftHintHtml
    out.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: '탭하면 1개 · 꾹 누르면 계속 만들어요'),
              if (g.acraftOpen) ...[
                const TextSpan(text: ' · '),
                const TextSpan(text: '자동', style: TextStyle(color: Color(0xFF4F6E2F), fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
                const TextSpan(text: '을 켜면 남는 재료를 알아서 가공해요'),
              ],
            ]),
            style: Ttc.t(13, color: Ttc.sepia2, height: 1.5))));
    for (var k = 0; k < recipes.length; k++) {
      final r = recipes[k], lk = g.recipeLock(r), inp = g.recipeInp(r);
      if (lk.isNotEmpty && r.lv > 0 && g.S.lv < r.lv - 1) continue;
      final m = matOf[r.out]!;
      final full = g.have(r.out) >= g.capOf(r.out), ok = g.craftMax(k) >= 1;
      out.add(hl('craft:$k', MCard(
        kind: lk.isNotEmpty ? CardKind.locked : CardKind.normal,
        thumb: Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 11, vertical: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const RadialGradient(center: Alignment(0, -.2), colors: [Color(0xFFF3E6C6), Color(0xFFDCC9A0)])),
          alignment: Alignment.center,
          child: ResIcon(r.out, size: 30),
        ),
        title: r.nm ?? m.n,
        tags: [smallTag('${r.nm != null ? '${m.n} ' : ''}보유 ${fmt(g.have(r.out))}')],
        desc: r.d == null ? null : descText(r.d!),
        costs: lk.isNotEmpty
            ? null
            : Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 5, runSpacing: 4, children: [
                costWrap(g, inp),
                Text('→ ${r.n}개', style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600)),
              ]),
        button: lk.isNotEmpty
            ? lockBadge(lk)
            // 카드의 버튼 자리는 폭 제한이 없는 Row 안이라, 두 버튼 폭을 맞출 때는 IntrinsicWidth로 감싼다
            : IntrinsicWidth(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  CraftBtn(g, k, ok: ok, why: ok ? null : (full ? '창고 가득' : (lackText(g, inp, short: true) ?? '재료 부족'))),
                  if (g.acraftOpen) ...[const SizedBox(height: 6), k == 0 ? hl('acr', _acrBtn(k)) : _acrBtn(k)], // 웹: 첫 스위치만 강조
                ]),
              ),
      ), radius: 12));
    }
    return out;
  }

  /// 자동 가공 스위치 (웹 .acr)
  Widget _acrBtn(int k) {
    final on = g.acraftOn(k);
    return GestureDetector(
      onTap: () => setState(() => g.acraftToggle(k)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFEEF3DF) : const Color(0xFFFBF4E4),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: on ? const Color(0xFF6F9646) : const Color(0x383B2A1A), width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 24,
            height: 14,
            padding: const EdgeInsets.all(2),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(color: on ? const Color(0xFF6F9646) : const Color(0x403B2A1A), borderRadius: BorderRadius.circular(99)),
            child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 6),
          Text('자동', style: Ttc.t(12, color: on ? const Color(0xFF2F4A1A) : Ttc.sepia2, weight: FontWeight.w700, height: 1)),
        ]),
      ),
    );
  }

  List<Widget> _research() {
    final out = <Widget>[
      sec('연구 · 탐사 장비'),
      Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('한 번 연구하면 영구히 남아요. 작업대 단계가 오를수록 더 깊이 연구할 수 있어요.', style: Ttc.t(13, color: Ttc.sepia2, height: 1.5))),
    ];
    if (g.wbL == 0) out.add(emptyBox(moduleThumb(1, 0, w: 52, h: 52, gray: true), '작업대가 아직 없어요', '작업대를 세우면 곡괭이·랜턴·드론을 연구할 수 있어요'));
    const names = {'tap': '곡괭이', 'splash': '랜턴 불씨', 'drone': '정찰 드론'};
    for (final k in const ['tap', 'splash', 'drone']) {
      final lv = g.upgLv(k), mx = lv >= Game.upgMax[k]!, c = g.upgCost(k), need = g.upgWb(k);
      final d = switch (k) {
        'tap' => '한 번에 걷어내는 힘 ${fmt(g.tapPow)}',
        'splash' => '옆 칸까지 번지는 빛 ${g.S.splashLv} → ${g.S.splashLv + 1}',
        _ => '스스로 초당 ${fmt(g.droneDmg())} → ${fmt(g.droneDmg(1))} 탐사',
      };
      out.add(MCard(
        thumb: researchThumb(k),
        title: names[k]!,
        tags: [smallTag('Lv.$lv${mx ? '' : ' / ${Game.upgMax[k]}'}')],
        desc: descText(mx ? '최대 단계예요' : d),
        costs: mx || g.wbL < need ? null : costWrap(g, c),
        button: mx ? doneBadge('최대') : g.wbL < need ? lockBadge('작업대 $need단계') : _btn('연구', c, () => g.buyUp(k)),
      ));
    }
    return out;
  }

  List<Widget> _store() => [
        sec('창고'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.9,
          children: [
            for (final m in mats)
              () {
                final v = g.have(m.k), cap = m.tier >= 3 ? 0 : g.capOf(m.k);
                return Container(
                  decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Ttc.line)),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(children: [
                        ResIcon(m.k, size: 23),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(fmt(v), style: Ttc.t(16, color: Ttc.sepia, weight: FontWeight.w700, height: 1.1)),
                            Text('${m.n}${cap > 0 ? ' · ${fmt(cap)}' : ''}', style: Ttc.t(11, color: Ttc.sepia2)),
                          ]),
                        ),
                      ]),
                    ),
                    if (cap > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 3,
                        child: Container(
                          color: const Color(0x143B2A1A),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(widthFactor: (v / cap).clamp(0, 1).toDouble(), child: Container(color: v >= cap ? const Color(0xFFE2644F) : Ttc.amber)),
                        ),
                      ),
                  ]),
                );
              }(),
          ],
        ),
        const SizedBox(height: 8),
        Text('기본 자재와 철판·밧줄은 창고 한도 ${fmt(g.cap)}, 전선·약품은 그 1/4까지 모여요. 창고 모듈과 쉘터 증축으로 늘려요. 건전지는 한도가 없어요.',
            style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
      ];
}

class ModuleCard extends StatelessWidget {
  const ModuleCard(this.g, this.slot, {super.key});
  final Game g;
  final int slot;
  @override
  Widget build(BuildContext context) {
    final m = g.S.mods[slot];
    if (m == null) return const SizedBox();
    final d = mods[m.id]!, up = m.l < 2 ? g.modCost(m.id, m.l + 1) : null;
    return MCard(
      thumb: moduleThumb(m.id, m.l),
      title: d.n,
      tags: [pips(m.l)],
      desc: up == null
          ? descText(d.fx[m.l])
          : Text.rich(
              TextSpan(children: [
                TextSpan(text: '${d.fx[m.l]} '),
                const TextSpan(text: '→', style: TextStyle(color: Ttc.amber, fontWeight: FontWeight.w700)),
                TextSpan(text: ' ${d.fx[m.l + 1]}', style: const TextStyle(color: Ttc.ok, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
              ]),
              style: Ttc.t(13, color: Ttc.sepia2, height: 1.5),
            ),
      costs: up == null ? null : costWrap(g, up),
      button: up == null ? doneBadge() : BuyButton('강화', why: g.canPay(up) ? null : (lackText(g, up, short: true) ?? '자재 부족'), onTap: g.canPay(up) ? () => g.upMod(slot) : null),
    );
  }
}

// ======================= 모듈·랜드마크·캠프 =======================
Widget moduleBody(Game g, int tile) {
  final slot = g.modAt[tile];
  final m = slot == null ? null : g.S.mods[slot];
  if (m == null) return const SizedBox();
  final say = modSay[m.id];
  return ListView(padding: _bodyPad, children: [
    if (say != null && say.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('“${say[tile % say.length]}”', style: Ttc.t(14, color: Ttc.sepia2, height: 1.5))),
    ModuleCard(g, slot!),
    if (m.id == 5 && g.have('fuel') <= 0) Text('연료가 없어 멈췄어요', style: Ttc.t(12.5, color: Ttc.no, weight: FontWeight.w700)),
  ]);
}

Widget landmarkBody(Game g, int tile) {
  final l = g.S.lm[tile];
  if (l == null) return const SizedBox();
  final t = lmText(l.k, g.S.region), info = landmarks[l.k], s = g.S.site[tile], c = g.lmCost(l.k);
  return ListView(padding: _bodyPad, children: [
    Center(child: AtlasPic(file: 'landmarks.webp', src: Atlas.fr(Atlas.landmarkFrames[l.k + (l.ok ? 5 : 0)]), width: 180, height: 120)),
    const SizedBox(height: 10),
    Text(l.ok ? t[2] : t[1], style: Ttc.t(14.5, color: Ttc.sepia, height: 1.6)),
    const SizedBox(height: 10),
    Wrap(spacing: 6, runSpacing: 6, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: const Color(0x1F4F6E2F), borderRadius: BorderRadius.circular(99)),
        child: Text('복구하면 ${info.desc}', style: Ttc.t(12, color: Ttc.ok, weight: FontWeight.w700)),
      ),
      if (!l.ok && s != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: const Color(0x0D26333B), borderRadius: BorderRadius.circular(99), border: Border.all(color: Ttc.line)),
          child: Text('남은 물자 ${s.c}/${s.max}', style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600)),
        ),
    ]),
    if (!l.ok) ...[
      sec('복구에 필요한 자재'),
      costWrap(g, c),
      const SizedBox(height: 14),
      Row(children: [
        if (s != null && s.c > 0) ...[
          Expanded(
            child: GestureDetector(
              onTap: () {
                g.setAim(tile);
                g.hitSite(tile, g.tapPow * (g.fever > 0 ? 2 : 1));
                g.poke();
              },
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0x4726333B))),
                child: Text('뒤지기', style: Ttc.t(13, color: Ttc.sepia, weight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: BuyButton('복구하기', width: double.infinity, why: g.canPay(c) ? null : '자재 부족', onTap: g.canPay(c) ? () => g.restoreLm(tile) : null)),
      ]),
    ],
    if (l.ok && info.key == 'station') ...[const SizedBox(height: 12), Builder(builder: (context) => lnCardWidget(context, g))],
  ]);
}

Widget campBody(Game g, int tile) {
  final c = g.S.camp[tile];
  final id = (c?['id'] as num?)?.toInt();
  final sv = id != null && id < survivors.length ? survivors[id] : null;
  return ListView(padding: _bodyPad, children: [
    Text(sv == null ? '잔해 아래에서 누군가 기다리고 있어요.' : '${sv.name} · ${sv.job}', style: Ttc.t(16, color: Ttc.sepia, weight: FontWeight.w700)),
    const SizedBox(height: 8),
    Text('구조와 생존자 이야기는 다음 단계(생존자)에서 옮겨요.', style: Ttc.t(13.5, color: Ttc.sepia2, height: 1.6)),
  ]);
}

// ======================= 일지 (앱 전용 2026-10-20: 위 탭 셋 — 기록 · 사건 수첩 · 도감) =======================
// 기록 = 오늘의 할 일 · 이야기 · 기록 조각 · 일기 / 회상, 사건 수첩 = 사건, 도감 = 폐허 도감 / 업적 / 노선도. 안내서는 설정으로 옮겼다.
// DiaryBody.tab에는 안쪽 칸 이름(story·scene·case·relic·ach·towns)을 그대로 둔다 (새 기능 카드 '보러 가기'·라디오 노선도 버튼이 쓰는 이름).
class DiaryBody extends StatefulWidget {
  const DiaryBody(this.g, {super.key});
  final Game g;
  static String tab = 'story';

  /// 안쪽 칸 → 위 탭
  static String topOf(String k) => switch (k) {
        'case' => 'case',
        'relic' || 'ach' || 'towns' => 'book',
        _ => 'log',
      };
  @override
  State<DiaryBody> createState() => _DiaryBodyState();
}

class _DiaryBodyState extends State<DiaryBody> {
  Game get g => widget.g;

  bool _dot(String k) =>
      (k == 'ach' && g.achReady) || (k == 'scene' && g.S.rest['artNew'] != null) || (k == 'case' && g.S.rest['caseNew'] != null) || g.segNew('diary', k);

  void _go(String k) => setState(() {
        DiaryBody.tab = k;
        g.seeFeat('diary', k);
      });

  @override
  Widget build(BuildContext context) {
    g.artBackfill();
    final subs = <String, List<(String, String)>>{
      'log': [('story', '이야기'), if (g.artCount > 0) ('scene', '회상')],
      if (g.caseSeen) 'case': [('case', '사건')],
      'book': [('relic', '도감'), ('ach', '업적'), if (g.S.gen > 0 || g.tlogList.isNotEmpty) ('towns', '노선도')],
    };
    const names = {'log': '기록', 'case': '사건 수첩', 'book': '도감'};
    // 없는 칸(옛 '안내서'·아직 안 열린 회상·사건)이면 기록의 이야기로
    if (!subs.values.any((l) => l.any((x) => x.$1 == DiaryBody.tab))) DiaryBody.tab = 'story';
    final top = DiaryBody.topOf(DiaryBody.tab), tops = subs.keys.toList(), inner = subs[top]!;
    // 지금 보는 칸의 새 표시는 바로 지운다
    if (DiaryBody.tab == 'scene') g.S.rest.remove('artNew');
    if (DiaryBody.tab == 'case') g.S.rest.remove('caseNew');
    return ListView(padding: _bodyPad, children: [
      Segs(
        items: [for (final t in tops) names[t]!],
        on: tops.indexOf(top),
        oneRow: true,
        dots: [for (final t in tops) t != top && subs[t]!.any((x) => _dot(x.$1))],
        // 위 탭을 누르면 그 탭의 첫 칸부터 (기록 → 이야기, 도감 → 도감)
        onTap: (k) => _go(subs[tops[k]]!.first.$1),
      ),
      if (inner.length > 1)
        SubTabs(
          items: [for (final x in inner) x.$2],
          on: inner.indexWhere((x) => x.$1 == DiaryBody.tab),
          dots: [for (final x in inner) x.$1 != DiaryBody.tab && _dot(x.$1)],
          onTap: (k) => _go(inner[k].$1),
        ),
      ...switch (DiaryBody.tab) {
        'relic' => relicsSection(g),
        'scene' => scenesTab(context, g),
        'case' => casesTab(context, g),
        'towns' => routeTab(context, g),
        'ach' => achTab(g),
        _ => [...dailySection(g), ...storyLog(g), ...fragSection(context, g), ...diaryLog(g, (k) => showDiary(context, k))],
      },
    ]);
  }
}

/// 웹 .page 모달
Future<void> showPage(BuildContext context, {required String tag, required String title, required String body, String button = '덮기'}) => showDialog(
      context: context,
      barrierColor: const Color(0xC70F161D),
      builder: (ctx) => Dialog(
        backgroundColor: Ttc.paper,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x66EEE5D3))),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tag, style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(title, style: Ttc.t(23, color: Ttc.sepia, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Flexible(child: SingleChildScrollView(child: Text(body, style: Ttc.t(16, color: Ttc.sepia, height: 1.7)))),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: double.infinity,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Ttc.amber, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x73252E36))),
                child: Text(button, style: Ttc.t(13.5, color: const Color(0xFF252E36), weight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );

Future<void> showDiary(BuildContext context, int k) => showPage(context, tag: '목격자의 일기 · ${k + 1}/7', title: diaries[k].$1, body: diaries[k].$2);

Widget comingBody(String title, String stage) => ListView(padding: _bodyPad, children: [
      emptyBox(SvgIcon(Ico.lock, size: 26, color: Ttc.sepia2), '$title 화면은 $stage에서 옮겨요', '지금 미리보기는 지도 밝히기·뒤지기·쉘터 짓기까지예요.'),
    ]);

// ======================= 설정 =======================
class SettingsBody extends StatefulWidget {
  const SettingsBody(this.g, {super.key, required this.onReset, this.onTut, this.onSaveNow, this.onLegacy});
  final Game g;
  final VoidCallback onReset;
  final VoidCallback? onTut;
  final Future<void> Function()? onSaveNow;
  final Future<void> Function()? onLegacy;
  @override
  State<SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<SettingsBody> {
  final ctrl = TextEditingController();
  String msg = '';
  bool confirmReset = false;

  /// 안내서 보는 중 (앱 전용 2026-10-20: 일지에서 설정으로 옮김)
  bool guide = false;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Widget _row(String t, String d, Widget btn) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700)),
              Text(d, style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
            ]),
          ),
          const SizedBox(width: 10),
          btn,
        ]),
      );

  static const _si = {
    'mus': '<path d="M9 18V6l11-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>',
    'snd': '<path d="M4 10v4h4l5 4V6L8 10z"/><path d="M16 9a4 4 0 0 1 0 6M18.5 6.5a8 8 0 0 1 0 11"/>',
    'vib': '<rect x="8" y="3" width="8" height="18" rx="2"/><path d="M4 8v8M20 8v8"/>',
    'calm': '<path d="M3 12h4l2-5 4 10 2-5h6"/>',
    'big': '<path d="M4 19L9 5l5 14M6 14h6"/><path d="M15 19l3-8 3 8M16 16h4"/>',
    'eco': '<rect x="3" y="7" width="16" height="10" rx="2"/><path d="M22 11v2"/><path d="M11 9l-2 3h4l-2 3"/>',
  };

  /// 웹 .setrow: 아이콘 · 이름과 설명 · 켜고 끄기
  Widget _setRow(String k, String n, String d) {
    final on = Prefs.get(k);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => Prefs.toggle(k)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0x123B2A1A), borderRadius: BorderRadius.circular(10)),
            child: SvgPicture.string(
                '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="#26333B" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">${_si[k]}</svg>',
                width: 20,
                height: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n, style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700)),
              Text(d, style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
            ]),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 50,
            height: 28,
            padding: const EdgeInsets.all(2),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(color: on ? const Color(0xFF6F8F4A) : const Color(0xFFCBBD9B), borderRadius: BorderRadius.circular(99), border: Border.all(color: Ttc.sepia, width: 2)),
            child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Ttc.paper, boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))])),
          ),
        ]),
      ),
    );
  }

  Widget _ghost(String t, VoidCallback onTap, {bool warn = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: warn ? Ttc.rust : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: warn ? Ttc.rust : const Color(0x47252E36))),
          alignment: Alignment.center,
          child: Text(t, style: Ttc.t(13, color: warn ? const Color(0xFFFFF1E6) : Ttc.sepia, weight: FontWeight.w700)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    if (guide) {
      return ListView(padding: _bodyPad, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => guide = false),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            alignment: Alignment.centerLeft,
            child: Text('‹ 설정으로', style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700)),
          ),
        ),
        ...guideTab(context, g),
      ]);
    }
    return ListView(padding: _bodyPad, children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => guide = true),
        child: _row('안내서', '쉘터·생존자·밤·원정·오늘의 할 일 등 게임 방법을 한곳에 모았어요', _ghost('열기', () => setState(() => guide = true))),
      ),
      if (widget.onSaveNow != null) CloudSection(onSaveNow: widget.onSaveNow!),
      if (widget.onLegacy != null) _row('예전 버전에서 진행 가져오기', '웹 게임이나 예전 탭투시티 앱에서 하던 진행을 이 앱으로 옮겨요', _ghost('가져오기', () => widget.onLegacy!())),
      _row('피드백 보내기', '버그·제안·소감, 무엇이든 개발자에게 바로 전해져요', _ghost('쓰기', () => showFeedback(context, g))),
      // 웹 설정과 같이 (App Store 심사 전 2026-10-20)
      _row('개인정보 처리방침', '진행은 기기와 클라우드에 저장돼요 · 광고 없음', _ghost('보기', () => launchUrl(Uri.parse('https://gogeangs.github.io/taptocity/privacy.html'), mode: LaunchMode.externalApplication))),
      for (final (k, n, d) in const [
        ('mus', '음악', '낮과 밤, 재폭풍, 심야 방송에 맞춰 흐르는 배경 음악'),
        ('snd', '소리', '두드리기, 자재 줍기, 라디오 잡음 같은 효과음'),
        ('vib', '진동', '두드릴 때 휴대폰이 살짝 떨려요'),
        ('calm', '움직임 줄이기', '흔들림·깜빡임 같은 애니메이션을 줄여요'),
        ('eco', '절전 모드', '화면을 덜 자주, 조금 덜 선명하게 그려 휴대폰이 덜 뜨거워지고 배터리가 오래가요'),
        ('big', '글자 크게', '앱 전체 글자를 1.15배로 키워 읽기 쉽게 해요'),
      ])
        _setRow(k, n, d),
      sec('저장'),
      _row('저장 코드 복사', '웹 버전의 저장 코드와 같은 형식이에요', _ghost('복사', () async {
        await Clipboard.setData(ClipboardData(text: g.exportCode()));
        if (mounted) setState(() => msg = '내 저장 코드를 복사했어요');
      })),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('저장 코드 불러오기', style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700)),
      ),
      Text('웹에서 복사한 TTC1. 코드를 붙여 넣으면 그 진행으로 이어서 해요', style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl,
        maxLines: 3,
        style: Ttc.t(12, color: Ttc.sepia),
        decoration: InputDecoration(
          hintText: 'TTC1. 로 시작하는 코드',
          hintStyle: Ttc.t(12, color: Ttc.sepia2),
          filled: true,
          fillColor: Ttc.surface,
          contentPadding: const EdgeInsets.all(10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Ttc.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Ttc.line)),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text(msg, style: Ttc.t(12.5, color: Ttc.ok, weight: FontWeight.w700))),
        BuyButton('불러오기', width: 84, onTap: () {
          final s = Game.parseCode(ctrl.text);
          if (s == null) {
            setState(() => msg = '코드를 읽지 못했어요');
            return;
          }
          g.replaceState(s);
          setState(() => msg = '불러왔어요');
        }),
      ]),
      const SizedBox(height: 6),
      if (g.tut == null && widget.onTut != null) ...[
        sec('그날 밤'),
        _row('튜토리얼 다시 보기', '재가 내리던 새벽을 다시 걸어요. 끝나면 지금 쉘터로 그대로 돌아와요.', _ghost('다시 보기', widget.onTut!)),
      ],
      _row(confirmReset ? '정말 처음부터 할까요?' : '새 땅에서 다시 시작', confirmReset ? '지금 진행은 사라져요' : '지도와 쉘터를 처음부터', _ghost(confirmReset ? '처음부터' : '다시 시작', () {
        if (!confirmReset) {
          setState(() => confirmReset = true);
          return;
        }
        widget.onReset();
      }, warn: confirmReset)),
    ]);
  }
}

/// 가공 버튼 (웹 craftBtn · chStep): 누르면 1개, 누르고 있으면 점점 빨리 여러 개 · '+N 만드는 중'
class CraftBtn extends StatefulWidget {
  const CraftBtn(this.g, this.k, {super.key, required this.ok, this.why});
  final Game g;
  final int k;
  final bool ok;
  final String? why;
  @override
  State<CraftBtn> createState() => _CraftBtnState();
}

class _CraftBtnState extends State<CraftBtn> {
  Timer? _t;
  int _n = 0, _made = 0;
  bool _hold = false;
  Game get g => widget.g;

  void _down() {
    final k = widget.k, out = recipes[k].out;
    if (g.craftMax(k) < 1) {
      g.fx.add(FxToast(g.have(out) >= g.capOf(out) ? '${matOf[out]!.n} 창고가 가득 찼어요' : '재료가 모자라요'));
      return;
    }
    final r = g.craftQuiet(k, 1);
    if (r.$1 == 0) {
      g.fx.add(const FxToast('재료가 모자라요'));
      return;
    }
    Sound.sfx('get');
    setState(() {
      _hold = true;
      _n = 0;
      _made = r.$2;
    });
    _t = Timer(const Duration(milliseconds: 380), _step);
  }

  void _step() {
    if (!_hold || !mounted) return;
    final mx = g.craftMax(widget.k);
    if (mx < 1) return _stop();
    _n++;
    final batch = math.max(1, math.min(mx, math.pow(1.45, _n - 1).floor()));
    final r = g.craftQuiet(widget.k, batch);
    if (r.$1 == 0) return _stop();
    setState(() => _made += r.$2);
    if (_n % 3 == 0) Sound.sfx('get');
    Sound.tick();
    _t = Timer(Duration(milliseconds: _n < 3 ? 260 : 110), _step);
  }

  void _stop() {
    _t?.cancel();
    if (!_hold) return;
    if (_made > 1) g.fx.add(FxToast('${matOf[recipes[widget.k].out]!.n} ${fmt(_made)}개를 만들었어요'));
    if (mounted) setState(() => _hold = false);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.ok || _hold;
    return Listener(
      onPointerDown: on ? (_) => _down() : null,
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: Transform.translate(
        offset: Offset(0, _hold ? 2 : 0),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 84),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
              color: on ? (_hold ? const Color(0xFF3A4752) : Ttc.darkBtn) : Ttc.offBtn,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: on ? Ttc.darkBtn : Ttc.offBtnLine, width: .8)),
          alignment: Alignment.center,
          child: _hold
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('+${fmt(_made)}', style: Ttc.t(16, color: Ttc.darkBtnText, weight: FontWeight.w800, height: 1)),
                  const SizedBox(height: 2),
                  Text('만드는 중', style: Ttc.t(10.5, color: Ttc.darkBtnText.withValues(alpha: .75), weight: FontWeight.w600, height: 1)),
                ])
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('만들기', style: Ttc.t(on ? 13 : 12, color: on ? Ttc.darkBtnText : Ttc.offBtnText, weight: FontWeight.w700, height: 1.2)),
                  if (widget.why != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(widget.why!, textAlign: TextAlign.center, style: Ttc.t(11, color: Ttc.offBtnText.withValues(alpha: .85), weight: FontWeight.w600, height: 1.2)),
                    ),
                ]),
        ),
      ),
    );
  }
}
