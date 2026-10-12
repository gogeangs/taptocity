import 'dart:math' as math;

// 게임 저장 상태. 웹 버전의 `S`와 같은 필드 이름·같은 JSON 모양을 쓴다.
// 이 단계에서 아직 옮기지 않은 필드도 `rest`에 그대로 보관해, 웹 ↔ 네이티브를 오가도 진행이 사라지지 않게 한다.

int _i(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
double _d(Object? v, [double d = 0]) => v is num ? v.toDouble() : d;
num _n(Object? v, [num d = 0]) => v is num ? v : d;

Map<int, V> _intKeys<V>(Object? raw, V Function(Object?) f) {
  final out = <int, V>{};
  if (raw is Map) {
    raw.forEach((k, v) {
      final i = int.tryParse('$k');
      if (i != null) out[i] = f(v);
    });
  }
  return out;
}

Map<String, Object?> _strKeys<K>(Map<K, Object?> m) => {for (final e in m.entries) '${e.key}': e.value};

/// 쉘터 둘레 칸에 지은 모듈. id는 웹의 MODS 번호, l은 0~2단계.
class Mod {
  Mod(this.id, this.l);
  int id;
  int l;
  Map<String, Object?> toJson() => {'id': id, 'l': l};
  static Mod from(Object? v) {
    final m = v is Map ? v : const {};
    return Mod(_i(m['id']), _i(m['l']));
  }
}

/// 밝힌 칸 위의 뒤질 거리(폐허·폐차·상점·벙커·잔해·랜드마크).
class Site {
  Site({required this.k, required this.c, required this.max, required this.d, required this.hp, this.rt = 0});
  String k;
  int c;
  int max;
  double d;
  double hp;
  int rt;
  Map<String, Object?> toJson() => {'k': k, 'c': c, 'max': max, 'd': d, 'hp': hp, 'rt': rt};
  static Site from(Object? v) {
    final m = v is Map ? v : const {};
    return Site(k: '${m['k'] ?? 'rubble'}', c: _i(m['c']), max: _i(m['max'], 1), d: _d(m['d']), hp: _d(m['hp']), rt: _i(m['rt']));
  }
}

class Landmark {
  Landmark(this.k, this.ok);
  int k;
  bool ok;
  Map<String, Object?> toJson() => {'k': k, 'ok': ok};
  static Landmark from(Object? v) {
    final m = v is Map ? v : const {};
    return Landmark(_i(m['k']), m['ok'] == true);
  }
}

class GameState {
  GameState({
    required this.seed,
    required this.ter,
    required this.diaryAt,
    required this.rev,
    required this.hp,
    required this.m,
    required this.lv,
    Map<String, Object?>? rest,
  }) : rest = rest ?? {};

  int seed;
  List<int> ter;
  Map<int, int> diaryAt;
  List<int> rev;
  List<double> hp;
  Map<String, num> m;
  Map<String, num> got = {};
  Map<String, double> frac = {};
  int lv;
  Map<int, Mod> mods = {};
  int walls = 0;
  Map<int, Site> site = {};
  int tapLv = 0, splashLv = 0, droneLv = 0;
  List<int> found = [];
  int fevers = 0;
  int t = 0;
  Map<int, int> sig = {};
  Map<int, int> trace = {};
  Map<int, Landmark> lm = {};
  num hopeB = 0;
  bool half = false;
  int gen = 0;
  String? region;

  /// {k, m, t, label} 임시 효과. 없으면 null.
  Map<String, Object?>? buff;

  /// 생존자 기록(2단계에서 옮김). 웹 그대로 보관.
  Map<String, Object?> sv = {};

  /// 구조 캠프(2단계). 칸 번호 → {id, hp, max, visit}
  Map<int, Map<String, Object?>> camp = {};

  /// 생존자 배치(칸 → 생존자 id).
  Map<int, int> asg = {};

  /// 밤 재(3단계). 웹 그대로 보관.
  Map<String, Object?> ash = {};

  /// 아직 옮기지 않은 나머지 필드.
  Map<String, Object?> rest;

  static const _known = {
    'seed', 'ter', 'diaryAt', 'rev', 'hp', 'm', 'got', 'frac', 'lv', 'mods', 'walls', 'site', 'tapLv', 'splashLv', 'droneLv', 'found',
    'fevers', 't', 'sig', 'trace', 'lm', 'hopeB', 'half', 'gen', 'region', 'buff', 'sv', 'camp', 'asg', 'ash',
  };

  Map<String, Object?> toJson() => {
        ...rest,
        'seed': seed,
        'ter': ter,
        'diaryAt': _strKeys(diaryAt),
        'rev': rev,
        'hp': [for (final v in hp) v == v.roundToDouble() ? v.toInt() : v],
        'm': m,
        'got': got,
        'frac': frac,
        'lv': lv,
        'mods': {for (final e in mods.entries) '${e.key}': e.value.toJson()},
        'walls': walls,
        'site': {for (final e in site.entries) '${e.key}': e.value.toJson()},
        'tapLv': tapLv,
        'splashLv': splashLv,
        'droneLv': droneLv,
        'found': found,
        'fevers': fevers,
        't': t,
        'sig': _strKeys(sig),
        'trace': _strKeys(trace),
        'lm': {for (final e in lm.entries) '${e.key}': e.value.toJson()},
        'hopeB': hopeB,
        if (half) 'half': true,
        if (gen != 0) 'gen': gen,
        if (region != null) 'region': region,
        if (buff != null) 'buff': buff,
        'sv': sv,
        'camp': {for (final e in camp.entries) '${e.key}': e.value},
        'asg': _strKeys(asg),
        'ash': ash,
      };

  /// 웹 저장본(JSON)을 읽는다. 지도 크기가 맞지 않거나 자원이 없으면 null.
  static GameState? fromJson(Map<String, Object?> j, {int n = 1600}) {
    final ter = j['ter'];
    if (ter is! List || ter.length != n || j['m'] is! Map) return null;
    List<int> ints(Object? v, int d) => v is List ? [for (final x in v) _i(x, d)] : List.filled(n, d);
    final s = GameState(
      seed: _i(j['seed']),
      ter: [for (final x in ter) _i(x)],
      diaryAt: _intKeys(j['diaryAt'], (v) => _i(v)),
      rev: ints(j['rev'], 0),
      hp: j['hp'] is List ? [for (final x in j['hp'] as List) _d(x, -1)] : List.filled(n, -1.0),
      m: {for (final e in (j['m'] as Map).entries) '${e.key}': _n(e.value)},
      lv: math.min(5, math.max(1, _i(j['lv'], 1))),
      rest: {for (final e in j.entries) if (!_known.contains(e.key)) e.key: e.value},
    );
    if (j['got'] is Map) s.got = {for (final e in (j['got'] as Map).entries) '${e.key}': _n(e.value)};
    if (j['frac'] is Map) s.frac = {for (final e in (j['frac'] as Map).entries) '${e.key}': _d(e.value)};
    s.mods = _intKeys(j['mods'], Mod.from);
    s.walls = _i(j['walls']);
    s.site = _intKeys(j['site'], Site.from);
    s.tapLv = _i(j['tapLv']);
    s.splashLv = _i(j['splashLv']);
    s.droneLv = _i(j['droneLv']);
    s.found = j['found'] is List ? [for (final x in j['found'] as List) _i(x)] : [];
    s.fevers = _i(j['fevers']);
    s.t = _i(j['t']);
    s.sig = _intKeys(j['sig'], (v) => _i(v));
    s.trace = _intKeys(j['trace'], (v) => _i(v));
    s.lm = _intKeys(j['lm'], Landmark.from);
    s.hopeB = _n(j['hopeB']);
    s.half = j['half'] == true;
    s.gen = _i(j['gen']);
    s.region = j['region'] is String ? j['region'] as String : null;
    s.buff = j['buff'] is Map ? Map<String, Object?>.from(j['buff'] as Map) : null;
    s.sv = j['sv'] is Map ? Map<String, Object?>.from(j['sv'] as Map) : {};
    s.camp = _intKeys(j['camp'], (v) => v is Map ? Map<String, Object?>.from(v) : <String, Object?>{});
    s.asg = _intKeys(j['asg'], (v) => _i(v));
    s.ash = j['ash'] is Map ? Map<String, Object?>.from(j['ash'] as Map) : {};
    return s;
  }
}
