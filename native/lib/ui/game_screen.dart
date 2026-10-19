// 게임 화면. 배치·치수·색은 웹 버전(header / #tape / #stage / #lamp / .tabs / #sheet)을 그대로 따른다.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/web_data.g.dart' as web;
import '../game/data.dart';
import '../game/engine.dart';
import '../game/state.dart';
import '../game/storage.dart';
import '../game/cloud.dart';
import '../legacy/legacy.dart';
import '../legacy/legacy_peek.dart';
import '../report.dart';
import 'atlas.dart';
import 'cloud_ui.dart';
import 'crisis_ui.dart';
import 'cuts_ui.dart';
import 'feat_ui.dart';
import 'gear.dart';
import 'icons.dart';
import 'life_ui.dart';
import 'map_view.dart';
import 'outside_ui.dart';
import 'season_ui.dart';
import 'sheets.dart';
import 'portrait.dart';
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

  /// 클라우드 저장 켜기 (앱에서만. 시험에서는 끈다)
  static bool cloudOn = false;

  /// 이 기기에 저장이 없던 첫 실행 (예전 버전 진행을 찾아본다)
  static bool firstRun = false;

  /// 켤 때 읽은 저장의 마지막 저장 시각 (클라우드가 더 최근인지 견줄 때)
  static int loadedT = 0;
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
    FeatNav.go = _featGo;
    Portrait.sigWorn = g.sigWorn;
    Atlas.onTint = () => g.mapVersion.value++;
    onTalkLine = _endingLine;
    Game.onSfx = (k, b) {
      Sound.sfx(k);
      if (b) Sound.buzz();
    };
    // 처음 켠 새 게임(튜토리얼)이 아니면, 켤 때 몰려오는 큰 창은 둘까지만
    if (!GameScreen.firstRun) _burstStart();
    _start();
    WidgetsBinding.instance.addPostFrameCallback((_) => fxc.pull(g));
    if (GameScreen.cloudOn) Future.delayed(const Duration(seconds: 2), () => mounted ? _cloudStart() : null);
  }


  void _start() {
    _clock?.cancel();
    // 게임 시간은 0.25초마다 한 번. 화면은 바뀐 게 있을 때만 다시 그린다.
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      g.uiModal = pageWatch.n > 0 || _paging || _pageQ.any((x) => !_held(x));
      g.uiSheet = sheet != null;
      final changed = g.tick(.25);
      _burstTick();
      _storyUi();
      Sound.mood(_mood());
      Sound.dim(g.isNight && g.defn == null ? .75 : 1);
      _heartbeat();
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

  /// 대형 재폭풍 밤에는 낮은 심장 소리 (앱 전용). 내구도가 절반 아래면 빨라진다
  int _beatT = 0;
  void _heartbeat() {
    final D = g.defn;
    if (D == null) {
      _beatT = 0;
      return;
    }
    if (++_beatT % (D.hp < D.max * .5 ? 5 : 9) == 0) Sound.sfx('heart');
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

  String? _saved; // 마지막으로 기기에 쓴 저장 (클라우드에는 이걸 올린다)
  void _save() {
    if (!g.dirty) return;
    g.dirty = false;
    _saved = g.toJsonString();
    Storage.save(_saved!);
  }

  // ---------- 클라우드 저장 (웹 cloud.js: 켤 때 맞춰 보고, 45초마다·뒤로 갈 때 올린다) ----------
  Timer? _cloudT;
  Future<void> _cloudUp({bool force = false}) async {
    g.dirty = true;
    _save();
    if (_saved != null) await Cloud.upload(_saved!, force: force);
  }

  bool _cloudStarting = false, _cloudReady = false;
  Future<void> _cloudStart() async {
    if (_cloudStarting || _cloudReady) return;
    _cloudStarting = true;
    try {
      await _cloudStart0();
    } finally {
      _cloudStarting = false;
    }
  }

  Future<void> _cloudStart0() async {
    Report.dev = () => devInfo(g, mounted ? context : null);
    if (!await Cloud.signIn()) return;
    Cloud.busy = true;
    try {
      final c = await Cloud.fetch();
      // 이 기기 저장의 시각은 켤 때 읽어 둔 값 (지금 저장하면 '지금'이 되어 늘 이 기기가 더 최근이 된다)
      final local = jsonEncode(g.S.toJson()), ls = Cloud.summary(local), localT = GameScreen.loadedT;
      if (c != null) {
        Cloud.last = c.at > 0 ? c.at : c.t;
        if (c.data.isNotEmpty && c.t > localT + 3000 && mounted) {
          final yes = await cloudAsk(
              context,
              '클라우드에 더 최근 진행이 있어요',
              '클라우드: Lv.${c.lv}${c.gen > 0 ? ' · ${c.gen + 1}번째 동네' : ''} · ${cloudWhen(c.t)} 저장\n이 기기: Lv.${ls.$2}${ls.$3 > 0 ? ' · ${ls.$3 + 1}번째 동네' : ''}${localT > 0 ? ' · ${cloudWhen(localT)} 저장' : ''}\n\n클라우드 진행을 불러올까요?',
              '불러오기',
              '이 기기 진행 유지');
          if (yes) {
            final s = GameState.fromJson(jsonDecode(c.data) as Map<String, dynamic>);
            if (s != null) {
              await Storage.backup();
              g.replaceState(s);
              cam.set(0, (CX + CY + 1) * TH / 2 - 10);
              g.dirty = true;
              _save();
              fxc.toast('클라우드 진행을 불러왔어요');
            }
          }
        }
      }
    } catch (_) {
      Cloud.msg = '클라우드에 연결하지 못했어요';
    }
    Cloud.busy = false;
    Cloud.version.value++;
    _cloudReady = true;
    await _cloudUp(force: true);
    unawaited(Cloud.flush());
    _cloudT?.cancel();
    _cloudT = Timer.periodic(const Duration(seconds: 45), (_) => _cloudUp());
    await _legacyStart();
  }

  // ---------- 예전 버전에서 진행 옮기기 ----------
  bool _peek = false;
  StreamSubscription<Uri>? _linkSub;

  Future<void> _legacyStart() async {
    if (!kIsWeb) {
      final links = AppLinks();
      _linkSub = links.uriLinkStream.listen(_onLink);
      final first = await links.getInitialLink();
      if (first != null) _onLink(first);
    }
    if (!GameScreen.firstRun || await Storage.getRaw('ttc_legacy_asked') != null) return;
    if (kIsWeb) {
      final raw = await readWebSave();
      if (raw != null) await _offerLegacy(raw, '이 브라우저의 웹 게임');
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (mounted) setState(() => _peek = true);
    }
  }

  void _onLink(Uri u) {
    if (u.scheme != 'taptocity' || u.host != 'import') return;
    final c = u.queryParameters['c'];
    if (c == null || c.isEmpty) return;
    final s = Game.parseCode(c);
    if (s == null) {
      fxc.toast('진행을 읽지 못했어요');
      return;
    }
    _offerLegacy(jsonEncode(s.toJson()), '예전 앱');
  }

  Future<void> _offerLegacy(String raw, String from) async {
    await Storage.setRaw('ttc_legacy_asked', '1');
    GameState? s;
    try {
      s = GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
    if (s == null || !mounted) return;
    final ls = Cloud.summary(raw);
    final ok = await cloudAsk(
        context,
        '$from의 진행을 찾았어요',
        'Lv.${ls.$2}${ls.$3 > 0 ? ' · ${ls.$3 + 1}번째 동네' : ''}${ls.$1 > 0 ? ' · ${cloudWhen(ls.$1)} 저장' : ''}\n\n이 진행으로 이어서 할까요? 지금 이 앱의 진행은 따로 보관해 둬요.',
        '이어서 하기',
        '지금 진행 유지');
    if (!ok || !mounted) return;
    await Storage.backup();
    g.replaceState(s);
    cam.set(0, (CX + CY + 1) * TH / 2 - 10);
    g.dirty = true;
    _save();
    fxc.toast('예전 진행을 불러왔어요');
    if (GameScreen.cloudOn) unawaited(_cloudUp(force: true));
  }

  /// 설정의 '예전 버전에서 진행 가져오기'
  Future<void> _legacyManual() async {
    if (kIsWeb) {
      final raw = await readWebSave();
      if (raw == null) {
        fxc.toast('이 브라우저에는 웹 게임 진행이 없어요');
      } else {
        await _offerLegacy(raw, '이 브라우저의 웹 게임');
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      setState(() => _peek = true);
    } else {
      // 예전 안드로이드 앱은 크롬에 저장했다 → 크롬으로 옮기기 페이지를 열면 taptocity://import 로 돌아온다
      await launchUrl(Uri.parse('https://gogeangs.github.io/taptocity/transfer.html'), mode: LaunchMode.externalApplication);
    }
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
      if (GameScreen.cloudOn) _cloudUp();
    } else if (s == AppLifecycleState.resumed && _clock == null) {
      _burstStart();
      g.offline(DateTime.now().millisecondsSinceEpoch);
      fxc.pull(g);
      g.poke();
      _start();
      Sound.pauseAll(false);
      // 켤 때 클라우드에 못 붙었으면 다시
      if (GameScreen.cloudOn && !_cloudReady) _cloudStart();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _camEase?.cancel();
    _cloudT?.cancel();
    _linkSub?.cancel();
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
        _queue(1, () async {
          // 웹툰 컷 (앱 전용): 이야기 속 사람이 처음 합류할 때 네 칸
          final cut = joinCuts[id];
          if (cut != null) await playCutOnce(context, g, cut, cut, const [0, 1, 2, 3]);
          if (mounted) await showRescuePage(context, g, id, via);
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
        _queue((f.tag ?? '').startsWith('아침 보고') ? 2 : 1, () async {
          // 9장 까마귀 · 대치: 독수리 앞에 선 진 (웹툰 컷 ①② 먼저, 대화 뒤 남기로 한 ③)
          final jin = f.tag == '까마귀 · 대치' && g.hasSv(jinId);
          if (jin) {
            await playCutOnce(context, g, 'join_jin_choice', 'join_jin_choice', const [0, 1]);
            if (!mounted) return;
          }
          if (f.after == 'endCard') _endMood = 'air';
          await showTalk(context, g, f, onDone: () {
            if (f.goal != null) g.panGuide = DateTime.now().millisecondsSinceEpoch;
            if (f.after == 'endCard') {
              _endMood = null;
              setState(() => _endCard = true);
            }
          });
          if (!jin || !mounted) return;
          await playCutOnce(context, g, 'join_jin_choice:3', 'join_jin_choice', const [2]);
        });
      case FxCase(:final k):
        _queue(1, () {
          Sound.sfx('mystery');
          return showCase(context, g, k);
        });
      case FxCrowMeet():
        _queue(1, () {
          Sound.sfx('mystery');
          return showCrowMeet(context, g);
        });
      case FxTutDone(:final replay):
        _tutDone(replay);
      case FxOnboard():
        _queue(1, () => showOnboard(context, g, onTour: () => setState(() => _coach = 0)));
      case FxConf():
        _queue(1, () async {
          // 6장 재혁의 고백: 웹툰 컷 네 칸을 먼저
          await playCutOnce(context, g, 'join_jaehyuk', 'join_jaehyuk', const [0, 1, 2, 3]);
          if (mounted) await showConf(context, g);
        });
      case FxFeat(:final k):
        _queue(3, () => showFeatCard(context, g, k, go: _featGo));
      case FxPfName():
        _queue(1, () => showPfName(context, g, first: true));
      case FxBlackout(:final sec):
        Sound.blackout(sec);
      case FxTownChoice():
        _queue(1, () => showTownChoice(context, g));
      case FxChoice():
        _queue(1, () {
          Sound.sfx('mystery');
          return showChoice(context, g);
        });
      case FxDeath():
        // 폭풍이 걷히고 잠시 뒤 (웹 setTimeout 2200)
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (!mounted) return;
          setState(() {
            sheet = null;
            _closeRing();
          });
          _queue(0, () async {
            _mournUntil = DateTime.now().millisecondsSinceEpoch + 3600000;
            Sound.sfx('toll');
            await showDeath(context, g, f);
            Sound.sfx('chime');
            _mournUntil = DateTime.now().millisecondsSinceEpoch + 1500;
          });
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
        _queue(2, () => showPage(context,
            tag: '돌아오셨군요',
            title: '${h > 0 ? '$h시간 ' : ''}$m분 동안',
            body: '모인 자재 · ${got.entries.map((e) => '${matOf[e.key]!.n} +${e.value}').join(' · ')}',
            button: '좋아요'));
      default:
        break;
    }
  }

  // ---------- 화면 둘러보기 (웹 onbTour): 가리킬 곳 ----------
  static final _kMats = GlobalKey(), _kTape = GlobalKey(), _kClock = GlobalKey(), _kLamp = GlobalKey(), _kTabs = GlobalKey();
  final _kEv = GlobalKey(), _kStage = GlobalKey();
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

  // ---------- 큰 창 줄 세우기 (웹 mq: 창은 한 번에 하나) ----------
  // 앱 전용 (2026-10-20): 줄 하나에 급을 매긴다. 0 죽음 · 1 이야기 대화·웹툰 컷·사건·선택·구조 · 2 아침 보고·돌아오셨군요 · 3 새 기능 카드.
  // 앱을 켜거나 돌아온 직후(_burst)에는 큰 창을 둘까지만 띄우고, 급 2·3은 손을 20초 쉬거나 시트를 열었다 닫을 때까지 미룬다
  // (급 1은 이야기 순서가 꼬이지 않게 미루지 않는다). 미룬 창은 버리지 않고 그대로 줄에 남는다. 길어야 90초 뒤에는 다 풀린다.
  final List<_Pg> _pageQ = [];
  int _pgSeq = 0;
  bool _paging = false;
  bool _burst = false;
  int _burstShown = 0, _burstTicks = 0, _idleTicks = 0;
  bool _burstSheet = false;

  void _queue(int p, Future<void> Function() open) {
    final it = _Pg(p, _pgSeq++, open);
    // 같은 급끼리는 온 순서대로, 높은 급(작은 수)이 앞으로
    final i = _pageQ.indexWhere((x) => x.p > p);
    if (i < 0) {
      _pageQ.add(it);
    } else {
      _pageQ.insert(i, it);
    }
    _pumpPages();
  }

  /// 지금 띄우면 안 되고 미뤄 둘 창
  bool _held(_Pg x) => _burst && x.p >= 2 && _burstShown >= 2 && g.tut == null;

  /// 앱을 켜거나 돌아왔을 때: 몰려오는 창을 둘까지만
  void _burstStart() {
    _burst = true;
    _burstShown = 0;
    _burstTicks = 0;
    _idleTicks = 0;
    _burstSheet = false;
  }

  /// 매 0.25초: 손을 20초 쉬었거나, 시트를 열었다 닫았거나, 90초가 지나면 미룬 창을 푼다
  void _burstTick() {
    if (!_burst) return;
    _burstTicks++;
    if (sheet != null) _burstSheet = true;
    final idle = sheet == null && pageWatch.n == 0 && ringTile < 0;
    _idleTicks = idle ? _idleTicks + 1 : 0;
    if (_idleTicks >= 80 || (_burstSheet && sheet == null) || _burstTicks >= 360) _burst = false;
  }

  void _pumpPages() {
    if (_paging || _pageQ.isEmpty || pageWatch.n > 0 || !mounted) return;
    final i = _pageQ.indexWhere((x) => !_held(x));
    if (i < 0) return;
    _paging = true;
    final it = _pageQ.removeAt(i);
    if (_burst) _burstShown++;
    Future.delayed(const Duration(milliseconds: 150), () async {
      if (!mounted) return;
      try {
        await it.open();
      } finally {
        // 창 하나가 잘못되어도 줄이 멈추지 않게
        _paging = false;
      }
      if (!mounted) return;
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

  /// 새 기능 카드 '보러 가기' (웹 featGo): 그 화면과 칸을 연다
  void _featGo(String k) {
    final f = feats.where((x) => x.k == k).firstOrNull;
    if (f == null || !mounted) return;
    g.featSeen(k);
    const segs = ['build', 'craft', 'research', 'store', 'deco'];
    if (f.sheet == 'shelter') {
      ShelterBody.tab = math.max(0, segs.indexOf(f.seg ?? 'build'));
      g.sheetOpened('shelter', seg: f.seg ?? 'build');
      setState(() {
        sheet = const SheetSpec('shelter');
        matsOpen = false;
        _closeRing();
      });
    } else if (f.sheet != null) {
      if (f.sheet == 'diary' && f.seg != null) DiaryBody.tab = f.seg!;
      if (sheet?.kind != f.sheet) _open(SheetSpec(f.sheet!));
    } else if (sheet != null) {
      _close();
    }
    // 화면이 열린 뒤 그 버튼을 4.2초 깜빡이며 보이게 (웹 featGo: 350ms 뒤 .fchl)
    final hk = featHlOf[k];
    if (hk != null) {
      Timer(const Duration(milliseconds: 350), () {
        featHlKey.value = hk;
        Timer(const Duration(milliseconds: 4200), () {
          if (featHlKey.value == hk) featHlKey.value = null;
        });
      });
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
      if (m.sub.isNotEmpty) fxc.toast(uiWords(m.sub));
    }

    void toShelter(int tab) {
      ShelterBody.tab = tab;
      g.sheetOpened('shelter', seg: const ['build', 'craft', 'research', 'store', 'deco'][tab.clamp(0, 4)]);
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
        // 손님 부탁 버튼은 시계 아래 줄의 맨 아래 (연속 칩·부탁 띠에 따라 내려간다)
        final eb = _kEv.currentContext?.findRenderObject() as RenderBox?, sb = _kStage.currentContext?.findRenderObject() as RenderBox?;
        if (eb == null || sb == null || !eb.hasSize || !sb.hasSize) return const Offset(34, 48);
        final o = eb.localToGlobal(Offset.zero) - sb.localToGlobal(Offset.zero);
        return Offset(o.dx + 22, o.dy - 2);
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
        // 탭 점·새 기능 표시 지우기 (웹 openSheet 감싸기)
        if (sheet != null) {
          g.sheetOpened(s.kind, seg: s.kind == 'shelter' ? const ['build', 'craft', 'research', 'store', 'deco'][ShelterBody.tab.clamp(0, 4)] : s.kind == 'diary' ? DiaryBody.tab : null);
        }
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

  /// 카메라를 부드럽게 위아래로 (웹 camGoalY: 매 프레임 남은 거리 × min(1, dt·9)). 손가락이 닿으면 멈춘다
  Timer? _camEase;
  void _camEaseTo(double goal) {
    _camEase?.cancel();
    var last = DateTime.now();
    _camEase = Timer.periodic(const Duration(milliseconds: 16), (t) {
      final now = DateTime.now(), dt = now.difference(last).inMicroseconds / 1e6;
      last = now;
      final df = goal - cam.y;
      if (!mounted || df.abs() < .5) {
        if (mounted) cam.set(cam.x, goal);
        t.cancel();
        return;
      }
      cam.set(cam.x, cam.y + df * math.min(1, dt * 9));
    });
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
    // 건물을 위로 올려 버튼이 랜턴·탭 줄 위에 오게 (웹 openRing camGoalY)
    if (_stageSize != Size.zero) {
      final w = tileC(tile), sy = (w.dy - cam.y) * cam.z + _stageSize.height / 2;
      final lim = _stageSize.height - (MediaQuery.of(context).padding.bottom + 10 + 86) - (RingMenu.R + 54);
      if (sy > lim) _camEaseTo(math.max(0, math.min((W + H) * TH / 2, cam.y + (sy - lim) / cam.z)));
    }
    g.mapVersion.value++;
  }

  void _close() {
    _camEase?.cancel(); // 손가락이 닿으면 카메라 미끄러짐을 멈춘다 (웹 ptrs.size)
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

  /// 연속 칩: 일지 '기록' 맨 위의 오늘의 할 일
  void _openDaily() {
    DiaryBody.tab = 'story';
    if (sheet?.kind != 'diary') {
      _open(const SheetSpec('diary'));
    } else {
      setState(() {});
    }
  }

  /// 이야기 띠의 '새 이야기 N': 한 사람이면 그 사람의 이야기 탭, 여럿이면 생존자 수첩 맨 위 목록
  void _openStories() {
    if (pageWatch.n > 0) return;
    final ids = g.qNew;
    if (ids.length == 1) {
      _close();
      survTab = 'story';
      _survPage(ids.first);
    } else if (ids.isNotEmpty && sheet?.kind != 'surv') {
      _open(const SheetSpec('surv'));
    }
  }

  /// 이야기 띠의 '선택 기다림': 닫아 둔 선택 창을 다시
  void _openChoice() {
    if (pageWatch.n > 0 || g.choiceView() == null) return;
    _close();
    Sound.sfx('mystery');
    showChoice(context, g);
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
        return SheetPanel(icon: Ico.gear, title: '설정', onClose: _close, child: SettingsBody(g, onReset: _reset, onTut: _tutReplay, onSaveNow: () => _cloudUp(force: true), onLegacy: _legacyManual));
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
            title: gid != null ? '${survivors[gid].name} · ${slotName[gsl]}' : '장비 가방 ${g.bagCount}/${Game.bagMax}',
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

  /// 열린 시트. 닫힐 때 사라지는 동안(AnimatedSwitcher)에도 다시 그려지므로 그때의 시트 이름을 붙잡아 둔다
  Widget _sheetBox(SheetSpec s) => KeyedSubtree(key: ValueKey(s), child: AnimatedBuilder(animation: g, builder: (c, _) => _sheetFor(s)));

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final bottom = pad.bottom + 10;
    final coachR = _coach >= 0 ? _coachRect() : null;
    if (_coach >= 0 && coachR == null) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() {}) : null);
    return Scaffold(
      backgroundColor: Ttc.body,
      // 손이 닿으면 '쉬는 중' 셈을 처음부터 (미룬 큰 창은 손을 20초 쉬면 연다)
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _idleTicks = 0,
        child: Stack(children: [
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
            onStories: _openStories,
            onChoice: _openChoice,
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            _stageSize = box.biggest;
            return Container(
              key: _kStage,
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
                  // 대형 재폭풍 동안은 숨긴다: 아래 방어 막대가 같은 말을 하는 머리가 된다
                  child: Align(alignment: Alignment.centerLeft, child: KeyedSubtree(key: _kClock, child: Every(g: g, builder: (c) => g.defn != null ? const SizedBox.shrink() : clockChip(g)))),
                ),
                // 대형 재폭풍 막대 (시계 자리, 오른쪽 위 버튼은 비켜서)
                Positioned(
                  left: 10,
                  right: 64,
                  top: 12,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: Every(g: g, ms: 250, builder: (c) => defenseBar(g)),
                    ),
                  ),
                ),
                // 시계 아래 왼쪽 줄 (앱 전용 2026-10-20): 연속 칩 · 생존자의 부탁 띠(접힘 한 줄, 누르면 펼침) · 손님 부탁. 지도 가운데는 비워 둔다
                Positioned(
                  left: 12,
                  right: 64,
                  top: 50,
                  child: Every(
                    g: g,
                    builder: (c) {
                      if (g.defn != null || matsOpen) return const SizedBox.shrink();
                      final sqOpen = g.sq != null && g.sqOn && DateTime.now().millisecondsSinceEpoch < g.sqOpenUntil;
                      final streak = g.dayOn ? streakChip(g, onTap: _openDaily) : null;
                      final side = sideQuest(g, onTap: _sqGo);
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        if (streak != null || !sqOpen)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if (streak != null) streak,
                            if (streak != null && !sqOpen && g.sq != null && g.sqOn) const SizedBox(width: 6),
                            if (!sqOpen) Flexible(child: side),
                          ]),
                        if (sqOpen) ...[
                          if (streak != null) const SizedBox(height: 6),
                          SizedBox(width: math.min(300, box.maxWidth - 84), child: side),
                        ],
                        if (g.evCur >= 0) ...[
                          const SizedBox(height: 8),
                          KeyedSubtree(key: _kEv, child: eventButton(g, () => showRequestPage(context, g))),
                        ],
                      ]);
                    },
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
                        : _sheetBox(sheet!),
                  ),
                ),
                // 스킬 바 (시트가 열리면 숨김)
                Positioned(
                  left: 94,
                  bottom: bottom + 84,
                  // 링 메뉴가 열려 있어도 숨겨 버튼을 가리지 않게 (웹 body.ringon #skills)
                  child: IgnorePointer(
                    ignoring: sheet != null || ringTile >= 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: sheet != null || ringTile >= 0 ? 0 : 1,
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
                    dots: g.actionDots(Game.nowMs()),
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
                        var off = false;
                        if (tg.tile >= 0) {
                          off = p0.dx < 50 || p0.dx > box.maxWidth - 50 || p0.dy < 110 || p0.dy > box.maxHeight - 190;
                          if (off) {
                            final dx = p0.dx - box.maxWidth / 2, dy = p0.dy - box.maxHeight / 2;
                            label += ' ${dx.abs() > dy.abs() * 1.3 ? (dx > 0 ? '→' : '←') : (dy > 0 ? '↓' : '↑')}';
                          }
                        }
                        final x = p0.dx.clamp(40.0, math.max(40.0, box.maxWidth - 40)), y = p0.dy.clamp(40.0, math.max(40.0, box.maxHeight - 8));
                        return Stack(children: [
                          Positioned(left: x.toDouble(), top: y.toDouble(), child: FractionalTranslation(translation: const Offset(-.5, -1), child: GuideArrow(label, x: x.toDouble(), screenW: box.maxWidth,
                                  // 화면 밖을 가리키는 안내(쉘터 ← 등)는 눌러서 그쪽으로 (웹 2026-10-15)
                                  onTap: off ? () => g.panGuide = DateTime.now().millisecondsSinceEpoch : null))),
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
                        bottomGuard: bottom + 86,
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
        if (_peek)
          Positioned(
              left: 0,
              top: 0,
              child: LegacyPeek(onResult: (raw) {
                setState(() => _peek = false);
                if (raw != null) {
                  _offerLegacy(raw, '예전 탭투시티 앱');
                } else {
                  Storage.setRaw('ttc_legacy_asked', '1');
                }
              })),
        if (_mig != null) Positioned.fill(child: MigStamp(_mig!.$1, _mig!.$2, key: ValueKey(_mig), onDone: () => setState(() => _mig = null))),
        if (coachR != null) Positioned.fill(child: CoachOverlay(i: _coach, hole: coachR, onNext: _coachNext, onSkip: () => setState(_coachEnd))),
      ]),
      ),
    );
  }
}

// ======================= 머리 (자원·설정·할 일 띠) =======================
class _Header extends StatelessWidget {
  const _Header(this.g,
      {required this.top,
      required this.ping,
      required this.onGo,
      required this.onSettings,
      required this.onMats,
      required this.onShelter,
      required this.onPed,
      required this.onMig,
      required this.onProfile,
      required this.onStories,
      required this.onChoice,
      this.matsKey,
      this.tapeKey});
  final Game g;
  final Key? matsKey, tapeKey;
  final double top;
  final int ping;
  final VoidCallback onSettings, onMats, onShelter, onPed, onGo, onMig, onProfile, onStories, onChoice;

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
        KeyedSubtree(key: tapeKey, child: MissionTape(g, onLv: onShelter, onGo: onGo, onPed: onPed, onMig: onMig, onStories: onStories, onChoice: onChoice, ping: ping)),
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
    final v = g.have(k), zero = v <= 0, full = v >= g.capOf(k), m = matOf[k];
    // 꾹 누르면 이름·수량·한도 (그림만으로는 무슨 자재인지 모를 수 있어서)
    return Tooltip(
      message: '${m?.n ?? k} ${fmt(v)}${m != null && m.tier < 3 ? ' · 보관 한도 ${fmt(g.capOf(k))}' : ''}',
      triggerMode: TooltipTriggerMode.longPress,
      preferBelow: true,
      verticalOffset: 28,
      waitDuration: Duration.zero,
      showDuration: const Duration(milliseconds: 1800),
      decoration: BoxDecoration(color: const Color(0xF2141A21), borderRadius: BorderRadius.circular(7), border: Border.all(color: Ttc.line25, width: .8)),
      textStyle: Ttc.t(12.5, color: Ttc.matText, weight: FontWeight.w600),
      child: _tile(v, zero, full),
    );
  }

  Widget _tile(num v, bool zero, bool full) {
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
                        if (m.tier < 3) TextSpan(text: '/${fmt(g.capOf(m.k))}', style: const TextStyle(color: Color(0xFFCDB993))),
                      ]), style: Ttc.t(12.5)),
                      Text(m.s2, style: Ttc.t(12, color: const Color(0xFFCDB993))),
                    ]),
                  ),
                ]),
              ),
          ]),
          const SizedBox(height: 8),
          Container(height: .8, color: Ttc.line20),
          const SizedBox(height: 6),
          Text('기본 자재와 철판·밧줄은 창고 한도 ${fmt(g.cap)}, 전선·약품은 그 1/4까지 모여요. 창고 모듈과 쉘터 증축으로 늘려요. 건전지는 한도가 없어요.',
              style: Ttc.t(12.5, color: const Color(0xFFCDB993), height: 1.5)),
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
  const _Tabs({required this.on, required this.onTap, this.dots = const {}});
  final int on;
  final Set<int> dots;
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
                      if (dots.contains(k))
                        Positioned(
                            right: -5,
                            top: -3,
                            child: Container(
                                width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: Ttc.amber, border: Border.all(color: Ttc.header, width: 1.5)))),
                    ]),
                    const SizedBox(height: 5),
                    FittedBox(fit: BoxFit.scaleDown, child: Text(items[k].$2, maxLines: 1, style: Ttc.t(11.5, color: k == on ? Ttc.tabOnText : Ttc.tabText, weight: FontWeight.w600, height: 1))),
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

/// 큰 창 줄의 한 칸: 급(0 죽음 · 1 이야기 · 2 아침 보고 · 3 새 기능), 온 순서, 여는 함수
class _Pg {
  _Pg(this.p, this.seq, this.open);
  final int p, seq;
  final Future<void> Function() open;
}
