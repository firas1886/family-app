# Family App — Release 1 status

| Task | Title | Status | Attempts | Commit | Notes |
|---|---|---|---|---|---|
| 1 | Project scaffold and CI | Done (2026-09-28) | 1 | 651661e | Accepted deviations: caret constraints restored; `kotlin { compilerOptions { jvmTarget = JVM_11 } }` (Kotlin 2.4); template AGP 9.1.0 / Kotlin 2.4.0 kept; extra standard .gitignore entries. Debug APK stops only at missing google-services.json (expected). |
| 2 | Text utilities | In progress (2026-09-28) | 1 | | |
| 3 | Models and placement logic | Not started | 0 | | |
| 4 | Firestore security rules | Done (2026-09-27) | 2 | 7270826 | Attempt 1 (2650074) passed as planned; attempt 2 = approved Option A tightening. 34/34 rules tests. |
| 5 | Family repository | Not started | 0 | | The joinFamily contract is now in the plan's Task 5 (writes `joinCode: normalized` on the child member doc, with test assertion); follow the plan as written. |
| 6 | Catalog repository | Not started | 0 | | |
| 7 | List and purchase repositories | Not started | 0 | | |
| 8 | App foundation (l10n, providers) | Not started | 0 | | |
| 9 | Item details sheet | Not started | 0 | | |
| 10 | Lists tab and list screen | Not started | 0 | | |
| 11 | History screen | Not started | 0 | | |
| 12 | Family screen | Not started | 0 | | |
| 13 | App shell | Not started | 0 | | |
| 14 | Release builds and setup guide | Not started | 0 | | Brief must include two one-line extras (existing constraints, not new scope): (a) `minSdk = 23` → `minSdk = 24` in `android/app/build.gradle.kts` (Global Constraint updated 2026-09-28); (b) `android:label="family_app"` → `android:label="Family"` in `android/app/src/main/AndroidManifest.xml` (Global Constraint: app title "Family"). |

**Next runnable task:** Task 2 (in progress); then Task 3.

## Decisions
- 2026-09-27: Spec and plan approved by Firas. Execution: subagent-driven with PM / developer / tester agents.
- 2026-09-27: Flutter SDK not installed; Firas: ignore Flutter for now. Task 4 run ahead of Task 1 (no Flutter dependency). Task 1 must merge into the existing ci.yml and .gitignore.
- 2026-09-27: Task 4 attempt 1 PASS (2650074). Accepted deviation: `rules-tests/package.json` `emulate` script uses `\"npm test\"` quoting for Windows cmd.exe (also valid on Linux).
- 2026-09-27: Firas chose Option A — tighten rules (purchase time, creator re-parenting, join code). Approved data-model addition: `members/{uid}.joinCode` (child joins only). Plan Task 4/5 and spec §3 updated. Task 4 attempt 2 PASS (7270826).
- 2026-09-28: Flutter 3.47.5 (Dart 3.13) installed at D:\flutter; Android toolchain ready. Flutter-dependent tasks unblocked; Task 1 started.
- 2026-09-28: Firas pre-authorised overnight work toward the APK: instead of "Decision needed" notes, PM picks the recommended option and logs "Auto-decided (Firas pre-authorised): <summary> — chose <option> because <reason>". Still Blocked for anything needing Firas's accounts (Firebase, GitHub secrets, keystore passwords) or after 3 failed attempts.
- 2026-09-28: Task 1 PASS (651661e).
- 2026-09-28: Auto-decided (Firas pre-authorised): minimum Android version — chose raise minSdk 23 → 24 (Android 7.0) over pinning an older Flutter, because Flutter 3.47.5 enforces 24 (it silently raises it at build time anyway) and Android 6 phones are a negligible share. Plan Global Constraints, plan Task 1 code block and spec tech-stack line updated. The one-line `android/app/build.gradle.kts` change is scheduled into Task 14 (the Android-release task), not Task 2 (pure Dart; keep it clean). Builds are unaffected meanwhile.
- 2026-09-28: Manifest label: template `android:label="family_app"` breaks the existing Global Constraint app title "Family". Not new scope; one-line fix assigned to Task 14 (same Android-config touch as minSdk).

## Parking lot
- Chores module (Release 2)
- Budget reports and charts built on purchase history
- Rules hardening (nice-to-have, from Task 4 test): enforce "last parent can't be demoted/leave" in rules too (spec §6 currently app-only); stop parents creating extra `isDefault: true` categories; check `users/{uid}.familyId` in rules rather than member-doc existence (spec §7 wording; current approach is equivalent in practice).
- Rules hardening (from Task 4 rework): a parent deleting a `joinCodes` doc on its own, or setting `families/{f}.joinCode` to a code with no `joinCodes` doc, reopens the creator-setup window; could require these to change together (getAfter/existsAfter). An undo that syncs more than 10 min after `boughtAt` (long offline) is rejected by rules; a parent then deletes it in History.
- Rules (from Task 4 attempt 2 test): the 5-minute clock-skew allowance lets a buyer whose phone clock runs ahead undo for up to ~15 minutes instead of 10.
- Build warning (from Task 1 test): the app applies the `kotlin-android` plugin (plan-required) and share_plus 10.x also applies it; Gradle warns that future Flutter versions will fail such builds. Warning only today; revisit if a Flutter upgrade breaks the build (drop `id("kotlin-android")` or upgrade share_plus).
- Dev tooling: npm reports 13 vulnerabilities in rules-tests dev dependencies; local Node 25 vs CI Node 20.
