import 'dart:async';
import 'dart:typed_data';
import 'settings_service.dart';
import 'package:paskluis_v1/l10n/l10n.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'locale_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_service.dart';
import 'supabase_service.dart';

class SupportThread {
  final String id;
  final String subject;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupportThread({
    required this.id,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportThread.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now();
    return SupportThread(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? L10n.current.question,
      status: json['status']?.toString() ?? 'open',
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? createdAt,
    );
  }
}

class SupportMessage {
  final String id;
  final String senderId;
  final String senderKind;
  final String? senderName;
  final String message;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.senderId,
    this.senderKind = 'user',
    this.senderName,
    required this.message,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderKind: json['sender_kind']?.toString() ?? 'user',
      senderName: json['sender_name']?.toString(),
      message: json['message']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class SupportConversation {
  final SupportThread thread;
  final List<SupportMessage> messages;

  SupportConversation({required this.thread, required List<SupportMessage> messages})
      : messages = List.unmodifiable([...messages]..sort((a, b) {
          final time = a.createdAt.compareTo(b.createdAt);
          return time != 0 ? time : a.id.compareTo(b.id);
        }));
}

abstract final class SupportService {
  static const _secure = FlutterSecureStorage();
  static final Set<String> _guestThreadIds = {};
  static const _guestTokenKey = 'support_guest_token';
  static final _conversationChanges = StreamController<String>.broadcast();
  static Stream<String> get conversationChanges => _conversationChanges.stream;
  static void notifyConversationChanged(String id) {
    if (id.isNotEmpty) _conversationChanges.add(id);
  }

  static SupabaseClient get _client {
    final client = SupabaseService.client;
    if (client == null) {
      throw  AuthException(
        L10n.current.customerSupportIsCurrentlyUnavailable,
      );
    }
    return client;
  }

  static Future<List<Map<String,dynamic>>> loadIncidents() async {
    try {
      final rows = await _client.from('service_incidents').select('title_nl,body_nl,title_en,body_en').eq('active',true).order('updated_at',ascending:false);
      return rows;
    } catch (_) { return []; }
  }

  static Future<List<SupportThread>> loadThreads() async {
    final guestRows = await _client.rpc('guest_support_threads',
      params: {'p_token': await _guestToken()}) as List;
    final guest = guestRows.map((row) => SupportThread.fromJson(Map<String,dynamic>.from(row))).toList();
    _guestThreadIds..clear()..addAll(guest.map((t) => t.id));
    final own = AccountService.currentUser == null ? <SupportThread>[] :
      (await _client.from('support_threads').select('id, subject, status, created_at, updated_at')
        .eq('user_id', AccountService.currentUser!.id)).map(SupportThread.fromJson).toList();
    final all = {...{for(final t in guest) t.id:t}, ...{for(final t in own) t.id:t}}.values.toList();
    all.sort((a,b) => b.updatedAt.compareTo(a.updatedAt));
    return all;
  }

  static Future<SupportThread> createThread({
    required String subject,
    required String message,
    String? guestName,
    String? guestEmail,
    String category = 'overig',
  }) async {
    final id = await _client.rpc('create_support_conversation', params: {
      'p_token': await _guestToken(), 'p_name': guestName?.trim() ?? '',
      'p_email': guestEmail?.trim() ?? '', 'p_subject': subject.trim(),
      'p_message': message.trim(), 'p_category': category,
      'p_locale': LocaleService.languageCode,
      'p_context': {'platform': Platform.operatingSystem, 'version': SettingsService.appVersion},
    });
    final threads = await loadThreads();
    try { await registerGuestNotifications(); } catch (_) {}
    return threads.firstWhere((t) => t.id == id.toString());
  }

  static Future<SupportConversation> loadConversation(String threadId, {
    SupportThread? fallbackThread,
  }) async {
    final token = await _guestToken();
    try {
      // Authorize this exact conversation on the server, even when opened
      // directly from a notification before the conversation list has loaded.
      final data = Map<String, dynamic>.from(await _client.rpc(
        'support_conversation',
        params: {'p_thread_id': threadId, 'p_token': token},
      ) as Map);
      if (data['is_guest'] == true) _guestThreadIds.add(threadId);
      return SupportConversation(
        thread: SupportThread.fromJson(Map<String, dynamic>.from(data['thread'])),
        messages: (data['messages'] as List).map((row) =>
          SupportMessage.fromJson(Map<String, dynamic>.from(row))).toList(),
      );
    } on PostgrestException catch (error) {
      // Keep the existing app usable during the database rollout. Authorization
      // and network failures must never be mistaken for an older server.
      if (error.code != 'PGRST202' && error.code != '42883') rethrow;
    }
    final guestRows = await _client.rpc('guest_support_messages_v2', params: {
      'p_thread_id': threadId, 'p_token': token,
    }) as List;
    if (guestRows.isNotEmpty) _guestThreadIds.add(threadId);
    final rows = guestRows.isNotEmpty ? guestRows : await _client
        .from('support_messages').select().eq('thread_id', threadId)
        .order('created_at', ascending: true).order('id', ascending: true);
    var thread = fallbackThread;
    // Older servers cannot provide a single snapshot. Keep the current status
    // instead of letting an optional list request hide successfully read replies.
    if (thread == null) {
      thread = (await loadThreads()).where((t) => t.id == threadId).firstOrNull;
    }
    if (thread == null) throw StateError('CONVERSATION_UNAVAILABLE');
    return SupportConversation(thread: thread, messages: rows.map((row) =>
      SupportMessage.fromJson(Map<String, dynamic>.from(row))).toList());
  }

  static Future<void> sendMessage(String threadId, String message) async {
    final user = AccountService.currentUser;
    if (user == null || _guestThreadIds.contains(threadId)) {
      await _client.rpc('send_guest_support_message', params: {
        'p_token': await _guestToken(),
        'p_thread_id': threadId,
        'p_message': message.trim(),
      });
      return;
    }

    await _client.from('support_messages').insert({
      'thread_id': threadId,
      'sender_id': user.id,
      'sender_kind': 'user',
      'message': message.trim(),
    });
  }

  static Future<List<Map<String,dynamic>>> loadAttachments(String threadId) async {
    final response=await _client.functions.invoke('support-attachments',body:{
      'action':'list','thread_id':threadId,'guest_token':await _guestToken(),
    });
    final rows=response.data is Map ? response.data['attachments'] as List? : null;
    return rows?.map((row)=>Map<String,dynamic>.from(row)).toList() ?? [];
  }

  static Future<void> sendScreenshot(String threadId,Uint8List bytes) async {
    if(bytes.length>5*1024*1024)throw StateError('IMAGE_TOO_LARGE');
    final response=await _client.functions.invoke('support-attachments',body:{
      'action':'upload','thread_id':threadId,'guest_token':await _guestToken(),'image':base64Encode(bytes),
    });
    if(response.data is! Map || response.data['uploaded']!=true)throw StateError('UPLOAD_FAILED');
  }

  static Future<void> registerGuestNotifications() async {
    if(_guestThreadIds.isEmpty)return;
    final permission=await FirebaseMessaging.instance.requestPermission();
    if(permission.authorizationStatus==AuthorizationStatus.denied)return;
    final push=await FirebaseMessaging.instance.getToken();
    if(push==null)return;
    await _client.rpc('register_guest_support_push',params:{'p_token':await _guestToken(),'p_push_token':push,'p_locale':LocaleService.languageCode});
  }

  static Future<String> _guestToken() async {
    final preferences = await SharedPreferences.getInstance();
    final secured = await _secure.read(key: _guestTokenKey);
    if (secured != null && secured.length >= 32) return secured;
    final existing = preferences.getString(_guestTokenKey);
    if (existing != null && existing.length >= 32) {
      await _secure.write(key: _guestTokenKey, value: existing);
      await preferences.remove(_guestTokenKey);
      return existing;
    }
    final random = Random.secure();
    final token = base64UrlEncode(
      List<int>.generate(36, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    await _secure.write(key: _guestTokenKey, value: token);
    return token;
  }
}
