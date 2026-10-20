// 빠른 메뉴 (웹 openRing/buildRing 2488): 건물 설명 창 + 창 안 아래 한 줄 버튼 (2026-10-21 앱: 건물 둘레 동그란 버튼에서 바꿈)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/engine.dart';
import '../game/voice.dart';
import 'icons.dart';
import 'map_view.dart';
import 'story_ui.dart';
import 'theme.dart';
import 'lines_ui.dart';
import 'widgets.dart';

String _ri(String p) => '<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">$p</svg>';
final _icons = {
  'person': _ri('<circle cx="14" cy="9" r="4.5"/><path d="M5 25c1-6 5-9 9-9s8 3 9 9"/>'),
  'up': _ri('<path d="M14 23V6M7 12l7-7 7 7"/>'),
  'x': _ri('<path d="M5 13L14 5l9 8M7 12v11h14V12"/><path d="M12 23v-6h4v6"/>'),
  'line': _ri('<rect x="7" y="4" width="14" height="15" rx="3"/><path d="M7 12h14M10 19l-3 5M18 19l3 5"/><circle cx="10.5" cy="15.5" r="1"/><circle cx="17.5" cy="15.5" r="1"/>'),
};

class _Tok {
  const _Tok(this.icon, this.cap, this.onTap, {this.poor = false, this.lock = false, this.hl, this.go = false});
  final String icon, cap;
  final String? hl; // 길잡이 강조 키
  final VoidCallback onTap;
  final bool poor, lock;

  /// 노선 들어가기: 크고 호박색 (웹 .tok.lngo)
  final bool go;
}

class RingMenu extends StatelessWidget {
  const RingMenu({super.key, required this.g, required this.cam, required this.tile, required this.say, required this.onClose, required this.onAssign, required this.onShelter, required this.toast, this.bottomGuard = 0});

  /// 아래쪽 랜턴 버튼·탭 줄이 차지하는 높이 (버튼이 그 아래로 가지 않게, 웹 ringBot)
  final double bottomGuard;
  final Game g;
  final Camera cam;
  final int tile;
  final String say;
  final VoidCallback onClose, onAssign, onShelter;
  final void Function(String) toast;
  static const R = 96.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final S = g.S, m = g.modAtTile(tile);
      final toks = <_Tok>[];
      Widget label;
      if (S.ter[tile] == T.lm && m == null) {
        final l = S.lm[tile]!, t = lmText(l.k, S.region), info = landmarks[l.k], s = S.site[tile], c = g.lmCost(l.k);
        label = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _title(t[0], info.key == 'station' ? (l.ok ? '노선 입구 · 복구 완료' : '노선 입구 · 랜드마크') : (l.ok ? '복구 완료' : '랜드마크')),
          const SizedBox(height: 4),
          Text(l.ok ? t[2] : t[1], style: Ttc.t(13, color: Ttc.sepia, height: 1.5)),
          const SizedBox(height: 5),
          Wrap(spacing: 4, runSpacing: 4, children: [
            // 노선 역 표시 (웹 chip.ln: 호박색)
            if (info.key == 'station')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFF0C071), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0xFF2C2217))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SvgIcon(_icons['line']!, size: 13, color: const Color(0xFF2C2217)),
                  const SizedBox(width: 4),
                  Text(
                      '끊긴 노선 입구${l.ok ? (((g.lnState()['fat'] as num?) ?? 0) > 0 ? ' · 보상 ${(g.lnMult * 100).round()}%' : ' · 지금 최고 보상') : ' · 복구하면 열려요'}',
                      style: Ttc.t(12, color: const Color(0xFF2C2217), weight: FontWeight.w700)),
                ]),
              ),
            _chip('복구하면 ${info.desc}', good: true),
            if (!l.ok && s != null) _chip('남은 물자 ${s.c}/${s.max}'),
          ]),
          if (!l.ok) ...[
            const SizedBox(height: 6),
            Text('복구에 필요한 자재', style: Ttc.t(12, color: Ttc.sepia, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            costWrap(g, c),
          ],
        ]);
        if (!l.ok) {
          if (s != null && s.c > 0) {
            toks.add(_Tok('person', '뒤지기 조준', () {
              g.setAim(tile);
              onClose();
              toast('랜턴 버튼으로 랜드마크를 뒤져요');
            }));
          }
          toks.add(_Tok('up', '복구하기', hl: 'ring:lm', () {
            if (!g.canPay(c)) {
              toast('자재가 조금 모자라요');
              return;
            }
            g.restoreLm(tile);
          }, poor: !g.canPay(c)));
        } else if (info.key == 'station') {
          toks.add(_Tok('line', '노선 탐사', go: true, () {
            onClose();
            showLnPrep(context, g);
          }));
        }
      } else if (m != null) {
        final d = mods[m.id]!, slot = g.modAt[tile]!, id = S.asg[tile], wk = id != null && g.hasSv(id) ? survivors[id] : null;
        final up = m.l < 2 ? g.modCost(m.id, m.l + 1) : null;
        final ashStuck = S.ash['$tile'] is Map && (S.ash['$tile'] as Map)['stuck'] == true;
        label = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _title(d.n, '${m.l + 1}/3단계'),
          if (say.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${wk != null ? '${wk.name}: ' : ''}“${wk != null ? voiced(id!, say) : say}”', style: Ttc.t(13, color: Ttc.sepia, height: 1.5))),
          const SizedBox(height: 5),
          Wrap(spacing: 4, runSpacing: 4, children: [
            if (m.id == 5 && g.have('fuel') <= 0) _chip('연료가 없어 멈춤', bad: true),
            if (ashStuck) _chip('재에 덮여 멈춤 · 두드려 걷어내요', bad: true),
            if (wk != null) _chip('${wk.name} ×${g.asgMult(tile).toStringAsFixed(1)}', good: true),
            _chip(d.fx[m.l], good: true),
          ]),
          if (up != null) ...[
            const SizedBox(height: 5),
            Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [_chip('다음: ${d.fx[m.l + 1]}'), costWrap(g, up)]),
          ],
        ]);
        if (up != null) {
          toks.add(_Tok('up', '강화', () {
            if (!g.canPay(up)) {
              toast('자재가 조금 모자라요');
              return;
            }
            g.upMod(slot);
          }, poor: !g.canPay(up)));
        }
        final n = S.sv.length;
        toks.add(_Tok('person', id != null && wk != null ? '${wk.name} 교체' : (n > 0 ? '생존자 배치' : '생존자 없음'), n > 0 ? onAssign : () {}, lock: n == 0, hl: 'ring:asg'));
        toks.add(_Tok('x', '쉘터 화면', onShelter));
      } else {
        return const SizedBox.shrink();
      }

      // 2026-10-21 대표님: 건물 둘레에 흩어진 버튼이 알림·부탁 띠와 겹침 → 버튼을 설명 창 안 아래 한 줄로.
      // 창은 건물을 가리지 않는 쪽(건물이 화면 아래쪽이면 위, 위쪽이면 아래)에 두고, 내용만큼 늘어난다(넘치면 창 안에서 스크롤)
      final w = tileC(tile);
      final by = (w.dy - cam.y) * cam.z + box.maxHeight / 2;
      final labelW = math.min(360.0, box.maxWidth - 24);
      final top = by > box.maxHeight * .48;
      const topY = 58.0;
      final botY = bottomGuard + 8; // 랜턴 버튼·탭 줄 바로 위 (스킬 바는 창이 떠 있는 동안 숨는다)
      final room = top ? by - 60 - topY : box.maxHeight - botY - (by + 24);
      final maxH = math.max(220.0, math.min(room, box.maxHeight - topY - botY - 8));
      return Stack(children: [
        Positioned(
          left: (box.maxWidth - labelW) / 2,
          width: labelW,
          top: top ? topY : null,
          bottom: top ? null : botY,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Ttc.paper,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Ttc.line),
                boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Flexible(child: SingleChildScrollView(child: label)),
                if (toks.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    for (var k = 0; k < toks.length; k++) ...[
                      if (k > 0) const SizedBox(width: 6),
                      Expanded(child: toks[k].hl == null ? _TokBtn(toks[k]) : hl(toks[k].hl!, _TokBtn(toks[k]), radius: 8)),
                    ],
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ]);
    });
  }

  Widget _title(String b, String i) => Text.rich(TextSpan(children: [
        TextSpan(text: b, style: Ttc.t(17, color: Ttc.sepia, weight: FontWeight.w700)),
        TextSpan(text: '  $i', style: Ttc.t(12, color: Ttc.sepia2)),
      ]));

  Widget _chip(String t, {bool good = false, bool bad = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: bad ? Ttc.no : good ? const Color(0xFF6F8F4A) : const Color(0x593B2A1A)),
        ),
        child: Text(t, style: Ttc.t(12, color: bad ? Ttc.no : good ? Ttc.ok : Ttc.sepia)),
      );
}

class _TokBtn extends StatelessWidget {
  const _TokBtn(this.t);
  final _Tok t;
  @override
  Widget build(BuildContext context) {
    final bg = t.go ? const Color(0xFFF0C071) : t.lock ? const Color(0xFFD9CFBC) : t.poor ? const Color(0xFFE6DCC6) : const Color(0xFF2F3F4B);
    final fg = t.go ? const Color(0xFF2C2217) : t.lock ? const Color(0xFF8A7D68) : t.poor ? const Color(0xFF9A5A44) : Ttc.paper;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: t.onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.go ? const Color(0xFF2C2217) : t.poor || t.lock ? Ttc.line : const Color(0xFF243039)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          SvgIcon(_icons[t.icon]!, size: 20, color: fg),
          const SizedBox(height: 3),
          Text(t.cap, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Ttc.t(12.5, color: fg, weight: FontWeight.w700, height: 1.1)),
        ]),
      ),
    );
  }
}
