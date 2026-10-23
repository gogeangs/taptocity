// 앱 오류 보고: 잡히지 않은 오류를 피드백과 같은 곳(feedback, cat 'crash')으로 보낸다.
// 같은 오류는 한 번만, 하루에 다섯 건까지. 이름·연락처는 담지 않는다 (개인정보 처리방침의 '진단' 범위).
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'game/cloud.dart';
import 'game/storage.dart';

class Report {
  Report._();
  static const ver = '2.0.1';
  static Map<String, dynamic> Function()? dev;
  static final Set<String> _seen = {};
  static bool off = false;

  static String get app => kIsWeb ? 'native' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

  static Future<void> error(Object e, StackTrace? st) async {
    if (off) return;
    try {
      final head = '$e'.split('\n').first;
      final key = head.length > 120 ? head.substring(0, 120) : head;
      if (!_seen.add(key)) return;
      final day = DateTime.now().toIso8601String().substring(0, 10);
      final raw = await Storage.getRaw('ttc_crash_day');
      var n = 0;
      if (raw != null) {
        final m = jsonDecode(raw) as Map;
        if (m['d'] == day) n = (m['n'] as num).toInt();
      }
      if (n >= 5) return;
      await Storage.setRaw('ttc_crash_day', jsonEncode({'d': day, 'n': n + 1}));
      final stack = (st?.toString() ?? '').split('\n').where((l) => l.trim().isNotEmpty).take(8).join('\n');
      var text = '[앱 오류 자동 보고] $head\n$stack';
      if (text.length > 800) text = text.substring(0, 800);
      final now = DateTime.now().millisecondsSinceEpoch;
      await Cloud.feedback({
        'id': 'c${now.toRadixString(36)}${key.hashCode.toUnsigned(20).toRadixString(36)}',
        'cat': 'crash',
        'text': text,
        'at': now,
        'ver': ver,
        'dev': dev?.call() ?? {'app': app},
      });
    } catch (_) {}
  }
}
