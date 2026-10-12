import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/engine.dart';
import 'report.dart';
import 'game/storage.dart';
import 'ui/atlas.dart';
import 'ui/game_screen.dart';
import 'ui/sound.dart';
import 'ui/story_ui.dart';
import 'ui/theme.dart';

Future<void> main() => start();

/// 앱 시작. 기기 시험(integration_test)은 cloud: false 로 불러 실제 클라우드·오류 보고를 건드리지 않는다
Future<void> start({bool cloud = true}) async {
  WidgetsFlutterBinding.ensureInitialized();
  Report.off = !cloud;
  // 잡히지 않은 오류는 개발자에게 (하루 다섯 건까지)
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    Report.error(d.exception, d.stack);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (e, st) {
    Report.error(e, st);
    return true;
  };
  GameScreen.cloudOn = cloud;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  await Prefs.load();
  await Atlas.load();
  final saved = await Storage.load();
  GameScreen.firstRun = saved == null;
  // 클라우드와 비교할 '마지막 저장 시각'은 오프라인 진행이 고치기 전에 잡아 둔다
  GameScreen.loadedT = saved?.t ?? 0;
  // 저장이 있는데 읽지 못했으면, 새 게임으로 덮어쓰기 전에 옆에 남겨 둔다
  if (saved == null && await Storage.getRaw(Storage.key) != null) await Storage.backup();
  Game.tutFlag = await Storage.getRaw('ttc_tut') == '1';
  Game game;
  try {
    game = Game(saved ?? Game.fresh());
  } catch (_) {
    // 저장을 읽다 문제가 생겨도 화면이 비지 않게: 원래 저장은 따로 남겨 두고 새로 시작
    if (saved != null) await Storage.backup();
    game = Game(Game.fresh());
  }
  if (saved != null) {
    game.offline(DateTime.now().millisecondsSinceEpoch);
  } else {
    await Storage.save(game.toJsonString());
  }
  runApp(TaptocityApp(game: game));
  Sound.init();
}

class TaptocityApp extends StatelessWidget {
  const TaptocityApp({super.key, required this.game});
  final Game game;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '탭투시티',
        debugShowCheckedModeBanner: false,
        theme: Ttc.theme(),
        navigatorObservers: [pageWatch],
        // 글자 크게 (웹 body.big: 창·띠·알림을 1.12배)
        builder: (context, child) => ValueListenableBuilder<int>(
          valueListenable: Prefs.version,
          builder: (c, _, __) => Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => Sound.kick(),
            child: Prefs.big ? MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.12)), child: child!) : child!,
          ),
        ),
        home: GameScreen(game: game),
      );
}
