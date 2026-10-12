// 기기(iPhone 시뮬레이터)에서 진짜 앱을 띄워 보는 시험.
// 1) 처음 설치한 것처럼 켜기: 예전 앱 진행 찾기(숨은 웹뷰)·튜토리얼·소리 재생이 오류 없이 도는지
// 2) 진행 중인 저장으로 다시 켜기: 탭·시트·설정·프로필을 열고, 지도를 두드려 소리를 내 본다
// 화면마다 사진을 찍고(ios-shots/), 오류는 모아서 마지막에 실패로 알린다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptocity/game/data.dart';
import 'package:taptocity/game/engine.dart';
import 'package:taptocity/game/storage.dart';
import 'package:taptocity/main.dart' as app;

Game _midGame() {
  final g = Game(Game.fresh(seed: 7));
  final S = g.S;
  S.rest['pfAsk'] = 1;
  S.rest['onb'] = 2;
  for (var y = CY - 4; y <= CY + 4; y++) {
    for (var x = CX - 4; x <= CX + 4; x++) {
      if (S.rev[y * W + x] == 0) g.reveal(y * W + x);
    }
  }
  S.m.addAll({'wood': 500, 'scrap': 500, 'cloth': 300, 'parts': 300, 'fuel': 200, 'food': 400, 'plate': 80, 'rope': 40, 'wire': 20, 'med': 10, 'batt': 30});
  S.lv = 3;
  g.recalc();
  for (final id in [9, 1, 2, 8, 3, 4, 5]) {
    if (mods[id] != null && g.canBuild(id)) g.buildMod(id);
  }
  for (final id in [0, 1, 2, 3, 4, 5]) {
    g.rescue(id, 'sig');
    g.rec(id)!['xp'] = 400;
  }
  g.autoGear();
  S.rest['mi'] = stepI('첫 원정 보내기');
  S.rest['storyI'] = g.mi;
  g.takeFx();
  return g;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];
  final log = <String>[];

  testWidgets('iPhone에서 앱 띄워 보기', (tester) async {
    Future<void> wait(double sec) async {
      final n = (sec * 10).round();
      for (var k = 0; k < n; k++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    void hook() {
      FlutterError.onError = (d) {
        final m = d.exceptionAsString().split('\n').first;
        if (!errors.contains(m)) errors.add(m);
      };
      WidgetsBinding.instance.platformDispatcher.onError = (e, st) {
        final m = '$e'.split('\n').first;
        if (!errors.contains(m)) errors.add(m);
        return true;
      };
    }

    var shot = 0;
    Future<void> snap(String name) async {
      try {
        await binding.takeScreenshot('${(++shot).toString().padLeft(2, '0')}-$name');
      } catch (e) {
        log.add('사진 실패 $name: $e');
      }
    }

    Future<bool> tapText(String t) async {
      final f = find.text(t);
      if (f.evaluate().isEmpty) {
        log.add('못 찾음: $t');
        return false;
      }
      await tester.tap(f.last, warnIfMissed: false);
      await wait(1.2);
      return true;
    }

    Future<void> tapMap(int n) async {
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      for (var k = 0; k < n; k++) {
        await tester.tapAt(Offset(size.width / 2 + (k % 3 - 1) * 30, size.height * .45 + (k % 2) * 20));
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    // ---------- 1) 처음 설치한 것처럼 ----------
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await app.start(cloud: false);
    hook();
    await wait(8); // 숨은 웹뷰가 예전 앱 저장소를 확인할 시간
    await snap('first-launch');
    log.add('첫 실행 화면 글자 ${find.byType(Text).evaluate().length}개');
    await tapMap(12);
    await wait(2);
    await snap('first-taps');
    if (tester.takeException() case final e?) errors.add('$e'.split('\n').first);

    // ---------- 2) 진행 중인 저장으로 ----------
    await Storage.save(_midGame().toJsonString());
    await Storage.setRaw('ttc_tut', '1');
    await Storage.setRaw('ttc_legacy_asked', '1');
    await app.start(cloud: false);
    hook();
    await wait(4);
    for (var k = 0; k < 4 && find.byType(Dialog).evaluate().isNotEmpty; k++) {
      Navigator.of(tester.element(find.byType(Dialog).last)).pop();
      await wait(1);
    }
    await snap('map');
    await tapMap(20);
    await wait(1);
    await snap('map-taps');
    for (final (tab, subs) in const [
      ('쉘터', ['건설', '가공', '연구']),
      ('일지', ['이야기', '도감']),
      ('원정', <String>[]),
      ('라디오', <String>[]),
      ('생존자', <String>[]),
    ]) {
      if (!await tapText(tab)) continue;
      await snap(tab);
      for (final s in subs) {
        if (await tapText(s)) await snap('$tab-$s');
      }
      await tapText(tab); // 다시 누르면 닫힘
    }
    await tester.tap(find.byKey(const ValueKey('setBtn')));
    await wait(1.5);
    await snap('settings');
    await tester.tapAt(const Offset(10, 10));
    await wait(1);
    for (var k = 0; k < 3 && find.byType(Dialog).evaluate().isNotEmpty; k++) {
      Navigator.of(tester.element(find.byType(Dialog).last)).pop();
      await wait(1);
    }
    await tester.tap(find.byKey(const ValueKey('pfBtn')));
    await wait(1.5);
    await snap('profile');
    // 앱이 뒤로 갔다 돌아오기 (저장·소리 멈춤·다시 켜기)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await wait(1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await wait(2);
    await snap('resumed');
    final saved = await Storage.getRaw(Storage.key);
    if (saved == null || (jsonDecode(saved) as Map)['lv'] != 3) errors.add('저장 확인 실패');
    if (tester.takeException() case final e?) errors.add('$e'.split('\n').first);

    binding.reportData = {'errors': errors, 'log': log};
    await SystemChannels.platform.invokeMethod<void>('HapticFeedback.vibrate'); // 진동 채널이 살아 있는지
    expect(errors, isEmpty, reason: errors.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 6)));
}
