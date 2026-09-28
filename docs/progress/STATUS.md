# Family App — Release 1 status

| Task | Title | Status | Attempts | Commit | Notes |
|---|---|---|---|---|---|
| 1 | Project scaffold and CI | Done (2026-09-28) | 1 | 651661e | Accepted deviations: caret constraints restored; `kotlin { compilerOptions { jvmTarget = JVM_11 } }` (Kotlin 2.4); template AGP 9.1.0 / Kotlin 2.4.0 kept; extra standard .gitignore entries. Debug APK stops only at missing google-services.json (expected). |
| 2 | Text utilities | Done (2026-09-28) | 1 | 30f6910 | 16/16 tests. Literal Arabic characters instead of the plan's `\u` escapes (same codepoints) — accepted. |
| 3 | Models and placement logic | Done (2026-09-28) | 1 | ccbcfd8 | 40/40 tests, incl. Step 5b hardening. Accepted deviations: `_invisible` regex written with `\u` escapes (same code points, avoids analyzer warnings); two formatting-only line splits. |
| 4 | Firestore security rules | Done (2026-09-27) | 2 | 7270826 | Attempt 1 (2650074) passed as planned; attempt 2 = approved Option A tightening. 34/34 rules tests. |
| 5 | Family repository | Done (2026-09-28) | 1 | d48fbec | 50/50 tests; diff-identical to plan; every write checked against firestore.rules; Review Focus #4 passes. |
| 6 | Catalog repository | Done (2026-09-28) | 1 | c9adbdd | 57/57 tests; byte-identical to plan; every write checked against firestore.rules; Review Focus #3 passes. |
| 7 | List and purchase repositories | Done (2026-09-28) | 1 | 4aa6b26 | 64/64 tests; byte-identical to plan; every write checked against firestore.rules. Two observations parked. |
| 8 | App foundation (l10n, providers) | In progress (2026-09-28) | 1 | | |
| 9 | Item details sheet | Not started | 0 | | Must confirm (from Task 6 test): `_deleteFromCatalog` passes EVERY list id to `deleteItem` (it only clears entries in the lists it is given) — the sheet must keep `listsProvider` watched so lists are loaded, as the plan does; delete is parent-only. |
| 10 | Lists tab and list screen | Not started | 0 | | Must confirm (from Task 6 test): (a) category delete is never offered for the default "Other" category (the server rejects the whole batch; offline it applies locally then rolls back) — plan gates the long-press on `isParent && !isDefault`; (b) `deleteCategory` receives the FULL catalog (`itemsProvider` value, not a filtered/section list), or items in the deleted category are left pointing at it. |
| 11 | History screen | Not started | 0 | | |
| 12 | Family screen | Not started | 0 | | |
| 13 | App shell | Not started | 0 | | Brief must require (and tester confirm) that onboarding Join/Create are only reachable when `users/{uid}.familyId` is null (from Task 5 test: joinFamily by a user already in a family fails with a raw permission error, or leaves an orphan member doc in the old family). |
| 14 | Release builds and setup guide | Not started | 0 | | Brief must include two one-line extras (existing constraints, not new scope): (a) `minSdk = 23` → `minSdk = 24` in `android/app/build.gradle.kts` (Global Constraint updated 2026-09-28); (b) `android:label="family_app"` → `android:label="Family"` in `android/app/src/main/AndroidManifest.xml` (Global Constraint: app title "Family"); (c) `applicationId = "com.family.family_app"` → `applicationId = "com.firas.familia"` in `android/app/build.gradle.kts` (namespace and Kotlin package stay `com.family.family_app`). Firebase: project `familia-a1b9f` already exists; `android/app/google-services.json` is present locally (gitignored, never commit). Google Sign-In also needs debug SHA fingerprints registered + Google sign-in enabled (asked of Firas, pending); the release keystore fingerprints must be registered too. SETUP.md step 2 should account for the existing project. |

**Next runnable task:** Task 8 (in progress); then Task 9.

## Decisions
- 2026-09-27: Spec and plan approved by Firas. Execution: subagent-driven with PM / developer / tester agents.
- 2026-09-27: Flutter SDK not installed; Firas: ignore Flutter for now. Task 4 run ahead of Task 1 (no Flutter dependency). Task 1 must merge into the existing ci.yml and .gitignore.
- 2026-09-27: Task 4 attempt 1 PASS (2650074). Accepted deviation: `rules-tests/package.json` `emulate` script uses `\"npm test\"` quoting for Windows cmd.exe (also valid on Linux).
- 2026-09-27: Firas chose Option A — tighten rules (purchase time, creator re-parenting, join code). Approved data-model addition: `members/{uid}.joinCode` (child joins only). Plan Task 4/5 and spec §3 updated. Task 4 attempt 2 PASS (7270826).
- 2026-09-28: Flutter 3.47.5 (Dart 3.13) installed at D:\flutter; Android toolchain ready. Flutter-dependent tasks unblocked; Task 1 started.
- 2026-09-28: Firas pre-authorised overnight work toward the APK: instead of "Decision needed" notes, PM picks the recommended option and logs "Auto-decided (Firas pre-authorised): <summary> — chose <option> because <reason>". Still Blocked for anything needing Firas's accounts (Firebase, GitHub secrets, keystore passwords) or after 3 failed attempts.
- 2026-09-28: Task 1 PASS (651661e).
- 2026-09-28: Auto-decided (Firas pre-authorised): minimum Android version — chose raise minSdk 23 → 24 (Android 7.0) over pinning an older Flutter, because Flutter 3.47.5 enforces 24 (it silently raises it at build time anyway) and Android 6 phones are a negligible share. Plan Global Constraints, plan Task 1 code block and spec tech-stack line updated. The one-line `android/app/build.gradle.kts` change is scheduled into Task 14 (the Android-release task), not Task 2 (pure Dart; keep it clean). Builds are unaffected meanwhile.
- 2026-09-28: Task 2 PASS (30f6910).
- 2026-09-28: Auto-decided (Firas pre-authorised): text hardening from the Task 2 test — chose a small fix now (plan Task 3 Step 5b) over parking, because (a) a name pasted with an invisible RTL/LTR mark gets a blank tile letter and doesn't match the same item (spec name matching, Review Focus #5), and (b) typing "NaN"/"Infinity" in the item sheet would crash on `.round()`, and a negative quantity or price makes no sense. Fix: `nameKey`/`tileLetter` strip invisible direction marks (not ZWJ, which emoji need); `parseNumber` returns null unless the value is finite and >= 0. Spec name-matching line updated. Placed in Task 3: it is the next pure-Dart `lib/core` task and runs before any caller (Tasks 6, 9, 11).
- 2026-09-28: Task 3 PASS (ccbcfd8).
- 2026-09-28: Manifest label: template `android:label="family_app"` breaks the existing Global Constraint app title "Family". Not new scope; one-line fix assigned to Task 14 (same Android-config touch as minSdk).
- 2026-09-28: Task 5 PASS (d48fbec).
- 2026-09-28: Task 6 PASS (c9adbdd). Two tester observations attached as "must confirm" notes to Tasks 9 and 10; one parked.
- 2026-09-28 (Firas's decision): Firas created Firebase project `familia-a1b9f` and registered the Android app as `com.firas.familia`; he chose to change the app's `applicationId` to `com.firas.familia` to match (namespace/Kotlin package stay `com.family.family_app`). Plan Global Constraint, plan Task 14 (Files, note, SETUP package name) and spec §deployment updated; the one-line change is scheduled into Task 14. Pending on Firas's account: register debug SHA fingerprints and enable Google sign-in; later, register the release keystore fingerprints.
- 2026-09-28: Task 7 PASS (4aa6b26). Two observations parked.

## Parking lot
- Chores module (Release 2)
- Budget reports and charts built on purchase history
- Rules hardening (nice-to-have, from Task 4 test): enforce "last parent can't be demoted/leave" in rules too (spec §6 currently app-only); stop parents creating extra `isDefault: true` categories; check `users/{uid}.familyId` in rules rather than member-doc existence (spec §7 wording; current approach is equivalent in practice).
- Rules hardening (from Task 4 rework): a parent deleting a `joinCodes` doc on its own, or setting `families/{f}.joinCode` to a code with no `joinCodes` doc, reopens the creator-setup window; could require these to change together (getAfter/existsAfter). An undo that syncs more than 10 min after `boughtAt` (long offline) is rejected by rules; a parent then deletes it in History.
- Clock/undo timing (Task 4 attempt 2 + Task 7 tests): the 5-minute skew allowance lets a fast-clock buyer undo for up to ~15 min instead of 10; an undo reaching the server >10 min after `boughtAt` (offline buy+undo then late reconnect, or clock >10 min slow) is denied and the whole undo batch rolls back silently (fire-and-forget); a clock >5 min fast makes purchase creates fail.
- Lists (from Task 7 test): `deleteList` uses one batch, which would exceed Firestore's 500-write limit for a list with >499 entries (unrealistic).
- Build warning (from Task 1 test): the app applies the `kotlin-android` plugin (plan-required) and share_plus 10.x also applies it; Gradle warns that future Flutter versions will fail such builds. Warning only today; revisit if a Flutter upgrade breaks the build (drop `id("kotlin-android")` or upgrade share_plus).
- Dev tooling: npm reports 13 vulnerabilities in rules-tests dev dependencies; local Node 25 vs CI Node 20.
- Text (from Task 3 test): invisible-character stripping doesn't cover U+2060 word joiner or U+00AD soft hyphen (plan's chosen set); add only if a real name mismatches.
- Family (from Task 5 test): the last-parent check (demote/remove/leave) isn't transactional; two parents demoting each other at the same moment could leave no parent.
- Tests (from Task 5 test): removeMember has no last-parent test (the code applies the check).
- Catalog (from Task 6 test): any member can `saveItem(isNew: true)` over an existing item id, overwriting `createdBy`/`createdAt` (rules and spec allow it).
