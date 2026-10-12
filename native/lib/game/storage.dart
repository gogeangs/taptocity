// 저장·불러오기. 웹과 같은 키 이름, 같은 JSON.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'state.dart';

class Storage {
  static const key = 'taptocity-shelter-v1';
  static SharedPreferences? _p;

  static Future<GameState?> load() async {
    _p ??= await SharedPreferences.getInstance();
    final raw = _p!.getString(key);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw);
      if (j is Map<String, dynamic>) return GameState.fromJson(j);
    } catch (_) {}
    return null;
  }

  /// 읽지 못한 저장을 지우지 않고 옆에 남겨 둔다
  static Future<void> backup() async {
    _p ??= await SharedPreferences.getInstance();
    final raw = _p!.getString(key);
    if (raw != null) await _p!.setString('$key-backup-${DateTime.now().millisecondsSinceEpoch}', raw);
  }

  static Future<void> save(String json) async {
    _p ??= await SharedPreferences.getInstance();
    await _p!.setString(key, json);
  }
}
