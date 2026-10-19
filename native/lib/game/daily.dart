// 앱 전용 (2026-10-18): 매일 할 거리 — 오늘의 의뢰 3개(실제 날짜마다), 연속 일수(7일째 귀한 장비), 아침 보고(30분 넘게 비웠다 돌아오면).
// 웹(index.html)에는 없다. 저장: S.rest['dayQ'] = {d: yyyymmdd, q: [{k, n, p(모은 것), l(마지막으로 본 값), ok}], all},
// 'dayStreak'(연속 일수 0~7), 'dayLast'(마지막으로 다 한 날 yyyymmdd), 'dayRare'(7일째 받은 횟수). 시각은 Game.nowMs() (시험에서 바꿔 끼운다).
part of 'engine.dart';

/// yyyymmdd (기기 시간대)
int dayKeyOf(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return d.year * 10000 + d.month * 100 + d.day;
}

/// yyyymmdd에서 며칠 앞뒤
int dayKeyAdd(int k, int days) {
  final d = DateTime(k ~/ 10000, k ~/ 100 % 100, k % 100 + days);
  return d.year * 10000 + d.month * 100 + d.day;
}

/// 오늘의 의뢰 종류: 할 수 있나, 몇 번, 지금 값(늘어난 만큼 센다), 글, 보상(쉘터 레벨만큼 커짐 · 건전지 1은 따로)
class _Dq {
  const _Dq(this.ok, this.n, this.v, this.t, this.rw);
  final bool Function(Game g) ok;
  final int Function(Game g) n;
  final num Function(Game g) v;
  final String Function(int n) t;
  final Cost rw;
}

final Map<String, _Dq> _dqTypes = {
  'wood': _Dq((g) => true, (g) => (40 * g.lvScale).round(), (g) => g.S.got['wood'] ?? 0, (n) => '목재 ${fmt(n)}개 모으기', const {'food': 12}),
  'scrap': _Dq((g) => true, (g) => (40 * g.lvScale).round(), (g) => g.S.got['scrap'] ?? 0, (n) => '고철 ${fmt(n)}개 모으기', const {'wood': 12}),
  'food': _Dq((g) => true, (g) => (35 * g.lvScale).round(), (g) => g.S.got['food'] ?? 0, (n) => '식량 ${fmt(n)}개 모으기', const {'scrap': 12}),
  'reveal': _Dq((g) => g.frontier.length >= 30, (g) => 12, (g) => g.revCount, (n) => '어둠 $n칸 걷어내기', const {'wood': 10, 'scrap': 6}),
  'skill': _Dq((g) => g.party.isNotEmpty, (g) => 3, (g) => g.num_('skillUses'), (n) => '생존자 스킬 $n번 쓰기', const {'parts': 6}),
  'gift': _Dq((g) => g.svIds.any((id) => Game.trustLv(g.xpOf(id)) < 5 || (!g.bondGiftedToday(id) && g.bondLv(id) < 5)), (g) => 1, (g) => g.num_('giftN'),
      (n) => '생존자에게 선물 한 번 하기', const {'cloth': 10}),
  'exp': _Dq((g) => g.num_('expDone') > 0 || g.mi > stepI('첫 원정 보내기'), (g) => 1, (g) => g.num_('expDone'), (n) => '원정 한 번 다녀오기', const {'parts': 8}),
  'ug': _Dq((g) => g.ugOpen && g.S.sv.isNotEmpty, (g) => 3, (g) => g.num_('ugDown'), (n) => '지하에서 계단 $n번 내려가기', const {'fuel': 6}),
  'night': _Dq((g) => g.num_('nights') > 0, (g) => 1, (g) => g.num_('nights'), (n) => '재폭풍 밤 한 번 버티기', const {'scrap': 12}),
  'ev': _Dq((g) => g.num_('evDone') > 0, (g) => 1, (g) => g.num_('evDone'), (n) => '생존자의 부탁 하나 들어주기', const {'food': 12}),
};

/// 오늘 몫을 다 했을 때
const Map<int, String> _dqAll = {
  0: '오늘 몫은 다 했구먼. 내일도 이 시간에 보자고.',
  3: '오늘 거 다 했어요! 내일도 같이 해요.',
  4: '오늘 할 일은 다 했데이. 욕봤다.',
  5: '오늘 몫 끝. 수고했어, 국 먹고 쉬어.',
  6: '오늘 작업 끝. 내일 또 보자.',
  10: '오늘의 의뢰, 모두 완료. 내일 이 시간에 또 만나요.',
  12: '오늘 몫은 다 감았구먼. 내일 또 감세.',
  17: '…오늘 거 다 했네. 내일도 올 거지?',
};

/// 7일째: 귀한 장비를 건네며
const Map<int, String> _dq7 = {
  0: '이레를 하루도 안 빠졌구먼. 내가 아껴 둔 거야, 받으라고.',
  3: '일주일 내내 했어요! 이거 선물이에요. 제가 제일 먼저 찾았어요.',
  4: '이레 동안 욕봤데이. 이거 받아라, 귀한 기다.',
  5: '일주일 개근이네. 상 줘야지. 이거 가져가.',
  6: '칠 일 연속이면 현장에선 포상감이야. 받아.',
  10: '일주일 개근 축하해요. 오늘 방송 첫 곡은 당신 거예요. 이건 선물이고요.',
  12: '이레를 꼬박 채웠구먼. 시간을 잘 쓰는 사람에게 주는 걸세.',
  17: '…칠 일 내내 했네. 이거, 너 가져.',
};

/// 하루를 걸러 연속이 끊겼을 때 (벌은 없다)
const Map<int, String> _dqMiss = {
  0: '어제는 쉬었구먼. 괜찮아, 오늘부터 다시 세자고.',
  3: '어제 안 왔죠? 괜찮아요, 오늘부터 다시 세어요!',
  4: '어제는 쉬었나. 괜찮다, 쉬는 날도 있어야제.',
  5: '어제 빼먹었지? 됐어, 오늘 다시 하면 돼.',
  6: '하루 빠졌네. 괜찮아, 다시 쌓으면 돼.',
  10: '어제는 쉬어 가는 날이었네요. 오늘 다시 시작해요.',
  12: '하루 쉬었구먼. 태엽은 다시 감으면 되는 걸세.',
  17: '…어제 안 왔더라. 뭐, 괜찮아.',
};

/// 아침 보고: 말순(5) → 만수(0) → 나(-1). {loot} 모인 자재, {names} 나은 사람
const Map<int, Map<String, List<String>>> _mr = {
  5: {
    'open': [
      '왔어? 밥은 먹고 다니냐.',
      '어이, 등불지기. 늦었다. 국 다 식었어.',
      '왔네. 앉아 봐, 보고할 거 있어.',
      '이제 오냐. 다들 네 얘기만 하더라.',
      '어디 갔다 왔어? 얼굴이 반쪽이네.',
      '마침 잘 왔다. 솥에 불 지피던 참이야.',
    ],
    'close': [
      '자, 됐고. 국 한 그릇 떠 놨으니 먹고 해.',
      '할 얘긴 그게 다야. 오늘도 굶지 말고.',
      '됐어, 보고 끝. 가서 랜턴이나 닦아.',
      '그래도 다들 무사해. 그거면 됐지.',
      '오늘은 좀 일찍 들어와. 국 데워 놓을게.',
      '잔소리는 여기까지. 나가 봐.',
    ],
    'res': ['네가 없는 동안 이만큼 모았어: {loot}. 다들 손이 안 쉬더라.'],
    'none': ['창고는 그대로야. 다들 쉬엄쉬엄 했지 뭐.'],
    'healed': ['{names} 다 나았어. 내 국 먹고 일어난 거야.'],
    'visitor': ['쉘터 앞에 낯선 사람이 와 있어. 가 봐.'],
    'exp': ['원정 갔던 애들 돌아와 있더라. 짐 좀 풀어 줘.'],
    'rumor': ['밤새 바람이 순하더라. 재도 덜 날리고.', '누가 그러는데 동쪽 하늘이 조금 밝아졌대.', '어젯밤엔 다들 일찍 잤어. 오랜만에 조용했지.'],
  },
  0: {
    'open': [
      '왔구먼. 운행 잘 마치고 왔나?',
      '허허, 이제 오는구먼. 기다렸다고.',
      '어이, 등불지기. 자리 비운 사이 별일 없었어.',
      '왔나. 시동부터 걸자고, 보고할 게 있어.',
      '늦었구먼. 그래도 돌아왔으니 됐어.',
      '마침 잘 왔구먼. 차 한 잔 하면서 듣자고.',
    ],
    'close': [
      '자, 오늘 노선도 달려 보자고.',
      '보고는 여기까지구먼. 출발하자고.',
      '다들 무사하구먼. 그거면 됐어.',
      '오늘도 한 바퀴 돌아 보자고.',
      '운행 시작이구먼. 조심히 다니자고.',
      '그럼 나는 정비하러 가 봐야겠구먼.',
    ],
    'res': ['네가 없는 동안 이만큼 모였구먼: {loot}. 다들 손이 부지런해.'],
    'none': ['창고는 그대로구먼. 다들 좀 쉬었지.'],
    'healed': ['{names} 다 나았구먼. 허허, 다행이야.'],
    'visitor': ['쉘터 앞에 누가 와서 기다리는구먼. 가 보자고.'],
    'exp': ['원정 갔던 친구들이 돌아와 있구먼. 짐 좀 풀어 주자고.'],
    'rumor': ['밤새 바람이 순했구먼. 재가 덜 쌓였어.', '멀리서 엔진 소리 같은 게 들렸다는구먼. 잘못 들었겠지.', '다들 푹 잤구먼. 오랜만이야.'],
  },
  -1: {
    'open': [
      '돌아왔다. 쉘터 불빛은 그대로였다.',
      '한참 만에 돌아왔다. 랜턴 갓이 식어 있었다.',
      '다시 쉘터 앞에 섰다.',
      '자리를 비운 사이에도 불은 꺼지지 않았다.',
      '돌아오니 다들 일어나 있었다.',
      '쉘터 문을 열자 익숙한 냄새가 났다.',
    ],
    'close': [
      '오늘도 해야 할 일이 있다.',
      '랜턴을 다시 들었다.',
      '다들 무사했다. 그거면 됐다.',
      '오늘도 한 칸씩 밝혀 가자.',
      '숨을 한 번 고르고, 일을 시작했다.',
      '불빛을 조금 더 키워야겠다.',
    ],
    'res': ['없는 동안 창고가 이만큼 불어 있었다: {loot}.'],
    'none': ['창고는 그대로였다.'],
    'healed': ['{names}의 상처가 다 아물어 있었다.'],
    'visitor': ['쉘터 앞에 누군가 와 있었다.'],
    'exp': ['원정 갔던 사람들이 돌아와 있었다.'],
    'rumor': ['밤새 재가 조용히 내렸다고 했다.', '멀리서 개 짖는 소리가 들렸다고 했다.', '다들 오랜만에 푹 잤다고 했다.'],
  },
};

extension Daily on Game {
  int get todayKey => dayKeyOf(Game.nowMs());

  /// 오늘의 의뢰가 열리는 때 (긴장 장치와 같게: 튜토리얼·안내 뒤, 재폭풍 밤을 배우고 판잣집이 된 뒤)
  bool get dayOn => tensionOn;
  Map? get dayQ => S.rest['dayQ'] is Map ? S.rest['dayQ'] as Map : null;
  int get dayStreak => ((S.rest['dayStreak'] as num?) ?? 0).toInt();
  int get dayLast => ((S.rest['dayLast'] as num?) ?? 0).toInt();

  /// 오늘 다 했나
  bool get dayAllDone => dayQ != null && dayQ!['d'] == todayKey && dayQ!['all'] == 1;

  /// 화면에 보일 오늘의 의뢰: (글, 모은 것, 목표, 끝남)
  List<(String, int, int, bool)> get dayList {
    final q = dayQ;
    if (q == null || q['d'] != todayKey || q['q'] is! List) return const [];
    return [
      for (final x in q['q'] as List)
        if (x is Map && _dqTypes[x['k']] != null)
          (_dqTypes[x['k']]!.t(((x['n'] as num?) ?? 1).toInt()), math.min(((x['p'] as num?) ?? 0).toInt(), ((x['n'] as num?) ?? 1).toInt()), ((x['n'] as num?) ?? 1).toInt(), x['ok'] == 1),
    ];
  }

  /// 연속 칸에 보일 수: 어제나 오늘 다 했으면 이어지고, 아니면 0
  int get streakShown {
    final t = todayKey, l = dayLast;
    return l == t || l == dayKeyAdd(t, -1) ? dayStreak : 0;
  }

  /// 말할 사람: 지금 쉘터에 있는 사람 중 그 줄이 있는 사람 (없으면 나)
  (Object, String) _dayVoice(Map<int, String> pool, String me) {
    final ids = [for (final id in svIds) if (pool.containsKey(id) && _tnHere(id)) id];
    if (ids.isEmpty) return ('me', me);
    final id = ids[rnd.nextInt(ids.length)];
    return (id, pool[id]!);
  }

  String _voiceHead(Object who) => who is int ? survivors[who].name : (pfSet ? pfName : '나');
  String _voiceText(Object who, String t) => who is int ? '“$t”' : t;

  void _dayNew(int today) {
    final st = dayStreak, last = dayLast;
    if (st > 0 && last != today && last != dayKeyAdd(today, -1)) {
      S.rest['dayStreak'] = 0;
      final (who, say) = _dayVoice(_dqMiss, '하루를 걸렀다. 괜찮다, 오늘부터 다시 세면 된다.');
      fx.add(FxNote(_voiceHead(who), '${_voiceText(who, say)}\n오늘의 의뢰 연속이 처음부터 다시 시작돼요', ms: 5200));
    }
    final ks = _dqTypes.keys.where((k) => _dqTypes[k]!.ok(this)).toList(), pick = <String>[];
    double wt(String k) => const ['wood', 'scrap', 'food', 'reveal'].contains(k) ? 1 : 1.3;
    while (pick.length < 3 && ks.isNotEmpty) {
      var tot = 0.0;
      for (final k in ks) {
        tot += wt(k);
      }
      var r = rnd.nextDouble() * tot;
      var k = ks.last;
      for (final q in ks) {
        r -= wt(q);
        if (r <= 0) {
          k = q;
          break;
        }
      }
      ks.remove(k);
      pick.add(k);
    }
    S.rest['dayQ'] = <String, Object?>{
      'd': today,
      'all': 0,
      'q': [
        for (final k in pick) <String, Object?>{'k': k, 'n': _dqTypes[k]!.n(this), 'p': 0, 'l': _dqTypes[k]!.v(this), 'ok': 0},
      ],
    };
    dirty = true;
  }

  /// 매초: 날짜가 바뀌면 새 의뢰, 늘어난 만큼 세고, 끝나면 보상
  void _tickDaily() {
    if (!dayOn) return;
    final today = todayKey, q = dayQ;
    if (q == null || q['d'] != today || q['q'] is! List) {
      _dayNew(today);
      return;
    }
    final list = q['q'] as List;
    var ch = false;
    for (final x in list) {
      if (x is! Map || x['ok'] == 1) continue;
      final T = _dqTypes[x['k']];
      if (T == null) {
        x['ok'] = 1;
        continue;
      }
      final v = T.v(this), l = (x['l'] as num?) ?? v, n = ((x['n'] as num?) ?? 1).toInt();
      // 이주로 값이 처음부터 다시 세어지면 줄어든 만큼은 무시한다
      if (v > l) x['p'] = math.min(n, ((x['p'] as num?) ?? 0) + (v - l));
      x['l'] = v;
      if (((x['p'] as num?) ?? 0) >= n) {
        x['ok'] = 1;
        ch = true;
        final got = give({...scaleCost(T.rw, lvScale), 'batt': 1});
        final done = list.where((y) => y is Map && y['ok'] == 1).length;
        fx.add(FxNote('오늘의 의뢰 $done/${list.length} · ${T.t(n)}', lootText(got), ms: 3800));
        sfx('chime');
      }
    }
    if (ch) dirty = true;
    if (ch && q['all'] != 1 && list.every((y) => y is! Map || y['ok'] == 1)) {
      q['all'] = 1;
      _dayAll(today);
    }
  }

  void _dayAll(int today) {
    final st = dayStreak, last = dayLast;
    final n = last == dayKeyAdd(today, -1) && st > 0 && st < 7 ? st + 1 : 1;
    S.rest['dayStreak'] = n;
    S.rest['dayLast'] = today;
    final got = give({'batt': 2});
    if (n == 7) {
      final t = _dayRare();
      give({'batt': 3});
      S.rest['dayRare'] = num_('dayRare') + 1;
      final (w, line) = _dayVoice(_dq7, '이레째 되는 날, 창고 구석에서 귀한 물건이 나왔다.');
      fx.add(FxNote('연속 7일 · ${_voiceHead(w)}', '${_voiceText(w, line)}\n${t != null ? '${gear[t]!.n} · ' : ''}건전지 +5', ms: 6500));
    } else {
      final (w, line) = _dayVoice(_dqAll, '오늘 할 일을 다 마쳤다.');
      fx.add(FxNote('오늘의 의뢰 끝 · 연속 $n일', '${_voiceText(w, line)}${w is int ? ' — ${survivors[w].name}' : ''}\n${lootText(got)} · 7일째엔 귀한 장비', ms: 5600));
    }
    dirty = true;
  }

  /// 7일째 선물: 아직 없는 전설 장비 (폐허·원정에서는 거의 안 나오는 것)
  String? _dayRare() {
    final have = {for (final x in inv) x['t']};
    final pool = [for (final G in gear.values) if (G.g == 3 && !G.sig && !G.line) G.key];
    final fresh = pool.where((k) => !have.contains(k)).toList(), p = fresh.isNotEmpty ? fresh : pool;
    if (p.isEmpty) return null;
    final t = p[rnd.nextInt(p.length)];
    addGear(t);
    return t;
  }

  // ================= 아침 보고 =================
  /// 30분 넘게 비웠다 돌아오면 (engine offline): 비운 시간만큼 쉬어 다 나은 사람을 포함해, 말순 → 만수 → 나 순으로 짧게 알려 준다
  void morningReport(double sec, Map<String, int> got, List<int> healed) {
    final int who = _tnHere(5) ? 5 : _tnHere(0) ? 0 : -1;
    final V = _mr[who]!;
    String pick(String k) {
      final l = V[k]!;
      return l[rnd.nextInt(l.length)];
    }

    Line say(String t) => who >= 0 ? Line(who, t) : Line('me', t);
    final names = [for (final id in healed) if (id != who) callName(who >= 0 ? who : null, id)];
    final now = Game.nowMs();
    final expBack = expMap.values.any((x) => now >= ((x['end'] as num?) ?? 1e15));
    final visitor = S.camp.values.any((c) => c['visit'] == true);
    final lines = <Line>[
      say(pick('open')),
      say(got.isNotEmpty ? pick('res').replaceAll('{loot}', lootText(got)) : pick('none')),
      if (names.isNotEmpty) say(pick('healed').replaceAll('{names}', names.join(', '))),
      say(visitor ? pick('visitor') : expBack ? pick('exp') : pick('rumor')),
      say(pick('close')),
    ];
    final h = sec ~/ 3600, m = (sec % 3600 / 60).round();
    talk(lines, tag: '아침 보고 · ${h > 0 ? '$h시간 ' : ''}$m분 만에 돌아왔어요');
    S.rest['mrN'] = num_('mrN') + 1;
    dirty = true;
  }
}
