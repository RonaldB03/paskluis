import 'dart:async';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

class FakePurchasePlatform extends InAppPurchasePlatform {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = false;
  int restores = 0;
  int buys = 0;
  PurchaseParam? lastPurchase;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async => ProductDetailsResponse(productDetails: [ProductDetails(id: 'paskluis_plus', title: 'Plus', description: 'Plus', price: '€ 1,99', rawPrice: 1.99, currencyCode: 'EUR')], notFoundIDs: []);
  @override
  Future<void> restorePurchases({String? applicationUserName}) async { restores++; }
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async { buys++; lastPurchase = purchaseParam; return true; }
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}
