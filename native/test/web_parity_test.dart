// 웹 버전과 같은 결과가 나오는지 확인한다.
// 기준값(test/fixtures/web_core.json)은 tool/gen_data.cjs가 웹 코드를 직접 돌려서 만든 것이다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taptocity/game/data.dart';
import 'package:taptocity/game/engine.dart';
import 'package:taptocity/game/rng.dart';
import 'package:taptocity/game/state.dart';

void main() {
  final fx = jsonDecode(File('test/fixtures/web_core.json').readAsStringSync()) as Map<String, dynamic>;

  test('난수(mulberry32)와 잡음이 웹과 같다', () {
    final r = mulberry(12345);
    for (final v in fx['rng']['mulberry'] as List) {
      expect(r(), v);
    }
    final n = valueNoise(mulberry(9), 6);
    final pts = [(0, 0), (3, 7), (17, 22), (39, 39), (25.5, 1)];
    final want = fx['rng']['noise'] as List;
    for (var k = 0; k < pts.length; k++) {
      expect(n(pts[k].$1, pts[k].$2), closeTo((want[k] as num).toDouble(), 1e-12));
    }
  });

  for (final m in (fx['maps'] as List).cast<Map<String, dynamic>>()) {
    test('같은 시드면 같은 지도 (시드 ${m['seed']})', () {
      final seed = m['seed'] as int;
      final (ter, diaryAt) = genMap(seed);
      expect(ter, (m['genTer'] as List).cast<int>(), reason: '지형 생성');
      final s = GameState(seed: seed, ter: ter, diaryAt: diaryAt, rev: List.filled(N, 0), hp: List.filled(N, -1.0), m: {}, lv: 1);
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
      Game.placeSignals(s);
      Game.sprinkle(s);
      expect(s.ter, (m['ter'] as List).cast<int>(), reason: '폐허·흔적·랜드마크 배치');
      Map<String, int> keys(Map<int, int> x) => {for (final e in x.entries) '${e.key}': e.value};
      expect(keys(s.diaryAt), (m['diaryAt'] as Map).cast<String, int>());
      expect(keys(s.sig), (m['sig'] as Map).cast<String, int>());
      expect(keys(s.trace), (m['trace'] as Map).cast<String, int>());
      expect({for (final e in s.lm.entries) '${e.key}': e.value.k}, {for (final e in (m['lm'] as Map).entries) e.key: (e.value as Map)['k']});
      final g = Game(s);
      final tiles = [0, 21, 57, 820, C0 + 5, C0 - W * 7, 1599];
      expect([for (final i in tiles) g.maxHp(i)], (m['maxHp'] as List).cast<int>());
    });
  }

  for (final c in (fx['calc'] as List).cast<Map<String, dynamic>>()) {
    test('계산 공식이 웹과 같다 (${c['name']})', () {
      final st = c['state'] as Map<String, dynamic>;
      final s = GameState(
        seed: 1,
        ter: List.filled(N, T.ash),
        diaryAt: {},
        rev: List.filled(N, 1),
        hp: List.filled(N, 0.0),
        m: {'wood': 500, 'scrap': 500, 'cloth': 300, 'parts': 200, 'fuel': 100, 'food': 300, 'plate': 80, 'rope': 40, 'wire': 10, 'med': 5, 'batt': 2},
        lv: st['lv'] as int,
      );
      s.gen = st['gen'] as int;
      s.tapLv = st['tapLv'] as int;
      s.splashLv = st['splashLv'] as int;
      s.droneLv = st['droneLv'] as int;
      s.half = st['half'] as bool;
      (st['mods'] as Map).forEach((k, v) => s.mods[int.parse(k as String)] = Mod((v as Map)['id'] as int, v['l'] as int));
      (c['sv'] as Map).forEach((k, v) => s.sv[k as String] = Map<String, Object?>.from(v as Map));
      (c['asg'] as Map).forEach((k, v) => s.asg[int.parse(k as String)] = v as int);
      final g = Game(s);
      for (final t in c['trait'] as List) {
        expect(g.traitOf(t[0] as int), t[1], reason: '특기 문구 ${t[0]}');
      }
      for (final t in c['asgMult'] as List) {
        expect(g.asgMult(t[0] as int), closeTo((t[1] as num).toDouble(), 1e-9), reason: '배치 배수 ${t[0]}');
      }
      (c['E'] as Map).forEach((k, v) => expect(g.E[k] ?? 0, closeTo((v as num).toDouble(), 1e-9), reason: '효과 $k'));

      Map<String, double> dbl(Object? m) => {for (final e in (m as Map).entries) e.key as String: (e.value as num).toDouble()};
      Map<String, num> cost(Object? m) => {for (final e in (m as Map).entries) e.key as String: e.value as num};
      final want = dbl(c['prod']);
      expect(g.prod.keys.toSet(), want.keys.toSet(), reason: '생산 종류');
      want.forEach((k, v) => expect(g.prod[k], closeTo(v, 1e-9), reason: '생산 $k'));
      expect(g.cap, c['cap']);
      expect(g.hope, c['hope']);
      expect(g.eat, closeTo((c['eat'] as num).toDouble(), 1e-9));
      expect(g.fuelUse, closeTo((c['fuelUse'] as num).toDouble(), 1e-9));
      expect(g.tapPow, closeTo((c['tapPow'] as num).toDouble(), 1e-9));
      expect(g.droneDmg(), closeTo((c['droneDmg'] as num).toDouble(), 1e-9));
      (c['siteHp'] as Map).forEach((k, v) {
        final ds = [0.0, 5.0, 12.5];
        for (var j = 0; j < 3; j++) {
          expect(g.siteHp(Site(k: k as String, c: 1, max: 1, d: ds[j], hp: 0)), (v as List)[j], reason: '뒤지기 체력 $k');
        }
      });
      (c['modBuild'] as Map).forEach((id, v) => expect(g.modBuildCost(int.parse(id as String)), cost(v), reason: '짓기 비용 $id'));
      (c['modUp'] as Map).forEach((id, v) {
        for (var l = 1; l <= 2; l++) {
          expect(g.modCost(int.parse(id as String), l), cost((v as List)[l - 1]), reason: '강화 비용 $id/$l');
        }
      });
      expect(g.shelterUpCost, c['shup'] == null ? isNull : cost(c['shup']));
      for (var k = 0; k < 3; k++) {
        expect(g.wallCost(k), cost((c['walls'] as List)[k]));
      }
      (c['upg'] as Map).forEach((k, v) => expect(g.upgCost(k as String), cost(v), reason: '연구 비용 $k'));
      (c['upgWb'] as Map).forEach((k, v) => expect(g.upgWb(k as String), v));
      (c['capOf'] as Map).forEach((k, v) => expect(g.capOf(k as String), v, reason: '창고 한도 $k'));
    });
  }

  test('저장 코드(TTC1.)를 읽고 다시 쓰면 내용이 그대로', () {
    final s = Game.fresh(seed: 42);
    s.rest['future'] = {'아직': '옮기지 않은 필드'};
    final g = Game(s);
    final code = g.exportCode();
    final back = Game.parseCode(code)!;
    expect(back.seed, 42);
    expect(back.ter, s.ter);
    expect(back.rest['future'], {'아직': '옮기지 않은 필드'});
    expect(jsonEncode(back.toJson()), jsonEncode(s.toJson()));
  });

  test('구조 신호를 밝히면 캠프가 생기고, 잔해를 치우고 자재를 내면 구조된다', () {
    final g = Game(Game.fresh(seed: 42));
    final sig = g.S.sig.entries.first;
    g.reveal(sig.key);
    expect(g.S.camp[sig.key]?['id'], sig.value);
    g.S.m.addAll({for (final e in g.campNeed(sig.value).entries) e.key: e.value});
    var n = 0;
    while (g.S.camp.containsKey(sig.key) && n++ < 500) {
      g.hitCamp(sig.key, 5);
    }
    expect(g.hasSv(sig.value), isTrue);
    expect(g.bedsUsed, 1);
    // 일터에 배치하면 효과가 붙고 신뢰가 쌓인다
    g.S.m.addAll({'wood': 999, 'scrap': 999});
    g.buildMod(1);
    final tile = g.modAt.keys.first;
    g.assign(tile, sig.value);
    expect(g.atOf(sig.value), tile);
    final xp0 = g.xpOf(sig.value);
    g.tick(5);
    expect(g.xpOf(sig.value), greaterThan(xp0));
  });

  test('구름을 두드리면 밝혀지고, 경계가 이어진다', () {
    final g = Game(Game.fresh(seed: 7));
    final before = g.S.rev.where((v) => v == 1).length;
    for (var k = 0; k < 200; k++) {
      g.digAim();
    }
    expect(g.S.rev.where((v) => v == 1).length, greaterThan(before));
    for (final i in g.frontier) {
      expect(g.isFrontier(i), isTrue);
    }
  });
}
