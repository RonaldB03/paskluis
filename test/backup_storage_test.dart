import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:paskluis_v1/data/services/storage_service.dart';
void main(){
 test('new cards belong to the consenting backup account, never to a stale session',()async{
  final dir=await Directory.systemTemp.createTemp('paskluis-backup-test-');
  Hive.init(dir.path);await Hive.openBox(StorageService.cardsBoxName);
  try{
   StorageService.accountId='a';StorageService.backupOwner='a';
   for(final type in ['Pasje','QR-code','QR-set','Cadeaukaart']){
    final key=await StorageService.addCard({'id':type,'type':type});
    expect((StorageService.cardsBox.get(key) as Map)['backupOwnerId'],'a');
    await StorageService.saveCard(key,{'id':type,'type':type,'name':'Edited'});
    expect((StorageService.cardsBox.get(key) as Map)['backupOwnerId'],'a');
   }
   StorageService.accountId='b';
   final key=await StorageService.addCard({'id':'new-b','type':'Pasje'});
   expect((StorageService.cardsBox.get(key) as Map)['backupOwnerId'],isNull);
   final received=await StorageService.addCard({'id':'shared','isShared':true,'shareRecipientId':'b'});
   expect((StorageService.cardsBox.get(received) as Map)['backupOwnerId'],isNull);
  }finally{StorageService.accountId=null;StorageService.backupOwner=null;await Hive.close();await dir.delete(recursive:true);}
 });
}
