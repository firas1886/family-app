# Family App — Release 1: Family Layer + Shopping Module

**Date:** 2026-09-27
**Status:** Draft for review
**Out of scope for this release:** Chores module, budget reports/charts, notifications, iOS build, item icons/images, Play Store publishing.

---

## 1. Goal

A private Android app for one family to share shopping lists. A parent creates a family, others join with a code, and everyone sees the same lists update live. Items bought regularly come back onto the list by themselves after a set number of days. Every purchase is recorded, with an optional price, to support budget tracking later.

**Success looks like:** the whole family uses one shared list instead of messaging each other, recurring items (milk, bread) reappear without anyone re-typing them, and a months-long purchase history exists for a later budgeting phase.

---

## 2. Decisions

| Topic | Decision |
|---|---|
| Platform | Flutter; Android only for now (iOS possible later without rewrite) |
| Distribution | Signed APK, sideloaded; no Play Store |
| Build | GitHub Actions builds the signed APK; no local setup required |
| Backend | Firebase: Auth (Google sign-in), Cloud Firestore (offline cache on), Security Rules. No custom server code. |
| Sign-in / join | Google sign-in + 6-character family join code |
| Roles | Creator is parent. Joiners are children. Parents promote/demote. |
| Languages | Arabic + English UI (RTL in Arabic); item names in either language |
| Lists | Multiple lists per family; created by parents |
| Catalog | One family catalog of items and categories, shared by all lists |
| Categories | Any member can add. Built-in "Other" cannot be deleted. |
| Tiles | Letter tile only: stylized first letter + name + quantity. Coral = To buy, teal = Recently used. |
| Quantity | Number + unit picker (pcs, kg, g, L, ml, pack), shown as "2 L" |
| New typed item | Goes to "Other" |
| Buying | One tap = bought, 5-second Undo; records who and when |
| Expiry return | Silent: item reappears in To buy on the list it was bought from |
| To buy sort | Grouped by category (default); toggle to A–Z |
| Recently used | Max 12 tiles, soonest-to-return first, days left shown |
| Price | Optional; added/edited later from History only |
| Currency | SAR (fixed in v1) |

---

## 3. Data model (Cloud Firestore)

```
users/{uid}
    name, email, familyId (nullable), language ("ar" | "en")

joinCodes/{code}                         # lookup only
    familyId

families/{familyId}
    name, joinCode, createdBy, createdAt

  members/{uid}
      name, role ("parent" | "child"), joinedAt

  categories/{categoryId}
      name, isDefault (true only for "Other"), createdBy, createdAt

  items/{itemId}                         # the family catalog
      name, nameKey (normalized, for matching), categoryId,
      quantity (number, nullable), unit (nullable), notes,
      expiryDays (int, nullable), createdBy, createdAt

  lists/{listId}
      name, createdBy, createdAt

    entries/{itemId}                     # an item's status on this list
        status ("toBuy" | "bought"),
        addedBy, addedAt, boughtBy, boughtAt

  purchases/{purchaseId}                 # permanent history
      itemId, itemName, categoryName, listId, listName,
      quantity, unit, price (nullable), currency ("SAR"),
      boughtBy, boughtByName, boughtAt
```

- A user belongs to one family at a time.
- Purchase records keep their own copy of names and quantity, so later renames or deletions never change history.
- An item has at most one entry per list, because the entry ID is the item ID.

---

## 4. Where each item appears (core logic)

This is pure Dart with no Firebase or UI dependency, so it can be fully unit-tested.

For each entry on a list, with `now` taken from the phone's clock:

- `status == toBuy` → **To buy**
- `status == bought` and `expiryDays` set and `boughtAt + expiryDays ≤ now` → **To buy** (returned). It is shown exactly like a toBuy entry.
- `status == bought` and not yet due → **Recently used**, showing `daysLeft = ceil(dueAt − now in days)`
- `status == bought` and `expiryDays` empty → **Recently used**, with no countdown

Because `dueAt` is calculated from the item's *current* `expiryDays`, editing expiry takes effect immediately.

**Recently used ordering:** items with a countdown come first, sorted by `dueAt` ascending, followed by items with no expiry, sorted by `boughtAt` descending. Only the first 12 are shown. The rest still exist, still return on time, and can be reached through Categories.

**To buy ordering:**
- *By category (default):* groups sorted by category name, with "Other" last; items A–Z within each group.
- *A–Z:* one flat grid.
- Sorting uses the current UI language's collation.

**Name matching:** `nameKey` = trimmed, lower-cased, repeated spaces collapsed, Arabic diacritics removed, أ/إ/آ → ا, ة → ه, ى → ي. Two items with the same `nameKey` are treated as the same item.

---

## 5. Screens

**First launch:** Google sign-in, then either **Create family** (enter a name; the user becomes its parent, and the family starts with the "Other" category) or **Join family** (enter the code; the user joins as a child).

The app has three bottom tabs.

**Lists:** the family's lists. Parents also see "+ New list", and long-press on a list to rename or delete it.

**List screen (top to bottom):**
1. List name and Sort toggle (Category / A–Z).
2. **To buy:** coral tiles. Tapping one marks it bought.
3. **Recently used:** teal tiles showing days left. Tapping one puts it back on To buy.
4. **Categories:** collapsible sections holding the full catalog. Tapping an item adds it to To buy. Items already on To buy are dimmed, and tapping one makes it flash. "+ New category" appears at the end.
5. **"I need…" box:** suggests catalog matches as you type. Enter or + adds an existing match, or creates a new item in "Other".

**Long-press sheet (any tile):** name; category (with "New category…"); quantity and unit; notes; expiry days; last bought by and when; "Remove from this list". Parents also see "Delete from catalog".

**History:** all purchases, newest first, grouped by date, with a list filter. Each row shows the item, quantity, buyer, and price or "Add price". Tapping a row lets anyone edit the price. Parents can delete a record.

**Family:** members and their roles; the join code with Share and (for parents) Regenerate; promote/demote/remove (parents); language switch; sign out; leave family.

---

## 6. Behaviours and edge cases

- **Buy:** a single batched write sets the entry to bought and creates the purchase record. **Undo** (5 s) restores the previous entry and deletes the purchase.
- **Tap a Recently used tile:** sets status to toBuy with a new `addedBy/addedAt`. No purchase record is created.
- **Simultaneous or offline double-buy:** both purchases are recorded. Parents can delete the duplicate in History.
- **Add an item already on To buy:** no change; the tile flashes.
- **Delete category (parent):** its items move to "Other". "Other" can't be deleted.
- **Delete catalog item (parent):** its entries are removed from all lists. History is kept.
- **Delete list (parent):** its entries are removed. History is kept.
- **Roles:** there is always at least one parent. The last parent can't be demoted and can't leave. A removed member's `familyId` is cleared.
- **Regenerate join code (parent):** the old code stops working. Existing members are unaffected.
- **Offline:** everything works from the local cache and syncs later. An "Offline" chip is shown. Joining or creating a family needs a connection.
- **Language:** defaults to the phone's language (Arabic if the phone is Arabic, otherwise English), and can be changed on the Family tab.

---

## 7. Permissions (enforced in Firestore Security Rules)

| Action | Child | Parent |
|---|---|---|
| Read all family data | ✓ | ✓ |
| Add/edit items, add categories, change expiry | ✓ | ✓ |
| Add to / buy / remove from a list | ✓ | ✓ |
| Add or edit a price in History | ✓ | ✓ |
| Create, rename, delete lists | ✗ | ✓ |
| Delete items, rename or delete categories | ✗ | ✓ |
| Delete purchase records | ✗ | ✓ |
| Promote/demote/remove members, regenerate code | ✗ | ✓ |

- A user can only read or write inside the family in their own `users/{uid}.familyId`.
- Joining may only create one's own member document with role "child".
- Purchase records can't be edited except for `price`.

---

## 8. Technical stack

- Flutter (stable), minimum Android SDK 23.
- Packages: `firebase_core`, `firebase_auth`, `google_sign_in`, `cloud_firestore`, `flutter_riverpod` (state), `flutter_localizations` + `intl` (ar/en).
- Folder layout: `lib/core` (pure logic: status, sorting, name matching), `lib/data` (Firestore repositories), `lib/features/{auth,family,lists,history}` (screens and widgets), `lib/l10n` (ARB files).

---

## 9. Testing

- **Unit tests:** placement rules, days-left, Recently used ordering and cap, sorting, and `nameKey` normalization (including Arabic cases).
- **Security rules tests:** run against the Firebase emulator, covering every row of the permissions table.
- **Widget tests:** list screen sections, tap-to-buy with Undo, long-press sheet.
- **Manual release checklist:** two phones, parent plus child; offline buy then reconnect; Arabic RTL layout.

---

## 10. Build and delivery

- Private GitHub repository.
- A GitHub Actions workflow runs the tests on every push. On a version tag, it builds a signed release APK and attaches it to a GitHub Release.
- The signing keystore and `google-services.json` are stored as GitHub secrets, never committed. A copy of the keystore is kept safely by Firas, because losing it means future updates can't install over the existing app.
- One-time setup by Firas (step-by-step instructions to be provided): create the Firebase project, enable Google sign-in and Firestore, register the signing key's SHA-1, and add the secrets to GitHub.
- Updating: tag a release, download the APK from GitHub, and send it to the family. Installing it keeps all data, which lives in Firebase.
