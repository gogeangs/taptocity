// 5단계: 이야기 — 등불 일지(스토리 10장·38걸음), 미션 띠·받기, 대화, 길잡이, 재혁의 고백, 은호·미영 맞이,
// 등불 탑, 끝없는 불빛, 업적·칭호. 웹 index.html 1880–2107, 4086–4104, 4393–4405, 5067–5133, 5182–5201, 5682–5684, 5858–5861.
part of 'engine.dart';

/// 대사 한 줄 (웹 [말하는 사람, 문구, 조건, 표정, 대체 줄])
class Line {
  const Line(this.who, this.t, {this.cond, this.mood, this.fb});
  final Object who; // 생존자 번호(int) · 'me' · 'g'(길잡이) · 'npc:x'
  final String t;
  final String? cond, mood;
  final Line? fb;

  static Line? of(Object? o) {
    if (o is! List) return null;
    return Line(o[0] as Object, o[1] as String, cond: o[2] as String?, mood: o[3] as String?, fb: of(o[4]));
  }
}

class StepInfo {
  StepInfo(this.i, this.ci, this.si, Map m)
      : goal = m['goal'] as String,
        rw = {for (final e in (m['rw'] as Map).entries) e.key as String: e.value as num},
        focus = m['focus'] as String?,
        hint = m['hint'] as String,
        hl = m['hl'] as String?,
        intro = [for (final l in m['intro'] as List) Line.of(l)!],
        outro = [for (final l in m['outro'] as List) Line.of(l)!];
  final int i, ci, si;
  final String goal, hint;
  final String? focus, hl;
  final Cost rw;
  final List<Line> intro, outro;
  bool get first => si == 0;
}

class Chapter {
  Chapter(this.ch, this.title, this.steps);
  final String ch, title;
  final List<StepInfo> steps;
}

final List<Chapter> chapters = () {
  final out = <Chapter>[];
  var i = 0;
  for (var ci = 0; ci < web.story.length; ci++) {
    final c = web.story[ci] as Map;
    final st = <StepInfo>[];
    final list = c['steps'] as List;
    for (var si = 0; si < list.length; si++) {
      st.add(StepInfo(i++, ci, si, list[si] as Map));
    }
    out.add(Chapter(c['ch'] as String, c['title'] as String, st));
  }
  return out;
}();
final List<StepInfo> steps = [for (final c in chapters) ...c.steps];
int stepI(String goal) => steps.indexWhere((s) => s.goal == goal);
final List<Line> endLines = [for (final l in web.endLines) Line.of(l)!];

/// 지금 띠에 걸린 목표 (웹 mission())
class Mission {
  const Mission(this.txt, this.done, this.rw, this.sub, {this.step, this.eg = false});
  final String txt, sub;
  final bool done, eg;
  final Cost rw;
  final StepInfo? step;
}

/// 대화 창 하나 (웹 openTalk opt)
class FxTalk extends Fx {
  const FxTalk(this.lines, {this.tag, this.card, this.goal, this.reward, this.chain = false, this.scene, this.noskip = false, this.after, this.replay = false});
  final List<Line> lines;
  final String? tag, goal, scene, after;
  final (String, String)? card;
  final Map<String, int>? reward;
  final bool chain, noskip, replay;
}

/// 재혁의 고백 고르기 창
class FxConf extends Fx {
  const FxConf();
}

/// 끝없는 불빛 (웹 EGT 5183)
class _Eg {
  const _Eg(this.ok, this.val, this.tg, this.t, this.rw, this.go);
  final bool Function(Game g) ok;
  final num Function(Game g) val;
  final num Function(num v) tg;
  final String Function(num g, num v) t;
  final Cost rw;
  final String go;
}

final Map<String, _Eg> _egt = {
  'tower': _Eg((g) => g.towerN >= 5, (g) => g.towerN, (v) => v + 1, (t, v) => '등불 탑 $t층까지 올리기', {'batt': 3, 'plate': 20}, 'build'),
  'land': _Eg((g) => true, (g) => g.revCount, (v) => ((v + 30) / 10).ceil() * 10, (t, v) => '땅 $t칸까지 밝히기', {'scrap': 40, 'wood': 40}, 'map'),
  'exp': _Eg((g) => g.S.sv.isNotEmpty, (g) => g.num_('expDone'), (v) => v + 2, (t, v) => '원정 2번 다녀오기', {'parts': 30, 'batt': 2}, 'exp'),
  'feast': _Eg((g) => g.feastOpen, (g) => g.num_('feasts'), (v) => v + 1, (t, v) => '마을 잔치 열기', {'batt': 2, 'med': 1}, 'craft'),
  'def': _Eg((g) => g.S.lv >= 3, (g) => g.num_('defWins'), (v) => v + 1, (t, v) => '대형 재폭풍 한 번 더 막아내기', {'plate': 30, 'batt': 2}, 'clock'),
  'ug': _Eg((g) => g.ugOpen && g.ugBest < 20, (g) => g.ugBest, (v) => v + 1, (t, v) => '지하 구역 $t층까지 내려가기', {'wire': 3, 'med': 2}, 'exp'),
  'trust': _Eg((g) => g.S.sv.keys.any((k) => Game.trustLv(g.xpOf(int.parse(k))) < 5),
      (g) => g.S.sv.keys.where((k) => Game.trustLv(g.xpOf(int.parse(k))) >= 5).length, (v) => v + 1, (t, v) => '신뢰도 5인 생존자 $t명 만들기', {'food': 120, 'cloth': 40}, 'surv'),
  'wire': _Eg((g) => g.wbL >= 2, (g) => g.S.got['wire'] ?? 0, (v) => v + 5, (t, v) => '전선 5개 모으기', {'parts': 40, 'fuel': 30}, 'craft'),
};
const _egOrder = ['tower', 'land', 'exp', 'tower', 'feast', 'ug', 'tower', 'def', 'trust', 'tower', 'wire', 'land'];

/// 등불 탑 (웹 TOWER 5089)
class TowerStep {
  const TowerStep(this.n, this.d, this.cost, this.req);
  final String n, d;
  final Cost cost;
  final List<(String, bool Function(Game g))> req;
}

/// 업적 (웹 ACH 4086): 키, 칭호, 설명, 목표, 건전지
final List<(String, String, String, int, int)> achList = [
  for (final a in web.ach) (a[0] as String, a[1] as String, a[2] as String, (a[3] as num).toInt(), (a[4] as num).toInt())
];

const _quickSteps = web.quickSteps;
const _sceneOf = ['shelter', 'mall', 'shelter', 'shelter', 'metro', 'bunker', 'control', 'shelter', 'shelter', 'shelter'];

extension Story on Game {
  int get mi => num_('mi').toInt();
  int get storyI => (S.rest['storyI'] as num?)?.toInt() ?? -1;
  String? get conf => S.rest['conf'] as String?;
  int get towerN => num_('tower').toInt();
  bool get ugOpen => S.lv >= 3 || lmOn('station');
  int get ugBest => (((S.rest['ug'] as Map?)?['best'] as num?) ?? 0).toInt();

  // ================= 옛 저장 맞추기 (웹 migrateSteps 4403) =================
  void migrateSteps() {
    final v = num_('stepV').toInt();
    if (v == 4) return;
    final list = (v == 3 ? web.stepGoals['v3'] : v == 2 ? web.stepGoals['v2'] : web.stepGoals['old'])!;
    S.rest['stepV'] = 4;
    if (!(mi > 0)) return;
    final was = mi, sawIntro = storyI >= was;
    int n;
    if (was >= list.length) {
      n = S.rest['endSeen'] != null && S.rest['endSeen'] != 0 ? steps.length : stepI('등불 탑 토대 놓기');
    } else {
      n = stepI(list[was]);
      if (n < 0) n = stepI('등불 탑 토대 놓기');
    }
    S.rest['mi'] = n;
    S.rest['storyI'] = sawIntro ? n : n - 1;
  }

  // ================= 걸음 완료 조건 (웹 STORY의 done) =================
  /// 세는 목표는 그 걸음이 시작될 때부터 센다 (웹 rel, 2008)
  bool _rel(String goal, num v) {
    if (S.rest['mb'] is! Map) S.rest['mb'] = <String, Object?>{};
    final mb = S.rest['mb'] as Map;
    mb[goal] ??= v;
    return v - (mb[goal] as num) >= 1;
  }

  bool stepDone(StepInfo st) {
    final svN = S.sv.length;
    final ug = (S.rest['ug'] as Map?)?['best'] as num? ?? 0;
    switch (st.goal) {
      case '구름을 두드려 땅 6칸 밝히기':
        return revCount >= 15;
      case '폐허를 뒤져 목재 15개 모으기':
        return (S.got['wood'] ?? 0) >= 15;
      case '작업대 만들기':
        return hasMod(1);
      case '텃밭 상자 만들기':
        return hasMod(2);
      case '구조 신호를 따라가 생존자 구하기':
        return svN >= 1;
      case '생존자를 모듈에 배치하기':
        return S.asg.isNotEmpty;
      case '생존자 스킬 한 번 쓰기':
        return _rel(st.goal, num_('skillUses'));
      case '작업대에서 철판 5개 만들기':
        return (S.got['plate'] ?? 0) >= 5;
      case '쉘터를 판잣집으로 키우기':
        return S.lv >= 2;
      case '재폭풍 밤 한 번 버티기':
        return _rel(st.goal, num_('nights'));
      case '방벽 세우기':
        return S.walls >= 1;
      case '랜턴 피버 한 번 켜기':
        return _rel(st.goal, S.fevers);
      case '고물상 세우기':
        return hasMod(9);
      case '생존자의 부탁 들어주기':
        return _rel(st.goal, num_('evDone'));
      case '생존자에게 장비 하나 맞춰 주기':
        return S.sv.values.any((r) => r is Map && r['eq'] is Map && (r['eq'] as Map).values.any((u) => u != null));
      case '생존자 3명 모으기':
        return svN >= 3;
      case '컨테이너 쉘터로 키우기':
        return S.lv >= 3;
      case '라디오로 주파수 탐색 한 번 하기':
        return _rel(st.goal, num_('gUses'));
      case '목소리의 주인 맞이하기':
        return hasSv(10);
      case '첫 원정 보내기':
        return _rel(st.goal, num_('expDone'));
      case '랜드마크 하나 복구하기':
        return S.lm.values.any((l) => l.ok);
      case '생존자 5명 모으기':
        return svN >= 5;
      case '지하 구역 2층까지 내려가기':
        return ug >= 2;
      case '발전기 가동하기':
        return hasMod(5);
      case '지하 구역 4층까지 내려가기':
        return ug >= 4;
      case '오재혁 구하기':
        return hasSv(9);
      case '재혁의 이야기 듣기':
        return conf != null;
      case '요새로 키우기':
        return S.lv >= 4;
      case '대형 재폭풍 한 번 막아내기':
        return _rel(st.goal, num_('defWins'));
      case '방벽을 모래주머니 방벽으로 올리기':
        return S.walls >= 2;
      case '무전실 세우기':
        return hasMod(7);
      case '불빛의 도시 완성하기':
        return S.lv >= 5;
      case '탁미영 맞이하기':
        return hasSv(13);
      case '등불 탑 토대 놓기':
        return towerN >= 1;
      case '등불 탑 기둥 세우기':
        return towerN >= 2;
      case '등불 탑에 전선 잇기':
        return towerN >= 3;
      case '등불 탑에 렌즈 올리기':
        return towerN >= 4;
      case '등불 탑에 불 켜기':
        return towerN >= 5;
    }
    return false;
  }

  // ================= 미션 (웹 mission 2009) =================
  Mission mission() {
    final tm = tutMission;
    if (tm != null) return tm;
    if (mi < steps.length) {
      final m = steps[mi];
      return Mission(m.goal, stepDone(m), {...m.rw, 'batt': (m.rw['batt'] ?? 0) + 1}, m.hint, step: m);
    }
    return _egMission();
  }

  Map<String, Object?> _egMake(int i) {
    for (var s = 0; s < _egOrder.length; s++) {
      final k = _egOrder[(i + s) % _egOrder.length], T = _egt[k]!;
      if (T.ok(this)) {
        final v = T.val(this);
        return {'i': i, 'k': k, 'tg': T.tg(v), 'v0': v};
      }
    }
    return {'i': i, 'k': 'land', 'tg': _egt['land']!.tg(revCount), 'v0': revCount};
  }

  Mission _egMission() {
    var e = S.rest['eg'] as Map?;
    if (e == null || !_egt.containsKey(e['k'])) {
      e = _egMake(((e?['i'] as num?) ?? 0).toInt());
      S.rest['eg'] = e;
    }
    final T = _egt[e['k']]!, v = T.val(this), tg = e['tg'] as num, v0 = e['v0'] as num, i = (e['i'] as num).toInt();
    final rel = const ['exp', 'feast', 'def', 'wire'].contains(e['k']);
    final f = 1 + math.min(2, i * .05);
    return Mission(T.t(tg, v) + (rel ? ' (${math.max(0, v - v0)}/${tg - v0})' : e['k'] == 'land' ? ' ($v)' : ''), v >= tg, scaleCost(T.rw, lvScale * f),
        '이야기는 끝나지 않아요. 한 층씩, 한 칸씩 계속 키워 가요', eg: true);
  }

  String get egGo => _egt[(S.rest['eg'] as Map?)?['k']]?.go ?? 'map';

  void _egNext() => S.rest['eg'] = _egMake((((S.rest['eg'] as Map?)?['i'] as num?) ?? 0).toInt() + 1);

  /// 첫 동네: 폭풍 미션이 열리면 다음 밤에 바로 온다 (웹 hastenStorm 2014)
  void hastenStorm(Mission m) {
    if (S.gen != 0 || m.done || m.step == null) return;
    final g = m.step!.goal;
    if (g != '재폭풍 밤 한 번 버티기' && g != '대형 재폭풍 한 번 막아내기') return;
    if (S.rest['hasten'] is! Map) S.rest['hasten'] = <String, Object?>{};
    final h = S.rest['hasten'] as Map;
    if (h[g] != null) return;
    h[g] = 1;
    if (g == '대형 재폭풍 한 번 막아내기') {
      final n = num_('nightCount').toInt(), r = n % 3;
      if (r != 2) S.rest['nightCount'] = n + (2 - r + 3) % 3;
    }
    if (!isNight && phase < dayLen - 25) S.rest['clock'] = clock + (dayLen - 25 - phase);
    dirty = true;
  }

  // ================= 대사 =================
  bool _cond(String c) => switch (c) {
        'crowRaid' => (S.rest['crow'] as Map?)?['raid'] != null && (S.rest['crow'] as Map)['raid'] != 0 && (S.rest['crow'] as Map)['raid'] != false,
        'sv10' => hasSv(10),
        'sv11' => hasSv(11),
        'sv12' => hasSv(12),
        'confA' => conf == 'a' && hasSv(9),
        'confB' => conf == 'b' && hasSv(9),
        _ => false,
      };

  bool lineOk(Line l) => l.cond == null || _cond(l.cond!);

  /// 말하는 사람이 지금 무리에 없거나 조건이 안 맞으면 대체 줄로, 없으면 건너뛴다 (웹 talkLine 2059)
  Line? talkLine(Line? l) {
    if (l == null) return null;
    final gone = l.who is int && (!hasSv(l.who as int) || isDead(l.who as int));
    final off = l.cond != null && !_cond(l.cond!);
    return (gone || off) ? talkLine(l.fb) : l;
  }

  List<Line> talkLines(List<Line> ls) => [for (final l in ls) talkLine(l)].whereType<Line>().toList();

  /// 길잡이: 만수, 없으면 가장 나이 많은 어른 (웹 guideId 1878)
  int? get guideId {
    if (hasSv(0)) return 0;
    final ids = [for (final k in S.sv.keys) int.parse(k)].where((id) => id < survivors.length && !isDead(id)).toList();
    if (ids.isEmpty) return null;
    final ad = ids.where((id) => survivors[id].age >= 18 || survivors[id].age == 0).toList();
    final pool = ad.isNotEmpty ? ad : ids;
    pool.sort((a, b) => survivors[b].age.compareTo(survivors[a].age));
    return pool.first;
  }

  /// 대사의 말하는 사람 → 생존자 번호(없으면 '나' = null)
  int? speakerId(Object w) {
    var x = w;
    if (x is int && !hasSv(x)) x = 'g';
    if (x == 'g') return guideId;
    return x is int ? x : null;
  }

  String speakerName(Object w) {
    final id = speakerId(w);
    return id == null ? '나' : survivors[id].name;
  }

  void talk(List<Line> lines, {String? tag, (String, String)? card, String? goal, Map<String, int>? reward, bool chain = false, String? scene, bool noskip = false, String? after}) {
    final ls = talkLines(lines);
    if (ls.isEmpty) return;
    fx.add(FxTalk(ls, tag: tag, card: card, goal: goal, reward: reward, chain: chain, scene: scene, noskip: noskip, after: after));
  }

  bool _isQuick(StepInfo st) => S.gen == 0 && _quickSteps.contains(st.goal) && !st.first;

  /// 걸음이 시작될 때 장면 (웹 introStep 2072)
  void introStep(int i) {
    if (i < 0 || i >= steps.length) return;
    final st = steps[i], c = chapters[st.ci];
    if (_isQuick(st)) {
      final L = st.intro.where((l) => l.cond == null || _cond(l.cond!)).toList();
      final l = L.isEmpty ? const Line('me', '') : L.last;
      final id = speakerId(l.who);
      fx.add(FxNote('새 목표 · ${st.goal}', '${id == null ? '' : '${survivors[id].name}: '}“${l.t}”', ms: 5200));
      panGuide = DateTime.now().millisecondsSinceEpoch;
      return;
    }
    talk(st.intro, scene: _sceneOf[st.ci], card: st.first ? (c.ch, c.title) : null, tag: st.first ? null : '${c.ch} · ${c.title}', goal: st.goal);
  }

  /// 화면이 비어 있을 때 다음 걸음의 장면을 연다 (웹 tickStory 2075)
  void tickStory() {
    if (uiBusy || tut != null || tutPending) return;
    if (onb == 1) {
      // 안내 카드를 닫기 전에 앱을 껐다면 다시 띄운다 (웹 tickStory 덮어쓰기)
      if (!onbAsked) {
        onbAsked = true;
        fx.add(const FxOnboard());
      }
      return;
    }
    if (storyI < mi && mi < steps.length) {
      S.rest['storyI'] = mi;
      introStep(mi);
      dirty = true;
    }
  }

  bool get uiBusy => uiModal || uiSheet || defn != null || ug != null;

  // ================= 받기 (웹 claim 2019) =================
  void claimMission() {
    final m = mission();
    if (!m.done) return;
    final got = give(m.rw);
    final st = m.step;
    if (mi < steps.length) {
      S.rest['mi'] = mi + 1;
    } else {
      _egNext();
    }
    misDoneAt = 0;
    misNudged = false;
    if (st != null) {
      final c = chapters[st.ci];
      final last = st.si == c.steps.length - 1;
      if (last) {
        talk(st.outro, tag: '${c.ch} 끝', reward: got, chain: true);
      } else {
        final ol = st.outro.where((l) => l.cond == null || _cond(l.cond!)).toList();
        if (ol.length > 1 && !_isQuick(st)) {
          talk(ol, tag: '${c.ch} · ${c.title}', reward: got, chain: true);
        } else if (ol.isNotEmpty) {
          final l = ol.last;
          fx.add(FxNote('등불 일지 · ${speakerName(l.who)}', '“${l.t}”\n보상 · ${lootText(got)}', ms: 5200));
        }
      }
    } else {
      fx.add(FxToast('보상: ${lootText(got)}'));
    }
    recalc();
    _changed();
  }

  /// 다 했는데 안 받으면 알려 주고, 한참 뒤엔 챙겨 둔다 (웹 tickClaim 4394)
  void _tickClaim(Mission m) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!m.done) {
      misDoneAt = 0;
      misNudged = false;
      return;
    }
    if (misDoneAt == 0) misDoneAt = now;
    final t = (now - misDoneAt) / 1000, auto = mi < 8 && S.gen == 0 ? 6 : 25;
    if (t > 10 && t < auto && !misNudged) {
      misNudged = true;
      S.rest['hintClaim'] = num_('hintClaim') + 1;
      fx.add(FxNote('미션 완료!', num_('hintClaim') <= 2 ? '위쪽 미션 줄의 ‘받기’를 눌러요' : '', ms: num_('hintClaim') <= 2 ? 4500 : 2600));
    }
    if (t > auto && !uiBusy) {
      fx.add(const FxNote('미션 보상을 챙겨 뒀어요', '', ms: 2600));
      claimMission();
    }
  }

  // ================= 6장: 재혁의 고백 (웹 openConf 5075) =================
  void chooseConf(bool a) {
    if (conf != null) return;
    S.rest['conf'] = a ? 'a' : 'b';
    if (hasSv(9)) {
      if (a) {
        rec(9)!['xp'] = xpOf(9) + 150;
        S.hopeB += 3;
      } else {
        _buff('all', 1.15, 600, '재혁의 속죄');
      }
    }
    recalc();
    talk(a
        ? const [Line(9, '…고마워요. 이번엔 제대로 해낼게요.'), Line('g', '대신 약속하게. 다시는 혼자 숨기지 않기로.')]
        : const [Line(9, '알겠어요. 말보다 손으로 갚을게요.'), Line('me', '그날부터 재혁은 누구보다 먼저 일어나 발전기를 돌렸다. (10분간 모든 생산 +15%)')]);
    _changed();
  }

  /// 매초: 고백 창, 미영 맞이, 은호 맞이 (웹 tickFinale 5119, tickSeason 5928, tickEunho 5860)
  void _tickStorySec(Mission m) {
    final st = m.step;
    if (st != null) {
      if (st.goal == '재혁의 이야기 듣기' && conf == null && !confShown && !uiBusy && storyI >= mi && hasSv(9)) {
        confShown = true;
        fx.add(const FxConf());
      }
      if (st.goal == '탁미영 맞이하기' && !hasSv(13) && !uiModal) {
        if (++miyT >= 4) {
          miyT = 0;
          rescue(13, 'visit');
        }
      }
    }
    final free = !uiBusy && (mi >= steps.length || storyI >= mi);
    if (!free) {
      scIdle = 0;
      return;
    }
    if (++scIdle < 6) return;
    if (_tickSeasonScenes()) scIdle = -40;
  }

  bool _tickEunho() {
    if (hasSv(10) || inStay(10) || isDead(10)) return false;
    final ji = stepI('목소리의 주인 맞이하기');
    final st = mi < steps.length ? steps[mi] : null;
    if ((st != null && st.goal == '목소리의 주인 맞이하기') || (mi > ji && ji >= 0)) {
      rescue(10, 'visit');
      return true;
    }
    return false;
  }

  /// 0.25초마다 (게임 tick에서): 미션 띠 상태와 장면 진행
  void tickStoryFast() {
    migrateSteps();
    if (tut != null) return;
    final m = mission();
    hastenStorm(m);
    tickStory();
    _tickClaim(m);
  }

  void tickStorySec() {
    _tickAch();
    if (tickTut()) return;
    _tickSeasonSec();
    _tickStorySec(mission());
  }

  // ================= 등불 탑 (웹 5084–5115) =================
  int get heartCount =>
      bonds.where((b) => b.ids.every(hasSv)).length +
      S.sv.values.where((r) => r is Map && r['q'] is Map && Game._truthy((r['q'] as Map)['done'])).length +
      pets.keys.where((k) => petLv(k) >= 3).length +
      kids.where((k) => ((k['g'] as num?) ?? 0) >= 1).length;
  int trustN(int l) => S.sv.keys.where((k) => Game.trustLv(xpOf(int.parse(k))) >= l).length;

  List<TowerStep> get _towerBase => [
        for (var i = 0; i < web.tower.length; i++)
          TowerStep(web.tower[i]['n'] as String, web.tower[i]['d'] as String, scaleCost({for (final e in (web.tower[i]['cost'] as Map).entries) e.key as String: e.value as num}, S.gen != 0 ? .6 : 1), [
            for (var r = 0; r < (web.tower[i]['req'] as List).length; r++) ((web.tower[i]['req'] as List)[r] as String, _towerReq[i][r]),
          ]),
      ];

  static final List<List<bool Function(Game g)>> _towerReq = [
    [(g) => g.S.sv.length >= (g.S.gen != 0 ? 6 : 7)],
    [(g) => g.trustN(4) >= 3],
    [(g) => g.heartCount >= 1],
    [(g) => g.hasSv(9) && Game.trustLv(g.xpOf(9)) >= 3, (g) => g.hasSv(13) && Game.trustLv(g.xpOf(13)) >= 2],
    [(g) => g.hope >= 60, (g) => !g.S.sv.values.any((r) => r is Map && Game._truthy(r['away']))],
  ];

  bool get towerOpen => S.gen != 0 ? S.lv >= 5 : (stepI('등불 탑 토대 놓기') >= 0 && mi >= stepI('등불 탑 토대 놓기'));
  List<TowerStep> get towerSteps => _towerBase;

  TowerStep towerNext() {
    final n = towerN, T = _towerBase;
    if (n == 0 && S.gen != 0) return TowerStep(T[0].n, T[0].d, T[0].cost, [('생존자 6명', T[0].req[0].$2)]);
    if (n == 3 && S.gen != 0 && !(hasSv(9) && hasSv(13))) return TowerStep(T[3].n, T[3].d, T[3].cost, [('신뢰도 4 이상 생존자 2명 (렌즈를 맞출 손)', (g) => g.trustN(4) >= 2)]);
    if (n < 5) return T[n];
    final f = n - 4, k = math.pow(1.22, f - 1).toDouble();
    return TowerStep('${n + 1}층', '탑을 한 층 더 올려 빛이 더 멀리 닿게 해요',
        scaleCost({'plate': 260, 'parts': 240, 'wood': 500, 'food': 350, 'fuel': 180, 'wire': f % 3 == 0 ? 12 : 0}, k), [('희망 ${60 + f * 4}', (g) => g.hope >= 60 + f * 4)]);
  }

  Cost get towerCost => scaleCost(towerNext().cost, costMult);
  bool get towerOk {
    final t = towerNext();
    return t.req.every((r) => r.$2(this)) && canPay(towerCost);
  }

  double get towerBonus => towerN < 5 ? 0 : .1 + .03 * (towerN - 5);

  bool buildTower() {
    final t = towerNext();
    if (!towerOk || !pay(towerCost)) return false;
    S.rest['tower'] = towerN + 1;
    fx.add(FxBurst(C0, 0xFFFFD98A, 30));
    recalc();
    if (towerN == 5) {
      _lightTower();
    } else if (towerN > 5) {
      if (towerN % 5 == 0) {
        final it = dropGear(2);
        give({'batt': 5});
        fx.add(FxNote('등불 탑 $towerN층!', '빛이 한층 멀리 닿아요 · 건전지 +5${it == null ? '' : ' · 장비 ${gear[it]?.n ?? ''}'}', ms: 5000));
      } else {
        fx.add(FxToast('등불 탑 $towerN층 · 모든 생산 +${(towerBonus * 100).round()}%'));
      }
    } else {
      fx.add(FxToast('등불 탑 ${jo(t.n, '을', '를')} 쌓았어요 · $towerN/5'));
    }
    _changed();
    mapVersion.value++;
    return true;
  }

  void _lightTower() {
    final first = S.rest['endSeen'] == null || S.rest['endSeen'] == 0;
    S.rest['endSeen'] = 1;
    give({'batt': first ? 10 : 5});
    recalc();
    fx.add(FxBurst(C0, 0xFFFFF4C8, 40));
    fx.add(FxNote(first ? '등불 탑에 첫 불이 들어왔어요' : '이 동네에도 등불 탑이 켜졌어요', '모든 생산 +10% · 이제 탑을 한 층씩 계속 올릴 수 있어요', ms: 6000));
  }

  void _towerEff(Map<String, double> e) {
    final b = towerBonus;
    if (b > 0) {
      e['global'] = (e['global'] ?? 0) + b;
      e['hope'] = (e['hope'] ?? 0) + math.max(0, towerN - 5) * 2;
    }
  }

  // ================= 업적·칭호 (웹 ACH 4086) =================
  Map get achMap {
    if (S.rest['ach'] is! Map) S.rest['ach'] = <String, Object?>{};
    return S.rest['ach'] as Map;
  }

  int achVal(String k) {
    final st = S.rest['stat'] as Map? ?? const {};
    final ug = S.rest['ug'] as Map? ?? const {};
    int qDone() => S.sv.values.where((r) => r is Map && r['q'] is Map && Game._truthy((r['q'] as Map)['done'])).length;
    int sets() => web.rsets.where((s) => relicSet(s['k'] as String)).length;
    return switch (k) {
      'rev100' || 'rev300' => revCount,
      'ash100' => ((st['ash'] as num?) ?? 0).toInt(),
      'foe50' => ((st['foe'] as num?) ?? 0).toInt(),
      'def3' => num_('defWins').toInt(),
      'sv5' || 'sv13' => S.sv.length,
      'hid1' => [10, 11, 12].where(hasSv).length,
      'ug5' || 'ug15' || 'ug10' => ((ug['best'] as num?) ?? 0).toInt(),
      'ugd' => ((ug['diary'] as List?) ?? const []).length,
      'q1' || 'q5' => qDone(),
      'gear10' => inv.length,
      'deco5' => deco.length,
      'relic1' || 'relic6' => sets(),
      'ally2' => allies.length,
      'kid1' => kids.where((k) => ((k['g'] as num?) ?? 0) >= 1).length,
      'lv5' => S.lv,
      'pull30' => num_('gTotal').toInt(),
      _ => 0,
    };
  }

  int achState(String k) => ((achMap[k] as num?) ?? 0).toInt();
  bool get achReady => achList.any((a) => achState(a.$1) == 1);
  String get title => S.rest['title'] as String? ?? '등불지기';
  set title(String t) {
    S.rest['title'] = t;
    _changed();
  }

  void _tickAch() {
    for (final a in achList) {
      if (achState(a.$1) != 0) continue;
      if (achVal(a.$1) >= a.$4) achMap[a.$1] = 1;
    }
  }

  void achGet(String k) {
    final a = achList.where((x) => x.$1 == k).firstOrNull;
    if (a == null || achState(k) != 1) return;
    achMap[k] = 2;
    give({'batt': a.$5});
    S.rest['title'] = a.$2;
    fx.add(FxToast('칭호 ‘${a.$2}’ · 건전지 +${a.$5}'));
    _changed();
  }

  // ================= 회상 그림 (웹 S.art) =================
  void markArt(int n) {
    if (S.rest['art'] is! Map) S.rest['art'] = <String, Object?>{};
    final a = S.rest['art'] as Map;
    if (a['$n'] == null) {
      a['$n'] = 1;
      S.rest['artNew'] = 1;
      dirty = true;
    }
  }
}
