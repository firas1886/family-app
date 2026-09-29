import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart';
import 'package:family_app/app/palette.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/data/family_repository.dart';
import 'package:family_app/features/common/member_avatar.dart';
import 'package:family_app/features/family/family_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<Map<String, dynamic>> memberDoc(FakeFirebaseFirestore db, String uid) async =>
    (await db.doc('families/f1/members/$uid').get()).data()!;

void main() {
  group('Family screen', () {
    testWidgets('members show avatars and colour dots', (tester) async {
      final db = await seedFamily();
      await db.doc('families/f1/members/u2').update({'color': 4});
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      expect(find.byType(MemberAvatar), findsNWidgets(2));
      expect(find.byKey(const ValueKey('memberColor-u1')), findsOneWidget);
      expect(find.byKey(const ValueKey('memberColor-u2')), findsOneWidget);
      // Sara's letter sits on her saved colour (blue).
      final avatar = tester.widget<CircleAvatar>(
        find.descendant(of: find.widgetWithText(MemberAvatar, 'S'), matching: find.byType(CircleAvatar)),
      );
      expect(avatar.backgroundColor, personColor(4, Brightness.light).fill);
    });

    testWidgets('a parent picks a colour for a member', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      await tester.tap(find.byKey(const ValueKey('memberColor-u2')));
      await settle(tester);
      expect(find.byKey(const ValueKey('paletteColor-7')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('paletteColor-5')));
      await settle(tester);
      expect((await memberDoc(db, 'u2'))['color'], 5);
    });

    testWidgets('a child sees colours but cannot change them', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
      expect(find.byKey(const ValueKey('memberColor-u2')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('memberColor-u2')));
      await settle(tester);
      expect(find.byKey(const ValueKey('paletteColor-0')), findsNothing);
    });

    testWidgets('parents switch picture tiles on for a child; children see no switch', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      expect(find.byKey(const ValueKey('pictureTiles-u1')), findsNothing); // parents have none
      expect(tester.widget<Switch>(find.byKey(const ValueKey('pictureTiles-u2'))).value, isFalse);
      await tester.tap(find.byKey(const ValueKey('pictureTiles-u2')));
      await settle(tester);
      expect((await memberDoc(db, 'u2'))['pictureTiles'], isTrue);
      expect(tester.widget<Switch>(find.byKey(const ValueKey('pictureTiles-u2'))).value, isTrue);

      await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
      expect(find.byKey(const ValueKey('pictureTiles-u2')), findsNothing);
    });

    testWidgets('the theme choice is saved on the user', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
      expect(find.byKey(const Key('themeMode')), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await settle(tester);
      expect((await db.doc('users/u2').get()).data()!['themeMode'], 'dark');
      await tester.tap(find.text('System'));
      await settle(tester);
      expect((await db.doc('users/u2').get()).data()!['themeMode'], isNull);
    });

    testWidgets('a member with a photo still shows their letter underneath', (tester) async {
      final db = await seedFamily();
      await db.doc('families/f1/members/u2').update({'photoUrl': 'https://example.com/sara.png'});
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      await settle(tester);
      expect(tester.takeException(), isNull);
      final avatar = tester.widget<CircleAvatar>(
        find.descendant(of: find.widgetWithText(MemberAvatar, 'S'), matching: find.byType(CircleAvatar)),
      );
      expect(avatar.foregroundImage, isA<NetworkImage>());
    });

    testWidgets('a progress ring is drawn around the avatar', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(
        tester,
        db: db,
        child: const Scaffold(body: MemberAvatar(member: Member(uid: 'u2', name: 'Sara', role: Role.child), progress: 0.5)),
      );
      final ring = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
      expect(ring.value, 0.5);
    });

    const sizes = [Size(360, 740), Size(320, 640)];
    const scales = [1.0, 1.3];
    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets('fits a small phone at $size, text x$scale', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final db = await seedFamily();
          await db.doc('families/f1/members/u2').update({'name': 'سارة عبدالله محمد الأحمد'});
          await pumpWithFamily(tester, db: db, child: const FamilyScreen());
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('themeMode')), findsOneWidget);
        });
      }
    }
  });

  group('ProfileSync', () {
    const home = ProfileSync(child: Text('home'));

    testWidgets('saves my Google photo on my member doc', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, uid: 'u2', photoUrl: 'https://example.com/sara.png', child: home);
      await settle(tester);
      expect((await memberDoc(db, 'u2'))['photoUrl'], 'https://example.com/sara.png');
      expect((await memberDoc(db, 'u1')).containsKey('photoUrl'), isFalse);
    });

    testWidgets("a parent's phone gives colours to members without one", (tester) async {
      final db = await seedFamily();
      await db.doc('families/f1/members/u1').update({'joinedAt': DateTime(2026, 1, 1)});
      await db.doc('families/f1/members/u2').update({'joinedAt': DateTime(2026, 2, 1)});
      await pumpWithFamily(tester, db: db, child: home);
      await settle(tester);
      expect((await memberDoc(db, 'u1'))['color'], 0);
      expect((await memberDoc(db, 'u2'))['color'], 1);
    });

    testWidgets('saved colours are kept; newcomers get the lowest free one', (tester) async {
      final db = await seedFamily();
      await db.doc('families/f1/members/u1').update({'color': 0});
      await db.doc('families/f1/members/u2').update({'color': 1});
      await db.doc('families/f1/members/u3').set({'name': 'Omar', 'role': 'child'});
      await pumpWithFamily(tester, db: db, child: home);
      await settle(tester);
      expect((await memberDoc(db, 'u1'))['color'], 0);
      expect((await memberDoc(db, 'u2'))['color'], 1);
      expect((await memberDoc(db, 'u3'))['color'], 2);
    });

    testWidgets("a child's phone writes no colours", (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: home);
      await settle(tester);
      expect((await memberDoc(db, 'u1')).containsKey('color'), isFalse);
      expect((await memberDoc(db, 'u2')).containsKey('color'), isFalse);
    });

    test("a new family's creator starts with colour 0", () async {
      final db = FakeFirebaseFirestore();
      final repo = FamilyRepository(db);
      await repo.ensureUser(uid: 'u1', name: 'Dad', email: 'd@x', language: 'en');
      final f = await repo.createFamily(uid: 'u1', userName: 'Dad', familyName: 'Home', otherCategoryName: 'Other');
      expect((await repo.watchMember(f, 'u1').first)!.color, 0);
    });

    testWidgets('the app shell is wrapped in ProfileSync', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, child: const RootGate());
      expect(find.byType(ProfileSync), findsOneWidget);
      expect(find.byType(HomeShell), findsOneWidget);
    });
  });
}
