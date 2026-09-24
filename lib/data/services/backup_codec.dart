import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:image/image.dart' as img;
import 'card_access_policy.dart';

abstract final class BackupCodec {
  static const limitBytes = 10000000;
  static final cipher = AesGcm.with256bits();
  static String digest(List<int> bytes) => sha256.convert(bytes).toString();
  static Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {for(final k in keys) k: canonical(value[k])};
    }
    if(value is List) return value.map(canonical).toList();
    return value;
  }
  static Map<String,dynamic> portable(Map card) {
    final copy = Map<String,dynamic>.from(card);
    copy.removeWhere((k,v) => k.startsWith('share') || k=='isShared' || k=='backupOwnerId' || k=='lastUsedAt');
    // Catalog assets can change independently of the user's cards.
    if((copy['brandId']?.toString() ?? '').isNotEmpty) copy.remove('logoAsset');
    return copy;
  }
  static bool belongsTo(Map card,String user) => !CardAccessPolicy.isReceived(card) && card['backupOwnerId']==user;
  static Future<Map<String,String>> seal(List<int> plain,List<int> key,String user) async {
    final id=digest(plain);
    final box=await cipher.encrypt(plain,secretKey:SecretKey(key),aad:utf8.encode('paskluis-backup-v1:$user:$id'));
    return {'id':id,'data':base64Encode([...box.nonce,...box.cipherText,...box.mac.bytes])};
  }
  static Future<Uint8List> open(Map object,List<int> key,String user) async {
    final id=object['id'] as String;
    final data=base64Decode(object['data'] as String);
    if(data.length<29 || data.length>limitBytes || !RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) throw const FormatException('INVALID_BACKUP');
    final plain=await cipher.decrypt(SecretBox(data.sublist(12,data.length-16),nonce:data.sublist(0,12),mac:Mac(data.sublist(data.length-16))),secretKey:SecretKey(key),aad:utf8.encode('paskluis-backup-v1:$user:$id'));
    if(digest(plain)!=id) throw const FormatException('INVALID_BACKUP');
    return Uint8List.fromList(plain);
  }
  static Uint8List prepareImage(Uint8List data) {
    if(data.length>30000000) throw const FormatException('IMAGE_TOO_LARGE');
    final decoder=img.findDecoderForData(data);
    final info=decoder?.startDecode(data);
    if(info==null || info.width*info.height>40000000) throw const FormatException('IMAGE_INVALID');
    var image=decoder!.decodeFrame(0);
    if(image==null) throw const FormatException('IMAGE_INVALID');
    if(image.width>1600 || image.height>1600) {
      image=img.copyResize(image,width:image.width>=image.height?1600:null,height:image.height>image.width?1600:null,interpolation:img.Interpolation.average);
    }
    return Uint8List.fromList(img.encodePng(image));
  }
  static List<Map<String,dynamic>> readManifest(List<int> bytes,Set<String> images) {
    final m=jsonDecode(utf8.decode(bytes));
    if(m is! Map || m['schema']!=1 || m['cards'] is! List || (m['cards'] as List).length>5000) throw const FormatException('INVALID_BACKUP');
    final result=<Map<String,dynamic>>[];final ids=<String>{};
    for(final raw in m['cards']) {
      if(raw is! Map) throw const FormatException('INVALID_BACKUP');
      final c=Map<String,dynamic>.from(raw); final id=c['id'];
      if(id is! String || id.isEmpty || !ids.add(id) || CardAccessPolicy.isReceived(c)) throw const FormatException('INVALID_BACKUP');
      if((c['customImage']??'')!='' && !images.contains(c['customImage'])) throw const FormatException('INVALID_BACKUP');
      result.add(c);
    }
    return result;
  }
}
