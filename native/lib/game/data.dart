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
  const SurvInfo(this.id, this.name, this.job, this.src, this.d, this.region, this.hidden);
  final int id;
  final String name, job, src;
  final double d;
  final String? region;
  final bool hidden;
}

final List<SurvInfo> survivors = [
  for (final s in web.surv)
    SurvInfo(s['id'] as int, s['name'] as String, s['job'] as String, s['src'] as String, (s['d'] as num).toDouble(), s['region'] as String?, s['hidden'] as bool),
];

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
