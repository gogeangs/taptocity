// 둥근 빠른 메뉴 (웹 openRing/buildRing 2488): 건물 위 설명 카드 + 건물 둘레 동그란 버튼
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/engine.dart';
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

List<double> _angles(int n) {
  if (n == 1) return [90];
  if (n == 2) return [130, 50];
  final span = n >= 5 ? 240.0 : 180.0, st = 90 + span / 2;
  return [for (var k = 0; k < n; k++) st - k * span / (n - 1)];
}

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
          if (say.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${wk != null ? '${wk.name}: ' : ''}“$say”', style: Ttc.t(13, color: Ttc.sepia, height: 1.5))),
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
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x403B2A1A)))),
            child: Text('빠른 메뉴 · 자세한 건 쉘터 화면에서', style: Ttc.t(11.5, color: Ttc.sepia2)),
          ),
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

      // 건물 화면 위치 (가장자리에서 떨어지게)
      final w = tileC(tile);
      final sx = ((w.dx - cam.x) * cam.z + box.maxWidth / 2).clamp(R + 34, math.max(R + 34, box.maxWidth - R - 34)).toDouble();
      final an = _angles(toks.length);
      // 버튼이 랜턴 버튼·탭 줄 위에 오도록 (웹 ringBot - ringDown)
      final ringDown = an.map((x) => math.sin(x * math.pi / 180)).reduce(math.max) * R + 30 + 24;
      final lowest = math.min(box.maxHeight - R - 44, box.maxHeight - bottomGuard - ringDown);
      final sy = ((w.dy - cam.y) * cam.z + box.maxHeight / 2).clamp(R + 40, math.max(R + 40, lowest)).toDouble();
      final labelW = math.min(300.0, box.maxWidth - 140);
      final ringTop = sy - R - 30;
      final low = ringTop - 58 < 140; // 위에 자리가 모자라면 카드는 아래로
      return Stack(children: [
        Positioned(
          left: (box.maxWidth - labelW) / 2,
          width: labelW,
          top: low ? null : 58,
          bottom: low ? 158 : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: math.max(96, low ? box.maxHeight - (sy + R + 60) - 158 : ringTop - 58 - 8)),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
              decoration: BoxDecoration(
                color: Ttc.paper,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Ttc.line),
                boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: SingleChildScrollView(child: label),
            ),
          ),
        ),
        for (var k = 0; k < toks.length; k++)
          Positioned(
            left: sx + math.cos(an[k] * math.pi / 180) * R - 40,
            top: sy + math.sin(an[k] * math.pi / 180) * R - (toks[k].go ? 30 : 24),
            width: 80,
            child: toks[k].hl == null ? _TokBtn(toks[k]) : hl(toks[k].hl!, _TokBtn(toks[k]), radius: 99),
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: t.onTap,
        child: Column(children: [
          Container(
            width: t.go ? 60 : 48,
            height: t.go ? 60 : 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.go ? const Color(0xFFF0C071) : t.lock ? const Color(0xFF6B5D49) : t.poor ? const Color(0xFFCBBD9B) : Ttc.paper,
              border: Border.all(color: t.go ? const Color(0xFF2C2217) : t.lock ? const Color(0xFF4A3D2C) : Ttc.sepia, width: 2),
              boxShadow: t.go
                  ? const [BoxShadow(color: Color(0x59F0C071), spreadRadius: 3), BoxShadow(color: Color(0x8CFFC86E), blurRadius: 16)]
                  : const [BoxShadow(color: Color(0x73000000), blurRadius: 12, offset: Offset(0, 5))],
            ),
            alignment: Alignment.center,
            child: SvgIcon(_icons[t.icon]!, size: t.go ? 30 : 26, color: t.go ? const Color(0xFF2C2217) : t.lock ? const Color(0xFF3A2F22) : Ttc.sepia),
          ),
          const SizedBox(height: 4),
          Text(t.cap,
              textAlign: TextAlign.center,
              style: Ttc.t(12, color: t.go ? const Color(0xFFFFE2A0) : t.lock ? const Color(0xFFBFAE8F) : t.poor ? const Color(0xFFF0A898) : Ttc.paper, weight: FontWeight.w700, height: 1)
                  .copyWith(shadows: const [Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)), Shadow(color: Colors.black, blurRadius: 6)])),
        ]),
      );
}
