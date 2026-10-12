// 아래에서 올라오는 시트: 쉘터(짓기·작업대·연구), 모듈·랜드마크 빠른 메뉴, 일지, 설정.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/data.dart';
import '../game/engine.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showTtcSheet(BuildContext context, Game g, Widget Function(BuildContext) body, {double height = .72}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => FractionallySizedBox(
      heightFactor: height,
      child: Container(
        decoration: const BoxDecoration(
          color: Ttc.leather,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 18)],
        ),
        child: SafeArea(
          top: false,
          child: Column(children: [
            Container(width: 44, height: 5, margin: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Ttc.paper.withValues(alpha: .3), borderRadius: BorderRadius.circular(3))),
            Expanded(child: AnimatedBuilder(animation: g, builder: (c, _) => body(c))),
          ]),
        ),
      ),
    ),
  );
}

Widget _head(String title, String sub) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(title, style: Ttc.title(22)),
        const SizedBox(width: 8),
        Expanded(child: Text(sub, style: Ttc.body(12.5, color: Ttc.muted))),
      ]),
    );

// ======================= 쉘터 =======================
class ShelterSheet extends StatefulWidget {
  const ShelterSheet(this.g, {super.key});
  final Game g;
  @override
  State<ShelterSheet> createState() => _ShelterSheetState();
}

class _ShelterSheetState extends State<ShelterSheet> {
  int tab = 0;
  Game get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final S = g.S;
    return Column(children: [
      _head('Lv.${S.lv} ${shelterName[S.lv - 1]}', '보관 한도 ${fmt(g.cap)} · 희망 ${g.hope} · 식량 +${fmt(g.prod['food'] ?? 0)} / -${fmt(g.eat)} 매분'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          for (final (k, n) in const [(0, '짓기'), (1, '작업대'), (2, '연구')])
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => tab = k),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: tab == k ? Ttc.paper : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Ttc.paper.withValues(alpha: .3)),
                  ),
                  child: Text(n, textAlign: TextAlign.center, style: Ttc.body(14.5, color: tab == k ? Ttc.sepia : Ttc.paper, weight: FontWeight.w700)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 20), children: switch (tab) {
          0 => _build(),
          1 => _craft(),
          _ => _research(),
        }),
      ),
    ]);
  }

  List<Widget> _build() {
    final S = g.S;
    final out = <Widget>[];
    // 쉘터 키우기
    final up = g.shelterUpCost;
    if (up != null) {
      final need = shupNeed[S.lv - 1];
      out.add(PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('쉘터 키우기 → ${shelterName[S.lv]}', style: Ttc.title(17, color: Ttc.sepia))),
            TtcButton('키우기', onTap: S.mods.length >= need && g.canPay(up) ? () => g.upShelter() : null),
          ]),
          const SizedBox(height: 4),
          Text('모듈 ${S.mods.length}/$need개 · 자리 ${slotsByLv[S.lv - 1]} → ${slotsByLv[S.lv]}칸 · 창고 ${fmt(capByLv[S.lv - 1])} → ${fmt(capByLv[S.lv])}',
              style: Ttc.body(12.5, color: Ttc.sepia2)),
          const SizedBox(height: 6),
          CostRow(g, up),
        ]),
      ));
    }
    // 모듈 짓기
    final free = g.freeSlot();
    for (final id in modOrder) {
      final m = mods[id]!;
      final n = g.modN(id);
      final locked = S.lv < m.req;
      final once = n > 0 && !repeatable.contains(id);
      final c = g.modBuildCost(id);
      out.add(PaperCard(
        dim: locked,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AtlasThumb('modules.webp', modOrder.indexOf(id), 3, 3, size: 46),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n > 0 ? '${m.n} · $n개' : m.n, style: Ttc.title(16, color: Ttc.sepia)),
                Text(m.fx[0], style: Ttc.body(12.5, color: Ttc.sepia2)),
              ]),
            ),
            if (locked)
              Text('쉘터 Lv.${m.req}', style: Ttc.body(12.5, color: Ttc.sepia2, weight: FontWeight.w700))
            else if (once)
              Text('지었어요', style: Ttc.body(12.5, color: Ttc.good, weight: FontWeight.w700))
            else
              TtcButton(n > 0 ? '하나 더' : '짓기', onTap: free >= 0 && g.canPay(c) ? () => g.buildMod(id) : null),
          ]),
          if (!locked && !once) ...[const SizedBox(height: 6), CostRow(g, c)],
          if (!locked && !once && free < 0) Text('빈 자리가 없어요. 쉘터를 키우면 자리가 늘어요', style: Ttc.body(12, color: Ttc.rust)),
        ]),
      ));
    }
    // 지은 모듈 강화
    if (S.mods.isNotEmpty) {
      out.add(Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 8), child: Text('지은 모듈', style: Ttc.title(16))));
      final keys = S.mods.keys.toList()..sort();
      for (final k in keys) {
        out.add(ModuleCard(g, k));
      }
    }
    // 방벽
    if (S.lv >= 2 && S.walls < 3) {
      final c = g.wallCost(S.walls);
      out.add(PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('방벽 · ${wallsInfo[S.walls].$1}', style: Ttc.title(16, color: Ttc.sepia))),
            TtcButton('두르기', onTap: g.canPay(c) ? () => g.upWalls() : null),
          ]),
          const SizedBox(height: 6),
          CostRow(g, c),
        ]),
      ));
    }
    return out;
  }

  List<Widget> _craft() {
    if (g.wbL == 0) {
      return [PaperCard(child: Text('작업대를 지으면 고철로 철판을, 천으로 밧줄을 만들 수 있어요.', style: Ttc.body(14, color: Ttc.sepia)))];
    }
    return [
      for (var k = 0; k < recipes.length; k++)
        () {
          final r = recipes[k], lock = g.recipeLock(r), inp = g.recipeInp(r), name = r.nm ?? '${matOf[r.out]!.n} 만들기';
          return PaperCard(
            dim: lock.isNotEmpty,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ResIcon(r.out, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$name  → ${matOf[r.out]!.n} ${r.n}', style: Ttc.title(15.5, color: Ttc.sepia)),
                    Text(r.d ?? '가진 ${matOf[r.out]!.n} ${fmt(g.have(r.out))}/${fmt(g.capOf(r.out))}', style: Ttc.body(12.5, color: Ttc.sepia2)),
                  ]),
                ),
                if (lock.isNotEmpty) Text(lock, style: Ttc.body(12.5, color: Ttc.sepia2, weight: FontWeight.w700)),
              ]),
              if (lock.isEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: CostRow(g, inp)),
                  TtcButton('×1', small: true, onTap: g.canPay(inp) ? () => g.craft(k, 1) : null),
                  const SizedBox(width: 6),
                  TtcButton('×5', small: true, primary: false, onTap: g.canPay(inp) ? () => g.craft(k, 5) : null),
                ]),
              ],
            ]),
          );
        }(),
    ];
  }

  List<Widget> _research() {
    String desc(String k) => switch (k) {
          'tap' => '한 번에 걷어내는 힘 ${fmt(g.tapPow)}',
          'splash' => '옆 칸까지 번지는 빛 ${g.S.splashLv} → ${g.S.splashLv + 1}',
          _ => '스스로 초당 ${fmt(g.droneDmg())} → ${fmt(g.droneDmg(1))} 탐사',
        };
    const names = {'tap': '곡괭이', 'splash': '랜턴 불씨', 'drone': '정찰 드론'};
    return [
      for (final k in const ['tap', 'splash', 'drone'])
        () {
          final lv = g.upgLv(k), max = Game.upgMax[k]!, wb = g.upgWb(k), c = g.upgCost(k);
          final lockTxt = g.wbL < wb ? '작업대 $wb단계' : '';
          return PaperCard(
            dim: lockTxt.isNotEmpty,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${names[k]} $lv/$max', style: Ttc.title(16, color: Ttc.sepia)),
                    Text(desc(k), style: Ttc.body(12.5, color: Ttc.sepia2)),
                  ]),
                ),
                if (lv >= max)
                  Text('최고 단계', style: Ttc.body(12.5, color: Ttc.good, weight: FontWeight.w700))
                else if (lockTxt.isNotEmpty)
                  Text(lockTxt, style: Ttc.body(12.5, color: Ttc.sepia2, weight: FontWeight.w700))
                else
                  TtcButton('연구', onTap: g.canPay(c) ? () => g.buyUp(k) : null),
              ]),
              if (lv < max && lockTxt.isEmpty) ...[const SizedBox(height: 6), CostRow(g, c)],
            ]),
          );
        }(),
    ];
  }
}

class ModuleCard extends StatelessWidget {
  const ModuleCard(this.g, this.slot, {super.key});
  final Game g;
  final int slot;
  @override
  Widget build(BuildContext context) {
    final m = g.S.mods[slot];
    if (m == null) return const SizedBox();
    final info = mods[m.id]!;
    final up = m.l < 2 ? g.modCost(m.id, m.l + 1) : null;
    final stopped = m.id == 5 && g.have('fuel') <= 0;
    return PaperCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AtlasThumb('modules.webp', modOrder.indexOf(m.id), 3, 3, size: 40),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${info.n} ${m.l + 1}/3단계', style: Ttc.title(15.5, color: Ttc.sepia)),
              Text(info.fx[m.l], style: Ttc.body(12.5, color: Ttc.sepia2)),
              if (stopped) Text('연료가 없어 멈춤', style: Ttc.body(12.5, color: Ttc.rust, weight: FontWeight.w700)),
            ]),
          ),
          if (up != null) TtcButton('강화', small: true, onTap: g.canPay(up) ? () => g.upMod(slot) : null),
        ]),
        if (up != null) ...[
          const SizedBox(height: 6),
          Text('다음: ${info.fx[m.l + 1]}', style: Ttc.body(12.5, color: Ttc.sepia2)),
          const SizedBox(height: 4),
          CostRow(g, up),
        ],
      ]),
    );
  }
}

// ======================= 모듈·랜드마크·캠프 빠른 메뉴 =======================
Widget moduleSheet(BuildContext context, Game g, int tile) {
  final slot = g.modAt[tile];
  final m = slot == null ? null : g.S.mods[slot];
  if (m == null) return const SizedBox();
  final say = modSay[m.id];
  return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 20), children: [
    if (say != null && say.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 10), child: Text('“${say[tile % say.length]}”', style: Ttc.body(14, color: Ttc.muted))),
    ModuleCard(g, slot!),
    Text('자세한 건 쉘터 화면에서', textAlign: TextAlign.center, style: Ttc.body(12, color: Ttc.muted)),
  ]);
}

Widget landmarkSheet(BuildContext context, Game g, int tile) {
  final l = g.S.lm[tile];
  if (l == null) return const SizedBox();
  final t = lmText(l.k, g.S.region), info = landmarks[l.k], s = g.S.site[tile], c = g.lmCost(l.k);
  return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 20), children: [
    PaperCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t[0], style: Ttc.title(19, color: Ttc.sepia)),
        Text(l.ok ? '복구 완료' : '랜드마크', style: Ttc.body(12.5, color: Ttc.sepia2, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(l.ok ? t[2] : t[1], style: Ttc.body(14, color: Ttc.sepia)),
        const SizedBox(height: 8),
        Text('복구하면 ${info.desc}', style: Ttc.body(13, color: Ttc.good, weight: FontWeight.w700)),
        if (!l.ok && s != null) Text('남은 물자 ${s.c}/${s.max}', style: Ttc.body(12.5, color: Ttc.sepia2)),
        if (!l.ok) ...[
          const SizedBox(height: 10),
          Text('복구에 필요한 자재', style: Ttc.body(12.5, color: Ttc.sepia2, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          CostRow(g, c),
          const SizedBox(height: 10),
          Row(children: [
            if (s != null && s.c > 0)
              TtcButton('뒤지기', primary: false, onTap: () {
                g.hitSite(tile, g.tapPow * (g.fever > 0 ? 2 : 1));
                g.poke();
              }),
            const Spacer(),
            TtcButton('복구하기', onTap: g.canPay(c) ? () => g.restoreLm(tile) : null),
          ]),
        ],
        if (l.ok && info.key == 'station') ...[const SizedBox(height: 8), Text('끊긴 노선 탐사는 6단계에서 옮겨요', style: Ttc.body(12.5, color: Ttc.sepia2))],
      ]),
    ),
  ]);
}

Widget campSheet(BuildContext context, Game g, int tile) {
  final c = g.S.camp[tile];
  final id = (c?['id'] as num?)?.toInt();
  final sv = id != null && id < survivors.length ? survivors[id] : null;
  return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 20), children: [
    PaperCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(sv == null ? '생존자 캠프' : '${sv.name} · ${sv.job}', style: Ttc.title(18, color: Ttc.sepia)),
        const SizedBox(height: 6),
        Text('잔해 아래에서 누군가 기다리고 있어요. 구조와 생존자 이야기는 다음 단계(생존자)에서 옮겨요.', style: Ttc.body(14, color: Ttc.sepia)),
      ]),
    ),
  ]);
}

// ======================= 일지 =======================
Widget diarySheet(BuildContext context, Game g) {
  final found = [...g.S.found]..sort();
  return Column(children: [
    _head('일지', '목격자의 일기 ${found.length}/7'),
    Expanded(
      child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 20), children: [
        if (found.isEmpty) PaperCard(child: Text('구름 속 어딘가에 누군가의 일기가 흩어져 있어요. 지도를 밝히다 보면 찾을 수 있어요.', style: Ttc.body(14, color: Ttc.sepia))),
        for (final k in found)
          GestureDetector(
            onTap: () => showDiary(context, k),
            child: PaperCard(
              child: Row(children: [
                Text('${k + 1}', style: Ttc.title(22, color: Ttc.rust)),
                const SizedBox(width: 12),
                Expanded(child: Text(diaries[k].$1, style: Ttc.title(16, color: Ttc.sepia))),
              ]),
            ),
          ),
        const SizedBox(height: 6),
        Text('이야기·사건 수첩·회상은 5단계에서 옮겨요', textAlign: TextAlign.center, style: Ttc.body(12, color: Ttc.muted)),
      ]),
    ),
  ]);
}

Future<void> showDiary(BuildContext context, int k) => showDialog(
      context: context,
      barrierColor: const Color(0xAA000000),
      builder: (ctx) => Dialog(
        backgroundColor: Ttc.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('목격자의 일기 · ${k + 1}/7', style: Ttc.body(12.5, color: Ttc.rust, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(diaries[k].$1, style: Ttc.title(20, color: Ttc.sepia)),
            const SizedBox(height: 10),
            Flexible(child: SingleChildScrollView(child: Text(diaries[k].$2, style: TextStyle(fontFamily: Ttc.serif, fontSize: 15.5, height: 1.7, color: Ttc.sepia)))),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: TtcButton('덮기', onTap: () => Navigator.pop(ctx))),
          ]),
        ),
      ),
    );

// ======================= 아직 옮기지 않은 탭 =======================
Widget comingSheet(BuildContext context, String title, String stage) => Column(children: [
      _head(title, ''),
      Padding(
        padding: const EdgeInsets.all(12),
        child: PaperCard(child: Text('$title 화면은 $stage에서 옮겨요. 지금 미리보기는 지도 밝히기·뒤지기·쉘터 짓기까지예요.', style: Ttc.body(14, color: Ttc.sepia))),
      ),
    ]);

// ======================= 설정 =======================
class SettingsSheet extends StatefulWidget {
  const SettingsSheet(this.g, {super.key, required this.onReset});
  final Game g;
  final VoidCallback onReset;
  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final ctrl = TextEditingController();
  String msg = '';
  bool confirmReset = false;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
      _head('설정', '네이티브 미리보기 · 1단계'),
      PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('저장 코드', style: Ttc.title(16, color: Ttc.sepia)),
          const SizedBox(height: 4),
          Text('웹 버전의 설정 → 저장 코드와 같은 형식이에요. 웹에서 복사한 코드를 붙여 넣으면 그 진행으로 이어서 해요.', style: Ttc.body(13, color: Ttc.sepia2)),
          const SizedBox(height: 8),
          Row(children: [
            TtcButton('내 코드 복사', primary: false, small: true, onTap: () async {
              await Clipboard.setData(ClipboardData(text: g.exportCode()));
              setState(() => msg = '복사했어요');
            }),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            maxLines: 3,
            style: Ttc.body(12, color: Ttc.sepia),
            decoration: InputDecoration(
              hintText: 'TTC1. 로 시작하는 코드를 붙여 넣어요',
              hintStyle: Ttc.body(12, color: Ttc.sepia2),
              filled: true,
              fillColor: const Color(0x11000000),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(msg, style: Ttc.body(12.5, color: Ttc.rust, weight: FontWeight.w700))),
            TtcButton('불러오기', small: true, onTap: () {
              final s = Game.parseCode(ctrl.text);
              if (s == null) {
                setState(() => msg = '코드를 읽지 못했어요');
                return;
              }
              g.replaceState(s);
              setState(() => msg = '불러왔어요');
            }),
          ]),
        ]),
      ),
      PaperCard(
        child: Row(children: [
          Expanded(child: Text(confirmReset ? '정말 처음부터 할까요? 지금 진행은 사라져요' : '새 땅에서 다시 시작', style: Ttc.body(14, color: Ttc.sepia))),
          TtcButton(confirmReset ? '처음부터' : '다시 시작', primary: confirmReset, small: true, onTap: () {
            if (!confirmReset) {
              setState(() => confirmReset = true);
              return;
            }
            widget.onReset();
            Navigator.pop(context);
          }),
        ]),
      ),
    ]);
  }
}
