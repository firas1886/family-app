# Family App: how this repo is built

This is a Flutter Android app built from an approved spec and plan:
- Spec: `docs/superpowers/specs/2026-09-27-family-app-shopping-design.md`
- Plan: `docs/superpowers/plans/2026-09-27-family-app-shopping.md`
- Release 2a (current): spec `docs/superpowers/specs/2026-09-28-release2a-chores-and-look-design.md`, plan `docs/superpowers/plans/2026-09-28-release2a-chores-and-look.md` (10 tasks)
- Progress: `docs/progress/STATUS.md` (kept by the project-manager agent)

## The team (in `.claude/agents/`)

- **project-manager:** picks the next task, writes briefs, records outcomes, escalates decisions. Writes no code.
- **developer:** implements exactly one task, test-first, and makes one commit.
- **tester:** verifies independently, returns PASS or FAIL. Read-only.

## The loop (the main session runs it; subagents can't call each other)

1. Ask **project-manager**: "What's next?" It returns a Developer brief.
2. Give that brief to **developer**. It returns a Developer report.
3. Give the report to **tester**. It returns a Test report.
4. Give the test report to **project-manager**. It updates STATUS.md and returns either the next brief (PASS) or a rework brief (FAIL).
5. Repeat from step 2.

Stop and ask Firas when:
- the project manager writes a **Decision needed** note;
- a task is Blocked;
- Task 14 is done (Firas must then follow `docs/SETUP.md`);
- anything needs his accounts (Firebase, GitHub secrets).

## Ground rules for every session

- Don't widen scope beyond the spec. Park new ideas in STATUS.md.
- Never commit `android/key.properties`, `*.jks`, `*.keystore` or `android/app/google-services.json`.
- Checks: `flutter analyze --no-fatal-infos`, `flutter test`, and `cd rules-tests && npm run emulate` for rules.
- Firas is a product/banking-tech manager, not a Flutter developer. When you talk to him, use plain language: what changed, what he needs to do, and what's next.
