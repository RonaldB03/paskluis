import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'device_session_service.dart';
import 'notification_service.dart';
import 'supabase_service.dart';
import 'locale_service.dart';

abstract final class PushNotificationService {
  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _messageSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static Future<void> Function()? _onSharedCardChanged;

  static Future<void> init({
    Future<void> Function()? onSharedCardChanged,
  }) async {
    _onSharedCardChanged = onSharedCardChanged;

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    await _messageSubscription?.cancel();
    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    await _openedSubscription?.cancel();
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _handleOpenedMessage(initialMessage);
    }
  }

  static Future<void> registerForCurrentUser() async {
    final client = SupabaseService.client;
    if (client?.auth.currentUser == null) return;

    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _getTokenWhenReady();
    if (token != null && token.isNotEmpty) {
      await _saveToken(token);
    }

    await _tokenSubscription?.cancel();
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        try {
          await _saveToken(token);
        } catch (_) {
          // A refresh is retried the next time the app starts or resumes.
        }
      },
    );
  }

  static Future<void> unregisterCurrentToken() async {
    final client = SupabaseService.client;
    if (client?.auth.currentUser == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await client!.rpc(
        'unregister_push_token',
        params: {'p_token': token},
      );
    } catch (_) {
      // Signing out must remain possible when Firebase or Supabase is offline.
    } finally {
      await _tokenSubscription?.cancel();
      _tokenSubscription = null;
    }
  }

  static Future<String?> _getTokenWhenReady() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (Platform.isIOS) {
          final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken == null) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            continue;
          }
        }
        return await FirebaseMessaging.instance.getToken();
      } catch (_) {
        if (attempt == 4) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return null;
  }

  static Future<void> _saveToken(String token) async {
    final client = SupabaseService.client;
    if (client?.auth.currentUser == null || token.isEmpty) return;
    await client!.rpc(
      'register_push_token',
      params: {
        'p_token': token,
        'p_platform': Platform.isIOS ? 'ios' : 'android',
        'p_device_id': await DeviceSessionService.deviceId,
      },
    );
    await syncLanguage();
  }

  static Future<void> syncLanguage() async {
    final client = SupabaseService.client;
    if (client?.auth.currentUser == null) return;
    await client!.rpc('set_push_device_locale', params: {
      'p_device_id': await DeviceSessionService.deviceId,
      'p_locale': LocaleService.languageCode,
    });
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final membershipId = message.data['membership_id']?.toString() ?? '';
    if (membershipId.isNotEmpty) {
      NotificationService.markSharedCardPushReceived(membershipId);
    }
    await NotificationService.showRemoteMessage(message);
    final callback = _onSharedCardChanged;
    if (callback != null) await callback();
  }

  static Future<void> _handleOpenedMessage(RemoteMessage message) async {
    final membershipId = message.data['membership_id']?.toString() ?? '';
    if (membershipId.isNotEmpty) {
      NotificationService.markSharedCardPushReceived(membershipId);
    }
    final callback = _onSharedCardChanged;
    if (callback != null) await callback();
  }
}
