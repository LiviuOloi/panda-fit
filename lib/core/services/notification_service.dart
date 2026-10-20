import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String keyMorningEnabled = 'notification_morning_enabled';
  static const String keyMorningHour = 'notification_morning_hour';
  static const String keyMorningMinute = 'notification_morning_minute';

  static const String keyEveningEnabled = 'notification_evening_enabled';
  static const String keyEveningHour = 'notification_evening_hour';
  static const String keyEveningMinute = 'notification_evening_minute';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted =
            await androidImplementation?.requestNotificationsPermission();
        return granted ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return false;
  }

  Future<void> scheduleDailyMorningReminder({
    required int hour,
    required int minute,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyMorningEnabled, enabled);
    await prefs.setInt(keyMorningHour, hour);
    await prefs.setInt(keyMorningMinute, minute);

    if (!_isInitialized) return;

    const id = 101;
    if (!enabled) {
      await _notificationsPlugin.cancel(id: id);
      return;
    }

    try {
      final scheduledDate = _nextInstanceOfTime(hour, minute);
      const androidDetails = AndroidNotificationDetails(
        'pandafit_morning_reminders',
        'Cântărire & Obiceiuri de Dimineață',
        channelDescription: 'Notificări zilnice pentru cântărirea pe stomacul gol',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: 'Cântărirea de dimineață 🐼',
        body: 'Cântărește-te pe stomacul gol pentru a calcula media mobilă pe 7 zile!',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'morning_weigh_in',
      );
    } catch (e) {
      debugPrint('Error scheduling morning notification: $e');
    }
  }

  Future<void> scheduleDailyEveningReminder({
    required int hour,
    required int minute,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyEveningEnabled, enabled);
    await prefs.setInt(keyEveningHour, hour);
    await prefs.setInt(keyEveningMinute, minute);

    if (!_isInitialized) return;

    const id = 102;
    if (!enabled) {
      await _notificationsPlugin.cancel(id: id);
      return;
    }

    try {
      final scheduledDate = _nextInstanceOfTime(hour, minute);
      const androidDetails = AndroidNotificationDetails(
        'pandafit_evening_reminders',
        'Jurnal Zilnic & Antrenamente',
        channelDescription: 'Notificări de seară pentru salvarea meselor și antrenamentelor',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: 'Jurnalul PandaFit 📋',
        body: 'Nu uita să salvezi mesele de azi și antrenamentul pentru menținerea streak-ului!',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'evening_log',
      );
    } catch (e) {
      debugPrint('Error scheduling evening notification: $e');
    }
  }

  Future<void> showTestNotification() async {
    if (!_isInitialized) await initialize();

    try {
      const androidDetails = AndroidNotificationDetails(
        'pandafit_test',
        'Test PandaFit',
        channelDescription: 'Test notificări PandaFit',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _notificationsPlugin.show(
        id: 999,
        title: 'PandaFit Notificare Activă! 🐼',
        body: 'Notificările locale funcționează perfect pe dispozitivul tău.',
        notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
