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
    g.S.m.addAll({'wood': 999, 'scrap': 999, 'food': 100});
    g.buildMod(1);
    final tile = g.modAt.keys.first;
    g.assign(tile, sig.value);
    expect(g.atOf(sig.value), tile);
    final xp0 = g.xpOf(sig.value);
    g.tick(5);
    expect(g.xpOf(sig.value), greaterThan(xp0));
  });

  test('장비를 입히면 효과가 붙고, 강화와 스킬이 돈다', () {
    final g = Game(Game.fresh(seed: 42));
    g.S.m.addAll({'wood': 999, 'scrap': 999, 'food': 900, 'parts': 300, 'batt': 9, 'med': 9, 'wire': 9});
    g.buildMod(1);
    g.rescue(0, 'sig');
    g.rescue(1, 'sig');
    final tile = g.modAt.keys.first;
    g.assign(tile, 0);
    final it = g.addGear('shovel');
    expect(g.equip(0, 'tool', it['u']), isTrue);
    expect(g.wearer(it['u']), 0);
    expect(g.gearEff(0)['scav'], greaterThan(0));
    // 착용 중인 장비는 분해되지 않는다
    g.dismantle(it['u']);
    expect(g.itemAt(it['u']), isNotNull);
    // 별 강화: 신뢰도가 모자라면 안 되고, 채우면 된다
    g.rec(0)!['xp'] = 0;
    final st0 = g.starOf(0);
    g.rec(0)!['xp'] = trustXp[4];
    expect(g.promote(0), 'star');
    expect(g.starOf(0), st0 + 1);
    // 스킬: 쓰면 대기시간이 생긴다
    expect(g.party, [0, 1], reason: '구조하면 스킬 바에 들어간다');
    g.toggleParty(1);
    expect(g.party, [0]);
    expect(g.useSkill(0), isTrue);
    expect(g.cdLeft(0), greaterThan(0));
    expect(g.useSkill(0), isFalse);
    // 저장했다가 다시 읽어도 그대로
    final back = Game(Game.parseCode(g.exportCode())!);
    expect(back.wearer(it['u']), 0);
    expect(back.party, [0]);
  });

  test('밤이 오면 재가 밀려오고, 새벽엔 날씨가 바뀐다', () {
    final g = Game(Game.fresh(seed: 42));
    g.S.m.addAll({'wood': 999, 'scrap': 999, 'food': 999});
    for (var k = 0; k < 400 && g.revCount < 30; k++) {
      g.digAim();
    }
    g.rescue(0, 'sig');
    g.S.lv = 2;
    g.recalc();
    expect(g.isNight, isFalse);
    // 해 질 녘까지
    for (var k = 0; k < 4 * 160; k++) {
      g.tick(.25);
    }
    expect(g.isNight, isTrue);
    expect(g.stormOn, isTrue);
    expect(g.S.ash, isNotEmpty, reason: '재가 내려앉음');
    // 재를 두드려 걷어내면 고철을 준다
    final a = int.parse(g.S.ash.keys.first), s0 = g.have('scrap');
    for (var k = 0; k < 50 && g.S.ash.containsKey('$a'); k++) {
      g.hitAsh(a, 999);
    }
    expect(g.S.ash.containsKey('$a'), isFalse);
    expect(g.have('scrap'), greaterThanOrEqualTo(s0));
    // 새벽: 날씨가 정해진다
    for (var k = 0; k < 4 * 60; k++) {
      g.tick(.25);
    }
    expect(g.isNight, isFalse);
    expect(g.S.rest['wx'], isNotNull);
    expect(g.num_('day'), 1);
  });

  test('대형 재폭풍: 괴물을 다 막으면 이긴다', () {
    final g = Game(Game.fresh(seed: 42));
    g.S.lv = 2;
    g.recalc();
    g.startDefense();
    expect(g.defn, isNotNull);
    var n = 0;
    while (g.defn != null && n++ < 4000) {
      g.tickDefense(1 / 30);
      final f = g.urgentFoe;
      if (f != null) g.hurtFoe(f, 999);
    }
    expect(g.defn, isNull);
    expect(g.num_('defWins'), 1);
  });

  test('생존자의 부탁을 고르면 보상과 건전지를 받는다', () {
    final g = Game(Game.fresh(seed: 42));
    g.S.m.addAll({'wood': 999, 'scrap': 999, 'food': 999, 'cloth': 99, 'parts': 99, 'fuel': 99});
    g.rescue(0, 'sig');
    g.evCur = 1; // 고장 난 트럭 (만수)
    g.evLeft = evTotal;
    final b0 = g.have('batt');
    expect(g.chooseEv(1), isTrue);
    expect(g.have('batt'), b0 + 1);
    expect(g.evCur, -1);
    expect(g.num_('evDone'), 1);
  });

  test('원정을 보내고 돌아오면 전리품과 신뢰를 받는다', () {
    final g = Game(Game.fresh(seed: 42));
    g.rescue(0, 'sig');
    g.rescue(1, 'sig');
    final c = g.sendExp('mall', [0, 1]);
    expect(c, isNotNull);
    expect(g.busy(0), isTrue);
    expect(c!.t, 21); // 60초 × 0.6 × 정찰(도윤) 0.7 × 운전(만수) 0.85 = 21.42 → 21
    expect(c.mult, closeTo(1.25 * 1.25, 1e-9)); // 두 명 +25%, 기술(만수) +25%
    ((g.S.rest['exp'] as Map)['mall'] as Map)['end'] = 0;
    final xp0 = g.xpOf(0), b0 = g.have('batt');
    g.claimExp('mall');
    expect(g.busy(0), isFalse);
    expect(g.xpOf(0), greaterThan(xp0));
    expect(g.have('batt'), b0 + 2);
    expect(g.num_('expDone'), 1);
    expect(g.takeFx().whereType<FxExpBack>(), isNotEmpty);
  });

  test('주파수 탐색: 20번 안에 히든 생존자 신호가 반드시 잡힌다', () {
    final g = Game(Game.fresh(seed: 42));
    g.S.m['batt'] = 30;
    final got = <String>[];
    for (var k = 0; k < 20; k++) {
      got.addAll(g.pull(1)!.map((x) => x.k));
    }
    expect(got, contains('hidden'));
    expect(g.batt, 10);
    expect(g.pull(99), isNull);
  });

  test('바깥 세상: 펫·떠돌이 무리·장식·유물·잔치', () {
    final g = Game(Game.fresh(seed: 42));
    g.S.m.addAll({'wood': 999, 'scrap': 999, 'food': 999, 'cloth': 99, 'parts': 99, 'fuel': 99, 'med': 9});
    g.rescue(0, 'sig');
    g.rescue(3, 'sig');
    // 펫: 데려오면 동행하고 효과가 붙는다
    g.petAdopt('dog', quiet: true);
    expect(g.petOn, 'dog');
    expect(g.E['scav'], greaterThan(0));
    expect(g.petFeed('dog'), isTrue);
    expect(g.petFeed('dog'), isFalse, reason: '2분 동안은 배불러요');
    // 떠돌이 무리: 피란민에게 식량을 나누면 희망
    g.S.rest['band'] = <String, Object?>{'k': 'refugee', 'name': '저수지 피란민', 'tile': C0 + 3, 't': 150, 'offers': [], 'say': '', 'tribute': {}};
    final h0 = g.S.hopeB;
    expect(g.bandAct('bref'), isTrue);
    expect(g.S.hopeB, h0 + 4);
    expect(g.band, isNull);
    // 장식: 쉘터 둘레에 놓으면 희망
    for (var y = CY - 3; y <= CY + 3; y++) {
      for (var x = CX - 3; x <= CX + 3; x++) {
        if (g.S.rev[y * W + x] == 0) g.reveal(y * W + x);
      }
    }
    final spot = [for (var i = 0; i < N; i++) if (g.decoOk(i)) i].first;
    final hope0 = g.hope;
    expect(g.placeDeco('bench', spot), isTrue);
    expect(g.hope, greaterThan(hope0));
    // 유물
    expect(g.findRelic(), isNotNull);
    expect(g.relics.length, 1);
    // 잔치
    g.S.lv = 3;
    g.S.m.addAll({'food': 999, 'wood': 999});
    expect(g.holdFeast(), isTrue);
    expect(g.holdFeast(), isFalse, reason: '20분에 한 번');
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
