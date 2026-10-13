// 설정의 '클라우드 저장'과 '피드백 보내기' (웹 cloud.js ui · fbHtml)
import 'package:flutter/material.dart';

import '../game/cloud.dart';
import '../game/engine.dart';
import '../game/storage.dart';
import '../report.dart';
import 'sound.dart';
import 'survivors.dart';
import 'theme.dart';
import 'widgets.dart';

String cloudWhen(int t) {
  if (t <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  return '${d.month}/${d.day} ${'${d.hour}'.padLeft(2, '0')}:${'${d.minute}'.padLeft(2, '0')}';
}

/// 설정 화면의 클라우드 저장 묶음
class CloudSection extends StatelessWidget {
  const CloudSection({super.key, required this.onSaveNow});
  final Future<void> Function() onSaveNow;

  Widget _btn(String t, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x47252E36))),
          child: Text(t, style: Ttc.t(12.5, color: Ttc.sepia, weight: FontWeight.w700)),
        ),
      );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: Cloud.version,
        builder: (c, _, __) {
          final kids = <Widget>[sec('클라우드 저장')];
          if (Cloud.uid == null) {
            kids.add(descText(Cloud.offline
                ? '지금은 인터넷에 닿지 않아 클라우드 저장이 쉬고 있어요. 진행은 이 기기에 그대로 저장되고, 다음에 온라인으로 열면 다시 백업돼요.'
                : Cloud.msg.isNotEmpty
                    ? Cloud.msg
                    : '클라우드에 연결하는 중…'));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids);
          }
          kids.addAll([
            Text('이 기기로 자동 저장 중', style: Ttc.t(14, color: Ttc.sepia, weight: FontWeight.w700)),
            Text.rich(
                TextSpan(children: [
                  const TextSpan(text: '진행이 서버에도 자동으로 백업돼요'),
                  if (Cloud.last > 0) TextSpan(text: '\n마지막 저장 ${cloudWhen(Cloud.last)}'),
                  if (Cloud.msg.isNotEmpty) TextSpan(text: '\n${Cloud.msg}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                style: Ttc.t(12.5, color: Ttc.sepia2, height: 1.5)),
            const SizedBox(height: 8),
            Row(children: [
              _btn('지금 저장', () async {
                await onSaveNow();
                if (Cloud.msg.isEmpty) {
                  Cloud.msg = '저장했어요';
                  Cloud.version.value++;
                }
              }),
              const SizedBox(width: 8),
              _btn('클라우드 데이터 삭제', () async {
                final ok = await cloudAsk(context, '클라우드 데이터를 삭제할까요?',
                    '서버에 저장된 진행 상황과 익명 식별자가 지워져요. 이 기기의 진행은 그대로 남고, 다음 저장부터 새 익명 식별자로 다시 시작해요.', '삭제', '취소');
                if (ok) await Cloud.wipe();
              }),
            ]),
          ]);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids);
        },
      );
}

/// 묻는 창 (웹 ask)
Future<bool> cloudAsk(BuildContext context, String title, String body, String yes, String no) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB30A0805),
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFFEFE3C4),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Ttc.serif(17, color: const Color(0xFF3B2A1A), weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(body, style: Ttc.t(14.5, color: const Color(0xFF3B2A1A), height: 1.55)),
            const SizedBox(height: 14),
            Row(children: [
              pageBtn(no, () => Navigator.pop(ctx, false), alt: true),
              const SizedBox(width: 8),
              pageBtn(yes, () => Navigator.pop(ctx, true)),
            ]),
          ]),
        ),
      ),
    ),
  );
  return r == true;
}

/// 진행·기기 정보 (웹 fbInfo)
Map<String, dynamic> devInfo(Game g, BuildContext? context) {
  final mq = context == null ? null : MediaQuery.maybeOf(context);
  return {
    'app': Report.app,
    'ua': 'TaptocityNative/${Report.ver} (${Report.app})',
    if (mq != null) 'scr': '${mq.size.width.round()}x${mq.size.height.round()}@${mq.devicePixelRatio}',
    'lv': g.S.lv,
    'gen': g.S.gen,
    'region': g.S.region ?? 'home',
    'mi': g.mi,
    'nights': g.num_('nightCount').toInt(),
    'play': (g.num_('playT') / 60).round(),
  };
}

const _fbCat = [('bug', '버그'), ('idea', '제안'), ('hard', '어려워요'), ('like', '좋아요'), ('etc', '기타')];

/// 피드백 보내기 (웹 openFeedback)
Future<void> showFeedback(BuildContext context, Game g) async {
  final ctrl = TextEditingController(text: await Storage.getRaw('ttc_fb_draft') ?? '');
  if (!context.mounted) return;
  var cat = 'idea', info = true, sending = false;
  String? done;
  await showPageOf(context, g, (ctx) => StatefulBuilder(builder: (ctx, set) {
        if (done != null) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            const ResIcon('hope', size: 52),
            const SizedBox(height: 10),
            Text(done == 'sent' ? '고마워요! 잘 전했어요' : '고마워요! 연결되면 보낼게요', style: Ttc.t(19, color: Ttc.sepia, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(done == 'sent' ? '보내 주신 이야기는 하나하나 읽고 게임에 반영할게요.' : '지금은 인터넷에 닿지 않아요. 이 기기에 담아 두었다가 다음에 연결되면 자동으로 보내요.',
                textAlign: TextAlign.center, style: Ttc.t(13, color: Ttc.sepia2, height: 1.55)),
            const SizedBox(height: 14),
            Row(children: [pageBtn('닫기', () => Navigator.pop(ctx))]),
          ]);
        }
        Future<void> send() async {
          final txt = ctrl.text.trim();
          if (txt.length < 2 || sending) {
            if (txt.length < 2) g.fx.add(const FxToast('내용을 조금만 적어 주세요'));
            return;
          }
          set(() => sending = true);
          final now = DateTime.now().millisecondsSinceEpoch;
          final r = await Cloud.feedback({
            'id': '${now.toRadixString(36)}${(now * 7919 % 2176782336).toRadixString(36)}',
            'cat': cat,
            'text': txt.length > 800 ? txt.substring(0, 800) : txt,
            'at': now,
            'ver': Report.ver,
            if (info) 'dev': devInfo(g, ctx),
          });
          await Storage.setRaw('ttc_fb_draft', null);
          Sound.sfx('chime');
          set(() => done = r);
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('피드백', style: Ttc.t(11, color: Ttc.sepia2, weight: FontWeight.w600)),
          Padding(padding: const EdgeInsets.fromLTRB(0, 4, 0, 10), child: Text('개발자에게 한마디', style: Ttc.t(20, color: Ttc.sepia, weight: FontWeight.w700))),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (k, n) in _fbCat)
              GestureDetector(
                onTap: () => set(() => cat = k),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: cat == k ? const Color(0xFF2F3F4B) : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: cat == k ? const Color(0xFF2F3F4B) : const Color(0x47252E36)),
                  ),
                  child: Text(n, style: Ttc.t(12.5, color: cat == k ? Colors.white : Ttc.sepia, weight: FontWeight.w600)),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            maxLength: 800,
            maxLines: 6,
            minLines: 5,
            onChanged: (v) {
              Storage.setRaw('ttc_fb_draft', v);
              set(() {});
            },
            style: Ttc.t(14, color: Ttc.sepia, height: 1.5),
            decoration: InputDecoration(
              hintText: '어떤 점이 좋았는지, 불편했는지, 어디서 막혔는지 알려 주세요.',
              hintStyle: Ttc.t(13.5, color: Ttc.sepia2),
              filled: true,
              fillColor: Ttc.surface,
              counterText: '${ctrl.text.length}/800',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Ttc.line)),
            ),
          ),
          GestureDetector(
            onTap: () => set(() => info = !info),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(value: info, onChanged: (v) => set(() => info = v ?? false), activeColor: const Color(0xFF3B2A1A)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: '진행 단계·기기 정보 함께 보내기\n'),
                        TextSpan(text: '문제를 찾는 데 도움이 돼요', style: Ttc.t(12, color: const Color(0xFF8A7A64))),
                      ]),
                      style: Ttc.t(13.5, color: const Color(0xFF3B2A1A), height: 1.4)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text('이름·연락처는 보내지 않아요. 답장이 필요하면 ceo@itso.co.kr 로 메일 주세요.', style: Ttc.t(12, color: Ttc.sepia2, height: 1.5)),
          const SizedBox(height: 12),
          Row(children: [
            pageBtn('닫기', () => Navigator.pop(ctx), alt: true),
            const SizedBox(width: 8),
            pageBtn(sending ? '보내는 중…' : '보내기', sending ? null : send),
          ]),
        ]);
      }));
  ctrl.dispose();
}
