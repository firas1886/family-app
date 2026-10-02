# PLAN.md — Family App: state of the project and how to continue

Last updated: 2026-10-02. Owner: Firas (product/banking-tech manager, not a Flutter developer). Talk to him in plain language: what changed, what he must do, what's next.

## 1. What this is

A Flutter Android app (Arabic/English) for one family:
- shared shopping lists (Release 1);
- chores with a new look (Release 2a);
- a tablet Day/Week board, name fixes and an invite/download link (2a.1–2a.3).

Backend: Firebase (Auth with Google sign-in, Firestore). No server code.

| Item | Value |
|---|---|
| Repo (local) | `D:\ClaudeProjects\Family App\family-app-starter` (branch `main`) |
| Repo (GitHub, **public**) | https://github.com/firas1886/family-app (remote `origin`) |
| Permanent download link | https://github.com/firas1886/family-app/releases/latest/download/family-app.apk |
| Latest published release | **v1.3.0** (GitHub release workflow run 36976898297, signed with the release key `CN=Family App`, SHA-1 `F7:E3:30:D6:FA:00:59:C3:3C:6B:A1:58:F7:CD:E4:16:75:5D:14:93`) |
| Latest local test APK | `D:\ClaudeProjects\Family App\Family-test.apk` (1.2.2, debug-key signed) |
| Firebase project | `familia-a1b9f`; Android app id `com.firas.familia`; namespace `com.family.family_app`; minSdk 24 |
| Local config, never commit | `android/app/google-services.json` (gitignored) |

## 2. Toolchain on this PC

- Flutter 3.47.5 / Dart 3.13 at `D:\flutter\bin` (NOT on PATH).
- Java 21 at `C:\Program Files\Android\Android Studio\jbr`.
- Android SDK at `%LOCALAPPDATA%\Android\Sdk` (licences accepted; build-tools 36/37).
- Node 25 is on PATH.
- No `gh` CLI. Git Credential Manager handles GitHub sign-in.
- Shell prefixes:
  - Bash: `export PATH="/d/flutter/bin:/c/Program Files/Android/Android Studio/jbr/bin:$PATH"; export JAVA_HOME="C:\\Program Files\\Android\\Android Studio\\jbr"`
  - PowerShell: `$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'; $env:Path="D:\flutter\bin;$env:JAVA_HOME\bin;$env:Path"`
- Checks:
  - `flutter analyze --no-fatal-infos` (5 known infos are OK)
  - `flutter test` (last: 421 passing)
  - Rules: `cd rules-tests && npm run emulate` (needs JAVA_HOME AND jbr `bin` on PATH; last: 73 passing)
- Local release build: `GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false flutter build apk --release`, then `cd android && ./gradlew --stop`.
- Shared agent notes (scratchpad): `C:\Users\firas\AppData\Local\Temp\claude\D--ClaudeProjects\9b921dc5-9620-475c-9b35-4f1ccc7e6e5e\scratchpad\env.md`.

## 3. How work is done (CLAUDE.md loop)

- **Roles:** `.claude/agents/{project-manager,developer,tester}.md`.
- **Session setup:** the session cwd was the parent folder, so the role files aren't auto-registered. They run as general-purpose subagents told to read their role file.
- **Loop:**
  1. PM: brief.
  2. Developer: test-first, one commit, report.
  3. Tester: read-only; PASS/FAIL with evidence.
  4. PM: records the result in `docs/progress/STATUS.md`, then writes the next brief or a rework brief.
- **Briefs** go in `docs/progress/briefs/` (gitignored). Subagents can't write outside the repo.
- **For bounded changes** Claude writes the brief directly from the design Firas approved in chat (no plan doc).
- **Firas pre-authorised** the PM to auto-decide routine questions (logged "Auto-decided"). Stop for: his accounts/secrets, 3 failed attempts, real product decisions.
- **Process skills:**
  - new features → brainstorming (classify bounded/architectural), then spec → plan for architectural;
  - bugs → systematic-debugging.
- **Copy the APK to `Family App\Family-test.apk` BEFORE running the tester** (usage limits interrupted work several times).
- **Commit trailer:** `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push to `origin main` after tested work (the repo is public; scan for secrets first).

## 4. Specs and plans (paths)

| Release | Spec | Plan | Status |
|---|---|---|---|
| 1 — shopping | `docs/superpowers/specs/2026-09-27-family-app-shopping-design.md` | `docs/superpowers/plans/2026-09-27-family-app-shopping.md` (14 tasks) | Done |
| 2a — chores + look | `docs/superpowers/specs/2026-09-28-release2a-chores-and-look-design.md` | `docs/superpowers/plans/2026-09-28-release2a-chores-and-look.md` (10 tasks; "Plan-level amendments" at the end override) | Done (1.1.0) |
| 2a.1 — tablet Day/Week + first names | brief `docs/progress/briefs/r2a1-week-view.md` | — (bounded) | Done (1.2.0) |
| 2a.2 — name repair + editable display names | briefs `r2a2-names.md`, `r2a2-names-rework.md` | — (bounded) | Done (1.2.2) |
| 2a.3 — no-login members + download link | `docs/superpowers/specs/2026-10-01-release2a3-nologin-members-and-download-link-design.md` | `docs/superpowers/plans/2026-10-01-release2a3-nologin-members-and-download-link.md` (4 tasks) | Tasks 3 and 4 done (v1.3.0 published); **Tasks 1–2 NOT started** |

Other docs:
- `docs/SETUP.md`: release key, Firebase, publishing, "Share the app".
- `docs/progress/release-2a-device-checklist.md`
- `docs/ideas/2026-09-28-skylight-feature-inventory.md`
- `docs/progress/STATUS.md`: decisions log and parking lot. Read this for detail.

## 5. Architecture (key files)

- **Layers:**
  - `lib/core`: pure Dart (models, dates, chores logic, text, names, colours, reminders);
  - `lib/data`: Firestore repositories plus the notification scheduler;
  - `lib/app`: theme, palette, providers, app shell;
  - `lib/features/*`: screens.
- **Data model** (Firestore, under `families/{f}`):
  - `members/{uid}`: name, role, color, photoUrl, pictureTiles, joinedAt, displayName, joinCode (joiners);
  - `categories`, `items`, `lists/{l}/entries`, `purchases`;
  - `chores/{id}`: rule-based repeats;
  - `choreDone/{choreId}_{YYYY-MM-DD}`: with dayNumber and copied title/assignee/doneBy/doneByName.
  - Outside the family: `users/{uid}` (name, email, familyId, language, themeMode) and `joinCodes/{code}`.
- **Main files:**
  - `lib/core/chores.dart` (occursOn, choresForDay, lateChores, canToggle, validateChore, tolerant fromMap);
  - `lib/core/dates.dart`, `lib/core/member_colors.dart`, `lib/core/member_names.dart` (`memberLabel`, `accountDisplayName`), `lib/core/text.dart` (`firstName`, `tileLetter`, `nameKey`), `lib/core/reminders.dart`;
  - `lib/data/{family,chore,catalog,list,purchase}_repository.dart`, `lib/data/reminder_scheduler.dart`, `lib/data/write.dart` (`fireAndForget` uses `then<void>`);
  - `lib/app/{app,providers,theme,palette,links}.dart`: `ProfileSync` (colour/photo/name repair, attempt-once set) and `ReminderSync` (the only `AppLifecycleListener`, refreshes `todayProvider`);
  - `lib/features/chores/{chores_screen,chores_board,week_board,chore_card,chore_sheet,chore_groups,late_strip,who_did_it,celebration,repeat_label}.dart`;
  - `lib/features/family/{family_screen,invite,onboarding_screen}.dart`, `lib/features/today/today_screen.dart`, `lib/features/lists/*`, `lib/features/history/history_screen.dart`.
- **Security:** `firestore.rules` and tests in `rules-tests/test/rules.test.js` (73 tests).
- **CI:**
  - `.github/workflows/ci.yml` (flutter analyze/test + rules on push);
  - `keystore.yml` (run once; already done; artifact deleted);
  - `release.yml`: on a published release, builds with `--dart-define=APP_DOWNLOAD_URL=…${{ github.repository }}…`, attaches `family-app-<tag>.apk` and `family-app.apk`, signs from 5 secrets.

## 6. Architectural constraints and must-keeps

- UI never awaits offline-capable writes. Use `fireAndForget`. Only create/join family, regenerate code and role changes are awaited.
- **Chore dates:** local `YYYY-MM-DD`; weeks start on Sunday; one family timezone.
- **Child tick rules:**
  - children tick only today or yesterday (UI `canToggle` + rules window `[utcDay−2, utcDay+1]`);
  - they untick only their own ticks (`mayChange` guard + `toggleChore` backstop);
  - parents can tick for anyone on any day.
- **Names everywhere in chores use `memberLabel`:** displayName, else first name, else the name. The Family screen shows the full name.
- **`chores_screen.dart` must-keeps:**
  - `heroTag: 'addChore'`;
  - `mayChange` + backstop;
  - board cards via `_card`;
  - the Day switch `maxWidth >= boardBreakpoint && groups.any(...)`;
  - `addButtonClearance` (no literal 96);
  - LateStrip in Day mode;
  - Undo `Duration(seconds: 5)`;
  - shared `_canTick` / `_onToggle` / `_onEdit`.
- **Tablet:** board at width ≥ 840 dp; the Day | Week toggle only there; columns at least 260 dp wide.
- **Accessibility:**
  - tap targets ≥ 48 dp;
  - no overflow at 320×640 / 360×740, text 1.3, en+ar;
  - contrast ≥ 4.5:1 (palette tokens, `AppTokens.onToBuy` = #4A1B0C);
  - no hard-coded colours in features.
- **Data parsing:** `Member.fromMap` / `Chore.fromMap` / `ChoreDone.fromMap` are type-tolerant and never throw.
- **Rules changes** require Firas to paste `firestore.rules` into the Firebase console (Firestore → Rules → Publish). Copy it to his clipboard with `clip.exe < firestore.rules`. The latest rules (1.2.1+) are needed for name repair and display names.
- **Never commit** `android/key.properties`, `*.jks`, `*.keystore`, `android/app/google-services.json`, `rules-tests/node_modules` or `package-lock.json`.

## 7. Known bugs / open issues

- **Open:** none blocking. Release 2a.3 Tasks 1–2 aren't built yet.
- **Firas's own pending checks:**
  - Has he published the latest `firestore.rules`? Needed since 1.2.1.
  - Each phone must uninstall the debug-signed test app once, then install from the permanent link.
  - If Google sign-in fails on v1.3.0: the release SHA-1/SHA-256 is missing in Firebase.
- **Parked:** about 40 items in `docs/progress/STATUS.md` "Parking lot". Notable ones:
  - rules hardening (chore value ranges, photoUrl content, price type, last parent);
  - accessibility label for late ticks;
  - Today loading flash;
  - Arabic digit style;
  - week chip overflow at 840 dp with text 2.0×;
  - no "Today" button in the day switcher;
  - the KGP build warning (share_plus, flutter_timezone);
  - `replaceAll` called with an unchanged plan.
- **versionCode:** GitHub builds use `github.run_number` as versionCode (v1.3.0 = versionCode 1). Local test builds used up to 6. That's harmless because phones reinstall once.

## 8. Queue (in order)

1. **Release 2a.3 Tasks 1–2: members without a login.** Plan file above, approved design.
   - Task 1:
     - `lib/core/no_login.dart`: `newNoLoginId`, `isNoLoginId`; id `^nl_[A-Za-z0-9]{20}$`;
     - `Member.noLogin`;
     - `nextFreeColor`;
     - `FamilyRepository.addNoLoginMember`;
     - `firestore.rules`: a create branch `validNoLoginMember`, parent branch (a) gets `resource.data.get('noLogin', false) != true`, and a new update branch (c) for no-login members;
     - 9 emulator tests.
   - Task 2:
     - Family screen: an "Add member without login" button (`Key('addNoLoginMember')`), a "No login" tag (`noLoginTag-<id>`), no "Make parent" in their menu, Edit name writes `name` (not displayName), Remove;
     - `seedNoLoginMember` test helper;
     - 11 widget tests, including Review Focus #1–4.
   - Then a release: bump `pubspec.yaml`, test, push, and Firas publishes `v1.4.0` (FULL release, not pre-release). He must publish the new `firestore.rules` too.
2. **Firas's PRD for the product:** he asked for it "when limits reset". Use the PRD/docs skill: `anthropic-skills:docs`, or `product-management:write-spec`, or an Artifact document via `quickstart`.
3. **Later releases** (from the Skylight inventory):
   - 2b: family calendar + wall mode + Google Calendar;
   - 2c: star rewards;
   - also "link a login" for no-login members.

## 9. ABSOLUTE NEXT STEP

Ask Firas to confirm starting **Release 2a.3 Task 1** (he was just asked "Shall I start on members without a login now?"). On yes:
1. The PM (or Claude directly) writes `docs/progress/briefs/r2a3-task1-nologin-data.md` from plan Task 1.
2. Run developer → tester (rules emulator required).
3. Then Task 2 the same way.
4. Bump the version and push. Firas publishes the rules and release `v1.4.0`.
