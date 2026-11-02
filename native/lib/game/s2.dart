// 시즌 2: 시즌 1 엔딩('다시, 03:11') 뒤 이어하기 자리에서 그대로 이어진다. 플레이어에게 '시즌' 경계는 보이지 않는다.
// 기획: 프로젝트 문서 claude/season2-bible.md(설정) · season2-script.md(대본) · season2-dialogue.md(핵심 장면) · season2-numbers.md(수치).
// 시즌 1(장면·대사·규칙)은 손대지 않는다. 여기 있는 것은 모두 S.rest['ehEnd']가 선 뒤에만 돈다.
//
// 1차(2026-11-02): 이야기 뼈대 — 산골의 아침 → 저수지 둑 → 옛 국책 연구소 → 첫 동네 → 발전소, 사건 10~14, 마지막 컷.
// 무대 이동은 시즌 1 이주(5명 고르기)를 그대로 쓰고, 이야기 동료는 늘 함께 간다.
part of 'engine.dart';

/// 이야기 동료: 만수·하늘·진·재혁·은호·미영·태식(합류했을 때만)
const s2Comps = [0, 3, jinId, 9, 10, 13, 12];

/// 무대 1~4의 동네
const s2Regs = ['reservoir', 'institute', 'hometown', 'plant'];

/// 무대 동네 정보 (RegionInfo 형식)
const Map<String, Map<String, Object?>> s2RegionData = {
  'reservoir': {
    'n': '얼어붙은 저수지 둑',
    'd': '얼음 밑으로 물이 우는 둑 · 식량 수확 ×1.3 · 한파가 잦아요',
    'prod': <String, num>{},
    'scav': {'food': 1.3},
    'wx': {'normal': 0.35, 'clear': 0.15, 'acid': 0.05, 'cold': 0.35, 'wind': 0.1},
    'big': 0,
  },
  'institute': {
    'n': '옛 국책 연구소',
    'd': '산그늘에 엎드린 철문 · 부품·전선 수확 ×1.3',
    'prod': <String, num>{},
    'scav': {'parts': 1.3, 'wire': 1.3},
    'wx': null,
    'big': 0,
  },
  'hometown': {
    'n': '처음 불을 켠 동네',
    'd': '돌아온 첫 동네 · 문설주의 이름들이 그대로예요',
    'prod': <String, num>{},
    'scav': <String, num>{},
    'wx': null,
    'big': 0,
  },
  'plant': {
    'n': '발전소 외곽',
    'd': '재의 눈 한가운데 · 대형 재폭풍이 두 밤마다 와요 · 연료 수확 ×1.3',
    'prod': <String, num>{},
    'scav': {'fuel': 1.3},
    'wx': null,
    'big': 2,
  },
};

/// 지도 그림의 결: 시즌 2 동네는 비슷한 시즌 1 동네의 땅·색을 빌려 쓴다 (랜드마크 그림은 따로)
String? regionLook(String? r) => switch (r) {
      'reservoir' => 'snow',
      'plant' => 'factory',
      'institute' || 'hometown' => null,
      _ => r,
    };

/// 이주한 동네 번호 → 시즌 2 동네 (저장본에서 맞춘다. townName·노선도가 쓴다)
final Map<int, String> s2GenRegion = {};

/// 시즌 2 먼 원정 (season2-numbers.md 3절). 원정 시간은 expCalc가 ×0.6 하므로 실제 30분·1시간·2시간이 되게 적는다
const List<ExpInfo> s2Exps = [
  ExpInfo('s2near', '가까운 폐허', 3000, .10, 1, {'scrap': 42, 'parts': 24, 'fuel': 24}, 0, 1, '', '30분 · 한두 명. 멈춘 차들 사이에 부품과 연료가 있어요.', '탑 빛이 끝나는 곳까지 걸어가 멈춘 차들을 뒤졌다.'),
  ExpInfo('s2far', '먼 폐허', 6000, .20, 1, {'cloth': 48, 'food': 72, 'wood': 42, 'med': 6}, 0, 2, '', '1시간 · 두세 명. 생활 물자가 남은 마을이에요.', '재구름 너머 불 꺼진 마을로 들어갔다.'),
  ExpInfo('s2deep', '깊은 곳', 12000, .30, 1, {'parts': 66, 'fuel': 54, 'plate': 30, 'wire': 12}, 0, 3, '', '2시간 · 세 명. 재가 가장 짙은 곳, 귀한 것이 남아 있어요.', '재가 무릎까지 쌓인 길을 셋이 한 줄로 걸었다.'),
];

/// 시즌 2 사건 다섯 (사건 10~14, 번호 k = 9~13). 웹툰 컷은 cuts/case10~14
final List<CaseInfo> s2Cases = [
  CaseInfo(
    ch: '저수지 둑',
    t: '부서진 안테나',
    when: '새벽 3시 무렵',
    sus: 10,
    susN: '무전실의 사람',
    gate: (g) => false,
    x: (g) => [
      const Line(_me, '아침, 랜턴 기름이 반쯤 줄어 있었다. 어젯밤엔 가득 채워 두었다.'),
      _keeper('관리소 안테나가 꺾였어요. 바람으론 그렇게 안 꺾여요.', me: '관리소 안테나가 꺾여 있었다. 바람으론 그렇게 꺾이지 않는다.'),
    ],
    alibi: '은호: “그 시간엔 방송 중이었어요.”',
    a: CaseOpt((g) => '사람들을 모아 묻는다', (g) => [
          _keeper('새벽 세 시쯤 무전실 쪽에 누가 있었어요. …은호 씨 같았어요.', me: '새벽 세 시쯤 무전실 쪽에 누가 있었다고, 누군가 말했다. 은호 같았다고.'),
          const Line(_me, '꺾인 기둥 아래, 녹아 끊긴 전선 끝이 둥글었다.'),
        ], clue: '꺾인 기둥 아래, 녹아 끊긴 전선 끝이 둥글었다.'),
    b: CaseOpt((g) => '은호를 감싼다', (g) => const [Line(_me, '바람이 센 동네라고, 다들 그렇게 넘기자고 했다.')]),
    c: CaseOpt((g) => '덮어 둔다', (g) => const [Line(_me, '안테나는 다시 세우면 된다. 그날 무전 거래는 쉬었다.')]),
  ),
  CaseInfo(
    ch: '옛 국책 연구소',
    t: '재혁',
    when: '새벽 3시 무렵',
    sus: 33,
    susN: '보고서를 같이 읽은 사람',
    gate: (g) => false,
    x: (g) => [
      const Line(_me, '깨어 보니 이미 밝은 아침이었다. 손목시계를 볼 틈도 없었다.'),
      const Line(_g, '…재혁이가. 무전실에서.'),
      const Line(_me, '노트의 한 장이 뜯겨 있었다. 보고서도 없었다.'),
    ],
    alibi: '서다은: “저는 서고 정리하고 일찍 잤어요.”',
    a: CaseOpt((g) => '추궁한다', (g) => [
          if (g.crow['rel'] == 'fight') const Line(jinId, '까마귀는 이렇게 안 해. 가져가지, 남기진 않아.'),
          const Line(33, '저는 보고서 넘겨 드리고 바로 잤어요. 재혁 씨가 혼자 더 본다고….', fb: Line(_me, '보고서를 같이 읽던 사람은 일찍 잤다고 했다.')),
          const Line(_me, '무전실 플레이어에 은호의 방송 테이프가 끝까지 돌아 있었다.'),
        ], clue: '무전실 플레이어에 은호의 방송 테이프가 끝까지 돌아 있었다.'),
    b: CaseOpt((g) => '감싼다', (g) => const [Line(_me, '그 사람은 아니라고 했다. 그럼 누구냐는 물음엔 아무도 답하지 않았다.')]),
    c: CaseOpt((g) => '덮어 둔다', (g) => const [Line(_me, '사고였다고 하자고 했다. 하늘이가 그 말에 고개를 저었다.')]),
  ),
  CaseInfo(
    ch: '첫 동네',
    t: '말을 잃은 어르신',
    when: '새벽 3시 무렵',
    susN: '새로 찾아온 사람',
    gate: (g) => false,
    x: (g) => [
      const Line(_me, '아침, 내 소매 끝이 젖어 있었다. 밤새 비는 오지 않았다.'),
      Line(_g, g.hasSv(12) || g.s2F['tsHurt'] != null ? '어르신이… 의무실에 누워 계세요. 말을 못 하세요.' : '${g._s2Elder()} 어르신이… 의무실에 누워 계세요. 말을 못 하세요.'),
    ],
    alibi: '새로 온 사람: “저는 축하 끝나고 바로 잤어요.”',
    a: CaseOpt((g) => '추궁한다', (g) => const [
          Line(_me, '새로 온 사람은 아무것도 모른다고 했다. 어르신이랑 말도 몇 마디 못 해 봤다고.'),
          Line(10, '…….', fb: Line(_me, '구석의 누군가가 고개를 숙이고 있었다.')),
          Line(_me, '구석에서 은호가 고개를 숙이고 있었다. 뭔가를 더 아는 얼굴이었다.'),
        ], clue: '구석에서 은호가 고개를 숙이고 있었다. 뭔가를 더 아는 얼굴이었다.'),
    b: CaseOpt((g) => '감싼다', (g) => const [Line(_me, '온 지 며칠 안 된 사람이 그럴 리 없다고 했다. 은호가 나를 보다 고개를 돌렸다.')]),
    c: CaseOpt((g) => '덮어 둔다', (g) => const [Line(_me, '축하가 지나쳤던 밤이라고, 다들 넘어졌을 거라고 했다.')]),
  ),
  CaseInfo(
    ch: '발전소',
    t: '사라진 도면',
    when: '새벽 3시 무렵',
    sus: 13,
    susN: '도면을 보고 얼굴이 굳은 사람',
    gate: (g) => false,
    x: (g) => const [
      Line(_me, '내 배낭 바닥에 회색이 아닌 검은 재가 묻어 있었다. 어젯밤 배낭은 열지 않았다.'),
      Line(_me, '캠프 탁자 위, 도면을 눌러 둔 돌멩이만 남아 있었다. 도면이 없었다.'),
    ],
    alibi: '미영: “…그 밤엔 캠프 끝에서 경보 소리를 듣고 있었어요. 혼자요.”',
    a: CaseOpt((g) => '추궁한다', (g) => const [
          Line(13, '그 도면, 무슨 그림인지 저는 알아요. 그래서 가져갈 이유가 없어요.'),
          Line(_me, '무슨 그림이냐고 묻자 미영은 대답하지 않았다.'),
        ], clue: '미영은 그 도면이 무슨 그림인지 안다고 했다. 무슨 그림인지는 말하지 않았다.'),
    b: CaseOpt((g) => '감싼다', (g) => const [Line(_me, '바람에 날아갔을 거라고 했다. 미영이 고맙다고도, 아니라고도 하지 않았다.')]),
    c: CaseOpt((g) => '덮어 둔다', (g) => const [Line(_me, '종이 한 장이었다. 경보 방송 소리가 더 시끄러웠다.')]),
  ),
  CaseInfo(
    ch: '발전소',
    t: '은호',
    when: '새벽 3시 무렵',
    susN: '없음',
    gate: (g) => false,
    x: (g) => const [
      Line(_me, '랜턴 갓 안쪽에 재의 눈의 검은 재가 묻어 있었다. 캠프의 재는 회색인데.'),
      Line(jinId, '…은호 형. 벽 너머에.', fb: Line(_g, '…은호가. 벽 너머에.')),
      Line(_me, '은호의 가방에서 재혁 노트의 뜯긴 장이 나왔다.'),
    ],
    a: CaseOpt((g) => '가방을 끝까지 뒤진다', (g) => const [
          Line(_me, '빈 테이프 케이스 하나. 테이프는 없었다.'),
          Line(_me, '날짜 칸이 비어 있었다. 산골 창고에서 나왔던 그 테이프처럼.'),
        ], clue: '빈 테이프 케이스 하나. 날짜 칸이 비어 있었다.'),
    b: CaseOpt((g) => '은호를 감싼다', (g) => const [Line(_me, '은호는 그럴 사람이 아니라고 했다. 아무도 대답하지 않았다.')]),
    c: CaseOpt((g) => '덮어 둔다', (g) => const [Line(_me, '아무도 더 묻지 않았다. 그게 이 마을이 정한 끝이었다.')]),
    tail: const [Line(_me, '문설주에 은호의 이름을 새겼다. 재혁의 이름 옆이었다.')],
  ),
];

/// 수문지기 줄: 하경수 → 저수지 사람 → 첫 동네 사람(안내 동료) 순. me가 있으면 아무도 없을 때 내레이션
Line _keeper(String t, {String? me}) => Line(30, t, fb: Line(31, t, fb: Line(32, t, fb: Line(33, t, fb: me != null ? Line(_me, me) : Line(_g, t)))));

/// 시즌 2 한 걸음
class S2Step {
  const S2Step(this.goal, this.hint, this.done, {this.intro, this.outro, this.rw = const {}, this.cost, this.go, this.k});
  final String goal, hint;
  final bool Function(Game g) done;
  final List<Line> Function(Game g)? intro, outro;
  final Cost rw;

  /// 받을 때 내는 자재 (점화·공사)
  final Cost? cost;

  /// 다음 무대로 떠나는 걸음: 갈 동네
  final String? go;

  /// 받은 뒤 할 일 (아침 사건 예약 등)
  final String? k;
}

/// 시즌 2 사건 창이 고른 뒤 띄울 선택 (마을 회의)
class FxS2Choice extends Fx {
  const FxS2Choice(this.k);
  final String k;
}

/// 웹툰 컷 한 편 (이름, 칸)
class FxCut extends Fx {
  const FxCut(this.name, this.panels);
  final String name;
  final List<int> panels;
}

/// 산골의 아침: 수첩 마지막 장 줄 (무대를 떠나기 전 03:11이 지난 아침마다 '내' 글씨로)
const s2NoteLines = ['다음은 탑.', '다음은 불이 꺼지지 않는 곳.', '다음은 처음 불.', '다음은 심장.'];

extension Season2 on Game {
  // ================= 상태 =================
  bool get s2On => S.rest['ehEnd'] != null;
  Map get s2 {
    if (S.rest['s2'] is! Map) S.rest['s2'] = <String, Object?>{'st': 0, 'i': 0, 'iI': -1, 'f': <String, Object?>{}, 'gens': <String, Object?>{}};
    return S.rest['s2'] as Map;
  }

  /// 무대 0(산골의 아침)~4(발전소)
  int get s2St => ((S.rest['s2'] as Map?)?['st'] as num?)?.toInt() ?? 0;
  int get s2I => ((S.rest['s2'] as Map?)?['i'] as num?)?.toInt() ?? 0;
  Map get s2F {
    if (s2['f'] is! Map) s2['f'] = <String, Object?>{};
    return s2['f'] as Map;
  }

  /// 시즌 2 이야기가 끝났나 (마지막 컷 뒤)
  bool get s2Done => s2On && (S.rest['s2'] as Map?)?['end'] != null;

  /// 지금 시즌 2 이야기가 띠를 차지하나
  bool get s2Active => s2On && !s2Done && mi >= steps.length;

  /// 지금 시즌 2 무대 동네에 있나 (시즌 1 동네 미션·동네 이야기를 쉬게 한다)
  bool get s2Town => S.region != null && s2Regs.contains(S.region);

  void s2Sync() {
    s2GenRegion.clear();
    final gs = (S.rest['s2'] as Map?)?['gens'];
    if (gs is Map) {
      for (final e in gs.entries) {
        final k = int.tryParse('${e.key}');
        if (k != null && e.value is String) s2GenRegion[k] = e.value as String;
      }
    }
  }

  /// 세는 목표는 그 걸음이 시작될 때부터 (시즌 1 _rel과 같은 방식, 걸음마다 따로)
  bool _s2Rel(String k, num v, [num need = 1]) {
    final key = '$s2St.$s2I.$k';
    if (s2['mb'] is! Map) s2['mb'] = <String, Object?>{};
    final mb = s2['mb'] as Map;
    mb[key] ??= v;
    return v - (mb[key] as num) >= need;
  }

  // ================= 이야기 동료 부르기 (산골의 아침 · 건전지 없이) =================
  List<int> get s2Missing => [for (final id in s2Comps) if (!hasSv(id) && inStay(id) && !isDead(id)) id];
  List<int> get s2Calling => [for (final v in (s2['call'] as List? ?? const [])) (v as num).toInt()];
  bool s2CanCall(int id) => s2Active && s2St == 0 && s2Comps.contains(id) && inStay(id) && !s2Calling.contains(id);

  void s2Call(int id) {
    if (!s2CanCall(id)) return;
    s2['call'] = <Object?>[...s2Calling, id];
    sfx('chime');
    fx.add(FxToast('${survivors[id].name}에게 무전을 보냈어요 · 새벽에 도착해요'));
    _changed();
  }

  void _s2CallArrive() {
    final L = s2Calling;
    if (L.isEmpty) return;
    s2['call'] = <Object?>[];
    final st = S.rest['stay'] as Map?;
    if (st == null) return;
    final got = <String>[];
    for (final id in L) {
      for (final e in [...st.entries]) {
        final t = e.value as Map, sv = t['sv'] as Map;
        if (sv['$id'] == null) continue;
        final r = Map<String, Object?>.from(sv['$id'] as Map);
        sv.remove('$id');
        if (sv.isEmpty) st.remove(e.key);
        r['at'] = -1;
        r['away'] = false;
        r['hurt'] = 0;
        S.sv['$id'] = r;
        got.add(survivors[id].name);
        break;
      }
    }
    if (got.isEmpty) return;
    sfx('join');
    recalc();
    fx.add(FxNote('${got.join('·')} 도착했어요', '무전을 듣고 밤새 걸어왔어요', ms: 5200));
  }

  // ================= 걸음 =================
  List<S2Step> s2Steps(int st) => switch (st) {
        0 => _s2Dawn,
        1 => _s2Reservoir,
        2 => _s2Institute,
        3 => _s2Home,
        _ => _s2Plant,
      };

  S2Step? get s2Step {
    if (!s2Active) return null;
    final L = s2Steps(s2St);
    return s2I < L.length ? L[s2I] : null;
  }

  /// 시즌 2 띠 (mission()이 시즌 1 다음에 묻는다)
  Mission? get s2Mission {
    final m = s2Step;
    if (m == null) return null;
    final done = m.go == null && m.done(this) && (m.cost == null || canPay(m.cost!));
    return Mission(m.goal, done, m.rw, m.hint, s2: true, go: m.go != null);
  }

  String get _s2Tag => const ['산골의 아침', '얼어붙은 저수지 둑', '옛 국책 연구소', '처음 불을 켠 동네', '발전소'][s2St.clamp(0, 4)];

  /// 화면이 비었을 때 걸음 시작 장면 (tickStory가 부른다)
  bool s2TickIntro() {
    // 고르지 않고 닫힌 시즌 2 사건이 있으면 다시 연다 (앱을 껐다 켰을 때)
    if (!s2Reopened) {
      s2Reopened = true;
      for (var j = 0; j < s2Cases.length; j++) {
        final R = caseRec(s2Case0 + j);
        if (R != null && R['p'] == null) {
          fx.add(FxCase(s2Case0 + j));
          return true;
        }
      }
    }
    final m = s2Step;
    if (m == null) return false;
    final key = s2St * 100 + s2I;
    if (((s2['iI'] as num?) ?? -1) == key) return false;
    s2['iI'] = key;
    dirty = true;
    final L = m.intro?.call(this) ?? const <Line>[];
    if (L.isNotEmpty) {
      talk(L, tag: _s2Tag, goal: m.goal);
    } else {
      fx.add(FxNote('새 목표 · ${m.goal}', m.hint, ms: 4500));
    }
    return true;
  }

  void claimS2() {
    final m = s2Step;
    if (m == null || m.go != null) return;
    if (m.cost != null) {
      if (!pay(m.cost!)) return;
    }
    s2['i'] = s2I + 1;
    final o = m.outro?.call(this) ?? const <Line>[];
    if (o.isNotEmpty) talk(o, tag: _s2Tag, chain: true, noskip: m.k == 'final', after: m.k == 'final' ? 's2black' : null);
    if (m.k != null) _s2After(m.k!);
    if (s2St == 0 && s2I == 1) {
      // 만수의 "넌 좀 앉아 있어" 뒤: 사람 보내기 열림 (안내 카드)
      fx.add(const FxNote('사람 보내기', '탑 빛 안쪽은 사람들이 다녀와요. 폐허를 누르고 사람을 고르면 끝. 마을의 하루가 지나면 돌아와요.', ms: 7000));
    }
    dirty = true;
  }

  /// 다음 무대로 떠날 수 있으면 그 동네
  String? get s2GoNext => s2Step?.go;

  // ================= 받은 뒤 =================
  void _s2After(String k) {
    final n = num_('nights');
    switch (k) {
      case 'rescueRes':
        for (final id in const [30, 31, 32, 33]) {
          if (!hasSv(id) && !isDead(id)) rescue(id, 'visit');
        }
      case 'net1':
      case 'lamp':
      case 'ring':
        s2F[k] = 1;
        S.hopeB += 2;
        recalc();
        _s2Widen(k == 'ring' ? 3 : 2);
      case 'jh':
        s2F['net2'] = 1;
        _s2Widen(2);
        s2F['dawn'] = k;
        s2F['dawnN'] = n;
      case 'c10':
      case 'c12':
      case 'c13':
      case 'eh':
        // 그 밤 03:11 뒤 아침에 (다음 새벽)
        s2F['dawn'] = k;
        s2F['dawnN'] = n;
      case 'tapes':
        s2F['tapes'] = 1;
        fx.add(const FxNote('은호의 방송 테이프', '은호가 방송 테이프를 모두 내놓았어요. 날짜순으로.', ms: 5200));
      case 'meeting':
        fx.add(const FxS2Choice('meeting'));
      case 'final':
        // 마지막 컷 뒤: 딸깍. 블랙. (화면이 대화를 닫을 때 FxTalk.after 's2black'으로)
        s2['end'] = 1;
    }
    _changed();
  }

  /// 새벽 (crisis._onDawn → _regionDawn에서)
  void s2Dawn() {
    if (!s2On) return;
    _s2CallArrive();
    final k = s2F['dawn'] as String?;
    if (k == null) return;
    if (num_('nights') <= ((s2F['dawnN'] as num?) ?? 0)) return;
    s2F.remove('dawn');
    switch (k) {
      case 'c10':
        _s2Case(9);
      case 'jh':
        // 재혁의 죽음 (이야기 안에서만, 잃는 규칙과 별개)
        if (hasSv(9)) {
          _killSurv(9);
          tlog('재혁을 잃었다.');
        }
        _s2Case(10);
        talk([
          const Line(_me, '무전실 문을 열자 은호가 헤드폰을 쓰고 있었다. 녹음기가 돌고 있었다.'),
          const Line(_me, '은호가 헤드폰을 잡아 뜯듯 벗었다. 녹음기가 멈췄다. 손이 떨리고 있었다.'),
          const Line(10, '…아무것도 아니에요.'),
          const Line(_me, '은호는 내 얼굴을 보지 않았다. 내 입을 보고 있었다.'),
          const Line(_me, '괜찮으냐고 물었다.'),
          const Line(_me, '은호는 대답 대신 녹음기를 끌어안고 나갔다.'),
          const Line(_me, '그날부터 은호는 밥을 반쯤 남겼다. 무전실 앞을 지날 땐 걸음이 빨라졌다.'),
        ], tag: '그날 아침');
      case 'c12':
        s2F['tsHurt'] = 1;
        final r = rec(12);
        if (r != null) r['hurt'] = 600;
        _s2Case(11);
      case 'c13':
        _s2Case(12);
      case 'eh':
        if (hasSv(10)) {
          _killSurv(10);
          tlog('은호를 잃었다.');
        }
        s2F['ehDead'] = 1;
        _s2Case(13);
    }
    _changed();
  }

  void _s2Case(int k) {
    casesMap[caseKeyOf(k)] ??= <String, Object?>{'at': Game.nowMs()};
    fx.add(FxCase(k));
  }

  /// 사건을 고른 뒤 (pickCase가 부른다)
  void s2Picked(int k) {
    if (k == 13) {
      // 마을이 닫음: 재혁 사건 장 위에 회색 글씨
      final R = casesMap[caseKeyOf(10)];
      if (R is Map) R['closed'] = 1;
    }
  }

  /// 마을 회의: 감싼다(마을 믿음이 떨어짐) / 지켜본다(은호가 멀어짐)
  void s2Meeting(bool cover) {
    if (s2F['meet'] != null) return;
    s2F['meet'] = cover ? 'cover' : 'watch';
    if (cover) {
      for (final id in svIds) {
        if (!s2Comps.contains(id)) rec(id)!['xp'] = math.max(0, xpOf(id) - 20);
      }
      talk(const [
        Line(_me, '은호는 우리 사람이라고, 축하 방송은 다 같이 원한 거라고 말했다.'),
        Line(_me, '웅성거림이 가라앉지 않았다.'),
        Line(_me, '은호가 나를 봤다. 고마워하는 얼굴이 아니었다.'),
      ], tag: '마을 회의');
    } else {
      if (hasSv(10)) rec(10)!['xp'] = math.max(0, xpOf(10) - 60);
      talk(const [
        Line(_me, '당분간 밤 방송은 쉬고, 은호도 밤엔 쉘터 안에 있으라고 했다.'),
        Line(10, '…네. 그게 좋겠어요.'),
        Line(_me, '그날 밤부터 은호는 내 자리에서 가장 먼 곳에 누웠다.'),
      ], tag: '마을 회의');
    }
    recalc();
    _changed();
  }

  /// 수첩 마지막 장 ("다음은…")
  List<String> get s2Notes => [
        s2NoteLines[0],
        for (var i = 1; i < s2NoteLines.length; i++)
          if (s2F['note$i'] != null) s2NoteLines[i],
      ];

  // ================= 무대 이동 =================
  /// 이주(region.dart migrate)가 다음 무대 동네에 막 도착했을 때
  void _s2Arrive(int g, String region) {
    final gs = (s2['gens'] is Map) ? s2['gens'] as Map : (s2['gens'] = <String, Object?>{});
    gs['$g'] = region;
    s2Sync();
    s2['st'] = s2St + 1;
    s2['i'] = 0;
    s2['iI'] = -1;
    // 잃는 규칙(시즌 1 그대로): 도착 뒤 첫 대형 재폭풍·습격 새벽 (동네 미션 1번째부터 세는 조건을 맞춘다)
    S.rest['rmi'] = 1;
    // 두드리기 없음: 탑 빛 안쪽은 처음부터 재가 걷혀 있다 (구조 신호는 없다 · 저수지 사람은 이야기로 합류)
    S.sig.clear();
    s2['send'] = <String, Object?>{};
    _s2Light(5);
    if (region == 'hometown') {
      // 쉘터는 그대로 서 있었다: 요새(Lv.4)로 시작한다 (11/02 대표님 결정. 시즌 1 앱이 떠난 동네의 지도를 남기지 않아 지도는 새로)
      S.lv = math.max(S.lv, 4);
      // 첫 동네에 남겨 둔 사람들과 다시 만난다
      final st = S.rest['stay'] as Map?;
      final t = st?['0'] as Map?;
      if (t != null && t['sv'] is Map) {
        final back = <int>[];
        for (final e in (t['sv'] as Map).entries) {
          final id = int.parse('${e.key}');
          if (isDead(id) || hasSv(id)) continue;
          final r = Map<String, Object?>.from(e.value as Map);
          r['at'] = -1;
          r['away'] = false;
          r['hurt'] = 0;
          S.sv['$id'] = r;
          back.add(id);
        }
        st!.remove('0');
        if (back.isNotEmpty) s2F['back'] = back.first;
      }
      recalc();
    }
    const arrive = {
      'reservoir': '산골 눈길을 내려와, 얼어붙은 저수지 둑에 닿았다.',
      'institute': '산 밑 옛길을 지나, 철문이 닫힌 연구소에 닿았다.',
      'hometown': '끊긴 남부 고가도로를 지나, 처음 불을 켠 동네에 닿았다.',
      'plant': '재의 눈을 건너, 발전소 외곽에 닿았다.',
    };
    tlog('불씨를 들고 도착했다.');
    talk([Line(_me, arrive[region] ?? '')], card: ('$g번째 동네', regions[region]?.n ?? ''), goal: s2Steps(s2St).first.goal);
  }

  /// 가는 길 한 줄 (이주 화면, 광고 자리)
  String s2WayLine(String region) => const {
        'reservoir': '눈길 위로 탑 불빛이 등 뒤에 길게 누웠다.',
        'institute': '빛줄기 하나가 우리보다 먼저 길을 가고 있었다.',
        'hometown': '낯익은 고가도로가 보이기 시작했다.',
        'plant': '재가 가장 깊은 쪽으로, 빛줄기를 따라 걸었다.',
      }[region] ??
      '';

  // ================= 2차 · 경영 놀이 (2026-11-02) =================
  /// 두드리기 없음: 산골의 아침에 만수가 "넌 좀 앉아 있어"라고 한 뒤부터 (대형 재폭풍의 괴물 막기는 시즌 1 그대로)
  bool get s2NoTap => s2On && (s2St >= 1 || s2I >= 1 || s2Done);

  /// 탑 빛 반경 (무대 동네에서 재가 걷힌 거리). 도착 5칸, 점화·연결마다 넓어진다
  int get s2LightR => ((s2['lr'] as num?) ?? 5).toInt();

  /// 탑 빛 안쪽을 밝힌다 (소리·불꽃 없이)
  void _s2Light(int r) {
    s2['lr'] = r;
    final snd = onSfx;
    onSfx = null;
    final f0 = fx.length;
    for (var i = 0; i < N; i++) {
      if (S.rev[i] == 0 && dist(i) <= r + .01) reveal(i);
    }
    onSfx = snd;
    if (fx.length > f0) fx.removeRange(f0, fx.length);
    _rebuildFrontier();
    _mapChanged();
  }

  void _s2Widen(int by) {
    if (!s2Town) return;
    _s2Light(s2LightR + by);
    fx.add(FxNote('탑 빛이 넓어졌어요', '빛 안쪽의 땅이 늘었어요 · 사람을 보낼 곳이 많아져요', ms: 4500));
  }

  // ---------- 사람 보내기 (가까운 땅 · 한 명씩 · 마을 하루 동안 다녀옴) ----------
  static const s2SendT = 200.0;
  Map get s2SendMap {
    if (s2['send'] is! Map) s2['send'] = <String, Object?>{};
    return s2['send'] as Map;
  }

  List<int> get s2SendIds => [for (final k in s2SendMap.keys) int.parse('$k')];
  int? s2SentTo(int tile) {
    for (final e in s2SendMap.entries) {
      if ((e.value as Map)['t'] == tile) return int.parse('${e.key}');
    }
    return null;
  }

  /// 보낼 수 있는 사람: 일터에 없고 쉬는 사람 (이야기 동료는 원정·보내기에 나가지 않는다)
  List<int> get s2SendPool => [for (final id in svIds) if (!s2Comps.contains(id) && atOf(id) < 0 && !busy(id)) id];

  /// 그 땅에 맞는 사람 하나 (정찰·운전이면 더 많이 가져온다)
  int? s2SendPick(int tile) {
    final p = s2SendPool;
    if (p.isEmpty) return null;
    p.sort((a, b) => (_s2Fit(b) ? 1 : 0) - (_s2Fit(a) ? 1 : 0));
    return p.first;
  }

  bool _s2Fit(int id) => roleOf(id).contains('scout') || roleOf(id).contains('drive');

  bool s2Send(int id, int tile) {
    if (!s2NoTap || !hasSv(id) || busy(id) || atOf(id) >= 0 || s2Comps.contains(id)) return false;
    if (S.rev[tile] != 1 || !siteLive(tile) || s2SentTo(tile) != null) return false;
    s2SendMap['$id'] = <String, Object?>{'t': tile, 'left': s2SendT};
    rec(id)!['away'] = 's2send';
    sfx('tap');
    if (s2F['sendTold'] == null) {
      s2F['sendTold'] = 1;
      fx.add(const FxNote('사람 보내기', '탑 빛 안쪽은 사람들이 다녀와요. 사람을 누르고, 땅을 누르면 끝. 마을의 하루가 지나면 돌아와요.', ms: 6500));
    } else {
      fx.add(FxToast('${jo(survivors[id].name, '이', '가')} 폐허로 갔어요 · 마을 하루 뒤 돌아와요'));
    }
    recalc();
    _changed();
    return true;
  }

  void s2Recall(int id) {
    if (s2SendMap.remove('$id') == null) return;
    final r = rec(id);
    if (r != null) r['away'] = false;
    recalc();
    _changed();
  }

  /// 한 번 다녀온 몫: 그 폐허를 세 번 뒤진 만큼 (맞는 사람이면 네 번)
  void _s2Trip(int id, int tile, {bool quiet = false}) {
    final s = S.site[tile];
    if (s == null || s.c <= 0) return;
    final n = _s2Fit(id) ? 4 : 3;
    for (var k = 0; k < n && s.c > 0; k++) {
      s.c--;
      haul(tile, s);
    }
    if (s.c <= 0) {
      s.hp = siteHp(s).toDouble();
      s.rt = 0;
    }
    if (hasSv(id)) rec(id)!['xp'] = xpOf(id) + 6;
    s2['trips'] = ((s2['trips'] as num?) ?? 0) + 1;
  }

  /// 매초: 보낸 사람들이 다녀오고, 폐허가 비면 쉰다
  void s2TickSec([double dt = 1]) {
    if (!s2On) return;
    if (s2SendMap.isEmpty) return;
    for (final k in s2SendMap.keys.toList()) {
      final id = int.parse('$k'), x = s2SendMap[k] as Map, t = (x['t'] as num).toInt();
      if (!hasSv(id)) {
        s2SendMap.remove(k);
        continue;
      }
      x['left'] = ((x['left'] as num?) ?? s2SendT) - dt;
      if ((x['left'] as num) > 0) continue;
      _s2Trip(id, t);
      if (siteLive(t)) {
        x['left'] = s2SendT;
      } else {
        s2Recall(id);
        fx.add(FxToast('${jo(survivors[id].name, '이', '가')} 돌아왔어요 · 그 폐허는 다 털었어요'));
      }
      _mapChanged();
      dirty = true;
    }
  }

  /// 꺼 둔 동안 (최대 8시간, 시즌 1 누적 규칙 그대로): 그동안 다녀온 횟수만큼
  void s2Offline(double sec) {
    if (!s2On || s2SendMap.isEmpty) return;
    final trips = (sec / s2SendT).floor();
    if (trips <= 0) return;
    final snd = onSfx;
    onSfx = null;
    final f0 = fx.length;
    for (final k in s2SendMap.keys.toList()) {
      final id = int.parse('$k'), t = ((s2SendMap[k] as Map)['t'] as num).toInt();
      for (var n = 0; n < trips && siteLive(t); n++) {
        _s2Trip(id, t, quiet: true);
      }
      if (!siteLive(t)) s2Recall(id);
    }
    onSfx = snd;
    if (fx.length > f0) fx.removeRange(f0, fx.length);
  }

  // ---------- 먼 원정 (조 · 실제 시간 30분~2시간) ----------
  /// 지금 동네의 원정 목록: 시즌 2 무대 동네에서는 먼 원정 셋
  List<ExpInfo> get expList => s2Town ? s2Exps : exps;

  // ================= 말하는 사람 고르기 =================
  /// 첫 동네 출신 일반 생존자 한 명 (이야기 동료·저수지 사람 빼고)
  int? _s2Local() {
    for (final id in svIds) {
      if (!s2Comps.contains(id) && id != 11 && (id < 30 || id > 33) && survivors[id].age >= 18) return id;
    }
    return null;
  }

  /// 태식이 없을 때: 무리에서 가장 나이 많은 어른 이름
  String _s2Elder() {
    final ids = [for (final id in svIds) if (survivors[id].age >= 18) id]..sort((a, b) => survivors[b].age.compareTo(survivors[a].age));
    return ids.isEmpty ? '' : survivors[ids.first].name;
  }

  Line _local(String t, {String? malsun}) {
    final id = _s2Local();
    if (id == null) return Line(_g, t);
    return Line(id, id == 5 && malsun != null ? malsun : t);
  }

  // ================= 무대 0 · 산골의 아침 =================
  List<S2Step> get _s2Dawn => [
        S2Step('남겨 두고 온 동료들 무전으로 부르기', '라디오 탭 › 무전 교대에서 불러요 · 이야기 동료는 건전지 없이 다음 새벽에 와요',
            (g) => g.s2Missing.isEmpty && g.s2Calling.isEmpty,
            intro: (g) => [
                  const Line(_me, '눈을 떴다. 창밖은 이미 밝았다.'),
                  const Line(_me, '머리맡의 랜턴이 미지근했다. 밤새 꺼 두었는데.'),
                  const Line(_me, '…탑 불빛이 밤새 비춘 탓이겠지.'),
                  const Line('npc:snow', '어젯밤 방송이요. 아이들이 마지막 곡 끝까지 듣겠다고 버텼는데… 중간에 끊겼다고 울었어요.'),
                  if (g.hasSv(10)) ...const [Line(10, '…죄송해요. 장비가 말을 안 들어서.'), Line(_me, '은호는 그 뒤로 내 쪽을 보지 않았다.')],
                  if (!g.hasSv(10) && g.inStay(10)) const Line('r:10', '…어젯밤 방송, 끊겨서 죄송합니다. 장비가… 말을 안 들어서요.'),
                  const Line(_me, '끊긴 방송을 들은 건 우리만이 아니었다.'),
                  if (!g.hasSv(0) && g.inStay(0)) const Line('r:0', '어이, 거기 별일 없는 거지? 밤새 잡음만 들리길래 잠을 못 잤구먼.'),
                  if (!g.hasSv(3) && g.inStay(3)) const Line('r:3', '아저씨! 노래가 끊겼어요. 다들 괜찮아요?'),
                  if (!g.hasSv(jinId) && g.inStay(jinId)) const Line('r:17', '…라디오 끊겼던데. 거기 무슨 일 있어?'),
                  if (!g.hasSv(12) && g.inStay(12)) const Line('r:12', '시계 소리만 들리는 밤이었네. 자네들 무사한가.'),
                  if (!g.hasSv(13) && g.inStay(13)) const Line('r:13', '…거기 탑은요? 불은 괜찮아요?'),
                  if (!g.hasSv(9) && g.inStay(9)) const Line('r:9', '방송 끊긴 시각이… 아니에요. 다들 괜찮으면 됐어요.'),
                  if (g.s2Missing.isNotEmpty) const Line(_me, '남겨 두고 온 얼굴들이었다. 불러야겠다고 생각했다.'),
                  if (!g.hasSv(10) && g.inStay(10)) ...const [Line('r:10', '저… 저도 가도 될까요?'), Line(_me, '은호의 목소리가 떨렸다.')],
                ],
            outro: (g) => [
                  const Line(0, '탑 빛 안쪽은 이제 우리가 다녀올게. 넌 좀 앉아 있어.', fb: Line(_g, '탑 빛 안쪽은 이제 우리가 다녀올게요. 좀 앉아 있어요.')),
                  const Line(_me, '아직 걸을 만하다고 했다.'),
                  const Line(0, '걸을 만할 때 쉬는 거구먼. 등불지기가 쓰러지면 불은 누가 지키나.', fb: Line(_g, '걸을 만할 때 쉬는 거예요. 등불지기가 쓰러지면 불은 누가 지켜요.')),
                  const Line(3, '아저씨는 랜턴만 잘 들고 있어요!'),
                  const Line(_me, '아버지가 남긴 말과 같았다.'),
                ]),
        S2Step('먼 불빛을 따라 떠나기', '위쪽 띠의 ‘새 동네로’를 눌러요 · 이야기 동료는 늘 함께 가요', (g) => false,
            go: 'reservoir',
            intro: (g) => [
                  const Line(11, '오늘 밤은 하늘이 얕아요.'),
                  const Line(_me, '탑 불빛 너머, 먼 불빛이 또 깜빡였다. 셋. 하나. 하나.'),
                  const Line(jinId, '…또 저거네.'),
                  const Line(0, '저쪽은… 사막 가는 길에 지나던 저수지 둑이구먼.', fb: Line(_me, '노선도에 적힌 이정표였다. 얼어붙은 저수지 둑.')),
                  const Line(_me, '수첩을 펼쳤다. 마지막 장에 내 글씨가 그대로 있었다. 다음은 탑.'),
                  const Line(_me, '저 불빛도 탑일까.'),
                  const Line(_me, '가 보자고 했다.'),
                ]),
      ];

  // ================= 무대 1 · 얼어붙은 저수지 둑 =================
  List<S2Step> get _s2Reservoir => [
        S2Step('둑 위에 자리 잡기 · 판잣집 쉘터 세우기', '쉘터를 판잣집으로 키워요', (g) => g.S.lv >= 2,
            rw: const {'food': 30, 'batt': 1},
            k: 'rescueRes',
            intro: (g) => const [
                  Line(_me, '둑 위에 바람이 셌다. 얼음 밑으로 물이 우는 소리가 났다.'),
                  Line(_g, '우선 바람 막을 데부터 찾자고. 수문 관리소가 아직 서 있구먼.'),
                ],
            outro: (g) => const [
                  Line('npc:keeper', '…불빛 보고 나왔어요. 수문 관리인 하경수예요. 여기 몇 사람 더 있어요.'),
                ]),
        S2Step('중계등 점화 · 전선 6 · 부품 20 · 철판 10', '자재가 모이면 받기를 눌러 랜턴으로 불을 붙여요', (g) => true,
            cost: const {'wire': 6, 'parts': 20, 'plate': 10},
            rw: const {'batt': 1},
            k: 'net1',
            intro: (g) => [
                  _keeper('관리소 지붕에 등이 하나 있어요. 사고 전에 발전소 사람들이 달고 갔죠. 한 번도 켜진 적은 없고요.', me: '관리소 지붕에 작은 등이 달려 있었다. 한 번도 켜진 적 없는 것 같았다.'),
                  const Line(13, '…등불 계획 중계등이에요. 랜턴 빛이면 깨울 수 있어요.'),
                ],
            outro: (g) => const [
                  Line(_me, '랜턴을 들어 올렸다. 지붕 위 작은 등이 숨을 쉬듯 켜졌다.'),
                  Line(_me, '노선도 위, 산골 탑과 이 둑 사이에 가는 빛줄기 하나가 그어졌다.'),
                  Line(_me, '랜턴을 내렸다. 갓이 뜨거웠다.'),
                ]),
        S2Step('배급 정하기 · 식량 80 모으기', '식량을 모아 두면 나눠 먹는 법을 정해요', (g) => g.have('food') >= 80,
            rw: const {'cloth': 20},
            intro: (g) => [
                  Line(31, '매점 창고에 라면 상자가 몇 개 남았는데… 사람이 늘었으니 이걸로는 며칠 못 가요.', fb: const Line(_me, '매점 창고의 라면 상자는 며칠 치뿐이었다.')),
                  const Line(_g, '나눠 먹는 법부터 정해야겠구먼.'),
                ],
            outro: (g) => const [Line(_me, '배급표가 관리소 문에 붙었다. 누군가 그 아래 작게 적었다. "고마워요."')]),
        S2Step('얼음 밑의 길 · 원정 한 번 보내기', '원정 탭에서 먼 원정을 보내요 · 30분부터', (g) => g._s2Rel('exp', g.num_('expDone')),
            rw: const {'food': 40, 'parts': 10},
            intro: (g) => const [Line(32, '얼음 밑으로 물길이 하나 살아 있어요. 그걸 따라가면 하류 마을 창고가 나와요.', fb: Line(_me, '얼음 밑으로 물길 하나가 살아 있었다. 따라가면 하류 마을이었다.'))],
            outro: (g) => const [Line(32, '봐요, 얼음이 거짓말은 안 해요.', fb: Line(_me, '하류 창고는 털리지 않은 채였다.'))]),
        S2Step('노친네 · 밤 하나 넘기기', '해가 지고 새벽이 오면 돼요', (g) => g._s2Rel('night', g.num_('nights')),
            rw: const {'batt': 1},
            k: 'c10',
            intro: (g) => const [
                  Line('npc:ped', '딸랑. …둑 위까지 수레 끌고 오느라 바퀴가 다 얼었어요. 있을 때 사 두는 겁니다.'),
                  Line('npc:ped', '산 밑 옛 연구소에 밤에도 불이 안 꺼진답디다. 누가 켜 두는지는 몰라요.'),
                ],
            outro: (g) => const [Line(_me, '노친네가 떠난 자리에 손수레 바퀴 자국이 산 쪽으로 이어졌다.')]),
        S2Step('연구소 쪽 정찰 조 · 원정 한 번 보내기', '원정 탭에서 먼 원정을 보내요 · 돌아오면 다음 길이 보여요',
            (g) => g._s2Rel('exp', g.num_('expDone')) && g.caseRec(9)?['p'] != null,
            rw: const {'batt': 2},
            intro: (g) => const [Line(_me, '정찰 조가 돌아오기를 기다리는 사이, 무전이 며칠째 조용했다.')],
            outro: (g) {
              g.s2F['note1'] = 1;
              return const [
                Line(jinId, '철문 있어. 큰 거. 옥상에 불 하나 켜져 있고. 근데 아무도 없어.', fb: Line(_g, '철문이 있더구먼. 옥상에 불 하나 켜져 있고. 근데 아무도 없어.')),
                Line(9, '…거기 알아요. 등불 계획이 처음 시작된 곳이에요.'),
                Line(_me, '수첩 마지막 장에 한 줄이 늘어 있었다. 다음은 불이 꺼지지 않는 곳.'),
                Line(_me, '언제 썼는지 기억나지 않았다.'),
              ];
            }),
        S2Step('불이 꺼지지 않는 곳으로 떠나기', '위쪽 띠의 ‘새 동네로’를 눌러요', (g) => false, go: 'institute'),
      ];

  // ================= 무대 2 · 옛 국책 연구소 =================
  List<S2Step> get _s2Institute => [
        S2Step('철문 앞 · 판잣집 쉘터 세우기', '쉘터를 판잣집으로 키워요', (g) => g.S.lv >= 2,
            rw: const {'food': 30, 'batt': 1},
            intro: (g) => [
                  const Line(_me, '연구소는 산그늘에 엎드려 있었다. 철문에 녹슨 봉인 띠가 감겨 있었다.'),
                  if (g.hasSv(12)) const Line(12, '…시계 뒷면이랑 같은 무늬구먼.') else const Line(_me, '철문 손잡이에 등불 문양이 찍혀 있었다. 랜턴 밑바닥과 같은 무늬였다.'),
                ],
            outro: (g) => const [Line(_me, '봉인 띠를 끊었다. 철문은 생각보다 쉽게 열렸다.')]),
        S2Step('꺼지지 않는 불 · 연료 30 · 부품 15', '자재가 모이면 받기를 눌러 랜턴으로 시험등을 깨워요', (g) => true,
            cost: const {'fuel': 30, 'parts': 15},
            rw: const {'batt': 1},
            k: 'lamp',
            intro: (g) => const [
                  Line(9, '옥상 시험등이에요. 이렇게 오래 켜져 있을 리가 없는데….'),
                  Line(13, '예전엔 발전소 실험로가 아주 약하게 내던 빛에 답했을 거예요. 그 빛은… 제가 심지를 꺼낸 날 꺼졌고요.'),
                  Line(13, '지금은 우리가 켠 탑들 빛에 답하는 거예요. 분소 탑들처럼요.'),
                ],
            outro: (g) => const [
                  Line(_me, '랜턴을 대자, 희미하던 시험등이 제 빛을 찾았다.'),
                  Line(_me, '빛은 아직 저수지까지 닿지 않았다. 무언가 하나가 모자랐다.'),
                  Line(9, '렌즈예요. 공단에서 가져온 게 하나 남아 있어요.'),
                ]),
        S2Step('녹음된 새벽 · 밤 둘 넘기기', '연구소에서 며칠 지내요', (g) => g._s2Rel('night', g.num_('nights'), 2),
            rw: const {'food': 30},
            k: 'tapes',
            outro: (g) {
              final asked = g.caseRec(9)?['p'] == 'a';
              return [
                if (asked) _keeper('그때 말한 거요. 다시 말할게요.'),
                _keeper('안테나 부서지던 밤이요. 새벽 세 시쯤, 무전실 쪽 어둠에 누가 쪼그려 앉아 있었어요. …은호 씨였어요.'),
                const Line(_me, '웅성거림이 번졌다.'),
                const Line(10, '…그 시간엔 방송 중이었어요.'),
                _keeper('방송은 흐르고 있었죠. 근데 무전실엔 아무도 없었어요.'),
                const Line(_me, '은호가 늘 하던 말이었다. 그 시간엔 방송 중이었어요.'),
                const Line(_me, '말하지 않아도 된다고 했다.'),
                const Line(10, '…아니요. 말할게요.'),
                const Line(10, '새벽 방송은… 전부 전날 녹음한 거예요.'),
                const Line(10, '그 시간이 되면 손이 떨려서 마이크를 못 켜요. 그래서 틀어 놓고 밖에 나가 있었어요. 지나갈 때까지.'),
                const Line(3, '뭐가 지나가요?'),
                if (g.hasSv(3)) const Line(10, '…시간이요.'),
                _keeper('그걸 누가 믿어요.'),
                const Line(jinId, '나 봤어.'),
                const Line(jinId, '밤에 돌아다니다 몇 번. 저 사람 혼자 쪼그려 앉아 있었어. 추운데.'),
                const Line(jinId, '…그냥 앉아만 있었어.'),
                const Line(_me, '사건 수첩 6번 장이 떠올랐다. 라벨 날짜가 하루 전이던 테이프.'),
                const Line(10, '산골 그 밤도요. 장비 탓 아니었어요. 처음으로 그 시간에 직접 해 보려고 했는데… 손이 또. 제가 내렸어요.'),
                const Line(10, '그날 이후로 계속 그래요.'),
                const Line(_me, '그날이 언제냐고는 아무도 묻지 않았다. 여기 있는 사람 모두에게 그날은 하나였다.'),
                _keeper('…그래도 거짓말한 건 거짓말이죠.'),
                const Line(10, '네.'),
                const Line(_me, '그 시간이 되면 손이 떨린다는 말에, 재혁이 고개를 들었다.'),
                const Line(_me, '그날 밤부터 은호는 방송 테이프를 모두 내놓았다. 날짜순으로.'),
                if (g.hasSv(11)) ...const [
                  Line(_me, '그 밤 모닥불 곁. 둘은 내가 있는 걸 잊은 것 같았다.'),
                  Line(11, '은호 씨. 아까… 손 떨린다는 거요.'),
                  Line(10, '네.'),
                  Line(11, '저도 그날 이후로 하늘 볼 때마다 그래요.'),
                  Line(11, '그 전날 저녁 원고, 기억나요? 내일은 맑겠습니다.'),
                  Line(10, '…복도에서 봤어요. 원고가 바뀌는 거.'),
                  Line(11, '알아요. 그때 은호 씨랑 눈 마주쳤잖아요.'),
                  Line(11, '며칠 전부터 발전소 위에 이상한 빛무리가 떴어요. 시험할 때마다요. 저는 봤어요. 근데 말 안 했어요.'),
                  Line(11, '위에서 하지 말라니까. 그게 다였어요.'),
                  Line(10, '…저도요.'),
                  Line(_me, '은호가 잠깐 말을 멈췄다.'),
                  Line(10, '저도 그 원고 보고 아무 말 안 했으니까요.'),
                  Line(11, '우리 방송국이 입 다문 날이네요. 둘 다.'),
                  Line(11, '그래서 지금은 매일 저녁 진짜 하늘을 말해요. 다시는 틀리지 않으려고.'),
                  Line(10, '알아요. 설화 씨가 얕다고 하면, 저는 그 밤에 방송해요.'),
                  Line(11, '…그럼 우리, 또 같이 방송하는 거네요.'),
                  Line(_me, '은호가 작게 웃었다. 쉘터에 온 뒤로 처음 보는 얼굴이었다.'),
                  Line(_me, '장작이 탁 튀었다. 둘이 그제야 나를 봤다.'),
                  Line(_me, '은호가 먼저 고개를 돌렸다.'),
                ],
              ];
            }),
        S2Step('지하 서고 · 원정 한 번 보내기', '원정 탭에서 먼 원정을 보내요 · 30분부터', (g) => g._s2Rel('exp', g.num_('expDone')),
            rw: const {'parts': 15, 'wire': 4},
            intro: (g) => const [Line(9, '지하에 봉인된 서고가 있어요. 거기 기록이 있으면… 그날이 왜 그렇게 됐는지 알 수 있을지도 몰라요.')],
            outro: (g) => const [
                  Line(_me, '원정 조가 젖은 종이 상자를 안고 올라왔다.'),
                  Line(_me, '서고 옆에 작은 방이 하나 더 있었다고 했다. 아이 침대 하나, 벽에 크레용 그림.'),
                  Line(_me, '원정 조가 그림을 떼어 왔다. 랜턴을 든 남자와, 그 손을 잡은 작은 아이.'),
                  Line(_me, '한참 그 그림 앞에 서 있었다. 왜 그랬는지 모르겠다.'),
                  Line(33, '보고서 같은 게 하나 있어요. 사고 보고서요. 날짜가 아주 오래됐어요. 피해자 이름은 다 지워져 있고요.', fb: Line(9, '사고 보고서예요. 중단 직전 겨울 거예요. 피해자 이름은… 지워져 있어요.')),
                  Line(9, '…중단 직전 겨울이에요.', cond: 'sv33'),
                ]),
        S2Step('렌즈 공사 · 철판 20 · 전선 8', '자재가 모이면 받기를 눌러요', (g) => true,
            cost: const {'plate': 20, 'wire': 8},
            rw: const {'batt': 1},
            k: 'jh',
            intro: (g) {
              final conf = g.conf, c5 = g.caseRec(4)?['p'] == 'a';
              return [
                const Line(9, '이거 다 끼우면, 저수지 불빛이랑 이어질 거예요.'),
                const Line(_me, '재혁은 렌즈를 끼우다 말고 손을 멈췄다.'),
                const Line(9, '…할 말이 있어요. 그때 못 한 거요.'),
                const Line(9, '그날 제가 제어실 문 열고 도망쳤다고 했죠.'),
                const Line(9, '그때 제가 두고 나온 사람… 책임 연구원님이었어요.'),
                const Line(9, '당신 아버지요.'),
                const Line(_me, '바람이 불었다. 시험등이 한 번 흔들렸다.'),
                const Line(_me, '알고 있었느냐고 물었다.'),
                const Line(9, '랜턴을 처음 본 날부터요. 그건 그분 거니까.'),
                const Line(9, '미안해요. 이 말을 하는 데 이렇게 오래 걸렸어요.'),
                if (c5) ...[
                  const Line(9, '그때 말했던 젊은 남자요. …당신 아버지 곁에 있던 사람이었어요.'),
                  const Line(_me, '아버지 곁에 누가 있었다는 거냐고 물었다.'),
                  if (conf == 'b') const Line(9, '나머지는 확인하고 말할게요.'),
                  const Line(9, '…내일, 둘이서 다시 얘기해요.'),
                ] else if (conf == 'b') ...const [
                  Line(9, '더 있어요. 근데 그건… 말로 갚을 일은 아니라서요.'),
                  Line(9, '확인하고 나서 말할게요. 내일.'),
                  Line(_me, '재혁은 다시 렌즈를 끼우기 시작했다. 손이 조금 떨렸다.'),
                ] else ...const [
                  Line(9, '그리고 하나 더요. 그날 밤 제어실에서 미영 씨 전화를 넘겨받은 사람이 있었어요.'),
                  Line(9, '전화를 넘겨받은 건… 젊은 남자였어요. 책임 연구원님 곁에 있던.'),
                  Line(_me, '아버지 곁에 누가 있었느냐고 물었다.'),
                  Line(_me, '재혁은 대답하지 않았다. 나를 오래 보았다.'),
                  Line(9, '…내일, 둘이서 다시 얘기해요.'),
                ],
              ];
            },
            outro: (g) => const [
                  Line(_me, '렌즈가 다 끼워지자 시험등의 빛이 저수지까지 곧게 닿았다. 노선도에 두 번째 빛줄기가 생겼다.'),
                  Line(11, '오늘 밤은 하늘이 얕아요.'),
                  Line(_me, '은호가 고개를 끄덕였다.'),
                  Line(_me, '잠들기 전, 재혁의 자리에 아직 불이 켜져 있었다. 노트에 뭔가를 쓰고 있었다.'),
                  Line(_me, '03:11. 라디오에서 녹음 방송이 흘렀다. 재혁의 자리는 비어 있었다.'),
                  Line(_me, '다시 자야… 겠습니다.'),
                ]),
        S2Step('문설주에 이름 새기기', '사건 수첩의 그날 아침을 정리해요', (g) => g.caseRec(10)?['p'] != null,
            rw: const {'batt': 1},
            intro: (g) => const [Line(_me, '재혁의 이름을 새길 나무를 골랐다. 아무도 말이 없었다.')],
            outro: (g) => const [
                  Line(_me, '문설주에 이름이 하나 늘었다.'),
                  Line(_me, '하늘이가 재혁의 노트를 품에 안고 있었다. 돌려 달라고 하지 않았다.'),
                ]),
        S2Step('처음 불을 켠 동네로 떠나기', '위쪽 띠의 ‘새 동네로’를 눌러요', (g) => false,
            go: 'hometown',
            intro: (g) {
              g.s2F['note2'] = 1;
              return const [
                Line(0, '저 멀리 불빛… 우리 동네 탑이구먼. 처음 불 켠 데.', fb: Line(_g, '저 멀리 불빛, 처음 불을 켠 동네 탑이에요.')),
                Line(_me, '수첩 마지막 장. 다음은 처음 불.'),
              ];
            }),
      ];

  // ================= 무대 3 · 처음 불을 켠 동네 =================
  List<S2Step> get _s2Home => [
        S2Step('문설주 앞에 서기', '잠시 뒤 받기를 눌러요', (g) => true,
            rw: const {'food': 30, 'batt': 1},
            intro: (g) => const [Line(_me, '쉘터 문설주의 이름들이 그대로였다. 바람에 조금 흐려졌을 뿐.')],
            outro: (g) {
              final b = (g.s2F['back'] as num?)?.toInt();
              return [
                const Line(_me, '무전으로 듣던 목소리들이 다시 얼굴이 되어 달려 나왔다.'),
                if (b != null && g.hasSv(b)) Line(b, b == 5 ? '왔나? 진짜 왔어!' : b == 4 ? '왔나, 참말로 왔데이.' : b == 6 ? '왔냐.' : '왔어요? 진짜 왔어요?'),
              ];
            }),
        S2Step('혼자 공터 걸어 보기', '잠시 뒤 받기를 눌러요', (g) => true,
            intro: (g) => [
                  const Line(_me, '사람들이 다 나간 낮, 혼자 공터로 걸어 나왔다.'),
                  const Line(_me, '쓰러진 슈퍼 간판. 그날 밤, 여기 왼편에 텐트를 쳤다.'),
                  const Line(_me, '그런데 왼편 땅엔 말뚝 자국이 하나도 없었다.'),
                  const Line(_me, '말뚝이 박혔던 구멍은 오른편에만 있었다. 마흔세 날째부터 내가 지낸 자리.'),
                  const Line(_me, '…내가 잘못 기억하고 있었나.'),
                  const Line(_me, '발이 저절로 집 쪽으로 향했다. 무너진 담장, 반쯤 남은 현관.'),
                  const Line(_me, '아버지는 여기서 랜턴을 건넸다. 잘 들고 있어라. 그 말만 남기고.'),
                  const Line(_me, '현관에 섰다. 문고리를 잡으려는데, 다른 손이 무거웠다.'),
                  const Line(_me, '그날도 그랬던 것 같다. 문을 나서던 손에 랜턴이 들려 있었다.'),
                  const Line(_me, '랜턴을 들고 있던 건… 아버지가 아니라 나였던 것 같다.'),
                  const Line(_me, '신발장 위, 전화기가 놓여 있던 자리에 먼지 자국만 네모나게 남아 있었다.'),
                  const Line(_me, '그날 밤, 저 전화가 울렸던가.'),
                  const Line(_me, '머리가 아팠다.'),
                  if (g.hasSv(3)) ...const [Line(3, '아저씨! 다들 왔어요. 밥 먹어요!'), Line(_me, '하늘이가 내 빈손을 잡아끌었다. 랜턴 든 손은 놓아두고.')] else const Line(_me, '멀리서 저녁 짓는 연기가 올랐다. 돌아가야 했다.'),
                  const Line(_me, '돌아오는 길에 한 번도 뒤돌아보지 않았다.'),
                ]),
        S2Step('첫 탑을 등불망에 잇기 · 전선 12 · 철판 30 · 연료 40', '자재가 모이면 받기를 눌러 랜턴으로 이어요', (g) => true,
            cost: const {'wire': 12, 'plate': 30, 'fuel': 40},
            rw: const {'batt': 2},
            k: 'ring',
            intro: (g) => const [Line(13, '첫 탑이에요. 심지가 든 탑. 이걸 이으면… 지금까지 켠 불이 전부 하나로 이어져요.')],
            outro: (g) => [
                  const Line(_me, '탑 꼭대기에서 랜턴을 들었다. 빛줄기들이 둥글게 닫혔다.'),
                  const Line(_me, '그날 밤 하늘의 재가 가장 얕았다. 별이 몇 개 보였다.'),
                  const Line(3, '아저씨, 별이 네 개예요! 아니, 다섯 개!'),
                  if (g.hasSv(11)) const Line(11, '오늘 밤은 하늘이 얕아요. 이렇게 얕은 건 처음이에요.') else const Line(10, '오늘은… 얕네요. 설화 씨가 있었으면 그렇게 말했을 거예요.'),
                ]),
        S2Step('축하 방송 · 밤 하나 넘기기', '해가 지고 새벽이 오면 돼요', (g) => g._s2Rel('night', g.num_('nights')),
            rw: const {'food': 30},
            k: 'c12',
            intro: (g) => [
                  g._local('오늘 같은 날 방송 안 하면 언제 해요. 은호 씨, 한 곡만요.', malsun: '오늘 같은 날 노래 안 틀면 언제 트노. 한 곡만!'),
                  const Line(10, '…오늘은 좀….'),
                  g._local('다들 기다렸어요.'),
                  const Line(_me, '은호가 나를 봤다. 나는 해도 된다고 했다.'),
                ],
            outro: (g) => [
                  const Line(_me, '그날 밤 쉘터에 노래가 흘렀다. 다들 웃었다.'),
                  if (g.hasSv(12)) const Line(12, '자네 아버지가 시계를 맡기던 해 말일세… 아니, 내일 천천히 얘기하세.') else g._local('벽에 붙은 그 그림 속 사내요. 어디서 본 것 같은데… 내일 생각나면 말할게요.'),
                ]),
        S2Step('독수리 · 그날 아침 정리하기', '사건 수첩의 그날 아침을 정리해요', (g) => g.caseRec(11)?['p'] != null,
            rw: const {'batt': 1},
            k: 'meeting',
            outro: (g) {
              final rel = g.crow['rel'];
              return [
                const Line(_me, '재구름 너머에서 검은 새 표식이 보였다. 독수리 혼자였다.'),
                Line('npc:crow', rel == 'deal' ? '통행료 낸 사이니, 오늘은 장사하러 왔소.' : rel == 'fight' ? '싸우러 온 건 아니오. 그날 빚은 아직이지만.' : '그때 길을 비켜 준 덕에 여기까지 왔소. 이번엔 우리가 물으러 왔소.'),
                if (g.hasSv(jinId)) ...const [Line(_me, '진이 내 등 뒤로 반 걸음 물러났다.'), Line('npc:crow', '…아직 여기 있었군.'), Line(jinId, '…대장.')],
                const Line('npc:crow', '요 며칠 시그널이 자주 들리더군. 무슨 일이 있소?'),
                const Line(_me, '등불이 이어져 축하할 일이 있었다고 했다.'),
                const Line('npc:crow', '그래서 그랬군. 우린 그 방송을 따라 여기까지 왔소.'),
                const Line('npc:crow', '이 동네에 처음 왔던 밤도. 그 노래가 우리를 문 앞까지 데려왔소.'),
                const Line(_me, '처음 왔던 밤. 창고가 털리던, 그 재폭풍의 밤.'),
                if (g.hasSv(6)) const Line(6, '…그 밤 창고 털린 게 방송 때문이었다고?') else g._local('그 밤 창고 털린 게… 방송 때문이었다고요?'),
                const Line('npc:crow', '탓하러 온 건 아니오. 들리니까 왔을 뿐이지.'),
                const Line(_me, '독수리는 떠나며 옛 시그널을 흥얼거렸다. 은호만 그 노래가 끝날 때까지 고개를 들지 않았다.'),
                _keeper('새벽 세 시마다 밖에 있었던 것도 은호 씨, 방송도 은호 씨예요.'),
                _keeper('재혁 씨 그 밤도 은호 씨가 방송한 밤이었어요.'),
                g._local('어르신 다친 밤은 축하 방송이었고요.'),
                _keeper('새벽 세 시마다 그 사람이 밖에 있었어요. 이게 우연이에요?'),
                const Line(_me, '아무도 대답하지 않았다. 다들 은호를 보고 있었다.'),
                const Line(10, '…….'),
                const Line(_me, '은호는 변명하지 않았다.'),
              ];
            }),
        S2Step('하늘이가 본 것 · 밤 하나 넘기기', '해가 지고 새벽이 오면 돼요', (g) => g.s2F['meet'] != null && g._s2Rel('night', g.num_('nights')),
            rw: const {'food': 20},
            intro: (g) => const [
                  Line(3, '아저씨. 은호 아저씨가 밤에 탑 밑에 뭘 묻었어요.'),
                  Line(_me, '그런 말 함부로 하면 안 된다고 했다.'),
                  Line(3, '진짜예요.'),
                  Line(jinId, '하늘이는 거짓말 안 해.'),
                ],
            outro: (g) => const [Line(_me, '탑 밑을 파 보자는 사람은 없었다. 다음 날 아침, 흙이 다시 덮여 있었다. 누가 덮었는지는 몰랐다.')]),
        S2Step('발전소로 떠나기', '위쪽 띠의 ‘새 동네로’를 눌러요', (g) => false,
            go: 'plant',
            intro: (g) {
              g.s2F['note3'] = 1;
              return const [
                Line(13, '발전소로 가야 해요.'),
                Line(_me, '미영이 먼저 어디로 가자고 한 건 처음이었다.'),
                Line(_me, '수첩 마지막 장. 다음은 심장.'),
              ];
            }),
      ];

  // ================= 무대 4 · 발전소 =================
  List<S2Step> get _s2Plant => [
        S2Step('캠프 세우기 · 판잣집 쉘터', '쉘터를 판잣집으로 키워요', (g) => g.S.lv >= 2,
            rw: const {'food': 30, 'batt': 1},
            intro: (g) => const [
                  Line(_me, '재의 눈 한가운데. 발전소 굴뚝이 손에 닿을 듯 가까웠다.'),
                  Line(_g, '여기선 불 하나 꺼지면 끝이구먼. 캠프부터 단단히.'),
                ],
            outro: (g) => const [Line(_me, '캠프에 불이 들어왔다. 재의 벽은 그대로였지만, 발밑은 보였다.')]),
        S2Step('무너진 천장 치우기 · 사람 보내기 6번', '폐허를 눌러 사람을 보내 둬요 · 다녀올 때마다 판넬을 조금씩 치워요',
            (g) => g._s2Rel('trips', (g.s2['trips'] as num?) ?? 0, 6),
            rw: const {'plate': 10},
            intro: (g) => const [Line(13, '제어실 천장 판넬이 그날 무너졌어요. 그 밑에… 운전 기록계가 있어요.')],
            outro: (g) {
              g.fx.add(const FxCut('s2_counter', [0, 1, 2, 3]));
              return const [
                Line(_me, '판넬 아래, 먼지 덮인 운전 기록계가 있었다. 종이가 말려 있었다.'),
                Line(_me, '미영이 종이를 펼쳤다. 손가락이 통신반 쪽으로 아주 조금 움직였다가 멈췄다.'),
                Line(_me, '지진 때 기록이냐고 했다.'),
                Line(_me, '미영이 종이를 접어 품에 넣었다.'),
              ];
            }),
        S2Step('제어실 전원 · 연료 60 · 전선 10', '자재가 모이면 받기를 눌러요', (g) => true,
            cost: const {'fuel': 60, 'wire': 10},
            rw: const {'batt': 1},
            intro: (g) => const [Line(13, '기록계를 읽으려면 제어실에 전기를 넣어야 해요.')],
            outro: (g) => const [
                  Line(_me, '전등이 깜빡이며 켜졌다. 그리고 다른 소리가 따라왔다.'),
                  Line(_me, '등불 계획 중단. 반경 내 인원은 대피하라.'),
                  Line(_me, '기계 목소리가 캠프의 라디오마다 되풀이됐다.'),
                  Line(_me, '미영은 끌 수 있다고 했다. 기록계를 다 읽기 전엔 전원을 내릴 수 없다고.'),
                ]),
        S2Step('심장부로 내려가기', '잠시 뒤 받기를 눌러 랜턴을 들고 내려가요', (g) => true,
            rw: const {'batt': 1},
            k: 'c13',
            intro: (g) => const [Line(13, '실험로 아래는… 랜턴 빛 없이는 못 내려가요.')],
            outro: (g) => const [
                  Line(_me, '랜턴을 들고 계단을 내려갔다. 아무도 없었다.'),
                  Line(_me, '벽에 손톱으로 긁은 줄이 여러 개. 날짜를 센 것 같았다.'),
                  Line(_me, '바닥에 도면 한 장. 귀퉁이에 등불 문양.'),
                  Line(_me, '랜턴 그림이었다. 한 곳에 동그라미가 쳐져 있었다. 무슨 뜻인지는 알 수 없었다.'),
                  Line(_me, '도면을 들고 올라와 캠프 탁자에 펼쳤다. 돌멩이로 귀퉁이를 눌러 두었다.'),
                  Line(_me, '미영이 도면을 보다 얼굴이 굳었다. 아무 말도 하지 않았다.'),
                ]),
        S2Step('하늘이의 말 · 그날 아침 정리하기', '사건 수첩의 그날 아침을 정리해요', (g) => g.caseRec(12)?['p'] != null,
            rw: const {'batt': 1},
            k: 'eh',
            outro: (g) => const [
                  Line(3, '은호 아저씨가 뭘 숨겼어요. 다들 봐야 돼요.'),
                  Line(3, '이번엔 탑 밑이 아니에요. 아저씨 가방에요.'),
                  Line(_me, '모두가 은호를 봤다. 은호는 하늘이를, 그다음 나를 오래 봤다.'),
                  Line(_g, '…내일 아침에 다 같이 보자고.'),
                  Line(_me, '캠프 끝, 꺼진 제어동 그림자 아래.'),
                  Line(_me, '은호와 미영이 같은 자리에 서 있는 걸 처음 봤다.'),
                  Line(_me, '먼저 다가간 건 은호였다.'),
                  Line(_me, '무슨 말인지는 바람에 묻혔다.'),
                  Line(_me, '은호가 허리를 깊이 숙였다. 오래.'),
                  Line(_me, '미영이 손으로 입을 막았다.'),
                  Line(_me, '둘이 한 번, 동시에 내 쪽을 봤다. 나는 장작을 내려놓는 척했다.'),
                  Line(_me, '은호가 외투 안주머니에 손을 넣었다. 무언가 꺼내려다, 그대로 멈췄다.'),
                  Line(_me, '돌아서는 은호의 소매를 미영이 붙잡았다. 무언가 말했다. 은호가 고개를 끄덕였다.'),
                ]),
        S2Step('끝난 일', '사건 수첩의 그날 아침을 정리해요', (g) => g.caseRec(13)?['p'] != null,
            k: 'final',
            intro: (g) => [_keeper('끝났네요. 범인이 있었고, 이제 끝났어요.', me: '끝났다고, 누군가 말했다.'), const Line(_me, '아무도 대답하지 않았다. 몇몇이 고개를 끄덕였다.')],
            outro: (g) => [
                  const Line(_me, '살아 있는 은호를 본 건 그게 마지막이었다.'),
                  if (g.hasSv(11)) ...const [
                    Line(11, '…잠깐만요.'),
                    Line(_me, '설화가 관측 일지를 내 앞에 펼쳤다. 손가락이 날짜를 따라 내려가다 멈췄다.'),
                    Line(11, '재혁 씨 밤. 어르신 다친 밤. 전부… 제가 하늘이 얕다고 한 날이에요.'),
                    Line(11, '은호 씨는 그 말 듣고 방송했고요.'),
                    Line(_me, '설화는 일지를 덮지 못했다.'),
                  ] else if (g.inStay(11) && !g.isDead(11))
                    const Line('r:11', '…일지를 다시 봤어요. 다 제가 얕다고 한 밤이에요. 그 사람이 정말 그랬을까요.')
                  else
                    const Line(3, '아저씨, 은호 아저씨 테이프 날짜요. 재혁 아저씨 날이랑, 어르신 날이랑… 다 같아요.'),
                  const Line(_me, '해 질 녘, 독수리가 홀로 찾아왔다. 문설주 앞에서 옛 시그널을 흥얼거렸다. 알아듣는 사람이 없었다.'),
                  const Line('npc:crow', '사흘째 시그널이 안 들리더군.'),
                  const Line('npc:crow', '…그 목소리로 그런 짓을 할 사람이 아니오.'),
                  if (g.hasSv(jinId)) const Line(_me, '진이 독수리를 부르려다 멈췄다.'),
                  const Line(_me, '은호의 이름을 문설주에 새긴 밤이었다.'),
                  const Line(_me, '랜턴을 무릎에 올려 두고 앉아 있었다.'),
                  const Line(13, '…잠깐 앉아도 돼요?'),
                  const Line(_me, '미영이 먼저 나를 찾아온 건 처음이었다.'),
                  const Line(13, '그날… 아버님이 내려가시기 전에 하신 말이 있어요.'),
                  const Line(_me, '아버지라는 말에 고개를 들었다.'),
                  const Line(13, '심지를 지켜. 그리고 그 애가 오면…'),
                  const Line(13, '…랜턴을 끄게 해.'),
                  const Line(_me, '그 애가 나냐고 물었다.'),
                  const Line(13, '…네.'),
                  const Line(_me, '왜냐고 물었다.'),
                  const Line(_me, '미영은 입을 열었다가, 다시 닫았다.'),
                  const Line(13, '미안해요. 너무 늦게 전해서.'),
                  const Line(_me, '랜턴을 내려다봤다. 이 불이 꺼지면 재는 녹지 않는다. 탑도 깨어나지 않는다.'),
                  const Line(_me, '이건 못 끈다고 했다.'),
                  const Line(13, '알아요.'),
                  const Line(13, '그래서 지금까지 말 못 했어요.'),
                  const Line(_me, '미영이 돌아간 뒤에도 한참 앉아 있었다.'),
                  const Line(_me, '아버지는 왜.'),
                  const Line(_me, '랜턴의 갓이 미지근했다.'),
                  const Line(_me, '03:10. 하늘이 잠든 자리. 이불이 발치로 흘러내려 있었다.'),
                  const Line(_me, '끌어 올려 주었다. 랜턴 불빛이 아이 얼굴에 닿았다.'),
                  const Line(_me, '추웠겠다.'),
                  const Line(_me, '시계가 03:11로 넘어갔다.'),
                  const Line(_me, '따뜻하게 자야… 합니다.'),
                ]),
      ];
}
