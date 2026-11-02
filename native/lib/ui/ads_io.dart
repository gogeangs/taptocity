// 시즌 2 광고 (2026-11-02 대표님 결정): 과금 없음.
// - 전면 광고: 동네를 옮길 때 '가는 길' 화면 (첫 동네 이주부터, 앱 전체)
// - 보상형: 원할 때만 (먼 원정 30분 줄이기 · 무전 거래 하나 더), 합쳐서 하루 6번 (game/s2.dart adLeft)
// - 맞춤 광고: 첫 광고 직전에 우리 안내 한 장('계속' 하나) → iOS 추적 허용 팝업 → 유럽이면 구글 동의 창.
//   허용 여부와 상관없이 게임은 같다(허용 유도·보상 금지).
// 웹 미리보기·데스크톱에서는 광고 없이 그대로 지나간다.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../game/engine.dart';
import '../game/storage.dart';
import 'theme.dart';

class Ads {
  Ads._();
  static bool get on => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // 광고 단위 (AdMob 계정 pub-8720405407394137, 2026-11-02 등록)
  static String get _inter => Platform.isIOS ? 'ca-app-pub-8720405407394137/5560948785' : 'ca-app-pub-8720405407394137/5408905546';
  static String get _rew => Platform.isIOS ? 'ca-app-pub-8720405407394137/2782742205' : 'ca-app-pub-8720405407394137/4095823879';

  static bool _init = false;
  static InterstitialAd? _i;
  static RewardedAd? _r;

  static Future<void> init() async {
    if (!on || _init) return;
    _init = true;
    try {
      await MobileAds.instance.initialize();
      _loadI();
      _loadR();
    } catch (_) {}
  }

  static void _loadI() {
    if (!on) return;
    InterstitialAd.load(
        adUnitId: _inter,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: (a) => _i = a, onAdFailedToLoad: (e) => _i = null));
  }

  static void _loadR() {
    if (!on) return;
    RewardedAd.load(adUnitId: _rew, request: const AdRequest(), rewardedAdLoadCallback: RewardedAdLoadCallback(onAdLoaded: (a) => _r = a, onAdFailedToLoad: (e) => _r = null));
  }

  static const _askKey = 'ttc_ad_asked';

  /// 첫 광고 직전 한 번: 안내 한 장 → iOS 추적 허용 → (유럽) 동의 창
  static Future<void> _ask(BuildContext context) async {
    if (await Storage.getRaw(_askKey) != null) return;
    await Storage.setRaw(_askKey, '1');
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xC70F161D),
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFF3EEE2),
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('광고 안내', style: Ttc.t(12, color: Ttc.sepia2, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('탭투시티는 결제 없이 무료예요', style: Ttc.t(19, color: Ttc.sepia, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('광고는 동네를 옮길 때와, 원정을 빨리 부르고 싶을 때처럼 원할 때만 나와요.\n이어서 휴대폰이 광고 맞춤 여부를 물어볼 수 있어요. 어느 쪽을 골라도 게임은 똑같아요.',
                style: Ttc.t(14, color: const Color(0xFF4A3320), height: 1.7)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Ttc.amber, borderRadius: BorderRadius.circular(9)),
                child: Text('계속', style: Ttc.t(15, color: const Color(0xFF252E36), weight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
    try {
      if (Platform.isIOS && await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (_) {}
    // 유럽 경제 지역·영국: 구글 동의 창 (필요한 곳에서만 뜬다)
    try {
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(ConsentRequestParameters(), () {
        ConsentForm.loadAndShowConsentFormIfRequired((e) {
          if (!done.isCompleted) done.complete();
        });
      }, (e) {
        if (!done.isCompleted) done.complete();
      });
      await done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
    } catch (_) {}
  }

  /// 이주 '가는 길': 한 줄을 보여 주고, 전면 광고가 준비돼 있으면 하나
  static Future<void> wayAndAd(BuildContext context, String line) async {
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xF20F161D),
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('가는 길', style: Ttc.t(12, color: const Color(0xFFB9AE98), weight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(line, textAlign: TextAlign.center, style: Ttc.t(17, color: const Color(0xFFF3E7CB), weight: FontWeight.w600, height: 1.7)),
            ]),
          ),
        ),
      ),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (on && context.mounted) {
      await _ask(context);
      final a = _i;
      if (a != null) {
        _i = null;
        final done = Completer<void>();
        a.fullScreenContentCallback = FullScreenContentCallback(onAdDismissedFullScreenContent: (x) {
          x.dispose();
          if (!done.isCompleted) done.complete();
        }, onAdFailedToShowFullScreenContent: (x, e) {
          x.dispose();
          if (!done.isCompleted) done.complete();
        });
        try {
          await a.show();
          await done.future.timeout(const Duration(minutes: 2), onTimeout: () {});
        } catch (_) {}
      }
      _loadI();
    }
    if (nav.mounted && nav.canPop()) nav.pop();
  }

  /// 보상형: 끝까지 보면 true
  static Future<bool> rewarded(BuildContext context, Game g) async {
    if (!on) return false;
    await _ask(context);
    final a = _r;
    if (a == null) {
      _loadR();
      g.fx.add(const FxToast('광고를 불러오는 중이에요 · 잠시 뒤 다시 눌러요'));
      return false;
    }
    _r = null;
    var got = false;
    final done = Completer<void>();
    a.fullScreenContentCallback = FullScreenContentCallback(onAdDismissedFullScreenContent: (x) {
      x.dispose();
      if (!done.isCompleted) done.complete();
    }, onAdFailedToShowFullScreenContent: (x, e) {
      x.dispose();
      if (!done.isCompleted) done.complete();
    });
    try {
      await a.show(onUserEarnedReward: (ad, r) => got = true);
      await done.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    } catch (_) {}
    _loadR();
    return got;
  }
}
