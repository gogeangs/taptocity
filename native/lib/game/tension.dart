// 앱 전용 긴장감 (2026-10-17): 밤 방어 실패의 부상, 정답 없는 선택, 잘못된 의심과 사과, 불빛 밖의 밤길.
// 웹(index.html)에는 없다. 튜토리얼·첫 밤(재폭풍을 배우기 전)과 판잣집 전에는 일어나지 않는다.
// 모든 상태는 S.rest와 생존자 기록(rec)에 둔다: 'hurtBy'·'slow'(부상), 'choice'·'choiceDay'·'choiceTry'·'choice_med'·'medCb'·'medKin'(선택),
// 'sorry_<id>'·'sorryXp_<id>'(사과), 'darkWarnN'·'darkHurtN'(불빛 밖), stat.hurtN·stat.choiceN(기록).
part of 'engine.dart';

/// 정답 없는 선택 창을 띄운다 (내용은 g.choiceView())
class FxChoice extends Fx {
  const FxChoice();
}

/// 선택 창에 보일 것
class ChoiceView {
  const ChoiceView(this.tag, this.title, this.lines, this.opts);
  final String tag, title;
  final List<Line> lines;

  /// (고르는 글, 작은 설명)
  final List<(String, String)> opts;
}

/// 부를 때 쓰는 이름: 성을 뗀다 (박만수 → 만수). 마리아처럼 성이 없는 이름은 그대로
String _tnShort(int id) {
  final n = survivors[id].name;
  return n.length == 3 && id != 19 ? n.substring(1) : n;
}

/// 받침이 있으면 '이'를 붙인 부름 (하늘 → 하늘이, 철호 → 철호)
String _tnCall(String n) => jo(n, '이', '');

/// 여자인 생존자 (부르는 말: 할머니·아줌마·언니·누나·이모)
const Set<int> _tnFemale = {2, 3, 4, 5, 7, 11, 13, 14, 16, 19, 21, 23, 25, 26, 28};

/// 남을 가리켜 부르는 이름: 말하는 사람(by: 생존자 번호, 그 밖은 '나')과 듣는 사람의 나이로 높인다.
/// 아이는 하늘이·진이, 손아랫사람은 이름만, 손윗사람은 일흔부터 할머니·할아버지, 쉰부터 아저씨·아줌마, 서른부터 씨.
/// 아이가 부를 땐 마흔부터 아저씨·아줌마, 서른부터 삼촌·이모, 그 아래는 오빠·언니(하늘)·형·누나(진). '나'는 예순부터만 높인다 (만수 아저씨)
String callName(Object? by, int id) {
  if (id < 0 || id >= survivors.length) return '누군가';
  final n = _tnShort(id), a = survivors[id].age, f = _tnFemale.contains(id);
  if (a < 20) return _tnCall(n);
  final sp = by is int && by >= 0 && by < survivors.length ? by : null;
  if (sp == null) return a >= 70 ? '$n ${f ? '할머니' : '할아버지'}' : a >= 60 ? '$n ${f ? '아줌마' : '아저씨'}' : n;
  if (sp == id) return n;
  final sa = survivors[sp].age;
  if (sa >= a) return n;
  if (a >= 70) return '$n ${f ? '할머니' : '할아버지'}';
  if (sa < 20) {
    if (a >= 40) return '$n ${f ? '아줌마' : '아저씨'}';
    if (a >= 30) return '$n ${f ? '이모' : '삼촌'}';
    final sf = _tnFemale.contains(sp);
    return '$n ${f ? (sf ? '언니' : '누나') : (sf ? '오빠' : '형')}';
  }
  if (a >= 50) return '$n ${f ? '아줌마' : '아저씨'}';
  if (a >= 30) return '$n 씨';
  return n;
}

/// 부르는 말 (하늘아, 철호야, 만수 아저씨): 이름만 부르면 아/야를 붙인다
String callVoc(Object? by, int id) {
  if (id < 0 || id >= survivors.length) return '저기';
  final c = callName(by, id), n = _tnShort(id);
  return c == n || c == _tnCall(n) ? jo(n, '아', '야') : c;
}

/// 대형 재폭풍을 못 막고 다친 사람의 대답
const Map<int, String> _tnHurtReply = {
  0: '허허, 늙은 몸이 재 바람 한 번에 이 꼴이구먼. 하루면 된다고.',
  1: '이 정도는 배달하다 넘어진 거에 비하면 아무것도 아니에요.',
  2: '제가 제일 잘 알아요. 하루면 돼요. 붕대는 제가 감을게요.',
  3: '…하나도 안 아파요. 진짜예요. …조금만 아파요.',
  4: '아이고, 이 할미 걱정은 마래이. 하루 누버 있으믄 된다.',
  5: '내 걱정 말고 국솥이나 봐. 내일은 내가 다시 끓인다.',
  6: '…괜찮다니까. 방벽은 내일 내가 다시 세울게.',
  7: '…괜찮아요. 오른손은 멀쩡하니까 그림은 그릴 수 있어요.',
  8: '별거 아니에요. 내일이면 다시 나가요.',
  9: '…이번엔 도망치지 않았어요. 그거면 됐어요.',
  10: '오늘 밤 방송은 쉬어야겠네요. 목소리는 멀쩡한데, 팔이 말을 안 들어서요.',
  11: '내일 예보는 누워서 할게요. 맑음, 이번엔 정말로요.',
  12: '이 늙은이 태엽이 좀 풀렸을 뿐일세. 하루면 다시 감기겠지.',
  13: '…버틸 만해요. 자리를 지킨 값이니까요.',
  14: '약초는 제가 알아요. 하루면 아물 거예요.',
  15: '…용접하다 덴 것보다 낫네. 하루면 돼.',
  16: '구조대가 구조받는 신세네요. 하루만 쉴게요.',
  17: '…별거 아니야. 까마귀 땐 이보다 더한 것도 혼자 버텼어.',
};

/// 불빛 밖에서 발을 헛디딘 사람
const Map<int, String> _tnDarkReply = {
  0: '허허, 어둠에 발을 헛디뎠구먼. 밤길은 사람을 잡아먹는다니까.',
  1: '골목은 다 외우는데… 깜깜하니까 소용없네요.',
  3: '…넘어졌어요. 안 울어요. 진짜로요.',
  4: '아이고 내 발목이야. 밤길은 이래서 무섭다 카이.',
  5: '에이, 깜깜해서 돌부리에 걸렸어. 하루 쉬면 돼.',
  6: '…발밑을 못 봤다. 내가 한 말인데.',
  12: '눈이 어두운 늙은이가 밤길에 나선 게 잘못일세.',
  15: '…불꽃 없이는 한 치 앞도 안 보이네.',
  17: '…씨. 아무것도 안 보였어.',
};

/// 다쳐서 누운 사람에게 선물을 내밀면
const Map<int, String> _tnGiftHurt = {
  0: '허허, 누워서 받을 순 없지. 다 나으면 받겠구먼.',
  3: '…지금은 입맛이 없어요. 다 나으면 주세요.',
  4: '아이고, 누워서 무슨 선물이고. 다 낫거든 도.',
  5: '됐어, 누워서 받는 건 체질에 안 맞아. 일어나면 줘.',
  6: '…누워서 받긴 그렇다. 다 나으면.',
  10: '목소리 돌아오면 받을게요. 지금은 좀 쉴래요.',
  12: '누운 채로 받을 순 없지. 다 나으면 받겠네.',
  15: '…지금 말고. 일어나면.',
  17: '…지금 말고. 다 나으면.',
};

/// 약을 받은 사람
const Map<int, String> _tnMedThanks = {
  0: '고맙구먼. 이 빚은 운전대로 갚겠구먼.',
  3: '…고마워요. 쓴 거 다 참고 먹었어요.',
  4: '이 할미를 먼저 챙기다이… 고맙데이.',
  5: '쓰다, 써. …그래도 고마워.',
  6: '…빚졌다. 일어나면 갚을게.',
  10: '고마워요. 내일 밤 방송은 당신한테 바칠게요.',
  12: '고맙네. 이 늙은이 태엽을 또 감아 주는구먼.',
  15: '…빚졌어.',
  17: '…왜 나야. …고마워.',
};

/// 약을 양보한 사람 (고른 뒤)
const Map<int, String> _tnMedAfter = {
  0: '잘 골랐구먼. 나는 하루 더 누워 있으면 그만이구먼.',
  3: '…괜찮아요. 저 금방 나아요.',
  4: '잘했다. 이 할미는 쑥찜이면 된다.',
  5: '잘했어. 난 원래 잘 안 죽어.',
  6: '…잘했다. 나는 버틴다.',
  10: '잘했어요. 저는 노래 한 곡이면 나아요.',
  12: '잘했네. 늙은이는 기다리는 데 이골이 났다네.',
  15: '…됐어. 버틸 만해.',
  17: '…그럴 줄 알았어. 괜찮아.',
};

/// 약이 하나뿐일 때 먼저 양보하는 말 (고르기 전)
const Map<int, String> _tnMedYield = {
  0: '허허, 나야 하루 더 누워 있으면 그만이구먼.',
  3: '…저 진짜 괜찮아요.',
  4: '나는 괜찮다. 약은 젊은 사람 먼저 주이소.',
  5: '난 국 한 그릇이면 낫는다. 그거 딴 사람 줘.',
  6: '…난 됐어. 그거 저쪽 줘.',
  17: '…난 필요 없어. 원래 혼자 낫는 거야.',
};

/// 국이 모자란 밤: 아이들 먼저라 서운한 어른
const Map<int, String> _tnSoupGrumble = {
  0: '허허, 애들 먹는 거 보니 배부르구먼. …그래도 허리띠는 한 칸 졸라야겠어.',
  1: '배달은 배가 든든해야 빠른데… 뭐, 오늘은 참을게요.',
  6: '…빈속으로 방벽 올리라고? 알았다. 내일은 좀 늦을 거다.',
  8: '…알겠어요. 내일 순찰은 좀 짧게 돌게요.',
  12: '늙은이 배는 금방 고프다네. …허나 애들 먼저가 맞지.',
  15: '…빈속으론 불꽃이 안 서. 알아서 해.',
};

/// 국이 모자란 밤: 일하는 사람 먼저라 든든한 어른
const Map<int, String> _tnSoupThanks = {
  0: '든든하구먼. 내일은 해 뜨자마자 시동 걸자고.',
  1: '든든하네요! 내일은 두 배로 뛸게요.',
  6: '…고맙다. 내일 방벽은 두 배로 올린다.',
  8: '든든하네요. 내일 순찰은 끝까지 돌게요.',
  12: '고맙네. 배가 부르니 손이 덜 떨리는구먼.',
  15: '…배부르니 불꽃이 선다.',
};

/// 잘못 의심받은 사람의 서운한 말 / 사과를 받는 말
const Map<int, String> _tnAccused = {
  1: '…그 밧줄, 제가 타고 내려갈 줄이었어요. 제가 왜 끊어요.',
  3: '…저 아니라고 했잖아요.',
  6: '…내가 그렇게 보였냐.',
  9: '…또 저군요. 도망친 사람은 계속 의심받는 거겠죠.',
  14: '…이 동네 사람이 아니라서 그런 거죠? 괜찮아요. 익숙해요.',
  15: '…그래. 불꽃 다루는 놈이 제일 만만하지.',
  17: '…역시. 다들 나부터 의심하지.',
};
const Map<int, String> _tnForgive = {
  1: '에이, 됐어요. 대신 다음 원정 길은 제가 고를게요.',
  3: '…불 하나 더 켜 주면 용서해 줄게요.',
  6: '…됐다. 공구 정리나 같이 하자.',
  9: '…아니에요. 저라도 저를 의심했을 거예요. 물어봐 줘서… 고마워요.',
  14: '약초 차 한 잔 끓여 놨어요. 같이 마셔요. 그럼 다 잊을게요.',
  15: '…됐어. 용접 불 좀 같이 봐 줘. 그거면 돼.',
  17: '…됐어. 다음엔 먼저 물어봐.',
};

/// 칸의 세계 좌표 (화면 쪽 tileC와 같은 식)
(double, double) _tnPos(int i) {
  final x = i % W, y = i ~/ W;
  return ((x - y) * TW / 2, (x + y + 1) * TH / 2);
}

extension Tension on Game {
  /// 이 긴장 장치들이 켜지는 때: 튜토리얼·안내가 끝나고, 재폭풍 밤을 배우고, 판잣집이 된 뒤 (새 동네는 처음부터).
  /// 앱 전용 (2026-10-20): 첫 동네는 4장에서 은호가 온 뒤('첫 원정 보내기' 걸음부터) — 기능이 이야기와 함께 하나씩 열리게
  bool get tensionOn => tut == null && onb != 1 && ashLearned && (S.gen != 0 || (S.lv >= 2 && mi >= stepI('첫 원정 보내기')));
  int get dayN => num_('day').toInt();

  bool _tnHere(int id) => hasSv(id) && !Game._truthy(rec(id)!['away']) && !isDead(id);
  bool _tnHurt(int id) => ((rec(id)?['hurt'] as num?) ?? 0) > 0;
  int _tnId(Object? v) => (v as num?)?.toInt() ?? -1;

  void _tnCount(String k) {
    final st = _stat;
    st[k] = ((st[k] as num?) ?? 0) + 1;
  }

  /// 다치게 한다 (이미 더 오래 다쳐 있으면 그대로)
  void _tnWound(int id, double sec, String by) {
    final r = rec(id);
    if (r == null) return;
    r['hurt'] = math.max(((r['hurt'] as num?) ?? 0).toDouble(), sec);
    r['hurtBy'] = by;
    if (by != 'sick') _tnCount('hurtN');
  }

  void _tnXp(int id, num d, List<String> out) {
    final r = rec(id);
    if (r == null) return;
    final x0 = xpOf(id), v = math.max(0, x0 + d);
    r['xp'] = v;
    final real = (v - x0).round();
    out.add('${_tnShort(id)} 신뢰 ${real >= 0 ? '+' : ''}$real');
  }

  /// 다친 사람에게 선물을 내밀었을 때의 말
  String hurtGiftLine(int id) => _tnGiftHurt[id] ?? '다 나으면 받을게요. 지금은 좀 쉴래요.';

  // ================= A. 밤 방어 실패 → 한 사람 부상 =================
  String _tnCareLine(int c, int id) {
    final n = callName(c, id), vo = callVoc(c, id), v = rnd.nextInt(2);
    if (c == 4 && id == 3) return '아이고 내 새끼, 어데 보자. 할미가 밤새 옆에 있으께.';
    if (c == 5 && id == 3) return '하늘아, 울지 마. 아줌마가 따뜻한 국 끓여 줄게.';
    switch (c) {
      case 5:
        return v == 0 ? '$n 팔이 찢어졌어. 오늘은 내가 국 끓일 테니, 넌 붕대나 찾아와.' : '$vo, 이리 와 앉아. 피는 멎었으니 하루만 누워 있어.';
      case 4:
        return v == 0 ? '아이고, $n 다리 좀 봐라. 오늘은 꼼짝 말고 누워 있거래이.' : '$vo, 피 나는 데 쑥 찧어 붙이자. 하루면 낫는다.';
      default:
        // 손윗사람에게는 '넌'이라 하지 않는다
        return v == 0 || survivors[id].age > survivors[c].age ? '$vo, 손 좀 보자고. 허허, 이 정도면 하루 쉬면 붙겠구먼.' : '$vo, 오늘 망은 내가 볼 테니, 넌 눈 좀 붙여.';
    }
  }

  /// 대형 재폭풍을 못 막은 뒤 (crisis.dart endDefense): 방벽·순찰에 있던 사람부터 한 사람이 하루 동안 다친다. 아무도 떠나지 않는다
  void nightInjury() {
    if (!tensionOn) return;
    final ids = [for (final id in svIds) if (_tnHere(id) && !_tnHurt(id)) id];
    if (ids.isEmpty) return;
    double w(int id) => dutyOf(id) == 'patrol' ? 3 : _isGuard(id) ? 2 : atOf(id) >= 0 ? 1.5 : 1;
    var tot = 0.0;
    for (final id in ids) {
      tot += w(id);
    }
    var r = rnd.nextDouble() * tot, id = ids.last;
    for (final q in ids) {
      r -= w(q);
      if (r <= 0) {
        id = q;
        break;
      }
    }
    _tnWound(id, cycleLen, 'night');
    recalc();
    final care = [5, 4, 0].where((c) => c != id && _tnHere(c) && !_tnHurt(c)).firstOrNull;
    final n = callName(null, id);
    // 재혁의 '도망치지 않았어요'는 그날 이야기(고백)를 들은 뒤에만
    final reply = id == 9 && conf == null ? '…괜찮아요. 연구실에서 다친 것보다 덜해요.' : _tnHurtReply[id] ?? '…괜찮아요. 하루만 쉬면 돼요.';
    talk([
      Line('me', '폭풍이 걷히자 ${jo(n, '이', '가')} 방벽 아래 주저앉아 있었다.'),
      if (care != null) Line(care, _tnCareLine(care, id)),
      Line(id, reply),
    ], tag: '폭풍이 지나간 새벽 · ${survivors[id].name} 다침');
    fx.add(FxToast('${survivors[id].name} 부상 · 하루 쉬어요. 다 나을 때까지 신뢰가 오르지 않아요'));
  }

  // ================= B. 정답 없는 선택 =================
  Map? get choice => S.rest['choice'] is Map ? S.rest['choice'] as Map : null;

  /// 국이 모자란 밤에 서운해할 어른: 일터에 있는 사람 먼저
  int? _tnGrumbler() {
    final order = [6, 0, 15, 1, 8, 12, ...svIds];
    bool ok(int id) => id != 5 && id != 3 && id != 4 && id != jinId && _tnHere(id) && survivors[id].age >= 18;
    return order.where((id) => ok(id) && atOf(id) >= 0).firstOrNull ?? order.where(ok).firstOrNull;
  }

  Map<String, Object?>? _choiceCand() {
    final day = dayN;
    final hurt = [for (final id in svIds) if (_tnHere(id) && _tnHurt(id)) id]
      ..sort((a, b) => (rec(b)!['hurt'] as num).compareTo(rec(a)!['hurt'] as num));
    if (hurt.length >= 2) return <String, Object?>{'k': 'med', 'a': hurt[0], 'b': hurt[1], 'v': '', 'day': day};
    if (_tnHere(5) && !_tnHurt(5) && have('food') < math.max(15, eat * 3)) {
      final kid = [3, jinId].where((q) => _tnHere(q)).firstOrNull, gr = _tnGrumbler();
      if (kid != null && gr != null) return <String, Object?>{'k': 'soup', 'a': kid, 'b': gr, 'v': '', 'day': day};
    }
    if (S.rest['medKin'] == null && day >= 2 && _tnHere(3) && _tnHere(4) && !_tnHurt(3) && !_tnHurt(4)) {
      return <String, Object?>{'k': 'med', 'a': 3, 'b': 4, 'v': 'kin', 'day': day};
    }
    return null;
  }

  /// 매초: 새벽 뒤 한동안 조건이 맞으면 (하루 한 번 굴림, 이틀에 한 번까지) 선택을 연다. 해가 질 때까지 안 고르면 누군가 대신 정한다
  void _tickChoice() {
    final c = choice;
    if (c != null) {
      if (!hasSv(_tnId(c['a'])) || !hasSv(_tnId(c['b']))) {
        S.rest['choice'] = null;
        return;
      }
      if (isNight && !uiModal) {
        _resolveChoice(0, auto: true);
        return;
      }
      final key = '${c['k']}${c['day']}';
      if (choiceAsked != key && !uiBusy && tut == null) {
        choiceAsked = key;
        fx.add(const FxChoice());
      }
      return;
    }
    if (!tensionOn || isNight || defn != null || ug != null || ln != null) return;
    final day = dayN, p = phase;
    if (day < 1 || p < 6 || p > 90 || S.rest['choiceTry'] == day) return;
    final last = S.rest['choiceDay'];
    if (last is num && day - last < 2) return;
    final pick = _choiceCand();
    if (pick == null) return;
    S.rest['choiceTry'] = day;
    if (rnd.nextDouble() >= .6) return;
    S.rest['choiceDay'] = day;
    S.rest['choice'] = pick;
    if (pick['v'] == 'kin') {
      S.rest['medKin'] = 1;
      _tnWound(3, 150, 'sick');
      _tnWound(4, 150, 'sick');
      recalc();
    }
    dirty = true;
  }

  /// 선택 창에 보일 것 (없으면 null)
  ChoiceView? choiceView() {
    final c = choice;
    if (c == null) return null;
    final a = _tnId(c['a']), b = _tnId(c['b']);
    if (!hasSv(a) || !hasSv(b)) return null;
    final an = _tnShort(a), bn = _tnShort(b);
    if (c['k'] == 'med' && c['v'] == 'kin') {
      final care = [2, 5].where((x) => _tnHere(x) && !_tnHurt(x)).firstOrNull;
      return ChoiceView('낮 · 정답 없는 선택', '약 한 알', [
        const Line('me', '밤새 하늘이가 열에 들떴다. 순례 할머니는 무릎이 퉁퉁 부어 일어나지 못했다.'),
        if (care == 2) const Line(2, '소염진통제가 한 알뿐이에요. 열도 내리고 붓기도 빼는 건데… 하늘이도, 할머니도 필요해요.'),
        if (care == 5) const Line(5, '약이 한 알뿐이야. 할매도 하늘이도 앓는데… 네가 정해.'),
        const Line(4, '약은 아한테 먼저 주이소. 나는 괜찮다.'),
        const Line(3, '…할머니 먼저 줘요. 저는 금방 나아요.'),
      ], const [
        ('하늘이에게 준다', '하늘이 바로 나아요 · 순례 할머니는 더디게 나아요'),
        ('순례 할머니에게 준다', '할머니가 바로 나아요 · 하늘이는 더디게 나아요'),
      ]);
    }
    if (c['k'] == 'med') {
      final care = [2, 5, 4].where((x) => x != a && x != b && _tnHere(x) && !_tnHurt(x)).firstOrNull;
      final y = b == 4 && a == 3 ? '약은 아한테 먼저 주이소. 나는 괜찮다.' : _tnMedYield[b];
      return ChoiceView('낮 · 정답 없는 선택', '약 한 알, 다친 사람 둘', [
        const Line('me', '약상자에 남은 건 진통제 한 알뿐이었다. 누워 있는 사람은 둘이다.'),
        if (care == 2) Line(2, '한 사람 몫이에요. ${callName(2, a)}도 ${callName(2, b)}도 상처가 깊어요. 누구 먼저 줄지 정해 줘요.'),
        if (care == 5) Line(5, '약이 한 알뿐이야. ${callName(5, a)}도 ${callName(5, b)}도 끙끙 앓는데. 네가 정해. 난 못 고르겠다.'),
        if (care == 4) const Line(4, '약이 한 알뿐이데이. 둘 다 앓는데… 니가 정해 도.'),
        if (y != null) Line(b, y),
      ], [
        ('${callName(null, a)}에게 준다', '$an 바로 회복 · $bn 회복이 더뎌요'),
        ('${callName(null, b)}에게 준다', '$bn 바로 회복 · $an 회복이 더뎌요'),
      ]);
    }
    if (c['k'] == 'soup') {
      return ChoiceView('낮 · 정답 없는 선택', '국이 모자란 밤', [
        const Line('me', '저녁 국솥이 반도 차지 않았다.'),
        const Line(5, '국이 모자라. 다 같이 반 그릇씩 먹으면 내일 아무도 힘을 못 써. 누구 몫부터 뜰까.'),
      ], [
        ('아이들 몫 먼저', '아이들 신뢰가 올라요 · 일하던 $bn 신뢰가 조금 내려요'),
        ('일하는 사람 먼저', '하루 동안 생산 ×1.2 · 아이들 신뢰가 조금 내려요'),
      ]);
    }
    return null;
  }

  /// 선택 창에서 고르기. 돌려주는 것: 이어지는 대사, 효과 글
  (List<Line>, List<String>) pickChoice(int k) => _resolveChoice(k);

  (List<Line>, List<String>) _resolveChoice(int k, {bool auto = false}) {
    final c = choice;
    if (c == null) return (const <Line>[], const <String>[]);
    S.rest['choice'] = null;
    final a = _tnId(c['a']), b = _tnId(c['b']);
    if (!hasSv(a) || !hasSv(b)) return (const <Line>[], const <String>[]);
    _tnCount('choiceN');
    final ls = <Line>[], out = <String>[];
    if (c['k'] == 'med') {
      final x = k == 0 ? a : b, y = k == 0 ? b : a;
      final rx = rec(x)!, ry = rec(y)!;
      rx['hurt'] = 0;
      rx.remove('hurtBy');
      rx.remove('slow');
      if (_tnHurt(y)) ry['slow'] = 1;
      if (have('med') >= 1) {
        S.m['med'] = have('med') - 1;
        out.add('${matOf['med']?.n ?? '약품'} -1');
      }
      out.add('${_tnShort(x)} 바로 회복');
      out.add('${_tnShort(y)} 회복 더딤');
      S.rest['choice_med'] = x;
      if (c['v'] == 'kin') {
        S.rest['medCb'] = dayN + 1;
        if (x == 3) {
          ls.addAll(const [Line(3, '…할머니, 미안해요.'), Line(4, '미안할 거 하나도 없다. 니가 아프믄 이 할미가 더 아프데이.')]);
        } else {
          ls.addAll(const [Line(4, '이 할미를 먼저 챙기다이… 고맙데이.'), Line(3, '괜찮아요. 봐요, 벌써 하나도 안 뜨거워요.'), Line('me', '하늘이 이마는 아직 뜨거웠다.')]);
        }
      } else {
        ls.add(Line(x, _tnMedThanks[x] ?? '…고마워요. 금방 일어날게요.'));
        ls.add(Line(y, _tnMedAfter[y] ?? '…괜찮아요. 잘했어요.'));
      }
      if (auto) fx.add(FxNote('약 한 알', '머뭇거리는 사이 약은 ${callName(null, x)} 몫이 됐다. ${jo(callName(null, y), '은', '는')} 하루를 더 앓는다.', ms: 6000));
    } else if (c['k'] == 'soup') {
      final kids = [3, jinId].where((q) => _tnHere(q)).toList();
      if (k == 0) {
        for (final id in kids) {
          _tnXp(id, 40, out);
        }
        if (kids.contains(3) && _tnHere(4)) _tnXp(4, 20, out);
        _tnXp(b, -25, out);
        ls.add(const Line(5, '애들부터 떠. 어른은 국물에 밥 말아 먹으면 돼.'));
        if (kids.contains(3)) ls.add(const Line(3, '와, 건더기도 있어요!'));
        if (kids.contains(jinId)) ls.add(const Line(jinId, '…진짜 내 거 맞아? …잘 먹을게.'));
        ls.add(Line(b, _tnSoupGrumble[b] ?? '…알겠어요. 내일 손이 좀 느려도 이해해 줘요.'));
        if (auto) fx.add(FxNote('김말순', '“네가 안 정하니 내가 떴다. 애들 먼저.” · ${out.join(' · ')}', ms: 6000));
      } else {
        S.buff = <String, Object?>{'k': 'all', 'm': 1.2, 't': cycleLen, 'label': '든든한 저녁'};
        out.add('생산 ×1.2 · 하루');
        for (final id in kids) {
          _tnXp(id, -15, out);
        }
        ls.add(const Line(5, '일하는 사람부터. 내일 벽이 서야 애들도 사니까.'));
        ls.add(Line(b, _tnSoupThanks[b] ?? '든든하네요. 내일은 두 배로 일할게요.'));
        if (kids.contains(3)) ls.addAll(const [Line(3, '…괜찮아요. 저 배 안 고파요.'), Line('me', '꼬르륵 소리가 났다. 하늘이는 못 들은 척 고개를 돌렸다.')]);
        if (kids.contains(jinId)) ls.add(const Line(jinId, '…역시 그렇지. 어디 가나 똑같네.'));
      }
    }
    recalc();
    _changed();
    return (talkLines(ls), out);
  }

  /// 약을 고른 다음 날: 하늘·순례가 그날을 기억한다
  void _tickMedCb() {
    final cb = S.rest['medCb'];
    if (cb is! num || dayN < cb || isNight || uiBusy || phase < 10 || phase > 120) return;
    S.rest.remove('medCb');
    final x = (S.rest['choice_med'] as num?)?.toInt();
    // 상대가 지금 쉘터에 없으면(원정·이주·떠남) 그날을 떠올리는 말로
    if (x == 3 && _tnHere(3)) {
      talk([
        if (_tnHere(4)) ...const [
          Line(3, '그때 할머니가 양보한 거, 저 알아요.'),
          Line(4, '…야가 뭘 안다꼬. 어서 밥이나 묵어라.'),
          Line('me', '순례 할머니는 괜히 하늘이 머리만 쓰다듬었다.'),
        ] else ...const [
          Line(3, '그때 할머니가 약 양보한 거, 저 다 알아요. …고맙다고 말도 못 했는데.'),
          Line('me', '하늘이는 할머니가 앉던 밭둑 쪽을 한참 바라보았다.'),
        ],
      ], tag: '약 한 알 · 그 뒤');
    } else if (x == 4 && _tnHere(4)) {
      talk([
        const Line(4, '니 덕에 이 할미가 아직 밭을 맨다 아이가.'),
        if (_tnHere(3))
          const Line('me', '할머니는 호미를 들고 밭으로 나갔다. 하늘이가 그 뒤를 졸졸 따랐다.')
        else
          const Line('me', '할머니는 호미를 들고 밭으로 나갔다. 하늘이가 늘 따라 걷던 자리를 몇 번이나 돌아보았다.'),
      ], tag: '약 한 알 · 그 뒤');
    }
    dirty = true;
  }

  // ================= C. 의심 · 사과 =================
  /// 사건 수첩에서 엉뚱한 사람을 추궁했을 때 (season.dart pickCase): 서운한 말, 그리고 이틀 뒤 사과할 기회
  Line wrongAccuse(int id, num lost) {
    S.rest['sorry_$id'] = dayN + 2;
    S.rest['sorryXp_$id'] = lost;
    return Line(id, _tnAccused[id] ?? '…저를 의심했군요.');
  }

  void _tickSorry() {
    if (isNight || uiBusy || phase < 4 || phase > 120) return;
    for (final k in S.rest.keys.toList()) {
      if (!k.startsWith('sorry_')) continue;
      final id = int.tryParse(k.substring(6)), due = S.rest[k];
      if (id == null || due is! num || id < 0 || id >= survivors.length || !hasSv(id)) {
        S.rest.remove(k);
        S.rest.remove('sorryXp_${k.substring(6)}');
        continue;
      }
      if (dayN < due || Game._truthy(rec(id)!['away'])) continue;
      final lost = (S.rest['sorryXp_$id'] as num?) ?? 0, back = (lost + 20).round();
      S.rest.remove(k);
      S.rest.remove('sorryXp_$id');
      rec(id)!['xp'] = xpOf(id) + back;
      talk([Line('me', survivors[id].age >= 60 ? '미안합니다.' : '미안해.'), Line(id, _tnForgive[id] ?? '…괜찮아요. 이제 됐어요.')], tag: '사과 · ${survivors[id].name} 신뢰 +$back');
      dirty = true;
      return;
    }
  }

  // ================= D. 불빛 밖의 밤길 =================
  /// 밤에 랜턴 불빛이 닿는 칸인지 (지도 그림의 어둠 구멍과 비슷하게: 쉘터 둘레·랜턴탑 둘레·등불 장식 옆)
  bool litAt(int i) {
    if (prot[i] == 1 || isSlot(i)) return true;
    final (x, y) = _tnPos(i);
    final (cx, cy) = _tnPos(C0);
    double d(double ax, double ay) => math.sqrt(math.pow(x - ax, 2) + math.pow(y - ay, 2));
    if (d(cx, cy) < (110 + S.lv * 28) * .7) return true;
    for (final e in deco.entries) {
      if (e.value != 'lamp' && e.value != 'string') continue;
      final j = int.tryParse(e.key);
      if (j == null) continue;
      final (lx, ly) = _tnPos(j);
      if (d(lx, ly) < 60) return true;
    }
    return false;
  }

  /// 밤에 불빛 밖의 폐허·캠프를 두드림 (hitSite·hitCamp): 밤마다 처음 한 번은 경고, 그 뒤엔 가끔(4%) 한 사람이 다친다 (밤마다 한 번까지)
  void darkTap(int i) {
    if (!isNight || defn != null || !tensionOn || litAt(i)) return;
    final nc = num_('nightCount').toInt();
    if (num_('darkWarnN').toInt() != nc) {
      S.rest['darkWarnN'] = nc;
      final (who, t) = _tnHere(6) && !_tnHurt(6)
          ? (survivors[6].name, '“불 밖으로는 나가지 마. 밤엔 길이 사람을 잡아먹어.”')
          : _tnHere(0) && !_tnHurt(0)
              ? (survivors[0].name, '“불 밖으로는 나가지 말자고. 밤길은 사람을 잡아먹는구먼.”')
              : (pfSet ? pfName : '나', '불빛 밖은 발밑도 보이지 않았다. 밤에는 길이 사람을 잡아먹는다.');
      fx.add(FxNote(who, '$t\n밤에 불빛 밖을 뒤지면 누군가 다칠 수 있어요', ms: 5500));
      return;
    }
    if (num_('darkHurtN').toInt() == nc) return;
    final now = Game.nowMs();
    if (now - darkRollAt < 1500) return;
    darkRollAt = now;
    if (rnd.nextDouble() >= .04) return;
    final free = [for (final id in svIds) if (!busy(id) && !isDead(id)) id];
    if (free.isEmpty) return;
    final idle = free.where((id) => atOf(id) < 0).toList(), pool = idle.isNotEmpty ? idle : free;
    final id = pool[rnd.nextInt(pool.length)];
    S.rest['darkHurtN'] = nc;
    _tnWound(id, 120, 'dark');
    recalc();
    sfx('hit', buzz: true);
    fx.add(FxBurst(i, 0xFF6A5A4A, 10));
    fx.add(FxNote('${survivors[id].name} 다침 · 불빛 밖', '“${_tnDarkReply[id] ?? '어둠 속에서 발을 헛디뎠어요. …하루만 쉴게요.'}”\n2분 동안 쉬어요', ms: 5500));
  }

  /// 매초 (engine tick)
  void _tickTension() {
    if (tut != null) return;
    _tickChoice();
    _tickSorry();
    _tickMedCb();
  }
}
