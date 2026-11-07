// 웹에서 뽑은 표(web_data.g.dart)를 쓰기 편한 모양으로 감싼다.
import '../data/web_data.g.dart' as web;

const int W = web.W, H = web.H, N = W * H, CX = 20, CY = 20, C0 = CY * W + CX;
const double TW = 64, TH = 32;

/// 지형 종류 (웹의 T)
abstract final class T {
  static const ash = 0, water = 1, ruin = 2, silo = 3, diary = 4, spent = 5, car = 6, crate = 7, trace = 8, lm = 9;
}

class MatInfo {
  const MatInfo(this.k, this.n, this.color, this.tier, this.s2, this.src);
  final String k, n, s2, src;
  final int color, tier;
}

final List<MatInfo> mats = [
  for (final m in web.mats)
    MatInfo(m['k'] as String, m['n'] as String, int.parse((m['c'] as String).substring(1), radix: 16) | 0xFF000000, m['tier'] as int,
        m['s2'] as String, m['src'] as String),
];
final Map<String, MatInfo> matOf = {for (final m in mats) m.k: m};
const baseMats = ['scrap', 'wood', 'cloth', 'parts', 'fuel', 'food'];

/// 자원 그림 아틀라스(resources.webp, 12칸)에서의 순서
const resIcon = {'scrap': 0, 'wood': 1, 'cloth': 2, 'parts': 3, 'fuel': 4, 'food': 5, 'plate': 6, 'rope': 7, 'wire': 8, 'med': 9, 'batt': 10, 'hope': 11};

typedef Cost = Map<String, num>;

Cost _cost(Object? v) => {for (final e in (v as Map).entries) e.key as String: e.value as num};
List<(String, double)> _drops(Object? v) => v == null ? const [] : [for (final d in v as List) (d[0] as String, (d[1] as num).toDouble())];

class SiteInfo {
  const SiteInfo(this.n, this.drops, this.c, this.hp, this.regen);
  final String n;
  final List<(String, double)> drops;
  final int c, hp, regen;
}

final Map<String, SiteInfo> sites = {
  for (final e in web.sites.entries)
    e.key: SiteInfo(e.value['n'] as String, _drops(e.value['drops']), e.value['c'] as int, e.value['hp'] as int, e.value['regen'] as int),
};

class LmInfo {
  const LmInfo(this.key, this.d, this.drops, this.cost, this.desc);
  final String key, desc;
  final double d;
  final List<(String, double)> drops;
  final Cost cost;
}

final List<LmInfo> landmarks = [
  for (final l in web.landmarks) LmInfo(l['key'] as String, (l['d'] as num).toDouble(), _drops(l['drops']), _cost(l['cost']), l['desc'] as String),
];

/// 동네별 랜드마크 [이름, 폐허 모습, 복구 후 모습]
List<String> lmText(int k, String? region) {
  final t = (web.landmarkText[region ?? 'home'] ?? web.landmarkText['home'])!;
  return List<String>.from(t[k]);
}

String? traceItem(int id) => web.traceItem['$id'];

final List<String> shelterName = [for (final s in web.shelter) s['n'] as String];
final List<int> slotsByLv = List<int>.of(web.slots);
final List<int> capByLv = List<int>.of(web.cap);
final List<Cost> shupBase = [for (final s in web.shupBase) _cost(s['cost'])];
final List<int> shupNeed = [for (final s in web.shupBase) s['need'] as int];
final List<(int, int)> slotOff = [for (final o in web.slotOff) (o[0], o[1])];
int slotTile(int k) => (CY + slotOff[k].$2) * W + CX + slotOff[k].$1;

class ModInfo {
  const ModInfo(this.id, this.n, this.req, this.cost, this.fx);
  final int id, req;
  final String n;
  final List<Cost> cost;
  final List<String> fx;
}

final Map<int, ModInfo> mods = {
  for (final e in web.mods.entries)
    int.parse(e.key): ModInfo(int.parse(e.key), e.value['n'] as String, e.value['req'] as int, [for (final c in e.value['cost'] as List) _cost(c)],
        [for (final f in e.value['fx'] as List) f as String]),
};
final List<int> modOrder = List<int>.of(web.modOrder);
const repeatable = [2, 9, 4, 8];

final List<(String, Cost)> wallsInfo = [for (final w in web.walls) (w['n'] as String, _cost(w['cost']))];

class Recipe {
  const Recipe(this.out, this.n, this.lv, this.wb, this.nm, this.d, this.inp);
  final String out;
  final int n, lv, wb;
  final String? nm, d;
  final List<Cost> inp; // 작업대 1~3단계별 재료
}

final List<Recipe> recipes = [
  for (final r in web.recipes)
    Recipe(r['out'] as String, r['n'] as int, r['lv'] as int, r['wb'] as int, r['nm'] as String?, r['d'] as String?, [for (final c in r['inp'] as List) _cost(c)]),
];

final Map<int, List<String>> modSay = {for (final e in web.say.entries) int.parse(e.key): List<String>.from(e.value)};

final List<(String, String)> diaries = [for (final d in web.diary) (d[0], d[1])];

class SurvInfo {
  const SurvInfo({
    required this.id, required this.name, required this.age, required this.job, required this.src, required this.d, required this.region,
    required this.hidden, required this.alias, required this.hint, required this.hope, required this.need, required this.match,
    required this.eff, required this.grade, required this.story, required this.trait,
  });
  final int id, age, grade;
  final String name, job, src, trait;
  final double d, hope;
  final String? region, alias, hint;
  final bool hidden;
  final int? need;
  final List<int> match;
  final Map<String, double> eff;
  final List<String> story;
}

final List<SurvInfo> survivors = [
  for (final s in web.surv)
    SurvInfo(
      id: s['id'] as int,
      name: s['name'] as String,
      age: s['age'] as int,
      job: s['job'] as String,
      src: s['src'] as String,
      d: (s['d'] as num).toDouble(),
      region: s['region'] as String?,
      hidden: s['hidden'] as bool,
      alias: s['alias'] as String?,
      hint: s['hint'] as String?,
      hope: (s['hope'] as num).toDouble(),
      need: s['need'] as int?,
      match: [for (final m in s['match'] as List) m as int],
      eff: {for (final e in (s['eff'] as Map).entries) e.key as String: (e.value as num).toDouble()},
      grade: s['grade'] as int,
      story: [for (final t in s['story'] as List) t as String],
      trait: s['trait'] as String,
    ),
  // 시즌 2 · 얼어붙은 저수지 둑 사람들 (30~33). 초상은 residents-reservoir.webp 2×2
  ...s2Residents,
];

/// 시즌 2 저수지 사람 넷 (season2-script.md 0절). 동네 사람과 같은 규칙(구조 신호·잃는 규칙)
const List<SurvInfo> s2Residents = [
  SurvInfo(id: 30, name: '하경수', age: 52, job: '수문 관리인', src: 'town', d: 6.5, region: 'reservoir', hidden: false, alias: '수문지기', hint: '얼어붙은 저수지 둑에서 만나요',
      hope: 0, need: null, match: [0, 6], eff: {'craft': 0.15}, grade: 1,
      story: ['그날부터 수문을 하루도 빼지 않고 열고 닫았다. 물이 얼지 않게.', '깃발이 펄럭이는 쪽을 보면 물이 어느 쪽으로 밀리는지 안다.', '“수문은 열 때보다 닫을 때가 어려워요.”'], trait: '가공할 때 {craft:pc}% 확률로 하나 더'),
  SurvInfo(id: 31, name: '오순임', age: 64, job: '저수지 매점 주인', src: 'town', d: 7.5, region: 'reservoir', hidden: false, alias: null, hint: '얼어붙은 저수지 둑에서 만나요',
      hope: 0, need: null, match: [5, 4], eff: {'thrift': 0.12}, grade: 0,
      story: ['매점 셔터를 끝까지 올려 두었다. 누구든 들어와 라면 하나 끓여 먹으라고.', '벤치에 앉아 컵라면 하나 먹던 손님들 얼굴을 다 기억한다.', '“물 끓었다. 먹고 가.”'], trait: '식량 소비 -{thrift:pc}%'),
  SurvInfo(id: 32, name: '길태용', age: 40, job: '얼음낚시꾼', src: 'town', d: 8, region: 'reservoir', hidden: false, alias: null, hint: '얼어붙은 저수지 둑에서 만나요',
      hope: 0, need: null, match: [17], eff: {'food': 0.25}, grade: 0,
      story: ['얼음 구멍 하나로 둑 위 사람들을 먹여 왔다. 매일 아침 같은 자리.', '밤낚시 할 때 등불 하나면 됐다고 한다.', '“얼음은 거짓말 안 해요.”'], trait: '식량 생산 +{food:pc}%'),
  SurvInfo(id: 33, name: '서다은', age: 26, job: '수자원 연구 대학원생', src: 'town', d: 9, region: 'reservoir', hidden: false, alias: null, hint: '얼어붙은 저수지 둑에서 만나요',
      hope: 0, need: null, match: [9, 11], eff: {'hope': 6}, grade: 1,
      story: ['수위 기록을 날마다 적었다. 누가 읽을지 몰라도.', '풍경 소리로 바람 세기를 적는 법을 안다.', '“기록은 남겨 두면 언젠가 누가 읽어요.”'], trait: '쉘터 희망 +{hope:r}'),
];

/// 시즌 2 저수지 사람들의 역할 (web.role 뒤에 이어 붙임)
const Map<int, List<String>> s2Roles = {30: ['mech', 'guard'], 31: ['cook'], 32: ['farm', 'scout'], 33: ['sci']};

/// 구조에 필요한 것 (웹 RESCUE)
final Map<int, (Cost, String)> rescueNeed = {
  for (final e in web.rescue.entries) int.parse(e.key): (_cost(e.value['need']), e.value['why'] as String),
  // 시즌 2 저수지 사람들 (2026-11-07 실기기: 구조 신호 창이 비어 회색으로 뜨던 것)
  30: (const {'fuel': 6, 'food': 10}, '얼어붙은 수문 관리소에 갇혀 있어요. 문틈의 얼음을 녹일 연료와 식량이 필요해요.'),
  31: (const {'food': 14, 'cloth': 6}, '셔터를 올려 둔 매점 안에서 버티고 있어요. 함께 먹을 식량과 두를 천이 필요해요.'),
  32: (const {'rope': 4, 'food': 10}, '얼음 구멍 옆 천막에 고립돼 있어요. 끌어낼 밧줄과 식량이 필요해요.'),
  33: (const {'parts': 6, 'food': 8}, '수위 관측소 지붕에서 손전등을 깜빡여요. 내려올 사다리를 고칠 부품과 식량이 필요해요.'),
};

class Bond {
  const Bond(this.ids, this.name, this.txt, this.eff, this.d);
  final List<int> ids;
  final String name, txt, d;
  final Map<String, double> eff;
}

final List<Bond> bonds = [
  for (final b in web.bonds)
    Bond([for (final i in b['ids'] as List) i as int], b['name'] as String, b['txt'] as String,
        {for (final e in (b['eff'] as Map).entries) e.key as String: (e.value as num).toDouble()}, b['d'] as String),
];

final List<int> trustXp = List<int>.of(web.trust);
final List<int> bedsByLv = List<int>.of(web.beds);

class GradeInfo {
  const GradeInfo(this.n, this.m, this.cd, this.w, this.color);
  final String? n;
  final double m, cd, w;
  final int color;
}

final List<GradeInfo> grades = [
  for (final g in web.grades)
    GradeInfo(g['n'] as String?, (g['m'] as num).toDouble(), (g['cd'] as num).toDouble(), (g['w'] as num).toDouble(),
        g['c'] == null ? 0xFF8A8479 : int.parse((g['c'] as String).substring(1), radix: 16) | 0xFF000000),
];

final Map<String, (String, String, String, String)> duties = {
  for (final e in web.duty.entries) e.key: (e.value['n'] as String, e.value['v'] as String, e.value['ic'] as String, e.value['d'] as String),
};

class SkillInfo {
  const SkillInfo(this.n, this.cd, this.d, this.cat, this.res);
  final String n, d, cat;
  final double cd;

  /// 동네 사람(18~29)의 스킬 종류: k(buff 종류)·give·heal·clear·hope·name
  final Map<String, Object?>? res;
}

final List<SkillInfo> skills = [
  for (var i = 0; i < web.skills.length; i++)
    SkillInfo(web.skills[i]['n'] as String, (web.skills[i]['cd'] as num).toDouble(), web.skills[i]['d'] as String, web.skillCat[i],
        web.skills[i]['res'] == null ? null : Map<String, Object?>.from(web.skills[i]['res'] as Map)),
  // 시즌 2 저수지 사람들 (30~33): 동네 사람처럼 res로 효과를 정한다
  const SkillInfo('수문 열기', 100, '60초간 가공 ×1.3', 'craft', {'k': 'craft', 'give': null, 'heal': false, 'clear': 0, 'hope': false, 'name': '하경수'}),
  const SkillInfo('라면 한 솥', 110, '60초간 식량 생산 ×1.5', 'food', {'k': 'farm', 'give': null, 'heal': false, 'clear': 0, 'hope': false, 'name': '오순임'}),
  const SkillInfo('새벽 얼음낚시', 90, '45초간 폐허 뒤지기 수확 ×1.6', 'scav', {'k': 'scav', 'give': null, 'heal': false, 'clear': 0, 'hope': false, 'name': '길태용'}),
  const SkillInfo('수위 기록', 120, '희망이 잠시 오르고 60초간 모든 생산 +15%', 'all', {'k': 'all', 'give': null, 'heal': false, 'clear': 0, 'hope': true, 'name': '서다은'}),
];

class GearInfo {
  const GearInfo(this.key, this.n, this.slot, this.g, this.eff, this.fit, this.cost, this.wb, this.d, this.sig, this.line, this.ug);
  final String key, n, slot, d;
  final int g, wb;
  final Map<String, double> eff;
  final List<int> fit;
  final Cost? cost;
  final bool sig, line, ug;
  int? get only => sig && fit.length == 1 ? fit.first : null;
}

final Map<String, GearInfo> gear = {
  for (final e in web.gear.entries)
    e.key: GearInfo(
      e.key,
      e.value['n'] as String,
      e.value['slot'] as String,
      e.value['g'] as int,
      {for (final x in (e.value['eff'] as Map).entries) x.key as String: (x.value as num).toDouble()},
      [for (final f in e.value['fit'] as List) f as int],
      e.value['cost'] == null ? null : _cost(e.value['cost']),
      e.value['wb'] as int,
      e.value['d'] as String,
      e.value['sig'] as bool,
      e.value['line'] as bool,
      e.value['ug'] as bool,
    ),
  ...bondGearInfo,
};

/// 인연 3단계의 고유 장비 (앱 전용 2026-10-18, game/bond.dart). 그 사람만 쓸 수 있고(sig) 분해·자동 분해되지 않는다.
/// 이미 있는 전용 장비(운전 장갑·노란 우산·호미·국자·줄자·검은 깃털)와 다른 칸에 들어간다
const Map<String, GearInfo> bondGearInfo = {
  'bdHandle': GearInfo('bdHandle', '낡은 버스 핸들 커버', 'keep', 2, {'craft': 0.1, 'scav': 0.08}, [0], null, 0, '삼십 년 손자국이 밴 가죽. 쥐면 손이 길을 기억한다.', true, false, false),
  'bdRaincoat': GearInfo('bdRaincoat', '노란 실로 기운 비옷', 'wear', 2, {'hope': 4, 'fever': 1}, [3], null, 0, '구멍 난 자리를 할머니가 노란 실로 기워 줬다.', true, false, false),
  'bdHanky': GearInfo('bdHanky', '씨앗 싼 꽃무늬 손수건', 'keep', 2, {'food': 0.15, 'hope': 2}, [4], null, 0, '꽃무늬는 다 바랬지만 마른 흙냄새는 그대로다.', true, false, false),
  'bdApron': GearInfo('bdApron', '말순네 앞치마', 'wear', 2, {'thrift': 0.1, 'hope': 3}, [5], null, 0, '주머니에 ‘말순네’ 자수가 반쯤 풀린 채 남아 있다.', true, false, false),
  'bdHelmet': GearInfo('bdHelmet', '찌그러진 반장 안전모', 'wear', 2, {'cost': 0.06, 'tap': 0.12}, [6], null, 0, '무너질 때 머리 대신 맞아 준 안전모. 새 끈을 단단히 맸다.', true, false, false),
  'bdCloak': GearInfo('bdCloak', '천 덧댄 정찰 망토', 'wear', 2, {'scav': 0.12, 'fever': 1}, [17], null, 0, '검은 새 표식 위에 하늘이가 천을 덧대 삐뚤빼뚤 꿰맸다.', true, false, false),
};

/// 장비 그림 칸: [시트, 번호] (웹 design.js GCELL, LNI)
final Map<String, (String, int)> gearCell = {
  for (final e in web.gearCell.entries) e.key: (e.value[0] as String, e.value[1] as int),
  // 고유 장비는 비슷한 그림을 빌려 쓴다
  'bdHandle': ('keep', 10),
  'bdRaincoat': ('wear', 7),
  'bdHanky': ('keep', 3),
  'bdApron': ('wear', 9),
  'bdHelmet': ('wear', 8),
  'bdCloak': ('wear', 4),
};
const slotKeys = ['tool', 'wear', 'keep'];
const slotName = {'tool': '도구', 'wear': '옷', 'keep': '소지품'};

/// 효과 이름 (웹 EFFN)
String effName(String k, double v) {
  String pc(double x) => '${(x * 100 + .5).floor()}';
  return switch (k) {
    'scav' => '뒤지기 수확 +${pc(v)}%',
    'tap' => '두드리는 힘 +${pc(v)}%',
    'thrift' => '식량 소비 -${pc(v)}%',
    'hope' => '희망 +${((v * 10 + .5).floor() / 10).toString().replaceAll(RegExp(r'\.0$'), '')}',
    'food' => '식량 생산 +${pc(v)}%',
    'cost' => '건설 자재 -${pc(v)}%',
    'craft' => '가공 보너스 +${pc(v)}%',
    'fever' => '랜턴 피버 +${v.toStringAsFixed(1)}초',
    _ => '모든 생산 +${pc(v)}%',
  };
}

String effText(Map<String, double> o) => o.entries.map((e) => effName(e.key, e.value)).join(' · ');

/// 특기 문구: '{tap:pc}' → 백분율, '{hope:r}' → 반올림, '{fever:f1}' → 소수 한 자리
String traitText(SurvInfo s, Map<String, double> v) => s.trait.replaceAllMapped(RegExp(r'\{(\w+):(\w+)\}'), (m) {
      final x = v[m[1]] ?? 0;
      return switch (m[2]) {
        'pc' => '${(x * 100 + .5).floor()}',
        'r' => '${(x + .5).floor()}',
        _ => x.toStringAsFixed(1),
      };
    });

/// 한국어 조사: jo('목재','을','를') → '목재를'
String jo(String w, String a, String b) {
  if (w.isEmpty) return w + a;
  final c = w.codeUnitAt(w.length - 1) - 0xAC00;
  if (c < 0 || c > 11171) return '$w$a($b)';
  final j = c % 28;
  if (a == '으로') return w + (j == 0 || j == 8 ? '로' : '으로');
  return w + (j != 0 ? a : b);
}

/// 웹의 fmt(): 10 미만 소수는 한 자리, 만·억 단위
String fmt(num n) {
  if (n < 10 && n % 1 != 0) return n.toStringAsFixed(1);
  if (n < 1e4) {
    final s = n.floor().toString();
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }
  if (n < 1e8) return '${(n / 1e4).toStringAsFixed(n < 1e5 ? 1 : 0)}만';
  return '${(n / 1e8).toStringAsFixed(1)}억';
}
