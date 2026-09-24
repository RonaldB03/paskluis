import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'account_service.dart';
import 'backup_codec.dart';
import 'card_access_policy.dart';
import 'media_storage_service.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

abstract final class BackupService {
  static final revision=ValueNotifier(0);
  static bool busy=false;
  static String? error;
  static Map<String,dynamic>? status;
  static Timer? _timer;
  static StreamSubscription? _changes;
  static SharedPreferences? _prefs;
  static String? _user;
  static bool _suppress=false;
  static String? get user => AccountService.currentUser?.id;
  static bool get enabled => user!=null && (_prefs?.getBool('backup_enabled_$user')??false);
  static List<Map<String,dynamic>> get versions => (status?['versions'] as List? ?? []).map((v)=>Map<String,dynamic>.from(v)).toList();
  static String? get lastSuccess => versions.isEmpty?null:versions.first['createdAt']?.toString();
  static void _notify()=>revision.value++;
  static Future<void> init() async {
    _prefs=await SharedPreferences.getInstance();_user=user;
    StorageService.backupOwner=enabled?user:null;
    _changes??=StorageService.cardsBox.watch().listen((_) {if(!_suppress) schedule();});
  }
  static void accountChanged() {
    if(_user==user)return;
    _user=user;StorageService.backupOwner=enabled?user:null;status=null;error=null;_timer?.cancel();_notify();
  }
  static void pause() {_timer?.cancel();StorageService.backupOwner=null;status=null;_notify();}
  static void schedule() {
    if(!enabled || _suppress)return;
    _timer?.cancel();_timer=Timer(const Duration(seconds:15),()=>upload(automatic:true));
  }
  static void _check(String id,int epoch) {
    if(user!=id || StorageService.accountRevision!=epoch || AccountService.isSigningOut) throw StateError('ACCOUNT_CHANGED');
  }
  static Future<Map<String,dynamic>> _call(String action,String id,int epoch,[Map<String,dynamic> data=const {}]) async {
    _check(id,epoch);
    try {
      final r=await SupabaseService.client!.functions.invoke('card-backups',body:{'action':action,...data});
      _check(id,epoch);
      final result=Map<String,dynamic>.from(r.data as Map);
      if(result['error']!=null)throw StateError(result['error'].toString());
      return result;
    } on FunctionException catch(e) {
      final details=e.details;
      throw StateError(details is Map?details['error']?.toString()??'BACKUP_FAILED':'BACKUP_FAILED');
    }
  }
  static Future<void> refresh() async {
    accountChanged();if(user==null||busy)return;
    final id=user!;final epoch=StorageService.accountRevision;
    busy=true;error=null;_notify();
    try {status=await _call('status',id,epoch);status!.remove('key');}
    catch(e){error=_code(e);}
    finally{busy=false;_notify();}
    if(enabled && error==null)schedule();
  }
  static String _code(Object e)=>e.toString().split(': ').last;
  static Future<void> setEnabled(bool value) async {
    final id=user;if(id==null||busy)return;
    final epoch=StorageService.accountRevision;
    if(value) {
      await refresh();_check(id,epoch);
      if(error!=null || status?['available']!=true)throw StateError(error??'NOT_AVAILABLE');
      // An existing cloud history must be reviewed before this installation uploads.
      if(versions.isNotEmpty && _prefs?.getString('backup_reviewed_$id')!=status?['generation']) throw StateError('RESTORE_FIRST');
      _suppress=true;
      try {
        for(final key in StorageService.cardsBox.keys.toList()) {
          final c=StorageService.cardsBox.get(key);
          if(c is Map && !CardAccessPolicy.isReceived(c) && c['backupOwnerId']==null) {
            _check(id,epoch);await StorageService.saveCard(key,{...c,'backupOwnerId':id});
          }
        }
      }finally{_suppress=false;}
    }
    _check(id,epoch);await _prefs!.setBool('backup_enabled_$id',value);
    StorageService.backupOwner=value?id:null;
    if(value)schedule();else _timer?.cancel();_notify();
  }
  static Future<void> upload({bool automatic=false}) async {
    if(user==null || busy || (automatic&&!enabled))return;
    final id=user!;final epoch=StorageService.accountRevision;
    busy=true;error=null;_timer?.cancel();_notify();
    try {
      final state=await _call('status',id,epoch);
      if(state['available']!=true)throw StateError('NOT_AVAILABLE');
      if((state['versions'] as List).isNotEmpty && _prefs!.getString('backup_reviewed_$id')!=state['generation'])throw StateError('RESTORE_FIRST');
      final key=base64Decode(state['key'] as String);
      final cards=<Map<String,dynamic>>[];final objects=<String,Map<String,String>>{};
      var bytes=0;
      for(final raw in StorageService.cardsBox.values.toList()) {
        if(raw is! Map || !BackupCodec.belongsTo(raw,id))continue;
        final c=BackupCodec.portable(raw);
        final image=raw['customImage']?.toString()??'';
        if(image.isNotEmpty) {
          final resolved=await MediaStorageService.resolveManagedImage(image);
          if(resolved==null)throw StateError('IMAGE_MISSING');
          final compressed=await compute(BackupCodec.prepareImage,await File(resolved).readAsBytes());
          _check(id,epoch);
          final object=await BackupCodec.seal(compressed,key,id);
          if(!objects.containsKey(object['id']))bytes+=compressed.length+28;
          objects[object['id']!]=object;c['customImage']=object['id'];
        }
        cards.add(c);
        if(bytes>BackupCodec.limitBytes || objects.length>300)throw StateError('BACKUP_QUOTA');
      }
      cards.sort((a,b)=>a['id'].toString().compareTo(b['id'].toString()));
      final manifest=await BackupCodec.seal(utf8.encode(jsonEncode(BackupCodec.canonical({'schema':1,'cards':cards}))),key,id);
      objects[manifest['id']!]=manifest;
      await _call('upload',id,epoch,{'generation':state['generation'],'manifest':manifest['id'],'objects':objects.values.toList()});
      await _prefs!.setString('backup_reviewed_$id',state['generation']);
      status=await _call('status',id,epoch);status!.remove('key');
    }catch(e){error=_code(e);}
    finally{busy=false;_notify();}
  }
  static Future<BackupRestore?> prepareRestore(String version) async {
    if(user==null||busy)return null;
    final id=user!;final epoch=StorageService.accountRevision;busy=true;error=null;_notify();
    try {
      final response=await _call('restore',id,epoch,{'id':version});
      final key=base64Decode(response['key']);final objects=<String,Uint8List>{};
      var bytes=0;
      for(final raw in response['objects']){
        final plain=await BackupCodec.open(raw,key,id);bytes+=plain.length;
        if(bytes>BackupCodec.limitBytes)throw StateError('INVALID_BACKUP');objects[raw['id']]=plain;
      }
      final manifest=objects.remove(response['manifest']);if(manifest==null)throw StateError('INVALID_BACKUP');
      final cards=BackupCodec.readManifest(manifest,objects.keys.toSet());_check(id,epoch);
      return BackupRestore(id,epoch,response['generation'],cards,objects);
    }catch(e){error=_code(e);return null;}
    finally{busy=false;_notify();}
  }
  static Future<void> applyRestore(BackupRestore restore,{required bool replaceConflicts}) async {
    if(busy)return;busy=true;error=null;_suppress=true;_notify();
    final created=<String>[];
    try {
      _check(restore.user,restore.epoch);
      final docs=await getApplicationDocumentsDirectory();
      final dir=Directory('${docs.path}/card_images');await dir.create(recursive:true);
      final images=<String,String>{};
      for(final entry in restore.images.entries){
        final file=File('${dir.path}/restore_${DateTime.now().microsecondsSinceEpoch}_${entry.key}.png');
        await file.writeAsBytes(entry.value,flush:true);created.add(file.path);images[entry.key]=file.path;
      }
      _check(restore.user,restore.epoch);
      // Stage the merged vault before a single Hive batch write; no deletion of local cards.
      final changes=<dynamic,dynamic>{};
      var next=StorageService.cardsBox.keys.whereType<int>().fold(-1,(a,b)=>a>b?a:b)+1;
      for(final raw in restore.cards) {
        final c={...raw,'backupOwnerId':restore.user,'isShared':false};
        final localKeys=StorageService.cardsBox.keys.where((k){final v=StorageService.cardsBox.get(k);return v is Map && v['id']==c['id'];}).toList();
        if(localKeys.isNotEmpty){
          final local=StorageService.cardsBox.get(localKeys.first) as Map;
          if(CardAccessPolicy.isReceived(local) || (local['backupOwnerId']!=null && local['backupOwnerId']!=restore.user) || !replaceConflicts)continue;
        }
        c['customImage']=images[c['customImage']]??'';
        changes[localKeys.isEmpty?next++:localKeys.first]=c;
      }
      _check(restore.user,restore.epoch);
      await StorageService.cardsBox.putAll(changes);await StorageService.cardsBox.flush();
      _check(restore.user,restore.epoch);
      await _prefs!.setString('backup_reviewed_${restore.user}',restore.generation);
      // Keep images referenced by either old or new cards, delete only unused staged files.
      final used=StorageService.cardsBox.values.whereType<Map>().map((c)=>c['customImage']).toSet();
      for(final file in created)if(!used.contains(file))await File(file).delete();
    }catch(e){error=_code(e);}
    finally{busy=false;_suppress=false;_notify();}
  }
  static Future<void> deleteCloud() async {
    if(user==null||busy)return;final id=user!;final epoch=StorageService.accountRevision;
    busy=true;error=null;_timer?.cancel();_notify();
    try {
      await _prefs!.setBool('backup_enabled_$id',false);
      await _call('delete',id,epoch,{'confirm':'DELETE_BACKUPS'});
      await _prefs!.remove('backup_reviewed_$id');status=await _call('status',id,epoch);status!.remove('key');
    }catch(e){error=_code(e);}
    finally{busy=false;_notify();}
  }
}
class BackupRestore {
 final String user,generation;final int epoch;final List<Map<String,dynamic>> cards;final Map<String,Uint8List> images;
 BackupRestore(this.user,this.epoch,this.generation,this.cards,this.images);
}
