// 게임 화면. 배치·치수·색은 웹 버전(header / #tape / #stage / #lamp / .tabs / #sheet)을 그대로 따른다.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/web_data.g.dart' as web;
import '../game/data.dart';
import '../game/engine.dart';
import '../game/state.dart';
import '../game/storage.dart';
import 'atlas.dart';
import 'crisis_ui.dart';
import 'gear.dart';
import 'icons.dart';
import 'life_ui.dart';
import 'map_view.dart';
import 'outside_ui.dart';
import 'season_ui.dart';
import 'sheets.dart';
import 'profile_ui.dart';
import 'sound.dart';
import 'story_ui.dart';
import 'region_ui.dart';
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
  String? placing; // 놓으려는 장식
  bool camOpen = false;

  Game get g => widget.game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fxc.onFx = _onFx;
    Atlas.onTint = () => g.mapVersion.value++;
    onTalkLine = _endingLine;
    Game.onSfx = (k, b) {
      Sound.sfx(k);
      if (b) Sound.buzz();
    };
    _start();
    WidgetsBinding.instance.addPostFrameCallback((_) => fxc.pull(g));
  }

  void _start() {
    _clock?.cancel();
    // 게임 시간은 0.25초마다 한 번. 화면은 바뀐 게 있을 때만 다시 그린다.
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      g.uiModal = pageWatch.n > 0 || _pageQ.isNotEmpty;
      g.uiSheet = sheet != null;
      final changed = g.tick(.25);
      _storyUi();
      Sound.mood(_mood());
      Atlas.region = g.S.gen != 0 ? g.S.region : null;
      Sound.duck(pageWatch.n > 0 || g.dread);
      if (g.fx.isNotEmpty) fxc.pull(g);
      if (changed) g.poke();
      if (++_saveAcc >= 40) {
        _saveAcc = 0;
        _save();
      }
    });
  }

  /// 엔딩 대사마다 소리 (웹 endingLine 5874)
  int _endOffUntil = 0;
  void _endingLine(String t) {
    if (_endMood == null) return;
    if (t == '03:11. 노래가 뚝 끊겼다.') {
      _endMood = 'off';
      Sound.blackout(4);
    } else if (t == '딸깍.') {
      Timer(const Duration(milliseconds: 350), () => Sound.sfx('click'));
    } else if (t.startsWith('노래는 다시 이어지지')) {
      Sound.sfx('static');
    } else if (t == '셋. 하나. 하나.') {
      for (final d in const [0, 260, 520, 1500, 2400]) {
        Timer(Duration(milliseconds: d), () => Sound.sfx('ui'));
      }
    } else if (t.startsWith('바람에 흔들리는')) {
      _endOffUntil = DateTime.now().millisecondsSinceEpoch + 3000;
    }
  }

  /// 지금 흐를 배경음 (웹 musicMood 5922)
  int _mournUntil = 0;
  String? _endMood;
  String _mood() {
    if (DateTime.now().millisecondsSinceEpoch < _mournUntil) return 'off';
    if (_endCard || DateTime.now().millisecondsSinceEpoch < _endOffUntil) return 'off';
    if (_endMood != null) return _endMood!;
    final U = g.tut;
    if (U != null) {
      final i = ((U['i'] as num?) ?? 0).toInt();
      if (i < 2) return 'tut';
      if (i == 2) return U['radio'] == 1 ? 'off' : 'air';
      return 'storm';
    }
    if (g.ug != null) return 'under';
    if (g.defn != null) return 'storm';
    if (g.isNight) return g.S.rest['airTonight'] == g.num_('nightCount').toInt() && g.hasSv(10) ? 'air' : 'night';
    return 'day';
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
      Sound.pauseAll(true);
      g.dirty = true;
      _save();
    } else if (s == AppLifecycleState.resumed && _clock == null) {
      g.offline(DateTime.now().millisecondsSinceEpoch);
      fxc.pull(g);
      g.poke();
      _start();
      Sound.pauseAll(false);
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
      case FxDefense(:final start):
        if (start) {
          setState(() {
            sheet = null;
            _closeRing();
          });
          _frameDefense();
        }
      case FxKidGrown(:final n):
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) showKidGrown(context, g, n);
        });
      case FxPetNew(:final k):
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) showPetName(context, g, k, true);
        });
      case FxExpBack():
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) showExpBack(context, g, f);
        });
      case FxEventDone(:final ev, :final k, :final sum):
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) showRequestDone(context, g, ev, k, sum);
        });
      case FxTalk():
        _pageQ.add(() {
          if (f.after == 'endCard') _endMood = 'air';
          return showTalk(context, g, f, onDone: () {
            if (f.goal != null) g.panGuide = DateTime.now().millisecondsSinceEpoch;
            if (f.after == 'endCard') {
              _endMood = null;
              setState(() => _endCard = true);
            }
          });
        });
        _pumpPages();
      case FxCase(:final k):
        _pageQ.add(() {
          Sound.sfx('mystery');
          return showCase(context, g, k);
        });
        _pumpPages();
      case FxCrowMeet():
        _pageQ.add(() {
          Sound.sfx('mystery');
          return showCrowMeet(context, g);
        });
        _pumpPages();
      case FxTutDone(:final replay):
        _tutDone(replay);
      case FxOnboard():
        _pageQ.add(() => showOnboard(context, g, onTour: () => setState(() => _coach = 0)));
        _pumpPages();
      case FxConf():
        _pageQ.add(() => showConf(context, g));
        _pumpPages();
      case FxPfName():
        _pageQ.add(() => showPfName(context, g, first: true));
        _pumpPages();
      case FxBlackout(:final sec):
        Sound.blackout(sec);
      case FxTownChoice():
        _pageQ.add(() => showTownChoice(context, g));
        _pumpPages();
      case FxDeath():
        // 폭풍이 걷히고 잠시 뒤 (웹 setTimeout 2200)
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (!mounted) return;
          setState(() {
            sheet = null;
            _closeRing();
          });
          _pageQ.insert(0, () async {
            _mournUntil = DateTime.now().millisecondsSinceEpoch + 3600000;
            Sound.sfx('toll');
            await showDeath(context, g, f);
            Sound.sfx('chime');
            _mournUntil = DateTime.now().millisecondsSinceEpoch + 1500;
          });
          _pumpPages();
        });
      case FxMigrated(g: final n, :final region):
        setState(() {
          sheet = null;
          _closeRing();
          _mig = (n, region);
        });
        cam.set(0, (CX + CY + 1) * TH / 2 - 10);
      case FxLevelUp(:final lv):
        Sound.buzzMid();
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

  // ---------- 화면 둘러보기 (웹 onbTour): 가리킬 곳 ----------
  static final _kMats = GlobalKey(), _kTape = GlobalKey(), _kClock = GlobalKey(), _kLamp = GlobalKey(), _kTabs = GlobalKey();
  int _coach = -1;
  bool _endCard = false;
  (int, String)? _mig;
  Rect? _coachRect() {
    final k = [_kMats, _kTape, _kClock, _kLamp, _kTabs][_coach];
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _coachNext() => setState(() {
        _coach++;
        if (_coach >= coachSteps.length) _coachEnd();
      });
  void _coachEnd() {
    _coach = -1;
    g.onbEnd();
  }

  /// 튜토리얼 다시 보기: 지금 저장을 옆에 두고 새 지도에서 (웹 startTut(true))
  Future<void> _tutReplay() async {
    await Storage.setRaw('ttc_tut_bak', g.toJsonString());
    if (!mounted) return;
    setState(() => sheet = null);
    g.replaceState(Game.fresh());
    g.startTut(replay: true);
    cam.set(0, (CX + CY + 1) * TH / 2 - 10);
    fxc.pull(g);
  }

  Future<void> _tutDone(bool replay) async {
    await Storage.setRaw('ttc_tut', '1');
    if (replay) {
      final bak = await Storage.getRaw('ttc_tut_bak');
      await Storage.setRaw('ttc_tut_bak', null);
      if (bak != null) {
        try {
          final s = GameState.fromJson(jsonDecode(bak) as Map<String, dynamic>);
          if (s != null) {
            s.rest['tutSeen'] = 1;
            g.replaceState(s);
            fxc.toast('원래 쉘터로 돌아왔어요');
          }
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() => sheet = null);
    cam.set(0, (CX + CY + 1) * TH / 2 - 10);
    g.dirty = true;
    _save();
  }

  // ---------- 이야기 창 줄 세우기 (웹 mq: 창은 한 번에 하나) ----------
  final List<Future<void> Function()> _pageQ = [];
  bool _paging = false;
  void _pumpPages() {
    if (_paging || _pageQ.isEmpty || pageWatch.n > 0 || !mounted) return;
    _paging = true;
    final open = _pageQ.removeAt(0);
    Future.delayed(const Duration(milliseconds: 150), () async {
      if (!mounted) return;
      await open();
      _paging = false;
      fxc.pull(g);
      _pumpPages();
    });
  }

  /// 매 0.25초: 길잡이 강조 키·화살표, 창 줄
  int _claimPing = 0;
  GuideTarget? _guide;
  void _storyUi() {
    if (g.tutCloseSheet) {
      g.tutCloseSheet = false;
      if (sheet != null) setState(() => sheet = null);
    }
    _pumpPages();
    final m = g.mission(), st = m.step;
    String? k;
    if (m.done) {
      k = 'claim';
    } else if (st != null && st.hl != null) {
      k = hlOf(st.hl);
      if (sheet?.kind == 'shelter' && k != null && (k.startsWith('mbuild') || k == 'shup' || k == 'wall' || k == 'tower' || k == 'craft:0')) {
        final want = k == 'craft:0' ? 1 : 0;
        if (ShelterBody.tab != want) k = 'seg:$want';
      }
    }
    if (hlKey.value != k) hlKey.value = k;
    final tg = sheet != null || ringTile >= 0 || pageWatch.n > 0 || g.defn != null ? null : guideTarget(g);
    if ((tg == null) != (_guide == null) || tg?.el != _guide?.el || tg?.tile != _guide?.tile || tg?.label != _guide?.label) setState(() => _guide = tg);
    // 새 목표를 알린 직후 3초 동안은 카메라를 그쪽으로 천천히 끌어 온다 (웹 updateGuide panGuide)
    if (tg != null && tg.tile >= 0 && g.panGuide > 0 && _stageSize != Size.zero) {
      if (DateTime.now().millisecondsSinceEpoch - g.panGuide < 3000) {
        final w = tileC(tg.tile, tg.z);
        final sx = (w.dx - cam.x) * cam.z, sy = (w.dy - cam.y) * cam.z;
        if (sx.abs() > _stageSize.width * .18 || sy.abs() > _stageSize.height * .15) {
          cam.set(cam.x + (w.dx - cam.x) * .3, cam.y + (w.dy + 20 - cam.y) * .3);
        } else {
          g.panGuide = 0;
        }
      } else {
        g.panGuide = 0;
      }
    }
  }

  /// 미션 띠를 누르면 할 일 쪽으로 데려간다 (웹 goMission 4449)
  void _goMission() {
    if (pageWatch.n > 0 || g.defn != null) return;
    final m = g.mission();
    if (m.done) {
      setState(() => _claimPing++);
      return;
    }
    final st = m.step, f = st?.focus, hlS = st?.hl ?? '';
    void hint() {
      if (m.sub.isNotEmpty) fxc.toast(m.sub);
    }

    void toShelter(int tab) {
      ShelterBody.tab = tab;
      setState(() {
        sheet = const SheetSpec('shelter');
        matsOpen = false;
        _closeRing();
      });
    }

    if (st == null && m.reg) {
      switch (m.rk) {
        case 'spot':
          final si = (g.rq['spotI'] as num?)?.toInt() ?? -1;
          if (si >= 0) {
            _close();
            _flyTo(si);
            fxc.toast('${(web.regionMisc['spotIco'] as Map)[g.S.region] ?? ''} 표시 쪽 구름을 걷어요');
          }
        case 'op':
          showOp(context, g);
        case 'choice':
          showTownChoice(context, g);
        case 'raid':
          fxc.toast('밤이 오면 물 도둑이 몰려와요');
        case 'cold':
          toShelter(1);
        default:
          if (RegExp('쉘터|요새|도시|탑').hasMatch(m.txt)) {
            toShelter(0);
          } else if (m.txt.contains('재폭풍')) {
            _close();
            hint();
          } else {
            _close();
            if (g.aim >= 0) _flyTo(g.aim);
            hint();
          }
      }
      return;
    }
    if (st == null) {
      switch (g.egGo) {
        case 'radio':
          _open(const SheetSpec('radio'));
        case 'build':
          toShelter(0);
        case 'craft':
          toShelter(1);
        case 'exp':
          _open(const SheetSpec('exp'));
        case 'surv':
          _open(const SheetSpec('surv'));
        case 'clock':
          fxc.toast(g.bigPeriod == 2 ? '이 동네의 대형 재폭풍은 두 밤마다 와요' : '대형 재폭풍은 세 번째 밤마다 와요');
        default:
          _close();
          if (g.aim >= 0) _flyTo(g.aim);
      }
      return;
    }
    switch (f) {
      case 'center':
        toShelter(hlS.contains('craft') || hlS.contains('data-cb') ? 1 : 0);
        return;
      case 'fExp':
        _open(const SheetSpec('exp'));
        return;
      case 'conf':
        showConf(context, g);
        return;
      case 'radio':
        _open(const SheetSpec('radio'));
        return;
      case 'fSurv':
        _open(const SheetSpec('surv'));
        return;
    }
    _close();
    switch (f) {
      case 'ev':
        if (g.evCur >= 0) {
          showRequestPage(context, g);
        } else {
          fxc.toast('부탁이 생기면 왼쪽 위에 말풍선이 떠요');
        }
        return;
      case 'clock':
        fxc.toast(g.isNight ? '지금이 밤이에요. 붉은 재를 두드려요' : '밤이 오면 시작돼요. 시계를 봐 두세요');
        return;
      case 'skills':
      case 'lamp':
        if (f == 'lamp' && g.aim >= 0) _flyTo(g.aim);
        hint();
        return;
    }
    final tg = guideTarget(g);
    if (tg != null && tg.tile >= 0) {
      _flyTo(tg.tile);
      if (f == 'module' && g.modAtTile(tg.tile) != null || f == 'lm' && g.S.rev[tg.tile] == 1) {
        Future.delayed(const Duration(milliseconds: 560), () {
          if (mounted) _openRing(tg.tile);
        });
      }
    }
    hint();
  }

  /// 길잡이 화살표가 가리킬 화면 위치 (무대 좌표)
  Offset? _guidePos(GuideTarget tg, double bottom) {
    final W0 = _stageSize.width, H0 = _stageSize.height;
    switch (tg.el) {
      case 'lamp':
        return Offset(8 + 38, H0 - bottom - 82 - 2);
      case 'fExp':
      case 'radio':
      case 'fSurv':
        final k = const {'fSurv': 0, 'fExp': 1, 'radio': 3}[tg.el]!;
        return Offset(94 + (W0 - 102) * (k + .5) / 5, H0 - bottom - 78 - 2);
      case 'clock':
        return const Offset(60, 10);
      case 'ev':
        return Offset(34, (g.sq != null && g.sqOn ? 122 : 50) - 2.0);
      case 'skills':
        return Offset(94 + 28, H0 - bottom - 84 - 60);
    }
    final w = tileC(tg.tile, tg.z);
    return Offset((w.dx - cam.x) * cam.z + W0 / 2, (w.dy - cam.y) * cam.z + H0 / 2 - 10);
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
    Sound.tick();
    g.digAim();
    _follow();
    fxc.pull(g);
    g.poke();
    _lampHold?.cancel();
    _lampHold = Timer(const Duration(milliseconds: 300), _lampRepeat);
  }

  void _lampRepeat() {
    if (!_lampDown) return;
    if (g.defn == null && g.urgentAsh < 0 && g.S.rev.fold<int>(0, (a, v) => a + v) - _lampR0 >= holdMax) {
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
        if (s.kind == 'shelter' && g.tut != null) g.tutSheet = 1;
        if (s.kind == 'radio' && sheet != s) eggRadio(context, g);
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
      case 'person':
        _survPage(tile);
      case 'pet':
        showPetPage(context, g, petKeys[tile]);
      case 'stray':
        showStrayPage(context, g);
      case 'band':
        showBandPage(context, g);
      case 'deco':
        showDecoTile(context, g, tile);
      case 'module':
      case 'landmark':
        if (_ringClosedAt == tile) {
          _ringClosedAt = -1; // 같은 건물을 다시 누르면 닫기만
        } else {
          _openRing(tile);
        }
    }
  }

  /// 대형 재폭풍: 쉘터를 화면 아래쪽에 두고, 괴물이 나오는 타원을 화면 크기에 맞춘다 (웹 frameDefense)
  void _frameDefense() {
    final D2 = g.defn;
    if (D2 == null || _stageSize == Size.zero) return;
    final cw = _stageSize.width, ch = _stageSize.height, c = tileC(C0);
    final z = math.min(1.15, math.max(.85, cw / 360)).clamp(.45, 3.2).toDouble();
    cam.z = z;
    cam.set(c.dx, c.dy - (ch * .58 - ch / 2) / z);
    D2.rx = (cw / 2 - 22) / z;
    D2.ry = math.min(ch * .58 - 190, ch * .42 - 120) / z;
    D2.up = (ch * .58 - 200) / z;
  }

  void _sqGo() {
    final q = g.sq;
    if (q == null) return;
    if (g.sqDone) {
      Sound.buzzMid();
      g.claimSq();
      fxc.pull(g);
      return;
    }
    if (DateTime.now().millisecondsSinceEpoch >= g.sqOpenUntil) {
      g.sqOpenUntil = DateTime.now().millisecondsSinceEpoch + 7000;
      g.poke();
      return;
    }
    final who = (q['who'] as num?)?.toInt() ?? -1;
    fxc.toast('${g.hasSv(who) ? '${survivors[who].name}: ' : ''}${(q['say'] as String? ?? '').replaceAll(RegExp(r'^“|”$'), '')}');
    switch (sqTypes[q['k']]?.go) {
      case 'craft':
        ShelterBody.tab = 1;
        _open(const SheetSpec('shelter'));
      case 'fExp':
        _open(const SheetSpec('exp'));
      case 'radio':
        _open(const SheetSpec('radio'));
      case 'ev':
        if (g.evCur >= 0) showRequestPage(context, g);
      default:
        break;
    }
  }

  void _survPage(int id) => showSurvPage(context, g, id, onGear: (id, slot) => _open(SheetSpec('gear', arg: '$id:$slot')));

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

  Widget _sheetFor(SheetSpec s) {
    switch (s.kind) {
      case 'shelter':
        return SheetPanel(
            icon: Ico.shelter,
            title: 'Lv.${g.S.lv} ${shelterName[g.S.lv - 1]}',
            onClose: _close,
            child: ShelterBody(g, onDeco: (k) {
              setState(() {
                sheet = null;
                placing = k;
              });
              g.placingDeco = k;
              g.mapVersion.value++;
            }));
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
        return SheetPanel(icon: Ico.diary, title: '일지', onClose: _close, child: DiaryBody(g));
      case 'profile':
        return SheetPanel(icon: Ico.surv, title: '내 프로필', onClose: _close, child: ProfileBody(g));
      case 'settings':
        return SheetPanel(icon: Ico.gear, title: '설정', onClose: _close, child: SettingsBody(g, onReset: _reset, onTut: _tutReplay));
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
        return SheetPanel(
            icon: Ico.surv,
            title: '생존자 수첩 $n/$total',
            onClose: _close,
            child: SurvBody(g,
                onOpen: _survPage,
                onFly: _flyTo,
                onBag: () => _open(const SheetSpec('gear')),
                onRadio: () => _open(const SheetSpec('radio')),
                onPets: () => _open(const SheetSpec('pets')),
                toast: fxc.toast));
      case 'pets':
        return SheetPanel(
            icon: Ico.surv,
            title: '펫',
            onClose: _close,
            child: PetsBody(g, onPet: (k) => showPetPage(context, g, k), onStray: () {
              final st = g.stray;
              if (st != null) _flyTo((st['i'] as num).toInt());
            }));
      case 'party':
        return SheetPanel(icon: Ico.surv, title: '스킬 바에 데려갈 3명', onClose: _close, child: partyBody(g));
      case 'gear':
        final a = s.arg?.split(':');
        final gid = a == null ? null : int.parse(a[0]), gsl = a?[1];
        return SheetPanel(
            icon: Ico.surv,
            title: gid != null ? '${survivors[gid].name} · ${slotName[gsl]}' : '장비 가방 ${g.inv.length}/${Game.bagMax}',
            onClose: _close,
            child: BagBody(g, key: ValueKey(s.arg), id: gid, slot: gsl, toast: fxc.toast, onBack: () {
              setState(() => sheet = null);
              if (gid != null) _survPage(gid);
            }));
      case 'exp':
        return SheetPanel(icon: Ico.exp, title: '원정', onClose: _close, child: ExpBody(g, toast: fxc.toast));
      default:
        return SheetPanel(icon: Ico.radio, title: '주파수 탐색', onClose: _close, child: RadioBody(g, onRoute: () {
          DiaryBody.tab = 'towns';
          _open(const SheetSpec('diary'));
        }));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final bottom = pad.bottom + 10;
    final coachR = _coach >= 0 ? _coachRect() : null;
    if (_coach >= 0 && coachR == null) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() {}) : null);
    return Scaffold(
      backgroundColor: Ttc.body,
      body: Stack(children: [
        Column(children: [
        AnimatedBuilder(
          animation: g,
          builder: (c, _) => _Header(
            g,
            matsKey: _kMats,
            tapeKey: _kTape,
            top: pad.top,
            ping: _claimPing,
            onGo: _goMission,
            onSettings: () => _open(const SheetSpec('settings')),
            onMats: () => setState(() => matsOpen = !matsOpen),
            onShelter: () => _open(const SheetSpec('shelter')),
            onPed: () {
              _close();
              showPedPage(context, g, fxc.toast);
            },
            onMig: () {
              _close();
              showMigrate(context, g);
            },
            onProfile: () => sheet?.kind == 'profile' ? _close() : _open(const SheetSpec('profile')),
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            _stageSize = box.biggest;
            return Container(
              color: Ttc.stage,
              child: Stack(clipBehavior: Clip.hardEdge, children: [
                Positioned.fill(
                    child: MapView(
                        game: g,
                        camera: cam,
                        onSelect: _select,
                        fxLayer: fxc,
                        onTouch: placing == null ? _close : null,
                        onPlace: placing == null
                            ? null
                            : (i) {
                                if (i < 0 || !g.decoOk(i)) {
                                  fxc.toast('쉘터 둘레의 빈 땅을 눌러요');
                                  return;
                                }
                                if (g.placeDeco(placing!, i)) {
                                  Sound.tick();
                                  fxc.pull(g);
                                  if (!g.canPay(g.decoCost(placing!))) {
                                    setState(() => placing = null);
                                    g.placingDeco = null;
                                  }
                                } else {
                                  fxc.toast('자재가 모자라요');
                                  setState(() => placing = null);
                                  g.placingDeco = null;
                                }
                              })),
                Positioned.fill(child: DreadLayer(g)),
                if (placing != null)
                  Positioned(
                    left: 10,
                    right: 10,
                    top: 56,
                    child: placeBar(g, placing!, () {
                      setState(() => placing = null);
                      g.placingDeco = null;
                      g.mapVersion.value++;
                    }),
                  ),
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
                // 시계 (웹 #clock)
                Positioned(
                  left: 10,
                  top: 12,
                  right: 116,
                  child: Align(alignment: Alignment.centerLeft, child: KeyedSubtree(key: _kClock, child: Every(g: g, builder: (c) => clockChip(g)))),
                ),
                // 대형 재폭풍 막대 · 생존자 의뢰 · 부탁
                Positioned(
                  left: 0,
                  right: 0,
                  top: 56,
                  child: Center(
                    child: SizedBox(
                      width: math.min(350, box.maxWidth - 20),
                      child: Every(g: g, ms: 250, builder: (c) => defenseBar(g)),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 70,
                  child: Every(
                    g: g,
                    builder: (c) => g.defn != null || matsOpen
                        ? const SizedBox.shrink()
                        : DateTime.now().millisecondsSinceEpoch >= g.sqOpenUntil && !g.sqDone
                            ? sideQuest(g, onTap: _sqGo)
                            : SizedBox(width: math.min(300, box.maxWidth - 84), child: sideQuest(g, onTap: _sqGo)),
                  ),
                ),
                // (Stack 크기가 0이 되지 않게, 위치가 바뀌는 부탁 버튼은 자기 Stack 안에 둔다)
                Positioned.fill(
                  child: Every(
                    g: g,
                    builder: (c) => Stack(children: [
                      if (g.defn == null && !matsOpen && g.evCur >= 0)
                        Positioned(
                          left: 12,
                          right: 72,
                          top: g.sq != null && g.sqOn ? 122 : 50,
                          child: Align(alignment: Alignment.centerLeft, child: eventButton(g, () => showRequestPage(context, g))),
                        ),
                    ]),
                  ),
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
                // 스킬 바 (시트가 열리면 숨김)
                Positioned(
                  left: 94,
                  bottom: bottom + 84,
                  child: IgnorePointer(
                    ignoring: sheet != null,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: sheet != null ? 0 : 1,
                      child: AnimatedBuilder(
                        animation: g,
                        builder: (c, _) => SkillBar(g, toast: fxc.toast, onEmpty: () {
                          if (g.S.sv.isEmpty) {
                            fxc.toast('구조 신호를 따라가 생존자를 먼저 만나요');
                          } else {
                            _open(const SheetSpec('party'));
                          }
                        }),
                      ),
                    ),
                  ),
                ),
                // 랜턴
                Positioned(
                  left: 8,
                  bottom: bottom,
                  child: Listener(
                    key: _kLamp,
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
                  child: AnimatedBuilder(
                    key: _kTabs,
                    animation: g,
                    builder: (c, _) => _Tabs(
                    dot: g.achReady ? 4 : -1,
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
                ),
                if (_guide != null)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: cam,
                      builder: (c, _) {
                        final tg = _guide!, p0 = _guidePos(tg, bottom);
                        if (p0 == null) return const SizedBox.shrink();
                        var label = tg.label;
                        if (tg.tile >= 0) {
                          final off = p0.dx < 50 || p0.dx > box.maxWidth - 50 || p0.dy < 110 || p0.dy > box.maxHeight - 190;
                          if (off) {
                            final dx = p0.dx - box.maxWidth / 2, dy = p0.dy - box.maxHeight / 2;
                            label += ' ${dx.abs() > dy.abs() * 1.3 ? (dx > 0 ? '→' : '←') : (dy > 0 ? '↓' : '↑')}';
                          }
                        }
                        final x = p0.dx.clamp(40.0, math.max(40.0, box.maxWidth - 40)), y = p0.dy.clamp(40.0, math.max(40.0, box.maxHeight - 8));
                        return Stack(children: [
                          Positioned(left: x.toDouble(), top: y.toDouble(), child: FractionalTranslation(translation: const Offset(-.5, -1), child: GuideArrow(label, x: x.toDouble(), screenW: box.maxWidth))),
                        ]);
                      },
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
                // 튜토리얼 건너뛰기 (웹 #tutSkip)
                Positioned(
                  left: 12,
                  bottom: bottom + 154,
                  child: AnimatedBuilder(
                    animation: g,
                    builder: (c, _) => g.tut == null
                        ? const SizedBox.shrink()
                        : GestureDetector(
                            onTap: () {
                              g.tutEnd = true;
                              g.finishTut();
                              fxc.pull(g);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(color: const Color(0xB814100C), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x80EFE3C4), width: 1.5)),
                              child: Text('건너뛰기', style: Ttc.t(13, color: const Color(0xFFEFE3C4), weight: FontWeight.w600, height: 1)),
                            ),
                          ),
                  ),
                ),
              ]),
            );
          }),
        ),
        ]),
        if (_endCard)
          Positioned.fill(
              child: EndCard(onDone: () {
            g.S.rest['ehEnd'] = 1;
            g.endingOn = false;
            g.dirty = true;
            setState(() => _endCard = false);
          })),
        if (_mig != null) Positioned.fill(child: MigStamp(_mig!.$1, _mig!.$2, key: ValueKey(_mig), onDone: () => setState(() => _mig = null))),
        if (coachR != null) Positioned.fill(child: CoachOverlay(i: _coach, hole: coachR, onNext: _coachNext, onSkip: () => setState(_coachEnd))),
      ]),
    );
  }
}

// ======================= 머리 (자원·설정·할 일 띠) =======================
class _Header extends StatelessWidget {
  const _Header(this.g,
      {required this.top, required this.ping, required this.onGo, required this.onSettings, required this.onMats, required this.onShelter, required this.onPed, required this.onMig, required this.onProfile, this.matsKey, this.tapeKey});
  final Game g;
  final Key? matsKey, tapeKey;
  final double top;
  final int ping;
  final VoidCallback onSettings, onMats, onShelter, onPed, onGo, onMig, onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 8, 8, 0),
      decoration: const BoxDecoration(color: Ttc.header, border: Border(bottom: BorderSide(color: Ttc.line12))),
      child: Column(children: [
        SizedBox(
          height: 45,
          child: Row(children: [
            KeyedSubtree(key: const ValueKey('pfBtn'), child: _HudBtn(child: g.pfSet ? ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 30, height: 38, child: pfPortrait(g.pfIndex()))) : SvgPicture.string(Ico.profileLamp, width: 34, height: 34), onTap: onProfile)),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                key: matsKey,
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
            KeyedSubtree(key: const ValueKey('setBtn'), child: _HudBtn(child: SvgIcon(Ico.gear, size: 18, color: Ttc.hudText), onTap: onSettings)),
          ]),
        ),
        const SizedBox(height: 6),
        KeyedSubtree(key: tapeKey, child: MissionTape(g, onLv: onShelter, onGo: onGo, onPed: onPed, onMig: onMig, ping: ping)),
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
    final label = g.defn != null ? (fev ? '피버! 막기' : '막기') : fev ? '피버!' : g.combo > 0 ? '연타 ${g.combo.floor()}' : '두드리기';
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
  const _Tabs({required this.on, required this.onTap, this.dot = -1});
  final int on, dot;
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
                    Stack(clipBehavior: Clip.none, children: [
                      SvgIcon(items[k].$1, size: 22, color: k == on ? Ttc.tabOnText : Ttc.tabText),
                      if (k == dot)
                        Positioned(
                            right: -5,
                            top: -3,
                            child: Container(
                                width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: Ttc.amber, border: Border.all(color: Ttc.header, width: 1.5)))),
                    ]),
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
