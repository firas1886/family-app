import 'package:family_app/core/history.dart';
import 'package:family_app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

Purchase p(String id, DateTime at) => Purchase(
      id: id, itemId: id, itemName: id, categoryName: '', listId: 'l1', listName: 'Home',
      boughtBy: 'u1', boughtByName: 'Dad', boughtAt: at,
    );

void main() {
  test('groups by calendar day, newest day and newest purchase first', () {
    final groups = groupPurchasesByDay([
      p('a', DateTime(2026, 9, 28, 9)),
      p('b', DateTime(2026, 9, 30, 10)),
      p('c', DateTime(2026, 9, 30, 18)),
    ]);
    expect(groups.map((g) => g.day).toList(), [DateTime(2026, 9, 30), DateTime(2026, 9, 28)]);
    expect(groups.first.purchases.map((x) => x.id).toList(), ['c', 'b']);
  });

  test('empty input gives no groups', () {
    expect(groupPurchasesByDay([]), isEmpty);
  });
}
