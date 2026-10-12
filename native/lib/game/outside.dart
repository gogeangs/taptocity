// 4단계: 바깥 세상 — 원정 (웹 index.html 2893–2978, 자동 원정 4189–4204).
part of 'engine.dart';

/// 원정에서 돌아옴 → 원정 일지 창
class FxExpBack extends Fx {
  const FxExpBack(this.key, this.team, this.lines, this.sum);
  final String key;
  final List<int> team;
  final List<String> lines, sum;
}

class ExpInfo {
  const ExpInfo(this.key, this.name, this.t, this.risk, this.mult, this.loot, this.reveal, this.min, this.lock, this.desc, this.open);
  final String key, name, lock, desc, open;
  final double t, risk, mult;
  final Cost loot;
  final int reveal, min;
}

final List<ExpInfo> exps = [
  for (final e in web.exps)
    ExpInfo(e['key'] as String, e['name'] as String, (e['t'] as num).toDouble(), (e['risk'] as num).toDouble(), (e['mult'] as num).toDouble(),
        {for (final x in (e['loot'] as Map).entries) x.key as String: x.value as num}, e['reveal'] as int, e['min'] as int, e['lock'] as String, e['desc'] as String, e['open'] as String),
];
ExpInfo? expOf(String k) => exps.where((e) => e.key == k).firstOrNull;

class ExpCalc {
  const ExpCalc(this.t, this.risk, this.mult, this.perks);
  final int t;
  final double risk, mult;
  final List<String> perks;
}

extension Outside on Game {
  List<String> roleOf(int id) => id >= 0 && id < web.role.length ? web.role[id] : const [];
  bool hasRole(List<int> team, String r) => team.any((id) => roleOf(id).contains(r));

  /// 열려 있는지 (웹 EXPS[].req)
  bool expOpen(ExpInfo e) => switch (e.key) {
        'road' => revCount >= 25,
        'apt' => S.lv >= 3,
        'plant' => hasSv(9) || S.lv >= 4,
        _ => true,
      };

  Map<String, Map> get expMap {
    if (S.rest['exp'] is! Map) S.rest['exp'] = <String, Object?>{};
    return {for (final e in (S.rest['exp'] as Map).entries) e.key as String: e.value as Map};
  }

  ExpCalc expCalc(ExpInfo e, List<int> team) {
    final t = e.t * .6 * (1 - expDisc) * (hasRole(team, 'scout') ? .7 : 1) * (hasRole(team, 'drive') ? .85 : 1);
    final risk = e.risk * (hasRole(team, 'medic') ? .3 : 1) * (hasRole(team, 'guard') ? .5 : 1);
    final mult = e.mult * (1 + .25 * (team.length - 1)) * (hasRole(team, 'mech') ? 1.25 : 1);
    final perks = <String>[
      if (hasRole(team, 'scout')) '정찰: 시간 -30%',
      if (hasRole(team, 'drive')) '운전: 시간 -15%',
      if (hasRole(team, 'medic')) '간호: 부상 위험 크게 줄어듦',
      if (hasRole(team, 'guard')) '소방: 위험 절반',
      if (hasRole(team, 'mech')) '기술: 전리품 +25%',
      if (hasRole(team, 'cook')) '요리: 동료 신뢰 +40',
      if (hasRole(team, 'heart')) '하늘: 희망 +2',
      if (hasRole(team, 'farm')) '순례: 식량 ×1.5 60초',
      if (hasRole(team, 'art')) '유나: 지도 스케치 30초',
      if (hasRole(team, 'sci')) '재혁: 어둠 +4칸',
    ];
    return ExpCalc(jsRound(t), risk, mult, perks);
  }

  /// 보낼 수 있는 사람: 쉬는 사람 중 순찰·아이 돌보기가 아닌 사람 (웹 expPool)
  List<int> get expPool => [
        for (final id in svIds)
          if (atOf(id) < 0 && !busy(id) && !(((rec(id)!['hurt'] as num?) ?? 0) > 0) && !const ['patrol', 'care'].contains(dutyOf(id))) id
      ];

  /// 가장 효율 좋은 팀 (웹 autoTeam)
  List<int>? autoTeam(ExpInfo e, [List<int>? pool0]) {
    final pool = pool0 ?? expPool, n = pool.length;
    List<int>? best;
    var bs = -1.0;
    void tryT(List<int> t) {
      if (t.length < e.min) return;
      final c = expCalc(e, t), sc = c.mult * (1 - c.risk) / c.t;
      if (sc > bs) {
        bs = sc;
        best = t;
      }
    }

    for (var a = 0; a < n; a++) {
      tryT([pool[a]]);
      for (var b = a + 1; b < n; b++) {
        tryT([pool[a], pool[b]]);
        for (var c = b + 1; c < n; c++) {
          tryT([pool[a], pool[b], pool[c]]);
        }
      }
    }
    return best;
  }

  /// 원정 출발 (웹 startExp/sendExp)
  ExpCalc? sendExp(String key, List<int> team0) {
    final e = expOf(key);
    if (e == null || expMap.containsKey(key)) return null;
    final team = team0.where((id) => hasSv(id) && !busy(id)).toList();
    if (team.length < e.min) return null;
    final c = expCalc(e, team);
    (S.rest['exp'] as Map)[key] = <String, Object?>{'team': team, 'end': DateTime.now().millisecondsSinceEpoch + c.t * 1000, 'dur': c.t};
    for (final id in team) {
      rec(id)!['away'] = key; // 일터 자리는 그대로, 돌아오면 다시 일한다
    }
    if (S.rest['expTold'] == null) {
      S.rest['expTold'] = 1;
      fx.add(const FxNote('원정대가 길을 떠났어요', '앱을 닫아도 원정은 계속돼요. 돌아오면 원정 탭에 표시되고, 다시 들어오면 알려 드려요.', ms: 7000));
    }
    fx.add(FxToast('${team.map((id) => survivors[id].name).join(', ')} 원정 출발! ${mmss(c.t.toDouble())} 뒤에 돌아와요'));
    recalc();
    _changed();
    return c;
  }

  String mmss(double s) => '${s ~/ 60}:${(s % 60).floor().toString().padLeft(2, '0')}';

  /// 저장이 어긋난 원정·자리 비움을 바로잡는다 (웹 repairExpeditions)
  void repairExpeditions() {
    final m = S.rest['exp'];
    if (m is! Map) {
      S.rest['exp'] = <String, Object?>{};
      return;
    }
    final used = <int>{};
    for (final k in m.keys.toList()) {
      final x = m[k], e = expOf('$k');
      final team = x is Map && x['team'] is List ? [for (final v in x['team'] as List) (v as num).toInt()] : <int>[];
      final ok = e != null && x is Map && x['end'] is num && x['dur'] is num && (x['dur'] as num) > 0 && team.length >= e.min && team.length <= 3 && team.every(hasSv) && !team.any(used.contains);
      if (!ok) {
        m.remove(k);
        continue;
      }
      used.addAll(team);
    }
    for (final id in svIds) {
      final r = rec(id)!;
      final a = r['away'];
      if (a != null && a != false && !(m[a] is Map && ((m[a] as Map)['team'] as List).contains(id))) r['away'] = false;
    }
    m.forEach((k, x) {
      for (final id in (x as Map)['team'] as List) {
        rec((id as num).toInt())!['away'] = k;
      }
    });
  }

  void revealToward(int target, int n) {
    final tx = target % W, ty = target ~/ W;
    for (var k = 0; k < n; k++) {
      var best = -1;
      var bd = 1e9;
      for (final i in frontier) {
        final d = hypot(i % W - tx, i ~/ W - ty);
        if (d < bd) {
          bd = d;
          best = i;
        }
      }
      if (best < 0) return;
      reveal(best);
      if (best == target) return;
    }
  }

  /// 원정 귀환 (웹 claimExp)
  void claimExp(String key, {bool quiet = false}) {
    repairExpeditions();
    final x = expMap[key];
    if (x == null || DateTime.now().millisecondsSinceEpoch < (x['end'] as num)) return;
    final e = expOf(key)!, team = [for (final v in x['team'] as List) (v as num).toInt()], c = expCalc(e, team), sum = <String>[];
    (S.rest['exp'] as Map).remove(key);
    _expNotified.remove(key);
    final lines = [e.open];
    for (final id in team) {
      final q = id < web.expq.length ? web.expq[id] : const <String>[];
      if (q.isNotEmpty) lines.add('${survivors[id].name}: ${q[rnd.nextInt(q.length)]}');
    }
    final got = give(scaleCost(e.loot, c.mult * (1 + (S.lv - 1) * .3)));
    give({'batt': team.length});
    sum.add('건전지 +${team.length}');
    if (rnd.nextDouble() < (e.key == 'mall' ? .25 : .4)) {
      final t = dropGear(e.key == 'plant' ? 2 : e.key == 'mall' ? 0 : 1);
      if (t != null) {
        sum.add('장비: ${gear[t]!.n}');
        lines.add('폐허 한쪽에서 ${jo(gear[t]!.n, '을', '를')} 챙겨 왔다.');
      }
    }
    sum.add(got.isNotEmpty ? lootText(got) : '창고가 가득 차 전리품을 두고 왔어요');
    for (final id in team) {
      final r = rec(id);
      if (r == null) continue;
      r['away'] = false;
      r['xp'] = xpOf(id) + 30 * team.length;
    }
    sum.add('동료 신뢰 +${30 * team.length}');
    if (hasRole(team, 'cook')) {
      for (final id in team) {
        if (hasSv(id)) rec(id)!['xp'] = xpOf(id) + 40;
      }
    }
    if (hasRole(team, 'heart')) {
      S.hopeB += 2;
      sum.add('희망 +2');
    }
    if (hasRole(team, 'farm')) S.buff = <String, Object?>{'k': 'farm', 'm': 1.5, 't': 60, 'label': '순례의 들깨'};
    if (hasRole(team, 'art')) {
      S.rest['hintT'] = math.max(num_('hintT'), 30);
      sum.add('지도 스케치 30초');
    }
    final rv = e.reveal + (hasRole(team, 'sci') ? 4 : 0);
    if (rv > 0) {
      final sig = S.sig.keys.toList();
      if (sig.isNotEmpty) {
        var best = sig.first;
        var bd = 1e9;
        for (final t in sig) {
          if (dist(t) < bd) {
            bd = dist(t);
            best = t;
          }
        }
        revealToward(best, rv);
        sum.add('구조 신호 쪽으로 $rv칸 길을 틈');
        lines.add('멀리서 깜빡이는 구조 신호를 봤다. 그쪽으로 길을 터 두었다.');
      } else {
        revealN(rv);
        sum.add('어둠 $rv칸 걷힘');
      }
    }
    if (rnd.nextDouble() < .35) {
      if (rnd.nextDouble() < .5) {
        S.buff = <String, Object?>{'k': 'all', 'm': 1.4, 't': 60, 'label': '원정 전리품'};
        sum.add('통조림 상자: 60초 생산 ×1.4');
        lines.add('무너진 창고에서 통조림 상자를 찾았다.');
      } else {
        fever = feverT;
        S.fevers++;
        sum.add('등유 한 통: 랜턴 피버');
        lines.add('주유기 밑에서 등유 한 통을 건졌다.');
      }
    }
    if (rnd.nextDouble() < c.risk) {
      final id = team[rnd.nextInt(team.length)];
      if (hasSv(id)) {
        rec(id)!['hurt'] = 120;
        sum.add('${survivors[id].name} 부상 · 2분 휴식');
        lines.add('돌아오는 길에 ${jo(survivors[id].name, '이', '가')} 발을 삐었다. 한동안 쉬어야 한다.');
      }
    }
    S.rest['expDone'] = num_('expDone') + 1;
    recalc();
    if (quiet) {
      fx.add(FxNote('원정 귀환 · ${e.name}', '${team.map((id) => survivors[id].name).join(', ')} · ${sum.join(' · ')}', ms: 5200));
    } else {
      fx.add(FxExpBack(key, team, lines, sum));
    }
    _changed();
  }

  bool get autoExpOpen => S.lv >= 4 || S.gen != 0;

  /// 1초마다: 돌아온 원정대 알림 · 자동 원정 (웹 tickExp, tickAutoExp)
  void _tickExp() {
    final now = DateTime.now().millisecondsSinceEpoch;
    expMap.forEach((k, x) {
      if (now >= (x['end'] as num) && !_expNotified.contains(k)) {
        _expNotified.add(k);
        fx.add(FxToast('${expOf(k)?.name ?? ''} 원정대가 돌아왔어요! 원정 버튼을 눌러요'));
        _changed();
      }
    });
    if (S.rest['autoExp'] != true || !autoExpOpen) return;
    if (++_autoExpT % 5 != 0) return;
    for (final k in expMap.keys.toList()) {
      if (now >= (expMap[k]!['end'] as num)) claimExp(k, quiet: true);
    }
    final sent = <String>[];
    for (final e in exps.reversed) {
      if (!expOpen(e) || expMap.containsKey(e.key)) continue;
      final team = autoTeam(e);
      if (team == null) continue;
      final c = sendExp(e.key, team);
      if (c != null) sent.add('${e.name} (${team.map((id) => survivors[id].name).join(', ')} · ${mmss(c.t.toDouble())})');
    }
    if (sent.isNotEmpty) {
      fx.removeWhere((f) => f is FxToast && f.text.contains('원정 출발'));
      fx.add(FxNote('자동 원정 출발', sent.join('\n'), ms: 4800));
    }
  }

  bool get anyExpBack => expMap.values.any((x) => DateTime.now().millisecondsSinceEpoch >= (x['end'] as num));
}

// ================= 라디오: 주파수 탐색 (웹 3111–3155) =================
const hiddenSv = [11, 12];
const pity = 20;
const gTable = [('hidden', .05, '히든 생존자'), ('gear', .10, '장비 (희귀 65% · 영웅 30% · 전설 5%)'), ('rare', .22, '희귀 자재'), ('voice', .08, '먼 곳의 목소리'), ('memo', .05, '생존자의 사연'), ('junk', .50, '잡음 속 물자')];
const voices = ['“…여기는 남쪽 저수지… 물은 있는데 불이 없어요…”', '“…3시 14분… 모든 시계가… 멈췄…”', '“…오늘의 날씨… 재… 내일은… 맑…”', '“…누구든 이 방송을 듣는다면, 불을 켜 주세요…”', '“…발전소 제어실… 아직 전원이… 살아…”', '“…사랑해, 꼭 다시 만나…”'];
const exchCost = {'parts': 12, 'fuel': 6, 'scrap': 10};

/// 탐색 한 번의 결과
class Pull {
  Pull(this.k, {this.id, this.t, this.got = const {}});
  String k; // hidden gear rare voice memo junk
  final int? id;
  final String? t; // 장비 키 또는 목소리
  Map<String, int> got;
}

extension Radio on Game {
  int get batt => have('batt').toInt();
  int get pityLeft => math.max(1, pity - num_('gp').toInt());

  Pull _rollOne() {
    S.rest['gp'] = num_('gp') + 1;
    S.rest['gTotal'] = num_('gTotal') + 1;
    final left = hiddenSv.where((id) => !hasSv(id) && !isDead(id) && !inStay(id) && !S.camp.values.any((c) => c['id'] == id)).toList();
    var r = rnd.nextDouble();
    String k;
    if (left.isNotEmpty && (num_('gp') >= pity || r < .05)) {
      k = 'hidden';
    } else {
      r = rnd.nextDouble();
      k = r < 10 / 95 ? 'gear' : r < 32 / 95 ? 'rare' : r < 40 / 95 ? 'voice' : r < 45 / 95 ? 'memo' : 'junk';
    }
    if (k == 'hidden') {
      S.rest['gp'] = 0;
      return Pull(k, id: left[rnd.nextInt(left.length)]);
    }
    if (k == 'gear') {
      final q = rnd.nextDouble();
      final t = dropGear(q < .05 ? 3 : q < .35 ? 2 : 1);
      if (t != null) return Pull(k, t: t);
      k = 'junk';
    }
    if (k == 'memo') {
      final ids = svIds.toList();
      if (ids.isNotEmpty) {
        final id = ids[rnd.nextInt(ids.length)];
        rec(id)!['xp'] = xpOf(id) + 60;
        return Pull(k, id: id);
      }
      k = 'junk';
    }
    if (k == 'voice') {
      S.hopeB += 2;
      return Pull(k, t: voices[rnd.nextInt(voices.length)]);
    }
    if (k == 'rare') {
      const opts = [
        {'plate': 5},
        {'rope': 5},
        {'wire': 1},
        {'med': 1},
        {'plate': 3, 'rope': 3},
      ];
      return Pull(k, got: give(scaleCost(opts[rnd.nextInt(opts.length)], 1 + (S.lv - 1) * .3)));
    }
    final a = baseMats[rnd.nextInt(6)], b = baseMats[rnd.nextInt(6)];
    return Pull('junk', got: give(scaleCost(a == b ? {a: 6} : {a: 8, b: 6}, lvScale)));
  }

  /// 건전지 n개로 n번 탐색 (웹 pull). 5번 탐색엔 희귀 이상이 하나는 꼭.
  List<Pull>? pull(int n) {
    if (batt < n) return null;
    S.m['batt'] = have('batt') - n;
    final res = [for (var q = 0; q < n; q++) _rollOne()];
    if (n >= 5 && res.every((x) => x.k == 'junk')) {
      res.last
        ..k = 'rare'
        ..got = give(scaleCost({'plate': 4, 'rope': 4}, 1 + (S.lv - 1) * .3));
    }
    S.rest['gUses'] = num_('gUses') + 1;
    recalc();
    _changed();
    return res;
  }

  /// 히든 생존자가 신호를 따라 온다 (빈 침상이 없으면 쉘터 앞에서 기다림)
  void hiddenArrive(int id) {
    if (hasSv(id)) return;
    if (bedFree > 0) {
      rescue(id, 'visit');
    } else {
      final t = visitorTile();
      if (t >= 0) {
        makeCamp(t, id, visit: true);
        fx.add(FxToast('${jo(survivors[id].name, '이', '가')} 쉘터 앞에서 빈 침상을 기다려요'));
      }
    }
    _changed();
  }

  Cost get exchangeCost => scaleCost(exchCost, 1 + (S.lv - 1) * .2);
  void exchange() {
    if (!pay(exchangeCost)) return;
    give({'batt': 1});
    fx.add(const FxToast('건전지 1개를 만들었어요'));
    _changed();
  }
}
