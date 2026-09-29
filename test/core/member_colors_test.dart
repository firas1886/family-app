import 'package:family_app/app/palette.dart';
import 'package:family_app/core/member_colors.dart';
import 'package:family_app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

Member member(String uid, {int? color, DateTime? joined}) =>
    Member(uid: uid, name: uid, role: Role.child, color: color, joinedAt: joined);

void main() {
  test('Member reads colour, photo, picture tiles and join time', () {
    final m = Member.fromMap('u2', {
      'name': 'Sara', 'role': 'child', 'color': 3, 'photoUrl': 'https://p/s.png',
      'pictureTiles': true, 'joinedAt': DateTime(2026, 9, 1),
    });
    expect(m.color, 3);
    expect(m.photoUrl, 'https://p/s.png');
    expect(m.pictureTiles, isTrue);
    expect(m.joinedAt, DateTime(2026, 9, 1));

    final old = Member.fromMap('u1', {'name': 'Dad', 'role': 'parent'});
    expect(old.color, isNull);
    expect(old.photoUrl, isNull);
    expect(old.pictureTiles, isFalse);
    expect(old.joinedAt, isNull);
  });

  test('members without a colour get the lowest free index', () {
    final all = [member('a', color: 0), member('b', color: 2), member('c'), member('d')];
    expect(missingColorAssignments(all), {'c': 1, 'd': 3});
  });

  test('assignment follows join order, unknown join times last, then uid', () {
    final all = [
      member('z', joined: DateTime(2026, 1, 3)),
      member('y'),
      member('x', joined: DateTime(2026, 1, 1)),
      member('w'),
    ];
    expect(missingColorAssignments(all), {'x': 0, 'z': 1, 'w': 2, 'y': 3});
  });

  test('everyone coloured means nothing to assign', () {
    expect(missingColorAssignments([member('a', color: 5)]), isEmpty);
    expect(missingColorAssignments(const []), isEmpty);
  });

  test('colours wrap around after the whole palette is used', () {
    final all = [for (var i = 0; i < 10; i++) member('m$i', joined: DateTime(2026, 1, 1 + i))];
    final assigned = missingColorAssignments(all);
    expect([for (var i = 0; i < 10; i++) assigned['m$i']], [0, 1, 2, 3, 4, 5, 6, 7, 0, 1]);
    // Same wrap as the palette itself.
    expect(assigned['m8'], 8 % personPaletteSize);
  });

  test('effectiveColorIndex prefers the saved colour', () {
    final all = [member('a', color: 6), member('b')];
    expect(effectiveColorIndex(all[0], all), 6);
    expect(effectiveColorIndex(all[1], all), 0);
    // A member missing from the list is placed as if they were in it.
    expect(effectiveColorIndex(member('c'), all), 1);
  });
}
