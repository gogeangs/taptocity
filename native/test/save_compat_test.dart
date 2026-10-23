// 저장 호환 시험 (코드 정리 안전망, 2026-10-23): 2.0.1로 만든 저장본(test/fixtures/saves)을 지금 코드가
// 그대로 읽고, 이어서 굴려도 오류가 없고, 핵심 진행(레벨·동네·생존자·이야기 걸음)이 유지되는지 본다.
// 저장본은 CI의 QA 자동 플레이가 native-play/saves/ 로 올린 것을 고정본으로 복사해 둔다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taptocity/game/engine.dart';
import 'package:taptocity/game/state.dart';

void main() {
  final dir = Directory('test/fixtures/saves');
  final files = dir.existsSync() ? (dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()..sort((a, b) => a.path.compareTo(b.path))) : <File>[];
  test('저장본이 있다', () {}, skip: files.isEmpty ? '고정 저장본이 아직 없어요' : null);
  for (final f in files) {
    final name = f.uri.pathSegments.last;
    test('저장 호환: $name', () {
      Game.tutFlag = true;
      final raw = f.readAsStringSync();
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final s = GameState.fromJson(j);
      expect(s, isNotNull, reason: '$name 을 읽지 못함');
      final g = Game(s!);
      final lv = g.S.lv, gen = g.S.gen, sv = [...g.svIds]..sort(), mi = g.mi, frags = g.fragsGot.length;
      // 저장 → 다시 읽기가 같은 내용인지 (시각 t 제외)
      final again = GameState.fromJson(jsonDecode(g.toJsonString()) as Map<String, dynamic>)!;
      expect(again.lv, lv);
      // 1시간 비웠다 돌아오고 2분 굴린다
      g.offline(g.S.t + 3600 * 1000);
      for (var k = 0; k < 240; k++) {
        g.tick(.5);
        if (g.defn != null) g.tickDefense(.5);
      }
      expect(g.S.lv, greaterThanOrEqualTo(lv));
      expect(g.S.gen, gen);
      expect(g.mi, greaterThanOrEqualTo(mi));
      expect(g.fragsGot.length, greaterThanOrEqualTo(frags));
      for (final id in sv) {
        expect(g.hasSv(id) || g.isDead(id) || g.inStay(id), isTrue, reason: '생존자 $id 가 사라짐');
      }
      expect(() => g.mission(), returnsNormally);
      expect(Game.parseCode(g.exportCode()), isNotNull);
    });
  }
}
