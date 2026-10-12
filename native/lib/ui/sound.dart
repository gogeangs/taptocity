// 소리 (웹 sfx·music.js). 웹은 WebAudio로 그때그때 합성하지만, 앱은 같은 합성을 미리 렌더링한 음원을 튼다 (tool/gen_audio.cjs).
// 효과음: assets/audio/sfx/*.m4a — 변주가 있는 소리(tap·hit·click)는 여러 벌 중 하나, 줍기(get)는 오음음계를 한 칸씩 오른다.
// 배경음: assets/audio/music/<분위기>.m4a — 이음매 없이 도는 고리. 분위기가 바뀌면 천천히 겹쳐 바꾼다. 창이 열리면 절반으로, '딸깍'이면 잠깐 꺼진다.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/storage.dart';

/// 설정 (웹 SET, 'taptocity-settings')
class Prefs {
  Prefs._();
  static bool snd = true, mus = true, vib = true, calm = false, big = false, eco = false;
  static final ValueNotifier<int> version = ValueNotifier(0);
  static const _key = 'taptocity-settings';

  static Future<void> load() async {
    try {
      final raw = await Storage.getRaw(_key);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map;
      snd = m['snd'] != false;
      mus = m['mus'] != false;
      vib = m['vib'] != false;
      calm = m['calm'] == true;
      big = m['big'] == true;
      eco = m['eco'] == true;
    } catch (_) {}
  }

  static bool get(String k) => switch (k) { 'snd' => snd, 'mus' => mus, 'vib' => vib, 'calm' => calm, 'big' => big, _ => eco };

  static void toggle(String k) {
    switch (k) {
      case 'snd':
        snd = !snd;
      case 'mus':
        mus = !mus;
      case 'vib':
        vib = !vib;
      case 'calm':
        calm = !calm;
      case 'big':
        big = !big;
      default:
        eco = !eco;
    }
    Storage.setRaw(_key, jsonEncode({'snd': snd, 'mus': mus, 'vib': vib, 'calm': calm, 'big': big, 'eco': eco}));
    version.value++;
    if (k == 'snd' && snd) Sound.sfx('chime');
    if (k == 'vib' && vib) Sound.buzz();
    if (k == 'mus') Sound.mood(Sound._want);
  }
}

class Sound {
  Sound._();
  static bool _ready = false;
  static const _vars = {'tap': 4, 'hit': 4, 'click': 3};
  static final List<AudioPlayer> _pool = [];
  static int _pi = 0;
  static final Map<String, int> _last = {};
  static int _getI = 0, _getT = 0;
  static final _r = math.Random();

  /// 앱을 켤 때 한 번 (시험에서는 부르지 않아 소리가 나지 않는다)
  static Future<void> init() async {
    try {
      AudioCache.instance = AudioCache(prefix: 'assets/audio/');
      for (var k = 0; k < 6; k++) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        if (!kIsWeb) await p.setPlayerMode(PlayerMode.lowLatency);
        _pool.add(p);
      }
      _ma = AudioPlayer();
      _mb = AudioPlayer();
      for (final p in [_ma!, _mb!]) {
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setVolume(0);
      }
      // 자주 쓰는 소리는 미리 읽어 둔다
      if (!kIsWeb) {
        await AudioCache.instance.loadAll([for (final k in ['tap0', 'tap1', 'hit0', 'hit1', 'get0', 'get1', 'get2', 'reveal', 'chime']) 'sfx/$k.m4a']);
      }
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static void buzz() {
    if (Prefs.vib) HapticFeedback.lightImpact();
  }

  static void buzzMid() {
    if (Prefs.vib) HapticFeedback.mediumImpact();
  }

  static void buzzHeavy() {
    if (Prefs.vib) HapticFeedback.heavyImpact();
  }

  static void tick() {
    if (Prefs.vib) HapticFeedback.selectionClick();
  }

  static void sfx(String k) {
    if (!_ready || !Prefs.snd || k.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_last[k] ?? 0) < (k == 'get' ? 70 : 45)) return;
    _last[k] = now;
    var f = k;
    if (k == 'get') {
      if (now - _getT > 1600) _getI = 0;
      _getT = now;
      f = 'get${math.min(7, _getI++)}';
    } else if (_vars[k] != null) {
      f = '$k${_r.nextInt(_vars[k]!)}';
    }
    final p = _pool[_pi++ % _pool.length];
    () async {
      try {
        await p.stop();
        await p.play(AssetSource('sfx/$f.m4a'), volume: 1);
      } catch (_) {}
    }();
  }

  // ---------- 배경음 ----------
  static AudioPlayer? _ma, _mb;
  static bool _aOn = true; // 지금 소리 나는 쪽이 _ma
  static String _want = 'off', _cur = 'off';
  static bool _duck = false;
  static int _blackUntil = 0;
  static Timer? _fade;
  static double _va = 0, _vb = 0;

  static const _moods = {'day', 'night', 'air', 'storm', 'under', 'tut'};

  /// 매초 부른다 (웹 TTCMusic.mood)
  static void mood(String m) {
    _want = m;
    if (!_ready) return;
    final target = Prefs.mus && _moods.contains(m) ? m : 'off';
    if (target != _cur) {
      _cur = target;
      _switch(target);
    }
    _apply();
  }

  static void duck(bool on) {
    if (on == _duck) return;
    _duck = on;
    _apply();
  }

  /// '딸깍', 그리고 잠깐 어둠 (웹 TTCMusic.blackout)
  static void blackout([double sec = 2.6]) {
    if (!_ready) return;
    _blackUntil = DateTime.now().millisecondsSinceEpoch + (sec * 1000).round();
    _apply(fast: true);
    Timer(Duration(milliseconds: (sec * 1000).round() + 30), _apply);
  }

  static Future<void> _switch(String m) async {
    final next = _aOn ? _mb! : _ma!;
    _aOn = !_aOn;
    try {
      await next.stop();
      if (m != 'off') {
        await next.setVolume(0);
        await next.play(AssetSource('music/$m.m4a'), volume: 0);
      }
    } catch (_) {}
    _apply();
  }

  static double get _level {
    if (_cur == 'off') return 0;
    if (DateTime.now().millisecondsSinceEpoch < _blackUntil) return 0;
    return (_duck ? .5 : 1) * .85;
  }

  /// 소리 크기를 천천히 맞춘다 (웹 setTargetAtTime 1.2초 → 약 1.5초에 걸쳐)
  static void _apply({bool fast = false}) {
    _fade?.cancel();
    final step = fast ? .5 : .06;
    _fade = Timer.periodic(const Duration(milliseconds: 60), (t) {
      final ta = _aOn ? _level : 0.0, tb = _aOn ? 0.0 : _level;
      double mv(double v, double to) => (to - v).abs() < step ? to : v + (to > v ? step : -step);
      _va = mv(_va, ta);
      _vb = mv(_vb, tb);
      try {
        _ma?.setVolume(_va);
        _mb?.setVolume(_vb);
      } catch (_) {}
      if (_va == ta && _vb == tb) {
        t.cancel();
        // 다 줄어든 쪽은 멈춰 둔다 (휴대폰이 덜 데워지게)
        if (ta == 0) _ma?.pause();
        if (tb == 0) _mb?.pause();
        if (ta > 0 && _ma?.state != PlayerState.playing) _ma?.resume();
        if (tb > 0 && _mb?.state != PlayerState.playing) _mb?.resume();
      }
    });
    if (_level > 0) {
      final on = _aOn ? _ma : _mb;
      if (on != null && on.state == PlayerState.paused) on.resume();
    }
  }

  /// 화면을 처음 누를 때: 브라우저는 누르기 전엔 소리를 못 내게 막아서, 그때 배경음을 다시 튼다 (웹 start)
  static bool _kicked = false;
  static void kick() {
    if (!_ready || _kicked || _cur == 'off') return;
    _kicked = true;
    final on = _aOn ? _ma! : _mb!;
    if (on.state != PlayerState.playing) {
      () async {
        try {
          await on.play(AssetSource('music/$_cur.m4a'), volume: _aOn ? _va : _vb);
        } catch (_) {}
        _apply();
      }();
    }
  }

  /// 앱이 뒤로 가면 멈추고, 돌아오면 다시
  static void pauseAll(bool paused) {
    if (!_ready) return;
    if (paused) {
      _ma?.pause();
      _mb?.pause();
    } else {
      _apply();
    }
  }
}
