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

  ExpCalc expCalc(ExpInfo e, List<int> team, [String? pk]) {
    final px = pk != null && web.pets.containsKey(pk) ? (web.pets[pk]!['exp'] as Map? ?? const {}) : const {};
    double pxv(String k) => ((px[k] as num?) ?? 1).toDouble();
    final t = e.t * .6 * (1 - expDisc) * (hasRole(team, 'scout') ? .7 : 1) * (hasRole(team, 'drive') ? .85 : 1) * pxv('t');
    final risk = e.risk * (hasRole(team, 'medic') ? .3 : 1) * (hasRole(team, 'guard') ? .5 : 1) * pxv('risk');
    final mult = e.mult * (1 + .25 * (team.length - 1)) * (hasRole(team, 'mech') ? 1.25 : 1) * pxv('mult');
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
      if (pk != null && web.pets.containsKey(pk)) '${petName(pk)}: ${(web.pets[pk]!['expd'] as String).replaceAll('원정 ', '')}',
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
  ExpCalc? sendExp(String key, List<int> team0, {String? pet}) {
    final e = expOf(key);
    if (e == null || expMap.containsKey(key)) return null;
    final team = team0.where((id) => hasSv(id) && !busy(id)).toList();
    if (team.length < e.min) return null;
    final pk = pet != null && petHere(pet) ? pet : null;
    final c = expCalc(e, team, pk);
    (S.rest['exp'] as Map)[key] = <String, Object?>{'team': team, 'end': DateTime.now().millisecondsSinceEpoch + c.t * 1000, 'dur': c.t, 'pet': pk};
    if (pk != null) (S.rest['pets'] as Map)[pk]['away'] = key;
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
    final pk = x['pet'] as String?;
    final e = expOf(key)!, team = [for (final v in x['team'] as List) (v as num).toInt()], c = expCalc(e, team, pk), sum = <String>[];
    (S.rest['exp'] as Map).remove(key);
    _expNotified.remove(key);
    final lines = [e.open];
    if (pk != null && pets.containsKey(pk)) {
      (S.rest['pets'] as Map)[pk]['away'] = false;
      petGain(pk, 15);
      lines.add('${jo(petName(pk), '이', '가')} 앞장서서 길을 살폈다. 덕분에 모두 한결 든든했다.');
    }
    for (final id in team) {
      final q = id < web.expq.length ? web.expq[id] : const <String>[];
      if (q.isNotEmpty) lines.add('${survivors[id].name}: ${q[rnd.nextInt(q.length)]}');
    }
    final got = give(scaleCost(e.loot, c.mult * (1 + (S.lv - 1) * .3)));
    give({'batt': team.length});
    if (rnd.nextDouble() < .2 && findRelic() != null) sum.add('유물 발견');
    for (final id in team) {
      if (qStep(id)?['k'] == 'exp') Future.delayed(const Duration(milliseconds: 300), () => qAdvance(id));
    }
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
    if (bedFree(id) > 0) {
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

// ================= 떠돌이 장사꾼 '노친네' (웹 3159–3196) =================
const pedFirst = 4, pedHaneul = 3;
const pedLines = ['있을 때 사 두는 겁니다. 다음엔 없어요.', '해 지기 전엔 가야 해서요. …자리를 잡으면 안 되는 사람도 있어요.', '(창고 문 닫히는 소리에 어깨가 움찔한다) …아, 아무것도 아닙니다. 뭘 보시겠어요?', '오늘은 좀 많이 실었습니다. 다 못 팔아도 괜찮아요.', '그날 밤 우리 가게 셔터는… 안에서 내려갔어요. …값은 적어 두세요, 다음에 받죠.'];
const pedMore = ['장사꾼은 편이 없어요. 사는 쪽이 손님이지.', '길이 험해서 수레 바퀴가 또 빠졌지 뭡니까.', '여기 불빛은 멀리서도 보여요. 그래서 왔지요.', '하늘이 거는 값 안 받습니다. 그냥 그렇게 정했어요.'];
const pedRumor = ['남쪽 급유탑 마을엔 물이 거의 없답니다', '북쪽 공단 굴뚝에서 밤마다 불꽃이 튄대요', '산골 분교 아이들이 난로를 돌아가며 쬔다더군요', '어느 동네든 등불 켜진 데는 사람이 모여요', '멀리서 3번, 1번, 1번 깜빡이는 불빛을 봤다는 사람이 있어요. 뭔진 모르겠고'];
const _pedPrac = [
  ({'fuel': 12}, '랜턴 기름 두 통', '뚜껑에 테이프가 감겨 있다.', {'wood': 30, 'scrap': 10}),
  ({'med': 4}, '약품 상자', '유통기한은 지웠다.', {'food': 40, 'cloth': 8}),
  ({'food': 30}, '말린 고기 묶음', '“뭔 고기냐고는 묻지 마세요.”', {'scrap': 20, 'wood': 10}),
  ({'wire': 4}, '구리선 뭉치', '폐가전에서 뽑은 것.', {'scrap': 25, 'parts': 5}),
  ({'parts': 8}, '부품 자루', '크기가 제각각이다.', {'scrap': 30, 'wood': 12}),
];

// ================= 떠돌이 무리 (웹 3962–4003) =================
const bandTypes = {
  'trader': (['떠돌이 고물상', '남쪽 교역단', '수레 끄는 상인들'], 0xFF3F7FA8, ['“좋은 물건 있수. 바꿔 가시겠소?”', '“우린 늘 길 위에 있지. 거래는 공정하게.”']),
  'refugee': (['길 잃은 가족들', '저수지 피란민', '철길을 걷는 사람들'], 0xFF8A8479, ['“며칠째 제대로 먹지 못했어요…”', '“불빛을 보고 왔어요. 잠깐만 쉬어 가도 될까요?”']),
  'raider': (['검은 우산단', '철길 약탈자', '재 까마귀들'], 0xFF1D1712, ['“이 동네 불빛이 제일 밝더군. 통행세를 좀 내야겠어.”', '“순순히 내놓으면 조용히 지나가지.”']),
};
const _trades = [
  ({'scrap': 20}, {'plate': 3}), ({'food': 15}, {'fuel': 6}), ({'wood': 25}, {'parts': 6}), ({'cloth': 15}, {'rope': 4}),
  ({'parts': 12}, {'wire': 1}), ({'fuel': 10}, {'med': 1}), ({'food': 20}, {'batt': 1}), ({'scrap': 15, 'wood': 15}, {'cloth': 12}),
];
const allyCost = {'food': 20, 'med': 1};

// ================= 아이들 (웹 4006–4020) =================
const kidNames = ['봄이', '다온', '로운', '하람', '새벽', '누리', '가온', '아라'];
const kidJobs = {
  'mech': ('정비 견습', '가공 보너스 +6%', {'craft': .06}),
  'farm': ('농사 견습', '식량 생산 +10%', {'food': .1}),
  'scout': ('정찰 견습', '뒤지기 수확 +6%', {'scav': .06}),
};

/// 아이가 자람 → 배울 일을 고르는 창
class FxKidGrown extends Fx {
  const FxKidGrown(this.n);
  final int n;
}

extension Visitors on Game {
  Map get ped {
    if (S.rest['ped'] is! Map) S.rest['ped'] = <String, Object?>{'next': 0, 'here': null, 'stock': [], 'visits': 0, 'bought': 0};
    return S.rest['ped'] as Map;
  }

  bool get pedHere => ped['here'] != null && !isNight;
  int get pedVisits => ((ped['visits'] as num?) ?? 0).toInt();
  String get pedLine {
    final v = pedVisits;
    return v >= 1 && v <= pedLines.length ? pedLines[v - 1] : pedMore[(v + num_('day').toInt()) % pedMore.length];
  }

  List<Map> get pedStock => [for (final x in (ped['stock'] as List? ?? const [])) x as Map];

  List<Map<String, Object?>> _makePedStock() {
    final st = <Map<String, Object?>>[], rare = <Map<String, Object?>>[];
    final have = {for (final x in inv) x['t']};
    final gp = gear.values.where((G) => !G.sig && !G.ug && !G.line && G.g >= 1 && !have.contains(G.key)).toList();
    if (gp.isNotEmpty) {
      final G = gp[rnd.nextInt(gp.length)];
      rare.add({'kind': 'gear', 't': G.key, 'n': G.n, 'd': G.d, 'price': {'plate': 4 + 2 * G.g, 'rope': 3 + G.g}, 'rare': 1});
    }
    final rl = relicLeft;
    if (rl.isNotEmpty) {
      final it = rl[rnd.nextInt(rl.length)];
      rare.add({'kind': 'relic', 'it': it, 'n': it, 'd': '“어디서 났냐고요? 길에서요.”', 'price': {'scrap': 30, 'cloth': 10, 'parts': 4}, 'rare': 1});
    }
    rare.add({'kind': 'mat', 'm': {'batt': 3}, 'n': '건전지 세 개', 'd': '아직 살아 있다. 아마도.', 'price': {'parts': 10, 'fuel': 8}, 'rare': 1});
    st.add(rare[rnd.nextInt(rare.length)]);
    final pr = [..._pedPrac]..shuffle(rnd);
    final two = [for (final x in pr.take(2)) <String, Object?>{'kind': 'mat', 'm': x.$1, 'n': x.$2, 'd': x.$3, 'price': x.$4}];
    if (hasSv(pedHaneul)) two[0] = {...two[0], 'price': <String, num>{}, 'free': 1};
    st.addAll(two);
    if (pedVisits >= 2 && rnd.nextDouble() < .35) {
      st.add({'kind': 'mat', 'm': {'food': 20}, 'n': '검은 새 표식 통조림', 'd': '뚜껑에 검은 새가 찍혀 있다. “어느 쪽 물건이냐고는… 묻지 마세요.”', 'price': {'scrap': 8}, 'crow': 1});
    }
    for (final x in st) {
      x['sold'] = 0;
    }
    return st;
  }

  void _pedDawn() {
    final P = ped;
    if (S.lv < pedFirst || P['here'] != null || num_('day') < ((P['next'] as num?) ?? 0) || defn != null) return;
    P['here'] = num_('day');
    P['visits'] = pedVisits + 1;
    P['stock'] = _makePedStock();
    fx.add(FxNote(pedVisits == 1 ? '딸랑 — 손수레 끄는 노인이 찾아왔어요' : '딸랑 — 노친네가 수레를 끌고 왔어요',
        '${pedVisits == 1 && hasSv(0) ? '만수: “저 노친네, 뭘 팔러 왔구먼.” · ' : ''}해 지기 전까지 쉘터 앞에 있어요 · 위 띠의 ‘노친네’를 눌러요', ms: 6500));
  }

  void pedLeave({bool bye = false}) {
    final P = ped;
    if (P['here'] == null) return;
    P['here'] = null;
    P['next'] = num_('day') + 3 + rnd.nextInt(2);
    var t = pedRumor[rnd.nextInt(pedRumor.length)];
    if (pedVisits == 4) {
      give({'food': 8});
      t = '수레가 섰던 자리에 통조림 몇 개가 값 없이 놓여 있었어요';
    }
    fx.add(FxNote(bye ? '노친네가 수레를 끌고 떠났어요' : '노친네가 해 지기 전에 떠났어요', bye && pedVisits != 4 ? '“있을 때 사 두라니까요.” 며칠 뒤 다시 들른대요' : t, ms: 5200));
    _changed();
  }

  /// 노친네에게 사기. 결과 문구(실패면 이유)
  String pedBuy(int i) {
    final st = pedStock;
    if (i < 0 || i >= st.length || !pedHere) return '';
    final x = st[i];
    if (x['sold'] == 1) return '';
    final price = {for (final e in (x['price'] as Map).entries) e.key as String: e.value as num};
    if (x['kind'] == 'mat') {
      final k = (x['m'] as Map).keys.first as String;
      if (have(k) >= capOf(k)) return '${matOf[k]!.n} 창고가 꽉 찼어요';
    }
    if (x['kind'] == 'relic' && relics.contains(x['it'])) {
      x['sold'] = 1;
      _changed();
      return '이미 가진 유물이에요';
    }
    if (!pay(price)) return '자재가 모자라요';
    x['sold'] = 1;
    ped['bought'] = ((ped['bought'] as num?) ?? 0) + 1;
    switch (x['kind']) {
      case 'mat':
        give({for (final e in (x['m'] as Map).entries) e.key as String: e.value as num});
      case 'gear':
        addGear(x['t'] as String);
      case 'relic':
        gainRelic(x['it'] as String);
    }
    _changed();
    return x['free'] == 1 ? '노친네: “하늘이 거는 됐어요.”' : '${jo(x['n'] as String, '을', '를')} 샀어요';
  }

  // ---------- 떠돌이 무리 ----------
  Map? get band => S.rest['band'] is Map ? S.rest['band'] as Map : null;
  List<String> get allies => [for (final a in (S.rest['allies'] as List? ?? const [])) '$a'];

  void _tickBand() {
    if (num_('bandT') == 0) S.rest['bandT'] = 200 + rnd.nextDouble() * 120;
    final B = band;
    if (B != null) {
      B['t'] = ((B['t'] as num?) ?? 0) - 1;
      if ((B['t'] as num) <= 0) {
        fx.add(FxToast('${B['name']}이(가) 떠났어요'));
        S.rest['band'] = null;
        S.rest['bandT'] = 240 + rnd.nextDouble() * 180;
        _mapChanged();
      }
      return;
    }
    if (S.lv < 2 || revCount < 40 || defn != null) return;
    S.rest['bandT'] = num_('bandT') - 1;
    if (num_('bandT') > 0) return;
    final cand = <int>[];
    for (var i = 0; i < N; i++) {
      if (S.rev[i] == 0 || isSlot(i) || S.ter[i] == T.water || S.ter[i] == T.lm || (S.site[i] != null && S.site[i]!.c > 0) || S.camp.containsKey(i) || deco.containsKey('$i')) continue;
      final d = dist(i);
      if (d >= S.lv + 2 && d <= S.lv + 7) cand.add(i);
    }
    if (cand.isEmpty) {
      S.rest['bandT'] = 60;
      return;
    }
    final r = rnd.nextDouble(), k = r < .45 ? 'trader' : r < .75 ? 'refugee' : 'raider', T0 = bandTypes[k]!, tile = cand[rnd.nextInt(cand.length)];
    final tr = [..._trades]..shuffle(rnd);
    S.rest['band'] = <String, Object?>{
      'k': k,
      'name': T0.$1[rnd.nextInt(T0.$1.length)],
      'tile': tile,
      't': 150,
      'offers': [for (final (g0, t0) in tr.take(3)) <String, Object?>{'give': scaleCost(g0, lvScale), 'get': scaleCost(t0, 1 + (S.lv - 1) * .3), 'left': 2}],
      'say': T0.$3[rnd.nextInt(T0.$3.length)],
      'tribute': scaleCost({'scrap': 30, 'food': 20}, lvScale),
    };
    fx.add(FxBurst(tile, 0xFFFFD98A, 16));
    fx.add(FxNote(k == 'raider' ? '수상한 무리가 나타났어요' : '멀리서 누군가 다가와요', '${band!['name']} · 지도의 깃발을 눌러요 (2분 30초 뒤 떠나요)', ms: 5000));
    _mapChanged();
  }

  /// 떠돌이 무리와 하는 일 (웹 bandAct). 창을 닫아야 하면 true
  bool bandAct(String a, [int g = 0]) {
    final B = band;
    if (B == null) return true;
    Cost c(Object? m) => {for (final e in (m as Map).entries) e.key as String: e.value as num};
    switch (a) {
      case 'btr':
        final o = (B['offers'] as List)[g] as Map;
        if (((o['left'] as num?) ?? 0) <= 0 || !pay(c(o['give']))) return false;
        o['left'] = (o['left'] as num) - 1;
        give(c(o['get']));
        fx.add(FxToast('교역 · ${lootText(c(o['get']))}'));
      case 'bal':
        if (allies.length >= 3 || !pay(allyCost)) return false;
        S.rest['allies'] = [...allies, B['name']];
        fx.add(FxNote('${B['name']}와(과) 동맹을 맺었어요', '새벽마다 물자를 보내 주고, 대형 재폭풍 때 함께 싸워요'));
      case 'bref':
        if (!pay({'food': 25})) return false;
        S.hopeB += 4;
        var extra = '';
        final r = rnd.nextDouble();
        if (S.rest['dog'] == null && r < .25) {
          S.rest['dog'] = 1;
          extra = '떠나면서 강아지 한 마리를 두고 갔어요. 이름은 ‘등불’로 지었어요.';
        } else if (r < .7 && kids.length < 4) {
          final k = addKid();
          extra = '“이 아이를 부탁드려요.” ${k['n']}(이)가 쉘터에 남았어요.';
        }
        S.rest['band'] = null;
        S.rest['bandT'] = 240 + rnd.nextDouble() * 180;
        recalc();
        fx.add(FxNote('피란민이 고맙다며 떠났어요 · 희망 +4', extra, ms: 6000));
        _mapChanged();
        _changed();
        return true;
      case 'bpay':
        if (!pay(c(B['tribute']))) return false;
        S.rest['band'] = null;
        S.rest['bandT'] = 260 + rnd.nextDouble() * 180;
        fx.add(const FxToast('약탈자들이 통행세를 챙겨 떠났어요'));
        _mapChanged();
        _changed();
        return true;
      case 'brf':
        S.rest['raid'] = B['name'];
        S.rest['band'] = null;
        S.rest['bandT'] = 300 + rnd.nextDouble() * 180;
        fx.add(FxNote('${B['name']}: “후회하게 될 거다.”', '오늘 밤 약탈자들이 쳐들어와요. 방벽과 랜턴탑을 점검해요', ms: 6000));
        _mapChanged();
        _changed();
        return true;
      case 'bye':
        S.rest['band'] = null;
        S.rest['bandT'] = 240 + rnd.nextDouble() * 180;
        _mapChanged();
        _changed();
        return true;
    }
    _changed();
    return false;
  }

  void _allyGifts() {
    final A = allies;
    if (A.isEmpty) return;
    final o = <String, num>{};
    for (var n = 0; n < A.length; n++) {
      final k = baseMats[rnd.nextInt(6)];
      o[k] = (o[k] ?? 0) + (8 * lvScale).round();
    }
    final got = give(o);
    if (got.isNotEmpty) fx.add(FxNote('동맹이 물자를 보내왔어요', '${A.join(', ')} · ${lootText(got)}'));
  }

  /// 대형 재폭풍 때 동맹이 함께 싸운다 (웹 worldFight)
  void _worldFight(Defense D2, double dt) {
    final A = allies.length;
    if (A == 0) return;
    D2.ally += dt;
    if (D2.ally < 1.4 / A) return;
    D2.ally = 0;
    final live = D2.foes.where((f) => !f.dead && f.delay <= 0).toList();
    if (live.isEmpty) return;
    final f = live[rnd.nextInt(live.length)];
    hurtFoe(f, tapPow * .8);
    D2.beams.add(Beam(f.x - 40, f.y - 60, f.x, f.y - 8, .25, 0xFFA0D2FF));
  }

  // ---------- 아이들 ----------
  List<Map> get kids => [for (final k in (S.rest['kids'] as List? ?? const [])) k as Map];

  Map addKid() {
    if (S.rest['kids'] is! List) S.rest['kids'] = [];
    final used = kids.map((k) => k['n']).toSet();
    final n = kidNames.where((x) => !used.contains(x)).firstOrNull ?? '아이';
    const sk = ['#f2caa6', '#e2b791', '#d8a57e', '#f0c9a4'], hr = ['#2a1f18', '#4a3526', '#6a3a2a', '#1f1a16'], tp = ['#d9483b', '#3f6fa0', '#e0b441', '#6b8f4a', '#8a5a9a'];
    final k = <String, Object?>{
      'n': n,
      'g': 0,
      'job': null,
      'look': {'skin': sk[rnd.nextInt(4)], 'hair': hr[rnd.nextInt(4)], 'top': tp[rnd.nextInt(5)]},
    };
    (S.rest['kids'] as List).add(k);
    recalc();
    return k;
  }

  void _kidsDawn() {
    if (kids.length < 2 && S.lv >= 4 && hope >= 60 && rnd.nextDouble() < .25) {
      final k = addKid();
      fx.add(FxNote('쉘터에 새 식구가 생겼어요', '지나가던 가족이 ${jo(k['n'] as String, '을', '를')} 맡기고 갔어요. 희망이 커진 덕분이에요'));
    }
  }

  void _tickKids() {
    final ks = kids;
    for (var n = 0; n < ks.length; n++) {
      final k = ks[n];
      final g0 = ((k['g'] as num?) ?? 0).toDouble();
      if (g0 >= 1) continue;
      k['g'] = math.min(1.0, g0 + 1 / 600);
      if ((k['g'] as num) >= 1) fx.add(FxKidGrown(n));
    }
  }

  /// 돌봐 준 사람들 일에 따라 소질 (웹 kidBest)
  String? kidBest(Map k) => k['best'] as String?;

  void kidJob(int n, String j) {
    final ks = kids;
    if (n < 0 || n >= ks.length || !kidJobs.containsKey(j)) return;
    ks[n]['job'] = j;
    recalc();
    _changed();
  }

  void _kidEff(Map<String, double> e) {
    for (final k in kids) {
      if (((k['g'] as num?) ?? 0) < 1) {
        e['hope'] = (e['hope'] ?? 0) + 2;
      } else if (k['job'] != null && kidJobs.containsKey(k['job'])) {
        final m = k['job'] == k['best'] ? 1.5 : 1.0;
        kidJobs[k['job']]!.$3.forEach((x, v) => e[x] = (e[x] ?? 0) + v * m);
      }
    }
  }
}
