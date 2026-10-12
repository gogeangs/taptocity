// 4단계: 유물·장식·잔치·펫 (웹 index.html 4022–4106 장식, 4067–4084 유물, 4793–5016 펫, 5166–5180 잔치).
part of 'engine.dart';

/// 펫을 새로 만남 → 이름 짓기 창
class FxPetNew extends Fx {
  const FxPetNew(this.k);
  final String k;
}

const petKeys = ['dog', 'cat', 'crow', 'goat', 'hog', 'fox', 'turtle', 'owl', 'fennec', 'bot', 'bear'];
const collarColors = [0xFFD9483B, 0xFF3F6FA0, 0xFFE0B441, 0xFF6B8F4A, 0xFF8A5A9A, 0xFFF1ECE0];
const collarNames = ['빨강', '파랑', '노랑', '초록', '보라', '하양'];
const petXp = [0, 20, 60, 130, 250];
const setHope = {'park': 5, 'square': 4};
const feastCd = 20 * 60 * 1000, feastT = 600;

Map<String, Object?> petInfo(String k) => Map<String, Object?>.from(web.pets[k]!);
List<String> get petNormal => [for (final k in petKeys) if (petInfo(k)['hidden'] != true) k];

extension Living on Game {
  // ================= 유물 =================
  List<String> get relics => [for (final r in (S.rest['relics'] as List? ?? const [])) '$r'];
  List<String> get relicLeft => [for (final s in web.rsets) for (final it in s['items'] as List) if (!relics.contains(it)) it as String];
  bool relicSet(String k) {
    final s = web.rsets.where((x) => x['k'] == k).firstOrNull;
    return s != null && (s['items'] as List).every(relics.contains);
  }

  /// 유물 하나 얻기 (웹 findRelic). 받은 유물 이름 또는 null
  String? findRelic([int? tile]) {
    final left = relicLeft;
    if (left.isEmpty) return null;
    final it = left[rnd.nextInt(left.length)];
    gainRelic(it, tile: tile);
    return it;
  }

  void gainRelic(String it, {int? tile}) {
    if (relics.contains(it)) return;
    S.rest['relics'] = [...relics, it];
    final set = web.rsets.firstWhere((s) => (s['items'] as List).contains(it)), done = relicSet(set['k'] as String);
    if (tile != null) {
      fx.add(FxFloat(tile, '유물 발견!', 0xFFFFDC96, rise: 30));
      fx.add(FxBurst(tile, 0xFFE0B441, 20));
    }
    final have = (set['items'] as List).where(relics.contains).length;
    fx.add(FxNote('유물 · $it', '${web.rstory[it]}${done ? '\n‘${set['n']}’ 세트 완성! ${set['fx']}' : ' · ${set['n']} $have/3'}', ms: 6500));
    if (done) recalc();
    _changed();
  }

  // ================= 장식 =================
  Map<String, Object?> get deco {
    if (S.rest['deco'] is! Map) S.rest['deco'] = <String, Object?>{};
    return S.rest['deco'] as Map<String, Object?>;
  }

  int get decoHope {
    final c = <String, int>{};
    for (final v in deco.values) {
      c['$v'] = (c['$v'] ?? 0) + 1;
    }
    var h = 0;
    c.forEach((k, n) => h += ((web.deco[k]?['hope'] as num?) ?? 0).toInt() * math.min(3, n));
    return h;
  }

  /// 가까이 놓은 장식끼리 생기는 장소 (웹 decoSets)
  Map<String, int> decoSets() {
    final out = <String, int>{};
    final tiles = deco.keys.map(int.parse).toList();
    web.dsets.forEach((k, Z) {
      final need = [for (final n in Z['need'] as List) '$n'];
      for (final t in tiles) {
        if (deco['$t'] != need[0]) continue;
        final tx = t % W, ty = t ~/ W;
        final ok = need.skip(1).every((n) => tiles.any((u) => deco['$u'] == n && (u % W - tx).abs() <= 2 && (u ~/ W - ty).abs() <= 2));
        if (ok) {
          out[k] = t;
          break;
        }
      }
    });
    return out;
  }

  double get patrolM => decoSets().containsKey('watch') ? 1.3 : 1;
  List<int> decoFans(String k) => [for (final e in web.fav.entries) if (e.value == k) int.parse(e.key)];

  bool decoOk(int i) {
    final x = i % W - CX, y = i ~/ W - CY;
    return math.max(x.abs(), y.abs()) <= S.lv + 2 &&
        S.rev[i] == 1 &&
        i != C0 &&
        !modAt.containsKey(i) &&
        !(S.site[i] != null && S.site[i]!.c > 0) &&
        !S.camp.containsKey(i) &&
        S.ter[i] != T.water &&
        S.ter[i] != T.lm &&
        band?['tile'] != i &&
        !deco.containsKey('$i');
  }

  Cost decoCost(String k) => scaleCost({for (final e in (web.deco[k]!['cost'] as Map).entries) e.key as String: e.value as num});

  /// 장식 놓기 (웹 placeAt + decoReact)
  bool placeDeco(String k, int i) {
    if (!decoOk(i) || !pay(decoCost(k))) return false;
    deco['$i'] = k;
    fx.add(FxBurst(i, 0xFFFFD98A, 12));
    final fav = S.rest['favDone'] is Map ? S.rest['favDone'] as Map : (S.rest['favDone'] = <String, Object?>{});
    for (final id in decoFans(k)) {
      if (!hasSv(id) || fav['$id'] == 1) continue;
      fav['$id'] = 1;
      rec(id)!['xp'] = xpOf(id) + 30 * trustM;
      fx.add(FxToast('${jo(survivors[id].name, '이', '가')} ${jo(web.deco[k]!['n'] as String, '을', '를')} 좋아해요 · 신뢰 +30'));
    }
    final seen = S.rest['setsSeen'] is Map ? S.rest['setsSeen'] as Map : (S.rest['setsSeen'] = <String, Object?>{});
    for (final q in decoSets().keys) {
      if (seen[q] == 1) continue;
      seen[q] = 1;
      final Z = web.dsets[q]!;
      fx.add(FxNote("'${Z['n']}'이(가) 생겼어요", '${Z['d']}', ms: 5200));
    }
    recalc();
    _mapChanged();
    _changed();
    return true;
  }

  void removeDeco(int i) {
    final k = deco['$i'];
    if (k == null) return;
    deco.remove('$i');
    give(scaleCost(decoCost('$k'), .5));
    recalc();
    _mapChanged();
    _changed();
  }

  // ================= 마을 잔치 =================
  bool get feastOpen => S.lv >= 3 || S.gen != 0;
  Cost get feastCost => scaleCost({'food': 120, 'wood': 80}, lvScale);
  int get feastLeftMs => math.max(0, num_('feastAt').toInt() + feastCd - DateTime.now().millisecondsSinceEpoch);
  bool holdFeast() {
    if (!feastOpen || feastLeftMs > 0 || !pay(feastCost)) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    S.rest['feastAt'] = now;
    S.rest['feasts'] = num_('feasts') + 1;
    S.rest['feastEnd'] = now + feastT * 1000;
    S.buff = <String, Object?>{'k': 'all', 'm': 1.25, 't': feastT, 'label': '마을 잔치'};
    for (final id in svIds) {
      rec(id)!['xp'] = xpOf(id) + 40;
    }
    for (final k in pets.keys) {
      petGain(k, 5);
    }
    fx.add(FxBurst(C0, 0xFFFFD98A, 30));
    final who = svIds.toList();
    final a = who.isEmpty ? '' : survivors[who[rnd.nextInt(who.length)]].name;
    fx.add(FxNote('마을 잔치가 열렸어요!', '${a.isNotEmpty ? '$a: “이렇게 배불리 먹어 보는 게 얼마 만이에요.” · ' : ''}10분간 모든 생산 +25%'));
    recalc();
    _changed();
    return true;
  }

  // ================= 펫 =================
  Map<String, Map> get pets {
    if (S.rest['pets'] is! Map) S.rest['pets'] = <String, Object?>{};
    return {for (final e in (S.rest['pets'] as Map).entries) e.key as String: e.value as Map};
  }

  Map get _petsRaw {
    if (S.rest['pets'] is! Map) S.rest['pets'] = <String, Object?>{};
    return S.rest['pets'] as Map;
  }

  String? get petOn => S.rest['petOn'] as String?;
  bool get petsOpen => S.gen != 0 || (S.lv >= 2 && S.sv.length >= 2);
  int petLv(String k) {
    final x = ((pets[k]?['xp'] as num?) ?? 0);
    var l = 1;
    for (var q = 1; q < petXp.length; q++) {
      if (x >= petXp[q]) l = q + 1;
    }
    return l;
  }

  double petMul(String k) => 1 + .25 * (petLv(k) - 1);
  bool petHere(String k) {
    final p = pets[k];
    return p != null && (p['away'] == null || p['away'] == false);
  }

  double petM(String k) => petHere(k) ? petMul(k) * (petOn == k ? 1 : .5) : 0;
  String petName(String k) => (pets[k]?['n'] as String?) ?? (petInfo(k)['def'] as String);
  String petStory(String k, String t) => t.replaceAll('{n}', petName(k));

  void petGain(String k, num x) {
    final p = _petsRaw[k];
    if (p is! Map) return;
    final l0 = petLv(k);
    final pair = petInfo(k)['pair'] as int;
    p['xp'] = ((p['xp'] as num?) ?? 0) + x * (hasSv(pair) ? 1.5 : 1);
    final l1 = petLv(k);
    if (l1 > l0) {
      fx.add(FxNote('${jo(petName(k), '과', '와')} 더 친해졌어요 · 친밀도 $l1', petStory(k, (petInfo(k)['story'] as List)[l1 - 1] as String), ms: 6000));
      recalc();
    }
  }

  void petAdopt(String k, {bool quiet = false}) {
    if (pets.containsKey(k)) return;
    _petsRaw[k] = <String, Object?>{'n': petInfo(k)['def'], 'xp': 0, 'c': petKeys.indexOf(k) % collarColors.length, 'at': DateTime.now().millisecondsSinceEpoch};
    S.rest['petOn'] ??= k;
    if (k == 'dog') S.rest['dog'] = 1;
    recalc();
    if (!quiet) fx.add(FxPetNew(k));
    _changed();
  }

  void petRename(String k, String name, int c) {
    final p = _petsRaw[k];
    if (p is! Map) return;
    final first = p['named'] != 1;
    final v = name.replaceAll(RegExp('[<>&"\'`]'), '').trim();
    p['n'] = v.isEmpty ? petInfo(k)['def'] : v.substring(0, math.min(8, v.length));
    p['c'] = c;
    p['named'] = 1;
    if (first) {
      fx.add(FxNote('${jo(p['n'] as String, '이', '가')} 식구가 됐어요', '${petOn == k ? '랜턴 곁을 따라다녀요. ' : ''}지도에서 누르면 쓰다듬고, 두 번 누르면 자세히 볼 수 있어요', ms: 6000));
    }
    _changed();
  }

  Cost petFeedCost(String k) => scaleCost(k == 'bot' ? {'fuel': 5} : {'food': 8}, math.max(1, lvScale * .8));
  int petFedLeft(String k) => math.max(0, (((pets[k]?['fedT'] as num?) ?? 0) + 120000 - DateTime.now().millisecondsSinceEpoch) ~/ 1000);
  bool petFeed(String k) {
    final p = _petsRaw[k];
    if (p is! Map || petFedLeft(k) > 0 || !pay(petFeedCost(k))) return false;
    p['fedT'] = DateTime.now().millisecondsSinceEpoch;
    petGain(k, 12);
    _changed();
    return true;
  }

  /// 쓰다듬기: 8초에 한 번 친밀도 +2. 친밀도가 올랐으면 true
  bool petPat(String k) {
    final p = _petsRaw[k];
    if (p is! Map) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (p['patT'] is num && now - (p['patT'] as num) <= 8000) return false;
    p['patT'] = now;
    petGain(k, 2);
    _changed();
    return true;
  }

  void petCompanion(String k) {
    if (!petHere(k)) return;
    S.rest['petOn'] = k;
    recalc();
    _changed();
  }

  // ---------- 떠돌이 동물 ----------
  Map? get stray => S.rest['stray'] is Map ? S.rest['stray'] as Map : null;
  bool get strayVis {
    final s = stray;
    if (s == null) return false;
    return !(s['k'] == 'fox' || s['k'] == 'owl') || isNight;
  }

  String? _strayPick() {
    final own = pets;
    for (final k in petKeys) {
      final P = petInfo(k);
      if (P['region'] != null && P['region'] == S.region && !own.containsKey(k) && num_('rmi') >= 2) return k;
    }
    if (isNight && !own.containsKey('fox') && petNormal.where(own.containsKey).length >= 3 && num_('nights') >= 5) return 'fox';
    if (isNight && !own.containsKey('owl') && lmOn('library')) return 'owl';
    final left = petNormal.where((k) => !own.containsKey(k) && petInfo(k)['region'] == null).toList();
    return left.isEmpty ? null : left[rnd.nextInt(left.length)];
  }

  int _strayTile(String k) {
    if (k == 'owl') {
      for (final e in S.lm.entries) {
        if (landmarks[e.value.k].key == 'library' && S.rev[e.key] == 1) {
          final c = nb4(e.key).where((j) => S.rev[j] == 1 && S.ter[j] != T.water && !siteLive(j) && !S.camp.containsKey(j)).toList();
          if (c.isNotEmpty) return c.first;
        }
      }
    }
    final c = <int>[];
    for (var i = 0; i < N; i++) {
      if (S.rev[i] == 0 || isSlot(i) || S.ter[i] == T.water || siteLive(i) || S.camp.containsKey(i) || modAtTile(i) != null || S.ter[i] == T.lm) continue;
      final d = dist(i);
      if (d < 3 || d > 10) continue;
      c.add(i);
    }
    return c.isEmpty ? -1 : c[rnd.nextInt(c.length)];
  }

  bool _straySpawn() {
    final k = _strayPick();
    if (k == null) return false;
    final i = _strayTile(k);
    if (i < 0) return false;
    S.rest['stray'] = <String, Object?>{'k': k, 'i': i, 'n': 0, 'need': k == 'fox' || k == 'owl' ? 2 : 3, 't': 0};
    fx.add(FxBurst(i, 0xFFFFE6BE, 10));
    final lib = landmarks.where((l) => l.key == 'library').firstOrNull;
    fx.add(FxNote(
        k == 'fox' ? '재 위에 은빛 발자국이 이어져 있어요' : k == 'owl' ? '${lib != null ? lmText(landmarks.indexOf(lib), S.region)[0] : '도서관'} 쪽에서 부엉, 부엉 소리가 들려요' : '어디선가 ‘${petInfo(k)['snd']}’ 소리가 들려요',
        '지도에 찍힌 발자국을 찾아가 눌러 봐요',
        ms: 6000));
    _mapChanged();
    return true;
  }

  Cost strayCost(String k) => scaleCost(k == 'bot' ? {'fuel': 4} : {'food': 6}, math.max(1, lvScale * .8));
  int get strayWait => math.max(0, ((((stray?['t'] as num?) ?? 0) - DateTime.now().millisecondsSinceEpoch) / 1000).ceil());

  /// 먹이 두고 오기. 마지막이면 식구가 된다
  bool strayFeed() {
    final s = stray;
    if (s == null || strayWait > 0 || !pay(strayCost(s['k'] as String))) return false;
    s['n'] = ((s['n'] as num?) ?? 0) + 1;
    s['t'] = DateTime.now().millisecondsSinceEpoch + 20000;
    final k = s['k'] as String;
    if ((s['n'] as num) >= ((s['need'] as num?) ?? 3)) {
      S.rest['stray'] = null;
      S.rest['strayT'] = 300 + rnd.nextDouble() * 120;
      petAdopt(k);
    } else {
      final hid = petInfo(k)['hidden'] == true;
      fx.add(FxToast(k == 'bot' ? '삐빅… 연료를 받아 들였어요 · ${s['n']}/${s['need']}' : '${jo(hid ? '그 동물' : petInfo(k)['n'] as String, '이', '가')} 먹이를 먹었어요 · ${s['n']}/${s['need']}'));
    }
    _mapChanged();
    _changed();
    return true;
  }

  /// 동행 펫의 재주 (웹 tickPets의 앞부분). 받은 것과 소리, 펫 위치는 화면에서 정한다
  void _tickPets() {
    final own = pets;
    if (S.rest['dog'] != null && S.rest['dog'] != 0 && !own.containsKey('dog')) {
      petAdopt('dog', quiet: true);
      _petsRaw['dog']['xp'] = 40;
      _petsRaw['dog']['named'] = 1;
    }
    if (petOn != null && !pets.containsKey(petOn)) S.rest['petOn'] = null;
    final ex = expMap;
    for (final q in pets.keys) {
      final p = _petsRaw[q] as Map;
      final aw = p['away'];
      if (aw == 'ug' && ug == null) {
        p['away'] = false;
      } else if (aw != null && aw != false && aw != 'ug' && !(ex[aw] is Map && ex[aw]!['pet'] == q)) {
        p['away'] = false;
      }
    }
    final k = petOn;
    if (k != null && petHere(k)) {
      S.rest['petXT'] = num_('petXT') + 1;
      if (num_('petXT') >= 30) {
        S.rest['petXT'] = 0;
        petGain(k, 1);
      }
      S.rest['petAT'] = (S.rest['petAT'] == null ? 60 : num_('petAT')) - 1;
      if (num_('petAT') <= 0) {
        final m = petMul(k), sc = lvScale;
        Map<String, num>? o;
        var msg = '';
        S.rest['petAT'] = 90 + rnd.nextDouble() * 40;
        switch (k) {
          case 'dog':
            o = {baseMats[rnd.nextInt(6)]: (3 * sc * m).round()};
            msg = '멍!';
          case 'crow':
            o = rnd.nextDouble() < .2 * m ? {'wire': 1} : {'parts': (2 * sc * m).round()};
            msg = '까악!';
          case 'goat' when !isNight:
            o = {'food': (4 * sc * m).round()};
            msg = '메에~';
          case 'fennec':
            o = {'fuel': (3 * sc * m).round()};
            msg = '캥!';
          case 'bot':
            o = rnd.nextDouble() < .25 * m ? {'wire': 1} : {'parts': (2 * sc * m).round()};
            msg = '삐빅!';
          case 'bear' when !isNight:
            o = {'food': (5 * sc * m).round()};
            msg = '끄응~';
          case 'owl' when isNight:
            const r = [
              {'rope': 1},
              {'wire': 1},
              {'med': 1},
              {'plate': 2},
            ];
            o = r[rnd.nextInt(r.length)];
            msg = '부엉!';
            S.rest['petAT'] = 150;
          case 'fox' when isNight:
            var best = -1;
            var bd = 1e9;
            for (final i in frontier) {
              if (S.sig.containsKey(i) || S.ter[i] == T.diary || S.ter[i] == T.trace) {
                if (dist(i) < bd) {
                  bd = dist(i);
                  best = i;
                }
              }
            }
            if (best < 0) {
              for (final i in frontier) {
                if (dist(i) < bd) {
                  bd = dist(i);
                  best = i;
                }
              }
            }
            if (best >= 0) {
              reveal(best);
              fx.add(FxFloat(best, '여우가 길을 찾았어요', 0xFFD7E6FF, rise: 30));
            }
            S.rest['petAT'] = 100;
        }
        if (o != null) {
          petTrick = (k, o, msg);
          give(o);
          _changed();
        }
      }
    }
    if (pets.containsKey('cat') && petHere('cat')) {
      final ph = phase;
      if (!isNight && ph > dayLen - 25 && ph <= dayLen - 24 && (bigNightNext || S.rest['raid'] != null) && S.rest['catW'] != S.rest['nights']) {
        S.rest['catW'] = S.rest['nights'];
        fx.add(FxNote('${jo(petName('cat'), '이', '가')} 털을 곤두세워요', '오늘 밤 큰 재폭풍이 올 것 같아요. 방벽과 랜턴탑을 점검해요', ms: 5000));
      }
    }
    if (!petsOpen) return;
    final s = stray;
    if (s != null) {
      if ((s['k'] == 'fox' || s['k'] == 'owl') && !isNight && s['n'] == 0) {
        S.rest['stray'] = null;
        S.rest['strayT'] = 20;
        _mapChanged();
      }
      return;
    }
    S.rest['strayT'] = (S.rest['strayT'] == null ? 240 : num_('strayT')) - 1;
    if (num_('strayT') <= 0 && !_straySpawn()) S.rest['strayT'] = 60;
  }

  void _petEff(Map<String, double> e) {
    for (final k in pets.keys) {
      final P = petInfo(k), m = petM(k);
      if (m == 0) continue;
      final ef = P['eff'] as String;
      e[ef] = (e[ef] ?? 0) + (P['v'] as num) * m;
      if (hasSv(P['pair'] as int)) e['hope'] = (e['hope'] ?? 0) + 3;
    }
  }

  double get petDef => 1 - .15 * petM('hog');
  double get petAsh => 1 + .3 * petM('cat');

  /// 아이 돌보기를 한 사람의 일 (웹 CARE_JOB)
  String? careJob(int id) {
    final R = roleOf(id);
    if (R.contains('mech') || R.contains('sci')) return 'mech';
    if (R.contains('farm') || R.contains('cook')) return 'farm';
    if (R.contains('scout') || R.contains('drive') || R.contains('art')) return 'scout';
    return null;
  }

  /// 웹 extraEff (4108)
  void _extraEff(Map<String, double> e) {
    for (final s in web.rsets) {
      final ef = s['e'];
      if (ef is Map && relicSet(s['k'] as String)) ef.forEach((k, v) => e['$k'] = (e['$k'] ?? 0) + (v as num));
    }
    _kidEff(e);
    _petEff(e);
    _towerEff(e);
    if (num_('feastEnd') > DateTime.now().millisecondsSinceEpoch) e['hope'] = (e['hope'] ?? 0) + 8;
    e['hope'] = (e['hope'] ?? 0) + decoHope;
    for (final q in decoSets().keys) {
      e['hope'] = (e['hope'] ?? 0) + (setHope[q] ?? 0);
    }
    _townEff(e);
    if (S.gen > 0) {
      e['global'] = (e['global'] ?? 0) + .1 * S.gen;
      e['tap'] = (e['tap'] ?? 0) + .1 * S.gen;
    }
  }
}
