import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart';
import 'package:family_app/features/chores/chores_screen.dart';
import 'package:family_app/features/common/member_avatar.dart';
import 'package:family_app/features/family/family_screen.dart';
import 'package:family_app/l10n/app_localizations.dart';
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

/// Opens the "Name shown on chores" dialog for [uid] the way a parent does:
/// the edit button on their own row, or "Edit name" at the top of another
/// member's ⋮ menu.
Future<void> openEditName(WidgetTester tester, String uid) async {
  final menu = find.byKey(ValueKey('memberMenu-$uid'));
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu);
    await settle(tester);
  }
  await tester.tap(find.byKey(ValueKey('editName-$uid')));
  await settle(tester);
}

Future<void> saveName(WidgetTester tester, [String? value]) async {
  if (value != null) await tester.enterText(find.byKey(const Key('promptField')), value);
  await tester.tap(find.byKey(const Key('promptConfirm')));
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
    testWidgets('a parent edits their own name with a button and others\' from the ⋮ menu; a child can\'t',
        (tester) async {
      final db = await seedNames();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      // The parent's own row (it has no ⋮ menu): a visible button.
      final own = find.byKey(const ValueKey('editName-u1'));
      expect(own.hitTestable(), findsOneWidget);
      expect(tester.widget(own), isA<IconButton>());
      expect(tester.getSize(own).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(own).height, greaterThanOrEqualTo(48));

      // Another member's row: no button; "Edit name" is the menu's first item.
      expect(find.byKey(const ValueKey('editName-u2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('memberMenu-u2')));
      await settle(tester);
      final item = find.byKey(const ValueKey('editName-u2'));
      expect(item, findsOneWidget);
      expect(find.descendant(of: item, matching: find.text('Edit name')), findsOneWidget);
      expect(tester.getSize(item).height, greaterThanOrEqualTo(48));
      final items = tester.widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>)).toList();
      expect(items.first.key, const ValueKey('editName-u2'));
      expect(items, hasLength(3)); // Edit name, Make parent, Remove
      await tester.tapAt(const Offset(4, 4)); // close the menu
      await settle(tester);
      expect(find.byKey(const ValueKey('editName-u2')), findsNothing);

      // A child: no button, no menu, so no menu item either.
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
      expect(find.byKey(const ValueKey('editName-u1')), findsNothing);
      expect(find.byKey(const ValueKey('editName-u2')), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('saving "Abdul Rahman" sets the display name; the full name stays', (tester) async {
      final db = await seedNames();
      await db.doc('families/f1/members/u2').update({'name': 'Sara Alhalabi'});
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      expect(find.text('Child'), findsOneWidget);

      // ⋮ menu → Edit name.
      await openEditName(tester, 'u2');
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
      await openEditName(tester, 'u2');
      expect(find.widgetWithText(TextField, 'Soso'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect((await data(db, 'families/f1/members/u2'))['displayName'], 'Soso');

      await openEditName(tester, 'u2');
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
      await openEditName(tester, 'u2');
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
        // u1's button on their own row; u2's item once their ⋮ menu is open.
        for (final uid in ['u1', 'u2']) {
          if (uid == 'u2') {
            await tester.tap(find.byKey(const ValueKey('memberMenu-u2')));
            await settle(tester);
          }
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

    testWidgets('Save without choosing a name writes nothing', (tester) async {
      final db = await seedNames(); // u1 Dad, u2 Sara; no display names yet
      final dad = WriteCounter(db, 'families/f1/members/u1');
      final sara = WriteCounter(db, 'families/f1/members/u2');
      addTearDown(dad.cancel);
      addTearDown(sara.cancel);
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());

      // Opened and saved as it was (the first name).
      await openEditName(tester, 'u2');
      expect(find.widgetWithText(TextField, 'Sara'), findsOneWidget);
      await saveName(tester);
      expect(find.byKey(const Key('promptField')), findsNothing); // closed
      // Only spaces added around it.
      await openEditName(tester, 'u2');
      await saveName(tester, '  Sara ');
      // The parent's own row too.
      await openEditName(tester, 'u1');
      await saveName(tester);
      await frames(tester, 20);

      expect(sara.writes, 0);
      expect(dad.writes, 0);
      expect((await data(db, 'families/f1/members/u2')).containsKey('displayName'), isFalse);
      expect((await data(db, 'families/f1/members/u1')).containsKey('displayName'), isFalse);
    });

    testWidgets('a chosen name can be set back to the first name on purpose', (tester) async {
      final db = await seedNames();
      await db.doc('families/f1/members/u2').update({'displayName': 'Soso'});
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      await openEditName(tester, 'u2');
      await saveName(tester, 'Sara');
      expect((await data(db, 'families/f1/members/u2'))['displayName'], 'Sara');
    });

    testWidgets('more than 40 by String.length is refused in the dialog, with nothing written', (tester) async {
      final db = await seedNames();
      final sara = WriteCounter(db, 'families/f1/members/u2');
      addTearDown(sara.cancel);
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      await openEditName(tester, 'u2');
      expect(find.text('4/40'), findsOneWidget); // "Sara"

      // 25 Arabic letters, each with a haraka (fatha): 25 characters on
      // screen, but 50 UTF-16 code units, more than the rules accept.
      const letters = 'ابتثجحخدذرزسشصضطظعغفقكلمن';
      final marked = [for (final letter in letters.split('')) '$letterَ'].join();
      expect(letters.length, 25);
      expect(marked.length, 50);
      await tester.enterText(find.byKey(const Key('promptField')), marked);
      await settle(tester);
      expect(find.text('50/40'), findsOneWidget);
      expect(find.text('Too long. Please shorten it.'), findsOneWidget);

      await saveName(tester);
      // Still open, the reason under the field; the keyboard's Done is refused too.
      expect(find.byKey(const Key('promptField')), findsOneWidget);
      expect(find.text('Too long. Please shorten it.'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.byKey(const Key('promptField')), findsOneWidget);
      await frames(tester, 20);
      expect(sara.writes, 0);
      expect((await data(db, 'families/f1/members/u2')).containsKey('displayName'), isFalse);

      // Shortened to fit: the error goes and Save works.
      final fits = marked.substring(0, 40);
      await tester.enterText(find.byKey(const Key('promptField')), fits);
      await settle(tester);
      expect(find.text('40/40'), findsOneWidget);
      expect(find.text('Too long. Please shorten it.'), findsNothing);
      await saveName(tester);
      expect(find.byKey(const Key('promptField')), findsNothing);
      expect((await data(db, 'families/f1/members/u2'))['displayName'], fits);
    });

    testWidgets('40 plain letters are accepted', (tester) async {
      final db = await seedNames();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      await openEditName(tester, 'u2');
      final forty = 'Abdulrahma' * 4;
      expect(forty.length, 40);
      await tester.enterText(find.byKey(const Key('promptField')), forty);
      await settle(tester);
      expect(find.text('40/40'), findsOneWidget);
      expect(find.text('Too long. Please shorten it.'), findsNothing);
      await saveName(tester);
      expect(find.byKey(const Key('promptField')), findsNothing);
      expect((await data(db, 'families/f1/members/u2'))['displayName'], forty);
    });
  });

  group('Family screen: names stay readable on small phones', () {
    // Five members with real-world name lengths (13–21 characters). Each has
    // a chosen name, so every subtitle ("Role · chosen") needs the full width.
    const families = {
      'en': [
        ('u1', 'Firas Alhalabi', 'parent', 'Baba Firas'),
        ('u2', 'Sara Alhalabi', 'child', 'Soso'),
        ('u3', 'Rania Alhalabi', 'parent', 'Mama Rania'),
        ('u4', 'Abdul Rahman Alhalabi', 'child', 'Aboudi'),
        ('u5', 'Yousef Alhalabi', 'child', 'Joe'),
      ],
      'ar': [
        ('u1', 'فراس محمد الحلبي', 'parent', 'بابا فراس'),
        ('u2', 'سارة فراس الحلبي', 'child', 'سوسو'),
        ('u3', 'رانيا أحمد الحلبي', 'parent', 'ماما رانيا'),
        ('u4', 'عبد الرحمن الحلبي', 'child', 'عبودي'),
        ('u5', 'يوسف فراس الحلبي', 'child', 'جو'),
      ],
    };

    for (final size in const [Size(320, 640), Size(360, 740)]) {
      for (final lang in ['en', 'ar']) {
        final label = '${size.width.toInt()}×${size.height.toInt()}';
        testWidgets('a parent with 5 members at $label, text x1.3 ($lang): names and subtitles keep 80 dp',
            (tester) async {
          useSize(tester, size);
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final l = lookupAppLocalizations(Locale(lang));
          final db = await seedFamily();
          final members = families[lang]!;
          var color = 0;
          for (final (uid, name, role, chosen) in members) {
            expect(name.length, inInclusiveRange(13, 21));
            await db.doc('families/f1/members/$uid').set({
              'name': name,
              'role': role,
              'color': color++,
              'displayName': chosen,
            });
          }
          await db.doc('users/u1').update({'language': lang});
          await pumpWithFamily(tester, db: db, locale: Locale(lang), child: const FamilyScreen());
          expect(tester.takeException(), isNull); // no overflow

          for (final (uid, name, _, _) in members) {
            final title = tester.getRect(find.text(name));
            expect(title.width, greaterThanOrEqualTo(80), reason: '$uid name title');
          }
          for (final (uid, _, role, chosen) in members) {
            final subtitle = find.text('${role == 'parent' ? l.parent : l.child} · $chosen');
            expect(tester.widget<Text>(subtitle).maxLines, 2);
            expect(tester.getRect(subtitle).width, greaterThanOrEqualTo(80), reason: '$uid subtitle');

            // Two controls at the end: own row edit + colour, others colour + ⋮.
            final controls = uid == 'u1'
                ? [ValueKey('editName-$uid'), ValueKey('memberColor-$uid')]
                : [ValueKey('memberColor-$uid'), ValueKey('memberMenu-$uid')];
            for (final key in controls) {
              final rect = tester.getRect(find.byKey(key));
              expect(rect.left, greaterThanOrEqualTo(0), reason: '$key');
              expect(rect.right, lessThanOrEqualTo(size.width), reason: '$key');
            }
            if (uid != 'u1') expect(find.byKey(ValueKey('editName-$uid')), findsNothing);
          }
          expect(find.byKey(const ValueKey('editName-u1')).hitTestable(), findsOneWidget);
        });
      }
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
