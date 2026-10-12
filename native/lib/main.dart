import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/engine.dart';
import 'game/storage.dart';
import 'ui/atlas.dart';
import 'ui/game_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  await Atlas.load();
  final saved = await Storage.load();
  final game = Game(saved ?? Game.fresh());
  if (saved != null) {
    game.offline(DateTime.now().millisecondsSinceEpoch);
  } else {
    await Storage.save(game.toJsonString());
  }
  runApp(TaptocityApp(game: game));
}

class TaptocityApp extends StatelessWidget {
  const TaptocityApp({super.key, required this.game});
  final Game game;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '탭투시티',
        debugShowCheckedModeBanner: false,
        theme: Ttc.theme(),
        home: GameScreen(game: game),
      );
}
