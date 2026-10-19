// 웹 버전과 같은 결과가 나오는지 확인한다.
// 기준값(test/fixtures/web_core.json)은 tool/gen_data.cjs가 웹 코드를 직접 돌려서 만든 것이다.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taptocity/game/data.dart';
import 'package:taptocity/game/engine.dart';
import 'package:taptocity/game/rng.dart';
import 'package:taptocity/game/state.dart';

void main() {
  Game.tutFlag = true; // 튜토리얼은 따로 시험한다
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
      // 새 동네(gen>0)의 모듈 비용은 앱에서 일부러 낮췄다 (지어 본 설계: 첫 짓기 절반·증축 3/4) → 첫 동네만 웹과 같은지 본다
      if (g.S.gen == 0) (c['modBuild'] as Map).forEach((id, v) => expect(g.modBuildCost(int.parse(id as String)), cost(v), reason: '짓기 비용 $id'));
      if (g.S.gen == 0) (c['modUp'] as Map).forEach((id, v) {
        for (var l = 1; l <= 2; l++) {
          expect(g.modCost(int.parse(id as String), l), cost((v as List)[l - 1]), reason: '강화 비용 $id/$l');
        }
      });
      // 요새·불빛의 도시 증축(Lv.3→4, 4→5)은 앱에서 일부러 낮췄다 → 그 앞 단계만 웹과 같은지 본다
      if (g.S.lv <= 2) expect(g.shelterUpCost, c['shup'] == null ? isNull : cost(c['shup']));
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
    g.S.rest['mi'] = stepI('방벽 세우기');
    g.S.rest['storyI'] = g.mi;
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
    expect(g.rec(0)!['away'], isFalse); // 부상(위험 10%)일 수는 있어도 원정에서는 돌아왔다
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

  test('이야기: 미션을 하고 받으면 다음 걸음, 세는 목표는 그때부터 센다', () {
    final g = Game(Game.fresh(seed: 42));
    expect(steps.length, 38);
    expect(g.mission().txt, '구름을 두드려 땅 6칸 밝히기');
    expect(g.mission().done, isFalse);
    // 화면이 비어 있으면 첫 장면(프롤로그)이 열린다
    g.tick(.25);
    expect(g.takeFx().whereType<FxTalk>().first.card?.$1, '프롤로그');
    for (var k = 0; k < 200 && g.revCount < 15; k++) {
      g.digAim();
    }
    expect(g.mission().done, isTrue);
    final b0 = g.have('batt');
    g.claimMission();
    expect(g.mi, 1);
    expect(g.have('batt'), b0 + 1, reason: '미션마다 건전지 하나');
    // 세는 목표: 걸음이 열린 뒤에 한 번 해야 끝난다
    g.S.rest['mi'] = stepI('생존자 스킬 한 번 쓰기');
    g.S.rest['skillUses'] = 5;
    expect(g.mission().done, isFalse);
    g.S.rest['skillUses'] = 6;
    expect(g.mission().done, isTrue);
    // 옛 저장(걸음 순서가 달랐던 때)은 목표 글로 다시 맞춘다
    final o = Game(Game.fresh(seed: 1));
    o.S.rest['mi'] = 9; // 옛 순서 9번 = 라디오 탐색
    o.S.rest['storyI'] = 9;
    o.S.rest.remove('stepV');
    o.migrateSteps();
    expect(o.mi, stepI('라디오로 주파수 탐색 한 번 하기'));
    expect(o.S.rest['stepV'], 4);
  });

  test('등불 탑·업적', () {
    final g = Game(Game.fresh(seed: 42));
    g.S.rest['mi'] = stepI('등불 탑 토대 놓기');
    g.S.rest['storyI'] = g.mi;
    expect(g.towerOpen, isTrue);
    for (final id in [0, 1, 2, 3, 4, 5, 6]) {
      g.rescue(id, 'sig');
    }
    g.S.m.addAll({'plate': 9999, 'wood': 9999});
    expect(g.towerOk, isTrue);
    expect(g.buildTower(), isTrue);
    expect(g.towerN, 1);
    expect(g.mission().done, isTrue);
    // 업적: 땅 100칸 → 받을 수 있음 → 받으면 칭호
    for (var k = 0; k < 600 && g.revCount < 100; k++) {
      g.digAim();
    }
    g.tickStorySec();
    expect(g.achState('rev100'), 1);
    g.achGet('rev100');
    expect(g.achState('rev100'), 2);
    expect(g.title, '어둠을 걷는 사람');
  });

  test('지하 구역: 칸을 밝히면 기름이 줄고, 계단으로 내려가고, 돌아오면 챙긴 것을 받는다', () {
    final g = Game(Game.fresh(seed: 5), random: math.Random(3));
    g.S.lv = 3;
    for (final id in [0, 1]) {
      g.rescue(id, 'sig');
    }
    g.S.m['fuel'] = 10;
    expect(g.ugStart([0, 1], 4, 1), isTrue);
    expect(g.have('fuel'), 6);
    final u = g.ug!;
    expect(u.oil, 14 + 4 * 3);
    expect(u.floor, 1);
    // 계단을 찾을 때까지 앞쪽 칸을 두드린다
    var guard = 0;
    while (g.ug != null && g.ug!.floor == 1 && guard++ < 200) {
      final st = u.cells.indexWhere((c) => c.rev && c.c == 'stairs');
      if (st >= 0) {
        g.ugTap(st);
        break;
      }
      final i = List.generate(ugW * ugH, (k) => k).firstWhere((k) => g.ugFront(k), orElse: () => -1);
      if (i < 0 || g.ugTap(i)) break;
    }
    if (g.ug != null) {
      expect(g.ug!.floor, greaterThanOrEqualTo(1));
      g.ugEnd(true);
    }
    expect(g.ug, isNull);
    expect(g.ugRuns, 1);
    expect(g.ugBest, greaterThanOrEqualTo(1));
  });

  test('튜토리얼 그날 밤: 네 걸음을 지나면 새 지도에서 시작하고 안내 카드가 뜬다', () {
    Game.tutFlag = false;
    final g = Game(Game.fresh(seed: 9));
    g.tick(1);
    final t0 = g.takeFx().whereType<FxTalk>().first;
    expect(t0.card?.$2, '재가 내리던 새벽');
    expect(g.mission().txt, startsWith('랜턴을 두드려 어둠 걷기'));
    expect(g.clockText, '그날 밤 · 03:02');
    expect(g.isNight, isTrue);
    for (var k = 0; k < 40 && g.revCount < 20; k++) {
      g.digAim();
    }
    g.tick(1);
    expect(((g.tut!['i'] as num)).toInt(), 1);
    // 건너뛰기
    g.tutEnd = true;
    g.finishTut();
    expect(g.tut, isNull);
    expect(g.S.rest['tutSeen'], 1);
    expect(g.onb, 1);
    expect(g.takeFx().whereType<FxOnboard>(), isNotEmpty);
    // 안내 중에는 첫 이야기가 기다린다
    g.tick(1);
    expect(g.takeFx().whereType<FxTalk>(), isEmpty);
    g.onbEnd();
    g.tick(.25);
    expect(g.takeFx().whereType<FxTalk>().first.card?.$1, '프롤로그');
    Game.tutFlag = true;
  });

  test('사건 수첩: 조건이 되면 사건이 열리고, 추궁하면 단서와 결말이 남는다', () {
    final g = Game(Game.fresh(seed: 11));
    for (final id in [0, 1, 3]) {
      g.rescue(id, 'sig');
    }
    g.S.rest['mi'] = stepI('생존자 3명 모으기');
    g.S.rest['storyI'] = g.mi;
    g.takeFx();
    for (var k = 0; k < 8; k++) {
      g.tick(1);
    }
    expect(g.takeFx().whereType<FxCase>().map((f) => f.k), contains(0));
    final (ls, fx) = g.pickCase(0, 'a');
    expect(ls, isNotEmpty);
    expect(g.caseRec(0)!['solved'], 1);
    expect(fx.join(), contains('등불'));
    expect(g.caseSeen, isTrue);
    // 까마귀와 마주치면 고른 대로
    final (cl, cfx) = g.pickCrow('avoid');
    expect(cl, isNotEmpty);
    expect(g.crow['rel'], 'avoid');
    expect(cfx, isEmpty);
    // 회상: 지난 걸음의 그림이 열린다
    g.artBackfill();
    expect(g.artCount, greaterThan(4));
    expect(g.sceneSource(4), isNotNull);
  });

  test('이주: 다섯 명과 떠나면 새 동네가 시작되고, 남은 사람은 무전으로 거래·교대한다', () {
    final g = Game(Game.fresh(seed: 21));
    for (final id in [0, 1, 2, 3, 4, 5, 6, 7]) {
      g.rescue(id, 'sig');
    }
    g.S.lv = 5;
    g.S.rest['endSeen'] = 1;
    g.S.rest['mi'] = steps.length;
    g.S.rest['storyI'] = steps.length;
    g.S.m['batt'] = 10;
    expect(g.canMigrate, isTrue);
    final (rec, why) = g.migRecommend('desert');
    expect(rec.length, migMax);
    expect(why, isNotEmpty);
    g.takeFx();
    g.migrate([0, 1, 2, 3, 4]);
    expect(g.S.gen, 1);
    expect(g.S.region, 'desert');
    expect(g.S.sv.length, 5);
    expect(g.stayList.length, 3);
    expect(g.inStay(5), isTrue);
    final fx = g.takeFx();
    expect(fx.whereType<FxMigrated>(), isNotEmpty);
    expect(fx.whereType<FxTalk>().first.card?.$2, '메마른 사막 도시');
    // 동네 미션
    final m = g.mission();
    expect(m.reg, isTrue);
    expect(m.txt, contains('불빛'));
    expect(townName(1), '메마른 사막 도시');
    expect(wayLine(1), contains('지나'));
    // 숨겨진 저수조 찾기
    g.S.rest['rmi'] = 3;
    g.S.rest['rsI'] = 3;
    g.tickRegionSec();
    final si = (g.rq['spotI'] as num).toInt();
    g.S.rev[si] = 1;
    g.tickRegionSec();
    expect(g.mission().done, isTrue);
    g.claimMission();
    expect(g.rmi, 4);
    // 저수조 선택
    expect(g.pickTown('a'), isNotEmpty);
    expect(g.rq['pick'], 'share');
    g.recalc();
    expect(g.E['hope']! >= 10, isTrue);
    // 무전 거래
    for (final k in ['wood', 'scrap', 'food', 'cloth', 'fuel', 'parts']) {
      g.S.m[k] = 100;
    }
    final T = g.trState();
    expect((T['offers'] as List), isNotEmpty);
    expect(g.trAccept(0), isNull);
    expect((g.trade['pend'] as List).length, 1);
    // 교대: 건전지 2를 내고, 취소하면 돌려받는다
    final b0 = g.have('batt');
    expect(g.swapStart(5, 1), isTrue);
    expect(g.have('batt'), b0 - 2);
    g.swapCancel();
    expect(g.have('batt'), b0);
    // 노선도 기록
    expect(g.tlogList.any((e) => e is Map && e['g'] == 0 && e['left'] != null), isTrue);
  });

  test('새 동네: 잃은 사람, 모닥불, 동네 사건', () {
    final g = Game(Game.fresh(seed: 22));
    g.S.gen = 1;
    g.S.region = 'desert';
    g.S.rest['rmi'] = 3;
    g.S.rest['mi'] = steps.length;
    for (final id in [0, 1, 2, 4, 5, 6, 7, 8]) {
      g.rescue(id, 'sig');
    }
    // 큰 밤에 지면 누군가를 잃을 수 있다 (만수·하늘 등은 지킨다)
    for (var k = 0; k < 30 && g.S.rest['deathG'] == null; k++) {
      g.deathAfterDefense(false, Defense(null));
    }
    expect((g.S.rest['deathG'] as Map)['1'], 1);
    final dead = ((g.S.rest['dead'] as List).first as Map)['id'] as int;
    expect(g.isDead(dead), isTrue);
    expect(g.hasSv(dead), isFalse);
    expect(dead, isNot(0));
    final d = g.takeFx().whereType<FxDeath>().first;
    expect(g.deathLines(d), isNotEmpty);
    // 동네 사건: 미션 셋째부터
    g.S.rest['storyI'] = steps.length;
    g.S.rest['rsI'] = 3;
    for (var k = 0; k < 60; k++) {
      g.tick(1);
    }
    expect(g.takeFx().whereType<FxCase>().map((f) => f.k), contains(6));
    final (ls, cfx) = g.pickCase(6, 'a');
    expect(ls, isNotEmpty);
    expect(cfx, contains('단서를 찾았어요'));
    expect(g.caseKeys, contains(6));
    // 산골 모닥불
    g.S.region = 'snow';
    g.S.gen = 3;
    g.S.rest['warm'] = 0;
    g.recalc();
    expect(g.warmTier, 0);
    g.S.m['wood'] = 100;
    g.feedFire();
    g.feedFire();
    expect(g.warmTier, 2);
    // 마지막 동네의 미션을 다 하면 엔딩
    expect(g.regionMis().length, 9);
  });

  test('끊긴 노선: 터널을 고르고 올라오면 챙긴 것을 받고, 연달아 들어가면 보상이 준다', () {
    final g = Game(Game.fresh(seed: 23));
    for (final id in [0, 6]) {
      g.rescue(id, 'sig');
    }
    g.S.m['food'] = 100;
    expect(g.lnStart([0, 6]), isTrue);
    expect(g.ln!.hp, g.lnHp0([0, 6]));
    for (var k = 0; k < 40 && g.ln != null && (g.ln!.step < 2 || g.ln!.carry.isEmpty) && g.ln!.phase != 'done'; k++) {
      final L = g.ln!;
      if (L.phase == 'pick') {
        final i = L.cards.indexWhere((c) => c.c != 'foe' && c.c != 'hazard' && !c.hid);
        g.lnPick(i >= 0 ? i : 0);
      } else if (L.phase == 'hazard') {
        g.lnHazard(false);
      } else if (L.phase == 'fight') {
        L.fight!.hp = 0;
        L.phase = 'pick';
        L.fight = null;
        L.cards = [LnCard('loot')];
      } else {
        g.lnGoOn();
      }
    }
    final carry = Map.of(g.ln!.carry);
    g.lnEnd(true);
    expect(g.ln, isNull);
    expect(g.lnState()['fat'], 1);
    expect(g.lnMult, .75);
    expect(carry.isNotEmpty, isTrue);
    // 고리 판정: 금빛 테두리에 맞으면 2
    expect(g.lnStart([0]), isTrue);
    final L = g.ln!;
    L.phase = 'fight';
    L.fight = LnFight(false, 3, 1100, DateTime.now().microsecondsSinceEpoch / 1000 - 1100 * (1 - lnTgt / 100) - 60);
    g.lnStrike();
    expect(L.fight!.hp, 1);
  });

  test('개인 이야기: 신뢰도 3이면 열리고, 건네기·데려오기로 나아가 끝에 전용 장비', () {
    final g = Game(Game.fresh(seed: 24));
    // 앱 전용 (2026-10-20): 첫 동네의 개인 이야기는 3장부터 열린다 (웹은 이야기 걸음과 상관없이 신뢰도 3). 웹과 같은 조건을 보도록 3장에 둔다
    g.S.rest['mi'] = stepI('고물상 세우기');
    g.rescue(2, 'sig');
    g.rec(2)!['xp'] = 100000;
    g.tickStorySec();
    expect(g.qOf(2), isNotNull);
    expect(g.qStep(2)!['k'], 'give');
    g.S.m['med'] = 5;
    g.S.m['cloth'] = 50;
    expect(g.qGive(2), isTrue);
    expect(g.qStep(2)!['k'], 'find');
    // 하늘: 순례 할머니가 오면 다음 걸음
    g.rescue(3, 'sig');
    g.rec(3)!['xp'] = 100000;
    g.tickStorySec();
    g.rescue(4, 'sig');
    g.tickStorySec();
    expect(g.qStep(3)!['k'], 'find');
    // 마지막 걸음을 마치면 전용 장비
    g.qOf(3)!['s'] = 2;
    g.S.m['wood'] = 50;
    expect(g.qGive(3), isTrue);
    expect(g.qOf(3)!['done'], true);
    expect(g.inv.any((x) => x['t'] == 'umbrella'), isTrue);
  });

  test('프로필: 프롤로그 뒤 한 번 이름을 묻고, 이름은 열 글자까지', () {
    final g = Game(Game.fresh(seed: 25));
    g.S.rest['mi'] = 2;
    g.S.rest['storyI'] = 2;
    g.S.rest['onb'] = 2;
    g.tickStory();
    expect(g.takeFx().whereType<FxPfName>(), isNotEmpty);
    expect(g.S.rest['pfAsk'], 1);
    expect(g.speakerName('me'), '나');
    g.setPfName('  <하람>"의 등불지기입니다  ');
    expect(g.pfName, '하람의 등불지기입니');
    expect(g.pfSet, isTrue);
    expect(g.speakerName('me'), g.pfName);
    final i = g.pfIndex();
    expect(g.pfRandom(i), isNot(i));
    g.tickStorySec();
    expect(g.num_('playT'), 1);
  });
}
