// 5단계: 튜토리얼 '그날 밤' (재가 내리던 새벽 03:02 → 03:14)과 첫 동네 안내 카드. 웹 index.html 6178–6262.
// 처음 시작할 때 프롤로그 앞에서 한 번 돈다. 설정의 '다시 보기'는 지금 저장을 옆에 두고 새 지도에서 돌린 뒤 되돌린다.
part of 'engine.dart';

class TutStep {
  TutStep(Map m)
      : t = m['t'] as String,
        goal = m['goal'] as String,
        hint = m['hint'] as String,
        n = m['n'] as int,
        focus = m['focus'] as String,
        say = [for (final l in m['say'] as List) Line.of(l)!];
  final String t, goal, hint, focus;
  final int n;
  final List<Line> say;
}

final List<TutStep> tutSteps = [for (final m in web.tut) TutStep(m as Map)];

/// 튜토리얼이 끝남 → 화면이 새 지도로 카메라를 맞추고, 처음이면 안내 카드를, 다시 보기면 원래 저장을 되돌린다
class FxTutDone extends Fx {
  const FxTutDone(this.replay);
  final bool replay;
}

/// 첫 동네 안내 카드 (웹 openOnboard)
class FxOnboard extends Fx {
  const FxOnboard();
}

extension Tutorial on Game {
  Map? get tut => S.rest['tut'] as Map?;
  bool get tutDone => Game.tutFlag || S.rest['tutSeen'] != null;
  bool get tutPending => tut == null && S.gen == 0 && mi == 0 && S.rest['storyI'] == null && !tutDone;
  int get onb => num_('onb').toInt();

  num _tutV(int i) => switch (i) {
        0 => revCount,
        1 => S.got['wood'] ?? 0,
        2 => tutSheet,
        _ => (((S.rest['stat'] as Map?)?['ash'] as num?) ?? 0),
      };

  void startTut({bool replay = false}) {
    S.rest['tut'] = <String, Object?>{'i': 0, 'b': 0, 'replay': replay};
    S.sig.clear();
    S.camp.clear();
    S.rest['clock'] = dayLen + 20;
    tutEnd = false;
    tutResumed = true;
    wasNight = true;
    _tutOpen(0);
    _changed();
  }

  void _tutOpen(int i) {
    final T = tutSteps[i];
    tutSheet = 0;
    tut!['i'] = i;
    tut!['b'] = _tutV(i);
    dirty = true;
    talk(T.say, card: i == 0 ? ('그날 밤', '재가 내리던 새벽') : null, tag: i == 0 ? null : '그날 밤 · ${T.t}', goal: T.goal);
  }

  /// 미션 띠에 걸 튜토리얼 목표 (웹 mission 덮어쓰기)
  Mission? get tutMission {
    final U = tut;
    if (U == null) return null;
    final i = ((U['i'] as num?) ?? 0).toInt(), T = tutSteps[i];
    final p = math.max(0, math.min(T.n, _tutV(i) - ((U['b'] as num?) ?? 0)));
    return Mission('${T.goal}${T.n > 1 ? ' $p/${T.n}' : ''}', false, const {}, '그날 밤 · ${T.t} — ${T.hint}');
  }

  String get tutClock {
    final U = tut!, i = ((U['i'] as num?) ?? 0).toInt();
    return '그날 밤 · ${U['radio'] == 1 && i == 2 ? '03:11' : tutSteps[i].t}';
  }

  /// 매초 (웹 tickTut). 튜토리얼이 돌고 있으면 true — 다른 이야기 진행은 쉰다
  bool tickTut() {
    if (tutPending) {
      startTut();
      return true;
    }
    final U = tut;
    if (U == null) return false;
    final i = ((U['i'] as num?) ?? 0).toInt();
    // 도중에 다시 열면 지금 걸음의 대사를 한 번 더 (이미 진행했으면 그대로)
    if (!tutResumed) {
      tutResumed = true;
      if (!tutEnd && !(i == 2 && U['radio'] == 1) && _tutV(i) - ((U['b'] as num?) ?? 0) <= 0 && !uiModal) {
        _tutOpen(i);
        return true;
      }
    }
    S.rest['clock'] = (clock / cycleLen).floor() * cycleLen + dayLen + 20;
    if (tutEnd) {
      if (!uiModal) finishTut();
      return true;
    }
    final T = tutSteps[i];
    if (i == 3 && !uiModal) {
      tutAsh -= 1;
      if (tutAsh <= 0 && S.ash.length < 3) {
        final e = _edgeTiles();
        if (e.isNotEmpty) {
          final t = e[rnd.nextInt(e.length)], hp = tapPow * 2;
          S.ash['$t'] = <String, Object?>{'hp': hp, 'max': hp, 't': 16};
          fx.add(FxBurst(t, 0xFF77726B, 14));
          _mapChanged();
        }
        tutAsh = 1.4;
      }
    }
    if (_tutV(i) - ((U['b'] as num?) ?? 0) >= T.n && !uiModal) {
      if (i == 2 && U['radio'] != 1) {
        U['radio'] = 1;
        tutCloseSheet = true;
        talk(const [
          Line('me', '라디오에서는 심야 방송이 흐르고 있었다. 누군가 신청한 옛 노래.'),
          Line('me', '03:11. 노래가 뚝 끊겼다.'),
          Line('me', '잡음도 없이. 1분, 2분, 3분…'),
          Line('me', '눈을 떠 보니 나는 텐트 밖에 서 있었다. 손에 든 랜턴이 뜨거웠다.'),
        ], tag: '그날 밤 · 03:11');
        dirty = true;
        return true;
      }
      if (i < tutSteps.length - 1) {
        _tutOpen(i + 1);
      } else {
        S.ash.clear();
        tutEnd = true;
        _mapChanged();
        talk(const [Line('me', '재는 밤새 그치지 않았다.'), Line('me', '라디오는 그날 밤, 끝내 다시 켜지지 않았다.'), Line('me', '그리고 마흔세 번의 밤이 지났다.')], tag: '그날 밤');
      }
    }
    return true;
  }

  /// 튜토리얼 끝 (웹 finishTut). 다시 보기였으면 화면이 원래 저장을 되돌린다.
  void finishTut() {
    final replay = tut?['replay'] == true;
    Game.tutFlag = true;
    tutEnd = false;
    if (replay) {
      S.rest.remove('tut');
      fx.add(const FxTutDone(true));
      return;
    }
    replaceState(Game.fresh(random: rnd));
    S.rest['tutSeen'] = 1;
    S.rest['onb'] = 1;
    fx.add(const FxTutDone(false));
    fx.add(const FxOnboard());
    onbAsked = true;
    _changed();
  }

  void onbEnd() {
    S.rest['onb'] = 2;
    _changed();
  }
}
