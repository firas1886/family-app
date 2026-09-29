import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/reminders.dart';

/// Schedules chore reminders as notifications on this phone.
abstract class ReminderScheduler {
  /// Asks the phone for permission to show notifications (Android 13+ shows a
  /// prompt; older versions answer at once). True when notifications are allowed.
  Future<bool> requestPermission();

  /// Replaces every pending chore reminder on this phone with [reminders].
  /// Notifications already showing are left alone.
  Future<void> replaceAll(List<PlannedReminder> reminders);
}

/// [ReminderScheduler] backed by flutter_local_notifications.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({
    required this.channelName,
    required this.bodyFor,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'chores';

  /// The channel's name in the phone's notification settings.
  final String channelName;

  /// The notification's second line, e.g. "Chore for Sara".
  final String Function(PlannedReminder reminder) bodyFor;

  final FlutterLocalNotificationsPlugin _plugin;

  // Shared by every instance: the plugin is a singleton, and a new scheduler is
  // created when the language or the members change, so one replacement must
  // finish before the next starts.
  static Future<void>? _ready;
  static Future<void> _queue = Future<void>.value();

  Future<void> _init() => _ready ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      )
      .then((_) {});

  @override
  Future<bool> requestPermission() async {
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) {
    final next = _queue.then((_) => _replace(reminders));
    _queue = next.catchError((Object error) {
      debugPrint('Scheduling reminders failed: $error');
    });
    return next;
  }

  Future<void> _replace(List<PlannedReminder> reminders) async {
    await _init();
    await _plugin.cancelAllPendingNotifications();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    for (final r in reminders) {
      final at = tz.TZDateTime.from(r.at, tz.local);
      if (!at.isAfter(tz.TZDateTime.now(tz.local))) continue;
      try {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: bodyFor(r),
          scheduledDate: at,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (error) {
        debugPrint('Scheduling reminder ${r.choreId} ${r.date} failed: $error');
      }
    }
  }
}
