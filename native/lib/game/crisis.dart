// 3단계: 낮밤·밤 재·대형 재폭풍 방어전·날씨·생존자의 부탁·생존자 의뢰.
// 웹 index.html 2726–2860(부탁·밤), 3826–3880(방어전), 3943–3960(날씨), 5419–5510(부탁 창·의뢰)을 옮겼다.
part of 'engine.dart';

const dayLen = 150.0, cycleLen = 200.0, evTotal = 90.0;
const _wallP = [.35, .2, .1, .03];
const _wallRed = [0.0, .3, .5, .7];

/// 화면에 알림 카드로 띄울 것 (웹 note)
class FxNote extends Fx {
  const FxNote(this.h, this.t, {this.ms = 4500});
  final String h, t;
  final int ms;
}

/// 세계 좌표에 파편 튀기기·글자 띄우기 (방어전 괴물처럼 칸에 붙지 않은 것)
class FxBurstAt extends Fx {
  const FxBurstAt(this.x, this.y, this.color, this.n);
  final double x, y;
  final int color, n;
}

class FxFloatAt extends Fx {
  const FxFloatAt(this.x, this.y, this.text, this.color);
  final double x, y;
  final String text;
  final int color;
}

/// 대형 재폭풍이 시작됨 → 화면이 쉘터로 카메라를 맞춘다
class FxDefense extends Fx {
  const FxDefense(this.start);
  final bool start;
}

/// 부탁을 들어줌 → 결과 창
class FxEventDone extends Fx {
  const FxEventDone(this.ev, this.k, this.sum);
  final int ev, k;
  final List<(String, String?, bool)> sum; // 글, 자원 키, 나쁜 효과
}

class Foe {
  Foe(this.x, this.y, this.hp, this.spd, this.brute, this.delay, this.ph) : max = hp;
  double x, y, hp, spd, delay, ph;
  final double max;
  final bool brute;
  double hit = 0, sl = 0;
  bool dead = false;
}

class Beam {
  Beam(this.x0, this.y0, this.x1, this.y1, this.t, this.color);
  final double x0, y0, x1, y1;
  double t;
  final int color;
}

class Defense {
  Defense(this.raid);
  final String? raid;
  double t = 0, dur = 80, hp = 100, max = 100, shake = 0, fire = 0, ally = 0;
  int wave = 0, kills = 0;
  final List<Foe> foes = [];
  final List<Beam> beams = [];
  final List<(double, double, double)> trail = []; // x, y, 남은 시간
  // 괴물이 나오는 타원 (화면 크기에 맞춰 화면 쪽에서 정한다, 웹 frameDefense)
  double rx = 220, ry = 120, up = 150;
}

class WxInfo {
  const WxInfo(this.n, this.ic, this.d);
  final String n, ic, d;
}

final Map<String, WxInfo> wxInfo = {for (final e in web.wx.entries) e.key: WxInfo(e.value['n'] as String, e.value['ic'] as String, e.value['d'] as String)};

/// 생존자 의뢰 종류 (웹 SQT 5452)
class _Sq {
  const _Sq(this.ok, this.n, this.v, this.t, this.go, this.say);
  final bool Function(Game g) ok;
  final int Function(Game g) n;
  final num Function(Game g) v;
  final String Function(int n) t;
  final String go;
  final List<String> say;
}

num _gotN(Game g, String k) => g.S.got[k] ?? 0;
final Map<String, _Sq> sqTypes = {
  'wood': _Sq((g) => true, (g) => (45 * g.lvScale).round(), (g) => _gotN(g, 'wood'), (n) => '목재 ${fmt(n)}개 모으기', 'lamp',
      const ['“장작이 모자라요. 오늘 밤 불 좀 넉넉히 피우고 싶어요.”', '“침상 다리가 또 부러졌어요. 나무가 필요해요.”']),
  'scrap': _Sq((g) => true, (g) => (45 * g.lvScale).round(), (g) => _gotN(g, 'scrap'), (n) => '고철 ${fmt(n)}개 모으기', 'lamp',
      const ['“고철만 있으면 이것저것 고쳐 볼게요.”', '“녹슨 거라도 좋아요. 쇠붙이 좀 모아 와요.”']),
  'food': _Sq((g) => true, (g) => (40 * g.lvScale).round(), (g) => _gotN(g, 'food'), (n) => '식량 ${fmt(n)}개 모으기', 'lamp',
      const ['“창고가 비어 가요. 아이들 먹을 거라도 채워 둬요.”', '“오늘은 제대로 한 끼 차려 보고 싶어요.”']),
  'plate': _Sq((g) => g.wbL >= 1 && g.S.lv >= 2 && g.have('plate') < g.capOf('plate'), (g) => (8 * g.lvScale).round(), (g) => _gotN(g, 'plate'),
      (n) => '철판 ${fmt(n)}장 만들기', 'craft', const ['“지붕에 구멍이 났어요. 철판으로 덮어야 해요.”', '“철판 몇 장만 있으면 문을 단단히 달 수 있어요.”']),
  'rope': _Sq((g) => g.wbL >= 1 && g.S.lv >= 2 && g.have('rope') < g.capOf('rope'), (g) => (6 * g.lvScale).round(), (g) => _gotN(g, 'rope'),
      (n) => '밧줄 ${fmt(n)}개 만들기', 'craft', const ['“빨랫줄이 끊어졌어요. 밧줄 좀 꼬아 줄래요?”', '“망루에 올라갈 밧줄이 필요해요.”']),
  'reveal': _Sq((g) => g.frontier.length >= 30, (g) => 10 + g.S.lv * 2, (g) => g.revCount, (n) => '어둠 $n칸 걷어내기', 'lamp',
      const ['“저 너머에 뭐가 있는지 궁금해요. 조금만 더 밝혀 줘요.”', '“구름 속에서 뭔가 반짝였어요. 가까이 가 봐요.”']),
  'exp': _Sq((g) => g.num_('expDone') > 0 || g.mi > stepI('첫 원정 보내기'), (g) => 1, (g) => g.num_('expDone'), (n) => '원정 한 번 다녀오기', 'fExp',
      const ['“지도에 표시해 둔 곳이 있어요. 누가 다녀와 줄래요?”', '“멀리서 연기가 올라와요. 확인해 봐야겠어요.”']),
  'ug': _Sq((g) => g.ugOpen && g.ugRuns > 0, (g) => 1, (g) => g.ugRuns, (n) => '지하 구역 한 번 내려가기', 'fExp',
      const ['“지하에서 이상한 소리가 났대요. 한번 내려가 봐요.”', '“지하철역 매점에 통조림이 남아 있을지도 몰라요.”']),
  'radio': _Sq((g) => g.have('batt') >= 3, (g) => 3, (g) => g.num_('gTotal'), (n) => '주파수 탐색 $n번 하기', 'radio',
      const ['“라디오에서 누가 부르는 것 같았어요. 다이얼 좀 돌려 봐요.”', '“건전지 아껴서 뭐 해요. 신호 좀 찾아봐요!”']),
  'ev': _Sq((g) => g.num_('evDone') > 0, (g) => 1, (g) => g.num_('evDone'), (n) => '생존자의 부탁 하나 들어주기', 'ev', const ['“다들 말은 안 해도 부탁이 하나씩 있을 거예요.”']),
  'night': _Sq((g) => g.num_('nights') > 0, (g) => 1, (g) => g.num_('nights'), (n) => '재폭풍 밤 한 번 버티기', 'clock', const ['“오늘 밤도 무사히 넘겨요. 그럼 한잔해요.”']),
  'feast': _Sq((g) => g.feastOpen && g.feastLeftMs <= 0, (g) => 1, (g) => g.num_('feasts'), (n) => '마을 잔치 한 번 열기', 'craft', const ['“요즘 다들 지쳤어요. 잔치 한번 열어요!”']),
};

extension Crisis on Game {
  num num_(String k) => (S.rest[k] as num?) ?? 0;
  Map get _stat {
    if (S.rest['stat'] is! Map) S.rest['stat'] = <String, Object?>{};
    return S.rest['stat'] as Map;
  }
  int get revCount => S.rev.fold(0, (a, v) => a + v);
  bool hasMod(int id) => modLv(id) >= 0;


  // ================= 낮밤 (웹 2799) =================
  double get clock => num_('clock').toDouble();
  double get phase => clock % cycleLen;
  bool get isNight => phase >= dayLen;
  double get nightness {
    final p = phase;
    if (p < dayLen - 10) return 0;
    if (p < dayLen) return (p - dayLen + 10) / 10;
    if (p < cycleLen - 10) return 1;
    return (cycleLen - p) / 10;
  }

  bool get ashLearned => S.gen != 0 || mi >= stepI('재폭풍 밤 한 번 버티기');
  bool get stormOn => isNight && revCount >= 16 && (S.gen != 0 || mi >= stepI('구조 신호를 따라가 생존자 구하기'));
  bool get bigNightNext => S.lv >= 2 && ashLearned && num_('nightCount').toInt() % bigPeriod == bigPeriod - 1;
  bool get shield => num_('shield') != 0;

  /// 큰 밤이 다가오면 화면 가장자리를 붉게 (웹 tickDusk)
  bool get duskWarn => !isNight && defn == null && (bigNightNext || S.rest['raid'] != null) && revCount >= 16 && phase > dayLen - 12;

  String get clockText {
    if (tut != null) return tutClock;
    final p = phase, n = isNight, st = n && stormOn;
    final left = n ? cycleLen - p : dayLen - p, mm = left ~/ 60, ss = (left % 60).floor().toString().padLeft(2, '0');
    String t;
    final oc = oddClock;
    if (defn != null) {
      t = '대형 재폭풍 · 쉘터를 지켜요';
    } else if (oc != null) {
      t = oc.startsWith('새벽 3시') ? '$oc · $mm:$ss' : oc;
    } else if (n) {
      t = st ? '재폭풍 · 새벽까지 $mm:$ss' : '고요한 밤 · $mm:$ss';
    } else {
      t = bigNightNext ? '낮 · 대형 재폭풍 $mm:$ss' : '낮 · 밤까지 $mm:$ss';
    }
    final w = wxInfo[wxK]!;
    return '${w.ic} ${isNight || defn != null ? '' : '${w.n} · '}$t';
  }

  List<int> _edgeTiles() => [
        for (var i = 0; i < N; i++)
          if (S.rev[i] == 1 && i != C0 && !modAt.containsKey(i) && S.ter[i] != T.water && S.ter[i] != T.lm && !S.ash.containsKey('$i') && prot[i] == 0 && nb4(i).any((j) => S.rev[j] == 0)) i
      ];
  List<int> _modTargets() => [for (final t in modAt.keys) if (!S.ash.containsKey('$t') && prot[t] == 0) t];

  void _tickClock(double dt) {
    S.rest['clock'] = clock + dt;
    final n = isNight;
    if (n && !wasNight) {
      pedLeave();
      final big = (bigNightNext || S.rest['raid'] != null) && revCount >= 16;
      S.rest['nightCount'] = num_('nightCount') + 1;
      nightN = 0;
      nightLost = 0;
      spawnT = 2;
      if (big) {
        startDefense();
      } else if (stormOn) {
        fx.add(FxToast(shield ? '밤이 왔어요. 방화포 덕에 재폭풍이 약해요' : '해가 졌어요! 재폭풍이 밀려와요. 붉은 재를 두드려요'));
      } else {
        fx.add(const FxToast('고요한 밤이에요'));
      }
      _mapChanged();
    }
    if (!n && wasNight) {
      _onDawn();
      if (nightN > 0) {
        final held = nightN - nightLost;
        final got = give({...scaleCost({'scrap': held * 2, 'wood': held}, lvScale), 'batt': 1});
        S.rest['nights'] = num_('nights') + 1;
        fx.add(FxToast('밤을 버텼어요! 막아낸 재 $held/$nightN${got.isNotEmpty ? ' · ${lootText(got)}' : ''}'));
      }
      S.rest['shield'] = 0;
      S.ash.removeWhere((k, v) => !(v is Map && v['stuck'] == true));
      _mapChanged();
    }
    // 저녁·새벽 10초 동안 지도 어둠이 바뀐다
    final p = phase;
    if ((p > dayLen - 10 && p < dayLen + .5) || p > cycleLen - 10.5) _mapChanged();
    wasNight = n;
    if (n && stormOn && defn == null) {
      spawnT -= dt;
      if (spawnT <= 0) {
        spawnT = math.max(2.2, 6 - S.lv * .6) * (shield ? 1.8 : 1);
        final mt = _modTargets();
        final useMod = mt.isNotEmpty && rnd.nextDouble() < _wallP[S.walls.clamp(0, 3)];
        final c = useMod ? mt : _edgeTiles();
        if (c.isNotEmpty) {
          final i = c[rnd.nextInt(c.length)], hp = tapPow * (2.5 + S.lv * .5);
          S.ash['$i'] = <String, Object?>{'hp': hp, 'max': hp, 't': 14.0};
          nightN++;
          fx.add(FxBurst(i, 0xFF77726B, 14));
          if (useMod) fx.add(FxToast('재가 ${jo(mods[modAtTile(i)!.id]!.n, '을', '를')} 덮치려 해요!'));
          _mapChanged();
        }
      }
    }
    var ch = false, any = false;
    for (final k in S.ash.keys.toList()) {
      final a = S.ash[k];
      if (a is! Map || a['stuck'] == true) continue;
      any = true;
      a['t'] = ((a['t'] as num?) ?? 0) - dt;
      if ((a['t'] as num) > 0) continue;
      final i = int.parse(k);
      nightLost++;
      if (!ashLearned) {
        S.ash.remove(k);
        nightLost--;
        fx.add(FxBurst(i, 0xFF9A948C, 10));
        fx.add(FxFloat(i, '재가 흩어졌다', 0xFFDCD7CD, rise: 30));
        continue;
      }
      final m = modAtTile(i);
      if (m != null) {
        a['stuck'] = true;
        ch = true;
        fx.add(FxToast('${jo(mods[m.id]!.n, '이', '가')} 재에 덮여 멈췄어요'));
      } else if (isSlot(i)) {
        S.ash.remove(k);
      } else {
        S.ash.remove(k);
        S.rev[i] = 0;
        S.hp[i] = -1;
        if (aim == i) aim = -1;
        _rebuildFrontier();
        fx.add(const FxToast('재에 덮여 땅 한 칸을 잃었어요'));
      }
    }
    if (any) _mapChanged(); // 재의 남은 시간 고리
    if (ch) recalc();
  }

  String lootText(Map<String, num> o) => o.entries.map((e) => '${matOf[e.key]?.n ?? e.key} +${fmt(e.value)}').join(' · ');

  /// 붉은 재 두드리기 (웹 hitAsh 2841)
  void hitAsh(int i, double amt) {
    final a = S.ash['$i'];
    if (a is! Map) return;
    addCombo();
    a['hp'] = ((a['hp'] as num?) ?? 0) - amt * petAsh;
    fx.add(FxBurst(i, 0xFF9A948C, 6));
    if ((a['hp'] as num) <= 0) {
      final st = _stat;
      st['ash'] = ((st['ash'] as num?) ?? 0) + 1;
      final was = a['stuck'] == true;
      S.ash.remove('$i');
      fx.add(FxBurst(i, 0xFFFFD98A, 14));
      fx.add(FxFloat(i, '재를 걷어냈다!', 0xFFFFE6A0, rise: 34));
      loot({'scrap': math.max(1, (1.5 * lvScale).round())}, i);
      if (was) recalc();
    }
    _changed();
  }

  /// 가장 급한 재 (웹 urgentAsh)
  int get urgentAsh {
    var best = -1;
    var bt = 1e9;
    S.ash.forEach((k, a) {
      if (a is! Map) return;
      final t = a['stuck'] == true ? 999.0 : ((a['t'] as num?) ?? 0).toDouble();
      if (t < bt) {
        bt = t;
        best = int.parse(k);
      }
    });
    return best;
  }

  // ================= 날씨 (웹 3943) =================
  String get wxK => S.rest['wx'] is String && wxInfo.containsKey(S.rest['wx']) ? S.rest['wx'] as String : 'normal';
  double wxMul(String kind, [String? k]) {
    final w = wxK;
    switch (kind) {
      case 'prod':
        return (w == 'acid' && k == 'food' ? .5 : 1) * regProd(k ?? '');
      case 'eat':
        return w == 'cold' ? 1.3 : 1;
      case 'fuel':
        return w == 'cold' ? 2 : 1;
      case 'scav':
        return w == 'clear' ? 1.25 : w == 'acid' ? .85 : 1;
      case 'dig':
        return w == 'clear' ? 1.2 : w == 'wind' ? 1.1 : 1;
    }
    return 1;
  }

  String rollWx() {
    final rw = rollRegionWx();
    if (rw != null) return rw;
    final r = rnd.nextDouble();
    return r < .4 ? 'normal' : r < .62 ? 'clear' : r < .76 ? 'acid' : r < .9 ? 'cold' : 'wind';
  }

  bool get canForecast => hasSv(11) || hasMod(7);

  void _onDawn() {
    S.rest['wx'] = S.rest['wxNext'] is String ? S.rest['wxNext'] : rollWx();
    S.rest['wxNext'] = rollWx();
    S.rest['day'] = num_('day') + 1;
    final w = wxInfo[wxK]!, nx = wxInfo[S.rest['wxNext']]!;
    fx.add(FxNote('${w.ic} 오늘의 날씨 · ${w.n}', '${w.d}${canForecast ? ' · 내일은 ${nx.ic} ${nx.n}' : ''}', ms: 5000));
    _regionDawn();
    _pedDawn();
    _allyGifts();
    _kidsDawn();
    recalc();
  }

  // ================= 생존자의 부탁 (웹 2726, 5436) =================
  bool _evFit(int k) {
    final e = web.events[k];
    if (!(e['who'] as List).every((id) => hasSv(id as int))) return false;
    if (e['dog'] == true && (S.rest['dog'] != null && S.rest['dog'] != 0)) return false;
    return true;
  }

  Map<String, Object?> evOpt(int ev, int k) => Map<String, Object?>.from(web.events[ev][k == 0 ? 'a' : 'b'] as Map);
  Cost evCost(int ev, int k) {
    final c = evOpt(ev, k)['cost'];
    return c is Map ? scaleCost({for (final e in c.entries) e.key as String: e.value as num}, lvScale) : {};
  }

  /// 고르면 받는 것 (웹 evFxList)
  List<(String, String?, bool)> evFxList(int ev, int k) {
    final fx0 = (evOpt(ev, k)['fx'] as Map?) ?? const {}, out = <(String, String?, bool)>[];
    final lootM = fx0['loot'];
    if (lootM is Map) {
      final l = scaleCost({for (final e in lootM.entries) e.key as String: e.value as num}, lvScale * (lmOn('library') ? 1.5 : 1));
      l.forEach((q, v) => out.add(('${matOf[q]?.n ?? q} +${fmt(v)}', q, false)));
    }
    final xp = fx0['xp'];
    if (xp is Map) {
      xp.forEach((id, v) {
        if (hasSv(int.parse('$id'))) out.add(('${survivors[int.parse('$id')].name} 신뢰 +$v', null, false));
      });
    }
    if (fx0['xpAll'] != null) out.add(('모두 신뢰 +${fx0['xpAll']}', null, false));
    if (fx0['hope'] != null) out.add(('희망 +${fx0['hope']}', null, false));
    final b = fx0['buff'];
    if (b is Map) out.add(('${b['k'] == 'farm' ? '식량 ' : '생산 '}×${b['m']} · ${b['t']}초', null, (b['m'] as num) < 1));
    if (fx0['dog'] != null && S.rest['dog'] == null) out.add(('강아지가 가족이 돼요', null, false));
    if (fx0['shield'] != null) out.add(('오늘 밤 재폭풍 약화', null, false));
    if (fx0['reveal'] != null) out.add(('어둠 ${fx0['reveal']}칸 걷힘', null, false));
    out.add(('건전지 +1', 'batt', false));
    return out;
  }

  void _tickEvents(double dt) {
    if (evCur >= 0) {
      evLeft -= dt;
      if (evLeft <= 0) {
        evCur = -1;
        evT = 50;
      }
      return;
    }
    if (revCount < 14 || (S.gen == 0 && mi < stepI('구조 신호를 따라가 생존자 구하기'))) return;
    evT -= dt;
    if (evT > 0) return;
    final all = [for (var k = 0; k < web.events.length; k++) if (_evFit(k)) k];
    final pool = all.where((k) => !evSeen.contains(k)).toList();
    final list = pool.isNotEmpty ? pool : all;
    if (list.isEmpty) return;
    final pref = list.where((k) => (web.events[k]['who'] as List).isNotEmpty).toList();
    final pick = pref.isNotEmpty && rnd.nextDouble() < .8 ? pref : list;
    evCur = pick[rnd.nextInt(pick.length)];
    evLeft = evTotal;
    evSeen.add(evCur);
    if (evSeen.length > 5) evSeen.removeAt(0);
    _changed();
  }

  int? evWho(int ev) {
    final w = web.events[ev]['who'] as List;
    return w.isEmpty ? null : w.first as int;
  }

  /// 부탁 하나를 고름 (웹 chooseEv)
  bool chooseEv(int k) {
    final ev = evCur;
    if (ev < 0) return false;
    final c = evCost(ev, k);
    if (!pay(c)) return false;
    final fx0 = (evOpt(ev, k)['fx'] as Map?) ?? const {}, sum = <(String, String?, bool)>[];
    final lootM = fx0['loot'];
    if (lootM is Map) {
      final got = give(scaleCost({for (final e in lootM.entries) e.key as String: e.value as num}, lvScale * (lmOn('library') ? 1.5 : 1)));
      got.forEach((q, v) => sum.add(('${matOf[q]?.n ?? q} +${fmt(v)}', q, false)));
    }
    final xp = fx0['xp'];
    if (xp is Map) {
      xp.forEach((id0, v) {
        final id = int.parse('$id0');
        final r = rec(id);
        if (r != null) {
          r['xp'] = xpOf(id) + (v as num);
          sum.add(('${survivors[id].name} 신뢰 +$v', null, false));
        }
      });
    }
    final xa = fx0['xpAll'] as num?;
    if (xa != null) {
      for (final id in svIds) {
        rec(id)!['xp'] = xpOf(id) + xa;
      }
      sum.add(('모두 신뢰 +$xa', null, false));
    }
    final hp = fx0['hope'] as num?;
    if (hp != null) {
      S.hopeB += hp.toInt();
      sum.add(('희망 +$hp', null, false));
    }
    final b = fx0['buff'];
    if (b is Map) {
      S.buff = <String, Object?>{'k': b['k'], 'm': b['m'], 't': b['t'], 'label': b['label']};
      sum.add(('${b['label']} · ${b['k'] == 'farm' ? '식량 ' : '생산 '}×${b['m']} ${b['t']}초', null, (b['m'] as num) < 1));
    }
    if (fx0['dog'] != null && S.rest['dog'] == null) {
      S.rest['dog'] = 1;
      sum.add(('강아지가 가족이 됐어요', null, false));
    }
    if (fx0['shield'] != null) {
      S.rest['shield'] = 1;
      sum.add(('오늘 밤 재폭풍 약화', null, false));
    }
    final rv = fx0['reveal'] as num?;
    if (rv != null) {
      revealN(rv.toInt());
      sum.add(('어둠 $rv칸 걷힘', null, false));
    }
    give({'batt': 1});
    sum.add(('건전지 +1', 'batt', false));
    S.rest['evDone'] = num_('evDone') + 1;
    evCur = -1;
    evT = 70 + rnd.nextDouble() * 60;
    recalc();
    fx.add(FxEventDone(ev, k, sum));
    _changed();
    return true;
  }

  /// 경계에서 가까운 칸 n개 밝히기 (웹 revealN)
  void revealN(int n) {
    final fr = frontier.toList();
    if (fr.isEmpty) return;
    final o = fr[rnd.nextInt(fr.length)], ox = o % W, oy = o ~/ W;
    for (var k = 0; k < n; k++) {
      var best = -1, bd = 1 << 30;
      for (final i in frontier) {
        final d = (i % W - ox).abs() + (i ~/ W - oy).abs();
        if (d < bd) {
          bd = d;
          best = i;
        }
      }
      if (best < 0) break;
      reveal(best);
    }
  }

  // ================= 생존자 의뢰 (웹 5449) =================
  bool get sqOn => S.sv.length >= 2 && (S.lv >= 2 || S.gen != 0);
  Map? get sq => S.rest['sq'] is Map ? S.rest['sq'] as Map : null;
  num sqProg() {
    final q = sq;
    if (q == null || !sqTypes.containsKey(q['k'])) return 0;
    final T0 = sqTypes[q['k']]!, n = (q['n'] as num?) ?? 1;
    if (T0.go == 'craft' && matOf.containsKey(q['k']) && have(q['k'] as String) >= capOf(q['k'] as String)) return n;
    return math.max(0, math.min(n, T0.v(this) - ((q['b'] as num?) ?? 0)));
  }

  bool get sqDone => sq != null && sqProg() >= ((sq!['n'] as num?) ?? 1);

  void _sqNew() {
    final last = sq?['k'];
    final ks = sqTypes.keys.where((k) => k != last && sqTypes[k]!.ok(this)).toList();
    if (ks.isEmpty) return;
    double w(String k) => const ['wood', 'scrap', 'food', 'reveal'].contains(k) ? 1 : 1.4;
    var tot = 0.0;
    for (final k in ks) {
      tot += w(k);
    }
    var r = rnd.nextDouble() * tot;
    var k = ks.first;
    for (final q in ks) {
      r -= w(q);
      if (r <= 0) {
        k = q;
        break;
      }
    }
    final T0 = sqTypes[k]!;
    final ids = svIds.where((id) => rec(id)!['away'] != true).toList();
    final who = (ids.isNotEmpty ? ids : svIds.toList());
    S.rest['sq'] = <String, Object?>{
      'k': k,
      'n': T0.n(this),
      'b': T0.v(this),
      'at': DateTime.now().millisecondsSinceEpoch,
      'who': who[rnd.nextInt(who.length)],
      'say': T0.say[rnd.nextInt(T0.say.length)],
    };
    sqOpenUntil = DateTime.now().millisecondsSinceEpoch + 7000;
    _changed();
  }

  /// 다음 증축에 모자란 것을 보상으로 (웹 sqReward)
  Cost sqReward() {
    final rw = <String, num>{};
    if (S.lv < 5) {
      final tgt = shelterUpCost!;
      String? best;
      var bv = 0.0;
      tgt.forEach((k, v) {
        if (k == 'batt') return;
        final miss = v - have(k);
        if (miss <= 0) return;
        final f = miss / v;
        if (f > bv) {
          bv = f.toDouble();
          best = k;
        }
      });
      if (best != null) {
        final v = tgt[best]!, miss = v - have(best!);
        rw[best!] = math.max(1, math.min(miss, (v * ((matOf[best]?.tier ?? 0) > 0 ? .03 : .04)).round()));
      }
    }
    if (rw.isEmpty) rw.addAll(scaleCost({'scrap': 15, 'wood': 15}, lvScale));
    rw['batt'] = 1;
    return rw;
  }

  void claimSq() {
    if (!sqDone) return;
    final q = sq!, rw = sqReward(), bonus = (num_('sqN').toInt() + 1) % 3 == 0;
    final got = give(rw);
    var extra = '';
    if (bonus) {
      give({'batt': 3});
      final t = dropGear(S.lv >= 4 ? 2 : 1);
      extra = ' · 보급 상자: 건전지 +3${t != null ? ' · ${gear[t]!.n}' : ''}';
    }
    final who = (q['who'] as num?)?.toInt() ?? -1;
    if (hasSv(who)) rec(who)!['xp'] = xpOf(who) + 40;
    S.rest['sqN'] = num_('sqN') + 1;
    final nm = hasSv(who) ? survivors[who].name : '';
    fx.add(FxNote('${nm.isNotEmpty ? '$nm의 ' : ''}의뢰 완료', '${lootText(got)}${nm.isNotEmpty ? ' · $nm 신뢰 +40' : ''}$extra'));
    S.rest['sq'] = null;
    S.rest['sqAt'] = DateTime.now().millisecondsSinceEpoch + 60000;
    _changed();
  }

  void _tickSide() {
    if (!sqOn) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final q = sq;
    if (q == null && now > num_('sqAt')) {
      _sqNew();
    } else if (q != null && !sqTypes.containsKey(q['k'])) {
      S.rest['sq'] = null;
    } else if (q != null && !sqDone && now - ((q['at'] as num?) ?? now) > 10 * 60000) {
      _sqNew();
    }
  }

  // ================= 대형 재폭풍 (웹 3826) =================
  void startDefense() {
    defn = Defense(S.rest['raid'] as String?);
    S.rest['raid'] = null;
    if (defn!.raid != null) fx.add(FxToast('${defn!.raid}이(가) 쳐들어와요!'));
    if (num_('defs') == 0) fx.add(const FxNote('대형 재폭풍이 몰려와요!', '두드리면 가까운 괴물을, 문지르면 한꺼번에 베어요. 랜턴 버튼은 쉘터 옆부터 쳐요', ms: 6000));
    fx.add(const FxDefense(true));
    _changed();
  }

  void _spawnWave() {
    final D2 = defn!, w = ++D2.wave, n = 3 + S.lv * 2 + w * 2, c = tileC0;
    for (var k = 0; k < n; k++) {
      final a = rnd.nextDouble() * math.pi * 2, brute = w >= 2 && rnd.nextDouble() < .18 + w * .08;
      final hp = tapPow * (brute ? 7 : 2.4) * (1 + S.lv * .25);
      final ry = math.sin(a) < 0 ? D2.up : D2.ry;
      D2.foes.add(Foe(c.$1 + math.cos(a) * D2.rx * (.92 + rnd.nextDouble() * .08), c.$2 + math.sin(a) * ry * (.9 + rnd.nextDouble() * .1), hp,
          (brute ? 9 : 14 + rnd.nextDouble() * 6) * (1 + w * .06), brute, k * .45 + rnd.nextDouble() * .6, rnd.nextDouble() * 6));
    }
    fx.add(FxToast(w == 1 ? '첫 번째 무리가 다가와요' : w == 2 ? '두 번째 무리! 큰 놈이 섞여 있어요' : '마지막 무리예요, 버텨요!'));
  }

  (double, double) get tileC0 {
    final x = C0 % W, y = C0 ~/ W;
    return ((x - y) * TW / 2, (x + y + 1) * TH / 2);
  }

  (double, double) _tc(int i, [double z = 0]) {
    final x = i % W, y = i ~/ W;
    return ((x - y) * TW / 2, (x + y + 1) * TH / 2 - z);
  }

  bool _isGuard(int id) => id < web.role.length && web.role[id].contains('guard');

  /// 화면 쪽에서 프레임마다 부른다 (웹 tickDefense)
  void tickDefense(double dt) {
    final D2 = defn;
    if (D2 == null) return;
    D2.t += dt;
    D2.shake = math.max(0, D2.shake - dt * 2);
    if (D2.wave < 3 && D2.t >= D2.wave * 24) _spawnWave();
    final (cx, cy) = tileC0;
    for (final f in D2.foes) {
      if (f.delay > 0) {
        f.delay -= dt;
        continue;
      }
      f.hit = math.max(0, f.hit - dt * 3);
      final dx = cx - f.x, dy = cy - f.y, d = math.sqrt(dx * dx + dy * dy);
      if (d < 16) {
        f.dead = true;
        final dmg = (f.brute ? 16 : 7) * (1 - _wallRed[S.walls.clamp(0, 3)]) * petDef;
        D2.hp -= dmg;
        D2.shake = 1;
        fx.add(FxToast(S.walls > 0 ? '재가 방벽에 부딪혔어요 · 내구도 -${dmg.round()}' : '재가 쉘터를 덮쳤어요 · 내구도 -${dmg.round()}'));
        continue;
      }
      f.x += dx / d * f.spd * dt;
      f.y += dy / d * f.spd * dt;
    }
    D2.fire += dt;
    if (D2.fire >= 1) {
      D2.fire = 0;
      // 랜턴탑이 쏜다
      for (final en in modAt.entries) {
        final m = S.mods[en.value]!;
        final a = S.ash['${en.key}'];
        if (m.id != 8 || (a is Map && a['stuck'] == true)) continue;
        final (tx, ty) = _tc(en.key, 50);
        final R = (2 + m.l) * TW * .55;
        for (final f in D2.foes) {
          if (!f.dead && f.delay <= 0 && math.sqrt(math.pow(f.x - tx, 2) + math.pow((f.y - ty) * 1.6, 2)) < R) {
            hurtFoe(f, tapPow * (1 + m.l * .5));
            D2.beams.add(Beam(tx, ty, f.x, f.y - 8, .25, 0xFFFFD278));
            break;
          }
        }
      }
      // 일하는 생존자가 싸운다
      for (final id in svIds) {
        final at = atOf(id);
        if (at < 0 || busy(id)) continue;
        final gm = _isGuard(id) ? 2 : 1;
        final (wx, wy) = _tc(at, 16);
        Foe? best;
        var bd = TW * 3.4;
        for (final f in D2.foes) {
          if (f.dead || f.delay > 0) continue;
          final d = math.sqrt(math.pow(f.x - wx, 2) + math.pow(f.y - wy, 2));
          if (d < bd) {
            bd = d;
            best = f;
          }
        }
        if (best != null && rnd.nextDouble() < .55) {
          hurtFoe(best, tapPow * .7 * gm);
          D2.beams.add(Beam(wx, wy, best.x, best.y - 8, .2, 0xFFFFF0BE));
        }
      }
    }
    _worldFight(D2, dt);
    for (final b in D2.beams) {
      b.t -= dt;
    }
    D2.beams.removeWhere((b) => b.t <= 0);
    for (var k = 0; k < D2.trail.length; k++) {
      final p = D2.trail[k];
      D2.trail[k] = (p.$1, p.$2, p.$3 - dt);
    }
    D2.trail.removeWhere((p) => p.$3 <= 0);
    D2.foes.removeWhere((f) => f.dead);
    if (D2.hp <= 0) {
      endDefense(false);
    } else if (D2.wave >= 3 && D2.foes.isEmpty && D2.t > 50) {
      endDefense(true);
    } else if (D2.t > D2.dur + 25) {
      endDefense(D2.hp > 0);
    }
  }

  void hurtFoe(Foe f, double a) {
    if (f.dead) return;
    f.hp -= a;
    f.hit = 1;
    if (f.hp <= 0) {
      f.dead = true;
      defn!.kills++;
      final st = _stat;
      st['foe'] = ((st['foe'] as num?) ?? 0) + 1;
      fx.add(FxBurstAt(f.x, f.y - 8, 0xFFFFD98A, 12));
      fx.add(FxBurstAt(f.x, f.y - 8, 0xFF3A332B, 10));
      if (rnd.nextDouble() < .35) {
        final got = give({'scrap': math.max(1, lvScale.round())});
        if (got.isNotEmpty) fx.add(FxFloatAt(f.x, f.y - 20, '고철 +${got['scrap']}', 0xFFFFE6A0));
      }
    }
  }

  /// 쉘터에 가장 가까운 괴물 (웹 urgentFoe)
  Foe? get urgentFoe {
    final D2 = defn;
    if (D2 == null) return null;
    final (cx, cy) = tileC0;
    Foe? best;
    var bd = 1e9;
    for (final f in D2.foes) {
      if (f.dead || f.delay > 0) continue;
      final d = math.sqrt(math.pow(f.x - cx, 2) + math.pow(f.y - cy, 2));
      if (d < bd) {
        bd = d;
        best = f;
      }
    }
    return best;
  }

  void tapFoe(Foe f) {
    addCombo();
    hurtFoe(f, tapPow * (fever > 0 ? 2 : 1));
  }

  /// 눌린 곳 가까이의 괴물 하나 (세계 좌표, 반지름 r) — 웹 strikeAt
  bool strikeAt(double x, double y, double r) {
    final D2 = defn;
    if (D2 == null) return false;
    Foe? best;
    var bd = r * r;
    for (final f in D2.foes) {
      if (f.dead || f.delay > 0) continue;
      final d = math.pow(f.x - x, 2) + math.pow(f.y - 10 - y, 2);
      if (d < bd) {
        bd = d.toDouble();
        best = f;
      }
    }
    if (best != null) {
      tapFoe(best);
      return true;
    }
    return false;
  }

  /// 문질러 베기 (웹 slashAt)
  void slashAt(double x, double y, double r, int nowMs) {
    final D2 = defn;
    if (D2 == null) return;
    var n = 0;
    for (final f in D2.foes) {
      if (f.dead || f.delay > 0 || nowMs - f.sl < 130) continue;
      if (math.pow(f.x - x, 2) + math.pow(f.y - 10 - y, 2) < r * r) {
        f.sl = nowMs.toDouble();
        hurtFoe(f, tapPow * .8 * (fever > 0 ? 2 : 1));
        n++;
      }
    }
    if (n > 0) addCombo();
    D2.trail.add((x, y, .25));
  }

  void endDefense(bool win) {
    final D2 = defn!;
    defn = null;
    S.rest['defs'] = num_('defs') + 1;
    if (win) {
      S.rest['defWins'] = num_('defWins') + 1;
      final q = math.max(.4, D2.hp / D2.max);
      final got = give({...scaleCost({'scrap': 25, 'parts': 12, 'plate': 5, 'fuel': 8}, lvScale * q), 'batt': q >= .8 ? 3 : 2});
      var gt = '';
      if (rnd.nextDouble() < .5 + q * .3) {
        final gg = S.lv >= 4 ? (rnd.nextDouble() < .35 ? 2 : 1) : S.lv >= 3 ? 1 : 0;
        final t = dropGear(gg);
        if (t != null) gt = ' · 장비 ${gear[t]!.n}';
      }
      if (D2.raid != null) {
        final r2 = give(scaleCost({'scrap': 30, 'food': 25, 'parts': 10, 'fuel': 10}, lvScale));
        gt += ' · ${D2.raid}의 물자 ${lootText(r2)}';
      }
      for (final id in svIds) {
        rec(id)!['xp'] = xpOf(id) + 25;
      }
      fx.add(FxNote('대형 재폭풍을 막아냈어요! 내구도 ${D2.hp.round()}%', '괴물 ${D2.kills}마리 · ${lootText(got)}$gt · 모두 신뢰 +25', ms: 7000));
    } else {
      final lost = <String, num>{};
      for (final k in baseMats) {
        final l = (have(k) * .15).floor();
        if (l > 0) {
          S.m[k] = have(k) - l;
          lost[k] = l;
        }
      }
      final ks = S.mods.keys.toList();
      for (var q = 0; q < math.min(2, ks.length); q++) {
        final t = slotTile(ks[rnd.nextInt(ks.length)]);
        S.ash['$t'] = <String, Object?>{'hp': tapPow * 3, 'max': tapPow * 3, 't': 0, 'stuck': true};
      }
      recalc();
      fx.add(FxNote('쉘터가 재에 뒤덮였어요', '잃은 자재 ${lost.isEmpty ? '없음' : lootText(lost)} · 모듈 일부가 멈췄어요. 두드려 걷어내요. 방벽과 랜턴탑을 키우면 더 잘 버텨요', ms: 7500));
    }
    fx.add(const FxDefense(false));
    crowRaidAfterDefense();
    deathAfterDefense(win, D2);
    _changed();
  }
}
