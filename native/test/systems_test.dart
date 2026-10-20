// 앱 전용 장치(끝없는 지하·기록 조각·인연·오늘의 의뢰·오프라인 회복·긴장감)를 화면 없이 바로 두드려 보는 시험.
// 시드를 정해 두고(Game(.., random: Random(seed))), 시각은 Game.nowMs를 바꿔 끼운다.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:taptocity/game/data.dart';
import 'package:taptocity/game/engine.dart';
import 'package:taptocity/game/state.dart';
import 'package:taptocity/ui/map_view.dart';

/// 중반 판: 판잣집 넘어 컨테이너(Lv.3), 재폭풍 밤을 배운 뒤(긴장 장치·오늘의 의뢰가 켜짐), 튜토리얼·안내 끝
Game mk(int seed, List<int> ids, {int lv = 3, num xp = 0}) {
  final s = Game.fresh(seed: seed, random: math.Random(seed));
  s.lv = lv;
  final mi = stepI('생존자 5명 모으기');
  s.rest['mi'] = mi;
  s.rest['storyI'] = mi;
  s.rest['pfAsk'] = 1;
  s.rest['tutSeen'] = 1;
  s.rest['hintDef1'] = 1;
  for (final id in ids) {
    s.sv['$id'] = <String, Object?>{'xp': xp, 'at': -1};
  }
  s.rest['party'] = <Object?>[...ids.take(3)];
  s.m['food'] = 5000;
  s.m['fuel'] = 200;
  s.m['parts'] = 200;
  return Game(s, random: math.Random(seed));
}

/// 그 날짜(기기 시간대) 정오 등
int ms(int day, [int h = 12, int m = 0, int s = 0]) => DateTime(2026, 3, day, h, m, s).millisecondsSinceEpoch;

String shortName(int id) {
  final n = survivors[id].name;
  return n.length == 3 && id != 19 ? n.substring(1) : n;
}

/// 오늘의 의뢰 세 개를 모두 끝낸다 (날짜가 바뀐 첫 틱에 새 의뢰 → 다 모은 것으로 → 다음 틱에 보상)
void finishToday(Game g) {
  g.tick(1);
  final q = g.dayQ;
  expect(q, isNotNull);
  expect(q!['d'], g.todayKey);
  final list = q['q'] as List;
  expect(list.length, 3);
  for (final x in list) {
    final m = x as Map;
    m['p'] = m['n'];
  }
  g.tick(1);
  expect(g.dayAllDone, isTrue);
}

int invCount(Game g, String t) => g.inv.where((x) => x['t'] == t).length;

void main() {
  Game.tutFlag = true;
  final realNow = Game.nowMs;
  var now = ms(1);
  setUp(() {
    now = ms(1);
    Game.nowMs = () => now;
  });
  tearDown(() => Game.nowMs = realNow);

  test('중반 판 준비: 긴장 장치·오늘의 의뢰·지하가 열려 있다', () {
    final g = mk(1, [0, 3]);
    expect(g.tensionOn, isTrue);
    // 앱 전용 (2026-10-20): 첫 동네 지하·오늘의 할 일은 5장 첫 걸음부터 열린다 (그 전엔 닫힘)
    expect(g.dayOn, isFalse);
    expect(g.ugOpen, isFalse);
    g.S.rest['mi'] = stepI('지하 구역 2층까지 내려가기');
    expect(g.ugOpen, isTrue);
    expect(g.dayOn, isTrue);
    g.S.rest['mi'] = stepI('생존자 5명 모으기');
    expect(g.heal, 1);
  });

  test('끝없는 지하: 17층 → 42층 (재괴물 20·30·40층), 조각 12개까지', () {
    final g = mk(11, [0, 3, 4, 5, 6, 13]);
    g.S.rest['conf'] = 'a'; // 재혁의 조각도 나올 수 있게
    // 조각은 한 번이라도 함께한 사람의 것만 나온다: 나머지 주인은 함께했다가 잃은 사람으로
    g.S.rest['dead'] = <Object?>[for (final f in frags) if (!g.hasSv(f.$1)) <String, Object?>{'id': f.$1}];
    // 이야기 물건(quest) 칸이 칸을 모자라게 하지 않도록 찾기 걸음이 없는 사람으로
    final team = [for (final id in g.svIds) if (g.qStep(id)?['k'] != 'find') id].take(3).toList();
    expect(team.length, 3);
    expect(g.ugStart(team, g.ugFuelMax(team), ugDeep), isTrue);
    expect(g.ug!.floor, ugDeep);

    final bosses = <int>[];
    void down() {
      final u = g.ug!;
      final f = u.floor;
      final i = u.cells.indexWhere((c) => c.c == 'stairs');
      expect(i, greaterThanOrEqualTo(0), reason: '지하 $f층에 계단이 없어요');
      u.cells[i].rev = true;
      u.oil = 999;
      g.ugTap(i);
      expect(g.ug, isNotNull);
      expect(g.ug!.floor, f + 1);
      final nf = g.ug!.floor;
      final hasBoss = g.ug!.cells.any((c) => c.boss);
      expect(hasBoss, ugBossFloor(nf), reason: '지하 $nf층 재괴물');
      if (!ugBossFloor(nf)) return;
      final bi = g.ug!.cells.indexWhere((c) => c.boss && c.c == 'foe');
      expect(bi, greaterThanOrEqualTo(0), reason: '지하 $nf층 재괴물 칸이 다른 칸에 덮였어요');
      final bc = g.ug!.cells[bi];
      expect(bc.fhp, greaterThan(0));
      bc.rev = true;
      final before = g.fragsGot.length;
      for (var n = 0; n < 500 && bc.fhp > 0; n++) {
        g.ug!.oil = 999;
        g.ugTap(bi);
      }
      expect(bc.fhp, 0);
      // 쓰러뜨리면 조각 하나 (다 모았으면 그대로)
      expect(g.fragsGot.length, before < frags.length ? before + 1 : frags.length, reason: '지하 $nf층 재괴물 조각');
      bosses.add(nf);
    }

    while (g.ug!.floor < 42) {
      down();
    }
    expect(bosses, [20, 30, 40]);
    expect(g.ugBest, 42);
    expect((g.ugRec['last'] as num).toInt(), 42);

    // 더 내려가며 조각을 다 모은다 (재괴물 10층마다 + 계단참 8%)
    while (g.fragsGot.length < frags.length && g.ug!.floor < 400) {
      down();
    }
    expect(g.fragsGot.length, frags.length);
    // 다 모은 뒤의 재괴물: 조각 없이 (fragDrop -1)
    final nb = bosses.length;
    while (bosses.length == nb && g.ug!.floor < 420) {
      down();
    }
    expect(bosses.length, nb + 1);
    expect(g.fragsGot.length, frags.length);
    expect(g.fragsGot.toSet().length, g.fragsGot.length, reason: '조각이 겹쳤어요');
    expect(g.fragsGot.every((k) => k >= 0 && k < frags.length), isTrue);
    expect(g.ugBest, g.ug!.floor);
    g.ugEnd(true);
    expect(g.ug, isNull);
    expect(g.takeFx(), isNotEmpty);
  });

  test('기록 조각: 함께 있는 사람의 것부터, 재혁의 것은 고백을 들은 뒤에만', () {
    final g = mk(21, [0, 3, 9]);
    expect(g.conf, isNull);
    int owner(int k) => frags[k].$1;
    final a = g.fragDrop(), b = g.fragDrop();
    expect({owner(a), owner(b)}, {0, 3});
    // 한 번도 만나지 못한 사람의 조각은 나오지 않는다 (재혁은 고백 전)
    expect(g.fragDrop(), -1);
    // 함께했다가 잃은 사람의 것은 나온다
    g.S.rest['dead'] = <Object?>[for (final f in frags) if (!{0, 3, 9}.contains(f.$1)) <String, Object?>{'id': f.$1}];
    // 그다음은 다른 사람의 것 (재혁의 것은 빼고)
    for (var n = 0; n < frags.length; n++) {
      final k = g.fragDrop();
      if (k < 0) break;
      expect(owner(k), isNot(9));
    }
    expect(g.fragsGot.length, frags.length - 1);
    expect(g.fragDrop(), -1);
    g.S.rest['conf'] = 'a';
    final j = g.fragDrop();
    expect(j, greaterThanOrEqualTo(0));
    expect(owner(j), 9);
    expect(g.fragDrop(), -1);
    expect(g.fragsGot.toSet().length, frags.length);
  });

  test('인연: 신뢰도 5 뒤로 1~5단계, 단계마다 장면, 3단계 고유 장비는 한 번', () {
    final ids = [0, 3, 4, 5, 6, if (survivors.length > 17) 17];
    final g = mk(31, ids, xp: trustXp.last);
    g.tick(1);
    g.takeFx();
    for (final id in ids) {
      expect(g.bondLv(id), 0);
      expect(g.rec(id)!['bondN'], 0);
    }
    for (final id in ids) {
      final nm = survivors[id].name;
      for (var n = 1; n <= bondCum.length; n++) {
        g.rec(id)!['xp'] = trustXp.last + bondCum[n - 1];
        g.tick(1);
        final fx = g.takeFx();
        expect(g.bondLv(id), n, reason: '$nm 인연');
        expect(g.rec(id)!['bondN'], n, reason: '$nm 알린 인연');
        expect(fx.whereType<FxTalk>().where((f) => (f.tag ?? '').startsWith('인연 Lv.$n · $nm')).length, 1, reason: '$nm 인연 $n 장면');
        expect(fx.whereType<FxNote>().where((f) => f.h == '$nm의 고유 장비').length, n == 3 ? 1 : 0, reason: '$nm 인연 $n 고유 장비 알림');
        expect(invCount(g, bondGearOf[id]!), n >= 3 ? 1 : 0, reason: '$nm 인연 $n 고유 장비');
      }
      expect(g.rec(id)!['bondG'], 1);
      expect(g.bondNext(id), isNull);
    }
    // 더 돌려도 장비는 그대로 한 개
    for (var k = 0; k < 3; k++) {
      g.tick(1);
    }
    for (final id in ids) {
      expect(invCount(g, bondGearOf[id]!), 1);
    }
    expect(g.bondN, ids.length);
  });

  test('인연: 옛 저장(이미 3단계 넘음)은 조용히 맞추고 고유 장비만 한 번', () {
    final g = mk(32, [0], xp: trustXp.last + bondCum[3]);
    g.tick(1);
    final fx = g.takeFx();
    expect(g.rec(0)!['bondN'], 4);
    expect(invCount(g, 'bdHandle'), 1);
    expect(fx.whereType<FxTalk>().where((f) => (f.tag ?? '').startsWith('인연 Lv.')), isEmpty);
    g.rec(0)!['xp'] = trustXp.last + bondCum[4];
    g.tick(1);
    expect(g.rec(0)!['bondN'], 5);
    expect(invCount(g, 'bdHandle'), 1);
  });

  test('인연 선물: 한 사람에게 실제 날짜 하루 한 번, 다친 사람은 받지 않는다', () {
    final g = mk(33, [0, 6], xp: trustXp.last);
    final food0 = g.have('food');
    expect(g.gift(0), isTrue);
    expect(g.xpOf(0), trustXp.last + bondGiftXp);
    expect(g.have('food'), food0 - bondGiftCost['food']!);
    expect(g.bondGiftedToday(0), isTrue);
    expect(g.gift(0), isFalse);
    expect(g.xpOf(0), trustXp.last + bondGiftXp);
    // 다른 사람은 같은 날에도
    expect(g.bondGift(6), isTrue);
    // 같은 날 밤 11시 59분에도 안 된다
    now = ms(1, 23, 59, 59);
    expect(g.gift(0), isFalse);
    // 자정이 지나면 다시
    now = ms(2, 0, 0, 1);
    expect(g.bondGiftedToday(0), isFalse);
    expect(g.gift(0), isTrue);
    expect(g.xpOf(0), trustXp.last + 2 * bondGiftXp);
    expect(g.num_('giftN'), 3);
    // 다친 사람
    now = ms(3);
    g.rec(6)!['hurt'] = 50.0;
    final x6 = g.xpOf(6);
    expect(g.bondGift(6), isFalse);
    expect(g.xpOf(6), x6);
  });

  test('오늘의 의뢰: 7일 연속 → 귀한 장비, 하루 거르면 0부터 (벌 없음), 자정에 새 의뢰', () {
    final g = mk(41, [0, 3, 5, 6]);
    g.S.rest['mi'] = stepI('지하 구역 2층까지 내려가기');
    expect(g.dayOn, isTrue);
    for (var d = 1; d <= 7; d++) {
      now = ms(d);
      final inv0 = g.inv.length;
      finishToday(g);
      expect(g.dayStreak, d);
      expect(g.dayLast, dayKeyOf(now));
      expect(g.streakShown, d);
      if (d == 7) {
        final fx = g.takeFx();
        expect(fx.whereType<FxNote>().where((f) => f.h.startsWith('연속 7일')).length, 1);
        expect(g.num_('dayRare'), 1);
        final added = g.inv.skip(inv0).map((x) => x['t'] as String).toList();
        expect(added.where((t) => gear[t]!.g == 3 && !gear[t]!.sig).length, 1, reason: '7일째 귀한 장비: $added');
      } else {
        g.takeFx();
      }
    }
    // 8일째(3/8)를 거르고 3/9
    now = ms(9);
    expect(g.streakShown, 0);
    // 벌은 없다: 건전지·장비·신뢰는 그대로
    final batt0 = g.have('batt'), inv0 = g.inv.length, xp0 = {for (final id in g.svIds) id: g.xpOf(id)};
    g.tick(1);
    expect(g.dayStreak, 0);
    expect(g.takeFx().whereType<FxNote>().where((f) => f.t.contains('연속이 처음부터')).length, 1);
    expect(g.have('batt'), greaterThanOrEqualTo(batt0));
    expect(g.inv.length, inv0);
    for (final e in xp0.entries) {
      expect(g.xpOf(e.key), greaterThanOrEqualTo(e.value));
    }
    // 그날 다 하면 1일부터
    final q = g.dayQ!;
    for (final x in q['q'] as List) {
      final m = x as Map;
      m['p'] = m['n'];
    }
    g.tick(1);
    expect(g.dayStreak, 1);
    // 자정: 23:59:58의 의뢰 → 00:00:01에 새 의뢰
    now = ms(10, 23, 59, 58);
    g.tick(1);
    expect(g.dayQ!['d'], 20260310);
    ((g.dayQ!['q'] as List).first as Map)['p'] = 1;
    now = ms(11, 0, 0, 1);
    g.tick(1);
    final q2 = g.dayQ!;
    expect(q2['d'], 20260311);
    expect(q2['all'], 0);
    for (final x in q2['q'] as List) {
      expect((x as Map)['p'], 0);
      expect(x['ok'], 0);
    }
    expect(g.dayList.length, 3);
    expect(g.dayStreak, 0); // 3/10을 다 하지 않았으니
  });

  test('오프라인 회복: 비운 시간만큼 낫는다 (더딘 회복은 절반)', () {
    final g = mk(51, [0, 5, 6]);
    final base = ms(5, 9);
    g.S.t = base;
    expect(g.heal, 1);
    g.rec(6)!['hurt'] = 300.0;
    g.rec(6)!['hurtBy'] = 'night';
    g.offline(base + 120 * 1000);
    expect((g.rec(6)!['hurt'] as num).toDouble(), closeTo(180, 1e-9));
    expect(g.S.t, base + 120 * 1000);
    g.offline(g.S.t + 400 * 1000);
    expect(g.rec(6)!['hurt'], 0);
    expect(g.rec(6)!.containsKey('hurtBy'), isFalse);
    // 더딘 회복
    g.rec(0)!['hurt'] = 300.0;
    g.rec(0)!['slow'] = 1;
    g.offline(g.S.t + 120 * 1000);
    expect((g.rec(0)!['hurt'] as num).toDouble(), closeTo(240, 1e-9));
    expect(g.rec(0)!['slow'], 1);
    // 30분 넘게 비우면 아침 보고에 나은 사람 이름
    g.rec(6)!['hurt'] = 300.0;
    g.takeFx();
    g.offline(g.S.t + 2000 * 1000);
    expect(g.rec(6)!['hurt'], 0);
    expect(g.rec(0)!['hurt'], 0);
    expect(g.rec(0)!.containsKey('slow'), isFalse);
    final mr = g.takeFx().whereType<FxTalk>().where((f) => (f.tag ?? '').startsWith('아침 보고')).toList();
    expect(mr.length, 1);
    expect(mr.first.lines.any((l) => l.t.contains(shortName(6))), isTrue, reason: mr.first.lines.map((l) => l.t).join(' / '));
    expect(g.num_('mrN'), 1);
  });

  test('긴장: 못 막은 밤에 쉘터에 있는 안 다친 사람 하나만 다친다', () {
    for (var seed = 1; seed <= 6; seed++) {
      final g = mk(60 + seed, [0, 3, 4, 5, 6]);
      g.rec(6)!['hurt'] = 999.0;
      g.rec(3)!['away'] = 'exp';
      g.defn = Defense(null);
      g.endDefense(false);
      expect(g.defn, isNull);
      final newly = [for (final id in g.svIds) if (id != 6 && ((g.rec(id)!['hurt'] as num?) ?? 0) > 0) id];
      expect(newly.length, 1, reason: '시드 $seed: $newly');
      expect(newly.first, isNot(3), reason: '자리에 없는 사람은 다치지 않아요');
      expect((g.rec(newly.first)!['hurt'] as num).toDouble(), cycleLen);
      expect(g.rec(newly.first)!['hurtBy'], 'night');
      expect(g.rec(6)!['hurt'], 999.0);
      expect(((g.S.rest['stat'] as Map)['hurtN'] as num).toInt(), 1);
      expect(g.takeFx().whereType<FxTalk>().where((f) => (f.tag ?? '').startsWith('폭풍이 지나간 새벽')).length, 1);
    }
    // 판잣집 전(긴장 장치가 꺼짐)에는 아무도 다치지 않는다
    final g0 = mk(70, [0, 5, 6], lv: 1);
    expect(g0.tensionOn, isFalse);
    g0.defn = Defense(null);
    g0.endDefense(false);
    expect(g0.svIds.where((id) => ((g0.rec(id)!['hurt'] as num?) ?? 0) > 0), isEmpty);
  });

  test('긴장: 고르지 않은 선택은 해 질 녘에 첫 번째로 정해진다', () {
    final g = mk(71, [2, 3, 4]);
    g.rec(3)!['hurt'] = 500.0;
    g.rec(4)!['hurt'] = 400.0;
    g.S.rest['clock'] = 20.0;
    g.S.rest['choice'] = <String, Object?>{'k': 'med', 'a': 3, 'b': 4, 'v': '', 'day': g.dayN};
    g.tick(1);
    expect(g.isNight, isFalse);
    expect(g.choice, isNotNull);
    expect(g.takeFx().whereType<FxChoice>().length, 1);
    expect(g.choiceView()?.opts.length, 2);
    // 낮 동안에는 그대로
    g.tick(1);
    expect(g.choice, isNotNull);
    // 해 질 녘
    g.S.rest['clock'] = dayLen - .5;
    g.tick(1);
    expect(g.isNight, isTrue);
    expect(g.choice, isNull);
    expect(g.rec(3)!['hurt'], 0);
    expect(g.rec(3)!.containsKey('slow'), isFalse);
    expect((g.rec(4)!['hurt'] as num) > 0, isTrue);
    expect(g.rec(4)!['slow'], 1);
    expect(g.S.rest['choice_med'], 3);
    expect(((g.S.rest['stat'] as Map)['choiceN'] as num).toInt(), 1);
    expect(g.takeFx().whereType<FxNote>().where((f) => f.h == '약 한 알').length, 1);
  });

  test('긴장: 엉뚱한 사람을 추궁하면 신뢰가 깎이고, 이틀 뒤 사과로 잃은 만큼 + 20', () {
    final k = [for (var i = 0; i < cases.length; i++) i].firstWhere((i) => !cases[i].tut && !cases[i].all && cases[i].sus != null);
    final sid = cases[k].sus!;
    final g = mk(81, {0, sid}.toList(), xp: 300);
    g.S.rest['medKin'] = 1; // 약 한 알(하늘·순례) 선택이 끼어들지 않게
    g.pickCase(k, 'a');
    expect(g.xpOf(sid), 240);
    final due = (g.S.rest['sorry_$sid'] as num).toInt();
    expect(due, g.dayN + 2);
    expect(g.S.rest['sorryXp_$sid'], 60);
    num? gained;
    var dayAt = -1;
    for (var sec = 0; sec < 3 * cycleLen.toInt() + 60; sec++) {
      final x0 = g.xpOf(sid);
      g.tick(1);
      if (!g.S.rest.containsKey('sorry_$sid')) {
        gained = g.xpOf(sid) - x0;
        dayAt = g.dayN;
        expect(g.isNight, isFalse);
        expect(g.takeFx().whereType<FxTalk>().where((f) => (f.tag ?? '').startsWith('사과 · ${survivors[sid].name} 신뢰 +80')).length, 1);
        break;
      }
    }
    expect(gained, 80);
    expect(dayAt, greaterThanOrEqualTo(due));
    expect(g.S.rest.containsKey('sorryXp_$sid'), isFalse);
  });

  test('저장 왕복: 조각·연속 일수·인연·부상이 그대로', () {
    final g = mk(91, [0, 3, 6]);
    g.S.rest['mi'] = stepI('지하 구역 2층까지 내려가기');
    g.S.rest['conf'] = 'a';
    for (var n = 0; n < 3; n++) {
      g.fragDrop();
    }
    g.rec(0)!['xp'] = trustXp.last + bondCum[2];
    for (var d = 1; d <= 2; d++) {
      now = ms(d);
      finishToday(g);
    }
    expect(g.dayStreak, 2);
    expect(g.bondLv(0), 3);
    expect(g.rec(0)!['bondN'], 3);
    expect(invCount(g, 'bdHandle'), 1);
    g.rec(6)!['hurt'] = 123.5;
    g.rec(6)!['slow'] = 1;
    g.takeFx();

    final a = g.toJsonString();
    final s2 = GameState.fromJson(jsonDecode(a) as Map<String, dynamic>);
    expect(s2, isNotNull);
    final g2 = Game(s2!, random: math.Random(1));
    expect(g2.fragsGot, g.fragsGot);
    expect(g2.fragsGot.length, 3);
    expect(g2.dayStreak, 2);
    expect(g2.dayLast, g.dayLast);
    expect(g2.dayAllDone, isTrue);
    expect(g2.bondLv(0), 3);
    expect(g2.rec(0)!['bondN'], 3);
    expect(g2.rec(0)!['bondG'], 1);
    expect(invCount(g2, 'bdHandle'), 1);
    expect(g2.rec(6)!['hurt'], 123.5);
    expect(g2.rec(6)!['slow'], 1);
    final b = jsonEncode(s2.toJson());
    expect(jsonEncode((jsonDecode(b) as Map)..remove('t')), jsonEncode((jsonDecode(a) as Map)..remove('t')));
    // 읽은 판도 계속 돈다
    g2.tick(1);
    expect(g2.dayStreak, 2);
    expect(Game.parseCode(g2.exportCode()), isNotNull);
  });

  test('텐트 그림 윗부분·이름표를 눌러도 텐트가 잡힌다 (2026-10-20 실기기 신고)', () {
    final g = Game(Game.fresh(seed: 3, random: math.Random(3)));
    final cam = Camera();
    final p = MapPainter(g, cam, cam);
    final c = tileC(C0);
    expect(p.bldAt(c), C0); // 칸 가운데
    expect(p.bldAt(c.translate(0, -30)), C0); // 텐트 몸통 위쪽 (뒤 칸 자리)
    expect(p.bldAt(c.translate(8, -46)), C0); // 이름표
    expect(p.bldAt(c.translate(0, -140)), -1); // 한참 위 하늘
    expect(pickTile(c.translate(0, -30)) == C0, isFalse); // 예전에는 뒤 칸이 잡혔다
  });

  test('같은 안내는 겹쳐 쌓이지 않고, 제목 카드는 잠시 뒤 제목만 남는다', () {
    final c = FxLayerController();
    for (var k = 0; k < 3; k++) {
      c.toast('빛이 새는 구름이나 폐허를 두드려 보세요');
    }
    expect(c.toasts.length, 1);
    c.toast('다른 안내');
    expect(c.toasts.length, 2);
    c.note('박만수 · 부탁 1/3', '대사', ms: 5200);
    final n = c.toasts.last;
    expect(n.folded, isFalse);
    c.step(.1);
    for (var k = 0; k < 25; k++) {
      c.step(.1);
    }
    expect(n.folded, isTrue);
  });
}
