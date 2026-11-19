import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Local notifications (Spark-plan approach, design doc 4.2): shown from
/// Firestore listeners while the app is open or in the background.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool _enabled = true;
  bool get enabled => _enabled;

  /// Turned off from the Settings screen; this also cancels the daily
  /// "close shop" reminder (it is scheduled again at the next login).
  set enabled(bool value) {
    _enabled = value;
    if (!value && _ready) unawaited(_plugin.cancelAllPendingNotifications());
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'smartshop_alerts',
      'SmartShop alerts',
      channelDescription: 'Order ready, Save Food deals and stock alerts',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!_supported) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Android 13+ asks the user once.
  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Shows the notification every day at [hour]:00, even when the app is
  /// closed (Android alarm; needs the receivers in AndroidManifest.xml).
  /// Turning notifications off in Settings cancels it.
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    if (!enabled) return cancel(id);
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        // The same moment in UTC; Malaysia has no daylight saving, so it
        // stays at [hour]:00 local time every day.
        scheduledDate: tz.TZDateTime.from(next, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Could not schedule the reminder: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id: id);
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_ready || !enabled) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }
}
