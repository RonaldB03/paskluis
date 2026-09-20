import 'dart:convert';
import 'dart:math';

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
      subject: json['subject']?.toString() ?? 'Vraag',
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
  final String message;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.senderId,
    required this.message,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

abstract final class SupportService {
  static const _guestTokenKey = 'support_guest_token';

  static SupabaseClient get _client {
    final client = SupabaseService.client;
    if (client == null) {
      throw const AuthException(
        'De klantenservice is momenteel niet beschikbaar.',
      );
    }
    return client;
  }

  static Future<List<SupportThread>> loadThreads() async {
    if (AccountService.currentUser == null) {
      final rows = await _client.rpc(
        'guest_support_threads',
        params: {'p_token': await _guestToken()},
      ) as List;
      return rows
          .map((row) => SupportThread.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    }
    final rows = await _client
        .from('support_threads')
        .select('id, subject, status, created_at, updated_at')
        .order('updated_at', ascending: false);
    return rows.map(SupportThread.fromJson).toList();
  }

  static Future<SupportThread> createThread({
    required String subject,
    required String message,
    String? guestName,
    String? guestEmail,
  }) async {
    final user = AccountService.currentUser;
    if (user == null) {
      final id = await _client.rpc('create_guest_support_thread', params: {
        'p_token': await _guestToken(),
        'p_name': guestName?.trim() ?? '',
        'p_email': guestEmail?.trim() ?? '',
        'p_subject': subject.trim(),
        'p_message': message.trim(),
      });
      final threads = await loadThreads();
      return threads.firstWhere(
        (thread) => thread.id == id.toString(),
        orElse: () => SupportThread(
          id: id.toString(),
          subject: subject.trim(),
          status: 'open',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    final threadRow = await _client
        .from('support_threads')
        .insert({'user_id': user.id, 'subject': subject.trim()})
        .select('id, subject, status, created_at, updated_at')
        .single();

    final thread = SupportThread.fromJson(threadRow);
    await sendMessage(thread.id, message);
    return thread;
  }

  static Future<List<SupportMessage>> loadMessages(String threadId) async {
    if (AccountService.currentUser == null) {
      final rows = await _client.rpc(
        'guest_support_messages',
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
        .select('id, sender_id, message, created_at')
        .eq('thread_id', threadId)
        .order('created_at');
    return rows.map(SupportMessage.fromJson).toList();
  }

  static Future<void> sendMessage(String threadId, String message) async {
    final user = AccountService.currentUser;
    if (user == null) {
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
    final existing = preferences.getString(_guestTokenKey);
    if (existing != null && existing.length >= 32) return existing;
    final random = Random.secure();
    final token = base64UrlEncode(
      List<int>.generate(36, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    await preferences.setString(_guestTokenKey, token);
    return token;
  }
}
