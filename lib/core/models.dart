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
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.familyId,
    this.language,
    this.themeMode,
  });
  final String uid;
  final String name;
  final String email;
  final String? familyId;
  final String? language;

  /// 'light', 'dark', or null to follow the phone.
  final String? themeMode;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid,
        name: m['name'] as String? ?? '',
        email: m['email'] as String? ?? '',
        familyId: m['familyId'] as String?,
        language: m['language'] as String?,
        themeMode: m['themeMode'] as String?,
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
  const Member({
    required this.uid,
    required this.name,
    required this.role,
    this.color,
    this.photoUrl,
    this.pictureTiles = false,
    this.joinedAt,
    this.displayName,
    this.noLogin = false,
  });
  final String uid;
  final String name;
  final Role role;

  /// Palette index 0–7, or null until one is assigned.
  final int? color;

  /// The member's Google profile photo, or null.
  final String? photoUrl;

  /// Show this member's chores as big emoji tiles.
  final bool pictureTiles;
  final DateTime? joinedAt;

  /// The name a parent chose to show on chores, or null for the first name.
  final String? displayName;

  /// A member a parent added who has no login (always a child).
  final bool noLogin;

  /// Any joiner can write any fields on their own member doc, so a value of
  /// the wrong type falls back to "not set" instead of breaking the members
  /// stream for the whole family.
  factory Member.fromMap(String uid, Map<String, dynamic> m) {
    final name = m['name'];
    final color = m['color'];
    final photoUrl = m['photoUrl'];
    final displayName = m['displayName'];
    return Member(
      uid: uid,
      name: name is String ? name : '',
      role: m['role'] == 'parent' ? Role.parent : Role.child,
      color: color is int && color >= 0 && color <= 7 ? color : null,
      photoUrl: photoUrl is String ? photoUrl : null,
      pictureTiles: m['pictureTiles'] == true,
      joinedAt: _readMemberDate(m['joinedAt']),
      displayName: displayName is String && displayName.trim().isNotEmpty ? displayName : null,
      noLogin: m['noLogin'] == true,
    );
  }
}

/// Like [readDate], but anything that isn't a DateTime or a Timestamp reads as null.
DateTime? _readMemberDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    final date = (value as dynamic).toDate();
    return date is DateTime ? date : null;
  } on NoSuchMethodError {
    return null;
  }
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
