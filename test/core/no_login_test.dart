import 'dart:math';

import 'package:family_app/core/models.dart';
import 'package:family_app/core/no_login.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new ids look like nl_ plus 20 letters or digits', () {
    final id = newNoLoginId(Random(1));
    expect(id, matches(RegExp(r'^nl_[A-Za-z0-9]{20}$')));
    expect(isNoLoginId(id), isTrue);
  });

  test('ids differ from one call to the next', () {
    final random = Random(7);
    final ids = {for (var i = 0; i < 500; i++) newNoLoginId(random)};
    expect(ids, hasLength(500));
  });

  test('a Google sign-in id is never a no-login id', () {
    expect(isNoLoginId('Xy3kP9aQ2bR7sT1uV5wZ8cD4eF6g'), isFalse);
    expect(isNoLoginId('nl_short'), isFalse);
    expect(isNoLoginId('nl_ABCDEFGHIJKLMNOPQRS!'), isFalse);
  });

  test('Member.fromMap reads noLogin and treats anything else as false', () {
    expect(Member.fromMap('nl_x', {'name': 'Yusuf', 'role': 'child', 'noLogin': true}).noLogin, isTrue);
    expect(Member.fromMap('u1', {'name': 'Dad', 'role': 'parent'}).noLogin, isFalse);
    expect(Member.fromMap('u2', {'name': 'Sara', 'noLogin': 'yes'}).noLogin, isFalse);
  });
}
