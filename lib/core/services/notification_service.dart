import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  static const _lastDigestIdKey = 'last_notified_digest_id';
  static const _notificationsEnabledKey = 'notifications_enabled';

  /// Called once at app startup.
  Future<void> init() async {
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(iOS: iosSettings);
    await _plugin.initialize(initSettings);
  }

  /// Request permission from the user.  Returns true if granted.
  Future<bool> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios == null) return false;
    final granted = await ios.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  /// Show a local notification for a new daily digest.
  Future<void> showDigestNotification(DailyDigest digest) async {
    final prefs = await SharedPreferences.getInstance();

    // Don't notify for the same digest twice
    final lastId = prefs.getString(_lastDigestIdKey);
    if (lastId == digest.id) return;

    // Don't notify if user has disabled
    if (!isEnabled(prefs)) return;

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      0, // single notification slot — always replaces previous
      'Your Daily Digest is Ready',
      digest.overallSummary.length > 100
          ? '${digest.overallSummary.substring(0, 100)}...'
          : digest.overallSummary,
      const NotificationDetails(iOS: iosDetails),
    );

    await prefs.setString(_lastDigestIdKey, digest.id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Check if notifications are enabled in local prefs.
  bool isEnabled(SharedPreferences prefs) {
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  /// Persist the enabled/disabled state locally.
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, value);
    if (!value) await cancelAll();
  }
}
