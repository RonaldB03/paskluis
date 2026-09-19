import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
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

  static Future<void> syncGiftCard(Map<dynamic, dynamic> card) async {
    if (card['type']?.toString() != 'Cadeaukaart') return;
    final id = card['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await cancelGiftCard(id);

    final expiry = DateTime.tryParse(card['expiryDate']?.toString() ?? '');
    final enabled = card['expiryNotificationsEnabled'] == true ||
        card['expiryNotificationsEnabled']?.toString() == 'true';
    final archived = card['isArchived'] == true ||
        card['isArchived']?.toString() == 'true';
    if (expiry == null || !enabled || archived) return;
    await requestPermission();

    final name = card['name']?.toString().trim().isNotEmpty == true
        ? card['name'].toString().trim()
        : 'Je cadeaukaart';
    final localExpiry = DateTime(expiry.year, expiry.month, expiry.day, 9);
    final reminders = <({int days, String body})>[
      (days: 30, body: '$name verloopt over 30 dagen.'),
      (days: 7, body: '$name verloopt over 7 dagen.'),
      (days: 0, body: '$name verloopt vandaag.'),
    ];
    final base = _baseId(id);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'gift_card_expiry',
        'Vervaldatums cadeaukaarten',
        channelDescription: 'Herinneringen voordat cadeaukaarten verlopen',
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
        'Cadeaukaart niet vergeten',
        reminder.body,
        tz.TZDateTime.from(moment.toUtc(), tz.UTC),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
