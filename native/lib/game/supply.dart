// 보급 더미 (앱 시즌 1 다듬기, 2026-10-17):
// 지금 목표가 자재 하나 때문에 90초 넘게 막혀 있으면, 가까운 폐허 하나에 그 자재가 쌓인 '보급 더미'(✦)가 생긴다.
// 두드리면 모자란 양의 60%쯤을 세 번에 나눠 준다. 4분에 한 번까지. 기다리는 시간을 '할 일'로 바꾸는 장치.
part of 'engine.dart';

extension SupplyExt on Game {
  /// 지금 목표를 막고 있는 비용 (증축·새 모듈·등불 탑)
  Cost? get goalCost {
    if (tut != null) return null;
    final m = mission();
    if (m.done) return null;
    final txt = m.txt, hl = m.step?.hl ?? '';
    final mb = RegExp(r'mbuild"\]\[data-arg="(\d+)"').firstMatch(hl);
    if (mb != null) {
      final id = int.parse(mb.group(1)!);
      if (mods[id] == null || hasMod(id)) return null;
      return modBuildCost(id);
    }
    if (txt.contains('등불 탑')) return towerOpen && towerN < 5 ? towerCost : null;
    if (hl.contains('"shup"') || txt.contains('쉘터') || txt.contains('요새로') || txt.contains('불빛의 도시')) return shelterUpCost;
    return null;
  }

  /// 가장 많이 모자란 자재와 모자란 양 (창고 한도 안에서 모을 수 있는 것만)
  (String, num)? get goalLack {
    final c = goalCost;
    if (c == null || canPay(c)) return null;
    String? best;
    var bf = 0.0;
    num short = 0;
    for (final e in c.entries) {
      final need = e.value, h = have(e.key);
      if (need <= 0 || h >= need || matOf[e.key] == null || need > capOf(e.key)) continue;
      final f = (need - h) / need;
      if (f > bf) {
        bf = f;
        best = e.key;
        short = need - h;
      }
    }
    return best == null ? null : (best, short);
  }

  Map? get supply => S.rest['supply'] is Map ? S.rest['supply'] as Map : null;

  void tickSupply() {
    final sp = supply;
    if (sp != null) {
      if (!siteLive((sp['i'] as num).toInt())) {
        S.rest.remove('supply');
        _mapChanged();
      }
      return;
    }
    final lk = goalLack;
    if (lk == null || defn != null) {
      S.rest['lackS'] = 0;
      return;
    }
    final k = lk.$1;
    if (S.rest['lackK'] != k) {
      S.rest['lackK'] = k;
      S.rest['lackS'] = 0;
    }
    final s = num_('lackS') + 1;
    S.rest['lackS'] = s;
    final now = Game.nowMs();
    if (s < 90 || uiModal || now - num_('supplyAt') < 240000) return;
    var best = -1;
    var bd = 1e9;
    for (var j = 0; j < N; j++) {
      if (!siteLive(j)) continue;
      final d = dist(j);
      if (d < bd) {
        bd = d;
        best = j;
      }
    }
    if (best < 0) return;
    final n = math.max(matOf[k]!.tier == 2 ? 4 : 10, (lk.$2 * .6).ceil());
    S.rest['supply'] = <String, Object?>{'i': best, 'k': k, 'n': n};
    S.rest['supplyAt'] = now;
    S.rest['lackS'] = 0;
    sfx('chime');
    // 시스템 알림이 아니라 쉘터 사람이 자기 말투로 알려 준다 (바이블 말투 표). 그 사람이 없으면 '나'의 독백
    final say = supplySay(k);
    fx.add(FxNote(say.$1, '${say.$2}\n지도에서 ✦를 두드려요', ms: 5600));
    _mapChanged();
  }

  /// 보급 더미를 두드리면 한 묶음씩 (세 번이면 다 챙긴다)
  void supplyHit(int i) {
    final sp = supply;
    if (sp == null || (sp['i'] as num).toInt() != i) return;
    final k = sp['k'] as String;
    var n = (sp['n'] as num).toInt();
    final x = math.min(n, math.max(1, (n / 3).ceil()));
    loot({k: x}, i);
    n -= x;
    if (n <= 0) {
      S.rest.remove('supply');
      fx.add(FxFloat(i, '보급을 다 챙겼다', 0xFFFFE6A0, rise: 40));
      _mapChanged();
    } else {
      sp['n'] = n;
    }
  }

  /// 보급 더미를 알려 주는 사람과 한마디: 자재마다 그걸 알아볼 사람들, 앞사람부터 지금 무리에 있는 사람
  (String, String) supplySay(String k) {
    const lines = <String, List<(int, String)>>{
      'wood': [(6, '저쪽 무너진 창고에 각목이 그대로 있어. 가져다 쓰지.'), (0, '저기 목재 더미 봤어? 한 번에 날라 오자고.')],
      'scrap': [(0, '저 고물 더미, 쓸 만한 게 꽤 있구먼. 같이 가 보자고.'), (6, '저기 철근 무더기. 녹은 슬었어도 쓸 만해.')],
      'cloth': [(7, '저기… 천막 천이 한 무더기 있었어요. 아직 깨끗한 것도 있고요.'), (5, '저 집 장롱에 이불이 그대로더라. 뜯어다 쓰면 돼.')],
      'food': [(5, '저 집 찬장에 통조림이 줄줄이더라. 얼른 가져와, 국 끓이게.'), (3, '저기 가게에 과자 있어요! 진짜예요, 진짜 많아요!')],
      'parts': [(9, '저 건물 안쪽에 부품 상자가 남아 있을 거예요. …제가 본 게 맞다면요.'), (1, '아까 지나가다 봤는데요, 저기 부품 상자 통째로 있어요. 제가 먼저 갈게요!'), (0, '저 정비소 안에 부품이 굴러다니더구먼. 주워 오자고.')],
      'fuel': [(1, '저 앞 폐차들, 기름 아직 남아 있어요. 길은 제가 알아요!'), (8, '저 주유소, 탱크 하나는 멀쩡해요. 조심해서 빼 와요.')],
      'plate': [(6, '철판은 저 공사장 가설 울타리 뜯으면 돼. 가자.'), (0, '저 버스 차고에 철판이 몇 장 남았구먼.')],
      'rope': [(0, '저 정비소에 밧줄 타래가 남아 있더구먼. 가져다 쓰자고.'), (8, '저 건물 비상용 로프, 아직 걸려 있어요.')],
      'wire': [(9, '저쪽 배전함, 전선이 그대로예요. 벗겨 오면 쓸 수 있어요.'), (10, '저기 방송 장비 잔해요. 전선이라면 거기 한가득일걸요.')],
      'med': [(2, '저 약국 안쪽 선반 확인했어요. 아직 남은 게 있어요. 지금 가요.')],
      'batt': [(10, '저기 전파사 서랍, 아직 안 열어 봤죠? 건전지라면 거기부터예요.'), (3, '저기 장난감 가게요! 건전지 들어 있는 거 봤어요!')],
    };
    for (final (id, t) in lines[k] ?? const <(int, String)>[]) {
      if (hasSv(id) && !busy(id)) return (survivors[id].name, '“$t”');
    }
    return (pfSet ? pfName : '나', '저쪽 폐허 너머, ${jo(matOf[k]!.n, '이', '가')} 쌓여 있는 게 보였다.');
  }
}
