// 새 기능 안내 카드 (웹 FEAT_GUIDE · featCardHtml · renderGuide '열린 기능 안내')
import 'package:flutter/material.dart';

import '../game/engine.dart';
import 'gear.dart';
import 'survivors.dart';
import 'theme.dart';
import 'underground_ui.dart';
import 'widgets.dart';

class FeatGuide {
  const FeatGuide(this.icon, this.what, this.steps, {this.tip});

  /// 'm:batt' 자재 · 'g:toolbox' 장비 · 'u:quest' 지하 아이콘
  final String icon, what;
  final List<String> steps;
  final String? tip;
}

const featGuide = {
  'radio': FeatGuide('m:batt', '건전지로 주파수를 돌려 물자와 장비를 찾고, 라디오로만 만나는 히든 생존자의 목소리를 잡아요.',
      ['아래 ‘라디오’ 탭을 눌러요.', '‘1번 탐색’은 건전지 1개, ‘5번 탐색’은 5개를 써요. 5번 탐색에는 희귀 자재 이상이 하나는 꼭 들어 있어요.', '화면에 ‘히든 신호까지 남은 횟수’가 나와요. 그 안에 히든 생존자가 반드시 한 번 나와요.'],
      tip: '건전지는 목표·원정·부탁에서 얻고 한도가 없어 모아 둘 수 있어요.'),
  'bag': FeatGuide('g:toolbox', '주운 장비를 생존자에게 입혀 생산과 두드리는 힘을 올려요.',
      ['생존자 수첩 위쪽 ‘장비’를 눌러요.', '장비마다 ‘잘 맞는 사람’이 있어요. 그 사람이 입으면 효과가 1.5배예요.', '‘지금 맞추기’를 누르면 가장 잘 맞게 한 번에 입혀요.', '남는 장비는 ‘정리하기’로 분해해 재료로 돌려받아요.'],
      tip: '아끼는 장비는 자물쇠로 잠가 두면 분해되지 않아요.'),
  'quest': FeatGuide('u:quest', '신뢰가 쌓인 생존자의 개인 이야기가 열렸어요. 끝까지 따라가면 그 사람만의 전용 장비를 받아요.',
      ['생존자 수첩에서 그 사람을 눌러요.', '‘개인 이야기’의 할 일을 확인해요. 물건을 건네거나, 지하에 함께 내려가는 일이에요.', '모든 단계를 마치면 전용 장비와 희망 +3을 받아요.'],
      tip: '전용 장비는 그 사람이 입었을 때 제 힘을 내요.'),
  'deco': FeatGuide('u:rest', '쉘터 주변에 장식을 놓아 마을을 꾸며요.', ['쉘터 화면에서 ‘꾸미기’ 탭을 눌러요.', '장식을 고르고 지도에서 놓을 칸을 눌러요.', '놓은 장식은 다시 눌러 옮기거나 치울 수 있어요.']),
  'ug': FeatGuide('u:stairs', '랜턴 기름이 버티는 만큼 지하로 내려가 귀한 물자와 사람들의 기록을 찾아요.',
      ['원정 탭 맨 위 ‘지하 구역’에서 ‘내려갈 준비’를 눌러요.', '최대 3명과 연료를 챙겨요. 연료 1개는 기름 3이에요.', '어두운 칸을 한 번 두드릴 때마다 기름 1을 써요. 계단을 찾아 더 깊이 내려가요.', '기름이 떨어지기 전에 올라와요. 떨어지면 챙긴 것의 절반을 잃어요.'],
      tip: '다음 탐사는 지난번 멈춘 층부터 시작해요. 1층부터 다시 내려갈 수도 있어요.'),
  'relic': FeatGuide('u:rare', '폐허에서 찾은 유물을 일지 ‘도감’에 모아요.', ['일지에서 ‘도감’ 탭을 눌러요.', '찾은 유물의 이야기와 효과를 볼 수 있어요.', '유물은 이주할 때도 함께 가져가요.']),
  'auto': FeatGuide('u:who', '버튼 한 번으로 빈 일터에 딱 맞는 사람을 앉혀요.', ['생존자 수첩 맨 위 ‘자동’을 눌러요.', '스위치를 켜 두면 빈 일터가 생길 때 알아서 채워요.'], tip: '딱 맞는 사람이 일하면 모듈 효과가 커져요.'),
  'autoexp': FeatGuide('u:start', '쉬는 사람으로 가장 효율 좋은 팀을 꾸려 원정을 보내고, 돌아오면 전리품도 챙겨요.', ['원정 탭 맨 위 ‘자동 원정’ 스위치를 켜요.', '순찰·아이 돌보기 중인 사람은 빼고 팀을 꾸려요.']),
  'acraft': FeatGuide('g:welder', '레시피마다 자동 가공을 켜 두면 재료가 있을 때 알아서 만들어요.', ['쉘터 화면 ‘가공’ 탭을 눌러요.', '레시피 옆 자동 스위치를 켜요.']),
  'trade': FeatGuide('u:shop', '이주할 때 남겨 둔 사람들과 무전으로 물건을 바꿔요.', ['라디오 탭에서 아래 ‘무전 거래’로 내려가요.', '남은 사람마다 바꿔 주는 물건이 달라요.', '거래한 물건은 잠시 뒤에 도착해요.']),
  'route': FeatGuide('g:lnMap', '만수가 그려 준 노선도에서 지나온 동네와 남은 사람들을 봐요.', ['일지에서 ‘노선도’ 탭을 눌러요.', '동네를 누르면 그곳에 남은 사람과 기록이 나와요.']),
  'migrate': FeatGuide('u:door', '불빛의 도시를 완성했어요. 새 동네로 떠날 수 있어요.',
      ['쉘터 화면 건설 탭 맨 위 ‘새 동네로’를 눌러요.', '함께 갈 사람과 남을 사람을 골라요. 남은 사람과는 무전 거래를 이어가요.', '사람·장비·유물은 함께 가고, 등불의 기억(생산·두드리기 +10%)이 쌓여요.']),
  'line': FeatGuide('g:lnLamp', '복구한 역(랜드마크) 안쪽 터널을 따라 종점까지 가는 던전이에요.',
      ['원정 탭 ‘끊긴 노선’에서 ‘노선 들어가기’를 눌러요. 지도에서 역 랜드마크를 눌러 ‘노선 탐사’로 들어가도 돼요.', '동료는 2명까지, 1명당 식량 8을 도시락으로 써요.', '갈림길마다 터널 셋 중 하나를 골라요. 재 괴물은 좁혀 오는 고리가 금빛 테두리에 겹칠 때 두드려요.', '역에서 올라갈지 더 갈지 정해요. 종점의 우두머리를 쓰러뜨리면 이 동네 전용 물건을 얻어요.'],
      tip: '연달아 들어가면 보상이 줄고, 15분마다 한 단계씩 회복해요.'),
  'pets': FeatGuide('u:pet', '식구가 된 동물을 돌보면 효과가 커지고 사연이 열려요.',
      ['생존자 수첩 위쪽 ‘펫’을 눌러요.', '동행 펫 한 마리는 효과를 모두 내고, 쉬는 펫은 절반을 내요.', '지도에서 펫을 누르면 쓰다듬고, 먹이를 주면 친밀도가 올라요.'],
      tip: '잘 맞는 생존자와 함께 있으면 희망이 오르고 더 빨리 친해져요.'),
  'fire': FeatGuide('m:hope', '눈 덮인 산골에서는 모닥불 온기를 지켜야 해요.',
      ['위쪽 띠의 ‘모닥불’ 칩에서 온기를 확인해요.', '밤과 한파에는 빨리 식어요. 칩을 눌러 장작을 넣으면 온기 +30이에요.', '온기가 60% 이상이면 희망 +4·두드리는 힘 +15%, 꺼지면 생산이 ×0.8로 줄어요.']),
};

/// 카드 머리 아이콘 (웹 .fcic: 어두운 둥근 네모)
Widget featIcon(String k, {double box = 64}) {
  final G = featGuide[k];
  final a = G?.icon.split(':') ?? const ['u', 'who'];
  final inner = box * .86;
  final Widget pic = switch (a[0]) {
    'm' => ResIcon(a[1], size: box * .75),
    'g' => GearIcon(a[1], size: inner),
    _ => SizedBox(width: inner, height: inner, child: ugIcon(a[1])),
  };
  return Container(
    width: box,
    height: box,
    decoration: BoxDecoration(color: const Color(0xFF2C333B), borderRadius: BorderRadius.circular(box > 50 ? 14 : 10)),
    clipBehavior: Clip.antiAlias,
    alignment: Alignment.center,
    child: pic,
  );
}

/// 새 기능 안내 카드. go가 있으면 '보러 가기'
Future<void> showFeatCard(BuildContext context, Game g, String k, {required void Function(String k) go}) {
  final f = feats.where((x) => x.k == k).firstOrNull, G = featGuide[k];
  if (f == null || G == null) return Future.value();
  return showPageOf(
    context,
    g,
    (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('새 기능 안내', style: Ttc.serif(12, color: Ttc.no, weight: FontWeight.w700).copyWith(letterSpacing: 1.2)),
      const SizedBox(height: 4),
      Row(children: [
        featIcon(k),
        const SizedBox(width: 12),
        Expanded(child: Text(f.h, style: Ttc.t(21, color: Ttc.sepia, weight: FontWeight.w700, height: 1.25))),
      ]),
      const SizedBox(height: 10),
      Text(G.what, style: Ttc.t(15, color: Ttc.sepia, height: 1.6)),
      const SizedBox(height: 12),
      Text('이렇게 써요', style: Ttc.t(12.5, color: Ttc.sepia2, weight: FontWeight.w700)),
      const SizedBox(height: 6),
      for (var i = 0; i < G.steps.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(color: const Color(0x0F3B2A1A), borderRadius: BorderRadius.circular(10)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 21,
              height: 21,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Color(0xFF2C333B), shape: BoxShape.circle),
              child: Text('${i + 1}', style: Ttc.t(12, color: const Color(0xFFFFDF9E), weight: FontWeight.w700, height: 1)),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(G.steps[i], style: Ttc.t(14, color: Ttc.sepia, height: 1.5))),
          ]),
        ),
      if (G.tip != null)
        Container(
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: const Color(0x29D9A34E), borderRadius: BorderRadius.circular(10)),
          child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: '팁 ', style: TextStyle(fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])),
                TextSpan(text: G.tip),
              ]),
              style: Ttc.t(13.5, color: const Color(0xFF5A3D12), height: 1.55)),
        ),
      const SizedBox(height: 8),
      Row(children: [
        pageBtn('나중에', () => Navigator.of(ctx).pop(), alt: true),
        const SizedBox(width: 8),
        pageBtn(f.sheet != null || k == 'fire' ? '보러 가기' : '알겠어요', () {
          Navigator.of(ctx).pop();
          if (f.sheet != null || k == 'fire') go(k);
        }),
      ]),
    ]),
  );
}

/// 안내서 맨 위 '열린 기능 안내' (웹 renderGuide fclist)
List<Widget> featListSection(BuildContext context, Game g, {required void Function(String k) go}) {
  final open = [for (final f in feats) if (featGuide.containsKey(f.k) && g.featOf(f.k) != 0) f];
  if (open.isEmpty) return const [];
  return [
    Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('열린 기능 안내', style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700))),
    for (final f in open)
      GestureDetector(
        onTap: () => showFeatCard(context, g, f.k, go: go),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: const Color(0x0F3B2A1A), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            featIcon(f.k, box: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.h, style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700)),
                Text(featGuide[f.k]!.what, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ttc.t(12, color: Ttc.sepia2, height: 1.4)),
              ]),
            ),
            Text('›', style: Ttc.t(18, color: Ttc.sepia2)),
          ]),
        ),
      ),
    const SizedBox(height: 12),
  ];
}

/// 화면이 정해 주는 '보러 가기' (게임 화면이 연다)
class FeatNav {
  FeatNav._();
  static void Function(String k)? go;
}
