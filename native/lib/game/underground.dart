// 5단계: 지하 구역 — 5×6 칸, 랜턴 기름이 버티는 만큼 내려간다. 웹 index.html 3621–3825.
// 한 번의 탐사(UgRun)는 저장하지 않는다(웹 UG처럼). 기록(S.ug: 최고 층·횟수·쉼터·기록)만 남는다.
part of 'engine.dart';

const ugW = 5, ugH = 6;

class UgTheme {
  const UgTheme(this.f, this.k, this.n, this.intro);
  final int f;
  final String k, n, intro;
}

final List<UgTheme> ugThemes = [for (final t in web.ugTheme) UgTheme(t['f'] as int, t['k'] as String, t['n'] as String, t['intro'] as String)];
final List<(int, String, String)> ugDiaries = [for (final d in web.ugDiary) (d['f'] as int, d['t'] as String, d['x'] as String)];
const List<int> ugCks = web.ugCk;

/// 이야기로 정해 둔 마지막 층 (마지막 지하 기록이 놓이는 층 = 17). 그 아래는 끝없는 지하 (앱 전용 2026-10-18)
final int ugDeep = ugDiaries.fold(15, (a, d) => math.max(a, d.$1));

/// 기록 조각이 나오기 시작하는 층
const fragFrom = 5;

/// 끝없는 지하의 세기: 마지막 층에서 한 층 내려갈 때마다 +12% (세 배까지)
double ugDeepK(int f) => f <= ugDeep ? 1 : math.min(3.0, 1 + .12 * (f - ugDeep));

/// 깊은 곳의 재괴물이 지키는 층: 마지막 층 아래의 10층마다 (20, 30, 40…)
bool ugBossFloor(int f) => f > ugDeep && f % 10 == 0;

/// 끝없는 지하의 테마: 다섯 층마다 지하철역 → 하수도 → 방공호 → 발전소 지하를 더 깊은 모습으로 되풀이
const _ugDeepIntro = [
  '지도에 없는 승강장. 선로가 어둠 속으로 끝없이 이어진다.',
  '물소리가 멀어졌다. 여기까지 내려온 사람은 없는 것 같다.',
  '철문 너머에 또 철문. 벽에 새긴 날짜들이 점점 흐려진다.',
  '바닥이 따뜻하다. 아주 먼 곳에서 무언가 천천히 빛나고 있다.',
];
UgTheme ugTheme(int f) {
  if (f <= ugDeep) return ugThemes.fold(ugThemes[0], (a, t) => f >= t.f ? t : a);
  final seg = (f - ugDeep - 1) ~/ 5, k = seg % ugThemes.length, t = ugThemes[k];
  return UgTheme(ugDeep + 1 + seg * 5, t.k, '깊은 ${t.n}', _ugDeepIntro[k % _ugDeepIntro.length]);
}

/// 이야기 물건을 찾았을 때의 첫마디 (웹 UG_FOUND)
const Map<int, String> ugFoundSay = {0: '찾았구먼…', 3: '찾았어요!', 4: '찾았데이…', 5: '찾았다!', 6: '…찾았다.', 12: '찾았구먼…', 17: '…찾았어.'};

/// 칸 이름 (웹 UGL · UGN)
const ugLabel = {'pet': '웅덩이', 'loot': '상자', 'rare': '귀한것', 'gear': '장비', 'oil': '기름', 'hazard': '위험', 'stairs': '계단', 'start': '입구', 'rest': '쉼터', 'key': '열쇠', 'door': '문', 'foe': '괴물', 'shop': '상인', 'diary': '기록', 'who': '흔적', 'quest': '이야기'};
const ugName = {'pet': '물웅덩이', 'loot': '상자', 'rare': '귀한 물건', 'gear': '장비', 'oil': '기름통', 'hazard': '위험', 'stairs': '아래층 계단', 'start': '내려온 곳', 'rest': '쉼터', 'key': '열쇠', 'door': '잠긴 문', 'foe': '재 괴물', 'shop': '지하 상인', 'diary': '기록', 'who': '누군가의 흔적', 'quest': '이야기 물건'};
const ugRoleN = {'guard': '위험 피해 절반', 'scout': '옆 칸 위험', 'art': '옆 칸 위험', 'sci': '계단 위치', 'medic': '부상 한 번 막기', 'mech': '자재 +30%', 'cook': '기름 +6', 'heart': '기름 +4', 'drive': '기름 +3', 'farm': '식량 두 배'};
const ugRoleShort = {'guard': '소방', 'scout': '정찰', 'art': '그림', 'sci': '연구', 'medic': '간호', 'mech': '기술', 'cook': '요리', 'heart': '희망', 'drive': '운전', 'farm': '텃밭'};
const ugPerk = {
  'scout': '정찰: 옆 칸의 위험이 보여요',
  'sci': '연구: 계단 위치가 보여요',
  'medic': '간호: 층마다 한 번 부상을 막아요',
  'guard': '소방: 위험 피해 절반',
  'mech': '기술: 자재 +30%',
  'cook': '요리: 기름 +6',
  'heart': '희망: 층을 내려갈 때 기름 +4',
  'drive': '운전: 층을 내려갈 때 기름 +3',
  'art': '그림: 옆 칸의 위험이 보여요',
  'farm': '텃밭: 식량 두 배',
};

class UgCell {
  UgCell(this.hp);
  String c = 'empty';
  bool rev = false, hit = false, fresh = false, used = false, open = false;
  int hp, fhp = 0, did = -1, qid = -1;
  String? hz;

  /// 깊은 곳의 재괴물 (끝없는 지하의 10층마다)
  bool boss = false;

  /// 지하 상인 칸: 이 상인에게서 산 횟수 [기름, 열쇠]
  final List<int> buys = [0, 0];
}

/// 지하 상인: 한 층의 상인에게서 기름은 2번, 열쇠는 1번까지 (웹 UG_SHOP_MAX, 2026-10-13)
const ugShopMax = [2, 1];

class UgRun {
  UgRun(this.team, this.oil, this.floor, this.msg, this.pet) : max = oil;
  final List<int> team;
  final String? pet;
  int oil, max, floor, keys = 0;
  final Set<int> explored = {};
  final Map<String, int> carry = {};
  final List<String> gear = [];
  final List<int> hurt = [];
  final List<int> found = [];
  String msg;
  List<UgCell> cells = [];
  bool medicUsed = false, shop = false, dPlaced = false, mtrace = false;
  String? petFound;
}

extension Underground on Game {
  Map get ugRec {
    if (S.rest['ug'] is! Map) S.rest['ug'] = <String, Object?>{'best': 0, 'runs': 0, 'bestWith': <String, Object?>{}};
    return S.rest['ug'] as Map;
  }

  List<int> get ugCkDone => [for (final v in (ugRec['ck'] as List? ?? const [])) (v as num).toInt()];
  List<int> get ugDiaryGot => [for (final v in (ugRec['diary'] as List? ?? const [])) (v as num).toInt()];
  int get ugRuns => ((ugRec['runs'] as num?) ?? 0).toInt();

  /// 지난번 멈춘 층 (웹 ugLast)
  int get ugLast {
    final l = ((ugRec['last'] as num?) ?? 0).toInt();
    if (l > 0) return math.max(1, l);
    final ck = ugCkDone;
    return math.max(1, ck.isEmpty ? 1 : ck.reduce(math.max));
  }

  int ugOil0(List<int> team, int fuel) => 14 + fuel * 3 + (team.any((id) => roleOf(id).contains('cook')) ? 6 : 0);
  int ugFuelMax(List<int> team) => 4 + 2 * team.length.clamp(1, 3);

  /// 그 몫(간호·소방)을 맡은 사람의 이름: 다치지 않은 동료 중 처음, 없으면 같이 온 펫
  String _ugRoleWho(String r) {
    final u = ug!;
    for (final id in u.team) {
      if (!u.hurt.contains(id) && roleOf(id).contains(r)) return survivors[id].name;
    }
    return u.pet != null ? petName(u.pet!) : '누군가';
  }

  bool ugRole(String r) {
    final u = ug;
    if (u == null) return false;
    if (u.team.any((id) => !u.hurt.contains(id) && roleOf(id).contains(r))) return true;
    return u.pet != null && petInfo(u.pet!)['ug'] == r;
  }

  /// 추천 셋: 소방·정찰(또는 그림)·연구·간호를 한 명씩, 나머지는 등급 순 (웹 ugRecommend)
  (List<int>, Map<int, String>) ugRecommend(List<int> free, {bool pet = false}) {
    final petR = pet && petOn != null && petHere(petOn!) ? petInfo(petOn!)['ug'] as String? : null;
    final need = <List<String>>[
      ['guard'],
      ['scout', 'art'],
      ['sci'],
      ['medic']
    ].where((rs) => !rs.contains(petR)).toList();
    int score(int id) => gradeOf(id) * 3 + Game.trustLv(xpOf(id)) + (roleOf(id).any(ugRoleN.containsKey) ? 1 : 0);
    final pick = <int>[], has = <String>{}, why = <int, String>{};
    void take(int id, String w) {
      if (pick.contains(id) || pick.length >= 3) return;
      pick.add(id);
      has.addAll(roleOf(id));
      if (w.isNotEmpty) why[id] = w;
    }

    for (final rs in need) {
      if (rs.any(has.contains)) continue;
      final c = free.where((id) => !pick.contains(id) && roleOf(id).any(rs.contains)).toList()..sort((a, b) => score(b) - score(a));
      if (c.isNotEmpty) take(c.first, ugRoleN[rs.firstWhere((k) => roleOf(c.first).contains(k))]!);
    }
    for (final id in [...free]..sort((a, b) => score(b) - score(a))) {
      take(id, gradeOf(id) >= 2 ? grades[gradeOf(id)].n ?? '' : '');
    }
    return (pick, why);
  }

  // ================= 내려가기 (웹 ugStart) =================
  bool ugStart(List<int> team0, int fuel0, int startF, {bool pet = false}) {
    final t = team0.where((id) => hasSv(id) && !busy(id)).toList();
    if (t.isEmpty || ug != null || defn != null) return false;
    final fuel = math.min(fuel0, ugFuelMax(t));
    if (fuel > 0 && !pay({'fuel': fuel})) return false;
    final oil = ugOil0(t, fuel) + (startF > 1 ? 12 : 0);
    final upk = pet && petOn != null && petHere(petOn!) ? petOn : null;
    if (upk != null) pets[upk]!['away'] = 'ug';
    final u = UgRun(t, oil, startF - 1, startF > 1 ? '지난번 멈춘 $startF층에서 다시 출발했다 · ${ugTheme(startF).n}' : '랜턴을 들고 계단을 내려갔다.', upk);
    ug = u;
    ugRec['runs'] = ugRuns + 1;
    _ugFloor();
    sfx('reveal');
    _changed();
    return true;
  }

  void _ugFloor() {
    final u = ug!;
    final f = ++u.floor;
    ugRec['last'] = f;
    const n = ugW * ugH;
    // 끝없는 지하에서도 칸 하나는 네 번까지만 (기름 한계 안에서 더 내려갈 수 있게)
    final deep = f > ugDeep;
    final cells = List.generate(n, (_) => UgCell(deep ? math.min(4, 1 + (f - 1) ~/ 5) : 1 + (f - 1) ~/ 5));
    const start = (ugH - 1) * ugW + 2;
    cells[start]
      ..rev = true
      ..c = 'start';
    bool isFree(int i) => cells[i].c == 'empty' && i != start && ((i % ugW) - 2).abs() + ((i ~/ ugW) - (ugH - 1)).abs() >= 2;
    // 빈칸을 200번 굴려 찾는다 (웹과 같은 난수 순서). 못 찾으면 -1: 예전처럼 아무 칸이나 돌려주면 계단·재괴물·입구를 덮어썼다
    int free() {
      int i, g = 0;
      do {
        i = rnd.nextInt(n);
        g++;
      } while (!isFree(i) && g < 200);
      return isFree(i) ? i : -1;
    }

    // 칸을 놓는다. 빈칸이 없으면 놓지 않고 null (상자·위험·상인·장비·이야기 물건 같은 것은 이 층에서 빠진다)
    UgCell? put(String c) {
      final i = free();
      if (i < 0) return null;
      cells[i].c = c;
      return cells[i];
    }

    {
      int i, g = 0;
      do {
        i = rnd.nextInt(ugW * 3);
        g++;
      } while (cells[i].c != 'empty' && g < 50);
      cells[i].c = 'stairs';
    }
    final th = ugTheme(f);
    if (f > 1 && th.f == f) u.msg = '${th.n} · ${th.intro}';
    if (ugBossFloor(f)) {
      // 깊은 곳의 재괴물(끝없는 지하의 10층마다): 계단 다음으로 먼저 놓아 다른 칸에 덮이거나 밀려나지 않게.
      // 보통 괴물의 세 배. 쓰러뜨리면 그날 밤의 기록 조각. 기름통 하나와 쉼터는 칸이 넉넉할 때만 (아래)
      var bi = free();
      if (bi < 0) bi = [for (var i = 0; i < n; i++) if (isFree(i)) i].firstOrNull ?? -1;
      if (bi >= 0) {
        cells[bi]
          ..c = 'foe'
          ..boss = true
          ..fhp = _ugDeepHp(f) * 3;
      }
      u.msg = '아래에서 무언가 숨 쉬는 소리가 들린다. 깊은 곳의 재괴물이 이 층 어딘가에 있다.';
    }
    if (ugCks.contains(f)) put('rest');
    for (var k = 0; k < (th.k == 'plant' || deep ? 4 : 5); k++) {
      put('loot');
    }
    put('rare');
    if (f >= 3) put('rare');
    for (var k = 0; k < (deep ? 5 : math.min(7, 2 + f ~/ 3)); k++) {
      final h = put('hazard'); // 위험 종류 굴림은 칸이 없어도 한다 (예전과 같은 난수 순서)
      final hz = rnd.nextDouble() < (th.k == 'sewer' ? .75 : .5) ? 'gas' : 'fall';
      h?.hz = hz;
    }
    put('oil');
    if (f % 2 == 0 || th.k == 'sewer' || f >= 8) put('oil');
    if (th.k == 'bunker' || (f >= 3 && rnd.nextDouble() < .45)) {
      final door = put('door');
      // 열쇠 칸이 없으면 열 수 없는 문도 두지 않는다
      if (put('key') == null) door?.c = 'empty';
    }
    if (f >= 5) {
      put('foe')?.fhp = deep ? _ugDeepHp(f) : 2 + f ~/ 4;
      if (th.k == 'plant') put('foe')?.fhp = deep ? _ugDeepHp(f) + 1 : 3 + f ~/ 4;
    }
    if (ugBossFloor(f)) {
      // 재괴물 층의 덤: 남은 빈칸이 넉넉할 때만 기름통 하나와 쉼터
      int room() => [for (var i = 0; i < n; i++) if (isFree(i)) i].length;
      if (room() > 6) put('oil');
      if (room() > 6) put('rest');
    }
    if (f >= 4 && rnd.nextDouble() < .3) put('shop');
    {
      final got = ugDiaryGot;
      var d = -1;
      for (var k = 0; k < ugDiaries.length; k++) {
        if (f >= ugDiaries[k].$1 && !got.contains(k)) {
          d = k;
          break;
        }
      }
      if (d >= 0 && !u.dPlaced) put('diary')?.did = d;
    }
    if (f >= 15 && !hasSv(13) && !u.mtrace) put('who');
    if (f >= 6 && f <= 9 && !pets.containsKey('turtle') && u.petFound == null && rnd.nextDouble() < .4) put('pet');
    if (rnd.nextDouble() < .22 + f * .03) put('gear');
    for (final id in u.team) {
      final st = qStep(id);
      if (st != null && st['k'] == 'find' && f >= (st['f'] as num) && !u.found.contains(id)) put('quest')?.qid = id;
    }
    u.cells = cells;
    u.medicUsed = false;
    u.shop = false;
    if (f > 1) {
      if (ugRole('heart')) u.oil += 4;
      if (ugRole('drive')) u.oil += 3;
      u.max = math.max(u.max, u.oil);
    }
    if (f > ((ugRec['best'] as num?) ?? 0)) {
      ugRec['best'] = f;
      if (f > 1) {
        give({'batt': 1});
        u.msg = '새 기록! 지하 $f층 · 건전지 +1${ugBossFloor(f) ? ' · 깊은 곳의 재괴물이 이 층 어딘가에 있다' : f == ugDeep + 1 ? ' · 기록이 끝난 곳보다 더 아래예요' : ''}';
      }
    }
    if (ugRec['bestWith'] is! Map) ugRec['bestWith'] = <String, Object?>{};
    final bw = ugRec['bestWith'] as Map;
    for (final id in u.team) {
      bw['$id'] = math.max(((bw['$id'] as num?) ?? 0).toInt(), f);
    }
  }

  /// 끝없는 지하의 재 괴물 힘: 마지막 층의 괴물(2 + 17÷4 = 6)에 깊이 배수
  int _ugDeepHp(int f) => jsRound((2 + ugDeep ~/ 4) * ugDeepK(f));

  /// 기록 조각 수 (지하 준비 화면)
  int get ugFragN => fragsGot.length;

  List<int> ugAdj(int i) {
    final x = i % ugW, y = i ~/ ugW;
    return [
      for (final (a, b) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)])
        if (a >= 0 && b >= 0 && a < ugW && b < ugH) b * ugW + a
    ];
  }

  bool ugFront(int i) => !ug!.cells[i].rev && ugAdj(i).any((j) => ug!.cells[j].rev);
  bool get ugFoeAlive => ug!.cells.any((x) => x.rev && x.c == 'foe' && x.fhp > 0);

  void _ugAdd(Map<String, num> o) => o.forEach((k, v) => ug!.carry[k] = (ug!.carry[k] ?? 0) + v.toInt());

  /// 칸 누르기. 기름이 다 떨어지면 true (화면이 잠깐 뒤 ugEnd(false))
  bool ugTap(int i) {
    final u = ug;
    if (u == null) return false;
    final c = u.cells[i];
    if (c.rev) {
      if (c.c == 'stairs') {
        final from = u.floor;
        u.msg = '지하 ${u.floor + 1}층으로 내려갔다.';
        S.rest['ugDown'] = num_('ugDown') + 1;
        _ugFloor();
        // 그날 밤의 기록 조각: 5층부터 계단을 내려갈 때마다 (2026-10-23 대표님: 본편에서 절반쯤 보게 — 예전엔 15층 아래 8%라 엔딩까지 0~1편).
        // 이야기 층(5~15층)은 20%, 그 아래 끝없는 지하는 10%. 나머지는 엔딩 뒤 깊은 지하·10층마다 재괴물에서
        if (from >= fragFrom && rnd.nextDouble() < (from <= ugDeep ? .2 : .1)) {
          final k = fragDrop();
          if (k >= 0) u.msg += ' · 계단참에서 기록 조각을 주웠다: **${frags[k].$2}** (올라가면 읽을 수 있어요)';
        }
        sfx('reveal');
        _changed();
        return false;
      }
      return _ugUse(c);
    }
    if (!ugFront(i) || u.oil <= 0) return false;
    c.hit = true;
    final tax = ugFoeAlive ? 2 : 1;
    u.oil = math.max(0, u.oil - tax);
    if (tax > 1 && c.hp <= 1) u.msg = '재 괴물이 랜턴 불빛에 끌려온다! (칸마다 기름 2)';
    c.hp--;
    if (c.hp <= 0) {
      c.rev = true;
      c.fresh = true;
      u.explored.add(u.floor);
      _ugResolve(c);
    }
    _changed();
    return u.oil <= 0;
  }

  void _ugResolve(UgCell c) {
    // 끝없는 지하의 전리품은 40층 몫까지만 커진다
    final u = ug!, f = u.floor, fr = math.min(f, 40), sc = 1 + (fr - 1) * .35;
    final snd = const {'loot': 'get', 'oil': 'get', 'key': 'get', 'hazard': 'night', 'foe': 'night', 'empty': '', 'stairs': '', 'start': '', 'shop': ''}[c.c] ?? 'find';
    if (snd.isNotEmpty) sfx(snd);
    switch (c.c) {
      case 'loot':
        final a = baseMats[rnd.nextInt(6)], b = baseMats[rnd.nextInt(6)], m = ugRole('mech') ? 1.3 : 1.0;
        final o = <String, num>{};
        o[a] = jsRound((3 + fr * 1.2) * m * (a == 'food' && ugRole('farm') ? 2 : 1));
        o[b] = (o[b] ?? 0) + jsRound((2 + fr) * m);
        _ugAdd(o);
        u.msg = '상자를 열었다 · ${lootText(o)}';
        if (rnd.nextDouble() < .08 && findRelic() != null) u.msg += ' · 유물도 함께!';
      case 'rare':
        final opts = <Map<String, num>>[
          {'plate': jsRound(2 * sc)},
          {'rope': jsRound(2 * sc)},
          {'wire': 1},
          {'med': 1},
          {'batt': 1},
          {'wire': 1, 'med': 1}
        ];
        final o = opts[math.min(opts.length - 1, rnd.nextInt(f >= 4 ? 6 : 4))];
        _ugAdd(o);
        u.msg = '귀한 물건! ${lootText(o)}';
      case 'gear':
        final q = rnd.nextDouble(), g = f >= 6 ? (q < .08 ? 3 : q < .6 ? 2 : 1) : f >= 3 ? (q < .35 ? 2 : 1) : (q < .3 ? 1 : 0);
        final t = f >= 10 && rnd.nextDouble() < .3 ? _ugMiner() : _ugGearPick(g);
        u.gear.add(t);
        u.msg = '장비를 찾았다 · ${gear[t]!.n} (${grades[g].n})';
      case 'oil':
        u.oil += 6;
        u.max = math.max(u.max, u.oil);
        u.msg = '기름통을 찾았다 · 기름 +6';
      case 'hazard':
        final guard = ugRole('guard');
        if (c.hz == 'gas') {
          // 끝없는 지하: 가스는 마지막 층 세기에서 한 층마다 +4% (1.6배까지)
          final l = f > ugDeep
              ? jsRound((3 + ugDeep ~/ 2) * math.min(1.6, 1 + .04 * (f - ugDeep)) * (guard ? .5 : 1))
              : jsRound((3 + f ~/ 2) * (guard ? .5 : 1));
          u.oil = math.max(0, u.oil - l);
          u.msg = '가스가 새어 나왔다! 랜턴이 흔들린다 · 기름 -$l';
        } else {
          final ok = u.team.where((id) => !u.hurt.contains(id)).toList();
          if (ugRole('medic') && !u.medicUsed) {
            u.medicUsed = true;
            u.msg = '천장이 무너졌지만, ${jo(_ugRoleWho('medic'), '이', '가')} 재빨리 모두를 끌어냈다.';
          } else if (guard && rnd.nextDouble() < .5) {
            u.msg = '천장이 무너졌다! ${jo(_ugRoleWho('guard'), '이', '가')} 몸으로 막아냈다.';
          } else if (ok.isNotEmpty) {
            final id = ok[rnd.nextInt(ok.length)];
            u.hurt.add(id);
            u.msg = '천장이 무너졌다! ${jo(survivors[id].name, '이', '가')} 다쳤다.';
          }
        }
      case 'stairs':
        u.msg = '아래로 이어지는 계단을 찾았다. 눌러서 내려가요.';
      case 'rest':
        u.msg = '쉼터를 찾았다! 눌러서 쉬어 가면 챙긴 물건을 위로 올려 보내고, 다음엔 여기서 시작할 수 있어요.';
      case 'key':
        u.keys++;
        u.msg = '녹슨 열쇠를 주웠다. 이 층 어딘가에 잠긴 문이 있다.';
      case 'door':
        u.msg = u.keys > 0 ? '잠긴 철문. 열쇠로 열 수 있다. 눌러서 열어요.' : '잠긴 철문. 이 층 어딘가에 열쇠가 있을 거다.';
      case 'foe':
        if (ugRole('guard')) c.fhp = math.max(1, (c.fhp / 2).ceil());
        u.msg = c.boss
            ? '**깊은 곳의 재괴물 · 지하 $f층**이 몸을 일으켰다! 쓰러뜨리기 전까지 칸마다 기름이 2씩 들어요. 눌러서 싸워요 (${c.fhp})'
            : '재 괴물이 깨어났다! 쓰러뜨리기 전까지 칸마다 기름이 2씩 들어요. 눌러서 싸워요 (${c.fhp})';
      case 'shop':
        u.msg = '지하 상인이 등불을 들고 앉아 있다. 눌러서 거래해요.';
      case 'diary':
        if (ugRec['diary'] is! List) ugRec['diary'] = <Object?>[];
        final dl = ugRec['diary'] as List;
        if (!dl.contains(c.did)) dl.add(c.did);
        final d = ugDiaries[c.did];
        u.dPlaced = true;
        u.msg = '**${d.$2}** — ${d.$3}';
        dirty = true;
      case 'pet':
        u.petFound = 'turtle';
        u.msg = '물웅덩이 속 바위가 움직였다. 이끼 낀 늙은 거북이 천천히 눈을 떴다. 함께 올라가요!';
      case 'quest':
        if (c.qid >= 0 && !u.found.contains(c.qid)) {
          u.found.add(c.qid);
          final qs = qStep(c.qid);
          u.msg = '${survivors[c.qid].name}: “${ugFoundSay[c.qid] ?? '찾았어요…'} ${qs?['item'] ?? ''}!”${qs?['note'] != null ? ' ${qs!['note']}' : ''}';
          qAdvance(c.qid);
        }
      case 'who':
        u.mtrace = true;
        u.msg = '발전소 쪽으로 난 철문. 그 너머는 재가 벽처럼 막고 있다. 문 앞에 직원용 비상식량 깡통이 가지런히 비어 있고, 벽에 분필 글씨가 남아 있다. “아직 여기 있어요. 위에서 불빛이 보이면 갈게요. — 탁”';
      default:
        u.msg = '먼지뿐이다.';
    }
  }

  String _ugGearPick(int g) {
    final pool = gear.entries.where((e) => e.value.g == g && !e.value.sig && !e.value.ug && !e.value.line).map((e) => e.key).toList();
    return pool[rnd.nextInt(pool.length)];
  }

  String _ugMiner() => const ['mpick', 'mhelm', 'mlamp'][rnd.nextInt(3)];

  /// 밝혀진 칸 쓰기: 쉼터·문·괴물·상인 (웹 ugUse). 기름이 떨어지면 true
  bool _ugUse(UgCell c) {
    final u = ug!, f = u.floor;
    if (c.c == 'rest' && !c.used) {
      c.used = true;
      final got = give(u.carry);
      u.carry.clear();
      for (final t in u.gear) {
        addGear(t);
      }
      final ng = u.gear.length;
      u.gear.clear();
      final ck = ugCkDone;
      if (!ck.contains(f)) ck.add(f);
      ck.sort();
      ugRec['ck'] = ck;
      u.oil += 10;
      u.max = math.max(u.max, u.oil);
      sfx('find');
      u.msg = '쉼터에서 한숨 돌렸다. 챙긴 물건을 위로 올려 보냈다${got.isNotEmpty ? ' · ${lootText(got)}' : ''}${ng > 0 ? ' · 장비 $ng개' : ''} · 기름 +10 · 다음엔 $f층에서 시작할 수 있어요';
      dirty = true;
    } else if (c.c == 'door' && !c.open) {
      if (u.keys <= 0) {
        u.msg = '잠긴 철문. 열쇠가 필요해요.';
        _changed();
        return false;
      }
      u.keys--;
      c.open = true;
      sfx('find');
      final fr = math.min(f, 40), sc = 1 + (fr - 1) * .35;
      final o = <String, num>{'plate': jsRound(3 * sc), 'parts': jsRound(4 * sc)};
      if (f >= 4) o[rnd.nextDouble() < .5 ? 'wire' : 'med'] = 1 + fr ~/ 8;
      _ugAdd(o);
      var m = '철문이 열렸다! 비밀 창고 · ${lootText(o)}';
      if (rnd.nextDouble() < .35 + f * .02) {
        final t = f >= 10 && rnd.nextDouble() < .5 ? _ugMiner() : _ugGearPick(f >= 6 ? 2 : 1);
        u.gear.add(t);
        m += ' · ${gear[t]!.n}';
      }
      if (rnd.nextDouble() < .15 && findRelic() != null) m += ' · 유물도!';
      u.msg = m;
    } else if (c.c == 'foe' && c.fhp > 0) {
      if (u.oil <= 0) return false;
      u.oil--;
      c.fhp -= ugRole('guard') ? 2 : 1;
      sfx(c.fhp <= 0 ? 'find' : 'hit', buzz: true);
      if (c.fhp <= 0) {
        c.fhp = 0;
        final o = <String, num>{rnd.nextDouble() < .5 ? 'wire' : 'med': 1, 'scrap': 6 + math.min(f, 40)};
        _stat['foe'] = ((_stat['foe'] as num?) ?? 0) + 1;
        if (c.boss) {
          // 깊은 곳의 재괴물: 전리품 세 배 + 그날 밤의 기록 조각 (다 모았으면 건전지)
          o.updateAll((key, v) => v * 3);
          o['batt'] = 2;
          _ugAdd(o);
          final k = fragDrop();
          _stat['ugBoss'] = ((_stat['ugBoss'] as num?) ?? 0) + 1;
          u.msg = '깊은 곳의 재괴물이 흩어졌다! · ${lootText(o)}${k >= 0 ? ' · 재 속에서 기록 조각이 나왔다: **${frags[k].$2}** (올라가면 읽을 수 있어요)' : ''}';
        } else {
          _ugAdd(o);
          u.msg = '재 괴물을 쓰러뜨렸다! · ${lootText(o)}';
        }
      } else {
        u.msg = c.boss ? '깊은 곳의 재괴물을 내리쳤다! 남은 힘 ${c.fhp}' : '재 괴물을 내리쳤다! 남은 힘 ${c.fhp}';
      }
      if (u.oil <= 0) {
        _changed();
        return true;
      }
    } else if (c.c == 'shop') {
      u.shop = !u.shop;
      u.msg = '상인: “위에서 가져온 걸로 바꿔 주지.” (쉘터 창고에서 빠져요)';
    }
    _changed();
    return false;
  }

  /// 이 층 상인에게서 산 횟수 (상인이 없으면 다 산 것으로)
  List<int> ugShopBuys() {
    final u = ug;
    if (u == null) return const [9, 9];
    for (final c in u.cells) {
      if (c.c == 'shop') return c.buys;
    }
    return const [9, 9];
  }

  /// 지하 상인 (0: 식량 15 → 기름 8, 1: 부품 12 → 열쇠). 웹 ugb
  void ugBuy(int k) {
    final u = ug;
    if (u == null) return;
    final sb = ugShopBuys();
    if (sb[k] >= ugShopMax[k]) {
      u.msg = k == 1 ? '상인: “열쇠는 그게 마지막이야.”' : '상인: “기름은 이걸로 끝이야. 나도 내려가야 하거든.”';
      _changed();
      return;
    }
    if (k == 0 && pay({'food': 15})) {
      sb[0]++;
      u.oil += 8;
      u.max = math.max(u.max, u.oil);
      u.msg = '상인: “아껴 써. 남은 게 많지 않아.” · 기름 +8 (${ugShopMax[0] - sb[0]}번 남음)';
      sfx('get');
    } else if (k == 1 && pay({'parts': 12})) {
      sb[1]++;
      u.keys++;
      u.msg = '상인: “이 열쇠, 어디 문인지는 나도 몰라.” · 열쇠 +1';
      sfx('get');
    }
    _changed();
  }

  /// 돌아오기 (웹 ugEnd). safe=false면 기름이 떨어져 급히 올라옴: 자재 절반·장비를 잃는다
  void ugEnd(bool safe) {
    final u = ug;
    if (u == null) return;
    ug = null;
    final units = u.explored.length;
    var lost = false;
    if (!safe) {
      u.carry.updateAll((k, v) => v ~/ 2);
      lost = u.gear.isNotEmpty;
      u.gear.clear();
    }
    final got = give(u.carry);
    for (final t in u.gear) {
      addGear(t);
    }
    for (final id in u.hurt) {
      if (hasSv(id)) rec(id)!['hurt'] = 90;
    }
    for (final id in u.team) {
      if (hasSv(id)) rec(id)!['xp'] = xpOf(id) + 15 * units;
    }
    recalc();
    if (u.pet != null && pets[u.pet] != null) {
      pets[u.pet]!['away'] = false;
      if (units > 0) petGain(u.pet!, 3 * units);
    }
    if (u.petFound != null && !pets.containsKey(u.petFound)) petAdopt(u.petFound!);
    fx.add(FxNote(safe ? '지하 ${u.floor}층에서 무사히 돌아왔어요' : '기름이 떨어져 급히 올라왔어요 · 지하 ${u.floor}층',
        '${got.isNotEmpty ? lootText(got) : '챙긴 게 없어요'}${u.gear.isNotEmpty ? ' · 장비 ${u.gear.map((t) => gear[t]!.n).join(', ')}' : ''}${lost ? ' · 장비를 떨어뜨렸어요' : ''}${u.hurt.isNotEmpty ? ' · ${u.hurt.map((id) => survivors[id].name).join(', ')} 부상' : ''} · 동료 신뢰 +${15 * units}',
        ms: 6500));
    _changed();
  }
}
