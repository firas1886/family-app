import 'text.dart';

enum Role { parent, child }

enum EntryStatus { toBuy, bought }

const units = ['pcs', 'kg', 'g', 'L', 'ml', 'pack'];

/// Reads a DateTime or a Firestore Timestamp without importing Firebase here.
DateTime? readDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return (value as dynamic).toDate() as DateTime;
}

double? readDouble(Object? value) => value == null ? null : (value as num).toDouble();

int? readInt(Object? value) => value == null ? null : (value as num).toInt();

class AppUser {
  const AppUser({required this.uid, required this.name, required this.email, this.familyId, this.language});
  final String uid;
  final String name;
  final String email;
  final String? familyId;
  final String? language;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid,
        name: m['name'] as String? ?? '',
        email: m['email'] as String? ?? '',
        familyId: m['familyId'] as String?,
        language: m['language'] as String?,
      );
}

class Family {
  const Family({required this.id, required this.name, required this.joinCode});
  final String id;
  final String name;
  final String joinCode;

  factory Family.fromMap(String id, Map<String, dynamic> m) => Family(
        id: id,
        name: m['name'] as String? ?? '',
        joinCode: m['joinCode'] as String? ?? '',
      );
}

class Member {
  const Member({required this.uid, required this.name, required this.role});
  final String uid;
  final String name;
  final Role role;

  factory Member.fromMap(String uid, Map<String, dynamic> m) => Member(
        uid: uid,
        name: m['name'] as String? ?? '',
        role: m['role'] == 'parent' ? Role.parent : Role.child,
      );
}

class ItemCategory {
  const ItemCategory({required this.id, required this.name, required this.isDefault});
  final String id;
  final String name;
  final bool isDefault;

  factory ItemCategory.fromMap(String id, Map<String, dynamic> m) => ItemCategory(
        id: id,
        name: m['name'] as String? ?? '',
        isDefault: m['isDefault'] == true,
      );
}

class ShoppingList {
  const ShoppingList({required this.id, required this.name});
  final String id;
  final String name;

  factory ShoppingList.fromMap(String id, Map<String, dynamic> m) =>
      ShoppingList(id: id, name: m['name'] as String? ?? '');
}

class Item {
  const Item({
    required this.id,
    required this.name,
    required this.categoryId,
    this.quantity,
    this.unit,
    this.notes = '',
    this.expiryDays,
  });
  final String id;
  final String name;
  final String categoryId;
  final double? quantity;
  final String? unit;
  final String notes;
  final int? expiryDays;

  String get key => nameKey(name);

  int? get effectiveExpiryDays {
    final days = expiryDays;
    return (days != null && days > 0) ? days : null;
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'nameKey': key,
        'categoryId': categoryId,
        'quantity': quantity,
        'unit': unit,
        'notes': notes,
        'expiryDays': expiryDays,
      };

  factory Item.fromMap(String id, Map<String, dynamic> m) => Item(
        id: id,
        name: m['name'] as String? ?? '',
        categoryId: m['categoryId'] as String? ?? '',
        quantity: readDouble(m['quantity']),
        unit: m['unit'] as String?,
        notes: m['notes'] as String? ?? '',
        expiryDays: readInt(m['expiryDays']),
      );
}

class Entry {
  const Entry({
    required this.itemId,
    required this.status,
    this.addedBy,
    this.addedAt,
    this.boughtBy,
    this.boughtAt,
  });
  final String itemId;
  final EntryStatus status;
  final String? addedBy;
  final DateTime? addedAt;
  final String? boughtBy;
  final DateTime? boughtAt;

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'status': status.name,
        'addedBy': addedBy,
        'addedAt': addedAt,
        'boughtBy': boughtBy,
        'boughtAt': boughtAt,
      };

  factory Entry.fromMap(String id, Map<String, dynamic> m) => Entry(
        itemId: id,
        status: m['status'] == 'bought' ? EntryStatus.bought : EntryStatus.toBuy,
        addedBy: m['addedBy'] as String?,
        addedAt: readDate(m['addedAt']),
        boughtBy: m['boughtBy'] as String?,
        boughtAt: readDate(m['boughtAt']),
      );
}

class Purchase {
  const Purchase({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.categoryName,
    required this.listId,
    required this.listName,
    this.quantity,
    this.unit,
    this.price,
    this.currency = 'SAR',
    required this.boughtBy,
    required this.boughtByName,
    required this.boughtAt,
  });
  final String id;
  final String itemId;
  final String itemName;
  final String categoryName;
  final String listId;
  final String listName;
  final double? quantity;
  final String? unit;
  final double? price;
  final String currency;
  final String boughtBy;
  final String boughtByName;
  final DateTime boughtAt;

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'itemName': itemName,
        'categoryName': categoryName,
        'listId': listId,
        'listName': listName,
        'quantity': quantity,
        'unit': unit,
        'price': price,
        'currency': currency,
        'boughtBy': boughtBy,
        'boughtByName': boughtByName,
        'boughtAt': boughtAt,
      };

  factory Purchase.fromMap(String id, Map<String, dynamic> m) => Purchase(
        id: id,
        itemId: m['itemId'] as String? ?? '',
        itemName: m['itemName'] as String? ?? '',
        categoryName: m['categoryName'] as String? ?? '',
        listId: m['listId'] as String? ?? '',
        listName: m['listName'] as String? ?? '',
        quantity: readDouble(m['quantity']),
        unit: m['unit'] as String?,
        price: readDouble(m['price']),
        currency: m['currency'] as String? ?? 'SAR',
        boughtBy: m['boughtBy'] as String? ?? '',
        boughtByName: m['boughtByName'] as String? ?? '',
        boughtAt: readDate(m['boughtAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
