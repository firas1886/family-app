import 'dart:math';

/// Ids of family members who have no login start with this. A Google sign-in
/// id never contains an underscore, so the two can never collide.
const String noLoginPrefix = 'nl_';

const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
final _shape = RegExp(r'^nl_[A-Za-z0-9]{20}$');

/// A new id for a member without a login: `nl_` plus 20 random letters and digits.
String newNoLoginId([Random? random]) {
  final r = random ?? Random.secure();
  final suffix = List.generate(20, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
  return '$noLoginPrefix$suffix';
}

/// Whether [id] is the id of a member without a login.
bool isNoLoginId(String id) => _shape.hasMatch(id);
