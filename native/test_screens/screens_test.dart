// 화면 사진: 실제 그림·글꼴로 주요 화면을 그려 PNG로 남긴다 (CI가 native-play/shots/ 에 올림).
// 실행: flutter test test_screens --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taptocity/game/data.dart';
import 'package:taptocity/game/engine.dart';
import 'package:taptocity/ui/atlas.dart';
import 'package:taptocity/ui/cuts_ui.dart' show CutSeen, caseCut, cutFile, showCuts;
import 'package:taptocity/ui/game_screen.dart';
import 'package:taptocity/ui/lines_ui.dart';
import 'package:taptocity/ui/map_view.dart';
import 'package:taptocity/ui/season_ui.dart' show showChoice;
import 'package:taptocity/ui/theme.dart';
import 'package:taptocity/ui/underground_ui.dart' show showUg;

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
  S.rest['pfAsk'] = 1;
  g.takeFx();
  return g;
}

/// 앱 전용 화면용 후반 진행: 쉘터 Lv.5, 생존자 열둘(0~11), 이야기 끝, 낮 (qa_ui_test의 late·home과 같은 결).
/// 오늘의 할 일·긴장 장치(선택·부상·사과·불빛 밖)가 켜지는 상태. 시험마다 새로 만들어 서로 섞이지 않게 쓴다.
Game _late() {
  final g = Game(Game.fresh(seed: 42));
  final S = g.S;
  S.rest['pfAsk'] = 1;
  S.rest['onb'] = 2;
  for (var y = CY - 4; y <= CY + 4; y++) {
    for (var x = CX - 4; x <= CX + 4; x++) {
      if (S.rev[y * W + x] == 0) g.reveal(y * W + x);
    }
  }
  S.m.addAll({'wood': 500, 'scrap': 500, 'cloth': 300, 'parts': 300, 'fuel': 200, 'food': 400, 'plate': 80, 'rope': 40, 'wire': 20, 'med': 10, 'batt': 30});
  S.lv = 5;
  g.recalc();
  for (final id in [9, 1, 2, 8, 3, 4, 5, 6, 7]) {
    if (mods[id] != null && g.canBuild(id)) g.buildMod(id);
  }
  for (var id = 0; id < 12; id++) {
    g.rescue(id, 'sig');
    g.rec(id)!['xp'] = 3000;
  }
  for (final t in ['shovel', 'coverall', 'photo', 'hammer']) {
    g.addGear(t);
  }
  g.autoGear();
  g.petAdopt('dog', quiet: true);
  g.addKid();
  S.rest['mi'] = steps.length;
  S.rest['storyI'] = steps.length;
  S.rest['endSeen'] = 1;
  S.rest['tower'] = 5;
  S.rest['clock'] = 12.0; // 낮 이른 때 (사과·선택은 새벽 직후엔 열리지 않는다)
  g.party = [0, 3];
  g.recalc();
  g.takeFx();
  return g;
}

/// 정답 없는 선택 창 상태 (kin: 하늘·순례가 함께 앓는 '약 한 알')
Game _choice(String k, int a, int b, String v) {
  final g = _late();
  if (v == 'kin') {
    g.S.rest['medKin'] = 1;
    for (final id in [a, b]) {
      g.rec(id)!['hurt'] = 150.0;
      g.rec(id)!['hurtBy'] = 'sick';
    }
  }
  g.S.rest['choice'] = <String, Object?>{'k': k, 'a': a, 'b': b, 'v': v, 'day': g.dayN};
  g.choiceAsked = '$k${g.dayN}'; // 화면 틱이 같은 창을 또 띄우지 않게
  g.recalc();
  return g;
}

/// 오늘의 할 일 셋(하나 끝) + 어제까지 연속 4일
void _daily(Game g) {
  g.S.rest['dayStreak'] = 4;
  g.S.rest['dayLast'] = dayKeyAdd(g.todayKey, -1);
  g.S.rest['dayQ'] = <String, Object?>{
    'd': g.todayKey,
    'all': 0,
    'q': [
      <String, Object?>{'k': 'wood', 'n': 136, 'p': 136, 'l': 1e9, 'ok': 1},
      <String, Object?>{'k': 'ug', 'n': 3, 'p': 1, 'l': 1e9, 'ok': 0},
      <String, Object?>{'k': 'gift', 'n': 1, 'p': 0, 'l': 1e9, 'ok': 0},
    ],
  };
}

/// 게임이 띄울 대화 하나만 남긴다 (화면이 켜지면 창 줄로 연다). 없으면 그 사진은 실패로 적는다
void _keepTalk(Game g, String tag) {
  final t = g.takeFx().whereType<FxTalk>().where((x) => (x.tag ?? '').startsWith(tag)).lastOrNull;
  if (t == null) throw StateError('‘$tag’ 대화가 열리지 않음');
  g.fx.add(t);
}

/// 개인 이야기를 이미 열어 둔 것으로: 화면 틱이 '…의 이야기가 열렸어요'·'… 2/3' 알림 카드를 띄워
/// 찍으려는 알림(불빛 밖 경고·방어 안내)을 가리지 않게. 저절로 넘어가는 걸음(데려오기)도 미리 넘긴다
void _quietQuests(Game g) {
  for (final id in g.svIds) {
    final Q = quests[id], r = g.rec(id);
    if (Q == null || r == null || r['q'] != null) continue;
    var s = 0;
    while (s < Q.steps.length && Q.steps[s]['k'] == 'bond' && g.hasSv((Q.steps[s]['id'] as num).toInt())) {
      s++;
    }
    r['q'] = <String, Object?>{'s': s};
  }
}

/// 사건 창을 바로 열리게: 처음 여는 사건은 웹툰 컷(그림을 진짜로 풀어야 해서 시험 시계로는 끝나지 않음)부터 띄우므로 본 것으로 적는다
void _caseReady(Game g, int k) {
  g.cutMark(caseCut(k));
  g.fx.add(FxCase(k));
}

Future<void> _noAct(Game g) async {}

Future<void> _pumps(WidgetTester tester, int n, [int ms = 60]) async {
  for (var k = 0; k < n; k++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

BuildContext _ctx(WidgetTester tester) => tester.element(find.byType(GameScreen));

const _narrow = Size(640, 1280); // 320×640 논리 픽셀 (작은 안드로이드 폰)

Future<void> _shot(WidgetTester tester, Game g, String name, {Future<void> Function()? act, Size size = const Size(750, 1624), int settle = 10}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2;
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: Ttc.theme(), home: GameScreen(game: g)));
  await tester.pump(const Duration(milliseconds: 50));
  if (act != null) await act();
  for (var k = 0; k < settle; k++) {
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
      for (final f in ['story-1.webp', 'story-2.webp', 'story-3.webp', 'story-4.webp', 'story-5.webp', 'founder-expressions.webp', 'underground-icons.webp', 'crows-kids.webp', 'regional-npcs.webp', 'player-faceless.webp']) {
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
    // 3단계: 생존자의 부탁(펼친 카드)·손님 부탁이 떠 있는 낮
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
      await tester.tap(find.text('노친네').first); // 2026-10-14: 칩 이모지가 손그림 얼굴로 바뀜
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
      // 2026-10-20: 일지 위 탭 '도감' 안의 '업적'
      await tester.tap(find.text('도감').first);
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
    _caseReady(g, 0);
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
      await tester.tap(find.text('사건 수첩').last); // 2026-10-20: 일지 위 탭 '사건 수첩'
    });
    await _shot(tester, g, '30-gallery', act: () async {
      await tester.tap(find.text('일지').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      // 2026-10-20: 일지 위 탭 '기록' 안의 '회상'
      await tester.tap(find.text('기록').first);
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
    r.S.rest['pfAsk'] = 1;
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
      // 2026-10-20: 일지 위 탭 '도감' 안의 '노선도'
      await tester.tap(find.text('도감').first);
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
    r.rescue(10, 'sig');
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
    final qid = r.svIds.firstWhere((id) => quests[id] != null && id != 0);
    r.rec(qid)!['xp'] = 100000;
    r.tickStorySec();
    r.takeFx();
    await _shot(tester, r, '39-quest', act: () async {
      await tester.tap(find.text('생존자').last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text(survivors[qid].name).last);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('이야기').last);
    });
    // 7단계: 프로필·설정·산골 풍경
    r.pf['name'] = '하람';
    r.pf['set'] = 1;
    r.pf['portrait'] = 2;
    r.S.rest['playT'] = 5400;
    // 플레이 시간이 길어 새 기능 카드(무전 거래 등)가 반쯤 뜬 채 찍히지 않게: 안내를 다 본 것으로
    for (final f in feats) {
      r.featSeen(f.k);
    }
    r.S.rest['featQ'] = <Object?>[];
    r.takeFx();
    await _shot(tester, r, '40-profile', act: () async {
      await tester.tap(find.byKey(const ValueKey('pfBtn')));
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    });
    await _shot(tester, r, '41-settings', act: () async {
      await tester.tap(find.byKey(const ValueKey('setBtn')));
    });
    final w = Game(Game.fresh(seed: 42));
    w.S.gen = 3;
    w.S.region = 'snow';
    w.S.rest['pfAsk'] = 1;
    w.S.rest['mi'] = steps.length;
    w.S.rest['storyI'] = steps.length;
    w.S.rest['rsI'] = 0;
    w.S.rest['wx'] = 'normal';
    for (var y = CY - 4; y <= CY + 4; y++) {
      for (var x = CX - 4; x <= CX + 4; x++) {
        if (w.S.rev[y * W + x] == 0) w.reveal(y * W + x);
      }
    }
    w.buildMod(1);
    w.buildMod(2);
    w.S.rest['warm'] = 75;
    w.recalc();
    w.takeFx();
    Atlas.region = 'snow';
    await _shot(tester, w, '42-snow', act: () async {
      await tester.runAsync(() => Atlas.tintAll('snow'));
      w.mapVersion.value++;
      for (var k = 0; k < 10; k++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  });

  // ===== 43~72: 앱 전용 화면 (웹툰 컷·선택·부상·사과·아침 보고·의뢰·조각·인연·깊은 지하·불빛 밖) + 좁은 폰 =====
  // 위 테스트와 따로 돈다: 하나가 막혀도 01~42는 그대로 찍히고, 여기서도 막힌 사진만 빠지고 나머지는 찍는다 (끝에 모아서 실패로 알린다).
  testWidgets('화면 사진 · 앱 전용 화면과 좁은 폰', (tester) async {
    await tester.runAsync(() async {
      await Atlas.load();
      for (final f in [
        'story-1.webp', 'story-2.webp', 'story-3.webp', 'story-4.webp', 'story-5.webp', 'founder-expressions.webp', 'underground-icons.webp', 'crows-kids.webp', 'regional-npcs.webp',
        'player-faceless.webp', 'guests.webp', 'survivors-signature-1.webp', 'survivors-signature-2.webp',
      ]) {
        await Atlas.ensure(f);
      }
    });
    Atlas.region = null; // 앞 테스트 끝(42-snow)의 산골 색이 첫 장면에 남지 않게
    final failed = <String>[];

    /// 사진 하나: 상태를 새로 만들고(make), 화면을 연 뒤(act) 충분히 기다려 찍는다
    Future<void> shot(String name, Game Function() make, {Future<void> Function(Game g) act = _noAct, Size size = const Size(750, 1624), int settle = 24}) async {
      try {
        final g = make();
        await _shot(tester, g, name, act: () => act(g), size: size, settle: settle);
      } catch (e) {
        failed.add('$name · $e');
        debugPrint('사진 $name 못 찍음: $e');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    }

    /// 창 줄(_pageQ)로 뜨는 대화·사건 창을 기다린다 (틱 0.25초 → 0.15초 뒤 열림 → 페이드)
    Future<void> waitPage(Game g) => _pumps(tester, 14, 100);

    /// 시트 안에서 글자가 보일 때까지 내리고, 가운데쯤 오게 맞춘다. 못 찾으면 적어 둔다 (사진은 그대로 찍는다)
    Future<void> reveal(String name, String text) async {
      for (var k = 0; k < 12 && find.text(text).evaluate().isEmpty; k++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -400), warnIfMissed: false);
        await _pumps(tester, 4);
      }
      final f = find.text(text);
      if (f.evaluate().isEmpty) {
        failed.add('$name · ‘$text’이 화면에 없음');
        return;
      }
      await Scrollable.ensureVisible(tester.element(f.first), alignment: .35);
      await _pumps(tester, 4);
    }

    Future<void> tapText(String t, {bool first = false}) async {
      final f = find.text(t);
      await tester.tap(first ? f.first : f.last);
      await _pumps(tester, 8);
    }

    /// 웹툰 컷: 그림을 미리 풀어 두고 연 뒤, taps번 넘긴다
    Future<void> cuts(String name, List<int> panels, int taps) async {
      await tester.runAsync(() => Atlas.ensure(cutFile(name)));
      showCuts(_ctx(tester), name, panels);
      await _pumps(tester, 8);
      for (var k = 0; k < taps; k++) {
        await tester.tap(find.text('탭해서 계속 ›'));
        await _pumps(tester, 8);
      }
    }

    // --- 웹툰 컷 (사건 1 ①·④ 효과 글자, 순례 합류 ②, 탑 아래 진 ③) ---
    await shot('43-cut-case1-1', _demo, act: (g) => cuts('case1', const [0, 1, 2, 3], 0));
    await shot('44-cut-case1-4', _demo, act: (g) => cuts('case1', const [0, 1, 2, 3], 3));
    await shot('45-cut-sunrye-2', _demo, act: (g) => cuts('join_sunrye', const [0, 1, 2, 3], 1));
    await shot('46-cut-jin-choice-3', _demo, act: (g) => cuts('join_jin_choice', const [2], 0));

    // --- 정답 없는 선택 ---
    // (창이 닫힐 때까지 기다리면 안 되므로 await 없이 연다)
    Future<void> openChoice(Game g) async {
      showChoice(_ctx(tester), g);
    }

    await shot('47-choice-med', () => _choice('med', 3, 4, 'kin'), act: openChoice);
    await shot('48-choice-soup', () => _choice('soup', 3, 6, ''), act: openChoice);

    // --- 대형 재폭풍을 못 막은 새벽의 부상 · 사과 · 아침 보고 (게임이 낸 대화를 화면 창 줄로) ---
    await shot('49-night-injury', () {
      final g = _late();
      g.nightInjury();
      _keepTalk(g, '폭풍이 지나간 새벽');
      return g;
    }, act: waitPage);
    await shot('50-apology', () {
      final g = _late();
      g.wrongAccuse(6, 30); // 사건 수첩에서 철호를 잘못 추궁
      g.S.rest['sorry_6'] = g.dayN; // 이틀이 지난 것으로
      g.tick(1.0);
      _keepTalk(g, '사과');
      return g;
    }, act: waitPage);
    await shot('51-morning-report', () {
      final g = _late();
      g.morningReport(3 * 3600 + 25 * 60.0, {'wood': 120, 'scrap': 80, 'food': 40}, const [1]);
      _keepTalk(g, '아침 보고');
      return g;
    }, act: waitPage);

    // --- 일지 기록: 오늘의 할 일·연속 칸 / 기록 조각 목록 / 조각 창 ---
    Game daily() {
      final g = _late();
      _daily(g);
      return g;
    }

    await shot('52-diary-daily', daily, act: (g) async {
      await tapText('일지');
      await tapText('기록');
    });
    Game fragGame() {
      final g = _late();
      g.S.rest['frags'] = <Object?>[0, 1, 3, 4];
      g.ugRec['best'] = 23;
      return g;
    }

    await shot('53-diary-frags', fragGame, act: (g) async {
      await tapText('일지');
      await tapText('기록');
      await reveal('53-diary-frags', '그날 밤의 기록 조각');
    });
    await shot('54-frag-scene', () {
      final g = fragGame();
      g.fx.add(g.fragTalk(4, first: true)); // 4/12 · 철호의 '마지막으로 나온 사람'
      return g;
    }, act: waitPage);

    // --- 인연 Lv.3: 성장 탭 / 장면 ---
    Game bond() {
      final g = _late();
      final r0 = g.rec(0)!;
      r0['xp'] = trustXp.last + bondCum[2] + 500;
      r0['bondN'] = 3; // 이미 알린 단계 (틱이 장면을 또 띄우지 않게)
      r0['bondG'] = 1;
      return g;
    }

    await shot('55-bond-grow', bond, act: (g) async {
      await tapText('생존자');
      await tapText(survivors[0].name, first: true);
      await tapText('성장');
      await reveal('55-bond-grow', '인연 Lv.3');
    });
    await shot('56-bond-scene', () {
      final g = bond();
      g.fx.add(g.bondTalk(0, 3));
      return g;
    }, act: waitPage);

    // --- 끝없는 지하: 23층 / 재괴물 층(20층) ---
    Future<void> openUg(Game g) async {
      showUg(_ctx(tester), g);
    }

    Game under(int floor) {
      final g = _late();
      g.ugRec['best'] = 23;
      if (!g.ugStart(const [0, 6, 8], 0, floor)) throw StateError('지하 $floor층으로 내려가지 못함');
      return g;
    }

    await shot('57-ug-deep', () {
      final g = under(23);
      // 입구 위 두 칸을 두드려 둔다 (계단은 위쪽 세 줄에만 있어 내려가지 않는다)
      for (final i in [(ugH - 2) * ugW + 2, (ugH - 3) * ugW + 2]) {
        if (g.ugFront(i)) g.ugTap(i);
      }
      g.takeFx();
      return g;
    }, act: openUg);
    await shot('58-ug-boss', () {
      final g = under(20);
      if (!ugBossFloor(20)) throw StateError('20층이 재괴물 층이 아님');
      final bi = g.ug!.cells.indexWhere((c) => c.boss);
      if (bi < 0) throw StateError('재괴물 칸이 없음');
      g.ug!.cells[bi].rev = true; // 재괴물이 보이게
      g.takeFx();
      return g;
    }, act: openUg);

    // --- 지도: 스킬 바의 다친 사람·원정 간 사람 / 밤의 불빛 밖 경고 ---
    await shot('59-hurt-avatars', () {
      final g = _demo();
      g.party = [0, 1, 3];
      g.S.rest['cd'] = <String, Object?>{'0': 12.0};
      g.rec(3)!['hurt'] = 150.0; // 하늘: 다쳐서 쉬는 중 (붉은 테·남은 시간)
      g.rec(3)!['hurtBy'] = 'night';
      if (g.sendExp('mall', const [1]) == null) throw StateError('원정을 보내지 못함'); // 도윤: 원정 중
      g.recalc();
      g.takeFx();
      return g;
    });
    await shot('60-dark-warning', () {
      final g = _late();
      g.S.rest['clock'] = 170.0;
      g.wasNight = true;
      g.S.rest['nightCount'] = 3; // darkWarnN(0)과 달라야 그 밤의 첫 경고가 뜬다
      g.S.rest['wx'] = 'normal';
      _quietQuests(g);
      g.takeFx();
      final dark = [for (var t = 0; t < N; t++) if (g.S.rev[t] == 1 && !g.litAt(t)) t];
      g.darkTap(dark.isNotEmpty ? dark.first : [for (var t = 0; t < N; t++) if (!g.litAt(t)) t].first);
      if (!g.fx.any((f) => f is FxNote)) throw StateError('불빛 밖 경고가 뜨지 않음');
      return g;
    });

    // --- 쉘터: 증축 자재가 모자람 ('… 더 필요') ---
    Game poor() {
      final g = _demo();
      for (final id in modOrder) {
        if (g.S.mods.length >= shupNeed[g.S.lv - 1]) break;
        if (mods[id] != null && g.canBuild(id)) g.buildMod(id);
      }
      for (final k in g.S.m.keys.toList()) {
        if (k != 'food' && g.S.m[k]! > 4) g.S.m[k] = 4;
      }
      g.recalc();
      g.takeFx();
      return g;
    }

    await shot('61-shelter-disabled', poor, act: (g) async {
      await tapText('쉘터');
      await tapText('건설');
    });

    // --- 사건 수첩의 '컷 다시 보기' ---
    await shot('62-casebook-replay', () {
      final g = _late();
      g.S.rest['cases'] = <String, Object?>{
        '0': <String, Object?>{'p': 'a', 'clue': 1, 'solved': 1},
        '1': <String, Object?>{'p': 'b', 'clue': 1},
      };
      return g;
    }, act: (g) async {
      await tapText('일지');
      await tapText('사건 수첩');
      await reveal('62-casebook-replay', '컷 다시 보기');
    });

    // --- 첫 대형 재폭풍: 아래 안내 ---
    await shot('63-defense-hint', () {
      final g = _late();
      g.S.rest['clock'] = 170.0;
      g.wasNight = true;
      g.S.rest['wx'] = 'normal';
      _quietQuests(g);
      g.takeFx();
      g.startDefense(); // defs 0 · hintDef1 없음 → '대형 재폭풍이 몰려와요!' 안내
      return g;
    }, act: (g) => _pumps(tester, 20, 100));

    // --- 대사 창: 4줄 중 2번째 (탭해서 계속 · 건너뛰기) ---
    const talk4 = FxTalk([
      Line('me', '판잣집 불빛이 멀리서도 보이는 모양이다. 누군가 이쪽을 살피고 있다.'),
      Line(0, '누가 오는 것 같구먼. 랜턴을 너무 높이 들지 말게.'),
      Line(0, '조심해서 나쁠 건 없지.'),
      Line('me', '나는 랜턴 심지를 조금 낮췄다.'),
    ], tag: '3장 · 모여드는 사람들', goal: '생존자 3명 모으기');
    await shot('64-talk-multi', () => _late()..fx.add(talk4), act: (g) async {
      await waitPage(g);
      await tester.tap(find.text('탭해서 계속 ›'));
    });

    // ===== 좁은 폰 (320×640) =====
    await shot('65-narrow-map', _demo, size: _narrow);
    await shot('66-narrow-shelter', _demo, size: _narrow, act: (g) async {
      await tapText('쉘터');
      await tapText('건설');
    });
    await shot('67-narrow-survivor-page', _demo, size: _narrow, act: (g) async {
      await tapText('생존자');
      await tapText(survivors[0].name, first: true);
      await tapText('정보');
    });
    await shot('68-narrow-talk', () {
      final g = _demo();
      g.S.rest['mi'] = stepI('생존자 3명 모으기'); // 22-talk처럼: 3장 첫 장면(그림·장 제목 카드)
      g.S.rest['storyI'] = g.mi - 1;
      return g;
    }, size: _narrow, act: waitPage);
    await shot('69-narrow-case', () {
      final g = _demo();
      g.S.rest['mi'] = stepI('생존자 3명 모으기');
      g.S.rest['storyI'] = g.mi;
      _caseReady(g, 0);
      return g;
    }, size: _narrow, act: waitPage);
    await shot('70-narrow-cut', _demo, size: _narrow, act: (g) => cuts('case1', const [0, 1, 2, 3], 3));
    await shot('71-narrow-diary-daily', daily, size: _narrow, act: (g) async {
      await tapText('일지');
      await tapText('기록');
    });
    await shot('72-narrow-choice', () => _choice('med', 3, 4, 'kin'), size: _narrow, act: openChoice);

    // 남은 지연 호출(창 줄·알림)을 다 흘려보낸다
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(failed, isEmpty, reason: '못 찍은 사진:\n${failed.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 20)));
}

Future<void> showLnRunFor(WidgetTester tester, Game g) async {
  final ctx = tester.element(find.byType(GameScreen));
  showLnRun(ctx, g);
  for (var k = 0; k < 4; k++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}
