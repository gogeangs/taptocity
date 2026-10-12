// 기기(iPhone 시뮬레이터)에서 진짜 앱을 띄워 보는 시험.
// 1) 처음 설치한 것처럼 켜기: 예전 앱 진행 찾기(숨은 웹뷰)·튜토리얼·소리 재생이 오류 없이 도는지
// 2) 진행 중인 저장으로 다시 켜기: 탭·시트·설정·프로필을 열고, 지도를 두드려 소리를 내 본다
// 화면마다 사진을 찍고(ios-shots/), 오류는 모아서 마지막에 실패로 알린다.
import 'dart:async';
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
import 'package:taptocity/ui/sound.dart';

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
    final t0 = DateTime.now();
    // 시험 틀의 오류 처리기는 마지막에 되돌려 놓는다 (안 그러면 실패 보고까지 삼켜 멈춘다)
    final origErr = FlutterError.onError;
    final origPd = WidgetsBinding.instance.platformDispatcher.onError;
    String where(StackTrace? st) =>
        (st?.toString() ?? '').split('\n').where((l) => l.contains('package:taptocity')).take(3).map((l) => l.replaceAll(RegExp(r'^#\d+\s+'), '').trim()).join(' ← ');
    String at() => '${DateTime.now().difference(t0).inSeconds}s';

    Future<void> wait(double sec) async {
      final n = (sec * 10).round();
      for (var k = 0; k < n; k++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    void hook() {
      FlutterError.onError = (d) {
        final m = '${d.exceptionAsString().split('\n').first} @ ${where(d.stack)} (${d.context?.toDescription() ?? ''})';
        if (!errors.contains(m)) errors.add(m);
      };
      WidgetsBinding.instance.platformDispatcher.onError = (e, st) {
        final m = '${'$e'.split('\n').first} @ ${where(st)}';
        if (!errors.contains(m)) errors.add(m);
        return true;
      };
    }

    /// 한 단계: 90초 안에 끝나야 하고, 멈추거나 오류가 나도 기록하고 다음으로 간다
    Future<void> step(String name, Future<void> Function() f) async {
      // ignore: avoid_print
      print('▶ $name (${at()})');
      try {
        await f().timeout(const Duration(seconds: 90));
        log.add('✓ $name (${at()})');
      } on TimeoutException {
        errors.add('멈춤: $name');
        log.add('✗ $name 90초 넘게 멈춤');
      } catch (e) {
        errors.add('$name: ${'$e'.split('\n').first}');
        log.add('✗ $name: $e');
      }
      final ex = tester.takeException();
      if (ex != null) errors.add('$name: ${'$ex'.split('\n').first}');
    }

    var shot = 0;
    Future<void> snap(String name) async {
      try {
        await binding.takeScreenshot('${(++shot).toString().padLeft(2, '0')}-$name').timeout(const Duration(seconds: 20));
      } catch (e) {
        log.add('사진 실패 $name: $e');
      }
    }

    Future<bool> tapText(String t) async {
      final f = find.text(t);
      if (f.evaluate().isEmpty) {
        final seen = [for (final e in find.byType(Text).evaluate().take(12)) (e.widget as Text).data ?? ''].where((x) => x.isNotEmpty).join(' | ');
        log.add('못 찾음: $t — 화면 글자: $seen');
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

    Future<void> closeDialogs() async {
      for (var k = 0; k < 4 && find.byType(Dialog).evaluate().isNotEmpty; k++) {
        Navigator.of(tester.element(find.byType(Dialog).last)).pop();
        await wait(1);
      }
    }

    // ---------- 1) 처음 설치한 것처럼 ----------
    await step('처음 켜기', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await app.start(cloud: false);
      hook();
      await wait(8); // 숨은 웹뷰가 예전 앱 저장소를 확인할 시간
      log.add('첫 실행 화면 글자 ${find.byType(Text).evaluate().length}개');
    });
    await snap('first-launch');
    await step('첫 화면 두드리기', () async {
      await tapMap(12);
      await wait(2);
    });
    await snap('first-taps');

    // ---------- 2) 진행 중인 저장으로 ----------
    await step('진행 중인 저장으로 켜기', () async {
      await Storage.save(_midGame().toJsonString());
      await Storage.setRaw('ttc_tut', '1');
      await Storage.setRaw('ttc_legacy_asked', '1');
      await app.start(cloud: false);
      hook();
      await wait(4);
      await closeDialogs();
    });
    await snap('map');
    await step('지도 두드리기 (소리)', () async {
      await tapMap(20);
      await wait(1);
    });
    await snap('map-taps');
    for (final (tab, subs) in const [
      ('쉘터', ['건설', '가공', '연구']),
      ('일지', ['이야기', '도감']),
      ('원정', <String>[]),
      ('라디오', <String>[]),
      ('생존자', <String>[]),
    ]) {
      var opened = false;
      await step('탭 $tab', () async => opened = await tapText(tab));
      if (!opened) continue;
      await snap(tab);
      for (final sub in subs) {
        var ok = false;
        await step('$tab · $sub', () async => ok = await tapText(sub));
        if (ok) await snap('$tab-$sub');
      }
      await step('$tab 닫기', () async => await tapText(tab));
    }
    await step('설정', () async {
      await tester.tap(find.byKey(const ValueKey('setBtn')));
      await wait(1.5);
    });
    await snap('settings');
    await step('설정 닫기', () async {
      await tester.tapAt(const Offset(10, 10));
      await wait(1);
      await closeDialogs();
    });
    await step('프로필', () async {
      await tester.tap(find.byKey(const ValueKey('pfBtn')));
      await wait(1.5);
    });
    await snap('profile');
    await step('프로필 닫기', closeDialogs);
    // 앱이 뒤로 갔다 돌아오기 (저장·소리 멈춤·다시 켜기)
    await step('뒤로 갔다 돌아오기', () async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // 뒤로 간 동안은 화면을 그리지 않으므로 pump 없이 실제 시간만
      await Future<void>.delayed(const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await wait(2);
    });
    await snap('resumed');
    await step('저장 확인', () async {
      final saved = await Storage.getRaw(Storage.key);
      if (saved == null || (jsonDecode(saved) as Map)['lv'] != 3) errors.add('저장 확인 실패');
    });
    await step('진동 채널', () => SystemChannels.platform.invokeMethod<void>('HapticFeedback.vibrate'));

    log.add('끝까지 진행 (${at()})');
    binding.reportData = {'errors': errors, 'log': log};
    FlutterError.onError = origErr;
    WidgetsBinding.instance.platformDispatcher.onError = origPd;
    // 소리를 멈추고(재생 위치를 매 프레임 읽는 콜백이 남지 않게) 화면을 비운다
    await Sound.stopAll();
    await tester.pumpWidget(const SizedBox());
    for (var k = 0; k < 30 && tester.binding.transientCallbackCount > 0; k++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(errors, isEmpty, reason: errors.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
