import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/data/services/backup_codec.dart';

void main(){
 final key=List<int>.generate(32,(i)=>i);
 test('encrypted cards round trip only for the correct account and key',()async{
  final plain=utf8.encode('{"pinCode":"1234","code":"001234"}');
  final object=await BackupCodec.seal(plain,key,'account-a');
  expect(await BackupCodec.open(object,key,'account-a'),plain);
  await expectLater(BackupCodec.open(object,key,'account-b'),throwsA(anything));
  await expectLater(BackupCodec.open(object,List.filled(32,9),'account-a'),throwsA(anything));
  final corrupt=base64Decode(object['data']!);corrupt[15]^=1;
  await expectLater(BackupCodec.open({...object,'data':base64Encode(corrupt)},key,'account-a'),throwsA(anything));
 });
 test('identical content deduplicates while encryption uses fresh nonces',()async{
  final a=await BackupCodec.seal([1,2,3],key,'a');final b=await BackupCodec.seal([1,2,3],key,'a');
  expect(a['id'],b['id']);expect(a['data'],isNot(b['data']));
 });
 test('received and foreign-account cards cannot enter an own backup',(){
  expect(BackupCodec.belongsTo({'backupOwnerId':'a'},'a'),true);
  expect(BackupCodec.belongsTo({'backupOwnerId':'b'},'a'),false);
  expect(BackupCodec.belongsTo({'backupOwnerId':'a','isShared':true},'a'),false);
  expect(BackupCodec.belongsTo({},'a'),false);
 });
 test('rejects duplicate IDs, shared cards and missing image objects',(){
  List<int> data(List cards)=>utf8.encode(jsonEncode({'schema':1,'cards':cards}));
  expect(()=>BackupCodec.readManifest(data([{'id':'1'},{'id':'1'}]),{}),throwsFormatException);
  expect(()=>BackupCodec.readManifest(data([{'id':'1','isShared':true}]),{}),throwsFormatException);
  expect(()=>BackupCodec.readManifest(data([{'id':'1','customImage':'missing'}]),{}),throwsFormatException);
  expect(BackupCodec.readManifest(data([{'id':'1','code':'0001'}]),{}).single['code'],'0001');
 });
 test('portable cards remove shared privileges and preserve PIN and QR data',(){
  final card=BackupCodec.portable({'id':'1','sharedCardId':'secret','shareOwnerId':'a','backupOwnerId':'a','pinCode':'0002','code':'001','brandId':'hema','logoAsset':'old'});
  expect(card.containsKey('sharedCardId'),false);expect(card.containsKey('backupOwnerId'),false);expect(card['pinCode'],'0002');expect(card['code'],'001');
 });
}
