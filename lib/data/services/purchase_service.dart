import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'account_service.dart';
import 'settings_service.dart';
import 'store_access_service.dart';

abstract final class PurchaseService {
  static const productId = 'paskluis_plus';
  static final revision = ValueNotifier<int>(0);
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static ProductDetails? product;
  static bool busy = false;
  static bool loading = false;
  static String? messageCode;
  static Future<void> _work = Future.value();
  static String? _purchaseUserId;
  static bool _explicitAction = false;
  static Timer? _watchdog;

  static void init() {
    _subscription ??= InAppPurchase.instance.purchaseStream.listen((purchases) {
      _work = _work
          .then((_) => _process(purchases))
          .catchError((_) => _finish('failed'));
    }, onError: (_) => _finish('failed'));
  }

  static Future<void> loadProduct() async {
    if (loading) return;
    init();
    loading = true;
    revision.value++;
    try {
      if (!await InAppPurchase.instance.isAvailable().timeout(
        const Duration(seconds: 15),
      )) {
        product = null;
        return;
      }
      final response = await InAppPurchase.instance
          .queryProductDetails({productId})
          .timeout(const Duration(seconds: 20));
      product = response.error == null
          ? response.productDetails.where((p) => p.id == productId).firstOrNull
          : null;
    } catch (_) {
      product = null;
    } finally {
      loading = false;
      revision.value++;
    }
  }

  // Store correlation only; no personal information or app account required.
  static String _newStoreToken() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static void _start() {
    init();
    busy = true;
    messageCode = null;
    _explicitAction = true;
    _purchaseUserId = AccountService.currentUser?.id;
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(minutes: 2), () => _finish('pending'));
    revision.value++;
  }

  static void _finish(String code) {
    _watchdog?.cancel();
    busy = false;
    messageCode = code;
    revision.value++;
  }

  static Future<void> buy() async {
    if (product == null || busy || !SettingsService.storePurchaseEnabled)
      return;
    _start();
    try {
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product!,
          applicationUserName: _newStoreToken(),
        ),
      );
      if (!started) _finish('failed');
    } catch (_) {
      _finish('failed');
    }
  }

  static Future<void> restore() async {
    if (busy) return;
    _start();
    try {
      await InAppPurchase.instance.restorePurchases().timeout(
        const Duration(seconds: 30),
      );
      await _work;
      if (busy) _finish('restoreRequested');
    } catch (_) {
      _finish('failed');
    }
  }

  static Future<void> linkToAccount() async {
    if (busy || AccountService.currentUser == null) return;
    _start();
    try {
      _finish(
        await StoreAccessService.linkToAccount() ? 'success' : 'verification',
      );
    } catch (_) {
      _finish('linkFailed');
    }
  }

  static Future<void> _process(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;
      if (purchase.status == PurchaseStatus.pending) {
        busy = true;
        messageCode = 'pending';
        revision.value++;
        continue;
      }
      if (purchase.status == PurchaseStatus.canceled) {
        _finish('cancelled');
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        _finish('failed');
        continue;
      }
      try {
        final proof = purchase.verificationData.serverVerificationData;
        if (proof.isEmpty) throw StateError('Missing store proof');
        // Do not attach delayed callbacks to an account signed in afterwards.
        final link =
            _explicitAction &&
            _purchaseUserId != null &&
            AccountService.currentUser?.id == _purchaseUserId;
        final active = await StoreAccessService.verify(proof);
        var linkFailed = false;
        if (active && link) {
          try {
            await StoreAccessService.verify(proof, linkAccount: true);
          } catch (_) {
            linkFailed = true;
          }
        }
        if (purchase.pendingCompletePurchase)
          await InAppPurchase.instance.completePurchase(purchase);
        _finish(
          !active
              ? 'revoked'
              : linkFailed
              ? 'linkFailed'
              : 'success',
        );
      } catch (_) {
        _finish('verification');
      }
    }
  }
}
