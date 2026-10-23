// 휴대폰 알림 (2026-10-23 UX 제안 1): 앱을 닫아 둔 동안 '원정대가 돌아왔어요', '창고가 가득 찼어요'.
// 서버 없이 기기 안에서 예약한다. 앱이 뒤로 갈 때 다시 계산해 최대 2개만 걸고, 앱이 돌아오면 모두 지운다.
// 밤(22시~8시)에 걸리는 알림은 아침 8시로 미룬다. 설정의 '휴대폰 알림'으로 끈다.
// 처음 원정을 보낼 때(또는 설정에서 켤 때) 한 번만 허락을 묻는다. 시험(테스트)·웹에서는 아무것도 하지 않는다.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../game/data.dart';
import '../game/engine.dart';
import '../game/storage.dart';
import 'sound.dart';

class Notify {
  Notify._();
  static final _p = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _askedKey = 'ttc_noti_asked';

  /// 앱을 켤 때 한 번 (main)
  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      tzdata.initializeTimeZones();
      await _p.initialize(
          settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ));
      _ready = true;
      await _p.cancelAll();
    } catch (_) {
      _ready = false;
    }
  }

  /// 허락 묻기 (한 번만. force면 설정에서 켤 때 다시)
  static Future<void> ask({bool force = false}) async {
    if (!_ready) return;
    try {
      if (!force && await Storage.getRaw(_askedKey) != null) return;
      await Storage.setRaw(_askedKey, '1');
      await _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true);
      await _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// 앱이 돌아오면: 걸어 둔 알림을 지운다
  static Future<void> clear() async {
    if (!_ready) return;
    try {
      await _p.cancelAll();
    } catch (_) {}
  }

  /// 앱이 뒤로 갈 때: 비운 동안 일어날 일을 최대 2개 예약
  static Future<void> schedule(Game g) async {
    if (!_ready) return;
    try {
      await _p.cancelAll();
      if (!Prefs.noti || await Storage.getRaw(_askedKey) == null) return;
      final now = DateTime.now();
      final list = [for (final e in plan(g, now.millisecondsSinceEpoch)) (quiet(DateTime.fromMillisecondsSinceEpoch(e.$1)), e.$2, e.$3)]..sort((a, b) => a.$1.compareTo(b.$1));
      const det = NotificationDetails(
        android: AndroidNotificationDetails('ttc_events', '탭투시티 소식', channelDescription: '원정대 귀환·창고 가득', importance: Importance.defaultImportance, priority: Priority.defaultPriority),
        iOS: DarwinNotificationDetails(),
      );
      for (var k = 0; k < math.min(2, list.length); k++) {
        final (at, t, b) = list[k];
        await _p.zonedSchedule(id: k + 1, scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC), notificationDetails: det, androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, title: t, body: b);
      }
    } catch (_) {}
  }

  /// 밤 22시~8시면 아침 8시로
  static DateTime quiet(DateTime d) {
    if (d.hour >= 22) return DateTime(d.year, d.month, d.day + 1, 8);
    if (d.hour < 8) return DateTime(d.year, d.month, d.day, 8);
    return d;
  }

  /// 비운 동안 생길 일 (시각 ms, 제목, 글). 5분 안에 일어날 일은 빼고, 원정은 가장 먼저 돌아오는 팀 하나
  static List<(int, String, String)> plan(Game g, int now) {
    final out = <(int, String, String)>[];
    // 원정대 귀환
    int? first;
    String? name;
    g.expMap.forEach((k, x) {
      final end = ((x['end'] as num?) ?? 0).toInt();
      if (end > now + 300000 && (first == null || end < first!)) {
        first = end;
        name = expOf(k)?.name;
      }
    });
    if (first != null) out.add((first!, '원정대가 돌아왔어요', '${name ?? '원정'}에서 짐을 지고 왔어요. 풀어 보러 가요'));
    // 창고 가득: 비운 동안 자재는 켜 둔 때의 절반 빠르기로 8시간까지 모인다 (Game.offline)
    double? full;
    String? fk;
    for (final k in baseMats) {
      final r = (g.prod[k] ?? 0) * .5 / 60; // 1초에
      final left = g.capOf(k) - g.have(k);
      if (r <= 0 || left <= 0) continue;
      final s = left / r;
      if (s <= 8 * 3600 && (full == null || s < full)) {
        full = s;
        fk = k;
      }
    }
    if (full != null && full! * 1000 > 300000) out.add((now + (full! * 1000).round(), '창고가 가득 찼어요', '${matOf[fk]?.n ?? '자재'}가 더 쌓이지 않아요. 쓰러 와요'));
    return out;
  }
}
