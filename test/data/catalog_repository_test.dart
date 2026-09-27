import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/data/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/seed.dart';

void main() {
  late FakeFirebaseFirestore db;
  late CatalogRepository repo;

  setUp(() async {
    db = await seedFamily();
    repo = CatalogRepository(db, 'f1');
  });

  test('addCategory trims the name; renameCategory renames', () async {
    final id = repo.newId();
    await repo.addCategory(id: id, name: ' Frozen ', uid: 'u2');
    var cat = (await repo.watchCategories().first).firstWhere((c) => c.id == id);
    expect(cat.name, 'Frozen');
    expect(cat.isDefault, isFalse);
    await repo.renameCategory(id, 'Freezer');
    cat = (await repo.watchCategories().first).firstWhere((c) => c.id == id);
    expect(cat.name, 'Freezer');
  });

  test('deleteCategory moves its items to Other', () async {
    final items = await repo.watchItems().first;
    await repo.deleteCategory(categoryId: 'dairy', otherCategoryId: 'other', catalog: items);
    final milk = (await repo.watchItems().first).firstWhere((i) => i.id == 'milk');
    expect(milk.categoryId, 'other');
    expect((await repo.watchCategories().first).map((c) => c.id), isNot(contains('dairy')));
  });

  test('findByName ignores case, spacing and Arabic spelling variants', () {
    const catalog = [
      Item(id: 'a', name: 'Milk', categoryId: 'other'),
      Item(id: 'b', name: 'قهوة', categoryId: 'other'),
      Item(id: 'c', name: 'أرز', categoryId: 'other'),
    ];
    expect(repo.findByName('  MILK ', catalog)?.id, 'a');
    expect(repo.findByName('قهوه', catalog)?.id, 'b');
    expect(repo.findByName('ارز', catalog)?.id, 'c');
    expect(repo.findByName('Labneh', catalog), isNull);
  });

  test('findByName returns null for blank input', () {
    const catalog = [Item(id: 'a', name: 'Milk', categoryId: 'other')];
    expect(repo.findByName('', catalog), isNull);
    expect(repo.findByName('   ', catalog), isNull);
  });

  test('saveItem writes nameKey and can clear optional fields', () async {
    await repo.saveItem(
      const Item(id: 'milk', name: 'Fresh Milk', categoryId: 'dairy'),
      uid: 'u1',
    );
    final data = (await db.doc('families/f1/items/milk').get()).data()!;
    expect(data['nameKey'], 'fresh milk');
    expect(data['quantity'], isNull);
    expect(data['unit'], isNull);
    expect(data['expiryDays'], isNull);
  });

  test('saveItem with isNew records the creator', () async {
    final id = repo.newId();
    await repo.saveItem(Item(id: id, name: 'Labneh', categoryId: 'other'), uid: 'u2', isNew: true);
    final data = (await db.doc('families/f1/items/$id').get()).data()!;
    expect(data['createdBy'], 'u2');
    expect(data['name'], 'Labneh');
  });

  test('deleteItem removes it from every list', () async {
    await db.doc('families/f1/lists/l2').set({'name': 'Weekend'});
    await db.doc('families/f1/lists/l2/entries/milk').set({'itemId': 'milk', 'status': 'toBuy'});
    await repo.deleteItem(itemId: 'milk', listIds: ['l1', 'l2']);
    expect((await db.doc('families/f1/items/milk').get()).exists, isFalse);
    expect((await db.doc('families/f1/lists/l1/entries/milk').get()).exists, isFalse);
    expect((await db.doc('families/f1/lists/l2/entries/milk').get()).exists, isFalse);
  });
}
