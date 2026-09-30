import 'package:family_app/core/member_names.dart';
import 'package:family_app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

// Release 2a.2: the name a member is shown by on chores, and the name the
// Google account gives a member whose name is blank.

Member member(String name, {String? displayName}) =>
    Member(uid: 'u1', name: name, role: Role.child, displayName: displayName);

void main() {
  group('memberLabel', () {
    test('a display name wins over the first name', () {
      expect(memberLabel(member('Abdulrahman Alhalabi', displayName: 'Abdul Rahman')), 'Abdul Rahman');
      expect(memberLabel(member('Sara', displayName: '  Soso  ')), 'Soso');
    });

    test('a blank or whitespace display name falls back to the first name', () {
      expect(memberLabel(member('Sara Alhalabi')), 'Sara');
      expect(memberLabel(member('Sara Alhalabi', displayName: '')), 'Sara');
      expect(memberLabel(member('Sara Alhalabi', displayName: '   ')), 'Sara');
      expect(memberLabel(member('Sara Alhalabi', displayName: '  \t ')), 'Sara');
    });

    test('a blank name and no display name give an empty label', () {
      expect(memberLabel(member('')), '');
      expect(memberLabel(member('   ')), '');
      expect(memberLabel(member(' ', displayName: ' ')), '');
    });

    test('Arabic names', () {
      expect(memberLabel(member('محمد علي')), 'محمد');
      expect(memberLabel(member('عبد الرحمن الحلبي', displayName: 'عبد الرحمن')), 'عبد الرحمن');
      expect(memberLabel(member('سارة', displayName: '  ')), 'سارة');
    });
  });

  group('Member.displayName', () {
    test('is read when it is a non-blank string', () {
      final m = Member.fromMap('u2', {'name': 'Sara', 'role': 'child', 'displayName': 'Soso'});
      expect(m.displayName, 'Soso');
      expect(Member.fromMap('u2', {'name': 'Sara', 'role': 'child'}).displayName, isNull);
    });

    test('a value of the wrong type or a blank one reads as null', () {
      Member read(Object? value) =>
          Member.fromMap('u2', {'name': 'Sara', 'role': 'child', 'displayName': value});
      for (final bad in <Object?>[42, true, ['A'], {'a': 1}, '', '   ', null]) {
        expect(read(bad).displayName, isNull, reason: 'displayName $bad');
      }
      expect(memberLabel(read(42)), 'Sara');
    });
  });

  group('accountDisplayName', () {
    test("the account's display name, trimmed", () {
      expect(accountDisplayName('Firas Alhalabi', 'firas@example.com'), 'Firas Alhalabi');
      expect(accountDisplayName('  فراس الحلبي ', null), 'فراس الحلبي');
    });

    test('otherwise the part of the email before @', () {
      expect(accountDisplayName(null, 'firas.h@example.com'), 'firas.h');
      expect(accountDisplayName('', 'firas@example.com'), 'firas');
      expect(accountDisplayName('   ', 'firas@example.com'), 'firas');
      expect(accountDisplayName(null, 'noatsign'), 'noatsign');
    });

    test('nothing when neither gives a name', () {
      expect(accountDisplayName(null, null), isNull);
      expect(accountDisplayName('', ''), isNull);
      expect(accountDisplayName('  ', '@example.com'), isNull);
      expect(accountDisplayName(null, '  @example.com'), isNull);
    });
  });
}
