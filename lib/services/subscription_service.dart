import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "광고 제거" 구독을 관리하는 서비스.
///
/// 주의: 여기서는 클라이언트에 결제 성공 여부를 로컬로 저장하는
/// 방식입니다 (빠르게 구현하기 위한 최소 버전). 조작 방지가 중요하다면
/// 서버에서 영수증(receipt)을 검증하는 절차를 추가하는 것이 안전합니다.
class SubscriptionService {
  SubscriptionService._internal();
  static final SubscriptionService _instance =
      SubscriptionService._internal();
  factory SubscriptionService() => _instance;

  // TODO: Play Console / App Store Connect에 등록한 구독 상품 ID로 교체하세요.
  static const String removeAdsProductId = 'remove_ads_monthly';

  static const String _premiumFlagKey = 'is_premium';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  /// UI에서 구독 상태를 실시간으로 구독하고 싶을 때 사용 (예: 설정 화면 버튼 표시/숨김)
  final ValueNotifier<bool> isPremiumNotifier = ValueNotifier(false);

  Future<void> initialize() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    isPremiumNotifier.value = prefs.getBool(_premiumFlagKey) ?? false;

    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('인앱 결제를 사용할 수 없는 환경입니다.');
      return;
    }

    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (error) => debugPrint('구매 스트림 오류: $error'),
    );

    // 재설치 등으로 인한 구매 내역 복원
    await _iap.restorePurchases();
  }

  Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumFlagKey) ?? false;
  }

  /// 설정 화면의 "광고 제거" 버튼에서 호출하세요.
  Future<void> purchaseRemoveAds() async {
    final response = await _iap.queryProductDetails({removeAdsProductId});

    if (response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty) {
      debugPrint('스토어에서 상품을 찾을 수 없습니다: ${response.notFoundIDs}');
      return;
    }

    final product = response.productDetails.first;
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// "구매 복원" 버튼에서 호출하세요 (기기 변경/재설치 대응).
  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> _handlePurchaseUpdates(
      List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (purchase.productID == removeAdsProductId) {
          await _setPremium(true);
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('구매 오류: ${purchase.error}');
      }
    }
  }

  Future<void> _setPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumFlagKey, value);
    isPremiumNotifier.value = value;
  }

  void dispose() {
    _purchaseSubscription?.cancel();
  }
}