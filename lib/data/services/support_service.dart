import 'package:paskluis_v1/l10n/l10n.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
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
  final String message;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.senderId,
    this.senderKind = 'user',
    required this.message,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderKind: json['sender_kind']?.toString() ?? 'user',
      message: json['message']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

abstract final class SupportService {
  static const _secure = FlutterSecureStorage();
  static final Set<String> _guestThreadIds = {};
  static const _guestTokenKey = 'support_guest_token';

  static SupabaseClient get _client {
    final client = SupabaseService.client;
    if (client == null) {
      throw  AuthException(
        L10n.current.customerSupportIsCurrentlyUnavailable,
      );
    }
    return client;
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
      'p_context': {'platform': Platform.operatingSystem, 'version': '1.5.0'},
    });
    final threads = await loadThreads();
    return threads.firstWhere((t) => t.id == id.toString());
  }

  static Future<List<SupportMessage>> loadMessages(String threadId) async {
    if (AccountService.currentUser == null || _guestThreadIds.contains(threadId)) {
      final rows = await _client.rpc(
        'guest_support_messages_v2',
        params: {
          'p_token': await _guestToken(),
          'p_thread_id': threadId,
        },
      ) as List;
      return rows
          .map((row) => SupportMessage.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    }
    final rows = await _client
        .from('support_messages')
        .select('id, sender_id, sender_kind, message, created_at')
        .eq('thread_id', threadId)
        .order('created_at');
    return rows.map(SupportMessage.fromJson).toList();
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
      'message': message.trim(),
    });
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
