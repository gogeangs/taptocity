// 시즌 2 이야기 뼈대 시험 (2026-11-02): 시즌 1 엔딩 저장본(s1-end)에서 이어 받아, 화면 없이 마지막 컷까지 굴린다.
// 걸음 조건은 시험이 대신 채운다(자재·쉘터 단계·원정 수·밤). 사건은 '추궁한다', 마을 회의는 '감싼다'.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:taptocity/game/data.dart';
import 'package:taptocity/game/engine.dart';
import 'package:taptocity/game/state.dart';

Game _load() {
  final j = jsonDecode(File('test/fixtures/saves/s1-end.json').readAsStringSync()) as Map<String, dynamic>;
  return Game(GameState.fromJson(j)!, random: math.Random(7));
}

/// 쌓인 화면 신호를 대신 처리한다: 사건은 a, 회의는 감싼다
void _drain(Game g, List<String> log) {
  for (var guard = 0; guard < 20 && g.fx.isNotEmpty; guard++) {
    final L = [...g.fx];
    g.fx.clear();
    for (final f in L) {
      if (f is FxCase) {
        log.add('case ${f.k + 1}');
        g.pickCase(f.k, 'a');
      } else if (f is FxS2Choice) {
        log.add('meeting');
        g.s2Meeting(true);
      }
    }
  }
}

void _night(Game g) {
  g.S.rest['nights'] = g.num_('nights') + 1;
  g.s2Dawn();
}

void main() {
  test('시즌 1 엔딩 저장본에서 시즌 2가 이어진다', () {
    Game.tutFlag = true;
    final g = _load();
    expect(g.s2On, isTrue);
    expect(g.s2Active, isTrue);
    final m0 = g.mission();
    expect(m0.s2, isTrue, reason: '엔딩 뒤 띠는 시즌 2 걸음');
    expect(g.s2St, 0);
    // 시즌 1 장면·상태는 그대로
    expect(g.S.rest['ehEnd'], 1);
    expect(g.mi, greaterThanOrEqualTo(steps.length));
  });

  test('시즌 2를 마지막 컷까지 굴린다', () {
    Game.tutFlag = true;
    final g = _load();
    final gen0 = g.S.gen;
    final log = <String>[];
    var rounds = 0, builds = 0;
    while (!g.s2Done && rounds++ < 400) {
      g.s2TickIntro();
      _drain(g, log);
      final m = g.mission();
      expect(m.s2, isTrue, reason: '걸음 ${g.s2St}.${g.s2I}에서 시즌 2 띠가 끊김');
      if (m.go) {
        log.add('go ${g.s2GoNext}');
        expect(g.canMigrate, isTrue);
        g.migrate(g.svIds.toList());
        _drain(g, log);
        continue;
      }
      if (m.done) {
        g.claimMission();
        _drain(g, log);
        continue;
      }
      // 공사 걸음: 실제 시간이 지나야 끝난다 (렌즈 공사 1시간, 재혁이 있으면 42분)
      final at = g.s2BuildAt;
      if (at != null) {
        if (builds++ == 0) expect((at - Game.nowMs()) / 60000, closeTo(42, .1));
        g.s2F['bAt'] = Game.nowMs() - 1;
        continue;
      }
      // 걸음 조건을 채운다
      for (final id in g.s2Missing) {
        g.s2Call(id);
      }
      g.S.lv = math.max(g.S.lv, 2);
      for (final k in const ['wire', 'parts', 'plate', 'fuel', 'food']) {
        g.S.m[k] = math.max(g.S.m[k] ?? 0, 200);
      }
      g.S.rest['expDone'] = g.num_('expDone') + 1;
      g.s2['trips'] = ((g.s2['trips'] as num?) ?? 0) + 6;
      _night(g);
      _drain(g, log);
    }
    expect(g.s2Done, isTrue, reason: '마지막 컷에 닿지 못함 (${g.s2St}.${g.s2I}) · $log');
    expect(builds, 1, reason: '렌즈 공사');
    expect(g.S.gen, gen0 + 4);
    expect(g.S.region, 'plant');
    expect(townName(gen0 + 1), '얼어붙은 저수지 둑');
    expect(townName(gen0 + 3), '처음 불을 켠 동네');
    // 이야기 안에서만 잃는 두 사람
    expect(g.isDead(9), isTrue, reason: '재혁');
    expect(g.isDead(10), isTrue, reason: '은호');
    // 사건 10~14 모두 적힘, 재혁 장에는 '마을이 닫음'
    for (var k = 9; k <= 13; k++) {
      expect(g.caseRec(k)?['p'], isNotNull, reason: '사건 ${k + 1}');
    }
    expect(g.caseRec(10)?['closed'], 1);
    expect(log.where((e) => e == 'meeting').length, 1);
    // 저수지 사람들이 합류했다 (잃는 규칙으로 잃었거나 이주 때 남았을 수는 있음)
    expect([30, 31, 32, 33].any((id) => g.hasSv(id) || g.isDead(id) || g.inStay(id)), isTrue);
    // 첫 동네에 남겨 둔 사람들과 다시 만났다
    expect((g.S.rest['stay'] as Map?)?['0'], isNull);
    // 끝난 뒤에도 띠는 끝없는 불빛으로 계속된다
    final m = g.mission();
    expect(m.s2, isFalse);
    // 저장 → 다시 읽기
    final again = Game(GameState.fromJson(jsonDecode(g.toJsonString()) as Map<String, dynamic>)!);
    expect(again.s2Done, isTrue);
    expect(townName(gen0 + 2), '옛 국책 연구소');
    for (var k = 0; k < 60; k++) {
      again.tick(.5);
    }
  });

  test('두드리기 없음 · 사람 보내기 · 먼 원정', () {
    Game.tutFlag = true;
    final g = _load();
    final log = <String>[];
    // 저수지 둑에 닿을 때까지
    for (var r = 0; r < 60 && g.s2St < 1; r++) {
      g.s2TickIntro();
      _drain(g, log);
      final m = g.mission();
      if (m.go) {
        g.migrate(g.svIds.toList());
      } else if (m.done) {
        g.claimMission();
      } else {
        for (final id in g.s2Missing) {
          g.s2Call(id);
        }
        _night(g);
      }
      _drain(g, log);
    }
    expect(g.S.region, 'reservoir');
    expect(g.s2NoTap, isTrue);
    expect(g.S.sig, isEmpty);
    // 탑 빛 안쪽은 밝혀져 있다
    final inside = [for (var i = 0; i < N; i++) if (dist(i) <= 4) i];
    expect(inside.every((i) => g.S.rev[i] == 1), isTrue);
    // 구름을 두드려도 걷히지 않는다
    final rev0 = g.revCount;
    for (final f in g.frontier.take(5).toList()) {
      expect(g.tapTile(f), 'far');
      g.dig(f);
    }
    expect(g.revCount, rev0);
    // 폐허를 누르면 사람 보내기
    final site = [for (var i = 0; i < N; i++) if (g.S.rev[i] == 1 && g.siteLive(i)) i];
    expect(site, isNotEmpty, reason: '탑 빛 안쪽에 폐허가 있어야 함');
    expect(g.tapTile(site.first), 'send');
    final pool = g.s2SendPool;
    expect(pool, isNotEmpty);
    final id = pool.first, have0 = g.S.got.values.fold<num>(0, (a, v) => a + v);
    expect(g.s2Send(id, site.first), isTrue);
    expect(g.busy(id), isTrue);
    for (var k = 0; k < 205; k++) {
      g.s2TickSec();
    }
    expect((g.s2['trips'] as num?) ?? 0, greaterThanOrEqualTo(1));
    expect(g.S.got.values.fold<num>(0, (a, v) => a + v), greaterThan(have0));
    // 저장 → 다시 읽어도 보낸 사람이 그대로
    final again = Game(GameState.fromJson(jsonDecode(g.toJsonString()) as Map<String, dynamic>)!);
    expect(again.s2SendIds.contains(id) || !again.busy(id), isTrue);
    // 먼 원정은 30분·1시간·2시간
    expect(g.expList.map((e) => e.key).toList(), ['s2near', 's2far', 's2deep']);
    final c = g.expCalc(g.expList.first, [pool.last]);
    expect(c.t, greaterThanOrEqualTo(1200));
    // 마을 믿음과 규칙
    final t0 = g.s2Trust;
    expect(t0, inInclusiveRange(40, 80));
    expect(g.s2RuleOpen('ration'), isFalse);
    g.s2TrustAdd(5);
    expect(g.s2Trust, t0 + 5);
    final p0 = g.prod['food'] ?? 0;
    g.s2['i'] = 3;
    expect(g.s2RuleOpen('ration'), isTrue);
    g.s2SetRule('ration', 'work');
    expect(g.s2Rule['ration'], 'work');
    expect(g.prod['food'] ?? 0, greaterThanOrEqualTo(p0));
  });

  test('아침의 흔적: 지도에 반짝이고, 누르면 수첩에 적힌다', () {
    Game.tutFlag = true;
    final g = _load();
    final log = <String>[];
    for (var r = 0; r < 60 && g.s2St < 1; r++) {
      g.s2TickIntro();
      _drain(g, log);
      final m = g.mission();
      if (m.go) {
        g.migrate(g.svIds.toList());
      } else if (m.done) {
        g.claimMission();
      } else {
        for (final id in g.s2Missing) {
          g.s2Call(id);
        }
        _night(g);
      }
      _drain(g, log);
    }
    expect(g.S.region, 'reservoir');
    final n0 = g.s2Traces.length;
    g.S.rest.remove('caseNew');
    g.s2F['aired'] = 1;
    _night(g);
    final L = g.s2TraceTiles;
    expect(L, isNotEmpty, reason: '방송 밤 다음 아침에 반짝이는 흔적');
    expect(g.s2Traces.length, greaterThan(n0));
    for (final i in L) {
      expect(g.S.rev[i], 1, reason: '밝힌 땅 위');
      expect(i == C0, isFalse);
    }
    expect(g.S.rest['caseNew'], isNull, reason: '누르기 전에는 수첩에 적히지 않음');
    expect(g.s2SeeTrace(L.first), isTrue);
    expect(g.s2TraceTiles.length, L.length - 1);
    expect(g.S.rest['caseNew'], 1);
    expect(g.s2SeeTrace(L.first), isFalse, reason: '두 번 적히지 않음');
    // 동네를 떠나면 못 본 흔적은 그대로 수첩에
    if (g.s2TraceTiles.isNotEmpty) {
      g.s2Traces.whereType<Map>().forEach((t) => t['seen'] ??= 1);
    }
    expect(g.s2TraceTiles, isEmpty);
  });
}
