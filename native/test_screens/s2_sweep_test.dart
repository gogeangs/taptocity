// 시즌 2 화면 훑기 (2026-11-07 실기기 신고: 관리 창이 회색으로만 뜸 = 그리다 오류).
// 시즌 1 엔딩 저장본에서 시즌 2를 무대마다 진행하며, 아래 메뉴 다섯과 안쪽 칸을 모두 열어 오류를 모은다.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taptocity/game/engine.dart';
import 'package:taptocity/game/state.dart';
import 'package:taptocity/ui/atlas.dart';
import 'package:taptocity/ui/game_screen.dart';
import 'package:taptocity/ui/people.dart' show drawPerson;
import 'package:taptocity/ui/survivors.dart' show showCampPage, showSurvPage;
import 'package:taptocity/ui/theme.dart';

Game _load() {
  final j = jsonDecode(File('test/fixtures/saves/s1-end.json').readAsStringSync()) as Map<String, dynamic>;
  return Game(GameState.fromJson(j)!, random: math.Random(7));
}

void _drain(Game g) {
  for (var guard = 0; guard < 20 && g.fx.isNotEmpty; guard++) {
    final L = [...g.fx];
    g.fx.clear();
    for (final f in L) {
      if (f is FxCase) {
        g.pickCase(f.k, 'a');
      } else if (f is FxS2Choice) {
        g.s2Meeting(true);
      }
    }
  }
}

void _night(Game g) {
  g.S.rest['nights'] = g.num_('nights') + 1;
  g.s2Dawn();
}

/// 시즌 2를 한 걸음 진행 (season2_test와 같은 방식)
void _step(Game g) {
  g.s2TickIntro();
  _drain(g);
  final m = g.mission();
  if (m.go) {
    g.migrate(g.svIds.toList());
  } else if (m.done) {
    g.claimMission();
  } else {
    final at = g.s2BuildAt;
    if (at != null) {
      g.s2F['bAt'] = Game.nowMs() - 1;
    } else {
      for (final id in g.s2Missing) {
        g.s2Call(id);
      }
      g.S.lv = math.max(g.S.lv, 2);
      for (final k in const ['wire', 'parts', 'plate', 'fuel', 'food']) {
        g.S.m[k] = math.max(g.S.m[k] ?? 0, 200);
      }
      g.S.rest['expDone'] = g.num_('expDone') + 1;
      g.s2['trips'] = ((g.s2['trips'] as num?) ?? 0) + 6;
      g.s2F['aired'] = 1;
      _night(g);
    }
  }
  _drain(g);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final sans = FontLoader('TTCSans')..addFont(rootBundle.load('assets/fonts/ttc-sans.ttf'));
    await sans.load();
  });

  testWidgets('시즌 2 화면 훑기 · 회색 창(그리다 오류) 없음', (tester) async {
    await tester.runAsync(() async => Atlas.load());
    final errs = <String, int>{};
    var where = '';
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      final st = (d.stack?.toString() ?? '').split('\n').where((l) => l.contains('package:taptocity')).take(4).join(' ← ');
      final k = '$where · ${d.exceptionAsString().split('\n').first} @ $st';
      errs[k] = (errs[k] ?? 0) + 1;
    };
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;

    Future<void> settle() async {
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 80));
      }
    }

    Future<void> tapText(String t) async {
      final f = find.text(t);
      if (f.evaluate().isEmpty) return;
      try {
        await tester.tap(f.last, warnIfMissed: false);
      } catch (_) {}
      await settle();
    }

    final g = _load();
    // 무대마다 (0 산골의 아침 · 1 저수지 · 2 연구소 · 3 첫 동네 · 4 발전소) 걸음 몇 개씩 지나며 훑는다
    var rounds = 0, lastKey = -1;
    while (!g.s2Done && rounds++ < 400) {
      final key = g.s2St * 100 + g.s2I;
      if (key != lastKey && (g.s2I % 2 == 0)) {
        lastKey = key;
        final tag = '무대 ${g.s2St}.${g.s2I}';
        Future<void> home() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: Ttc.theme(), home: GameScreen(game: g)));
          await settle();
          for (var k = 0; k < 4; k++) {
            if (find.byType(Dialog).evaluate().isEmpty) break;
            Navigator.of(tester.element(find.byType(Dialog).last)).pop();
            await settle();
          }
        }

        for (final (tab, subs) in const [
          ('사람', <String>[]),
          ('원정', <String>[]),
          ('마을', ['건설', '가공', '연구', '창고', '꾸미기']),
          ('라디오', <String>[]),
          ('일지', ['기록', '기록>회상', '사건 수첩', '도감', '도감>노선도']),
        ]) {
          for (final s in ['', ...subs]) {
            where = '$tag · $tab${s.isEmpty ? '' : ' · $s'}';
            await home();
            await tapText(tab);
            for (final t in s.split('>')) {
              if (t.isNotEmpty) await tapText(t);
            }
            final lv = find.byType(Scrollable);
            if (lv.evaluate().isNotEmpty) {
              await tester.drag(lv.last, const Offset(0, -3000), warnIfMissed: false);
              await settle();
            }
            final ex = tester.takeException();
            if (ex != null) errs['$where · 예외 ${'$ex'.split('\n').first}'] = 1;
          }
        }
        // 구조 신호 창 (2026-11-07 실기기 회색 창: 저수지 사람들의 구조 사연이 없어서) · 생존자 창 네 탭
        for (final t in g.S.camp.keys.toList()) {
          where = '$tag · 구조 신호 ${(g.S.camp[t]?['id'])}';
          await home();
          showCampPage(tester.element(find.byType(GameScreen)), g, t);
          await settle();
          final ex = tester.takeException();
          if (ex != null) errs['$where · 예외 ${'$ex'.split('\n').first}'] = 1;
        }
        for (final id in g.svIds) {
          for (final tb in const ['정보', '성장', '장비', '이야기']) {
            where = '$tag · 생존자 $id · $tb';
            await home();
            showSurvPage(tester.element(find.byType(GameScreen)), g, id);
            await settle();
            await tapText(tb);
            final ex = tester.takeException();
            if (ex != null) errs['$where · 예외 ${'$ex'.split('\n').first}'] = 1;
          }
        }
      }
      _step(g);
      g.takeFx();
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = old;
    for (final e in errs.entries) {
      debugPrint('S2-SWEEP: ${e.key} ×${e.value}');
    }
    expect(errs, isEmpty, reason: errs.keys.take(12).join('\n'));
  });

  testWidgets('시즌 2 저수지 화면 사진 (2026-11-08 UI 다듬기 확인)', (tester) async {
    await tester.runAsync(() async {
      await Atlas.load();
      await Atlas.ensure('walkers-4.webp');
      await Atlas.ensure('residents-reservoir.webp');
      await Atlas.ensure('landmarks-reservoir.webp');
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final g = _load();
    for (var r = 0; r < 80 && g.s2St < 1; r++) {
      _step(g);
      g.takeFx();
    }
    // 판잣집까지 지나 중계등 걸음 (다리 구간 · 전선 2 · 철판 0)
    for (var r = 0; r < 20 && g.s2St == 1 && g.s2I < 1; r++) {
      _step(g);
      g.takeFx();
    }
    g.S.m['wire'] = 2;
    g.S.m['plate'] = 0;
    Future<void> shot(String name) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: Ttc.theme(), home: GameScreen(game: g)));
      for (var k = 0; k < 8; k++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      for (var k = 0; k < 4; k++) {
        if (find.byType(Dialog).evaluate().isEmpty) break;
        Navigator.of(tester.element(find.byType(Dialog).last)).pop();
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
      final f = File('test_screens/shots/$name.png');
      if (f.existsSync()) {
        final b = base64Encode(f.readAsBytesSync());
        for (var i = 0; i < b.length; i += 900) {
          debugPrint('SHOT64:$name ${b.substring(i, math.min(b.length, i + 900))}');
        }
      }
    }

    await shot('s2-res-bridge');
    // 점화 뒤 (꺼진 랜턴 · 하루 부탁 바)
    g.S.m['wire'] = 50;
    g.S.m['plate'] = 50;
    g.S.m['parts'] = 100;
    g.claimMission();
    g.takeFx();
    await shot('s2-res-after');
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('지도 인물 사진 · 저수지 사람도 손그림 (2026-11-08)', (tester) async {
    await tester.runAsync(() async {
      await Atlas.load();
      await Atlas.ensure('walkers-4.webp');
    });
    tester.view.physicalSize = const Size(900, 240);
    tester.view.devicePixelRatio = 1;
    // 칸 테두리 재기는 비동기라 한 번 그려 두고 기다린다
    Widget board() => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Container(color: const Color(0xFFC8CDD2), child: CustomPaint(size: const Size(900, 240), painter: _People())));
    await tester.pumpWidget(board());
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(board());
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/s2-walkers.png'));
    // 실행 기록에서 바로 볼 수 있게 (내려받기가 막힌 곳에서 확인용)
    final f = File('test_screens/shots/s2-walkers.png');
    if (f.existsSync()) {
      final b = base64Encode(f.readAsBytesSync());
      for (var i = 0; i < b.length; i += 900) {
        debugPrint('WK64 ${b.substring(i, math.min(b.length, i + 900))}');
      }
    }
  });
}

class _People extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    const ids = [18, 19, 20, 21, 27, 30, 31, 32, 33];
    c.scale(3);
    for (var i = 0; i < ids.length; i++) {
      drawPerson(c, ids[i], 16 + i * 32.0, 70, 0, false, 1, null);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => true;
}
