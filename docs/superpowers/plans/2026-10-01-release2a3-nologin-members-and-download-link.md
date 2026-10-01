# Release 2a.3 — Members without a login, and a download link — Implementation Plan

> **For agentic workers:** execute task by task through the project-manager → developer → tester loop in `CLAUDE.md` (Firas's chosen method). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let parents add family members who have no login, so they can be given chores; and publish the app from a public GitHub repository behind one permanent download link that an "Invite to family" message carries.

**Architecture:**
- No-login members live in the existing `families/{f}/members` collection. Their id is `nl_` + 20 random letters and digits, and they carry a `noLogin: true` flag, so every chores screen already treats them like a child.
- Firestore rules gain one create branch and one update branch for them (parents only).
- The download link reaches the app at build time through `--dart-define=APP_DOWNLOAD_URL=…`, which the GitHub release workflow sets from the repository name. Local builds simply have no link.

**Tech Stack:** Flutter 3.47.5 / Dart 3.13, Riverpod 2, cloud_firestore, gen-l10n (ar/en), fake_cloud_firestore, the Firebase emulator + mocha for rules, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-01-release2a3-nologin-members-and-download-link-design.md` (approved 2026-10-01).

## Global Constraints

- **Release 2a carries over.** Its constraints and accepted must-keeps still apply. In particular:
  - `flutter analyze --no-fatal-infos` reports no errors or warnings, and `flutter test` passes;
  - UI never `await`s an offline-capable write (`fireAndForget`);
  - never commit `android/key.properties`, `*.jks`, `*.keystore` or `android/app/google-services.json`.
- **Order:** this plan starts AFTER the 1.2.2 name fix (`docs/progress/briefs/r2a2-names-rework.md`) is committed and tested. Family-screen anchors below refer to the file as 1.2.2 leaves it. Adapt anchors to the current text, and report each adaptation.
- **No-login member id:** `^nl_[A-Za-z0-9]{20}$`. Fields: `name` (1–80 characters), `role: 'child'`, `noLogin: true`, `color` (0–7), `pictureTiles` (bool), `joinedAt`, `createdBy` (the parent's uid), and optionally `displayName` (1–40 characters).
- **Parents only** create, edit (`name`, `displayName`, `color`, `pictureTiles`) and remove no-login members. `role`, `noLogin` and `createdBy` never change. Only parents can tick their chores; the existing rules already ensure this.
- **Download link:** `https://github.com/<owner>/<repo>/releases/latest/download/family-app.apk`, built from `${{ github.repository }}`. The repository is public.
- **Strings:** every new user-facing string goes in both ARB files with real Arabic, then `flutter gen-l10n`.
- **Rules tests:** run `cd rules-tests && npm run emulate` with JAVA_HOME set and the Android Studio `jbr\bin` on PATH.
- **Commit trailer:** `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A child taps a no-login member's chore on the board, week view or Today.** Nothing is written, and the rules would refuse it anyway. Test: Task 2, "a child cannot tick a no-login member's chore anywhere".
2. **A parent tries to turn a no-login member into a parent** (through the existing role menu or a crafted write). The menu doesn't offer it, and the rules refuse it. Tests: Task 1 rules "role, noLogin and createdBy never change"; Task 2 "no Make parent for a no-login member".
3. **A no-login member is removed while they still have chores.** Their chores move under "Former member", and their past ticks stay. Test: Task 2, "removing a no-login member moves their chores to Former member".
4. **An Arabic name for a no-login member** on a 320×640 phone at text scale 1.3. The name is readable, the initial is right, and nothing overflows. Test: Task 2, "Arabic no-login member on a small phone".
5. **An invite sent from a build with no download link** (a local build). The message still has the code and contains no broken link. Test: Task 3, "invite without a link still carries the code".

---

### Task 1: No-login members — model, id, colour, repository and rules

**Files:**
- Create: `lib/core/no_login.dart`, `test/core/no_login_test.dart`
- Modify:
  - `lib/core/models.dart` (`Member.noLogin`)
  - `lib/core/member_colors.dart` (`nextFreeColor`)
  - `lib/data/family_repository.dart` (`addNoLoginMember`)
  - `firestore.rules` (the `members/{m}` match)
  - `rules-tests/test/rules.test.js`
- Test: `test/core/member_colors_test.dart` (append), `test/data/family_repository_test.dart` (append)

**Interfaces:**
- Consumes: `Member`, `missingColorAssignments` (existing); `FamilyRepository._members(f)` (existing private helper).
- Produces:
  - `const String noLoginPrefix = 'nl_';`
  - `String newNoLoginId([Random? random])`
  - `bool isNoLoginId(String id)`
  - `Member` gains `final bool noLogin;` (default false; `fromMap` reads `m['noLogin'] == true`).
  - `int nextFreeColor(List<Member> all)`: the lowest palette index 0–7 not used by any member's effective colour; when all 8 are used, `all.length % 8`.
  - `Future<String> FamilyRepository.addNoLoginMember({required String familyId, required String name, required String createdBy, required int color, DateTime? now, Random? random})`: returns the new id.

- [ ] **Step 1: Write the failing unit tests**

Create `test/core/no_login_test.dart`:

```dart
import 'dart:math';

import 'package:family_app/core/models.dart';
import 'package:family_app/core/no_login.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new ids look like nl_ plus 20 letters or digits', () {
    final id = newNoLoginId(Random(1));
    expect(id, matches(RegExp(r'^nl_[A-Za-z0-9]{20}$')));
    expect(isNoLoginId(id), isTrue);
  });

  test('ids differ from one call to the next', () {
    final random = Random(7);
    final ids = {for (var i = 0; i < 500; i++) newNoLoginId(random)};
    expect(ids, hasLength(500));
  });

  test('a Google sign-in id is never a no-login id', () {
    expect(isNoLoginId('Xy3kP9aQ2bR7sT1uV5wZ8cD4eF6g'), isFalse);
    expect(isNoLoginId('nl_short'), isFalse);
    expect(isNoLoginId('nl_ABCDEFGHIJKLMNOPQRS!'), isFalse);
  });

  test('Member.fromMap reads noLogin and treats anything else as false', () {
    expect(Member.fromMap('nl_x', {'name': 'Yusuf', 'role': 'child', 'noLogin': true}).noLogin, isTrue);
    expect(Member.fromMap('u1', {'name': 'Dad', 'role': 'parent'}).noLogin, isFalse);
    expect(Member.fromMap('u2', {'name': 'Sara', 'noLogin': 'yes'}).noLogin, isFalse);
  });
}
```

Append to `test/core/member_colors_test.dart` (inside `main`):

```dart
  group('nextFreeColor', () {
    test('the lowest colour nobody uses', () {
      const all = [
        Member(uid: 'a', name: 'A', role: Role.parent, color: 0),
        Member(uid: 'b', name: 'B', role: Role.child, color: 1),
        Member(uid: 'c', name: 'C', role: Role.child, color: 3),
      ];
      expect(nextFreeColor(all), 2);
    });
    test('counts members whose colour is not saved yet', () {
      const all = [
        Member(uid: 'a', name: 'A', role: Role.parent, color: 0),
        Member(uid: 'b', name: 'B', role: Role.child),
      ];
      expect(nextFreeColor(all), 2);
    });
    test('wraps when all 8 are taken', () {
      final all = [for (var i = 0; i < 9; i++) Member(uid: 'm$i', name: 'M$i', role: Role.child, color: i % 8)];
      expect(nextFreeColor(all), 9 % 8);
    });
    test('an empty family starts at 0', () => expect(nextFreeColor(const []), 0));
  });
```

Append to `test/data/family_repository_test.dart` (inside `main`; it already imports fake_cloud_firestore, the repository and `seedFamily`):

```dart
  test('addNoLoginMember writes a child with no login', () async {
    final db = await seedFamily();
    final repo = FamilyRepository(db);
    final id = await repo.addNoLoginMember(
      familyId: 'f1', name: '  Yusuf  ', createdBy: 'u1', color: 4,
      now: DateTime(2026, 10, 1, 9), random: Random(3),
    );
    expect(id, matches(RegExp(r'^nl_[A-Za-z0-9]{20}$')));
    final data = (await db.doc('families/f1/members/$id').get()).data()!;
    expect(data['name'], 'Yusuf');
    expect(data['role'], 'child');
    expect(data['noLogin'], isTrue);
    expect(data['color'], 4);
    expect(data['pictureTiles'], isFalse);
    expect(data['createdBy'], 'u1');
    expect(data.containsKey('joinedAt'), isTrue);
  });
```

(Add `import 'dart:math';` at the top of that file if it isn't there.)

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/core/no_login_test.dart test/core/member_colors_test.dart test/data/family_repository_test.dart`
Expected: compile errors: `lib/core/no_login.dart` is missing, and `nextFreeColor`, `addNoLoginMember` and `noLogin` are undefined.

- [ ] **Step 3: Implement**

Create `lib/core/no_login.dart`:

```dart
import 'dart:math';

/// Ids of family members who have no login start with this. A Google sign-in
/// id never contains an underscore, so the two can never collide.
const String noLoginPrefix = 'nl_';

const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
final _shape = RegExp(r'^nl_[A-Za-z0-9]{20}$');

/// A new id for a member without a login: `nl_` plus 20 random letters and digits.
String newNoLoginId([Random? random]) {
  final r = random ?? Random.secure();
  final suffix = List.generate(20, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
  return '$noLoginPrefix$suffix';
}

/// Whether [id] is the id of a member without a login.
bool isNoLoginId(String id) => _shape.hasMatch(id);
```

In `lib/core/models.dart`, `Member`:
- add the constructor parameter `this.noLogin = false,` after `this.displayName,`;
- add the field with a doc comment:
  ```dart
  /// A member a parent added who has no login (always a child).
  final bool noLogin;
  ```
- in `fromMap`, pass `noLogin: m['noLogin'] == true,` as the last argument.

In `lib/core/member_colors.dart`, append:

```dart
/// The colour for a new member: the lowest palette index nobody uses (counting
/// colours not saved yet), or `all.length % 8` once all eight are taken.
int nextFreeColor(List<Member> all) {
  final used = {for (final m in all) effectiveColorIndex(m, all)};
  for (var i = 0; i < 8; i++) {
    if (!used.contains(i)) return i;
  }
  return all.length % 8;
}
```

In `lib/data/family_repository.dart`, add `import 'dart:math';` and `import '../core/no_login.dart';`, then add next to `setMemberName`:

```dart
  /// Adds a family member who has no login (a parent action). Returns the new id.
  Future<String> addNoLoginMember({
    required String familyId,
    required String name,
    required String createdBy,
    required int color,
    DateTime? now,
    Random? random,
  }) async {
    final id = newNoLoginId(random);
    await _members(familyId).doc(id).set({
      'name': name.trim(),
      'role': 'child',
      'noLogin': true,
      'color': color,
      'pictureTiles': false,
      'joinedAt': now ?? DateTime.now(),
      'createdBy': createdBy,
    });
    return id;
  }
```

- [ ] **Step 4: Run the unit tests and see them pass**

Run: the Step 2 command. Expected: all pass.

- [ ] **Step 5: Write the failing rules tests**

Append to `rules-tests/test/rules.test.js`:

```js
describe('members without a login (Release 2a.3)', () => {
  const NL = 'nl_ABCDEFGHIJKLMNOPQRST';
  const nl = (who, id = NL) => doc(as(who), `families/${F}/members/${id}`);
  const good = (over = {}) => ({
    name: 'Yusuf', role: 'child', noLogin: true, color: 3, pictureTiles: false,
    joinedAt: Timestamp.now(), createdBy: 'dad', ...over,
  });
  const seedNl = () => env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `families/${F}/members/${NL}`), good());
  });

  it('a parent creates a member without a login', async () => {
    await assertSucceeds(setDoc(nl('dad'), good()));
  });
  it('a child cannot create one', async () => {
    await assertFails(setDoc(nl('kid'), good({ createdBy: 'kid' })));
  });
  it('the id, role, flag, creator and name are checked on create', async () => {
    await assertFails(setDoc(nl('dad', 'nl_short'), good()));
    await assertFails(setDoc(nl('dad', 'yusuf_ABCDEFGHIJKLMNOPQ'), good()));
    await assertFails(setDoc(nl('dad', 'ABCDEFGHIJKLMNOPQRSTUVWXYZab'), good()));
    await assertFails(setDoc(nl('dad'), good({ role: 'parent' })));
    await assertFails(setDoc(nl('dad'), good({ noLogin: false })));
    const { noLogin, ...withoutFlag } = good();
    await assertFails(setDoc(nl('dad'), withoutFlag));
    await assertFails(setDoc(nl('dad'), good({ createdBy: 'kid' })));
    await assertFails(setDoc(nl('dad'), good({ name: '' })));
    await assertFails(setDoc(nl('dad'), good({ name: 'x'.repeat(81) })));
    await assertFails(setDoc(nl('dad'), good({ color: 9 })));
    await assertFails(setDoc(nl('dad'), good({ joinCode: 'ABC234' })));
  });
  it('a parent renames, recolours and sets picture tiles and a display name', async () => {
    await seedNl();
    await assertSucceeds(updateDoc(nl('dad'), { name: 'Yusuf Ali' }));
    await assertSucceeds(updateDoc(nl('dad'), { color: 5, pictureTiles: true }));
    await assertSucceeds(updateDoc(nl('dad'), { displayName: 'Yoyo' }));
    await assertSucceeds(updateDoc(nl('dad'), { displayName: deleteField() }));
  });
  it('role, noLogin and createdBy never change', async () => {
    await seedNl();
    await assertFails(updateDoc(nl('dad'), { role: 'parent' }));
    await assertFails(updateDoc(nl('dad'), { noLogin: false }));
    await assertFails(updateDoc(nl('dad'), { createdBy: 'kid' }));
    await assertFails(updateDoc(nl('dad'), { name: 'Yusuf', role: 'parent' }));
  });
  it('a blank or too-long name is refused on edit', async () => {
    await seedNl();
    await assertFails(updateDoc(nl('dad'), { name: '' }));
    await assertFails(updateDoc(nl('dad'), { name: 'x'.repeat(81) }));
  });
  it('a child cannot edit or remove one', async () => {
    await seedNl();
    await assertFails(updateDoc(nl('kid'), { name: 'Joe' }));
    await assertFails(updateDoc(nl('kid'), { color: 1 }));
    await assertFails(deleteDoc(nl('kid')));
  });
  it('a parent removes one', async () => {
    await seedNl();
    await assertSucceeds(deleteDoc(nl('dad')));
  });
  it('only a parent ticks their chores', async () => {
    await seedNl();
    const utcDay = Math.floor(Date.now() / 86400000);
    const date = new Date(utcDay * 86400000).toISOString().slice(0, 10);
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `families/${F}/chores/yteeth`), {
        title: 'Teeth', assignee: NL, repeat: 'daily', every: 1, weekdays: [],
        startDate: '2026-01-01', createdBy: 'dad', remind: false,
      });
    });
    const done = (doneBy) => ({
      choreId: 'yteeth', date, choreTitle: 'Teeth', assignee: NL,
      doneBy, doneByName: 'Yusuf', doneAt: Timestamp.now(), dayNumber: utcDay,
    });
    await assertFails(setDoc(doc(as('kid'), `families/${F}/choreDone/yteeth_${date}`), done('kid')));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/choreDone/yteeth_${date}`), done(NL)));
    await assertSucceeds(setDoc(doc(as('dad'), `families/${F}/choreDone/yteeth_${date}`), done(NL)));
  });
  it("a parent's role menu cannot touch a no-login member through the normal parent branch", async () => {
    await seedNl();
    await assertFails(updateDoc(nl('dad'), { role: 'child', name: 'Z' }));
  });
});
```

- [ ] **Step 6: Run the rules tests and see the new ones fail**

Run: `cd rules-tests && npm run emulate`
Expected: the creates and parent edits that should succeed FAIL with PERMISSION_DENIED (no create or update branch yet). The refusals may already pass. All existing tests pass.

- [ ] **Step 7: Change `firestore.rules`**

Inside `match /members/{m}`, after `function validNewMember(d) {…}`, add:

```
        // A member a parent added who has no login (Release 2a.3).
        function validNoLoginMember(id, d) {
          return id.matches('^nl_[A-Za-z0-9]{20}$')
            && d.keys().hasOnly(['name', 'role', 'noLogin', 'color', 'pictureTiles',
                                 'displayName', 'joinedAt', 'createdBy'])
            && d.noLogin == true
            && d.role == 'child'
            && d.name is string && d.name.size() >= 1 && d.name.size() <= 80
            && d.createdBy == uid()
            && validNewMember(d)
            && (!('displayName' in d)
              || (d.displayName is string && d.displayName.size() >= 1 && d.displayName.size() <= 40));
        }
```

Change the create rule from `allow create: if signedIn() && uid() == m && validNewMember(request.resource.data) && ( … );` to:

```
        allow create: if (signedIn() && uid() == m && validNewMember(request.resource.data) && (
          … the two existing branches, unchanged …
        )) || (isParent(f) && validNoLoginMember(m, request.resource.data));
```

In the update rule:
- in the first (parent) branch, add `&& resource.data.get('noLogin', false) != true` right after `isParent(f)`;
- add a third branch after the self branch:

```
          || (isParent(f) && resource.data.get('noLogin', false) == true
            && onlyChanges(['name', 'displayName', 'color', 'pictureTiles'])
            && (!changes('name')
              || (request.resource.data.name is string
                && request.resource.data.name.size() >= 1
                && request.resource.data.name.size() <= 80))
            && (!('color' in request.resource.data)
              || (request.resource.data.color is int
                && request.resource.data.color >= 0
                && request.resource.data.color <= 7))
            && (!('pictureTiles' in request.resource.data)
              || request.resource.data.pictureTiles is bool)
            && (!('displayName' in request.resource.data)
              || (request.resource.data.displayName is string
                && request.resource.data.displayName.size() >= 1
                && request.resource.data.displayName.size() <= 40)))
```

The delete rule is unchanged.

- [ ] **Step 8: Run all checks**

Run: `cd rules-tests && npm run emulate`. Expected: everything passes (the previous count + 9).
Run: `flutter analyze --no-fatal-infos` and `flutter test`. Expected: no errors or warnings; all pass.

- [ ] **Step 9: Commit**

```bash
git add lib/core/no_login.dart lib/core/models.dart lib/core/member_colors.dart lib/data/family_repository.dart firestore.rules rules-tests/test/rules.test.js test/core/no_login_test.dart test/core/member_colors_test.dart test/data/family_repository_test.dart
git commit -m "feat(family): members without a login — data and rules"
```

---

### Task 2: No-login members — Family screen and chores

**Files:**
- Modify:
  - `lib/features/family/family_screen.dart`
  - both ARB files
  - `test/support/seed.dart` (add `seedNoLoginMember`)
- Test: `test/features/no_login_member_test.dart` (new)

**Interfaces:**
- Consumes: `addNoLoginMember`, `nextFreeColor`, `Member.noLogin` (Task 1); `setMemberName`, `removeMember`, `memberLabel`, `promptText(…, maxLength:)`, `confirm` (existing); the 1.2.2 member menu with its "Edit name" item.
- Produces:
  - Family screen keys: `Key('addNoLoginMember')` (parents only); `ValueKey('noLoginTag-<id>')` on the "No login" text in a no-login member's row.
  - l10n keys: `addNoLoginMember`, `noLoginTag`.
  - `Future<String> seedNoLoginMember(FakeFirebaseFirestore db, {String id = 'nl_YUSUFabcdefghijklmno', String name = 'Yusuf', int color = 5})` in `test/support/seed.dart`.

- [ ] **Step 1: Add the test seed helper**

Append to `test/support/seed.dart`:

```dart
/// A member without a login in family f1, created by u1.
Future<String> seedNoLoginMember(
  FakeFirebaseFirestore db, {
  String id = 'nl_YUSUFabcdefghijklmno',
  String name = 'Yusuf',
  int color = 5,
}) async {
  await db.doc('families/f1/members/$id').set({
    'name': name, 'role': 'child', 'noLogin': true, 'color': color,
    'pictureTiles': false, 'joinedAt': DateTime(2026, 9, 1), 'createdBy': 'u1',
  });
  return id;
}
```

- [ ] **Step 2: Write the failing widget tests**

Create `test/features/no_login_member_test.dart`. Each test seeds with `seedFamily()` (+ `seedChores(db)` where chores are needed) and pumps with `pumpWithFamily`, as the existing family and chores tests do; copy their imports and their `useSize`/`settle` usage.
1. **"a parent adds a member without a login"** (u1): tap `addNoLoginMember`, enter "Yusuf", tap the confirm button. Exactly one new `families/f1/members/nl_…` doc exists, with `noLogin: true`, `role: 'child'`, `createdBy: 'u1'`, and `color` equal to `nextFreeColor` of the members before. A blank name writes nothing.
2. **"a child cannot add one"** (u2): `addNoLoginMember` is absent.
3. **"the row shows No login; its menu has Edit name and Remove but no Make parent"** (u1, with `seedNoLoginMember`): `noLoginTag-nl_YUSUFabcdefghijklmno` is visible. Opening `memberMenu-nl_YUSUFabcdefghijklmno` shows "Edit name" and "Remove", and no "Make parent"/"Make child". This is Review Focus #2.
4. **"Edit name on a no-login member changes the name itself"**: Edit name → "Yusuf Ali" → Save writes `name: 'Yusuf Ali'` (not `displayName`). A blank value writes nothing.
5. **"Remove asks first, then removes"**: Remove → Cancel writes nothing; Remove → confirm deletes the doc.
6. **"a no-login member appears in Who, on the board, in the week view, on Today and in who-did-it"**: assign the seeded `brush` chore to the no-login member in the database, then:
   - the chore sheet (u1) has the chip `choreWho-nl_YUSUFabcdefghijklmno`;
   - at 1280×800 the board has `boardColumn-nl_YUSUFabcdefghijklmno`;
   - in Week view the chip `weekChip-brush-2026-10-01` shows the initial "Y";
   - Today shows his progress ring;
   - ticking the Anyone chore `plants` as u1 lists "Yusuf" in who-did-it.
7. **"a child cannot tick a no-login member's chore anywhere"** (u2, `brush` assigned to Yusuf): on the phone Chores tab, the board and Week view at 1280×800, and Today, tapping that chore writes nothing (`choreDone` stays empty for it). This is Review Focus #1.
8. **"a parent ticks a no-login member's chore"** (u1): tapping it writes `choreDone/brush_2026-10-01` with `doneBy: 'u1'`, as for any child's chore ticked by a parent.
9. **"removing a no-login member moves their chores to Former member"**: delete the member doc. The Chores tab (u1) shows `choreSection-former` containing `brush`. This is Review Focus #3.
10. **"Arabic no-login member on a small phone"**: Arabic name "يوسف علي" at 320×640 and 360×740, text 1.3, `Locale('ar')`, on the Family screen and the Chores tab. No exception; the row title is at least 80 dp wide; the avatar letter is "ي". This is Review Focus #4.
11. **"ProfileSync never writes to a no-login member"**: with a no-login member that has a blank name and no colour, pump `RootGate` as u1 for 50 frames. Only the expected colour write happens (parents fill missing colours, as today); no name or photo write ever targets the `nl_` doc.

- [ ] **Step 3: Run them and see them fail**

Run: `flutter test test/features/no_login_member_test.dart`
Expected: 1, 3, 4 and 5 fail (no button, tag or menu change). 6–9 and 11 may already pass: chores, board, week and rules treat members generically. They stay as regression guards.

- [ ] **Step 4: Implement on the Family screen**

In `lib/features/family/family_screen.dart` (as 1.2.2 left it):

1. Import `../../core/member_colors.dart` (for `nextFreeColor`) if it isn't imported.
2. **Subtitle:** for a no-login member, the role text is `l.noLoginTag`, wrapped in a `Text` with key `ValueKey('noLoginTag-${m.uid}')`. A parent-chosen displayName is still appended the way `_subtitle` does it.
3. **Member menu:** wrap the `role` item with `if (!m.noLogin)`. Edit name and Remove stay.
4. **Edit name for a no-login member:** in the Edit-name handler, if `m.noLogin`, prefill with `m.name`. On save, a non-blank trimmed value → `fireAndForget(repo.setMemberName(familyId, m.uid, value))`; blank → no write. Members with a login keep the 1.2.2 displayName behaviour.
5. **Add button:** directly after the member rows (inside the same card), for parents only:

```dart
                if (isParent && family != null && uid != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const Key('addNoLoginMember'),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(l.addNoLoginMember),
                      onPressed: () async {
                        final name = await promptText(
                          context,
                          title: l.addNoLoginMember,
                          label: l.name,
                          confirmLabel: l.create,
                          maxLength: 80,
                        );
                        final trimmed = name?.trim() ?? '';
                        if (trimmed.isEmpty) return;
                        fireAndForget(ref.read(familyRepositoryProvider).addNoLoginMember(
                              familyId: family.id,
                              name: trimmed,
                              createdBy: uid,
                              color: nextFreeColor(members),
                            ).then((_) {}));
                      },
                    ),
                  ),
```

(`members` is the list the screen already builds. If 1.2.2 named it differently, use that name and report it.)

6. **Strings.** In `lib/l10n/app_en.arb` add `"addNoLoginMember": "Add member without login"` and `"noLoginTag": "No login"`. In `lib/l10n/app_ar.arb` add `"addNoLoginMember": "إضافة فرد بدون حساب"` and `"noLoginTag": "بدون حساب"`. Then run `flutter gen-l10n`.

- [ ] **Step 5: Run the tests and see them pass**

Run: `flutter test test/features/no_login_member_test.dart`, then the full `flutter test`, then `flutter analyze --no-fatal-infos`.
Expected: all pass; analyze reports no errors or warnings.

- [ ] **Step 6: Commit**

```bash
git add lib/features/family/family_screen.dart lib/l10n test/support/seed.dart test/features/no_login_member_test.dart
git commit -m "feat(family): add, edit and remove members without a login"
```

---

### Task 3: Invite to family, and the release workflow's permanent link

**Files:**
- Create:
  - `lib/app/links.dart`
  - `lib/features/family/invite.dart`
  - `test/features/invite_test.dart`
- Modify:
  - `lib/app/providers.dart` (`shareTextProvider`)
  - `lib/features/family/family_screen.dart` (the share button)
  - both ARB files
  - `.github/workflows/release.yml`
  - `pubspec.yaml` (`version: 1.3.0+6`)
  - `test/support/pump.dart` (optional `List<String>? shared`)

**Interfaces:**
- Produces:
  - `const String appDownloadUrl = String.fromEnvironment('APP_DOWNLOAD_URL');` (empty in local builds)
  - `String inviteText(AppLocalizations l, {required String code, required String link})`
  - `final shareTextProvider = Provider<void Function(String text)>((ref) => (text) => Share.share(text));`
  - Family key `Key('inviteFamily')` on the share button (it replaces the old share icon's role; tooltip `l.inviteFamily`)
  - l10n keys `inviteFamily`, `inviteMessage` ({link}, {code}), `inviteMessageNoLink` ({code})

- [ ] **Step 1: Write the failing tests** (`test/features/invite_test.dart`)

```dart
import 'package:family_app/features/family/invite.dart';
import 'package:family_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const link = 'https://github.com/firas/family-app/releases/latest/download/family-app.apk';

  test('the invite carries the link and the code (English)', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final text = inviteText(l, code: 'ABC234', link: link);
    expect(text, contains(link));
    expect(text, contains('ABC234'));
  });

  test('the invite carries the link and the code (Arabic)', () {
    final l = lookupAppLocalizations(const Locale('ar'));
    final text = inviteText(l, code: 'ABC234', link: link);
    expect(text, contains(link));
    expect(text, contains('ABC234'));
  });

  test('invite without a link still carries the code', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final text = inviteText(l, code: 'ABC234', link: '');
    expect(text, contains('ABC234'));
    expect(text, isNot(contains('http')));
  });
}
```

Also add a widget test in the same file: pump `FamilyScreen` as u1 with `shareTextProvider` overridden to record the text (via the new `pump.dart` `shared` list). Tapping `inviteFamily` records exactly one text containing 'ABC234'. In a test build `appDownloadUrl` is empty, so the text is the no-link form.

- [ ] **Step 2: Run them and see them fail** (`invite.dart` is missing; the key and provider are undefined).

- [ ] **Step 3: Implement**

`lib/app/links.dart`:

```dart
/// Where to download the app. The release workflow sets it with
/// `--dart-define=APP_DOWNLOAD_URL=…`; local builds leave it empty.
const String appDownloadUrl = String.fromEnvironment('APP_DOWNLOAD_URL');
```

`lib/features/family/invite.dart`:

```dart
import '../../l10n/app_localizations.dart';

/// The "Join our family" message: the download link (when this build has one)
/// and the join code.
String inviteText(AppLocalizations l, {required String code, required String link}) =>
    link.isEmpty ? l.inviteMessageNoLink(code) : l.inviteMessage(link, code);
```

In `lib/app/providers.dart` add `import 'package:share_plus/share_plus.dart';` and:

```dart
/// Opens the phone's share sheet. Tests override it to capture the text.
final shareTextProvider = Provider<void Function(String text)>((ref) => (text) => Share.share(text));
```

In `test/support/pump.dart`, add the optional parameter `List<String>? shared`. When it is given, override `shareTextProvider` with `(text) => shared.add(text)`; otherwise override with a no-op, so tests never open a real share sheet.

In `family_screen.dart`, replace the share `IconButton`'s `onPressed: () => Share.share(l.shareCodeMessage(family.joinCode))` with:

```dart
                    key: const Key('inviteFamily'),
                    tooltip: l.inviteFamily,
                    onPressed: () => ref.read(shareTextProvider)(
                          inviteText(l, code: family.joinCode, link: appDownloadUrl),
                        ),
```

Then add the two imports (`../../app/links.dart`, `invite.dart`), and remove the `share_plus` import if it is now unused.

**Strings.** In `lib/l10n/app_en.arb`:

```json
  "inviteFamily": "Invite to family",
  "inviteMessage": "Join our family on the Family app:\n1) Install it: {link}\n2) Sign in with Google\n3) Enter the code {code}",
  "@inviteMessage": { "placeholders": { "link": { "type": "String" }, "code": { "type": "String" } } },
  "inviteMessageNoLink": "Join our family on the Family app: sign in with Google and enter the code {code}",
  "@inviteMessageNoLink": { "placeholders": { "code": { "type": "String" } } }
```

In `lib/l10n/app_ar.arb`:

```json
  "inviteFamily": "دعوة إلى العائلة",
  "inviteMessage": "انضم إلى عائلتنا في تطبيق Family:\n1) ثبّت التطبيق: {link}\n2) سجّل الدخول بحساب Google\n3) أدخل الرمز {code}",
  "inviteMessageNoLink": "انضم إلى عائلتنا في تطبيق Family: سجّل الدخول بحساب Google وأدخل الرمز {code}"
```

Then run `flutter gen-l10n`.

**Workflow.** In `.github/workflows/release.yml`, replace the build and copy steps with:

```yaml
      - run: >
          flutter build apk --release
          --build-name "${TAG#v}" --build-number "${{ github.run_number }}"
          --dart-define=APP_DOWNLOAD_URL=https://github.com/${{ github.repository }}/releases/latest/download/family-app.apk
      - run: |
          cp build/app/outputs/flutter-apk/app-release.apk "family-app-${TAG}.apk"
          cp build/app/outputs/flutter-apk/app-release.apk family-app.apk
```

and change the upload step's `files:` to `files: family-app*.apk`.

**Version.** In `pubspec.yaml`, set `version: 1.3.0+6`.

- [ ] **Step 4: Run all checks**

- `flutter test` passes.
- `flutter analyze --no-fatal-infos` reports no errors or warnings.
- `python -c "import yaml,sys; [yaml.safe_load(open(p)) for p in sys.argv[1:]]; print('ok')" .github/workflows/*.yml` prints `ok`.
- Local proof that the link reaches the app: build with `flutter build apk --release --dart-define=APP_DOWNLOAD_URL=https://example.com/x.apk` (GRADLE_OPTS as usual), and confirm `strings` or `grep -a` finds `https://example.com/x.apk` inside `lib/arm64-v8a/libapp.so` in the APK. Then delete that APK; it is a check only. Stop the Gradle daemon.

- [ ] **Step 5: Commit**

```bash
git add lib/app/links.dart lib/features/family/invite.dart lib/app/providers.dart lib/features/family/family_screen.dart lib/l10n .github/workflows/release.yml pubspec.yaml test/features/invite_test.dart test/support/pump.dart
git commit -m "feat(family): invite to family with a permanent download link"
```

---

### Task 4: Publish — public repository, first signed release (with Firas)

This task is done with Firas, because it needs his accounts and secrets. The main session runs the commands; Firas does the account steps. The tester verifies the result.

**Files:** `docs/SETUP.md` (add a short "Share the app" section with the permanent-link pattern and the one-time reinstall note).

- [ ] **Step 1 (Claude): Secret scan before anything is public.** Each of these must print nothing:
  - `git ls-files | grep -Ei 'key\.properties|\.jks$|\.keystore$|google-services\.json'`
  - `git grep -nE 'AIza[0-9A-Za-z_-]{35}|-----BEGIN (RSA |EC )?PRIVATE KEY|storePassword=|keyPassword='`
  
  Also review `git log --all --stat` for any of those paths ever having been committed. If any appear, STOP and tell Firas: the history would need cleaning before going public.
- [ ] **Step 2 (Firas):** create a free GitHub account if needed, then a new **public**, **empty** repository named `family-app`: no README, no licence, no .gitignore.
- [ ] **Step 3 (Claude, Firas signs in when the window opens):**
  - `git remote add origin https://github.com/<owner>/family-app.git`
  - `git push -u origin main`
  
  Git Credential Manager opens a browser sign-in for Firas. Claude never types his password.
- [ ] **Step 4 (Firas), following `docs/SETUP.md` section 1:**
  - run **Actions → Generate signing key** and download the result;
  - store the key file and passwords safely;
  - add the 4 signing secrets, plus `GOOGLE_SERVICES_JSON`.
- [ ] **Step 5 (Firas), following `docs/SETUP.md` section 2:**
  - in Firebase, add the release key's SHA-1 and SHA-256;
  - re-download `google-services.json` and update the `GOOGLE_SERVICES_JSON` secret.
- [ ] **Step 6 (Firas):** **Releases → Draft a new release**, tag `v1.3.0`, then **Publish**. Wait for the Release APK action to finish (about 10 minutes).
- [ ] **Step 7 (Claude):** run `curl -sIL https://github.com/<owner>/family-app/releases/latest/download/family-app.apk`.
  - Expect a final `200`, with a `content-length` of about 60 MB.
  - Download it and check with `apksigner verify --print-certs` that the signer is NOT "Android Debug".
  - Check with `aapt dump badging` that the package is `com.firas.familia` and versionName is `1.3.0`.
- [ ] **Step 8 (Firas, each phone, once):** uninstall the test app, open the link, install, sign in. From now on, new releases install over the top.
- [ ] **Step 9 (Claude):** add the "Share the app" section to `docs/SETUP.md` and commit it: `docs(setup): share the app with the permanent link`.
