import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/data/family_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/seed.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FamilyRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FamilyRepository(db);
  });

  Future<String> createAsDad() async {
    await repo.ensureUser(uid: 'u1', name: 'Dad', email: 'dad@x.com', language: 'en');
    return repo.createFamily(uid: 'u1', userName: 'Dad', familyName: 'Home', otherCategoryName: 'Other');
  }

  test('ensureUser creates the user once and never overwrites', () async {
    await repo.ensureUser(uid: 'u1', name: 'Dad', email: 'dad@x.com', language: 'ar');
    await repo.ensureUser(uid: 'u1', name: 'Changed', email: 'dad@x.com', language: 'en');
    final user = await repo.watchUser('u1').first;
    expect(user!.name, 'Dad');
    expect(user.language, 'ar');
    expect(user.familyId, isNull);
  });

  test('createFamily makes the creator a parent and seeds Other', () async {
    final f = await createAsDad();
    final family = await repo.watchFamily(f).first;
    expect(family!.name, 'Home');
    expect(family.joinCode, matches(RegExp(r'^[A-HJ-NP-Z2-9]{6}$')));
    final code = await db.doc('joinCodes/${family.joinCode}').get();
    expect(code.data()!['familyId'], f);
    expect((await repo.watchMember(f, 'u1').first)!.role, Role.parent);
    final cats = await db.collection('families/$f/categories').get();
    expect(cats.docs.single.data()['isDefault'], true);
    expect(cats.docs.single.data()['name'], 'Other');
    expect((await repo.watchUser('u1').first)!.familyId, f);
  });

  test('joinFamily accepts a lowercase code with spaces and joins as child', () async {
    final f = await createAsDad();
    final code = (await repo.watchFamily(f).first)!.joinCode.toLowerCase();
    final typed = ' ${code.substring(0, 3)} ${code.substring(3)} ';
    final joined = await repo.joinFamily(uid: 'u2', userName: 'Sara', code: typed);
    expect(joined, f);
    expect((await repo.watchMember(f, 'u2').first)!.role, Role.child);
    expect((await db.doc('families/$f/members/u2').get()).data()!['joinCode'], code.toUpperCase());
    expect((await repo.watchUser('u2').first)!.familyId, f);
  });

  test('joinFamily rejects unknown or malformed codes', () async {
    await createAsDad();
    for (final bad in ['ZZZZZZ', '', 'abc']) {
      await expectLater(
        repo.joinFamily(uid: 'u2', userName: 'Sara', code: bad),
        throwsA(isA<JoinCodeNotFound>()),
      );
    }
  });

  test('the last parent cannot be demoted or leave', () async {
    final f = await createAsDad();
    await expectLater(repo.setRole(f, 'u1', Role.child), throwsA(isA<LastParentException>()));
    await expectLater(repo.leaveFamily(f, 'u1'), throwsA(isA<LastParentException>()));
    expect((await repo.watchMember(f, 'u1').first)!.role, Role.parent);
  });

  test('a parent can be demoted when another parent exists', () async {
    final f = await createAsDad();
    final code = (await repo.watchFamily(f).first)!.joinCode;
    await repo.joinFamily(uid: 'u2', userName: 'Mum', code: code);
    await repo.setRole(f, 'u2', Role.parent);
    await repo.setRole(f, 'u1', Role.child);
    expect((await repo.watchMember(f, 'u1').first)!.role, Role.child);
  });

  test('a child can leave and their familyId is cleared', () async {
    final f = await createAsDad();
    final code = (await repo.watchFamily(f).first)!.joinCode;
    await repo.joinFamily(uid: 'u2', userName: 'Sara', code: code);
    await repo.leaveFamily(f, 'u2');
    expect(await repo.watchMember(f, 'u2').first, isNull);
    expect((await repo.watchUser('u2').first)!.familyId, isNull);
  });

  test('removeMember deletes the member', () async {
    final f = await createAsDad();
    final code = (await repo.watchFamily(f).first)!.joinCode;
    await repo.joinFamily(uid: 'u2', userName: 'Sara', code: code);
    await repo.removeMember(f, 'u2');
    expect((await repo.watchMembers(f).first).map((m) => m.uid), ['u1']);
  });

  test('regenerateCode replaces the join code', () async {
    final f = await createAsDad();
    final old = (await repo.watchFamily(f).first)!.joinCode;
    final fresh = await repo.regenerateCode(f);
    expect(fresh, isNot(old));
    expect((await db.doc('joinCodes/$old').get()).exists, isFalse);
    expect((await db.doc('joinCodes/$fresh').get()).data()!['familyId'], f);
    expect((await repo.watchFamily(f).first)!.joinCode, fresh);
  });

  test('setLanguage stores the choice', () async {
    await repo.ensureUser(uid: 'u1', name: 'Dad', email: 'd@x', language: 'en');
    await repo.setLanguage('u1', 'ar');
    expect((await repo.watchUser('u1').first)!.language, 'ar');
  });

  test('setDisplayName sets and clears the name shown on chores', () async {
    final f = await createAsDad();
    await repo.setDisplayName(f, 'u1', 'Abu Sara');
    expect((await db.doc('families/$f/members/u1').get()).data()!['displayName'], 'Abu Sara');
    expect((await repo.watchMember(f, 'u1').first)!.displayName, 'Abu Sara');
    await repo.setDisplayName(f, 'u1', null);
    final data = (await db.doc('families/$f/members/u1').get()).data()!;
    expect(data.containsKey('displayName'), isFalse);
    expect(data['name'], 'Dad');
  });

  test('setMemberName and setUserName repair a blank name', () async {
    await repo.ensureUser(uid: 'u1', name: '', email: 'd@x', language: 'en');
    final f = await repo.createFamily(uid: 'u1', userName: '', familyName: 'Home', otherCategoryName: 'Other');
    await repo.setMemberName(f, 'u1', 'Firas Alhalabi');
    await repo.setUserName('u1', 'Firas Alhalabi');
    expect((await repo.watchMember(f, 'u1').first)!.name, 'Firas Alhalabi');
    final user = (await repo.watchUser('u1').first)!;
    expect(user.name, 'Firas Alhalabi');
    expect(user.familyId, f); // merged, not replaced
    expect(user.language, 'en');
  });

  test('addNoLoginMember writes a child with no login', () async {
    final db = await seedFamily();
    final repo = FamilyRepository(db);
    final id = await repo.addNoLoginMember(
      familyId: 'f1', name: '  Yusuf  ', createdBy: 'u1', color: 4,
      now: DateTime(2026, 10, 1, 9), random: Random(3),
    );
    expect(id, matches(RegExp(r'^nl_[A-Za-z0-9]{20}$')));
    final data = (await db.doc('families/f1/members/$id').get()).data()!;
    expect(data['name'], 'Yusuf');
    expect(data['role'], 'child');
    expect(data['noLogin'], isTrue);
    expect(data['color'], 4);
    expect(data['pictureTiles'], isFalse);
    expect(data['createdBy'], 'u1');
    expect(data.containsKey('joinedAt'), isTrue);
  });
}
