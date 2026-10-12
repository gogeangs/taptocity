import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/data.dart';
import '../game/engine.dart';
import '../game/storage.dart';
import 'map_view.dart';
import 'sheets.dart';
import 'theme.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.game});
  final Game game;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final cam = Camera();
  final fxc = FxLayerController();
  Timer? _clock;
  int _saveAcc = 0;
  Timer? _lampHold;
  int _lampR0 = 0;
  bool _lampDown = false;

  Game get g => widget.game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fxc.onFx = _onFx;
    _start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fxc.pull(g);
    });
  }

  void _start() {
    _clock?.cancel();
    // 게임 시간은 0.25초마다 한 번. 화면은 바뀐 게 있을 때만 다시 그린다.
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final changed = g.tick(.25);
      if (g.fx.isNotEmpty) fxc.pull(g);
      if (changed) g.poke();
      if (++_saveAcc >= 40) {
        _saveAcc = 0;
        _save();
      }
    });
  }

  void _save() {
    if (!g.dirty) return;
    g.dirty = false;
    Storage.save(g.toJsonString());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive || s == AppLifecycleState.hidden || s == AppLifecycleState.detached) {
      // 백그라운드에서는 완전히 멈춘다
      _clock?.cancel();
      _clock = null;
      _lampStop();
      g.dirty = true;
      _save();
    } else if (s == AppLifecycleState.resumed && _clock == null) {
      g.offline(DateTime.now().millisecondsSinceEpoch);
      fxc.pull(g);
      g.poke();
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _lampHold?.cancel();
    super.dispose();
  }

  void _onFx(Fx f) {
    switch (f) {
      case FxDiary(:final k):
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) showDiary(context, k);
        });
      case FxLevelUp(:final lv):
        HapticFeedback.mediumImpact();
        _stamp(lv);
      case FxOffline(:final seconds, :final got):
        final h = seconds ~/ 3600, m = (seconds % 3600 / 60).round();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Ttc.paper,
              title: Text('돌아오셨군요 · ${h > 0 ? '$h시간 ' : ''}$m분 동안', style: Ttc.title(18, color: Ttc.sepia)),
              content: Text('모인 자재 · ${got.entries.map((e) => '${matOf[e.key]!.n} +${e.value}').join(' · ')}', style: Ttc.body(14, color: Ttc.sepia)),
              actions: [TtcButton('좋아요', onTap: () => Navigator.pop(ctx))],
            ),
          );
        });
      default:
        break;
    }
  }

  String? _stampText;
  void _stamp(int lv) {
    setState(() => _stampText = 'Lv.$lv ${shelterName[lv - 1]}');
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) setState(() => _stampText = null);
    });
  }

  // 랜턴 버튼: 누르면 한 번, 누르고 있으면 계속 (웹 lampRepeat)
  void _lampPress() {
    _lampDown = true;
    _lampR0 = g.S.rev.fold(0, (a, v) => a + v);
    HapticFeedback.selectionClick();
    g.digAim();
    _follow();
    fxc.pull(g);
    g.poke();
    _lampHold?.cancel();
    _lampHold = Timer(const Duration(milliseconds: 300), _lampRepeat);
  }

  void _lampRepeat() {
    if (!_lampDown) return;
    if (g.S.rev.fold<int>(0, (a, v) => a + v) - _lampR0 >= holdMax) {
      _lampStop();
      fxc.toast('구름 $holdMax개를 걷었어요 · 다시 눌러요');
      return;
    }
    g.digAim();
    _follow();
    fxc.pull(g);
    g.poke();
    _lampHold = Timer(const Duration(milliseconds: 110), _lampRepeat);
  }

  void _lampStop() {
    _lampDown = false;
    _lampHold?.cancel();
  }

  /// 조준한 칸이 화면 가장자리로 나가면 카메라를 끌어 온다
  void _follow() {
    if (g.aim < 0) return;
    final sz = MediaQuery.of(context).size;
    final w = tileC(g.aim, 12);
    final sx = (w.dx - cam.x) * cam.z + sz.width / 2, sy = (w.dy - cam.y) * cam.z + sz.height * .4;
    if (sx < 70 || sx > sz.width - 70 || sy < 90 || sy > sz.height * .7) {
      cam.set(cam.x + (w.dx - cam.x) * .35, cam.y + (w.dy - cam.y) * .35);
    }
  }

  void _select(String kind, int tile) {
    switch (kind) {
      case 'shelter':
        showTtcSheet(context, g, (c) => ShelterSheet(g));
      case 'module':
        showTtcSheet(context, g, (c) => moduleSheet(c, g, tile), height: .45);
      case 'landmark':
        showTtcSheet(context, g, (c) => landmarkSheet(c, g, tile), height: .55);
      case 'camp':
        showTtcSheet(context, g, (c) => campSheet(c, g, tile), height: .4);
    }
  }

  void _reset() {
    g.replaceState(Game.fresh());
    cam.set(0, (CX + CY + 1) * TH / 2 - 10);
    Storage.save(g.toJsonString());
    fxc.toast('새 땅에서 다시 시작해요');
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      body: Column(children: [
        AnimatedBuilder(animation: g, builder: (c, _) => _Header(g, top: pad.top, onSettings: () => showTtcSheet(context, g, (c) => SettingsSheet(g, onReset: _reset)))),
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: MapView(game: g, camera: cam, onSelect: _select, fxLayer: fxc)),
            // 랜턴 버튼
            Positioned(
              left: 12,
              bottom: 10,
              child: Listener(
                onPointerDown: (_) => _lampPress(),
                onPointerUp: (_) => _lampStop(),
                onPointerCancel: (_) => _lampStop(),
                child: AnimatedBuilder(animation: g, builder: (c, _) => _Lamp(g)),
              ),
            ),
            Positioned(
              right: 12,
              top: 14,
              child: Column(children: [
                _RoundBtn(Icons.add, () => cam.set(cam.x, cam.y, cam.z * 1.25)),
                const SizedBox(height: 6),
                _RoundBtn(Icons.remove, () => cam.set(cam.x, cam.y, cam.z / 1.25)),
                const SizedBox(height: 6),
                _RoundBtn(Icons.home_outlined, () => cam.set(0, (CX + CY + 1) * TH / 2 - 10)),
              ]),
            ),
            if (_stampText != null)
              Center(
                child: Transform.rotate(
                  angle: -.08,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: Ttc.rust, width: 3), borderRadius: BorderRadius.circular(8), color: const Color(0xCCEFE3C4)),
                    child: Text(_stampText!, style: Ttc.title(26, color: Ttc.rust)),
                  ),
                ),
              ),
          ]),
        ),
        _Tabs(onTap: (k) {
          switch (k) {
            case 2:
              showTtcSheet(context, g, (c) => ShelterSheet(g));
            case 4:
              showTtcSheet(context, g, (c) => diarySheet(c, g));
            case 0:
              showTtcSheet(context, g, (c) => comingSheet(c, '생존자', '2단계'), height: .35);
            case 1:
              showTtcSheet(context, g, (c) => comingSheet(c, '원정', '4단계'), height: .35);
            case 3:
              showTtcSheet(context, g, (c) => comingSheet(c, '라디오', '4단계'), height: .35);
          }
        }, bottom: pad.bottom),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.g, {required this.top, required this.onSettings});
  final Game g;
  final double top;
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) {
    final S = g.S;
    final shown = [for (final m in mats) if (g.have(m.k) > 0 || baseMats.contains(m.k)) m.k];
    return Container(
      padding: EdgeInsets.fromLTRB(12, top + 8, 12, 8),
      decoration: const BoxDecoration(color: Ttc.leather, boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 12, offset: Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Lv.${S.lv}', style: Ttc.title(15, color: Ttc.glow)),
          const SizedBox(width: 6),
          Text(shelterName[S.lv - 1], style: Ttc.title(17)),
          const SizedBox(width: 10),
          const ResIcon('hope', size: 16),
          Text(' ${g.hope}', style: Ttc.body(14, weight: FontWeight.w700)),
          const Spacer(),
          if (S.buff != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Ttc.amber.withValues(alpha: .25), borderRadius: BorderRadius.circular(99)),
              child: Text('${S.buff!['label'] ?? '효과'} ${((S.buff!['t'] as num?) ?? 0).ceil()}초', style: Ttc.body(12, color: Ttc.glow, weight: FontWeight.w700)),
            ),
          GestureDetector(onTap: onSettings, child: const Icon(Icons.settings_outlined, color: Ttc.paper, size: 22)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 10, runSpacing: 4, children: [
          for (final k in shown)
            Row(mainAxisSize: MainAxisSize.min, children: [
              ResIcon(k, size: 18),
              const SizedBox(width: 2),
              Text(fmt(g.have(k)),
                  style: Ttc.body(13.5, color: g.have(k) >= g.capOf(k) ? Ttc.amber : Ttc.paper, weight: FontWeight.w700)),
            ]),
        ]),
        if (g.hungry) Text('식량이 떨어졌어요! 생산이 절반으로 줄어요', style: Ttc.body(12, color: const Color(0xFFFF9A7A), weight: FontWeight.w700)),
      ]),
    );
  }
}

class _Lamp extends StatelessWidget {
  const _Lamp(this.g);
  final Game g;
  @override
  Widget build(BuildContext context) {
    final fev = g.fever > 0;
    final p = fev ? g.fever / g.feverT : g.combo / g.comboMax;
    final label = fev ? '피버!' : g.combo > 0 ? '연타 ${g.combo.floor()}' : '두드리기';
    return SizedBox(
      width: 92,
      height: 108,
      child: Column(children: [
        SizedBox(
          width: 86,
          height: 86,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fev ? const Color(0xFF6B3A12) : const Color(0xE63A2618),
                boxShadow: [BoxShadow(color: (fev ? Ttc.amber : Colors.black).withValues(alpha: fev ? .6 : .5), blurRadius: fev ? 22 : 10)],
                border: Border.all(color: Ttc.paper.withValues(alpha: .3), width: 1.5),
              ),
            ),
            const AtlasThumb('shelters.webp', 5, 3, 2, size: 48),
            CustomPaint(size: const Size(86, 86), painter: RingPainter(p.clamp(0, 1).toDouble(), fev ? Ttc.glow : Ttc.amber)),
          ]),
        ),
        Text(label, style: Ttc.body(13, color: Ttc.glow, weight: FontWeight.w700, shadow: true)),
      ]),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xE63A2618), border: Border.all(color: Ttc.paper.withValues(alpha: .3), width: 1.5)),
          child: Icon(icon, size: 19, color: Ttc.paper),
        ),
      );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.onTap, required this.bottom});
  final void Function(int) onTap;
  final double bottom;
  static const items = [(Icons.people_alt_outlined, '생존자'), (Icons.explore_outlined, '원정'), (Icons.cottage_outlined, '쉘터'), (Icons.radio_outlined, '라디오'), (Icons.menu_book_outlined, '일지')];
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.only(bottom: math.max(6, bottom), top: 6),
        color: Ttc.leather,
        child: Row(children: [
          for (var k = 0; k < items.length; k++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(k),
                child: Column(children: [
                  Icon(items[k].$1, color: k == 2 ? Ttc.glow : Ttc.paper, size: 24),
                  const SizedBox(height: 2),
                  Text(items[k].$2, style: Ttc.body(11.5, color: k == 2 ? Ttc.glow : Ttc.paper, weight: FontWeight.w600)),
                ]),
              ),
            ),
        ]),
      );
}
