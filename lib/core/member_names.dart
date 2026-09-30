import 'models.dart';
import 'text.dart';

/// The name a member is shown by on chores: the name a parent chose for them
/// ([Member.displayName]), else their first name, else their whole name
/// trimmed (an empty string when that is blank too).
String memberLabel(Member m) {
  final chosen = m.displayName?.trim();
  if (chosen != null && chosen.isNotEmpty) return chosen;
  final first = firstName(m.name);
  if (first.isNotEmpty) return first;
  return m.name.trim();
}

/// The name a Google account gives a member whose name is blank: its display
/// name if it has one, else the part of its email before '@'. Null when
/// neither gives a name.
String? accountDisplayName(String? displayName, String? email) {
  final name = displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  final address = email ?? '';
  final at = address.indexOf('@');
  final local = (at < 0 ? address : address.substring(0, at)).trim();
  return local.isEmpty ? null : local;
}
