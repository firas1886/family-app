import 'package:family_app/data/reminder_scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the notifications plugin. Its first start fails.
class _PluginThatFailsToStartOnce implements FlutterLocalNotificationsPlugin {
  int starts = 0;
  int clears = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) {
      starts++;
      return starts == 1
          ? Future<bool?>.error(StateError('the plugin could not start'))
          : Future<bool?>.value(true);
    }
    if (invocation.memberName == #cancelAllPendingNotifications) {
      clears++;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  test('after a failed start, the next call starts the plugin again', () async {
    final plugin = _PluginThatFailsToStartOnce();
    final scheduler = LocalReminderScheduler(channelName: 'Chore reminders', bodyFor: (_) => '', plugin: plugin);

    await expectLater(scheduler.replaceAll(const []), throwsStateError);
    expect(plugin.starts, 1);
    expect(plugin.clears, 0);

    await scheduler.replaceAll(const []);
    expect(plugin.starts, 2, reason: 'a failed start is not kept');
    expect(plugin.clears, 1);

    await scheduler.replaceAll(const []);
    expect(plugin.starts, 2, reason: 'a successful start is kept');
    expect(plugin.clears, 2);
  });
}
