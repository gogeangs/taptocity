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

  /// 개인 이야기가 열릴 수 있는 때. 앱 전용 (2026-10-20): 첫 동네는 3장('고물상 세우기')부터 — 신뢰도가 먼저 차도 3장까지 기다린다
  bool get questsOpen => S.gen != 0 || mi >= stepI('고물상 세우기');

  /// 지금 걸음 (끝났거나 안 열렸으면 null)
  Map? qStep(int id) {
    final q = qOf(id), Q = quests[id];
    if (q == null || Q == null || Game._truthy(q['done'])) return null;
    final s = ((q['s'] as num?) ?? 0).toInt();
    return s < Q.steps.length ? Q.steps[s] : null;
  }

  /// 걸음 문구: 상황에 따라 바뀌는 문구가 있으면 그쪽 (웹 qSay — 말순: 철호가 이미 있으면)
  String qSay(Map st) {
    final a = st['alt'] as Map?;
    return a != null && hasSv((a['sv'] as num).toInt()) ? a['say'] as String : '${st['say']}';
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
    fx.add(FxNote('${survivors[id].name} · ${Q.t} ${s + 1}/${Q.steps.length}', qSay(Q.steps[s]), ms: 5200));
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
    // 같은 순간에 여럿이 열리면 알림 카드는 하나로 묶는다 (지도 가운데를 카드가 덮지 않게)
    final opened = <int>[];
    for (final id in svIds.toList()) {
      final Q = quests[id], r = rec(id);
      if (Q == null || r == null) continue;
      if (r['q'] == null && questsOpen && Game.trustLv(xpOf(id)) >= qUnlock) {
        r['q'] = <String, Object?>{'s': 0};
        svNew = true;
        opened.add(id);
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
    // 앱 전용 (2026-10-20): 열렸다는 카드를 지도 위에 띄우지 않는다. 위쪽 이야기 띠에 '새 이야기 N'을 달고, 알림은 한 줄만
    if (opened.isEmpty) return;
    final nw = qNewRaw;
    for (final id in opened) {
      if (!nw.contains(id)) nw.add(id);
    }
    fx.add(FxToast(opened.length == 1
        ? '${survivors[opened.first].name}의 이야기가 열렸어요 · 위쪽 띠의 ‘새 이야기’'
        : '${survivors[opened.first].name} 외 ${opened.length - 1}명의 이야기가 열렸어요 · 위쪽 띠의 ‘새 이야기’'));
  }

  /// 아직 읽지 않은 새 이야기 (저장: S.rest['qNew'] = [생존자 번호])
  List get qNewRaw {
    if (S.rest['qNew'] is! List) S.rest['qNew'] = <Object?>[];
    return S.rest['qNew'] as List;
  }

  /// 화면에 보일 새 이야기: 지금 쉘터에 있고 이야기가 끝나지 않은 사람만
  List<int> get qNew => [
        for (final x in (S.rest['qNew'] is List ? S.rest['qNew'] as List : const []))
          if (x is num && hasSv(x.toInt()) && qOf(x.toInt()) != null) x.toInt(),
      ];

  /// 그 사람의 이야기를 봤다 (화면을 그리는 중에도 부를 수 있게 알리지는 않는다)
  void qSeen(int id) {
    final l = S.rest['qNew'];
    if (l is! List || !l.contains(id)) return;
    l.remove(id);
    dirty = true;
  }
}
