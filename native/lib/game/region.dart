// 6단계: 이주와 새 동네 — 이주(함께 갈 사람 고르기), 동네 규칙, 동네 미션 9개·동네 이야기, 먼 곳의 신호,
// 동네마다 숨은 사람, 저수조·공장·분교 이야기와 선택, 소문, 동네 기록·노선도, 남은 사람들(무전 거래·교대),
// 잃은 사람들, 신기루·멈추지 않은 기계, 산골 모닥불, 동네 사건, 엔딩 시점.
// 웹 index.html 3150–3260, 4207–4292, 5202–5417, 5745–5780, 5862–5866, 6015–6177.
part of 'engine.dart';

class RegionInfo {
  RegionInfo(Map m)
      : n = m['n'] as String,
        d = m['d'] as String,
        prod = {for (final e in (m['prod'] as Map).entries) e.key as String: (e.value as num).toDouble()},
        scav = {for (final e in (m['scav'] as Map).entries) e.key as String: (e.value as num).toDouble()},
        wx = m['wx'] == null ? null : {for (final e in (m['wx'] as Map).entries) e.key as String: (e.value as num).toDouble()},
        big = (m['big'] as num).toInt();
  final String n, d;
  final Map<String, double> prod, scav;
  final Map<String, double>? wx;
  final int big;
}

final Map<String, RegionInfo> regions = {for (final e in web.regions.entries) e.key: RegionInfo(e.value)};
final List<String> regionOrder = [for (final r in web.regionMisc['order'] as List) r as String];
String regionOfGen(int g) => g == 0 ? 'home' : regionOrder[(g - 1) % regionOrder.length];

String townName(int g) {
  if (g == 0) return '처음 불을 켠 동네';
  final n = regions[regionOfGen(g)]?.n ?? '';
  final lap = (g - 1) ~/ regionOrder.length;
  return lap > 0 ? '${const ['두', '세', '네', '다섯', '여섯'].elementAtOrNull(lap - 1) ?? '${lap + 1}'} 번째 $n' : n;
}

List<String> wayPts(int g) => [for (final x in ((web.regionMisc['wayPts'] as Map)['${regionOfGen(g - 1)}>${regionOfGen(g)}'] as List? ?? const [])) x as String];

bool _bat(String w) => (w.codeUnitAt(w.length - 1) - 0xac00) % 28 > 0;
String wayLine(int g) {
  final w = wayPts(g);
  if (w.isEmpty) return '';
  final parts = [for (var i = 0; i < w.length; i++) i < w.length - 1 ? '${w[i]}${_bat(w[i]) ? '과' : '와'}' : w[i]];
  return '${parts.join(' ')}${_bat(w.last) ? '을' : '를'} 지나, ${townName(g)}에 닿았다.';
}

List<Line> _lines(Object? l) => [for (final x in (l as List? ?? const [])) Line.of(x)!];
List<(List<Line>, List<Line>)> _arc(Object? a) => [for (final s in (a as List)) (_lines((s as Map)['i']), _lines(s['o']))];

final Map<String, List<(List<Line>, List<Line>)>> regStory = {for (final e in (web.regionText['story'] as Map).entries) e.key as String: _arc(e.value)};
final List<(List<Line>, List<Line>)> regAgain = _arc(web.regionText['again']);

/// 동네 미션 하나 (웹 regionMis)
class RegMis {
  const RegMis(this.goal, this.done, this.rw, this.hint, {this.k});
  final String goal, hint;
  final String? k;
  final bool Function(Game g) done;
  final Cost rw;
}

/// 잃은 사람 장면
class FxDeath extends Fx {
  const FxDeath(this.id, this.raid, this.where, this.tile, this.friend);
  final int id, tile;
  final String? raid;
  final String where;
  final int? friend;
}

/// 동네 선택 창 · 공장 작전 창
class FxTownChoice extends Fx {
  const FxTownChoice();
}

/// 이주 직후: 화면이 도장을 찍고 카메라를 가운데로
class FxMigrated extends Fx {
  const FxMigrated(this.g, this.region);
  final int g;
  final String region;
}

const migMax = 5;
const swapCost = <String, num>{'batt': 2};
const trMax = 3, trTrust = 5;

extension Region on Game {
  RegionInfo? get reg => S.region == null ? null : regions[S.region];
  Map get rq {
    if (S.rest['rq'] is! Map) S.rest['rq'] = <String, Object?>{};
    return S.rest['rq'] as Map;
  }

  int get rmi => num_('rmi').toInt();
  String get nextRegion => regionOrder[S.gen % regionOrder.length];

  double regScav(String k) {
    var v = reg?.scav[k] ?? 1;
    final pk = S.gen != 0 ? rq['pick'] : null;
    if (pk == 'keep' && k == 'fuel') v *= 1.3;
    if (pk == 'fix' && (k == 'parts' || k == 'wire')) v *= 1.3;
    return v;
  }

  double regProd(String k) => reg?.prod[k] ?? 1;

  /// 대형 재폭풍 주기 (공단은 두 밤마다, 라인을 부수면 세 밤)
  int get bigPeriod => S.gen != 0 && rq['pick'] == 'smash' ? 3 : (reg != null && reg!.big > 0 ? reg!.big : 3);

  String? rollRegionWx() {
    final w = reg?.wx;
    if (w == null) return null;
    var r = rnd.nextDouble();
    for (final e in w.entries) {
      if (r < e.value) return e.key;
      r -= e.value;
    }
    return 'normal';
  }

  // ================= 동네 미션 (웹 regionMis 4220) =================
  List<RegMis> regionMis() {
    final r = S.region, base = num_('arriveWins');
    final light = RegMis('새 동네에 불빛 켜기 · 땅 30칸 밝히기', (g) => g.revCount >= 30, {'wood': 20, 'scrap': 20, 'batt': 1}, '랜턴으로 주변 구름부터 걷어요');
    final shack = RegMis('판잣집 쉘터 다시 세우기', (g) => g.S.lv >= 2, {'cloth': 20, 'food': 20, 'batt': 1}, '함께 온 사람들 덕분에 침상 걱정은 없어요');
    final fort = RegMis('요새로 키우기', (g) => g.S.lv >= 4, {'wire': 4, 'med': 2, 'batt': 2}, '');
    final city = RegMis('불빛의 도시 다시 밝히기', (g) => g.S.lv >= 5, {'batt': 5}, '이 동네에도 등불 탑을 세울 수 있게 돼요');
    final tower = RegMis('이 동네 등불 탑에 불 켜기', (g) => g.towerN >= 5, {'batt': 5, 'med': 3}, '쉘터 화면 ‘건설’ 맨 위 등불 탑에서 쌓아요');
    if (r == 'desert') {
      return [
        light,
        shack,
        RegMis('연료 80 모으기', (g) => g.have('fuel') >= 80, {'food': 40, 'batt': 2}, '폐차와 벙커에서 연료가 잘 나와요'),
        RegMis('숨겨진 저수조 찾기', (g) => g.rq['spot'] != null, {'food': 60, 'batt': 2}, '지도에 물방울 표시가 생겼어요. 그쪽 구름을 걷어요', k: 'spot'),
        RegMis('저수조 지키기 · 물 도둑 막아내기', (g) => g.num_('defWins') - ((g.rq['raidBase'] as num?) ?? 1e9) >= 1, {'plate': 20, 'batt': 2},
            '오늘 밤 물 도둑이 쳐들어와요. 방벽과 랜턴탑으로 버텨요',
            k: 'raid'),
        RegMis('저수조를 어떻게 할지 정하기', (g) => g.rq['pick'] != null, {'batt': 2}, '미션을 눌러 정해요', k: 'choice'),
        fort,
        city,
        tower,
      ];
    }
    if (r == 'factory') {
      return [
        light,
        shack,
        RegMis('대형 재폭풍 2번 막아내기', (g) => g.num_('defWins') - base >= 2, {'plate': 15, 'batt': 2}, '두 밤마다 몰려와요. 방벽과 랜턴탑을 서둘러요'),
        RegMis('멈추지 않는 공장 찾기', (g) => g.rq['spot'] != null, {'parts': 40, 'batt': 2}, '지도에 굴뚝 표시가 생겼어요. 그쪽 구름을 걷어요', k: 'spot'),
        RegMis('공장 끄기 작전', (g) => g.rq['op'] != null, {'wire': 6, 'batt': 2}, '미션을 눌러 작전을 시작해요', k: 'op'),
        RegMis('공장 라인을 어떻게 할지 정하기', (g) => g.rq['pick'] != null, {'batt': 2}, '미션을 눌러 정해요', k: 'choice'),
        fort,
        city,
        tower,
      ];
    }
    return [
      light,
      shack,
      RegMis('목재 200 모으기', (g) => g.have('wood') >= 200, {'fuel': 30, 'batt': 2}, '무너진 집에서 목재가 넉넉히 나와요'),
      RegMis('산골 분교 찾기', (g) => g.rq['spot'] != null, {'food': 60, 'cloth': 20, 'batt': 2}, '지도에 학교 표시가 생겼어요. 그쪽 구름을 걷어요', k: 'spot'),
      RegMis('한파 사흘 버티기', (g) => g.rq['cold'] != null, {'fuel': 40, 'batt': 3}, '사흘 밤 동안 장작이 빨리 줄어요. 목재를 넉넉히 모아 둬요', k: 'cold'),
      RegMis('산 너머 대피소를 어떻게 할지 정하기', (g) => g.rq['pick'] != null, {'batt': 2}, '미션을 눌러 정해요', k: 'choice'),
      fort,
      city,
      tower,
    ];
  }

  Mission? get regionMission {
    if (S.gen == 0 || mi < steps.length) return null;
    final RM = regionMis(), k = rmi;
    if (k >= RM.length) return null;
    final m = RM[k], Q = rq;
    var txt = m.goal;
    if (m.k == 'op' && Q['opEnd'] != null && Q['op'] == null) {
      txt += ' · 진행 중 ${math.max(0, (((Q['opEnd'] as num) - Game.nowMs()) / 1000).ceil())}초';
    } else if (m.k == 'cold' && Q['coldBase'] != null && Q['cold'] == null) {
      txt += ' (${math.min(3, num_('nights') - (Q['coldBase'] as num))}/3밤)';
    }
    return Mission(txt, m.done(this), m.rw, m.hint, reg: true, rk: m.k);
  }

  String? get curRegK {
    if (S.gen == 0 || S.region == null) return null;
    final RM = regionMis();
    return rmi < RM.length ? RM[rmi].k : null;
  }

  // ================= 동네 이야기 (웹 REG_STORY 5207) =================
  List<(List<Line>, List<Line>)> get regArc => S.gen <= 3 && regStory[S.region] != null ? regStory[S.region]! : regAgain;

  List<Line>? regIntro(int k) {
    final a = k < regArc.length ? regArc[k].$1 : null;
    if (k != 0 || S.gen <= 3) return a;
    final p = (S.rest['rumor'] as Map?)?[S.region];
    final rumor = (web.regionMisc['rumor'] as Map)[p];
    return rumor == null ? a : [Line('me', '이 동네 사람이 먼저 말을 걸어왔다. $rumor'), ...?a];
  }

  List<Line>? regOutro(int k) => k < regArc.length ? regArc[k].$2 : null;

  /// 지금 동네 미션의 장면 (웹 tickRegionStory)
  void _tickRegionStory() {
    if (S.gen == 0 || mi < steps.length) return;
    final RM = regionMis(), k = rmi;
    if (k >= RM.length || num_('rsI') == k || uiBusy) return;
    S.rest['rsI'] = k;
    final it = regIntro(k);
    if (it != null) talk(it, tag: '${reg?.n ?? ''} · ${k + 1}/${RM.length}', goal: RM[k].goal);
  }

  /// 받기를 눌렀을 때 동네 미션 쪽 (웹 claim의 m.reg)
  void claimRegion() {
    final o = regOutro(rmi);
    S.rest['rmi'] = rmi + 1;
    if (o != null) talk(o, tag: reg?.n ?? '');
  }

  // ================= 먼 곳의 신호 (웹 NEXT_CALL 5243) =================
  bool get signalOk => towerN >= 5 && (S.rest['hook'] as Map?)?['${S.gen}'] == null;

  void hearNextCall() {
    if (S.rest['hook'] is! Map) S.rest['hook'] = <String, Object?>{};
    (S.rest['hook'] as Map)['${S.gen}'] = 1;
    final r = nextRegion;
    final nc = (web.regionText['nextCall'] as Map)[r];
    talk(S.gen < 3 && nc != null ? _lines(nc) : _lines(web.regionText['nextAgain']), tag: '먼 곳의 신호');
  }

  /// 다음 동네에서 부른 사람 (신호를 들은 뒤)
  (String, String)? get nextCaller {
    final r = nextRegion;
    final npc = (web.regionMisc['npc'] as Map)[r];
    if (S.gen >= 3 || npc == null || (S.rest['hook'] as Map?)?['${S.gen}'] == null) return null;
    return ((npc as Map)['n'] as String, npc['sub'] as String);
  }

  /// 첫 동네는 마지막 걸음('등불 탑에 불 켜기')까지 받은 뒤에 떠난다.
  /// (탑을 켠 직후 받기 전에 떠나면 그 걸음이 새 동네로 따라와 동네 미션이 열리지 않던 문제 · 2026-10-17)
  bool get canMigrate => S.lv >= 5 && (S.gen != 0 || (S.rest['endSeen'] != null && mi >= steps.length));

  // ================= 이주 (웹 migrate 4272) =================
  /// 다음 동네에 맞춘 추천 다섯 (웹 migRecommend)
  (List<int>, Map<int, List<String>>) migRecommend(String region) {
    final need = (web.regionMisc['migNeed'] as Map)[region] as Map? ?? (web.regionMisc['migNeed'] as Map)['desert'] as Map;
    final roles = [for (final r in need['roles'] as List) r as String], effs = [for (final r in need['eff'] as List) r as String];
    const en = {'thrift': '식량 절약', 'food': '식량 생산', 'craft': '가공', 'tap': '두드리기', 'hope': '희망', 'scav': '수확'};
    final roleN = web.regionMisc['roleN'] as Map;
    final ids = svIds.toList(), sc = <int, int>{}, why = <int, List<String>>{};
    for (final id in ids) {
      var s = gradeOf(id) * 3 + Game.trustLv(xpOf(id));
      final w = <String>[];
      final e = effOf(id);
      for (final k in effs) {
        if ((e[k] ?? 0) != 0) {
          s += 3;
          w.add(en[k] ?? k);
        }
      }
      for (final k in [...roles, 'medic']) {
        if (roleOf(id).contains(k)) {
          s += k == 'medic' && !roles.contains(k) ? 2 : 4;
          w.add('${roleN[k]}');
        }
      }
      if (sigWorn(id)) {
        s += 2;
        w.add('전용 도구');
      }
      if (gradeOf(id) >= 2) w.add(grades[gradeOf(id)].n ?? '');
      sc[id] = s;
      why[id] = w.toSet().take(2).toList();
    }
    final pick = <int>[], has = <String>{};
    void take(int id) {
      if (!pick.contains(id) && pick.length < migMax) {
        pick.add(id);
        has.addAll(roleOf(id));
      }
    }

    for (final k in [...roles, 'medic']) {
      final c = ids.where((id) => !pick.contains(id) && roleOf(id).contains(k)).toList()..sort((a, b) => sc[b]! - sc[a]!);
      if (c.isNotEmpty && !has.contains(k)) take(c.first);
    }
    for (final id in [...ids]..sort((a, b) => sc[b]! - sc[a]!)) {
      take(id);
    }
    return (pick, why);
  }

  /// 그 사람 전용 도구를 끼고 있나 (웹 sigWorn 1589)
  bool sigWorn(int id) {
    final q = rec(id)?['eq'];
    if (q is! Map) return false;
    for (final u in q.values) {
      final it = itemAt(u);
      if (it != null && gear[it['t']]?.only == id) return true;
    }
    return false;
  }

  void _tlogLeft() {
    // 떠날 때 남긴 장식 (웹 4273)
    final c = <String, int>{};
    for (final v in deco.values) {
      c['$v'] = (c['$v'] ?? 0) + 1;
    }
    final ds = [for (final q in decoSets().keys) web.dsets[q]?['n'] ?? q];
    final parts = [for (final e in c.entries) '${(web.deco[e.key]?['n']) ?? e.key} ${e.value}'];
    if (parts.isNotEmpty) tlog('떠날 때 남긴 장식: ${parts.join(', ')}${ds.isNotEmpty ? ' · ${ds.join('·')}이(가) 있던 동네' : ''}');
    final e = tlogEntry(S.gen);
    e['left'] = <String, Object?>{'day': num_('day'), 'tower': towerN, 'lv': S.lv, 'sets': [for (final q in decoSets().keys) web.dsets[q]?['n'] ?? q]};
  }

  /// 떠나기. pick = 함께 갈 사람 (최대 다섯, 다섯 이하면 모두)
  void migrate(List<int> pick) {
    final old = S, g = old.gen + 1, region = nextRegion;
    _tlogLeft();
    // 진행 중인 교대는 취소하고 건전지를 돌려준다
    if (old.rest['swap'] != null) {
      old.m['batt'] = (old.m['batt'] ?? 0) + swapCost['batt']!;
      old.rest['swap'] = null;
    }
    final all = [for (final k in old.sv.keys) int.parse(k)];
    final going = all.length > migMax ? pick.where((id) => old.sv.containsKey('$id')).take(migMax).toList() : all;
    final stayed = <String, Object?>{};
    for (final id in all) {
      if (going.contains(id)) continue;
      final r = Map<String, Object?>.from(old.sv['$id'] as Map);
      r['at'] = -1;
      r['away'] = false;
      r['hurt'] = 0;
      stayed['$id'] = r;
    }
    final stay = Map<String, Object?>.from(old.rest['stay'] as Map? ?? const {});
    if (stayed.isNotEmpty) stay['${old.gen}'] = <String, Object?>{'region': old.region ?? 'home', 'n': old.gen, 'sv': stayed};
    final svGo = <String, Object?>{for (final id in going) '$id': old.sv['$id']};
    const keepKeys = [
      'pf', 'playT', 'pfAsk', 'qc', 'inv', 'iu', 'relics', 'ach', 'title', 'kids', 'dog', 'endSeen', 'conf', 'hook', 'tlog', 'rumor', 'sqN', 'cases', 'odd', 'dead', 'egg', 'crow',
      'pets', 'petOn', 'stat', 'gTotal', 'gp', 'heard', 'mi', 'storyI', 'favDone', 'defWins', 'defs', 'nights', 'evDone', 'skillUses', 'expDone', 'gUses', 'art', 'artNew', 'ehEnd', 'feat',
      'expTold', 'pedCrow', 'tutSeen', 'onb', 'stepV', 'line', 'lnGot', 'deathG', 'memo', 'feasts',
    ];
    final ns = Game.fresh(random: rnd);
    for (final k in keepKeys) {
      if (old.rest.containsKey(k)) ns.rest[k] = old.rest[k];
    }
    ns.rest['ug'] = old.rest['ug'] ?? <String, Object?>{'best': 0, 'runs': 0, 'bestWith': <String, Object?>{}};
    final party = old.rest['party'];
    ns.rest['party'] = [for (final id in (party is List ? party : const [])) if (svGo.containsKey('$id')) id];
    ns.rest['stay'] = stay;
    final tr = old.rest['trade'];
    if (tr is Map) ns.rest['trade'] = <String, Object?>{'day': -1, 'offers': [], 'used': 0, 'pend': tr['pend'] ?? []};
    final pd = old.rest['ped'];
    if (pd is Map) ns.rest['ped'] = <String, Object?>{'next': 0, 'here': null, 'stock': [], 'visits': pd['visits'], 'bought': pd['bought']};
    // 연구(두드리는 힘·튀김·드론)는 손이 기억한다 — 새 동네에서 처음부터 다시 올리지 않는다 (앱 시즌 1 다듬기)
    ns.tapLv = old.tapLv;
    ns.splashLv = old.splashLv;
    ns.droneLv = old.droneLv;
    ns.found
      ..clear()
      ..addAll(old.found);
    ns.fevers = old.fevers;
    ns.sv
      ..clear()
      ..addAll(svGo);
    for (final r in ns.sv.values) {
      (r as Map)['at'] = -1;
      r['away'] = false;
      r['hurt'] = 0;
    }
    ns.gen = g;
    ns.region = region;
    ns.rest['rmi'] = 0;
    ns.rest['rsI'] = 0;
    ns.rest['arriveWins'] = old.rest['defWins'] ?? 0;
    ns.rest['carry'] = ns.sv.length;
    final cap0 = web.cap[0];
    final carryM = <String, num>{'batt': old.m['batt'] ?? 0};
    for (final k in const ['plate', 'rope', 'wire', 'med']) {
      carryM[k] = math.min(((old.m[k] ?? 0) / 2).floor(), matOf[k]!.tier == 2 ? (cap0 / 4).ceil() : cap0);
    }
    ns.m.addAll({'wood': 90, 'scrap': 60, 'food': 80, 'cloth': 30, ...carryM});
    if (region == 'desert') {
      for (var i = 0; i < N; i++) {
        if (ns.ter[i] == T.water) ns.ter[i] = rnd.nextDouble() < .3 ? T.ruin : T.ash;
      }
    }
    Game.placeSignals(ns);
    replaceState(ns);
    sfx('level');
    S.rest['wx'] = rollRegionWx() ?? 'normal';
    fx.add(FxMigrated(g, region));
    final wl = wayLine(g);
    talk([if (wl.isNotEmpty) Line('me', wl), ...(regIntro(0) ?? _lines((web.regionText['talk'] as Map)[region]))],
        card: ('$g번째 동네', regions[region]!.n), goal: regionMis()[0].goal);
    S.rest['rsI'] = 0;
    fx.add(const FxToastLater(5200, '연구와 지어 본 설계는 그대로 기억해요 · 모듈 첫 짓기 비용 절반'));
    if (g == 1) {
      final here = hasSv(0), left = !here && inStay(0) && !isDead(0);
      fx.add(FxNote(here ? '만수가 노선도를 그려 줬어요' : left ? '만수가 떠나기 전에 노선도를 그려 줬어요' : '지나온 길을 노선도로 그리기 시작했어요',
          '${here ? '“이 길, 내가 알아. 시운전하던 밤에 달린 길이거든.” · ' : left ? '“이 길, 내가 알아. 시운전하던 밤에 달린 길이거든. 가져가.” · ' : ''}일지 ‘노선도’에서 지나온 동네와 남은 사람들을 봐요',
          ms: 6500));
    }
    _changed();
  }

  // ================= 동네 기록 (웹 tlog 5323) =================
  List get tlogList {
    if (S.rest['tlog'] is! List) S.rest['tlog'] = <Object?>[];
    return S.rest['tlog'] as List;
  }

  Map tlogEntry([int? g0]) {
    final g = g0 ?? S.gen;
    for (final e in tlogList) {
      if (e is Map && e['g'] == g) return e;
    }
    final e = <String, Object?>{'g': g, 'r': g == S.gen ? (S.region ?? 'home') : regionOfGen(g), 't': <Object?>[]};
    tlogList.add(e);
    return e;
  }

  void tlog(String t) {
    final e = tlogEntry();
    final L = e['t'] as List;
    if (!L.contains(t)) L.add(t);
    dirty = true;
  }

  // ================= 동네 사건·사건 진행 (웹 tickTownEvents 5363) =================
  void _tickTownEvents() {
    if (S.gen == 0 || S.region == null) return;
    final Q = rq;
    if (!tlogList.any((e) => e is Map && e['g'] == S.gen)) tlog('불씨를 들고 도착했다.');
    if (towerN >= 5 && Q['towerLog'] == null) {
      Q['towerLog'] = 1;
      tlog('이 동네 등불 탑에 불을 켰다.');
    }
    _tickRegionSpot();
    _tickFire();
    final k = curRegK;
    if (k == null) return;
    final spotLog = (web.regionMisc['spotLog'] as Map)[S.region] as String? ?? '';
    switch (k) {
      case 'spot':
        if (Q['spotI'] == null) {
          final v = _pickSpot();
          if (v >= 0) {
            Q['spotI'] = v;
            _mapChanged();
          }
        }
        final si = (Q['spotI'] as num?)?.toInt() ?? -1;
        if (si >= 0 && S.rev[si] == 1 && Q['spot'] == null) {
          Q['spot'] = 1;
          tlog(spotLog);
          sfx('chime');
          fx.add(FxNote('찾았어요!', '$spotLog 미션 띠에서 보상을 받아요'));
          _mapChanged();
        }
      case 'raid':
        if (Q['raidBase'] == null) {
          Q['raidBase'] = num_('defWins');
          S.rest['raid'] = '물 도둑';
          fx.add(const FxNote('오늘 밤 물 도둑이 쳐들어와요', '방벽과 랜턴탑을 점검해요'));
        } else if (num_('defWins') > (Q['raidBase'] as num) && Q['raidLog'] == null) {
          Q['raidLog'] = 1;
          tlog('물 도둑을 막아 냈다.');
        } else if (S.rest['raid'] == null && num_('defWins') == Q['raidBase'] && defn == null && !isNight) {
          S.rest['raid'] = '물 도둑';
        }
      case 'op':
        if (Q['opEnd'] != null && Q['op'] == null && Game.nowMs() >= (Q['opEnd'] as num)) {
          Q['op'] = 1;
          tlog('공장을 멈췄다. 공단이 처음으로 조용해졌다.');
          sfx('chime');
          fx.add(const FxNote('공장 끄기 작전 성공!', '미션 띠에서 보상을 받아요'));
        }
      case 'cold':
        if (Q['coldBase'] == null) {
          Q['coldBase'] = num_('nights');
          fx.add(const FxNote('한파가 시작됐어요', '사흘 밤 동안 장작(목재)이 빨리 줄어요', ms: 5000));
        }
        if (Q['cold'] == null) {
          coldAcc += .6 * lvScale;
          final w = coldAcc.floor();
          if (w > 0) {
            coldAcc -= w;
            S.m['wood'] = math.max(0, have('wood') - w);
          }
          if (have('wood') <= 0 && Q['coldBad'] == null) {
            Q['coldBad'] = 1;
            fx.add(const FxNote('장작이 떨어졌어요!', '아이들이 떨고 있어요. 목재를 모아 난로를 지켜요'));
          }
          if (num_('nights') >= (Q['coldBase'] as num) + 3) {
            Q['cold'] = 1;
            final n = Q['coldBad'] != null ? 1 : 2;
            for (var q = 0; q < n; q++) {
              if (kids.length < 8) addKid();
            }
            recalc();
            tlog('한파 사흘을 버텼다. 분교 아이 $n명이 쉘터 식구가 됐다.');
            sfx('chime');
            fx.add(FxNote('한파를 버텼어요!', '분교 아이 $n명이 쉘터에 합류했어요'));
          }
        }
      case 'choice':
        if (Q['pick'] == null && townChoiceShown != S.gen && !uiBusy && num_('rsI') == rmi) {
          townChoiceShown = S.gen;
          fx.add(const FxTownChoice());
        }
    }
  }

  /// 숨겨진 자리: 어둠 속 6~9칸 (다 밝혔으면 더 멀리, 그래도 없으면 밝힌 칸) (웹 pickSpot2)
  int _pickSpot() {
    bool ok(int i) => !isSlot(i) && S.ter[i] != T.water && S.ter[i] != T.lm && !S.sig.containsKey(i);
    for (final (lo, hi, dark) in const [(6, 9, true), (6, 14, true), (3, 99, true), (4, 99, false)]) {
      final c = <int>[];
      for (var i = 0; i < N; i++) {
        if (!ok(i) || (dark && S.rev[i] == 1)) continue;
        final d = dist(i);
        if (d >= lo && d <= hi) c.add(i);
      }
      if (c.isNotEmpty) return c[rnd.nextInt(c.length)];
    }
    return -1;
  }

  // ================= 동네 선택 (웹 TOWN_CHOICE 5393) =================
  Map get townChoice => (web.regionText['choice'] as Map)[S.region] as Map? ?? const {};

  String choiceDesc(String x) {
    final o = townChoice[x] as Map;
    return '${o['d']}${o['k'] == 'fix' && hasSv(9) && !(o['d'] as String).contains('재혁') ? ' · 재혁 신뢰도가 크게 올라요' : ''}';
  }

  /// 고르기 → 이어지는 대사
  List<Line> pickTown(String x) {
    final o = townChoice[x] as Map?, Q = rq;
    if (o == null || Q['pick'] != null) return const [];
    final k = o['k'] as String;
    Q['pick'] = k;
    if (S.rest['rumor'] is! Map) S.rest['rumor'] = <String, Object?>{};
    (S.rest['rumor'] as Map)[S.region] = k;
    tlog(k == 'rescue' && !hasSv(16) ? '산 너머 대피소로 구조대를 보냈다.' : (web.regionMisc['pickLog'] as Map)[k] as String);
    if (k == 'fix' && hasSv(9)) rec(9)!['xp'] = xpOf(9) + 150;
    if (k == 'rescue') {
      final ids = [for (final id in svIds) if (!busy(id)) id];
      if (ids.isNotEmpty && rnd.nextDouble() < .6) {
        final id = ids[rnd.nextInt(ids.length)];
        rec(id)!['hurt'] = 300;
        tlog('${jo(survivors[id].name, '이', '가')} 눈길에서 다쳤지만 무사히 돌아왔다.');
      }
      give(scaleCost({'med': 4, 'fuel': 40}, lvScale));
      if (hasSv(16)) rec(16)!['xp'] = xpOf(16) + 200;
      if (rnd.nextDouble() < .5) findRelic();
    }
    if (k == 'stay' && kids.length < 8) addKid();
    recalc();
    _changed();
    return talkLines(_lines(o['r']));
  }

  void _townEff(Map<String, double> e) {
    final p = S.gen != 0 ? rq['pick'] : null;
    if (p == null) return;
    if (p == 'share') {
      e['hope'] = (e['hope'] ?? 0) + 10;
      e['food'] = (e['food'] ?? 0) + .2;
    } else if (p == 'keep') {
      e['hope'] = (e['hope'] ?? 0) + 3;
    } else if (p == 'smash' || p == 'stay') {
      e['hope'] = (e['hope'] ?? 0) + 5;
    }
  }

  // ================= 공장 끄기 작전 (웹 openOp 5385) =================
  Cost get opCost => scaleCost({'plate': 40, 'parts': 40, 'fuel': 30}, lvScale);
  bool get opFast => hasSv(15) || hasSv(9);
  bool startOp() {
    final Q = rq;
    if (Q['opEnd'] != null || !pay(opCost)) return false;
    Q['opDur'] = (opFast ? 50 : 100) * 1000;
    Q['opEnd'] = Game.nowMs() + (Q['opDur'] as int);
    _changed();
    return true;
  }

  // ================= 동네마다 숨은 사람 (웹 tickRegionHidden 5288) =================
  void _tickRegionHidden() {
    if (S.gen == 0 || S.region == null || rmi < 2) return;
    final s = survivors.where((x) => x.src == 'region' && x.region == S.region).firstOrNull;
    if (s == null || hasSv(s.id) || isDead(s.id) || inStay(s.id) || num_('rhs') == S.gen) return;
    if (S.sig.values.contains(s.id) || S.camp.values.any((c) => c['id'] == s.id)) return;
    final c = <int>[];
    for (var i = 0; i < N; i++) {
      if (S.rev[i] == 1 || isSlot(i) || S.ter[i] == T.water || S.ter[i] == T.diary || S.ter[i] == T.silo || S.ter[i] == T.lm || S.sig.containsKey(i)) continue;
      final d = dist(i);
      if (d >= 8 && d <= 12) c.add(i);
    }
    if (c.isEmpty) return;
    S.sig[c[rnd.nextInt(c.length)]] = s.id;
    S.rest['rhs'] = S.gen;
    _mapChanged();
    fx.add(FxNote(
        const {'desert': '모래바람 너머로 이상한 불빛이 깜빡여요', 'factory': '공장 굴뚝 사이에서 용접 불꽃 같은 빛이 튀어요', 'snow': '눈보라 속에서 구조 신호탄이 올라갔어요'}[S.region] ?? '어딘가에서 구조 신호가 보여요',
        '지도에 새 구조 신호가 생겼어요. 이 동네에만 있는 사람일지도 몰라요',
        ms: 6000));
  }

  // ================= 남은 사람들: 무전 거래·교대 (웹 3159–3248) =================
  List<(int, int, String, Map)> get stayList {
    final o = <(int, int, String, Map)>[];
    final st = S.rest['stay'];
    if (st is! Map) return o;
    for (final e in st.entries) {
      final t = e.value as Map, g = int.parse('${e.key}');
      final town = regions[t['region']]?.n ?? '첫 동네';
      for (final s in (t['sv'] as Map).entries) {
        final id = int.parse('${s.key}');
        if (id < survivors.length) o.add((id, g, town, s.value as Map));
      }
    }
    return o;
  }

  Map get trade {
    if (S.rest['trade'] is! Map) S.rest['trade'] = <String, Object?>{'day': -1, 'offers': <Object?>[], 'used': 0, 'pend': <Object?>[]};
    return S.rest['trade'] as Map;
  }

  /// 오늘의 거래 제안 (웹 trState)
  Map trState() {
    final T = trade, L = stayList;
    if (L.isEmpty) {
      T['offers'] = <Object?>[];
      return T;
    }
    if (T['day'] != num_('day')) {
      T['day'] = num_('day');
      T['used'] = 0;
      final pick = [...L]..shuffle(rnd);
      T['offers'] = [for (final x in pick.take(trMax)) _trMake(x.$1, x.$2)];
    }
    final st = S.rest['stay'] as Map? ?? const {};
    T['offers'] = [
      for (final o in T['offers'] as List)
        if (((st['${(o as Map)['gen']}'] as Map?)?['sv'] as Map?)?.containsKey('${o['id']}') == true) o
    ];
    return T;
  }

  Map<String, Object?> _trMake(int id, int gen) {
    final val = web.regionMisc['trVal'] as Map, regs = web.regionMisc['trReg'] as Map, roleT = web.regionMisc['trRole'] as Map;
    final reg0 = ((S.rest['stay'] as Map)['$gen'] as Map)['region'] ?? 'home';
    final pool = [for (final x in (regs[reg0] ?? regs['home']) as List) x as String];
    for (final r in roleOf(id)) {
      if (roleT[r] != null) pool.addAll([roleT[r] as String, roleT[r] as String]);
    }
    final gk = pool[rnd.nextInt(pool.length)];
    double v(String k) => (val[k] as num).toDouble();
    final cand = [for (final k in val.keys) k as String].where((k) => k != gk && have(k) >= 4).toList()
      ..sort((a, b) => (have(b) / capOf(b) * v(b)).compareTo(have(a) / capOf(a) * v(a)));
    final c3 = cand.take(3).toList();
    final wk = c3.isNotEmpty ? c3[rnd.nextInt(c3.length)] : (gk == 'food' ? 'wood' : 'food');
    final urgent = rnd.nextDouble() < 1 / 6;
    var f = urgent ? 1.5 : 1.15 * (.75 + rnd.nextDouble() * .5);
    var base = (36 + 10 * S.gen) * (.8 + rnd.nextDouble() * .4);
    final w = wxK;
    if (w == 'cold' && gk == 'wood') {
      base *= .7;
      f *= .85;
    }
    if (w == 'clear' && gk == 'fuel') f *= 1.15;
    if (w == 'acid' && gk == 'food') {
      base *= .7;
      f *= .9;
    }
    final gn = math.max(2, jsRound(base / v(gk))), wn = math.max(1, jsRound(gn * v(gk) / f / v(wk)));
    final nm = survivors[id].name, G = matOf[gk]!.n, W0 = matOf[wk]!.n;
    String nj(int n, String a, String b) => '$n${'013678'.contains('$n'.substring('$n'.length - 1)) ? a : b}';
    String nro(int n) => '$n${'036'.contains('$n'.substring('$n'.length - 1)) ? '으로' : '로'}';
    final txt = urgent
        ? '${jo(W0, '이', '가')} 급해요. $G ${nro(gn)} 갚을게요.'
        : ['$G $gn 보낼게요. $W0 $wn 주실 수 있어요?', '여긴 ${jo(G, '이', '가')} 남아요. $W0 ${nj(wn, '이랑', '랑')} 바꿔요.', '$G $gn, 길 건너 보낼게요. $W0 $wn만 챙겨 줘요.'][rnd.nextInt(3)];
    return {'id': id, 'gen': gen, 'give': {gk: gn}, 'want': {wk: wn}, 'f': f, 'urgent': urgent, 'txt': '$nm: “$txt”'};
  }

  /// 거래 보내기. 실패하면 이유 글
  String? trAccept(int i) {
    final T = trState(), offers = T['offers'] as List;
    if (i >= offers.length) return '';
    if (((T['used'] as num?) ?? 0) >= trMax) return '오늘은 $trMax건까지만 무전이 닿아요';
    final o = offers[i] as Map, gk = (o['give'] as Map).keys.first as String;
    if (have(gk) >= capOf(gk)) return '${matOf[gk]!.n} 창고가 꽉 찼어요';
    if (!pay({for (final e in (o['want'] as Map).entries) e.key as String: e.value as num})) return '자재가 모자라요';
    T['used'] = ((T['used'] as num?) ?? 0) + 1;
    sfx('chime');
    offers.removeAt(i);
    (T['pend'] as List).add(<String, Object?>{'id': o['id'], 'gen': o['gen'], 'give': o['give'], 'day': num_('day')});
    final r = (((S.rest['stay'] as Map)['${o['gen']}'] as Map?)?['sv'] as Map?)?['${o['id']}'];
    if (r is Map) r['xp'] = ((r['xp'] as num?) ?? 0) + trTrust;
    _stat['trades'] = ((_stat['trades'] as num?) ?? 0) + 1;
    fx.add(FxToast('${survivors[(o['id'] as num).toInt()].name}에게 보냈어요 · 새벽에 도착해요'));
    _changed();
    return null;
  }

  void _trArrive() {
    final T = S.rest['trade'];
    if (T is! Map || (T['pend'] as List?)?.isNotEmpty != true) return;
    final got = <String>[];
    for (final p in List.of(T['pend'] as List)) {
      final gv = {for (final e in ((p as Map)['give'] as Map).entries) e.key as String: e.value as num};
      give(gv);
      got.add('${survivors[(p['id'] as num).toInt()].name}의 ${gv.entries.map((e) => '${matOf[e.key]!.n} ${e.value}').join(', ')}');
    }
    (T['pend'] as List).clear();
    fx.add(FxNote('무전 거래 물건이 도착했어요', got.join(' · '), ms: 5200));
  }

  Map? get swap => S.rest['swap'] as Map?;

  bool swapStart(int inId, int outId) {
    final L = stayList.where((x) => x.$1 == inId).firstOrNull;
    if (L == null || !hasSv(outId) || busy(outId) || swap != null || !pay(swapCost)) return false;
    S.rest['swap'] = <String, Object?>{'inId': inId, 'outId': outId, 'gen': L.$2, 'day': num_('day')};
    sfx('chime');
    fx.add(FxToast('${survivors[inId].name}에게 무전을 보냈어요 · 새벽에 도착해요'));
    _changed();
    return true;
  }

  void swapCancel() {
    if (swap == null) return;
    give(swapCost);
    S.rest['swap'] = null;
    _changed();
  }

  void _swapArrive() {
    final w = swap;
    if (w == null) return;
    final inId = (w['inId'] as num).toInt(), outId = (w['outId'] as num).toInt();
    final t = (S.rest['stay'] as Map?)?['${w['gen']}'] as Map?;
    if (t == null || (t['sv'] as Map)['$inId'] == null || !hasSv(outId)) {
      S.rest['swap'] = null;
      give(swapCost);
      return;
    }
    if (busy(outId)) {
      fx.add(FxNote('${jo(survivors[inId].name, '이', '가')} 기다려요', '${jo(survivors[outId].name, '이', '가')} 돌아오면 교대해요', ms: 4200));
      return;
    }
    S.rest['swap'] = null;
    final out = Map<String, Object?>.from(rec(outId)!);
    final at = (out['at'] as num?)?.toInt() ?? -1;
    if (at >= 0) S.asg.remove(at);
    out['at'] = -1;
    out['away'] = false;
    out['hurt'] = 0;
    (t['sv'] as Map)['$outId'] = out;
    S.sv.remove('$outId');
    (S.rest['cd'] as Map?)?.remove('$outId');
    party = party.where((x) => x != outId).toList();
    final inr = Map<String, Object?>.from((t['sv'] as Map)['$inId'] as Map);
    sfx('join');
    (t['sv'] as Map).remove('$inId');
    inr['at'] = -1;
    inr['away'] = false;
    inr['hurt'] = 0;
    S.sv['$inId'] = inr;
    if ((t['sv'] as Map).isEmpty) (S.rest['stay'] as Map).remove('${w['gen']}');
    recalc();
    fx.add(FxNote('${jo(survivors[inId].name, '이', '가')} 도착했어요', '${jo(survivors[outId].name, '은', '는')} ${regions[t['region']]?.n ?? '첫 동네'}의 등불을 지키러 갔어요', ms: 5200));
  }

  void _regionDawn() {
    if (swap != null) _swapArrive();
    _trArrive();
    trState();
  }

  // ================= 잃은 사람들 (웹 6015) =================
  List<int> get _safeIds => [0, 3, 9, 10, 13, jinId, if (egg['c'] == null) 12];

  int? _deathPick() {
    final safe = _safeIds;
    final ids = [for (final id in svIds) if (!safe.contains(id) && !Game._truthy(rec(id)!['away'])) id];
    if (S.sv.length < (S.gen != 0 ? 7 : 8) || ids.isEmpty) return null;
    double w(int id) => (((rec(id)!['hurt'] as num?) ?? 0) > 0 ? 2 : 1) * (atOf(id) >= 0 ? 1.5 : 1);
    var tot = 0.0;
    for (final id in ids) {
      tot += w(id);
    }
    var r = rnd.nextDouble() * tot;
    for (final id in ids) {
      r -= w(id);
      if (r <= 0) return id;
    }
    return ids.first;
  }

  int? _deathFriend(int id) {
    final here = [for (final j in svIds) if (j != id && !isDead(j)) j];
    const pairs = web.pairs;
    int? f = here.where((j) => pairs['${math.min(id, j)}-${math.max(id, j)}'] != null || pairs['$id-$j'] != null || pairs['$j-$id'] != null).firstOrNull;
    if (f == null) {
      final b = bonds.where((b) => b.ids.contains(id)).firstOrNull;
      if (b != null) f = b.ids.where((j) => j != id && here.contains(j)).firstOrNull;
    }
    if (f == null && here.isNotEmpty) f = ([...here]..sort((a, b) => xpOf(b).compareTo(xpOf(a)))).first;
    return f;
  }

  void _killSurv(int id) {
    final r = rec(id);
    if (r == null) return;
    final at = (r['at'] as num?)?.toInt() ?? -1;
    if (at >= 0) S.asg.remove(at);
    S.sv.remove('$id');
    party = party.where((x) => x != id).toList();
    (S.rest['cd'] as Map?)?.remove('$id');
    if (S.rest['dead'] is! List) S.rest['dead'] = <Object?>[];
    (S.rest['dead'] as List).add(<String, Object?>{'id': id, 'g': S.gen, 'town': reg?.n ?? '', 'at': Game.nowMs()});
    recalc();
  }

  /// 새 동네의 큰 밤이 끝난 뒤 (웹 endDefense 덮어쓰기 6118)
  void deathAfterDefense(bool win, Defense D2) {
    if (S.gen == 0 || rmi < 1 || (S.rest['deathG'] as Map?)?['${S.gen}'] != null) return;
    if (S.rest['deathTry'] is! Map) S.rest['deathTry'] = <String, Object?>{};
    final dt = S.rest['deathTry'] as Map;
    final n = (((dt['${S.gen}'] as num?) ?? 0) + 1).toInt();
    dt['${S.gen}'] = n;
    final p = !win ? .8 : (n <= 3 ? const [.3, .5, .75][n - 1] : 1.0) * (n < 4 && D2.hp >= 80 ? .5 : 1);
    if (rnd.nextDouble() >= p) return;
    final id = _deathPick();
    if (id == null) return;
    if (S.rest['deathG'] is! Map) S.rest['deathG'] = <String, Object?>{};
    (S.rest['deathG'] as Map)['${S.gen}'] = 1;
    final at = atOf(id), where = at >= 0 ? workName(at) : '방벽', tile = at >= 0 ? at : C0, friend = _deathFriend(id);
    _killSurv(id);
    if (S.rest['memo'] is! Map) S.rest['memo'] = <String, Object?>{};
    (S.rest['memo'] as Map)['${S.gen}'] = <String, Object?>{'i': tile, 'id': id};
    tlog('${jo(survivors[id].name, '을', '를')} 잃었다.');
    fx.add(FxDeath(id, D2.raid, where, tile, friend));
    _mapChanged();
  }

  /// 잃은 사람 장면 뒤의 대사
  List<Line> deathLines(FxDeath d) {
    final nm = survivors[d.id].name;
    final fr = d.friend != null && hasSv(d.friend!) ? survivors[d.friend!].name : null;
    return [
      d.raid != null ? Line('me', '${jo(d.raid!, '이', '가')} 물러간 새벽, ${jo(nm, '이', '가')} 쓰러져 있었다.') : Line('me', '폭풍이 걷힌 새벽, ${jo(nm, '이', '가')} 보이지 않았다.'),
      d.raid != null ? const Line('g', '아이들 숨겨 둔 창고 문을 혼자 막고 있었대. 끝까지 비키지 않았다고.') : Line('g', '…${d.where} 옆에서 찾았어. 끝까지 불을 지키고 있었더라고.'),
      if (fr != null) Line('me', '${jo(fr, '은', '는')} 한참 동안 $nm의 자리를 떠나지 못했다.'),
      Line('me', '우리는 $nm의 이름을 쉘터 문설주에 새겼다. ${d.tile != C0 ? '그리고 ${d.where} 옆에 작은 초를 하나 켜 두었다.' : '그리고 다시 불을 켰다.'}'),
    ];
  }

  String lastLine(int id) => ((web.regionMisc['last'] as Map)['$id'] as String?) ?? '그가 앉던 자리는 한동안 비워 두었다.';

  /// 위험한 첫 밤을 미리 알린다 (웹 tickDeathWarn)
  void _tickDeathWarn() {
    if (S.gen == 0 || (S.rest['deathG'] as Map?)?['${S.gen}'] != null || num_('deathWarn') == S.gen || rmi < 1) return;
    final warn = !isNight && defn == null && (bigNightNext || S.rest['raid'] != null) && revCount >= 16 && phase > dayLen - 12;
    if (!warn) return;
    S.rest['deathWarn'] = S.gen;
    fx.add(const FxNote('오늘 밤, 모두 돌아올 수 있을까요', '이 동네에서는 누군가를 잃을 수도 있어요. 방벽과 랜턴탑이 튼튼하고, 다친 사람이 쉬고 있을수록 안전해요', ms: 7000));
  }

  // ================= 신기루·멈추지 않은 기계 (웹 tickRegionSpot 6071) =================
  Map? get rspot => S.rest['rspot'] as Map?;

  int _rspotTile(String k) {
    final c = <int>[];
    for (var i = 0; i < N; i++) {
      if (S.rev[i] != 1 || i == C0 || isSlot(i) || S.ter[i] == T.water || S.ter[i] == T.lm || siteLive(i) || S.camp.containsKey(i) || modAtTile(i) != null) continue;
      final d = dist(i);
      if (d < 2.5 || d > 9) continue;
      if (k == 'machine' && S.ter[i] != T.ruin && rnd.nextDouble() < .6) continue;
      c.add(i);
    }
    return c.isEmpty ? -1 : c[rnd.nextInt(c.length)];
  }

  void _tickRegionSpot() {
    final r = S.region;
    if (S.gen == 0 || (r != 'desert' && r != 'factory') || defn != null || ug != null || tut != null) return;
    final now = Game.nowMs(), sp = rspot;
    if (sp != null && now > (sp['end'] as num)) {
      if (sp['k'] == 'machine' && ((sp['n'] as num?) ?? 0) > 0) fx.add(const FxToast('기계가 다시 쿵쿵 돌기 시작했어요'));
      S.rest['rspot'] = null;
      S.rest['rspotT'] = 60 + rnd.nextDouble() * 60;
      return;
    }
    if (sp != null) return;
    S.rest['rspotT'] = ((S.rest['rspotT'] as num?) ?? 25) - 1;
    if (num_('rspotT') > 0) return;
    final k = r == 'desert' ? 'mirage' : 'machine';
    if (k == 'mirage' && isNight) {
      S.rest['rspotT'] = 20;
      return;
    }
    final i = _rspotTile(k);
    if (i < 0) {
      S.rest['rspotT'] = 30;
      return;
    }
    S.rest['rspot'] = <String, Object?>{'k': k, 'i': i, 'start': now, 'end': now + (k == 'mirage' ? 26000 : 40000), 'n': 0, 't0': 0, 'need': 8};
    if (S.rest['rs'] is! Map) S.rest['rs'] = <String, Object?>{};
    final rs = S.rest['rs'] as Map;
    if (rs['${k}Told'] == null) {
      rs['${k}Told'] = 1;
      fx.add(k == 'mirage'
          ? const FxNote('모래 위로 무언가 아른거려요', '빛나는 자리를 눌러 봐요. 진짜일 수도, 신기루일 수도 있어요', ms: 6000)
          : const FxNote('멈춘 줄 알았던 기계가 쿵쿵 돌아요', '불꽃 튀는 자리를 7초 안에 8번 두드려 꺼요. 부품이 쏟아져요', ms: 6000));
    } else {
      sfx(k == 'mirage' ? 'reveal' : 'hit');
    }
  }

  /// 지도에서 그 자리를 눌렀을 때 (웹 rspotHit). 처리했으면 true
  bool rspotHit(int i) {
    final sp = rspot;
    if (sp == null || (sp['i'] as num).toInt() != i || S.rev[i] != 1) return false;
    if (S.rest['rs'] is! Map) S.rest['rs'] = <String, Object?>{};
    final rs = S.rest['rs'] as Map, sc = lvScale;
    if (sp['k'] == 'mirage') {
      S.rest['rspot'] = null;
      S.rest['rspotT'] = 70 + rnd.nextDouble() * 60;
      final real = rs['mirFirst'] == null || rnd.nextDouble() < .62;
      if (real) {
        rs['mirFirst'] = 1;
        rs['mir'] = ((rs['mir'] as num?) ?? 0) + 1;
        final got = give(scaleCost({'fuel': 10, 'food': 14}, sc));
        sfx('get');
        fx.add(FxBurst(i, 0xFFFFE7A8, 14));
        fx.add(FxToast('모래 속에 묻힌 물통과 연료 통! · ${lootText(got)}'));
        if (rs['mir'] == 1) tlog('신기루 속에서 진짜 물통을 찾았다.');
      } else {
        sfx('reveal');
        fx.add(const FxToast('가까이 가 보니… 신기루였어요'));
      }
      _changed();
      return true;
    }
    final now = Game.nowMs();
    if (((sp['t0'] as num?) ?? 0) == 0 || now - (sp['t0'] as num) > 7000) {
      if (((sp['t0'] as num?) ?? 0) != 0 && ((sp['n'] as num?) ?? 0) < 8) fx.add(const FxToast('놓쳤어요! 다시 처음부터 두드려요'));
      sp['t0'] = now;
      sp['n'] = 0;
    }
    sp['n'] = ((sp['n'] as num?) ?? 0) + 1;
    sfx('hit', buzz: true);
    fx.add(FxBurst(i, 0xFFFFB35A, 5));
    if ((sp['n'] as num) >= 8) {
      S.rest['rspot'] = null;
      S.rest['rspotT'] = 80 + rnd.nextDouble() * 60;
      rs['mach'] = ((rs['mach'] as num?) ?? 0) + 1;
      final got = give(scaleCost({'parts': 8, 'plate': 3}, sc));
      sfx('chime');
      fx.add(FxToast('기계를 멈췄어요 · ${lootText(got)}'));
      if (rs['mach'] == 1) tlog('혼자 돌던 기계 하나를 손으로 멈췄다.');
    }
    _changed();
    return true;
  }

  // ================= 산골 모닥불 (웹 tickFire 6103) =================
  num? get warm => S.rest['warm'] as num?;
  int get warmTier => S.region != 'snow' || warm == null ? 1 : warm! >= 60 ? 2 : warm! > 0 ? 1 : 0;
  Cost get fireCost => scaleCost({'wood': 10}, lvScale);
  bool get fireOn => S.region == 'snow' && S.gen != 0;

  void _tickFire() {
    if (!fireOn) return;
    if (warm == null) {
      S.rest['warm'] = 70;
      fx.add(const FxNote('모닥불을 꺼뜨리지 마세요', '위 띠의 모닥불을 눌러 장작을 넣어요', ms: 5500));
    }
    final t0 = warmTier;
    if (ug == null) S.rest['warm'] = math.max(0, warm! - (isNight ? .32 : .13) * (wxK == 'cold' ? 2 : 1) * (defn != null ? 1.4 : 1));
    final t1 = warmTier;
    if (t0 != t1) {
      recalc();
      if (t1 == 0) fx.add(const FxNote('모닥불이 꺼졌어요', '추워서 모두 굼떠요 · 생산 ×0.8 · 장작을 넣어 다시 피워요', ms: 5000));
    }
  }

  void feedFire() {
    if (S.region != 'snow') return;
    final c = fireCost;
    if ((warm ?? 0) >= 98) {
      fx.add(const FxToast('불이 충분히 타고 있어요'));
      return;
    }
    if (!pay(c)) {
      fx.add(FxToast('목재가 모자라요 · 목재 ${c['wood']}'));
      return;
    }
    final t0 = warmTier;
    S.rest['warm'] = math.min(100, (warm ?? 0) + 30);
    sfx('get');
    fx.add(FxBurst(C0, 0xFFFFB35A, 12));
    if (warmTier != t0) recalc();
    fx.add(FxToast('장작을 넣었어요 · 온기 ${(warm!).round()}% · 목재 -${c['wood']}'));
    _changed();
  }

  /// 재계산 끝에 (웹 recalc 덮어쓰기: 모닥불 온기)
  void _regionAfterRecalc() {
    if (S.region != 'snow' || warm == null) return;
    final t = warmTier;
    if (t == 2) {
      hope += 4;
      tapAdd += .15;
    } else if (t == 0) {
      prod.updateAll((k, v) => v * .8);
    }
  }

  /// 매초 (웹 tickRegionStory · tickRegionHidden · tickTownEvents · tickDeathWarn)
  void tickRegionSec() {
    if (S.gen == 0) return;
    _tickRegionStory();
    _tickRegionHidden();
    _tickTownEvents();
    _tickDeathWarn();
  }
}
