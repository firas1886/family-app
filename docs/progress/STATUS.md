# Family App — Release 1 status

| Task | Title | Status | Attempts | Commit | Notes |
|---|---|---|---|---|---|
| 1 | Project scaffold and CI | Not started | 0 | | Waiting: Flutter SDK not installed. Must merge into existing `ci.yml` (keep the `rules` job) and `.gitignore` (keep `rules-tests/node_modules/`), not overwrite; also add `*-debug.log` to `.gitignore` (emulator logs). |
| 2 | Text utilities | Not started | 0 | | Waiting: Flutter SDK |
| 3 | Models and placement logic | Not started | 0 | | Waiting: Flutter SDK |
| 4 | Firestore security rules | Rework (attempt 2) (2026-09-27) | 2 | 2650074 (attempt 1) | Attempt 1 passed as planned. Attempt 2 is an approved scope tightening (Option A), not a failure: rules-only fix for purchase time, creator re-parenting, join code. Developer also updates the plan's Task 4 code and Task 5 join write, plus one field in spec §3. |
| 5 | Family repository | Not started | 0 | | Waiting: Flutter SDK and Task 4 attempt 2. Join contract changes: `joinFamily` must write `joinCode: <normalized code>` on the new child member doc (same batch as the user doc). `createFamily` keeps its 3-step order (family → own parent member doc → batch of join code + Other + user doc); `regenerateCode` keeps delete-old + create-new + update-family in one batch. |
| 6 | Catalog repository | Not started | 0 | | |
| 7 | List and purchase repositories | Not started | 0 | | |
| 8 | App foundation (l10n, providers) | Not started | 0 | | |
| 9 | Item details sheet | Not started | 0 | | |
| 10 | Lists tab and list screen | Not started | 0 | | |
| 11 | History screen | Not started | 0 | | |
| 12 | Family screen | Not started | 0 | | |
| 13 | App shell | Not started | 0 | | |
| 14 | Release builds and setup guide | Not started | 0 | | |

**Next runnable task:** Task 4 rework (attempt 2, rules only). After that, every remaining task needs Flutter/Dart; waiting for Firas to install the Flutter SDK.

## Decision needed (2026-09-27) — tighten the security rules? RESOLVED
Firas chose Option A (see Decisions). Task 4 is in rework.

## Decisions
- 2026-09-27: Spec and plan approved by Firas. Execution: subagent-driven with PM / developer / tester agents.
- 2026-09-27: Flutter SDK not installed; Firas: ignore Flutter for now. Task 4 run ahead of Task 1 (no Flutter dependency). Task 1 must merge into the existing ci.yml and .gitignore.
- 2026-09-27: Task 4 PASS (2650074). Accepted deviation: `rules-tests/package.json` `emulate` script uses `\"npm test\"` quoting for Windows cmd.exe (also valid on Linux). ci.yml holds the Task 1 skeleton + `rules` job only; .gitignore holds only `rules-tests/node_modules/`.
- 2026-09-27: Firas chose Option A — tighten rules (purchase time, creator re-parenting, join code) as a rules-only rework of Task 4 before Task 5. Approved data-model addition: `members/{uid}.joinCode` (child joins only, the code used to join). Plan Task 4/Task 5 and spec §3 are updated to match, so later tasks and the tester compare against the new reference.

## Parking lot
- Chores module (Release 2)
- Budget reports and charts built on purchase history
- Rules hardening (nice-to-have, from Task 4 test): enforce "last parent can't be demoted/leave" in rules too (spec §6 currently app-only); stop parents creating extra `isDefault: true` categories; check `users/{uid}.familyId` in rules rather than member-doc existence (spec §7 wording; current approach is equivalent in practice).
- Rules hardening (from Task 4 rework): a parent deleting a `joinCodes` doc on its own, or setting `families/{f}.joinCode` to a code with no `joinCodes` doc, reopens the creator-setup window; could require these to change together (getAfter/existsAfter). An undo that syncs more than 10 min after `boughtAt` (long offline) is rejected by rules; a parent then deletes it in History.
- Dev tooling: npm reports 13 vulnerabilities in rules-tests dev dependencies; local Node 25 vs CI Node 20.
