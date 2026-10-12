// 게임 규칙. 웹 버전(index.html)의 같은 이름 함수를 그대로 옮겼다. 행 번호는 웹 기준.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'data.dart';
import 'rng.dart';
import 'state.dart';

/// 화면 연출(떠오르는 글자·알림·창 열기)을 그림 쪽에 알려 주는 신호.
sealed class Fx {
  const Fx();
}

class FxFloat extends Fx {
  const FxFloat(this.tile, this.text, this.color, {this.rise = 26});
  final int tile;
  final String text;
  final int color;
  final double rise;
}

class FxToast extends Fx {
  const FxToast(this.text);
  final String text;
}

class FxBurst extends Fx {
  const FxBurst(this.tile, this.color, this.n);
  final int tile, color, n;
}

class FxDiary extends Fx {
  const FxDiary(this.k);
  final int k;
}

class FxLevelUp extends Fx {
  const FxLevelUp(this.lv);
  final int lv;
}

class FxOffline extends Fx {
  const FxOffline(this.seconds, this.got);
  final double seconds;
  final Map<String, int> got;
}

/// 고정 무늬값 (웹 2148: speck, speck2) — 지도 꾸밈과 드론 순서에 쓴다.
final List<double> speck = () {
  final r = mulberry(7);
  return List<double>.generate(N, (_) => r());
}();
final List<double> speck2 = () {
  final r = mulberry(7);
  for (var i = 0; i < N; i++) {
    r();
  }
  return List<double>.generate(N, (_) => r());
}();

double dist(int i) => hypot(i % W - CX, i ~/ W - CY);
bool isSlot(int i) {
  final x = i % W - CX, y = i ~/ W - CY;
  return math.max(x.abs(), y.abs()) <= 2;
}

List<int> nb4(int i) {
  final x = i % W, y = i ~/ W;
  return [if (x > 0) i - 1, if (x < W - 1) i + 1, if (y > 0) i - W, if (y < H - 1) i + W];
}

Cost scaleCost(Cost o, [double f = 1]) {
  final r = <String, num>{};
  o.forEach((k, v) {
    final c = (v * f).ceil();
    if (c > 0) r[k] = c;
  });
  return r;
}

/// 웹 genMap(seed) (1785)
(List<int>, Map<int, int>) genMap(int seed) {
  final r = mulberry(seed), n1 = valueNoise(r, 6), n2 = valueNoise(r, 4);
  final ter = List<int>.filled(N, T.ash);
  final diaryAt = <int, int>{};
  for (var i = 0; i < N; i++) {
    final x = i % W, y = i ~/ W;
    if (dist(i) < 2.5) continue;
    if (n1(x, y) > .66) {
      ter[i] = T.water;
    } else if (n2(x, y) > .64) {
      ter[i] = T.ruin;
    }
  }
  var p = 0, g = 0;
  while (p < 14 && g++ < 3000) {
    final i = (r() * N).floor();
    if (dist(i) > 4 && dist(i) < 19 && ter[i] == T.ash) {
      ter[i] = T.silo;
      p++;
    }
  }
  const rads = [3.2, 5.5, 8, 10.5, 13, 15.5, 18];
  for (var k = 0; k < rads.length; k++) {
    for (var t = 0; t < 400; t++) {
      final a = r() * math.pi * 2;
      final x = jsRound(CX + math.cos(a) * rads[k]), y = jsRound(CY + math.sin(a) * rads[k]);
      if (x < 1 || y < 1 || x >= W - 1 || y >= H - 1) continue;
      final i = y * W + x;
      if (ter[i] != T.water) {
        ter[i] = T.diary;
        diaryAt[i] = k;
        break;
      }
    }
  }
  return (ter, diaryAt);
}

class Game extends ChangeNotifier {
  Game(this.S, {math.Random? random}) : rnd = random ?? math.Random() {
    _rebuildFrontier();
    recalc();
  }

  GameState S;
  final math.Random rnd;

  /// 지도가 바뀔 때만 올라가는 번호. 지도 그림은 이 값이 바뀔 때만 다시 그린다.
  final ValueNotifier<int> mapVersion = ValueNotifier(0);
  final List<Fx> fx = [];
  bool dirty = false; // 저장할 변화가 있음

  // ---------- 파생 값 (웹 D, 1821) ----------
  Map<String, double> E = {};
  int hope = 0, cap = 60;
  Map<String, double> prod = {};
  double eat = 0, fuelUse = 0, tapAdd = 0, heal = 1, trustM = 1, visitDisc = 0, expDisc = 0;
  int genOn = 0;
  bool hungry = false;
  List<double> green = List.filled(N, 0);
  Map<int, int> modAt = {}; // 칸 → 슬롯 번호
  List<int> prot = List.filled(N, 0);

  // ---------- 손맛 ----------
  double combo = 0, idle = 0, fever = 0, feverT = 6;
  int aim = -1;
  (int, int) aimDir = (0, -1);
  final Set<int> frontier = {};

  // ================= 새 게임 (웹 fresh 1796) =================
  static GameState fresh({int? seed, math.Random? random}) {
    final rnd = random ?? math.Random();
    final sd = seed ?? rnd.nextInt(1000000000);
    final (ter, diaryAt) = genMap(sd);
    final s = GameState(
      seed: sd,
      ter: ter,
      diaryAt: diaryAt,
      rev: List.filled(N, 0),
      hp: List.filled(N, -1.0),
      m: {'wood': 12, 'scrap': 6, 'food': 20},
      lv: 1,
      rest: {'mi': 0, 'endT': 0, 'clock': 0, 'nights': 0, 'evDone': 0, 'shield': 0, 'party': [], 'cd': {}, 'exp': {}, 'inv': [], 'iu': 0,
        'ug': {'best': 0, 'runs': 0, 'bestWith': {}}},
    );
    s.t = DateTime.now().millisecondsSinceEpoch;
    for (var y = CY - 2; y <= CY + 2; y++) {
      for (var x = CX - 2; x <= CX + 2; x++) {
        final i = y * W + x;
        if (s.ter[i] == T.water || isSlot(i)) s.ter[i] = T.ash;
      }
    }
    for (var y = CY - 1; y <= CY + 1; y++) {
      for (var x = CX - 1; x <= CX + 1; x++) {
        s.rev[y * W + x] = 1;
      }
    }
    for (final (dx, dy, t) in const [(3, 0, T.ruin), (-1, -3, T.car), (-3, 2, T.ruin), (2, 3, T.crate)]) {
      s.ter[(CY + dy) * W + CX + dx] = t;
    }
    fixDiaries(s, rnd);
    placeSignals(s);
    sprinkle(s);
    return s;
  }

  static bool _dead(GameState s, int id) {
    final d = s.rest['dead'];
    return d is List && d.any((e) => e is Map && e['id'] == id);
  }

  static bool _inStay(GameState s, int id) {
    final st = s.rest['stay'];
    if (st is! Map) return false;
    return st.values.any((v) => v is List && v.any((e) => e == id || (e is Map && e['id'] == id)));
  }

  /// 웹 fixDiaries (1803)
  static void fixDiaries(GameState s, math.Random rnd) {
    final have = <int>{};
    s.diaryAt.forEach((i, k) {
      if (s.ter[i] == T.diary || s.rev[i] == 1) have.add(k);
    });
    const rads = [3.8, 5.5, 8, 10.5, 13, 15.5, 18];
    for (var k = 0; k < 7; k++) {
      if (have.contains(k) || s.found.contains(k)) continue;
      for (var g = 0; g < 600; g++) {
        final a = rnd.nextDouble() * math.pi * 2, rr = rads[k] + (g ~/ 100) * .5;
        final x = jsRound(CX + math.cos(a) * rr), y = jsRound(CY + math.sin(a) * rr);
        if (x < 1 || y < 1 || x >= W - 1 || y >= H - 1) continue;
        final i = y * W + x;
        if (s.rev[i] == 1 || isSlot(i) || s.ter[i] != T.ash || s.sig.containsKey(i)) continue;
        s.ter[i] = T.diary;
        s.diaryAt[i] = k;
        break;
      }
    }
  }

  /// 웹 placeSignals (1814)
  static void placeSignals(GameState s) {
    s.sig = {};
    final r = mulberry(s.seed + 77);
    for (final sv in survivors) {
      final here = sv.src == 'sig' || (sv.src == 'town' && s.gen != 0 && sv.region == s.region);
      if (!here || s.sv.containsKey('${sv.id}') || _dead(s, sv.id) || _inStay(s, sv.id)) continue;
      for (var t = 0; t < 900; t++) {
        final a = r() * math.pi * 2, rad = sv.d + (t ~/ 150) * .8;
        final x = jsRound(CX + math.cos(a) * rad), y = jsRound(CY + math.sin(a) * rad);
        if (x < 1 || y < 1 || x >= W - 1 || y >= H - 1) continue;
        final i = y * W + x;
        if (s.rev[i] == 1 || isSlot(i) || s.ter[i] == T.water || s.ter[i] == T.diary || s.ter[i] == T.silo || s.sig.containsKey(i)) continue;
        s.sig[i] = sv.id;
        break;
      }
    }
  }

  /// 웹 sprinkle (1805)
  static void sprinkle(GameState s) {
    final r = mulberry(s.seed + 5);
    s.lm = {};
    s.trace = {};
    bool free(int i) => s.rev[i] == 0 && s.ter[i] == T.ash && !s.sig.containsKey(i) && !isSlot(i) && dist(i) > 2.5;
    void put(int type, int n) {
      var c = 0, g = 0;
      while (c < n && g++ < 6000) {
        final i = (r() * N).floor();
        if (dist(i) > 19 || !free(i)) continue;
        s.ter[i] = type;
        c++;
      }
    }

    put(T.car, 40);
    put(T.crate, 28);
    put(T.ruin, 45);
    for (final sv in survivors) {
      if (sv.hidden || (sv.region != null && sv.region != (s.region ?? 'home'))) continue;
      for (var g = 0; g < 500; g++) {
        final i = (r() * N).floor(), d = dist(i);
        if (d < 3 || d > 15 || !free(i)) continue;
        s.ter[i] = T.trace;
        s.trace[i] = sv.id;
        break;
      }
    }
    for (var k = 0; k < landmarks.length; k++) {
      final l = landmarks[k];
      for (var g = 0; g < 900; g++) {
        final a = r() * math.pi * 2, rad = l.d + (g ~/ 150) * .6;
        final x = jsRound(CX + math.cos(a) * rad), y = jsRound(CY + math.sin(a) * rad);
        if (x < 1 || y < 1 || x >= W - 1 || y >= H - 1) continue;
        final i = y * W + x;
        if (!free(i)) continue;
        s.ter[i] = T.lm;
        s.lm[i] = Landmark(k, false);
        break;
      }
    }
    void near(int type, int min) {
      var c = 0;
      for (var i = 0; i < N; i++) {
        if (s.ter[i] == type && dist(i) <= 7) c++;
      }
      for (var g = 0; c < min && g < 4000; g++) {
        final a = r() * math.pi * 2, rad = 3 + r() * 4;
        final x = jsRound(CX + math.cos(a) * rad), y = jsRound(CY + math.sin(a) * rad), i = y * W + x;
        if (dist(i) <= 7 && free(i)) {
          s.ter[i] = type;
          c++;
        }
      }
    }

    near(T.crate, 4);
    near(T.ruin, 10);
  }

  // ================= 계산 =================
  int maxHp(int i) {
    final d = dist(i), t = S.ter[i];
    final k = t == T.ruin ? 1.3 : t == T.silo ? 1.8 : t == T.lm ? 2.2 : t == T.car ? 1.2 : 1.0;
    return jsRound((5 + d * 1.5) * (1 + .2 * S.gen) * k);
  }

  bool lmOn(String key) => S.lm.values.any((l) => l.ok && landmarks[l.k].key == key);
  int capOf(String k) {
    final t = matOf[k]?.tier ?? 0;
    return t >= 3 ? 1000000000 : t == 2 ? (cap / 4).ceil() : cap;
  }

  num have(String k) => S.m[k] ?? 0;

  Map<String, int> give(Map<String, num> o) {
    final got = <String, int>{};
    o.forEach((k, v) {
      final n = math.max(0, jsRound(v));
      if (n == 0) return;
      final room = math.max(0, capOf(k) - have(k)).toInt();
      final a = math.min(n, room);
      S.m[k] = have(k) + a;
      S.got[k] = (S.got[k] ?? 0) + a;
      if (a > 0) got[k] = a;
    });
    if (got.isNotEmpty) dirty = true;
    return got;
  }

  bool canPay(Cost o) => o.entries.every((e) => have(e.key) >= e.value);
  bool pay(Cost o) {
    if (!canPay(o)) return false;
    o.forEach((k, v) => S.m[k] = have(k) - v);
    dirty = true;
    return true;
  }

  int modLv(int id) {
    var l = -1;
    for (final m in S.mods.values) {
      if (m.id == id) l = math.max(l, m.l);
    }
    return l;
  }

  int get wbL => modLv(1) + 1;
  int modN(int id) => S.mods.values.where((m) => m.id == id).length;
  Mod? modAtTile(int i) {
    final k = modAt[i];
    return k == null ? null : S.mods[k];
  }

  double get lvScale => 1 + (S.lv - 1) * .6;
  double get costMult => (1 - (E['cost'] ?? 0)) * (S.half ? .5 : 1);
  double get tapPow => (1 + S.tapLv) * (1 + (E['tap'] ?? 0) + tapAdd) * (1 + (S.lv - 1) * .15);
  double droneDmg([int e = 0]) => (S.droneLv + e) * (1 + S.tapLv) * .5 * (lmOn('station') ? 2 : 1);
  double get scavMult {
    final b = S.buff;
    final bm = b != null && b['k'] == 'scav' ? (b['m'] as num).toDouble() : 1.0;
    return (1 + (E['scav'] ?? 0) + (S.lv - 1) * .15) * (fever > 0 ? 2 : 1) * bm;
  }

  double buffMult(String k) {
    final b = S.buff;
    if (b == null) return 1;
    return (b['k'] == 'all' || (b['k'] == 'farm' && k == 'food')) ? (b['m'] as num).toDouble() : 1;
  }

  Cost modCost(int id, int l) => scaleCost(mods[id]!.cost[l], costMult);
  Cost modBuildCost(int id) => scaleCost(mods[id]!.cost[0], costMult * (1 + .6 * modN(id)));
  double shupPace(int i) => S.gen != 0 ? const [.8, .65, .55, .55][i] : const [1.0, 1.0, .7, .7][i];
  Cost? get shelterUpCost => S.lv >= 5 ? null : scaleCost(scaleCost(shupBase[S.lv - 1], shupPace(S.lv - 1)), costMult);
  Cost wallCost(int k) => scaleCost(wallsInfo[k].$2, costMult);
  Cost lmCost(int k) => scaleCost(landmarks[k].cost, costMult);
  Cost recipeInp(Recipe r) => r.inp[math.min(2, math.max(0, wbL - 1))];
  String recipeLock(Recipe r) => (r.wb > 0 && wbL < r.wb) ? '작업대 ${r.wb}단계' : (r.lv > 0 && S.lv < r.lv) ? '쉘터 Lv.${r.lv}' : '';

  // 연구 (웹 UPG 1867)
  static const upgMax = {'tap': 20, 'splash': 5, 'drone': 15};
  int upgLv(String k) => k == 'tap' ? S.tapLv : k == 'splash' ? S.splashLv : S.droneLv;
  Cost upgCost(String k) {
    final l = upgLv(k);
    if (k == 'tap') return scaleCost(l < 2 ? {'scrap': 8 + l * 8} : {'scrap': 10 * math.pow(1.6, l), 'plate': 1.5 * math.pow(1.5, l - 2)});
    if (k == 'splash') return scaleCost({'cloth': 10 * math.pow(2, l), 'fuel': 3 * math.pow(1.8, l), 'rope': l});
    return scaleCost({'parts': 10 * math.pow(1.7, l), 'fuel': 4 * math.pow(1.5, l), 'wire': l >= 2 ? l - 1 : 0});
  }

  int upgWb(String k) => k == 'tap' ? (S.tapLv >= 2 ? 1 : 0) : k == 'splash' ? 1 : 2;

  int siteHp(Site s) => jsRound(sites[s.k]!.hp * 2.8 * (1 + s.d * .06) * (1 + (S.lv - 1) * .25));
  bool siteLive(int i) {
    final s = S.site[i];
    return s != null && s.c > 0 && s.k != 'lm' && S.rev[i] == 1;
  }

  double get perMin => prod.values.fold(0.0, (a, v) => a + v);

  // ================= 파생 값 다시 계산 (웹 recalc 1837) =================
  void recalc() {
    final e = <String, double>{'scav': 0, 'tap': 0, 'thrift': 0, 'hope': 0, 'food': 0, 'cost': 0, 'craft': 0, 'fever': 0, 'global': 0};
    // 생존자·인연·장비 효과는 2단계에서 옮긴다
    e['cost'] = math.min(.5, e['cost']!);
    e['thrift'] = math.min(.7, e['thrift']!);
    E = e;
    feverT = 6 + e['fever']!;
    modAt = {for (final k in S.mods.keys) slotTile(k): k};
    final p = <String, double>{};
    void add(String k, double v) => p[k] = (p[k] ?? 0) + v;
    double capAdd = 0, waterRed = 0, hopeM = 0, genB = 0, tAdd = 0, fUse = 0;
    prot = List.filled(N, 0);
    heal = 1;
    trustM = 1;
    visitDisc = 0;
    expDisc = 0;
    genOn = 0;
    for (final en in S.mods.entries) {
      final m = en.value, l = m.l, t = slotTile(en.key);
      final ash = S.ash['$t'];
      final stuck = ash is Map && ash['stuck'] == true;
      final pm = stuck ? 0.0 : 1.0; // 배치 배수(asgMult)는 2단계
      final q = stuck ? 0.0 : 1 + (pm - 1) * .5;
      switch (m.id) {
        case 2:
          add('food', const [6.0, 14.0, 28.0][l] * pm);
        case 9:
          add('scrap', const [3.0, 6.0, 11.0][l] * pm);
          add('wood', const [2.0, 4.0, 8.0][l] * pm);
        case 3:
          waterRed += const [.2, .35, .5][l] * q;
          hopeM += const [2, 4, 6][l];
        case 4:
          capAdd += const [80, 200, 400][l] * q;
        case 8:
          if (!stuck) {
            final r = const [2, 3, 4][l], x = t % W, y = t ~/ W;
            for (var dy = -r; dy <= r; dy++) {
              for (var dx = -r; dx <= r; dx++) {
                final xx = x + dx, yy = y + dy;
                if (xx >= 0 && yy >= 0 && xx < W && yy < H) prot[yy * W + xx] = 1;
              }
            }
            tAdd += const [.1, .15, .2][l] * q;
          }
        case 5:
          if (!stuck) {
            fUse += const [.6, .9, 1.3][l];
            if (have('fuel') > 0) {
              genB += const [.25, .5, .8][l] * q;
              tAdd += const [.2, .3, .4][l] * q;
              genOn = l + 1;
            }
          }
        case 6:
          heal = math.max(heal, const [2.0, 3.0, 4.0][l] * q);
          trustM = math.max(trustM, 1 + const [.1, .2, .3][l] * q);
        case 7:
          visitDisc = math.max(visitDisc, const [.2, .35, .5][l]);
          expDisc = math.max(expDisc, const [0.0, .1, .2][l]);
      }
    }
    final home = S.sv.values.where((r) => !(r is Map && r['away'] != null && r['away'] != false && r['away'] != 0)).length;
    eat = home * 1 * (1 - e['thrift']!) * (1 - math.min(.7, waterRed));
    fuelUse = fUse;
    tapAdd = tAdd;
    final mult = (1 + e['global']! + genB) * (hungry ? .5 : 1);
    p.updateAll((k, v) => v * mult * (k == 'food' ? (1 + e['food']!) * (lmOn('tower') ? 1.5 : 1) : 1));
    for (final k in const ['wood', 'scrap', 'cloth', 'parts', 'fuel']) {
      if (p[k] != null && p[k] != 0) p[k] = p[k]! * 1.3;
    }
    prod = p;
    cap = (capByLv[S.lv - 1] + capAdd).floor();
    final hopeT = S.rest['hopeT'];
    final ht = hopeT is Map && (hopeT['until'] as num? ?? 0) > DateTime.now().millisecondsSinceEpoch ? (hopeT['v'] as num? ?? 0) : 0;
    final h = S.sv.length * 3 + e['hope']! + S.hopeB + ht + hopeM + (S.lv - 1) * 4 + S.lm.values.where((l) => l.ok).length * 5;
    hope = jsRound(h);
    final rg = S.lv + .5;
    for (var i = 0; i < N; i++) {
      final d = math.max((i % W - CX).abs(), (i ~/ W - CY).abs());
      green[i] = d <= rg ? math.min(1.0, (rg - d + .6) / 2.2) : 0.0;
    }
  }

  // ================= 경계(밝힌 칸 바로 옆 구름) =================
  bool isFrontier(int i) => S.rev[i] == 0 && nb4(i).any((j) => S.rev[j] == 1);
  void _rebuildFrontier() {
    frontier.clear();
    for (var i = 0; i < N; i++) {
      if (isFrontier(i)) frontier.add(i);
    }
  }

  int frontierNearest() {
    var best = -1;
    var bd = 1e9;
    for (final i in frontier) {
      final d = dist(i) + speck[i] * 1.5;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  int nearestFrontierTo(int i) {
    var best = -1;
    var bd = 1e9;
    final x = i % W, y = i ~/ W;
    for (final j in frontier) {
      final d = (j % W - x).abs() + (j ~/ W - y).abs() + speck[j] * .5;
      if (d < bd) {
        bd = d;
        best = j;
      }
    }
    return best;
  }

  void setAim(int i) {
    if (i < 0) return;
    aim = i;
    if (S.rev[i] == 1) return;
    for (final r in nb4(i)) {
      if (S.rev[r] == 1) {
        aimDir = (i % W - r % W, i ~/ W - r ~/ W);
        break;
      }
    }
  }

  void nextAim(int i) {
    final x = i % W, y = i ~/ W, nx = x + aimDir.$1, ny = y + aimDir.$2;
    if (nx >= 0 && ny >= 0 && nx < W && ny < H && S.rev[ny * W + nx] == 0) {
      aim = ny * W + nx;
      return;
    }
    final side = nb4(i).where((j) => S.rev[j] == 0).toList();
    if (side.isNotEmpty) {
      setAim(side[rnd.nextInt(side.length)]);
      return;
    }
    setAim(nearestFrontierTo(i));
  }

  bool get aimValid =>
      aim >= 0 && (frontier.contains(aim) || siteLive(aim) || (S.site[aim]?.k == 'lm' && (S.site[aim]?.c ?? 0) > 0 && !(S.lm[aim]?.ok ?? true)));

  // ================= 두드리기 (웹 2402–2462) =================
  int get comboMax => lmOn('gas') ? 16 : 24;
  void addCombo() {
    idle = 0;
    if (fever > 0) return;
    combo = math.min(comboMax.toDouble(), combo + 1);
    if (combo >= comboMax) {
      fever = feverT;
      combo = 0;
      S.fevers++;
      if (S.fevers <= 3) fx.add(const FxToast('랜턴 피버! 넓게, 두 배로 밝혀요'));
    }
  }

  void damage(int i, double amt, {bool fromTap = false}) {
    if (S.rev[i] == 1) return;
    if (S.hp[i] < 0) S.hp[i] = maxHp(i).toDouble();
    S.hp[i] -= amt;
    if (fromTap) fx.add(FxBurst(i, 0xFFF3A53A, 5));
    if (S.hp[i] <= 0) reveal(i);
    _mapChanged();
  }

  void makeSite(int i, String k) {
    final s = Site(k: k, c: sites[k]!.c, max: sites[k]!.c, d: dist(i), hp: 0);
    s.hp = siteHp(s).toDouble();
    S.site[i] = s;
  }

  void reveal(int i) {
    S.rev[i] = 1;
    S.hp[i] = 0;
    frontier.remove(i);
    for (final j in nb4(i)) {
      if (S.rev[j] == 0) frontier.add(j);
    }
    if (i == aim) nextAim(i);
    fx.add(FxBurst(i, 0xFFFFCF7A, 12));
    final t = S.ter[i];
    if (isSlot(i)) {
      if (t != T.water) S.ter[i] = T.ash;
    } else if (t == T.ruin) {
      makeSite(i, 'house');
    } else if (t == T.car) {
      makeSite(i, 'car');
    } else if (t == T.crate) {
      makeSite(i, 'store');
      if (rnd.nextDouble() < .5) openCrate(i);
    } else if (t == T.silo) {
      makeSite(i, 'bunker');
      fx.add(const FxToast('버려진 벙커를 찾았어요! 두드려서 물자를 꺼내요'));
    } else if (t == T.lm) {
      makeSite(i, 'lm');
      fx.add(FxToast('랜드마크 발견: ${lmText(S.lm[i]!.k, S.region)[0]}! 뒤지거나 복구할 수 있어요'));
    } else if (t == T.trace) {
      final k = S.trace.remove(i);
      S.ter[i] = T.ash;
      if (k != null) findTrace(k, i);
    } else if (t == T.diary) {
      final k = S.diaryAt[i];
      S.ter[i] = T.ash;
      if (k != null && !S.found.contains(k)) {
        S.found.add(k);
        fx.add(FxDiary(k));
      }
    } else if (t == T.ash && rnd.nextDouble() < .22) {
      makeSite(i, 'rubble');
    }
    final id = S.sig.remove(i);
    if (id != null) makeCamp(i, id);
    dirty = true;
  }

  void openCrate(int i) {
    final r = rnd.nextDouble();
    if (r < .45) {
      final k = const ['cloth', 'food', 'parts'][rnd.nextInt(3)];
      loot({k: jsRound(6 * lvScale)}, i);
      fx.add(const FxToast('물자 상자를 찾았어요!'));
    } else if (r < .75) {
      fever = feverT;
      S.fevers++;
      fx.add(const FxToast('등유 한 통을 찾았어요! 랜턴 피버'));
    } else {
      S.buff = {'k': 'all', 'm': 1.5, 't': 45, 'label': '통조림 잔치'};
      fx.add(const FxToast('통조림 상자! 45초 동안 생산 ×1.5'));
    }
  }

  void findTrace(int k, int i) {
    if (k >= survivors.length) return;
    final sv = survivors[k];
    final it = traceItem(k) ?? '${sv.name}의 손때 묻은 물건';
    final rec = S.sv['$k'];
    if (rec is Map) {
      rec['xp'] = ((rec['xp'] as num?) ?? 0) + 60;
      fx.add(FxToast('$it. ${sv.name}의 물건이에요. 돌려주니 무척 반가워해요'));
    } else {
      S.hopeB += 2;
      recalc();
      fx.add(FxToast('${jo(it, '을', '를')} 주웠어요. 주인을 찾으면 좋겠어요 (희망 +2)'));
    }
    fx.add(FxBurst(i, 0xFFFFE68A, 14));
  }

  void makeCamp(int i, int id) {
    if (S.sv.containsKey('$id')) return;
    final hp = jsRound(14 + dist(i) * 2.6);
    S.camp[i] = {'id': id, 'hp': hp, 'max': hp, 'visit': false};
    S.hp[i] = 0;
    S.site.remove(i);
    S.ter[i] = T.ash;
    fx.add(FxBurst(i, 0xFFCFE6FF, 24));
    fx.add(const FxToast('생존자를 찾았어요! 잔해를 치우고 구조해요'));
  }

  Map<String, int> loot(Map<String, num> o, int tile) {
    final got = give(o);
    var rise = 26.0;
    got.forEach((k, v) {
      fx.add(FxFloat(tile, '+$v ${matOf[k]!.n}', 0xFFFFE6A0, rise: rise));
      rise += 16;
    });
    return got;
  }

  bool hitSite(int i, double amt) {
    final s = S.site[i];
    if (s == null || s.c <= 0) return false;
    addCombo();
    s.hp -= amt;
    while (s.hp <= 0 && s.c > 0) {
      s.c--;
      s.hp += siteHp(s);
      haul(i, s);
    }
    if (s.c <= 0) {
      s.hp = siteHp(s).toDouble();
      s.rt = 0;
      fx.add(FxFloat(i, sites[s.k]!.regen > 0 ? '다 털었다 · 나중에 다시' : '다 털었다', 0xFFDCD2BE, rise: 34));
      if (aim == i) aim = -1;
    }
    _mapChanged();
    dirty = true;
    return true;
  }

  void haul(int i, Site s) {
    final drops = s.k == 'lm' ? landmarks[S.lm[i]!.k].drops : sites[s.k]!.drops;
    var r = rnd.nextDouble();
    var k = drops.last.$1;
    for (final (m, p) in drops) {
      if (r < p) {
        k = m;
        break;
      }
      r -= p;
    }
    final n = matOf[k]!.tier == 2 ? 1 : math.max(1, jsRound((1 + rnd.nextDouble() * 1.3) * scavMult));
    final got = loot({k: n}, i);
    if (!got.containsKey(k)) fx.add(FxFloat(i, '${matOf[k]!.n} 창고가 가득 찼어요', 0xFFFFB4A0));
    if ((s.k == 'bunker' || s.k == 'lm') && rnd.nextDouble() < .1) loot({'batt': 1}, i);
    // 장비·유물 발견은 2·4단계에서
  }

  /// 구름 칸 하나를 두드린다 (웹 dig 2459)
  void dig(int i) {
    final x = i % W;
    addCombo();
    damage(i, tapPow * (fever > 0 ? 2 : 1), fromTap: true);
    final spl = S.splashLv + (fever > 0 ? tapPow : 0);
    if (spl > 0) {
      final tg = fever > 0
          ? [...nb4(i), i - W - 1, i - W + 1, i + W - 1, i + W + 1].where((j) => j >= 0 && j < N && ((j % W) - x).abs() <= 1)
          : nb4(i);
      for (final j in tg) {
        if (S.rev[j] == 0) damage(j, spl.toDouble());
      }
    }
  }

  /// 랜턴 버튼 (웹 digAim 2450의 지도 부분)
  void digAim() {
    if (!aimValid) {
      setAim(nearestFrontierTo(C0));
      if (aim < 0) return;
    }
    final pw = tapPow * (fever > 0 ? 2 : 1);
    if (S.rev[aim] == 1 && S.site[aim] != null) {
      hitSite(aim, pw);
    } else {
      dig(aim);
    }
  }

  /// 지도를 손가락으로 두드림. 무엇을 했는지 돌려준다.
  String tapTile(int i) {
    if (i < 0) return 'none';
    if (S.rev[i] == 1) {
      if (siteLive(i)) {
        setAim(i);
        hitSite(i, tapPow * (fever > 0 ? 2 : 1));
        return 'site';
      }
      if (i == C0) return 'shelter';
      if (S.camp.containsKey(i)) return 'camp';
      if (modAtTile(i) != null) return 'module';
      if (S.ter[i] == T.lm) return 'landmark';
      return 'none';
    }
    if (frontier.contains(i)) {
      setAim(i);
      dig(i);
      return 'dig';
    }
    return 'far';
  }

  // ================= 짓기 (웹 2464–2481) =================
  int freeSlot() {
    for (var k = 0; k < slotsByLv[S.lv - 1]; k++) {
      if (!S.mods.containsKey(k)) return k;
    }
    return -1;
  }

  void clearTile(int t) {
    if (S.rev[t] == 0) {
      S.rev[t] = 1;
      frontier.remove(t);
      for (final j in nb4(t)) {
        if (S.rev[j] == 0) frontier.add(j);
      }
    }
    S.hp[t] = 0;
    S.site.remove(t);
    if (S.ter[t] != T.ash) S.ter[t] = T.ash;
    // 구조 신호가 있던 자리는 2단계에서 바로 구조로 이어진다
  }

  bool canBuild(int id) => freeSlot() >= 0 && (modN(id) == 0 || repeatable.contains(id)) && S.lv >= mods[id]!.req && canPay(modBuildCost(id));

  bool buildMod(int id) {
    final k = freeSlot();
    if (k < 0) {
      fx.add(const FxToast('빈 자리가 없어요. 쉘터를 키우면 자리가 늘어요'));
      return false;
    }
    if (modN(id) > 0 && !repeatable.contains(id)) return false;
    final c = modBuildCost(id);
    if (S.lv < mods[id]!.req || !pay(c)) return false;
    S.half = false;
    final t = slotTile(k);
    clearTile(t);
    S.mods[k] = Mod(id, 0);
    recalc();
    fx.add(FxFloat(t, '${mods[id]!.n}!', 0xFFEFE3C4, rise: 30));
    fx.add(FxBurst(t, 0xFFB8A888, 16));
    _changed();
    return true;
  }

  bool upMod(int k) {
    final m = S.mods[k];
    if (m == null || m.l >= 2) return false;
    if (!pay(modCost(m.id, m.l + 1))) return false;
    S.half = false;
    m.l++;
    final t = slotTile(k);
    recalc();
    fx.add(FxFloat(t, '${mods[m.id]!.n} ${m.l + 1}단계!', 0xFFC8E696, rise: 30));
    fx.add(FxBurst(t, 0xFF9FBF6A, 20));
    _changed();
    return true;
  }

  bool upShelter() {
    final c = shelterUpCost;
    if (c == null || S.mods.length < shupNeed[S.lv - 1] || !pay(c)) return false;
    S.half = false;
    S.lv++;
    final r = S.lv + 1;
    for (var y = CY - r; y <= CY + r; y++) {
      for (var x = CX - r; x <= CX + r; x++) {
        final i = y * W + x;
        if (x >= 0 && y >= 0 && x < W && y < H && S.rev[i] == 0) reveal(i);
      }
    }
    recalc();
    fx.add(FxLevelUp(S.lv));
    fx.add(FxToast('쉘터가 ${jo(shelterName[S.lv - 1], '으로', '로')} 커졌어요! 랜턴 빛이 더 멀리 닿아요'));
    _changed();
    return true;
  }

  bool upWalls() {
    if (S.walls >= 3 || S.lv < 2) return false;
    if (!pay(wallCost(S.walls))) return false;
    S.half = false;
    S.walls++;
    recalc();
    fx.add(FxToast('${jo(wallsInfo[S.walls - 1].$1, '을', '를')} 둘렀어요'));
    _changed();
    return true;
  }

  int craft(int k, int times) {
    final r = recipes[k];
    if (wbL == 0 || recipeLock(r).isNotEmpty) return 0;
    var n = 0, made = 0;
    for (var q = 0; q < times; q++) {
      if (have(r.out) >= capOf(r.out)) {
        fx.add(FxToast('${matOf[r.out]!.n} 창고가 가득 찼어요'));
        break;
      }
      if (!pay(recipeInp(r))) break;
      n++;
      final extra = rnd.nextDouble() < (E['craft'] ?? 0) ? 1 : 0;
      made += give({r.out: r.n + extra})[r.out] ?? 0;
    }
    if (n > 0) {
      if (n > 1) fx.add(FxToast('${matOf[r.out]!.n} ${fmt(made)}개를 만들었어요'));
    } else {
      fx.add(const FxToast('재료가 모자라요'));
    }
    _changed();
    return made;
  }

  bool buyUp(String k) {
    if (upgLv(k) >= upgMax[k]! || wbL < upgWb(k) || !pay(upgCost(k))) return false;
    if (k == 'tap') {
      S.tapLv++;
    } else if (k == 'splash') {
      S.splashLv++;
    } else {
      S.droneLv++;
    }
    _changed();
    return true;
  }

  bool restoreLm(int i) {
    final l = S.lm[i];
    if (l == null || l.ok) return false;
    if (!pay(lmCost(l.k))) return false;
    S.half = false;
    l.ok = true;
    fx.add(FxFloat(i, '${lmText(l.k, S.region)[0]} 복구!', 0xFFFFE6A0, rise: 40));
    fx.add(FxToast('${lmText(l.k, S.region)[0]} 복구 완료! ${landmarks[l.k].desc}'));
    if (aim == i) aim = -1;
    recalc();
    _changed();
    return true;
  }

  // ================= 시간 =================
  double _acc = 0;

  /// 시간을 dt초 진행한다. 화면에 보일 변화가 있으면 true.
  bool tick(double dt) {
    var changed = false;
    // 생산·식량·연료 (웹 tickProd 2721)
    prod.forEach((k, v) {
      final add = v * buffMult(k) * dt / 60;
      S.frac[k] = (S.frac[k] ?? 0) + add;
      final w = S.frac[k]!.floor();
      if (w > 0) {
        S.frac[k] = S.frac[k]! - w;
        if (give({k: w}).isNotEmpty) changed = true;
      }
    });
    final e = eat * dt / 60;
    S.frac['eat'] = (S.frac['eat'] ?? 0) + e;
    if (S.frac['eat']! >= 1) {
      final w = S.frac['eat']!.floor();
      S.frac['eat'] = S.frac['eat']! - w;
      S.m['food'] = math.max(0, have('food') - w);
      changed = true;
    }
    if (fuelUse > 0) {
      S.frac['fuel'] = (S.frac['fuel'] ?? 0) + fuelUse * dt / 60;
      if (S.frac['fuel']! >= 1) {
        final w = S.frac['fuel']!.floor();
        S.frac['fuel'] = S.frac['fuel']! - w;
        final was = have('fuel') > 0;
        S.m['fuel'] = math.max(0, have('fuel') - w);
        changed = true;
        if (was && have('fuel') <= 0) {
          fx.add(const FxToast('연료가 떨어져 발전기가 멈췄어요'));
          recalc();
        }
      }
    }
    final h = have('food') <= 0 && eat > 0;
    if (h != hungry) {
      hungry = h;
      if (h) fx.add(const FxToast('식량이 떨어졌어요! 생산이 절반으로 줄어요'));
      recalc();
      changed = true;
    }
    // 임시 효과
    final b = S.buff;
    if (b != null) {
      b['t'] = ((b['t'] as num?) ?? 0) - dt;
      if ((b['t'] as num) <= 0) S.buff = null;
      changed = true;
    }
    // 연타·피버
    idle += dt;
    if (fever > 0) {
      fever = math.max(0, fever - dt);
      changed = true;
    } else if (idle > .7 && combo > 0) {
      combo = math.max(0, combo - dt * 10);
      changed = true;
    }
    // 1초마다
    _acc += dt;
    while (_acc >= 1) {
      _acc -= 1;
      if (_tickSites()) _mapChanged();
      if (S.droneLv > 0) {
        final i = frontierNearest();
        if (i >= 0) {
          damage(i, droneDmg());
          fx.add(FxBurst(i, 0xFF9FC6D2, 4));
        }
      }
    }
    if (changed) dirty = true;
    return changed;
  }

  bool _tickSites() {
    var ch = false;
    S.site.forEach((k, s) {
      final rg = sites[s.k]!.regen;
      if (rg == 0 || s.c >= s.max) return;
      if (s.k == 'lm' && (S.lm[k]?.ok ?? false)) return;
      s.rt++;
      if (s.rt >= rg) {
        s.rt = 0;
        s.c++;
        ch = true;
      }
    });
    return ch;
  }

  /// 앱을 다시 열었을 때 꺼져 있던 동안의 생산 (웹 start 6417: 최대 8시간, 절반)
  void offline(int nowMs) {
    final el = math.min(8 * 3600, (nowMs - S.t) / 1000).toDouble();
    if (el > 60 && perMin > 0) {
      final got = give({for (final e in prod.entries) e.key: e.value * el / 60 * .5});
      if (got.isNotEmpty) fx.add(FxOffline(el, got));
    }
    S.t = nowMs;
  }

  // ================= 저장 =================
  String toJsonString() {
    S.t = DateTime.now().millisecondsSinceEpoch;
    return jsonEncode(S.toJson());
  }

  /// 웹 exportSave (4360): 'TTC1.' + base64(utf8(JSON))
  String exportCode() => 'TTC1.${base64.encode(utf8.encode(toJsonString()))}';

  static GameState? parseCode(String code) {
    try {
      final c = code.trim().replaceAll(RegExp(r'\s'), '');
      if (!c.startsWith('TTC1.')) return null;
      final j = jsonDecode(utf8.decode(base64.decode(c.substring(5))));
      if (j is! Map<String, dynamic>) return null;
      return GameState.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  void replaceState(GameState s) {
    S = s;
    combo = 0;
    fever = 0;
    aim = -1;
    _rebuildFrontier();
    recalc();
    _changed();
  }

  void _mapChanged() => mapVersion.value++;
  void _changed() {
    dirty = true;
    _mapChanged();
    notifyListeners();
  }

  /// 연출 신호를 꺼내 간다.
  List<Fx> takeFx() {
    if (fx.isEmpty) return const [];
    final l = List<Fx>.of(fx);
    fx.clear();
    return l;
  }

  void poke() => notifyListeners();
}
