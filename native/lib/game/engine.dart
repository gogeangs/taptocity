// 게임 규칙. 웹 버전(index.html)의 같은 이름 함수를 그대로 옮겼다. 행 번호는 웹 기준.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/web_data.g.dart' as web;
import 'data.dart';
import 'rng.dart';
import 'state.dart';

part 'crisis.dart';
part 'outside.dart';

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

class FxCamp extends Fx {
  const FxCamp(this.tile);
  final int tile;
}

class FxRescue extends Fx {
  const FxRescue(this.id, this.via);
  final int id;
  final String via;
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
    repairExpeditions();
    _rebuildFrontier();
    recalc();
    wasNight = isNight;
  }

  // ---------- 낮밤·위기 (저장하지 않는 진행 상태, crisis.dart) ----------
  bool wasNight = false;
  double spawnT = 0, evT = 45, evLeft = 0;
  int nightN = 0, nightLost = 0, evCur = -1, sqOpenUntil = 0;
  final List<int> evSeen = [];
  Defense? defn;
  final Set<String> _expNotified = {};
  int _autoExpT = 0;

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
  int sel = -1; // 빠른 메뉴로 고른 칸 (저장하지 않음)
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
    return (1 + (E['scav'] ?? 0) + (S.lv - 1) * .15) * (fever > 0 ? 2 : 1) * bm * wxMul('scav');
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
    // 웹 calcEff (1833): 일터에 있는 생존자의 특기 + 인연. 장비 효과는 2단계 후반, 유물·아이·펫·탑·잔치·동네·장식(웹 extraEff 4108)은 4~6단계
    for (final id in svIds) {
      if (atOf(id) < 0 || busy(id)) continue;
      effOf(id).forEach((k, v) => e[k] = (e[k] ?? 0) + v);
      gearEff(id).forEach((k, v) => e[k] = (e[k] ?? 0) + v);
    }
    for (final b in bonds) {
      if (b.ids.every(hasSv)) b.eff.forEach((k, v) => e[k] = (e[k] ?? 0) + v);
    }
    // 이주한 동네 수만큼: 모든 생산 +10%, 두드리는 힘 +10%
    if (S.gen > 0) {
      e['global'] = e['global']! + .1 * S.gen;
      e['tap'] = e['tap']! + .1 * S.gen;
    }
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
      final pm = stuck ? 0.0 : asgMult(t);
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
    final home = svIds.where((id) => !_truthy(rec(id)?['away'])).length;
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
      aim >= 0 &&
      (frontier.contains(aim) ||
          (S.rev[aim] == 1 && ((S.camp[aim]?['hp'] as num?) ?? 0) > 0) ||
          siteLive(aim) ||
          (S.site[aim]?.k == 'lm' && (S.site[aim]?.c ?? 0) > 0 && !(S.lm[aim]?.ok ?? true)));

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

  /// 웹 makeCamp (3080): 구조 신호 자리(잔해) 또는 쉘터 앞 손님
  void makeCamp(int i, int id, {bool visit = false}) {
    if (hasSv(id)) return;
    final hp = jsRound(14 + dist(i) * 2.6);
    S.camp[i] = {'id': id, 'hp': visit ? 0 : hp, 'max': visit ? 1 : hp, 'visit': visit};
    S.hp[i] = 0;
    S.site.remove(i);
    if (!visit) S.ter[i] = T.ash;
    fx.add(FxBurst(i, 0xFFCFE6FF, 24));
    fx.add(FxToast(visit ? '${jo(survivors[id].name, '이', '가')} 쉘터 앞에 찾아왔어요!' : '생존자를 찾았어요! 잔해를 치우고 구조해요'));
    _mapChanged();
  }

  // ================= 장비 (웹 1554–1591, 3283–3352, 4168) =================
  static const bagMax = 40;
  List<Map> get inv {
    if (S.rest['inv'] is! List) S.rest['inv'] = <Object?>[];
    return (S.rest['inv'] as List).whereType<Map>().toList();
  }

  Map? itemAt(Object? uid) {
    if (uid == null) return null;
    for (final x in inv) {
      if (x['u'] == uid) return x;
    }
    return null;
  }

  Map eqOf(int id) {
    final r = rec(id)!;
    if (r['eq'] is! Map) r['eq'] = <String, Object?>{};
    return r['eq'] as Map;
  }

  int? wearer(Object? uid) {
    for (final id in svIds) {
      final q = rec(id)?['eq'];
      if (q is Map && q.values.contains(uid)) return id;
    }
    return null;
  }

  bool canWear(int id, String t) {
    final o = gear[t]?.only;
    return o == null || o == id;
  }

  /// 웹 gearEff (1591): 잘 맞는 사람이 쓰면 ×1.5
  Map<String, double> gearEff(int id) {
    final o = <String, double>{}, q = rec(id)?['eq'];
    if (q is! Map) return o;
    for (final sl in slotKeys) {
      final it = itemAt(q[sl]);
      if (it == null) continue;
      final G = gear[it['t']];
      if (G == null) continue;
      final f = G.fit.contains(id) ? 1.5 : 1.0;
      G.eff.forEach((k, v) => o[k] = (o[k] ?? 0) + v * f);
    }
    return o;
  }

  /// 웹 addGear (3285): 가방이 넘치면 가장 낮은 등급 하나를 분해
  Map addGear(String t) {
    if (S.rest['inv'] is! List) S.rest['inv'] = <Object?>[];
    final list = S.rest['inv'] as List;
    final u = ((S.rest['iu'] as num?) ?? 0).toInt() + 1;
    S.rest['iu'] = u;
    final it = <String, Object?>{'u': u, 't': t};
    list.add(it);
    if (list.length > bagMax) {
      final worn = <Object?>{};
      for (final id in svIds) {
        final q = rec(id)?['eq'];
        if (q is Map) worn.addAll(q.values);
      }
      final cand = list.whereType<Map>().where((x) => x != it && !worn.contains(x['u']) && !(gear[x['t']]?.sig ?? true) && !(gear[x['t']]?.line ?? true) && x['lk'] != 1).toList()
        ..sort((a, b) => gear[a['t']]!.g - gear[b['t']]!.g);
      if (cand.isNotEmpty) {
        list.remove(cand.first);
        final G = gear[cand.first['t']]!;
        give(G.cost != null ? scaleCost(G.cost!, .5) : {'parts': 4 * (G.g + 1)});
        fx.add(FxToast('가방이 가득 차 ${jo(G.n, '을', '를')} 분해했어요'));
      }
    }
    dirty = true;
    return it;
  }

  String? dropGear(int g) {
    final pool = gear.values.where((G) => G.g == g && !G.sig && !G.ug && !G.line).map((G) => G.key).toList();
    if (pool.isEmpty) return null;
    final t = pool[rnd.nextInt(pool.length)];
    addGear(t);
    return t;
  }

  bool equip(int id, String slot, Object? uid) {
    final it = itemAt(uid);
    if (it == null || !hasSv(id)) return false;
    final G = gear[it['t']]!;
    if (G.slot != slot || !canWear(id, G.key)) return false;
    final w = wearer(uid);
    if (w != null) eqOf(w)[slot] = null;
    eqOf(id)[slot] = uid;
    recalc();
    fx.add(FxToast('${survivors[id].name}: ${G.n} 장착'));
    _changed();
    return true;
  }

  void unequip(int id, String slot) {
    eqOf(id)[slot] = null;
    recalc();
    _changed();
  }

  bool craftGear(String t) {
    final G = gear[t]!;
    if (G.cost == null || wbL < G.wb) return false;
    if (!pay(scaleCost(G.cost!, costMult))) return false;
    addGear(t);
    S.rest['gearMade'] = ((S.rest['gearMade'] as num?) ?? 0) + 1;
    fx.add(FxToast('${jo(G.n, '을', '를')} 만들었어요'));
    _changed();
    return true;
  }

  Cost dismBack(GearInfo G) => G.cost != null ? scaleCost(G.cost!, .5) : scaleCost({'parts': 4 * (G.g + 1), 'cloth': 3 * (G.g + 1), 'batt': G.g >= 2 ? 1 : 0});

  void dismantle(Object? uid) {
    final it = itemAt(uid);
    if (it == null || it['lk'] == 1 || wearer(uid) != null) return;
    final G = gear[it['t']]!;
    (S.rest['inv'] as List).remove(it);
    final got = give(dismBack(G));
    fx.add(FxToast('${G.n} 분해 · ${got.entries.map((e) => '${matOf[e.key]!.n} +${e.value}').join(' · ')}'));
    _changed();
  }

  void toggleLock(Object? uid) {
    final it = itemAt(uid);
    if (it == null) return;
    it['lk'] = it['lk'] == 1 ? 0 : 1;
    fx.add(FxToast(it['lk'] == 1 ? '${gear[it['t']]!.n} 잠금 · 분해되지 않아요' : '${gear[it['t']]!.n} 잠금 풀림'));
    _changed();
  }

  /// 웹 bagSurplus (3310): 같은 장비 여분, 더 좋은 장비가 있는 일반 등급
  List<(Map, String)> bagSurplus() {
    final all = inv, out = <(Map, String)>[], kept = <String>{}, best = <String, int>{};
    for (final x in all) {
      final G = gear[x['t']]!;
      best[G.slot] = math.max(best[G.slot] ?? 0, G.g);
    }
    final free = all.where((x) => x['lk'] != 1 && !gear[x['t']]!.sig && !gear[x['t']]!.line && wearer(x['u']) == null).toList()
      ..sort((a, b) => (b['u'] as num).compareTo(a['u'] as num));
    for (final x in free) {
      final G = gear[x['t']]!;
      if (kept.contains(G.key)) {
        out.add((x, '같은 장비 여분'));
        continue;
      }
      if (G.g == 0 && (best[G.slot] ?? 0) > 0) {
        out.add((x, '더 좋은 ${slotName[G.slot]} 있음'));
        continue;
      }
      kept.add(G.key);
    }
    return out;
  }

  void tidy(List<Map> items) {
    final back = <String, num>{};
    for (final x in items) {
      dismBack(gear[x['t']]!).forEach((k, v) => back[k] = (back[k] ?? 0) + v);
      (S.rest['inv'] as List).remove(x);
    }
    final got = give(back);
    fx.add(FxToast('장비 ${items.length}개 분해 · ${got.entries.map((e) => '${matOf[e.key]!.n} +${e.value}').join(' · ')}'));
    _changed();
  }

  /// 웹 autoGear (4168): 전용 → 잘 맞는 장비 → 높은 등급
  int autoGear() {
    final items = inv, ids = svIds.toList();
    if (items.isEmpty || ids.isEmpty) return 0;
    final plan = {for (final id in ids) id: <String, Object?>{}}, used = <Object?>{};
    for (final it in items) {
      final G = gear[it['t']]!, o = G.only;
      if (o != null && hasSv(o) && plan[o]![G.slot] == null) {
        plan[o]![G.slot] = it['u'];
        used.add(it['u']);
      }
    }
    final rest = items.where((it) => !used.contains(it['u']) && gear[it['t']]!.only == null).toList()..sort((a, b) => gear[b['t']]!.g - gear[a['t']]!.g);
    for (final it in rest) {
      final G = gear[it['t']]!;
      final who = ids.where((id) => plan[id]![G.slot] == null && G.fit.contains(id)).firstOrNull;
      if (who != null) {
        plan[who]![G.slot] = it['u'];
        used.add(it['u']);
      }
    }
    for (final it in rest) {
      if (used.contains(it['u'])) continue;
      final G = gear[it['t']]!;
      final who = ids.where((id) => plan[id]![G.slot] == null).firstOrNull;
      if (who != null) {
        plan[who]![G.slot] = it['u'];
        used.add(it['u']);
      }
    }
    var ch = 0;
    for (final id in ids) {
      final q = eqOf(id);
      for (final sl in slotKeys) {
        final want = plan[id]![sl];
        if (q[sl] != want) ch++;
        q[sl] = want;
      }
    }
    if (ch > 0) {
      recalc();
      _changed();
    }
    return ch;
  }

  // ================= 등급·별 (웹 3261–3282) =================
  int maxGrade(int id) => math.min(3, survivors[id].grade + 2);
  Cost starCost(int id) {
    final g = gradeOf(id), s = starOf(id), k = g + 1;
    return scaleCost({'food': 8 * s * k, 'parts': 3 * s * k, 'batt': s >= 3 ? 1 : 0, 'med': g >= 2 && s >= 4 ? 1 : 0});
  }

  /// 다음 강화: (종류, 필요 신뢰도, 비용, 이름) 또는 null
  (String, int, Cost, String)? nextStep(int id) {
    final g = gradeOf(id), s = starOf(id);
    if (s < 5) return ('star', s, starCost(id), '${s + 1}성으로 강화');
    if (g < maxGrade(id)) return ('grade', 5, scaleCost(gradeUpCost[g]), '${grades[g + 1].n} 등급으로 승급');
    return null;
  }

  ({double m, double w, double cd}) pwAt(int g, int st) {
    final a = grades[g], b = grades[math.min(g + 1, grades.length - 1)], f = .8 * (st - 1) / 4;
    return (m: a.m + (b.m - a.m) * f, w: a.w + (b.w - a.w) * f, cd: a.cd + (b.cd - a.cd) * f);
  }

  bool canPromote(int id) {
    final n = nextStep(id);
    return n != null && trustLv(xpOf(id)) >= n.$2 && canPay(n.$3);
  }

  /// 결과: 'star' 또는 'grade' (실패하면 null)
  String? promote(int id) {
    final n = nextStep(id);
    if (n == null || trustLv(xpOf(id)) < n.$2 || !pay(n.$3)) return null;
    final r = rec(id)!;
    if (n.$1 == 'star') {
      r['st'] = starOf(id) + 1;
      fx.add(FxToast('${survivors[id].name} ${r['st']}성!'));
    } else {
      r['g'] = gradeOf(id) + 1;
      r['st'] = 1;
    }
    recalc();
    _changed();
    return n.$1;
  }

  // ================= 스킬 (웹 2844–2897) =================
  List<int> get party {
    if (S.rest['party'] is! List) S.rest['party'] = <Object?>[];
    return (S.rest['party'] as List).map((e) => (e as num?)?.toInt()).whereType<int>().toList();
  }

  set party(List<int> v) => S.rest['party'] = v;
  double skillCd(int id) => skills[id].cd * (1 - .08 * (trustLv(xpOf(id)) - 1)) * pw(id).cd;
  double cdLeft(int id) {
    final cd = S.rest['cd'];
    return cd is Map ? ((cd['$id'] as num?) ?? 0).toDouble() : 0;
  }

  double get craftBuff {
    final b = S.buff;
    return b != null && ((b['t'] as num?) ?? 0) > 0 && b['k'] == 'craft' ? (b['m'] as num).toDouble() - 1 : 0;
  }

  void toggleParty(int id) {
    final p = party;
    if (p.contains(id)) {
      p.remove(id);
    } else if (p.length < 3) {
      p.add(id);
    }
    party = p;
    _changed();
  }

  /// 웹 effParty (4410): 바에 있는 사람이 원정·부상이면 쉬는 사람 중 등급 높은 사람이 대신
  List<(int, int?)> effParty() {
    final used = party.toSet(), out = <(int, int?)>[];
    for (final id in party) {
      if (busy(id)) {
        final sub = (svIds.where((j) => !used.contains(j) && !busy(j)).toList()..sort((a, b) => gradeOf(b) - gradeOf(a))).firstOrNull;
        if (sub != null) {
          used.add(sub);
          out.add((sub, id));
          continue;
        }
      }
      out.add((id, null));
    }
    return out;
  }

  /// 웹 partyRecommend (2870): 지금 쉘터에 필요한 것에 맞춰 셋
  List<int> partyRecommend() {
    final w = <String, double>{'all': 2, 'scav': 1.5, 'loot': 1, 'fever': 1, 'reset': 1.6, 'craft': 1, 'find': .8, 'heal': .8, 'storm': .5, 'food': .8, 'build': .6, 'reveal': .8, 'drone': modLv(8) >= 0 ? 1 : 0};
    if (S.ash.isNotEmpty) {
      w['storm'] = 3;
      w['heal'] = 2;
    }
    if (hungry || have('food') < 40) w['food'] = 3;
    if (svIds.any((id) => ((rec(id)!['hurt'] as num?) ?? 0) > 0)) w['heal'] = math.max(w['heal']!, 2.2);
    final ids = svIds.where((id) => id < skills.length).toList();
    final sc = {for (final id in ids) id: (w[skills[id].cat] ?? .5) * (1 + .12 * gradeOf(id)) * math.sqrt(60 / math.max(30, skillCd(id)))};
    final order = [...ids]..sort((a, b) => sc[b]!.compareTo(sc[a]!));
    final pick = <int>[], cats = <String>{};
    for (final id in order) {
      if (cats.contains(skills[id].cat)) continue;
      pick.add(id);
      cats.add(skills[id].cat);
      if (pick.length == 3) break;
    }
    for (final id in order) {
      if (pick.length >= 3) break;
      if (!pick.contains(id)) pick.add(id);
    }
    return pick;
  }

  void _skillLoot(Map<String, num> o, String label) {
    final got = loot(scaleCost(o, lvScale * scavMult / (fever > 0 ? 2 : 1)), C0);
    fx.add(FxToast('$label${got.isNotEmpty ? ' ${got.entries.map((e) => '${matOf[e.key]!.n} +${e.value}').join(' · ')}' : ' · 창고가 가득 찼어요'}'));
  }

  void _buff(String k, double m, int t, String label) => S.buff = <String, Object?>{'k': k, 'm': m, 't': t, 'label': label};

  int _nearestFrontierFromCenter() {
    var best = -1;
    var bd = 1e9;
    for (final i in frontier) {
      final d = dist(i);
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  /// 웹 useSkill (2860). 스킬마다의 효과는 웹 SKILLS[].fn 그대로
  bool useSkill(int id) {
    if (!hasSv(id) || busy(id) || cdLeft(id) > 0 || id >= skills.length) return false;
    final name = survivors[id].name;
    bool ok = true;
    switch (id) {
      case 0: // 막차 돌진
        if (!aimValid || S.rev[aim] == 1) {
          final f = nearestFrontierTo(aim >= 0 ? aim : C0);
          if (f < 0) return false;
          setAim(f);
        }
        var i = aim, k = 0;
        final dir = aimDir;
        while (k < 5 && i >= 0) {
          final x = i % W, y = i ~/ W;
          if (S.rev[i] == 0) {
            reveal(i);
            fx.add(FxBurst(i, 0xFF3F6FA0, 10));
          }
          k++;
          final nx = x + dir.$1, ny = y + dir.$2;
          i = (nx >= 0 && ny >= 0 && nx < W && ny < H) ? ny * W + nx : -1;
        }
        if (!aimValid) setAim(nearestFrontierTo(C0));
      case 1: // 퀵 배달
        final o = <String, num>{};
        for (var q = 0; q < 3; q++) {
          final k = const ['scrap', 'wood', 'cloth', 'parts'][rnd.nextInt(4)];
          o[k] = (o[k] ?? 0) + 5;
        }
        _skillLoot(o, '퀵 배달 도착!');
      case 2: // 응급처치
        var n = 0;
        for (final k in S.ash.keys.toList()) {
          if ((S.ash[k] as Map?)?['stuck'] == true) {
            S.ash.remove(k);
            n++;
          }
        }
        for (final j in svIds) {
          if (((rec(j)!['hurt'] as num?) ?? 0) > 0) {
            rec(j)!['hurt'] = 0;
            n++;
          }
        }
        _buff('all', 1.2, 30, '응급처치');
        recalc();
        if (n > 0) fx.add(FxToast('응급처치로 $n곳을 살렸어요'));
      case 3: // 희망의 노래
        fever = feverT;
        combo = 0;
        S.fevers++;
        if (S.fevers <= 3) fx.add(const FxToast('하늘이의 노래에 랜턴이 활활 타올라요!'));
      case 4: // 씨앗 뿌리기
        if (modLv(2) < 0) {
          fx.add(const FxToast('텃밭 상자가 먼저 있어야 해요'));
          return false;
        }
        _buff('farm', 3, 30, '씨앗 뿌리기');
      case 5:
        _buff('all', 1.5, 30, '국밥 한 솥');
      case 6: // 긴급 시공
        if (S.half) {
          fx.add(const FxToast('이미 준비돼 있어요'));
          return false;
        }
        S.half = true;
        recalc();
        fx.add(const FxToast('철호 반장 대기 중! 다음 공사 자재 절반'));
      case 7:
        S.rest['hintT'] = 60;
        fx.add(const FxToast('유나가 지도를 그렸어요. 반짝이는 곳을 찾아봐요'));
      case 8: // 진화 작업
        final ks = S.ash.keys.toList();
        if (ks.isEmpty) {
          S.rest['shield'] = 1;
          fx.add(const FxToast('우진이 방화포를 둘렀어요. 오늘 밤 재폭풍이 약해요'));
        } else {
          var st = false;
          for (final k in ks) {
            if ((S.ash[k] as Map?)?['stuck'] == true) st = true;
            S.ash.remove(k);
          }
          if (st) recalc();
          _skillLoot({'scrap': ks.length * 2}, '재 ${ks.length}곳을 한 번에 껐어요');
        }
      case 9:
        S.rest['overT'] = 30;
        fx.add(const FxToast('재혁이 드론 출력을 끝까지 올렸어요'));
      case 10: // 심야 방송
        for (final j in svIds) {
          rec(j)!['xp'] = xpOf(j) + 30;
        }
        _buff('all', 1.3, 60, '심야 방송');
        recalc();
        fx.add(const FxToast('은호의 방송이 쉘터에 울려 퍼져요'));
      case 11:
        _buff('scav', 2, 60, '맑음 예보');
        fx.add(const FxToast('설화: “앞으로 한 시간, 맑겠습니다!”'));
      case 12: // 태엽 감기
        final cd = S.rest['cd'];
        final n = cd is Map ? cd.length : 0;
        if (n == 0) {
          fx.add(const FxToast('되감을 시간이 없어요'));
          return false;
        }
        S.rest['cd'] = <String, Object?>{};
        fx.add(FxToast('태식이 태엽을 감았어요. 스킬 $n개가 다시 준비됐어요'));
      case 13:
        _buff('all', 1.5, 60, '비상 발전');
        fx.add(const FxToast('미영이 예비 발전기를 돌렸어요'));
      case 14:
        for (final j in svIds) {
          rec(j)!['hurt'] = 0;
        }
        _buff('farm', 1.5, 60, '선인장 수액');
        recalc();
        fx.add(const FxToast('한별이 모두의 상처를 돌봤어요'));
      case 15:
        final n = jsRound(12 * lvScale);
        give({'plate': n});
        fx.add(FxToast('도진이 철판 $n장을 용접했어요'));
      case 16:
        var c = 0;
        for (var q = 0; q < 6; q++) {
          final b = _nearestFrontierFromCenter();
          if (b < 0) break;
          reveal(b);
          c++;
        }
        fx.add(FxToast('설아가 로프를 타고 $c칸을 열었어요'));
        ok = c > 0;
      case 17:
        _buff('scav', 1.8, 60, '지름길');
        fx.add(const FxToast('진이 아무도 모르는 뒷길로 앞장섰어요'));
      default: // 동네 사람들 (웹 RESIDENTS.skill)
        final k = skills[id].res ?? const {};
        if (k['give'] != null) {
          final g = k['give'] as String, n = g == 'plate' ? jsRound(10 * lvScale) : jsRound(4 * lvScale);
          give({g: n});
          fx.add(FxToast('${jo(name, '이', '가')} ${matOf[g]!.n} $n개를 만들었어요'));
        } else if (k['heal'] == true) {
          for (final j in svIds) {
            rec(j)!['hurt'] = 0;
          }
          recalc();
          fx.add(FxToast('${jo(name, '이', '가')} 모두의 상처를 돌봤어요'));
        } else if (((k['clear'] as num?) ?? 0) > 0) {
          var c = 0;
          for (var q = 0; q < (k['clear'] as num); q++) {
            final b = _nearestFrontierFromCenter();
            if (b < 0) break;
            reveal(b);
            c++;
          }
          fx.add(FxToast('${jo(name, '이', '가')} 길을 $c칸 열었어요'));
          ok = c > 0;
        } else {
          final kk = (k['k'] as String?) ?? 'all';
          final d = skills[id].d;
          if (kk == 'all') {
            _buff('all', d.contains('+15') ? 1.15 : 1.2, 60, skills[id].n);
            if (k['hope'] == true) {
              S.rest['hopeT'] = {'v': 3, 'until': DateTime.now().millisecondsSinceEpoch + 120000};
              recalc();
            }
          } else {
            _buff(kk, kk == 'craft' ? 1.3 : kk == 'farm' ? (d.contains('1.4') ? 1.4 : 1.5) : 1.6, kk == 'scav' ? 45 : 60, skills[id].n);
          }
          fx.add(FxToast('$name의 ${skills[id].n}!'));
        }
    }
    if (!ok) return false;
    if (S.rest['cd'] is! Map) S.rest['cd'] = <String, Object?>{};
    (S.rest['cd'] as Map)['$id'] = skillCd(id);
    S.rest['skillUses'] = ((S.rest['skillUses'] as num?) ?? 0) + 1;
    fx.add(FxFloat(C0, '$name: ${skills[id].n}!', 0xFFFFE6A0, rise: 60));
    _changed();
    return true;
  }

  // ================= 자동 배치 (웹 4157, 쉘터 Lv.3부터) =================
  bool get autoOpen => S.lv >= 3 || S.gen != 0;
  double _asgScore(int id, int t) {
    final m = modAtTile(t);
    if (m == null) return 0;
    final p = pw(id);
    return (survivors[id].match.contains(m.id) ? 2 + p.w : 1.3) * p.m;
  }

  ({int n, int fit}) autoAssign(bool full) {
    if (!autoOpen) return (n: 0, fit: 0);
    final tiles = modAt.keys.toList(), free = svIds.where((id) => !busy(id) && !(((rec(id)!['hurt'] as num?) ?? 0) > 0)).toList();
    if (full) {
      for (final t in tiles) {
        unassign(t);
      }
      for (final id in free) {
        rec(id)!['at'] = -1;
      }
    }
    final open = tiles.where((t) => S.asg[t] == null).toList(), idle = free.where((id) => atOf(id) < 0).toList();
    final pairs = <(double, int, int)>[for (final id in idle) for (final t in open) (_asgScore(id, t), id, t)]..sort((a, b) => b.$1.compareTo(a.$1));
    final ui = <int>{}, ut = <int>{};
    var n = 0, fit = 0;
    for (final (_, id, t) in pairs) {
      if (ui.contains(id) || ut.contains(t)) continue;
      ui.add(id);
      ut.add(t);
      S.asg[t] = id;
      rec(id)!['at'] = t;
      n++;
      if (survivors[id].match.contains(modAtTile(t)!.id)) fit++;
    }
    if (n > 0 || full) {
      recalc();
      _changed();
    }
    return (n: n, fit: fit);
  }

  int _autoT = 0;
  void _tickAuto() {
    if (S.rest['autoAsg'] != true || !autoOpen) return;
    if (++_autoT % 5 != 0) return;
    final r = autoAssign(false);
    if (r.n > 0) fx.add(FxToast('자동 배치 · ${r.n}명이 빈 일터로 갔어요'));
  }

  // ================= 생존자 (웹 1489–1545, 2639–2662, 3058–3110, 4116–4160) =================
  static bool _truthy(Object? v) => v != null && v != false && v != 0 && v != '';
  Iterable<int> get svIds => (S.sv.keys.map(int.tryParse).whereType<int>().toList()..sort());
  bool hasSv(int id) => S.sv['$id'] is Map;
  Map? rec(int id) => S.sv['$id'] is Map ? S.sv['$id'] as Map : null;
  num xpOf(int id) => (rec(id)?['xp'] as num?) ?? 0;
  int atOf(int id) => ((rec(id)?['at'] as num?) ?? -1).toInt();
  bool busy(int id) {
    final r = rec(id);
    return r != null && (_truthy(r['away']) || ((r['hurt'] as num?) ?? 0) > 0);
  }

  bool isDead(int id) => _dead(S, id);
  bool inStay(int id) => _inStay(S, id);

  static int trustLv(num xp) {
    var l = 0;
    while (l < 5 && xp >= trustXp[l]) {
      l++;
    }
    return l;
  }

  int gradeOf(int id) => (rec(id)?['g'] as num?)?.toInt() ?? survivors[id].grade;
  int starOf(int id) {
    final st = (rec(id)?['st'] as num?)?.toInt() ?? 0;
    return st > 0 ? st : 1;
  }

  /// 웹 pw(): 등급 사이를 별로 보간 (5성은 다음 등급까지 80%)
  ({double m, double w, double cd}) pw(int id) {
    final g = gradeOf(id), st = starOf(id);
    final a = grades[g], b = grades[math.min(g + 1, grades.length - 1)], f = .8 * (st - 1) / 4;
    return (m: a.m + (b.m - a.m) * f, w: a.w + (b.w - a.w) * f, cd: a.cd + (b.cd - a.cd) * f);
  }

  /// 웹 effOf (1520): 신뢰도·등급만큼 커지는 특기 효과
  Map<String, double> effOf(int id) {
    final sc = 1 + .25 * (trustLv(xpOf(id)) - 1), gm = pw(id).m;
    return {for (final e in survivors[id].eff.entries) e.key: e.value * math.max(1, sc) * gm};
  }

  String traitOf(int id) => traitText(survivors[id], effOf(id));

  /// 웹 asgMult (1832): 딱 맞는 일터면 ×(2+등급), 아니면 ×1.3, 신뢰도마다 +10%
  double asgMult(int tile) {
    final id = S.asg[tile];
    if (id == null || !hasSv(id) || busy(id)) return 1;
    final m = modAtTile(tile);
    return ((m != null && survivors[id].match.contains(m.id)) ? 2 + pw(id).w : 1.3) * (1 + .1 * (trustLv(xpOf(id)) - 1));
  }

  int get bedsMax => bedsByLv[S.lv - 1] + ((S.rest['carry'] as num?) ?? 0).toInt();
  int get bedsUsed => S.sv.length;
  int get bedFree => bedsMax - bedsUsed;
  Cost campNeed(int id) => scaleCost(rescueNeed[id]!.$1, 1);
  bool campReady(int i) {
    final c = S.camp[i];
    if (c == null) return false;
    final id = (c['id'] as num).toInt();
    return ((c['hp'] as num?) ?? 0) <= 0 && canPay(campNeed(id)) && bedFree > 0;
  }

  /// 웹 hitCamp (3085): 잔해를 두드려 치우고, 다 치우면 구조
  void hitCamp(int i, double amt) {
    final c = S.camp[i];
    if (c == null) return;
    if (((c['hp'] as num?) ?? 0) <= 0) {
      if (campReady(i)) {
        doRescue(i);
      } else {
        fx.add(FxCamp(i));
      }
      return;
    }
    addCombo();
    c['hp'] = (c['hp'] as num) - amt;
    fx.add(FxBurst(i, 0xFFC9B48F, 7));
    if ((c['hp'] as num) <= 0) {
      c['hp'] = 0;
      fx.add(FxBurst(i, 0xFFFFD98A, 24));
      fx.add(FxFloat(i, '잔해를 치웠다!', 0xFFFFE6A0, rise: 30));
      if (aim == i) aim = -1;
      if (campReady(i)) {
        doRescue(i);
      } else {
        fx.add(FxCamp(i));
      }
    }
    dirty = true;
    _mapChanged();
  }

  void doRescue(int i) {
    final c = S.camp[i];
    if (c == null || ((c['hp'] as num?) ?? 0) > 0 || bedFree <= 0) return;
    final id = (c['id'] as num).toInt();
    if (!pay(campNeed(id))) return;
    S.camp.remove(i);
    fx.add(FxBurst(i, 0xFFFFD98A, 30));
    rescue(id, c['visit'] == true ? 'visit' : 'sig');
  }

  /// 웹 rescue (2643)
  void rescue(int id, String via) {
    if (hasSv(id) || isDead(id)) return;
    S.sv['$id'] = <String, Object?>{'xp': 0, 'at': -1};
    if (S.rest['party'] is! List) S.rest['party'] = <Object?>[];
    final party = S.rest['party'] as List;
    if (party.length < 3) party.add(id);
    recalc();
    fx.add(FxRescue(id, via));
    _changed();
  }

  Cost giftCost(int id) => {'food': (6 * math.pow(2.5, trustLv(xpOf(id)) - 1)).ceil()};
  bool gift(int id) {
    final r = rec(id);
    if (r == null) return false;
    final l = trustLv(xpOf(id));
    if (l >= 5 || !pay(giftCost(id))) return false;
    r['xp'] = xpOf(id) + math.max(20, ((trustXp[l] - trustXp[l - 1]) * .45).ceil());
    final a = trustLv(xpOf(id));
    if (a > l) {
      fx.add(FxToast('${survivors[id].name} 신뢰도 $a! 새 사연이 열렸어요'));
      recalc();
    }
    _changed();
    return true;
  }

  void unassign(int tile) {
    final id = S.asg[tile];
    if (id == null) return;
    rec(id)?['at'] = -1;
    S.asg.remove(tile);
  }

  void assign(int tile, int id) {
    final r = rec(id);
    if (r == null || modAtTile(tile) == null) return;
    final at = atOf(id);
    if (at >= 0) S.asg.remove(at);
    unassign(tile);
    S.asg[tile] = id;
    r['at'] = tile;
    recalc();
    fx.add(FxBurst(tile, 0xFFFFD98A, 16));
    fx.add(FxFloat(tile, '${survivors[id].name} 합류!', 0xFFFFE6A0, rise: 30));
    _changed();
  }

  String workName(int at) {
    final m = modAtTile(at);
    return m != null ? mods[m.id]!.n : '쉘터';
  }

  String dutyOf(int id) {
    final d = rec(id)?['duty'];
    return d is String && duties.containsKey(d) ? d : 'gather';
  }

  String statusOf(int id) {
    final r = rec(id)!;
    if (_truthy(r['away'])) return '원정 중';
    if (((r['hurt'] as num?) ?? 0) > 0) return '다쳐서 쉬는 중';
    final at = atOf(id);
    if (at >= 0) return '${workName(at)}에서 일하는 중';
    return duties[dutyOf(id)]!.$2;
  }

  /// 웹 visitorTile (3097)
  int visitorTile() {
    var best = -1;
    var bd = 1e9;
    for (var i = 0; i < N; i++) {
      if (S.rev[i] == 0 || isSlot(i) || S.ter[i] == T.water || S.ter[i] == T.lm || (S.site[i] != null && S.site[i]!.c > 0) || S.camp.containsKey(i)) continue;
      final d = (dist(i) - 3.2).abs() + speck[i] * .3;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  void _tickVisitors() {
    for (final s in survivors) {
      if (s.src != 'visit' || hasSv(s.id) || isDead(s.id) || inStay(s.id) || S.camp.values.any((c) => c['id'] == s.id)) continue;
      if (hope >= s.hope * (1 - visitDisc) && (s.need == null || hasSv(s.need!))) {
        final t = visitorTile();
        if (t >= 0) makeCamp(t, s.id, visit: true);
        break;
      }
    }
  }

  /// 웹 tickSurv (2659): 다친 사람 회복, 일하는 사람 신뢰 쌓기, 손님 맞기
  void _tickSurv() {
    var ch = false;
    for (final id in svIds) {
      final r = rec(id)!;
      final hurt = (r['hurt'] as num?) ?? 0;
      if (hurt > 0) {
        r['hurt'] = hurt - heal;
        if ((r['hurt'] as num) <= 0) {
          r['hurt'] = 0;
          ch = true;
          fx.add(FxToast('${jo(survivors[id].name, '이', '가')} 다 나았어요'));
        }
        continue;
      }
      if (atOf(id) < 0 || _truthy(r['away']) || hungry) continue;
      final b = trustLv(xpOf(id));
      r['xp'] = xpOf(id) + (lmOn('school') ? 1.5 : 1) * trustM;
      final a = trustLv(xpOf(id));
      if (a > b) {
        ch = true;
        fx.add(FxToast('${survivors[id].name} 신뢰도 $a! 새 사연이 열렸어요'));
      }
    }
    if (ch) recalc();
    _tickVisitors();
  }

  int _dutyT = 0;

  /// 웹 tickDuty (4136): 쉬는 사람의 일. 훈련(신뢰 절반), 주워 오기(25초마다 기본 자재). 순찰·아이 돌보기는 3·4단계
  void _tickDuty() {
    _dutyT++;
    final ids = svIds.where((id) => atOf(id) < 0 && !busy(id) && !(((rec(id)!['hurt'] as num?) ?? 0) > 0)).toList();
    if (ids.isEmpty) return;
    for (final id in ids) {
      final d = dutyOf(id);
      if (d == 'train' && !hungry) {
        final b = trustLv(xpOf(id));
        rec(id)!['xp'] = xpOf(id) + .5 * trustM;
        final a = trustLv(xpOf(id));
        if (a > b) {
          fx.add(FxToast('${survivors[id].name} 신뢰도 $a! 새 사연이 열렸어요'));
          recalc();
        }
      }
    }
    if (_dutyT % 25 == 0) {
      final n = ids.where((id) => dutyOf(id) == 'gather').length;
      for (var q = 0; q < n; q++) {
        final k = baseMats[rnd.nextInt(baseMats.length)];
        loot({k: math.max(1, jsRound(2.4 * lvScale))}, C0);
      }
    }
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
    // 장비 발견: 폐허 1%, 벙커·랜드마크 4% (유물은 4단계)
    final gp = s.k == 'bunker' || s.k == 'lm' ? .04 : .01;
    if (rnd.nextDouble() < gp) {
      final it = dropGear(s.k == 'bunker' || s.k == 'lm' ? 1 : 0);
      if (it != null) {
        fx.add(FxFloat(i, '${gear[it]!.n}!', 0xFFC8AAFF, rise: 40));
        fx.add(FxToast('폐허에서 장비를 찾았어요: ${gear[it]!.n}'));
      }
    }
  }

  /// 구름 칸 하나를 두드린다 (웹 dig 2459)
  void dig(int i) {
    final x = i % W;
    addCombo();
    damage(i, tapPow * (fever > 0 ? 2 : 1) * wxMul('dig'), fromTap: true);
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
    if (defn != null) {
      final f = urgentFoe;
      if (f != null) tapFoe(f);
      return;
    }
    final a = urgentAsh;
    if (a >= 0) {
      hitAsh(a, tapPow * (fever > 0 ? 2 : 1));
      return;
    }
    if (!aimValid) {
      setAim(nearestFrontierTo(C0));
      if (aim < 0) return;
    }
    final pw = tapPow * (fever > 0 ? 2 : 1);
    if (S.rev[aim] == 1 && S.camp[aim] != null) {
      hitCamp(aim, pw);
    } else if (S.rev[aim] == 1 && S.site[aim] != null) {
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
      if (S.camp.containsKey(i)) {
        if (((S.camp[i]!['hp'] as num?) ?? 0) > 0) {
          setAim(i);
          hitCamp(i, tapPow * (fever > 0 ? 2 : 1));
          return 'camphit';
        }
        hitCamp(i, 0);
        return 'campdone';
      }
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
    final id = S.sig.remove(t);
    if (id != null) rescue(id, 'sig');
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
      final extra = rnd.nextDouble() < (E['craft'] ?? 0) + craftBuff ? 1 : 0;
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
      final add = v * buffMult(k) * wxMul('prod', k) * dt / 60;
      S.frac[k] = (S.frac[k] ?? 0) + add;
      final w = S.frac[k]!.floor();
      if (w > 0) {
        S.frac[k] = S.frac[k]! - w;
        if (give({k: w}).isNotEmpty) changed = true;
      }
    });
    final e = eat * wxMul('eat') * dt / 60;
    S.frac['eat'] = (S.frac['eat'] ?? 0) + e;
    if (S.frac['eat']! >= 1) {
      final w = S.frac['eat']!.floor();
      S.frac['eat'] = S.frac['eat']! - w;
      S.m['food'] = math.max(0, have('food') - w);
      changed = true;
    }
    if (fuelUse > 0) {
      S.frac['fuel'] = (S.frac['fuel'] ?? 0) + fuelUse * wxMul('fuel') * dt / 60;
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
    // 스킬 대기시간
    if (S.rest['cd'] is Map && S.rest['cd'] is! Map<String, Object?>) S.rest['cd'] = Map<String, Object?>.from(S.rest['cd'] as Map);
    final cd = S.rest['cd'];
    if (cd is Map && cd.isNotEmpty) {
      for (final k in cd.keys.toList()) {
        final v = ((cd[k] as num?) ?? 0) - dt;
        if (v <= 0) {
          cd.remove(k);
        } else {
          cd[k] = v;
        }
      }
      changed = true;
    }
    // 낮밤·밤 재·부탁 (crisis.dart)
    _tickClock(dt);
    _tickEvents(dt);
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
      _tickSurv();
      _tickDuty();
      final overT = ((S.rest['overT'] as num?) ?? 0).toInt();
      if (overT > 0) S.rest['overT'] = overT - 1;
      final hintT = ((S.rest['hintT'] as num?) ?? 0).toInt();
      if (hintT > 0) {
        S.rest['hintT'] = hintT - 1;
        _mapChanged();
      }
      _tickAuto();
      _tickSide();
      _tickExp();
      if (S.droneLv > 0 || overT > 0) {
        final i = frontierNearest();
        if (i >= 0) {
          damage(i, overT > 0 ? math.max(droneDmg(), tapPow) * 4 : droneDmg());
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
    defn = null;
    evCur = -1;
    _rebuildFrontier();
    recalc();
    wasNight = isNight;
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
