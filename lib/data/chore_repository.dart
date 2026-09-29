import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/chores.dart';
import '../core/dates.dart';

class ChoreRepository {
  ChoreRepository(this._db, this.familyId);

  final FirebaseFirestore _db;
  final String familyId;

  DocumentReference<Map<String, dynamic>> get _family => _db.collection('families').doc(familyId);
  CollectionReference<Map<String, dynamic>> get _chores => _family.collection('chores');
  CollectionReference<Map<String, dynamic>> get _done => _family.collection('choreDone');

  Stream<List<Chore>> watchChores() =>
      _chores.snapshots().map((q) => [for (final d in q.docs) Chore.fromMap(d.id, d.data())]);

  /// Done records whose `date` is between [fromDate] and [toDate], both "YYYY-MM-DD" and inclusive.
  Stream<List<ChoreDone>> watchDone({required String fromDate, required String toDate}) => _done
      .where('date', isGreaterThanOrEqualTo: fromDate)
      .where('date', isLessThanOrEqualTo: toDate)
      .snapshots()
      .map((q) => [for (final d in q.docs) ChoreDone.fromMap(d.data())]);

  /// Creates the chore under a new id and returns that id. `chore.id` is ignored.
  Future<String> addChore(Chore chore) async {
    final ref = _chores.doc();
    await ref.set({...chore.toMap(), 'createdAt': DateTime.now()});
    return ref.id;
  }

  /// Rewrites the chore's fields; `createdAt` and any unknown fields are kept.
  Future<void> updateChore(Chore chore) =>
      _chores.doc(chore.id).set(chore.toMap(), SetOptions(merge: true));

  /// Deletes the chore only. Its done records stay as history.
  Future<void> deleteChore(String choreId) => _chores.doc(choreId).delete();

  /// Marks [chore] done for [date] ("YYYY-MM-DD"). Ticking the same chore and
  /// date twice, from any phone, gives one record.
  Future<void> tick({
    required Chore chore,
    required String date,
    required String doneBy,
    required String doneByName,
    DateTime? now,
  }) {
    final record = ChoreDone(
      choreId: chore.id,
      date: date,
      choreTitle: chore.title,
      assignee: chore.assignee,
      doneBy: doneBy,
      doneByName: doneByName,
      doneAt: now ?? DateTime.now(),
      dayNumber: dayNumberOf(parseDateKey(date)),
    );
    return _done.doc(record.id).set(record.toMap());
  }

  Future<void> untick({required String choreId, required String date}) =>
      _done.doc(choreDoneId(choreId, date)).delete();
}
