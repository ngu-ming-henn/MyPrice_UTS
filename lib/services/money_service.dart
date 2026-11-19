import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/utils/firestore_helpers.dart';
import '../core/utils/format.dart';
import '../models/money.dart';
import '../models/product.dart';
import 'sample_data.dart';

/// The owner's money and planning data (staff only, see firestore.rules):
/// - `closings/{yyyy-MM-dd}`: one summary per day, saved by "Close shop".
/// - `calendar/{yyyy-MM-dd}`: the kind of week starting that Monday
///   (exam / break / event); weeks with no document are normal.
class MoneyService {
  MoneyService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _closings =>
      _db.collection('closings');
  CollectionReference<Map<String, dynamic>> get _calendar =>
      _db.collection('calendar');

  // --------------------------------------------------------------- closings

  /// The closing of [day], or null while the shop is still open.
  Stream<DayClosing?> watchClosing(DateTime day) => _closings
      .doc(dayId(day))
      .snapshots()
      .map((d) => d.exists ? DayClosing.fromDoc(d) : null);

  /// Closed days since [since], newest first.
  Stream<List<DayClosing>> watchClosingsSince(DateTime since) => _closings
      .where('day', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .snapshots()
      .map(
        (s) =>
            s.docs.map(DayClosing.fromDoc).toList()
              ..sort((a, b) => b.day.compareTo(a.day)),
      );

  /// The last closing before today (its float is the default for today).
  Future<DayClosing?> lastClosingBefore(DateTime day) async {
    final snap = await _closings
        .where('day', isLessThan: Timestamp.fromDate(dateOnly(day)))
        .orderBy('day', descending: true)
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : DayClosing.fromDoc(snap.docs.first);
  }

  /// Saves (or replaces) the day's closing. Returns false if it is queued
  /// offline and will be sent when the connection returns.
  Future<bool> saveClosing(DayClosing closing) =>
      waitForSync(_closings.doc(closing.id).set(closing.toMap()));

  // ---------------------------------------------------------------- calendar

  /// Week ID (Monday, "yyyy-MM-dd") -> WeekType, for the marked weeks.
  Stream<Map<String, String>> watchCalendar() => _calendar.snapshots().map(
    (s) => {
      for (final d in s.docs)
        if (d.data()['type'] is String) d.id: d.data()['type'] as String,
    },
  );

  /// Marks the week starting [monday]; a normal week removes the mark.
  /// Returns false if it is queued offline.
  Future<bool> setWeekType(DateTime monday, String type) {
    final ref = _calendar.doc(dayId(weekStart(monday)));
    return waitForSync(
      type == WeekType.normal
          ? ref.delete()
          : ref.set({'type': type, 'updatedAt': FieldValue.serverTimestamp()}),
    );
  }

  // -------------------------------------------------------------------- demo

  /// Adds 8 weeks of sample closed days and marks sample exam, break and
  /// event weeks (see [buildSampleHistory]). Days already closed and weeks
  /// already marked are kept. Returns how many days were added.
  Future<int> seedSampleHistory(List<Product> products, String staffId) async {
    final today = DateTime.now();
    final sample = buildSampleHistory(today, products, staffId);
    final since = DateTime(today.year, today.month, today.day - 60);
    final closed = {
      for (final d
          in (await _closings
                  .where(
                    'day',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(since),
                  )
                  .get())
              .docs)
        d.id,
    };
    final marked = {for (final d in (await _calendar.get()).docs) d.id};
    final batch = _db.batch();
    var added = 0;
    for (final c in sample.closings) {
      if (closed.contains(c.id)) continue;
      batch.set(_closings.doc(c.id), c.toMap());
      added++;
    }
    sample.weekTypes.forEach((week, type) {
      if (!marked.contains(week)) {
        batch.set(_calendar.doc(week), {
          'type': type,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    await batch.commit();
    return added;
  }
}
