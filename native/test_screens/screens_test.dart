// 화면 사진: 실제 그림·글꼴로 주요 화면을 그려 PNG로 남긴다 (CI가 native-play/shots/ 에 올림).
// 실행: flutter test test_screens --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taptocity/game/data.dart';
import 'package:taptocity/game/engine.dart';
import 'package:taptocity/ui/atlas.dart';
import 'package:taptocity/ui/game_screen.dart';
import 'package:taptocity/ui/map_view.dart';
import 'package:taptocity/ui/theme.dart';

Future<void> _fonts() async {
  final sans = FontLoader('TTCSans')..addFont(rootBundle.load('assets/fonts/ttc-sans.ttf'));
  await sans.load();
  final serif = FontLoader('GowunBatang')
    ..addFont(rootBundle.load('assets/fonts/GowunBatang-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/GowunBatang-Bold.ttf'));
  await serif.load();
}

/// 사진용 진행: 쉘터 Lv.2, 모듈 몇 개, 생존자 셋, 구조 캠프 하나
Game _demo() {
  final g = Game(Game.fresh(seed: 42));
  final S = g.S;
  S.m.addAll({'wood': 140, 'scrap': 90, 'cloth': 40, 'parts': 12, 'fuel': 6, 'food': 60, 'plate': 8, 'rope': 3});
  // 쉘터 둘레를 밝힘
  for (var y = CY - 4; y <= CY + 4; y++) {
    for (var x = CX - 4; x <= CX + 4; x++) {
      if (S.rev[y * W + x] == 0) g.reveal(y * W + x);
    }
  }
  g.buildMod(1);
  g.buildMod(2);
  g.buildMod(9);
  S.lv = 2;
  g.recalc();
  for (final id in [0, 1, 3]) {
    g.rescue(id, 'sig');
  }
  final tiles = g.modAt.keys.toList();
  g.assign(tiles[0], 0);
  g.assign(tiles[2], 1);
  g.rec(0)!['xp'] = 180;
  g.S.m.addAll({'wood': 140, 'scrap': 90, 'cloth': 40, 'food': 60});
  g.takeFx();
  return g;
}

Future<void> _shot(WidgetTester tester, Game g, String name, {Future<void> Function()? act}) async {
  tester.view.physicalSize = const Size(750, 1624);
  tester.view.devicePixelRatio = 2;
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: Ttc.theme(), home: GameScreen(game: g)));
  await tester.pump(const Duration(milliseconds: 50));
  if (act != null) await act();
  for (var k = 0; k < 10; k++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _fonts();
  });

  testWidgets('화면 사진', (tester) async {
    await tester.runAsync(() async {
      await Atlas.load();
    });
    await _shot(tester, Game(Game.fresh(seed: 42)), '01-start');
    final g = _demo();
    await _shot(tester, g, '02-map');
    await _shot(tester, g, '03-shelter', act: () async {
      await tester.tap(find.text('쉘터').last);
    });
    await _shot(tester, g, '04-survivors', act: () async {
      await tester.tap(find.text('생존자').last);
    });
    await _shot(tester, g, '05-survivor-page', act: () async {
      await tester.tap(find.text('생존자').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text(survivors[0].name).first);
    });
    await _shot(tester, g, '07-ring', act: () async {
      final r = tester.getRect(find.byType(MapView));
      final z = (r.width / (TW * 4.2)).clamp(.6, 2.2).toDouble();
      final w = tileC(g.modAt.keys.first, 10);
      final p = r.topLeft + Offset(w.dx * z + r.width / 2, (w.dy - ((CX + CY + 1) * TH / 2 - 10)) * z + r.height / 2);
      await tester.tapAt(p);
    });
    await _shot(tester, g, '06-diary', act: () async {
      await tester.tap(find.text('일지').last);
    });
  });
}
