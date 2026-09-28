import 'models.dart';

class DayGroup {
  DayGroup(this.day, this.purchases);
  final DateTime day;
  final List<Purchase> purchases;
}

List<DayGroup> groupPurchasesByDay(Iterable<Purchase> purchases) {
  final sorted = [...purchases]..sort((a, b) => b.boughtAt.compareTo(a.boughtAt));
  final groups = <DayGroup>[];
  for (final p in sorted) {
    final day = DateTime(p.boughtAt.year, p.boughtAt.month, p.boughtAt.day);
    if (groups.isEmpty || groups.last.day != day) groups.add(DayGroup(day, []));
    groups.last.purchases.add(p);
  }
  return groups;
}
