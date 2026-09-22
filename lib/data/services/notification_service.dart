import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'settings_service.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final Set<String> _sharedCardPushes = <String>{};

  static Future<void> Function(String)? onOpen;

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings, onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if(payload != null) onOpen?.call(payload);
    });
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel('support_replies', 'PasKluis support', importance: Importance.high));
    await android?.createNotificationChannel(const AndroidNotificationChannel('shared_cards', 'PasKluis shared cards', importance: Importance.high));
  }

  static Future<bool> requestPermission() async {
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return android ?? ios ?? true;
  }

  static int _baseId(String cardId) {
    var value = 17;
    for (final unit in cardId.codeUnits) {
      value = ((value * 31) + unit) & 0x1fffffff;
    }
    return (value % 700000000) * 3;
  }

  static Future<void> cancelGiftCard(String cardId) async {
    final base = _baseId(cardId);
    for (var i = 0; i < 3; i++) {
      await _plugin.cancel(base + i);
    }
  }

  static Future<void> showSharedCardReceived(
    Map<dynamic, dynamic> card,
  ) async {
    final id = card['shareMembershipId']?.toString() ??
        card['id']?.toString() ??
        '';
    if (id.isEmpty) return;
    if (_sharedCardPushes.remove(id)) return;
    await requestPermission();

    final name = card['name']?.toString().trim().isNotEmpty == true
        ? card['name'].toString().trim()
        : card['type']?.toString() == 'Cadeaukaart'
            ? L10n.current.aGiftCard
            : L10n.current.aLoyaltyCard;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'shared_cards',
        L10n.current.sharedCards,
        channelDescription: L10n.current.notificationsWhenSomeoneSharesACardWith,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      _baseId('shared:$id'),
      L10n.current.newCardInPaskluis,
      L10n.current.hasBeenSharedWithYou((name).toString()),
      details,
    );
  }

  static void markSharedCardPushReceived(String membershipId) {
    if (membershipId.isNotEmpty) _sharedCardPushes.add(membershipId);
  }

  static Future<void> showRemoteMessage(RemoteMessage message) async {
    final isSharedCard = message.data['event'] == 'shared_card';
    final name = message.data['card_name']?.toString().trim() ?? '';
    final title = isSharedCard ? L10n.current.newCardInPaskluis
        : message.notification?.title ?? L10n.current.newCardInPaskluis;
    final body = isSharedCard
        ? (name.isEmpty ? L10n.current.aCardHasBeenSharedWithYou : L10n.current.hasBeenSharedWithYou(name))
        : message.notification?.body ?? L10n.current.aCardHasBeenSharedWithYou;
    final membershipId = message.data['membership_id']?.toString() ??
        message.messageId ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        isSharedCard ? 'shared_cards' : 'support_replies',
        isSharedCard ? L10n.current.sharedCards : L10n.current.customerSupport,
        channelDescription: L10n.current.notificationsWhenSomeoneSharesACardWith,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      _baseId('push:$membershipId'),
      title,
      body,
      details,
      payload: isSharedCard ? 'shared_card:$membershipId' : 'support_reply:${message.data['thread_id'] ?? ''}',
    );
  }

  static Future<void> syncGiftCard(Map<dynamic, dynamic> card) async {
    if (card['type']?.toString() != 'Cadeaukaart') return;
    final id = card['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await cancelGiftCard(id);

    if (!SettingsService.giftExpiryNotificationsEnabled) return;

    final expiry = DateTime.tryParse(card['expiryDate']?.toString() ?? '');
    final enabled = card['expiryNotificationsEnabled'] == true ||
        card['expiryNotificationsEnabled']?.toString() == 'true';
    final archived = card['isArchived'] == true ||
        card['isArchived']?.toString() == 'true';
    if (expiry == null || !enabled || archived) return;
    await requestPermission();

    final name = card['name']?.toString().trim().isNotEmpty == true
        ? card['name'].toString().trim()
        : L10n.current.yourGiftCard;
    final localExpiry = DateTime(expiry.year, expiry.month, expiry.day, 9);
    final reminders = <({int days, String body})>[
      (days: 30, body: L10n.current.expiresIn30Days((name).toString())),
      (days: 7, body: L10n.current.expiresIn7Days((name).toString())),
      (days: 0, body: L10n.current.expiresToday((name).toString())),
    ];
    final base = _baseId(id);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'gift_card_expiry',
        L10n.current.giftCardExpiryDates,
        channelDescription: L10n.current.remindersBeforeGiftCardsExpire,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    for (var i = 0; i < reminders.length; i++) {
      final reminder = reminders[i];
      final moment = localExpiry.subtract(Duration(days: reminder.days));
      if (!moment.isAfter(DateTime.now())) continue;
      await _plugin.zonedSchedule(
        base + i,
        L10n.current.rememberYourGiftCard,
        reminder.body,
        tz.TZDateTime.from(moment.toUtc(), tz.UTC),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
