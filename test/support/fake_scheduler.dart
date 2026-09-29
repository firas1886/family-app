import 'package:family_app/core/reminders.dart';
import 'package:family_app/data/reminder_scheduler.dart';

/// Records what the app asked to schedule, instead of touching the phone.
class FakeReminderScheduler implements ReminderScheduler {
  /// The reminders from the latest [replaceAll].
  List<PlannedReminder> scheduled = [];

  /// What [requestPermission] answers.
  bool permission = true;

  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    scheduled = List.of(reminders);
  }
}
