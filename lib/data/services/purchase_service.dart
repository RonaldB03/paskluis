import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'account_service.dart';
import 'settings_service.dart';
import 'supabase_service.dart';

abstract final class PurchaseService {
 static const productId='paskluis_plus';
 static final revision=ValueNotifier<int>(0);
 static StreamSubscription<List<PurchaseDetails>>? _subscription;
 static ProductDetails? product;
 static bool busy=false;
 static String? messageCode;
 static Future<void> _work=Future.value();
 static void init(){
  _subscription??=InAppPurchase.instance.purchaseStream.listen((purchases){
   _work=_work.then((_)=>_process(purchases)).catchError((_){busy=false;messageCode='failed';revision.value++;});
  },onError:(_){busy=false;messageCode='failed';revision.value++;});
 }
 static Future<void> loadProduct() async {
  init();
  if(!await InAppPurchase.instance.isAvailable()){product=null;revision.value++;return;}
  final response=await InAppPurchase.instance.queryProductDetails({productId});
  product=response.productDetails.where((p)=>p.id==productId).firstOrNull;
  revision.value++;
 }
 static Future<void> buy() async {
  final user=AccountService.currentUser;
  if(user==null||product==null||busy||!SettingsService.storePurchaseEnabled)return;
  busy=true;messageCode=null;revision.value++;
  try{
   final started=await InAppPurchase.instance.buyNonConsumable(purchaseParam:PurchaseParam(productDetails:product!,applicationUserName:user.id));
   if(!started){busy=false;messageCode='failed';revision.value++;}
  }catch(_){busy=false;messageCode='failed';revision.value++;}
 }
 static Future<void> restore() async {
  if(AccountService.currentUser==null||busy)return;
  init();busy=true;messageCode=null;revision.value++;
  try{await InAppPurchase.instance.restorePurchases(applicationUserName:AccountService.currentUser!.id);await _work;}
  finally{busy=false;revision.value++;}
 }
 static Future<void> _process(List<PurchaseDetails> purchases) async {
  for(final purchase in purchases){
   if(purchase.productID!=productId)continue;
   if(purchase.status==PurchaseStatus.pending){busy=true;messageCode='pending';revision.value++;continue;}
   if(purchase.status==PurchaseStatus.canceled){busy=false;messageCode='cancelled';revision.value++;continue;}
   if(purchase.status==PurchaseStatus.error){busy=false;messageCode='failed';revision.value++;continue;}
   final userId=AccountService.currentUser?.id;
   if(userId==null){busy=false;messageCode='signIn';revision.value++;continue;}
   try{
    final response=await SupabaseService.client!.functions.invoke('verify-purchase',body:{
     'platform':Platform.isIOS?'apple':'google','productId':productId,
     'proof':Platform.isIOS?purchase.purchaseID:purchase.verificationData.serverVerificationData,
    });
    if(response.data is! Map||response.data['verified']!=true)throw StateError('Not verified');
    if(AccountService.currentUser?.id!=userId)continue;
    await AccountService.loadPlusStatus();
    if(purchase.pendingCompletePurchase)await InAppPurchase.instance.completePurchase(purchase);
    messageCode='success';
   }catch(_){messageCode='verification';}
   finally{busy=false;revision.value++;}
  }
 }
}
