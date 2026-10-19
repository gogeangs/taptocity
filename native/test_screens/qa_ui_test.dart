// QA: 모든 화면 훑기 (웹 tests/qa/tqa.py에 해당).
// 진행 단계(처음·중반·후반) × 동네(첫 동네·사막·공단·산골) × 화면 크기(작은 폰·큰 폰)마다
// 시트·탭·생존자 창·설정·프로필을 열어 보고, 화면 넘침(overflow)·예외·깨진 글자(null·NaN 등)를 모아
// test_screens/shots/qa-ui.txt 로 남긴다. (그림은 진짜 아틀라스로 그린다)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taptocity/game/data.dart';
import 'package:taptocity/game/engine.dart';
import 'package:taptocity/ui/atlas.dart';
import 'package:taptocity/ui/cuts_ui.dart';
import 'package:taptocity/ui/game_screen.dart';
import 'package:taptocity/ui/season_ui.dart';
import 'package:taptocity/ui/story_ui.dart';
import 'package:taptocity/ui/survivors.dart';
import 'package:taptocity/ui/theme.dart';

final _bad = RegExp(r'\bnull\b|NaN|Infinity|undefined|\[object|Instance of|\$\{');

Game _state(String stage, String town) {
  final g = Game(Game.fresh(seed: 42));
  final S = g.S;
  S.rest['pfAsk'] = 1;
  S.rest['onb'] = 2;
  for (var y = CY - 4; y <= CY + 4; y++) {
    for (var x = CX - 4; x <= CX + 4; x++) {
      if (S.rev[y * W + x] == 0) g.reveal(y * W + x);
    }
  }
  if (stage == 'early') {
    S.rest['mi'] = 3;
    S.rest['storyI'] = 3;
    g.takeFx();
    return g;
  }
  S.m.addAll({'wood': 500, 'scrap': 500, 'cloth': 300, 'parts': 300, 'fuel': 200, 'food': 400, 'plate': 80, 'rope': 40, 'wire': 20, 'med': 10, 'batt': 30});
  S.lv = stage == 'mid' ? 3 : 5;
  g.recalc();
  for (final id in [9, 1, 2, 8, 3, 4, 5, 6, 7]) {
    if (mods[id] != null && g.canBuild(id)) g.buildMod(id);
  }
  final ids = stage == 'mid' ? [0, 1, 2, 3, 4, 5] : [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
  for (final id in ids) {
    g.rescue(id, 'sig');
    g.rec(id)!['xp'] = stage == 'mid' ? 400 : 3000;
  }
  for (final t in ['shovel', 'coverall', 'photo', 'hammer']) {
    g.addGear(t);
  }
  g.autoGear();
  g.petAdopt('dog', quiet: true);
  g.addKid();
  S.rest['mi'] = stage == 'mid' ? stepI('첫 원정 보내기') : steps.length;
  S.rest['storyI'] = g.mi;
  if (stage == 'late') {
    S.rest['endSeen'] = 1;
    S.rest['tower'] = 5;
    S.rest['cases'] = <String, Object?>{'0': {'p': 'a', 'clue': 1, 'solved': 1}, '1': {'p': 'b'}};
    S.rest['dead'] = [
      <String, Object?>{'id': 13, 'g': 1, 'town': '메마른 사막 도시', 'at': 0}
    ];
  }
  final hops = const {'home': 0, 'desert': 1, 'factory': 2, 'snow': 3}[town]!;
  for (var k = 0; k < hops; k++) {
    final (pick, _) = g.migRecommend(g.nextRegion);
    g.migrate(pick);
    g.S.lv = 4;
    g.S.m.addAll({'wood': 500, 'scrap': 500, 'cloth': 300, 'parts': 300, 'fuel': 200, 'food': 400});
    g.S.rest['rmi'] = 4;
    g.S.rest['rsI'] = 4;
    g.S.rest['tower'] = 5;
    g.recalc();
  }
  g.S.rest['pfAsk'] = 1;
  g.takeFx();
  return g;
}

void main() {
  final report = <String>[];
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final sans = FontLoader('TTCSans')..addFont(rootBundle.load('assets/fonts/ttc-sans.ttf'));
    await sans.load();
  });
  tearDownAll(() {
    Directory('test_screens/shots').createSync(recursive: true);
    File('test_screens/shots/qa-ui.txt').writeAsStringSync('${report.join('\n')}\n');
  });

  testWidgets('모든 화면 훑기', (tester) async {
    await tester.runAsync(() async {
      await Atlas.load();
    });
    final problems = <String, int>{};
    void add(String k) => problems[k] = (problems[k] ?? 0) + 1;
    final old = FlutterError.onError;
    var where = '';
    FlutterError.onError = (d) {
      final msg = d.exceptionAsString().split('\n').first;
      add('$where · ${msg.length > 160 ? msg.substring(0, 160) : msg}');
    };
    var screens = 0;

    Future<void> settle() async {
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 80));
      }
    }

    void scanText() {
      for (final e in find.byType(Text).evaluate()) {
        final w = e.widget as Text;
        final t = w.data ?? w.textSpan?.toPlainText() ?? '';
        if (_bad.hasMatch(t)) add('$where · 깨진 글자: “${t.length > 80 ? t.substring(0, 80) : t}”');
      }
      for (final e in find.byType(RichText).evaluate()) {
        final t = (e.widget as RichText).text.toPlainText();
        if (_bad.hasMatch(t)) add('$where · 깨진 글자: “${t.length > 80 ? t.substring(0, 80) : t}”');
      }
    }

    Future<bool> tapText(String t) async {
      final f = find.text(t);
      if (f.evaluate().isEmpty) return false;
      try {
        await tester.tap(f.last, warnIfMissed: false);
      } catch (_) {
        return false;
      }
      await settle();
      return true;
    }

    Future<void> visit(String name, Future<void> Function() go) async {
      where = name;
      try {
        await go();
        await settle();
        screens++;
        // 화면이 실제로 열렸는지: 글자 수가 너무 적으면 기록
        final n = find.byType(Text).evaluate().length + find.byType(RichText).evaluate().length;
        if (n < 8) add('$where · 글자가 거의 없음($n) — 화면이 안 열렸을 수 있음');
        scanText();
        final ex = tester.takeException();
        if (ex != null) add('$where · 예외: ${'$ex'.split('\n').first}');
      } catch (e) {
        add('$where · 테스트 진행 오류: ${'$e'.split('\n').first}');
      }
    }

    for (final size in const [(Size(720, 1280), 2.0, '작은 폰'), (Size(1170, 2532), 3.0, '큰 폰')]) {
      for (final (stage, town) in const [('early', 'home'), ('mid', 'home'), ('late', 'home'), ('late', 'desert'), ('late', 'factory'), ('late', 'snow')]) {
        final g = _state(stage, town);
        tester.view.physicalSize = size.$1;
        tester.view.devicePixelRatio = size.$2;
        Future<void> home() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: Ttc.theme(), home: GameScreen(game: g)));
          await settle();
          // 떠 있는 창 닫기
          for (var k = 0; k < 3; k++) {
            if (find.byType(Dialog).evaluate().isEmpty) break;
            Navigator.of(tester.element(find.byType(Dialog).last)).pop();
            await settle();
          }
        }

        final tag = '${size.$3} · $stage · $town';
        await visit('$tag · 지도', home);
        for (final (tab, subs) in const [
          ('쉘터', ['건설', '가공', '연구', '창고', '꾸미기']),
          ('일지', ['이야기', '회상', '사건', '노선도', '도감', '업적', '안내서']),
          ('원정', <String>[]),
          ('라디오', <String>[]),
          ('생존자', <String>[]),
        ]) {
          await visit('$tag · $tab', () async {
            await home();
            await tapText(tab);
          });
          for (final s in subs) {
            await visit('$tag · $tab · $s', () async {
              await home();
              await tapText(tab);
              await tapText(s);
              // 아래까지 내려 보기
              final lv = find.byType(Scrollable);
              if (lv.evaluate().isNotEmpty) {
                await tester.drag(lv.last, const Offset(0, -2000), warnIfMissed: false);
                await settle();
              }
            });
          }
        }
        // 생존자 창 (네 탭)
        for (final id in g.svIds.take(stage == 'late' ? 3 : 1)) {
          for (final t in const ['정보', '성장', '장비', '이야기']) {
            await visit('$tag · 생존자 ${survivors[id].name} · $t', () async {
              await home();
              await tapText('생존자');
              await tapText(survivors[id].name);
              await tapText(t);
            });
          }
        }
        await visit('$tag · 설정', () async {
          await home();
          await tester.tap(find.byKey(const ValueKey('setBtn')));
          await settle();
          await tester.drag(find.byType(Scrollable).last, const Offset(0, -2000), warnIfMissed: false);
        });
        // 정답 없는 선택 창 (앱 전용): 약 한 알(하늘·순례) · 국이 모자란 밤
        if (stage == 'late' && town == 'home') {
          for (final (k, a, b, v) in const [('med', 3, 4, 'kin'), ('med', 6, 0, ''), ('soup', 3, 6, '')]) {
            await visit('$tag · 선택 · $k$v', () async {
              await home();
              g.S.rest['choice'] = <String, Object?>{'k': k, 'a': a, 'b': b, 'v': v, 'day': 1};
              g.choiceAsked = '${k}1';
              showChoice(tester.element(find.byType(GameScreen)), g);
              await settle();
            });
          }
          g.S.rest['choice'] = null;
          // 웹툰 컷 보기 (앱 전용 2026-10-19): 사건 1 ①·④(효과 글자), 순례 합류 ②, 탑 아래 진 ③, 사건 수첩의 다시 보기
          for (final (name, panels, taps, label) in const [
            ('case1', [0, 3], 0, '사건 1 ①'),
            ('case1', [0, 3], 1, '사건 1 ④'),
            ('join_sunrye', [1], 0, '순례 합류 ②'),
            ('join_jin_choice', [2], 0, '탑 아래 진 ③'),
          ]) {
            await visit('$tag · 웹툰 컷 · $label', () async {
              await home();
              await tester.runAsync(() => Atlas.ensure(cutFile(name)));
              showCuts(tester.element(find.byType(GameScreen)), name, panels);
              await settle();
              for (var k = 0; k < taps; k++) {
                await tapText('탭해서 계속 ▸');
              }
            });
          }
          await visit('$tag · 일지 · 사건 · 컷 다시 보기', () async {
            await home();
            await tester.runAsync(() => Atlas.ensure(cutFile('case1')));
            await tapText('일지');
            await tapText('사건');
            await tapText('컷 다시 보기');
          });
          // 앱 전용 (2026-10-18): 기록 조각 · 일지의 조각 목록 · 오늘의 의뢰 연속 칸 · 아침 보고 · 인연 Lv.3 · 지하 준비(가장 깊이)
          final frags0 = g.S.rest['frags'], ug0 = Map<String, Object?>.from(g.ugRec), dq0 = g.S.rest['dayQ'], ds0 = g.S.rest['dayStreak'], dl0 = g.S.rest['dayLast'];
          g.S.rest['frags'] = <Object?>[0, 3, 7];
          g.ugRec['best'] = 23;
          await visit('$tag · 기록 조각 창', () async {
            await home();
            showTalk(tester.element(find.byType(GameScreen)), g, g.fragTalk(3, first: true));
            await settle();
            await tapText('탭해서 계속 ▸');
          });
          g.S.rest['dayStreak'] = 6;
          g.S.rest['dayLast'] = g.todayKey;
          g.S.rest['dayQ'] = <String, Object?>{
            'd': g.todayKey,
            'all': 0,
            'q': [
              <String, Object?>{'k': 'wood', 'n': 136, 'p': 136, 'l': 1e9, 'ok': 1},
              <String, Object?>{'k': 'ug', 'n': 3, 'p': 1, 'l': 1e9, 'ok': 0},
              <String, Object?>{'k': 'gift', 'n': 1, 'p': 0, 'l': 1e9, 'ok': 0},
            ],
          };
          await visit('$tag · 일지 · 오늘의 의뢰 · 연속 칸', () async {
            await home();
            await tapText('일지');
            await tapText('이야기');
          });
          await visit('$tag · 일지 · 기록 조각 목록', () async {
            await home();
            await tapText('일지');
            await tapText('이야기');
            final lv = find.byType(Scrollable);
            if (lv.evaluate().isNotEmpty) {
              await tester.drag(lv.last, const Offset(0, -900), warnIfMissed: false);
              await settle();
            }
          });
          await visit('$tag · 지하 준비 · 가장 깊이', () async {
            await home();
            await tapText('원정');
            await tapText('내려갈 준비');
          });
          await visit('$tag · 아침 보고', () async {
            await home();
            g.morningReport(3 * 3600 + 25 * 60.0, {'wood': 120, 'scrap': 80, 'food': 40}, g.svIds.take(1).toList());
            final t = g.takeFx().whereType<FxTalk>().last;
            showTalk(tester.element(find.byType(GameScreen)), g, t);
            await settle();
            await tapText('탭해서 계속 ▸');
          });
          final r0 = g.rec(0)!, xp0 = r0['xp'], bn0 = r0['bondN'], bg0 = r0['bondG'];
          r0['xp'] = trustXp.last + bondCum[2] + 500;
          r0['bondN'] = 3;
          r0['bondG'] = 1;
          final st0 = survTab;
          await visit('$tag · 생존자 ${survivors[0].name} · 성장 · 인연 Lv.3', () async {
            await home();
            await tapText('생존자');
            await tapText(survivors[0].name);
            await tapText('성장');
            final lv = find.byType(Scrollable);
            if (lv.evaluate().isNotEmpty) {
              await tester.drag(lv.last, const Offset(0, -900), warnIfMissed: false);
              await settle();
            }
          });
          await visit('$tag · 인연 장면 창', () async {
            await home();
            showTalk(tester.element(find.byType(GameScreen)), g, g.bondTalk(0, 3));
            await settle();
          });
          survTab = st0;
          r0['xp'] = xp0;
          if (bn0 == null) {
            r0.remove('bondN');
          } else {
            r0['bondN'] = bn0;
          }
          if (bg0 == null) {
            r0.remove('bondG');
          } else {
            r0['bondG'] = bg0;
          }
          g.S.rest['frags'] = frags0;
          g.S.rest['ug'] = ug0;
          g.S.rest['dayQ'] = dq0;
          g.S.rest['dayStreak'] = ds0;
          g.S.rest['dayLast'] = dl0;
        }
        if (stage == 'mid' && town == 'home') {
          // 대사 창: 한 줄씩 넘기기(창 두드리기) · 건너뛰기 · 마지막 줄의 행동 버튼
          await visit('$tag · 대사 창', () async {
            await home();
            showTalk(
                tester.element(find.byType(GameScreen)),
                g,
                const FxTalk([
                  Line('me', '판잣집 불빛이 멀리서도 보이는 모양이다. 누군가 이쪽을 살피고 있다.'),
                  Line(0, '누가 오는 것 같구먼. 랜턴을 너무 높이 들지 말게.'),
                  Line(0, '조심해서 나쁠 건 없지.'),
                  Line('me', '나는 랜턴 심지를 조금 낮췄다.'),
                ], tag: '3장 · 모여드는 사람들', goal: '생존자 3명 모으기'));
            await settle();
            await tapText('탭해서 계속 ▸');
            await tapText('건너뛰기');
          });
          // 스킬 바: 다친 사람(붉은 테·남은 시간) · 스킬 대기 배지
          final p0 = List<int>.of(g.party), cd0 = g.S.rest['cd'];
          await visit('$tag · 지도 · 다친 사람', () async {
            g.party = [0, 1];
            g.rec(1)!['hurt'] = 150.0;
            g.S.rest['cd'] = <String, Object?>{'0': 20.0};
            await home();
          });
          g.rec(1)!['hurt'] = 0;
          g.party = p0;
          g.S.rest['cd'] = cd0;
        }
        for (final t in const ['프로필', '꾸미기']) {
          await visit('$tag · 프로필 · $t', () async {
            await home();
            await tester.tap(find.byKey(const ValueKey('pfBtn')));
            await settle();
            await tapText(t);
          });
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = old;
    report
      ..add('화면 $screens개를 열어 봄 · 문제 ${problems.length}종')
      ..addAll([for (final e in problems.entries) '${e.value > 1 ? '(${e.value}번) ' : ''}${e.key}']);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
