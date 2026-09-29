import 'package:family_app/features/family/family_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

void main() {
  testWidgets('shows family, code and members', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const FamilyScreen());
    expect(find.text('Join code: ABC234'), findsOneWidget);
    expect(find.text('Dad'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
  });

  testWidgets('a parent can promote a child', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const FamilyScreen());
    await tester.tap(find.byKey(const Key('memberMenu-u2')));
    await settle(tester);
    await tester.tap(find.text('Make parent'));
    await settle(tester);
    expect((await db.doc('families/f1/members/u2').get()).data()!['role'], 'parent');
  });

  testWidgets('children see no member menus and no new-code button', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
    expect(find.byKey(const Key('memberMenu-u1')), findsNothing);
    expect(find.byKey(const Key('regenerateCode')), findsNothing);
  });

  testWidgets('the last parent cannot leave', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const FamilyScreen());
    await tester.ensureVisible(find.byKey(const Key('leaveFamily'), skipOffstage: false));
    await settle(tester);
    await tester.tap(find.byKey(const Key('leaveFamily')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirmYes')));
    await settle(tester);
    expect(find.text('The family needs at least one parent.'), findsOneWidget);
    expect((await db.doc('families/f1/members/u1').get()).exists, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('switching language saves it on the user', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const FamilyScreen());
    await tester.tap(find.text('العربية'));
    await settle(tester);
    expect((await db.doc('users/u1').get()).data()!['language'], 'ar');
  });

  testWidgets('a parent can make a new join code', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const FamilyScreen());
    await tester.tap(find.byKey(const Key('regenerateCode')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirmYes')));
    await settle(tester);
    final code = (await db.doc('families/f1').get()).data()!['joinCode'];
    expect(code, isNot('ABC234'));
    expect((await db.doc('joinCodes/ABC234').get()).exists, isFalse);
  });
}
