// 게임 화면. 배치·치수·색은 웹 버전(header / #tape / #stage / #lamp / .tabs / #sheet)을 그대로 따른다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../game/data.dart';
import '../game/engine.dart';
import '../game/storage.dart';
import 'icons.dart';
import 'map_view.dart';
import 'sheets.dart';
import 'theme.dart';
import 'ring.dart';
import 'survivors.dart';
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
  SheetSpec? sheet;
  bool matsOpen = false;
  bool camOpen = false;

  Game get g => widget.game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fxc.onFx = _onFx;
    _start();
    WidgetsBinding.instance.addPostFrameCallback((_) => fxc.pull(g));
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
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden || s == AppLifecycleState.detached) {
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
      case FxCamp(:final tile):
        showCampPage(context, g, tile);
      case FxRescue(:final id, :final via):
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) showRescuePage(context, g, id, via);
        });
      case FxLevelUp(:final lv):
        HapticFeedback.mediumImpact();
        _stamp(lv);
      case FxOffline(:final seconds, :final got):
        final h = seconds ~/ 3600, m = (seconds % 3600 / 60).round();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          showPage(context,
              tag: '돌아오셨군요',
              title: '${h > 0 ? '$h시간 ' : ''}$m분 동안',
              body: '모인 자재 · ${got.entries.map((e) => '${matOf[e.key]!.n} +${e.value}').join(' · ')}',
              button: '좋아요');
        });
      default:
        break;
    }
  }

  String? _stampText;
  void _stamp(int lv) {
    setState(() => _stampText = 'Lv.$lv\n${shelterName[lv - 1]}');
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) setState(() => _stampText = null);
    });
  }

  // 랜턴 버튼: 누르면 한 번, 누르고 있으면 계속 (웹 lampRepeat)
  void _lampPress() {
    _close();
    setState(() => _lampDown = true);
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
    if (_lampDown && mounted) setState(() => _lampDown = false);
    _lampDown = false;
    _lampHold?.cancel();
  }

  /// 조준한 칸이 화면 가장자리로 나가면 카메라를 끌어 온다
  Size _stageSize = Size.zero;
  void _follow() {
    if (g.aim < 0 || _stageSize == Size.zero) return;
    final w = tileC(g.aim, 12);
    final sx = (w.dx - cam.x) * cam.z + _stageSize.width / 2, sy = (w.dy - cam.y) * cam.z + _stageSize.height / 2;
    if (sx < 70 || sx > _stageSize.width - 70 || sy < 90 || sy > _stageSize.height - 160) {
      cam.set(cam.x + (w.dx - cam.x) * .35, cam.y + (w.dy - cam.y) * .35);
    }
  }

  void _open(SheetSpec s) => setState(() {
        sheet = sheet == s ? null : s;
        matsOpen = false;
        _closeRing();
      });

  // 둥근 빠른 메뉴 (웹 ring)
  int ringTile = -1;
  String ringSay = '';
  int _ringClosedAt = -1;
  void _closeRing() {
    ringTile = -1;
    g.sel = -1;
  }

  void _openRing(int tile) {
    final m = g.modAtTile(tile);
    final says = m == null ? null : modSay[m.id];
    setState(() {
      sheet = null;
      matsOpen = false;
      ringTile = tile;
      g.sel = tile;
      ringSay = says == null || says.isEmpty ? '' : says[DateTime.now().millisecond % says.length];
    });
    g.mapVersion.value++;
  }

  void _close() {
    _ringClosedAt = ringTile;
    if (sheet != null || matsOpen || ringTile >= 0) {
      setState(() {
        sheet = null;
        matsOpen = false;
        _closeRing();
      });
      g.mapVersion.value++;
    }
  }

  void _select(String kind, int tile) {
    switch (kind) {
      case 'shelter':
        _open(const SheetSpec('shelter'));
      case 'module':
      case 'landmark':
        if (_ringClosedAt == tile) {
          _ringClosedAt = -1; // 같은 건물을 다시 누르면 닫기만
        } else {
          _openRing(tile);
        }
    }
  }

  void _flyTo(int tile) {
    final w = tileC(tile);
    setState(() => sheet = null);
    cam.set(w.dx, w.dy);
  }

  void _reset() {
    g.replaceState(Game.fresh());
    cam.set(0, (CX + CY + 1) * TH / 2 - 10);
    Storage.save(g.toJsonString());
    setState(() => sheet = null);
    fxc.toast('새 땅에서 다시 시작해요');
  }

  /// 아직 이야기(5단계)를 옮기기 전이라, 띠에는 쉘터를 키우는 다음 할 일을 보여 준다
  (String, String, double) _goal() {
    final S = g.S;
    if (S.lv >= 5) return ('끝없는 성장', '지도를 더 밝히고 랜드마크를 복구해요', 1);
    final need = shupNeed[S.lv - 1], n = S.mods.length;
    final p = (n / need).clamp(0, 1).toDouble();
    if (g.wbL == 0) return ('Lv.${S.lv + 1}까지', '작업대 짓기', p);
    if (n < need) return ('Lv.${S.lv + 1}까지', '모듈 짓기 $n/$need', p);
    return ('Lv.${S.lv + 1}까지', '${jo(shelterName[S.lv], '으로', '로')} 증축하기', p);
  }

  Widget _sheetFor(SheetSpec s) {
    switch (s.kind) {
      case 'shelter':
        return SheetPanel(icon: Ico.shelter, title: 'Lv.${g.S.lv} ${shelterName[g.S.lv - 1]}', onClose: _close, child: ShelterBody(g));
      case 'module':
        final slot = g.modAt[s.tile];
        final m = slot == null ? null : g.S.mods[slot];
        return SheetPanel(icon: Ico.shelter, title: m == null ? '모듈' : '${mods[m.id]!.n} ${m.l + 1}/3단계', onClose: _close, child: moduleBody(g, s.tile));
      case 'landmark':
        final l = g.S.lm[s.tile];
        return SheetPanel(icon: Ico.home, title: l == null ? '랜드마크' : lmText(l.k, g.S.region)[0], onClose: _close, child: landmarkBody(g, s.tile));
      case 'camp':
        return SheetPanel(icon: Ico.surv, title: '구조 캠프', onClose: _close, child: campBody(g, s.tile));
      case 'diary':
        return SheetPanel(icon: Ico.diary, title: '일지', onClose: _close, child: Builder(builder: (c) => diaryBody(c, g)));
      case 'settings':
        return SheetPanel(icon: Ico.gear, title: '설정', onClose: _close, child: SettingsBody(g, onReset: _reset));
      case 'assign':
        return SheetPanel(
            icon: Ico.surv,
            title: '${g.workName(s.tile)}에서 일할 사람',
            onClose: _close,
            child: assignBody(g, s.tile, onDone: () {
              setState(() => sheet = null);
              _openRing(s.tile);
            }));
      case 'surv':
        final n = g.S.sv.length, total = survivors.where((x) => x.src != 'town' || g.S.gen != 0 || g.hasSv(x.id)).length;
        return SheetPanel(icon: Ico.surv, title: '생존자 수첩 $n/$total', onClose: _close, child: SurvBody(g, onOpen: (id) => showSurvPage(context, g, id), onFly: _flyTo));
      case 'exp':
        return SheetPanel(icon: Ico.exp, title: '원정', onClose: _close, child: comingBody('원정', '4단계'));
      default:
        return SheetPanel(icon: Ico.radio, title: '라디오', onClose: _close, child: comingBody('라디오', '4단계'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final bottom = pad.bottom + 10;
    return Scaffold(
      backgroundColor: Ttc.body,
      body: Column(children: [
        AnimatedBuilder(
          animation: g,
          builder: (c, _) => _Header(
            g,
            top: pad.top,
            goal: _goal(),
            onSettings: () => _open(const SheetSpec('settings')),
            onMats: () => setState(() => matsOpen = !matsOpen),
            onShelter: () => _open(const SheetSpec('shelter')),
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            _stageSize = box.biggest;
            return Container(
              color: Ttc.stage,
              child: Stack(clipBehavior: Clip.hardEdge, children: [
                Positioned.fill(child: MapView(game: g, camera: cam, onSelect: _select, fxLayer: fxc, onTouch: _close)),
                // 오른쪽 위: 쉘터로, 카메라 도구
                Positioned(
                  right: 10,
                  top: 12,
                  child: Column(children: [
                    _StageBtn(Ico.home, () => cam.set(0, (CX + CY + 1) * TH / 2 - 10)),
                    const SizedBox(height: 6),
                    _StageBtn(Ico.dots, () => setState(() => camOpen = !camOpen)),
                    if (camOpen) ...[
                      const SizedBox(height: 6),
                      _StageBtn(null, () => cam.set(cam.x, cam.y, cam.z * 1.25), text: '+'),
                      const SizedBox(height: 6),
                      _StageBtn(null, () => cam.set(cam.x, cam.y, cam.z / 1.25), text: '−'),
                    ],
                  ]),
                ),
                // 시트
                Positioned(
                  left: 0,
                  right: 0,
                  top: 11,
                  bottom: bottom + 86,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, a) => SlideTransition(position: Tween(begin: const Offset(0, .08), end: Offset.zero).animate(a), child: FadeTransition(opacity: a, child: child)),
                    child: sheet == null
                        ? const SizedBox.shrink()
                        : KeyedSubtree(key: ValueKey(sheet), child: AnimatedBuilder(animation: g, builder: (c, _) => _sheetFor(sheet!))),
                  ),
                ),
                // 랜턴
                Positioned(
                  left: 8,
                  bottom: bottom,
                  child: Listener(
                    onPointerDown: (_) => _lampPress(),
                    onPointerUp: (_) => _lampStop(),
                    onPointerCancel: (_) => _lampStop(),
                    child: AnimatedBuilder(animation: g, builder: (c, _) => _Lamp(g, down: _lampDown)),
                  ),
                ),
                // 아래 메뉴
                Positioned(
                  left: 94,
                  right: 8,
                  bottom: bottom,
                  child: _Tabs(
                    on: switch (sheet?.kind) {
                      'surv' => 0,
                      'exp' => 1,
                      'shelter' => 2,
                      'radio' => 3,
                      'diary' => 4,
                      _ => -1,
                    },
                    onTap: (k) => _open(SheetSpec(const ['surv', 'exp', 'shelter', 'radio', 'diary'][k])),
                  ),
                ),
                if (ringTile >= 0)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([cam, g]),
                      builder: (c, _) => RingMenu(
                        g: g,
                        cam: cam,
                        tile: ringTile,
                        say: ringSay,
                        toast: fxc.toast,
                        onClose: _close,
                        onAssign: () {
                          final t = ringTile;
                          _open(SheetSpec('assign', tile: t));
                        },
                        onShelter: () => _open(const SheetSpec('shelter')),
                      ),
                    ),
                  ),
                if (matsOpen) Positioned(left: 8, right: 8, top: 4, child: AnimatedBuilder(animation: g, builder: (c, _) => _MatsAll(g))),
                if (_stampText != null) Center(child: _Stamp(_stampText!)),
              ]),
            );
          }),
        ),
      ]),
    );
  }
}

// ======================= 머리 (자원·설정·할 일 띠) =======================
class _Header extends StatelessWidget {
  const _Header(this.g, {required this.top, required this.goal, required this.onSettings, required this.onMats, required this.onShelter});
  final Game g;
  final double top;
  final (String, String, double) goal;
  final VoidCallback onSettings, onMats, onShelter;

  @override
  Widget build(BuildContext context) {
    final S = g.S;
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 8, 8, 0),
      decoration: const BoxDecoration(color: Ttc.header, border: Border(bottom: BorderSide(color: Ttc.line12))),
      child: Column(children: [
        SizedBox(
          height: 45,
          child: Row(children: [
            _HudBtn(child: SvgPicture.string(Ico.profileLamp, width: 34, height: 34), onTap: () {}),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: onMats,
                child: Row(children: [
                  for (var k = 0; k < baseMats.length; k++) ...[
                    if (k > 0) const SizedBox(width: 4),
                    Expanded(child: _MatTile(g, baseMats[k])),
                  ],
                ]),
              ),
            ),
            const SizedBox(width: 6),
            _HudBtn(child: SvgIcon(Ico.gear, size: 18, color: Ttc.hudText), onTap: onSettings),
          ]),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onShelter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(color: Ttc.tape, borderRadius: BorderRadius.circular(8), border: Border.all(color: Ttc.line17, width: .8)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Ttc.lvchip, borderRadius: BorderRadius.circular(7)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('Lv.${S.lv} ${shelterName[S.lv - 1]}', style: Ttc.t(11.5, color: Ttc.lvText, weight: FontWeight.w700, height: 1)),
                  const SizedBox(height: 3),
                  Container(
                    width: 54,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0x2EF5EAD0), borderRadius: BorderRadius.circular(99)),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: goal.$3.clamp(.05, 1).toDouble(),
                      child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), gradient: const LinearGradient(colors: [Color(0xFFC9A24A), Color(0xFFF3A53A)]))),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${goal.$1}  ', style: Ttc.t(11, color: Ttc.glow, weight: FontWeight.w700)),
                    TextSpan(text: goal.$2, style: Ttc.t(13, color: const Color(0xFFF0E7D6), weight: FontWeight.w600)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('▾', style: Ttc.t(12, color: const Color(0xFFC7CEC9))),
              const SizedBox(width: 4),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _HudBtn extends StatelessWidget {
  const _HudBtn({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Ttc.line17, width: .8)),
          child: child,
        ),
      );
}

class _MatTile extends StatelessWidget {
  const _MatTile(this.g, this.k);
  final Game g;
  final String k;
  @override
  Widget build(BuildContext context) {
    final v = g.have(k), zero = v <= 0, full = v >= g.capOf(k);
    return Opacity(
      opacity: zero ? .7 : 1,
      child: Container(
        height: 45,
        padding: const EdgeInsets.fromLTRB(2, 3, 2, 4),
        decoration: BoxDecoration(
          color: const Color(0x0BEEE5D3),
          borderRadius: BorderRadius.circular(6),
          border: full ? const Border(bottom: BorderSide(color: Ttc.amber, width: 2)) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ResIcon(k, size: 23, dim: zero),
          const SizedBox(height: 1),
          Text(fmt(v), style: Ttc.t(12, color: Ttc.matText, weight: FontWeight.w700, height: 1.2)),
        ]),
      ),
    );
  }
}

/// 자재 전체 보기 (웹 #matsAll)
class _MatsAll extends StatelessWidget {
  const _MatsAll(this.g);
  final Game g;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Ttc.header,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Ttc.line25),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 26, offset: Offset(0, 12))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Wrap(runSpacing: 6, children: [
            for (final m in mats)
              FractionallySizedBox(
                widthFactor: .5,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ResIcon(m.k, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(text: '${m.n} '),
                        TextSpan(text: fmt(g.have(m.k)), style: const TextStyle(fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
                        if (m.tier < 3) TextSpan(text: '/${fmt(g.capOf(m.k))}', style: const TextStyle(color: Color(0xFFB8A27C))),
                      ]), style: Ttc.t(12.5)),
                      Text(m.s2, style: Ttc.t(11, color: const Color(0xFFB8A27C))),
                    ]),
                  ),
                ]),
              ),
          ]),
          const SizedBox(height: 8),
          Container(height: .8, color: Ttc.line20),
          const SizedBox(height: 6),
          Text('기본 자재와 철판·밧줄은 창고 한도 ${fmt(g.cap)}, 전선·약품은 그 1/4까지 모여요. 창고 모듈과 쉘터 증축으로 늘려요. 건전지는 한도가 없어요.',
              style: Ttc.t(11, color: const Color(0xFFB8A27C), height: 1.5)),
        ]),
      );
}

// ======================= 지도 위 버튼 =======================
class _StageBtn extends StatelessWidget {
  const _StageBtn(this.svg, this.onTap, {this.text});
  final String? svg;
  final String? text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Ttc.btn, borderRadius: BorderRadius.circular(13), border: Border.all(color: Ttc.line25, width: .8)),
          child: svg != null ? SvgIcon(svg!, size: 18, color: Ttc.hudText) : Text(text!, style: Ttc.t(18, weight: FontWeight.w700, height: 1)),
        ),
      );
}

class _Lamp extends StatelessWidget {
  const _Lamp(this.g, {required this.down});
  final Game g;
  final bool down;
  @override
  Widget build(BuildContext context) {
    final fev = g.fever > 0;
    final p = fev ? g.fever / g.feverT : g.combo / g.comboMax;
    final flame = .7 + (fev ? 1 : g.combo / g.comboMax) * .8;
    final label = fev ? '피버!' : g.combo > 0 ? '연타 ${g.combo.floor()}' : '두드리기';
    return Transform.translate(
      offset: Offset(0, down ? 2 : 0),
      child: Container(
        width: 76,
        height: 82,
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
        decoration: BoxDecoration(
          color: Ttc.amber,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0C77F), width: .8),
          boxShadow: [BoxShadow(color: const Color(0xFF775933), offset: Offset(0, down ? 1 : 3))],
        ),
        child: Column(children: [
          SvgPicture.string(Ico.lamp(p, flame), width: 56, height: 56),
          Text(label, style: Ttc.t(12, color: const Color(0xFF252E36), weight: FontWeight.w700, height: 1.2)),
        ]),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.on, required this.onTap});
  final int on;
  final void Function(int) onTap;
  static const items = [(Ico.surv, '생존자'), (Ico.exp, '원정'), (Ico.shelter, '쉘터'), (Ico.radio, '라디오'), (Ico.diary, '일지')];
  @override
  Widget build(BuildContext context) => Container(
        height: 78,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Ttc.header, borderRadius: BorderRadius.circular(12), border: Border.all(color: Ttc.line20, width: .8)),
        child: Row(children: [
          for (var k = 0; k < items.length; k++) ...[
            if (k > 0) const SizedBox(width: 1),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(k),
                child: Container(
                  decoration: BoxDecoration(
                    color: k == on ? Ttc.tabOn : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: k == on ? const Border(bottom: BorderSide(color: Ttc.tabOnLine, width: 2)) : null,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SvgIcon(items[k].$1, size: 22, color: k == on ? Ttc.tabOnText : Ttc.tabText),
                    const SizedBox(height: 5),
                    Text(items[k].$2, style: Ttc.t(10, color: k == on ? Ttc.tabOnText : Ttc.tabText, weight: FontWeight.w500, height: 1)),
                  ]),
                ),
              ),
            ),
          ],
        ]),
      );
}

class _Stamp extends StatelessWidget {
  const _Stamp(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Transform.rotate(
          angle: -.08,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xEBE7E4DC), border: Border.all(color: Ttc.rust, width: 3), borderRadius: BorderRadius.circular(10)),
            child: Text(text, textAlign: TextAlign.center, style: Ttc.t(24, color: Ttc.rust, weight: FontWeight.w700, height: 1.2)),
          ),
        ),
      );
}
