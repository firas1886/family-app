# Family App — Release 1 status

| Task | Title | Status | Attempts | Commit | Notes |
|---|---|---|---|---|---|
| 1 | Project scaffold and CI | Not started | 0 | | Waiting: Flutter SDK not installed. Must merge into existing `ci.yml` (keep the `rules` job) and `.gitignore` (keep `rules-tests/node_modules/`), not overwrite; also add `*-debug.log` to `.gitignore` (emulator logs). |
| 2 | Text utilities | Not started | 0 | | Waiting: Flutter SDK |
| 3 | Models and placement logic | Not started | 0 | | Waiting: Flutter SDK |
| 4 | Firestore security rules | Done (2026-09-27) | 1 | 2650074 | Run ahead of Task 1. 22/22 rules tests pass. Tester found gaps in the plan's rules vs spec §7: see Decision needed below. |
| 5 | Family repository | Not started | 0 | | Waiting: Flutter SDK. Join-write shape may change depending on the Decision below. |
| 6 | Catalog repository | Not started | 0 | | |
| 7 | List and purchase repositories | Not started | 0 | | |
| 8 | App foundation (l10n, providers) | Not started | 0 | | |
| 9 | Item details sheet | Not started | 0 | | |
| 10 | Lists tab and list screen | Not started | 0 | | |
| 11 | History screen | Not started | 0 | | |
| 12 | Family screen | Not started | 0 | | |
| 13 | App shell | Not started | 0 | | |
| 14 | Release builds and setup guide | Not started | 0 | | |

**Next runnable task:** none. Every remaining task needs Flutter/Dart; waiting for Firas to install the Flutter SDK.

## Decision needed (2026-09-27) — tighten the security rules?
Task 4 passed exactly as the plan wrote it, but the tester found three holes where the plan's rules are looser than what the spec promises:
1. **Purchase deletes:** the spec says only parents can delete purchase records (kids get a 5-second Undo). The rules trust the purchase time the phone sends, so a child could fake a future time and then delete that purchase whenever they like.
2. **Removed creator:** if the person who created the family is demoted or removed, they can add themselves back as a parent.
3. **Join code:** anyone signed in who learns a family's internal ID can join as a child without the join code, and regenerating the code doesn't lock them out.

- **Option A — fix now, before Task 5.** A small rules-only rework of Task 4 (no Flutter needed, so it can run today): reject purchase times in the future (still works offline), only let the creator make their parent record while setting up the family, and require a valid join code when joining. Task 5's join step would then also save the code it used; I'd note that in Task 5's brief.
- **Option B — accept for Release 1.** The app is private to your family and these need deliberate misuse. Log them and revisit in Release 2.

**Recommendation: A.** The spec says these permissions are enforced by the security rules, the fix is small, it's the only work that can run before Flutter is installed, and doing it before Task 5 avoids reworking the join code logic later.

## Decisions
- 2026-09-27: Spec and plan approved by Firas. Execution: subagent-driven with PM / developer / tester agents.
- 2026-09-27: Flutter SDK not installed; Firas: ignore Flutter for now. Task 4 run ahead of Task 1 (no Flutter dependency). Task 1 must merge into the existing ci.yml and .gitignore.
- 2026-09-27: Task 4 PASS (2650074). Accepted deviation: `rules-tests/package.json` `emulate` script uses `\"npm test\"` quoting for Windows cmd.exe (also valid on Linux). ci.yml holds the Task 1 skeleton + `rules` job only; .gitignore holds only `rules-tests/node_modules/`.

## Parking lot
- Chores module (Release 2)
- Budget reports and charts built on purchase history
- Rules hardening (nice-to-have, from Task 4 test): enforce "last parent can't be demoted/leave" in rules too (spec §6 currently app-only); stop parents creating extra `isDefault: true` categories; check `users/{uid}.familyId` in rules rather than member-doc existence (spec §7 wording; current approach is equivalent in practice).
- Dev tooling: npm reports 13 vulnerabilities in rules-tests dev dependencies; local Node 25 vs CI Node 20.
