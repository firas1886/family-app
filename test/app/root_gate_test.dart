import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

void main() {
  testWidgets('signed out shows the sign-in screen', (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpWithFamily(tester, db: db, uid: '', child: const RootGate());
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('signed in without a family shows onboarding; creating one opens the app', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u9').set({'name': 'Firas', 'email': 'f@x.com', 'familyId': null, 'language': 'en'});
    await pumpWithFamily(tester, db: db, uid: 'u9', child: const RootGate());
    expect(find.text('Create a family'), findsWidgets);

    await tester.enterText(find.byKey(const Key('familyNameField')), 'Our home');
    await tester.tap(find.byKey(const Key('createFamilyButton')));
    await settle(tester);
    await settle(tester);

    final user = (await db.doc('users/u9').get()).data()!;
    expect(user['familyId'], isNotNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('joining with a code opens the app', (tester) async {
    final db = await seedFamily();
    await db.doc('users/u9').set({'name': 'Mum', 'email': 'm@x.com', 'familyId': null, 'language': 'en'});
    await pumpWithFamily(tester, db: db, uid: 'u9', child: const RootGate());
    await tester.enterText(find.byKey(const Key('joinCodeField')), 'abc 234');
    await tester.tap(find.byKey(const Key('joinFamilyButton')));
    await settle(tester);
    await settle(tester);
    expect((await db.doc('families/f1/members/u9').get()).data()!['role'], 'child');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('a wrong code shows an error', (tester) async {
    final db = await seedFamily();
    await db.doc('users/u9').set({'name': 'Mum', 'email': 'm@x.com', 'familyId': null, 'language': 'en'});
    await pumpWithFamily(tester, db: db, uid: 'u9', child: const RootGate());
    await tester.enterText(find.byKey(const Key('joinCodeField')), 'ZZZZZZ');
    await tester.tap(find.byKey(const Key('joinFamilyButton')));
    await settle(tester);
    expect(find.text("That code doesn't match any family."), findsOneWidget);
  });

  testWidgets('a member of a family sees the home shell', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const RootGate());
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('a removed member is sent back to onboarding', (tester) async {
    final db = await seedFamily();
    await db.doc('families/f1/members/u2').delete();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const RootGate());
    await settle(tester);
    expect((await db.doc('users/u2').get()).data()!['familyId'], isNull);
    expect(find.byKey(const Key('createFamilyButton')), findsOneWidget);
  });
}
