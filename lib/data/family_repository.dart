import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models.dart';
import '../core/no_login.dart';
import '../core/text.dart';

class JoinCodeNotFound implements Exception {}

class LastParentException implements Exception {}

class FamilyRepository {
  FamilyRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _family(String f) => _db.collection('families').doc(f);
  CollectionReference<Map<String, dynamic>> _members(String f) => _family(f).collection('members');
  DocumentReference<Map<String, dynamic>> _joinCode(String code) => _db.collection('joinCodes').doc(code);

  Stream<AppUser?> watchUser(String uid) => _user(uid)
      .snapshots()
      .map((s) => s.exists ? AppUser.fromMap(uid, s.data()!) : null);

  Future<void> ensureUser({
    required String uid,
    required String name,
    required String email,
    required String language,
  }) async {
    final snap = await _user(uid).get();
    if (snap.exists) return;
    await _user(uid).set({'name': name, 'email': email, 'familyId': null, 'language': language});
  }

  Future<void> setLanguage(String uid, String language) =>
      _user(uid).set({'language': language}, SetOptions(merge: true));

  /// 'light', 'dark', or null to follow the phone.
  Future<void> setThemeMode(String uid, String? mode) =>
      _user(uid).set({'themeMode': mode}, SetOptions(merge: true));

  /// Three sequential writes so each one passes the security rules
  /// (the member doc needs the family doc; the code and category need the member doc).
  Future<String> createFamily({
    required String uid,
    required String userName,
    required String familyName,
    required String otherCategoryName,
  }) async {
    final familyRef = _db.collection('families').doc();
    final code = await _unusedCode();
    final now = DateTime.now();
    await familyRef.set({'name': familyName, 'joinCode': code, 'createdBy': uid, 'createdAt': now});
    await _members(familyRef.id).doc(uid).set({'name': userName, 'role': 'parent', 'joinedAt': now, 'color': 0});
    final batch = _db.batch()
      ..set(_joinCode(code), {'familyId': familyRef.id})
      ..set(familyRef.collection('categories').doc(), {
        'name': otherCategoryName,
        'isDefault': true,
        'createdBy': uid,
        'createdAt': now,
      })
      ..set(_user(uid), {'familyId': familyRef.id}, SetOptions(merge: true));
    await batch.commit();
    return familyRef.id;
  }

  Future<String> joinFamily({
    required String uid,
    required String userName,
    required String code,
  }) async {
    final normalized = normalizeJoinCode(code);
    if (normalized.length != 6) throw JoinCodeNotFound();
    final snap = await _joinCode(normalized).get();
    if (!snap.exists) throw JoinCodeNotFound();
    final familyId = snap.data()!['familyId'] as String;
    final batch = _db.batch()
      ..set(_members(familyId).doc(uid), {
        'name': userName,
        'role': 'child',
        'joinedAt': DateTime.now(),
        'joinCode': normalized,
      })
      ..set(_user(uid), {'familyId': familyId}, SetOptions(merge: true));
    await batch.commit();
    return familyId;
  }

  Stream<Family?> watchFamily(String familyId) => _family(familyId)
      .snapshots()
      .map((s) => s.exists ? Family.fromMap(s.id, s.data()!) : null);

  Stream<List<Member>> watchMembers(String familyId) => _members(familyId)
      .snapshots()
      .map((q) => [for (final d in q.docs) Member.fromMap(d.id, d.data())]);

  Stream<Member?> watchMember(String familyId, String uid) => _members(familyId)
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? Member.fromMap(uid, s.data()!) : null);

  /// Parents only (security rules): palette index 0–7.
  Future<void> setColor(String familyId, String uid, int index) =>
      _members(familyId).doc(uid).update({'color': index});

  /// Parents only (security rules).
  Future<void> setPictureTiles(String familyId, String uid, bool on) =>
      _members(familyId).doc(uid).update({'pictureTiles': on});

  /// Only the member themselves (security rules).
  Future<void> setPhotoUrl(String familyId, String uid, String? url) =>
      _members(familyId).doc(uid).update({'photoUrl': url});

  /// Parents only (security rules): the name shown on chores, 1–40 characters.
  /// Null removes it, so chores show the first name again.
  Future<void> setDisplayName(String familyId, String uid, String? value) =>
      _members(familyId).doc(uid).update({'displayName': value ?? FieldValue.delete()});

  /// Only the member themselves (security rules): repairs a blank name.
  Future<void> setMemberName(String familyId, String uid, String name) =>
      _members(familyId).doc(uid).update({'name': name});

  /// Adds a family member who has no login (a parent action). Returns the new id.
  Future<String> addNoLoginMember({
    required String familyId,
    required String name,
    required String createdBy,
    required int color,
    DateTime? now,
    Random? random,
  }) async {
    final id = newNoLoginId(random);
    await _members(familyId).doc(id).set({
      'name': name.trim(),
      'role': 'child',
      'noLogin': true,
      'color': color,
      'pictureTiles': false,
      'joinedAt': now ?? DateTime.now(),
      'createdBy': createdBy,
    });
    return id;
  }

  /// Repairs a blank name on the user doc, keeping its other fields.
  Future<void> setUserName(String uid, String name) =>
      _user(uid).set({'name': name}, SetOptions(merge: true));

  Future<void> setRole(String familyId, String memberUid, Role role) async {
    if (role == Role.child) await _ensureAnotherParent(familyId, memberUid);
    await _members(familyId).doc(memberUid).update({'role': role.name});
  }

  Future<void> removeMember(String familyId, String memberUid) async {
    await _ensureAnotherParent(familyId, memberUid);
    await _members(familyId).doc(memberUid).delete();
  }

  Future<void> leaveFamily(String familyId, String uid) async {
    await _ensureAnotherParent(familyId, uid);
    await _members(familyId).doc(uid).delete();
    await clearFamily(uid);
  }

  Future<void> clearFamily(String uid) =>
      _user(uid).set({'familyId': null}, SetOptions(merge: true));

  Future<String> regenerateCode(String familyId) async {
    final family = await _family(familyId).get();
    final old = family.data()?['joinCode'] as String?;
    final code = await _unusedCode();
    final batch = _db.batch();
    if (old != null && old.isNotEmpty) batch.delete(_joinCode(old));
    batch
      ..set(_joinCode(code), {'familyId': familyId})
      ..update(_family(familyId), {'joinCode': code});
    await batch.commit();
    return code;
  }

  /// Throws if [memberUid] is a parent and no other parent exists.
  Future<void> _ensureAnotherParent(String familyId, String memberUid) async {
    final parents = await _members(familyId).where('role', isEqualTo: 'parent').get();
    final isParent = parents.docs.any((d) => d.id == memberUid);
    final otherParents = parents.docs.where((d) => d.id != memberUid);
    if (isParent && otherParents.isEmpty) throw LastParentException();
  }

  Future<String> _unusedCode() async {
    while (true) {
      final code = generateJoinCode();
      if (!(await _joinCode(code).get()).exists) return code;
    }
  }
}
