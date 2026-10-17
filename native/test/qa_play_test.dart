// QA: 자동 플레이 빨리 감기 (웹 tests/qa/tplay.py에 해당).
// 새 게임을 처음부터 시즌 끝(세 번째 새 동네의 엔딩)까지 사람 대신 두드리고 짓고 보내며 돌린다.
// 매 초 불변식(자재 음수·NaN, 생존자 겹침, 배치 어긋남, 저장 왕복)을 검사하고, 오류·막힌 걸음을 모아
// test_screens/shots/qa-play.txt 로 남긴다 (CI가 미리보기 폴더에 올린다).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:taptocity/game/data.dart';
import 'package:taptocity/game/engine.dart';
import 'package:taptocity/game/state.dart';

class Qa {
  final List<String> log = [];
  final Map<String, int> errs = {};
  void err(String where, Object e, [StackTrace? st]) {
    final k = '$where: ${'$e'.split('\n').first}';
    final n = errs[k] = (errs[k] ?? 0) + 1;
    if (n == 1) log.add('❌ $k\n${(st?.toString() ?? '').split('\n').take(6).join('\n')}');
  }

  void note(String t) => log.add(t);
}

int simMs = 0;

/// 목표마다 걸린 시간 (재미 점검용 · qa-pace.csv): 시드, 동네, 목표, 시작 분, 걸린 분
final pace = <String>['seed,gen,step,goal,start_min,minutes'];
int paceSeed = 0;

/// 사람처럼 한 걸음: 두드리고, 받고, 짓고, 보내고, 고른다
void autoStep(Game g, Qa qa, math.Random r) {
  void safe(String n, void Function() f) {
    try {
      f();
    } catch (e, st) {
      qa.err(n, e, st);
    }
  }

  // 화면이 해 주는 일: 창 처리 (고르기가 필요한 것만)
  safe('fx', () {
    for (final f in g.takeFx()) {
      switch (f) {
        case FxCase(:final k):
          g.pickCase(k, const ['a', 'b', 'c'][r.nextInt(3)]);
        case FxCrowMeet():
          g.pickCrow(const ['deal', 'avoid', 'fight'][r.nextInt(3)]);
        case FxConf():
          g.chooseConf(r.nextBool());
        case FxTownChoice():
          g.pickTown(r.nextBool() ? 'a' : 'b');
        case FxOnboard():
          g.onbEnd();
        case FxTalk(:final after):
          if (after == 'endCard') {
            g.S.rest['ehEnd'] = 1;
            g.endingOn = false;
            qa.note('🎬 엔딩 (${g.S.gen}번째 동네, 시뮬 ${simMs ~/ 60000}분)');
          }
        default:
          break;
      }
    }
  });
  if (g.defn != null) {
    safe('defense', () {
      for (var k = 0; k < 3; k++) {
        final f = g.urgentFoe;
        if (f != null) g.tapFoe(f);
      }
    });
    return;
  }
  if (g.ug != null) {
    safe('ug', () {
      final u = g.ug!;
      final front = [for (var i = 0; i < u.cells.length; i++) if (g.ugFront(i)) i];
      final stairs = [for (var i = 0; i < u.cells.length; i++) if (u.cells[i].rev && u.cells[i].c == 'stairs') i];
      if (stairs.isNotEmpty && r.nextDouble() < .7) {
        g.ugTap(stairs.first);
      } else if (front.isNotEmpty && u.oil > 3) {
        g.ugTap(front[r.nextInt(front.length)]);
      } else {
        g.ugEnd(true);
      }
    });
    return;
  }
  if (g.ln != null) {
    safe('line', () {
      final L = g.ln!;
      if (L.phase == 'pick') {
        g.lnPick(r.nextInt(L.cards.length));
      } else if (L.phase == 'hazard') {
        g.lnHazard(r.nextBool());
      } else if (L.phase == 'station' && L.step < 6) {
        g.lnGoOn();
      } else {
        g.lnEnd(true);
      }
    });
    return;
  }
  // 사람처럼 두드리기 (초당 5번쯤): 구조 캠프 잔해 → 폐허 뒤지기 → 구름 걷기
  safe('tap', () {
    // 잔해가 남은 캠프만 (다 치운 캠프는 침대·자재가 생길 때까지 기다린다)
    final camps = [for (final e in g.S.camp.entries) if (g.S.rev[e.key] == 1 && ((e.value['hp'] as num?) ?? 0) > 0) e.key];
    int near(Iterable<int> xs) => xs.reduce((a, b) => dist(a) <= dist(b) ? a : b);
    final sites = [for (var i = 0; i < N; i++) if (g.S.rev[i] == 1 && g.siteLive(i)) i];
    for (var k = 0; k < 5; k++) {
      if (camps.isNotEmpty) {
        g.tapTile(near(camps));
      } else if (sites.isNotEmpty && r.nextDouble() < .6) {
        final s = near(sites);
        g.tapTile(s);
        if (!g.siteLive(s)) sites.remove(s);
      } else {
        g.digAim();
      }
    }
  });
  safe('claim', () {
    if (g.mission().done) g.claimMission();
  });
  safe('rescue', () {
    for (final e in g.S.camp.entries.toList()) {
      if (g.campReady(e.key)) g.doRescue(e.key);
    }
  });
  if (r.nextDouble() < .3) {
    safe('build', () {
      // 아직 안 지은 모듈 먼저, 같은 모듈 또 짓기는 그다음
      final want = [for (final id in const [1, 2, 9, 3, 4, 8, 5, 6, 7]) if (mods[id] != null && g.modN(id) == 0 && g.S.lv >= mods[id]!.req) id];
      for (final id in [...want, if (want.isEmpty) ...[9, 1, 2, 8, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15]]) {
        if (mods[id] != null && g.canBuild(id)) {
          g.buildMod(id);
          break;
        }
      }
      // 아직 안 지은 모듈이 있으면 자재를 아낀다 (그 모듈에 드는 재료의 가공만)
      final saving = want.isNotEmpty;
      final need = {for (final id in want) ...g.modBuildCost(id).keys, if (g.towerOpen && g.towerN < 5) ...g.towerCost.keys};
      for (final k in g.S.mods.keys.toList()) {
        // 전선은 작업대 2단계부터 → 전선이 필요하면 작업대는 올린다
        final wbWant = need.contains('med') ? 3 : need.contains('wire') ? 2 : 0; // 약품은 작업대 3단계, 전선은 2단계부터
        if ((!saving || (g.S.mods[k]!.id == 1 && g.wbL < wbWant)) && r.nextDouble() < .2) g.upMod(k);
      }
      g.upShelter();
      g.upWalls();
      for (var k = 0; k < recipes.length; k++) {
        // 사람처럼: 다음에 지을 것(증축·새 모듈·방벽)에 드는 만큼만, 없으면 조금만 쌓아 둔다 (재료를 다 갈아 넣지 않게)
        final out = recipes[k].out;
        var want2 = 12.0;
        for (final c in [g.shelterUpCost, for (final id in want) g.modBuildCost(id), if (g.S.walls < 3) g.wallCost(g.S.walls), if (g.towerOpen && g.towerN < 5) g.towerCost]) {
          if (c != null && c[out] != null) want2 = math.max(want2, c[out]!.toDouble());
        }
        if (g.have(out) >= want2) continue;
        if ((!saving || k < 2 || need.contains(out)) && r.nextDouble() < .3) g.craft(k, 3);
      }
      for (final k in const ['tap', 'splash', 'drone']) {
        if (!saving && r.nextDouble() < .2) g.buyUp(k);
      }
      if (g.towerOk) g.buildTower();
      for (final e in g.S.lm.entries.toList()) {
        if (!e.value.ok && g.S.rev[e.key] == 1) g.restoreLm(e.key);
      }
    });
  }
  safe('assign', () {
    final free = [for (final id in g.svIds) if (g.atOf(id) < 0 && !g.busy(id)) id];
    // 원정 보낼 사람 두 명은 쉬게 둔다 (원정은 쉬는 사람만 갈 수 있다)
    final keep = g.svIds.length >= 3 ? 2 : 0;
    for (final t in g.modAt.keys) {
      if (free.length <= keep) break;
      if (g.S.asg[t] == null) g.assign(t, free.removeLast());
    }
  });
  if (r.nextDouble() < .2) {
    safe('skill', () {
      for (final id in g.party) {
        g.useSkill(id);
      }
    });
    safe('gear', () => g.autoGear());
    safe('promote', () {
      if (g.S.mods.values.every((m) => m.id != 5) && g.S.lv >= 3) return; // 발전기 지을 부품을 아낀다
      for (final id in g.svIds) {
        if (g.canPromote(id)) g.promote(id);
      }
    });
    safe('gift', () {
      if (g.svIds.isNotEmpty) g.gift(g.svIds.first);
    });
  }
  if (r.nextDouble() < .1) {
    safe('exp', () {
      // 등불 탑 5층(불 켜기)은 모두 쉘터에 있어야 해서 그 앞에선 새로 보내지 않는다
      final hold = g.towerOpen && g.towerN == 4;
      for (final e in exps) {
        g.claimExp(e.key, quiet: true);
        if (!hold && g.expOpen(e) && g.expMap[e.key] == null) {
          final t = g.autoTeam(e);
          if (t != null && t.isNotEmpty) g.sendExp(e.key, t);
        }
      }
    });
  }
  if (r.nextDouble() < .05 && g.have('batt') >= 3) safe('pull', () => g.pull(1));
  if (g.evCur >= 0) safe('event', () => g.chooseEv(r.nextInt(2)));
  if (g.sqDone) safe('sq', g.claimSq);
  if (r.nextDouble() < .02) safe('feast', () => g.holdFeast());
  if (r.nextDouble() < .02 && g.ugOpen && g.S.sv.length >= 2) {
    // 사람처럼: 지난번 멈춘 층부터, 들고 갈 수 있는 만큼 연료를 챙겨 내려간다
    safe('ugStart', () {
      final t = g.svIds.where((id) => !g.busy(id)).take(3).toList();
      g.ugStart(t, math.min(g.ugFuelMax(t), g.have('fuel').toInt()), g.ugLast);
    });
  }
  if (r.nextDouble() < .01 && g.lnOpen && g.S.sv.length >= 2) safe('lnStart', () => g.lnStart(g.svIds.take(2).toList()));
  // 동네 일
  if (g.S.gen != 0) {
    safe('town', () {
      if (g.curRegK == 'op' && g.rq['opEnd'] == null) g.startOp();
      if (g.fireOn && (g.warm ?? 100) < 50) g.feedFire();
      if (g.rspot != null && r.nextDouble() < .5) g.rspotHit((g.rspot!['i'] as num).toInt());
      final tr = g.trState();
      if ((tr['offers'] as List).isNotEmpty && r.nextDouble() < .05) g.trAccept(0);
    });
  }
  // 이주: 갈 수 있고 동네 미션을 다 했으면 (첫 동네는 탑까지)
  if (g.canMigrate && (g.S.gen == 0 ? g.towerN >= 5 : g.rmi >= g.regionMis().length) && g.S.gen < 3 && g.S.rest['ehEnd'] == null) {
    safe('migrate', () {
      final (pick, _) = g.migRecommend(g.nextRegion);
      qa.note('🚚 이주 → ${g.nextRegion} (시뮬 ${simMs ~/ 60000}분, 생존자 ${g.S.sv.length}명)');
      g.migrate(pick);
    });
  }
}

/// 불변식
void check(Game g, Qa qa, String tag) {
  void bad(String t) => qa.err('불변식 $tag', t);
  for (final e in g.S.m.entries) {
    final v = e.value;
    if (v.isNaN || v.isInfinite) bad('자재 ${e.key} = $v');
    if (v < 0) bad('자재 ${e.key} 음수 $v');
  }
  for (final id in g.svIds) {
    if (g.isDead(id)) bad('죽은 사람이 무리에 $id');
    if (g.inStay(id)) bad('남은 사람이 무리에 $id');
    final at = g.atOf(id);
    if (at >= 0 && g.S.asg[at] != id) bad('배치 어긋남 $id @ $at');
  }
  for (final e in g.S.asg.entries) {
    if (!g.hasSv(e.value)) bad('없는 사람이 배치됨 ${e.value}');
  }
  for (final id in g.party) {
    if (!g.hasSv(id)) bad('스킬 바에 없는 사람 $id');
  }
  void walk(Object? v, String p) {
    if (v is double && (v.isNaN || v.isInfinite)) bad('저장 값 $p = $v');
    if (v is Map) {
      for (final e in v.entries) {
        walk(e.value, '$p.${e.key}');
      }
    }
    if (v is List) {
      for (var i = 0; i < v.length; i++) {
        walk(v[i], '$p[$i]');
      }
    }
  }

  walk(g.S.rest, 'rest');
  try {
    final m = g.mission();
    if (RegExp(r'null|NaN|Infinity|undefined').hasMatch('${m.txt} ${m.sub}')) bad('미션 글: ${m.txt}');
  } catch (e, st) {
    qa.err('mission()', e, st);
  }
}

void roundTrip(Game g, Qa qa) {
  try {
    final a = g.toJsonString();
    final s = GameState.fromJson(jsonDecode(a) as Map<String, dynamic>)!;
    final b = jsonEncode(s.toJson());
    final a2 = jsonEncode((jsonDecode(a) as Map)..remove('t'));
    final b2 = jsonEncode((jsonDecode(b) as Map)..remove('t'));
    if (a2 != b2) qa.err('저장 왕복', '저장→읽기→저장 결과가 달라요 (${a2.length} vs ${b2.length})');
    // 저장 코드도
    if (Game.parseCode(g.exportCode()) == null) qa.err('저장 코드', '읽지 못함');
  } catch (e, st) {
    qa.err('저장 왕복', e, st);
  }
}

/// 한 판: 시뮬레이션 분 수만큼
void run(Game g, Qa qa, int minutes, int seed, {bool stopAtEnd = true}) {
  final r = math.Random(seed);
  final base = DateTime.now().millisecondsSinceEpoch;
  Game.nowMs = () => base + simMs;
  var lastMi = -1, lastRmi = -1, stuck = 0, lastGen = -1;
  String? paceLabel;
  var paceStart = 0, paceGen = 0, paceStep = 0;
  for (var sec = 0; sec < minutes * 60; sec++) {
    for (var q = 0; q < 2; q++) {
      simMs += 500;
      try {
        g.tick(.5);
        if (g.defn != null) g.tickDefense(.5);
      } catch (e, st) {
        qa.err('tick', e, st);
      }
    }
    autoStep(g, qa, r);
    if (sec % 10 == 0) check(g, qa, '${g.S.gen}동네 ${sec ~/ 60}분');
    if (sec % 300 == 0) roundTrip(g, qa);
    // 막힌 걸음 찾기: 15분(시뮬) 넘게 같은 걸음이면 기록
    final key = g.S.gen * 1000 + (g.mi < steps.length ? g.mi : 100 + g.rmi);
    if (key != lastMi * 1000 + lastRmi || g.S.gen != lastGen) {
      // 앞 목표가 끝났다 → 걸린 시간 기록
      if (paceLabel != null) {
        pace.add('$paceSeed,$paceGen,$paceStep,"${paceLabel.replaceAll('"', "'")}",${(paceStart / 60).toStringAsFixed(1)},${((sec - paceStart) / 60).toStringAsFixed(1)}');
      }
      paceLabel = g.mission().txt;
      paceStart = sec;
      paceGen = g.S.gen;
      paceStep = g.mi < steps.length ? g.mi : 100 + g.rmi;
      lastMi = key ~/ 1000;
      lastRmi = key % 1000;
      lastGen = g.S.gen;
      stuck = 0;
    } else if (++stuck == 15 * 60) {
      final m = g.mission();
      final mats = [for (final e in g.S.m.entries) if (e.value >= 1) '${e.key}${e.value.floor()}'].join(' ');
      final live = [for (var i = 0; i < N; i++) if (g.siteLive(i)) i].length;
      qa.note('⏸ 15분째 같은 목표: ${g.S.gen}동네 · ${m.txt} / ${m.sub} (Lv.${g.S.lv}, 생존자 ${g.S.sv.length}, 밝힌 땅 ${g.revCount}, 폐허 $live, 캠프 ${g.S.camp.length}, 모듈 ${g.S.mods.length}) · $mats');
    }
    if (stopAtEnd && g.S.rest['ehEnd'] != null) break;
  }
  qa.note('끝: ${g.S.gen}번째 동네 · Lv.${g.S.lv} · 생존자 ${g.S.sv.length} · 걸음 ${g.mi}/${steps.length} · 동네 미션 ${g.rmi} · 밤 ${g.num_('nights')} · 막은 폭풍 ${g.num_('defWins')} · 지하 ${g.ugBest}층 · 탑 ${g.towerN} · 시뮬 ${simMs ~/ 60000}분');
}

void main() {
  Game.tutFlag = true;
  final out = <String>[];
  tearDownAll(() {
    Directory('test_screens/shots').createSync(recursive: true);
    File('test_screens/shots/qa-play.txt').writeAsStringSync('${out.join('\n')}\n');
    File('test_screens/shots/qa-pace.csv').writeAsStringSync('${pace.join('\n')}\n');
  });

  for (final seed in [1, 2, 3]) {
    test('자동 플레이: 새 게임 → 시즌 끝 (시드 $seed)', () {
      simMs = 0;
      final qa = Qa();
      final g = Game(Game.fresh(seed: seed * 101));
      paceSeed = seed;
      run(g, qa, 24 * 60, seed);
      out
        ..add('===== 새 게임 시드 $seed =====')
        ..addAll(qa.log)
        ..add('오류 ${qa.errs.length}종 ${qa.errs.values.fold(0, (a, b) => a + b)}건');
      Game.nowMs = () => DateTime.now().millisecondsSinceEpoch;
      expect(qa.errs.keys.where((k) => !k.startsWith('불변식')).toList(), isEmpty, reason: qa.log.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 8)));
  }

  test('오프라인 진행: 8시간 비웠다 돌아오기', () {
    simMs = 0;
    final qa = Qa();
    final g = Game(Game.fresh(seed: 77));
    paceSeed = 0; // 오프라인 판 (재미 점검표에서 0)
    run(g, qa, 40, 9);
    try {
      g.offline(Game.nowMs() + 8 * 3600 * 1000);
      check(g, qa, '오프라인 뒤');
      roundTrip(g, qa);
    } catch (e, st) {
      qa.err('offline', e, st);
    }
    out
      ..add('===== 오프라인 =====')
      ..addAll(qa.log);
    Game.nowMs = () => DateTime.now().millisecondsSinceEpoch;
    expect(qa.errs, isEmpty, reason: qa.log.join('\n'));
  });
}
