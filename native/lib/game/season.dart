// 5단계: 시즌 1의 수수께끼 — 사건 수첩(6건), 사라진 3분(조각 셋 → 찢어진 페이지), 까마귀(흔적·접촉·습격·대치),
// 수상한 밤(새벽 3시)·기척, 회상 갤러리, 엔딩 '다시, 03:11'. 웹 index.html 5578–6014, 5862–5925.
// 누가 범인인지는 끝까지 말하지 않는다. 단서는 사람을 추궁할 때만 모인다.
part of 'engine.dart';

const jinId = 17;

class CaseOpt {
  const CaseOpt(this.l, this.r, {this.clue});
  final String Function(Game g) l;
  final List<Line?> Function(Game g) r;
  final String? clue;
}

class CaseInfo {
  const CaseInfo(
      {required this.ch,
      required this.t,
      required this.when,
      this.sus,
      required this.susN,
      this.solved = false,
      this.tut = false,
      this.all = false,
      required this.gate,
      required this.x,
      this.alibi,
      required this.a,
      required this.b,
      required this.c,
      this.end,
      this.log,
      this.tail,
      this.tailClue});
  final String ch, t, when, susN;
  final int? sus;
  final bool solved, tut, all;
  final bool Function(Game g) gate;
  final List<Line?> Function(Game g) x;
  final String? alibi, log, tailClue;
  final CaseOpt a, b, c;
  final String Function(Game g)? end;
  final List<Line>? tail;
  CaseOpt opt(String p) => p == 'a' ? a : p == 'b' ? b : c;
}

const _g = 'g', _me = 'me';

/// 사건 여섯 (웹 CASES 5688)
final List<CaseInfo> cases = [
  CaseInfo(
    ch: '3장',
    t: '사라지는 통조림',
    when: '해 질 녘',
    sus: 3,
    susN: '새로 온 사람들',
    solved: true,
    tut: true,
    gate: (g) => g.mi >= stepI('생존자 3명 모으기') && g.hasSv(3),
    x: (g) => const [Line(_g, '창고 통조림이 자꾸 한두 개씩 비어. 벌써 사흘째야.'), Line(_g, '꼭 해 질 녘이야. 새로 온 사람 중에 누가 몰래 챙기는 거 아닌가 몰라.')],
    a: CaseOpt(
        (g) => '해 질 녘에 창고를 지켜본다',
        (g) => const [
              Line(_me, '해가 기울자 창고 문이 삐걱 열렸다. 하늘이가 통조림을 안고 살금살금 나갔다.'),
              Line(3, '…미안해요. 쉘터 뒤에 떠돌이 개가 있는데, 너무 배고파 보였어요.'),
              Line(3, '근데 진짜예요. 창고 문은 이미 열려 있었어요.'),
              Line(_me, '창고 열쇠는 내 허리춤에 있다. 잠그는 걸 깜빡했나 보다.'),
            ]),
    b: CaseOpt(
        (g) => '모른 척 식량을 더 채워 둔다',
        (g) => [
              const Line(_me, '며칠 뒤, 하늘이가 쉘터 뒤에서 떠돌이 개에게 몰래 밥을 주는 걸 봤다.'),
              Line(3, g.S.rest['dog'] != null ? '…들켰다. 등불이 친구예요. 밥만 조금 나눠 주면 안 돼요?' : '…들켰다. 얘 이름 지어 줘도 돼요?'),
            ]),
    c: CaseOpt((g) => '그냥 넘어간다', (g) => const [Line(_me, '며칠 뒤 해 질 녘, 쉘터 뒤에서 개 짖는 소리가 났다. 하늘이가 떠돌이 개를 끌어안고 있었다.')]),
    end: (g) {
      if (g.S.rest['dog'] == null) {
        g.S.rest['dog'] = 1;
        return '떠돌이 개가 식구가 됐어요. 이름은 ‘등불’';
      }
      return '';
    },
    log: '범인은 하늘. 떠돌이 개에게 밥을 주고 있었다.',
  ),
  CaseInfo(
    ch: '4장',
    t: '돌아가 있는 다이얼',
    when: '새벽 3시 무렵',
    sus: 3,
    susN: '새로 온 사람들',
    gate: (g) => g.mi >= stepI('첫 원정 보내기') && g.hasSv(10),
    x: (g) => [
      const Line(_g, '라디오 다이얼이 엉뚱한 데로 돌아가 있어. “등불 계획 중단”이 되풀이되던 그 주파수에 맞춰 뒀었는데.'),
      g.hasSv(3) ? const Line(_g, '새벽 3시쯤 누가 만졌대. 등불지기도 그랬잖아, 하늘이가 요즘 라디오 앞에서 안 떠난다고.') : const Line(_g, '새벽 3시쯤 누가 만졌대. 등불지기도 요즘 누가 라디오를 만지는 것 같다고 했잖아.'),
      const Line(_me, '내가 그런 말을 했던가. 요즘 피곤해서 그런지 기억이 잘 나지 않는다.'),
      const Line(10, '전 그 시간에 방송 중이었어요. 제 송신기 앞에서요.'),
      const Line(_me, '다이얼 손잡이에서 희미하게 기름 냄새가 났다. 그날 밤 나는 일찍 잠들었는데… 깨어 보니 새벽 3시 20분이었다.'),
    ],
    alibi: '은호: “그 시간엔 방송 중이었어요.”',
    a: CaseOpt((g) => '하늘이를 불러 묻는다', (g) => const [Line(3, '나 아니야! 그 시간엔 자고 있었단 말이야!'), Line(_me, '다이얼을 다시 봤다. 손잡이에 남은 손자국은 아이 손보다 훨씬 컸다.')],
        clue: '다이얼에 남은 손자국은 아이 손이 아니라 어른 손이었다. 기름 냄새가 났다.'),
    b: CaseOpt((g) => '하늘이 편을 든다', (g) => const [Line(3, '…믿어 줘서 고마워요. 진짜 나 아니에요.')]),
    c: CaseOpt((g) => '주파수만 다시 맞춰 둔다', (g) => const [Line(_me, '다이얼을 되돌려 놓았다. 누가 돌렸는지는 모른 채로.')]),
  ),
  CaseInfo(
    ch: '5장',
    t: '반쯤 끊긴 밧줄',
    when: '새벽 3시 무렵',
    sus: 1,
    susN: '까마귀',
    gate: (g) => g.mi >= stepI('지하 구역 4층까지 내려가기'),
    x: (g) => [
      const Line(_g, '어제 걸어 둔 지하 기록실 밧줄이 밤새 반쯤 끊겨 있었어. 그대로 내려갔으면 누구 하나 떨어졌을 거야.'),
      const Line(_g, '새벽 3시쯤 창고 쪽에서 발소리를 들었다는 사람이 있어.'),
      g.hasSv(1) ? const Line(_g, '도윤이가 요즘 밤마다 밖을 돌아다니잖아. 아니면… 까마귀 짓이든가.') : const Line(_g, '까마귀 놈들 짓일지도 몰라.'),
      const Line(_me, '끊긴 자리 둘레에 둥근 그을음이 고리처럼 남아 있었다. 그날 아침, 내 랜턴 기름이 반쯤 줄어 있었다. 밤새 켜 둔 기억은 없는데.'),
    ],
    a: CaseOpt(
        (g) => g.hasSv(1) ? '도윤을 불러 묻는다' : '창고를 샅샅이 뒤진다',
        (g) => [
              g.hasSv(1) ? const Line(1, '밤에 나가는 건 배달하던 버릇이에요. 밧줄엔 손도 안 댔어요.') : const Line(_me, '창고에는 발자국 하나 없었다.'),
              const Line(_me, '끊긴 자리를 들여다봤다. 칼로 자른 게 아니었다. 뜨거운 걸 대서 녹여 끊은 자국이었다.'),
            ],
        clue: '밧줄은 칼이 아니라 뜨거운 것으로 녹여 끊겨 있었다. 둥근 그을음 고리가 남아 있었다.'),
    b: CaseOpt((g) => g.hasSv(1) ? '도윤을 믿는다' : '모두를 믿기로 한다',
        (g) => [g.hasSv(1) ? const Line(1, '…믿어 줘서 고마워요. 밤길은 제가 더 조심할게요.') : const Line(_me, '아무도 의심하지 않기로 했다.')]),
    c: CaseOpt((g) => '까마귀 짓이라고 해 둔다', (g) => const [Line(_me, '다들 까마귀를 탓했다. 그게 제일 편했다.')]),
  ),
  CaseInfo(
    ch: '7장',
    t: '잘린 안테나',
    when: '새벽 3시 무렵',
    sus: 6,
    susN: '까마귀',
    gate: (g) => g.hasMod(7) && g.mi >= stepI('무전실 세우기'),
    x: (g) => [
      const Line(_g, '발전소 목소리가 잡힌 바로 그날 밤이야. 무전실 안테나 선이 잘렸어.'),
      g.hasSv(6) ? const Line(_g, '새벽 3시 무렵이래. 철호가 그 시간에 공구 들고 나가는 걸 본 사람이 있어.') : const Line(_g, '새벽 3시 무렵이래. 까마귀가 또 다녀갔나.'),
      g.hasSv(10) ? const Line(10, '그 시간엔 저 방송 중이었어요. 끊긴 줄도 몰랐네요.') : null,
      const Line(_me, '손등이 따끔했다. 언제 덴 건지 모를 작은 화상이 있었다.'),
    ],
    alibi: '은호: “그 시간엔 방송 중이었어요.”',
    a: CaseOpt(
        (g) => g.hasSv(6) ? '철호를 불러 묻는다' : '안테나를 샅샅이 살핀다',
        (g) => [
              g.hasSv(6) ? const Line(6, '공구는 방벽 고치러 들고 나간 거요. 전선은 내 일이 아니오.') : const Line(_me, '안테나 아래에는 발자국 하나 없었다.'),
              const Line(_me, '잘린 전선 끝을 만져 봤다. 둥글게 눌린 화상 자국이 있었다. 철호의 인두, 은호의 납땜기… 쉘터엔 뜨거운 걸 다루는 손이 여럿이다.'),
            ],
        clue: '잘린 전선 끝에 둥글게 눌린 화상 자국이 남아 있었다.'),
    b: CaseOpt((g) => g.hasSv(6) ? '철호를 믿는다' : '모두를 믿기로 한다',
        (g) => [g.hasSv(6) ? const Line(6, '…고맙소. 선은 내가 다시 이어 두지.') : const Line(_me, '아무도 의심하지 않기로 했다.')]),
    c: CaseOpt((g) => '까마귀 짓이라고 해 둔다', (g) => const [Line(_me, '까마귀가 무전을 막으려 한 거라고, 다들 그렇게 믿었다.')]),
  ),
  CaseInfo(
    ch: '8장',
    t: '뜯겨 나간 한 장',
    when: '새벽 3시 무렵',
    sus: 9,
    susN: '재혁',
    gate: (g) => g.hasSv(13) && g.hasSv(9) && g.mi >= stepI('탁미영 맞이하기'),
    x: (g) => const [
      Line(9, '…제 연구 노트에서 한 장이 뜯겨 나갔어요. 그날 새벽 기록이에요.'),
      Line(_g, '새벽 3시쯤 재혁 자리에 불이 켜져 있었다던데. 자기가 찢어 놓고 모른 척하는 거 아냐?'),
      Line(_g, '아니면 미영 씨려나. 노트 보관함 열쇠는 등불지기가 갖고 있으니, 밖에서 연 건 아닐 테고.'),
      Line(_me, '그날 새벽 제어실에 있었던 미영에게 물어보려 했지만, 그 밤 이야기가 나오자 그녀는 조용히 자리를 떴다.'),
    ],
    a: CaseOpt(
        (g) => '재혁에게 따져 묻는다',
        (g) => const [
              Line(9, '제가 왜요! 그 장엔… 그날 새벽 제어실에서 방송국으로 건 전화가 적혀 있었어요.'),
              Line(9, '3시 11분. 그 전화를 넘겨받은 사람은… 젊은 남자였어요. 차분했어요. 이상할 만큼.'),
              Line(9, '노트엔 그렇게 적었어요. “책임 연구원 곁의 젊은 남자.”'),
            ],
        clue: '뜯긴 장에는 그날 새벽 3시 11분의 통화 기록이 있었다.'),
    b: CaseOpt((g) => '재혁을 믿는다', (g) => const [Line(9, '…고마워요. 이번엔 도망치지 않을게요.')]),
    c: CaseOpt((g) => '종이 한 장일 뿐이라고 넘긴다', (g) => const [Line(_me, '종이 한 장. 그땐 그렇게 생각했다.')]),
  ),
  CaseInfo(
    ch: '9장',
    t: '기둥에 꽂힌 쪽지',
    when: '새벽 3시 무렵',
    susN: '아무도 모름',
    all: true,
    gate: (g) => g.towerN >= 2,
    x: (g) => const [
      Line(_me, '아침에 보니 탑 기둥에 쪽지가 꽂혀 있었다. “불은 오래가지 않아.”'),
      Line(_me, '어디서 본 글씨였다. 오래 들여다볼수록 머리가 아팠다.'),
      Line(_g, '새벽 3시쯤 누가 다녀간 거야. 까마귀 놈들 짓인가?'),
    ],
    a: CaseOpt(
        (g) => '모두를 모아 묻는다',
        (g) => const [
              Line(_me, '아무도 자기가 썼다고 하지 않았다. 대신 누군가 쪽지 뒷면을 가리켰다.'),
              Line(_me, '뒷면에 시간표가 인쇄돼 있었다. 03:00, 03:30, 04:00… 줄마다 곡 제목이 적혀 있었다.'),
            ],
        clue: '쪽지 뒷면은 시간과 곡 제목이 적힌 방송 큐시트였다.'),
    b: CaseOpt((g) => '쪽지를 불에 태운다', (g) => const [Line(_me, '쪽지를 불에 넣었다. 탑 아래에서 그런 말은 필요 없다.')]),
    c: CaseOpt((g) => '사건 수첩에 끼워 둔다', (g) => const [Line(_me, '쪽지를 사건 수첩 사이에 끼워 두었다.')]),
    tail: const [Line(_me, '며칠 뒤, 창고 구석에서 라벨 없는 카세트테이프가 나왔다.'), Line(_me, '틀어 보니 사건이 있던 그 밤의 심야 방송이었다. 그런데 라벨의 날짜는 그 전날이었다.')],
    tailClue: '그 밤의 방송 테이프는 하루 전날 녹음된 것이었다.',
  ),
];

/// 새 동네 사건 셋 (웹 TCASES 5736) — 사건 7·8·9. 동네 미션 3번째부터.
const _dN = 'npc:desert', _fN = 'npc:factory', _wN = 'npc:snow';
bool _tGate(Game g) => g.rmi >= 3;
final List<CaseInfo> townCases = [
  CaseInfo(
    ch: '사막 도시',
    t: '빠진 진공관',
    when: '새벽 3시 무렵',
    sus: 14,
    susN: '마을 사람',
    gate: _tGate,
    x: (g) => [
      const Line(_dN, '급유탑 무전기가 죽었소. 누가 진공관을 쏙 빼 갔어. 당신들을 부른 바로 그 무전기요.'),
      const Line(_dN, '새벽 3시쯤이었소. 우리 마을 사람들은 그 시간에 탱크 밑에서 자고 있었는데.'),
      if (g.hasSv(10)) const Line(10, '저는 그 시간에 방송 중이었어요. 사막에서도 잘 들렸다면서요?'),
    ],
    alibi: '은호: “그 시간엔 방송 중이었어요.”',
    a: CaseOpt(
        (g) => g.hasSv(14) ? '한별에게 따져 묻는다' : '마을 사람들을 불러 묻는다',
        (g) => [
              g.hasSv(14) ? const Line(14, '진공관이요? 전 약초밖에 몰라요. 정말이에요.') : const Line(_dN, '우리 사람들은 아니오. 그 무전기가 유일한 희망이었는데.'),
              const Line(_me, '며칠 뒤, 빠진 진공관이 나왔다. 사막 마을이 아니라 우리 쉘터 공구함 안에서.'),
              const Line(_me, '공구함 열쇠는 늘 내 허리춤에 있다. 누가 언제 빌려 갔던가.'),
            ],
        clue: '빠진 진공관이 우리 쉘터 공구함에서 나왔다.'),
    b: CaseOpt((g) => g.hasSv(14) ? '한별을 믿는다' : '마을 사람들을 믿는다',
        (g) => [g.hasSv(14) ? const Line(14, '…고마워요. 무전기는 두식 할아버지랑 다시 맞춰 볼게요.') : const Line(_dN, '…믿어 줘서 고맙소.')]),
    c: CaseOpt((g) => '모래바람 탓이라고 해 둔다', (g) => const [Line(_me, '모래바람이 진공관을 날려 버렸다고, 다들 그렇게 넘어갔다.')]),
  ),
  CaseInfo(
    ch: '녹슨 공단',
    t: '끊긴 확성기',
    when: '새벽 3시 무렵',
    sus: 15,
    susN: '공단 사람들',
    gate: _tGate,
    x: (g) => [
      const Line(_fN, '공단 확성기 선이 끊겼다. 밤마다 흩어진 사람들을 불러 모으던 확성기다.'),
      const Line(_fN, '새벽 3시에. 불꽃 다루는 놈 짓이라고들 하더군.'),
      if (g.hasSv(10)) const Line(10, '그 시간엔 방송 중이었어요. 확성기 대신 제 방송 들으시면 되죠.'),
    ],
    alibi: '은호: “그 시간엔 방송 중이었어요.”',
    a: CaseOpt(
        (g) => g.hasSv(15) ? '도진을 불러 묻는다' : '공단 사람들을 불러 묻는다',
        (g) => [
              g.hasSv(15) ? const Line(15, '…내 불꽃이면 저렇게 얌전히 안 끊겨.') : const Line(_fN, '우리 사람들은 그 시간에 자고 있었다.'),
              const Line(_me, '끊긴 자리를 살폈다. 용접 불꽃이 아니었다. 무언가 뜨겁고 둥근 것을 대서 녹여 낸 자국. 둥근 그을음 고리가 남아 있었다.'),
            ],
        clue: '확성기 선은 용접이 아니라 둥글고 뜨거운 것으로 녹여 끊겨 있었다.'),
    b: CaseOpt((g) => g.hasSv(15) ? '도진을 믿는다' : '공단 사람들을 믿는다',
        (g) => [g.hasSv(15) ? const Line(15, '…말없이 다시 이어 두지.') : const Line(_fN, '…믿어 줘서 고맙다.')]),
    c: CaseOpt((g) => '재 괴물 탓이라고 해 둔다', (g) => const [Line(_me, '재 괴물이 선을 갉아 먹었다고, 다들 그렇게 믿기로 했다.')]),
  ),
  CaseInfo(
    ch: '눈 덮인 산골',
    t: '사라진 녹음테이프',
    when: '새벽 3시 무렵',
    susN: '분교 아이들',
    gate: _tGate,
    x: (g) => [
      const Line(_wN, '교실 서랍에 둔 테이프가 없어졌어요. 재가 내린 그날 밤, 아이들 재우려고 틀어 둔 라디오를 녹음한 거예요.'),
      const Line(_wN, '새벽 3시쯤 누가 교실에 들어왔대요. 아이들 중 하나가 장난친 걸까요…'),
      if (g.hasSv(10)) const Line(10, '저는 그 시간에 방송 중이었어요.'),
    ],
    alibi: '은호: “그 시간엔 방송 중이었어요.”',
    a: CaseOpt(
        (g) => '아이들을 모아 묻는다',
        (g) => const [
              Line(_wN, '아이들은 아무도 몰랐어요. 그런데… 이상한 게 하나 있어요.'),
              Line(_wN, '그 테이프, 3시 11분부터 3분 동안 아무 소리도 없었어요. 방송이 끊긴 줄 알았죠.'),
              Line(_wN, '아, 아주 작게… 딸깍, 딸깍. 뭔가 여닫는 소리만 몇 번 들렸어요.'),
            ],
        clue: '사라진 테이프에는 그날 밤 3시 11분부터 3분 동안 딸깍 소리만 남아 있었다.'),
    b: CaseOpt((g) => '아이들을 믿는다', (g) => const [Line(_wN, '그래요. 우리 애들이 그럴 리 없죠.')]),
    c: CaseOpt((g) => '그냥 잊어버리자고 한다', (g) => const [Line(_me, '테이프 한 개쯤이야. 은솔 선생님도 곧 웃었다.')]),
  ),
];

/// 사건 번호 k(0~8) → 내용. 6·7·8은 사막·공단·산골
CaseInfo caseOf(int k) => k < cases.length ? cases[k] : townCases[k - cases.length];
String caseKeyOf(int k) => k < cases.length ? '$k' : regionOrder[k - cases.length];

/// 사건 창 열기 / 고른 결과
class FxCase extends Fx {
  const FxCase(this.k);
  final int k;
}

class FxCrowMeet extends Fx {
  const FxCrowMeet();
}

/// 수상한 밤의 그림자 (지도 위에 그린다, 웹 SHD)
class OddShadow {
  OddShadow.walk(this.ax, this.ay, this.bx, this.by, this.dur) : light = null, far = false;
  OddShadow.light(this.light, this.dur, {this.far = false})
      : ax = 0,
        ay = 0,
        bx = 0,
        by = 0;
  final double ax, ay, bx, by, dur;
  final int? light;
  final bool far;
  double t = 0;
  bool got = false;
  (double, double) get pos {
    final f = math.min(1.0, t / dur), e = f * f * (3 - 2 * f);
    return (ax + (bx - ax) * e, ay + (by - ay) * e);
  }
}

const oddAt = dayLen + 31;
const _oddItems = ['녹은 납 부스러기', '구겨진 신청곡 쪽지', '이어폰 한 짝', '손때 묻은 카세트 라벨'];
const _prsT = [
  ('light', '재구름 너머에서 불빛 하나가 켜졌다가, 누가 손으로 가린 것처럼 꺼졌다.'),
  ('steps', '텐트 뒤에서 자갈 밟는 소리. 돌아보니 아무도 없다.'),
  ('dog', '멀리서 짖던 개가 갑자기 조용해졌다. 바람도 같이 멎었다.'),
  ('lamp', '랜턴 불꽃이 저절로 낮게 줄었다가 돌아왔다. 기름은 충분한데.'),
  ('breath', '재 너머에서 누가 숨을 고르는 소리가 났다. …내 숨이었나.'),
  ('mud', ''),
];
const oddNames = {'shadow': '그림자', 'radio': '라디오', 'light': '불빛', 'missing': '사라진 물건', 'steps': '발자국', 'absent': '빈자리', 'knock': '노크'};

/// 칸의 세계 좌표 (화면 쪽 tileC와 같은 식)
(double, double) _tc(int i) {
  final x = i % W, y = i ~/ W;
  return ((x - y) * TW / 2, (x + y + 1) * TH / 2);
}

extension Season on Game {
  bool get s1On => S.gen == 0 && mi < steps.length;
  Map get casesMap {
    if (S.rest['cases'] is! Map) S.rest['cases'] = <String, Object?>{};
    return S.rest['cases'] as Map;
  }

  Map? caseRec(int k) => casesMap[caseKeyOf(k)] as Map?;

  /// 수첩에 보일 사건: 처음 여섯 + 고른 동네 사건 (웹 cKeys)
  List<int> get caseKeys => [for (var k = 0; k < cases.length; k++) k, for (var j = 0; j < townCases.length; j++) if (caseRec(cases.length + j)?['p'] != null) cases.length + j];
  Map get egg {
    if (S.rest['egg'] is! Map) S.rest['egg'] = <String, Object?>{};
    return S.rest['egg'] as Map;
  }

  List get oddLogList => S.rest['odd'] as List? ?? const [];
  bool get caseSeen => casesMap.values.any((r) => r is Map && r['p'] != null) || oddLogList.isNotEmpty || egg.isNotEmpty;

  // ================= 사건 (웹 tickCases 5778) =================
  bool _tickCases() {
    if (S.gen != 0 && S.region != null && regionOrder.contains(S.region)) {
      final k = cases.length + regionOrder.indexOf(S.region!), R = caseRec(k);
      if (R != null && R['p'] != null) return false;
      if (R != null || townCases[k - cases.length].gate(this)) {
        casesMap[caseKeyOf(k)] ??= <String, Object?>{'at': DateTime.now().millisecondsSinceEpoch};
        dirty = true;
        fx.add(FxCase(k));
        return true;
      }
      return false;
    }
    if (!s1On) return false;
    for (var k = 0; k < cases.length; k++) {
      final R = caseRec(k);
      if (R != null && (R['p'] != null || R['skip'] != null)) continue;
      if (R != null && R['p'] == null) {
        fx.add(FxCase(k));
        return true;
      }
      if (k == 0 && !hasSv(3) && mi >= stepI('첫 원정 보내기')) {
        casesMap['$k'] = <String, Object?>{'skip': 1};
        continue;
      }
      if (k > 0) {
        final P = caseRec(k - 1);
        if (!(P != null && (P['p'] != null || P['skip'] != null))) return false;
      }
      if (cases[k].gate(this)) {
        casesMap['$k'] = <String, Object?>{'at': DateTime.now().millisecondsSinceEpoch};
        dirty = true;
        fx.add(FxCase(k));
        return true;
      }
      return false;
    }
    return false;
  }

  String caseSus(int k) {
    final c = caseOf(k);
    return c.sus != null && hasSv(c.sus!) ? survivors[c.sus!].name : c.susN;
  }

  /// 사건에서 고르기 (웹 pickCase). 돌려주는 것: 이어지는 대사, 효과 글
  (List<Line>, List<String>) pickCase(int k, String p) {
    final c = caseOf(k), o = c.opt(p);
    casesMap[caseKeyOf(k)] ??= <String, Object?>{'at': DateTime.now().millisecondsSinceEpoch};
    final R = casesMap[caseKeyOf(k)] as Map;
    if (R['p'] != null) return (const [], const []);
    R['p'] = p;
    final sid = c.sus != null && hasSv(c.sus!) ? c.sus : null;
    final out = <String>[];
    if (!c.tut) {
      if (p == 'a') {
        if (c.all) {
          for (final id in svIds) {
            rec(id)!['xp'] = math.max(0, xpOf(id) - 20);
          }
          out.add('모두 신뢰 -20');
        } else if (sid != null) {
          rec(sid)!['xp'] = math.max(0, xpOf(sid) - 60);
          out.add('${survivors[sid].name} 신뢰 -60');
        }
      }
      if (p == 'b') {
        if (sid != null) {
          rec(sid)!['xp'] = xpOf(sid) + 80;
          out.add('${survivors[sid].name} 신뢰 +80');
        } else {
          S.hopeB += 2;
          out.add('희망 +2');
        }
      }
    }
    if (o.clue != null && p == 'a') {
      R['clue'] = 1;
      out.add('단서를 찾았어요');
    }
    if (c.solved) R['solved'] = 1;
    final e = c.end?.call(this) ?? '';
    if (e.isNotEmpty) out.add(e);
    var ls = [for (final l in o.r(this)) if (l != null) l];
    if (c.tail != null) {
      ls = [...ls, ...c.tail!];
      R['tail'] = 1;
    }
    S.rest['caseNew'] = 1;
    recalc();
    _changed();
    return (talkLines(ls), out);
  }

  // ================= 사라진 3분 (웹 eggGet 5797) =================
  void eggGet(String q, String msg) {
    if (egg[q] != null) return;
    egg[q] = 1;
    final n = ['a', 'b', 'c'].where((x) => egg[x] != null).length;
    if (n >= 3 && egg['page'] == null) {
      egg['page'] = 1;
      fx.add(const FxNote('찢어진 페이지를 찾았어요', '일지 · 사건 수첩 맨 뒤에 끼워져 있어요', ms: 6000));
    } else {
      fx.add(FxNote('$msg · $n/3', '어딘가 비어 있는 3분이 있어요', ms: 4200));
    }
    _changed();
  }

  /// 실제 시각 03:11~03:14
  bool get lost3 {
    final d = DateTime.now();
    return d.hour == 3 && d.minute >= 11 && d.minute <= 14;
  }

  // ================= 까마귀 (웹 tickCrow 5821) =================
  Map get crow {
    if (S.rest['crow'] is! Map) S.rest['crow'] = <String, Object?>{};
    return S.rest['crow'] as Map;
  }

  List<int> get crowMarks => [for (final v in (crow['marks'] as List? ?? const [])) (v as num).toInt()];

  bool _tickCrow() {
    if (!s1On) return false;
    final C = crow;
    if (C['trace'] == null && mi >= stepI('랜드마크 하나 복구하기') && num_('expDone') > 0) {
      C['trace'] = 1;
      if (C['marks'] == null) {
        final t = <int>[];
        for (var i = 0; i < N && t.length < 40; i++) {
          if (S.rev[i] == 1 && i != C0 && dist(i) > 4 && dist(i) < 14 && S.ter[i] != T.water) t.add(i);
        }
        t.shuffle(rnd);
        C['marks'] = t.take(3).toList();
        _mapChanged();
      }
      dirty = true;
      talk(const [
        Line(_g, '원정 다녀온 사람들이 이상한 걸 봤대. 털린 건물 벽마다 검은 새가 그려져 있더래.'),
        Line(_g, '우리보다 먼저 싹 쓸어 간 무리가 있는 거야. 이 근처 벽에도 몇 개 있더라고.'),
        Line(_me, '사람들은 그 무리를 ‘까마귀’라고 부르기 시작했다.'),
      ], tag: '까마귀 · 흔적');
      return true;
    }
    if (C['trace'] != null && C['rel'] == null && mi >= stepI('요새로 키우기')) {
      fx.add(const FxCrowMeet());
      return true;
    }
    if (C['rel'] != null && C['stand'] == null && towerN >= 3) {
      C['stand'] = 1;
      dirty = true;
      final rel = C['rel'];
      talk([
        const Line(_me, '탑 아래로 까마귀 무리가 몰려왔다. 맨 앞의 사내가 탑 꼭대기를 올려다봤다.'),
        const Line('npc:crow', '독수리라고 하오. 쇼핑몰 경비팀장이었지. 사람 지키던 일이 이렇게 됐소.'),
        if (hasSv(jinId)) const Line(jinId, '…대장.'),
        Line('npc:crow', rel == 'deal' ? '통행료 낸 사이니 오늘은 손대지 않겠소.' : rel == 'fight' ? '그날 빚은 잊지 않았소. 하지만 오늘은 싸우러 온 게 아니오.' : '그때 길을 비켜 줘서 여기까지 왔지.'),
        const Line('npc:crow', '불 잘 켰더군. 하나만 알아 두시오.'),
        const Line('npc:crow', '빛은 우리만 부르는 게 아니야.'),
        const Line(_me, '그는 싸우지 않고 돌아섰다. 멀어지면서, 오래된 라디오 시그널 음악을 흥얼거렸다.'),
        if (hasSv(10)) const Line(_me, '그 가락에 은호가 잠깐 멈춰 섰다. 아무 말도 하지 않았다.'),
      ], tag: '까마귀 · 대치');
      return true;
    }
    if (C['jinDue'] != null && C['jinDue'] != 0 && !hasSv(jinId)) {
      C['jinDue'] = 0;
      rescue(jinId, 'visit');
      return true;
    }
    return false;
  }

  Cost get crowToll => scaleCost({'food': 40, 'fuel': 15}, lvScale);

  /// 길을 막은 사람들 앞에서 고르기 (웹 pickCrow 5842)
  (List<Line>, List<String>) pickCrow(String k) {
    final C = crow;
    if (C['rel'] != null) return (const [], const []);
    var ls = <Line>[];
    final out = <String>[];
    if (k == 'deal') {
      final c = crowToll;
      if (!pay(c)) return (const [], const []);
      C['rel'] = 'deal';
      ls = const [Line('npc:crow', '약속은 지키지. 오늘은 그냥 보내 주겠소.'), Line(_me, '그들은 정말로 길을 비켜 줬다. 이상하게 예의 바른 도둑들이었다.')];
      out.add('통행료 · ${lootText(c)}');
    } else if (k == 'fight') {
      C['rel'] = 'fight';
      final ids = [for (final id in svIds) if (!busy(id) && id != jinId) id];
      if (ids.isNotEmpty) {
        final id = ids[rnd.nextInt(ids.length)];
        rec(id)!['hurt'] = 180;
        out.add('${survivors[id].name} 다침');
      }
      final got = give(scaleCost({'parts': 10, 'scrap': 25}, lvScale));
      out.add(lootText(got));
      C['jinDue'] = 1;
      ls = const [Line(_me, '한바탕 몸싸움 끝에 그들이 물러났다. 도망치다 넘어진 아이 하나가 남았다.'), Line('npc:jin', '…때리지 마요. 따라갈게요.')];
    } else {
      C['rel'] = 'avoid';
      ls = const [Line(_me, '원정대는 먼 길로 돌아왔다. 하루가 더 걸렸지만, 아무도 다치지 않았다.'), Line(_g, '저놈들, 우리가 어디 사는지 알아냈을 거야.')];
    }
    recalc();
    _changed();
    return (talkLines(ls), out);
  }

  /// 대형 재폭풍이 끝난 뒤: 7장의 첫 큰 폭풍 밤엔 까마귀가 창고를 턴다 (웹 endDefense 덮어쓰기)
  void crowRaidAfterDefense() {
    final C = crow;
    if (!(s1On && C['raid'] == null && mi >= stepI('대형 재폭풍 한 번 막아내기'))) return;
    C['raid'] = 1;
    C['rel'] ??= 'avoid';
    final f = C['rel'] == 'deal' ? .04 : .08, lost = <String, num>{};
    for (final k in const ['wood', 'scrap', 'food', 'fuel']) {
      final n = (have(k) * f).floor();
      if (n > 0) {
        S.m[k] = have(k) - n;
        lost[k] = n;
      }
    }
    C['lost'] = lost;
    talk([
      const Line(_me, '폭풍이 걷히자 창고 문이 열려 있었다. 바닥에 검은 새가 그려져 있었다.'),
      const Line(_g, '재 괴물이랑 싸우는 틈에 사람이 들어왔어. 까마귀야.'),
      if (C['rel'] == 'deal') const Line(_g, '통행료 낸 사이라고 조금만 가져간 모양이야. 웃기는 놈들이지.'),
      if (lost.isNotEmpty) Line(_me, '창고에서 사라진 것: ${lootText(lost)}'),
      if (!hasSv(jinId)) const Line(_me, '창고 구석에 아이 하나가 웅크리고 있었다. 무리가 두고 간 거였다.'),
      if (!hasSv(jinId)) const Line('npc:jin', '…버려진 거예요, 저. 여기 있게 해 주세요.'),
    ], tag: '까마귀 · 습격');
    if (!hasSv(jinId)) C['jinDue'] = 1;
    dirty = true;
  }

  // ================= 수상한 밤 (웹 tickOdd 5940) =================
  bool get oddOn => hasSv(10) && (s1On || S.gen != 0);

  void _oddLog(String k, String t) {
    if (S.rest['odd'] is! List) S.rest['odd'] = <Object?>[];
    final L = S.rest['odd'] as List;
    L.insert(0, <String, Object?>{'n': num_('nightCount').toInt(), 'r': S.gen != 0 ? (reg?.n ?? '') : '', 'k': k, 't': t});
    if (L.length > 20) L.removeRange(20, L.length);
    dirty = true;
  }

  int _modTile(int id) {
    for (final e in modAt.entries) {
      if (S.mods[e.value]?.id == id) return e.key;
    }
    return -1;
  }

  String _oddPick() {
    final last = S.rest['oddLast'];
    final pool = [
      ('shadow', 3),
      ('radio', num_('gUses') > 0 || num_('gTotal') > 0 ? 2 : 0),
      ('light', hasMod(7) ? 2 : 0),
      ('missing', 2),
      ('steps', 2),
      ('absent', S.sv.length >= 4 ? 2 : 0),
      ('knock', 1)
    ].where((p) => p.$2 > 0 && p.$1 != last).toList();
    var tot = 0;
    for (final p in pool) {
      tot += p.$2;
    }
    var r = rnd.nextDouble() * tot;
    for (final p in pool) {
      r -= p.$2;
      if (r <= 0) return p.$1;
    }
    return 'knock';
  }

  void _tickOdd() {
    if (!oddOn) return;
    final n = isNight, nc = num_('nightCount').toInt();
    if (n && oddNightSeen != nc) {
      oddNightSeen = nc;
      // 은호는 하늘이 얕은 밤(절반, 새 동네는 30%)에만 방송한다. 수상한 일은 그 방송 밤에만.
      final air = rnd.nextDouble() < (S.gen != 0 ? .3 : .5);
      S.rest['airTonight'] = air ? nc : -1;
      if (air && defn == null) fx.add(FxToast(hasSv(11) ? '설화: “오늘 밤은 하늘이 얕아요.” 은호의 방송이 열렸어요' : '오늘 밤은 하늘이 얕아요. 은호의 방송이 열렸어요'));
      oddPlan = defn == null && air ? _oddPick() : null;
      oddDone = false;
    }
    if (n && oddPlan != null && !oddDone && phase >= oddAt && defn == null) {
      oddDone = true;
      S.rest['oddLast'] = oddPlan;
      _runOdd(oddPlan!);
    }
    if (!n && oddDawn != null) {
      oddDawnT = 3; // 동이 트고 조금 뒤에
      final f = oddDawn!;
      oddDawn = null;
      oddDawnNote = f;
    }
    if (oddDawnNote != null && --oddDawnT <= 0) {
      fx.add(oddDawnNote!);
      oddDawnNote = null;
    }
  }

  void _runOdd(String k) {
    oddUntil = DateTime.now().millisecondsSinceEpoch + 9000;
    dread = false;
    oddHit = DateTime.now().millisecondsSinceEpoch;
    poke();
    final nc = num_('nightCount').toInt();
    switch (k) {
      case 'shadow':
        final from = _modTile(7) >= 0 ? _modTile(7) : C0, e = _edgeTiles();
        final to = e.isNotEmpty ? e[rnd.nextInt(e.length)] : C0;
        final a = _tc(from), b = _tc(to);
        shadow = OddShadow.walk(a.$1 + 14, a.$2 + 6, b.$1, b.$2, 14);
        if (rnd.nextDouble() < .5) {
          oddDawn = const FxNote('아침 · 장갑 한 짝', '내 잠자리 근처에 그을음 묻은 장갑 한 짝이 떨어져 있었다. 내 것이던가?', ms: 5500);
          _oddLog('shadow', '아침, 내 잠자리 근처에 그을음 묻은 장갑 한 짝이 떨어져 있었다.');
        }
        fx.add(const FxNote('새벽 3시 · 수상한 그림자', '쉘터 쪽에서 누군가 움직여요. 눌러서 쫓아가 봐요', ms: 5500));
      case 'radio':
        fx.add(const FxNote('새벽 3시 · 라디오', '꺼 둔 라디오에서 잡음이 새어 나왔어요. “…여기는…” 딸깍. 그리고 조용해졌어요.', ms: 5500));
        _oddLog(k, '꺼 둔 라디오에서 잡음이 새어 나왔다. “…여기는…” 딸깍, 하는 소리와 함께 끊겼다.');
      case 'light':
        shadow = OddShadow.light(_modTile(7), 9);
        fx.add(const FxNote('새벽 3시 · 무전실', '아무도 없어야 할 무전실에 불이 켜졌다 꺼졌어요.', ms: 5500));
        if (hasSv(10)) oddDawn = const FxNote('아침 · 은호', '“무전실이요? 전 그 시간에 방송 중이었어요.” 무전실 문 앞엔 내 랜턴이 놓여 있었다. 내가 두고 왔던가?', ms: 6000);
        _oddLog(k, '아무도 없어야 할 무전실에 불이 켜졌다 꺼졌다. 아침에 보니 내 랜턴이 무전실 문 앞에 있었다.');
      case 'knock':
        fx.add(const FxNote('새벽 3시 · 창고', '창고 문에서 노크 소리. 세 번, 한 번, 한 번. 나가 보니 아무도 없어요.', ms: 5500));
        _oddLog(k, '누가 창고 문을 세 번, 한 번, 한 번 두드리고 멈췄다. 아무도 없었다.');
      case 'missing':
        final c = [('batt', 1), ('wire', 1), ('rope', 2), ('med', 1), ('fuel', 3)].where((x) => have(x.$1) > x.$2 + 1).toList();
        final (m, q) = c.isNotEmpty ? c[rnd.nextInt(c.length)] : ('food', 3);
        S.m[m] = math.max(0, have(m) - q);
        oddDawn = FxNote('아침 · 사라진 물건', '창고에서 ${matOf[m]!.n} $q개가 사라졌어요. 자물쇠는 그대로예요. 열쇠는 내 허리춤에 있었는데.', ms: 5500);
        _oddLog(k, '창고에서 ${matOf[m]!.n} $q개가 사라졌다. 자물쇠는 멀쩡했다.');
      case 'steps':
        final e = _edgeTiles();
        S.rest['oddSteps'] = <String, Object?>{'to': e.isNotEmpty ? e[rnd.nextInt(e.length)] : C0, 'n': nc};
        oddDawn = const FxNote('아침 · 발자국', '쉘터에서 어둠 쪽으로 발자국이 이어져 있어요. 돌아온 발자국은 없어요. 아침에 신으려니 내 신발 끈이 평소와 다르게 묶여 있었다.', ms: 6000);
        _oddLog(k, '쉘터에서 어둠 쪽으로 발자국이 났다. 돌아온 발자국은 없었다. 내 신발 끈이 다르게 묶여 있었다.');
        _mapChanged();
      case 'absent':
        final ids = [for (final id in svIds) if (id != 10 && id != jinId) id];
        final who = rnd.nextDouble() < .5 || ids.isEmpty ? 10 : ids[rnd.nextInt(ids.length)];
        final rep = ids.where((id) => id != who).firstOrNull ?? 0;
        final alibi = who == 10
            ? (hasMod(7) ? '“방송하느라 무전실에 있었죠. 다들 들었잖아요?”' : '“송신기 앞에서 방송 중이었어요. 다들 들었잖아요?”')
            : who == 1
                ? '“바람 좀 쐬고 왔어요. 배달하던 버릇이라.”'
                : '“잠이 안 와서요. 잠깐 걸었어요.”';
        final lead = rnd.nextDouble() < .35 ? ' …그러고 보니 등불지기님 자리도 비어 있었던 것 같은데. 아, 제가 잘못 봤겠죠.' : '';
        final wn = survivors[who].name;
        oddDawn = FxNote('아침 · ${survivors[rep].name}', '“어젯밤 ${jo(wn, '이', '가')} 자리에 없었어요.$lead” $wn: $alibi', ms: 6500);
        _oddLog(k, '새벽에 $wn의 자리가 비어 있었다. $wn: $alibi');
    }
  }

  /// 그림자를 눌러 쫓기 (웹 catchShadow)
  void catchShadow() {
    final s = shadow;
    if (s == null || s.got || s.light != null) return;
    s.got = true;
    s.t = math.max(s.t, s.dur - 1.2);
    S.rest['oddItem'] = num_('oddItem') + 1;
    final it = _oddItems[num_('oddItem').toInt() % _oddItems.length];
    fx.add(FxNote('놓쳤어요', '그림자는 쉘터 안, 내 잠자리 쪽으로 사라졌어요. 발밑에 ${jo(it, '이', '가')} 떨어져 있어요.', ms: 6000));
    _oddLog('shadow', '새벽 3시, 그림자를 쫓았지만 쉘터 안 내 잠자리 쪽에서 놓쳤다. 발밑에 ${jo(it, '이', '가')} 떨어져 있었다.');
  }

  /// 매 프레임 쪽 (0.25초): 그림자 움직임, 기척의 조여 오는 화면
  void tickShadow(double dt) {
    final s = shadow;
    if (s != null) {
      s.t += dt;
      if (s.t >= s.dur) {
        if (s.light == null && !s.got) _oddLog('shadow', '새벽 3시, 쉘터 쪽에서 그림자가 어둠 속으로 사라졌다.');
        shadow = null;
      }
    }
  }

  // ================= 기척 (웹 tickDread 5984): 손해 없는 불안 연출 =================
  bool get _dreadOK => tut == null && onb != 1 && defn == null && isNight;

  void _tickDread() {
    final n = isNight, nc = num_('nightCount').toInt(), p = phase;
    final pre = _dreadOK && oddPlan != null && !oddDone && p >= oddAt - 8 && p < oddAt;
    if (n && prsNight != nc) {
      prsNight = nc;
      prs = null;
      if (_dreadOK && oddPlan == null && nc >= 2 && rnd.nextDouble() < .34) {
        final last = S.rest['prsLast'];
        final pool = _prsT.where((x) => x.$1 != last && (hasSv(10) || (x.$1 != 'breath' && x.$1 != 'mud'))).toList();
        final pk = pool[rnd.nextInt(pool.length)];
        prs = (pk.$1, pk.$2, dayLen + 8 + rnd.nextDouble() * (cycleLen - dayLen - 22));
        prsDone = false;
      }
    }
    final pr = prs;
    final preP = pr != null && !prsDone && _dreadOK && p >= pr.$3 - 3 && p < pr.$3;
    if (dread != (pre || preP)) {
      dread = pre || preP;
      poke();
    }
    if (pr != null && !prsDone && n && p >= pr.$3) {
      prsDone = true;
      S.rest['prsLast'] = pr.$1;
      if (_dreadOK) _runPresence(pr.$1, pr.$2);
    }
    if (!n && prsDawn != null) {
      fx.add(prsDawn!);
      prsDawn = null;
    }
  }

  void _runPresence(String k, String t) {
    if (k == 'mud') {
      prsDawn = const FxNote('아침 · 장화', '장화 밑창에 젖은 흙이 묻어 있다. 어젯밤엔 텐트 밖으로 나간 적이 없는데.', ms: 5500);
      return;
    }
    if (k == 'light') {
      final e = _edgeTiles();
      if (e.isNotEmpty) shadow ??= OddShadow.light(e[rnd.nextInt(e.length)], 4.5, far: true);
    }
    if (k == 'lamp') lampFlick = DateTime.now().millisecondsSinceEpoch;
    oddHit = DateTime.now().millisecondsSinceEpoch;
    poke();
    fx.add(FxToast(t));
  }

  /// 새벽 3시 무렵의 시계 글 (웹 renderClock 덮어쓰기)
  String? get oddClock {
    if (dread && oddPlan != null && !oddDone) {
      final left = math.max(0, (oddAt - phase).ceil());
      return '새벽 2:5${math.min(9, 9 - left + 1)}';
    }
    if (isNight && DateTime.now().millisecondsSinceEpoch < oddUntil) return '새벽 3시';
    return null;
  }

  /// 매초: 수상한 밤·기척 (웹 tickSeason의 tickOdd), 그리고 장면 순서대로 은호·까마귀·사건
  void _tickSeasonSec() {
    _tickOdd();
    _tickDread();
  }

  bool _tickSeasonScenes() => _tickEunho() || _tickCrow() || _tickCases() || _tickEnding();

  /// 시즌 1 엔딩: 세 번째 새 동네의 탑 다음에 (이주는 6단계에서 옮긴다, 웹 tickEnding 5864)
  bool _tickEnding() {
    if (S.rest['ehEnd'] != null || endingOn) return false;
    if (!(S.gen > 3 || (S.gen == 3 && rmi >= regionMis().length))) return false;
    endingOn = true;
    talk(endLines, tag: '그날 밤', noskip: true, after: 'endCard');
    return true;
  }

  // ================= 회상 갤러리 (웹 artBackfill 5891) =================
  Map get artMap {
    if (S.rest['art'] is! Map) S.rest['art'] = <String, Object?>{};
    return S.rest['art'] as Map;
  }

  void artBackfill() {
    final a = artMap;
    if (tutDone) {
      for (final n in [0, 1, 2, 3]) {
        a['$n'] = 1;
      }
    }
    final sa = web.storyArt['stepArt'] as List;
    final d = math.min(mi, steps.length);
    for (var i = 0; i < d && i < sa.length; i++) {
      final p = sa[i] as List;
      a['${p[0]}'] = 1;
      a['${p[1]}'] = 1;
    }
    if (S.rest['ehEnd'] != null) {
      a['22'] = 1;
      a['21'] = 1;
    }
    for (final k in casesMap.keys) {
      final r = casesMap[k];
      final ki = int.tryParse('$k');
      if (r is Map && r['p'] != null && ki != null && ki < 6) a['${36 + ki}'] = 1;
    }
  }

  int get artCount => artMap.length;

  /// 그림 n번을 처음 보여 준 대화 (웹 sceneSource)
  (List<Line>, String)? sceneSource(int n) {
    if (n <= 3 && n < tutSteps.length) return (tutSteps[n].say, '그날 밤 · ${tutSteps[n].t}');
    if (n == 21 || n == 22) return (endLines, '그날 밤');
    if (n >= 42 && n <= 44) {
      final c = townCases[n - 42];
      return ([for (final l in c.x(this)) if (l != null) l], '사건 수첩 · ${c.t}');
    }
    if (n >= 27 && n <= 35) {
      final r = regionOrder[(n - 27) ~/ 3], beat = (n - 27) % 3, arc = regStory[r];
      if (arc != null) {
        final ls = [for (var k = 0; k < arc.length; k++) if ((k < 3 ? 0 : k < 6 ? 1 : 2) == beat) ...arc[k].$1];
        if (ls.isNotEmpty) return (ls, regions[r]?.n ?? '');
      }
    }
    if (n >= 36 && n <= 41) {
      final c = cases[n - 36];
      return ([for (final l in c.x(this)) if (l != null) l], '사건 수첩 · ${c.t}');
    }
    final sa = web.storyArt['stepArt'] as List;
    for (var i = 0; i < steps.length && i < sa.length; i++) {
      final a = sa[i] as List, st = steps[i], c = chapters[st.ci];
      if (a[0] == n && st.intro.isNotEmpty) return (st.intro, '${c.ch} · ${c.title}');
      if (a[1] == n && st.outro.isNotEmpty) return (st.outro, '${c.ch} · ${c.title}');
    }
    return null;
  }
}
