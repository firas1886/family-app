# Family App — Release 1 (Family Layer + Shopping) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a sideloadable Android app (Flutter + Firebase) where a family shares shopping lists. It covers join codes, parent/child roles, a shared catalog, one-tap buying with expiry-based auto-return, and a purchase history with optional prices.

**Architecture:** The code is layered one way: `lib/core` holds pure Dart (models, placement/sorting logic, text normalization) with no Flutter or Firebase imports; `lib/data` holds thin Firestore repositories; `lib/app` holds Riverpod providers, theme, formatting and localization glue; `lib/features/*` holds screens. Offline-capable writes are fired without awaiting, so the UI never blocks on the network. Permissions are enforced by `firestore.rules`, which is tested against the Firebase emulator.

**Naming note:** the category model is `ItemCategory`, to avoid clashing with Flutter's built-in `Category` annotation class.

**Tech Stack:** Flutter (stable channel), Dart 3, firebase_core, firebase_auth, google_sign_in (v6 API), cloud_firestore, flutter_riverpod 2.x, share_plus, intl, flutter_localizations (gen-l10n, ARB), fake_cloud_firestore for tests, Node 20 + @firebase/rules-unit-testing + mocha for rules tests, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-27-family-app-shopping-design.md`

## Global Constraints

- Android application id / namespace: `com.family.family_app`. Dart package name: `family_app`. App title: "Family".
- Minimum Android SDK: 24 (Android 7.0). Changed from 23 on 2026-09-28: Flutter 3.47.5 requires 24 and auto-raises it at build time.
- Dependency versions (use exactly these constraints): `firebase_core:^3.13.0`, `firebase_auth:^5.5.0`, `cloud_firestore:^5.6.0`, `google_sign_in:^6.2.2`, `flutter_riverpod:^2.6.1`, `share_plus:^10.1.4`, `intl:any`, `characters:any`, `flutter_localizations` (sdk), dev: `fake_cloud_firestore:^3.1.0`.
- Firestore paths and field names exactly as spec §3.
- Tile colors: To buy `0xFFEE6A6A`, Recently used `0xFF6DB5A8`. Background `0xFF2B3A42`.
- Recently used cap: 12. Undo window: 5 seconds. Currency: `"SAR"`. Units, in this order: `pcs, kg, g, L, ml, pack`.
- An `expiryDays` value of 0 or less is treated exactly like "no expiry".
- UI code must never `await` a Firestore write that should work offline (buy, undo, add, edit, remove). Use `fireAndForget(...)` from `lib/data/write.dart`. Only create/join family, regenerate code, and role changes are awaited, because they need a connection.
- Deviation from spec §7, required by Undo: a member may delete a purchase record they created within the last 10 minutes. All other purchase deletions are parent-only.
- `flutter analyze --no-fatal-infos` must report no errors or warnings. `flutter test` must pass.
- Rules tests need Node 20 and Java 17 or later (for the Firestore emulator).
- Never commit `android/key.properties`, `*.jks`, or `android/app/google-services.json`.

## Review Focus

1. **An entry whose catalog item was deleted on another phone while the list is open.** It must be skipped silently, with no crash and no empty tile. Test: Task 3, "entries whose item was deleted are skipped".
2. **Expiry days entered as 0, or as a negative number.** The item must not bounce straight back to To buy after being bought; it must behave as "no expiry". Tests: Task 3, "zero or negative expiry is treated as no expiry"; Task 9, "expiry 0 is saved as no expiry".
3. **A blank or whitespace-only name submitted in "I need…".** Nothing must be created or added. Tests: Task 6, "findByName returns null for blank input"; Task 10, "blank input adds nothing".
4. **A join code typed in lowercase, or with spaces** (as people retype codes from WhatsApp). It must still join. Test: Task 5, "joinFamily accepts a lowercase code with spaces".
5. **Tile letters for names with leading spaces, Arabic script, or a leading emoji.** The letter must be the first visible character, never a space or half an emoji. Test: Task 2, "tileLetter".

---

### Task 1: Project scaffold and CI

**Files:**
- Create (via `flutter create`): Flutter Android project in repo root
- Modify: `pubspec.yaml`, `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `.gitignore`, `lib/main.dart`
- Create: `.github/workflows/ci.yml`, `test/smoke_test.dart`
- Delete: `test/widget_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: a buildable Flutter project named `family_app`, and a CI workflow file (`ci.yml`) with a job `flutter` (Task 4 adds a `rules` job)

- [x] **Step 1: Create the project**

Run from the repository root, which already contains `docs/`:

```bash
flutter create --org com.family --project-name family_app --platforms android .
```

Expected: `All done!` and a `lib/main.dart` file.

- [x] **Step 2: Add dependencies**

```bash
flutter pub add firebase_core:^3.13.0 firebase_auth:^5.5.0 cloud_firestore:^5.6.0 google_sign_in:^6.2.2 flutter_riverpod:^2.6.1 share_plus:^10.1.4 intl:any characters:any 'flutter_localizations:{"sdk":"flutter"}'
flutter pub add --dev fake_cloud_firestore:^3.1.0
```

Expected: `Changed N dependencies!`

- [x] **Step 3: Register the Google services Gradle plugin**

In `android/settings.gradle.kts`, add this line inside the existing `plugins { ... }` block, after the `com.android.application` line:

```kotlin
    id("com.google.gms.google-services") version "4.4.2" apply false
```

- [x] **Step 4: Replace `android/app/build.gradle.kts`**

```kotlin
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.family.family_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.family.family_app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
```

Note: an Android build now requires `android/app/google-services.json`. That file is only present in the release workflow (Task 14). `flutter test` does not build Android, so CI tests are unaffected.

- [x] **Step 5: Ignore secrets**

Append to `.gitignore`:

```
# Signing and Firebase secrets — never commit
android/key.properties
*.jks
*.keystore
android/app/google-services.json
```

- [x] **Step 6: Replace `lib/main.dart` with a minimal app**

```dart
import 'package:flutter/material.dart';

void main() => runApp(const PlaceholderApp());

class PlaceholderApp extends StatelessWidget {
  const PlaceholderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Family'))),
    );
  }
}
```

- [x] **Step 7: Replace the generated counter test**

Delete `test/widget_test.dart`. Create `test/smoke_test.dart`:

```dart
import 'package:family_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const PlaceholderApp());
    expect(find.text('Family'), findsOneWidget);
  });
}
```

- [x] **Step 8: Add CI**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze --no-fatal-infos
      - run: flutter test
```

- [x] **Step 9: Verify**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: `No issues found!` (or infos only), then `All tests passed!`

- [x] **Step 10: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter Android project with Firebase deps and CI"
```

---

### Task 2: Text utilities (name matching, tile letters, join codes, number parsing)

**Files:**
- Create: `lib/core/text.dart`
- Test: `test/core/text_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `String nameKey(String input)`
  - `String tileLetter(String name)`
  - `String generateJoinCode([Random? random])` — 6 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`
  - `String normalizeJoinCode(String input)`
  - `int compareNames(String a, String b, String languageCode)`
  - `String formatNumber(double value)`
  - `double? parseNumber(String input)`

- [x] **Step 1: Write the failing tests**

Create `test/core/text_test.dart`:

```dart
import 'dart:math';

import 'package:family_app/core/text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nameKey', () {
    test('trims, lowercases and collapses spaces', () {
      expect(nameKey('  Olive   OIL '), 'olive oil');
    });
    test('removes Arabic diacritics', () {
      expect(nameKey('حَلِيب'), 'حليب');
    });
    test('unifies alef forms', () {
      expect(nameKey('أرز'), 'ارز');
      expect(nameKey('إناء'), 'اناء');
      expect(nameKey('آيس كريم'), 'ايس كريم');
    });
    test('treats taa marbuta as haa and alef maqsura as yaa', () {
      expect(nameKey('قهوة'), nameKey('قهوه'));
      expect(nameKey('مستشفى'), 'مستشفي');
    });
  });

  group('tileLetter', () {
    test('uppercases the first Latin letter', () {
      expect(tileLetter('milk'), 'M');
    });
    test('skips leading spaces and keeps Arabic letters', () {
      expect(tileLetter('   حليب'), 'ح');
    });
    test('keeps a whole emoji', () {
      expect(tileLetter('🍎 apples'), '🍎');
    });
    test('returns ? for blank names', () {
      expect(tileLetter('   '), '?');
    });
  });

  group('join codes', () {
    test('are 6 unambiguous characters', () {
      final code = generateJoinCode(Random(1));
      expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{6}$')));
    });
    test('normalize removes spaces and uppercases', () {
      expect(normalizeJoinCode(' ab c23 4 '), 'ABC234');
    });
  });

  group('compareNames', () {
    List<String> sorted(List<String> names, String lang) =>
        [...names]..sort((a, b) => compareNames(a, b, lang));

    test('ignores case', () {
      expect(sorted(['banana', 'Apple'], 'en'), ['Apple', 'banana']);
    });
    test('puts Latin first in English and Arabic first in Arabic', () {
      expect(sorted(['حليب', 'Milk', 'apple'], 'en'), ['apple', 'Milk', 'حليب']);
      expect(sorted(['Milk', 'حليب', 'apple'], 'ar'), ['حليب', 'apple', 'Milk']);
    });
  });

  group('numbers', () {
    test('formatNumber drops a trailing .0', () {
      expect(formatNumber(2), '2');
      expect(formatNumber(1.5), '1.5');
    });
    test('parseNumber accepts Western and Arabic digits and separators', () {
      expect(parseNumber('2.5'), 2.5);
      expect(parseNumber('1,5'), 1.5);
      expect(parseNumber('٢٫٥'), 2.5);
      expect(parseNumber('۳'), 3);
    });
    test('parseNumber returns null for blank or non-numeric input', () {
      expect(parseNumber(''), isNull);
      expect(parseNumber('  '), isNull);
      expect(parseNumber('abc'), isNull);
    });
  });
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/text_test.dart`
Expected: FAIL, compilation error `Target of URI doesn't exist: 'package:family_app/core/text.dart'`.

- [x] **Step 3: Implement**

Create `lib/core/text.dart`:

```dart
import 'dart:math';

import 'package:characters/characters.dart';

final _spaces = RegExp(r'\s+');
final _arabicDiacritics = RegExp('[\u064B-\u0652\u0670]');
final _alefVariants = RegExp('[\u0623\u0625\u0622]'); // أ إ آ

/// Normalized form used to decide whether two item names are the same item.
String nameKey(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(_spaces, ' ')
      .replaceAll(_arabicDiacritics, '')
      .replaceAll(_alefVariants, '\u0627') // ا
      .replaceAll('\u0629', '\u0647') // ة → ه
      .replaceAll('\u0649', '\u064A'); // ى → ي
}

/// The single character shown large on an item tile.
String tileLetter(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String generateJoinCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(
    6,
    (_) => _codeAlphabet[r.nextInt(_codeAlphabet.length)],
  ).join();
}

String normalizeJoinCode(String input) =>
    input.replaceAll(_spaces, '').toUpperCase();

bool _isArabicScript(String s) {
  if (s.isEmpty) return false;
  final c = s.codeUnitAt(0);
  return c >= 0x0600 && c <= 0x06FF;
}

/// Sorts names case-insensitively; the UI language's script sorts first.
int compareNames(String a, String b, String languageCode) {
  final ka = nameKey(a);
  final kb = nameKey(b);
  final aArabic = _isArabicScript(ka);
  final bArabic = _isArabicScript(kb);
  if (aArabic != bArabic) {
    final arabicFirst = languageCode == 'ar';
    return aArabic == arabicFirst ? -1 : 1;
  }
  return ka.compareTo(kb);
}

String formatNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// Parses user-typed numbers, accepting Arabic-Indic digits and , or ٫ as the decimal separator.
double? parseNumber(String input) {
  final buffer = StringBuffer();
  for (final rune in input.trim().runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + rune - 0x06F0);
    } else if (rune == 0x066B || rune == 0x2C) {
      buffer.write('.');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  final text = buffer.toString();
  if (text.isEmpty) return null;
  return double.tryParse(text);
}
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/text_test.dart`
Expected: PASS, `All tests passed!`

- [x] **Step 5: Commit**

```bash
git add lib/core/text.dart test/core/text_test.dart
git commit -m "feat(core): name matching, tile letters, join codes, number parsing"
```

---

### Task 3: Models and list placement logic

**Files:**
- Create: `lib/core/models.dart`, `lib/core/placement.dart`
- Modify (Step 5b only): `lib/core/text.dart`, `test/core/text_test.dart`
- Test: `test/core/models_test.dart`, `test/core/placement_test.dart`

**Interfaces:**
- Consumes: `nameKey`, `compareNames` (Task 2)
- Produces:
  - `enum Role { parent, child }`, `enum EntryStatus { toBuy, bought }`, `const List<String> units`
  - `DateTime? readDate(Object?)`, `double? readDouble(Object?)`, `int? readInt(Object?)`
  - Classes with `fromMap(String id, Map<String, dynamic>)`:
    - `AppUser{uid,name,email,familyId?,language?}`
    - `Family{id,name,joinCode}`
    - `Member{uid,name,role}`
    - `ItemCategory{id,name,isDefault}`
    - `ShoppingList{id,name}`
    - `Item{id,name,categoryId,quantity?,unit?,notes,expiryDays?}` with `key`, `effectiveExpiryDays`, `toMap()`
    - `Entry{itemId,status,addedBy?,addedAt?,boughtBy?,boughtAt?}` with `toMap()`
    - `Purchase{id,itemId,itemName,categoryName,listId,listName,quantity?,unit?,price?,currency,boughtBy,boughtByName,boughtAt}` with `toMap()`
  - `const recentlyUsedCap = 12`, `enum SortMode { category, alphabetical }`
  - `class TileView{item, entry, daysLeft?}`
  - `class CategoryGroup<T>{category?, members}`
  - `class ListSections{toBuy: List<CategoryGroup<TileView>>, recentlyUsed: List<TileView>, bool isOnToBuy(String itemId)}`
  - `DateTime? dueAt(Item, Entry)`, `int daysLeft(DateTime due, DateTime now)`, `bool isOnToBuy(Item, Entry, DateTime now)`
  - `ListSections buildSections({required Iterable<Entry> entries, required Map<String, Item> items, required Map<String, ItemCategory> categories, required DateTime now, required SortMode sort, required String languageCode})`
  - `int compareCategories(ItemCategory? a, ItemCategory? b, String languageCode)`
  - `List<CategoryGroup<Item>> catalogGroups({required Iterable<Item> items, required Map<String, ItemCategory> categories, required String languageCode})`

- [x] **Step 1: Write the failing model tests**

Create `test/core/models_test.dart`:

```dart
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
```

- [x] **Step 2: Write the failing placement tests**

Create `test/core/placement_test.dart`:

```dart
import 'package:family_app/core/models.dart';
import 'package:family_app/core/placement.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 1, 12);
const other = ItemCategory(id: 'other', name: 'Other', isDefault: true);
const dairy = ItemCategory(id: 'dairy', name: 'Dairy', isDefault: false);
const bakery = ItemCategory(id: 'bakery', name: 'Bakery', isDefault: false);
final categories = {for (final c in [other, dairy, bakery]) c.id: c};

Item item(String id, {String? name, String cat = 'other', int? expiry}) =>
    Item(id: id, name: name ?? id, categoryId: cat, expiryDays: expiry);
Entry toBuy(String id) => Entry(itemId: id, status: EntryStatus.toBuy);
Entry bought(String id, Duration ago) =>
    Entry(itemId: id, status: EntryStatus.bought, boughtAt: now.subtract(ago));

ListSections build(List<Item> items, List<Entry> entries,
        {SortMode sort = SortMode.category, String lang = 'en'}) =>
    buildSections(
      entries: entries,
      items: {for (final i in items) i.id: i},
      categories: categories,
      now: now,
      sort: sort,
      languageCode: lang,
    );

List<String> toBuyIds(ListSections s) =>
    [for (final g in s.toBuy) for (final t in g.members) t.item.id];
List<String> recentIds(ListSections s) =>
    [for (final t in s.recentlyUsed) t.item.id];

void main() {
  group('placement', () {
    test('toBuy entries appear in To buy', () {
      final s = build([item('milk')], [toBuy('milk')]);
      expect(toBuyIds(s), ['milk']);
      expect(s.recentlyUsed, isEmpty);
    });

    test('bought and not yet due appears in Recently used with days left', () {
      final s = build([item('milk', expiry: 7)], [bought('milk', const Duration(days: 2))]);
      expect(recentIds(s), ['milk']);
      expect(s.recentlyUsed.single.daysLeft, 5);
    });

    test('partial days round up', () {
      final s = build([item('milk', expiry: 3)], [bought('milk', const Duration(hours: 36))]);
      expect(s.recentlyUsed.single.daysLeft, 2);
    });

    test('returns to To buy exactly when due', () {
      final s = build([item('milk', expiry: 7)], [bought('milk', const Duration(days: 7))]);
      expect(toBuyIds(s), ['milk']);
      expect(s.recentlyUsed, isEmpty);
    });

    test('returns to To buy after due', () {
      final s = build([item('milk', expiry: 7)], [bought('milk', const Duration(days: 8))]);
      expect(toBuyIds(s), ['milk']);
    });

    test('no expiry stays in Recently used without countdown', () {
      final s = build([item('salt')], [bought('salt', const Duration(days: 90))]);
      expect(recentIds(s), ['salt']);
      expect(s.recentlyUsed.single.daysLeft, isNull);
    });

    test('zero or negative expiry is treated as no expiry', () {
      final s = build(
        [item('a', expiry: 0), item('b', expiry: -3)],
        [bought('a', const Duration(days: 1)), bought('b', const Duration(days: 1))],
      );
      expect(toBuyIds(s), isEmpty);
      expect(recentIds(s).toSet(), {'a', 'b'});
      expect(s.recentlyUsed.every((t) => t.daysLeft == null), isTrue);
    });

    test('countdown items first, soonest due first; then no-expiry newest first', () {
      final s = build(
        [item('a', expiry: 10), item('b', expiry: 3), item('c'), item('d')],
        [
          bought('a', const Duration(days: 1)), // due in 9 days
          bought('b', const Duration(days: 1)), // due in 2 days
          bought('c', const Duration(days: 5)),
          bought('d', const Duration(days: 1)),
        ],
      );
      expect(recentIds(s), ['b', 'a', 'd', 'c']);
    });

    test('Recently used is capped at 12', () {
      final items = [for (var i = 0; i < 15; i++) item('i$i', expiry: 30)];
      final entries = [for (var i = 0; i < 15; i++) bought('i$i', Duration(hours: i + 1))];
      expect(build(items, entries).recentlyUsed.length, 12);
    });

    test('entries whose item was deleted are skipped', () {
      final s = build(
        [item('milk')],
        [toBuy('milk'), toBuy('ghost'), bought('ghost2', const Duration(days: 1))],
      );
      expect(toBuyIds(s), ['milk']);
      expect(s.recentlyUsed, isEmpty);
    });

    test('changing expiry days takes effect immediately', () {
      final entry = bought('milk', const Duration(days: 5));
      expect(recentIds(build([item('milk', expiry: 7)], [entry])), ['milk']);
      expect(toBuyIds(build([item('milk', expiry: 3)], [entry])), ['milk']);
    });

    test('isOnToBuy reports items on To buy', () {
      final s = build([item('milk'), item('salt')], [toBuy('milk'), bought('salt', const Duration(days: 1))]);
      expect(s.isOnToBuy('milk'), isTrue);
      expect(s.isOnToBuy('salt'), isFalse);
    });
  });

  group('grouping', () {
    final shop = [
      item('cheese', cat: 'dairy'),
      item('milk', cat: 'dairy'),
      item('bread', cat: 'bakery'),
      item('zaatar'),
      item('apples'),
    ];
    final allToBuy = [for (final i in shop) toBuy(i.id)];

    test('To buy is grouped by category, Other last, names A–Z', () {
      final s = build(shop, allToBuy);
      expect(s.toBuy.map((g) => g.category!.id).toList(), ['bakery', 'dairy', 'other']);
      expect(toBuyIds(s), ['bread', 'cheese', 'milk', 'apples', 'zaatar']);
    });

    test('items with an unknown category fall into Other', () {
      final s = build([item('x', cat: 'deleted')], [toBuy('x')]);
      expect(s.toBuy.single.category!.id, 'other');
    });

    test('alphabetical mode is one flat group without a category', () {
      final s = build(shop, allToBuy, sort: SortMode.alphabetical);
      expect(s.toBuy.length, 1);
      expect(s.toBuy.single.category, isNull);
      expect(toBuyIds(s), ['apples', 'bread', 'cheese', 'milk', 'zaatar']);
    });

    test('Arabic names sort first in the Arabic UI', () {
      final s = build(
        [item('m', name: 'Milk'), item('h', name: 'حليب')],
        [toBuy('m'), toBuy('h')],
        sort: SortMode.alphabetical,
        lang: 'ar',
      );
      expect(toBuyIds(s), ['h', 'm']);
    });

    test('catalogGroups includes empty categories, Other last', () {
      final groups = catalogGroups(
        items: [item('milk', cat: 'dairy')],
        categories: categories,
        languageCode: 'en',
      );
      expect(groups.map((g) => g.category!.id).toList(), ['bakery', 'dairy', 'other']);
      expect(groups.first.members, isEmpty);
      expect(groups[1].members.single.id, 'milk');
    });
  });
}
```

- [x] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/core`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/core/models.dart'`.

- [x] **Step 4: Implement models**

Create `lib/core/models.dart`:

```dart
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
```

- [x] **Step 5: Implement placement**

Create `lib/core/placement.dart`:

```dart
import 'models.dart';
import 'text.dart';

const recentlyUsedCap = 12;

enum SortMode { category, alphabetical }

class TileView {
  const TileView({required this.item, required this.entry, this.daysLeft});
  final Item item;
  final Entry entry;
  final int? daysLeft;
}

class CategoryGroup<T> {
  const CategoryGroup(this.category, this.members);

  /// Null only for the single flat group in alphabetical mode.
  final ItemCategory? category;
  final List<T> members;
}

class ListSections {
  const ListSections({required this.toBuy, required this.recentlyUsed});
  final List<CategoryGroup<TileView>> toBuy;
  final List<TileView> recentlyUsed;

  bool isOnToBuy(String itemId) =>
      toBuy.any((g) => g.members.any((t) => t.item.id == itemId));
}

DateTime? dueAt(Item item, Entry entry) {
  final days = item.effectiveExpiryDays;
  final bought = entry.boughtAt;
  if (entry.status != EntryStatus.bought || days == null || bought == null) {
    return null;
  }
  return bought.add(Duration(days: days));
}

int daysLeft(DateTime due, DateTime now) =>
    (due.difference(now).inMinutes / Duration.minutesPerDay).ceil();

bool isOnToBuy(Item item, Entry entry, DateTime now) {
  if (entry.status == EntryStatus.toBuy) return true;
  final due = dueAt(item, entry);
  return due != null && !due.isAfter(now);
}

ListSections buildSections({
  required Iterable<Entry> entries,
  required Map<String, Item> items,
  required Map<String, ItemCategory> categories,
  required DateTime now,
  required SortMode sort,
  required String languageCode,
}) {
  final toBuy = <TileView>[];
  final counting = <TileView>[];
  final open = <TileView>[];

  for (final entry in entries) {
    final item = items[entry.itemId];
    if (item == null) continue; // item deleted from catalog
    if (isOnToBuy(item, entry, now)) {
      toBuy.add(TileView(item: item, entry: entry));
      continue;
    }
    final due = dueAt(item, entry);
    if (due != null) {
      counting.add(TileView(item: item, entry: entry, daysLeft: daysLeft(due, now)));
    } else {
      open.add(TileView(item: item, entry: entry));
    }
  }

  counting.sort((a, b) => dueAt(a.item, a.entry)!.compareTo(dueAt(b.item, b.entry)!));
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  open.sort((a, b) => (b.entry.boughtAt ?? epoch).compareTo(a.entry.boughtAt ?? epoch));

  return ListSections(
    toBuy: _groupTiles(toBuy, categories, sort, languageCode),
    recentlyUsed: [...counting, ...open].take(recentlyUsedCap).toList(),
  );
}

/// Other (default) last, the rest by name.
int compareCategories(ItemCategory? a, ItemCategory? b, String languageCode) {
  final aDefault = a?.isDefault ?? true;
  final bDefault = b?.isDefault ?? true;
  if (aDefault != bDefault) return aDefault ? 1 : -1;
  return compareNames(a?.name ?? '', b?.name ?? '', languageCode);
}

List<CategoryGroup<T>> _groupByCategory<T>({
  required Iterable<T> things,
  required Item Function(T) itemOf,
  required Map<String, ItemCategory> categories,
  required String languageCode,
}) {
  ItemCategory? other;
  for (final c in categories.values) {
    if (c.isDefault) other = c;
  }
  final buckets = <String, List<T>>{};
  final bucketCategory = <String, ItemCategory?>{};
  for (final thing in things) {
    final category = categories[itemOf(thing).categoryId] ?? other;
    final key = category?.id ?? '';
    bucketCategory[key] = category;
    buckets.putIfAbsent(key, () => []).add(thing);
  }
  final groups = [
    for (final e in buckets.entries)
      CategoryGroup<T>(
        bucketCategory[e.key],
        e.value..sort((a, b) => compareNames(itemOf(a).name, itemOf(b).name, languageCode)),
      ),
  ];
  groups.sort((a, b) => compareCategories(a.category, b.category, languageCode));
  return groups;
}

List<CategoryGroup<TileView>> _groupTiles(
  List<TileView> tiles,
  Map<String, ItemCategory> categories,
  SortMode sort,
  String languageCode,
) {
  if (sort == SortMode.alphabetical) {
    if (tiles.isEmpty) return [];
    final sorted = [...tiles]
      ..sort((a, b) => compareNames(a.item.name, b.item.name, languageCode));
    return [CategoryGroup<TileView>(null, sorted)];
  }
  return _groupByCategory<TileView>(
    things: tiles,
    itemOf: (t) => t.item,
    categories: categories,
    languageCode: languageCode,
  );
}

/// The full catalog for the Categories section, including empty categories.
List<CategoryGroup<Item>> catalogGroups({
  required Iterable<Item> items,
  required Map<String, ItemCategory> categories,
  required String languageCode,
}) {
  final grouped = _groupByCategory<Item>(
    things: items,
    itemOf: (i) => i,
    categories: categories,
    languageCode: languageCode,
  );
  final present = grouped.map((g) => g.category?.id).toSet();
  final all = [
    ...grouped,
    for (final c in categories.values)
      if (!present.contains(c.id)) CategoryGroup<Item>(c, <Item>[]),
  ];
  all.sort((a, b) => compareCategories(a.category, b.category, languageCode));
  return all;
}
```

- [x] **Step 5b: Harden text utilities (added 2026-09-28, auto-decided after Task 2 test)**

Test first: append to `test/core/text_test.dart` (inside `main()`):

```dart
  group('hardening', () {
    test('invisible direction marks are ignored', () {
      expect(nameKey('‏حليب‎'), 'حليب');
      expect(nameKey('﻿ Milk'), nameKey('Milk'));
      expect(tileLetter('‏ حليب'), 'ح');
      expect(tileLetter('​'), '?');
    });
    test('parseNumber rejects non-finite and negative values', () {
      expect(parseNumber('NaN'), isNull);
      expect(parseNumber('Infinity'), isNull);
      expect(parseNumber('-1'), isNull);
      expect(parseNumber('0'), 0);
    });
  });
```

Then in `lib/core/text.dart`: add
`final _invisible = RegExp('[​‎‏‪-‮⁦-⁩؜﻿]');`
(ZWJ/ZWNJ `‌‍` are deliberately kept: emoji sequences need them). In `nameKey` and `tileLetter`, call `.replaceAll(_invisible, '')` on the input before `.trim()`. In `parseNumber`, replace `return double.tryParse(text);` with:
`final value = double.tryParse(text); return (value != null && value.isFinite && value >= 0) ? value : null;`

- [x] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/core`
Expected: PASS, `All tests passed!`

- [x] **Step 7: Commit**

```bash
git add lib/core test/core
git commit -m "feat(core): models and To buy / Recently used placement logic"
```

---
### Task 4: Firestore security rules with emulator tests

**Files:**
- Create: `firestore.rules`, `firebase.json`, `rules-tests/package.json`, `rules-tests/test/rules.test.js`
- Modify: `.github/workflows/ci.yml` (add the `rules` job)

**Interfaces:**
- Consumes: the data model in spec §3
- Produces: `firestore.rules`, the file Firas pastes into the Firebase console (Task 14). Later tasks' repositories must only perform writes these rules allow. In particular, `createFamily` must keep its three-step order (family doc with `joinCode` → own parent member doc without `joinCode` → batch of join code + Other category + user doc): the rules only let the creator make themselves parent while the family's `joinCodes` doc does not exist yet. `joinFamily` must write `joinCode` (the normalized code used) on the child member doc; the rules check it against the family's current code and its `joinCodes` doc.

- [x] **Step 1: Write the failing rules tests**

Create `firebase.json`:

```json
{
  "firestore": { "rules": "firestore.rules" },
  "emulators": { "firestore": { "port": 8080 }, "singleProjectMode": true }
}
```

Create `rules-tests/package.json`:

```json
{
  "name": "rules-tests",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "mocha --timeout 15000 'test/**/*.test.js'",
    "emulate": "firebase emulators:exec --project demo-family --only firestore --config ../firebase.json 'npm test'"
  },
  "devDependencies": {
    "@firebase/rules-unit-testing": "^4.0.1",
    "firebase": "^11.0.0",
    "firebase-tools": "^13.0.0",
    "mocha": "^10.0.0"
  }
}
```

Create `rules-tests/test/rules.test.js`:

```js
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc, Timestamp,
} from 'firebase/firestore';

const F = 'fam1';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-family',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `families/${F}`), { name: 'Home', joinCode: 'ABC234', createdBy: 'dad' });
    await setDoc(doc(db, `families/${F}/members/dad`), { name: 'Dad', role: 'parent' });
    await setDoc(doc(db, `families/${F}/members/kid`), { name: 'Kid', role: 'child' });
    await setDoc(doc(db, `families/${F}/categories/other`), { name: 'Other', isDefault: true });
    await setDoc(doc(db, `families/${F}/categories/dairy`), { name: 'Dairy', isDefault: false });
    await setDoc(doc(db, `families/${F}/items/milk`), { name: 'Milk', nameKey: 'milk', categoryId: 'dairy' });
    await setDoc(doc(db, `families/${F}/lists/home`), { name: 'Home' });
    await setDoc(doc(db, `families/${F}/lists/home/entries/milk`), { itemId: 'milk', status: 'toBuy' });
    await setDoc(doc(db, `families/${F}/purchases/old`), {
      itemId: 'milk', itemName: 'Milk', boughtBy: 'kid', price: null,
      boughtAt: Timestamp.fromDate(new Date(Date.now() - 60 * 60 * 1000)),
    });
    await setDoc(doc(db, 'joinCodes/ABC234'), { familyId: F });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('family data', () => {
  it('outsiders cannot read family data', async () => {
    await assertFails(getDoc(doc(as('stranger'), `families/${F}/items/milk`)));
    await assertFails(getDoc(doc(anon(), `families/${F}`)));
  });
  it('members can read family data', async () => {
    await assertSucceeds(getDoc(doc(as('kid'), `families/${F}/items/milk`)));
    await assertSucceeds(getDocs(collection(as('kid'), `families/${F}/members`)));
  });
});

describe('items', () => {
  it('children can create and edit items', async () => {
    await assertSucceeds(setDoc(doc(as('kid'), `families/${F}/items/bread`), { name: 'Bread', nameKey: 'bread', categoryId: 'other' }));
    await assertSucceeds(updateDoc(doc(as('kid'), `families/${F}/items/milk`), { expiryDays: 5 }));
  });
  it('only parents delete items', async () => {
    await assertFails(deleteDoc(doc(as('kid'), `families/${F}/items/milk`)));
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/items/milk`)));
  });
});

describe('categories', () => {
  it('children can add a normal category but not a default one', async () => {
    await assertSucceeds(setDoc(doc(as('kid'), `families/${F}/categories/frozen`), { name: 'Frozen', isDefault: false }));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/categories/other2`), { name: 'Other', isDefault: true }));
  });
  it('only parents rename categories', async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/categories/dairy`), { name: 'Milk stuff' }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/categories/dairy`), { name: 'Milk stuff' }));
  });
  it('parents delete normal categories but never Other', async () => {
    await assertFails(deleteDoc(doc(as('kid'), `families/${F}/categories/dairy`)));
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/categories/dairy`)));
    await assertFails(deleteDoc(doc(as('dad'), `families/${F}/categories/other`)));
  });
});

describe('lists and entries', () => {
  it('only parents create, rename and delete lists', async () => {
    await assertFails(setDoc(doc(as('kid'), `families/${F}/lists/pharmacy`), { name: 'Pharmacy' }));
    await assertSucceeds(setDoc(doc(as('dad'), `families/${F}/lists/pharmacy`), { name: 'Pharmacy' }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/lists/home`), { name: 'House' }));
    await assertFails(deleteDoc(doc(as('kid'), `families/${F}/lists/home`)));
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/lists/home`)));
  });
  it('children add, buy and remove entries', async () => {
    const db = as('kid');
    await assertSucceeds(setDoc(doc(db, `families/${F}/lists/home/entries/bread`), { itemId: 'bread', status: 'toBuy' }));
    await assertSucceeds(updateDoc(doc(db, `families/${F}/lists/home/entries/milk`), { status: 'bought' }));
    await assertSucceeds(deleteDoc(doc(db, `families/${F}/lists/home/entries/milk`)));
  });
});

describe('purchases', () => {
  it('members record their own purchases only', async () => {
    const data = { itemId: 'milk', boughtBy: 'kid', boughtAt: Timestamp.now(), price: null };
    await assertSucceeds(setDoc(doc(as('kid'), `families/${F}/purchases/p2`), data));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/purchases/p3`), { ...data, boughtBy: 'dad' }));
  });
  it('anyone can set a price but nothing else', async () => {
    await assertSucceeds(updateDoc(doc(as('kid'), `families/${F}/purchases/old`), { price: 12.5 }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/purchases/old`), { itemName: 'Cheese' }));
  });
  it('the buyer can undo within 10 minutes; later only parents delete', async () => {
    await setDoc(doc(as('kid'), `families/${F}/purchases/fresh`), { itemId: 'milk', boughtBy: 'kid', boughtAt: Timestamp.now(), price: null });
    await assertSucceeds(deleteDoc(doc(as('kid'), `families/${F}/purchases/fresh`)));
    await assertFails(deleteDoc(doc(as('kid'), `families/${F}/purchases/old`)));
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/purchases/old`)));
  });
  it('a purchase cannot be dated in the future', async () => {
    const inAnHour = Timestamp.fromDate(new Date(Date.now() + 60 * 60 * 1000));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/purchases/p4`), { itemId: 'milk', boughtBy: 'kid', boughtAt: inAnHour, price: null }));
  });
  it('a purchase must have a purchase time', async () => {
    await assertFails(setDoc(doc(as('kid'), `families/${F}/purchases/p5`), { itemId: 'milk', boughtBy: 'kid', price: null }));
  });
  it('an offline-queued purchase from days ago still syncs', async () => {
    const twoDaysAgo = Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000));
    await assertSucceeds(setDoc(doc(as('kid'), `families/${F}/purchases/p6`), { itemId: 'milk', boughtBy: 'kid', boughtAt: twoDaysAgo, price: null }));
  });
  it('a phone clock a little ahead is tolerated', async () => {
    const inTwoMinutes = Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 1000));
    await assertSucceeds(setDoc(doc(as('kid'), `families/${F}/purchases/p7`), { itemId: 'milk', boughtBy: 'kid', boughtAt: inTwoMinutes, price: null }));
  });
  it('the purchase time can never be changed', async () => {
    const tomorrow = Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/purchases/old`), { boughtAt: tomorrow }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/purchases/old`), { price: 5, boughtAt: tomorrow }));
  });
});

describe('members and joining', () => {
  it('only parents change roles', async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { role: 'parent' }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { role: 'parent' }));
  });
  it('children cannot remove others but can leave', async () => {
    await assertFails(deleteDoc(doc(as('kid'), `families/${F}/members/dad`)));
    await assertSucceeds(deleteDoc(doc(as('kid'), `families/${F}/members/kid`)));
  });
  it('parents can remove members', async () => {
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/members/kid`)));
  });
  it('a newcomer can join as child but not as parent', async () => {
    await assertFails(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'parent', joinCode: 'ABC234' }));
    await assertSucceeds(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'child', joinCode: 'ABC234' }));
  });
  it('joining needs a join code', async () => {
    await assertFails(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'child' }));
  });
  it('joining with a wrong code fails', async () => {
    await assertFails(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'child', joinCode: 'ZZZ999' }));
  });
  it("another family's code does not open this family", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'families/fam2'), { name: 'Other home', joinCode: 'OTH234', createdBy: 'gran' });
      await setDoc(doc(db, 'joinCodes/OTH234'), { familyId: 'fam2' });
    });
    await assertFails(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'child', joinCode: 'OTH234' }));
  });
  it('the old code stops working after regeneration', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await deleteDoc(doc(db, 'joinCodes/ABC234'));
      await setDoc(doc(db, 'joinCodes/NEW234'), { familyId: F });
      await updateDoc(doc(db, `families/${F}`), { joinCode: 'NEW234' });
    });
    await assertFails(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'child', joinCode: 'ABC234' }));
    await assertSucceeds(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'child', joinCode: 'NEW234' }));
  });
  it('a removed user can still read their own (missing) member doc', async () => {
    await assertSucceeds(getDoc(doc(as('stranger'), `families/${F}/members/stranger`)));
  });
  it('the creator can make themselves parent of a new family', async () => {
    const db = as('newbie');
    await assertSucceeds(setDoc(doc(db, 'families/fam2'), { name: 'New', joinCode: 'XYZ789', createdBy: 'newbie' }));
    await assertSucceeds(setDoc(doc(db, 'families/fam2/members/newbie'), { name: 'N', role: 'parent' }));
    await assertSucceeds(setDoc(doc(db, 'joinCodes/XYZ789'), { familyId: 'fam2' }));
    await assertSucceeds(setDoc(doc(db, 'families/fam2/categories/o'), { name: 'Other', isDefault: true }));
    await assertSucceeds(setDoc(doc(db, 'users/newbie'), { familyId: 'fam2' }, { merge: true }));
  });
  it('after setup the creator cannot re-make themselves parent', async () => {
    const db = as('newbie');
    await setDoc(doc(db, 'families/fam2'), { name: 'New', joinCode: 'XYZ789', createdBy: 'newbie' });
    await setDoc(doc(db, 'families/fam2/members/newbie'), { name: 'N', role: 'parent' });
    await setDoc(doc(db, 'joinCodes/XYZ789'), { familyId: 'fam2' });
    await setDoc(doc(db, 'families/fam2/categories/o'), { name: 'Other', isDefault: true });
    await setDoc(doc(db, 'users/newbie'), { familyId: 'fam2' }, { merge: true });
    await assertSucceeds(deleteDoc(doc(db, 'families/fam2/members/newbie')));
    await assertFails(setDoc(doc(db, 'families/fam2/members/newbie'), { name: 'N', role: 'parent' }));
  });
  it('a removed creator cannot rejoin as parent', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `families/${F}/members/gran`), { name: 'Gran', role: 'parent' });
      await deleteDoc(doc(db, `families/${F}/members/dad`));
    });
    await assertFails(setDoc(doc(as('dad'), `families/${F}/members/dad`), { name: 'Dad', role: 'parent' }));
  });
  it('a demoted creator who left cannot come back as parent', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await updateDoc(doc(db, `families/${F}/members/dad`), { role: 'child' });
      await setDoc(doc(db, `families/${F}/members/gran`), { name: 'Gran', role: 'parent' });
    });
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/members/dad`)));
    await assertFails(setDoc(doc(as('dad'), `families/${F}/members/dad`), { name: 'Dad', role: 'parent' }));
  });
});

describe('join codes', () => {
  it('signed-in users can look up a code but not list them', async () => {
    await assertSucceeds(getDoc(doc(as('mum'), 'joinCodes/ABC234')));
    await assertFails(getDocs(collection(as('mum'), 'joinCodes')));
    await assertFails(getDoc(doc(anon(), 'joinCodes/ABC234')));
  });
  it('only parents of the family create or delete codes', async () => {
    await assertFails(setDoc(doc(as('kid'), 'joinCodes/NEW234'), { familyId: F }));
    await assertSucceeds(setDoc(doc(as('dad'), 'joinCodes/NEW234'), { familyId: F }));
    await assertSucceeds(deleteDoc(doc(as('dad'), 'joinCodes/ABC234')));
  });
  it('only parents update the family join code', async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}`), { joinCode: 'NEW234' }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}`), { joinCode: 'NEW234' }));
  });
});

describe('users', () => {
  it('users only access their own user doc', async () => {
    await assertSucceeds(setDoc(doc(as('kid'), 'users/kid'), { name: 'Kid', familyId: F }));
    await assertFails(setDoc(doc(as('kid'), 'users/dad'), { familyId: null }));
    await assertFails(getDoc(doc(as('kid'), 'users/dad')));
  });
});
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `cd rules-tests && npm install && npm run emulate`
Expected: FAIL. The emulator reports that `firestore.rules` can't be found, or every assertion fails.

- [x] **Step 3: Write the rules**

Create `firestore.rules`:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() { return request.auth != null; }
    function uid() { return request.auth.uid; }
    function familyPath(f) { return /databases/$(database)/documents/families/$(f); }
    function joinCodePath(c) { return /databases/$(database)/documents/joinCodes/$(c); }
    function memberPath(f) { return /databases/$(database)/documents/families/$(f)/members/$(uid()); }
    function isMember(f) { return signedIn() && exists(memberPath(f)); }
    function isParent(f) { return isMember(f) && get(memberPath(f)).data.role == 'parent'; }
    function onlyChanges(keys) {
      return request.resource.data.diff(resource.data).affectedKeys().hasOnly(keys);
    }

    match /users/{userId} {
      allow read, write: if signedIn() && uid() == userId;
    }

    match /joinCodes/{code} {
      allow get: if signedIn();
      allow list: if false;
      allow create: if isParent(request.resource.data.familyId);
      allow delete: if isParent(resource.data.familyId);
    }

    match /families/{f} {
      allow get: if isMember(f);
      allow create: if signedIn() && request.resource.data.createdBy == uid();
      allow update: if isParent(f) && onlyChanges(['name', 'joinCode']);

      match /members/{m} {
        allow read: if isMember(f) || (signedIn() && uid() == m);
        allow create: if signedIn() && uid() == m && (
          (request.resource.data.role == 'child'
            && request.resource.data.joinCode is string
            && request.resource.data.joinCode == get(familyPath(f)).data.joinCode
            && exists(joinCodePath(request.resource.data.joinCode))
            && get(joinCodePath(request.resource.data.joinCode)).data.familyId == f)
          || (request.resource.data.role == 'parent'
            && get(familyPath(f)).data.createdBy == uid()
            && !exists(joinCodePath(get(familyPath(f)).data.joinCode)))
        );
        allow update: if isParent(f) && onlyChanges(['role'])
          && request.resource.data.role in ['parent', 'child'];
        allow delete: if isParent(f) || (signedIn() && uid() == m);
      }

      match /categories/{c} {
        allow read: if isMember(f);
        allow create: if (isMember(f) && request.resource.data.isDefault == false)
          || (isParent(f) && request.resource.data.isDefault == true);
        allow update: if isParent(f) && onlyChanges(['name']);
        allow delete: if isParent(f) && resource.data.isDefault == false;
      }

      match /items/{i} {
        allow read, create, update: if isMember(f);
        allow delete: if isParent(f);
      }

      match /lists/{l} {
        allow read: if isMember(f);
        allow create, update, delete: if isParent(f);

        match /entries/{e} {
          allow read, create, update, delete: if isMember(f);
        }
      }

      match /purchases/{p} {
        allow read: if isMember(f);
        allow create: if isMember(f) && request.resource.data.boughtBy == uid()
          && request.resource.data.boughtAt is timestamp
          && request.resource.data.boughtAt <= request.time + duration.value(5, 'm');
        allow update: if isMember(f) && onlyChanges(['price']);
        allow delete: if isParent(f) || (
          isMember(f) && resource.data.boughtBy == uid()
          && request.time < resource.data.boughtAt + duration.value(10, 'm')
        );
      }
    }
  }
}
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `cd rules-tests && npm run emulate`
Expected: PASS, `34 passing`, with no failures.

- [x] **Step 5: Add the rules job to CI**

In `.github/workflows/ci.yml`, add this under `jobs:`, as a sibling of `flutter:`:

```yaml
  rules:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
      - run: npm install
        working-directory: rules-tests
      - run: npm run emulate
        working-directory: rules-tests
```

Also add `rules-tests/node_modules/` to `.gitignore`.

- [x] **Step 6: Commit**

```bash
git add firestore.rules firebase.json rules-tests/package.json rules-tests/test .github/workflows/ci.yml .gitignore
git commit -m "feat(rules): Firestore security rules with emulator tests"
```

---

### Task 5: Family repository (users, create/join, roles, join codes)

**Files:**
- Create: `lib/data/family_repository.dart`
- Test: `test/data/family_repository_test.dart`

**Interfaces:**
- Consumes: `AppUser`, `Family`, `Member`, `Role` (Task 3); `generateJoinCode`, `normalizeJoinCode` (Task 2)
- Produces:
  - `class JoinCodeNotFound implements Exception`, `class LastParentException implements Exception`
  - `class FamilyRepository(FirebaseFirestore db)` with:
    - `Stream<AppUser?> watchUser(String uid)`
    - `Future<void> ensureUser({required String uid, required String name, required String email, required String language})`
    - `Future<void> setLanguage(String uid, String language)`
    - `Future<String> createFamily({required String uid, required String userName, required String familyName, required String otherCategoryName})`
    - `Future<String> joinFamily({required String uid, required String userName, required String code})`
    - `Stream<Family?> watchFamily(String familyId)`
    - `Stream<List<Member>> watchMembers(String familyId)`
    - `Stream<Member?> watchMember(String familyId, String uid)`
    - `Future<void> setRole(String familyId, String memberUid, Role role)`
    - `Future<void> removeMember(String familyId, String memberUid)`
    - `Future<void> leaveFamily(String familyId, String uid)`
    - `Future<void> clearFamily(String uid)`
    - `Future<String> regenerateCode(String familyId)`

- [x] **Step 1: Write the failing tests**

Create `test/data/family_repository_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/data/family_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FamilyRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FamilyRepository(db);
  });

  Future<String> createAsDad() async {
    await repo.ensureUser(uid: 'u1', name: 'Dad', email: 'dad@x.com', language: 'en');
    return repo.createFamily(uid: 'u1', userName: 'Dad', familyName: 'Home', otherCategoryName: 'Other');
  }

  test('ensureUser creates the user once and never overwrites', () async {
    await repo.ensureUser(uid: 'u1', name: 'Dad', email: 'dad@x.com', language: 'ar');
    await repo.ensureUser(uid: 'u1', name: 'Changed', email: 'dad@x.com', language: 'en');
    final user = await repo.watchUser('u1').first;
    expect(user!.name, 'Dad');
    expect(user.language, 'ar');
    expect(user.familyId, isNull);
  });

  test('createFamily makes the creator a parent and seeds Other', () async {
    final f = await createAsDad();
    final family = await repo.watchFamily(f).first;
    expect(family!.name, 'Home');
    expect(family.joinCode, matches(RegExp(r'^[A-HJ-NP-Z2-9]{6}$')));
    final code = await db.doc('joinCodes/${family.joinCode}').get();
    expect(code.data()!['familyId'], f);
    expect((await repo.watchMember(f, 'u1').first)!.role, Role.parent);
    final cats = await db.collection('families/$f/categories').get();
    expect(cats.docs.single.data()['isDefault'], true);
    expect(cats.docs.single.data()['name'], 'Other');
    expect((await repo.watchUser('u1').first)!.familyId, f);
  });

  test('joinFamily accepts a lowercase code with spaces and joins as child', () async {
    final f = await createAsDad();
    final code = (await repo.watchFamily(f).first)!.joinCode.toLowerCase();
    final typed = ' ${code.substring(0, 3)} ${code.substring(3)} ';
    final joined = await repo.joinFamily(uid: 'u2', userName: 'Sara', code: typed);
    expect(joined, f);
    expect((await repo.watchMember(f, 'u2').first)!.role, Role.child);
    expect((await db.doc('families/$f/members/u2').get()).data()!['joinCode'], code.toUpperCase());
    expect((await repo.watchUser('u2').first)!.familyId, f);
  });

  test('joinFamily rejects unknown or malformed codes', () async {
    await createAsDad();
    for (final bad in ['ZZZZZZ', '', 'abc']) {
      await expectLater(
        repo.joinFamily(uid: 'u2', userName: 'Sara', code: bad),
        throwsA(isA<JoinCodeNotFound>()),
      );
    }
  });

  test('the last parent cannot be demoted or leave', () async {
    final f = await createAsDad();
    await expectLater(repo.setRole(f, 'u1', Role.child), throwsA(isA<LastParentException>()));
    await expectLater(repo.leaveFamily(f, 'u1'), throwsA(isA<LastParentException>()));
    expect((await repo.watchMember(f, 'u1').first)!.role, Role.parent);
  });

  test('a parent can be demoted when another parent exists', () async {
    final f = await createAsDad();
    final code = (await repo.watchFamily(f).first)!.joinCode;
    await repo.joinFamily(uid: 'u2', userName: 'Mum', code: code);
    await repo.setRole(f, 'u2', Role.parent);
    await repo.setRole(f, 'u1', Role.child);
    expect((await repo.watchMember(f, 'u1').first)!.role, Role.child);
  });

  test('a child can leave and their familyId is cleared', () async {
    final f = await createAsDad();
    final code = (await repo.watchFamily(f).first)!.joinCode;
    await repo.joinFamily(uid: 'u2', userName: 'Sara', code: code);
    await repo.leaveFamily(f, 'u2');
    expect(await repo.watchMember(f, 'u2').first, isNull);
    expect((await repo.watchUser('u2').first)!.familyId, isNull);
  });

  test('removeMember deletes the member', () async {
    final f = await createAsDad();
    final code = (await repo.watchFamily(f).first)!.joinCode;
    await repo.joinFamily(uid: 'u2', userName: 'Sara', code: code);
    await repo.removeMember(f, 'u2');
    expect((await repo.watchMembers(f).first).map((m) => m.uid), ['u1']);
  });

  test('regenerateCode replaces the join code', () async {
    final f = await createAsDad();
    final old = (await repo.watchFamily(f).first)!.joinCode;
    final fresh = await repo.regenerateCode(f);
    expect(fresh, isNot(old));
    expect((await db.doc('joinCodes/$old').get()).exists, isFalse);
    expect((await db.doc('joinCodes/$fresh').get()).data()!['familyId'], f);
    expect((await repo.watchFamily(f).first)!.joinCode, fresh);
  });

  test('setLanguage stores the choice', () async {
    await repo.ensureUser(uid: 'u1', name: 'Dad', email: 'd@x', language: 'en');
    await repo.setLanguage('u1', 'ar');
    expect((await repo.watchUser('u1').first)!.language, 'ar');
  });
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/family_repository_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/data/family_repository.dart'`.

- [x] **Step 3: Implement**

Create `lib/data/family_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models.dart';
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
    await _members(familyRef.id).doc(uid).set({'name': userName, 'role': 'parent', 'joinedAt': now});
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
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/data/family_repository_test.dart`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/data/family_repository.dart test/data/family_repository_test.dart
git commit -m "feat(data): family repository — create/join, roles, join codes"
```

---

### Task 6: Catalog repository (categories and items) and the shared test seed

**Files:**
- Create: `lib/data/catalog_repository.dart`, `lib/data/write.dart`, `test/support/seed.dart`
- Test: `test/data/catalog_repository_test.dart`

**Interfaces:**
- Consumes: `Item`, `ItemCategory` (Task 3); `nameKey` (Task 2)
- Produces:
  - `void fireAndForget(Future<void> write)` (`lib/data/write.dart`)
  - `class CatalogRepository(FirebaseFirestore db, String familyId)` with:
    - `String newId()`
    - `Stream<List<ItemCategory>> watchCategories()`
    - `Stream<List<Item>> watchItems()`
    - `Future<void> addCategory({required String id, required String name, required String uid})`
    - `Future<void> renameCategory(String id, String name)`
    - `Future<void> deleteCategory({required String categoryId, required String otherCategoryId, required Iterable<Item> catalog})`
    - `Item? findByName(String name, Iterable<Item> catalog)`
    - `Future<void> saveItem(Item item, {required String uid, bool isNew = false})`
    - `Future<void> deleteItem({required String itemId, required Iterable<String> listIds})`
  - `Future<FakeFirebaseFirestore> seedFamily()` (`test/support/seed.dart`). It seeds family `f1` with parent `u1` "Dad", child `u2` "Sara", categories `other` (default) and `dairy`, items `milk` (Dairy, 2 L, 7 days) and `bread` (Other), list `l1` "Home", and a toBuy entry for `milk`.

- [ ] **Step 1: Create the shared seed**

Create `test/support/seed.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';

Future<FakeFirebaseFirestore> seedFamily() async {
  final db = FakeFirebaseFirestore();
  await db.doc('users/u1').set({'name': 'Dad', 'email': 'dad@x.com', 'familyId': 'f1', 'language': 'en'});
  await db.doc('users/u2').set({'name': 'Sara', 'email': 'sara@x.com', 'familyId': 'f1', 'language': 'en'});
  await db.doc('families/f1').set({'name': 'Home', 'joinCode': 'ABC234', 'createdBy': 'u1'});
  await db.doc('joinCodes/ABC234').set({'familyId': 'f1'});
  await db.doc('families/f1/members/u1').set({'name': 'Dad', 'role': 'parent'});
  await db.doc('families/f1/members/u2').set({'name': 'Sara', 'role': 'child'});
  await db.doc('families/f1/categories/other').set({'name': 'Other', 'isDefault': true});
  await db.doc('families/f1/categories/dairy').set({'name': 'Dairy', 'isDefault': false});
  await db.doc('families/f1/items/milk').set(const Item(
    id: 'milk', name: 'Milk', categoryId: 'dairy', quantity: 2, unit: 'L', expiryDays: 7,
  ).toMap());
  await db.doc('families/f1/items/bread').set(const Item(id: 'bread', name: 'Bread', categoryId: 'other').toMap());
  await db.doc('families/f1/lists/l1').set({'name': 'Home', 'createdBy': 'u1', 'createdAt': DateTime(2026, 1, 1)});
  await db.doc('families/f1/lists/l1/entries/milk').set({
    'itemId': 'milk', 'status': 'toBuy', 'addedBy': 'u1', 'addedAt': DateTime(2026, 9, 30),
    'boughtBy': null, 'boughtAt': null,
  });
  return db;
}
```

- [ ] **Step 2: Write the failing tests**

Create `test/data/catalog_repository_test.dart`:

```dart
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
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/data/catalog_repository_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/data/catalog_repository.dart'`.

- [ ] **Step 4: Implement**

Create `lib/data/write.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Starts a Firestore write without waiting for the server.
/// Offline, the write is applied to the local cache at once and synced later.
void fireAndForget(Future<void> write) {
  write.catchError((Object error) {
    debugPrint('Firestore write failed: $error');
  });
}
```

Create `lib/data/catalog_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models.dart';
import '../core/text.dart';

class CatalogRepository {
  CatalogRepository(this._db, this.familyId);

  final FirebaseFirestore _db;
  final String familyId;

  DocumentReference<Map<String, dynamic>> get _family => _db.collection('families').doc(familyId);
  CollectionReference<Map<String, dynamic>> get _categories => _family.collection('categories');
  CollectionReference<Map<String, dynamic>> get _items => _family.collection('items');
  CollectionReference<Map<String, dynamic>> get _lists => _family.collection('lists');

  /// A fresh document id, generated locally (works offline).
  String newId() => _items.doc().id;

  Stream<List<ItemCategory>> watchCategories() => _categories
      .snapshots()
      .map((q) => [for (final d in q.docs) ItemCategory.fromMap(d.id, d.data())]);

  Stream<List<Item>> watchItems() => _items
      .snapshots()
      .map((q) => [for (final d in q.docs) Item.fromMap(d.id, d.data())]);

  Future<void> addCategory({required String id, required String name, required String uid}) =>
      _categories.doc(id).set({
        'name': name.trim(),
        'isDefault': false,
        'createdBy': uid,
        'createdAt': DateTime.now(),
      });

  Future<void> renameCategory(String id, String name) =>
      _categories.doc(id).update({'name': name.trim()});

  Future<void> deleteCategory({
    required String categoryId,
    required String otherCategoryId,
    required Iterable<Item> catalog,
  }) {
    final batch = _db.batch();
    for (final item in catalog.where((i) => i.categoryId == categoryId)) {
      batch.update(_items.doc(item.id), {'categoryId': otherCategoryId});
    }
    batch.delete(_categories.doc(categoryId));
    return batch.commit();
  }

  /// The existing item with the same normalized name, or null (also for blank input).
  Item? findByName(String name, Iterable<Item> catalog) {
    final key = nameKey(name);
    if (key.isEmpty) return null;
    for (final item in catalog) {
      if (item.key == key) return item;
    }
    return null;
  }

  Future<void> saveItem(Item item, {required String uid, bool isNew = false}) =>
      _items.doc(item.id).set({
        ...item.toMap(),
        if (isNew) 'createdBy': uid,
        if (isNew) 'createdAt': DateTime.now(),
      }, SetOptions(merge: true));

  Future<void> deleteItem({required String itemId, required Iterable<String> listIds}) {
    final batch = _db.batch();
    for (final listId in listIds) {
      batch.delete(_lists.doc(listId).collection('entries').doc(itemId));
    }
    batch.delete(_items.doc(itemId));
    return batch.commit();
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/data/catalog_repository_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/data/catalog_repository.dart lib/data/write.dart test/support/seed.dart test/data/catalog_repository_test.dart
git commit -m "feat(data): catalog repository for categories and items"
```

---

### Task 7: List and purchase repositories (buy, undo, history)

**Files:**
- Create: `lib/data/list_repository.dart`, `lib/data/purchase_repository.dart`
- Test: `test/data/list_repository_test.dart`

**Interfaces:**
- Consumes: `ShoppingList`, `Item`, `ItemCategory`, `Entry`, `Purchase`, `EntryStatus` (Task 3); `seedFamily` (Task 6)
- Produces:
  - `class BuyReceipt{listId, itemId, purchaseId, previousEntry, boughtEntry, purchase}` (the three last are `Map<String, dynamic>`)
  - `class ListRepository(FirebaseFirestore db, String familyId)` with:
    - `Stream<List<ShoppingList>> watchLists()` (ordered by `createdAt`)
    - `Future<void> createList({required String name, required String uid})`
    - `Future<void> renameList(String listId, String name)`
    - `Future<void> deleteList(String listId)`
    - `Stream<List<Entry>> watchEntries(String listId)`
    - `Future<void> addToBuy({required String listId, required String itemId, required String uid})`
    - `Future<void> removeFromList(String listId, String itemId)`
    - `BuyReceipt prepareBuy({required ShoppingList list, required Item item, required ItemCategory? category, required Entry entry, required String uid, required String userName, DateTime? now})`
    - `Future<void> commitBuy(BuyReceipt receipt)`
    - `Future<void> undoBuy(BuyReceipt receipt)`
  - `class PurchaseRepository(FirebaseFirestore db, String familyId)` with:
    - `Stream<List<Purchase>> watchPurchases()` (newest first, at most 500)
    - `Future<void> setPrice(String purchaseId, double? price)`
    - `Future<void> delete(String purchaseId)`

- [ ] **Step 1: Write the failing tests**

Create `test/data/list_repository_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/data/list_repository.dart';
import 'package:family_app/data/purchase_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/seed.dart';

const home = ShoppingList(id: 'l1', name: 'Home');
const milk = Item(id: 'milk', name: 'Milk', categoryId: 'dairy', quantity: 2, unit: 'L', expiryDays: 7);
const bread = Item(id: 'bread', name: 'Bread', categoryId: 'other');
const dairy = ItemCategory(id: 'dairy', name: 'Dairy', isDefault: false);

void main() {
  late FakeFirebaseFirestore db;
  late ListRepository lists;
  late PurchaseRepository purchases;

  setUp(() async {
    db = await seedFamily();
    lists = ListRepository(db, 'f1');
    purchases = PurchaseRepository(db, 'f1');
  });

  Future<Entry> entry(String itemId) async =>
      (await lists.watchEntries('l1').first).firstWhere((e) => e.itemId == itemId);

  test('buy marks the entry bought and records a purchase snapshot', () async {
    final at = DateTime(2026, 10, 1, 12);
    final receipt = lists.prepareBuy(
      list: home, item: milk, category: dairy, entry: await entry('milk'),
      uid: 'u2', userName: 'Sara', now: at,
    );
    await lists.commitBuy(receipt);

    final e = await entry('milk');
    expect(e.status, EntryStatus.bought);
    expect(e.boughtBy, 'u2');
    expect(e.boughtAt, at);
    expect(e.addedBy, 'u1');

    final p = (await purchases.watchPurchases().first).single;
    expect(p.id, receipt.purchaseId);
    expect(p.itemName, 'Milk');
    expect(p.categoryName, 'Dairy');
    expect(p.listName, 'Home');
    expect(p.quantity, 2.0);
    expect(p.unit, 'L');
    expect(p.price, isNull);
    expect(p.currency, 'SAR');
    expect(p.boughtByName, 'Sara');
    expect(p.boughtAt, at);
  });

  test('undo restores the entry and deletes the purchase', () async {
    final receipt = lists.prepareBuy(
      list: home, item: milk, category: dairy, entry: await entry('milk'),
      uid: 'u2', userName: 'Sara',
    );
    await lists.commitBuy(receipt);
    await lists.undoBuy(receipt);

    final e = await entry('milk');
    expect(e.status, EntryStatus.toBuy);
    expect(e.addedBy, 'u1');
    expect(e.boughtAt, isNull);
    expect(await purchases.watchPurchases().first, isEmpty);
  });

  test('addToBuy on a bought entry keeps its last purchase details', () async {
    await lists.commitBuy(lists.prepareBuy(
      list: home, item: milk, category: dairy, entry: await entry('milk'),
      uid: 'u2', userName: 'Sara',
    ));
    await lists.addToBuy(listId: 'l1', itemId: 'milk', uid: 'u1');
    final e = await entry('milk');
    expect(e.status, EntryStatus.toBuy);
    expect(e.boughtBy, 'u2');
    expect(e.boughtAt, isNotNull);
  });

  test('addToBuy creates a new entry; removeFromList deletes it', () async {
    await lists.addToBuy(listId: 'l1', itemId: 'bread', uid: 'u2');
    expect((await entry('bread')).status, EntryStatus.toBuy);
    await lists.removeFromList('l1', 'bread');
    expect((await lists.watchEntries('l1').first).map((e) => e.itemId), ['milk']);
  });

  test('createList trims; lists are ordered by creation; rename works', () async {
    await lists.createList(name: ' Pharmacy ', uid: 'u1');
    var all = await lists.watchLists().first;
    expect(all.map((l) => l.name).toList(), ['Home', 'Pharmacy']);
    await lists.renameList(all.last.id, 'Chemist');
    all = await lists.watchLists().first;
    expect(all.last.name, 'Chemist');
  });

  test('deleteList removes the list and its entries', () async {
    await lists.deleteList('l1');
    expect(await lists.watchLists().first, isEmpty);
    expect((await db.doc('families/f1/lists/l1/entries/milk').get()).exists, isFalse);
  });

  test('purchases are newest first; price can be set and cleared; records deleted', () async {
    await lists.addToBuy(listId: 'l1', itemId: 'bread', uid: 'u1');
    final first = lists.prepareBuy(
      list: home, item: milk, category: dairy, entry: await entry('milk'),
      uid: 'u1', userName: 'Dad', now: DateTime(2026, 9, 1),
    );
    final second = lists.prepareBuy(
      list: home, item: bread, category: null, entry: await entry('bread'),
      uid: 'u1', userName: 'Dad', now: DateTime(2026, 9, 2),
    );
    await lists.commitBuy(first);
    await lists.commitBuy(second);

    var all = await purchases.watchPurchases().first;
    expect(all.map((p) => p.itemName).toList(), ['Bread', 'Milk']);
    expect(all.first.categoryName, '');

    await purchases.setPrice(first.purchaseId, 12.5);
    all = await purchases.watchPurchases().first;
    expect(all.firstWhere((p) => p.id == first.purchaseId).price, 12.5);

    await purchases.setPrice(first.purchaseId, null);
    all = await purchases.watchPurchases().first;
    expect(all.firstWhere((p) => p.id == first.purchaseId).price, isNull);

    await purchases.delete(second.purchaseId);
    expect((await purchases.watchPurchases().first).single.id, first.purchaseId);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/list_repository_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/data/list_repository.dart'`.

- [ ] **Step 3: Implement**

Create `lib/data/list_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models.dart';

/// Everything needed to write a purchase and to undo it exactly.
class BuyReceipt {
  const BuyReceipt({
    required this.listId,
    required this.itemId,
    required this.purchaseId,
    required this.previousEntry,
    required this.boughtEntry,
    required this.purchase,
  });
  final String listId;
  final String itemId;
  final String purchaseId;
  final Map<String, dynamic> previousEntry;
  final Map<String, dynamic> boughtEntry;
  final Map<String, dynamic> purchase;
}

class ListRepository {
  ListRepository(this._db, this.familyId);

  final FirebaseFirestore _db;
  final String familyId;

  DocumentReference<Map<String, dynamic>> get _family => _db.collection('families').doc(familyId);
  CollectionReference<Map<String, dynamic>> get _lists => _family.collection('lists');
  CollectionReference<Map<String, dynamic>> get _purchases => _family.collection('purchases');
  CollectionReference<Map<String, dynamic>> _entries(String listId) =>
      _lists.doc(listId).collection('entries');

  Stream<List<ShoppingList>> watchLists() => _lists
      .orderBy('createdAt')
      .snapshots()
      .map((q) => [for (final d in q.docs) ShoppingList.fromMap(d.id, d.data())]);

  Future<void> createList({required String name, required String uid}) =>
      _lists.doc().set({'name': name.trim(), 'createdBy': uid, 'createdAt': DateTime.now()});

  Future<void> renameList(String listId, String name) =>
      _lists.doc(listId).update({'name': name.trim()});

  Future<void> deleteList(String listId) async {
    final entries = await _entries(listId).get();
    final batch = _db.batch();
    for (final d in entries.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_lists.doc(listId));
    await batch.commit();
  }

  Stream<List<Entry>> watchEntries(String listId) => _entries(listId)
      .snapshots()
      .map((q) => [for (final d in q.docs) Entry.fromMap(d.id, d.data())]);

  /// Puts an item on To buy. Merging keeps the last purchase details for the item sheet.
  Future<void> addToBuy({required String listId, required String itemId, required String uid}) =>
      _entries(listId).doc(itemId).set({
        'itemId': itemId,
        'status': EntryStatus.toBuy.name,
        'addedBy': uid,
        'addedAt': DateTime.now(),
      }, SetOptions(merge: true));

  Future<void> removeFromList(String listId, String itemId) =>
      _entries(listId).doc(itemId).delete();

  BuyReceipt prepareBuy({
    required ShoppingList list,
    required Item item,
    required ItemCategory? category,
    required Entry entry,
    required String uid,
    required String userName,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final purchaseId = _purchases.doc().id;
    final bought = Entry(
      itemId: item.id,
      status: EntryStatus.bought,
      addedBy: entry.addedBy,
      addedAt: entry.addedAt,
      boughtBy: uid,
      boughtAt: at,
    );
    final purchase = Purchase(
      id: purchaseId,
      itemId: item.id,
      itemName: item.name,
      categoryName: category?.name ?? '',
      listId: list.id,
      listName: list.name,
      quantity: item.quantity,
      unit: item.unit,
      boughtBy: uid,
      boughtByName: userName,
      boughtAt: at,
    );
    return BuyReceipt(
      listId: list.id,
      itemId: item.id,
      purchaseId: purchaseId,
      previousEntry: entry.toMap(),
      boughtEntry: bought.toMap(),
      purchase: purchase.toMap(),
    );
  }

  Future<void> commitBuy(BuyReceipt r) => (_db.batch()
        ..set(_entries(r.listId).doc(r.itemId), r.boughtEntry)
        ..set(_purchases.doc(r.purchaseId), r.purchase))
      .commit();

  Future<void> undoBuy(BuyReceipt r) => (_db.batch()
        ..set(_entries(r.listId).doc(r.itemId), r.previousEntry)
        ..delete(_purchases.doc(r.purchaseId)))
      .commit();
}
```

Create `lib/data/purchase_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models.dart';

class PurchaseRepository {
  PurchaseRepository(this._db, this.familyId);

  final FirebaseFirestore _db;
  final String familyId;

  CollectionReference<Map<String, dynamic>> get _purchases =>
      _db.collection('families').doc(familyId).collection('purchases');

  /// Newest first. List filtering happens in the UI to avoid a composite index.
  Stream<List<Purchase>> watchPurchases() => _purchases
      .orderBy('boughtAt', descending: true)
      .limit(500)
      .snapshots()
      .map((q) => [for (final d in q.docs) Purchase.fromMap(d.id, d.data())]);

  Future<void> setPrice(String purchaseId, double? price) =>
      _purchases.doc(purchaseId).update({'price': price});

  Future<void> delete(String purchaseId) => _purchases.doc(purchaseId).delete();
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/data`
Expected: PASS for all data tests.

- [ ] **Step 5: Commit**

```bash
git add lib/data/list_repository.dart lib/data/purchase_repository.dart test/data/list_repository_test.dart
git commit -m "feat(data): lists, one-tap buy with undo, purchase history"
```

---
### Task 8: App foundation — localization, theme, formatting, providers, dialogs

**Files:**
- Create: `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/app/theme.dart`, `lib/app/formatting.dart`, `lib/app/providers.dart`, `lib/features/common/dialogs.dart`, `lib/features/common/offline_chip.dart`, `test/support/pump.dart`
- Modify: `pubspec.yaml` (add `generate: true` under `flutter:`)
- Test: `test/app/formatting_test.dart`

**Interfaces:**
- Consumes: all of `lib/core` and `lib/data` (Tasks 2–7)
- Produces:
  - `AppLocalizations` (generated at `lib/l10n/app_localizations.dart`), with every key listed in Step 1
  - `AppColors.{background, surface, toBuy, recent, accent}`, `ThemeData buildTheme()`
  - `String unitLabel(AppLocalizations l, String unit)`, `String quantityLabel(AppLocalizations l, double? quantity, String? unit)`, `String categoryLabel(AppLocalizations l, ItemCategory? category)`
  - Providers:
    - `firebaseAuthProvider`, `googleSignInProvider`, `firestoreProvider`, `clockProvider` (`DateTime Function()`)
    - `authUserProvider`, `authReadyProvider` (`bool`), `currentUidProvider` (`String?`)
    - `familyRepositoryProvider`, `appUserProvider`, `familyIdProvider`, `localeProvider`
    - `catalogRepositoryProvider`, `listRepositoryProvider`, `purchaseRepositoryProvider`
    - `familyProvider`, `membersProvider`, `myMemberProvider`, `isParentProvider`
    - `categoriesProvider`, `itemsProvider`, `listsProvider`, `entriesProvider` (family, keyed by listId), `purchasesProvider`
    - `sortModeProvider` (`StateProvider<SortMode>`), `offlineProvider`
  - `Future<String?> promptText(BuildContext, {required String title, String? label, String initial = '', required String confirmLabel, TextInputType? keyboardType})`. Its field has key `promptField`; its confirm button has key `promptConfirm`.
  - `Future<bool> confirm(BuildContext, {required String message, required String confirmLabel})`. Its confirm button has key `confirmYes`.
  - `class OfflineChip extends ConsumerWidget`
  - Test helpers: `final testNow = DateTime(2026, 10, 1, 12)`, `Future<void> settle(WidgetTester)`, `Future<void> pumpWithFamily(WidgetTester, {required FakeFirebaseFirestore db, required Widget child, String uid = 'u1'})`

- [ ] **Step 1: Add localization files**

In `pubspec.yaml`, under the top-level `flutter:` key, add `generate: true`:

```yaml
flutter:
  generate: true
  uses-material-design: true
```

Create `l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-dir: lib/l10n
nullable-getter: true
```

Create `lib/l10n/app_en.arb`:

```json
{
  "@@locale": "en",
  "appTitle": "Family",
  "signInWithGoogle": "Sign in with Google",
  "signInFailed": "Sign-in didn't work. Please try again.",
  "createFamily": "Create a family",
  "joinFamily": "Join a family",
  "familyName": "Family name",
  "joinCode": "Join code",
  "create": "Create",
  "join": "Join",
  "joinCodeNotFound": "That code doesn't match any family.",
  "needsConnection": "This needs an internet connection.",
  "somethingWentWrong": "Something went wrong. Please try again.",
  "tabLists": "Lists",
  "tabHistory": "History",
  "tabFamily": "Family",
  "newList": "New list",
  "listName": "List name",
  "rename": "Rename",
  "delete": "Delete",
  "cancel": "Cancel",
  "save": "Save",
  "noListsParent": "No lists yet. Create one to get started.",
  "noListsChild": "No lists yet. Ask a parent to create one.",
  "toBuy": "To buy",
  "emptyToBuy": "Nothing to buy right now.",
  "recentlyUsed": "Recently used",
  "categories": "Categories",
  "newCategory": "New category",
  "categoryName": "Category name",
  "otherCategory": "Other",
  "sortByCategory": "By category",
  "sortAlphabetical": "A–Z",
  "iNeed": "I need…",
  "boughtItem": "{name} bought",
  "@boughtItem": { "placeholders": { "name": { "type": "String" } } },
  "undo": "Undo",
  "daysLeft": "{count, plural, =0{today} =1{1 day} other{{count} days}}",
  "@daysLeft": { "placeholders": { "count": { "type": "int" } } },
  "offline": "Offline",
  "name": "Name",
  "category": "Category",
  "quantity": "Quantity",
  "unit": "Unit",
  "noUnit": "—",
  "notes": "Notes",
  "expiryDays": "Expiry days",
  "expiryHint": "Leave empty so it never comes back by itself",
  "lastBought": "Last bought by {name} on {date}",
  "@lastBought": { "placeholders": { "name": { "type": "String" }, "date": { "type": "String" } } },
  "neverBought": "Not bought yet",
  "removeFromList": "Remove from this list",
  "deleteFromCatalog": "Delete from catalog",
  "confirmDeleteItem": "Delete {name} from every list? Purchase history is kept.",
  "@confirmDeleteItem": { "placeholders": { "name": { "type": "String" } } },
  "confirmDeleteList": "Delete the list {name}? Purchase history is kept.",
  "@confirmDeleteList": { "placeholders": { "name": { "type": "String" } } },
  "confirmDeleteCategory": "Delete {name}? Its items move to Other.",
  "@confirmDeleteCategory": { "placeholders": { "name": { "type": "String" } } },
  "allLists": "All lists",
  "addPrice": "Add price",
  "price": "Price (SAR)",
  "currencySar": "SAR",
  "noPurchases": "No purchases yet.",
  "members": "Members",
  "parent": "Parent",
  "child": "Child",
  "makeParent": "Make parent",
  "makeChild": "Make child",
  "removeMember": "Remove from family",
  "confirmRemoveMember": "Remove {name} from the family?",
  "@confirmRemoveMember": { "placeholders": { "name": { "type": "String" } } },
  "share": "Share",
  "regenerateCode": "New code",
  "confirmRegenerateCode": "Make a new join code? The old one will stop working.",
  "language": "Language",
  "signOut": "Sign out",
  "leaveFamily": "Leave family",
  "confirmLeaveFamily": "Leave this family?",
  "lastParentError": "The family needs at least one parent.",
  "shareCodeMessage": "Join our family in the Family app with code {code}",
  "@shareCodeMessage": { "placeholders": { "code": { "type": "String" } } },
  "unitPcs": "pcs",
  "unitKg": "kg",
  "unitG": "g",
  "unitL": "L",
  "unitMl": "ml",
  "unitPack": "pack"
}
```

Create `lib/l10n/app_ar.arb`:

```json
{
  "@@locale": "ar",
  "appTitle": "العائلة",
  "signInWithGoogle": "تسجيل الدخول عبر Google",
  "signInFailed": "تعذّر تسجيل الدخول. حاول مرة أخرى.",
  "createFamily": "إنشاء عائلة",
  "joinFamily": "الانضمام إلى عائلة",
  "familyName": "اسم العائلة",
  "joinCode": "رمز الانضمام",
  "create": "إنشاء",
  "join": "انضمام",
  "joinCodeNotFound": "هذا الرمز لا يطابق أي عائلة.",
  "needsConnection": "يتطلب هذا اتصالاً بالإنترنت.",
  "somethingWentWrong": "حدث خطأ. حاول مرة أخرى.",
  "tabLists": "القوائم",
  "tabHistory": "السجل",
  "tabFamily": "العائلة",
  "newList": "قائمة جديدة",
  "listName": "اسم القائمة",
  "rename": "إعادة تسمية",
  "delete": "حذف",
  "cancel": "إلغاء",
  "save": "حفظ",
  "noListsParent": "لا توجد قوائم بعد. أنشئ قائمة للبدء.",
  "noListsChild": "لا توجد قوائم بعد. اطلب من أحد الوالدين إنشاء قائمة.",
  "toBuy": "للشراء",
  "emptyToBuy": "لا شيء للشراء الآن.",
  "recentlyUsed": "مستخدم مؤخراً",
  "categories": "الفئات",
  "newCategory": "فئة جديدة",
  "categoryName": "اسم الفئة",
  "otherCategory": "أخرى",
  "sortByCategory": "حسب الفئة",
  "sortAlphabetical": "أ–ي",
  "iNeed": "أحتاج…",
  "boughtItem": "تم شراء {name}",
  "undo": "تراجع",
  "daysLeft": "{count, plural, =0{اليوم} =1{يوم واحد} =2{يومان} few{{count} أيام} many{{count} يومًا} other{{count} يوم}}",
  "offline": "غير متصل",
  "name": "الاسم",
  "category": "الفئة",
  "quantity": "الكمية",
  "unit": "الوحدة",
  "noUnit": "—",
  "notes": "ملاحظات",
  "expiryDays": "أيام الصلاحية",
  "expiryHint": "اتركه فارغاً كي لا يعود تلقائياً",
  "lastBought": "آخر شراء بواسطة {name} في {date}",
  "neverBought": "لم يُشترَ بعد",
  "removeFromList": "إزالة من هذه القائمة",
  "deleteFromCatalog": "حذف من الكتالوج",
  "confirmDeleteItem": "حذف {name} من كل القوائم؟ يبقى سجل المشتريات.",
  "confirmDeleteList": "حذف القائمة {name}؟ يبقى سجل المشتريات.",
  "confirmDeleteCategory": "حذف {name}؟ تنتقل عناصرها إلى أخرى.",
  "allLists": "كل القوائم",
  "addPrice": "أضف السعر",
  "price": "السعر (ريال)",
  "currencySar": "ر.س",
  "noPurchases": "لا توجد مشتريات بعد.",
  "members": "الأعضاء",
  "parent": "ولي أمر",
  "child": "طفل",
  "makeParent": "اجعله ولي أمر",
  "makeChild": "اجعله طفلاً",
  "removeMember": "إزالة من العائلة",
  "confirmRemoveMember": "إزالة {name} من العائلة؟",
  "share": "مشاركة",
  "regenerateCode": "رمز جديد",
  "confirmRegenerateCode": "إنشاء رمز انضمام جديد؟ سيتوقف الرمز القديم عن العمل.",
  "language": "اللغة",
  "signOut": "تسجيل الخروج",
  "leaveFamily": "مغادرة العائلة",
  "confirmLeaveFamily": "مغادرة هذه العائلة؟",
  "lastParentError": "يجب أن يكون للعائلة ولي أمر واحد على الأقل.",
  "shareCodeMessage": "انضم إلى عائلتنا في تطبيق العائلة بالرمز {code}",
  "unitPcs": "قطعة",
  "unitKg": "كغ",
  "unitG": "غ",
  "unitL": "لتر",
  "unitMl": "مل",
  "unitPack": "عبوة"
}
```

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations.dart`, `app_localizations_en.dart` and `app_localizations_ar.dart` are generated, with no errors.

- [ ] **Step 2: Write the failing formatting test**

Create `test/app/formatting_test.dart`:

```dart
import 'package:family_app/app/formatting.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  test('quantityLabel', () {
    expect(quantityLabel(en, 2, 'L'), '2 L');
    expect(quantityLabel(en, 1.5, 'kg'), '1.5 kg');
    expect(quantityLabel(en, 3, null), '3');
    expect(quantityLabel(en, null, 'L'), '');
    expect(quantityLabel(ar, 2, 'L'), '2 لتر');
  });

  test('unitLabel covers every unit', () {
    for (final u in units) {
      expect(unitLabel(en, u), isNotEmpty);
      expect(unitLabel(ar, u), isNotEmpty);
    }
  });

  test('categoryLabel localizes the default category only', () {
    const other = ItemCategory(id: 'o', name: 'Other', isDefault: true);
    const dairy = ItemCategory(id: 'd', name: 'Dairy', isDefault: false);
    expect(categoryLabel(ar, other), 'أخرى');
    expect(categoryLabel(ar, dairy), 'Dairy');
    expect(categoryLabel(en, null), 'Other');
  });

  test('daysLeft plural', () {
    expect(en.daysLeft(1), '1 day');
    expect(en.daysLeft(5), '5 days');
    expect(en.daysLeft(0), 'today');
  });
}
```

Run: `flutter test test/app/formatting_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/app/formatting.dart'`.

- [ ] **Step 3: Implement theme and formatting**

Create `lib/app/theme.dart`:

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF2B3A42);
  static const surface = Color(0xFF34464F);
  static const toBuy = Color(0xFFEE6A6A);
  static const recent = Color(0xFF6DB5A8);
  static const accent = Color(0xFF2E8B72);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        surface: AppColors.background,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: AppColors.background),
    );
```

Create `lib/app/formatting.dart`:

```dart
import '../core/models.dart';
import '../core/text.dart';
import '../l10n/app_localizations.dart';

String unitLabel(AppLocalizations l, String unit) => switch (unit) {
      'pcs' => l.unitPcs,
      'kg' => l.unitKg,
      'g' => l.unitG,
      'L' => l.unitL,
      'ml' => l.unitMl,
      'pack' => l.unitPack,
      _ => unit,
    };

/// "2 L", "1.5 kg", "3", or "" when no quantity is set.
String quantityLabel(AppLocalizations l, double? quantity, String? unit) {
  if (quantity == null) return '';
  final number = formatNumber(quantity);
  return unit == null ? number : '$number ${unitLabel(l, unit)}';
}

/// The built-in Other category is shown in the UI language, whatever name it was stored with.
String categoryLabel(AppLocalizations l, ItemCategory? category) {
  if (category == null || category.isDefault) return l.otherCategory;
  return category.name;
}
```

Run: `flutter test test/app/formatting_test.dart`
Expected: PASS

- [ ] **Step 4: Implement providers**

Create `lib/app/providers.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
```

- [ ] **Step 5: Implement dialogs and the offline chip**

Create `lib/features/common/dialogs.dart`:

```dart
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? label,
  String initial = '',
  required String confirmLabel,
  TextInputType? keyboardType,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      initial: initial,
      confirmLabel: confirmLabel,
      keyboardType: keyboardType,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.confirmLabel,
    required this.keyboardType,
  });
  final String title;
  final String? label;
  final String initial;
  final String confirmLabel;
  final TextInputType? keyboardType;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('promptField'),
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          key: const Key('promptConfirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String message,
  required String confirmLabel,
}) async {
  final l = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l.cancel)),
        FilledButton(
          key: const Key('confirmYes'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

Create `lib/features/common/offline_chip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';

class OfflineChip extends ConsumerWidget {
  const OfflineChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineProvider).valueOrNull ?? false;
    if (!offline) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Chip(
        avatar: const Icon(Icons.cloud_off, size: 16),
        label: Text(AppLocalizations.of(context)!.offline),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
```

- [ ] **Step 6: Create the widget-test pump helper**

Create `test/support/pump.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/providers.dart';
import 'package:family_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final testNow = DateTime(2026, 10, 1, 12);

/// Lets fake Firestore streams deliver without waiting for SnackBar timers.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> pumpWithFamily(
  WidgetTester tester, {
  required FakeFirebaseFirestore db,
  required Widget child,
  String uid = 'u1',
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      currentUidProvider.overrideWithValue(uid),
      authReadyProvider.overrideWithValue(true),
      clockProvider.overrideWithValue(() => testNow),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  ));
  await settle(tester);
}
```

- [ ] **Step 7: Verify**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: no errors or warnings; all tests pass.

- [ ] **Step 8: Commit**

```bash
git add l10n.yaml pubspec.yaml lib/l10n lib/app lib/features/common test/app test/support/pump.dart
git commit -m "feat(app): Arabic/English localization, theme, providers, dialogs"
```

---

### Task 9: Item details sheet (long-press)

**Files:**
- Create: `lib/features/lists/item_sheet.dart`
- Test: `test/features/item_sheet_test.dart`

**Interfaces:**
- Consumes: providers, `promptText`, `confirm`, `categoryLabel`, `unitLabel` (Task 8); `CatalogRepository`, `ListRepository`, `fireAndForget` (Tasks 6–7); `parseNumber`, `formatNumber` (Task 2); `compareCategories` (Task 3)
- Produces: `Future<void> showItemSheet(BuildContext context, {required Item item, required String listId, Entry? entry})`. Widget keys: `sheetName`, `sheetQuantity`, `sheetUnit`, `sheetExpiry`, `sheetNotes`, `sheetRemove`, `sheetDelete`, `sheetSave`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/item_sheet_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/features/lists/item_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

const milk = Item(id: 'milk', name: 'Milk', categoryId: 'dairy', quantity: 2, unit: 'L', expiryDays: 7);

Future<void> openSheet(WidgetTester tester, FakeFirebaseFirestore db, {String uid = 'u1', Entry? entry}) async {
  await pumpWithFamily(
    tester,
    db: db,
    uid: uid,
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showItemSheet(context, item: milk, listId: 'l1', entry: entry),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await settle(tester);
}

Future<Map<String, dynamic>> milkDoc(FakeFirebaseFirestore db) async =>
    (await db.doc('families/f1/items/milk').get()).data()!;

void main() {
  testWidgets('edits are saved and Arabic digits are accepted', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    await tester.enterText(find.byKey(const Key('sheetQuantity')), '١٫٥');
    await tester.enterText(find.byKey(const Key('sheetExpiry')), '٥');
    await tester.enterText(find.byKey(const Key('sheetNotes')), 'full fat');
    await tester.tap(find.byKey(const Key('sheetSave')));
    await settle(tester);
    final data = await milkDoc(db);
    expect(data['quantity'], 1.5);
    expect(data['expiryDays'], 5);
    expect(data['notes'], 'full fat');
    expect(find.byKey(const Key('sheetSave')), findsNothing);
  });

  testWidgets('expiry 0 is saved as no expiry', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    await tester.enterText(find.byKey(const Key('sheetExpiry')), '0');
    await tester.tap(find.byKey(const Key('sheetSave')));
    await settle(tester);
    expect((await milkDoc(db))['expiryDays'], isNull);
  });

  testWidgets('a blank name is not saved and the sheet stays open', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    await tester.enterText(find.byKey(const Key('sheetName')), '   ');
    await tester.tap(find.byKey(const Key('sheetSave')));
    await settle(tester);
    expect((await milkDoc(db))['name'], 'Milk');
    expect(find.byKey(const Key('sheetSave')), findsOneWidget);
  });

  testWidgets('children do not see Delete from catalog', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db, uid: 'u2');
    expect(find.byKey(const Key('sheetDelete')), findsNothing);
  });

  testWidgets('a parent can delete the item from the catalog', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    await tester.tap(find.byKey(const Key('sheetDelete')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirmYes')));
    await settle(tester);
    expect((await db.doc('families/f1/items/milk').get()).exists, isFalse);
    expect((await db.doc('families/f1/lists/l1/entries/milk').get()).exists, isFalse);
  });

  testWidgets('shows who last bought it; Remove from this list deletes the entry', (tester) async {
    final db = await seedFamily();
    final entry = Entry(
      itemId: 'milk', status: EntryStatus.bought,
      boughtBy: 'u2', boughtAt: DateTime(2026, 9, 28, 10),
    );
    await openSheet(tester, db, entry: entry);
    expect(find.text('Last bought by Sara on Sep 28, 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sheetRemove')));
    await settle(tester);
    expect((await db.doc('families/f1/lists/l1/entries/milk').get()).exists, isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/item_sheet_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/features/lists/item_sheet.dart'`.

- [ ] **Step 3: Implement**

Create `lib/features/lists/item_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/formatting.dart';
import '../../app/providers.dart';
import '../../core/models.dart';
import '../../core/placement.dart';
import '../../core/text.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/dialogs.dart';

const _newCategoryValue = '__new__';

Future<void> showItemSheet(
  BuildContext context, {
  required Item item,
  required String listId,
  Entry? entry,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ItemSheet(item: item, listId: listId, entry: entry),
  );
}

class ItemSheet extends ConsumerStatefulWidget {
  const ItemSheet({super.key, required this.item, required this.listId, this.entry});
  final Item item;
  final String listId;
  final Entry? entry;

  @override
  ConsumerState<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<ItemSheet> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _quantity = TextEditingController(
    text: widget.item.quantity == null ? '' : formatNumber(widget.item.quantity!),
  );
  late final _notes = TextEditingController(text: widget.item.notes);
  late final _expiry = TextEditingController(text: widget.item.expiryDays?.toString() ?? '');
  late String _categoryId = widget.item.categoryId;
  late String? _unit = units.contains(widget.item.unit) ? widget.item.unit : null;
  ItemCategory? _pendingCategory;
  int _categoryFieldVersion = 0;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _notes.dispose();
    _expiry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    ref.watch(listsProvider); // keep lists loaded so deleteItem can reach every list
    final lang = Localizations.localeOf(context).languageCode;
    final isParent = ref.watch(isParentProvider);
    final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];

    final categories = [...(ref.watch(categoriesProvider).valueOrNull ?? const <ItemCategory>[])];
    final pending = _pendingCategory;
    if (pending != null && categories.every((c) => c.id != pending.id)) categories.add(pending);
    categories.sort((a, b) => compareCategories(a, b, lang));
    final other = categories.where((c) => c.isDefault).firstOrNull;
    // If the item's category was deleted meanwhile, fall back to Other.
    final selectedCategory = categories.any((c) => c.id == _categoryId) ? _categoryId : other?.id;

    final entry = widget.entry;
    var lastBought = l.neverBought;
    if (entry != null && entry.boughtAt != null) {
      final who = members.where((m) => m.uid == entry.boughtBy).firstOrNull?.name ?? '—';
      lastBought = l.lastBought(who, DateFormat.yMMMd(lang).format(entry.boughtAt!));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('sheetName'),
              controller: _name,
              decoration: InputDecoration(labelText: l.name),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('sheetCategory-$_categoryFieldVersion'),
              value: selectedCategory,
              decoration: InputDecoration(labelText: l.category),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text(categoryLabel(l, c))),
                DropdownMenuItem(value: _newCategoryValue, child: Text(l.newCategory)),
              ],
              onChanged: (value) => _onCategoryChanged(value, l),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('sheetQuantity'),
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l.quantity),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: const Key('sheetUnit'),
                    value: _unit,
                    decoration: InputDecoration(labelText: l.unit),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(l.noUnit)),
                      for (final u in units)
                        DropdownMenuItem<String?>(value: u, child: Text(unitLabel(l, u))),
                    ],
                    onChanged: (value) => setState(() => _unit = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sheetNotes'),
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(labelText: l.notes),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sheetExpiry'),
              controller: _expiry,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.expiryDays, helperText: l.expiryHint),
            ),
            const SizedBox(height: 12),
            Text(lastBought, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              children: [
                if (entry != null)
                  TextButton(
                    key: const Key('sheetRemove'),
                    onPressed: _removeFromList,
                    child: Text(l.removeFromList),
                  ),
                if (isParent)
                  TextButton(
                    key: const Key('sheetDelete'),
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    onPressed: () => _deleteFromCatalog(l),
                    child: Text(l.deleteFromCatalog),
                  ),
                FilledButton(
                  key: const Key('sheetSave'),
                  onPressed: () => _save(selectedCategory),
                  child: Text(l.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCategoryChanged(String? value, AppLocalizations l) async {
    if (value == null) return;
    if (value != _newCategoryValue) {
      setState(() => _categoryId = value);
      return;
    }
    final name = await promptText(context, title: l.newCategory, label: l.categoryName, confirmLabel: l.save);
    if (!mounted) return;
    if (name == null || name.trim().isEmpty) {
      setState(() => _categoryFieldVersion++); // reset the dropdown away from "New category"
      return;
    }
    final repo = ref.read(catalogRepositoryProvider);
    final id = repo.newId();
    fireAndForget(repo.addCategory(id: id, name: name, uid: ref.read(currentUidProvider)!));
    setState(() {
      _pendingCategory = ItemCategory(id: id, name: name.trim(), isDefault: false);
      _categoryId = id;
      _categoryFieldVersion++;
    });
  }

  void _save(String? categoryId) {
    final name = _name.text.trim();
    if (name.isEmpty || categoryId == null) return;
    final quantity = parseNumber(_quantity.text);
    final expiry = parseNumber(_expiry.text)?.round();
    final item = Item(
      id: widget.item.id,
      name: name,
      categoryId: categoryId,
      quantity: quantity,
      unit: quantity == null ? null : _unit,
      notes: _notes.text.trim(),
      expiryDays: (expiry != null && expiry > 0) ? expiry : null,
    );
    fireAndForget(ref.read(catalogRepositoryProvider).saveItem(item, uid: ref.read(currentUidProvider)!));
    Navigator.of(context).pop();
  }

  void _removeFromList() {
    fireAndForget(ref.read(listRepositoryProvider).removeFromList(widget.listId, widget.item.id));
    Navigator.of(context).pop();
  }

  Future<void> _deleteFromCatalog(AppLocalizations l) async {
    final ok = await confirm(context, message: l.confirmDeleteItem(widget.item.name), confirmLabel: l.delete);
    if (!ok || !mounted) return;
    final lists = ref.read(listsProvider).valueOrNull ?? const <ShoppingList>[];
    fireAndForget(ref.read(catalogRepositoryProvider).deleteItem(
          itemId: widget.item.id,
          listIds: [for (final list in lists) list.id],
        ));
    Navigator.of(context).pop();
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/item_sheet_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/lists/item_sheet.dart test/features/item_sheet_test.dart
git commit -m "feat(lists): long-press item details sheet"
```

---

### Task 10: Lists tab and the list screen

**Files:**
- Create: `lib/features/lists/item_tile.dart`, `lib/features/lists/list_screen.dart`, `lib/features/lists/lists_screen.dart`
- Test: `test/features/list_screen_test.dart`, `test/features/lists_screen_test.dart`

**Interfaces:**
- Consumes: `buildSections`, `catalogGroups`, `TileView`, `SortMode` (Task 3); `tileLetter`, `nameKey` (Task 2); `showItemSheet` (Task 9); providers, formatting, dialogs, `OfflineChip` (Task 8)
- Produces:
  - `class ItemTile({required String name, required Color color, String caption = '', bool dimmed = false, bool highlighted = false, VoidCallback? onTap, VoidCallback? onLongPress})`
  - `class ListScreen({required String listId})`, with widget keys `iNeedField`, `iNeedAdd`, `sortToggle`
  - `class ListsScreen()`, with FAB key `newListFab`

- [ ] **Step 1: Write the failing tests**

Create `test/features/list_screen_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/features/lists/list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<void> openList(WidgetTester tester, FakeFirebaseFirestore db, {String uid = 'u1'}) =>
    pumpWithFamily(tester, db: db, uid: uid, child: const ListScreen(listId: 'l1'));

/// SnackBar and flash timers must finish before the test ends.
Future<void> drainTimers(WidgetTester tester) => tester.pump(const Duration(seconds: 6));

void main() {
  testWidgets('shows To buy items with quantity', (tester) async {
    final db = await seedFamily();
    await openList(tester, db);
    expect(find.text('To buy'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('2 L'), findsOneWidget);
  });

  testWidgets('tapping a To buy tile buys it, and Undo reverts', (tester) async {
    final db = await seedFamily();
    await openList(tester, db, uid: 'u2');
    await tester.tap(find.text('Milk'));
    await settle(tester);

    expect(find.text('Recently used'), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('Milk bought'), findsOneWidget);
    var purchases = await db.collection('families/f1/purchases').get();
    expect(purchases.docs.single.data()['boughtByName'], 'Sara');

    await tester.tap(find.text('Undo'));
    await settle(tester);
    purchases = await db.collection('families/f1/purchases').get();
    expect(purchases.docs, isEmpty);
    final entry = await db.doc('families/f1/lists/l1/entries/milk').get();
    expect(entry.data()!['status'], 'toBuy');
    await drainTimers(tester);
  });

  testWidgets('tapping a catalog item adds it to To buy', (tester) async {
    final db = await seedFamily();
    await openList(tester, db);
    await tester.tap(find.text('Other'));
    await settle(tester);
    await tester.tap(find.text('Bread'));
    await settle(tester);
    final entry = await db.doc('families/f1/lists/l1/entries/bread').get();
    expect(entry.data()!['status'], 'toBuy');
  });

  testWidgets('typing a new name creates it in Other and adds it', (tester) async {
    final db = await seedFamily();
    await openList(tester, db);
    await tester.enterText(find.byKey(const Key('iNeedField')), 'Labneh');
    await tester.tap(find.byKey(const Key('iNeedAdd')));
    await settle(tester);
    final items = await db.collection('families/f1/items').where('nameKey', isEqualTo: 'labneh').get();
    final labneh = items.docs.single;
    expect(labneh.data()['categoryId'], 'other');
    final entry = await db.doc('families/f1/lists/l1/entries/${labneh.id}').get();
    expect(entry.data()!['status'], 'toBuy');
  });

  testWidgets('typing an existing name reuses the catalog item', (tester) async {
    final db = await seedFamily();
    await openList(tester, db);
    await tester.enterText(find.byKey(const Key('iNeedField')), ' BREAD ');
    await tester.tap(find.byKey(const Key('iNeedAdd')));
    await settle(tester);
    expect((await db.collection('families/f1/items').get()).docs.length, 2);
    expect((await db.doc('families/f1/lists/l1/entries/bread').get()).data()!['status'], 'toBuy');
  });

  testWidgets('blank input adds nothing', (tester) async {
    final db = await seedFamily();
    await openList(tester, db);
    await tester.enterText(find.byKey(const Key('iNeedField')), '   ');
    await tester.tap(find.byKey(const Key('iNeedAdd')));
    await settle(tester);
    expect((await db.collection('families/f1/items').get()).docs.length, 2);
    expect((await db.collection('families/f1/lists/l1/entries').get()).docs.length, 1);
  });

  testWidgets('sort toggle switches to A–Z', (tester) async {
    final db = await seedFamily();
    await openList(tester, db);
    expect(find.text('Dairy'), findsWidgets); // category header in To buy
    await tester.tap(find.byKey(const Key('sortToggle')));
    await settle(tester);
    expect(find.text('A–Z'), findsOneWidget);
  });
}
```

Create `test/features/lists_screen_test.dart`:

```dart
import 'package:family_app/features/lists/lists_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

void main() {
  testWidgets('parents can create a list', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const ListsScreen());
    expect(find.text('Home'), findsOneWidget);
    await tester.tap(find.byKey(const Key('newListFab')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('promptField')), 'Pharmacy');
    await tester.tap(find.byKey(const Key('promptConfirm')));
    await settle(tester);
    expect(find.text('Pharmacy'), findsOneWidget);
  });

  testWidgets('children cannot create lists', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ListsScreen());
    expect(find.byKey(const Key('newListFab')), findsNothing);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/list_screen_test.dart test/features/lists_screen_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/features/lists/list_screen.dart'`.

- [ ] **Step 3: Implement the tile**

Create `lib/features/lists/item_tile.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/text.dart';

class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.name,
    required this.color,
    this.caption = '',
    this.dimmed = false,
    this.highlighted = false,
    this.onTap,
    this.onLongPress,
  });

  final String name;
  final Color color;
  final String caption;
  final bool dimmed;
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          border: Border.all(color: highlighted ? Colors.white : Colors.transparent, width: 3),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 2),
                    ),
                    child: Text(
                      tileLetter(name),
                      style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  if (caption.isNotEmpty)
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement the list screen**

Create `lib/features/lists/list_screen.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/formatting.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/placement.dart';
import '../../core/text.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/dialogs.dart';
import '../common/offline_chip.dart';
import 'item_sheet.dart';
import 'item_tile.dart';

class ListScreen extends ConsumerStatefulWidget {
  const ListScreen({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends ConsumerState<ListScreen> {
  TextEditingController? _typed;
  String? _flashId;
  Timer? _flashTimer;
  Timer? _snackTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    _snackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lists = ref.watch(listsProvider).valueOrNull ?? const <ShoppingList>[];
    final list = lists.where((x) => x.id == widget.listId).firstOrNull;
    final entriesAsync = ref.watch(entriesProvider(widget.listId));
    final itemsAsync = ref.watch(itemsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final sort = ref.watch(sortModeProvider);
    final isParent = ref.watch(isParentProvider);

    if (entriesAsync.hasError || itemsAsync.hasError || categoriesAsync.hasError) {
      return Scaffold(appBar: AppBar(title: Text(list?.name ?? '')), body: Center(child: Text(l.somethingWentWrong)));
    }
    if (!entriesAsync.hasValue || !itemsAsync.hasValue || !categoriesAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text(list?.name ?? '')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final entries = entriesAsync.requireValue;
    final items = itemsAsync.requireValue;
    final categories = categoriesAsync.requireValue;
    final itemMap = {for (final i in items) i.id: i};
    final categoryMap = {for (final c in categories) c.id: c};
    final entryMap = {for (final e in entries) e.itemId: e};
    final lang = Localizations.localeOf(context).languageCode;
    final sections = buildSections(
      entries: entries,
      items: itemMap,
      categories: categoryMap,
      now: ref.watch(clockProvider)(),
      sort: sort,
      languageCode: lang,
    );
    final catalog = catalogGroups(items: items, categories: categoryMap, languageCode: lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(list?.name ?? ''),
        actions: [
          const OfflineChip(),
          TextButton.icon(
            key: const Key('sortToggle'),
            onPressed: () => ref.read(sortModeProvider.notifier).state =
                sort == SortMode.category ? SortMode.alphabetical : SortMode.category,
            icon: const Icon(Icons.swap_vert),
            label: Text(sort == SortMode.category ? l.sortByCategory : l.sortAlphabetical),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _header(context, l.toBuy),
                if (sections.toBuy.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l.emptyToBuy, style: const TextStyle(color: Colors.white60)),
                  ),
                for (final group in sections.toBuy) ...[
                  if (group.category != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(categoryLabel(l, group.category),
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    ),
                  _grid([
                    for (final t in group.members)
                      ItemTile(
                        name: t.item.name,
                        color: AppColors.toBuy,
                        caption: quantityLabel(l, t.item.quantity, t.item.unit),
                        highlighted: _flashId == t.item.id,
                        onTap: list == null ? null : () => _buy(t, list, categoryMap, l),
                        onLongPress: () => _openSheet(t.item, t.entry),
                      ),
                  ]),
                ],
                if (sections.recentlyUsed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _header(context, l.recentlyUsed),
                  _grid([
                    for (final t in sections.recentlyUsed)
                      ItemTile(
                        name: t.item.name,
                        color: AppColors.recent,
                        caption: t.daysLeft != null
                            ? l.daysLeft(t.daysLeft!)
                            : quantityLabel(l, t.item.quantity, t.item.unit),
                        onTap: () => _addToBuy(t.item, sections),
                        onLongPress: () => _openSheet(t.item, t.entry),
                      ),
                  ]),
                ],
                const SizedBox(height: 12),
                _header(context, l.categories),
                for (final group in catalog)
                  ExpansionTile(
                    key: PageStorageKey('cat-${group.category?.id}'),
                    tilePadding: EdgeInsets.zero,
                    title: GestureDetector(
                      onLongPress: isParent && group.category != null && !group.category!.isDefault
                          ? () => _manageCategory(group.category!, items, categories, l)
                          : null,
                      child: Text(categoryLabel(l, group.category)),
                    ),
                    children: [
                      _grid([
                        for (final item in group.members)
                          ItemTile(
                            name: item.name,
                            color: AppColors.surface,
                            caption: quantityLabel(l, item.quantity, item.unit),
                            dimmed: sections.isOnToBuy(item.id),
                            highlighted: _flashId == item.id,
                            onTap: () => _addToBuy(item, sections),
                            onLongPress: () => _openSheet(item, entryMap[item.id]),
                          ),
                      ]),
                    ],
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _newCategory(l),
                    icon: const Icon(Icons.add),
                    label: Text(l.newCategory),
                  ),
                ),
              ],
            ),
          ),
          _inputBar(l, items, categories, sections),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );

  Widget _grid(List<Widget> tiles) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: tiles,
      );

  Widget _inputBar(AppLocalizations l, List<Item> items, List<ItemCategory> categories, ListSections sections) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Autocomplete<Item>(
          optionsViewOpenDirection: OptionsViewOpenDirection.up,
          displayStringForOption: (item) => item.name,
          optionsBuilder: (value) {
            final key = nameKey(value.text);
            if (key.isEmpty) return const Iterable<Item>.empty();
            return items.where((i) => i.key.contains(key)).take(6);
          },
          onSelected: (item) {
            _addToBuy(item, sections);
            _typed?.clear();
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _typed = controller;
            return Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('iNeedField'),
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: l.iNeed,
                      hintStyle: const TextStyle(color: Colors.black45),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _submitTyped(items, categories, sections),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('iNeedAdd'),
                  onPressed: () => _submitTyped(items, categories, sections),
                  icon: const Icon(Icons.add),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _buy(TileView tile, ShoppingList list, Map<String, ItemCategory> categories, AppLocalizations l) {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final userName = ref.read(appUserProvider).valueOrNull?.name ?? '';
    final repo = ref.read(listRepositoryProvider);
    final receipt = repo.prepareBuy(
      list: list,
      item: tile.item,
      category: categories[tile.item.categoryId],
      entry: tile.entry,
      uid: uid,
      userName: userName,
      now: ref.read(clockProvider)(),
    );
    fireAndForget(repo.commitBuy(receipt));

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final controller = messenger.showSnackBar(SnackBar(
      content: Text(l.boughtItem(tile.item.name)),
      action: SnackBarAction(label: l.undo, onPressed: () => fireAndForget(repo.undoBuy(receipt))),
    ));
    // Close after 5 s even if the platform keeps action snackbars open for accessibility.
    _snackTimer?.cancel();
    _snackTimer = Timer(const Duration(seconds: 5), controller.close);
  }

  void _addToBuy(Item item, ListSections sections) {
    if (sections.isOnToBuy(item.id)) {
      _flash(item.id);
      return;
    }
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    fireAndForget(ref.read(listRepositoryProvider).addToBuy(listId: widget.listId, itemId: item.id, uid: uid));
  }

  void _submitTyped(List<Item> items, List<ItemCategory> categories, ListSections sections) {
    final controller = _typed;
    final uid = ref.read(currentUidProvider);
    if (controller == null || uid == null) return;
    final text = controller.text;
    final catalogRepo = ref.read(catalogRepositoryProvider);
    final existing = catalogRepo.findByName(text, items);
    if (existing == null && nameKey(text).isEmpty) return;
    final other = categories.where((c) => c.isDefault).firstOrNull;
    if (existing == null && other == null) return;
    final item = existing ?? Item(id: catalogRepo.newId(), name: text.trim(), categoryId: other!.id);
    if (existing == null) {
      fireAndForget(catalogRepo.saveItem(item, uid: uid, isNew: true));
    }
    _addToBuy(item, sections);
    controller.clear();
  }

  void _flash(String itemId) {
    setState(() => _flashId = itemId);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flashId = null);
    });
  }

  void _openSheet(Item item, Entry? entry) =>
      showItemSheet(context, item: item, listId: widget.listId, entry: entry);

  Future<void> _newCategory(AppLocalizations l) async {
    final name = await promptText(context, title: l.newCategory, label: l.categoryName, confirmLabel: l.save);
    final uid = ref.read(currentUidProvider);
    if (name == null || name.trim().isEmpty || uid == null) return;
    final repo = ref.read(catalogRepositoryProvider);
    fireAndForget(repo.addCategory(id: repo.newId(), name: name, uid: uid));
  }

  Future<void> _manageCategory(
    ItemCategory category,
    List<Item> items,
    List<ItemCategory> categories,
    AppLocalizations l,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l.rename),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(l.delete),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final repo = ref.read(catalogRepositoryProvider);
    if (action == 'rename') {
      final name = await promptText(context,
          title: l.rename, label: l.categoryName, initial: category.name, confirmLabel: l.save);
      if (name != null && name.trim().isNotEmpty) fireAndForget(repo.renameCategory(category.id, name));
      return;
    }
    final other = categories.where((c) => c.isDefault).firstOrNull;
    if (other == null) return;
    final ok = await confirm(context, message: l.confirmDeleteCategory(category.name), confirmLabel: l.delete);
    if (ok) {
      fireAndForget(repo.deleteCategory(categoryId: category.id, otherCategoryId: other.id, catalog: items));
    }
  }
}
```

- [ ] **Step 5: Implement the Lists tab**

Create `lib/features/lists/lists_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/dialogs.dart';
import '../common/offline_chip.dart';
import 'list_screen.dart';

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final isParent = ref.watch(isParentProvider);
    final lists = ref.watch(listsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.tabLists), actions: const [OfflineChip()]),
      floatingActionButton: isParent
          ? FloatingActionButton.extended(
              key: const Key('newListFab'),
              onPressed: () => _create(context, ref, l),
              icon: const Icon(Icons.add),
              label: Text(l.newList),
            )
          : null,
      body: lists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l.somethingWentWrong)),
        data: (lists) => lists.isEmpty
            ? Center(child: Text(isParent ? l.noListsParent : l.noListsChild))
            : ListView(
                children: [
                  for (final list in lists)
                    ListTile(
                      title: Text(list.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => ListScreen(listId: list.id)),
                      ),
                      onLongPress: isParent ? () => _manage(context, ref, list, l) : null,
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final name = await promptText(context, title: l.newList, label: l.listName, confirmLabel: l.create);
    final uid = ref.read(currentUidProvider);
    if (name == null || name.trim().isEmpty || uid == null) return;
    fireAndForget(ref.read(listRepositoryProvider).createList(name: name, uid: uid));
  }

  Future<void> _manage(BuildContext context, WidgetRef ref, ShoppingList list, AppLocalizations l) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l.rename),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(l.delete),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final repo = ref.read(listRepositoryProvider);
    if (action == 'rename') {
      final name = await promptText(context,
          title: l.rename, label: l.listName, initial: list.name, confirmLabel: l.save);
      if (name != null && name.trim().isNotEmpty) fireAndForget(repo.renameList(list.id, name));
      return;
    }
    if (await confirm(context, message: l.confirmDeleteList(list.name), confirmLabel: l.delete)) {
      fireAndForget(repo.deleteList(list.id));
    }
  }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/list_screen_test.dart test/features/lists_screen_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/features/lists test/features/list_screen_test.dart test/features/lists_screen_test.dart
git commit -m "feat(lists): list screen with To buy, Recently used, catalog and I need box"
```

---
### Task 11: History screen

**Files:**
- Create: `lib/core/history.dart`, `lib/features/history/history_screen.dart`
- Test: `test/core/history_test.dart`, `test/features/history_screen_test.dart`

**Interfaces:**
- Consumes: `Purchase` (Task 3); `parseNumber` (Task 2); providers, `promptText`, `confirm`, `quantityLabel` (Task 8)
- Produces: `class DayGroup{day, purchases}`, `List<DayGroup> groupPurchasesByDay(Iterable<Purchase>)`, `class HistoryScreen()` (list filter key `historyFilter`)

- [ ] **Step 1: Write the failing tests**

Create `test/core/history_test.dart`:

```dart
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
```

Create `test/features/history_screen_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/features/history/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<void> addPurchase(FakeFirebaseFirestore db, String id, String item, String listId,
    String listName, DateTime at, {double? price}) {
  return db.doc('families/f1/purchases/$id').set(Purchase(
        id: id, itemId: item.toLowerCase(), itemName: item, categoryName: '',
        listId: listId, listName: listName, quantity: 2, unit: 'L', price: price,
        boughtBy: 'u2', boughtByName: 'Sara', boughtAt: at,
      ).toMap());
}

Future<FakeFirebaseFirestore> seedHistory() async {
  final db = await seedFamily();
  await db.doc('families/f1/lists/l2').set({'name': 'Weekend', 'createdAt': DateTime(2026, 2, 1)});
  await addPurchase(db, 'p1', 'Milk', 'l1', 'Home', DateTime(2026, 9, 30, 10));
  await addPurchase(db, 'p2', 'Bread', 'l2', 'Weekend', DateTime(2026, 9, 30, 18), price: 4.5);
  await addPurchase(db, 'p3', 'Cheese', 'l1', 'Home', DateTime(2026, 9, 28, 9));
  return db;
}

void main() {
  testWidgets('shows purchases grouped by day with prices', (tester) async {
    final db = await seedHistory();
    await pumpWithFamily(tester, db: db, child: const HistoryScreen());
    expect(find.text(DateFormat.yMMMMEEEEd('en').format(DateTime(2026, 9, 30))), findsOneWidget);
    expect(find.text(DateFormat.yMMMMEEEEd('en').format(DateTime(2026, 9, 28))), findsOneWidget);
    expect(find.text('4.50 SAR'), findsOneWidget);
    expect(find.text('Add price'), findsNWidgets(2));
  });

  testWidgets('a price can be added later', (tester) async {
    final db = await seedHistory();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const HistoryScreen());
    await tester.tap(find.text('Add price').first);
    await settle(tester);
    await tester.enterText(find.byKey(const Key('promptField')), '١٢٫٥');
    await tester.tap(find.byKey(const Key('promptConfirm')));
    await settle(tester);
    expect((await db.doc('families/f1/purchases/p1').get()).data()!['price'], 12.5);
  });

  testWidgets('filtering by list hides other lists', (tester) async {
    final db = await seedHistory();
    await pumpWithFamily(tester, db: db, child: const HistoryScreen());
    await tester.tap(find.byKey(const Key('historyFilter')));
    await settle(tester);
    await tester.tap(find.text('Weekend').last);
    await settle(tester);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Cheese'), findsNothing);
  });

  testWidgets('parents can delete a record; children cannot', (tester) async {
    final db = await seedHistory();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const HistoryScreen());
    await tester.longPress(find.text('Milk'));
    await settle(tester);
    expect(find.byKey(const Key('confirmYes')), findsNothing);

    await pumpWithFamily(tester, db: db, child: const HistoryScreen());
    await tester.longPress(find.text('Milk'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirmYes')));
    await settle(tester);
    expect((await db.doc('families/f1/purchases/p1').get()).exists, isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/history_test.dart test/features/history_screen_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/core/history.dart'`.

- [ ] **Step 3: Implement**

Create `lib/core/history.dart`:

```dart
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
```

Create `lib/features/history/history_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/formatting.dart';
import '../../app/providers.dart';
import '../../core/history.dart';
import '../../core/models.dart';
import '../../core/text.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/dialogs.dart';
import '../common/offline_chip.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _listFilter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final isParent = ref.watch(isParentProvider);
    final lists = ref.watch(listsProvider).valueOrNull ?? const <ShoppingList>[];
    final purchasesAsync = ref.watch(purchasesProvider);
    // A filter on a list that has since been deleted falls back to "All lists".
    final filter = lists.any((x) => x.id == _listFilter) ? _listFilter : null;

    return Scaffold(
      appBar: AppBar(title: Text(l.tabHistory), actions: const [OfflineChip()]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String?>(
              key: const Key('historyFilter'),
              isExpanded: true,
              value: filter,
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l.allLists)),
                for (final list in lists) DropdownMenuItem<String?>(value: list.id, child: Text(list.name)),
              ],
              onChanged: (value) => setState(() => _listFilter = value),
            ),
          ),
          Expanded(
            child: purchasesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(child: Text(l.somethingWentWrong)),
              data: (purchases) {
                final shown = filter == null ? purchases : purchases.where((p) => p.listId == filter);
                final groups = groupPurchasesByDay(shown);
                if (groups.isEmpty) return Center(child: Text(l.noPurchases));
                return ListView(
                  children: [
                    for (final group in groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          DateFormat.yMMMMEEEEd(lang).format(group.day),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      for (final p in group.purchases)
                        ListTile(
                          title: Text(p.itemName),
                          subtitle: Text([
                            quantityLabel(l, p.quantity, p.unit),
                            p.boughtByName,
                            p.listName,
                          ].where((s) => s.isNotEmpty).join(' · ')),
                          trailing: TextButton(
                            onPressed: () => _editPrice(p, l),
                            child: Text(p.price == null
                                ? l.addPrice
                                : '${NumberFormat('#,##0.00', 'en').format(p.price)} ${l.currencySar}'),
                          ),
                          onTap: () => _editPrice(p, l),
                          onLongPress: isParent ? () => _delete(p, l) : null,
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPrice(Purchase p, AppLocalizations l) async {
    final text = await promptText(
      context,
      title: p.itemName,
      label: l.price,
      initial: p.price == null ? '' : formatNumber(p.price!),
      confirmLabel: l.save,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    if (text == null) return;
    // Empty clears the price; unreadable input is ignored.
    final price = parseNumber(text);
    if (text.trim().isNotEmpty && price == null) return;
    fireAndForget(ref.read(purchaseRepositoryProvider).setPrice(p.id, price));
  }

  Future<void> _delete(Purchase p, AppLocalizations l) async {
    if (await confirm(context, message: '${l.delete} ${p.itemName}?', confirmLabel: l.delete)) {
      fireAndForget(ref.read(purchaseRepositoryProvider).delete(p.id));
    }
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/history_test.dart test/features/history_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/history.dart lib/features/history test/core/history_test.dart test/features/history_screen_test.dart
git commit -m "feat(history): purchase history with list filter and later price entry"
```

---

### Task 12: Family screen (members, roles, join code, language, leave, sign out)

**Files:**
- Create: `lib/features/family/family_screen.dart`
- Test: `test/features/family_screen_test.dart`

**Interfaces:**
- Consumes: `FamilyRepository`, `LastParentException` (Task 5); providers, `confirm` (Task 8); `tileLetter` (Task 2)
- Produces: `class FamilyScreen()`. Keys: `regenerateCode`, `memberMenu-<uid>`, `leaveFamily`, `signOut`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/family_screen_test.dart`:

```dart
import 'package:family_app/features/family/family_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

void main() {
  testWidgets('shows family, code and members', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const FamilyScreen());
    expect(find.text('Join code: ABC234'), findsOneWidget);
    expect(find.text('Dad'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
  });

  testWidgets('a parent can promote a child', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const FamilyScreen());
    await tester.tap(find.byKey(const Key('memberMenu-u2')));
    await settle(tester);
    await tester.tap(find.text('Make parent'));
    await settle(tester);
    expect((await db.doc('families/f1/members/u2').get()).data()!['role'], 'parent');
  });

  testWidgets('children see no member menus and no new-code button', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
    expect(find.byKey(const Key('memberMenu-u1')), findsNothing);
    expect(find.byKey(const Key('regenerateCode')), findsNothing);
  });

  testWidgets('the last parent cannot leave', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const FamilyScreen());
    await tester.tap(find.byKey(const Key('leaveFamily')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirmYes')));
    await settle(tester);
    expect(find.text('The family needs at least one parent.'), findsOneWidget);
    expect((await db.doc('families/f1/members/u1').get()).exists, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('switching language saves it on the user', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const FamilyScreen());
    await tester.tap(find.text('العربية'));
    await settle(tester);
    expect((await db.doc('users/u1').get()).data()!['language'], 'ar');
  });

  testWidgets('a parent can make a new join code', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const FamilyScreen());
    await tester.tap(find.byKey(const Key('regenerateCode')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirmYes')));
    await settle(tester);
    final code = (await db.doc('families/f1').get()).data()!['joinCode'];
    expect(code, isNot('ABC234'));
    expect((await db.doc('joinCodes/ABC234').get()).exists, isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/family_screen_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/features/family/family_screen.dart'`.

- [ ] **Step 3: Implement**

Create `lib/features/family/family_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/models.dart';
import '../../core/text.dart';
import '../../data/family_repository.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/dialogs.dart';
import '../common/offline_chip.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final family = ref.watch(familyProvider).valueOrNull;
    final isParent = ref.watch(isParentProvider);
    final uid = ref.watch(currentUidProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final lang = user?.language ?? Localizations.localeOf(context).languageCode;
    final members = [...(ref.watch(membersProvider).valueOrNull ?? const <Member>[])]
      ..sort((a, b) {
        if (a.role != b.role) return a.role == Role.parent ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(title: Text(l.tabFamily), actions: const [OfflineChip()]),
      body: ListView(
        children: [
          if (family != null)
            ListTile(
              title: Text(family.name, style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text('${l.joinCode}: ${family.joinCode}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l.share,
                    icon: const Icon(Icons.share),
                    onPressed: () => Share.share(l.shareCodeMessage(family.joinCode)),
                  ),
                  if (isParent)
                    IconButton(
                      key: const Key('regenerateCode'),
                      tooltip: l.regenerateCode,
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        final ok = await confirm(context,
                            message: l.confirmRegenerateCode, confirmLabel: l.regenerateCode);
                        if (ok) await ref.read(familyRepositoryProvider).regenerateCode(family.id);
                      },
                    ),
                ],
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l.members, style: Theme.of(context).textTheme.titleSmall),
          ),
          for (final m in members)
            ListTile(
              leading: CircleAvatar(child: Text(tileLetter(m.name))),
              title: Text(m.name),
              subtitle: Text(m.role == Role.parent ? l.parent : l.child),
              trailing: isParent && m.uid != uid && family != null
                  ? PopupMenuButton<String>(
                      key: ValueKey('memberMenu-${m.uid}'),
                      onSelected: (action) => _onMemberAction(context, ref, family.id, m, action),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'role',
                          child: Text(m.role == Role.parent ? l.makeChild : l.makeParent),
                        ),
                        PopupMenuItem(value: 'remove', child: Text(l.removeMember)),
                      ],
                    )
                  : null,
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.language),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'ar', label: Text('العربية')),
                ],
                selected: {lang == 'ar' ? 'ar' : 'en'},
                onSelectionChanged: (selection) {
                  if (uid != null) {
                    fireAndForget(ref.read(familyRepositoryProvider).setLanguage(uid, selection.first));
                  }
                },
              ),
            ),
          ),
          ListTile(
            key: const Key('leaveFamily'),
            leading: const Icon(Icons.logout),
            title: Text(l.leaveFamily),
            onTap: family == null || uid == null ? null : () => _leave(context, ref, family.id, uid),
          ),
          ListTile(
            key: const Key('signOut'),
            leading: const Icon(Icons.power_settings_new),
            title: Text(l.signOut),
            onTap: () async {
              await ref.read(googleSignInProvider).signOut();
              await ref.read(firebaseAuthProvider).signOut();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _onMemberAction(
    BuildContext context,
    WidgetRef ref,
    String familyId,
    Member m,
    String action,
  ) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(familyRepositoryProvider);
    try {
      if (action == 'role') {
        await repo.setRole(familyId, m.uid, m.role == Role.parent ? Role.child : Role.parent);
      } else {
        final ok = await confirm(context, message: l.confirmRemoveMember(m.name), confirmLabel: l.removeMember);
        if (ok) await repo.removeMember(familyId, m.uid);
      }
    } on LastParentException {
      messenger.showSnackBar(SnackBar(content: Text(l.lastParentError)));
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, String familyId, String uid) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirm(context, message: l.confirmLeaveFamily, confirmLabel: l.leaveFamily)) return;
    try {
      await ref.read(familyRepositoryProvider).leaveFamily(familyId, uid);
    } on LastParentException {
      messenger.showSnackBar(SnackBar(content: Text(l.lastParentError)));
    }
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/family_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/family/family_screen.dart test/features/family_screen_test.dart
git commit -m "feat(family): members, roles, join code, language, leave and sign out"
```

---

### Task 13: App shell — sign-in, onboarding, root gate, main

**Files:**
- Create: `lib/app/app.dart`, `lib/features/auth/sign_in_screen.dart`, `lib/features/family/onboarding_screen.dart`
- Modify: `lib/main.dart` (replace), `test/smoke_test.dart` (delete; superseded)
- Test: `test/app/root_gate_test.dart`

**Interfaces:**
- Consumes: everything above
- Produces: `class FamilyApp`, `class RootGate`, `class HomeShell`, `class SignInScreen`, `class OnboardingScreen`. Onboarding keys: `familyNameField`, `createFamilyButton`, `joinCodeField`, `joinFamilyButton`.

- [ ] **Step 1: Write the failing tests**

Delete `test/smoke_test.dart`. Create `test/app/root_gate_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

void main() {
  testWidgets('signed out shows the sign-in screen', (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpWithFamily(tester, db: db, uid: '', child: const RootGate());
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('signed in without a family shows onboarding; creating one opens the app', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u9').set({'name': 'Firas', 'email': 'f@x.com', 'familyId': null, 'language': 'en'});
    await pumpWithFamily(tester, db: db, uid: 'u9', child: const RootGate());
    expect(find.text('Create a family'), findsWidgets);

    await tester.enterText(find.byKey(const Key('familyNameField')), 'Our home');
    await tester.tap(find.byKey(const Key('createFamilyButton')));
    await settle(tester);
    await settle(tester);

    final user = (await db.doc('users/u9').get()).data()!;
    expect(user['familyId'], isNotNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('joining with a code opens the app', (tester) async {
    final db = await seedFamily();
    await db.doc('users/u9').set({'name': 'Mum', 'email': 'm@x.com', 'familyId': null, 'language': 'en'});
    await pumpWithFamily(tester, db: db, uid: 'u9', child: const RootGate());
    await tester.enterText(find.byKey(const Key('joinCodeField')), 'abc 234');
    await tester.tap(find.byKey(const Key('joinFamilyButton')));
    await settle(tester);
    await settle(tester);
    expect((await db.doc('families/f1/members/u9').get()).data()!['role'], 'child');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('a wrong code shows an error', (tester) async {
    final db = await seedFamily();
    await db.doc('users/u9').set({'name': 'Mum', 'email': 'm@x.com', 'familyId': null, 'language': 'en'});
    await pumpWithFamily(tester, db: db, uid: 'u9', child: const RootGate());
    await tester.enterText(find.byKey(const Key('joinCodeField')), 'ZZZZZZ');
    await tester.tap(find.byKey(const Key('joinFamilyButton')));
    await settle(tester);
    expect(find.text("That code doesn't match any family."), findsOneWidget);
  });

  testWidgets('a member of a family sees the home shell', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const RootGate());
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('a removed member is sent back to onboarding', (tester) async {
    final db = await seedFamily();
    await db.doc('families/f1/members/u2').delete();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const RootGate());
    await settle(tester);
    expect((await db.doc('users/u2').get()).data()!['familyId'], isNull);
    expect(find.byKey(const Key('createFamilyButton')), findsOneWidget);
  });
}
```

The first test passes `uid: ''`. To make an empty uid mean "signed out", `RootGate` treats both `null` and `''` as signed out.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/app/root_gate_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/app/app.dart'`.

- [ ] **Step 3: Implement sign-in**

Create `lib/features/auth/sign_in_screen.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    final l = AppLocalizations.of(context)!;
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await ref.read(googleSignInProvider).signIn();
      if (account == null) return; // user cancelled
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final result = await ref.read(firebaseAuthProvider).signInWithCredential(credential);
      final user = result.user!;
      await ref.read(familyRepositoryProvider).ensureUser(
            uid: user.uid,
            name: user.displayName ?? user.email ?? '',
            email: user.email ?? '',
            language: language == 'ar' ? 'ar' : 'en',
          );
    } catch (_) {
      if (mounted) setState(() => _error = l.signInFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.appTitle, style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 32),
              if (_busy)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.login),
                  label: Text(l.signInWithGoogle),
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement onboarding**

Create `lib/features/family/onboarding_screen.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/family_repository.dart';
import '../../l10n/app_localizations.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _familyName = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _familyName.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Creating or joining needs the server, so these writes are awaited with a timeout.
  Future<void> _run(Future<void> Function(FamilyRepository repo, String uid, String name) action) async {
    final l = AppLocalizations.of(context)!;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final name = ref.read(appUserProvider).valueOrNull?.name ?? '';
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      await action(ref.read(familyRepositoryProvider), uid, name).timeout(const Duration(seconds: 20));
    } on JoinCodeNotFound {
      error = l.joinCodeNotFound;
    } on TimeoutException {
      error = l.needsConnection;
    } catch (_) {
      error = l.somethingWentWrong;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.createFamily, style: Theme.of(context).textTheme.titleMedium),
                  TextField(
                    key: const Key('familyNameField'),
                    controller: _familyName,
                    decoration: InputDecoration(labelText: l.familyName),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('createFamilyButton'),
                    onPressed: _busy
                        ? null
                        : () => _run((repo, uid, name) => repo.createFamily(
                              uid: uid,
                              userName: name,
                              familyName: _familyName.text.trim().isEmpty ? l.appTitle : _familyName.text.trim(),
                              otherCategoryName: l.otherCategory,
                            )),
                    child: Text(l.create),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.joinFamily, style: Theme.of(context).textTheme.titleMedium),
                  TextField(
                    key: const Key('joinCodeField'),
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(labelText: l.joinCode),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('joinFamilyButton'),
                    onPressed: _busy
                        ? null
                        : () => _run((repo, uid, name) =>
                            repo.joinFamily(uid: uid, userName: name, code: _code.text)),
                    child: Text(l.join),
                  ),
                ],
              ),
            ),
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Implement the app, root gate and home shell**

Create `lib/app/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/write.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/family/family_screen.dart';
import '../features/family/onboarding_screen.dart';
import '../features/history/history_screen.dart';
import '../features/lists/lists_screen.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'theme.dart';

class FamilyApp extends ConsumerWidget {
  const FamilyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Family',
      theme: buildTheme(),
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RootGate(),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(authReadyProvider)) return const _Loading();
    final uid = ref.watch(currentUidProvider);
    if (uid == null || uid.isEmpty) return const SignInScreen();
    return ref.watch(appUserProvider).when(
          loading: () => const _Loading(),
          error: (_, __) => const OnboardingScreen(),
          data: (user) => user?.familyId == null
              ? const OnboardingScreen()
              : const _MembershipGuard(child: HomeShell()),
        );
  }
}

/// If this user was removed from the family on another phone, clear their familyId.
class _MembershipGuard extends ConsumerWidget {
  const _MembershipGuard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myMemberProvider).when(
          loading: () => const _Loading(),
          error: (_, __) => const _Loading(),
          data: (member) {
            if (member != null) return child;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final uid = ref.read(currentUidProvider);
              if (uid != null) fireAndForget(ref.read(familyRepositoryProvider).clearFamily(uid));
            });
            return const _Loading();
          },
        );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [ListsScreen(), HistoryScreen(), FamilyScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.checklist), label: l.tabLists),
          NavigationDestination(icon: const Icon(Icons.receipt_long), label: l.tabHistory),
          NavigationDestination(icon: const Icon(Icons.group), label: l.tabFamily),
        ],
      ),
    );
  }
}
```

Replace `lib/main.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // reads android/app/google-services.json
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  runApp(const ProviderScope(child: FamilyApp()));
}
```

- [ ] **Step 6: Run the full suite**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: no errors or warnings; all tests pass.

- [ ] **Step 7: Commit**

```bash
git add -A lib test
git commit -m "feat(app): sign-in, onboarding, root gate and bottom navigation"
```

---

### Task 14: Signed release builds and setup guide

**Files:**
- Create: `.github/workflows/keystore.yml`, `.github/workflows/release.yml`, `docs/SETUP.md`

**Interfaces:**
- Consumes: `android/app/build.gradle.kts` signing config (Task 1), which reads `android/key.properties` with keys `storeFile`, `storePassword`, `keyAlias`, `keyPassword`
- Produces: GitHub secrets contract, as follows. `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `GOOGLE_SERVICES_JSON` (the raw JSON). A published GitHub Release gets `family-app-<tag>.apk` attached.

- [ ] **Step 1: Add the one-time key generation workflow**

Create `.github/workflows/keystore.yml`:

```yaml
name: Generate signing key (run once)

on:
  workflow_dispatch:

jobs:
  keystore:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - name: Generate keystore
        run: |
          PASS=$(openssl rand -hex 16)
          keytool -genkeypair -keystore release.jks -alias family -keyalg RSA -keysize 2048 \
            -validity 10000 -dname "CN=Family App" -storepass "$PASS" -keypass "$PASS"
          base64 -w0 release.jks > ANDROID_KEYSTORE_BASE64.txt
          printf 'ANDROID_KEY_ALIAS=family\nANDROID_KEYSTORE_PASSWORD=%s\nANDROID_KEY_PASSWORD=%s\n' "$PASS" "$PASS" > secrets.txt
          keytool -list -v -keystore release.jks -alias family -storepass "$PASS" | grep -E 'SHA1:|SHA256:' > fingerprints.txt
          cat fingerprints.txt
      - uses: actions/upload-artifact@v4
        with:
          name: signing-key
          path: |
            release.jks
            ANDROID_KEYSTORE_BASE64.txt
            secrets.txt
            fingerprints.txt
          retention-days: 1
```

- [ ] **Step 2: Add the release workflow**

Create `.github/workflows/release.yml`:

```yaml
name: Release APK

on:
  release:
    types: [published]

permissions:
  contents: write

jobs:
  apk:
    runs-on: ubuntu-latest
    env:
      TAG: ${{ github.event.release.tag_name }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - name: Write signing key and Firebase config
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
          GOOGLE_SERVICES_JSON: ${{ secrets.GOOGLE_SERVICES_JSON }}
        run: |
          echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/release.jks
          cat > android/key.properties <<EOF
          storeFile=release.jks
          storePassword=$ANDROID_KEYSTORE_PASSWORD
          keyAlias=$ANDROID_KEY_ALIAS
          keyPassword=$ANDROID_KEY_PASSWORD
          EOF
          printf '%s' "$GOOGLE_SERVICES_JSON" > android/app/google-services.json
      - run: flutter pub get
      - run: flutter test
      - run: flutter build apk --release --build-name "${TAG#v}" --build-number "${{ github.run_number }}"
      - run: cp build/app/outputs/flutter-apk/app-release.apk "family-app-${TAG}.apk"
      - uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ github.event.release.tag_name }}
          files: family-app-*.apk
```

- [ ] **Step 3: Write the setup guide**

Create `docs/SETUP.md`:

```markdown
# Family App — one-time setup and releasing

Everything happens in a web browser: GitHub and the Firebase console. Nothing needs to be installed on your computer.

## 1. Create the signing key (once, ever)

1. In the GitHub repository, open **Actions → Generate signing key (run once) → Run workflow**.
2. When the run finishes, open it and download the **signing-key** artifact (a zip). It is deleted from GitHub after one day.
3. **Keep `release.jks` and `secrets.txt` safe forever**, for example in your password manager or a private Drive folder. If you lose them, future updates cannot install over the app, and everyone would have to uninstall and reinstall it.
4. In **Settings → Secrets and variables → Actions → New repository secret**, add:
   - `ANDROID_KEYSTORE_BASE64`: the whole contents of `ANDROID_KEYSTORE_BASE64.txt`
   - `ANDROID_KEY_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`: the values in `secrets.txt`
5. Keep `fingerprints.txt` open; you need it in step 2.

## 2. Create the Firebase project

1. Go to https://console.firebase.google.com → **Add project** → name it "family-app". You can turn Google Analytics off.
2. **Build → Authentication → Get started → Sign-in method → Google → Enable**. Pick your email as the support email, then Save.
3. **Build → Firestore Database → Create database → Start in production mode**. Choose the location closest to you (for example `me-central2`, Dammam, if listed).
4. In Firestore, open the **Rules** tab, replace everything with the contents of `firestore.rules` from this repository, and click **Publish**.
5. **Project settings (gear icon) → Your apps → Add app → Android**:
   - Package name: `com.family.family_app`
   - Debug signing certificate SHA-1: the SHA1 value from `fingerprints.txt`
   - Register, then **download `google-services.json`**.
6. Back in Project settings, open the Android app and **Add fingerprint** again with the SHA256 value.
7. In GitHub, add one more secret, `GOOGLE_SERVICES_JSON`, and paste the entire contents of `google-services.json`.

## 3. Release a version

1. In GitHub, open **Releases → Draft a new release**.
2. Create a new tag, e.g. `v1.0.0` (use `v1.0.1`, `v1.1.0`… for later updates), and click **Publish release**.
3. The **Release APK** workflow runs for about 10 minutes, then attaches `family-app-v1.0.0.apk` to the release.

## 4. Install on each phone

1. On the phone, open the release page (or send the APK over WhatsApp or Drive) and download the APK.
2. Tap it. The first time, Android asks you to allow **Install unknown apps** for that app (Chrome, WhatsApp…). Allow it, then install.
3. Open **Family** and sign in with Google. The first person creates the family. Everyone else taps **Join a family** and enters the code shown on the Family tab.
4. Promote your wife (or anyone else) to parent from the Family tab.

## Updating

Publish a new release with a higher tag, then install the new APK over the old one. Data lives in Firebase, so nothing is lost.

If `firestore.rules` changes in a later version, paste it into the Firestore **Rules** tab again and click Publish.
```

- [ ] **Step 4: Verify the workflows parse**

Run: `python3 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]; print('ok')" .github/workflows/*.yml`
Expected: `ok`

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/keystore.yml .github/workflows/release.yml docs/SETUP.md
git commit -m "ci: signed release APK workflow, key generation and setup guide"
```

- [ ] **Step 6: Manual release checklist (after Firas completes docs/SETUP.md)**

Run through this on two phones, one signed in as a parent and one as a child:
1. The parent creates the family; the child joins with the code typed in lowercase.
2. The parent creates the lists "Home" and "Pharmacy"; the child can't see "New list".
3. The child types "labneh" in Home, then taps it in To buy. It moves to Recently used, and "Undo" appears for about 5 seconds.
4. The parent's phone shows the change within a couple of seconds.
5. Turn on airplane mode on the child's phone, buy an item, then turn airplane mode off. The item syncs, and "Offline" shows while disconnected.
6. Switch to Arabic on the Family tab. The layout flips to right-to-left, and "حليب" gets a ح tile.
7. Set Milk's expiry to 1 day and buy it. The next day it's back in To buy.
8. On the History tab, add a price to a purchase.
