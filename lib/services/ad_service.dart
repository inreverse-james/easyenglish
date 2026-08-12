import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easyenglish/services/subscription_service.dart';

/// 전면 광고(interstitial) 노출을 관리하는 서비스.
/// - 단어 [wordsPerAd]개를 볼 때마다 1회
/// - 시험 결과 화면 진입 직전에 1회
/// 구독 중(광고 제거)이면 아무 것도 하지 않습니다.
class AdService {
  AdService._internal();
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;

  // TODO: 실제 서비스 배포 전, 애드몹 콘솔에서 발급받은 실제 광고 단위 ID로 교체하세요.
  // 아래는 구글이 제공하는 "테스트용" 전면 광고 ID입니다 (개발 중에는 반드시 이걸 쓰세요).
  static const String _interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  static const String _wordViewCountKey = 'word_view_count';
  static const int wordsPerAd = 20;

  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;



  Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    if (_isAdLoading || _interstitialAd != null) return;
    _isAdLoading = true;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('전면 광고 로드 실패: $error');
          _interstitialAd = null;
          _isAdLoading = false;
        },
      ),
    );
  }

  /// 단어 1개를 봤을 때 호출하세요 (예: 단어 학습 화면에서 다음 단어로 넘어갈 때).
  /// 누적 [wordsPerAd]개마다 전면 광고를 띄웁니다.
  Future<void> registerWordViewed() async {
    if (await SubscriptionService().isPremium()) return;

    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_wordViewCountKey) ?? 0) + 1;

    if (count >= wordsPerAd) {
      await prefs.setInt(_wordViewCountKey, 0);
      _showInterstitial();
    } else {
      await prefs.setInt(_wordViewCountKey, count);
    }
  }

  /// 시험 결과 화면으로 넘어가기 직전에 호출하세요.
  /// 광고를 다 본 뒤(또는 광고가 없으면 즉시) [onComplete]가 실행됩니다.
  /// 구독 중이면 광고 없이 바로 onComplete가 실행됩니다.
  Future<void> showBeforeResult(VoidCallback onComplete) async {
    if (await SubscriptionService().isPremium()) {
      onComplete();
      return;
    }
    _showInterstitial(onDismissed: onComplete);
  }

  void _showInterstitial({VoidCallback? onDismissed}) {
    final ad = _interstitialAd;
    if (ad == null) {
      // 아직 로드된 광고가 없으면 광고 없이 진행하고, 다음 번을 위해 미리 로드해 둡니다.
      onDismissed?.call();
      _loadInterstitialAd();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
        onDismissed?.call();
      },
    );

    ad.show();
  }
}