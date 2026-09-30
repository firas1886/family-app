import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart';
import 'package:family_app/features/chores/chores_screen.dart';
import 'package:family_app/features/common/member_avatar.dart';
import 'package:family_app/features/family/family_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

// Release 2a.2: a blank name is repaired from the Google account, and parents
// choose the name each member is shown by on chores. testNow is Thursday
// 2026-10-01; u1 is Dad (parent), u2 is Sara (child).

/// The seeded family with colours already saved (so a parent's phone writes
/// no colours) and the given names for u1.
Future<FakeFirebaseFirestore> seedNames({String memberName = 'Dad', String userName = 'Dad'}) async {
  final db = await seedFamily();
  await seedChores(db);
  await db.doc('families/f1/members/u1').update({'name': memberName, 'color': 0});
  await db.doc('families/f1/members/u2').update({'color': 1});
  await db.doc('users/u1').update({'name': userName});
  return db;
}

Future<Map<String, dynamic>> data(FakeFirebaseFirestore db, String path) async => (await db.doc(path).get()).data()!;

/// Counts the writes to one document from now on.
class WriteCounter {
  WriteCounter(FakeFirebaseFirestore db, String path) {
    // The first snapshot is the document as it is now, not a write.
    _sub = db.doc(path).snapshots().listen((_) => _events++);
  }

  late final StreamSubscription<Object?> _sub;
  var _events = 0;

  int get writes => _events == 0 ? 0 : _events - 1;

  Future<void> cancel() => _sub.cancel();
}

Future<void> frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

const tablet = Size(1280, 800);

void useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder inside(Finder parent, String text) =>
    find.descendant(of: parent, matching: find.text(text, skipOffstage: false), skipOffstage: false);

Finder chip(String choreId, String date) => find.byKey(ValueKey('weekChip-$choreId-$date'), skipOffstage: false);

Future<void> showWeek(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byKey(const Key('choresView')), matching: find.text('Week')));
  await settle(tester);
}

void main() {
  group('ProfileSync repairs a blank name', () {
    const home = ProfileSync(child: Text('home'));

    testWidgets('my blank member and user names get the account name, once', (tester) async {
      final db = await seedNames(memberName: '', userName: '');
      final member = WriteCounter(db, 'families/f1/members/u1');
      final user = WriteCounter(db, 'users/u1');
      final other = WriteCounter(db, 'families/f1/members/u2');
      addTearDown(member.cancel);
      addTearDown(user.cancel);
      addTearDown(other.cancel);

      await pumpWithFamily(tester, db: db, authName: 'Firas Alhalabi', child: home);
      await settle(tester);
      expect((await data(db, 'families/f1/members/u1'))['name'], 'Firas Alhalabi');
      expect((await data(db, 'users/u1'))['name'], 'Firas Alhalabi');
      expect((await data(db, 'users/u1'))['familyId'], 'f1'); // merged, not replaced
      expect(member.writes, 1);
      expect(user.writes, 1);
      expect(other.writes, 0);

      // Another member's change rebuilds ProfileSync; nothing more is written.
      await db.doc('families/f1/members/u2').update({'pictureTiles': true});
      await frames(tester, 50);
      expect(member.writes, 1);
      expect(user.writes, 1);
      expect(other.writes, 1); // the test's own change
    });

    testWidgets('a name that is not blank is never overwritten', (tester) async {
      final db = await seedNames();
      final member = WriteCounter(db, 'families/f1/members/u1');
      final user = WriteCounter(db, 'users/u1');
      addTearDown(member.cancel);
      addTearDown(user.cancel);

      await pumpWithFamily(tester, db: db, authName: 'Firas Alhalabi', child: home);
      await frames(tester, 50);
      expect((await data(db, 'families/f1/members/u1'))['name'], 'Dad');
      expect((await data(db, 'users/u1'))['name'], 'Dad');
      expect(member.writes, 0);
      expect(user.writes, 0);
    });

    testWidgets('without an account name nothing is written', (tester) async {
      final db = await seedNames(memberName: '', userName: '');
      final member = WriteCounter(db, 'families/f1/members/u1');
      final user = WriteCounter(db, 'users/u1');
      addTearDown(member.cancel);
      addTearDown(user.cancel);

      await pumpWithFamily(tester, db: db, child: home);
      await frames(tester, 50);
      expect((await data(db, 'families/f1/members/u1'))['name'], '');
      expect((await data(db, 'users/u1'))['name'], '');
      expect(member.writes, 0);
      expect(user.writes, 0);
    });

    testWidgets('a user doc that has a name is not touched', (tester) async {
      final db = await seedNames(memberName: '   ', userName: 'Dad');
      final member = WriteCounter(db, 'families/f1/members/u1');
      final user = WriteCounter(db, 'users/u1');
      addTearDown(member.cancel);
      addTearDown(user.cancel);

      await pumpWithFamily(tester, db: db, authName: 'Firas Alhalabi', child: home);
      await frames(tester, 50);
      expect((await data(db, 'families/f1/members/u1'))['name'], 'Firas Alhalabi');
      expect((await data(db, 'users/u1'))['name'], 'Dad');
      expect(member.writes, 1);
      expect(user.writes, 0);
    });
  });

  group('Family screen: the name shown on chores', () {
    testWidgets('a parent sees an edit button on every member; a child sees none', (tester) async {
      final db = await seedNames();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      for (final uid in ['u1', 'u2']) {
        final button = find.byKey(ValueKey('editName-$uid'));
        expect(button, findsOneWidget);
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }

      await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
      expect(find.byKey(const ValueKey('editName-u1')), findsNothing);
      expect(find.byKey(const ValueKey('editName-u2')), findsNothing);
    });

    testWidgets('saving "Abdul Rahman" sets the display name; the full name stays', (tester) async {
      final db = await seedNames();
      await db.doc('families/f1/members/u2').update({'name': 'Sara Alhalabi'});
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      expect(find.text('Child'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('editName-u2')));
      await settle(tester);
      expect(find.text('Name shown on chores'), findsOneWidget);
      expect(find.text('Leave empty to use the first name'), findsOneWidget);
      // Prefilled with what chores show now: the first name.
      expect(find.widgetWithText(TextField, 'Sara'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('promptField')), '  Abdul Rahman  ');
      await tester.tap(find.byKey(const Key('promptConfirm')));
      await settle(tester);
      final sara = await data(db, 'families/f1/members/u2');
      expect(sara['displayName'], 'Abdul Rahman');
      expect(sara['name'], 'Sara Alhalabi');

      // The full name stays the main line; the chores name is a hint under it.
      expect(find.text('Sara Alhalabi'), findsOneWidget);
      expect(find.text('Child · Abdul Rahman'), findsOneWidget);
      expect(find.widgetWithText(MemberAvatar, 'A'), findsOneWidget);
    });

    testWidgets('saving an empty name clears it back to the first name', (tester) async {
      final db = await seedNames();
      await db.doc('families/f1/members/u2').update({'displayName': 'Soso'});
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      expect(find.text('Child · Soso'), findsOneWidget);

      // Cancel changes nothing.
      await tester.tap(find.byKey(const ValueKey('editName-u2')));
      await settle(tester);
      expect(find.widgetWithText(TextField, 'Soso'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect((await data(db, 'families/f1/members/u2'))['displayName'], 'Soso');

      await tester.tap(find.byKey(const ValueKey('editName-u2')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('promptField')), '   ');
      await tester.tap(find.byKey(const Key('promptConfirm')));
      await settle(tester);
      final sara = await data(db, 'families/f1/members/u2');
      expect(sara.containsKey('displayName'), isFalse);
      expect(sara['name'], 'Sara');
      expect(find.text('Child'), findsOneWidget);
      expect(find.textContaining('Soso'), findsNothing);
    });

    testWidgets('the name field takes at most 40 characters (the rules limit)', (tester) async {
      final db = await seedNames();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      await tester.tap(find.byKey(const ValueKey('editName-u2')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('promptField')), 'x' * 45);
      await tester.tap(find.byKey(const Key('promptConfirm')));
      await settle(tester);
      expect((await data(db, 'families/f1/members/u2'))['displayName'], 'x' * 40);
    });

    testWidgets('a parent names themselves too', (tester) async {
      final db = await seedNames();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      await tester.tap(find.byKey(const ValueKey('editName-u1')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('promptField')), 'Baba');
      await tester.tap(find.byKey(const Key('promptConfirm')));
      await settle(tester);
      expect((await data(db, 'families/f1/members/u1'))['displayName'], 'Baba');
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('fits 320×640 at text x1.3 (${locale.languageCode})', (tester) async {
        useSize(tester, const Size(320, 640));
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final db = await seedNames();
        await db.doc('families/f1/members/u2').update({
          'name': 'سارة عبدالله محمد الأحمد',
          'displayName': 'عبد الرحمن الصغير الحبيب',
        });
        if (locale.languageCode == 'ar') await db.doc('users/u1').update({'language': 'ar'});
        await pumpWithFamily(tester, db: db, locale: locale, child: const FamilyScreen());
        expect(tester.takeException(), isNull);
        for (final uid in ['u1', 'u2']) {
          final button = find.byKey(ValueKey('editName-$uid'));
          expect(button, findsOneWidget);
          expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
          final rect = tester.getRect(button);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
        }

        await tester.tap(find.byKey(const ValueKey('editName-u2')));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('promptField')), findsOneWidget);
      });
    }
  });

  group('chores show the name shown on chores', () {
    testWidgets('the chore sheet, the board header and the week chip use the display name', (tester) async {
      useSize(tester, tablet);
      final db = await seedNames();
      await db.doc('families/f1/members/u2').update({'name': 'Sara Alhalabi', 'displayName': 'Abdul Rahman'});
      await pumpWithFamily(tester, db: db, child: const ChoresScreen());

      final column = find.byKey(const ValueKey('boardColumn-u2'));
      expect(inside(column, 'Abdul Rahman'), findsOneWidget);
      expect(find.descendant(of: column, matching: find.widgetWithText(MemberAvatar, 'A')), findsOneWidget);
      expect(find.text('Sara'), findsNothing);

      await showWeek(tester);
      expect(inside(chip('brush', '2026-10-01'), 'A'), findsOneWidget);

      await tester.tap(find.byKey(const Key('addChore')));
      await settle(tester);
      expect(inside(find.byKey(const ValueKey('choreWho-u2')), 'Abdul Rahman'), findsOneWidget);
      expect(find.text('Sara'), findsNothing);
    });

    testWidgets('a blank name shows "?" until the repair gives the account initial', (tester) async {
      useSize(tester, tablet);
      final db = await seedNames(memberName: '', userName: '');
      const app = ProfileSync(child: ChoresScreen());
      await pumpWithFamily(tester, db: db, child: app);
      await showWeek(tester);
      expect(inside(chip('bins', '2026-10-01'), '?'), findsOneWidget);

      // The same screen, now with the Google account's name available.
      await pumpWithFamily(tester, db: db, authName: 'Firas Alhalabi', child: app);
      await settle(tester);
      expect(inside(chip('bins', '2026-10-01'), '?'), findsNothing);
      expect(inside(chip('bins', '2026-10-01'), 'F'), findsOneWidget);
      expect((await data(db, 'families/f1/members/u1'))['name'], 'Firas Alhalabi');
    });
  });
}
