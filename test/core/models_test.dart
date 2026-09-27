import 'package:family_app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Item round-trips and stores its name key', () {
    const item = Item(
      id: 'milk', name: ' Fresh Milk', categoryId: 'dairy',
      quantity: 2, unit: 'L', notes: 'low fat', expiryDays: 7,
    );
    final map = item.toMap();
    expect(map['nameKey'], 'fresh milk');
    final back = Item.fromMap('milk', map);
    expect(back.name, ' Fresh Milk');
    expect(back.quantity, 2.0);
    expect(back.unit, 'L');
    expect(back.notes, 'low fat');
    expect(back.expiryDays, 7);
  });

  test('effectiveExpiryDays ignores zero and negatives', () {
    expect(const Item(id: 'a', name: 'a', categoryId: 'c', expiryDays: 0).effectiveExpiryDays, isNull);
    expect(const Item(id: 'a', name: 'a', categoryId: 'c', expiryDays: -2).effectiveExpiryDays, isNull);
    expect(const Item(id: 'a', name: 'a', categoryId: 'c', expiryDays: 3).effectiveExpiryDays, 3);
  });

  test('Entry round-trips', () {
    final at = DateTime(2026, 10, 1, 9);
    final entry = Entry(itemId: 'milk', status: EntryStatus.bought, addedBy: 'u1', addedAt: at, boughtBy: 'u2', boughtAt: at);
    final back = Entry.fromMap('milk', entry.toMap());
    expect(back.status, EntryStatus.bought);
    expect(back.boughtBy, 'u2');
    expect(back.boughtAt, at);
  });

  test('Purchase round-trips', () {
    final at = DateTime(2026, 10, 1, 9);
    final p = Purchase(
      id: 'p1', itemId: 'milk', itemName: 'Milk', categoryName: 'Dairy',
      listId: 'l1', listName: 'Home', quantity: 2, unit: 'L',
      boughtBy: 'u2', boughtByName: 'Sara', boughtAt: at,
    );
    final back = Purchase.fromMap('p1', p.toMap());
    expect(back.currency, 'SAR');
    expect(back.price, isNull);
    expect(back.boughtAt, at);
    expect(back.listName, 'Home');
  });

  test('Member reads role', () {
    expect(Member.fromMap('u1', {'name': 'Dad', 'role': 'parent'}).role, Role.parent);
    expect(Member.fromMap('u2', {'name': 'Sara', 'role': 'child'}).role, Role.child);
  });
}
