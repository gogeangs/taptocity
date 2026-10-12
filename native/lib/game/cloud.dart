// 클라우드 저장 (웹 cloud.js) — 같은 Firebase 프로젝트(taptocity-bd5d1)의 saves/{uid} 문서와 주고받는다.
// 앱에서는 Firebase SDK 대신 REST로 붙는다: 익명 로그인 → 토큰 갱신 → Firestore 문서 읽기·쓰기.
// 문서 모양은 웹과 같다: { data: 저장 JSON 문자열, t, lv, gen, play, name, at }
// 피드백(feedback/{id})과 오류 보고(cat: 'crash')도 같은 길로 보낸다. 보내지 못하면 기기에 모았다가 다음에 보낸다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'storage.dart';

class CloudSave {
  CloudSave(this.data, this.t, this.lv, this.gen, this.play, this.at);
  final String data;
  final int t, lv, gen, play, at;
}

class Cloud {
  Cloud._();
  static const apiKey = 'AIzaSyAzqQSuc2RtaenC7FD8vgtc8O-Q8ppL37k', project = 'taptocity-bd5d1';
  static const _authKey = 'ttc_cloud_auth', _fbKey = 'ttc_fb_q';
  static const _docs = 'https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents';

  /// 화면이 보는 상태 (웹 st)
  static final ValueNotifier<int> version = ValueNotifier(0);
  static String? uid;
  static int last = 0; // 마지막으로 올린 시각
  static String msg = '';
  static bool busy = false, offline = false;
  static String? _id, _refresh;
  static int _exp = 0;
  static String? _lastData;
  static http.Client client = http.Client();

  static void _ui() => version.value++;

  /// 앱 종류를 알리는 머리 (API 키 제한이 앱 패키지·번들로 걸려 있어도 통과하게)
  static Map<String, String> get _hd => {
        'Content-Type': 'application/json',
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) 'X-Android-Package': 'kr.co.itso.taptocity',
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) 'X-Ios-Bundle-Identifier': 'kr.co.itso.taptocity',
      };

  static Future<Map<String, dynamic>> _post(String url, Object body, {bool form = false}) async {
    final r = await client
        .post(Uri.parse(url),
            headers: form ? {..._hd, 'Content-Type': 'application/x-www-form-urlencoded'} : _hd, body: form ? body : jsonEncode(body))
        .timeout(const Duration(seconds: 12));
    final j = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 300) throw CloudError(r.statusCode, (j['error'] is Map ? (j['error'] as Map)['message'] : null)?.toString() ?? 'HTTP ${r.statusCode}');
    return j;
  }

  /// 로그인: 저장된 갱신 토큰이 있으면 그걸로, 없으면 새 익명 계정 (웹 signInAnonymously)
  static Future<bool> signIn() async {
    try {
      final raw = await Storage.getRaw(_authKey);
      if (raw != null) {
        final a = jsonDecode(raw) as Map;
        _refresh = a['r'] as String?;
        uid = a['u'] as String?;
      }
      if (_refresh != null) {
        await _token();
      } else {
        final j = await _post('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey', {'returnSecureToken': true});
        _setTok(j['idToken'] as String, j['refreshToken'] as String, j['localId'] as String, j['expiresIn']);
      }
      offline = false;
      _ui();
      return true;
    } on CloudError catch (e) {
      // 갱신 토큰이 더는 안 맞으면(계정 삭제 등) 새로 시작
      if (_refresh != null && (e.code == 400 || e.code == 401)) {
        _refresh = null;
        uid = null;
        await Storage.setRaw(_authKey, null);
        return signIn();
      }
      msg = '클라우드에 연결하지 못했어요';
      _ui();
      return false;
    } catch (_) {
      offline = true;
      _ui();
      return false;
    }
  }

  static void _setTok(String id, String refresh, String u, Object? exp) {
    _id = id;
    _refresh = refresh;
    uid = u;
    _exp = DateTime.now().millisecondsSinceEpoch + ((int.tryParse('$exp') ?? 3600) - 60) * 1000;
    Storage.setRaw(_authKey, jsonEncode({'r': refresh, 'u': u}));
  }

  static Future<String> _token() async {
    if (_id != null && DateTime.now().millisecondsSinceEpoch < _exp) return _id!;
    final j = await _post('https://securetoken.googleapis.com/v1/token?key=$apiKey', 'grant_type=refresh_token&refresh_token=${Uri.encodeComponent(_refresh!)}', form: true);
    _setTok(j['id_token'] as String, j['refresh_token'] as String, j['user_id'] as String, j['expires_in']);
    return _id!;
  }

  static Future<Map<String, String>> _auth() async => {..._hd, 'Authorization': 'Bearer ${await _token()}'};

  // ---------- Firestore 값 ----------
  static Map<String, dynamic> _val(Object? v) {
    if (v == null) return {'nullValue': null};
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': '$v'};
    if (v is num) return v == v.roundToDouble() && v.abs() < 9e15 ? {'integerValue': '${v.round()}'} : {'doubleValue': v};
    if (v is String) return {'stringValue': v};
    if (v is Map) return {'mapValue': {'fields': {for (final e in v.entries) '${e.key}': _val(e.value)}}};
    if (v is List) return {'arrayValue': {'values': [for (final x in v) _val(x)]}};
    return {'stringValue': '$v'};
  }

  static Object? _unval(Map v) {
    if (v.containsKey('stringValue')) return v['stringValue'];
    if (v.containsKey('integerValue')) return int.tryParse('${v['integerValue']}') ?? 0;
    if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
    if (v.containsKey('booleanValue')) return v['booleanValue'];
    if (v.containsKey('mapValue')) return {for (final e in (((v['mapValue'] as Map)['fields'] as Map?) ?? const {}).entries) e.key: _unval(e.value as Map)};
    return null;
  }

  static int _n(Object? v) => v is num ? v.toInt() : 0;

  /// 웹 sum(): 저장 JSON에서 요약
  static (int, int, int, int, String) summary(String data) {
    try {
      final o = jsonDecode(data) as Map;
      return (_n(o['t']), o['lv'] is num ? _n(o['lv']) : 1, _n(o['gen']), _n(o['playT']), ((o['pf'] as Map?)?['name'] as String?) ?? '');
    } catch (_) {
      return (0, 1, 0, 0, '');
    }
  }

  static String get _doc => '$_docs/saves/$uid';

  /// 클라우드 저장 읽기 (없으면 null)
  static Future<CloudSave?> fetch() async {
    if (uid == null) return null;
    final r = await client.get(Uri.parse(_doc), headers: await _auth()).timeout(const Duration(seconds: 12));
    if (r.statusCode == 404) return null;
    if (r.statusCode >= 300) throw CloudError(r.statusCode, r.body);
    final f = ((jsonDecode(r.body) as Map)['fields'] as Map?) ?? const {};
    Object? g(String k) => f[k] is Map ? _unval(f[k] as Map) : null;
    return CloudSave((g('data') as String?) ?? '', _n(g('t')), g('lv') is num ? _n(g('lv')) : 1, _n(g('gen')), _n(g('play')), _n(g('at')));
  }

  /// 올리기 (웹 up). force가 아니면 바뀐 게 있을 때만
  static Future<void> upload(String data, {bool force = false}) async {
    if (uid == null || busy) return;
    if (!force && data == _lastData) return;
    final s = summary(data), now = DateTime.now().millisecondsSinceEpoch;
    try {
      final body = {
        'fields': {
          'data': _val(data),
          't': _val(s.$1 > 0 ? s.$1 : now),
          'lv': _val(s.$2),
          'gen': _val(s.$3),
          'play': _val(s.$4),
          'name': _val(s.$5),
          'at': _val(now),
        }
      };
      final r = await client.patch(Uri.parse(_doc), headers: await _auth(), body: jsonEncode(body)).timeout(const Duration(seconds: 15));
      if (r.statusCode >= 300) throw CloudError(r.statusCode, r.body);
      _lastData = data;
      last = now;
      msg = '';
    } catch (_) {
      msg = '저장하지 못했어요. 인터넷 연결을 확인해 주세요';
    }
    _ui();
  }

  /// 클라우드 데이터 삭제 (웹 delete): 문서와 익명 계정을 지우고, 다음 저장부터 새 계정
  static Future<bool> wipe() async {
    if (uid == null) return false;
    try {
      busy = true;
      final h = await _auth();
      await client.delete(Uri.parse(_doc), headers: h).timeout(const Duration(seconds: 12));
      await _post('https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$apiKey', {'idToken': _id});
      await Storage.setRaw(_authKey, null);
      _id = null;
      _refresh = null;
      uid = null;
      _lastData = null;
      last = 0;
      msg = '클라우드 데이터를 삭제했어요';
      busy = false;
      _ui();
      unawaited(signIn());
      return true;
    } catch (_) {
      busy = false;
      msg = '삭제하지 못했어요. 인터넷 연결을 확인해 주세요';
      _ui();
      return false;
    }
  }

  // ---------- 피드백·오류 보고 (웹 ttcFeedback · fbQueue) ----------
  static Future<List<Map<String, dynamic>>> _queue() async {
    try {
      return [for (final x in jsonDecode(await Storage.getRaw(_fbKey) ?? '[]') as List) Map<String, dynamic>.from(x as Map)];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _enqueue(Map<String, dynamic> it) async {
    final q = await _queue();
    if (!q.any((x) => x['id'] == it['id'])) q.add(it);
    await Storage.setRaw(_fbKey, jsonEncode(q.length > 20 ? q.sublist(q.length - 20) : q));
  }

  static Future<void> _send(Map<String, dynamic> it) async {
    final body = {
      'fields': {for (final e in {...it, 'uid': uid}.entries) e.key: _val(e.value)}
    };
    final r = await client.patch(Uri.parse('$_docs/feedback/${it['id']}'), headers: await _auth(), body: jsonEncode(body)).timeout(const Duration(seconds: 9));
    if (r.statusCode >= 300) throw CloudError(r.statusCode, r.body);
  }

  /// 보내기. 'sent' 또는 'queued'
  static Future<String> feedback(Map<String, dynamic> it) async {
    if (uid == null) {
      await _enqueue(it);
      return 'queued';
    }
    try {
      await _send(it);
      unawaited(flush());
      return 'sent';
    } catch (_) {
      await _enqueue(it);
      return 'queued';
    }
  }

  static Future<void> flush() async {
    if (uid == null) return;
    final q = await _queue(), left = <Map<String, dynamic>>[];
    if (q.isEmpty) return;
    for (final it in q) {
      try {
        await _send(it);
      } catch (_) {
        left.add(it);
      }
    }
    await Storage.setRaw(_fbKey, jsonEncode(left));
  }
}

class CloudError implements Exception {
  CloudError(this.code, this.message);
  final int code;
  final String message;
  @override
  String toString() => 'CloudError($code): $message';
}
