// 6단계: 개인 이야기 — 신뢰도 3이 되면 열리는 사람마다의 세 걸음 (찾기·지하·원정·데려오기·건네기), 끝나면 전용 장비.
// 웹 index.html 3388–3474.
part of 'engine.dart';

class QuestInfo {
  QuestInfo(Map m)
      : t = m['t'] as String,
        gear = m['gear'] as String,
        steps = [for (final s in m['steps'] as List) s as Map],
        end = [for (final l in m['end'] as List) Line.of(l)!];
  final String t, gear;
  final List<Map> steps;
  final List<Line> end;
}

final Map<int, QuestInfo> quests = {for (final e in web.quests.entries) int.parse(e.key): QuestInfo(e.value)};
const qUnlock = web.qUnlock;

extension Quest on Game {
  Map? qOf(int id) => rec(id)?['q'] as Map?;

  /// 지금 걸음 (끝났거나 안 열렸으면 null)
  Map? qStep(int id) {
    final q = qOf(id), Q = quests[id];
    if (q == null || Q == null || Game._truthy(q['done'])) return null;
    final s = ((q['s'] as num?) ?? 0).toInt();
    return s < Q.steps.length ? Q.steps[s] : null;
  }

  String qStepTxt(Map st) => switch (st['k']) {
        'find' => '지하 ${st['f']}층 이상에서 ‘${st['item']}’ 찾기 (함께 내려가요)',
        'ug' => '함께 지하 ${st['f']}층까지 내려가기',
        'exp' => '함께 원정 한 번 다녀오기',
        'bond' => '${jo(hasSv((st['id'] as num).toInt()) ? survivors[(st['id'] as num).toInt()].name : '???', '을', '를')} 쉘터에 데려오기',
        _ => '물자 건네기',
      };

  Cost qCost(Map st) => {for (final e in (st['cost'] as Map? ?? const {}).entries) e.key as String: e.value as num};

  void qAdvance(int id) {
    final q = qOf(id), Q = quests[id];
    if (q == null || Q == null || Game._truthy(q['done'])) return;
    final s = ((q['s'] as num?) ?? 0).toInt() + 1;
    q['s'] = s;
    sfx('chime');
    if (s >= Q.steps.length) {
      q['done'] = true;
      addGear(Q.gear);
      S.hopeB += 3;
      recalc();
      talk(Q.end, tag: '${survivors[id].name}의 이야기 · 끝');
      fx.add(FxNote('${survivors[id].name}의 이야기 완결', '전용 장비 ‘${gear[Q.gear]?.n ?? Q.gear}’ · 희망 +3', ms: 5000));
      _changed();
      return;
    }
    fx.add(FxNote('${survivors[id].name} · ${Q.t} ${s + 1}/${Q.steps.length}', '${Q.steps[s]['say']}', ms: 5200));
    _changed();
  }

  /// 건네기 걸음
  bool qGive(int id) {
    final st = qStep(id);
    if (st == null || st['k'] != 'give' || !pay(qCost(st))) return false;
    qAdvance(id);
    return true;
  }

  /// 매초: 열기, 데려오기·지하 걸음 확인 (웹 tickQuests)
  void _tickQuests() {
    for (final id in svIds.toList()) {
      final Q = quests[id], r = rec(id);
      if (Q == null || r == null) continue;
      if (r['q'] == null && Game.trustLv(xpOf(id)) >= qUnlock) {
        r['q'] = <String, Object?>{'s': 0};
        fx.add(FxNote('${survivors[id].name}의 이야기가 열렸어요', '‘${Q.t}’ · 생존자 수첩에서 확인해요', ms: 5000));
        dirty = true;
        continue;
      }
      final st = qStep(id);
      if (st == null) continue;
      if (st['k'] == 'bond' && hasSv((st['id'] as num).toInt())) {
        qAdvance(id);
      } else if (st['k'] == 'ug' && ((((ugRec['bestWith'] as Map?) ?? const {})['$id'] as num?) ?? 0) >= (st['f'] as num)) {
        qAdvance(id);
      }
    }
  }
}
