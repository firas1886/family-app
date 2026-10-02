import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/member_colors.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/core/no_login.dart';
import 'package:family_app/features/chores/chore_card.dart';
import 'package:family_app/features/chores/chores_screen.dart';
import 'package:family_app/features/chores/week_board.dart';
import 'package:family_app/features/common/member_avatar.dart';
import 'package:family_app/features/family/family_screen.dart';
import 'package:family_app/features/today/today_screen.dart';
import 'package:family_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

// Release 2a.3 Task 2: family members who have no login. testNow is Thursday
// 2026-10-01; u1 is Dad (parent), u2 is Sara (child), and Yusuf is a member
// without a login (a child), added by Dad.

const yusuf = 'nl_YUSUFabcdefghijklmno';
const tablet = Size(1280, 800);
const choresDate = '2026-10-01';

/// The seeded family with chores and Yusuf. With [brushToYusuf] the seeded
/// `brush` chore (daily, due today) is Yusuf's instead of Sara's.
Future<FakeFirebaseFirestore> seeded({bool brushToYusuf = false}) async {
  final db = await seedFamily();
  await seedChores(db);
  await seedNoLoginMember(db);
  if (brushToYusuf) await db.doc('families/f1/chores/brush').update({'assignee': yusuf});
  return db;
}

Future<Map<String, dynamic>> data(FakeFirebaseFirestore db, String path) async => (await db.doc(path).get()).data()!;

Future<bool> exists(FakeFirebaseFirestore db, String path) async => (await db.doc(path).get()).exists;

/// The ids of every member without a login in family f1.
Future<List<String>> noLoginIds(FakeFirebaseFirestore db) async => [
      for (final d in (await db.collection('families/f1/members').get()).docs)
        if (d.id.startsWith('nl_')) d.id,
    ];

Future<int> doneCount(FakeFirebaseFirestore db) async => (await db.collection('families/f1/choreDone').get()).size;

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

void useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void useTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Finder byKey(Key key) => find.byKey(key, skipOffstage: false);

Finder inside(Finder parent, String text) =>
    find.descendant(of: parent, matching: find.text(text, skipOffstage: false), skipOffstage: false);

Finder chip(String choreId, String date) => byKey(ValueKey('weekChip-$choreId-$date'));

ChoreCard cardOf(WidgetTester tester, String choreId) => tester.widget<ChoreCard>(byKey(ValueKey('chore-$choreId')));

/// Scrolls the widget into view, then taps it.
Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(byKey(key));
  await settle(tester);
  await tester.tap(find.byKey(key));
  await settle(tester);
}

/// Scrolls the screen's list (from its top) until [target] has been built and
/// is on screen.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(target, 120, scrollable: scrollable);
  await settle(tester);
}

/// The Family screen row of a no-login member (found by his tag).
Finder rowOf(String uid) =>
    find.ancestor(of: find.byKey(ValueKey('noLoginTag-$uid'), skipOffstage: false), matching: find.byType(ListTile));

Future<void> showWeek(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byKey(const Key('choresView')), matching: find.text('Week')));
  await settle(tester);
}

Future<void> showEveryone(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byKey(const Key('choresScope')), matching: find.text('Everyone')));
  await settle(tester);
}

/// Opens a member's ⋮ menu on the Family screen.
Future<void> openMenu(WidgetTester tester, String uid) async {
  await tester.tap(find.byKey(ValueKey('memberMenu-$uid')));
  await settle(tester);
}

/// Dad opens "Edit name" from a member's ⋮ menu.
Future<void> openEditName(WidgetTester tester, String uid) async {
  await openMenu(tester, uid);
  await tester.tap(find.byKey(ValueKey('editName-$uid')));
  await settle(tester);
}

Future<void> saveName(WidgetTester tester, [String? value]) async {
  if (value != null) await tester.enterText(find.byKey(const Key('promptField')), value);
  await tester.tap(find.byKey(const Key('promptConfirm')));
  await settle(tester);
}

void main() {
  group('Family screen: add', () {
    testWidgets('a parent adds a member without a login', (tester) async {
      final db = await seedFamily();
      final before = [
        for (final d in (await db.collection('families/f1/members').get()).docs) Member.fromMap(d.id, d.data()),
      ];
      final expectedColor = nextFreeColor(before);
      expect(expectedColor, 2); // Dad 0 and Sara 1 are taken
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());

      final button = find.byKey(const Key('addNoLoginMember'));
      await tester.ensureVisible(button);
      await settle(tester);
      expect(inside(button, 'Add member without login'), findsOneWidget);
      await tester.tap(button);
      await settle(tester);
      expect(find.byKey(const Key('promptField')), findsOneWidget);
      expect(find.text('Add member without login'), findsNWidgets(2)); // the button and the dialog title
      await saveName(tester, '  Yusuf ');

      final ids = await noLoginIds(db);
      expect(ids, hasLength(1));
      final id = ids.single;
      expect(isNoLoginId(id), isTrue);
      final doc = await data(db, 'families/f1/members/$id');
      expect(doc['name'], 'Yusuf');
      expect(doc['noLogin'], isTrue);
      expect(doc['role'], 'child');
      expect(doc['createdBy'], 'u1');
      expect(doc['color'], expectedColor);
      expect(doc['pictureTiles'], isFalse);
      expect(doc['joinedAt'], isNotNull);
      expect(find.byKey(const Key('promptField')), findsNothing); // closed

      // The new row shows up with the tag.
      expect(find.text('Yusuf'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(ValueKey('noLoginTag-$id'))).data, 'No login');
    });

    testWidgets('a blank name, or Cancel, writes nothing', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());

      await tapKey(tester, const Key('addNoLoginMember'));
      await saveName(tester, '   ');
      expect(find.byKey(const Key('promptField')), findsNothing); // closed
      expect(await noLoginIds(db), isEmpty);

      await tapKey(tester, const Key('addNoLoginMember'));
      await saveName(tester); // nothing typed
      expect(await noLoginIds(db), isEmpty);

      await tapKey(tester, const Key('addNoLoginMember'));
      await tester.enterText(find.byKey(const Key('promptField')), 'Yusuf');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.byKey(const Key('promptField')), findsNothing);
      expect(await noLoginIds(db), isEmpty);
    });

    testWidgets('the name field takes at most 80 characters (the rules limit)', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      await tapKey(tester, const Key('addNoLoginMember'));
      expect(tester.widget<TextField>(find.byKey(const Key('promptField'))).maxLength, 80);
      await saveName(tester, 'x' * 90);
      final id = (await noLoginIds(db)).single;
      expect((await data(db, 'families/f1/members/$id'))['name'], 'x' * 80);
    });

    testWidgets('a child cannot add one', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
      expect(find.byKey(const Key('addNoLoginMember'), skipOffstage: false), findsNothing);
      expect(find.text('Add member without login', skipOffstage: false), findsNothing);
    });

    testWidgets('the new strings have the agreed English and Arabic text', (tester) async {
      final en = lookupAppLocalizations(const Locale('en'));
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(en.addNoLoginMember, 'Add member without login');
      expect(en.noLoginTag, 'No login');
      expect(ar.addNoLoginMember, 'إضافة فرد بدون حساب');
      expect(ar.noLoginTag, 'بدون حساب');
    });
  });

  group('Family screen: the row', () {
    testWidgets('the row shows No login; its menu has Edit name and Remove but no Make parent', (tester) async {
      final db = await seeded();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());

      final tag = find.byKey(const ValueKey('noLoginTag-$yusuf'));
      expect(tag, findsOneWidget);
      expect(tag.hitTestable(), findsOneWidget);
      expect(tester.widget<Text>(tag).data, 'No login');
      expect(tester.widget<Text>(tag).maxLines, 2);
      expect(tester.widget<Text>(tag).overflow, TextOverflow.ellipsis);
      // Other members keep their role text, with no tag.
      expect(find.text('Parent'), findsOneWidget); // Dad
      expect(find.text('Child'), findsOneWidget); // Sara; Yusuf shows No login instead
      expect(find.byKey(const ValueKey('noLoginTag-u1')), findsNothing);
      expect(find.byKey(const ValueKey('noLoginTag-u2')), findsNothing);

      await openMenu(tester, yusuf);
      final item = find.byKey(const ValueKey('editName-$yusuf'));
      expect(inside(item, 'Edit name'), findsOneWidget);
      expect(find.text('Remove from family'), findsOneWidget);
      expect(find.text('Make parent'), findsNothing);
      expect(find.text('Make child'), findsNothing);
      expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));
      expect(tester.getSize(item).height, greaterThanOrEqualTo(48));
      // The first item stays Edit name, as for members with a login.
      expect(
        tester.widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>)).first.key,
        const ValueKey('editName-$yusuf'),
      );
      await tester.tapAt(const Offset(4, 4)); // close the menu
      await settle(tester);

      // A member with a login keeps all three items.
      await openMenu(tester, 'u2');
      expect(find.byType(PopupMenuItem<String>), findsNWidgets(3));
      expect(find.text('Make parent'), findsOneWidget);
    });

    testWidgets('a name chosen for chores is still shown after No login', (tester) async {
      final db = await seeded();
      await db.doc('families/f1/members/$yusuf').update({'displayName': 'Yusi'});
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      final tag = find.byKey(const ValueKey('noLoginTag-$yusuf'));
      expect(tester.widget<Text>(tag).data, 'No login · Yusi');
      expect(find.text('Yusuf'), findsOneWidget); // the full name stays the title
      expect(find.widgetWithText(MemberAvatar, 'Y'), findsOneWidget);
    });

    testWidgets('colour and picture tiles work for a no-login member, as for any child', (tester) async {
      final db = await seeded();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());

      expect(find.byKey(const ValueKey('memberColor-$yusuf')), findsOneWidget);
      await tapKey(tester, const ValueKey('pictureTiles-$yusuf'));
      expect((await data(db, 'families/f1/members/$yusuf'))['pictureTiles'], isTrue);

      await tapKey(tester, const ValueKey('memberColor-$yusuf'));
      await tester.tap(find.byKey(const ValueKey('paletteColor-3')));
      await settle(tester);
      expect((await data(db, 'families/f1/members/$yusuf'))['color'], 3);
    });

    testWidgets('children see a no-login member but get no controls', (tester) async {
      final db = await seeded();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
      expect(find.text('Yusuf'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('noLoginTag-$yusuf'))).data, 'No login');
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byKey(const ValueKey('editName-$yusuf'), skipOffstage: false), findsNothing);
      expect(find.byKey(const ValueKey('pictureTiles-$yusuf'), skipOffstage: false), findsNothing);
      expect(find.byKey(const Key('addNoLoginMember'), skipOffstage: false), findsNothing);
    });
  });

  group('Family screen: edit name and remove', () {
    testWidgets('Edit name on a no-login member changes the name itself', (tester) async {
      final db = await seeded();
      final doc = WriteCounter(db, 'families/f1/members/$yusuf');
      addTearDown(doc.cancel);
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());

      await openEditName(tester, yusuf);
      // The real name's dialog, not the "Name shown on chores" one.
      expect(find.text('Edit name'), findsOneWidget);
      expect(find.text('Name shown on chores'), findsNothing);
      expect(find.text('Leave empty to use the first name'), findsNothing);
      final field = tester.widget<TextField>(find.byKey(const Key('promptField')));
      expect(field.decoration!.labelText, 'Name');
      expect(field.decoration!.helperText, isNull);
      expect(field.maxLength, 80);
      expect(field.controller!.text, 'Yusuf');

      await saveName(tester, '  Yusuf Ali  ');
      final saved = await data(db, 'families/f1/members/$yusuf');
      expect(saved['name'], 'Yusuf Ali');
      expect(saved.containsKey('displayName'), isFalse);
      expect(doc.writes, 1);
      expect(find.text('Yusuf Ali'), findsOneWidget);
    });

    testWidgets('a blank name, or Cancel, writes nothing', (tester) async {
      final db = await seeded();
      final doc = WriteCounter(db, 'families/f1/members/$yusuf');
      addTearDown(doc.cancel);
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());

      await openEditName(tester, yusuf);
      await saveName(tester, '   ');
      expect(find.byKey(const Key('promptField')), findsNothing); // closed

      await openEditName(tester, yusuf);
      await tester.enterText(find.byKey(const Key('promptField')), 'Someone else');
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      await frames(tester, 20);
      expect(doc.writes, 0);
      final unchanged = await data(db, 'families/f1/members/$yusuf');
      expect(unchanged['name'], 'Yusuf');
      expect(unchanged.containsKey('displayName'), isFalse);
    });

    testWidgets('the name field takes at most 80 characters (the rules limit)', (tester) async {
      final db = await seeded();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      await openEditName(tester, yusuf);
      expect(find.text('5/80'), findsOneWidget); // "Yusuf"
      await saveName(tester, 'y' * 90);
      expect((await data(db, 'families/f1/members/$yusuf'))['name'], 'y' * 80);
    });

    testWidgets('Remove asks first, then removes', (tester) async {
      final db = await seeded();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());

      await openMenu(tester, yusuf);
      await tester.tap(find.text('Remove from family'));
      await settle(tester);
      expect(find.text('Remove Yusuf from the family?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(await exists(db, 'families/f1/members/$yusuf'), isTrue);
      expect(find.text('Yusuf'), findsOneWidget);

      await openMenu(tester, yusuf);
      await tester.tap(find.text('Remove from family'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirmYes')));
      await settle(tester);
      expect(await exists(db, 'families/f1/members/$yusuf'), isFalse);
      expect(find.text('Yusuf'), findsNothing);
      expect(await exists(db, 'families/f1/members/u2'), isTrue); // nobody else is touched
    });
  });

  group('a no-login member is a child on the chores screens', () {
    testWidgets('appears in the chore sheet "Who"', (tester) async {
      final db = await seeded(brushToYusuf: true);
      await pumpWithFamily(tester, db: db, child: const ChoresScreen());
      await tester.tap(find.byKey(const Key('addChore')));
      await settle(tester);
      expect(inside(find.byKey(const ValueKey('choreWho-$yusuf')), 'Yusuf'), findsOneWidget);
    });

    testWidgets('appears as a column on the board', (tester) async {
      useSize(tester, tablet);
      final db = await seeded(brushToYusuf: true);
      await pumpWithFamily(tester, db: db, child: const ChoresScreen());

      final column = find.byKey(const ValueKey('boardColumn-$yusuf'));
      expect(column, findsOneWidget);
      expect(inside(column, 'Yusuf'), findsOneWidget);
      expect(inside(column, '✓ 0/1'), findsOneWidget);
      expect(find.descendant(of: column, matching: find.widgetWithText(MemberAvatar, 'Y')), findsOneWidget);
      expect(find.descendant(of: column, matching: find.byKey(const ValueKey('chore-brush'))), findsOneWidget);
      // Sara no longer has the chore.
      expect(find.descendant(of: find.byKey(const ValueKey('boardColumn-u2')), matching: find.byKey(const ValueKey('chore-brush'))), findsNothing);
    });

    testWidgets('appears in the week view with his initial', (tester) async {
      useSize(tester, tablet);
      final db = await seeded(brushToYusuf: true);
      await pumpWithFamily(tester, db: db, child: const ChoresScreen());
      await showWeek(tester);
      expect(chip('brush', choresDate), findsOneWidget);
      expect(inside(chip('brush', choresDate), 'Y'), findsOneWidget);
    });

    testWidgets('appears on Today with his progress ring', (tester) async {
      final db = await seeded(brushToYusuf: true);
      await pumpWithFamily(tester, db: db, child: const TodayScreen());
      final member = find.byKey(const ValueKey('todayMember-$yusuf'));
      expect(member, findsOneWidget);
      expect(inside(member, '✓ 0/1'), findsOneWidget);
      final ring = tester.widget<CircularProgressIndicator>(
        find.descendant(of: member, matching: find.byType(CircularProgressIndicator)),
      );
      expect(ring.value, 0.0);
      expect(find.descendant(of: member, matching: find.widgetWithText(MemberAvatar, 'Y')), findsOneWidget);
    });

    testWidgets('is listed in who-did-it for an Anyone chore', (tester) async {
      final db = await seeded();
      await pumpWithFamily(tester, db: db, child: const ChoresScreen());

      await tapKey(tester, const ValueKey('tick-plants')); // Anyone, late since 26 Sep
      expect(find.text('Who did it?'), findsOneWidget);
      final option = find.byKey(const ValueKey('whoDid-$yusuf'));
      expect(inside(option, 'Yusuf'), findsOneWidget);
      await tester.tap(option);
      await settle(tester);

      final done = await data(db, 'families/f1/choreDone/plants_2026-09-26');
      expect(done['doneBy'], yusuf);
      expect(done['doneByName'], 'Yusuf');
    });
  });

  group('who can tick his chores', () {
    /// Yusuf's chores: `brush` (daily) and a one-time `tidy` that is late.
    Future<FakeFirebaseFirestore> yusufsChores() async {
      final db = await seeded(brushToYusuf: true);
      await db.doc('families/f1/chores/tidy').set({
        ...const Chore(id: 'tidy', title: 'Tidy room', assignee: yusuf, startDate: '2026-09-28', createdBy: 'u1')
            .toMap(),
        'createdAt': DateTime(2026, 9, 1),
      });
      return db;
    }

    // Only the seeded record (Sara's tick of brush on 30 Sep) may exist.
    Future<void> expectNothingWritten(FakeFirebaseFirestore db) async {
      expect(await doneCount(db), 1);
      expect(await exists(db, 'families/f1/choreDone/brush_2026-09-30'), isTrue);
      expect(await exists(db, 'families/f1/choreDone/brush_$choresDate'), isFalse);
    }

    testWidgets('a child cannot tick them on the phone Chores tab, nor on the late strip', (tester) async {
      final db = await yusufsChores();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
      await showEveryone(tester);

      expect(cardOf(tester, 'brush').onToggle, isNull);
      await tapKey(tester, const ValueKey('tick-brush'));
      expect(find.text('Brush teeth done'), findsNothing);

      final late = tester.widget<ChoreCard>(byKey(const ValueKey('lateChore-tidy')));
      expect(late.onToggle, isNull);
      await tapKey(tester, const ValueKey('tick-tidy'));
      expect(find.text('Tidy room done'), findsNothing);

      await expectNothingWritten(db);
      expect(await exists(db, 'families/f1/choreDone/tidy_2026-09-28'), isFalse);
      expect(await exists(db, 'families/f1/choreDone/tidy_$choresDate'), isFalse);
    });

    testWidgets('a child cannot tick them on the board', (tester) async {
      useSize(tester, tablet);
      final db = await yusufsChores();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
      await showEveryone(tester);

      final column = find.byKey(const ValueKey('boardColumn-$yusuf'));
      expect(find.descendant(of: column, matching: find.byKey(const ValueKey('chore-brush'))), findsOneWidget);
      expect(cardOf(tester, 'brush').onToggle, isNull);
      await tapKey(tester, const ValueKey('tick-brush'));
      await tester.tap(find.descendant(of: column, matching: find.byKey(const ValueKey('chore-brush'))));
      await settle(tester);
      await expectNothingWritten(db);
    });

    testWidgets('a child cannot tick them in the week view', (tester) async {
      useSize(tester, tablet);
      final db = await yusufsChores();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
      await showEveryone(tester);
      await showWeek(tester);

      expect(inside(chip('brush', choresDate), 'Y'), findsOneWidget);
      expect(tester.widget<WeekChip>(chip('brush', choresDate)).onTap, isNull);
      await tester.tap(chip('brush', choresDate));
      await settle(tester);
      await expectNothingWritten(db);
    });

    testWidgets('a child cannot tick them on Today', (tester) async {
      final db = await yusufsChores();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const TodayScreen());

      // Yusuf's progress shows, but his chore is not among "Your chores"...
      final member = find.byKey(const ValueKey('todayMember-$yusuf'));
      expect(inside(member, '✓ 0/1'), findsOneWidget);
      expect(byKey(const ValueKey('chore-brush')), findsNothing);
      expect(byKey(const ValueKey('tick-brush')), findsNothing);
      // ...nor on the late strip, which lists only a child's own and Anyone chores.
      expect(byKey(const ValueKey('lateChore-tidy')), findsNothing);
      await tester.tap(member);
      await settle(tester);
      await expectNothingWritten(db);
    });

    testWidgets('a parent ticks his chore, and it records him, as for any child', (tester) async {
      final db = await seeded(brushToYusuf: true);
      await pumpWithFamily(tester, db: db, child: const ChoresScreen());
      expect(cardOf(tester, 'brush').onToggle, isNotNull);

      await tapKey(tester, const ValueKey('tick-brush'));
      final done = await data(db, 'families/f1/choreDone/brush_$choresDate');
      expect(done['choreId'], 'brush');
      expect(done['choreTitle'], 'Brush teeth');
      // Like Sara's chore ticked by Dad ("a parent ticking a child's chore
      // records the child"), the record names the person it is for.
      expect(done['doneBy'], yusuf);
      expect(done['doneByName'], 'Yusuf');
      expect(done['assignee'], yusuf);
      expect(cardOf(tester, 'brush').status.isDone, isTrue);
    });
  });

  group('removing a no-login member', () {
    testWidgets('moves their chores to Former member; past ticks stay', (tester) async {
      useSize(tester, const Size(500, 2400)); // tall: every section is built
      final db = await seeded(brushToYusuf: true);
      await pumpWithFamily(tester, db: db, child: const ChoresScreen());
      expect(inside(find.byKey(const ValueKey('choreSection-$yusuf')), 'Brush teeth'), findsOneWidget);
      expect(byKey(const ValueKey('choreSection-former')), findsNothing);

      await db.doc('families/f1/members/$yusuf').delete();
      await settle(tester);

      expect(byKey(const ValueKey('choreSection-$yusuf')), findsNothing);
      final former = byKey(const ValueKey('choreSection-former'));
      expect(former, findsOneWidget);
      expect(inside(former, 'Former member'), findsOneWidget);
      expect(inside(former, 'Brush teeth'), findsOneWidget);
      expect(find.descendant(of: former, matching: find.byKey(const ValueKey('chore-brush'))), findsOneWidget);
      // The history is untouched.
      expect(await exists(db, 'families/f1/choreDone/brush_2026-09-30'), isTrue);
      expect(await exists(db, 'families/f1/chores/brush'), isTrue);
    });
  });

  group('Arabic no-login member on a small phone', () {
    const arabicName = 'يوسف علي';
    const longArabicId = 'nl_LONGNAMEabcdefghijkl';
    const longArabicName = 'يوسف عبدالله محمد الأحمد';
    const longArabicChosen = 'عبد الرحمن الصغير الحبيب';

    for (final size in const [Size(320, 640), Size(360, 740)]) {
      final label = '${size.width.toInt()}×${size.height.toInt()}';

      testWidgets('Family screen at $label, text x1.3', (tester) async {
        useSize(tester, size);
        useTextScale(tester, 1.3);
        final l = lookupAppLocalizations(const Locale('ar'));
        final db = await seeded();
        await db.doc('families/f1/members/$yusuf').update({'name': arabicName});
        await seedNoLoginMember(db, id: longArabicId, name: longArabicName, color: 6);
        await db.doc('families/f1/members/$longArabicId').update({'displayName': longArabicChosen});
        await db.doc('users/u1').update({'language': 'ar'});
        await pumpWithFamily(tester, db: db, locale: const Locale('ar'), child: const FamilyScreen());
        expect(tester.takeException(), isNull); // no overflow

        // Each row: the initial is the first letter of the name chores show
        // (the chosen name when there is one), the title keeps its room, and
        // the controls stay on screen.
        for (final (uid, name, tagText, initial) in [
          (yusuf, arabicName, l.noLoginTag, 'ي'),
          (longArabicId, longArabicName, '${l.noLoginTag} · $longArabicChosen', 'ع'),
        ]) {
          final tag = find.byKey(ValueKey('noLoginTag-$uid'));
          await scrollTo(tester, tag);
          expect(tester.widget<Text>(tag).data, tagText);
          expect(tester.widget<Text>(tag).maxLines, 2);
          expect(tester.getRect(tag).width, greaterThanOrEqualTo(80), reason: '$uid subtitle');
          expect(tester.getRect(find.text(name)).width, greaterThanOrEqualTo(80), reason: '$uid title');
          expect(find.descendant(of: rowOf(uid), matching: find.widgetWithText(MemberAvatar, initial)), findsOneWidget);
          for (final key in [ValueKey('memberColor-$uid'), ValueKey('memberMenu-$uid')]) {
            final rect = tester.getRect(find.byKey(key));
            expect(rect.left, greaterThanOrEqualTo(0), reason: '$key');
            expect(rect.right, lessThanOrEqualTo(size.width), reason: '$key');
            expect(rect.width, greaterThanOrEqualTo(48), reason: '$key');
          }
        }
        expect(tester.takeException(), isNull);

        // The menu and its edit dialog open without an exception.
        await scrollTo(tester, find.byKey(const ValueKey('noLoginTag-$yusuf')));
        await openEditName(tester, yusuf);
        expect(tester.takeException(), isNull);
        expect(tester.widget<TextField>(find.byKey(const Key('promptField'))).controller!.text, arabicName);
      });

      testWidgets('Chores tab at $label, text x1.3', (tester) async {
        useSize(tester, size);
        useTextScale(tester, 1.3);
        final db = await seeded(brushToYusuf: true);
        await db.doc('families/f1/members/$yusuf').update({'name': arabicName});
        await db.doc('users/u1').update({'language': 'ar'});
        await pumpWithFamily(tester, db: db, locale: const Locale('ar'), child: const ChoresScreen());
        expect(tester.takeException(), isNull);

        final section = find.byKey(const ValueKey('choreSection-$yusuf'));
        await scrollTo(tester, section);
        expect(section, findsOneWidget);
        // Chores show the first name; the avatar shows its first letter.
        expect(inside(section, 'يوسف'), findsOneWidget);
        expect(find.descendant(of: section, matching: find.widgetWithText(MemberAvatar, 'ي')), findsOneWidget);
        expect(tester.getRect(find.descendant(of: section, matching: find.text('يوسف'))).width, greaterThanOrEqualTo(40));
        expect(find.descendant(of: section, matching: find.byKey(const ValueKey('chore-brush'))), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final size in const [Size(320, 640), Size(360, 740)]) {
      for (final lang in ['en', 'ar']) {
        final label = '${size.width.toInt()}×${size.height.toInt()}';
        testWidgets('the add button and its dialog fit $label, text x1.3 ($lang)', (tester) async {
          useSize(tester, size);
          useTextScale(tester, 1.3);
          final l = lookupAppLocalizations(Locale(lang));
          final db = await seeded();
          await db.doc('users/u1').update({'language': lang});
          await pumpWithFamily(tester, db: db, locale: Locale(lang), child: const FamilyScreen());
          expect(tester.takeException(), isNull);

          final button = find.byKey(const Key('addNoLoginMember'));
          await tester.ensureVisible(button);
          await settle(tester);
          expect(inside(button, l.addNoLoginMember), findsOneWidget);
          final rect = tester.getRect(button);
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));

          await tester.tap(button);
          await settle(tester);
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('promptField')), findsOneWidget);
          await saveName(tester, lang == 'ar' ? 'سارة' : 'Omar');
          expect(tester.takeException(), isNull);
          expect(await noLoginIds(db), hasLength(2)); // Yusuf and the new one
        });
      }
    }
  });

  group('ProfileSync', () {
    testWidgets('never writes to a no-login member, except the colour a parent fills in', (tester) async {
      final db = await seedFamily();
      await db.doc('families/f1/members/u1').update({'color': 0});
      await db.doc('families/f1/members/u2').update({'color': 1});
      // Blank name and no colour: the two things ProfileSync repairs for a member.
      await db.doc('families/f1/members/$yusuf').set({
        'name': '', 'role': 'child', 'noLogin': true, 'pictureTiles': false, 'createdBy': 'u1',
      });
      final nl = WriteCounter(db, 'families/f1/members/$yusuf');
      final dad = WriteCounter(db, 'families/f1/members/u1');
      addTearDown(nl.cancel);
      addTearDown(dad.cancel);

      await pumpWithFamily(
        tester,
        db: db,
        authName: 'Firas Alhalabi',
        photoUrl: 'https://example.com/dad.png',
        child: const RootGate(),
      );
      await frames(tester, 50);

      final doc = await data(db, 'families/f1/members/$yusuf');
      expect(doc['color'], 2); // the one expected write: the lowest free colour
      expect(doc['name'], ''); // not repaired from Dad's Google account
      expect(doc.containsKey('photoUrl'), isFalse);
      expect(doc['noLogin'], isTrue);
      expect(doc['role'], 'child');
      expect(doc['createdBy'], 'u1');
      expect(nl.writes, 1);
      // Dad's own photo is saved, as before: proof the sync did run.
      expect((await data(db, 'families/f1/members/u1'))['photoUrl'], 'https://example.com/dad.png');
      expect(dad.writes, 1);
    });
  });
}
