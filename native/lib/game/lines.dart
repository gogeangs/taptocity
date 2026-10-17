// 6단계: 끊긴 노선 — 복구한 지하철역 안쪽 터널. 갈림길마다 터널 셋 중 하나를 고르고,
// 재 괴물은 좁혀 오는 고리가 금빛 테두리에 닿을 때 두드려 쓰러뜨린다. 3구간 × 터널 3개 + 역, 종점엔 우두머리.
// 웹 index.html 3476–3620. 앱에서는 난이도를 조금 풀었다 (계획서 4절):
//  · 판정 폭 ±4/±10 → ±6/±13, 터치 지연 60ms 보정
//  · 고리 시간 하한 1,100ms (웹 990/950)
//  · 두 번 연달아 놓치면 '숨 고르기': 다음 고리가 1.3배 느리고 잠깐 쉬었다 시작
//  · 쉼터 회복 3 → 4, 종점 우두머리 앞에서 체력 3 회복
part of 'engine.dart';

const lnFat = [1.0, .75, .55, .4, .3];
const lnRec = 15 * 60000;
const lnTgt = 46.0;
const _lnW = [('loot', .34), ('foe', .28), ('hazard', .16), ('trace', .12), ('rest', .10)];
const lnCardName = {
  'loot': ('물자', '버려진 짐이 보여요'),
  'foe': ('재 괴물', '무언가 움직여요'),
  'hazard': ('무너진 선로', '천장이 내려앉았어요'),
  'trace': ('사람의 흔적', '누가 지나간 자리'),
  'rest': ('고요한 승강장', '잠깐 쉴 수 있어요'),
};
const _lnPick = [
  ['guard'],
  ['scout', 'art'],
  ['sci'],
  ['cook'],
  ['heart', 'medic'],
  ['drive']
];
const _lnWhy = {'guard': '덜 다침', 'scout': '터널이 보임', 'art': '터널이 보임', 'sci': '노선 물건↑', 'cook': '체력 +3', 'heart': '역마다 체력', 'medic': '쉼터 회복↑', 'drive': '선로 피해↓'};

class LnTownInfo {
  LnTownInfo(Map m)
      : n = m['n'] as String,
        st = [for (final x in m['st'] as List) x as String],
        loot = [for (final x in m['loot'] as List) x as String],
        boss = m['boss'] as String,
        items = [for (final x in m['items'] as List) x as String],
        trace = [for (final x in m['trace'] as List) x as String];
  final String n, boss;
  final List<String> st, loot, items, trace;
}

final Map<String, LnTownInfo> lnTowns = {for (final e in web.lnTown.entries) e.key: LnTownInfo(e.value)};

class LnCard {
  LnCard(this.c);
  final String c;
  bool hid = false;
}

class LnFight {
  LnFight(this.boss, this.hp, this.dur, this.t0) : max = hp;
  final bool boss;
  int hp;
  final int max;
  double dur, t0, lock = 0;
  String res = '';
}

class LnRun {
  LnRun(this.team, this.hp, this.reg) : max = hp;
  final List<int> team;
  final String reg;
  int hp, step = 0, best = 0, miss = 0;
  final int max;
  final Map<String, int> carry = {};
  final List<String> items = [];
  String msg = '개찰구를 넘어 어두운 승강장으로 내려갔다.', phase = 'pick';
  List<LnCard> cards = [];
  LnFight? fight;
  int hurtAt = 0; // 맞은 순간 (화면 흔들기)
}

double _lnNow() => DateTime.now().microsecondsSinceEpoch / 1000;

extension Lines on Game {
  String get lnReg => S.region != null && lnTowns.containsKey(S.region) ? S.region! : 'home';
  bool get lnOpen => lmOn('station');
  LnTownInfo get lnTown => lnTowns[lnReg]!;

  Map lnState() {
    if (S.rest['line'] is! Map) S.rest['line'] = <String, Object?>{};
    final all = S.rest['line'] as Map, r = lnReg;
    final L = (all[r] ??= <String, Object?>{'fat': 0, 'at': 0, 'runs': 0, 'best': 0}) as Map;
    final fat = ((L['fat'] as num?) ?? 0).toInt(), at = ((L['at'] as num?) ?? 0).toInt();
    if (fat > 0 && at > 0) {
      final k = (Game.nowMs() - at) ~/ lnRec;
      if (k > 0) {
        final f = math.max(0, fat - k);
        L['fat'] = f;
        L['at'] = f > 0 ? at + k * lnRec : 0;
      }
    }
    return L;
  }

  double get lnMult => lnFat[math.min(lnFat.length - 1, ((lnState()['fat'] as num?) ?? 0).toInt())];
  int get lnNextRec {
    final L = lnState();
    return ((L['fat'] as num?) ?? 0) > 0 ? math.max(0, lnRec - (Game.nowMs() - ((L['at'] as num?) ?? 0).toInt())) : 0;
  }

  bool lnOwned(String t) => inv.any((x) => x['t'] == t);
  bool lnSeen(String t) => ((S.rest['lnGot'] as List?) ?? const []).contains(t) || lnOwned(t);
  List<int> get lnFree => [for (final id in svIds) if (!busy(id)) id];
  bool lnRole(List<int> team, String r) => team.any((id) => roleOf(id).contains(r));
  int lnHp0(List<int> t) => 8 + 4 * t.length + (lnRole(t, 'cook') ? 3 : 0);
  Cost lnCost(int n) => {'food': 8 * math.max(1, n)};
  List<String> lnPerks(List<int> t) {
    final roleN = web.lnText['roleN'] as Map;
    return [for (final r in {for (final id in t) ...roleOf(id)}) if (roleN[r] != null) roleN[r] as String];
  }

  /// 추천 두 명 (웹 lnRecommend): 소방·정찰 먼저, 그다음 연구·요리·희망/간호·운전, 같으면 등급·신뢰
  (List<int>, Map<int, String>) lnRecommend(List<int> free) {
    int sc(int id) => gradeOf(id) * 3 + Game.trustLv(xpOf(id)) + (sigWorn(id) ? 2 : 0);
    final pick = <int>[], why = <int, String>{};
    for (final rs in _lnPick) {
      if (pick.length >= 2) break;
      if (pick.any((id) => roleOf(id).any(rs.contains))) continue;
      final c = free.where((id) => !pick.contains(id) && roleOf(id).any(rs.contains)).toList()..sort((a, b) => sc(b) - sc(a));
      if (c.isNotEmpty) {
        pick.add(c.first);
        why[c.first] = _lnWhy[rs.firstWhere((r) => roleOf(c.first).contains(r))] ?? '';
      }
    }
    for (final id in [...free]..sort((a, b) => sc(b) - sc(a))) {
      if (pick.length >= 2) break;
      if (!pick.contains(id)) {
        pick.add(id);
        why[id] = '높은 등급';
      }
    }
    return (pick, why);
  }

  bool lnStart(List<int> team0) {
    final t = team0.where((id) => hasSv(id) && !busy(id)).take(2).toList();
    if (t.isEmpty || defn != null || ug != null || !pay(lnCost(t.length))) return false;
    ln = LnRun(t, lnHp0(t), lnReg);
    sfx('chime');
    _lnDeal();
    _changed();
    return true;
  }

  void _lnDeal() {
    final L = ln!, sec = L.step ~/ 3, cards = <LnCard>[];
    for (var k = 0; k < 3; k++) {
      var c = _lnW.last.$1;
      for (var q = 0; q < 20; q++) {
        var r = rnd.nextDouble();
        c = _lnW.last.$1;
        for (final (n, w) in _lnW) {
          if (r < w) {
            c = n;
            break;
          }
          r -= w;
        }
        if (c == 'rest' && L.hp >= L.max) continue;
        if (cards.where((x) => x.c == c).length >= 2) continue;
        break;
      }
      cards.add(LnCard(c));
    }
    final scout = lnRole(L.team, 'scout') || lnRole(L.team, 'art');
    final nh = math.max(0, (sec >= 2 ? 2 : 1) - (scout ? 1 : 0));
    final ks = [0, 1, 2]..shuffle(rnd);
    for (final k in ks.take(nh)) {
      cards[k].hid = true;
    }
    L.cards = cards;
  }

  Map<String, int> _lnAdd(Map<String, int> o) {
    final L = ln!, m = lnRole(L.team, 'mech') ? 1.3 : 1.0, farm = lnRole(L.team, 'farm');
    for (final e in o.entries) {
      var v = e.value;
      if (e.key != 'batt' && e.key != 'wire' && e.key != 'med') v = jsRound(v * m * (e.key == 'food' && farm ? 2 : 1));
      if (v > 0) L.carry[e.key] = (L.carry[e.key] ?? 0) + v;
    }
    return o;
  }

  String _lnTxt(Map<String, int> o) => lootText({for (final e in o.entries) if (e.value > 0) e.key: e.value});

  Map<String, int> _lnLoot() {
    final T = lnTowns[ln!.reg]!, sec = ln!.step ~/ 3, o = <String, int>{};
    final ks = ([...T.loot]..shuffle(rnd)).take(2);
    for (final k in ks) {
      o[k] = (o[k] ?? 0) + (k == 'wire' ? 1 : jsRound((4 + sec * 3) * (.8 + rnd.nextDouble() * .4)));
    }
    if (rnd.nextDouble() < .08 + sec * .05) o['batt'] = 1;
    return o;
  }

  void lnPick(int k) {
    final L = ln;
    if (L == null || L.phase != 'pick' || k >= L.cards.length) return;
    final c = L.cards[k].c, sec = L.step ~/ 3;
    switch (c) {
      case 'loot':
        final o = _lnAdd(_lnLoot());
        sfx('get');
        L.msg = '버려진 짐을 뒤졌다 · ${_lnTxt(o)}';
        _lnNext();
      case 'foe':
        _lnFight(false);
      case 'hazard':
        L.phase = 'hazard';
        L.msg = '천장이 내려앉아 선로가 막혔다. 틈새로 고철이 삐죽 나와 있다.';
      case 'trace':
        final T = lnTowns[L.reg]!, o = _lnAdd({rnd.nextDouble() < .5 ? 'cloth' : 'food': 3 + sec * 2});
        for (final id in L.team) {
          if (hasSv(id)) rec(id)!['xp'] = xpOf(id) + 10;
        }
        L.msg = '${T.trace[rnd.nextInt(T.trace.length)]} · ${_lnTxt(o)} · 동료 신뢰 +10';
        sfx('find');
        _lnNext();
      default:
        final g = 4 + (lnRole(L.team, 'medic') ? 2 : 0);
        L.hp = math.min(L.max, L.hp + g);
        L.msg = '고요한 승강장에서 숨을 돌렸다 · 체력 +$g';
        sfx('chime');
        _lnNext();
    }
    dirty = true;
    poke();
  }

  int get lnHazardDmg => math.max(1, 2 + ((ln?.step ?? 0) >= 6 ? 1 : 0) - (ln != null && lnRole(ln!.team, 'drive') ? 1 : 0));

  void lnHazard(bool crawl) {
    final L = ln;
    if (L == null || L.phase != 'hazard') return;
    final sec = L.step ~/ 3;
    if (crawl) {
      final d = lnHazardDmg;
      L.hp -= d;
      final o = _lnAdd({'scrap': 4 + sec * 3, 'plate': sec >= 1 ? 1 : 0});
      L.msg = '기어서 틈을 지났다 · 체력 -$d · ${_lnTxt(o)}';
      L.hurtAt = Game.nowMs();
    } else {
      L.hp -= 1;
      L.msg = '먼 길로 돌아갔다 · 체력 -1';
    }
    L.phase = 'pick';
    if (L.hp <= 0) {
      lnEnd(false);
      return;
    }
    _lnNext();
    poke();
  }

  void _lnNext() {
    final L = ln!;
    L.step++;
    L.best = math.max(L.best, L.step);
    if (L.step % 3 == 0) {
      _lnStation();
      return;
    }
    _lnDeal();
  }

  void _lnStation() {
    final L = ln!, T = lnTowns[L.reg]!, s = L.step ~/ 3 - 1;
    if (s >= 2) {
      // 종점 앞: 우두머리와 싸우기 전에 숨을 고른다 (앱에서 더함)
      final before = L.hp;
      L.hp = math.min(L.max, L.hp + 3);
      _lnFight(true);
      if (L.hp > before) L.msg = '${L.msg} · 숨을 고르고 체력 +${L.hp - before}';
      return;
    }
    if (lnRole(L.team, 'heart')) L.hp = math.min(L.max, L.hp + 1);
    final o = <String, int>{T.loot[0]: 5 + s * 4, if (s == 1) 'batt': 1};
    _lnAdd(o);
    var extra = '';
    final ch = (s == 0 ? .12 : .3) * lnMult * (lnRole(L.team, 'sci') ? 1.4 : 1);
    if (rnd.nextDouble() < ch) {
      final it = _lnItemPick();
      if (it != null) {
        L.items.add(it);
        extra = ' · ${jo(gear[it]?.n ?? it, '을', '를')} 찾았다!';
        sfx('find');
      }
    }
    for (final id in L.team) {
      if (hasSv(id)) rec(id)!['xp'] = xpOf(id) + 15;
    }
    L.phase = 'station';
    sfx('chime');
    L.msg = '${T.st[s]}에 닿았다. 플랫폼에 남은 물건을 챙겼다 · ${_lnTxt(o)}$extra · 동료 신뢰 +15';
  }

  String? _lnItemPick() {
    final L = ln!, T = lnTowns[L.reg]!;
    final c = T.items.where((t) => !lnOwned(t) && !L.items.contains(t)).toList()..sort((a, b) => (gear[a]?.g ?? 0) - (gear[b]?.g ?? 0));
    return c.isEmpty ? null : c.first;
  }

  void lnGoOn() {
    final L = ln;
    if (L == null || L.phase != 'station') return;
    L.phase = 'pick';
    _lnDeal();
    L.msg = '다시 어두운 터널로 들어갔다.';
    poke();
  }

  /// 연달아 쓰러졌을 때 돕는 정도 (0~3): 고리가 느려지고 맞는 폭이 넓어진다 (앱 시즌 1 다듬기 2026-10-17)
  int get lnAssist => math.min(3, num_('lnLose').toInt());

  // ---------- 재 괴물: 고리가 좁혀 오다 금빛 테두리에 겹칠 때 두드린다 ----------
  void _lnFight(bool boss) {
    final L = ln!, sec = math.min(2, (L.step - (boss ? 1 : 0)) ~/ 3);
    L.phase = 'fight';
    L.miss = 0;
    L.fight = LnFight(boss, boss ? 7 : 3 + sec, (boss ? 1100 : math.max(1100, 1250 - sec * 80).toDouble()) * (1 + .12 * lnAssist), _lnNow() + 500);
    L.msg = boss ? '${jo(lnTowns[L.reg]!.boss, '이', '가')} 길을 막았다!' : '재 괴물이 다가온다! 고리가 금빛 테두리에 닿을 때 두드려요.';
    if (lnAssist > 0 && !boss && L.step <= 1) L.msg = '지난번엔 힘들었죠. 이번엔 고리가 조금 느리게 와요.';
  }

  /// 고리 반지름 (100 → 0)
  double lnRing([double? now]) {
    final F = ln?.fight;
    if (F == null) return 100;
    final t = now ?? _lnNow();
    return t < F.t0 ? 100 : math.max(0, 100 * (1 - (t - F.t0) / F.dur));
  }

  /// 두드리기. 터치가 화면에 닿기까지의 지연을 60ms 앞당겨 본다
  void lnStrike() {
    final L = ln;
    if (L == null || L.phase != 'fight') return;
    final F = L.fight!, now = _lnNow();
    if (now < F.t0 || now < F.lock) return;
    final r = lnRing(now - 60), d = (r - lnTgt).abs(), a = lnAssist;
    final dmg = d <= 6 + a ? 2 : d <= 13 + 2 * a ? 1 : 0;
    if (dmg > 0) {
      F.hp -= dmg;
      F.res = dmg > 1 ? '딱 맞았다!' : '맞혔다';
      sfx('hit', buzz: true);
      L.miss = 0;
    } else {
      _lnHurt();
      F.res = r > lnTgt ? '너무 일러요' : '늦었어요';
    }
    _lnNextRing(now, 420);
    if (F.hp <= 0) {
      Future.delayed(const Duration(milliseconds: 380), _lnWin);
    } else if (L.hp <= 0) {
      Future.delayed(const Duration(milliseconds: 420), () => lnEnd(false));
    }
    poke();
  }

  /// 다음 고리. 두 번 연달아 놓치면 숨 고르기
  void _lnNextRing(double now, int gap) {
    final L = ln!, F = L.fight!;
    final base = (F.boss ? 1100.0 : math.max(1100, 1250 - math.min(2, L.step ~/ 3) * 80).toDouble()) * (1 + .12 * lnAssist);
    if (L.miss >= 2) {
      F.dur = base * 1.3;
      F.t0 = now + gap + 500;
      F.lock = now + gap;
      F.res = '숨 고르기… 천천히 와요';
      L.miss = 0;
    } else {
      F.dur = base;
      F.t0 = now + gap;
      F.lock = now + gap;
    }
  }

  void _lnHurt() {
    final L = ln!, F = L.fight!, g = lnRole(L.team, 'guard');
    L.hp -= F.boss ? (g ? 2 : 3) : (g ? 1 : 2);
    sfx('hit', buzz: true);
    L.miss++;
    L.hurtAt = Game.nowMs();
  }

  /// 매 프레임: 고리가 다 좁혀지면 맞는다
  void lnTickFight() {
    final L = ln;
    if (L == null || L.phase != 'fight') return;
    final F = L.fight!, now = _lnNow();
    if (now >= F.t0 && lnRing(now) <= 0 && now >= F.lock && F.hp > 0 && L.hp > 0) {
      _lnHurt();
      F.res = '놓쳤어요';
      _lnNextRing(now, 520);
      if (L.hp <= 0) Future.delayed(const Duration(milliseconds: 420), () => lnEnd(false));
      poke();
    }
  }

  void _lnWin() {
    final L = ln;
    if (L == null || L.phase != 'fight') return;
    final F = L.fight!, sec = math.min(2, L.step ~/ 3);
    _stat['foe'] = ((_stat['foe'] as num?) ?? 0) + 1;
    if (F.boss) {
      final o = _lnAdd({'parts': 12, 'plate': 6, 'batt': 2});
      String? it;
      if (rnd.nextDouble() < math.min(1, lnMult * 1.25 * (lnRole(L.team, 'sci') ? 1.2 : 1))) it = _lnItemPick();
      if (it != null) L.items.add(it);
      for (final id in L.team) {
        if (hasSv(id)) rec(id)!['xp'] = xpOf(id) + 25;
      }
      L.step = 12;
      L.best = 12;
      L.msg = '${jo(lnTowns[L.reg]!.boss, '을', '를')} 쓰러뜨렸다! · ${_lnTxt(o)}${it != null ? ' · ${gear[it]?.n ?? it}' : ''}';
      L.phase = 'done';
      sfx('win');
      poke();
      return;
    }
    final o = <String, int>{'scrap': 6 + sec * 3};
    if (rnd.nextDouble() < .35) o[rnd.nextDouble() < .5 ? 'wire' : 'med'] = 1;
    _lnAdd(o);
    L.phase = 'pick';
    L.msg = '재 괴물을 쓰러뜨렸다 · ${_lnTxt(o)}';
    sfx('chime');
    L.fight = null;
    _lnNext();
    poke();
  }

  /// 올라오기. safe=false면 챙긴 것 절반, 찾은 물건은 두고 온다
  void lnEnd(bool safe) {
    final u = ln;
    if (u == null) return;
    ln = null;
    if (S.rest['line'] is! Map) S.rest['line'] = <String, Object?>{};
    final L = ((S.rest['line'] as Map)[u.reg] ??= <String, Object?>{'fat': 0, 'at': 0, 'runs': 0, 'best': 0}) as Map;
    final fat = ((L['fat'] as num?) ?? 0).toInt(), m = lnFat[math.min(lnFat.length - 1, fat)];
    final scaled = <String, num>{};
    for (final e in u.carry.entries) {
      final v = safe ? e.value : e.value ~/ 2;
      if (v > 0) scaled[e.key] = math.max(1, jsRound(v * m));
    }
    // 쓰러져 나오면 다음 판을 조금 돕고, 무사히 나오면 돕기를 한 단계 줄인다
    S.rest['lnLose'] = safe ? math.max(0, lnAssist - 1) : math.min(3, lnAssist + 1);
    final got = give(scaled), items = safe ? u.items : const <String>[];
    for (final t in items) {
      addGear(t);
      if (S.rest['lnGot'] is! List) S.rest['lnGot'] = <Object?>[];
      final lg = S.rest['lnGot'] as List;
      if (!lg.contains(t)) lg.add(t);
    }
    if (u.step > 0) {
      L['runs'] = ((L['runs'] as num?) ?? 0) + 1;
      if (fat == 0) L['at'] = Game.nowMs();
      L['fat'] = math.min(lnFat.length - 1, fat + 1);
    }
    L['best'] = math.max(((L['best'] as num?) ?? 0).toInt(), math.max(u.best, u.step));
    recalc();
    final T = lnTowns[u.reg]!;
    fx.add(FxNote(
        safe ? (u.step >= 12 ? '${T.st[2]}에서 돌아왔어요' : '노선에서 무사히 돌아왔어요') : '지쳐서 급히 돌아왔어요',
        '${got.isNotEmpty ? lootText(got) : '챙긴 게 없어요'}${items.isNotEmpty ? ' · ${items.map((t) => gear[t]?.n ?? t).join(', ')}' : ''}${!safe && u.items.isNotEmpty ? ' · 찾은 물건을 두고 왔어요' : ''}${m < 1 ? ' · 보상 ×$m' : ''}',
        ms: 6500));
    _changed();
  }
}
