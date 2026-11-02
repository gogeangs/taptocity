// 시즌 2 이야기 뼈대 시험 (2026-11-02): 시즌 1 엔딩 저장본(s1-end)에서 이어 받아, 화면 없이 마지막 컷까지 굴린다.
// 걸음 조건은 시험이 대신 채운다(자재·쉘터 단계·원정 수·밤). 사건은 '추궁한다', 마을 회의는 '감싼다'.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
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
    var rounds = 0;
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
      // 걸음 조건을 채운다
      for (final id in g.s2Missing) {
        g.s2Call(id);
      }
      g.S.lv = math.max(g.S.lv, 2);
      for (final k in const ['wire', 'parts', 'plate', 'fuel', 'food']) {
        g.S.m[k] = math.max(g.S.m[k] ?? 0, 200);
      }
      g.S.rest['expDone'] = g.num_('expDone') + 1;
      _night(g);
      _drain(g, log);
    }
    expect(g.s2Done, isTrue, reason: '마지막 컷에 닿지 못함 (${g.s2St}.${g.s2I}) · $log');
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
    // 저수지 사람들이 합류했다 (잃는 규칙으로 빠졌을 수는 있음)
    expect([30, 31, 32, 33].any((id) => g.hasSv(id) || g.isDead(id)), isTrue);
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
}
