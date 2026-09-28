import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:google_sign_in/google_sign_in.dart';

import '../core/models.dart';
import '../core/placement.dart';
import '../data/catalog_repository.dart';
import '../data/family_repository.dart';
import '../data/list_repository.dart';
import '../data/purchase_repository.dart';

// Platform services — overridden in tests.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn());
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// Auth.
final authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);
final authReadyProvider = Provider<bool>((ref) => !ref.watch(authUserProvider).isLoading);
final currentUidProvider = Provider<String?>((ref) => ref.watch(authUserProvider).valueOrNull?.uid);

// User and family.
final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) => FamilyRepository(ref.watch(firestoreProvider)),
);

final appUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(familyRepositoryProvider).watchUser(uid);
});

final familyIdProvider = Provider<String?>((ref) => ref.watch(appUserProvider).valueOrNull?.familyId);

/// Null means "follow the phone's language".
final localeProvider = Provider<Locale?>((ref) {
  final language = ref.watch(appUserProvider).valueOrNull?.language;
  return language == null ? null : Locale(language);
});

String _requireFamily(Ref ref) {
  final id = ref.watch(familyIdProvider);
  if (id == null) throw StateError('No family selected');
  return id;
}

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(firestoreProvider), _requireFamily(ref)),
);
final listRepositoryProvider = Provider<ListRepository>(
  (ref) => ListRepository(ref.watch(firestoreProvider), _requireFamily(ref)),
);
final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => PurchaseRepository(ref.watch(firestoreProvider), _requireFamily(ref)),
);

final familyProvider = StreamProvider<Family?>(
  (ref) => ref.watch(familyRepositoryProvider).watchFamily(_requireFamily(ref)),
);
final membersProvider = StreamProvider<List<Member>>(
  (ref) => ref.watch(familyRepositoryProvider).watchMembers(_requireFamily(ref)),
);
final myMemberProvider = StreamProvider<Member?>((ref) {
  final uid = ref.watch(currentUidProvider);
  final familyId = ref.watch(familyIdProvider);
  if (uid == null || familyId == null) return Stream.value(null);
  return ref.watch(familyRepositoryProvider).watchMember(familyId, uid);
});
final isParentProvider = Provider<bool>(
  (ref) => ref.watch(myMemberProvider).valueOrNull?.role == Role.parent,
);

// Shopping data.
final categoriesProvider = StreamProvider<List<ItemCategory>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchCategories(),
);
final itemsProvider = StreamProvider<List<Item>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchItems(),
);
final listsProvider = StreamProvider<List<ShoppingList>>(
  (ref) => ref.watch(listRepositoryProvider).watchLists(),
);
final entriesProvider = StreamProvider.family<List<Entry>, String>(
  (ref, listId) => ref.watch(listRepositoryProvider).watchEntries(listId),
);
final purchasesProvider = StreamProvider<List<Purchase>>(
  (ref) => ref.watch(purchaseRepositoryProvider).watchPurchases(),
);

final sortModeProvider = StateProvider<SortMode>((ref) => SortMode.category);

/// True while Firestore is serving data from the local cache only.
final offlineProvider = StreamProvider<bool>((ref) {
  final familyId = ref.watch(familyIdProvider);
  if (familyId == null) return Stream.value(false);
  return ref
      .watch(firestoreProvider)
      .collection('families')
      .doc(familyId)
      .collection('members')
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.metadata.isFromCache);
});
