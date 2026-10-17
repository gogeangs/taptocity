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
    fx.add(FxToast('${jo(matOf[k]!.n, '이', '가')} 쌓인 더미를 찾았어요 · 지도의 ✦를 두드려요'));
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
}
