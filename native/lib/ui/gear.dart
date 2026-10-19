// 장비 가방·스킬 바·데려갈 사람 고르기. 웹 renderGear(3329) · renderSkills(2884) · renderSheet('party')(2573) 를 옮겼다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'atlas.dart';
import 'icons.dart';
import 'portrait.dart';
import 'survivors.dart';
import 'theme.dart';
import 'widgets.dart';

// ======================= 장비 그림 (웹 gicon + design.js gear) =======================
const _gs = {'tools': ('gear-tools.webp', 7, 3, 8.0), 'wear': ('gear-wear.webp', 5, 3, 8.0), 'keep': ('gear-keep.webp', 6, 3, 8.0), 'line': ('line-items.webp', 12, 1, 0.0)};

class GearIcon extends StatelessWidget {
  const GearIcon(this.t, {super.key, this.size = 30, this.empty = false, this.slot});
  final String? t;
  final double size;
  final bool empty;
  final String? slot;
  @override
  Widget build(BuildContext context) {
    final G = t == null ? null : gear[t];
    if (G == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0x663B2A1A), width: 1.5)),
        alignment: Alignment.center,
        child: slot != null ? SvgIcon(slotSvg[slot]!, size: size * .5, color: Ttc.sepia) : Text('+', style: Ttc.t(16, color: Ttc.sepia, weight: FontWeight.w700, height: 1)),
      );
    }
    final c = Color(grades[G.g].color);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE3C4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c, width: 2),
        boxShadow: G.g >= 3 ? const [BoxShadow(color: Color(0x99FFD24A), blurRadius: 8)] : null,
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(4), child: CustomPaint(painter: _GearPainter(t!))),
    );
  }
}

class _GearPainter extends CustomPainter {
  _GearPainter(this.t);
  final String t;
  @override
  void paint(Canvas canvas, Size size) {
    final cell = gearCell[t];
    if (cell == null) return;
    final (f, cols, rows, inset) = _gs[cell.$1]!;
    final img = Atlas.image(f), r = Atlas.cell(f, cell.$2, cols, rows);
    if (img == null || r == null) return;
    final src = r.deflate(inset);
    canvas.drawImageRect(img, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_GearPainter old) => old.t != t;
}

const slotSvg = {
  'tool': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M14 6a4 4 0 0 0 5 5l-9 9-3-3 9-9a4 4 0 0 0-2-2z"/></svg>',
  'wear': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M8 3l-5 4 3 3 2-1v12h8V9l2 1 3-3-5-4c-1 2-5 2-8 0z"/></svg>',
  'keep': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M6 8h12l1 12H5z"/><path d="M9 8a3 3 0 0 1 6 0"/></svg>',
};

/// 등급 칩 (웹 .gr)
Widget gradeChip(int g) {
  final legend = g >= 3;
  return Container(
    padding: const EdgeInsets.fromLTRB(6, 3, 6, 2),
    decoration: BoxDecoration(
      color: legend ? null : Color(grades[g].color),
      gradient: legend ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF3C34A), Color(0xFFC9861A)]) : null,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(grades[g].n ?? '', style: Ttc.t(11, color: legend ? const Color(0xFF3B2A1A) : Colors.white, weight: FontWeight.w700, height: 1)),
  );
}

Widget badge(String t, {Color bg = const Color(0xFF6F8F4A), Color fg = Colors.white, Gradient? grad}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: grad == null ? bg : null, gradient: grad, borderRadius: BorderRadius.circular(99)),
      child: Text(t, style: Ttc.t(11, color: fg, height: 1.2)),
    );

const _goldGrad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF3C34A), Color(0xFFC9861A)]);

Widget ghostBtn(String t, VoidCallback? onTap, {double minW = 56}) => GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minWidth: minW, minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0x47252E36))),
        child: Text(t, style: Ttc.t(13, color: onTap == null ? Ttc.offBtnText : Ttc.sepia, weight: FontWeight.w700)),
      ),
    );

/// 웹 .wch: 누가 입고 있는지
Widget wearChip(int w) => Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.fromLTRB(2, 2, 8, 2),
      decoration: BoxDecoration(color: const Color(0x143B2A1A), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE6D8B6), border: Border.all(color: const Color(0x4D3B2A1A))),
          clipBehavior: Clip.antiAlias,
          child: Portrait(w, width: 18, height: 21),
        ),
        const SizedBox(width: 5),
        Text('${survivors[w].name} 착용 중', style: Ttc.t(11, color: Ttc.sepia, weight: FontWeight.w600, height: 1)),
      ]),
    );

int gearRank(Game g, int id, Map it, Object? cur) {
  final G = gear[it['t']]!;
  if (it['u'] == cur) return 0;
  if (G.only == id) return 1;
  final w = g.wearer(it['u']);
  if (G.fit.contains(id)) return w == null ? 2 : 3;
  return w == null ? 4 : 5;
}

// ======================= 장비 한 줄 (웹 itemRow) =======================
class GearRow extends StatefulWidget {
  const GearRow(this.g, this.it, {super.key, this.forId, required this.action});
  final Game g;
  final Map it;
  final int? forId;
  final Widget action;
  @override
  State<GearRow> createState() => _GearRowState();
}

class _GearRowState extends State<GearRow> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final g = widget.g, it = widget.it, G = gear[it['t']]!, w = g.wearer(it['u']), id = widget.forId, fit = id != null && G.fit.contains(id);
    final only = G.only;
    String? more;
    if (only != null) {
      more = '${g.hasSv(only) ? survivors[only].name : '???'} 전용';
    } else if (!fit && G.fit.isNotEmpty) {
      more = '잘 맞는 사람: ${G.fit.map((f) => g.hasSv(f) ? survivors[f].name : '???').join(', ')}';
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => open = !open),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x333B2A1A)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: GearIcon(it['t'] as String, size: 50)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 3, children: [
                Text(G.n, style: Ttc.t(15, color: Ttc.sepia, weight: FontWeight.w700, height: 1.35)),
                gradeChip(G.g),
                if (only != null && only == id)
                  badge('전용 ×1.5', grad: _goldGrad, fg: const Color(0xFF3B2A1A))
                else if (fit)
                  badge('잘 맞음 ×1.5'),
              ]),
              const SizedBox(height: 5),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final e in G.eff.entries) _gfx(effName(e.key, e.value)),
                _gfx(slotName[G.slot]!, slot: true),
              ]),
              if (w != null) wearChip(w),
              if (open)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: G.d, style: const TextStyle(color: Color(0xFF8A7458))),
                    if (more != null) TextSpan(text: '\n$more', style: only != null ? const TextStyle(fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)]) : null),
                  ]), style: Ttc.t(13, color: Ttc.sepia2, height: 1.5)),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Align(alignment: Alignment.center, child: widget.action),
        ]),
      ),
    );
  }

  Widget _gfx(String t, {bool slot = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: slot ? const Color(0x143B2A1A) : const Color(0x1F4D7A4F), borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: Ttc.t(11.5, color: slot ? const Color(0xFF73634E) : const Color(0xFF3F6A42), weight: FontWeight.w600, height: 1)),
      );
}

Widget _bchip(String t, bool on, VoidCallback onTap, {bool small = false}) => GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: small ? 32 : 34),
        padding: EdgeInsets.symmetric(horizontal: small ? 11 : 13, vertical: 8),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF3B2A1A) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: on ? Colors.transparent : const Color(0x333B2A1A)),
        ),
        child: Text(t, style: Ttc.t(small ? 11.5 : 12, color: on ? const Color(0xFFF3EAD6) : const Color(0xFF3B2A1A), weight: small ? FontWeight.w500 : FontWeight.w600, height: 1.2)),
      ),
    );

Widget _lockBtn(bool on, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: on ? 1 : .55,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: on ? const Color(0xFF3B2A1A) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: SvgIcon(
              '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="3" y="7" width="10" height="7" rx="1.5"/><path d="${on ? 'M5 7V5a3 3 0 0 1 6 0v2' : 'M5 7V5a3 3 0 0 1 5.6-1.5'}"/></svg>',
              size: 14,
              color: on ? const Color(0xFFF3C76A) : const Color(0xFF8A7A64)),
        ),
      ),
    );

Widget autoBox({required String title, required String sub, required Widget button, Widget? trailing, Widget? lead}) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFDCE4DE), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFB9C8BD))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [if (lead != null) ...[lead, const SizedBox(width: 4)], Flexible(child: Text(title, style: Ttc.t(13.5, color: const Color(0xFF354D44), weight: FontWeight.w700)))]),
            Text(sub, style: Ttc.t(11.5, color: Ttc.sepia2, height: 1.35)),
          ]),
        ),
        const SizedBox(width: 8),
        button,
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ]),
    );

/// 웹 .tgl 켜고 끄는 스위치
Widget toggle(bool on, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 50,
        height: 28,
        decoration: BoxDecoration(color: on ? const Color(0xFF6F8F4A) : const Color(0xFFCBBD9B), borderRadius: BorderRadius.circular(99), border: Border.all(color: Ttc.sepia, width: 2)),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Ttc.paper, boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))]),
          ),
        ),
      ),
    );

Widget autoGearBox(Game g, void Function(String) toast) {
  final n = g.inv.length;
  if (n == 0) return const SizedBox.shrink();
  return autoBox(
    title: '장비 자동 맞추기',
    lead: dutyIco('gear', size: 20),
    sub: '전용 도구 → 잘맞는 장비 → 높은 등급 순으로 $n개를 나눠 입혀요',
    button: BuyButton('지금 맞추기', width: 84, onTap: () {
      final ch = g.autoGear();
      toast(ch == 0 ? '이미 가장 잘 맞게 입고 있어요' : '장비 자동 맞춤 완료 · 바뀐 칸 $ch');
    }),
  );
}

// ======================= 장비 가방 시트 =======================
class BagBody extends StatefulWidget {
  const BagBody(this.g, {super.key, this.id, this.slot, required this.onBack, required this.toast});
  final Game g;
  final int? id;
  final String? slot;
  final VoidCallback onBack;
  final void Function(String) toast;
  @override
  State<BagBody> createState() => _BagBodyState();
}

class _BagBodyState extends State<BagBody> {
  static String bagF = 'all', bagSort = 'grade';
  Game get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final id = widget.id, slot = widget.slot, inv = g.inv;
    final out = <Widget>[];
    if (id != null && slot != null) {
      final s = survivors[id], cur = g.eqOf(id)[slot];
      out.add(GestureDetector(
        onTap: widget.onBack,
        child: Container(
          margin: const EdgeInsets.fromLTRB(0, 2, 0, 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: const Color(0xFF29353F), borderRadius: BorderRadius.circular(9)),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE6D8B6)), clipBehavior: Clip.antiAlias, child: Portrait(id, width: 34, height: 40)),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${s.name}에게 돌아가기', style: Ttc.t(15, color: const Color(0xFFFFCF7A), weight: FontWeight.w700)),
                TextSpan(text: '\n${slotName[slot]} 칸을 고르는 중'),
              ]), style: Ttc.t(12.5, color: Ttc.paper, height: 1.45)),
            ),
          ]),
        ),
      ));
      final list = inv.where((x) => gear[x['t']]!.slot == slot && g.canWear(id, x['t'] as String)).toList()
        ..sort((a, b) {
          final r = gearRank(g, id, a, cur) - gearRank(g, id, b, cur);
          return r != 0 ? r : gear[b['t']]!.g - gear[a['t']]!.g;
        });
      out.add(sec('가방 속 ${slotName[slot]} ${list.length}개'));
      if (list.isEmpty) out.add(emptyBox(SvgIcon(slotSvg[slot]!, size: 26, color: Ttc.sepia2), '${slotName[slot]}이 아직 없어요', '아래에서 만들거나 폐허·원정·주파수 탐색에서 찾아요'));
      for (final it in list) {
        final w = g.wearer(it['u']);
        out.add(GearRow(g, it,
            key: ValueKey(it['u']),
            forId: id,
            action: it['u'] == cur
                ? ghostBtn('빼기', () => g.unequip(id, slot))
                : BuyButton(w != null ? '가져오기' : '장착', width: 64, onTap: () {
                    if (g.equip(id, slot, it['u'])) {
                      widget.toast('${survivors[id].name}: ${gear[it['t']]!.n} 장착');
                      widget.onBack();
                    }
                  })));
      }
    } else {
      out.add(autoGearBox(g, widget.toast));
      out.add(_tidyBox(context));
      final fb = <(String, String)>[('all', '전체'), for (final k in slotKeys) (k, slotName[k]!)];
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (k, n) in fb) _bchip('$n ${k == 'all' ? inv.length : inv.where((x) => gear[x['t']]!.slot == k).length}', bagF == k, () => setState(() => bagF = k)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (k, n) in const [('grade', '등급순'), ('new', '새로 얻은 순'), ('name', '이름순')]) _bchip(n, bagSort == k, () => setState(() => bagSort = k), small: true),
          ]),
        ]),
      ));
      int sorter(Map a, Map b) {
        final A = gear[a['t']]!, B = gear[b['t']]!;
        if (bagSort == 'new') return (b['u'] as num).compareTo(a['u'] as num);
        if (bagSort == 'name') return A.n.compareTo(B.n);
        return B.g != A.g ? B.g - A.g : A.n.compareTo(B.n);
      }

      for (final sl in bagF == 'all' ? slotKeys : [bagF]) {
        final list = inv.where((x) => gear[x['t']]!.slot == sl).toList()..sort(sorter);
        out.add(sec('${slotName[sl]} ${list.length}개'));
        if (list.isEmpty) {
          out.add(Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0x0D3B2A1A), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Opacity(opacity: .6, child: SvgIcon(slotSvg[sl]!, size: 16, color: Ttc.sepia2)),
              const SizedBox(width: 8),
              Expanded(child: Text('비어 있어요 · 폐허·원정·라디오에서 찾거나 아래에서 만들어요', style: Ttc.t(12.5, color: Ttc.sepia2))),
            ]),
          ));
        }
        for (final it in list) {
          final G = gear[it['t']]!, w = g.wearer(it['u']), lk = it['lk'] == 1;
          out.add(GearRow(g, it,
              key: ValueKey(it['u']),
              action: Row(mainAxisSize: MainAxisSize.min, children: [
                _lockBtn(lk, () => g.toggleLock(it['u'])),
                const SizedBox(width: 6),
                if (w != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: const Color(0x1F4F6E2F), borderRadius: BorderRadius.circular(99)),
                    child: Text('착용 중', style: Ttc.t(12, color: Ttc.ok, weight: FontWeight.w700, height: 1)),
                  )
                else if (!lk && !G.sig && !G.line)
                  ghostBtn('분해', () => g.dismantle(it['u'])),
              ])));
        }
      }
    }
    // 작업대에서 만들기
    final wb = g.wbL;
    out.add(sec('작업대에서 만들기${wb > 0 ? ' · 작업대 $wb단계' : ''}'));
    if (wb == 0) out.add(descText('작업대를 세우면 장비를 만들 수 있어요.'));
    for (final G in gear.values.where((G) => G.cost != null && !G.sig && (slot == null || G.slot == slot))) {
      final c = scaleCost(G.cost!, g.costMult), lock = wb < G.wb;
      out.add(Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ttc.line))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 5, children: [
                GearIcon(G.key, size: 22),
                Text(G.n, style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700)),
                gradeChip(G.g),
              ]),
              const SizedBox(height: 3),
              descText('${effText(G.eff)}${lock ? ' · 작업대 ${G.wb}단계 필요' : ''}'),
              if (!lock) Padding(padding: const EdgeInsets.only(top: 5), child: costWrap(g, c)),
            ]),
          ),
          const SizedBox(width: 8),
          BuyButton(lock ? '잠김' : '만들기',
              onTap: lock || !g.canPay(c)
                  ? null
                  : () {
                      g.craftGear(G.key);
                      widget.toast('${G.n}을(를) 만들었어요');
                      final it = g.inv.last;
                      if (id != null && slot != null && G.slot == slot && g.eqOf(id)[slot] == null) {
                        g.equip(id, slot, it['u']);
                        widget.onBack();
                      }
                    },
              why: lock ? null : (g.canPay(c) ? null : '자재 부족')),
        ]),
      ));
    }
    out.add(Padding(
      padding: const EdgeInsets.only(top: 8),
      child: descText('사진·동전·하모니카·회중시계·나침반 같은 소지품은 폐허와 원정에서, 전설 장비는 주파수 탐색에서만 나와요. 전용 장비는 그 사람의 이야기와 신뢰로 얻고, 다른 사람은 쓸 수 없어요.'),
    ));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 20), children: out);
  }

  Widget _tidyBox(BuildContext context) {
    final c = g.bagSurplus();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Ttc.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Ttc.line)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.isEmpty ? '정리할 장비가 없어요' : '남는 장비 ${c.length}개', style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(c.isEmpty ? '같은 장비 여분이나, 더 좋은 장비가 있는 일반 등급 장비를 골라 줘요' : '같은 장비 여분 · 더 좋은 장비가 있는 일반 등급 · 착용 중·전용·잠금은 빼고',
                style: Ttc.t(13, color: Ttc.sepia2, height: 1.4)),
          ]),
        ),
        if (c.isNotEmpty) ...[const SizedBox(width: 10), BuyButton('정리하기', width: 72, onTap: () => showTidy(context, g, widget.toast))],
      ]),
    );
  }
}

/// 장비 가방 정리 (웹 openTidy)
void showTidy(BuildContext context, Game g, void Function(String) toast) {
  final c = g.bagSurplus();
  if (c.isEmpty) {
    toast('정리할 장비가 없어요');
    return;
  }
  final pick = {for (final o in c) o.$1['u']};
  showPageOf(context, g, (ctx) => StatefulBuilder(builder: (ctx, set) {
        final list = g.bagSurplus(), sel = [for (final o in list) if (pick.contains(o.$1['u'])) o.$1];
        final back = <String, num>{};
        for (final x in sel) {
          g.dismBack(gear[x['t']]!).forEach((k, v) => back[k] = (back[k] ?? 0) + v);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('장비 가방 정리', style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('남는 장비 분해', textAlign: TextAlign.center, style: Ttc.t(20, color: Ttc.sepia, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          descText('체크를 풀면 그 장비는 남겨요. 분해하면 재료를 절반쯤 돌려받아요.'),
          const SizedBox(height: 8),
          for (final (x, why) in list)
            () {
              final G = gear[x['t']]!, on = pick.contains(x['u']);
              return GestureDetector(
                onTap: () => set(() => on ? pick.remove(x['u']) : pick.add(x['u'])),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? const Color(0xFFF6E6CC) : const Color(0xFFFBF6EA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: on ? const Color(0xB3C98A3A) : const Color(0x2E3B2A1A)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? const Color(0xFFC98A3A) : null,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: on ? const Color(0xFFC98A3A) : const Color(0x663B2A1A), width: 1.5),
                      ),
                      child: on ? Text('✓', style: Ttc.t(12, color: Colors.white, weight: FontWeight.w700, height: 1)) : null,
                    ),
                    const SizedBox(width: 10),
                    GearIcon(G.key, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(G.n, style: Ttc.t(14, color: const Color(0xFF3B2A1A), weight: FontWeight.w700)), gradeChip(G.g)]),
                        Text('${slotName[G.slot]} · $why', style: Ttc.t(11.5, color: const Color(0xFF6B5A45))),
                      ]),
                    ),
                  ]),
                ),
              );
            }(),
          Padding(padding: const EdgeInsets.fromLTRB(0, 10, 0, 4), child: descText('돌려받는 재료')),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (sel.isEmpty) descText('고른 장비가 없어요'),
            for (final e in back.entries)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: const Color(0x2460A050), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ResIcon(e.key, size: 15),
                  const SizedBox(width: 4),
                  Text('${matOf[e.key]?.n ?? e.key} +${fmt(e.value)}', style: Ttc.t(12.5, color: const Color(0xFF2F5A28), weight: FontWeight.w600, height: 1)),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            pageBtn('그만두기', () => Navigator.pop(ctx), alt: true),
            const SizedBox(width: 8),
            pageBtn('${sel.length}개 분해', sel.isEmpty
                ? null
                : () {
                    Navigator.pop(ctx);
                    g.tidy(sel);
                  }),
          ]),
        ]);
      }));
}

// ======================= 스킬 바에 데려갈 3명 (웹 party) =======================
Widget partyBody(Game g) {
  final ids = g.svIds.toList(), party = g.party;
  final rec = ids.length > 3 ? g.partyRecommend() : null;
  const catName = {'all': '만능', 'scav': '뒤지기', 'loot': '물자', 'fever': '연타', 'reset': '재사용', 'craft': '가공', 'find': '찾기', 'heal': '치료', 'storm': '재해', 'food': '식량', 'build': '건설', 'reveal': '밝히기', 'drone': '드론'};
  return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 20), children: [
    if (ids.isEmpty) Padding(padding: const EdgeInsets.all(10), child: descText('아직 구조한 생존자가 없어요.')),
    if (rec != null)
      () {
        final same = rec.every(party.contains) && party.length == rec.length;
        return MCard(
          thumb: const SizedBox(width: 0),
          title: '추천 구성',
          desc: descText(rec.map((id) => '${survivors[id].name}(${catName[skills[id].cat] ?? ''})').join(' · ')),
          button: BuyButton(same ? '적용됨' : '추천으로\n바꾸기', width: 76, onTap: same
              ? null
              : () {
                  g.party = [...rec];
                  g.dirty = true;
                  g.poke();
                }),
        );
      }(),
    for (final id in ids)
      () {
        final s = survivors[id], on = party.contains(id), r = rec != null && rec.contains(id);
        return Container(
          padding: EdgeInsets.fromLTRB(r ? 8 : 0, 8, 0, 8),
          decoration: BoxDecoration(
            color: r ? const Color(0xFFFDF6DF) : null,
            border: Border(bottom: const BorderSide(color: Color(0x333B2A1A)), left: r ? const BorderSide(color: Color(0xFFE0B441), width: 3) : BorderSide.none),
          ),
          child: Row(children: [
            faceBox(g, id, w: 46, h: 54),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 2, children: [
                  Text(s.name, style: Ttc.t(15, color: Ttc.sepia, weight: FontWeight.w700)),
                  gradeTag(g, id),
                  badge(on ? '데려감' : '대기', bg: on ? const Color(0xFF6F8F4A) : const Color(0xFFB8A680)),
                  if (r) badge('추천', bg: const Color(0xFFE0B441), fg: const Color(0xFF3B2A1A)),
                ]),
                const SizedBox(height: 2),
                Text.rich(TextSpan(children: [bold(skills[id].n), TextSpan(text: ' · ${skills[id].d} (재사용 ${g.skillCd(id).round()}초)')]), style: Ttc.t(13, color: Ttc.sepia2, height: 1.45)),
              ]),
            ),
            const SizedBox(width: 8),
            on ? ghostBtn('빼기', () => g.toggleParty(id)) : BuyButton('넣기', width: 56, onTap: party.length >= 3 ? null : () => g.toggleParty(id)),
          ]),
        );
      }(),
  ]);
}

// ======================= 스킬 바 (지도 왼쪽 아래) =======================
class SkillBar extends StatelessWidget {
  const SkillBar(this.g, {super.key, required this.onEmpty, required this.toast});
  final Game g;
  final VoidCallback onEmpty;
  final void Function(String) toast;

  @override
  Widget build(BuildContext context) {
    final ep = g.effParty(), n = g.S.sv.length;
    final kids = <Widget>[];
    var emptyShown = false;
    for (var k = 0; k < 3; k++) {
      if (k >= ep.length) {
        if (emptyShown || n <= g.party.length) continue;
        emptyShown = true;
        kids.add(_slot(null, null));
      } else {
        kids.add(_slot(ep[k].$1, ep[k].$2));
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var k = 0; k < kids.length; k++) ...[if (k > 0) const SizedBox(width: 8), kids[k]],
    ]);
  }

  Widget _slot(int? id, int? sub) {
    if (id == null) {
      return GestureDetector(
        onTap: onEmpty,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xD93A2618), border: Border.all(color: const Color(0xFFD2B987))),
          alignment: Alignment.center,
          child: Text('+', style: Ttc.t(18, color: Ttc.paper, weight: FontWeight.w700, height: 1)),
        ),
      );
    }
    final off = g.busy(id), left = g.cdLeft(id), tot = g.skillCd(id), ready = left <= 0 && !off;
    final away = isAwayVal(g.rec(id)?['away']), hurtT = away ? null : hurtLeft(g, id), hurt = hurtT != null;
    const red = Color(0xFFD0533A);
    const txtShadow = [Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1))];
    return GestureDetector(
      onTap: () {
        if (off) {
          toast(away ? '${survivors[id].name}은(는) 원정 중이에요' : '${survivors[id].name}은(는) 다쳐서 쉬는 중이에요${hurt ? ' · $hurtT 남음' : ''}');
          return;
        }
        if (left > 0) {
          toast('${skills[id].n} 준비 중 · ${left.ceil()}초');
          return;
        }
        g.useSkill(id);
      },
      child: SizedBox(
        width: 44,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Opacity(
            // 원정 간 사람은 흐리게 (여기 없음)
            opacity: away ? .45 : 1,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE6D8B6),
                  border: Border.all(color: hurt ? red : ready ? Ttc.amber : const Color(0xFFD2B987), width: hurt ? 2 : 1),
                  boxShadow: hurt
                      ? const [BoxShadow(color: Color(0x66D0533A), spreadRadius: 2)]
                      : ready
                          ? const [BoxShadow(color: Color(0x26DFA54B), spreadRadius: 2)]
                          : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  ColorFiltered(
                    colorFilter: off ? const ColorFilter.matrix([.18, .35, .07, 0, 0, .18, .35, .07, 0, 0, .18, .35, .07, 0, 0, 0, 0, 0, 1, 0]) : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                    child: Portrait(id, width: 40, height: 47),
                  ),
                  // 다친 사람: 얼굴에 붉은 기운
                  if (hurt) const Positioned.fill(child: ColoredBox(color: Color(0x33D0533A))),
                  // 스킬 대기: 얼굴을 덮는 숫자 대신 옅은 시계 바늘 그림자만 (숫자는 오른쪽 아래 배지)
                  if (left > 0 && !off) Positioned.fill(child: CustomPaint(painter: _CdPainter((left / tot).clamp(0, 1).toDouble()))),
                ]),
              ),
              if (sub != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF3F8A7E), borderRadius: BorderRadius.circular(99)),
                    child: Text('대신', style: Ttc.t(10, color: Colors.white, weight: FontWeight.w700, height: 1)),
                  ),
                ),
              // 다침 배지: 붉은 동그라미 속 흰 십자 (왼쪽 위)
              if (hurt)
                Positioned(
                  top: -3,
                  left: -3,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: red, border: Border.all(color: Ttc.paper, width: 1.5)),
                    alignment: Alignment.center,
                    child: Stack(alignment: Alignment.center, children: [
                      Container(width: 8, height: 2.4, color: Colors.white),
                      Container(width: 2.4, height: 8, color: Colors.white),
                    ]),
                  ),
                ),
              // 스킬 대기 초: 오른쪽 아래 작은 배지
              if (left > 0 && !off)
                Positioned(
                  right: -5,
                  bottom: -3,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xF0202932), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0xFFD2B987), width: 1)),
                    child: Text('${left.ceil()}', textAlign: TextAlign.center, style: Ttc.t(10, color: Ttc.paper, weight: FontWeight.w700, height: 1)),
                  ),
                ),
            ]),
          ),
          if (off)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(away ? '원정 중' : (hurtT ?? '부상'),
                  maxLines: 1,
                  style: Ttc.t(10, color: hurt ? const Color(0xFFFFB4A3) : Ttc.paper, weight: hurt ? FontWeight.w700 : FontWeight.w500, height: 1.2).copyWith(shadows: txtShadow)),
            ),
        ]),
      ),
    );
  }
}

class _CdPainter extends CustomPainter {
  _CdPainter(this.p);
  final double p;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * p, true, Paint()..color = const Color(0x8C0D0B08));
  }

  @override
  bool shouldRepaint(_CdPainter old) => old.p != p;
}
