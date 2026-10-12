// 화면 사진: 실제 그림·글꼴로 주요 화면을 그려 PNG로 남긴다 (CI가 native-play/shots/ 에 올림).
// 실행: flutter test test_screens --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taptocity/game/data.dart';
import 'package:taptocity/game/engine.dart';
import 'package:taptocity/ui/atlas.dart';
import 'package:taptocity/ui/game_screen.dart';
import 'package:taptocity/ui/lines_ui.dart';
import 'package:taptocity/ui/map_view.dart';
import 'package:taptocity/ui/theme.dart';

Future<void> _fonts() async {
  final sans = FontLoader('TTCSans')..addFont(rootBundle.load('assets/fonts/ttc-sans.ttf'));
  await sans.load();
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
  g.S.m.addAll({'wood': 140, 'scrap': 90, 'cloth': 40, 'food': 60, 'parts': 30, 'batt': 3});
  // 스킬 바 둘, 한 명은 대기 중
  g.party = [0, 3];
  g.S.rest['cd'] = <String, Object?>{'3': 20.0};
  // 장비 몇 개
  for (final t in ['shovel', 'coverall', 'photo', 'shovel', 'hammer']) {
    g.addGear(t);
  }
  final shovel = g.inv.first['u'];
  g.equip(0, 'tool', shovel);
  // 이야기: 2장 '방벽 세우기'까지 본 상태
  S.rest['mi'] = stepI('방벽 세우기');
  S.rest['storyI'] = g.mi;
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
      for (final f in ['story-1.webp', 'story-2.webp', 'story-3.webp', 'story-4.webp', 'story-5.webp', 'founder-expressions.webp', 'underground-icons.webp', 'crows-kids.webp']) {
        await Atlas.ensure(f);
      }
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
    await _shot(tester, g, '08-survivor-grow', act: () async {
      await tester.tap(find.text('생존자').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text(survivors[0].name).first);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('성장').last);
    });
    await _shot(tester, g, '09-survivor-gear', act: () async {
      await tester.tap(find.text('생존자').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text(survivors[0].name).first);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('장비').last);
    });
    await _shot(tester, g, '10-bag', act: () async {
      await tester.tap(find.text('생존자').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('장비').first);
    });
    await _shot(tester, g, '11-party', act: () async {
      g.party = [0];
      g.poke();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text('+').first);
    });
    g.party = [0, 3];
    // 3단계: 의뢰·부탁이 떠 있는 낮
    final now = DateTime.now().millisecondsSinceEpoch;
    g.S.rest['sq'] = <String, Object?>{'k': 'wood', 'n': 45, 'b': (g.S.got['wood'] ?? 0) - 20, 'at': now, 'who': 1, 'say': '“장작이 모자라요.”'};
    g.sqOpenUntil = now + 60000;
    g.evCur = 1;
    g.evLeft = 70;
    g.S.rest['wx'] = 'clear';
    await _shot(tester, g, '12-day-quests');
    await _shot(tester, g, '14-request', act: () async {
      await tester.tap(find.text('고장 난 트럭').first);
    });
    // 재폭풍 밤
    g.evCur = -1;
    g.S.rest['sq'] = null;
    g.S.rest['clock'] = 170.0;
    g.wasNight = true;
    g.S.rest['wx'] = 'normal';
    final edge = [for (var i = 0; i < N; i++) if (g.S.rev[i] == 1 && !g.modAt.containsKey(i) && i != C0 && nb4(i).any((j) => g.S.rev[j] == 0)) i];
    for (final i in edge.take(3)) {
      g.S.ash['$i'] = <String, Object?>{'hp': 5.0, 'max': 8.0, 't': 9.0};
    }
    g.S.ash['${g.modAt.keys.first}'] = <String, Object?>{'hp': 4.0, 'max': 6.0, 't': 0, 'stuck': true};
    await _shot(tester, g, '13-night');
    // 대형 재폭풍
    g.S.ash.clear();
    g.startDefense();
    await _shot(tester, g, '15-defense', act: () async {
      for (var k = 0; k < 30; k++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
    g.defn = null;
    g.S.rest['clock'] = 10.0;
    g.wasNight = false;
    g.takeFx();
    // 4단계: 원정·라디오·펫·아이·떠돌이 무리·장식·노친네
    await _shot(tester, g, '16-exp', act: () async {
      await tester.tap(find.text('원정').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('팀 꾸리기').first);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text(survivors[0].name).last);
      await tester.tap(find.text(survivors[1].name).last);
    });
    g.S.m['batt'] = 6;
    await _shot(tester, g, '17-radio', act: () async {
      await tester.tap(find.text('라디오').last);
    });
    g.petAdopt('dog', quiet: true);
    g.petAdopt('cat', quiet: true);
    g.addKid();
    final open = [for (var i = 0; i < N; i++) if (g.decoOk(i)) i];
    g.S.m.addAll({'wood': 140, 'food': 60});
    if (open.length > 3) {
      g.placeDeco('bench', open[0]);
      g.placeDeco('pot', open[2]);
      g.S.rest['band'] = <String, Object?>{'k': 'trader', 'name': '떠돌이 고물상', 'tile': open[open.length - 1], 't': 150,
        'offers': [<String, Object?>{'give': {'scrap': 20}, 'get': {'plate': 3}, 'left': 2}], 'say': '“좋은 물건 있수.”', 'tribute': {}};
    }
    g.ped['here'] = 0;
    g.ped['visits'] = 1;
    g.ped['stock'] = [<String, Object?>{'kind': 'mat', 'm': {'batt': 3}, 'n': '건전지 세 개', 'd': '아직 살아 있다. 아마도.', 'price': {'parts': 10, 'fuel': 8}, 'rare': 1, 'sold': 0}];
    g.takeFx();
    await _shot(tester, g, '18-map-life', act: () async {
      for (var k = 0; k < 20; k++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
    await _shot(tester, g, '19-pets', act: () async {
      await tester.tap(find.text('생존자').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('펫').first);
    });
    await _shot(tester, g, '20-deco', act: () async {
      await tester.tap(find.text('쉘터').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('꾸미기').last);
    });
    await _shot(tester, g, '21-ped', act: () async {
      await tester.tap(find.text('🛒 노친네'));
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
    // 5단계: 이야기
    g.S.rest['mi'] = stepI('생존자 3명 모으기'); // 3장 첫 걸음의 장면을 아직 안 본 것으로 → 장 첫머리 대화 창
    g.S.rest['storyI'] = g.mi - 1;
    await _shot(tester, g, '22-talk', act: () async {
      for (var k = 0; k < 8; k++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
    g.takeFx(); // 생존자 셋이 이미 있어 미션 완료 → 띠가 '받기'로
    await _shot(tester, g, '23-mission-done');
    await _shot(tester, g, '24-diary-ach', act: () async {
      await tester.tap(find.text('일지').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('업적').last);
    });
    g.S.rest['mi'] = stepI('등불 탑 토대 놓기');
    g.S.rest['storyI'] = g.mi;
    g.S.m.addAll({'plate': 200, 'wood': 300});
    // 사건 수첩: 사건 창 → 수첩 → 회상
    g.S.rest['mi'] = stepI('생존자 3명 모으기');
    g.S.rest['storyI'] = g.mi;
    g.fx.add(const FxCase(0));
    await _shot(tester, g, '28-case', act: () async {
      for (var k = 0; k < 8; k++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
    g.pickCase(0, 'a');
    (g.S.rest['cases'] as Map)['1'] = <String, Object?>{'p': 'a', 'clue': 1};
    g.S.rest['odd'] = [
      <String, Object?>{'n': 4, 'r': '', 'k': 'knock', 't': '누가 창고 문을 세 번, 한 번, 한 번 두드리고 멈췄다. 아무도 없었다.'}
    ];
    g.egg['a'] = 1;
    g.takeFx();
    await _shot(tester, g, '29-casebook', act: () async {
      await tester.tap(find.text('일지').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('사건').last);
    });
    await _shot(tester, g, '30-gallery', act: () async {
      await tester.tap(find.text('일지').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('회상').last);
    });
    // 지하 구역: 준비 창 → 내려간 첫 층
    g.S.lv = 3;
    g.recalc();
    await _shot(tester, g, '26-ug-prep', act: () async {
      await tester.tap(find.text('원정').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('내려갈 준비'));
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text(survivors[0].name).last);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text(survivors[1].name).last);
    });
    await _shot(tester, g, '27-ug', act: () async {
      await tester.tap(find.text('원정').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('내려갈 준비'));
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('내려가기'));
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      // 입구 위 칸 두 번 두드리기
      for (final i in [(ugH - 2) * ugW + 2, (ugH - 3) * ugW + 2]) {
        if (g.ugFront(i)) g.ugTap(i);
      }
    });
    g.ugEnd(true);
    g.S.lv = 2;
    g.recalc();
    g.takeFx();
    await _shot(tester, g, '25-tower', act: () async {
      await tester.tap(find.text('쉘터').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('건설').last);
    });

    // ===== 6단계: 이주와 새 동네 =====
    final r = Game(Game.fresh(seed: 42));
    for (var y = CY - 4; y <= CY + 4; y++) {
      for (var x = CX - 4; x <= CX + 4; x++) {
        if (r.S.rev[y * W + x] == 0) r.reveal(y * W + x);
      }
    }
    for (final id in [0, 1, 2, 3, 4, 5, 6, 7]) {
      r.rescue(id, 'sig');
    }
    r.S.lv = 5;
    r.S.rest['endSeen'] = 1;
    r.S.rest['mi'] = steps.length;
    r.S.rest['storyI'] = steps.length;
    r.S.m.addAll({'wood': 200, 'scrap': 120, 'cloth': 60, 'food': 120, 'parts': 40, 'fuel': 40, 'batt': 8, 'plate': 20});
    r.recalc();
    r.takeFx();
    await _shot(tester, r, '31-migrate', act: () async {
      await tester.tap(find.text('쉘터').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('건설').last);
      for (var k = 0; k < 4; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.textContaining('새 동네로 떠나기').first);
    });
    r.migrate([0, 1, 2, 3, 4]);
    r.takeFx();
    for (var y = CY - 3; y <= CY + 3; y++) {
      for (var x = CX - 3; x <= CX + 3; x++) {
        if (r.S.rev[y * W + x] == 0) r.reveal(y * W + x);
      }
    }
    r.S.rest['rsI'] = 0;
    r.S.rest['rmi'] = 3;
    r.S.rest['rsI'] = 3;
    r.tickRegionSec();
    final si = (r.rq['spotI'] as num).toInt();
    r.takeFx();
    expect(si, greaterThanOrEqualTo(0));
    await _shot(tester, r, '32-desert');
    r.S.m.addAll({'wood': 100, 'scrap': 100, 'food': 100, 'cloth': 100, 'fuel': 100, 'parts': 100});
    r.trState();
    r.takeFx();
    await _shot(tester, r, '33-radio-trade', act: () async {
      await tester.tap(find.text('라디오').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    });
    r.tlog('급유탑 밑에 숨겨진 저수조를 찾았다.');
    await _shot(tester, r, '34-route', act: () async {
      await tester.tap(find.text('일지').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('노선도').last);
    });
    r.S.rest['rmi'] = 5;
    r.S.rest['rsI'] = 5;
    r.fx.add(const FxTownChoice());
    await _shot(tester, r, '35-town-choice', act: () async {
      for (var k = 0; k < 8; k++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
    r.takeFx();
    r.rescue(8, 'sig');
    r.rescue(9, 'sig');
    r.rescue(5, 'sig');
    for (var k = 0; k < 30 && r.S.rest['deathG'] == null; k++) {
      r.deathAfterDefense(false, Defense(null));
    }
    final dfx = r.takeFx().whereType<FxDeath>().toList();
    if (dfx.isNotEmpty) r.fx.add(dfx.first);
    await _shot(tester, r, '36-death', act: () async {
      for (var k = 0; k < 40; k++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    });
    r.takeFx();
    // 끊긴 노선
    r.S.m['food'] = 100;
    r.lnStart([0, 1]);
    await _shot(tester, r, '37-line', act: () async {
      await tester.pump(const Duration(milliseconds: 60));
      await showLnRunFor(tester, r);
    });
    final L = r.ln!;
    L.phase = 'fight';
    L.fight = LnFight(false, 4, 1100, DateTime.now().microsecondsSinceEpoch / 1000 - 400);
    await _shot(tester, r, '38-line-fight', act: () async {
      await tester.pump(const Duration(milliseconds: 60));
      await showLnRunFor(tester, r);
    });
    r.ln = null;
    // 개인 이야기
    r.rec(2)!['xp'] = 100000;
    r.tickStorySec();
    r.takeFx();
    await _shot(tester, r, '39-quest', act: () async {
      await tester.tap(find.text('생존자').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text(survivors[2].name).last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('이야기').last);
    });
  });
}

Future<void> showLnRunFor(WidgetTester tester, Game g) async {
  final ctx = tester.element(find.byType(GameScreen));
  showLnRun(ctx, g);
  for (var k = 0; k < 4; k++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}
