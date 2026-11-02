// 웹 미리보기용 빈 광고 (ads_io.dart와 같은 모양)
import 'package:flutter/material.dart';

import '../game/engine.dart';

class Ads {
  Ads._();
  static bool get on => false;
  static Future<void> init() async {}
  static Future<void> wayAndAd(BuildContext context, String line) async {}
  static Future<bool> rewarded(BuildContext context, Game g) async => false;
}
