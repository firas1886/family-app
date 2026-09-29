# Family App — status

## Release 2a — Chores and look and feel

Spec: `docs/superpowers/specs/2026-09-28-release2a-chores-and-look-design.md` · Plan: `docs/superpowers/plans/2026-09-28-release2a-chores-and-look.md` (10 tasks; its "Plan-level amendments" section overrides earlier text).

| Task | Title | Status | Attempts | Commit | Notes |
|---|---|---|---|---|---|
| 1 | Visual system — palette, tokens, fonts, light and dark themes | In progress (2026-09-29) | 1 | | Font download approved. Amendment 8: also updates `item_tile.dart`. |
| 2 | Navigation, Today screen (shopping), shared widgets, restyle | Not started | 0 | | |
| 3 | Member colours, photos, picture tiles, theme choice on Family screen | Not started | 0 | | Rules change (rules tests). |
| 4 | Dates and chore logic (pure Dart) | Not started | 0 | | Review Focus #1, #3. |
| 5 | Chore data — rules, repository, providers | Not started | 0 | | Rules change. Review Focus #2. |
| 6 | Chores tab (phone layout), chore cards and the chore sheet | Not started | 0 | | Review Focus #5. |
| 7 | Tablet board (landscape columns that scroll on their own) | Not started | 0 | | Review Focus #4. |
| 8 | Ticking polish — who did it, late chores, celebration, Today chores | Not started | 0 | | |
| 9 | Reminders on each phone | Not started | 0 | | Adds the 4 approved packages. |
| 10 | Release 1.1.0 — build, setup notes, device checklist | Not started | 0 | | |

**Next:** Task 1 with the developer.

## Release 1 (done)

All 14 tasks Done (2026-09-27 → 2026-09-28): 108 tests, 34 rules tests.

<details><summary>Release 1 task table</summary>

| Task | Title | Status | Attempts | Commit | Notes |
|---|---|---|---|---|---|
| 1 | Project scaffold and CI | Done (2026-09-28) | 1 | 651661e | Accepted deviations: caret constraints restored; `kotlin { compilerOptions { jvmTarget = JVM_11 } }` (Kotlin 2.4); template AGP 9.1.0 / Kotlin 2.4.0 kept; extra standard .gitignore entries. Debug APK stops only at missing google-services.json (expected). |
| 2 | Text utilities | Done (2026-09-28) | 1 | 30f6910 | 16/16 tests. Literal Arabic characters instead of the plan's `\u` escapes (same codepoints) — accepted. |
| 3 | Models and placement logic | Done (2026-09-28) | 1 | ccbcfd8 | 40/40 tests, incl. Step 5b hardening. Accepted deviations: `_invisible` regex written with `\u` escapes (same code points, avoids analyzer warnings); two formatting-only line splits. |
| 4 | Firestore security rules | Done (2026-09-27) | 2 | 7270826 | Attempt 1 (2650074) passed as planned; attempt 2 = approved Option A tightening. 34/34 rules tests. |
| 5 | Family repository | Done (2026-09-28) | 1 | d48fbec | 50/50 tests; diff-identical to plan; every write checked against firestore.rules; Review Focus #4 passes. |
| 6 | Catalog repository | Done (2026-09-28) | 1 | c9adbdd | 57/57 tests; byte-identical to plan; every write checked against firestore.rules; Review Focus #3 passes. |
| 7 | List and purchase repositories | Done (2026-09-28) | 1 | 4aa6b26 | 64/64 tests; byte-identical to plan; every write checked against firestore.rules. Two observations parked. |
| 8 | App foundation (l10n, providers) | Done (2026-09-28) | 1 | d72b994 | 68/68 tests; en/ar ARB 79 keys each. Accepted deviation: `import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;` in providers.dart (Riverpod 2.6.1 exports a `Family` class that clashes with our model; import-only). |
| 9 | Item details sheet | Done (2026-09-28) | 1 | f2a7da0 | 74/74 tests; diff-identical to plan; all writes via fireAndForget; must-confirm satisfied (deleteItem gets every list id; parent-only, rules line 59); Review Focus #2 passes. 2 infos only (deprecated `value` on DropdownButtonFormField, as planned). Observations parked. |
| 10 | Lists tab and list screen | Done (2026-09-28) | 2 | df5345b + 882bcf8 | 91/91 tests; 0 errors/0 warnings/3 pre-existing infos. Attempt 2 overflow fix verified: tester probe passed all 24 cases (360/412/320 dp, text scale 1.0/1.3/2.0, English/Arabic long names, with/without caption); letter, name and quantity stay visible. Accepted deviations: grid PageStorageKey, `GridView.extent(130)`, snackbar timer cancel, `childAspectRatio: 0.8`, ItemTile content wrapped in LayoutBuilder→Center→FittedBox(scaleDown), and positioning-only change (ensureVisible + settle) in test "tapping a catalog item adds it to To buy" (no assertion changed). |
| 11 | History screen | Done (2026-09-28) | 1 | 3dcf609 | 97/97 tests; 0 errors/0 warnings/4 infos (1 new `unnecessary_underscores`, verbatim plan code). Accepted deviation: child's `onLongPress` is `() {}` instead of null in history_screen.dart (null made a long press count as a tap and broke the plan's own test; spec line 127 behaviour unchanged). |
| 12 | Family screen | Done (2026-09-28) | 1 | 96a1f3e | 103/103 tests; 0 errors/0 warnings/4 pre-existing infos; verbatim from plan; all Produces keys present; spec lines 129/142/145 verified; parent-only controls backed by rules. One observation parked. |
| 13 | App shell | Done (2026-09-28) | 1 | 1913d6e | 108/108 tests; 0 errors/0 warnings/6 infos; requirements 1–7 verified (Join/Create only reachable with null familyId; family screens only built once familyId is set). Only deviation: pre-approved RootGate `error:` → `_Loading()`. Debug APK stops only at processDebugGoogleServices (package mismatch, expected until Task 14's applicationId change). Three observations → Device test checklist. |
| 14 | Release builds and setup guide | Done (2026-09-28) | 1 | 047a1ce | 108/108 tests; 0 errors/0 warnings; workflows verbatim from plan; secrets contract correct; nothing secret tracked. Release APK (53.2 MB) verified: `com.firas.familia`, minSdk 24, label "Family", signed with the debug key (fallback; no release keystore yet). SETUP.md step 2 adapted to the existing project. Steps 1–5 ticked; **Step 6 (manual release checklist) is Firas's, still open.** |

</details>

**Still open for Release 1:** Firas's steps — (1) follow `docs/SETUP.md` (signing key, Firebase setup incl. SHA fingerprints, GitHub secrets, first release, install); (2) run the Task 14 Step 6 manual checklist on two phones; (3) run the Device test checklist below. All 14 plan tasks are otherwise Done.

## Decisions
- 2026-09-28: Release 2 split into 2a (chores + look and feel), 2b (family calendar, wall mode, Google Calendar), 2c (star rewards). 2a spec drafted: docs/superpowers/specs/2026-09-28-release2a-chores-and-look-design.md, awaiting Firas's review.
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
- 2026-09-28: Task 8 PASS (d72b994). RootGate note attached to Task 13; widget tests (Tasks 9–13) must seed users/{uid} with a familyId (pumpWithFamily does not override appUserProvider). Western digits in Arabic UI match the plan.
- 2026-09-28: Task 9 PASS (f2a7da0). Observations parked.
- 2026-09-28: Task 10 attempt 1 FAIL (df5345b): tile overflow on small phones, caused by the plan's own ItemTile/grid code (square cells too short for letter + 2-line name + quantity). Auto-decided (Firas pre-authorised): fix approach — chose BOTH a taller grid cell (`childAspectRatio: 0.8`, keeping `GridView.extent(130)`) AND a shrink-safe tile column (name `maxLines: 2` + ellipsis, caption `maxLines: 1` + ellipsis, content wrapped in `Flexible`/`FittedBox(fit: BoxFit.scaleDown)`), over only one of them, because a taller cell alone still overflows at 320 dp / textScale 1.3 with real (taller) fonts, and shrinking alone would make the letter and quantity tiny on 360 dp phones. Behaviour, colours, callbacks and the ItemTile interface are unchanged; plan code will be treated as amended by this fix. Tester's note "no test covers the category or list rename/delete sheets" parked.
- 2026-09-28: Task 10 PASS (df5345b + 882bcf8, attempt 2).
- 2026-09-28: Auto-decided (Firas pre-authorised): Task 10 rework brief was self-contradictory (aspect 0.8 made an existing test's tap land under the I-need bar). Chose option A: keep 0.8 and allow a positioning-only ensureVisible in that test, because tiles stay more readable (0.8× vs 0.6× at 320dp/1.3).
- 2026-09-28: Task 11 PASS (3dcf609). One observation parked.
- 2026-09-28: Task 12 PASS (96a1f3e). One observation parked. Task 13 started.
- 2026-09-28: Auto-decided (Firas pre-authorised): Task 13 RootGate — the plan's `error:` branch of `appUserProvider` shows OnboardingScreen, which would make Join/Create reachable while the user's familyId is unknown (breaks the Task 13 note; could leave an orphan member doc). Chose to show `_Loading()` on that error instead (one-line deviation) over keeping it verbatim, because reading your own user doc practically never errors, and a stuck spinner is harmless while an orphan membership is not.
- 2026-09-28: Task 13 PASS (1913d6e). Three tester observations moved to the Device test checklist. Task 14 started.
- 2026-09-28: Task 14 PASS (047a1ce). Release 1 build work complete; waiting on Firas (SETUP.md + Step 6 checklist). `android/.kotlin/` build cache to be gitignored by the main session.
- 2026-09-28: Auto-decided (Firas pre-authorised): Task 14 verification — build a debug-key-signed release APK now so Firas can install and test tonight; the proper release keystore stays Firas's step in SETUP.md. The developer does not create the real keystore or choose its passwords (Firas's secrets); with no `android/key.properties`, the Task 1 signing fallback signs with the debug key. Such an APK cannot later be updated in place by the properly signed one (uninstall first).
- 2026-09-29: Firas approved the Release 2a spec (2026-09-28) and plan (10 tasks). Execution: same PM / developer / tester loop.
- 2026-09-29: Firas approved downloading the IBM Plex Sans Arabic font (Regular, Medium, SemiBold + OFL.txt, from google/fonts; Task 1) and adding `flutter_local_notifications`, `timezone`, `flutter_timezone` and `shared_preferences` (Task 9).
- 2026-09-29: Firas pre-authorised Release 2a: the PM may again auto-decide routine questions on its own recommendation, logged as "Auto-decided (Firas pre-authorised): <summary> — chose <option> because <reason>". Stop (Blocked + Decision needed) only for Firas's accounts or secrets (Firebase, GitHub secrets, keystore passwords), or after 3 failed attempts.
- 2026-09-29: Release 2a Task 1 started.

## Device test checklist (Firas, after installing)
- RootGate: if reading your own user record fails, the app shows a spinner forever (no error message). Check it never sticks on a normal start.
- Offline right after a (re)install: the app may treat you as removed from the family and send you back to onboarding. Test: reinstall, open with airplane mode on, then reconnect; if it happens, rejoin with the code.
- Google sign-in is not covered by automated tests: check sign-in, cancel, and sign-out/sign-in again on a real phone (needs the SHA fingerprints registered in Firebase).

## Parking lot
- Skylight-style family hub (inventory in docs/ideas/2026-09-28-skylight-feature-inventory.md) → Release 2a/2b/2c: chores → 2a; calendar, wall mode, Google Calendar → 2b; star rewards → 2c. Still parked: recipe bank, photo screensaver; meal planner and AI import (out of scope for all of Release 2).
- Release 2a items parked by the plan: see its "Plan-level amendments" item 9 and writer D's drafting note 9.
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
- Item sheet (from Task 9 test): seed has one list, so multi-list catalog delete isn't directly tested; if `listsProvider` hasn't emitted before the delete confirm, some list entries could be missed (small timing gap).
- Tests (from Task 10 test): no widget test covers the category or list rename/delete sheets.
- Item sheet (from Task 9 test): unparseable expiry text saves as "no expiry"; a future `value`→`initialValue` switch on DropdownButtonFormField needs care (behaviour differs).
- Rules hardening (from Task 11 test, belongs to Task 4): rules don't type-check purchase `price` as a number; only the UI's `parseNumber` keeps it valid.
- Sign out (from Task 12 test): no try/catch, so if Google sign-out throws, the Firebase sign-out is skipped (minor robustness).
- Tiles (from Task 10 test): on small phones with large text, tiles shrink to ~0.6–0.8×; check readability on a real device.
- SETUP.md wording (from Task 14 test): debug-key step implies nothing to install, but `keytool` isn't on PATH (it's in Android Studio's `jbr\bin`), and PowerShell needs `.\gradlew signingReport`.
- Local Windows build (from Task 14 test): needs `GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false` (Kotlin cache issue across C:/D: drives); CI unaffected.
