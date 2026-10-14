// 웹에 있는데 앱에 빠져 있던 작은 시스템들 (2026-10-14 점검):
// 새 기능 안내(FEAT), 아래 탭 알림 점, 자동 가공, 증축 응원 노트(beats), 신뢰 3 전용 장비,
// 해질녘 경고 노트, 같은 알림 줄이기(quietToast), 꾹 누르기 안내, 두 사람 대화 듣기.
part of 'engine.dart';

/// 잠시 뒤에 띄우는 알림 (웹 setTimeout(toast/note))
class FxToastLater extends Fx {
  const FxToastLater(this.ms, this.text);
  final int ms;
  final String text;
}

class FxNoteLater extends Fx {
  const FxNoteLater(this.wait, this.h, this.t, {this.ms = 4500});
  final int wait, ms;
  final String h, t;
}

/// 새 기능 안내 카드를 띄운다 (웹 openFeatCard)
class FxFeat extends Fx {
  const FxFeat(this.k);
  final String k;
}

/// 웹 FEAT (4327): 기능이 처음 열리면 카드 하나 · 아래 탭에 점
class FeatInfo {
  const FeatInfo(this.k, this.tab, this.sheet, this.seg, this.on, this.msg, this.h);
  final String k, msg, h;

  /// 아래 탭 번호 (0 생존자 · 1 원정 · 2 쉘터 · 3 라디오 · 4 일지), 없으면 -1
  final int tab;
  final String? sheet, seg;
  final bool Function(Game g) on;
}

final List<FeatInfo> feats = [
  FeatInfo('radio', 3, 'radio', null, (g) => g.have('batt') >= 3 && g.mi >= 2, '라디오에 건전지를 넣을 수 있어요', '주파수 탐색'),
  FeatInfo('bag', 0, 'surv', null, (g) => g.inv.isNotEmpty, '생존자에게 장비를 맞춰 줄 수 있어요', '장비'),
  FeatInfo('quest', 0, 'surv', null, (g) => g.S.sv.values.any((r) => r is Map && r['q'] != null), '생존자의 개인 이야기가 열렸어요', '개인 이야기'),
  FeatInfo('deco', 2, 'shelter', 'deco', (g) => g.S.lv >= 2, '쉘터 화면 ‘꾸미기’ 탭에서 장식을 놓을 수 있어요', '쉘터 꾸미기'),
  FeatInfo('ug', 1, 'exp', null, (g) => g.ugOpen, '원정 탭 맨 위에 지하 구역이 열렸어요', '지하 구역'),
  FeatInfo('relic', 4, 'diary', 'relic', (g) => g.relics.isNotEmpty, '일지 ‘폐허 도감’에서 유물을 볼 수 있어요', '폐허 도감'),
  FeatInfo('auto', 0, 'surv', null, (g) => g.S.lv >= 3, '생존자 수첩 맨 위에서 버튼 한 번으로 일터를 채울 수 있어요', '자동 배치'),
  FeatInfo('autoexp', 1, 'exp', null, (g) => g.S.lv >= 4, '원정 탭 맨 위에서 자동 원정을 켤 수 있어요', '자동 원정'),
  FeatInfo('acraft', 2, 'shelter', 'craft', (g) => g.acraftOpen, '가공 탭에서 레시피마다 자동 가공을 켤 수 있어요 (쉘터 Lv.4 · 작업대 2단계)', '자동 가공'),
  FeatInfo('trade', 3, 'radio', null, (g) => g.stayList.isNotEmpty, '라디오 ‘무전 거래’에서 남은 사람들과 물건을 바꿀 수 있어요', '무전 거래'),
  FeatInfo('route', 4, 'diary', 'towns', (g) => g.S.gen > 0, '일지 ‘노선도’에서 지나온 동네와 남은 사람들을 볼 수 있어요', '만수의 노선도'),
  FeatInfo('migrate', 2, 'shelter', 'build', (g) => Game._truthy(g.S.rest['endSeen']) && g.S.lv >= 5, '쉘터 화면에서 새 동네로 떠날 수 있어요', '이주'),
  FeatInfo('line', 1, 'exp', null, (g) => g.lnOpen, '복구한 역 안쪽 끊긴 노선에 들어갈 수 있어요', '끊긴 노선'),
  FeatInfo('pets', 0, 'pets', null, (g) => g.pets.isNotEmpty, '식구가 된 동물을 펫 화면에서 돌볼 수 있어요', '펫'),
  FeatInfo('fire', -1, null, null, (g) => g.S.region == 'snow', '위쪽 띠의 모닥불 온기를 지켜요', '모닥불 온기'),
];

/// 첫 동네 이후에는 그 동네에서 새로 생기는 기능만 카드를 띄운다 (웹 FEAT_LATER, 2026-10-13)
const featLater = ['trade', 'route', 'fire', 'line'];

/// 시트 → 아래 탭 (웹 TAB_OF)
const featTabOf = {'surv': 0, 'exp': 1, 'shelter': 2, 'radio': 3, 'diary': 4};

/// 신뢰도 3이 되면 받는 전용 장비 (웹 SIG_T3)
const sigT3 = {13: 'ckey', 14: 'herbbag', 15: 'wmask', 16: 'rope3', 17: 'feather'};

/// 증축 응원 (웹 BEAT_GOALS · BEAT_LINES · LV3_BEATS)
const beatGoals = ['요새로 키우기', '불빛의 도시 완성하기', '컨테이너 쉘터로 키우기'];
const beatLines = [
  Line('g', '벽 한쪽이 벌써 올라갔어. 조금만 더 하자고.'),
  Line('g', '오늘 모은 걸로 기둥을 세웠지. 모양이 나온다.'),
  Line('me', '쉘터에 새 기둥이 하나 더 섰다. 사람들이 올려다보며 웃었다.'),
  Line('g', '이제 반쯤 왔어. 밤엔 불빛이 멀리서도 보일 거야.'),
  Line('me', '망치 소리가 밤늦게까지 이어졌다. 아무도 피곤하다고 하지 않았다.'),
  Line('g', '거의 다 됐어! 마지막 자재만 모으면 돼.'),
];
const lv3Beats = [
  [Line('g', '벽 한쪽이 벌써 올라갔어. 컨테이너가 바람을 꽤 막아 주는구먼.')],
  [
    Line('me', '밤이 깊었는데 창고 쪽에서 지직거리는 소리가 났다.'),
    Line('me', '가 보니 아무것도 없었다. 소리는 짐 더미 어딘가에서 났다가, 금세 그쳤다.'),
    Line('g', '쥐겠지. 아니면 바람이 깡통을 건드렸거나.'),
  ],
  [
    Line(3, '아저씨, 창고에서 또 그 소리 났어요. 지지직… 하고. 누가 말하는 것 같기도 했어요.'),
    Line('me', '다 짓고 나면 창고부터 정리해야겠다.'),
  ],
];

/// 몇 번 넘게 나오면 조용히 넘기는 알림 (웹 QUIET — 순서가 저장 번호라 바꾸지 않는다)
final List<RegExp> quietPats = [
  RegExp('버려진 벙커를 찾았어요'), RegExp('생존자를 찾았어요'), RegExp('등유 한 통을 찾았어요'), RegExp('물자 상자를 찾았어요'), RegExp('통조림 상자'),
  RegExp(r'신뢰도 \d+! 새 사연'), RegExp('해가 졌어요'), RegExp('쉘터 앞에 찾아왔어요'), RegExp('개를 만들었어요'),
];

extension FeatExt on Game {
  // ---------------- 아래 탭 알림 점 (웹 svDot · exDot · upDot · rdDot) ----------------
  Map get ack {
    if (S.rest['ack'] is! Map) S.rest['ack'] = <String, Object?>{};
    return S.rest['ack'] as Map;
  }

  /// 시트를 열었을 때 (웹 openSheet 감싸기 5590·6230)
  void sheetOpened(String sheet, {String? seg}) {
    if (sheet == 'surv') svNew = false;
    if (sheet == 'shelter') ack['up'] = 1;
    if (sheet == 'radio') ack['rdAt'] = math.max(5, have('batt').toInt());
    seeTab(sheet);
    seeFeat(sheet, seg);
    _changed();
  }

  /// 짓거나 증축할 수 있는 게 있음
  bool get canUpNow {
    final up = S.lv < 5 && S.mods.length >= shupNeed[S.lv - 1] && canPay(shelterUpCost!);
    final build = freeSlot() >= 0 && modOrder.any((id) => mods[id] != null && !hasMod(id) && S.lv >= mods[id]!.req && canPay(modBuildCost(id)));
    return up || build;
  }

  /// 탭마다 점을 띄울지 (0 생존자 · 1 원정 · 2 쉘터 · 3 라디오 · 4 일지)
  Set<int> tabDots(int nowMs) {
    final out = <int>{};
    if (svNew) out.add(0);
    if (expMap.values.any((x) => nowMs >= ((x['end'] as num?) ?? 1e15))) out.add(1);
    final c = canUpNow;
    if (!c) ack['up'] = 0;
    if (c && !Game._truthy(ack['up'])) out.add(2);
    final bt = have('batt').toInt();
    if (bt < 5) ack['rdAt'] = 0;
    final rdAt = ((ack['rdAt'] as num?) ?? 0).toInt();
    if (bt >= 5 && (rdAt == 0 || bt >= rdAt + 10)) out.add(3);
    final f = featMap;
    for (final x in feats) {
      if (f[x.k] == 1 && x.tab >= 0) out.add(x.tab);
    }
    return out;
  }

  // ---------------- 새 기능 안내 (웹 tickFeat · seeFeat · seeTab) ----------------
  /// 처음 읽을 때(이 기능이 생기기 전 저장) 이미 열린 기능은 '봄'(2)으로 채운다 (웹 tickFeat의 !S.feat).
  /// 아래 탭 점이 첫 틱보다 먼저 읽어도 옛 기능이 전부 '새것'으로 뜨지 않게, 읽는 곳 어디서든 같은 씨앗을 쓴다.
  Map get featMap {
    if (S.rest['feat'] is! Map) {
      final m = <String, Object?>{};
      for (final f in feats) {
        if (f.on(this)) m[f.k] = 2;
      }
      S.rest['feat'] = m;
    }
    return S.rest['feat'] as Map;
  }

  /// 1 = 새것(아래 탭 점), 3 = 탭은 열었지만 안쪽 칸에 아직 점, 2 = 봄
  int featOf(String k) => ((featMap[k] as num?) ?? 0).toInt();

  /// 안쪽 칸(쉘터 '꾸미기', 일지 '도감' 등)에 N 표시
  bool segNew(String sheet, String seg) => feats.any((f) => (featOf(f.k) == 1 || featOf(f.k) == 3) && f.sheet == sheet && f.seg == seg);

  void _tickFeat() {
    final F = featMap, later = S.gen > 0;
    if (S.rest['featQ'] is! List) S.rest['featQ'] = <Object?>[];
    final q = S.rest['featQ'] as List;
    for (final f in feats) {
      if (later && !featLater.contains(f.k) && (F[f.k] == 1 || F[f.k] == 3)) F[f.k] = 2;
      if (F[f.k] != null && F[f.k] != 0) continue;
      if (f.on(this)) {
        // 첫 동네 이후에는 그 동네에서 새로 생기는 기능(무전 거래·노선도·모닥불·노선)만 카드를 띄운다
        if (later && !featLater.contains(f.k)) {
          F[f.k] = 2;
          continue;
        }
        F[f.k] = 1;
        q.add(f.k);
      }
    }
    final at = ((S.rest['featAt'] as num?) ?? 0).toInt(), now = Game.nowMs();
    if (q.isNotEmpty && num_('playT') >= 300 && now - at > 120000 && !uiModal) {
      final k = q.removeAt(0) as String;
      final f = feats.where((x) => x.k == k).firstOrNull;
      if (f != null && F[k] == 1) {
        S.rest['featAt'] = now;
        // 창·대화·방어전·지하·노선 중이면 카드 대신 짧은 알림
        if (uiModal || defn != null || ug != null || ln != null) {
          fx.add(FxNote('새 기능 · ${f.h}', f.msg, ms: 5000));
        } else {
          fx.add(FxFeat(k));
          sfx('chime');
        }
      }
    }
  }

  void seeFeat(String sheet, String? seg) {
    final F = featMap;
    for (final f in feats) {
      if ((F[f.k] == 1 || F[f.k] == 3) && f.sheet == sheet && (f.seg == null || f.seg == seg)) F[f.k] = 2;
    }
  }

  void seeTab(String sheet) {
    final tab = featTabOf[sheet];
    if (tab == null || S.rest['feat'] is! Map) return;
    final F = featMap;
    for (final f in feats) {
      if (F[f.k] == 1 && f.tab == tab) F[f.k] = f.seg != null && f.sheet == sheet ? 3 : 2;
    }
  }

  /// '보러 가기'를 눌렀을 때
  void featSeen(String k) {
    featMap[k] = 2;
    _changed();
  }

  // ---------------- 자동 가공 (웹 acraftOpen · tickACraft 5628) ----------------
  bool get acraftOpen => wbL >= 2 && (S.lv >= 4 || S.gen != 0);
  Map get acraft {
    if (S.rest['acraft'] is! Map) S.rest['acraft'] = <String, Object?>{};
    return S.rest['acraft'] as Map;
  }

  bool acraftOn(int k) => Game._truthy(acraft['$k']);
  void acraftToggle(int k) {
    acraft['$k'] = !acraftOn(k);
    sfx('tap');
    if (acraftOn(k)) fx.add(FxToast('${matOf[recipes[k].out]!.n} 자동 가공을 켰어요 · 다음 건설에 쓸 재료는 남겨 둬요'));
    _changed();
  }

  /// 다음 건설(증축·탑·새 모듈)에 쓸 만큼은 남겨 둔다
  int acReserve(String m) {
    var need = 0;
    void add(Cost? c) {
      final v = c?[m];
      if (v != null) need = math.max(need, v.ceil());
    }

    if (S.lv < 5) add(shelterUpCost);
    if (towerOpen) add(towerCost);
    for (final id in modOrder) {
      if (mods[id] != null && !hasMod(id) && S.lv >= mods[id]!.req) add(modBuildCost(id));
    }
    final tier = matOf[m]?.tier;
    return math.max(need, tier == 0 ? (capOf(m) * .25).floor() : 0);
  }

  /// 지금 만들 수 있는 개수 (재료·창고 자리)
  int craftMax(int k) {
    final r = recipes[k];
    if (wbL == 0 || recipeLock(r).isNotEmpty) return 0;
    var n = 999;
    recipeInp(r).forEach((m, v) {
      if (v > 0) n = math.min(n, (have(m) / v).floor());
    });
    final room = math.max(0, capOf(r.out) - have(r.out));
    n = math.min(n, (room / r.n).floor());
    return math.max(0, n);
  }

  /// 조용히 만들기: (만든 횟수, 얻은 개수)
  (int, int) craftQuiet(int k, int n) {
    final r = recipes[k];
    var made = 0, c = 0;
    for (var q = 0; q < n; q++) {
      if (!pay(recipeInp(r))) break;
      c++;
      final extra = rnd.nextDouble() < (E['craft'] ?? 0) + craftBuff ? 1 : 0;
      made += give({r.out: r.n + extra})[r.out] ?? 0;
    }
    if (c > 0) _changed();
    return (c, made);
  }

  void _tickACraft() {
    if (!acraftOpen || acraft.isEmpty) return;
    final per = wbL >= 3 ? 2 : 1;
    for (final e in acraft.entries.toList()) {
      if (!Game._truthy(e.value)) continue;
      final k = int.tryParse('${e.key}');
      if (k == null || k < 0 || k >= recipes.length) continue;
      final r = recipes[k];
      if (recipeLock(r).isNotEmpty) continue;
      var n = per;
      recipeInp(r).forEach((m, v) {
        if (v > 0) n = math.min(n, (math.max(0, have(m) - acReserve(m)) / v).floor());
      });
      n = math.min(n, craftMax(k));
      if (n > 0) craftQuiet(k, n);
    }
  }

  // ---------------- 증축 응원 (웹 tickBeats · lv3Beat 4443) ----------------
  double get lvProgress {
    if (S.lv >= 5) return 1;
    final c = shelterUpCost!;
    final parts = [for (final e in c.entries) math.min(1.0, have(e.key) / e.value), math.min(1.0, S.mods.length / shupNeed[S.lv - 1])];
    return parts.fold(0.0, (a, v) => a + v) / parts.length;
  }

  Map get beats {
    if (S.rest['beats'] is! Map) S.rest['beats'] = <String, Object?>{};
    return S.rest['beats'] as Map;
  }

  Map<String, int> _beatGift() => give({...scaleCost({'scrap': 12, 'wood': 12, 'food': 10}, lvScale), 'batt': 1});

  void _tickBeats() {
    final m = mission();
    if (m.step == null || m.done || !beatGoals.contains(m.txt)) return;
    final k = m.txt, n = ((beats[k] as num?) ?? 0).toInt(), f = lvProgress;
    const th = [.3, .55, .8];
    if (n >= th.length || f < th[n]) return;
    beats[k] = n + 1;
    final got = _beatGift();
    if (k == '컨테이너 쉘터로 키우기') {
      // 4장 라디오로 이어지는 세 장면
      final L = [for (final l in lv3Beats[n]) if (l.who is! int || hasSv(l.who as int)) l];
      if (n == 1 && !uiModal && !uiSheet) {
        talk(L, tag: '3장 · 모여드는 사람들', reward: got);
        sfx('mystery');
      } else {
        final l = L.last;
        fx.add(FxNote('${speakerName(l.who)} · ${(th[n] * 100).round()}% 왔어요', '“${l.t}”\n작은 보상 · ${lootText(got)}', ms: 5600));
        sfx('chime');
      }
    } else {
      final l = beatLines[(beatGoals.indexOf(k) * 2 + n) % beatLines.length];
      fx.add(FxNote('${speakerName(l.who)} · ${(th[n] * 100).round()}% 왔어요', '“${l.t}”\n작은 보상 · ${lootText(got)}', ms: 5200));
      sfx('chime');
    }
    _changed();
  }

  // ---------------- 신뢰 3 전용 장비 (웹 tickSig 4165) ----------------
  void _tickSig() {
    if (S.rest['sigGot'] is! Map) S.rest['sigGot'] = <String, Object?>{};
    final got = S.rest['sigGot'] as Map;
    for (final e in sigT3.entries) {
      final id = e.key;
      if (!hasSv(id) || got['$id'] == 1 || Game.trustLv(xpOf(id)) < 3) continue;
      got['$id'] = 1;
      if (inv.any((x) => x['t'] == e.value)) continue;
      final it = addGear(e.value), G = gear[it['t'] as String];
      if (G != null) fx.add(FxNote('${survivors[id].name}의 전용 장비', '${G.n} · ${G.d} 장비 가방에 들어왔어요', ms: 6000));
      _changed();
    }
  }

  // ---------------- 해질녘 경고 (웹 tickDusk 4390) ----------------
  void _tickDusk() {
    if (!duskWarn) return;
    final n = num_('nightCount');
    if (S.rest['warnedN'] == n) return;
    S.rest['warnedN'] = n;
    final raid = S.rest['raid'];
    fx.add(FxNote(raid != null && raid != false && raid != 0 ? '$raid이(가) 곧 쳐들어와요' : '곧 대형 재폭풍이 몰려와요', '10초 뒤 해가 져요. 하던 일을 마무리해요', ms: 6000));
    sfx('night');
  }

  // ---------------- 같은 알림 줄이기 (웹 quietToast 4441) ----------------
  /// 이 알림을 띄우지 않을지 (흔한 발견은 세 번까지만)
  bool quietToast(String m) {
    final i = quietPats.indexWhere((r) => r.hasMatch(m));
    if (i < 0) return false;
    if (S.rest['qc'] is! Map) S.rest['qc'] = <String, Object?>{};
    final qc = S.rest['qc'] as Map;
    final n = ((qc['$i'] as num?) ?? 0).toInt() + 1;
    qc['$i'] = n;
    return n > 3;
  }

  // ---------------- 꾹 누르기 안내 (웹 holdHint 4384) ----------------
  /// 같은 칸을 빠르게 여러 번 두드리면 한 번만 알려 준다
  void holdHint(int i) {
    final now = Game.nowMs();
    if (i == _tapRunI && now - _tapRunT < 450) {
      _tapRunN++;
    } else {
      _tapRunI = i;
      _tapRunN = 1;
    }
    _tapRunT = now;
    if (_tapRunN >= 6 && S.rest['holdTip'] == null) {
      S.rest['holdTip'] = 1;
      fx.add(const FxNote('꾹 누르고 있어도 돼요', '구름이나 폐허, 랜턴 버튼을 누르고 있으면 계속 두드려요 · 화면 안의 구름을 한 번에 30개까지', ms: 4500));
    }
  }

  // ---------------- 두 사람 대화 듣기 (웹 openChat 3969) ----------------
  /// 말풍선 ▸을 눌렀을 때: 대화를 열고, 처음 듣는 두 사람이면 신뢰 +10
  void openChat(int a, int b, List<(int, String)> lines) {
    if (S.rest['heard'] is! Map) S.rest['heard'] = <String, Object?>{};
    final heard = S.rest['heard'] as Map, key = a < b ? '$a-$b' : '$b-$a', first = heard[key] == null;
    heard[key] = 1;
    if (first) {
      if (hasSv(a)) rec(a)!['xp'] = xpOf(a) + 10;
      if (hasSv(b)) rec(b)!['xp'] = xpOf(b) + 10;
    }
    talk([for (final (w, t) in lines) Line(w, t)], tag: '${survivors[a].name} · ${survivors[b].name}${first ? ' · 두 사람의 신뢰 +10' : ''}');
    _changed();
  }
}
