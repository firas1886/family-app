# Family App — Release 2a (Chores and a new look) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. In this repo, execution follows the project-manager → developer → tester loop in `CLAUDE.md`.

**Goal:** Add chores (repeating, per person or "anyone", with ticking, late chores, reminders and a landscape tablet board) and give the whole app one light/dark visual system with person colours.

**Architecture:** Same layering as Release 1: `lib/core` pure Dart (dates, chore repeat logic, reminder planning, colour assignment), `lib/data` thin Firestore repositories plus a notification scheduler behind an interface, `lib/app` theme/tokens/providers, `lib/features/*` screens. Repeating chores are stored once as a rule; a `choreDone/{choreId}_{date}` record marks each completed day. Reminders are scheduled on each phone with local notifications.

**Tech Stack:** Flutter 3.47.5 / Dart 3.13, flutter_riverpod 2.x, cloud_firestore, gen-l10n (ar/en), fake_cloud_firestore for tests, flutter_local_notifications + timezone + flutter_timezone + shared_preferences (new), Firebase emulator + mocha for rules tests.

**Spec:** `docs/superpowers/specs/2026-09-28-release2a-chores-and-look-design.md` (approved 2026-09-28). Release 1 spec and plan still apply unless changed here.

## Global Constraints

- Everything in the Release 1 plan's Global Constraints still applies, including: `flutter analyze --no-fatal-infos` has no errors or warnings; `flutter test` passes; UI never `await`s an offline-capable write (use `fireAndForget`); never commit `android/key.properties`, `*.jks`, `*.keystore`, `android/app/google-services.json`.
- Application id `com.firas.familia`; namespace `com.family.family_app`; minSdk 24; app title "Family".
- New dependencies allowed, and only these: `flutter_local_notifications`, `timezone`, `flutter_timezone`, `shared_preferences`. Add each with `flutter pub add <name>` and keep the caret constraint pub writes for the resolved version (on Windows, check `pubspec.yaml` afterwards: `flutter.bat` can strip the `^`; restore it). Report the resolved versions.
- Font: IBM Plex Sans Arabic (SIL Open Font License), weights 400, 500, 600, bundled as assets in `assets/fonts/ibm_plex_sans_arabic/` with its `OFL.txt`. Source: `https://github.com/google/fonts/tree/main/ofl/ibmplexsansarabic` (files `IBMPlexSansArabic-Regular.ttf`, `-Medium.ttf`, `-SemiBold.ttf`, `OFL.txt`). Font family name in Flutter: `IBMPlexSansArabic`.
- Dates of chores are local calendar dates as `"YYYY-MM-DD"` strings. Weekday numbers follow `DateTime.weekday` (1 = Monday … 7 = Sunday). Weeks start on Sunday. The family shares one timezone.
- `dayNumber` = whole days since 1970-01-01 of the local date: `DateTime.utc(y, m, d).millisecondsSinceEpoch ~/ 86400000`.
- Chore title: trimmed, 1–80 characters. Monthly day 1–31; on shorter months it falls on the month's last day.
- Tablet board breakpoint: available width ≥ 840 dp. Board columns: minimum width 260 dp; if they don't fit, the board scrolls sideways.
- Tap targets ≥ 48 dp. Layouts must not overflow at 360×740 and 320×640 with text scale 1.0 and 1.3, in English and Arabic.
- Person palette: exactly 8 colours, index 0–7, values in the table below. Light theme: `fill` = 600 stop with white `onFill`; `tint` = 50 stop with 800-stop `onTint`. Dark theme: `fill` = 200 stop with 900-stop `onFill`; `tint` = 800 stop with 100-stop `onTint`.

| idx | name | 50 | 100 | 200 | 600 | 800 | 900 |
|---|---|---|---|---|---|---|---|
| 0 | teal | #E1F5EE | #9FE1CB | #5DCAA5 | #0F6E56 | #085041 | #04342C |
| 1 | coral | #FAECE7 | #F5C4B3 | #F0997B | #993C1D | #712B13 | #4A1B0C |
| 2 | amber | #FAEEDA | #FAC775 | #EF9F27 | #854F0B | #633806 | #412402 |
| 3 | purple | #EEEDFE | #CECBF6 | #AFA9EC | #534AB7 | #3C3489 | #26215C |
| 4 | blue | #E6F1FB | #B5D4F4 | #85B7EB | #185FA5 | #0C447C | #042C53 |
| 5 | pink | #FBEAF0 | #F4C0D1 | #ED93B1 | #993556 | #72243E | #4B1528 |
| 6 | green | #EAF3DE | #C0DD97 | #97C459 | #3B6D11 | #27500A | #173404 |
| 7 | gray | #F1EFE8 | #D3D1C7 | #B4B2A9 | #5F5E5A | #444441 | #2C2C2A |

- Shopping keeps its meanings: To buy tile `0xFFEE6A6A`, Recently used tile `0xFF6DB5A8` (both themes). Late: red family (light fill `#A32D2D`, tint `#FCEBEB`, onTint `#791F1F`; dark fill `#F09595`, tint `#791F1F`, onTint `#FCEBEB`).
- Every new user-facing string goes in both `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` (with real Arabic), then `flutter gen-l10n`.
- Rules changes are tested in `rules-tests/test/rules.test.js` via `cd rules-tests && npm run emulate` (set `JAVA_HOME` to the Android Studio `jbr` first). Local Windows release builds need `GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false`.
- Commit message trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A monthly chore set for the 31st** in a 30-day month and in February: it must appear on the month's last day, exactly once. Test: Task 4, "monthly on the 31st falls on the last day of short months".
2. **A child ticks a chore offline at 23:50 and the phone syncs after midnight**, including a phone in a timezone ahead of UTC: the tick must be accepted; a tick for three days ago must be refused. Test: Task 5, "child ticks today or yesterday only (timezone-safe window)".
3. **A chore edited from daily to weekly after being done on some days:** past done records and their copied titles stay; today's view follows the new rule. Test: Task 4, "editing the rule keeps past done records".
4. **A family with 9 or more members on the tablet:** colours wrap around the palette, the board scrolls sideways, and each column still scrolls on its own. Test: Task 7, "nine members: board scrolls sideways and columns scroll independently".
5. **Long Arabic chore titles with an emoji on a picture tile at 320 dp and text scale 1.3:** no overflow; title ellipsised; tick still tappable. Test: Task 6, "long Arabic titles do not overflow on small phones".

## File structure

```
assets/fonts/ibm_plex_sans_arabic/*.ttf, OFL.txt        Task 1
lib/app/palette.dart            PersonColor, personColor()          Task 1
lib/app/theme.dart              AppTokens, buildTheme()             Task 1 (rewrite)
lib/app/providers.dart          + themeModeProvider (T1), memberColorsProvider, authPhotoUrlProvider (T3),
                                + choreRepositoryProvider, choresProvider, choreDoneProvider, todayProvider (T5),
                                + sharedPreferencesProvider, remindEveryoneProvider, reminderSchedulerProvider (T9)
lib/app/app.dart                themes, HomeShell tabs (T1, T2, T6), ProfileSync (T3), ReminderSync (T9)
lib/core/models.dart            AppUser.themeMode (T1); Member.color/photoUrl/pictureTiles/joinedAt (T3)
lib/core/member_colors.dart     effectiveColorIndex, missingColorAssignments   Task 3
lib/core/dates.dart             dateKey, parseDateKey, dayNumberOf, dayOnly, addDays   Task 4
lib/core/chores.dart            Chore, ChoreDone, occursOn, choresForDay, lateChores, progressOf,
                                canToggle, validateChore   Task 4
lib/core/reminders.dart         PlannedReminder, planReminders   Task 9
lib/data/family_repository.dart + setThemeMode (T1); setColor, setPictureTiles, setPhotoUrl, color on create (T3)
lib/data/chore_repository.dart  ChoreRepository   Task 5
lib/data/reminder_scheduler.dart ReminderScheduler, LocalReminderScheduler   Task 9
lib/features/common/app_card.dart, empty_state.dart    Task 2
lib/features/common/member_avatar.dart                 Task 3
lib/features/today/today_screen.dart                   Task 2 (shopping), Task 8 (chores parts)
lib/features/chores/chores_screen.dart, chore_card.dart, chore_groups.dart,
                    repeat_label.dart, chore_sheet.dart  Task 6
lib/features/chores/chores_board.dart                   Task 7
lib/features/chores/who_did_it.dart, celebration.dart, late_strip.dart   Task 8
firestore.rules, rules-tests/test/rules.test.js         Tasks 3, 5
test/support/pump.dart, seed.dart                       extended in Tasks 3, 5, 9
test/support/fake_scheduler.dart                        Task 9
android/app/build.gradle.kts, src/main/AndroidManifest.xml   Task 9 (notifications)
docs/SETUP.md, pubspec.yaml version                     Task 10
```

---

### Task 1: Visual system — palette, tokens, fonts, light and dark themes

**Files:**
- Create: `lib/app/palette.dart`, `assets/fonts/ibm_plex_sans_arabic/{IBMPlexSansArabic-Regular.ttf,IBMPlexSansArabic-Medium.ttf,IBMPlexSansArabic-SemiBold.ttf,OFL.txt}`, `test/app/theme_test.dart`
- Modify: `lib/app/theme.dart` (rewrite), `pubspec.yaml` (fonts), `lib/core/models.dart` (`AppUser.themeMode`), `lib/data/family_repository.dart` (`setThemeMode`), `lib/app/providers.dart` (`themeModeProvider`), `lib/app/app.dart` (`theme`/`darkTheme`/`themeMode`), `lib/features/lists/list_screen.dart` and any other user of `AppColors` (switch to `context.tokens`)

**Interfaces:**
- Consumes: `appUserProvider` (existing).
- Produces:
  - `class PersonColor { const PersonColor({required this.fill, required this.onFill, required this.tint, required this.onTint}); final Color fill; final Color onFill; final Color tint; final Color onTint; }`
  - `const int personPaletteSize = 8;`
  - `PersonColor personColor(int index, Brightness brightness)` — index taken modulo 8 (negative-safe).
  - `class AppTokens extends ThemeExtension<AppTokens>` with fields `Color toBuy, recent, late, lateTint, onLateTint, card, cardBorder, mutedText; double cardRadius (16), tileRadius (20)` plus `copyWith`/`lerp`.
  - `extension AppTokensContext on BuildContext { AppTokens get tokens; }`
  - `ThemeData buildTheme(Brightness brightness)` — Material 3, font family `IBMPlexSansArabic`, `AppTokens` extension attached, light background `#F7F5F0`, dark background `#1E2326`.
  - `AppColors` is removed; its users switch to `context.tokens.toBuy / .recent / .card`.
  - `AppUser` gains `final String? themeMode;` (`'light'`, `'dark'`, or null = follow phone), read from `users/{uid}.themeMode`.
  - `Future<void> FamilyRepository.setThemeMode(String uid, String? mode)` — merge write of `themeMode`.
  - `final themeModeProvider = Provider<ThemeMode>` — from `appUserProvider`: 'light' → `ThemeMode.light`, 'dark' → `ThemeMode.dark`, otherwise `ThemeMode.system`.
  - `FamilyApp` uses `theme: buildTheme(Brightness.light)`, `darkTheme: buildTheme(Brightness.dark)`, `themeMode: ref.watch(themeModeProvider)`.
- Tests include: every palette entry's `onFill` on `fill` and `onTint` on `tint` has contrast ≥ 4.5:1 in both brightnesses (compute with `Color.computeLuminance`); `personColor(9, …) == personColor(1, …)`; `personColor(-1, …) == personColor(7, …)`; both themes carry `AppTokens`; `themeModeProvider` maps the three values.
- Commit: `feat(theme): palette, tokens, bundled font, light and dark themes`

Notes for the developer:
- `AppColors` has exactly one user today: `lib/features/lists/list_screen.dart`. `lib/features/lists/item_tile.dart` hard-codes white text, which would be invisible on a white catalog tile in the light theme, so this task also makes the tile's text colour follow the tile's brightness (Recently used tiles therefore get dark text; white on `#6DB5A8` is only 2.4:1). This is recorded under INTERFACE ISSUES.
- `context.tokens` falls back to `AppTokens.light` / `AppTokens.dark` when a theme has no `AppTokens` extension. `pumpWithFamily` builds a bare `MaterialApp` with no theme, so without the fallback every widget test of a restyled screen would crash.
- In `flutter test`, bundled fonts are not loaded (text uses the test font), so the font only changes the look on a device. The theme test still checks that the three `.ttf` files are real font files, not an HTML error page saved by `curl`.

- [x] **Step 1: Download the font and its licence**

In Git Bash, from the repo root:

```bash
mkdir -p assets/fonts/ibm_plex_sans_arabic
base=https://github.com/google/fonts/raw/main/ofl/ibmplexsansarabic
for f in IBMPlexSansArabic-Regular.ttf IBMPlexSansArabic-Medium.ttf IBMPlexSansArabic-SemiBold.ttf OFL.txt; do
  curl -fL -o "assets/fonts/ibm_plex_sans_arabic/$f" "$base/$f"
done
ls -l assets/fonts/ibm_plex_sans_arabic
for f in assets/fonts/ibm_plex_sans_arabic/*.ttf; do head -c 4 "$f" | od -An -tx1; done
grep -c "SIL OPEN FONT LICENSE" assets/fonts/ibm_plex_sans_arabic/OFL.txt
```

Expected: four files. Each `.ttf` starts with ` 00 01 00 00` (a TrueType font, not an HTML page); `OFL.txt` contains `SIL OPEN FONT LICENSE` (count ≥ 1). Report the four file sizes in the Developer report. If `curl` fails (`-f` makes a 404 fail loudly), stop and report Blocked; do not substitute another font.

- [x] **Step 2: Declare the font in `pubspec.yaml`**

In `pubspec.yaml`, under the top-level `flutter:` key, replace the whole commented example block that starts `  # To add custom fonts to your application, add a fonts section here,` and ends `  # see https://flutter.dev/to/font-from-package` with:

```yaml
  # IBM Plex Sans Arabic (SIL Open Font License, see assets/fonts/ibm_plex_sans_arabic/OFL.txt).
  fonts:
    - family: IBMPlexSansArabic
      fonts:
        - asset: assets/fonts/ibm_plex_sans_arabic/IBMPlexSansArabic-Regular.ttf
          weight: 400
        - asset: assets/fonts/ibm_plex_sans_arabic/IBMPlexSansArabic-Medium.ttf
          weight: 500
        - asset: assets/fonts/ibm_plex_sans_arabic/IBMPlexSansArabic-SemiBold.ttf
          weight: 600
```

(`fonts:` is indented two spaces, at the same level as `generate: true` and `uses-material-design: true`.) Run `flutter pub get`. Expected: `Got dependencies!` with no asset errors.

- [x] **Step 3: Write the failing tests**

Create `test/app/theme_test.dart`:

```dart
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart';
import 'package:family_app/app/palette.dart';
import 'package:family_app/app/providers.dart';
import 'package:family_app/app/theme.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/data/family_repository.dart';
import 'package:family_app/features/family/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('person palette', () {
    for (final brightness in Brightness.values) {
      test('text on every colour meets WCAG AA 4.5:1 ($brightness)', () {
        for (var i = 0; i < personPaletteSize; i++) {
          final c = personColor(i, brightness);
          expect(contrast(c.onFill, c.fill), greaterThanOrEqualTo(4.5), reason: 'onFill on fill, colour $i');
          expect(contrast(c.onTint, c.tint), greaterThanOrEqualTo(4.5), reason: 'onTint on tint, colour $i');
        }
      });

      test('the 8 colours are distinct ($brightness)', () {
        final fills = {for (var i = 0; i < personPaletteSize; i++) personColor(i, brightness).fill};
        expect(fills.length, personPaletteSize);
      });
    }

    test('uses the agreed stops', () {
      const teal = [
        Color(0xFF0F6E56), Color(0xFFFFFFFF), Color(0xFFE1F5EE), Color(0xFF085041), // light
        Color(0xFF5DCAA5), Color(0xFF04342C), Color(0xFF085041), Color(0xFF9FE1CB), // dark
      ];
      final light = personColor(0, Brightness.light);
      final dark = personColor(0, Brightness.dark);
      expect([light.fill, light.onFill, light.tint, light.onTint, dark.fill, dark.onFill, dark.tint, dark.onTint], teal);
    });

    test('indexes wrap around and negatives are safe', () {
      for (final b in Brightness.values) {
        expect(personColor(9, b), personColor(1, b));
        expect(personColor(8, b), personColor(0, b));
        expect(personColor(-1, b), personColor(7, b));
      }
    });
  });

  group('themes', () {
    for (final brightness in Brightness.values) {
      test('$brightness theme carries AppTokens and the bundled font', () {
        final theme = buildTheme(brightness);
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, brightness);
        expect(theme.colorScheme.brightness, brightness);
        final tokens = theme.extension<AppTokens>();
        expect(tokens, isNotNull);
        expect(tokens!.cardRadius, 16);
        expect(tokens.tileRadius, 20);
        expect(tokens.toBuy, const Color(0xFFEE6A6A));
        expect(tokens.recent, const Color(0xFF6DB5A8));
        expect(theme.textTheme.bodyMedium!.fontFamily, 'IBMPlexSansArabic');
        expect(theme.textTheme.titleLarge!.fontFamily, 'IBMPlexSansArabic');
      });

      test('$brightness tokens keep text readable', () {
        final theme = buildTheme(brightness);
        final tokens = theme.extension<AppTokens>()!;
        expect(contrast(tokens.onLateTint, tokens.lateTint), greaterThanOrEqualTo(4.5));
        expect(contrast(tokens.mutedText, tokens.card), greaterThanOrEqualTo(4.5));
        expect(contrast(tokens.mutedText, theme.scaffoldBackgroundColor), greaterThanOrEqualTo(4.5));
        expect(contrast(theme.colorScheme.onSurface, tokens.card), greaterThanOrEqualTo(4.5));
      });
    }

    test('page backgrounds', () {
      expect(buildTheme(Brightness.light).scaffoldBackgroundColor, const Color(0xFFF7F5F0));
      expect(buildTheme(Brightness.dark).scaffoldBackgroundColor, const Color(0xFF1E2326));
    });

    test('late colours', () {
      expect(AppTokens.light.late, const Color(0xFFA32D2D));
      expect(AppTokens.light.lateTint, const Color(0xFFFCEBEB));
      expect(AppTokens.light.onLateTint, const Color(0xFF791F1F));
      expect(AppTokens.dark.late, const Color(0xFFF09595));
      expect(AppTokens.dark.lateTint, const Color(0xFF791F1F));
      expect(AppTokens.dark.onLateTint, const Color(0xFFFCEBEB));
    });

    test('tokens copy and interpolate', () {
      expect(AppTokens.light.copyWith(card: const Color(0xFF000000)).card, const Color(0xFF000000));
      expect(AppTokens.light.copyWith().mutedText, AppTokens.light.mutedText);
      expect(AppTokens.light.lerp(AppTokens.dark, 0).card, AppTokens.light.card);
      expect(AppTokens.light.lerp(AppTokens.dark, 1).card, AppTokens.dark.card);
      expect(AppTokens.light.lerp(null, 0.5), AppTokens.light);
    });

    testWidgets('context.tokens reads the theme, with a fallback for bare themes', (tester) async {
      late AppTokens themed;
      late AppTokens bare;
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Builder(builder: (context) {
          themed = context.tokens;
          return Theme(
            data: ThemeData(brightness: Brightness.light),
            child: Builder(builder: (inner) {
              bare = inner.tokens;
              return const SizedBox();
            }),
          );
        }),
      ));
      expect(themed.card, AppTokens.dark.card);
      expect(bare.card, AppTokens.light.card);
    });

    test('the bundled font files are real fonts and the licence is there', () {
      const dir = 'assets/fonts/ibm_plex_sans_arabic';
      for (final weight in ['Regular', 'Medium', 'SemiBold']) {
        final bytes = File('$dir/IBMPlexSansArabic-$weight.ttf').readAsBytesSync();
        final tag = bytes.take(4).toList();
        final isFont = tag.toString() == [0, 1, 0, 0].toString() || String.fromCharCodes(tag) == 'OTTO';
        expect(isFont, isTrue, reason: '$weight is not a TrueType/OpenType file');
      }
      expect(File('$dir/OFL.txt').readAsStringSync().toUpperCase(), contains('SIL OPEN FONT LICENSE'));
    });
  });

  group('theme choice', () {
    Future<ThemeMode> modeFor(String? stored) async {
      final container = ProviderContainer(overrides: [
        appUserProvider.overrideWith(
          (ref) => Stream.value(AppUser(uid: 'u1', name: 'Dad', email: 'd@x', themeMode: stored)),
        ),
      ]);
      addTearDown(container.dispose);
      await container.read(appUserProvider.future);
      return container.read(themeModeProvider);
    }

    test('themeModeProvider maps the saved choice', () async {
      expect(await modeFor('light'), ThemeMode.light);
      expect(await modeFor('dark'), ThemeMode.dark);
      expect(await modeFor(null), ThemeMode.system);
      expect(await modeFor('purple'), ThemeMode.system);
    });

    test('AppUser reads themeMode', () {
      expect(AppUser.fromMap('u1', {'themeMode': 'dark'}).themeMode, 'dark');
      expect(AppUser.fromMap('u1', {}).themeMode, isNull);
    });

    test('setThemeMode saves and clears the choice', () async {
      final db = FakeFirebaseFirestore();
      final repo = FamilyRepository(db);
      await repo.ensureUser(uid: 'u1', name: 'Dad', email: 'd@x', language: 'en');
      await repo.setThemeMode('u1', 'dark');
      expect((await repo.watchUser('u1').first)!.themeMode, 'dark');
      await repo.setThemeMode('u1', null);
      expect((await repo.watchUser('u1').first)!.themeMode, isNull);
      expect((await repo.watchUser('u1').first)!.language, 'en');
    });

    testWidgets('the app follows the saved theme', (tester) async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/u9').set({
        'name': 'Firas', 'email': 'f@x.com', 'familyId': null, 'language': 'en', 'themeMode': 'dark',
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          currentUidProvider.overrideWithValue('u9'),
          authReadyProvider.overrideWithValue(true),
        ],
        child: const FamilyApp(),
      ));
      await settle(tester);
      BuildContext screen() => tester.element(find.byType(OnboardingScreen));
      expect(Theme.of(screen()).brightness, Brightness.dark);
      expect(screen().tokens.card, AppTokens.dark.card);

      await db.doc('users/u9').update({'themeMode': 'light'});
      await settle(tester);
      expect(Theme.of(screen()).brightness, Brightness.light);
      expect(screen().tokens.card, AppTokens.light.card);
    });
  });
}
```

- [x] **Step 4: Run the tests to verify they fail**

Run: `flutter test test/app/theme_test.dart`
Expected: FAIL, compilation error `Target of URI doesn't exist: 'package:family_app/app/palette.dart'` (and errors for `AppTokens`, `buildTheme(Brightness…)`, `themeMode`, `setThemeMode`, `themeModeProvider`).

- [x] **Step 5: Create the palette**

Create `lib/app/palette.dart`:

```dart
import 'package:flutter/material.dart';

/// One person's colour in one theme: a strong [fill] with [onFill] text,
/// and a light [tint] with [onTint] text.
class PersonColor {
  const PersonColor({required this.fill, required this.onFill, required this.tint, required this.onTint});
  final Color fill;
  final Color onFill;
  final Color tint;
  final Color onTint;

  @override
  bool operator ==(Object other) =>
      other is PersonColor &&
      other.fill == fill &&
      other.onFill == onFill &&
      other.tint == tint &&
      other.onTint == onTint;

  @override
  int get hashCode => Object.hash(fill, onFill, tint, onTint);
}

const int personPaletteSize = 8;

/// Stops 50, 100, 200, 600, 800, 900 of one palette colour.
class _Ramp {
  const _Ramp(this.s50, this.s100, this.s200, this.s600, this.s800, this.s900);
  final Color s50;
  final Color s100;
  final Color s200;
  final Color s600;
  final Color s800;
  final Color s900;
}

const _ramps = <_Ramp>[
  // 0 teal
  _Ramp(Color(0xFFE1F5EE), Color(0xFF9FE1CB), Color(0xFF5DCAA5), Color(0xFF0F6E56), Color(0xFF085041), Color(0xFF04342C)),
  // 1 coral
  _Ramp(Color(0xFFFAECE7), Color(0xFFF5C4B3), Color(0xFFF0997B), Color(0xFF993C1D), Color(0xFF712B13), Color(0xFF4A1B0C)),
  // 2 amber
  _Ramp(Color(0xFFFAEEDA), Color(0xFFFAC775), Color(0xFFEF9F27), Color(0xFF854F0B), Color(0xFF633806), Color(0xFF412402)),
  // 3 purple
  _Ramp(Color(0xFFEEEDFE), Color(0xFFCECBF6), Color(0xFFAFA9EC), Color(0xFF534AB7), Color(0xFF3C3489), Color(0xFF26215C)),
  // 4 blue
  _Ramp(Color(0xFFE6F1FB), Color(0xFFB5D4F4), Color(0xFF85B7EB), Color(0xFF185FA5), Color(0xFF0C447C), Color(0xFF042C53)),
  // 5 pink
  _Ramp(Color(0xFFFBEAF0), Color(0xFFF4C0D1), Color(0xFFED93B1), Color(0xFF993556), Color(0xFF72243E), Color(0xFF4B1528)),
  // 6 green
  _Ramp(Color(0xFFEAF3DE), Color(0xFFC0DD97), Color(0xFF97C459), Color(0xFF3B6D11), Color(0xFF27500A), Color(0xFF173404)),
  // 7 gray
  _Ramp(Color(0xFFF1EFE8), Color(0xFFD3D1C7), Color(0xFFB4B2A9), Color(0xFF5F5E5A), Color(0xFF444441), Color(0xFF2C2C2A)),
];

/// The colour for palette [index] (taken modulo 8, so any int is safe) in a theme.
PersonColor personColor(int index, Brightness brightness) {
  final ramp = _ramps[index % personPaletteSize];
  return brightness == Brightness.light
      ? PersonColor(fill: ramp.s600, onFill: const Color(0xFFFFFFFF), tint: ramp.s50, onTint: ramp.s800)
      : PersonColor(fill: ramp.s200, onFill: ramp.s900, tint: ramp.s800, onTint: ramp.s100);
}
```

- [x] **Step 6: Rewrite the theme**

Replace the whole of `lib/app/theme.dart` with:

```dart
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// App-specific design tokens, attached to both themes as a [ThemeExtension].
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.toBuy,
    required this.recent,
    required this.late,
    required this.lateTint,
    required this.onLateTint,
    required this.card,
    required this.cardBorder,
    required this.mutedText,
    this.cardRadius = 16,
    this.tileRadius = 20,
  });

  /// Shopping: To buy tiles (same in both themes).
  final Color toBuy;

  /// Shopping: Recently used tiles (same in both themes).
  final Color recent;

  /// Late chores: strong colour, light tint and text on the tint.
  final Color late;
  final Color lateTint;
  final Color onLateTint;

  /// Neutral cards on the calm screens.
  final Color card;
  final Color cardBorder;

  /// Secondary text; readable on [card] and on the page background.
  final Color mutedText;

  final double cardRadius;
  final double tileRadius;

  static const light = AppTokens(
    toBuy: Color(0xFFEE6A6A),
    recent: Color(0xFF6DB5A8),
    late: Color(0xFFA32D2D),
    lateTint: Color(0xFFFCEBEB),
    onLateTint: Color(0xFF791F1F),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE4E0D6),
    mutedText: Color(0xFF63625D),
  );

  static const dark = AppTokens(
    toBuy: Color(0xFFEE6A6A),
    recent: Color(0xFF6DB5A8),
    late: Color(0xFFF09595),
    lateTint: Color(0xFF791F1F),
    onLateTint: Color(0xFFFCEBEB),
    card: Color(0xFF283035),
    cardBorder: Color(0xFF3A444A),
    mutedText: Color(0xFFA9B1B6),
  );

  @override
  AppTokens copyWith({
    Color? toBuy,
    Color? recent,
    Color? late,
    Color? lateTint,
    Color? onLateTint,
    Color? card,
    Color? cardBorder,
    Color? mutedText,
    double? cardRadius,
    double? tileRadius,
  }) =>
      AppTokens(
        toBuy: toBuy ?? this.toBuy,
        recent: recent ?? this.recent,
        late: late ?? this.late,
        lateTint: lateTint ?? this.lateTint,
        onLateTint: onLateTint ?? this.onLateTint,
        card: card ?? this.card,
        cardBorder: cardBorder ?? this.cardBorder,
        mutedText: mutedText ?? this.mutedText,
        cardRadius: cardRadius ?? this.cardRadius,
        tileRadius: tileRadius ?? this.tileRadius,
      );

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      toBuy: Color.lerp(toBuy, other.toBuy, t)!,
      recent: Color.lerp(recent, other.recent, t)!,
      late: Color.lerp(late, other.late, t)!,
      lateTint: Color.lerp(lateTint, other.lateTint, t)!,
      onLateTint: Color.lerp(onLateTint, other.onLateTint, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
      tileRadius: lerpDouble(tileRadius, other.tileRadius, t)!,
    );
  }
}

extension AppTokensContext on BuildContext {
  /// The app's tokens. Falls back to the defaults for the theme's brightness
  /// when a theme without [AppTokens] is in use (for example a bare test app).
  AppTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AppTokens>() ??
        (theme.brightness == Brightness.dark ? AppTokens.dark : AppTokens.light);
  }
}

const _lightBackground = Color(0xFFF7F5F0);
const _darkBackground = Color(0xFF1E2326);
const _seed = Color(0xFF0F6E56); // palette teal, 600 stop

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final tokens = isDark ? AppTokens.dark : AppTokens.light;
  final background = isDark ? _darkBackground : _lightBackground;
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
    surface: background,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'IBMPlexSansArabic',
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: tokens.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        side: BorderSide(color: tokens.cardBorder),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.card,
      surfaceTintColor: Colors.transparent,
    ),
    extensions: [tokens],
  );
}
```

- [x] **Step 7: Save the theme choice on the user**

In `lib/core/models.dart`, replace the `AppUser` class:

```dart
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
```

with:

```dart
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.familyId,
    this.language,
    this.themeMode,
  });
  final String uid;
  final String name;
  final String email;
  final String? familyId;
  final String? language;

  /// 'light', 'dark', or null to follow the phone.
  final String? themeMode;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid,
        name: m['name'] as String? ?? '',
        email: m['email'] as String? ?? '',
        familyId: m['familyId'] as String?,
        language: m['language'] as String?,
        themeMode: m['themeMode'] as String?,
      );
}
```

In `lib/data/family_repository.dart`, directly after `setLanguage`:

```dart
  Future<void> setLanguage(String uid, String language) =>
      _user(uid).set({'language': language}, SetOptions(merge: true));
```

add:

```dart

  /// 'light', 'dark', or null to follow the phone.
  Future<void> setThemeMode(String uid, String? mode) =>
      _user(uid).set({'themeMode': mode}, SetOptions(merge: true));
```

(`users/{uid}` is already writable by its owner; no rules change.)

- [x] **Step 8: Add `themeModeProvider` and use both themes**

In `lib/app/providers.dart`, replace the import line `import 'package:flutter/widgets.dart';` with:

```dart
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
```

and insert directly above `String _requireFamily(Ref ref) {`:

```dart
/// The user's saved theme choice; anything else follows the phone.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return switch (ref.watch(appUserProvider).valueOrNull?.themeMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});

```

In `lib/app/app.dart`, inside `FamilyApp.build`, replace `      theme: buildTheme(),` with:

```dart
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
```

- [x] **Step 9: Switch the list screen and item tile to tokens**

In `lib/features/lists/list_screen.dart` (it already imports `../../app/theme.dart`), make these replacements:

1. After `    final l = AppLocalizations.of(context)!;` in `build`, add the line `    final tokens = context.tokens;`.
2. `child: Text(l.emptyToBuy, style: const TextStyle(color: Colors.white60)),` → `child: Text(l.emptyToBuy, style: TextStyle(color: tokens.mutedText)),`
3. `style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),` → `style: TextStyle(color: tokens.mutedText, fontWeight: FontWeight.w600)),`
4. `color: AppColors.toBuy,` → `color: tokens.toBuy,`
5. `color: AppColors.recent,` → `color: tokens.recent,`
6. `color: AppColors.surface,` → `color: tokens.card,`
7. In `_inputBar`, replace:

```dart
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
```

with:

```dart
                    decoration: InputDecoration(
                      hintText: l.iNeed,
                      hintStyle: TextStyle(color: context.tokens.mutedText),
                      filled: true,
                      fillColor: context.tokens.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(context.tokens.cardRadius),
                        borderSide: BorderSide(color: context.tokens.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(context.tokens.cardRadius),
                        borderSide: BorderSide(color: context.tokens.cardBorder),
                      ),
                    ),
```

Replace the whole of `lib/features/lists/item_tile.dart` with (only the colours change; layout is untouched):

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
    // Text colour follows the tile colour, so light tiles (the catalog's
    // card colour in the light theme) get dark text.
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final onColorMuted = onColor.withValues(alpha: 0.72);
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          border: Border.all(
            color: highlighted ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
            width: 3,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(6),
              // Keeps the width (so the name still wraps to 2 lines) and scales
              // the whole column down when a small phone or large text would
              // otherwise push the quantity out of the tile.
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: onColorMuted,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              tileLetter(name),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: onColor,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: onColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (caption.isNotEmpty)
                            Text(
                              caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: onColorMuted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Check nothing else uses `AppColors`: `grep -rn "AppColors" lib test` → no output.

- [x] **Step 10: Run the tests to verify they pass**

Run: `flutter test test/app/theme_test.dart`
Expected: PASS, `All tests passed!` (19 tests).

- [x] **Step 11: Full check**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: no errors or warnings (the 6 existing infos may remain); `All tests passed!` (127 tests: 108 before + 19 new). The list screen and item tile layout tests (`test/features/item_tile_test.dart`, `test/features/list_screen_test.dart`) must still pass unchanged.

- [x] **Step 12: Commit**

```bash
git add assets/fonts/ibm_plex_sans_arabic pubspec.yaml lib/app/palette.dart lib/app/theme.dart lib/app/providers.dart lib/app/app.dart lib/core/models.dart lib/data/family_repository.dart lib/features/lists/list_screen.dart lib/features/lists/item_tile.dart test/app/theme_test.dart
git commit -m "feat(theme): palette, tokens, bundled font, light and dark themes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Navigation, Today screen (shopping), shared widgets, restyle

**Files:**
- Create: `lib/features/common/app_card.dart`, `lib/features/common/empty_state.dart`, `lib/features/today/today_screen.dart`, `test/features/today_screen_test.dart`, `test/app/home_shell_test.dart`
- Modify: `lib/app/app.dart` (`HomeShell`: tabs Today · Lists · Family), `lib/features/lists/lists_screen.dart` (History button; restyle with `AppCard`/`EmptyState`), `lib/features/history/history_screen.dart` (now pushed as a page: has its own AppBar with back), `lib/features/family/family_screen.dart` and `lib/features/lists/list_screen.dart` (restyle only: `AppCard`, tokens; no behaviour change), both ARB files

**Interfaces:**
- Consumes: `context.tokens`, `buildTheme` (Task 1); `listsProvider`, `entriesProvider(listId)`, `clockProvider` (existing); `EntryStatus.toBuy` (existing).
- Produces:
  - `class AppCard extends StatelessWidget { const AppCard({super.key, required this.child, this.color, this.onTap, this.onLongPress, this.padding = const EdgeInsets.all(12)}); }` — rounded `tokens.cardRadius`, `color ?? tokens.card`, hairline `tokens.cardBorder` border when `color == null`, min height 48.
  - `class EmptyState extends StatelessWidget { const EmptyState({super.key, required this.emoji, required this.title, this.message, this.action}); final String emoji; final String title; final String? message; final Widget? action; }`
  - `class TodayScreen extends ConsumerWidget { const TodayScreen({super.key}); }` — a `ListView` with keys: `Key('todayHeader')` (date line from `clockProvider`), `Key('todayShopping')` section containing one `AppCard` per list with `ValueKey('todayList-<listId>')` showing the To buy count (tapping opens `ListScreen(listId:)`). Task 8 inserts chores sections between header and shopping; build the list of children so sections can be inserted.
  - `HomeShell` destinations in order: Today (`Icons.home_outlined`), Lists (`Icons.checklist`), Family (`Icons.group`). The History tab is removed. Task 6 inserts Chores at index 1.
  - `ListsScreen` app bar gets `IconButton(key: Key('openHistory'))` that pushes `HistoryScreen`.
  - New l10n keys: `tabToday`, `history`, `shopping`, `itemsToBuy` (plural, `{count}`), `nothingToBuy`, `noListsTitle`.
- Existing Release 1 tests must keep passing; update only test lines that navigate through the removed History tab (report each change as a Deviation).
- Commit: `feat(app): Today home, new navigation, shared cards and empty states`

Notes for the developer:
- **Existing tests and the History tab:** no existing test navigates through the History tab. `test/app/root_gate_test.dart` only checks that a `NavigationBar` exists (still true), and `test/features/history_screen_test.dart` pumps `HistoryScreen` directly as the home widget (still works: with nothing to pop, its AppBar shows no back button). So this task needs **no** edits to existing tests and has no Deviations from them. If one turns up anyway, report it as a Deviation.
- The Today card's count uses the same rule as the list screen's To buy section (`isOnToBuy(item, entry, now)` from `lib/core/placement.dart`), so a bought item that is due again counts too. Counting only `EntryStatus.toBuy` would miss those (see INTERFACE ISSUES).
- The ARB key `tabHistory` is replaced by `history`. The wording of `noListsParent` and `noListsChild` is shortened, because the empty state's title (`noListsTitle`) now says "No lists yet".

- [x] **Step 1: Write the failing tests**

Create `test/features/today_screen_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/features/lists/list_screen.dart';
import 'package:family_app/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../support/pump.dart';
import '../support/seed.dart';

/// Adds a second list with one item that is due again (bought 6 days ago, expiry 3)
/// and one item bought recently with no expiry (not to buy).
Future<void> addWeekendList(FakeFirebaseFirestore db, {String name = 'Weekend'}) async {
  await db.doc('families/f1/lists/l2').set({'name': name, 'createdBy': 'u1', 'createdAt': DateTime(2026, 2, 1)});
  await db.doc('families/f1/items/eggs').set(const Item(id: 'eggs', name: 'Eggs', categoryId: 'other', expiryDays: 3).toMap());
  await db.doc('families/f1/lists/l2/entries/eggs').set(Entry(
    itemId: 'eggs', status: EntryStatus.bought, boughtBy: 'u1', boughtAt: DateTime(2026, 9, 25),
  ).toMap());
  await db.doc('families/f1/lists/l2/entries/bread').set(Entry(
    itemId: 'bread', status: EntryStatus.bought, boughtBy: 'u1', boughtAt: DateTime(2026, 9, 30),
  ).toMap());
  await db.doc('families/f1/lists/l2/entries/milk').set(const Entry(itemId: 'milk', status: EntryStatus.toBuy).toMap());
}

void main() {
  testWidgets('shows today\'s date in the header', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const TodayScreen());
    expect(
      find.descendant(
        of: find.byKey(const Key('todayHeader')),
        matching: find.text(DateFormat.MMMMEEEEd('en').format(testNow)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows one card per list with its To buy count', (tester) async {
    final db = await seedFamily();
    await addWeekendList(db);
    await pumpWithFamily(tester, db: db, child: const TodayScreen());

    final shopping = find.byKey(const Key('todayShopping'));
    expect(find.descendant(of: shopping, matching: find.text('Shopping')), findsOneWidget);

    final home = find.byKey(const ValueKey('todayList-l1'));
    expect(find.descendant(of: home, matching: find.text('Home')), findsOneWidget);
    expect(find.descendant(of: home, matching: find.text('1 item to buy')), findsOneWidget);

    // Eggs are due again and milk is on To buy; bread (no expiry) is not.
    final weekend = find.byKey(const ValueKey('todayList-l2'));
    expect(find.descendant(of: weekend, matching: find.text('2 items to buy')), findsOneWidget);
  });

  testWidgets('a list with nothing to buy says so', (tester) async {
    final db = await seedFamily();
    await db.doc('families/f1/lists/l1/entries/milk').delete();
    await pumpWithFamily(tester, db: db, child: const TodayScreen());
    expect(
      find.descendant(of: find.byKey(const ValueKey('todayList-l1')), matching: find.text('Nothing to buy')),
      findsOneWidget,
    );
  });

  testWidgets('no lists shows a friendly line', (tester) async {
    final db = await seedFamily();
    await db.doc('families/f1/lists/l1').delete();
    await pumpWithFamily(tester, db: db, child: const TodayScreen());
    expect(find.text('No lists yet'), findsOneWidget);
  });

  testWidgets('tapping a list card opens that list', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const TodayScreen());
    await tester.tap(find.byKey(const ValueKey('todayList-l1')));
    await settle(tester);
    expect(find.byType(ListScreen), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
  });

  const sizes = [Size(360, 740), Size(320, 640)];
  const scales = [1.0, 1.3];
  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets('long Arabic list names fit at $size, text x$scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final db = await seedFamily();
        await addWeekendList(db, name: 'قائمة مشتريات نهاية الأسبوع الطويلة جداً للعائلة');
        await pumpWithFamily(tester, db: db, child: const TodayScreen());
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('todayList-l2')), findsOneWidget);
      });
    }
  }
}
```

Create `test/app/home_shell_test.dart`:

```dart
import 'package:family_app/app/app.dart';
import 'package:family_app/features/history/history_screen.dart';
import 'package:family_app/features/lists/lists_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

void main() {
  testWidgets('the bottom bar is Today, Lists, Family and opens on Today', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const HomeShell());
    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(labels, ['Today', 'Lists', 'Family']);
    expect(find.byKey(const Key('todayHeader')), findsOneWidget);
  });

  testWidgets('History opens from the Lists app bar and goes back', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const HomeShell());
    await tester.tap(find.byIcon(Icons.checklist));
    await settle(tester);
    expect(find.byType(ListsScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('openHistory')));
    await settle(tester);
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('No purchases yet.'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsNothing);
    expect(find.byKey(const Key('openHistory')), findsOneWidget);
  });
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/today_screen_test.dart test/app/home_shell_test.dart`
Expected: FAIL, compilation error `Target of URI doesn't exist: 'package:family_app/features/today/today_screen.dart'`.

- [x] **Step 3: Add the strings**

In `lib/l10n/app_en.arb`, replace `  "tabHistory": "History",` with:

```json
  "tabToday": "Today",
```

and replace

```json
  "noListsParent": "No lists yet. Create one to get started.",
  "noListsChild": "No lists yet. Ask a parent to create one.",
```

with

```json
  "noListsParent": "Create one to get started.",
  "noListsChild": "Ask a parent to create one.",
  "noListsTitle": "No lists yet",
  "history": "History",
  "shopping": "Shopping",
  "itemsToBuy": "{count, plural, =1{1 item to buy} other{{count} items to buy}}",
  "@itemsToBuy": { "placeholders": { "count": { "type": "int" } } },
  "nothingToBuy": "Nothing to buy",
```

In `lib/l10n/app_ar.arb`, replace `  "tabHistory": "السجل",` with:

```json
  "tabToday": "اليوم",
```

and replace

```json
  "noListsParent": "لا توجد قوائم بعد. أنشئ قائمة للبدء.",
  "noListsChild": "لا توجد قوائم بعد. اطلب من أحد الوالدين إنشاء قائمة.",
```

with

```json
  "noListsParent": "أنشئ قائمة للبدء.",
  "noListsChild": "اطلب من أحد الوالدين إنشاء قائمة.",
  "noListsTitle": "لا توجد قوائم بعد",
  "history": "السجل",
  "shopping": "التسوق",
  "itemsToBuy": "{count, plural, =0{لا شيء للشراء} =1{غرض واحد للشراء} =2{غرضان للشراء} few{{count} أغراض للشراء} many{{count} غرضًا للشراء} other{{count} غرض للشراء}}",
  "nothingToBuy": "لا شيء للشراء",
```

Run: `flutter gen-l10n`
Expected: the three generated files in `lib/l10n/` update with no errors.

- [x] **Step 4: Create the shared card and empty state**

Create `lib/features/common/app_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The app's rounded card. Neutral cards get a hairline border;
/// coloured cards ([color] set) have none.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = BorderRadius.circular(tokens.cardRadius);
    return Material(
      color: color ?? tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: color == null ? BorderSide(color: tokens.cardBorder) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
```

Create `lib/features/common/empty_state.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A friendly "nothing here" block: big emoji, a title, an optional message
/// and an optional action button. Place it inside a scrollable parent.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.title, this.message, this.action});

  final String emoji;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Text(emoji, style: const TextStyle(fontSize: 48))),
          const SizedBox(height: 12),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              style: text.bodyMedium?.copyWith(color: context.tokens.mutedText),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
```

- [x] **Step 5: Create the Today screen**

Create `lib/features/today/today_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/placement.dart';
import '../../l10n/app_localizations.dart';
import '../common/app_card.dart';
import '../common/offline_chip.dart';
import '../lists/list_screen.dart';

/// The home tab: today's date, then (Task 8) chores, then a shopping summary.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final sections = <Widget>[
      const _TodayHeader(key: Key('todayHeader')),
      // Chores sections go here (between the header and shopping).
      const _ShoppingSection(key: Key('todayShopping')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.tabToday), actions: const [OfflineChip()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 20),
            sections[i],
          ],
        ],
      ),
    );
  }
}

class _TodayHeader extends ConsumerWidget {
  const _TodayHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Localizations.localeOf(context).languageCode;
    final now = ref.watch(clockProvider)();
    return Text(
      DateFormat.MMMMEEEEd(lang).format(now),
      style: Theme.of(context).textTheme.headlineSmall,
    );
  }
}

class _ShoppingSection extends ConsumerWidget {
  const _ShoppingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final lists = ref.watch(listsProvider).valueOrNull ?? const <ShoppingList>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.shopping, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (lists.isEmpty)
          Text(l.noListsTitle, style: TextStyle(color: context.tokens.mutedText)),
        for (final list in lists)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ListSummaryCard(list: list),
          ),
      ],
    );
  }
}

class _ListSummaryCard extends ConsumerWidget {
  const _ListSummaryCard({required this.list});
  final ShoppingList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final entries = ref.watch(entriesProvider(list.id)).valueOrNull ?? const <Entry>[];
    final items = {for (final i in ref.watch(itemsProvider).valueOrNull ?? const <Item>[]) i.id: i};
    final now = ref.watch(clockProvider)();
    // Same rule as the list screen's To buy section, so due-again items count too.
    final count = entries.where((e) {
      final item = items[e.itemId];
      return item != null && isOnToBuy(item, e, now);
    }).length;

    return AppCard(
      key: ValueKey('todayList-${list.id}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ListScreen(listId: list.id)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 40,
            decoration: BoxDecoration(
              color: count > 0 ? tokens.toBuy : tokens.cardBorder,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  count == 0 ? l.nothingToBuy : l.itemsToBuy(count),
                  style: TextStyle(color: tokens.mutedText),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
```

- [x] **Step 6: New navigation; History moves into Lists**

In `lib/app/app.dart`:

1. Replace the imports

```dart
import '../features/history/history_screen.dart';
import '../features/lists/lists_screen.dart';
```

with

```dart
import '../features/lists/lists_screen.dart';
import '../features/today/today_screen.dart';
```

2. In `_HomeShellState.build`, replace `        children: const [ListsScreen(), HistoryScreen(), FamilyScreen()],` with `        children: const [TodayScreen(), ListsScreen(), FamilyScreen()],`
3. Replace the three destinations

```dart
          NavigationDestination(icon: const Icon(Icons.checklist), label: l.tabLists),
          NavigationDestination(icon: const Icon(Icons.receipt_long), label: l.tabHistory),
          NavigationDestination(icon: const Icon(Icons.group), label: l.tabFamily),
```

with

```dart
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: l.tabToday),
          NavigationDestination(icon: const Icon(Icons.checklist), label: l.tabLists),
          NavigationDestination(icon: const Icon(Icons.group), label: l.tabFamily),
```

In `lib/features/history/history_screen.dart`, replace

```dart
      appBar: AppBar(title: Text(l.tabHistory), actions: const [OfflineChip()]),
```

with

```dart
      // Pushed from the Lists app bar, so the AppBar shows a back button.
      appBar: AppBar(title: Text(l.history), actions: const [OfflineChip()]),
```

Replace the whole of `lib/features/lists/lists_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/app_card.dart';
import '../common/dialogs.dart';
import '../common/empty_state.dart';
import '../common/offline_chip.dart';
import '../history/history_screen.dart';
import 'list_screen.dart';

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final isParent = ref.watch(isParentProvider);
    final lists = ref.watch(listsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabLists),
        actions: [
          const OfflineChip(),
          IconButton(
            key: const Key('openHistory'),
            tooltip: l.history,
            icon: const Icon(Icons.receipt_long),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
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
        error: (_, _) => Center(child: Text(l.somethingWentWrong)),
        data: (lists) => ListView(
          // Bottom padding keeps the last card clear of the FAB.
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: [
            if (lists.isEmpty)
              EmptyState(
                emoji: '🛒',
                title: l.noListsTitle,
                message: isParent ? l.noListsParent : l.noListsChild,
              ),
            for (final list in lists)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => ListScreen(listId: list.id)),
                  ),
                  onLongPress: isParent ? () => _manage(context, ref, list, l) : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          list.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
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

- [x] **Step 7: Restyle the Family and List screens (no behaviour change)**

Replace the whole of `lib/features/family/family_screen.dart` with (same keys, texts and actions as before, now in `AppCard`s):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/text.dart';
import '../../data/family_repository.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/app_card.dart';
import '../common/dialogs.dart';
import '../common/offline_chip.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (family != null)
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(family.name, style: text.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          '${l.joinCode}: ${family.joinCode}',
                          style: text.bodyMedium?.copyWith(color: context.tokens.mutedText),
                        ),
                      ],
                    ),
                  ),
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
          _SectionTitle(l.members),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final m in members)
                  ListTile(
                    leading: CircleAvatar(child: Text(tileLetter(m.name))),
                    title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
              ],
            ),
          ),
          _SectionTitle(l.language),
          AppCard(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
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
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}
```

In `lib/features/lists/list_screen.dart` (as left by Task 1):

1. Replace the imports

```dart
import '../../l10n/app_localizations.dart';
import '../common/dialogs.dart';
import '../common/offline_chip.dart';
```

with

```dart
import '../../l10n/app_localizations.dart';
import '../common/app_card.dart';
import '../common/dialogs.dart';
import '../common/empty_state.dart';
import '../common/offline_chip.dart';
```

2. Replace the empty To buy message

```dart
                if (sections.toBuy.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l.emptyToBuy, style: TextStyle(color: tokens.mutedText)),
                  ),
```

with

```dart
                if (sections.toBuy.isEmpty) EmptyState(emoji: '🎉', title: l.emptyToBuy),
```

3. Replace the whole catalog loop

```dart
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
                            color: tokens.card,
                            caption: quantityLabel(l, item.quantity, item.unit),
                            dimmed: sections.isOnToBuy(item.id),
                            highlighted: _flashId == item.id,
                            onTap: () => _addToBuy(item, sections),
                            onLongPress: () => _openSheet(item, entryMap[item.id]),
                          ),
                      ], key: PageStorageKey('grid-${group.category?.id}')),
                    ],
                  ),
```

with (each category becomes a card; its tiles use the page colour so they stand out on the card)

```dart
                for (final group in catalog)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ExpansionTile(
                        key: PageStorageKey('cat-${group.category?.id}'),
                        tilePadding: EdgeInsets.zero,
                        shape: const Border(),
                        collapsedShape: const Border(),
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
                                // Catalog tiles sit inside a card, so they use the page colour.
                                color: Theme.of(context).scaffoldBackgroundColor,
                                caption: quantityLabel(l, item.quantity, item.unit),
                                dimmed: sections.isOnToBuy(item.id),
                                highlighted: _flashId == item.id,
                                onTap: () => _addToBuy(item, sections),
                                onLongPress: () => _openSheet(item, entryMap[item.id]),
                              ),
                          ], key: PageStorageKey('grid-${group.category?.id}')),
                        ],
                      ),
                    ),
                  ),
```

4. Replace `_header`

```dart
  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
```

with

```dart
  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
```

Check: `grep -rn "tabHistory" lib test` → no output (after `flutter gen-l10n`).

- [x] **Step 8: Run the tests to verify they pass**

Run: `flutter test test/features/today_screen_test.dart test/app/home_shell_test.dart`
Expected: PASS, `All tests passed!` (11 tests).

- [x] **Step 9: Full check**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: no errors or warnings; `All tests passed!` (138 tests). In particular the unchanged `test/features/family_screen_test.dart`, `lists_screen_test.dart`, `list_screen_test.dart`, `item_tile_test.dart`, `history_screen_test.dart` and `test/app/root_gate_test.dart` pass.

- [x] **Step 10: Commit**

```bash
git add lib/app/app.dart lib/features/common/app_card.dart lib/features/common/empty_state.dart lib/features/today/today_screen.dart lib/features/lists/lists_screen.dart lib/features/lists/list_screen.dart lib/features/history/history_screen.dart lib/features/family/family_screen.dart lib/l10n test/features/today_screen_test.dart test/app/home_shell_test.dart
git commit -m "feat(app): Today home, new navigation, shared cards and empty states" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Member colours, photos, picture tiles, theme choice on Family screen

**Files:**
- Create: `lib/core/member_colors.dart`, `lib/features/common/member_avatar.dart`, `test/core/member_colors_test.dart`, `test/features/family_screen_r2_test.dart`
- Modify: `lib/core/models.dart` (`Member`), `lib/data/family_repository.dart`, `lib/app/providers.dart`, `lib/app/app.dart` (`ProfileSync`), `lib/features/family/family_screen.dart`, `test/support/pump.dart` (override `authPhotoUrlProvider` with null), `firestore.rules`, `rules-tests/test/rules.test.js`, both ARB files

**Interfaces:**
- Consumes: `personColor`, `PersonColor`, `personPaletteSize` (Task 1); `AppCard` (Task 2); `membersProvider`, `isParentProvider`, `currentUidProvider`, `familyIdProvider`, `authUserProvider` (existing).
- Produces:
  - `Member` gains `final int? color; final String? photoUrl; final bool pictureTiles; final DateTime? joinedAt;` (constructor params optional, defaults null/false; `fromMap` reads `color`, `photoUrl`, `pictureTiles`, `joinedAt` via `readDate`).
  - `int effectiveColorIndex(Member m, List<Member> all)` — `m.color` if set; otherwise the index `missingColorAssignments(all)[m.uid]`.
  - `Map<String, int> missingColorAssignments(List<Member> all)` — for members without `color`, ordered by `joinedAt` (nulls last) then `uid`, each gets the lowest index 0–7 not used by members that have a colour or were assigned earlier in this pass; when all 8 are used, continue with `count % 8`.
  - `final memberColorsProvider = Provider<Map<String, int>>` — uid → effective colour index for current members.
  - `final authPhotoUrlProvider = Provider<String?>((ref) => ref.watch(authUserProvider).valueOrNull?.photoURL);`
  - `FamilyRepository`: `Future<void> setColor(String familyId, String uid, int index)`, `Future<void> setPictureTiles(String familyId, String uid, bool on)`, `Future<void> setPhotoUrl(String familyId, String uid, String? url)`; `createFamily` writes `'color': 0` on the creator's member doc.
  - `class MemberAvatar extends ConsumerWidget { const MemberAvatar({super.key, required this.member, this.size = 40, this.progress}); final Member member; final double size; final double? progress; }` — photo (`NetworkImage`) if `photoUrl` set, else `tileLetter(name)` on `personColor(index).fill` with `onFill` text; if `progress` (0–1) is set, draws a ring in the person's `fill` colour around it. Colour from `memberColorsProvider`.
  - `class ProfileSync extends ConsumerWidget { const ProfileSync({super.key, required this.child}); }` — wraps `HomeShell` in `_MembershipGuard`; after members load: (a) if my `photoUrl` differs from `authPhotoUrlProvider` and the latter is non-null → `fireAndForget(setPhotoUrl)`; (b) if I am a parent and `missingColorAssignments` is non-empty → `fireAndForget(setColor)` for each.
  - Family screen additions (keys): member colour dot `ValueKey('memberColor-<uid>')` (parents: opens a dialog of 8 swatches `ValueKey('paletteColor-<i>')`), `ValueKey('pictureTiles-<uid>')` switch shown to parents on child rows, theme `SegmentedButton` `Key('themeMode')` with segments system/light/dark calling `setThemeMode` via `fireAndForget`. Members' leading avatar becomes `MemberAvatar`.
  - Rules: `members/{m}` update allowed when (a) `isParent(f)` and only keys in `['role','color','pictureTiles']` change, `role in ['parent','child']`, `color` is int 0–7 if present, `pictureTiles` is bool if present; or (b) `uid() == m` and only `photoUrl` changes and it is a string or null. Rules tests: parent sets colour; child cannot set colour; member sets own photoUrl; member cannot set another's photoUrl; parent cannot set colour 9.
  - New l10n keys: `color`, `pictureTiles`, `theme`, `themeSystem`, `themeLight`, `themeDark`, `pickColor`.
- Commit: `feat(family): member colours, Google photos, picture tiles and theme choice`

Notes for the developer:
- `lib/core/member_colors.dart` keeps its own private palette size (8) so `lib/core` stays free of Flutter imports; a test checks that it wraps exactly like `personPaletteSize`.
- A joining child can't read the other members before joining, so `joinFamily` writes no colour. The first time a parent's phone opens the app afterwards, `ProfileSync` gives the newcomer the lowest free colour. Until then, `memberColorsProvider` already shows that colour on every phone.
- `ProfileSync` writes only after the frame (never during `build`), following the `_MembershipGuard` pattern. The writes repeat the same values, so a second callback before the stream catches up is harmless.
- `pumpWithFamily` gains an optional `String? photoUrl` (default null) that feeds the `authPhotoUrlProvider` override, so tests can check the photo sync. Without the override, `ProfileSync` inside `RootGate` would reach `FirebaseAuth.instance` and crash every `RootGate` test.
- Family screen layout: language and theme are two rows (icon with a screen-reader label, then the buttons) in one settings card, and the picture-tiles switch is a small row under each child's member row. This keeps `Key('leaveFamily')` inside the default 800×600 test surface, so the existing Release 1 test "the last parent cannot leave" still taps it without scrolling. Both SegmentedButtons sit in a `FittedBox(scaleDown)`, so three theme segments don't overflow at 320 dp with text ×1.3.

- [x] **Step 1: Write the failing Dart tests**

Create `test/core/member_colors_test.dart`:

```dart
import 'package:family_app/app/palette.dart';
import 'package:family_app/core/member_colors.dart';
import 'package:family_app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

Member member(String uid, {int? color, DateTime? joined}) =>
    Member(uid: uid, name: uid, role: Role.child, color: color, joinedAt: joined);

void main() {
  test('Member reads colour, photo, picture tiles and join time', () {
    final m = Member.fromMap('u2', {
      'name': 'Sara', 'role': 'child', 'color': 3, 'photoUrl': 'https://p/s.png',
      'pictureTiles': true, 'joinedAt': DateTime(2026, 9, 1),
    });
    expect(m.color, 3);
    expect(m.photoUrl, 'https://p/s.png');
    expect(m.pictureTiles, isTrue);
    expect(m.joinedAt, DateTime(2026, 9, 1));

    final old = Member.fromMap('u1', {'name': 'Dad', 'role': 'parent'});
    expect(old.color, isNull);
    expect(old.photoUrl, isNull);
    expect(old.pictureTiles, isFalse);
    expect(old.joinedAt, isNull);
  });

  test('members without a colour get the lowest free index', () {
    final all = [member('a', color: 0), member('b', color: 2), member('c'), member('d')];
    expect(missingColorAssignments(all), {'c': 1, 'd': 3});
  });

  test('assignment follows join order, unknown join times last, then uid', () {
    final all = [
      member('z', joined: DateTime(2026, 1, 3)),
      member('y'),
      member('x', joined: DateTime(2026, 1, 1)),
      member('w'),
    ];
    expect(missingColorAssignments(all), {'x': 0, 'z': 1, 'w': 2, 'y': 3});
  });

  test('everyone coloured means nothing to assign', () {
    expect(missingColorAssignments([member('a', color: 5)]), isEmpty);
    expect(missingColorAssignments(const []), isEmpty);
  });

  test('colours wrap around after the whole palette is used', () {
    final all = [for (var i = 0; i < 10; i++) member('m$i', joined: DateTime(2026, 1, 1 + i))];
    final assigned = missingColorAssignments(all);
    expect([for (var i = 0; i < 10; i++) assigned['m$i']], [0, 1, 2, 3, 4, 5, 6, 7, 0, 1]);
    // Same wrap as the palette itself.
    expect(assigned['m8'], 8 % personPaletteSize);
  });

  test('effectiveColorIndex prefers the saved colour', () {
    final all = [member('a', color: 6), member('b')];
    expect(effectiveColorIndex(all[0], all), 6);
    expect(effectiveColorIndex(all[1], all), 0);
    // A member missing from the list is placed as if they were in it.
    expect(effectiveColorIndex(member('c'), all), 1);
  });
}
```

Create `test/features/family_screen_r2_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart';
import 'package:family_app/app/palette.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/data/family_repository.dart';
import 'package:family_app/features/common/member_avatar.dart';
import 'package:family_app/features/family/family_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<Map<String, dynamic>> memberDoc(FakeFirebaseFirestore db, String uid) async =>
    (await db.doc('families/f1/members/$uid').get()).data()!;

void main() {
  group('Family screen', () {
    testWidgets('members show avatars and colour dots', (tester) async {
      final db = await seedFamily();
      await db.doc('families/f1/members/u2').update({'color': 4});
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      expect(find.byType(MemberAvatar), findsNWidgets(2));
      expect(find.byKey(const ValueKey('memberColor-u1')), findsOneWidget);
      expect(find.byKey(const ValueKey('memberColor-u2')), findsOneWidget);
      // Sara's letter sits on her saved colour (blue).
      final avatar = tester.widget<CircleAvatar>(
        find.descendant(of: find.widgetWithText(MemberAvatar, 'S'), matching: find.byType(CircleAvatar)),
      );
      expect(avatar.backgroundColor, personColor(4, Brightness.light).fill);
    });

    testWidgets('a parent picks a colour for a member', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      await tester.tap(find.byKey(const ValueKey('memberColor-u2')));
      await settle(tester);
      expect(find.byKey(const ValueKey('paletteColor-7')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('paletteColor-5')));
      await settle(tester);
      expect((await memberDoc(db, 'u2'))['color'], 5);
    });

    testWidgets('a child sees colours but cannot change them', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
      expect(find.byKey(const ValueKey('memberColor-u2')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('memberColor-u2')));
      await settle(tester);
      expect(find.byKey(const ValueKey('paletteColor-0')), findsNothing);
    });

    testWidgets('parents switch picture tiles on for a child; children see no switch', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      expect(find.byKey(const ValueKey('pictureTiles-u1')), findsNothing); // parents have none
      expect(tester.widget<Switch>(find.byKey(const ValueKey('pictureTiles-u2'))).value, isFalse);
      await tester.tap(find.byKey(const ValueKey('pictureTiles-u2')));
      await settle(tester);
      expect((await memberDoc(db, 'u2'))['pictureTiles'], isTrue);
      expect(tester.widget<Switch>(find.byKey(const ValueKey('pictureTiles-u2'))).value, isTrue);

      await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
      expect(find.byKey(const ValueKey('pictureTiles-u2')), findsNothing);
    });

    testWidgets('the theme choice is saved on the user', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
      expect(find.byKey(const Key('themeMode')), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await settle(tester);
      expect((await db.doc('users/u2').get()).data()!['themeMode'], 'dark');
      await tester.tap(find.text('System'));
      await settle(tester);
      expect((await db.doc('users/u2').get()).data()!['themeMode'], isNull);
    });

    testWidgets('a member with a photo still shows their letter underneath', (tester) async {
      final db = await seedFamily();
      await db.doc('families/f1/members/u2').update({'photoUrl': 'https://example.com/sara.png'});
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      await settle(tester);
      expect(tester.takeException(), isNull);
      final avatar = tester.widget<CircleAvatar>(
        find.descendant(of: find.widgetWithText(MemberAvatar, 'S'), matching: find.byType(CircleAvatar)),
      );
      expect(avatar.foregroundImage, isA<NetworkImage>());
    });

    testWidgets('a progress ring is drawn around the avatar', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(
        tester,
        db: db,
        child: const Scaffold(body: MemberAvatar(member: Member(uid: 'u2', name: 'Sara', role: Role.child), progress: 0.5)),
      );
      final ring = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
      expect(ring.value, 0.5);
    });

    const sizes = [Size(360, 740), Size(320, 640)];
    const scales = [1.0, 1.3];
    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets('fits a small phone at $size, text x$scale', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final db = await seedFamily();
          await db.doc('families/f1/members/u2').update({'name': 'سارة عبدالله محمد الأحمد'});
          await pumpWithFamily(tester, db: db, child: const FamilyScreen());
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('themeMode')), findsOneWidget);
        });
      }
    }
  });

  group('ProfileSync', () {
    const home = ProfileSync(child: Text('home'));

    testWidgets('saves my Google photo on my member doc', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, uid: 'u2', photoUrl: 'https://example.com/sara.png', child: home);
      await settle(tester);
      expect((await memberDoc(db, 'u2'))['photoUrl'], 'https://example.com/sara.png');
      expect((await memberDoc(db, 'u1')).containsKey('photoUrl'), isFalse);
    });

    testWidgets("a parent's phone gives colours to members without one", (tester) async {
      final db = await seedFamily();
      await db.doc('families/f1/members/u1').update({'joinedAt': DateTime(2026, 1, 1)});
      await db.doc('families/f1/members/u2').update({'joinedAt': DateTime(2026, 2, 1)});
      await pumpWithFamily(tester, db: db, child: home);
      await settle(tester);
      expect((await memberDoc(db, 'u1'))['color'], 0);
      expect((await memberDoc(db, 'u2'))['color'], 1);
    });

    testWidgets('saved colours are kept; newcomers get the lowest free one', (tester) async {
      final db = await seedFamily();
      await db.doc('families/f1/members/u1').update({'color': 0});
      await db.doc('families/f1/members/u2').update({'color': 1});
      await db.doc('families/f1/members/u3').set({'name': 'Omar', 'role': 'child'});
      await pumpWithFamily(tester, db: db, child: home);
      await settle(tester);
      expect((await memberDoc(db, 'u1'))['color'], 0);
      expect((await memberDoc(db, 'u2'))['color'], 1);
      expect((await memberDoc(db, 'u3'))['color'], 2);
    });

    testWidgets("a child's phone writes no colours", (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: home);
      await settle(tester);
      expect((await memberDoc(db, 'u1')).containsKey('color'), isFalse);
      expect((await memberDoc(db, 'u2')).containsKey('color'), isFalse);
    });

    test("a new family's creator starts with colour 0", () async {
      final db = FakeFirebaseFirestore();
      final repo = FamilyRepository(db);
      await repo.ensureUser(uid: 'u1', name: 'Dad', email: 'd@x', language: 'en');
      final f = await repo.createFamily(uid: 'u1', userName: 'Dad', familyName: 'Home', otherCategoryName: 'Other');
      expect((await repo.watchMember(f, 'u1').first)!.color, 0);
    });

    testWidgets('the app shell is wrapped in ProfileSync', (tester) async {
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, child: const RootGate());
      expect(find.byType(ProfileSync), findsOneWidget);
      expect(find.byType(HomeShell), findsOneWidget);
    });
  });
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/member_colors_test.dart test/features/family_screen_r2_test.dart`
Expected: FAIL, compilation errors `Target of URI doesn't exist: 'package:family_app/core/member_colors.dart'` and `…/features/common/member_avatar.dart`, plus `No named parameter with the name 'color'` for `Member` and `photoUrl` for `pumpWithFamily`.

- [x] **Step 3: Write the failing rules tests**

In `rules-tests/test/rules.test.js`, insert this block directly above `describe('join codes', () => {`:

```js
describe('member colours, photos and picture tiles', () => {
  it('a parent sets colours and picture tiles', async () => {
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { color: 3 }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { pictureTiles: true }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/members/dad`), { color: 0 }));
  });
  it('a child cannot set a colour or picture tiles', async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { color: 2 }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/dad`), { color: 2 }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { pictureTiles: true }));
  });
  it('a parent cannot set colour 9 or other bad values', async () => {
    await assertFails(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { color: 9 }));
    await assertFails(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { color: -1 }));
    await assertFails(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { color: '3' }));
    await assertFails(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { pictureTiles: 'yes' }));
  });
  it("a parent cannot change a member's name", async () => {
    await assertFails(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { name: 'Someone' }));
  });
  it('a member sets their own photoUrl', async () => {
    await assertSucceeds(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { photoUrl: 'https://example.com/kid.png' }));
    await assertSucceeds(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { photoUrl: null }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/members/dad`), { photoUrl: 'https://example.com/dad.png' }));
  });
  it("a member cannot set another member's photoUrl", async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/dad`), { photoUrl: 'https://example.com/x.png' }));
    await assertFails(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { photoUrl: 'https://example.com/x.png' }));
  });
  it('a photo update cannot carry other changes or a non-string', async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { photoUrl: 'https://example.com/kid.png', role: 'parent' }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { photoUrl: 42 }));
  });
  it('the creator of a new family starts with colour 0', async () => {
    const db = as('newbie');
    await setDoc(doc(db, 'families/fam2'), { name: 'New', joinCode: 'XYZ789', createdBy: 'newbie' });
    await assertSucceeds(setDoc(doc(db, 'families/fam2/members/newbie'), { name: 'N', role: 'parent', color: 0 }));
  });
});
```

Run (set `JAVA_HOME` to the Android Studio `jbr` first): `cd rules-tests && npm run emulate`
Expected: FAIL. `a parent sets colours and picture tiles`, `a member sets their own photoUrl` fail (the current rule allows only `role` changes); the other new tests already pass; all 34 existing tests pass.

- [x] **Step 4: Update the members rule**

In `firestore.rules`, replace

```
        allow update: if isParent(f) && onlyChanges(['role'])
          && request.resource.data.role in ['parent', 'child'];
```

with

```
        // Parents change role, colour and picture tiles; a member changes only their own photo.
        allow update: if (isParent(f)
            && onlyChanges(['role', 'color', 'pictureTiles'])
            && request.resource.data.role in ['parent', 'child']
            && (!('color' in request.resource.data)
              || (request.resource.data.color is int
                && request.resource.data.color >= 0
                && request.resource.data.color <= 7))
            && (!('pictureTiles' in request.resource.data)
              || request.resource.data.pictureTiles is bool))
          || (signedIn() && uid() == m
            && onlyChanges(['photoUrl'])
            && (request.resource.data.photoUrl == null
              || request.resource.data.photoUrl is string));
```

The full `members/{m}` block is now:

```
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
        // Parents change role, colour and picture tiles; a member changes only their own photo.
        allow update: if (isParent(f)
            && onlyChanges(['role', 'color', 'pictureTiles'])
            && request.resource.data.role in ['parent', 'child']
            && (!('color' in request.resource.data)
              || (request.resource.data.color is int
                && request.resource.data.color >= 0
                && request.resource.data.color <= 7))
            && (!('pictureTiles' in request.resource.data)
              || request.resource.data.pictureTiles is bool))
          || (signedIn() && uid() == m
            && onlyChanges(['photoUrl'])
            && (request.resource.data.photoUrl == null
              || request.resource.data.photoUrl is string));
        allow delete: if isParent(f) || (signedIn() && uid() == m);
      }
```

Run: `cd rules-tests && npm run emulate`
Expected: PASS, `42 passing`.

- [x] **Step 5: Extend `Member`, the repository and the providers**

In `lib/core/models.dart`, replace the `Member` class:

```dart
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
```

with:

```dart
class Member {
  const Member({
    required this.uid,
    required this.name,
    required this.role,
    this.color,
    this.photoUrl,
    this.pictureTiles = false,
    this.joinedAt,
  });
  final String uid;
  final String name;
  final Role role;

  /// Palette index 0–7, or null until one is assigned.
  final int? color;

  /// The member's Google profile photo, or null.
  final String? photoUrl;

  /// Show this member's chores as big emoji tiles.
  final bool pictureTiles;
  final DateTime? joinedAt;

  factory Member.fromMap(String uid, Map<String, dynamic> m) => Member(
        uid: uid,
        name: m['name'] as String? ?? '',
        role: m['role'] == 'parent' ? Role.parent : Role.child,
        color: readInt(m['color']),
        photoUrl: m['photoUrl'] as String?,
        pictureTiles: m['pictureTiles'] == true,
        joinedAt: readDate(m['joinedAt']),
      );
}
```

In `lib/data/family_repository.dart`:

1. In `createFamily`, replace `    await _members(familyRef.id).doc(uid).set({'name': userName, 'role': 'parent', 'joinedAt': now});` with

```dart
    await _members(familyRef.id).doc(uid).set({'name': userName, 'role': 'parent', 'joinedAt': now, 'color': 0});
```

2. Directly above `  Future<void> setRole(String familyId, String memberUid, Role role) async {` insert:

```dart
  /// Parents only (security rules): palette index 0–7.
  Future<void> setColor(String familyId, String uid, int index) =>
      _members(familyId).doc(uid).update({'color': index});

  /// Parents only (security rules).
  Future<void> setPictureTiles(String familyId, String uid, bool on) =>
      _members(familyId).doc(uid).update({'pictureTiles': on});

  /// Only the member themselves (security rules).
  Future<void> setPhotoUrl(String familyId, String uid, String? url) =>
      _members(familyId).doc(uid).update({'photoUrl': url});

```

Create `lib/core/member_colors.dart`:

```dart
import 'models.dart';

/// Number of person colours (same as `personPaletteSize` in lib/app/palette.dart;
/// kept here so lib/core stays free of Flutter imports).
const _paletteSize = 8;

/// The palette index [m] is shown with: their saved colour, or the one
/// [missingColorAssignments] would give them.
int effectiveColorIndex(Member m, List<Member> all) {
  final color = m.color;
  if (color != null) return color;
  final everyone = all.any((x) => x.uid == m.uid) ? all : [...all, m];
  return missingColorAssignments(everyone)[m.uid]!;
}

/// Colours for members that have none yet. Members are taken in join order
/// (unknown join times last, then by uid); each gets the lowest index 0–7 not
/// used by a coloured member or by an earlier assignment. Once all 8 are
/// used, the next index is (number of colours in use) % 8.
Map<String, int> missingColorAssignments(List<Member> all) {
  final used = <int>[
    for (final m in all)
      if (m.color != null) m.color! % _paletteSize,
  ];
  final missing = all.where((m) => m.color == null).toList()
    ..sort((a, b) {
      final ja = a.joinedAt;
      final jb = b.joinedAt;
      if (ja != null && jb != null) {
        final byTime = ja.compareTo(jb);
        if (byTime != 0) return byTime;
      } else if (ja != null) {
        return -1;
      } else if (jb != null) {
        return 1;
      }
      return a.uid.compareTo(b.uid);
    });

  final result = <String, int>{};
  for (final m in missing) {
    var index = -1;
    for (var i = 0; i < _paletteSize; i++) {
      if (!used.contains(i)) {
        index = i;
        break;
      }
    }
    if (index == -1) index = used.length % _paletteSize;
    used.add(index);
    result[m.uid] = index;
  }
  return result;
}
```

In `lib/app/providers.dart`:

1. Replace `import '../core/models.dart';` with

```dart
import '../core/member_colors.dart';
import '../core/models.dart';
```

2. Directly after the `currentUidProvider` line, add:

```dart

/// The signed-in user's Google profile photo (overridden with null in tests).
final authPhotoUrlProvider = Provider<String?>((ref) => ref.watch(authUserProvider).valueOrNull?.photoURL);
```

3. Directly after the `isParentProvider` declaration (ending `);`), add:

```dart

/// uid → palette index for every current member, including members whose
/// colour has not been saved yet.
final memberColorsProvider = Provider<Map<String, int>>((ref) {
  final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];
  final missing = missingColorAssignments(members);
  return {for (final m in members) m.uid: m.color ?? missing[m.uid]!};
});
```

In `test/support/pump.dart`, replace

```dart
  String uid = 'u1',
}) async {
```

with

```dart
  String uid = 'u1',
  String? photoUrl,
}) async {
```

and after `      clockProvider.overrideWithValue(() => testNow),` add:

```dart
      // Tests have no FirebaseAuth; the Google photo comes from here instead.
      authPhotoUrlProvider.overrideWithValue(photoUrl),
```

- [x] **Step 6: Add `ProfileSync` around the home shell**

In `lib/app/app.dart`:

1. Replace `import '../data/write.dart';` with

```dart
import '../core/member_colors.dart';
import '../core/models.dart';
import '../data/write.dart';
```

2. In `RootGate.build`, replace `              : const _MembershipGuard(child: HomeShell()),` with

```dart
              : const _MembershipGuard(child: ProfileSync(child: HomeShell())),
```

3. Directly above `class HomeShell extends StatefulWidget {` insert:

```dart
/// Keeps member profiles tidy once the family has loaded:
/// saves my Google photo on my member doc, and (parents only) gives a colour
/// to every member who has none yet.
class ProfileSync extends ConsumerWidget {
  const ProfileSync({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider).valueOrNull;
    final uid = ref.watch(currentUidProvider);
    final familyId = ref.watch(familyIdProvider);
    final photoUrl = ref.watch(authPhotoUrlProvider);
    final isParent = ref.watch(isParentProvider);
    if (members != null && uid != null && familyId != null &&
        _needsSync(members, uid, photoUrl, isParent)) {
      // Writes happen after the frame, never during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final latest = ref.read(membersProvider).valueOrNull;
        if (latest == null) return;
        final repo = ref.read(familyRepositoryProvider);
        final me = latest.where((m) => m.uid == uid).firstOrNull;
        if (me != null && photoUrl != null && me.photoUrl != photoUrl) {
          fireAndForget(repo.setPhotoUrl(familyId, uid, photoUrl));
        }
        if (isParent) {
          for (final entry in missingColorAssignments(latest).entries) {
            fireAndForget(repo.setColor(familyId, entry.key, entry.value));
          }
        }
      });
    }
    return child;
  }

  static bool _needsSync(List<Member> members, String uid, String? photoUrl, bool isParent) {
    final me = members.where((m) => m.uid == uid).firstOrNull;
    final photoChanged = me != null && photoUrl != null && me.photoUrl != photoUrl;
    final colorsMissing = isParent && members.any((m) => m.color == null);
    return photoChanged || colorsMissing;
  }
}
```

- [x] **Step 7: Create the member avatar**

Create `lib/features/common/member_avatar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../core/models.dart';
import '../../core/text.dart';

/// A member's Google photo, or their first letter on their colour.
/// With [progress] (0–1) a ring in their colour shows how much is done.
class MemberAvatar extends ConsumerWidget {
  const MemberAvatar({super.key, required this.member, this.size = 40, this.progress});

  final Member member;
  final double size;
  final double? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(memberColorsProvider)[member.uid] ?? member.color ?? 0;
    final color = personColor(index, Theme.of(context).brightness);
    final url = member.photoUrl;
    final hasPhoto = url != null && url.isNotEmpty;

    // The letter stays underneath the photo, so it shows while the photo
    // loads and if it can't be loaded (offline).
    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: color.fill,
      foregroundImage: hasPhoto ? NetworkImage(url) : null,
      onForegroundImageError: hasPhoto ? (_, _) {} : null,
      child: Text(
        tileLetter(member.name),
        style: TextStyle(
          color: color.onFill,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );

    final value = progress;
    if (value == null) return SizedBox.square(dimension: size, child: avatar);

    const ring = 3.0;
    const gap = 2.0;
    final outer = size + 2 * (ring + gap);
    return SizedBox.square(
      dimension: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: outer,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: ring,
              color: color.fill,
              backgroundColor: color.tint,
            ),
          ),
          avatar,
        ],
      ),
    );
  }
}
```

- [x] **Step 8: Add the strings**

In `lib/l10n/app_en.arb`, directly after `  "nothingToBuy": "Nothing to buy",` add:

```json
  "color": "Colour",
  "pickColor": "Pick a colour",
  "pictureTiles": "Picture tiles",
  "theme": "Theme",
  "themeSystem": "System",
  "themeLight": "Light",
  "themeDark": "Dark",
```

In `lib/l10n/app_ar.arb`, directly after `  "nothingToBuy": "لا شيء للشراء",` add:

```json
  "color": "اللون",
  "pickColor": "اختر لوناً",
  "pictureTiles": "بطاقات مصوّرة",
  "theme": "المظهر",
  "themeSystem": "تلقائي",
  "themeLight": "فاتح",
  "themeDark": "داكن",
```

Run: `flutter gen-l10n`
Expected: generated files update with no errors.

- [x] **Step 9: Family screen — avatars, colours, picture tiles, theme**

Replace the whole of `lib/features/family/family_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/family_repository.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/app_card.dart';
import '../common/dialogs.dart';
import '../common/member_avatar.dart';
import '../common/offline_chip.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final family = ref.watch(familyProvider).valueOrNull;
    final isParent = ref.watch(isParentProvider);
    final uid = ref.watch(currentUidProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final colors = ref.watch(memberColorsProvider);
    final lang = user?.language ?? Localizations.localeOf(context).languageCode;
    final themeMode = switch (user?.themeMode) {
      'light' => 'light',
      'dark' => 'dark',
      _ => 'system',
    };
    final members = [...(ref.watch(membersProvider).valueOrNull ?? const <Member>[])]
      ..sort((a, b) {
        if (a.role != b.role) return a.role == Role.parent ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(title: Text(l.tabFamily), actions: const [OfflineChip()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (family != null)
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(family.name, style: text.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          '${l.joinCode}: ${family.joinCode}',
                          style: text.bodyMedium?.copyWith(color: context.tokens.mutedText),
                        ),
                      ],
                    ),
                  ),
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
          _SectionTitle(l.members),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final m in members) ...[
                  ListTile(
                    leading: MemberAvatar(member: m),
                    title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(m.role == Role.parent ? l.parent : l.child),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ColorDot(
                          member: m,
                          index: colors[m.uid] ?? m.color ?? 0,
                          familyId: isParent ? family?.id : null,
                        ),
                        if (isParent && m.uid != uid && family != null)
                          PopupMenuButton<String>(
                            key: ValueKey('memberMenu-${m.uid}'),
                            onSelected: (action) => _onMemberAction(context, ref, family.id, m, action),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'role',
                                child: Text(m.role == Role.parent ? l.makeChild : l.makeParent),
                              ),
                              PopupMenuItem(value: 'remove', child: Text(l.removeMember)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (isParent && m.role == Role.child && family != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.pictureTiles,
                              style: text.bodyMedium?.copyWith(color: context.tokens.mutedText),
                            ),
                          ),
                          Switch(
                            key: ValueKey('pictureTiles-${m.uid}'),
                            value: m.pictureTiles,
                            onChanged: (on) => fireAndForget(
                              ref.read(familyRepositoryProvider).setPictureTiles(family.id, m.uid, on),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.language,
                  label: l.language,
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
                _SettingRow(
                  icon: Icons.brightness_6_outlined,
                  label: l.theme,
                  child: SegmentedButton<String>(
                    key: const Key('themeMode'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'system', label: Text(l.themeSystem)),
                      ButtonSegment(value: 'light', label: Text(l.themeLight)),
                      ButtonSegment(value: 'dark', label: Text(l.themeDark)),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) {
                      final choice = selection.first;
                      if (uid != null) {
                        fireAndForget(ref
                            .read(familyRepositoryProvider)
                            .setThemeMode(uid, choice == 'system' ? null : choice));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

/// An icon (labelled for screen readers) and a control that shrinks to fit narrow phones.
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.label, required this.child});
  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Tooltip(message: label, child: Icon(icon, semanticLabel: label)),
            const SizedBox(width: 12),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: child,
              ),
            ),
          ],
        ),
      );
}

/// The member's colour. Parents tap it to pick another colour.
class _ColorDot extends ConsumerWidget {
  const _ColorDot({required this.member, required this.index, required this.familyId});
  final Member member;
  final int index;

  /// Null when the viewer can't change colours.
  final String? familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final key = ValueKey('memberColor-${member.uid}');
    final dot = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: personColor(index, Theme.of(context).brightness).fill,
        shape: BoxShape.circle,
      ),
    );
    final id = familyId;
    if (id == null) {
      return Semantics(
        key: key,
        label: l.color,
        child: SizedBox.square(dimension: 48, child: Center(child: dot)),
      );
    }
    return IconButton(
      key: key,
      tooltip: l.pickColor,
      icon: dot,
      onPressed: () async {
        final picked = await _pickColor(context, index);
        if (picked != null && picked != member.color) {
          fireAndForget(ref.read(familyRepositoryProvider).setColor(id, member.uid, picked));
        }
      },
    );
  }

  Future<int?> _pickColor(BuildContext context, int current) {
    final l = AppLocalizations.of(context)!;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final brightness = Theme.of(dialogContext).brightness;
        return AlertDialog(
          title: Text(l.pickColor),
          content: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < personPaletteSize; i++)
                IconButton(
                  key: ValueKey('paletteColor-$i'),
                  iconSize: 36,
                  onPressed: () => Navigator.of(dialogContext).pop(i),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: personColor(i, brightness).fill,
                      shape: BoxShape.circle,
                    ),
                    child: i == current
                        ? Icon(Icons.check, color: personColor(i, brightness).onFill)
                        : null,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l.cancel)),
          ],
        );
      },
    );
  }
}
```

- [x] **Step 10: Run the tests to verify they pass**

Run: `flutter test test/core/member_colors_test.dart test/features/family_screen_r2_test.dart test/features/family_screen_test.dart`
Expected: PASS, `All tests passed!` (29 tests: 6 + 17 new, 6 existing unchanged).

- [x] **Step 11: Full check**

Run: `flutter analyze --no-fatal-infos && flutter test`, then `cd rules-tests && npm run emulate`
Expected: no errors or warnings; `All tests passed!` (161 tests); rules `42 passing`.

- [x] **Step 12: Commit**

```bash
git add lib/core/member_colors.dart lib/core/models.dart lib/data/family_repository.dart lib/app/providers.dart lib/app/app.dart lib/features/common/member_avatar.dart lib/features/family/family_screen.dart lib/l10n test/support/pump.dart test/core/member_colors_test.dart test/features/family_screen_r2_test.dart firestore.rules rules-tests/test/rules.test.js
git commit -m "feat(family): member colours, Google photos, picture tiles and theme choice" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

#### Drafting notes (writer A): interface issues resolved at merge

1. **Task 1 also touches `lib/features/lists/item_tile.dart`** (not in its Files list). The tile hard-codes white text, which would be invisible on a white catalog tile in the light theme. The text colour now follows the tile's brightness, so Recently used tiles (`#6DB5A8`) get dark text instead of white (white was 2.4:1). The tile colours themselves (coral and teal) are unchanged.
2. **Task 1 additions, not listed in the interfaces:** `AppTokens.light` and `AppTokens.dark` static presets; `PersonColor` value equality (`==`/`hashCode`, which the `personColor(9) == personColor(1)` test relies on); and a fallback in `context.tokens` to the preset for the theme's brightness when a theme has no `AppTokens` extension. `pumpWithFamily` uses a bare `MaterialApp`, so without the fallback every restyled screen's widget test would throw.
3. **Task 2 Today count:** the interface lists `EntryStatus.toBuy` as the input. The implementation counts with `isOnToBuy(item, entry, now)` (`lib/core/placement.dart`) plus `itemsProvider`, matching the list screen's To buy section. Counting status alone would miss bought items that are due again.
4. **Task 2 ARB housekeeping:** `tabHistory` is removed (replaced by `history`), and the existing `noListsParent`/`noListsChild` texts are shortened because the new `noListsTitle` carries "No lists yet". No test depends on the old wording.
5. **Task 2 "tests that rely on the History tab":** there are none (see the Task 2 notes). No Deviations are expected.
6. **Task 3 `pumpWithFamily`** gains an optional `String? photoUrl` parameter (default null, so the override is null as specified). It is needed to test ProfileSync's photo sync. Task 9 should add its `scheduler` parameter alongside it.
7. **Task 3 colours for joiners:** the spec says colours are assigned "at create or join", but a joiner can't read the other members before joining. So `joinFamily` writes no colour, and the colour is saved by a parent's `ProfileSync`. Until then, `memberColorsProvider` shows the same colour on every phone.
8. **Task 3 rules:** the member *create* rule is unchanged (per "existing role rules unchanged"), so it does not validate `color` or `photoUrl` at create time. A joining child could write any value there, and only a parent could correct it later. This is low risk; tighten it if the rules reviewer wants.
9. **Verification limits:** in worktree `scratchpad/wt-A`, the code of all three tasks was built on top of `28fd442`, using placeholder font files with a valid TrueType header. The real font download needs the user's permission to fetch files, so it was not run. Results: `flutter analyze --no-fatal-infos` showed only the 5 existing infos, and `flutter test` passed 161 tests. The rules tests were written and checked with `node --check` but not run: the emulator port is in use by another writer.

---

### Task 4: Dates and chore logic (pure Dart)

**Files:**
- Create: `lib/core/dates.dart`, `lib/core/chores.dart`, `test/core/dates_test.dart`, `test/core/chores_test.dart`

**Interfaces:**
- Consumes: `compareNames` from `lib/core/text.dart`; `readDate` from `lib/core/models.dart`.
- Produces (`lib/core/dates.dart`):
  - `DateTime dayOnly(DateTime d)` → `DateTime(d.year, d.month, d.day)`
  - `DateTime addDays(DateTime d, int n)` → `DateTime(d.year, d.month, d.day + n)`
  - `String dateKey(DateTime d)` → zero-padded `YYYY-MM-DD`
  - `DateTime parseDateKey(String key)` → local midnight
  - `int dayNumberOf(DateTime d)` → `DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000`
  - `DateTime startOfWeek(DateTime d)` → the Sunday on or before `d`
- Produces (`lib/core/chores.dart`):
  - `enum Repeat { once, daily, weekly, monthly }`
  - `class Chore { const Chore({required this.id, required this.title, this.icon, this.assignee, this.time, this.repeat = Repeat.once, this.every = 1, this.weekdays = const [], this.monthDay, required this.startDate, this.endDate, this.remind = false, required this.createdBy}); final String id; final String title; final String? icon; final String? assignee; final String? time; final Repeat repeat; final int every; final List<int> weekdays; final int? monthDay; final String startDate; final String? endDate; final bool remind; final String createdBy; bool get isAnyone; factory Chore.fromMap(String id, Map<String, dynamic> m); Map<String, dynamic> toMap(); Chore copyWith({...all fields; use a sentinel so nullable fields can be set to null}); }` — `toMap` writes every field except `id` (and not `createdAt`); `repeat` stored as its `name`.
  - `class ChoreDone { const ChoreDone({required this.choreId, required this.date, required this.choreTitle, this.assignee, required this.doneBy, required this.doneByName, this.doneAt, required this.dayNumber}); ... String get id; factory ChoreDone.fromMap(Map<String, dynamic> m); Map<String, dynamic> toMap(); }` (`doneAt` read with `readDate`)
  - `String choreDoneId(String choreId, String date)` → `'${choreId}_$date'`
  - `bool occursOn(Chore c, DateTime day)` — false before `startDate` or after `endDate`; once: day == start; daily: days since start % every == 0; weekly: weekday in `weekdays` and (weeks between `startOfWeek(start)` and `startOfWeek(day)`) % every == 0; monthly: months since start's month % every == 0 and day == min(monthDay, last day of that month).
  - `class ChoreStatus { const ChoreStatus(this.chore, this.done); final Chore chore; final ChoreDone? done; bool get isDone; }`
  - `class DayView { const DayView({required this.byMember, required this.anyone, required this.formerMember}); final Map<String, List<ChoreStatus>> byMember; final List<ChoreStatus> anyone; final List<ChoreStatus> formerMember; }` — `byMember` has an entry (possibly empty) for every uid in `memberUids`.
  - `DayView choresForDay({required List<Chore> chores, required List<ChoreDone> done, required Set<String> memberUids, required DateTime day})` — chores occurring on `day`; each list sorted: timed first by `time`, then by `compareNames(title)`.
  - `class LateChore { const LateChore(this.chore, this.date); final Chore chore; final String date; }`
  - `List<LateChore> lateChores({required List<Chore> chores, required List<ChoreDone> done, required DateTime today, int lookBackDays = 60})` — only chores that are `Repeat.once` or `isAnyone`; for each, the most recent occurrence before `today` within the look-back window that has no done record, and only if the chore has no done record dated after that occurrence up to and including today. Sorted by date, then title.
  - `({int done, int total}) progressOf(List<ChoreStatus> items)`
  - `bool canToggle({required Chore chore, required bool isParent, required String me, required DateTime day, required DateTime today})` — parents: always; children: only if (`chore.assignee == me` or `isAnyone`) and `day` is today or yesterday.
  - `enum ChoreProblem { blankTitle, titleTooLong, weeklyNoDays, badMonthDay, endBeforeStart }`
  - `Set<ChoreProblem> validateChore(Chore c)`
- Tests include Review Focus #1 ("monthly on the 31st falls on the last day of short months") and #3 ("editing the rule keeps past done records": done records for days no longer matching still appear in history queries; `choresForDay` for today follows the new rule).

- [x] **Step 1: Write the failing date tests**

Create `test/core/dates_test.dart`:

```dart
import 'package:family_app/core/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dayOnly drops the time of day', () {
    expect(dayOnly(DateTime(2026, 9, 28, 23, 59, 59)), DateTime(2026, 9, 28));
    expect(dayOnly(DateTime(2026, 9, 28)), DateTime(2026, 9, 28));
  });

  test('dateKey is zero-padded YYYY-MM-DD of the local date', () {
    expect(dateKey(DateTime(2026, 3, 5)), '2026-03-05');
    expect(dateKey(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
    expect(dateKey(DateTime(987, 1, 9)), '0987-01-09');
  });

  test('parseDateKey gives local midnight and round-trips every day of a leap year', () {
    final d = parseDateKey('2026-09-28');
    expect(d, DateTime(2026, 9, 28));
    expect(d.isUtc, isFalse);
    for (var day = DateTime(2028, 1, 1); day.year == 2028; day = addDays(day, 1)) {
      expect(dateKey(parseDateKey(dateKey(day))), dateKey(day));
    }
  });

  test('parseDateKey rejects malformed keys and impossible dates', () {
    for (final bad in ['', '2026-9-28', '2026/09/28', '28-09-2026', '2026-09-28T00:00', '2026-02-30', '2026-13-01']) {
      expect(() => parseDateKey(bad), throwsFormatException, reason: bad);
    }
  });

  test('addDays crosses month, year and leap-day boundaries', () {
    expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
    expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    expect(addDays(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29));
    expect(addDays(DateTime(2026, 9, 28, 18, 30), 3), DateTime(2026, 10, 1));
  });

  test('addDays never skips or repeats a day (daylight-saving safe)', () {
    final start = DateTime(2026, 1, 1);
    for (var i = -400; i <= 400; i++) {
      expect(dayNumberOf(addDays(start, i)), dayNumberOf(start) + i, reason: '$i');
    }
  });

  test('dayNumberOf counts whole days since 1970-01-01 and ignores the time', () {
    expect(dayNumberOf(DateTime(1970, 1, 1)), 0);
    expect(dayNumberOf(DateTime(1970, 1, 2, 23, 59)), 1);
    expect(dayNumberOf(DateTime(2026, 1, 1)), 20454);
    expect(dayNumberOf(DateTime(2026, 9, 28)), 20724);
    expect(dayNumberOf(DateTime(2026, 9, 28, 23, 59)), 20724);
    expect(dayNumberOf(DateTime.utc(2026, 9, 28)), 20724);
  });

  test('startOfWeek is the Sunday on or before the date', () {
    expect(startOfWeek(DateTime(2026, 9, 27)), DateTime(2026, 9, 27)); // Sunday
    expect(startOfWeek(DateTime(2026, 9, 28)), DateTime(2026, 9, 27)); // Monday
    expect(startOfWeek(DateTime(2026, 10, 1, 15)), DateTime(2026, 9, 27)); // Thursday
    expect(startOfWeek(DateTime(2026, 10, 3)), DateTime(2026, 9, 27)); // Saturday
    expect(startOfWeek(DateTime(2026, 10, 4)), DateTime(2026, 10, 4)); // next Sunday
    expect(startOfWeek(DateTime(2027, 1, 1)), DateTime(2026, 12, 27)); // across the year end
  });
}
```

- [x] **Step 2: Run the date tests to verify they fail**

Run: `flutter test test/core/dates_test.dart`
Expected: FAIL, `Error: Error when reading 'lib/core/dates.dart': The system cannot find the file specified`.

- [x] **Step 3: Implement the date helpers**

Create `lib/core/dates.dart` (pure Dart, no imports):

```dart
// Local calendar dates for chores. A chore belongs to a day, not a moment,
// so every date here is a local date at midnight or a "YYYY-MM-DD" key.

final _dateKeyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// The same local day at midnight.
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// [n] calendar days later (or earlier when negative), at local midnight.
/// Works on the date parts, so daylight-saving changes never skip or repeat a day.
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

String _two(int v) => v.toString().padLeft(2, '0');

/// "YYYY-MM-DD" for the local date of [d].
String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// Local midnight of a "YYYY-MM-DD" key. Throws [FormatException] for anything else.
DateTime parseDateKey(String key) {
  final match = _dateKeyPattern.firstMatch(key);
  if (match == null) throw FormatException('Not a YYYY-MM-DD date', key);
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw FormatException('No such date', key);
  }
  return date;
}

/// Whole days since 1970-01-01 for the local date of [d] (time of day ignored).
int dayNumberOf(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// The Sunday on or before [d], at local midnight. Weeks start on Sunday.
DateTime startOfWeek(DateTime d) => addDays(d, -(d.weekday % DateTime.daysPerWeek));
```

Notes: `addDays` builds the result from the date parts, so a daylight-saving change never skips or repeats a day; "days between two dates" is always computed as a difference of `dayNumberOf` values (UTC-based, so every day is exactly 86 400 000 ms).

- [x] **Step 4: Run the date tests to verify they pass**

Run: `flutter test test/core/dates_test.dart`
Expected: PASS, `+8: All tests passed!`

- [x] **Step 5: Write the failing chore tests**

Create `test/core/chores_test.dart`. It contains Review Focus #1 ("monthly on the 31st falls on the last day of short months") and Review Focus #3 ("editing the rule keeps past done records"). Calendar used throughout: 1 September 2026 is a Tuesday, the Sundays of September 2026 are the 6th, 13th, 20th and 27th, and 1 October 2026 (`testNow`) is a Thursday.

```dart
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/dates.dart';
import 'package:flutter_test/flutter_test.dart';

// September 2026: the 1st is a Tuesday; Sundays are 6, 13, 20, 27. 1 October is a Thursday.
DateTime d(String key) => parseDateKey(key);

Chore chore({
  String id = 'c1',
  String title = 'Chore',
  String? icon,
  String? assignee = 'u2',
  String? time,
  Repeat repeat = Repeat.daily,
  int every = 1,
  List<int> weekdays = const [],
  int? monthDay,
  String start = '2026-09-01',
  String? end,
  bool remind = false,
  String createdBy = 'u1',
}) =>
    Chore(
      id: id,
      title: title,
      icon: icon,
      assignee: assignee,
      time: time,
      repeat: repeat,
      every: every,
      weekdays: weekdays,
      monthDay: monthDay,
      startDate: start,
      endDate: end,
      remind: remind,
      createdBy: createdBy,
    );

ChoreDone doneOn(Chore c, String date, {String doneBy = 'u2', String? title}) => ChoreDone(
      choreId: c.id,
      date: date,
      choreTitle: title ?? c.title,
      assignee: c.assignee,
      doneBy: doneBy,
      doneByName: doneBy == 'u1' ? 'Dad' : 'Sara',
      doneAt: d(date).add(const Duration(hours: 8)),
      dayNumber: dayNumberOf(d(date)),
    );

/// The dates in [from]..[to] (inclusive) on which [c] occurs.
List<String> occurrences(Chore c, String from, String to) => [
      for (var day = d(from); !day.isAfter(d(to)); day = addDays(day, 1))
        if (occursOn(c, day)) dateKey(day),
    ];

List<String> ids(List<ChoreStatus> items) => [for (final s in items) s.chore.id];

void main() {
  group('occursOn', () {
    test('once occurs only on its date, whatever the time of day', () {
      final c = chore(repeat: Repeat.once, start: '2026-09-28');
      expect(occurrences(c, '2026-09-20', '2026-10-10'), ['2026-09-28']);
      expect(occursOn(c, DateTime(2026, 9, 28, 23, 59)), isTrue);
    });

    test('daily occurs every day from the start date', () {
      final c = chore(start: '2026-09-28');
      expect(occurrences(c, '2026-09-26', '2026-10-01'), ['2026-09-28', '2026-09-29', '2026-09-30', '2026-10-01']);
    });

    test('every 3 days counts from the start date', () {
      final c = chore(every: 3, start: '2026-09-29');
      expect(occurrences(c, '2026-09-25', '2026-10-10'), ['2026-09-29', '2026-10-02', '2026-10-05', '2026-10-08']);
    });

    test('every 2 days runs across a year end', () {
      final c = chore(every: 2, start: '2026-12-30');
      expect(occurrences(c, '2026-12-28', '2027-01-04'), ['2026-12-30', '2027-01-01', '2027-01-03']);
    });

    test('nothing before the start date; the end date is inclusive', () {
      final c = chore(start: '2026-09-28', end: '2026-09-30');
      expect(occurrences(c, '2026-09-25', '2026-10-05'), ['2026-09-28', '2026-09-29', '2026-09-30']);
    });

    test('an end date equal to the start date gives a single day', () {
      expect(occurrences(chore(start: '2026-09-28', end: '2026-09-28'), '2026-09-01', '2026-10-31'), ['2026-09-28']);
    });

    test('weekly occurs on the chosen weekdays only', () {
      final c = chore(repeat: Repeat.weekly, weekdays: [1, 4]); // Mon, Thu
      expect(occurrences(c, '2026-09-27', '2026-10-10'), ['2026-09-28', '2026-10-01', '2026-10-05', '2026-10-08']);
    });

    test('weekly Sun–Thu covers a whole school week', () {
      final c = chore(repeat: Repeat.weekly, weekdays: [7, 1, 2, 3, 4]);
      expect(
        occurrences(c, '2026-09-26', '2026-10-03'),
        ['2026-09-27', '2026-09-28', '2026-09-29', '2026-09-30', '2026-10-01'],
      );
    });

    test('every 2 weeks: weeks start on Sunday', () {
      // Starts Saturday 5 Sep; its week began Sunday 30 Aug. Sunday 6 Sep is already week 1 (off).
      final c = chore(repeat: Repeat.weekly, every: 2, weekdays: [6, 7], start: '2026-09-05');
      expect(occurrences(c, '2026-08-30', '2026-10-03'), ['2026-09-05', '2026-09-13', '2026-09-19', '2026-09-27', '2026-10-03']);
    });

    test('every 2 weeks counts from the week containing the start date', () {
      // Starts Wednesday 2 Sep: Monday 31 Aug is before the start, Monday 7 Sep is in week 1.
      final c = chore(repeat: Repeat.weekly, every: 2, weekdays: [1], start: '2026-09-02');
      expect(occurrences(c, '2026-08-30', '2026-10-04'), ['2026-09-14', '2026-09-28']);
    });

    test('every 3 weeks runs across a year end', () {
      final c = chore(repeat: Repeat.weekly, every: 3, weekdays: [5], start: '2026-12-18'); // Fridays
      expect(occurrences(c, '2026-12-01', '2027-02-10'), ['2026-12-18', '2027-01-08', '2027-01-29']);
    });

    test('weekly without weekdays never occurs', () {
      expect(occurrences(chore(repeat: Repeat.weekly), '2026-09-01', '2026-10-31'), isEmpty);
    });

    test('monthly occurs on its day of the month', () {
      final c = chore(repeat: Repeat.monthly, monthDay: 15);
      expect(occurrences(c, '2026-09-01', '2026-12-31'), ['2026-09-15', '2026-10-15', '2026-11-15', '2026-12-15']);
    });

    test('every 2 months counts from the start month; a day before the start is skipped', () {
      final c = chore(repeat: Repeat.monthly, every: 2, monthDay: 10, start: '2026-09-20');
      expect(occurrences(c, '2026-09-01', '2027-03-31'), ['2026-11-10', '2027-01-10', '2027-03-10']);
    });

    test('monthly on the 31st falls on the last day of short months', () {
      final c = chore(repeat: Repeat.monthly, monthDay: 31, start: '2026-01-01');
      expect(occurrences(c, '2026-01-01', '2026-12-31'), [
        '2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30', '2026-05-31', '2026-06-30',
        '2026-07-31', '2026-08-31', '2026-09-30', '2026-10-31', '2026-11-30', '2026-12-31',
      ]);
      // Leap year: 29 February, not the 28th; exactly once in the month.
      expect(occurrences(c, '2028-02-01', '2028-03-01'), ['2028-02-29']);
      // 30-day month: exactly once, on the 30th.
      expect(occurrences(c, '2026-04-01', '2026-04-30'), ['2026-04-30']);
      expect(occursOn(c, d('2026-04-29')), isFalse);
    });

    test('monthly on the 29th and 30th in February, leap and non-leap', () {
      final on29 = chore(repeat: Repeat.monthly, monthDay: 29, start: '2027-01-01');
      expect(occurrences(on29, '2027-02-01', '2027-03-31'), ['2027-02-28', '2027-03-29']);
      expect(occurrences(on29, '2028-02-01', '2028-02-29'), ['2028-02-29']);
      final on30 = chore(repeat: Repeat.monthly, monthDay: 30, start: '2027-01-01');
      expect(occurrences(on30, '2027-02-01', '2027-03-31'), ['2027-02-28', '2027-03-30']);
      expect(occurrences(on30, '2028-02-01', '2028-02-29'), ['2028-02-29']);
      expect(occurrences(on30, '2027-04-01', '2027-04-30'), ['2027-04-30']);
    });

    test('monthly stops after its end date', () {
      final c = chore(repeat: Repeat.monthly, monthDay: 1, start: '2026-09-01', end: '2026-11-01');
      expect(occurrences(c, '2026-09-01', '2027-01-31'), ['2026-09-01', '2026-10-01', '2026-11-01']);
    });

    test('monthly without a day never occurs', () {
      expect(occurrences(chore(repeat: Repeat.monthly), '2026-09-01', '2026-12-31'), isEmpty);
    });

    test('every below 1 is treated as 1; a malformed start date never occurs', () {
      expect(occurrences(chore(every: 0, start: '2026-09-28'), '2026-09-28', '2026-09-30'),
          ['2026-09-28', '2026-09-29', '2026-09-30']);
      expect(occursOn(chore(start: 'soon'), d('2026-09-28')), isFalse);
    });
  });

  group('Chore and ChoreDone', () {
    test('isAnyone when there is no assignee', () {
      expect(chore(assignee: null).isAnyone, isTrue);
      expect(chore(assignee: 'u2').isAnyone, isFalse);
    });

    test('Chore round-trips through toMap and fromMap', () {
      final c = chore(
        id: 'bins', title: 'Take out bins', icon: '🗑️', assignee: 'u1', time: '19:30',
        repeat: Repeat.weekly, every: 2, weekdays: [4, 1], start: '2026-09-01', end: '2027-06-30',
        remind: true, createdBy: 'u1',
      );
      final map = c.toMap();
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map['repeat'], 'weekly');
      final back = Chore.fromMap('bins', map);
      expect(back.id, 'bins');
      expect(back.title, 'Take out bins');
      expect(back.icon, '🗑️');
      expect(back.assignee, 'u1');
      expect(back.time, '19:30');
      expect(back.repeat, Repeat.weekly);
      expect(back.every, 2);
      expect(back.weekdays, [1, 4]);
      expect(back.monthDay, isNull);
      expect(back.startDate, '2026-09-01');
      expect(back.endDate, '2027-06-30');
      expect(back.remind, isTrue);
      expect(back.createdBy, 'u1');
    });

    test('toMap trims the title and clears fields that do not apply to the repeat', () {
      final map = chore(title: '  Make bed ', repeat: Repeat.daily, weekdays: [1], monthDay: 5).toMap();
      expect(map['title'], 'Make bed');
      expect(map['weekdays'], isEmpty);
      expect(map['monthDay'], isNull);
      expect(chore(repeat: Repeat.once, every: 3).toMap()['every'], 1);
      expect(chore(repeat: Repeat.monthly, monthDay: 31).toMap()['monthDay'], 31);
    });

    test('fromMap tolerates missing fields and Firestore number types', () {
      final c = Chore.fromMap('x', {'title': 'Tidy', 'startDate': '2026-09-01', 'every': 2.0, 'weekdays': [1.0, 3]});
      expect(c.repeat, Repeat.once);
      expect(c.every, 2);
      expect(c.weekdays, [1, 3]);
      expect(c.assignee, isNull);
      expect(c.remind, isFalse);
      expect(c.createdBy, '');
      expect(Chore.fromMap('y', {'repeat': 'fortnightly'}).repeat, Repeat.once);
    });

    test('copyWith changes given fields and can set nullable fields to null', () {
      final c = chore(icon: '🪥', assignee: 'u2', time: '07:00', repeat: Repeat.monthly, monthDay: 5, end: '2026-12-31');
      final same = c.copyWith();
      expect(same.icon, '🪥');
      expect(same.assignee, 'u2');
      expect(same.time, '07:00');
      expect(same.monthDay, 5);
      expect(same.endDate, '2026-12-31');

      final cleared = c.copyWith(icon: null, assignee: null, time: null, monthDay: null, endDate: null);
      expect(cleared.icon, isNull);
      expect(cleared.assignee, isNull);
      expect(cleared.isAnyone, isTrue);
      expect(cleared.time, isNull);
      expect(cleared.monthDay, isNull);
      expect(cleared.endDate, isNull);
      expect(cleared.title, c.title);

      final changed = c.copyWith(
        id: 'c2', title: 'New', icon: '🧹', assignee: 'u1', time: '08:15', repeat: Repeat.weekly,
        every: 3, weekdays: [2], monthDay: 7, startDate: '2026-10-01', endDate: '2027-01-01',
        remind: true, createdBy: 'u2',
      );
      expect(changed.id, 'c2');
      expect(changed.title, 'New');
      expect(changed.icon, '🧹');
      expect(changed.assignee, 'u1');
      expect(changed.time, '08:15');
      expect(changed.repeat, Repeat.weekly);
      expect(changed.every, 3);
      expect(changed.weekdays, [2]);
      expect(changed.monthDay, 7);
      expect(changed.startDate, '2026-10-01');
      expect(changed.endDate, '2027-01-01');
      expect(changed.remind, isTrue);
      expect(changed.createdBy, 'u2');
    });

    test('choreDoneId joins the chore id and the date', () {
      expect(choreDoneId('brush', '2026-09-30'), 'brush_2026-09-30');
    });

    test('ChoreDone round-trips and has the chore-and-date id', () {
      final at = DateTime(2026, 9, 30, 7, 5);
      final done = ChoreDone(
        choreId: 'brush', date: '2026-09-30', choreTitle: 'Brush teeth', assignee: 'u2',
        doneBy: 'u2', doneByName: 'Sara', doneAt: at, dayNumber: dayNumberOf(DateTime(2026, 9, 30)),
      );
      expect(done.id, 'brush_2026-09-30');
      final back = ChoreDone.fromMap(done.toMap());
      expect(back.id, 'brush_2026-09-30');
      expect(back.choreId, 'brush');
      expect(back.date, '2026-09-30');
      expect(back.choreTitle, 'Brush teeth');
      expect(back.assignee, 'u2');
      expect(back.doneBy, 'u2');
      expect(back.doneByName, 'Sara');
      expect(back.doneAt, at);
      expect(back.dayNumber, 20726);
      final anyone = ChoreDone.fromMap({...done.toMap(), 'assignee': null, 'doneAt': null});
      expect(anyone.assignee, isNull);
      expect(anyone.doneAt, isNull);
    });
  });

  group('choresForDay', () {
    final monday = d('2026-09-28');
    final chores = [
      chore(id: 'brush', title: 'Brush teeth', time: '07:00'),
      chore(id: 'bed', title: 'Make bed'),
      chore(id: 'wake', title: 'Wake up', time: '06:30'),
      chore(id: 'cat', title: 'Feed cat'),
      chore(id: 'plants', title: 'Water plants', assignee: null),
      chore(id: 'bins', title: 'Take out bins', assignee: 'u1', repeat: Repeat.weekly, weekdays: [1]),
      chore(id: 'old', title: 'Old chore', assignee: 'u9'),
      chore(id: 'party', title: 'Party prep', repeat: Repeat.once, start: '2026-09-27'),
      chore(id: 'swim', title: 'Swim', assignee: 'u1', repeat: Repeat.weekly, weekdays: [3]),
    ];

    test('groups by member, anyone and former members; only chores of that day', () {
      final view = choresForDay(chores: chores, done: const [], memberUids: {'u1', 'u2'}, day: monday);
      expect(view.byMember.keys.toSet(), {'u1', 'u2'});
      expect(ids(view.byMember['u2']!), ['wake', 'brush', 'cat', 'bed']);
      expect(ids(view.byMember['u1']!), ['bins']);
      expect(ids(view.anyone), ['plants']);
      expect(ids(view.formerMember), ['old']);
    });

    test('every member has an entry, even without chores', () {
      final view = choresForDay(chores: chores, done: const [], memberUids: {'u1', 'u2', 'u3'}, day: monday);
      expect(view.byMember['u3'], isEmpty);
      final empty = choresForDay(chores: const [], done: const [], memberUids: {'u1'}, day: monday);
      expect(empty.byMember, {'u1': isEmpty});
      expect(empty.anyone, isEmpty);
      expect(empty.formerMember, isEmpty);
    });

    test('timed chores first by time, then untimed by title; ties by title', () {
      final list = [
        chore(id: 'b', title: 'Beta', time: '08:00'),
        chore(id: 'a', title: 'alpha', time: '08:00'),
        chore(id: 'z', title: 'Zebra', time: '06:05'),
        chore(id: 'n2', title: 'نوم'),
        chore(id: 'n1', title: 'apple'),
      ];
      final en = choresForDay(chores: list, done: const [], memberUids: {'u2'}, day: monday);
      expect(ids(en.byMember['u2']!), ['z', 'a', 'b', 'n1', 'n2']);
      final ar = choresForDay(chores: list, done: const [], memberUids: {'u2'}, day: monday, languageCode: 'ar');
      expect(ids(ar.byMember['u2']!), ['z', 'a', 'b', 'n2', 'n1']);
    });

    test('done status comes from the record for that day only', () {
      final brush = chores.first;
      final bed = chores[1];
      final done = [doneOn(brush, '2026-09-28'), doneOn(bed, '2026-09-27')];
      final u2 = choresForDay(chores: chores, done: done, memberUids: {'u1', 'u2'}, day: monday).byMember['u2']!;
      final brushStatus = u2.firstWhere((s) => s.chore.id == 'brush');
      expect(brushStatus.isDone, isTrue);
      expect(brushStatus.done!.doneBy, 'u2');
      expect(u2.firstWhere((s) => s.chore.id == 'bed').isDone, isFalse);
      expect(progressOf(u2), (done: 1, total: 4));
    });

    test('a done record whose chore was deleted still shows on its day with its copied title', () {
      final gone = chore(id: 'gone', title: 'Old title');
      final done = [doneOn(gone, '2026-09-27')];
      final sunday = choresForDay(chores: const [], done: done, memberUids: {'u2'}, day: d('2026-09-27'));
      final status = sunday.byMember['u2']!.single;
      expect(status.chore.id, 'gone');
      expect(status.chore.title, 'Old title');
      expect(status.isDone, isTrue);
      expect(choresForDay(chores: const [], done: done, memberUids: {'u2'}, day: monday).byMember['u2'], isEmpty);
    });

    test('editing the rule keeps past done records', () {
      final before = chore(id: 'brush', title: 'Brush teeth', repeat: Repeat.daily, start: '2026-09-01');
      final done = [doneOn(before, '2026-09-26'), doneOn(before, '2026-09-27')];
      final after = before.copyWith(title: 'Brush teeth well', repeat: Repeat.weekly, weekdays: [1]);

      // Today (Monday) follows the new rule and has no record yet.
      final today = choresForDay(chores: [after], done: done, memberUids: {'u2'}, day: monday).byMember['u2']!;
      expect(today.single.chore.title, 'Brush teeth well');
      expect(today.single.isDone, isFalse);
      // Tuesday no longer has it.
      expect(choresForDay(chores: [after], done: done, memberUids: {'u2'}, day: d('2026-09-29')).byMember['u2'], isEmpty);
      // Past days that no longer match the rule still show their done records, with the copied title.
      for (final day in ['2026-09-26', '2026-09-27']) {
        final past = choresForDay(chores: [after], done: done, memberUids: {'u2'}, day: d(day)).byMember['u2']!;
        expect(past.single.chore.id, 'brush', reason: day);
        expect(past.single.isDone, isTrue, reason: day);
        expect(past.single.done!.choreTitle, 'Brush teeth', reason: day);
      }
      // The records themselves are untouched.
      expect(done.map((x) => x.choreTitle), everyElement('Brush teeth'));
      expect(done.map((x) => x.date), ['2026-09-26', '2026-09-27']);
    });
  });

  group('progressOf', () {
    test('counts done over total', () {
      final a = chore(id: 'a');
      final b = chore(id: 'b');
      final c = chore(id: 'c');
      expect(progressOf(const []), (done: 0, total: 0));
      expect(
        progressOf([
          ChoreStatus(a, doneOn(a, '2026-09-28')),
          ChoreStatus(b, null),
          ChoreStatus(c, doneOn(c, '2026-09-28')),
        ]),
        (done: 2, total: 3),
      );
    });
  });

  group('lateChores', () {
    final today = d('2026-10-01'); // Thursday

    List<String> lateOf(List<Chore> chores, [List<ChoreDone> done = const [], int lookBackDays = 60]) => [
          for (final l in lateChores(chores: chores, done: done, today: today, lookBackDays: lookBackDays))
            '${l.chore.id}@${l.date}',
        ];

    test('a missed one-time chore stays late until done', () {
      final blinds = chore(id: 'blinds', repeat: Repeat.once, start: '2026-09-28');
      expect(lateOf([blinds]), ['blinds@2026-09-28']);
      expect(lateOf([blinds], [doneOn(blinds, '2026-09-28')]), isEmpty);
    });

    test('one-time chores for today or later are not late', () {
      expect(lateOf([
        chore(id: 'a', repeat: Repeat.once, start: '2026-10-01'),
        chore(id: 'b', repeat: Repeat.once, start: '2026-10-05'),
      ]), isEmpty);
    });

    test('a repeating anyone chore is late only for its most recent missed occurrence', () {
      final daily = chore(id: 'daily', assignee: null, start: '2026-09-20');
      final plants = chore(id: 'plants', assignee: null, repeat: Repeat.weekly, weekdays: [6]); // Saturdays
      expect(lateOf([daily, plants]), ['plants@2026-09-26', 'daily@2026-09-30']);
    });

    test('a done record on the most recent occurrence clears earlier misses', () {
      final daily = chore(id: 'daily', assignee: null, start: '2026-09-20');
      expect(lateOf([daily], [doneOn(daily, '2026-09-30')]), isEmpty);
    });

    test('done later (up to and including today) suppresses the miss', () {
      final daily = chore(id: 'daily', assignee: null, start: '2026-09-20');
      expect(lateOf([daily], [doneOn(daily, '2026-10-01')]), isEmpty);
      // A record after today does not count.
      expect(lateOf([daily], [doneOn(daily, '2026-10-02')]), ['daily@2026-09-30']);
    });

    test('never lists a repeating chore that has an assignee', () {
      expect(lateOf([
        chore(id: 'brush', assignee: 'u2'),
        chore(id: 'bins', assignee: 'u1', repeat: Repeat.weekly, weekdays: [1]),
        chore(id: 'rent', assignee: 'u1', repeat: Repeat.monthly, monthDay: 1, start: '2026-01-01'),
      ]), isEmpty);
    });

    test('the look-back window limits how far back', () {
      final at60 = chore(id: 'a', repeat: Repeat.once, start: dateKey(addDays(today, -60)));
      final at61 = chore(id: 'b', repeat: Repeat.once, start: dateKey(addDays(today, -61)));
      expect(lateOf([at60, at61]), ['a@2026-08-02']);
      final at8 = chore(id: 'c', repeat: Repeat.once, start: dateKey(addDays(today, -8)));
      expect(lateOf([at8], const [], 7), isEmpty);
      expect(lateOf([at8], const [], 8), ['c@2026-09-23']);
    });

    test('an anyone chore that has not started yet is not late', () {
      expect(lateOf([chore(id: 'x', assignee: null, start: '2026-10-05')]), isEmpty);
    });

    test('sorted by date, then title', () {
      final result = lateOf([
        chore(id: 'y', title: 'Beta', repeat: Repeat.once, start: '2026-09-28'),
        chore(id: 'daily', title: 'Anything', assignee: null, start: '2026-09-20'),
        chore(id: 'x', title: 'alpha', repeat: Repeat.once, start: '2026-09-28'),
        chore(id: 'z', title: 'Zed', repeat: Repeat.once, start: '2026-09-25'),
      ]);
      expect(result, ['z@2026-09-25', 'x@2026-09-28', 'y@2026-09-28', 'daily@2026-09-30']);
    });
  });

  group('canToggle', () {
    final today = d('2026-10-01');
    final mine = chore(assignee: 'u2');
    final anyone = chore(assignee: null);
    final dads = chore(assignee: 'u1');

    bool child(Chore c, String day) => canToggle(chore: c, isParent: false, me: 'u2', day: d(day), today: today);

    test('parents can toggle any chore on any day', () {
      for (final c in [mine, anyone, dads]) {
        for (final day in ['2026-09-01', '2026-09-30', '2026-10-01', '2026-10-10']) {
          expect(canToggle(chore: c, isParent: true, me: 'u1', day: d(day), today: today), isTrue);
        }
      }
    });

    test('children toggle their own chores today and yesterday only', () {
      expect(child(mine, '2026-10-01'), isTrue);
      expect(child(mine, '2026-09-30'), isTrue);
      expect(child(mine, '2026-09-29'), isFalse);
      expect(child(mine, '2026-10-02'), isFalse);
    });

    test('children toggle anyone chores today and yesterday only', () {
      expect(child(anyone, '2026-10-01'), isTrue);
      expect(child(anyone, '2026-09-30'), isTrue);
      expect(child(anyone, '2026-09-20'), isFalse);
      expect(child(anyone, '2026-10-02'), isFalse);
    });

    test("children never toggle someone else's chore", () {
      expect(child(dads, '2026-10-01'), isFalse);
      expect(child(dads, '2026-09-30'), isFalse);
    });

    test('the time of day does not matter', () {
      expect(canToggle(chore: mine, isParent: false, me: 'u2', day: DateTime(2026, 9, 30, 23, 59), today: DateTime(2026, 10, 1, 0, 5)), isTrue);
      expect(canToggle(chore: mine, isParent: false, me: 'u2', day: DateTime(2026, 9, 29, 23, 59), today: DateTime(2026, 10, 1, 0, 5)), isFalse);
    });
  });

  group('validateChore', () {
    test('a good chore has no problems', () {
      expect(validateChore(chore(title: 'Brush teeth')), isEmpty);
      expect(validateChore(chore(repeat: Repeat.weekly, weekdays: [1])), isEmpty);
      expect(validateChore(chore(repeat: Repeat.monthly, monthDay: 31)), isEmpty);
      expect(validateChore(chore(start: '2026-09-28', end: '2026-09-28')), isEmpty);
    });

    test('blank titles are refused', () {
      expect(validateChore(chore(title: '')), {ChoreProblem.blankTitle});
      expect(validateChore(chore(title: '   ')), {ChoreProblem.blankTitle});
    });

    test('titles longer than 80 characters after trimming are refused', () {
      expect(validateChore(chore(title: 'a' * 80)), isEmpty);
      expect(validateChore(chore(title: '  ${'a' * 80}  ')), isEmpty);
      expect(validateChore(chore(title: 'ب' * 80)), isEmpty);
      expect(validateChore(chore(title: 'a' * 81)), {ChoreProblem.titleTooLong});
    });

    test('weekly needs at least one weekday', () {
      expect(validateChore(chore(repeat: Repeat.weekly)), {ChoreProblem.weeklyNoDays});
      expect(validateChore(chore(repeat: Repeat.weekly, weekdays: [0, 8])), {ChoreProblem.weeklyNoDays});
      expect(validateChore(chore(repeat: Repeat.daily)), isEmpty);
    });

    test('monthly needs a day between 1 and 31', () {
      expect(validateChore(chore(repeat: Repeat.monthly)), {ChoreProblem.badMonthDay});
      expect(validateChore(chore(repeat: Repeat.monthly, monthDay: 0)), {ChoreProblem.badMonthDay});
      expect(validateChore(chore(repeat: Repeat.monthly, monthDay: 32)), {ChoreProblem.badMonthDay});
      expect(validateChore(chore(repeat: Repeat.monthly, monthDay: 1)), isEmpty);
    });

    test('the end date cannot be before the start date', () {
      expect(validateChore(chore(start: '2026-09-28', end: '2026-09-27')), {ChoreProblem.endBeforeStart});
    });

    test('several problems are reported together', () {
      expect(
        validateChore(chore(title: ' ', repeat: Repeat.weekly, start: '2026-09-28', end: '2026-01-01')),
        {ChoreProblem.blankTitle, ChoreProblem.weeklyNoDays, ChoreProblem.endBeforeStart},
      );
    });
  });
}
```

- [x] **Step 6: Run the chore tests to verify they fail**

Run: `flutter test test/core/chores_test.dart`
Expected: FAIL, `Error: Error when reading 'lib/core/chores.dart': The system cannot find the file specified`.

- [x] **Step 7: Implement the chore logic**

Create `lib/core/chores.dart` (pure Dart: imports only `dart:math` and other `lib/core` files):

```dart
import 'dart:math';

import 'dates.dart';
import 'models.dart';
import 'text.dart';

enum Repeat { once, daily, weekly, monthly }

const maxChoreTitleLength = 80;

/// Lets [Chore.copyWith] tell "not given" apart from "set to null".
const Object _unset = Object();

class Chore {
  const Chore({
    required this.id,
    required this.title,
    this.icon,
    this.assignee,
    this.time,
    this.repeat = Repeat.once,
    this.every = 1,
    this.weekdays = const [],
    this.monthDay,
    required this.startDate,
    this.endDate,
    this.remind = false,
    required this.createdBy,
  });

  final String id;
  final String title;

  /// A single emoji, or null.
  final String? icon;

  /// Member uid, or null for an "anyone" chore.
  final String? assignee;

  /// "HH:mm", or null for no time.
  final String? time;
  final Repeat repeat;

  /// Repeat every N days, weeks or months (1 for once).
  final int every;

  /// 1 = Monday … 7 = Sunday; used by weekly chores only.
  final List<int> weekdays;

  /// 1–31; used by monthly chores only.
  final int? monthDay;

  /// "YYYY-MM-DD"; for a one-time chore, its date.
  final String startDate;

  /// "YYYY-MM-DD" (inclusive), or null for never.
  final String? endDate;
  final bool remind;
  final String createdBy;

  bool get isAnyone => assignee == null;

  factory Chore.fromMap(String id, Map<String, dynamic> m) => Chore(
        id: id,
        title: m['title'] as String? ?? '',
        icon: m['icon'] as String?,
        assignee: m['assignee'] as String?,
        time: m['time'] as String?,
        repeat: Repeat.values.asNameMap()[m['repeat']] ?? Repeat.once,
        every: readInt(m['every']) ?? 1,
        weekdays: [for (final w in (m['weekdays'] as List?) ?? const []) (w as num).toInt()],
        monthDay: readInt(m['monthDay']),
        startDate: m['startDate'] as String? ?? '',
        endDate: m['endDate'] as String?,
        remind: m['remind'] == true,
        createdBy: m['createdBy'] as String? ?? '',
      );

  /// Every field except [id] (and never `createdAt`). The title is trimmed, and
  /// fields that don't apply to the repeat are cleared, as the data model requires.
  Map<String, dynamic> toMap() => {
        'title': title.trim(),
        'icon': icon,
        'assignee': assignee,
        'time': time,
        'repeat': repeat.name,
        'every': repeat == Repeat.once ? 1 : every,
        'weekdays': repeat == Repeat.weekly ? (weekdays.toSet().toList()..sort()) : <int>[],
        'monthDay': repeat == Repeat.monthly ? monthDay : null,
        'startDate': startDate,
        'endDate': endDate,
        'remind': remind,
        'createdBy': createdBy,
      };

  Chore copyWith({
    String? id,
    String? title,
    Object? icon = _unset,
    Object? assignee = _unset,
    Object? time = _unset,
    Repeat? repeat,
    int? every,
    List<int>? weekdays,
    Object? monthDay = _unset,
    String? startDate,
    Object? endDate = _unset,
    bool? remind,
    String? createdBy,
  }) =>
      Chore(
        id: id ?? this.id,
        title: title ?? this.title,
        icon: identical(icon, _unset) ? this.icon : icon as String?,
        assignee: identical(assignee, _unset) ? this.assignee : assignee as String?,
        time: identical(time, _unset) ? this.time : time as String?,
        repeat: repeat ?? this.repeat,
        every: every ?? this.every,
        weekdays: weekdays ?? this.weekdays,
        monthDay: identical(monthDay, _unset) ? this.monthDay : monthDay as int?,
        startDate: startDate ?? this.startDate,
        endDate: identical(endDate, _unset) ? this.endDate : endDate as String?,
        remind: remind ?? this.remind,
        createdBy: createdBy ?? this.createdBy,
      );
}

String choreDoneId(String choreId, String date) => '${choreId}_$date';

/// One chore done on one day. Keeps its own copy of the title and assignee,
/// so history survives edits and deletes.
class ChoreDone {
  const ChoreDone({
    required this.choreId,
    required this.date,
    required this.choreTitle,
    this.assignee,
    required this.doneBy,
    required this.doneByName,
    this.doneAt,
    required this.dayNumber,
  });

  final String choreId;

  /// "YYYY-MM-DD" of the day the chore was for (not when it was ticked).
  final String date;
  final String choreTitle;
  final String? assignee;
  final String doneBy;
  final String doneByName;
  final DateTime? doneAt;

  /// [dayNumberOf] the [date]; lets the security rules check "today or yesterday".
  final int dayNumber;

  String get id => choreDoneId(choreId, date);

  factory ChoreDone.fromMap(Map<String, dynamic> m) => ChoreDone(
        choreId: m['choreId'] as String? ?? '',
        date: m['date'] as String? ?? '',
        choreTitle: m['choreTitle'] as String? ?? '',
        assignee: m['assignee'] as String?,
        doneBy: m['doneBy'] as String? ?? '',
        doneByName: m['doneByName'] as String? ?? '',
        doneAt: readDate(m['doneAt']),
        dayNumber: readInt(m['dayNumber']) ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'choreId': choreId,
        'date': date,
        'choreTitle': choreTitle,
        'assignee': assignee,
        'doneBy': doneBy,
        'doneByName': doneByName,
        'doneAt': doneAt,
        'dayNumber': dayNumber,
      };
}

DateTime? _tryParseDateKey(String? key) {
  if (key == null) return null;
  try {
    return parseDateKey(key);
  } on FormatException {
    return null;
  }
}

int _daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Whether chore [c] falls on the local calendar day of [day].
bool occursOn(Chore c, DateTime day) {
  final start = _tryParseDateKey(c.startDate);
  if (start == null) return false;
  final d = dayNumberOf(day);
  final s = dayNumberOf(start);
  if (d < s) return false;
  final end = _tryParseDateKey(c.endDate);
  if (end != null && d > dayNumberOf(end)) return false;
  final every = max(1, c.every);
  switch (c.repeat) {
    case Repeat.once:
      return d == s;
    case Repeat.daily:
      return (d - s) % every == 0;
    case Repeat.weekly:
      if (!c.weekdays.contains(day.weekday)) return false;
      final weeks = (dayNumberOf(startOfWeek(day)) - dayNumberOf(startOfWeek(start))) ~/ DateTime.daysPerWeek;
      return weeks % every == 0;
    case Repeat.monthly:
      final monthDay = c.monthDay;
      if (monthDay == null || monthDay < 1) return false;
      final months = (day.year - start.year) * 12 + day.month - start.month;
      if (months % every != 0) return false;
      return day.day == min(monthDay, _daysInMonth(day.year, day.month));
  }
}

class ChoreStatus {
  const ChoreStatus(this.chore, this.done);
  final Chore chore;
  final ChoreDone? done;
  bool get isDone => done != null;
}

class DayView {
  const DayView({required this.byMember, required this.anyone, required this.formerMember});

  /// One entry (possibly empty) for every current member uid.
  final Map<String, List<ChoreStatus>> byMember;
  final List<ChoreStatus> anyone;

  /// Chores assigned to someone who is no longer a member.
  final List<ChoreStatus> formerMember;
}

int _compareStatus(ChoreStatus a, ChoreStatus b, String languageCode) {
  final ta = a.chore.time;
  final tb = b.chore.time;
  if (ta != null && tb == null) return -1;
  if (ta == null && tb != null) return 1;
  if (ta != null && tb != null) {
    final byTime = ta.compareTo(tb);
    if (byTime != 0) return byTime;
  }
  final byTitle = compareNames(a.chore.title, b.chore.title, languageCode);
  return byTitle != 0 ? byTitle : a.chore.id.compareTo(b.chore.id);
}

/// The chores of [day], grouped by person, with done status.
///
/// Also lists that day's done records whose chore no longer occurs on it (the
/// rule was edited) or no longer exists (deleted, shown with the record's copied
/// title), so past days keep their history.
DayView choresForDay({
  required List<Chore> chores,
  required List<ChoreDone> done,
  required Set<String> memberUids,
  required DateTime day,
  String languageCode = 'en',
}) {
  final key = dateKey(day);
  final doneToday = {for (final d in done) if (d.date == key) d.choreId: d};
  final byId = {for (final c in chores) c.id: c};
  final byMember = {for (final uid in memberUids) uid: <ChoreStatus>[]};
  final anyone = <ChoreStatus>[];
  final former = <ChoreStatus>[];

  void place(ChoreStatus status) {
    final assignee = status.chore.assignee;
    if (assignee == null) {
      anyone.add(status);
    } else if (byMember.containsKey(assignee)) {
      byMember[assignee]!.add(status);
    } else {
      former.add(status);
    }
  }

  final shown = <String>{};
  for (final c in chores) {
    if (!occursOn(c, day)) continue;
    shown.add(c.id);
    place(ChoreStatus(c, doneToday[c.id]));
  }
  for (final record in doneToday.values) {
    if (shown.contains(record.choreId)) continue;
    final chore = byId[record.choreId] ??
        Chore(
          id: record.choreId,
          title: record.choreTitle,
          assignee: record.assignee,
          startDate: record.date,
          createdBy: record.doneBy,
        );
    place(ChoreStatus(chore, record));
  }

  int compare(ChoreStatus a, ChoreStatus b) => _compareStatus(a, b, languageCode);
  for (final list in byMember.values) {
    list.sort(compare);
  }
  anyone.sort(compare);
  former.sort(compare);
  return DayView(byMember: byMember, anyone: anyone, formerMember: former);
}

class LateChore {
  const LateChore(this.chore, this.date);
  final Chore chore;
  final String date;
}

/// One-time and "anyone" chores whose most recent occurrence before [today]
/// (within [lookBackDays]) was missed, and that nobody has done since.
List<LateChore> lateChores({
  required List<Chore> chores,
  required List<ChoreDone> done,
  required DateTime today,
  int lookBackDays = 60,
  String languageCode = 'en',
}) {
  final todayKey = dateKey(today);
  final doneDates = <String, Set<String>>{};
  for (final d in done) {
    doneDates.putIfAbsent(d.choreId, () => <String>{}).add(d.date);
  }
  final result = <LateChore>[];
  for (final c in chores) {
    if (c.repeat != Repeat.once && !c.isAnyone) continue;
    final dates = doneDates[c.id] ?? const <String>{};
    for (var back = 1; back <= lookBackDays; back++) {
      final day = addDays(today, -back);
      if (!occursOn(c, day)) continue;
      final key = dateKey(day);
      final doneSince = dates.any((x) => x.compareTo(key) >= 0 && x.compareTo(todayKey) <= 0);
      if (!doneSince) result.add(LateChore(c, key));
      break;
    }
  }
  result.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byTitle = compareNames(a.chore.title, b.chore.title, languageCode);
    return byTitle != 0 ? byTitle : a.chore.id.compareTo(b.chore.id);
  });
  return result;
}

({int done, int total}) progressOf(List<ChoreStatus> items) =>
    (done: items.where((s) => s.isDone).length, total: items.length);

/// Parents may tick or untick anything. Children only their own and "anyone"
/// chores, and only for today or yesterday.
bool canToggle({
  required Chore chore,
  required bool isParent,
  required String me,
  required DateTime day,
  required DateTime today,
}) {
  if (isParent) return true;
  if (chore.assignee != me && !chore.isAnyone) return false;
  final daysAgo = dayNumberOf(today) - dayNumberOf(day);
  return daysAgo == 0 || daysAgo == 1;
}

enum ChoreProblem { blankTitle, titleTooLong, weeklyNoDays, badMonthDay, endBeforeStart }

Set<ChoreProblem> validateChore(Chore c) {
  final problems = <ChoreProblem>{};
  final title = c.title.trim();
  if (title.isEmpty) {
    problems.add(ChoreProblem.blankTitle);
  } else if (title.length > maxChoreTitleLength) {
    problems.add(ChoreProblem.titleTooLong);
  }
  if (c.repeat == Repeat.weekly && !c.weekdays.any((w) => w >= 1 && w <= 7)) {
    problems.add(ChoreProblem.weeklyNoDays);
  }
  final monthDay = c.monthDay;
  if (c.repeat == Repeat.monthly && (monthDay == null || monthDay < 1 || monthDay > 31)) {
    problems.add(ChoreProblem.badMonthDay);
  }
  final end = c.endDate;
  if (end != null && end.compareTo(c.startDate) < 0) {
    problems.add(ChoreProblem.endBeforeStart);
  }
  return problems;
}
```

Behaviour notes the later tasks rely on:
- `choresForDay` and `lateChores` take an extra optional `languageCode` (default `'en'`) because `compareNames` needs one; pass `Localizations.localeOf(context).languageCode` from the UI (see INTERFACE ISSUES).
- `choresForDay` also shows that day's done records whose chore no longer occurs on it: if the chore still exists (its rule was edited) the current `Chore` is used; if it was deleted, a stand-in one-time `Chore` is built from the record (`id` = `choreId`, `title` = the copied `choreTitle`, `assignee` = the record's assignee, `createdBy` = `doneBy`). This is spec §9 ("a done record whose chore is gone still shows in past days using its copied title") and Review Focus #3.
- `Chore.toMap` trims the title (so the rules' 1–80 check matches `validateChore`) and clears fields that don't apply to the repeat (`weekdays` empty unless weekly, `monthDay` null unless monthly, `every` 1 for once), as in the spec's data model.
- `validateChore` counts the title in UTF-16 code units (`String.length`); the Firestore rules' `size()` accepted 80 Arabic letters and 40 emoji in the emulator, so a title that passes `validateChore` always passes the rules.

- [x] **Step 8: Run the core tests to verify they pass**

Run: `flutter test test/core`
Expected: PASS, `All tests passed!` (`dates_test.dart` 8 tests, `chores_test.dart` 54 tests, plus the existing core tests).

- [x] **Step 9: Full checks**

Run: `flutter analyze --no-fatal-infos`
Expected: no errors and no warnings (only the infos that were there before this task).

Run: `flutter test`
Expected: PASS, `All tests passed!`

- [x] **Step 10: Commit**

```bash
git add lib/core/dates.dart lib/core/chores.dart test/core/dates_test.dart test/core/chores_test.dart
git commit -m "feat(core): chore repeat rules, day view, late chores and validation" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Chore data — rules, repository, providers

**Files:**
- Create: `lib/data/chore_repository.dart`, `test/data/chore_repository_test.dart`
- Modify: `firestore.rules`, `rules-tests/test/rules.test.js`, `lib/app/providers.dart`, `test/support/seed.dart` (add `seedChores(db)`)

**Interfaces:**
- Consumes: everything in `lib/core/chores.dart` and `lib/core/dates.dart` (Task 4); `firestoreProvider`, `clockProvider`, `familyIdProvider` (existing; use the same `_requireFamily` pattern).
- Produces:
  - `class ChoreRepository { ChoreRepository(this._db, this.familyId); final String familyId; Stream<List<Chore>> watchChores(); Stream<List<ChoreDone>> watchDone({required String fromDate, required String toDate}); Future<String> addChore(Chore chore); Future<void> updateChore(Chore chore); Future<void> deleteChore(String choreId); Future<void> tick({required Chore chore, required String date, required String doneBy, required String doneByName, DateTime? now}); Future<void> untick({required String choreId, required String date}); }`
    - paths: `families/{familyId}/chores/{choreId}`, `families/{familyId}/choreDone/{choreId}_{date}`
    - `addChore` creates a new doc id, writes `chore.toMap()` plus `createdAt`, returns the id; `updateChore` writes `toMap()` with `SetOptions(merge: true)`; `watchDone` queries `date >= fromDate` and `date <= toDate`.
    - `tick` sets the done doc with `ChoreDone(..., choreTitle: chore.title, assignee: chore.assignee, doneAt: now ?? DateTime.now(), dayNumber: dayNumberOf(parseDateKey(date)))`.
  - `final choreRepositoryProvider = Provider<ChoreRepository>`
  - `final todayProvider = NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);` — `TodayNotifier extends Notifier<DateTime>`: `build()` returns `dayOnly(ref.watch(clockProvider)())` and arms one `Timer` for the next local midnight + 1 s that updates `state` and re-arms; `ref.onDispose` cancels it. (Changed 2026-09-29: the wall tablet runs across midnight.)
  - `final choresProvider = StreamProvider<List<Chore>>`
  - `final choreDoneProvider = StreamProvider.family<List<ChoreDone>, ({String from, String to})>`
  - `Future<void> seedChores(FakeFirebaseFirestore db)` in `test/support/seed.dart`: chores in family `f1`: `brush` (Brush teeth 🪥, assignee u2, daily, time 07:00, start 2026-09-01, remind true), `bins` (Take out bins, assignee u1, weekly [1,4], start 2026-09-01), `plants` (Water plants, anyone, weekly [6], start 2026-09-01), `blinds` (Order blinds, anyone, once, start 2026-09-28); one done record `brush_2026-09-30` by u2.
  - Rules:
    - `chores/{c}`: read members; create parent, or child with `assignee == uid() && createdBy == uid()`; update parent, or child where old and new `createdBy == assignee == uid()`; delete parent, or child where `createdBy == assignee == uid()`; on create/update require `title` string of size 1–80 and `repeat in ['once','daily','weekly','monthly']`.
    - `choreDone/{d}`: read members; no update; create: `d == choreId + '_' + date`, `dayNumber is int`, and either `isParent(f)`, or member with `doneBy == uid()`, the chore (`get` of `chores/{choreId}`) has `assignee == uid()` or `assignee == null`, and `dayNumber` within `[utcDay - 2, utcDay + 1]` where `utcDay = math.floor(request.time.toMillis() / 86400000)`; delete: `isParent(f)`, or `resource.data.doneBy == uid()` with the same window on `resource.data.dayNumber`.
  - Rules tests include Review Focus #2 ("child ticks today or yesterday only (timezone-safe window)"): ticks with `dayNumber` = today, yesterday, and today+1 succeed; today−3 fails; child cannot tick another member's chore or record `doneBy` as someone else; parent can tick for anyone on any day; mismatched document id fails; child creates own chore, cannot create one for someone else, cannot edit a parent's chore; blank title fails.

- [x] **Step 1: Write the failing rules tests**

Append to the end of `rules-tests/test/rules.test.js` (after the last `describe('users', …)` block; the existing imports already include everything used here). It contains Review Focus #2 ("child ticks today or yesterday only (timezone-safe window)"). Each test computes `utcDay = Math.floor(Date.now() / 86400000)`, the same day number the rules compute from `request.time`, and `dateOf(n)` gives the matching `"YYYY-MM-DD"`.

```js
const DAY_MS = 86400000;
const dateOf = (dayNumber) => new Date(dayNumber * DAY_MS).toISOString().slice(0, 10);
const chore = (fields) => ({
  title: 'Chore', icon: null, assignee: 'kid', time: null, repeat: 'daily', every: 1,
  weekdays: [], monthDay: null, startDate: '2026-09-01', endDate: null, remind: false,
  createdBy: 'dad', ...fields,
});
const tick = (choreId, dayNumber, doneBy, fields = {}) => ({
  choreId, date: dateOf(dayNumber), choreTitle: 'Chore', assignee: null,
  doneBy, doneByName: doneBy, doneAt: Timestamp.now(), dayNumber, ...fields,
});
const doneRef = (db, choreId, dayNumber) => doc(db, `families/${F}/choreDone/${choreId}_${dateOf(dayNumber)}`);

describe('chores', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `families/${F}/chores/bins`), chore({ title: 'Bins', assignee: 'dad' }));
      await setDoc(doc(db, `families/${F}/chores/brush`), chore({ title: 'Brush teeth' }));
      await setDoc(doc(db, `families/${F}/chores/kidOwn`), chore({ title: 'Read', createdBy: 'kid' }));
    });
  });

  it('members read chores; outsiders cannot', async () => {
    await assertSucceeds(getDocs(collection(as('kid'), `families/${F}/chores`)));
    await assertFails(getDoc(doc(as('stranger'), `families/${F}/chores/bins`)));
  });
  it('parents create chores for anyone', async () => {
    await assertSucceeds(setDoc(doc(as('dad'), `families/${F}/chores/c1`), chore({ assignee: 'kid' })));
    await assertSucceeds(setDoc(doc(as('dad'), `families/${F}/chores/c2`), chore({ assignee: null })));
    await assertSucceeds(setDoc(doc(as('dad'), `families/${F}/chores/c3`), chore({ assignee: 'dad', repeat: 'weekly', weekdays: [1, 4] })));
  });
  it('a child creates their own chore but not one for someone else', async () => {
    await assertSucceeds(setDoc(doc(as('kid'), `families/${F}/chores/c1`), chore({ createdBy: 'kid' })));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/chores/c2`), chore({ assignee: 'dad', createdBy: 'kid' })));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/chores/c3`), chore({ assignee: null, createdBy: 'kid' })));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/chores/c4`), chore({ assignee: 'kid', createdBy: 'dad' })));
  });
  it('outsiders cannot create chores, even "their own"', async () => {
    await assertFails(setDoc(doc(as('stranger'), `families/${F}/chores/c1`), chore({ assignee: 'stranger', createdBy: 'stranger' })));
  });
  it("a child cannot edit or delete a parent's chore, even one assigned to them", async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/chores/brush`), { title: 'No thanks' }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/chores/bins`), { title: 'Mine now' }));
    await assertFails(deleteDoc(doc(as('kid'), `families/${F}/chores/brush`)));
  });
  it('a child edits and deletes their own chore but cannot hand it to someone else', async () => {
    await assertSucceeds(updateDoc(doc(as('kid'), `families/${F}/chores/kidOwn`), { title: 'Read a book', repeat: 'weekly', weekdays: [6] }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/chores/kidOwn`), { assignee: 'dad' }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/chores/kidOwn`), { assignee: null }));
    await assertSucceeds(deleteDoc(doc(as('kid'), `families/${F}/chores/kidOwn`)));
  });
  it('parents edit and delete any chore', async () => {
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/chores/kidOwn`), { assignee: null }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/chores/brush`), { title: 'Brush teeth well', repeat: 'weekly', weekdays: [1] }));
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/chores/bins`)));
  });
  it('titles must be 1 to 80 characters', async () => {
    const db = as('dad');
    await assertFails(setDoc(doc(db, `families/${F}/chores/c1`), chore({ title: '' })));
    await assertFails(setDoc(doc(db, `families/${F}/chores/c2`), chore({ title: 'a'.repeat(81) })));
    await assertFails(setDoc(doc(db, `families/${F}/chores/c3`), chore({ title: 42 })));
    await assertSucceeds(setDoc(doc(db, `families/${F}/chores/c4`), chore({ title: 'a'.repeat(80) })));
    await assertFails(updateDoc(doc(db, `families/${F}/chores/brush`), { title: '' }));
  });
  it('80-character Arabic and emoji titles are accepted', async () => {
    const db = as('dad');
    await assertSucceeds(setDoc(doc(db, `families/${F}/chores/c1`), chore({ title: 'ب'.repeat(80) })));
    await assertSucceeds(setDoc(doc(db, `families/${F}/chores/c2`), chore({ title: '🪥'.repeat(40) })));
  });
  it('repeat and every are validated', async () => {
    const db = as('dad');
    await assertFails(setDoc(doc(db, `families/${F}/chores/c1`), chore({ repeat: 'hourly' })));
    await assertFails(setDoc(doc(db, `families/${F}/chores/c2`), chore({ every: 0 })));
    await assertFails(setDoc(doc(db, `families/${F}/chores/c3`), chore({ every: 1.5 })));
    await assertFails(updateDoc(doc(db, `families/${F}/chores/brush`), { repeat: 'yearly' }));
  });
});

describe('chore done records', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `families/${F}/chores/bins`), chore({ title: 'Bins', assignee: 'dad' }));
      await setDoc(doc(db, `families/${F}/chores/brush`), chore({ title: 'Brush teeth' }));
      await setDoc(doc(db, `families/${F}/chores/plants`), chore({ title: 'Water plants', assignee: null }));
    });
  });

  it('child ticks today or yesterday only (timezone-safe window)', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    const db = as('kid');
    // Local "today" and "yesterday" can be one day either side of the UTC day
    // (phones ahead of or behind UTC, an offline tick synced after midnight).
    for (const n of [utcDay + 1, utcDay, utcDay - 1, utcDay - 2]) {
      await assertSucceeds(setDoc(doneRef(db, 'brush', n), tick('brush', n, 'kid')));
    }
    await assertFails(setDoc(doneRef(db, 'brush', utcDay - 3), tick('brush', utcDay - 3, 'kid')));
    await assertFails(setDoc(doneRef(db, 'brush', utcDay + 2), tick('brush', utcDay + 2, 'kid')));
  });
  it("a child ticks their own and anyone chores, not someone else's", async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    const db = as('kid');
    await assertSucceeds(setDoc(doneRef(db, 'plants', utcDay), tick('plants', utcDay, 'kid')));
    await assertFails(setDoc(doneRef(db, 'bins', utcDay), tick('bins', utcDay, 'kid')));
  });
  it('a child cannot record someone else as the doer', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    await assertFails(setDoc(doneRef(as('kid'), 'brush', utcDay), tick('brush', utcDay, 'dad')));
    await assertFails(setDoc(doneRef(as('kid'), 'plants', utcDay), tick('plants', utcDay, 'dad')));
  });
  it('a child cannot tick a chore that does not exist', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    await assertFails(setDoc(doneRef(as('kid'), 'ghost', utcDay), tick('ghost', utcDay, 'kid')));
  });
  it('parents tick for anyone on any day', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    const db = as('dad');
    await assertSucceeds(setDoc(doneRef(db, 'brush', utcDay - 30), tick('brush', utcDay - 30, 'kid')));
    await assertSucceeds(setDoc(doneRef(db, 'plants', utcDay + 5), tick('plants', utcDay + 5, 'kid')));
    await assertSucceeds(setDoc(doneRef(db, 'bins', utcDay), tick('bins', utcDay, 'dad')));
  });
  it('the document id must be the chore id and the date', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    for (const uid of ['kid', 'dad']) {
      const db = as(uid);
      await assertFails(setDoc(doc(db, `families/${F}/choreDone/brush_2020-01-01`), tick('brush', utcDay, 'kid')));
      await assertFails(setDoc(doc(db, `families/${F}/choreDone/whatever`), tick('brush', utcDay, 'kid')));
      await assertFails(setDoc(doneRef(db, 'plants', utcDay), tick('brush', utcDay, 'kid')));
    }
  });
  it('the date must match the day number', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    const old = dateOf(utcDay - 10);
    await assertFails(setDoc(doc(as('kid'), `families/${F}/choreDone/brush_${old}`), tick('brush', utcDay, 'kid', { date: old })));
    await assertFails(setDoc(doc(as('dad'), `families/${F}/choreDone/brush_${old}`), tick('brush', utcDay, 'kid', { date: old })));
    await assertFails(setDoc(doneRef(as('dad'), 'brush', utcDay), tick('brush', utcDay, 'kid', { dayNumber: String(utcDay) })));
  });
  it('done records are never updated', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    await setDoc(doneRef(as('kid'), 'brush', utcDay), tick('brush', utcDay, 'kid'));
    await assertFails(setDoc(doneRef(as('kid'), 'brush', utcDay), tick('brush', utcDay, 'kid')));
    await assertFails(updateDoc(doneRef(as('dad'), 'brush', utcDay), { doneBy: 'dad' }));
  });
  it('a child unticks only their own record, today or yesterday', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doneRef(db, 'brush', utcDay), tick('brush', utcDay, 'kid'));
      await setDoc(doneRef(db, 'brush', utcDay - 3), tick('brush', utcDay - 3, 'kid'));
      await setDoc(doneRef(db, 'plants', utcDay), tick('plants', utcDay, 'dad'));
    });
    await assertSucceeds(deleteDoc(doneRef(as('kid'), 'brush', utcDay)));
    await assertFails(deleteDoc(doneRef(as('kid'), 'brush', utcDay - 3)));
    await assertFails(deleteDoc(doneRef(as('kid'), 'plants', utcDay)));
    await assertSucceeds(deleteDoc(doneRef(as('dad'), 'brush', utcDay - 3)));
    await assertSucceeds(deleteDoc(doneRef(as('dad'), 'plants', utcDay)));
  });
  it('members read done records; outsiders cannot', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    await setDoc(doneRef(as('kid'), 'brush', utcDay), tick('brush', utcDay, 'kid'));
    await assertSucceeds(getDocs(collection(as('dad'), `families/${F}/choreDone`)));
    await assertFails(getDoc(doneRef(as('stranger'), 'brush', utcDay)));
    await assertFails(setDoc(doneRef(as('stranger'), 'plants', utcDay), tick('plants', utcDay, 'stranger')));
  });
});
```

- [x] **Step 2: Run the rules tests to verify they fail**

Run (Git Bash; the emulator needs Java):

```bash
export JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
export PATH="/c/Program Files/Android/Android Studio/jbr/bin:$PATH"
cd rules-tests && npm run emulate
```

Expected: FAIL, `41 passing`, `13 failing` (every new test that expects a write or read to succeed is refused, because there are no rules for `chores` or `choreDone` yet).

- [x] **Step 3: Write the rules**

In `firestore.rules`, insert the two blocks below inside `match /families/{f} { … }`, directly after the closing `}` of `match /purchases/{p} { … }` and before the `}` that closes `match /families/{f}`. Nothing else in the file changes. The end of the file then reads:

```
      match /purchases/{p} {
        …unchanged…
      }

      match /chores/{c} { …new, below… }

      match /choreDone/{d} { …new, below… }
    }
  }
}
```

The new text:

```
      match /chores/{c} {
        function isOwnChore(data) {
          return data.createdBy == uid() && data.assignee == uid();
        }
        function validChore() {
          let d = request.resource.data;
          return d.title is string && d.title.size() >= 1 && d.title.size() <= 80
            && d.repeat in ['once', 'daily', 'weekly', 'monthly']
            && d.every is int && d.every >= 1
            && d.startDate is string
            && d.createdBy is string;
        }
        allow read: if isMember(f);
        allow create: if validChore() && (
          isParent(f) || (isMember(f) && isOwnChore(request.resource.data))
        );
        allow update: if validChore() && (
          isParent(f) || (isMember(f) && isOwnChore(resource.data) && isOwnChore(request.resource.data))
        );
        allow delete: if isParent(f) || (isMember(f) && isOwnChore(resource.data));
      }

      match /choreDone/{d} {
        // Days since 1970-01-01 in UTC. A phone's local date can be one day
        // either side of it; one more day back is the offline grace for yesterday.
        function inTickWindow(n) {
          let utcDay = math.floor(request.time.toMillis() / 86400000);
          return n is int && n >= utcDay - 2 && n <= utcDay + 1;
        }
        // The "YYYY-MM-DD" date must be the calendar day of dayNumber.
        function dateIsDay(date, n) {
          let t = timestamp.value(n * 86400000);
          return date.matches('[0-9]{4}-[0-9]{2}-[0-9]{2}')
            && int(date[0:4]) == t.year() && int(date[5:7]) == t.month() && int(date[8:10]) == t.day();
        }
        function choreAssignee(choreId) {
          return get(/databases/$(database)/documents/families/$(f)/chores/$(choreId)).data.get('assignee', null);
        }
        allow read: if isMember(f);
        allow create: if isMember(f)
          && request.resource.data.choreId is string
          && request.resource.data.date is string
          && d == request.resource.data.choreId + '_' + request.resource.data.date
          && request.resource.data.dayNumber is int
          && dateIsDay(request.resource.data.date, request.resource.data.dayNumber)
          && (isParent(f) || (
            request.resource.data.doneBy == uid()
            && choreAssignee(request.resource.data.choreId) in [uid(), null]
            && inTickWindow(request.resource.data.dayNumber)
          ));
        allow update: if false;
        allow delete: if isParent(f) || (
          isMember(f) && resource.data.doneBy == uid() && inTickWindow(resource.data.dayNumber)
        );
      }
```

How the tick window works: `utcDay` is the UTC day of the server time. A phone's local date is at most one day either side of it (ahead of UTC just after local midnight, behind UTC late in the evening), and a child may also tick yesterday, so the accepted `dayNumber` range is `utcDay - 2 … utcDay + 1`. An offline tick at 23:50 that syncs after midnight is accepted in any timezone; a tick for three days ago is refused. `dateIsDay` ties the `date` string (and so the document id) to `dayNumber`, so a child can't pair today's `dayNumber` with an old date.

- [x] **Step 4: Run the rules tests to verify they pass**

Run: `cd rules-tests && npm run emulate` (with `JAVA_HOME` and `PATH` set as in Step 2)
Expected: PASS, `54 passing`, no failures. (The emulator also prints `PERMISSION_DENIED … evaluation error` lines for the refused writes; the Release 1 tests print the same kind of lines. Only the mocha summary matters.)

- [x] **Step 5: Write the failing repository tests**

In `test/support/seed.dart`, add these imports next to the existing ones:

```dart
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/dates.dart';
```

and append at the end of the file:

```dart
/// Chores for family f1 (u1 Dad parent, u2 Sara child). On testNow
/// (Thursday 2026-10-01): brush and bins are due today; blinds (28 Sep) and
/// plants (Saturday 26 Sep) are late; brush was done on 30 Sep.
Future<void> seedChores(FakeFirebaseFirestore db) async {
  const chores = [
    Chore(
      id: 'brush', title: 'Brush teeth', icon: '🪥', assignee: 'u2', time: '07:00',
      repeat: Repeat.daily, startDate: '2026-09-01', remind: true, createdBy: 'u1',
    ),
    Chore(
      id: 'bins', title: 'Take out bins', assignee: 'u1',
      repeat: Repeat.weekly, weekdays: [1, 4], startDate: '2026-09-01', createdBy: 'u1',
    ),
    Chore(
      id: 'plants', title: 'Water plants',
      repeat: Repeat.weekly, weekdays: [6], startDate: '2026-09-01', createdBy: 'u1',
    ),
    Chore(id: 'blinds', title: 'Order blinds', startDate: '2026-09-28', createdBy: 'u1'),
  ];
  for (final c in chores) {
    await db.doc('families/f1/chores/${c.id}').set({...c.toMap(), 'createdAt': DateTime(2026, 9, 1)});
  }
  final done = ChoreDone(
    choreId: 'brush', date: '2026-09-30', choreTitle: 'Brush teeth', assignee: 'u2',
    doneBy: 'u2', doneByName: 'Sara', doneAt: DateTime(2026, 9, 30, 7, 5),
    dayNumber: dayNumberOf(DateTime(2026, 9, 30)),
  );
  await db.doc('families/f1/choreDone/${done.id}').set(done.toMap());
}
```

Create `test/data/chore_repository_test.dart`. The last group tests `todayProvider` with `testWidgets`, which runs in fake time (`tester.pump(duration)` fires due timers) and fails any test that leaves a timer pending, so no extra package is needed:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/providers.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/dates.dart';
import 'package:family_app/data/chore_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/seed.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ChoreRepository repo;

  setUp(() async {
    db = await seedFamily();
    await seedChores(db);
    repo = ChoreRepository(db, 'f1');
  });

  Future<Chore> choreById(String id) async => (await repo.watchChores().first).firstWhere((c) => c.id == id);

  Future<List<ChoreDone>> doneIn(String from, String to) => repo.watchDone(fromDate: from, toDate: to).first;

  test('watchChores reads the seeded chores', () async {
    final chores = await repo.watchChores().first;
    expect(chores.map((c) => c.id).toSet(), {'brush', 'bins', 'plants', 'blinds'});
    final brush = chores.firstWhere((c) => c.id == 'brush');
    expect(brush.title, 'Brush teeth');
    expect(brush.icon, '🪥');
    expect(brush.assignee, 'u2');
    expect(brush.time, '07:00');
    expect(brush.repeat, Repeat.daily);
    expect(brush.remind, isTrue);
    final bins = chores.firstWhere((c) => c.id == 'bins');
    expect(bins.weekdays, [1, 4]);
    expect(chores.firstWhere((c) => c.id == 'plants').isAnyone, isTrue);
    expect(chores.firstWhere((c) => c.id == 'blinds').repeat, Repeat.once);
  });

  test('addChore writes the chore with createdAt and returns the new id', () async {
    const chore = Chore(
      id: '', title: ' Feed cat ', icon: '🐱', assignee: 'u2', time: '18:00',
      repeat: Repeat.monthly, every: 2, monthDay: 31, startDate: '2026-10-01',
      endDate: '2027-06-30', remind: true, createdBy: 'u2',
    );
    final id = await repo.addChore(chore);
    expect(id, isNotEmpty);
    final raw = (await db.doc('families/f1/chores/$id').get()).data()!;
    expect(raw['createdAt'], isNotNull);
    expect(raw['title'], 'Feed cat');
    expect(raw['repeat'], 'monthly');
    final back = await choreById(id);
    expect(back.title, 'Feed cat');
    expect(back.icon, '🐱');
    expect(back.assignee, 'u2');
    expect(back.time, '18:00');
    expect(back.every, 2);
    expect(back.monthDay, 31);
    expect(back.startDate, '2026-10-01');
    expect(back.endDate, '2027-06-30');
    expect(back.remind, isTrue);
    expect(back.createdBy, 'u2');
  });

  test('updateChore rewrites the rule, can clear fields and keeps createdAt', () async {
    final brush = await choreById('brush');
    await repo.updateChore(brush.copyWith(
      title: 'Brush teeth well', icon: null, time: null, repeat: Repeat.weekly, weekdays: [1, 3],
      assignee: null, remind: false,
    ));
    final back = await choreById('brush');
    expect(back.title, 'Brush teeth well');
    expect(back.icon, isNull);
    expect(back.time, isNull);
    expect(back.isAnyone, isTrue);
    expect(back.repeat, Repeat.weekly);
    expect(back.weekdays, [1, 3]);
    expect(back.remind, isFalse);
    expect(back.startDate, '2026-09-01');
    final raw = (await db.doc('families/f1/chores/brush').get()).data()!;
    expect(raw['createdAt'], isNotNull);
  });

  test('deleteChore removes the chore but keeps its done records', () async {
    await repo.deleteChore('brush');
    expect((await repo.watchChores().first).map((c) => c.id), isNot(contains('brush')));
    final done = await doneIn('2026-09-01', '2026-10-31');
    expect(done.single.choreId, 'brush');
    expect(done.single.choreTitle, 'Brush teeth');
  });

  test('tick writes a record with copied title, assignee and day number', () async {
    final at = DateTime(2026, 10, 1, 7, 10);
    await repo.tick(chore: await choreById('brush'), date: '2026-10-01', doneBy: 'u2', doneByName: 'Sara', now: at);
    final raw = (await db.doc('families/f1/choreDone/brush_2026-10-01').get()).data()!;
    final record = ChoreDone.fromMap(raw);
    expect(record.id, 'brush_2026-10-01');
    expect(record.choreId, 'brush');
    expect(record.date, '2026-10-01');
    expect(record.choreTitle, 'Brush teeth');
    expect(record.assignee, 'u2');
    expect(record.doneBy, 'u2');
    expect(record.doneByName, 'Sara');
    expect(record.doneAt, at);
    expect(record.dayNumber, dayNumberOf(DateTime(2026, 10, 1)));
    expect(raw['dayNumber'], isA<int>());
  });

  test('an anyone chore records who did it and no assignee', () async {
    await repo.tick(chore: await choreById('plants'), date: '2026-09-26', doneBy: 'u1', doneByName: 'Dad');
    final record = (await doneIn('2026-09-26', '2026-09-26')).single;
    expect(record.assignee, isNull);
    expect(record.doneBy, 'u1');
    expect(record.doneAt, isNotNull);
  });

  test('ticking twice gives one record; untick deletes it', () async {
    final brush = await choreById('brush');
    await repo.tick(chore: brush, date: '2026-10-01', doneBy: 'u2', doneByName: 'Sara');
    await repo.tick(chore: brush, date: '2026-10-01', doneBy: 'u1', doneByName: 'Dad');
    expect((await doneIn('2026-10-01', '2026-10-01')).length, 1);
    await repo.untick(choreId: 'brush', date: '2026-10-01');
    expect(await doneIn('2026-10-01', '2026-10-01'), isEmpty);
    expect((await doneIn('2026-09-30', '2026-09-30')).single.id, 'brush_2026-09-30');
  });

  test('watchDone returns only records dated within the range, both ends included', () async {
    final brush = await choreById('brush');
    for (final date in ['2026-09-27', '2026-09-28', '2026-10-01', '2026-10-02']) {
      await repo.tick(chore: brush, date: date, doneBy: 'u2', doneByName: 'Sara');
    }
    final inRange = await doneIn('2026-09-28', '2026-10-01');
    expect(inRange.map((d) => d.date).toSet(), {'2026-09-28', '2026-09-30', '2026-10-01'});
  });

  test('editing a chore keeps past done records and their copied titles', () async {
    final brush = await choreById('brush');
    await repo.tick(chore: brush, date: '2026-09-29', doneBy: 'u2', doneByName: 'Sara');
    await repo.updateChore(brush.copyWith(title: 'Floss', repeat: Repeat.weekly, weekdays: [1]));
    final done = await doneIn('2026-09-01', '2026-10-31');
    expect(done.map((d) => d.date).toSet(), {'2026-09-29', '2026-09-30'});
    expect(done.map((d) => d.choreTitle), everyElement('Brush teeth'));
  });

  test('providers expose chores, done records and today', () async {
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      currentUidProvider.overrideWithValue('u1'),
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 1, 12)),
    ]);
    addTearDown(container.dispose);
    await container.read(appUserProvider.future);
    expect(container.read(todayProvider), DateTime(2026, 10, 1));
    expect(container.read(choreRepositoryProvider).familyId, 'f1');
    final chores = await container.read(choresProvider.future);
    expect(chores.length, 4);
    final done = await container.read(choreDoneProvider((from: '2026-09-30', to: '2026-10-01')).future);
    expect(done.single.id, 'brush_2026-09-30');
    expect(await container.read(choreDoneProvider((from: '2026-10-01', to: '2026-10-07')).future), isEmpty);
  });

  group('todayProvider', () {
    // testWidgets runs in fake time: tester.pump(duration) fires due timers, and the
    // test fails if any timer is still pending when it ends.
    testWidgets('is the local date and moves on just after local midnight', (tester) async {
      var now = DateTime(2026, 10, 1, 23, 59, 30);
      final container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => now)]);
      final seen = <DateTime>[];
      container.listen<DateTime>(todayProvider, (_, next) => seen.add(next));
      expect(container.read(todayProvider), DateTime(2026, 10, 1));

      await tester.pump(const Duration(seconds: 30)); // 00:00:00, timer not due yet
      expect(container.read(todayProvider), DateTime(2026, 10, 1));

      now = DateTime(2026, 10, 2, 0, 0, 1);
      await tester.pump(const Duration(seconds: 1)); // midnight + 1 s
      expect(container.read(todayProvider), DateTime(2026, 10, 2));

      now = DateTime(2026, 10, 3, 0, 0, 1);
      await tester.pump(const Duration(days: 1)); // the next timer was scheduled
      expect(container.read(todayProvider), DateTime(2026, 10, 3));
      expect(seen, [DateTime(2026, 10, 2), DateTime(2026, 10, 3)]);

      container.dispose();
    });

    testWidgets('disposing cancels the midnight timer', (tester) async {
      final container = ProviderContainer(overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 1, 12)),
      ]);
      expect(container.read(todayProvider), DateTime(2026, 10, 1));
      container.dispose();
      // No pending timer may remain: testWidgets fails the test otherwise.
      await tester.pump(const Duration(days: 2));
    });
  });
}
```

- [x] **Step 6: Run the repository tests to verify they fail**

Run: `flutter test test/data/chore_repository_test.dart`
Expected: FAIL, `Error: Error when reading 'lib/data/chore_repository.dart': The system cannot find the file specified`.

- [x] **Step 7: Implement the repository and providers**

Create `lib/data/chore_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/chores.dart';
import '../core/dates.dart';

class ChoreRepository {
  ChoreRepository(this._db, this.familyId);

  final FirebaseFirestore _db;
  final String familyId;

  DocumentReference<Map<String, dynamic>> get _family => _db.collection('families').doc(familyId);
  CollectionReference<Map<String, dynamic>> get _chores => _family.collection('chores');
  CollectionReference<Map<String, dynamic>> get _done => _family.collection('choreDone');

  Stream<List<Chore>> watchChores() =>
      _chores.snapshots().map((q) => [for (final d in q.docs) Chore.fromMap(d.id, d.data())]);

  /// Done records whose `date` is between [fromDate] and [toDate], both "YYYY-MM-DD" and inclusive.
  Stream<List<ChoreDone>> watchDone({required String fromDate, required String toDate}) => _done
      .where('date', isGreaterThanOrEqualTo: fromDate)
      .where('date', isLessThanOrEqualTo: toDate)
      .snapshots()
      .map((q) => [for (final d in q.docs) ChoreDone.fromMap(d.data())]);

  /// Creates the chore under a new id and returns that id. `chore.id` is ignored.
  Future<String> addChore(Chore chore) async {
    final ref = _chores.doc();
    await ref.set({...chore.toMap(), 'createdAt': DateTime.now()});
    return ref.id;
  }

  /// Rewrites the chore's fields; `createdAt` and any unknown fields are kept.
  Future<void> updateChore(Chore chore) =>
      _chores.doc(chore.id).set(chore.toMap(), SetOptions(merge: true));

  /// Deletes the chore only. Its done records stay as history.
  Future<void> deleteChore(String choreId) => _chores.doc(choreId).delete();

  /// Marks [chore] done for [date] ("YYYY-MM-DD"). Ticking the same chore and
  /// date twice, from any phone, gives one record.
  Future<void> tick({
    required Chore chore,
    required String date,
    required String doneBy,
    required String doneByName,
    DateTime? now,
  }) {
    final record = ChoreDone(
      choreId: chore.id,
      date: date,
      choreTitle: chore.title,
      assignee: chore.assignee,
      doneBy: doneBy,
      doneByName: doneByName,
      doneAt: now ?? DateTime.now(),
      dayNumber: dayNumberOf(parseDateKey(date)),
    );
    return _done.doc(record.id).set(record.toMap());
  }

  Future<void> untick({required String choreId, required String date}) =>
      _done.doc(choreDoneId(choreId, date)).delete();
}
```

In `lib/app/providers.dart`, add `import 'dart:async';` (for `Timer`) as the first import, followed by a blank line, and add these next to the existing relative imports (keep them sorted):

```dart
import '../core/chores.dart';
import '../core/dates.dart';
import '../data/chore_repository.dart';
```

Then insert this block directly after the `purchasesProvider` declaration:

```dart
// Chores.
final choreRepositoryProvider = Provider<ChoreRepository>(
  (ref) => ChoreRepository(ref.watch(firestoreProvider), _requireFamily(ref)),
);

/// Today's local date at midnight. It moves on by itself just after local
/// midnight, so a screen left open (the wall tablet) never shows yesterday as today.
final todayProvider = NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);

class TodayNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    _scheduleNextDay(clock);
    return dayOnly(clock());
  }

  /// One timer at a time, due 1 s after the next local midnight.
  void _scheduleNextDay(DateTime Function() clock) {
    _timer?.cancel();
    final now = clock();
    final next = addDays(dayOnly(now), 1).add(const Duration(seconds: 1));
    _timer = Timer(next.difference(now), () {
      final today = dayOnly(clock());
      if (today != state) state = today;
      _scheduleNextDay(clock);
    });
  }
}

final choresProvider = StreamProvider<List<Chore>>(
  (ref) => ref.watch(choreRepositoryProvider).watchChores(),
);

/// Done records with `date` in `from`..`to` ("YYYY-MM-DD", inclusive).
final choreDoneProvider = StreamProvider.family<List<ChoreDone>, ({String from, String to})>(
  (ref, range) => ref.watch(choreRepositoryProvider).watchDone(fromDate: range.from, toDate: range.to),
);
```

`todayProvider` is a `Notifier` rather than a plain `Provider` so that a screen left open for days (the wall tablet) moves to the new day by itself: one `Timer` is always pending for 1 s after the next local midnight, the callback sets the new day (only if it changed) and schedules the next one, and `ref.onDispose` cancels it. Widget tests are unaffected: `ProviderScope` disposes the container when the tree is torn down, which cancels the timer before Flutter's pending-timer check.

- [x] **Step 8: Run the repository tests to verify they pass**

Run: `flutter test test/data`
Expected: PASS, `All tests passed!` (`chore_repository_test.dart` 12 tests, plus the existing data tests).

- [x] **Step 9: Full checks**

Run: `flutter analyze --no-fatal-infos`
Expected: no errors and no warnings.

Run: `flutter test`
Expected: PASS, `All tests passed!`

Run: `cd rules-tests && npm run emulate` (with `JAVA_HOME` and `PATH` set as in Step 2)
Expected: PASS, `54 passing` (plus any rules tests added by Task 3, which must still pass).

- [x] **Step 10: Commit**

```bash
git add firestore.rules rules-tests/test/rules.test.js lib/data/chore_repository.dart lib/app/providers.dart test/support/seed.dart test/data/chore_repository_test.dart
git commit -m "feat(data): chore repository, providers and security rules" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

#### Drafting notes (writer B): interface issues resolved at merge

1. **`compareNames` needs a language code; `choresForDay` and `lateChores` have none.** `compareNames(a, b, languageCode)` sorts the UI language's script first. I added an optional named parameter `String languageCode = 'en'` to both functions. Existing call shapes still compile; Tasks 6, 8 and 9 should pass `Localizations.localeOf(context).languageCode` so Arabic titles sort first in Arabic.
2. **Past done records must stay visible (spec §9, Review Focus #3), but the interface says `choresForDay` lists only "chores occurring on `day`".** Without more, a past day whose rule was edited, or whose chore was deleted, would look empty although the record exists. `choresForDay` therefore also places that day's orphaned done records (see Task 4 Step 7 notes). No signature change. Consequence for Task 6: a deleted chore's stand-in (its id is not in `choresProvider`) should not open the chore sheet on long-press, or saving would re-create it as a one-time chore. Suggested check: only allow editing when `chores.any((c) => c.id == status.chore.id)`.
3. **`fireAndForget(repo.addChore(chore))` breaks when the write fails.** `addChore` returns `Future<String>`, and `fireAndForget`'s `catchError((Object error) { … })` handler returns null. Verified in a test: a failing `Future<String>` passed to `fireAndForget` logs the error and then throws an uncaught `ArgumentError: The error handler of Future.catchError must return a value of the future's type`. Fix either in Task 6 (`fireAndForget(repo.addChore(chore).then((_) {}))`) or once in `lib/data/write.dart`: `write.then<void>((_) {}, onError: (Object error) { debugPrint('Firestore write failed: $error'); });`.
4. **The rules are a little stricter than the interface text** (all satisfied by `Chore.toMap`/`ChoreRepository`): chores also require `every is int && every >= 1`, `startDate is string` and `createdBy is string`; `choreDone` creates also require `choreId` and `date` to be strings and `date` to be the calendar day of `dayNumber` (closes a hole where a child could send today's `dayNumber` with an old date and id).
5. **`Chore.toMap` normalises** (trims `title`; `weekdays` empty unless weekly; `monthDay` null unless monthly; `every` 1 for once). This follows the spec's data model; a round trip of, say, a daily chore carrying weekdays drops them.
6. **`todayProvider` changed at the orchestrator's request (2026-09-29)** from `Provider<DateTime>` to `NotifierProvider<TodayNotifier, DateTime>` with a midnight timer; the Task 5 Interfaces block above (copied from the amended interfaces file) shows the new declaration. Consumers are unchanged. Residual note: Dart timers follow the monotonic clock, so on a phone in deep sleep the midnight timer can fire late (it then sets the correct day when it does). If that matters for Today on phones, Task 8 could also `ref.invalidate(todayProvider)` on app resume.

---

### Task 6: Chores tab (phone layout), chore cards and the chore sheet

**Files:**
- Create: `lib/features/chores/chores_screen.dart`, `lib/features/chores/chore_card.dart`, `lib/features/chores/chore_groups.dart`, `lib/features/chores/repeat_label.dart`, `lib/features/chores/chore_sheet.dart`, `test/features/chores_screen_test.dart`, `test/features/chore_sheet_test.dart`
- Modify: `lib/app/app.dart` (Chores tab at index 1: Today · Chores · Lists · Family, icon `Icons.task_alt`), both ARB files, `lib/data/write.dart` (`fireAndForget` fix), `test/app/home_shell_test.dart` (four tabs)
- Test (extra): `test/data/write_test.dart`

**Interfaces:**
- Consumes: Tasks 1–5 (`context.tokens`, `personColor`, `AppCard`, `EmptyState`, `MemberAvatar`, `memberColorsProvider`, `Member.pictureTiles`, `choresProvider`, `choreDoneProvider`, `todayProvider`, `choreRepositoryProvider`, `choresForDay`, `progressOf`, `canToggle`, `validateChore`, `dateKey`, `addDays`); `membersProvider`, `isParentProvider`, `currentUidProvider`, `fireAndForget`, `confirm` (existing).
- Produces:
  - `class ChoreGroup { const ChoreGroup({required this.id, required this.items, this.member, this.isAnyone = false, this.isFormer = false}); final String id; final Member? member; final List<ChoreStatus> items; final bool isAnyone; final bool isFormer; }` — `id` is the member uid, `'anyone'` or `'former'`.
  - `List<ChoreGroup> buildChoreGroups({required DayView view, required List<Member> members, required String me, required bool isParent, required bool onlyMe})` — order: me first, then parents, then children (each by name); then Anyone (if non-empty or not onlyMe); Former only for parents and only if non-empty. With `onlyMe`: my group plus Anyone.
  - `String repeatLabel(AppLocalizations l, Chore c)` — "Once · 28 Sep", "Daily", "Every 2 days", "Sun–Thu", "Every 2 weeks · Mon, Thu", "Monthly · day 15", with "until 30 Jun" appended when `endDate` is set.
  - `class ChoreCard extends StatelessWidget { const ChoreCard({super.key, required this.status, required this.color, required this.pictureTile, required this.onToggle, this.onLongPress, this.late = false}); final ChoreStatus status; final PersonColor color; final bool pictureTile; final VoidCallback? onToggle; final VoidCallback? onLongPress; final bool late; }` — key `ValueKey('chore-<choreId>')`; tick button `ValueKey('tick-<choreId>')` (disabled look when `onToggle == null`); done → filled `color.fill` with `onFill` text; not done → tinted `color.tint` with `onTint` text (playful style); `pictureTile` → big emoji tile (emoji `chore.icon ?? tileLetter(title)`), title max 2 lines, ellipsis.
  - `class ChoresScreen extends ConsumerStatefulWidget { const ChoresScreen({super.key}); }` — keys `Key('dayPrev')`, `Key('dayNext')`, `Key('dayLabel')` (tap → date picker; long label "Today" for today), `Key('choresScope')` (SegmentedButton everyone/me; children default me, parents default everyone), `Key('addChore')` FAB, sections `ValueKey('choreSection-<groupId>')` each with `MemberAvatar`, name and "✓ done/total". Tapping a tick calls `choreRepository.tick`/`untick` via `fireAndForget`, recording `doneBy`: the chore's assignee when a parent ticks someone's chore, otherwise me (Task 8 replaces this for "anyone" chores with a picker). `onToggle` is null when `canToggle` is false. Long-press opens `showChoreSheet` when I'm a parent or it's my own created chore. Empty day → `EmptyState` ("No chores today 🎉").
  - `Future<void> showChoreSheet(BuildContext context, {Chore? chore, required DateTime day})` — keys `choreTitle`, `choreEmoji`, `choreWho-<uid>`, `choreWho-anyone` (children only see themselves), `choreTime` (tap → time picker; clear button `choreTimeClear`), `choreRepeat-once|daily|weekly|monthly`, `choreEvery`, `choreWeekday-<1..7>`, `choreMonthDay`, `choreStart`, `choreEndNever` (switch), `choreEndDate`, `choreRemind` (switch), `choreSave`, `choreDelete`. Validation messages from `validateChore` shown inline; Save disabled-free: tapping Save with problems shows them and does not write. Save → `addChore`/`updateChore` via `fireAndForget`; Delete → `confirm` then `deleteChore` via `fireAndForget`. New chore defaults: assignee me for children and first child for parents, repeat daily, start = `day`, never ends.
  - New l10n keys: `tabChores`, `today`, `everyone`, `me`, `anyone`, `formerMember`, `noChoresToday`, `addChore`, `editChore`, `choreTitle`, `choreEmoji`, `who`, `time`, `noTime`, `repeat`, `repeatOnce`, `repeatDaily`, `repeatWeekly`, `repeatMonthly`, `every`, `everyNDays` (plural), `everyNWeeks` (plural), `onDays`, `dayOfMonth`, `monthlyOnDay` ({day}), `startDate`, `endDate`, `endsNever`, `until` ({date}), `remind`, `confirmDeleteChore` ({name}), `problemBlankTitle`, `problemTitleTooLong`, `problemWeeklyNoDays`, `problemBadMonthDay`, `problemEndBeforeStart`, `doneCount` ({done}, {total}), and weekday short names `wd1`…`wd7`.
- Tests include Review Focus #5 ("long Arabic titles do not overflow on small phones") at 320×640 and 360×740, text scale 1.0 and 1.3, picture tiles on and off.
- Commit: `feat(chores): chores tab, cards and chore sheet`

Also touched by this task (orchestrator update 2026-09-29, outside the Files block above): Modify `lib/data/write.dart` (`fireAndForget` must accept a write that returns a value, such as `addChore`'s `Future<String>`) and `test/app/home_shell_test.dart` (Task 2's test expects exactly three tabs); Create `test/data/write_test.dart`.

Notes for this task (additions inside this task's own files; see INTERFACE ISSUES (writer C) at the end of this part):
- `choresForDay` takes `languageCode` (Task 4, default `'en'`); the screen passes `Localizations.localeOf(context).languageCode` so titles sort in the UI language.
- `choresForDay` also returns that day's done records whose chore was edited or deleted. A deleted chore comes back as a stand-in one-time `Chore` whose id is not in `choresProvider`. Such a card is read-only: no tick, and long-press does not open the sheet (saving it would bring the deleted chore back). So `onLongPress` needs "parent or my own chore" and "the chore still exists"; `onToggle` needs `canToggle` and "the chore still exists".
- Ticking shows the same Undo SnackBar as buying (spec §5 "ticking, Undo … work the same"). It uses `SnackBar(persist: false)`, which auto-closes after 4 s even though it has an action, so no timer of our own is needed and nothing is left pending when a test ends (the ScaffoldMessenger cancels its own timer on dispose). Three l10n keys are added on top of the list above: `choreTicked` ({title}), `noChores`, `everyNMonthsOnDay` ({count} plural, {day}).
- Public helpers defined here and reused by Tasks 7–8: `toggleChore(...)` (in `chores_screen.dart`: the one place that ticks and unticks), `ChoreGroupHeader`, `compareMembers`, `memberById` (in `chore_groups.dart`), `PictureTileGrid`, `neutralPersonColor` (in `chore_card.dart`), `ChoreSheet` (the sheet's widget, so tests can lay it out directly), and the date/time/label helpers in `repeat_label.dart`.
- A card handles long presses whenever it handles taps (`onLongPress ?? (onToggle == null ? null : () {})`): Release 1 learned that a long press on an `InkWell` without `onLongPress` counts as a tap, which here would tick a chore by accident.
- Widget tests scroll a target into view before tapping (`tapKey`): at the 800×600 test size the add button can cover the lowest tick, and from Task 8 on the late strip sits above the sections.
- Task 5's `seedChores` creates every seeded chore with `createdBy: 'u1'` (Dad), so for Sara `brush` is a parent's chore she may tick but not edit.

- [x] **Step 1: Write the failing tests**

Create `test/features/chores_screen_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/dates.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/features/chores/chore_card.dart';
import 'package:family_app/features/chores/chore_groups.dart';
import 'package:family_app/features/chores/chores_screen.dart';
import 'package:family_app/features/chores/repeat_label.dart';
import 'package:family_app/features/common/empty_state.dart';
import 'package:family_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<FakeFirebaseFirestore> seeded() async {
  final db = await seedFamily();
  await seedChores(db);
  return db;
}

Future<void> addChore(FakeFirebaseFirestore db, Chore chore) =>
    db.doc('families/f1/chores/${chore.id}').set(chore.toMap());

Future<bool> isDone(FakeFirebaseFirestore db, String doneId) async =>
    (await db.doc('families/f1/choreDone/$doneId').get()).exists;

/// Scrolls the widget into view (clear of the add button) before tapping it.
Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key, skipOffstage: false));
  await settle(tester);
  await tester.tap(find.byKey(key));
  await settle(tester);
}

Future<void> longPressKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key, skipOffstage: false));
  await settle(tester);
  await tester.longPress(find.byKey(key));
  await settle(tester);
}

ChoreCard cardOf(WidgetTester tester, String choreId) =>
    tester.widget<ChoreCard>(find.byKey(ValueKey('chore-$choreId'), skipOffstage: false));

Finder section(String groupId) => find.byKey(ValueKey('choreSection-$groupId'), skipOffstage: false);

Finder inside(Finder parent, String text) => find.descendant(
      of: parent,
      matching: find.text(text, skipOffstage: false),
      skipOffstage: false,
    );

/// Shows [child] in Arabic (right to left) inside the test app.
Widget arabic(Widget child) => Builder(
      builder: (context) =>
          Localizations.override(context: context, locale: const Locale('ar'), child: child),
    );

/// Sara's own chore (she created it for herself).
const readBook = Chore(
  id: 'read',
  title: 'Read a book',
  assignee: 'u2',
  repeat: Repeat.daily,
  startDate: '2026-09-01',
  createdBy: 'u2',
);

void main() {
  testWidgets('a parent sees everyone: own section first, then children, then Anyone', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    expect(inside(section('u1'), 'Dad'), findsOneWidget);
    expect(inside(section('u1'), 'Take out bins'), findsOneWidget);
    expect(inside(section('u1'), '✓ 0/1'), findsOneWidget);
    expect(inside(section('u2'), 'Sara'), findsOneWidget);
    expect(inside(section('u2'), 'Brush teeth'), findsOneWidget);
    expect(tester.getTopLeft(section('u1')).dy, lessThan(tester.getTopLeft(section('u2')).dy));

    // Nothing is "anyone" on Thursday 1 Oct, but parents still see the Anyone section.
    await tester.ensureVisible(section('anyone'));
    await settle(tester);
    expect(inside(section('anyone'), 'Anyone'), findsOneWidget);
    expect(tester.getTopLeft(section('anyone')).dy, greaterThan(tester.getTopLeft(section('u2')).dy));
    expect(section('former'), findsNothing);
  });

  testWidgets('a child opens on Me and can switch to Everyone', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    expect(tester.widget<SegmentedButton<bool>>(find.byKey(const Key('choresScope'))).selected, {true});
    expect(section('u2'), findsOneWidget);
    expect(section('u1'), findsNothing);
    expect(section('anyone'), findsNothing); // Me hides an empty Anyone section

    await tester.tap(find.text('Everyone'));
    await settle(tester);
    expect(section('u1'), findsOneWidget);
    expect(section('anyone'), findsOneWidget);
  });

  testWidgets('cards show the emoji, time and repeat', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    final brush = find.byKey(const ValueKey('chore-brush'), skipOffstage: false);
    expect(inside(brush, '🪥'), findsOneWidget);
    expect(inside(brush, '7:00 AM · Daily'), findsOneWidget);
    expect(inside(find.byKey(const ValueKey('chore-bins'), skipOffstage: false), 'Mon, Thu'), findsOneWidget);
  });

  testWidgets('ticking writes a done record; Undo and a second tap remove it', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-brush'));
    final data = (await db.doc('families/f1/choreDone/brush_2026-10-01').get()).data()!;
    expect(data['choreId'], 'brush');
    expect(data['date'], '2026-10-01');
    expect(data['choreTitle'], 'Brush teeth');
    expect(data['doneBy'], 'u2');
    expect(data['doneByName'], 'Sara');
    expect(data['dayNumber'], dayNumberOf(DateTime(2026, 10, 1)));
    expect(cardOf(tester, 'brush').status.isDone, isTrue);
    expect(find.text('Brush teeth done'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await isDone(db, 'brush_2026-10-01'), isFalse);
    expect(cardOf(tester, 'brush').status.isDone, isFalse);

    await tapKey(tester, const ValueKey('tick-brush'));
    expect(await isDone(db, 'brush_2026-10-01'), isTrue);
    await tapKey(tester, const ValueKey('tick-brush'));
    expect(await isDone(db, 'brush_2026-10-01'), isFalse);
  });

  testWidgets("a parent ticking a child's chore records the child", (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await tapKey(tester, const ValueKey('tick-brush'));
    final data = (await db.doc('families/f1/choreDone/brush_2026-10-01').get()).data()!;
    expect(data['doneBy'], 'u2');
    expect(data['doneByName'], 'Sara');
  });

  testWidgets("a child cannot tick someone else's chore", (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
    await tester.tap(find.text('Everyone'));
    await settle(tester);
    expect(cardOf(tester, 'bins').onToggle, isNull);
    await tapKey(tester, const ValueKey('tick-bins'));
    expect(await isDone(db, 'bins_2026-10-01'), isFalse);
  });

  testWidgets('past days: a child can change yesterday but not the day before', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
    expect(find.text('Today'), findsOneWidget);

    await tapKey(tester, const Key('dayPrev'));
    expect(find.text('Wed 30 Sep'), findsOneWidget);
    expect(cardOf(tester, 'brush').status.isDone, isTrue); // seeded done record
    expect(cardOf(tester, 'brush').onToggle, isNotNull);
    await tapKey(tester, const ValueKey('tick-brush'));
    expect(await isDone(db, 'brush_2026-09-30'), isFalse);

    await tapKey(tester, const Key('dayPrev'));
    expect(find.text('Tue 29 Sep'), findsOneWidget);
    expect(cardOf(tester, 'brush').onToggle, isNull);

    await tapKey(tester, const Key('dayNext'));
    await tapKey(tester, const Key('dayNext'));
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('parents can correct any past day', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    for (var i = 0; i < 3; i++) {
      await tapKey(tester, const Key('dayPrev'));
    }
    expect(find.text('Mon 28 Sep'), findsOneWidget);
    await tapKey(tester, const ValueKey('tick-brush'));
    final data = (await db.doc('families/f1/choreDone/brush_2026-09-28').get()).data()!;
    expect(data['doneBy'], 'u2');
  });

  testWidgets('tapping the date opens a date picker', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await tapKey(tester, const Key('dayLabel'));
    await tester.tap(find.text('3'));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('Sat 3 Oct'), findsOneWidget);
    // Water plants repeats on Saturdays.
    await tester.ensureVisible(section('anyone'));
    await settle(tester);
    expect(inside(section('anyone'), 'Water plants'), findsOneWidget);
  });

  testWidgets("long-press edits for parents and for a child's own chore only", (tester) async {
    final db = await seeded(); // brush was created by Dad
    await addChore(db, readBook);
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    await longPressKey(tester, const ValueKey('chore-brush'));
    expect(find.byKey(const Key('choreTitle')), findsNothing);
    expect(await isDone(db, 'brush_2026-10-01'), isFalse); // a long press is not a tap

    await longPressKey(tester, const ValueKey('chore-read'));
    expect(find.byKey(const Key('choreTitle')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('choreTitle'))).controller!.text, 'Read a book');
  });

  testWidgets("a parent's long-press opens the sheet for any chore", (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await longPressKey(tester, const ValueKey('chore-brush'));
    expect(tester.widget<TextField>(find.byKey(const Key('choreTitle'))).controller!.text, 'Brush teeth');
  });

  testWidgets("a deleted chore's done day still shows, read-only, with its copied title", (tester) async {
    final db = await seeded();
    await db.doc('families/f1/chores/brush').delete(); // brush_2026-09-30 stays as history
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    expect(find.byKey(const ValueKey('chore-brush'), skipOffstage: false), findsNothing); // gone from today

    await tapKey(tester, const Key('dayPrev'));
    expect(inside(section('u2'), 'Brush teeth'), findsOneWidget);
    expect(cardOf(tester, 'brush').status.isDone, isTrue);
    expect(cardOf(tester, 'brush').onToggle, isNull);
    expect(cardOf(tester, 'brush').onLongPress, isNull);
    await longPressKey(tester, const ValueKey('chore-brush'));
    expect(find.byKey(const Key('choreTitle')), findsNothing);
    expect((await db.doc('families/f1/chores/brush').get()).exists, isFalse);
  });

  testWidgets('the add button opens an empty chore sheet', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
    await tester.tap(find.byKey(const Key('addChore')));
    await settle(tester);
    expect(find.text('Add chore'), findsWidgets);
    expect(tester.widget<TextField>(find.byKey(const Key('choreTitle'))).controller!.text, isEmpty);
  });

  testWidgets('a day without chores shows a friendly empty state', (tester) async {
    final db = await seedFamily(); // no chores at all
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No chores today'), findsOneWidget);
  });

  testWidgets('picture tiles show big emoji tiles for that member only', (tester) async {
    final db = await seeded();
    await db.doc('families/f1/members/u2').update({'pictureTiles': true});
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    expect(cardOf(tester, 'brush').pictureTile, isTrue);
    expect(cardOf(tester, 'bins').pictureTile, isFalse);
    final emoji = tester.widget<Text>(inside(find.byKey(const ValueKey('chore-brush'), skipOffstage: false), '🪥'));
    expect(emoji.style!.fontSize, 44);
  });

  testWidgets('long Arabic titles do not overflow on small phones', (tester) async {
    const title = 'ترتيب غرفة النوم وتنظيف المكتب وجمع الألعاب قبل موعد النوم';
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final size in const [Size(320, 640), Size(360, 740)]) {
      for (final scale in const [1.0, 1.3]) {
        for (final pictureTiles in const [false, true]) {
          final label = '$size, text x$scale, picture tiles $pictureTiles';
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          final db = await seeded();
          await db.doc('families/f1/chores/brush').update({'title': title}); // keeps its 🪥
          await db.doc('families/f1/members/u2').update({'pictureTiles': pictureTiles});
          await pumpWithFamily(tester, db: db, uid: 'u2', child: arabic(const ChoresScreen()));
          expect(tester.takeException(), isNull, reason: label);

          // The title is cut to its lines with an ellipsis.
          final titleText = inside(find.byKey(const ValueKey('chore-brush'), skipOffstage: false), title);
          expect(tester.renderObject<RenderParagraph>(titleText).didExceedMaxLines, isTrue, reason: label);

          // The tick keeps a 48 dp target and still works.
          final tick = find.byKey(const ValueKey('tick-brush'), skipOffstage: false);
          await tester.ensureVisible(tick);
          await settle(tester);
          expect(tester.getSize(tick).width, greaterThanOrEqualTo(48), reason: label);
          expect(tester.getSize(tick).height, greaterThanOrEqualTo(48), reason: label);
          await tester.tap(tick);
          await settle(tester);
          expect(await isDone(db, 'brush_2026-10-01'), isTrue, reason: label);
          expect(tester.takeException(), isNull, reason: label);

          await tester.pumpWidget(const SizedBox()); // a fresh ProviderScope for the next case
        }
      }
    }
  });

  testWidgets('long English titles fit small phones in the family view', (tester) async {
    const long = 'Take the recycling and the garden waste bins out to the street';
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final size in const [Size(320, 640), Size(360, 740)]) {
      for (final scale in const [1.0, 1.3]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final db = await seeded();
        await db.doc('families/f1/chores/bins').update({'title': long});
        await db.doc('families/f1/chores/brush').update({'title': long});
        await db.doc('families/f1/members/u2').update({'pictureTiles': true});
        await pumpWithFamily(tester, db: db, child: const ChoresScreen());
        expect(tester.takeException(), isNull, reason: '$size, text x$scale');
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('the Chores tab sits between Today and Lists', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const HomeShell());
    final labels = [
      for (final d in tester.widgetList<NavigationDestination>(find.byType(NavigationDestination))) d.label,
    ];
    expect(labels, ['Today', 'Chores', 'Lists', 'Family']);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Chores')));
    await settle(tester);
    expect(find.byKey(const Key('dayLabel')), findsOneWidget);
  });

  group('buildChoreGroups', () {
    const dad = Member(uid: 'u1', name: 'Dad', role: Role.parent);
    const sara = Member(uid: 'u2', name: 'Sara', role: Role.child);
    const mum = Member(uid: 'u3', name: 'Mum', role: Role.parent);
    const adam = Member(uid: 'u4', name: 'Adam', role: Role.child);
    const members = [sara, dad, adam, mum];

    ChoreStatus item(String id, {String? assignee}) => ChoreStatus(
          Chore(id: id, title: id, assignee: assignee, startDate: '2026-10-01', createdBy: 'u1'),
          null,
        );

    DayView view({List<ChoreStatus> anyone = const [], List<ChoreStatus> former = const []}) => DayView(
          byMember: {
            for (final m in members) m.uid: [item('c-${m.uid}', assignee: m.uid)],
          },
          anyone: anyone,
          formerMember: former,
        );

    List<String> ids(List<ChoreGroup> groups) => [for (final g in groups) g.id];

    test('me first, then parents, then children, each by name; then Anyone', () {
      expect(
        ids(buildChoreGroups(view: view(), members: members, me: 'u2', isParent: false, onlyMe: false)),
        ['u2', 'u1', 'u3', 'u4', 'anyone'],
      );
      expect(
        ids(buildChoreGroups(view: view(), members: members, me: 'u3', isParent: true, onlyMe: false)),
        ['u3', 'u1', 'u4', 'u2', 'anyone'],
      );
    });

    test('only me: my own group, plus Anyone when it has chores', () {
      expect(ids(buildChoreGroups(view: view(), members: members, me: 'u2', isParent: false, onlyMe: true)), ['u2']);
      expect(
        ids(buildChoreGroups(
          view: view(anyone: [item('dishes')]),
          members: members,
          me: 'u2',
          isParent: false,
          onlyMe: true,
        )),
        ['u2', 'anyone'],
      );
    });

    test('former members show to parents only, and only when they have chores', () {
      final withFormer = view(former: [item('old', assignee: 'u9')]);
      final forParent =
          buildChoreGroups(view: withFormer, members: members, me: 'u1', isParent: true, onlyMe: false);
      expect(forParent.last.id, 'former');
      expect(forParent.last.isFormer, isTrue);
      expect(
        ids(buildChoreGroups(view: withFormer, members: members, me: 'u2', isParent: false, onlyMe: false)),
        isNot(contains('former')),
      );
      expect(
        ids(buildChoreGroups(view: view(), members: members, me: 'u1', isParent: true, onlyMe: false)),
        isNot(contains('former')),
      );
    });
  });

  testWidgets('repeat labels read naturally', (tester) async {
    late AppLocalizations l;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        l = AppLocalizations.of(context)!;
        return const SizedBox();
      }),
    ));
    Chore c({Repeat repeat = Repeat.daily, int every = 1, List<int> weekdays = const [], int? monthDay, String? endDate}) =>
        Chore(
          id: 'x',
          title: 'x',
          repeat: repeat,
          every: every,
          weekdays: weekdays,
          monthDay: monthDay,
          startDate: '2026-09-28',
          endDate: endDate,
          createdBy: 'u1',
        );
    expect(repeatLabel(l, c(repeat: Repeat.once)), 'Once · 28 Sep');
    expect(repeatLabel(l, c()), 'Daily');
    expect(repeatLabel(l, c(every: 2)), 'Every 2 days');
    expect(repeatLabel(l, c(repeat: Repeat.weekly, weekdays: [7, 1, 2, 3, 4])), 'Sun–Thu');
    expect(repeatLabel(l, c(repeat: Repeat.weekly, every: 2, weekdays: [4, 1])), 'Every 2 weeks · Mon, Thu');
    expect(repeatLabel(l, c(repeat: Repeat.monthly, monthDay: 15)), 'Monthly · day 15');
    expect(repeatLabel(l, c(repeat: Repeat.monthly, every: 3, monthDay: 31)), 'Every 3 months · day 31');
    expect(repeatLabel(l, c(endDate: '2027-06-30')), 'Daily · until 30 Jun');
  });
}
```

Create `test/features/chore_sheet_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/features/chores/chore_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<void> openSheet(WidgetTester tester, FakeFirebaseFirestore db, {String uid = 'u1', Chore? chore}) async {
  await pumpWithFamily(
    tester,
    db: db,
    uid: uid,
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showChoreSheet(context, chore: chore, day: DateTime(2026, 10, 1)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await settle(tester);
}

/// The sheet scrolls: bring the widget into view first.
Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key, skipOffstage: false));
  await settle(tester);
  await tester.tap(find.byKey(key));
  await settle(tester);
}

Future<void> typeInto(WidgetTester tester, Key key, String text) async {
  await tester.ensureVisible(find.byKey(key, skipOffstage: false));
  await settle(tester);
  await tester.enterText(find.byKey(key), text);
  await settle(tester);
}

Future<List<Map<String, dynamic>>> storedChores(FakeFirebaseFirestore db) async =>
    [for (final d in (await db.collection('families/f1/chores').get()).docs) d.data()];

Future<Chore> storedChore(FakeFirebaseFirestore db, String id) async =>
    Chore.fromMap(id, (await db.doc('families/f1/chores/$id').get()).data()!);

Future<FakeFirebaseFirestore> seeded() async {
  final db = await seedFamily();
  await seedChores(db);
  return db;
}

void main() {
  testWidgets('a parent adds a weekly chore for a child', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    // New chores from a parent start with the first child.
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('choreWho-u2'))).selected, isTrue);
    expect(find.byKey(const ValueKey('choreWho-u1')), findsOneWidget);
    expect(find.byKey(const ValueKey('choreWho-anyone')), findsOneWidget);

    await typeInto(tester, const Key('choreTitle'), '  Feed the cat ');
    await typeInto(tester, const Key('choreEmoji'), '🐱');
    await tapKey(tester, const ValueKey('choreRepeat-weekly'));
    // Weekly starts on the start day's weekday: Thursday.
    expect(tester.widget<FilterChip>(find.byKey(const ValueKey('choreWeekday-4'))).selected, isTrue);
    await tapKey(tester, const ValueKey('choreWeekday-1'));
    await typeInto(tester, const Key('choreEvery'), '2');
    expect(find.text('Every 2 weeks · Mon, Thu'), findsOneWidget); // live preview
    await tapKey(tester, const Key('choreSave'));

    final data = (await storedChores(db)).single;
    expect(data['title'], 'Feed the cat');
    expect(data['icon'], '🐱');
    expect(data['assignee'], 'u2');
    expect(data['repeat'], 'weekly');
    expect(data['every'], 2);
    expect(data['weekdays'], [1, 4]);
    expect(data['monthDay'], isNull);
    expect(data['startDate'], '2026-10-01');
    expect(data['endDate'], isNull);
    expect(data['remind'], isFalse);
    expect(data['createdBy'], 'u1');
    expect(find.byKey(const Key('choreSave')), findsNothing);
  });

  testWidgets('blank titles, weekly without days and bad month days are blocked inline', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);

    await typeInto(tester, const Key('choreTitle'), '   ');
    await tapKey(tester, const Key('choreSave'));
    expect(find.text('Please enter a title.'), findsOneWidget);

    await typeInto(tester, const Key('choreTitle'), 'Tidy up');
    expect(find.text('Please enter a title.'), findsNothing);
    await tapKey(tester, const ValueKey('choreRepeat-weekly'));
    await tapKey(tester, const ValueKey('choreWeekday-4')); // untick the only day
    await tapKey(tester, const Key('choreSave'));
    expect(find.text('Pick at least one day.'), findsOneWidget);

    await tapKey(tester, const ValueKey('choreRepeat-monthly'));
    await typeInto(tester, const Key('choreMonthDay'), '32');
    await tapKey(tester, const Key('choreSave'));
    expect(find.text('Pick a day between 1 and 31.'), findsOneWidget);

    expect(await storedChores(db), isEmpty);
    expect(find.byKey(const Key('choreSave')), findsOneWidget); // still open
  });

  testWidgets('the end date cannot be before the start date', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    await typeInto(tester, const Key('choreTitle'), 'Water the garden');
    await tapKey(tester, const Key('choreEndNever')); // now ends on the start day, 1 Oct
    expect(find.byKey(const Key('choreEndDate')), findsOneWidget);

    await tapKey(tester, const Key('choreStart'));
    await tester.tap(find.text('5'));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('Mon 5 Oct 2026'), findsOneWidget);

    await tapKey(tester, const Key('choreSave'));
    expect(find.text("The end date can't be before the start date."), findsOneWidget);
    expect(await storedChores(db), isEmpty);
  });

  testWidgets('a time can be picked and cleared; Remind needs a time', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    await typeInto(tester, const Key('choreTitle'), 'Practice piano');
    SwitchListTile remind() => tester.widget<SwitchListTile>(find.byKey(const Key('choreRemind')));
    expect(find.text('No time'), findsOneWidget);
    expect(remind().onChanged, isNull);

    await tapKey(tester, const Key('choreTime'));
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(remind().onChanged, isNotNull);

    await tapKey(tester, const Key('choreTimeClear'));
    expect(find.text('No time'), findsOneWidget);

    await tapKey(tester, const Key('choreTime'));
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tapKey(tester, const Key('choreRemind'));
    await tapKey(tester, const Key('choreSave'));
    final data = (await storedChores(db)).single;
    expect(data['time'], '08:00');
    expect(data['remind'], isTrue);
  });

  testWidgets('children only make chores for themselves', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db, uid: 'u2');
    expect(find.byKey(const ValueKey('choreWho-u2')), findsOneWidget);
    expect(find.byKey(const ValueKey('choreWho-u1')), findsNothing);
    expect(find.byKey(const ValueKey('choreWho-anyone')), findsNothing);
    await typeInto(tester, const Key('choreTitle'), 'Read a book');
    await tapKey(tester, const Key('choreSave'));
    final data = (await storedChores(db)).single;
    expect(data['assignee'], 'u2');
    expect(data['createdBy'], 'u2');
  });

  testWidgets('editing keeps the chore and changes only what was edited', (tester) async {
    final db = await seeded();
    await openSheet(tester, db, chore: await storedChore(db, 'bins'));
    expect(find.text('Edit chore'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('choreWho-u1'))).selected, isTrue);
    expect(tester.widget<FilterChip>(find.byKey(const ValueKey('choreWeekday-1'))).selected, isTrue);

    await typeInto(tester, const Key('choreTitle'), 'Take the bins out');
    await tapKey(tester, const Key('choreSave'));
    final data = (await db.doc('families/f1/chores/bins').get()).data()!;
    expect(data['title'], 'Take the bins out');
    expect(data['assignee'], 'u1');
    expect(data['repeat'], 'weekly');
    expect(data['weekdays'], [1, 4]);
    expect(data['startDate'], '2026-09-01');
    expect(await storedChores(db), hasLength(4));
  });

  testWidgets('a parent deletes a chore after confirming; its done days stay', (tester) async {
    final db = await seeded();
    await openSheet(tester, db, chore: await storedChore(db, 'brush'));
    await tapKey(tester, const Key('choreDelete'));
    expect(find.text('Delete the chore Brush teeth? Days already done stay in the history.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmYes')));
    await settle(tester);
    expect((await db.doc('families/f1/chores/brush').get()).exists, isFalse);
    expect((await db.doc('families/f1/choreDone/brush_2026-09-30').get()).exists, isTrue);
    expect(find.byKey(const Key('choreSave')), findsNothing);
  });

  testWidgets('a child can delete a chore they made for themselves', (tester) async {
    final db = await seeded();
    const own = Chore(
      id: 'read',
      title: 'Read a book',
      assignee: 'u2',
      repeat: Repeat.daily,
      startDate: '2026-09-01',
      createdBy: 'u2',
    );
    await db.doc('families/f1/chores/read').set(own.toMap());
    await openSheet(tester, db, uid: 'u2', chore: own);
    expect(find.byKey(const Key('choreDelete')), findsOneWidget);
  });

  testWidgets("a child cannot delete a parent's chore", (tester) async {
    final db = await seeded(); // brush was created by Dad
    await openSheet(tester, db, uid: 'u2', chore: await storedChore(db, 'brush'));
    expect(find.byKey(const Key('choreDelete')), findsNothing);
  });

  testWidgets('the sheet fits small phones in Arabic', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final size in const [Size(320, 640), Size(360, 740)]) {
      for (final scale in const [1.0, 1.3]) {
        final label = '$size, text x$scale';
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final db = await seedFamily();
        await pumpWithFamily(
          tester,
          db: db,
          child: Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('ar'),
              child: Scaffold(body: ChoreSheet(day: DateTime(2026, 10, 1))),
            ),
          ),
        );
        await tapKey(tester, const ValueKey('choreRepeat-weekly'));
        await tapKey(tester, const Key('choreEndNever'));
        await tapKey(tester, const Key('choreSave')); // shows the inline messages too
        expect(tester.takeException(), isNull, reason: label);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/chores_screen_test.dart test/features/chore_sheet_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/features/chores/chore_card.dart'` (and the same for the other new chores files).

- [x] **Step 3: Make `fireAndForget` safe for writes that return a value**

The chore sheet passes `addChore(...)` (a `Future<String>`) to `fireAndForget`. Today's `write.catchError((Object error) { ... })` returns null from the handler; on a `Future<String>` that is not a valid value, so a failed write turns into an uncaught `ArgumentError` instead of a log line.

Create `test/data/write_test.dart`:

```dart
import 'dart:async';

import 'package:family_app/data/write.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a failing write that returns a value is logged, not thrown', () async {
    final uncaught = <Object>[];
    final finished = Completer<void>();
    runZonedGuarded(() {
      fireAndForget(Future<String>.error(StateError('offline')));
      // Runs after the error has gone through every handler.
      Timer.run(finished.complete);
    }, (error, stack) => uncaught.add(error));
    await finished.future;
    expect(uncaught, isEmpty);
  });

  test('a failing plain write is logged, not thrown', () async {
    final uncaught = <Object>[];
    final finished = Completer<void>();
    runZonedGuarded(() {
      fireAndForget(Future<void>.error(StateError('offline')));
      Timer.run(finished.complete);
    }, (error, stack) => uncaught.add(error));
    await finished.future;
    expect(uncaught, isEmpty);
  });
}
```

Run: `flutter test test/data/write_test.dart`
Expected: FAIL in "a failing write that returns a value is logged, not thrown" (`uncaught` holds an `ArgumentError`); the plain-write test passes.

Replace `lib/data/write.dart` with:

```dart
import 'package:flutter/foundation.dart';

/// Starts a Firestore write without waiting for the server.
/// Offline, the write is applied to the local cache at once and synced later.
/// Works for writes that return a value too (for example a new document id).
void fireAndForget(Future<void> write) {
  write.then<void>(
    (_) {},
    onError: (Object error) {
      debugPrint('Firestore write failed: $error');
    },
  );
}
```

Run: `flutter test test/data/write_test.dart`
Expected: PASS

- [x] **Step 4: Add the strings**

In `lib/l10n/app_en.arb`, add a comma after the current last entry and append these entries before the closing `}`:

```json
  "tabChores": "Chores",
  "today": "Today",
  "everyone": "Everyone",
  "me": "Me",
  "anyone": "Anyone",
  "formerMember": "Former member",
  "noChoresToday": "No chores today",
  "noChores": "No chores",
  "addChore": "Add chore",
  "editChore": "Edit chore",
  "choreTitle": "Chore",
  "choreEmoji": "Emoji (optional)",
  "who": "Who",
  "time": "Time",
  "noTime": "No time",
  "repeat": "Repeat",
  "repeatOnce": "Once",
  "repeatDaily": "Daily",
  "repeatWeekly": "Weekly",
  "repeatMonthly": "Monthly",
  "every": "Every",
  "everyNDays": "{count, plural, =1{Daily} other{Every {count} days}}",
  "@everyNDays": { "placeholders": { "count": { "type": "int" } } },
  "everyNWeeks": "{count, plural, =1{Every week} other{Every {count} weeks}}",
  "@everyNWeeks": { "placeholders": { "count": { "type": "int" } } },
  "everyNMonthsOnDay": "{count, plural, =1{Monthly · day {day}} other{Every {count} months · day {day}}}",
  "@everyNMonthsOnDay": { "placeholders": { "count": { "type": "int" }, "day": { "type": "int" } } },
  "onDays": "On these days",
  "dayOfMonth": "Day of the month",
  "monthlyOnDay": "Monthly · day {day}",
  "@monthlyOnDay": { "placeholders": { "day": { "type": "int" } } },
  "startDate": "Starts",
  "endDate": "Ends on",
  "endsNever": "Never ends",
  "until": "until {date}",
  "@until": { "placeholders": { "date": { "type": "String" } } },
  "remind": "Remind me",
  "confirmDeleteChore": "Delete the chore {name}? Days already done stay in the history.",
  "@confirmDeleteChore": { "placeholders": { "name": { "type": "String" } } },
  "problemBlankTitle": "Please enter a title.",
  "problemTitleTooLong": "Keep the title to 80 characters or fewer.",
  "problemWeeklyNoDays": "Pick at least one day.",
  "problemBadMonthDay": "Pick a day between 1 and 31.",
  "problemEndBeforeStart": "The end date can't be before the start date.",
  "doneCount": "✓ {done}/{total}",
  "@doneCount": { "placeholders": { "done": { "type": "int" }, "total": { "type": "int" } } },
  "choreTicked": "{title} done",
  "@choreTicked": { "placeholders": { "title": { "type": "String" } } },
  "wd1": "Mon",
  "wd2": "Tue",
  "wd3": "Wed",
  "wd4": "Thu",
  "wd5": "Fri",
  "wd6": "Sat",
  "wd7": "Sun"
```

In `lib/l10n/app_ar.arb` (no `@` entries, as in the rest of that file), add a comma after the current last entry and append:

```json
  "tabChores": "المهام",
  "today": "اليوم",
  "everyone": "الجميع",
  "me": "أنا",
  "anyone": "أي شخص",
  "formerMember": "عضو سابق",
  "noChoresToday": "لا مهام اليوم",
  "noChores": "لا مهام",
  "addChore": "إضافة مهمة",
  "editChore": "تعديل المهمة",
  "choreTitle": "المهمة",
  "choreEmoji": "رمز تعبيري (اختياري)",
  "who": "لمن",
  "time": "الوقت",
  "noTime": "بلا وقت",
  "repeat": "التكرار",
  "repeatOnce": "مرة واحدة",
  "repeatDaily": "يوميًا",
  "repeatWeekly": "أسبوعيًا",
  "repeatMonthly": "شهريًا",
  "every": "كل",
  "everyNDays": "{count, plural, =1{يوميًا} =2{كل يومين} few{كل {count} أيام} many{كل {count} يومًا} other{كل {count} يوم}}",
  "everyNWeeks": "{count, plural, =1{كل أسبوع} =2{كل أسبوعين} few{كل {count} أسابيع} many{كل {count} أسبوعًا} other{كل {count} أسبوع}}",
  "everyNMonthsOnDay": "{count, plural, =1{شهريًا · يوم {day}} =2{كل شهرين · يوم {day}} few{كل {count} أشهر · يوم {day}} many{كل {count} شهرًا · يوم {day}} other{كل {count} شهر · يوم {day}}}",
  "onDays": "في هذه الأيام",
  "dayOfMonth": "يوم من الشهر",
  "monthlyOnDay": "شهريًا · يوم {day}",
  "startDate": "يبدأ",
  "endDate": "ينتهي في",
  "endsNever": "لا ينتهي",
  "until": "حتى {date}",
  "remind": "ذكّرني",
  "confirmDeleteChore": "حذف المهمة {name}؟ تبقى الأيام المنجزة في السجل.",
  "problemBlankTitle": "الرجاء إدخال عنوان.",
  "problemTitleTooLong": "اجعل العنوان 80 حرفًا أو أقل.",
  "problemWeeklyNoDays": "اختر يومًا واحدًا على الأقل.",
  "problemBadMonthDay": "اختر يومًا بين 1 و31.",
  "problemEndBeforeStart": "لا يمكن أن يكون تاريخ الانتهاء قبل تاريخ البدء.",
  "doneCount": "✓ {done}/{total}",
  "choreTicked": "تم إنجاز {title}",
  "wd1": "إثنين",
  "wd2": "ثلاثاء",
  "wd3": "أربعاء",
  "wd4": "خميس",
  "wd5": "جمعة",
  "wd6": "سبت",
  "wd7": "أحد"
```

Run: `flutter gen-l10n`
Expected: no errors; `lib/l10n/app_localizations*.dart` regenerated with the new getters (e.g. `String everyNMonthsOnDay(int count, int day)`).


- [x] **Step 5: Implement labels and groups**

Create `lib/features/chores/repeat_label.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/chores.dart';
import '../../core/dates.dart';
import '../../l10n/app_localizations.dart';

/// Weekday numbers (1 = Monday … 7 = Sunday) in the order the family's week
/// runs: Sunday first.
const weekOrder = [7, 1, 2, 3, 4, 5, 6];

String weekdayName(AppLocalizations l, int weekday) => switch (weekday) {
      1 => l.wd1,
      2 => l.wd2,
      3 => l.wd3,
      4 => l.wd4,
      5 => l.wd5,
      6 => l.wd6,
      _ => l.wd7,
    };

/// "Sun–Thu" for three or more days in a row, otherwise "Mon, Thu".
String weekdaysLabel(AppLocalizations l, List<int> weekdays) {
  final positions = {
    for (final d in weekdays)
      if (d >= 1 && d <= 7) weekOrder.indexOf(d),
  }.toList()
    ..sort();
  if (positions.isEmpty) return '';
  final isRun = positions.length >= 3 && positions.last - positions.first == positions.length - 1;
  if (isRun) {
    return '${weekdayName(l, weekOrder[positions.first])}–${weekdayName(l, weekOrder[positions.last])}';
  }
  final separator = l.localeName.startsWith('ar') ? '، ' : ', ';
  return [for (final p in positions) weekdayName(l, weekOrder[p])].join(separator);
}

/// "28 Sep".
String shortDate(String locale, DateTime day) => DateFormat('d MMM', locale).format(day);

/// "Wed 30 Sep": the Chores tab's day switcher.
String dayTitle(String locale, DateTime day) => DateFormat('EEE d MMM', locale).format(day);

/// "Thu 1 Oct 2026": dates in the chore sheet.
String longDate(String locale, DateTime day) => DateFormat('EEE d MMM y', locale).format(day);

/// "Once · 28 Sep", "Daily", "Every 2 days", "Sun–Thu", "Every 2 weeks · Mon, Thu",
/// "Monthly · day 15", "Every 3 months · day 31"; "… · until 30 Jun" when it ends.
String repeatLabel(AppLocalizations l, Chore c) {
  final locale = l.localeName;
  final base = switch (c.repeat) {
    Repeat.once => '${l.repeatOnce} · ${shortDate(locale, parseDateKey(c.startDate))}',
    Repeat.daily => c.every <= 1 ? l.repeatDaily : l.everyNDays(c.every),
    Repeat.weekly => _weeklyLabel(l, c),
    Repeat.monthly =>
      c.every <= 1 ? l.monthlyOnDay(c.monthDay ?? 1) : l.everyNMonthsOnDay(c.every, c.monthDay ?? 1),
  };
  final end = c.endDate;
  if (end == null || c.repeat == Repeat.once) return base;
  return '$base · ${l.until(shortDate(locale, parseDateKey(end)))}';
}

String _weeklyLabel(AppLocalizations l, Chore c) {
  final days = weekdaysLabel(l, c.weekdays);
  if (c.every <= 1) return days.isEmpty ? l.repeatWeekly : days;
  final every = l.everyNWeeks(c.every);
  return days.isEmpty ? every : '$every · $days';
}

/// "07:00" → 7:00, or null when the stored value is malformed.
TimeOfDay? parseChoreTime(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

/// 7:00 → "07:00", the stored form.
String choreTimeKey(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "7:00 AM" (or "07:00" when the phone uses 24-hour time), in the UI language.
String formatChoreTime(BuildContext context, String hhmm) {
  final time = parseChoreTime(hhmm);
  if (time == null) return hhmm;
  return MaterialLocalizations.of(context).formatTimeOfDay(
    time,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// The small line under a chore's title: "7:00 AM · Daily".
String choreCaption(BuildContext context, Chore c) {
  final l = AppLocalizations.of(context)!;
  final repeat = repeatLabel(l, c);
  final time = c.time;
  return time == null ? repeat : '${formatChoreTime(context, time)} · $repeat';
}
```

Create `lib/features/chores/chore_groups.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../core/models.dart';
import '../../core/text.dart';
import '../../l10n/app_localizations.dart';
import '../common/member_avatar.dart';

/// One section of the Chores tab (phone) or one column of the board (tablet).
class ChoreGroup {
  const ChoreGroup({
    required this.id,
    required this.items,
    this.member,
    this.isAnyone = false,
    this.isFormer = false,
  });

  /// The member's uid, `'anyone'` or `'former'`.
  final String id;
  final Member? member;
  final List<ChoreStatus> items;
  final bool isAnyone;
  final bool isFormer;
}

/// Parents before children, then by name.
int compareMembers(Member a, Member b) {
  if (a.role != b.role) return a.role == Role.parent ? -1 : 1;
  final byName = nameKey(a.name).compareTo(nameKey(b.name));
  return byName != 0 ? byName : a.uid.compareTo(b.uid);
}

Member? memberById(List<Member> members, String? uid) {
  for (final m in members) {
    if (m.uid == uid) return m;
  }
  return null;
}

/// Me first, then parents, then children (each by name), then Anyone (when it
/// has chores, or always when showing everyone), then Former member (parents
/// only, when it has chores). With [onlyMe]: my group plus Anyone.
List<ChoreGroup> buildChoreGroups({
  required DayView view,
  required List<Member> members,
  required String me,
  required bool isParent,
  required bool onlyMe,
}) {
  ChoreGroup forMember(Member m) =>
      ChoreGroup(id: m.uid, member: m, items: view.byMember[m.uid] ?? const <ChoreStatus>[]);
  final mine = memberById(members, me);
  final others = [
    for (final m in members)
      if (m.uid != me) m,
  ]..sort(compareMembers);
  return [
    if (mine != null) forMember(mine),
    if (!onlyMe)
      for (final m in others) forMember(m),
    if (view.anyone.isNotEmpty || !onlyMe) ChoreGroup(id: 'anyone', items: view.anyone, isAnyone: true),
    if (!onlyMe && isParent && view.formerMember.isNotEmpty)
      ChoreGroup(id: 'former', items: view.formerMember, isFormer: true),
  ];
}

/// Avatar, name and "✓ done/total": the head of a phone section or a board column.
class ChoreGroupHeader extends StatelessWidget {
  const ChoreGroupHeader({super.key, required this.group});

  final ChoreGroup group;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final progress = progressOf(group.items);
    final member = group.member;
    return Row(
      children: [
        if (member != null)
          MemberAvatar(member: member, size: 36)
        else
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              group.isAnyone ? Icons.groups_outlined : Icons.person_off_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            member?.name ?? (group.isAnyone ? l.anyone : l.formerMember),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          l.doneCount(progress.done, progress.total),
          style: theme.textTheme.labelLarge?.copyWith(color: context.tokens.mutedText),
        ),
      ],
    );
  }
}
```

- [x] **Step 6: Implement the chore card**

Create `lib/features/chores/chore_card.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../core/text.dart';
import 'repeat_label.dart';

/// Colours for chores that belong to no one yet ("anyone" and former members).
PersonColor neutralPersonColor(ThemeData theme) {
  final scheme = theme.colorScheme;
  return PersonColor(
    fill: scheme.primary,
    onFill: scheme.onPrimary,
    tint: scheme.surfaceContainerHighest,
    onTint: scheme.onSurface,
  );
}

/// A chore in the playful style: tinted in the person's colour until done,
/// then filled. With [pictureTile], a big emoji tile for younger children.
class ChoreCard extends StatelessWidget {
  const ChoreCard({
    super.key,
    required this.status,
    required this.color,
    required this.pictureTile,
    required this.onToggle,
    this.onLongPress,
    this.late = false,
  });

  final ChoreStatus status;
  final PersonColor color;
  final bool pictureTile;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final chore = status.chore;
    final done = status.isDone;
    final background = done ? color.fill : color.tint;
    final foreground = done ? color.onFill : color.onTint;
    final radius = BorderRadius.circular(tokens.tileRadius);
    final caption = choreCaption(context, chore);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
      decoration: done ? TextDecoration.lineThrough : null,
      decorationColor: foreground,
    );
    final captionStyle = theme.textTheme.bodySmall?.copyWith(color: foreground);
    final tick = _TickButton(
      key: ValueKey('tick-${chore.id}'),
      done: done,
      foreground: foreground,
      background: background,
      label: chore.title,
      onTap: onToggle,
    );

    final Widget content;
    if (pictureTile) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            chore.icon ?? tileLetter(chore.title),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 44, height: 1.2, color: foreground, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            chore.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: titleStyle,
          ),
          if (caption.isNotEmpty)
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: captionStyle,
            ),
          tick,
        ],
      );
    } else {
      content = Row(
        children: [
          if (chore.icon != null) ...[
            Text(chore.icon!, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chore.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
                  if (caption.isNotEmpty)
                    Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: captionStyle),
                ],
              ),
            ),
          ),
          tick,
        ],
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: late ? Border.all(color: tokens.late, width: 2) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onToggle,
          // A long press must never count as a tap (Release 1 lesson), so the
          // card claims long presses whenever it handles taps.
          onLongPress: onLongPress ?? (onToggle == null ? null : () {}),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: pictureTile
                  ? const EdgeInsets.fromLTRB(8, 12, 8, 4)
                  : const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 4),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// The round tick: a 48 dp target around a 30 dp circle.
class _TickButton extends StatelessWidget {
  const _TickButton({
    super.key,
    required this.done,
    required this.foreground,
    required this.background,
    required this.label,
    required this.onTap,
  });

  final bool done;
  final Color foreground;
  final Color background;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      checked: done,
      enabled: enabled,
      label: label,
      child: SizedBox(
        width: 48,
        height: 48,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.35,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? foreground : Colors.transparent,
                  border: Border.all(color: foreground, width: 2.5),
                ),
                child: done ? Icon(Icons.check, size: 20, color: background) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Picture tiles in rows of equal height: at least two per row, more when
/// there is room. Rows grow with the text, so nothing can overflow.
class PictureTileGrid extends StatelessWidget {
  const PictureTileGrid({super.key, required this.children, this.minTileWidth = 140, this.spacing = 8});

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = math.max(2, ((constraints.maxWidth + spacing) / (minTileWidth + spacing)).floor());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var start = 0; start < children.length; start += perRow)
              Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < perRow; i++) ...[
                        if (i > 0) SizedBox(width: spacing),
                        Expanded(
                          child: start + i < children.length ? children[start + i] : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

- [x] **Step 7: Implement the chore sheet**

Create `lib/features/chores/chore_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/chores.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/text.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/dialogs.dart';
import 'chore_groups.dart';
import 'repeat_label.dart';

/// Opens the chore sheet: a new chore starting on [day] when [chore] is null,
/// otherwise [chore] for editing.
Future<void> showChoreSheet(BuildContext context, {Chore? chore, required DateTime day}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ChoreSheet(chore: chore, day: day),
  );
}

class ChoreSheet extends ConsumerStatefulWidget {
  const ChoreSheet({super.key, this.chore, required this.day});

  final Chore? chore;
  final DateTime day;

  @override
  ConsumerState<ChoreSheet> createState() => _ChoreSheetState();
}

class _ChoreSheetState extends ConsumerState<ChoreSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.chore?.title ?? '');
  late final TextEditingController _emoji = TextEditingController(text: widget.chore?.icon ?? '');
  late final TextEditingController _every = TextEditingController(text: '${widget.chore?.every ?? 1}');
  late final TextEditingController _monthDay =
      TextEditingController(text: '${widget.chore?.monthDay ?? widget.day.day}');
  late bool _whoChosen = widget.chore != null;
  late String? _assignee = widget.chore?.assignee;
  late String? _time = widget.chore?.time;
  late Repeat _repeat = widget.chore?.repeat ?? Repeat.daily;
  late final Set<int> _weekdays = {...?widget.chore?.weekdays};
  late DateTime _start = widget.chore == null ? dayOnly(widget.day) : parseDateKey(widget.chore!.startDate);
  late DateTime? _end = _initialEnd();
  late bool _remind = widget.chore?.remind ?? false;
  bool _showProblems = false;

  DateTime? _initialEnd() {
    final end = widget.chore?.endDate;
    return end == null ? null : parseDateKey(end);
  }

  @override
  void dispose() {
    _title.dispose();
    _emoji.dispose();
    _every.dispose();
    _monthDay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final me = ref.watch(currentUidProvider) ?? '';
    final isParent = ref.watch(isParentProvider);
    final members = [...(ref.watch(membersProvider).valueOrNull ?? const <Member>[])]..sort(compareMembers);
    final assignee = _effectiveAssignee(me, isParent, members);
    final draft = _draft(me, assignee);
    final problems = _showProblems ? validateChore(draft) : const <ChoreProblem>{};
    final chore = widget.chore;
    final canDelete = chore != null && (isParent || (chore.createdBy == me && chore.assignee == me));
    final whoOptions = isParent
        ? members
        : [
            for (final m in members)
              if (m.uid == me) m,
          ];
    final errorStyle = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(chore == null ? l.addChore : l.editChore, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const Key('choreTitle'),
              controller: _title,
              maxLength: maxChoreTitleLength,
              // Longer titles are not cut off: Save explains the limit instead.
              maxLengthEnforcement: MaxLengthEnforcement.none,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.choreTitle,
                errorText: problems.contains(ChoreProblem.blankTitle)
                    ? l.problemBlankTitle
                    : problems.contains(ChoreProblem.titleTooLong)
                        ? l.problemTitleTooLong
                        : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('choreEmoji'),
              controller: _emoji,
              decoration: InputDecoration(labelText: l.choreEmoji, hintText: '🧹'),
              onChanged: _keepOneEmoji,
            ),
            const SizedBox(height: 16),
            Text(l.who, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in whoOptions)
                  ChoiceChip(
                    key: ValueKey('choreWho-${m.uid}'),
                    label: Text(m.name),
                    selected: assignee == m.uid,
                    onSelected: (_) => setState(() {
                      _whoChosen = true;
                      _assignee = m.uid;
                    }),
                  ),
                if (isParent)
                  ChoiceChip(
                    key: const ValueKey('choreWho-anyone'),
                    label: Text(l.anyone),
                    selected: assignee == null,
                    onSelected: (_) => setState(() {
                      _whoChosen = true;
                      _assignee = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _TapField(
              key: const Key('choreTime'),
              label: l.time,
              value: _time == null ? l.noTime : formatChoreTime(context, _time!),
              onTap: _pickTime,
              trailing: _time == null
                  ? null
                  : IconButton(
                      key: const Key('choreTimeClear'),
                      tooltip: l.noTime,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _time = null;
                        _remind = false;
                      }),
                    ),
            ),
            const SizedBox(height: 16),
            Text(l.repeat, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final r in Repeat.values)
                  ChoiceChip(
                    key: ValueKey('choreRepeat-${r.name}'),
                    label: Text(_repeatName(l, r)),
                    selected: _repeat == r,
                    onSelected: (_) => _setRepeat(r),
                  ),
              ],
            ),
            if (_repeat != Repeat.once) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('choreEvery'),
                controller: _every,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.every,
                  helperText: repeatLabel(l, draft), // live preview: "Every 2 weeks · Mon, Thu"
                  helperMaxLines: 2,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_repeat == Repeat.weekly) ...[
              const SizedBox(height: 12),
              Text(l.onDays, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final d in weekOrder)
                    FilterChip(
                      key: ValueKey('choreWeekday-$d'),
                      label: Text(weekdayName(l, d)),
                      selected: _weekdays.contains(d),
                      onSelected: (on) => setState(() => on ? _weekdays.add(d) : _weekdays.remove(d)),
                    ),
                ],
              ),
              if (problems.contains(ChoreProblem.weeklyNoDays))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l.problemWeeklyNoDays, style: errorStyle),
                ),
            ],
            if (_repeat == Repeat.monthly) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('choreMonthDay'),
                controller: _monthDay,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.dayOfMonth,
                  errorText: problems.contains(ChoreProblem.badMonthDay) ? l.problemBadMonthDay : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            _TapField(
              key: const Key('choreStart'),
              label: l.startDate,
              value: longDate(l.localeName, _start),
              onTap: _pickStart,
            ),
            if (_repeat != Repeat.once) ...[
              SwitchListTile(
                key: const Key('choreEndNever'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.endsNever),
                value: _end == null,
                onChanged: (never) => setState(() => _end = never ? null : _start),
              ),
              if (_end != null)
                _TapField(
                  key: const Key('choreEndDate'),
                  label: l.endDate,
                  value: longDate(l.localeName, _end!),
                  onTap: _pickEnd,
                  errorText: problems.contains(ChoreProblem.endBeforeStart) ? l.problemEndBeforeStart : null,
                ),
            ],
            SwitchListTile(
              key: const Key('choreRemind'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.remind),
              value: _remind && _time != null,
              onChanged: _time == null ? null : _setRemind,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (canDelete)
                  TextButton(
                    key: const Key('choreDelete'),
                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    onPressed: () => _delete(l),
                    child: Text(l.delete),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('choreSave'),
                  onPressed: () => _save(me, assignee),
                  child: Text(l.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Children always make chores for themselves. A parent's new chore starts
  /// with the first child until the parent picks someone.
  String? _effectiveAssignee(String me, bool isParent, List<Member> members) {
    if (!isParent) return me;
    if (_whoChosen) return _assignee;
    for (final m in members) {
      if (m.role == Role.child) return m.uid;
    }
    return me;
  }

  Chore _draft(String me, String? assignee) {
    final emoji = _emoji.text.trim();
    final typedEvery = parseNumber(_every.text)?.round() ?? 1;
    final every = typedEvery < 1 ? 1 : (typedEvery > 99 ? 99 : typedEvery);
    return Chore(
      id: widget.chore?.id ?? '',
      title: _title.text.trim(),
      icon: emoji.isEmpty ? null : emoji.characters.first,
      assignee: assignee,
      time: _time,
      repeat: _repeat,
      every: _repeat == Repeat.once ? 1 : every,
      weekdays: _repeat == Repeat.weekly ? (_weekdays.toList()..sort()) : const [],
      monthDay: _repeat == Repeat.monthly ? parseNumber(_monthDay.text)?.round() : null,
      startDate: dateKey(_start),
      endDate: _repeat == Repeat.once || _end == null ? null : dateKey(_end!),
      remind: _remind && _time != null,
      createdBy: widget.chore?.createdBy ?? me,
    );
  }

  /// The emoji field holds one emoji: typing another replaces it.
  void _keepOneEmoji(String value) {
    final chars = value.trim().characters;
    if (chars.length > 1) {
      final last = chars.last;
      _emoji.value = TextEditingValue(text: last, selection: TextSelection.collapsed(offset: last.length));
    }
    setState(() {});
  }

  void _setRepeat(Repeat repeat) {
    setState(() {
      _repeat = repeat;
      if (repeat == Repeat.weekly && _weekdays.isEmpty) _weekdays.add(_start.weekday);
    });
  }

  void _setRemind(bool on) => setState(() => _remind = on);

  String _repeatName(AppLocalizations l, Repeat r) => switch (r) {
        Repeat.once => l.repeatOnce,
        Repeat.daily => l.repeatDaily,
        Repeat.weekly => l.repeatWeekly,
        Repeat.monthly => l.repeatMonthly,
      };

  Future<void> _pickTime() async {
    final current = _time == null ? null : parseChoreTime(_time!);
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = choreTimeKey(picked));
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
        currentDate: ref.read(todayProvider),
      );

  Future<void> _pickStart() async {
    final picked = await _pickDate(_start);
    if (picked == null || !mounted) return;
    setState(() => _start = dayOnly(picked));
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDate(_end ?? _start);
    if (picked == null || !mounted) return;
    setState(() => _end = dayOnly(picked));
  }

  void _save(String me, String? assignee) {
    final draft = _draft(me, assignee);
    if (validateChore(draft).isNotEmpty) {
      setState(() => _showProblems = true);
      return;
    }
    final repo = ref.read(choreRepositoryProvider);
    if (widget.chore == null) {
      fireAndForget(repo.addChore(draft));
    } else {
      fireAndForget(repo.updateChore(draft));
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete(AppLocalizations l) async {
    final chore = widget.chore!;
    final ok = await confirm(context, message: l.confirmDeleteChore(chore.title), confirmLabel: l.delete);
    if (!ok || !mounted) return;
    fireAndForget(ref.read(choreRepositoryProvider).deleteChore(chore.id));
    Navigator.of(context).pop();
  }
}

/// A read-only field that opens a picker when tapped.
class _TapField extends StatelessWidget {
  const _TapField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
    this.errorText,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, errorText: errorText, suffixIcon: trailing),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
```

`maxChoreTitleLength` (80) comes from `lib/core/chores.dart` (Task 4).

- [x] **Step 8: Implement the Chores tab**

Create `lib/features/chores/chores_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../../data/chore_repository.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/empty_state.dart';
import '../common/offline_chip.dart';
import 'chore_card.dart';
import 'chore_groups.dart';
import 'chore_sheet.dart';
import 'repeat_label.dart';

/// Ticks or unticks one chore for [day]. Every screen with chore cards ticks
/// through here. Writes go through [fireAndForget] and are never awaited.
Future<void> toggleChore(
  BuildContext context,
  WidgetRef ref, {
  required ChoreStatus status,
  required DateTime day,
}) async {
  final me = ref.read(currentUidProvider);
  if (me == null) return;
  final repo = ref.read(choreRepositoryProvider);
  final chore = status.chore;
  final date = dateKey(day);
  if (status.isDone) {
    fireAndForget(repo.untick(choreId: chore.id, date: date));
    return;
  }
  final isParent = ref.read(isParentProvider);
  final members = ref.read(membersProvider).valueOrNull ?? const <Member>[];
  // A parent ticking someone's chore records that person; otherwise it's me.
  final doneBy = isParent && chore.assignee != null ? chore.assignee! : me;
  fireAndForget(repo.tick(
    chore: chore,
    date: date,
    doneBy: doneBy,
    doneByName: memberById(members, doneBy)?.name ?? '',
    now: ref.read(clockProvider)(),
  ));
  _showTicked(context, repo, chore, date);
}

/// "Brush teeth done · Undo", like buying in a shopping list.
void _showTicked(BuildContext context, ChoreRepository repo, Chore chore, String date) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final l = AppLocalizations.of(context)!;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      // A SnackBar with an action stays until dismissed unless persist is false.
      persist: false,
      content: Text(l.choreTicked(chore.title)),
      action: SnackBarAction(
        label: l.undo,
        onPressed: () => fireAndForget(repo.untick(choreId: chore.id, date: date)),
      ),
    ));
}

class ChoresScreen extends ConsumerStatefulWidget {
  const ChoresScreen({super.key});

  @override
  ConsumerState<ChoresScreen> createState() => _ChoresScreenState();
}

/// What every card on the screen needs to know about the day on show.
class _DayInfo {
  const _DayInfo({
    required this.day,
    required this.today,
    required this.me,
    required this.isParent,
    required this.colors,
    required this.choreIds,
  });

  final DateTime day;
  final DateTime today;
  final String me;
  final bool isParent;
  final Map<String, int> colors;

  /// Chores that still exist. A deleted chore's done day comes back from
  /// `choresForDay` as a stand-in, which stays read-only.
  final Set<String> choreIds;

  bool get isToday => day == today;
}

class _ChoresScreenState extends ConsumerState<ChoresScreen> {
  DateTime? _day; // null: follow today
  bool? _onlyMe; // null: children start on Me, parents on Everyone

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final today = ref.watch(todayProvider);
    final day = _day ?? today;
    final me = ref.watch(currentUidProvider);
    final isParent = ref.watch(isParentProvider);
    final onlyMe = _onlyMe ?? !isParent;
    final colors = ref.watch(memberColorsProvider);
    final membersAsync = ref.watch(membersProvider);
    final choresAsync = ref.watch(choresProvider);
    final key = dateKey(day);
    final doneAsync = ref.watch(choreDoneProvider((from: key, to: key)));

    final Widget content;
    if (me != null && membersAsync.hasValue && choresAsync.hasValue && doneAsync.hasValue) {
      final members = membersAsync.requireValue;
      final chores = choresAsync.requireValue;
      final view = choresForDay(
        chores: chores,
        done: doneAsync.requireValue,
        memberUids: {for (final m in members) m.uid},
        day: day,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      final info = _DayInfo(
        day: day,
        today: today,
        me: me,
        isParent: isParent,
        colors: colors,
        choreIds: {for (final c in chores) c.id},
      );
      final groups = buildChoreGroups(view: view, members: members, me: me, isParent: isParent, onlyMe: onlyMe);
      content = _phoneList(l, info, groups);
    } else if (membersAsync.hasError || choresAsync.hasError || doneAsync.hasError) {
      content = Center(child: Text(l.somethingWentWrong));
    } else {
      content = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.tabChores), actions: const [OfflineChip()]),
      floatingActionButton: FloatingActionButton(
        key: const Key('addChore'),
        tooltip: l.addChore,
        onPressed: () => showChoreSheet(context, day: day),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _dayBar(l, day, today, onlyMe),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _dayBar(AppLocalizations l, DateTime day, DateTime today, bool onlyMe) {
    final material = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('dayPrev'),
                tooltip: material.previousPageTooltip,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _day = addDays(day, -1)),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('dayLabel'),
                  onPressed: () => _pickDay(day, today),
                  child: Text(
                    day == today ? l.today : dayTitle(l.localeName, day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                key: const Key('dayNext'),
                tooltip: material.nextPageTooltip,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _day = addDays(day, 1)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SegmentedButton<bool>(
            key: const Key('choresScope'),
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(l.everyone)),
              ButtonSegment(value: true, label: Text(l.me)),
            ],
            selected: {onlyMe},
            onSelectionChanged: (selection) => setState(() => _onlyMe = selection.first),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDay(DateTime day, DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      currentDate: today,
    );
    if (picked != null && mounted) setState(() => _day = dayOnly(picked));
  }

  Widget _phoneList(AppLocalizations l, _DayInfo info, List<ChoreGroup> groups) {
    final allEmpty = groups.every((g) => g.items.isEmpty);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), // room for the add button
      children: [
        if (allEmpty)
          EmptyState(emoji: '🎉', title: info.isToday ? l.noChoresToday : l.noChores)
        else
          for (final g in groups) _section(l, info, g),
      ],
    );
  }

  Widget _section(AppLocalizations l, _DayInfo info, ChoreGroup group) {
    final cards = [for (final s in group.items) _card(info, group, s)];
    return Padding(
      key: ValueKey('choreSection-${group.id}'),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoreGroupHeader(group: group),
          const SizedBox(height: 8),
          if (cards.isEmpty)
            Text(l.noChores, style: TextStyle(color: context.tokens.mutedText))
          else if (group.member?.pictureTiles ?? false)
            PictureTileGrid(children: cards)
          else
            for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: card),
        ],
      ),
    );
  }

  Widget _card(_DayInfo info, ChoreGroup group, ChoreStatus status) {
    final chore = status.chore;
    final exists = info.choreIds.contains(chore.id);
    final canTick =
        exists && canToggle(chore: chore, isParent: info.isParent, me: info.me, day: info.day, today: info.today);
    final canEdit = exists && (info.isParent || (chore.createdBy == info.me && chore.assignee == info.me));
    return ChoreCard(
      key: ValueKey('chore-${chore.id}'),
      status: status,
      color: _colorFor(info, group, status),
      pictureTile: group.member?.pictureTiles ?? false,
      onToggle: canTick ? () => toggleChore(context, ref, status: status, day: info.day) : null,
      onLongPress: canEdit ? () => showChoreSheet(context, chore: chore, day: info.day) : null,
    );
  }

  /// Member chores wear the member's colour. "Anyone" and former-member chores
  /// take the colour of whoever did them, and a neutral one until then.
  PersonColor _colorFor(_DayInfo info, ChoreGroup group, ChoreStatus status) {
    final theme = Theme.of(context);
    final uid = group.member?.uid ?? status.done?.doneBy;
    final index = uid == null ? null : info.colors[uid];
    return index == null ? neutralPersonColor(theme) : personColor(index, theme.brightness);
  }
}
```

- [x] **Step 9: Add the Chores tab to the bottom bar**

In `lib/app/app.dart`:

1. Add `import '../features/chores/chores_screen.dart';` to the imports (keep them sorted).
2. In `_HomeShellState.build`, replace `        children: const [TodayScreen(), ListsScreen(), FamilyScreen()],` with `        children: const [TodayScreen(), ChoresScreen(), ListsScreen(), FamilyScreen()],`
3. Directly after the line `          NavigationDestination(icon: const Icon(Icons.home_outlined), label: l.tabToday),` insert:

```dart
          NavigationDestination(icon: const Icon(Icons.task_alt), label: l.tabChores),
```

Everything else in `HomeShell` stays as Tasks 2 and 3 left it. The result reads:

```dart
      body: IndexedStack(
        index: _index,
        children: const [TodayScreen(), ChoresScreen(), ListsScreen(), FamilyScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: l.tabToday),
          NavigationDestination(icon: const Icon(Icons.task_alt), label: l.tabChores),
          NavigationDestination(icon: const Icon(Icons.checklist), label: l.tabLists),
          NavigationDestination(icon: const Icon(Icons.group), label: l.tabFamily),
        ],
      ),
```

Task 2's `test/app/home_shell_test.dart` expects exactly three tabs. In it, rename the test `'the bottom bar is Today, Lists, Family and opens on Today'` to `'the bottom bar is Today, Chores, Lists, Family and opens on Today'` and replace `    expect(labels, ['Today', 'Lists', 'Family']);` with `    expect(labels, ['Today', 'Chores', 'Lists', 'Family']);`. Nothing else in that file changes (its History test taps `Icons.checklist`, which is still the Lists tab).

- [x] **Step 10: Run the tests to verify they pass**

Run: `flutter test test/features/chores_screen_test.dart test/features/chore_sheet_test.dart test/data/write_test.dart test/app/home_shell_test.dart`
Expected: PASS

- [x] **Step 11: Run the full suite**

Run: `flutter analyze --no-fatal-infos` then `flutter test`
Expected: no errors or warnings; all tests pass, including Release 1's and Tasks 1–5's.

- [x] **Step 12: Commit**

```bash
git add lib/features/chores lib/app/app.dart lib/data/write.dart lib/l10n test/features/chores_screen_test.dart test/features/chore_sheet_test.dart test/data/write_test.dart test/app/home_shell_test.dart
git commit -m "feat(chores): chores tab, cards and chore sheet" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Tablet board (landscape columns that scroll on their own)

**Files:**
- Create: `lib/features/chores/chores_board.dart`, `test/features/chores_board_test.dart`
- Modify: `lib/features/chores/chores_screen.dart` (use the board when width ≥ 840)

**Interfaces:**
- Consumes: `ChoreGroup`, `ChoreCard`, `buildChoreGroups`, the tick/edit callbacks used by `ChoresScreen` (Task 6); `MemberAvatar` (Task 3); `personColor` (Task 1).
- Produces:
  - `class ChoresBoard extends StatelessWidget { const ChoresBoard({super.key, required this.groups, required this.cardBuilder}); final List<ChoreGroup> groups; final Widget Function(ChoreGroup group, ChoreStatus status) cardBuilder; }` — a `Row` of columns (`ValueKey('boardColumn-<groupId>')`), each with a header (avatar, name, done/total) and its own vertical `ListView` (`ValueKey('boardList-<groupId>')`); columns share the width evenly with a minimum of 260 dp; if `groups.length * 260 > width`, the row is inside a horizontal `SingleChildScrollView` (`Key('boardScroll')`).
  - `ChoresScreen` switches to `ChoresBoard` when `LayoutBuilder` width ≥ 840 (day switcher and scope toggle stay on top), and extracts its card building into a method both layouts share.
- Tests (surface 1280×800): all member columns visible side by side; scrolling one column's list does not move another's; Review Focus #4 ("nine members: board scrolls sideways and columns scroll independently"); below 840 the phone sections are used.
- Commit: `feat(chores): landscape tablet board with independent columns`

Notes:
- `ChoresScreen` already builds every card in one method (`_card`, Task 6), so the board reuses it through `cardBuilder`, and ticking, colours, picture tiles and long-press behave the same in both layouts.
- Every column's `ListView` sets `primary: false`. On Android a vertical `ListView` otherwise attaches to the route's `PrimaryScrollController`, and ten lists sharing one controller would break "each column scrolls on its own".
- The column header reuses `ChoreGroupHeader` (Task 6), which shows `MemberAvatar`. The column's top accent bar uses `personColor` of the member's colour from `memberColorsProvider`.
- `ChoresBoard.minColumnWidth` (260) is public so the tests can refer to it.
- The board tests wait with `pumpAndSettle` after drags, so a fling has fully stopped before scroll offsets are compared. Nothing on the board animates forever, and `pumpAndSettle` does not wait for timers such as Task 5's midnight timer.

- [x] **Step 1: Write the failing tests**

Create `test/features/chores_board_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/palette.dart';
import 'package:family_app/app/providers.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/features/chores/chores_board.dart';
import 'package:family_app/features/chores/chores_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<FakeFirebaseFirestore> seeded() async {
  final db = await seedFamily();
  await seedChores(db);
  return db;
}

/// A landscape tablet: 1280 × 800 dp.
void useTablet(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> addDailyChores(FakeFirebaseFirestore db, String assignee, int count) async {
  for (var i = 0; i < count; i++) {
    final chore = Chore(
      id: 'extra-$assignee-$i',
      title: 'Extra chore $i',
      assignee: assignee,
      repeat: Repeat.daily,
      startDate: '2026-09-01',
      createdBy: 'u1',
    );
    await db.doc('families/f1/chores/${chore.id}').set(chore.toMap());
  }
}

Finder column(String groupId) => find.byKey(ValueKey('boardColumn-$groupId'), skipOffstage: false);

/// How far one column's own list has scrolled.
double listOffset(WidgetTester tester, String groupId) {
  final scrollable = find
      .descendant(
        of: find.byKey(ValueKey('boardList-$groupId'), skipOffstage: false),
        matching: find.byType(Scrollable, skipOffstage: false),
        skipOffstage: false,
      )
      .first;
  return tester.state<ScrollableState>(scrollable).position.pixels;
}

void main() {
  testWidgets('on a landscape tablet every member gets a column, side by side', (tester) async {
    useTablet(tester);
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    expect(find.byKey(const Key('boardScroll')), findsNothing); // three columns fit
    expect(find.byKey(const ValueKey('choreSection-u1'), skipOffstage: false), findsNothing);
    final rects = [for (final id in ['u1', 'u2', 'anyone']) tester.getRect(column(id))];
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].top, rects[0].top);
      expect(rects[i].left, greaterThan(rects[i - 1].left));
      expect(rects[i].width, moreOrLessEquals(rects[0].width));
    }
    expect(rects[0].width, greaterThan(ChoresBoard.minColumnWidth));
    expect(rects.last.right, lessThanOrEqualTo(1280));
    expect(find.descendant(of: column('u1'), matching: find.text('Take out bins')), findsOneWidget);
    expect(find.descendant(of: column('u2'), matching: find.text('Brush teeth')), findsOneWidget);
    expect(find.descendant(of: column('u2'), matching: find.text('✓ 0/1')), findsOneWidget);
    // The day switcher and the scope toggle stay on top.
    expect(find.byKey(const Key('dayLabel')), findsOneWidget);
    expect(find.byKey(const Key('choresScope')), findsOneWidget);
  });

  testWidgets('ticking on the board works as on the phone', (tester) async {
    useTablet(tester);
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await tester.tap(find.byKey(const ValueKey('tick-brush')));
    await settle(tester);
    final data = (await db.doc('families/f1/choreDone/brush_2026-10-01').get()).data()!;
    expect(data['doneBy'], 'u2');
  });

  testWidgets('scrolling one column does not move the others', (tester) async {
    useTablet(tester);
    final db = await seeded();
    await addDailyChores(db, 'u2', 20);
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    await tester.drag(find.byKey(const ValueKey('boardList-u2')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(listOffset(tester, 'u2'), greaterThan(0));
    expect(listOffset(tester, 'u1'), 0);
    expect(listOffset(tester, 'anyone'), 0);
  });

  testWidgets('nine members: board scrolls sideways and columns scroll independently', (tester) async {
    useTablet(tester);
    final db = await seeded();
    for (var i = 3; i <= 9; i++) {
      await db.doc('families/f1/members/m$i').set({'name': 'Kid $i', 'role': 'child'});
    }
    await addDailyChores(db, 'u1', 20);
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    // Nine members share the eight palette colours: the colours wrap around.
    final container = ProviderScope.containerOf(tester.element(find.byType(ChoresScreen)));
    final colors = container.read(memberColorsProvider);
    expect(colors, hasLength(9));
    expect(colors.values.every((i) => i >= 0 && i < personPaletteSize), isTrue);
    expect(colors.values.toSet(), hasLength(personPaletteSize));

    // Ten columns (nine members and Anyone) of 260 dp do not fit in 1280 dp.
    expect(find.byKey(const Key('boardScroll')), findsOneWidget);
    for (final id in ['u1', 'm3', 'm9', 'u2', 'anyone']) {
      expect(tester.getSize(column(id)).width, ChoresBoard.minColumnWidth);
    }

    // Dad's long list scrolls; the next column stays where it was.
    await tester.drag(find.byKey(const ValueKey('boardList-u1')), const Offset(0, -300));
    await tester.pumpAndSettle();
    final dadOffset = listOffset(tester, 'u1');
    expect(dadOffset, greaterThan(0));
    expect(listOffset(tester, 'm3'), 0);

    // The board scrolls sideways to the Anyone column; Dad's list keeps its place.
    final dadLeft = tester.getTopLeft(column('u1')).dx;
    await tester.drag(find.byKey(const Key('boardScroll')), const Offset(-1500, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(column('u1')).dx, lessThan(dadLeft));
    final anyone = tester.getRect(column('anyone'));
    expect(anyone.left, greaterThanOrEqualTo(0));
    expect(anyone.right, lessThanOrEqualTo(1280));
    expect(listOffset(tester, 'u1'), dadOffset);
    expect(listOffset(tester, 'm3'), 0);
  });

  testWidgets('below 840 dp the phone sections are used', (tester) async {
    tester.view.physicalSize = const Size(839, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    expect(find.byKey(const ValueKey('choreSection-u1'), skipOffstage: false), findsOneWidget);
    expect(column('u1'), findsNothing);
  });
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/chores_board_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/features/chores/chores_board.dart'`.

- [x] **Step 3: Implement the board**

Create `lib/features/chores/chores_board.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../l10n/app_localizations.dart';
import 'chore_groups.dart';

/// The landscape tablet board: one column per member plus Anyone, side by
/// side. Each column scrolls on its own. The board scrolls sideways only when
/// the columns can't all get [minColumnWidth].
class ChoresBoard extends StatelessWidget {
  const ChoresBoard({super.key, required this.groups, required this.cardBuilder});

  final List<ChoreGroup> groups;
  final Widget Function(ChoreGroup group, ChoreStatus status) cardBuilder;

  static const double minColumnWidth = 260;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = [
          for (final g in groups)
            _BoardColumn(key: ValueKey('boardColumn-${g.id}'), group: g, cardBuilder: cardBuilder),
        ];
        if (groups.length * minColumnWidth <= constraints.maxWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final c in columns) Expanded(child: c)],
          );
        }
        return SingleChildScrollView(
          key: const Key('boardScroll'),
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            height: constraints.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final c in columns) SizedBox(width: minColumnWidth, child: c)],
            ),
          ),
        );
      },
    );
  }
}

class _BoardColumn extends ConsumerWidget {
  const _BoardColumn({super.key, required this.group, required this.cardBuilder});

  final ChoreGroup group;
  final Widget Function(ChoreGroup group, ChoreStatus status) cardBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final colors = ref.watch(memberColorsProvider);
    final member = group.member;
    final index = member == null ? null : colors[member.uid];
    final accent = index == null ? theme.colorScheme.outlineVariant : personColor(index, theme.brightness).fill;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        child: ColoredBox(
          color: tokens.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(color: accent, child: const SizedBox(height: 4)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: ChoreGroupHeader(group: group),
              ),
              Expanded(
                child: ListView(
                  key: ValueKey('boardList-${group.id}'),
                  // Each column keeps its own scroll position; none of them is
                  // the screen's primary scroll view.
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                  children: [
                    if (group.items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(l.noChores, style: TextStyle(color: tokens.mutedText)),
                      )
                    else
                      for (final s in group.items)
                        Padding(padding: const EdgeInsets.only(bottom: 8), child: cardBuilder(group, s)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [x] **Step 4: Use the board on wide screens**

In `lib/features/chores/chores_screen.dart`:

1. Add `import 'chores_board.dart';` directly after `import 'chore_sheet.dart';`.
2. Directly above the doc comment of `toggleChore` (`/// Ticks or unticks one chore for [day]. …`), add:

```dart
/// From this available width the Chores tab shows the tablet board.
const boardBreakpoint = 840.0;

```

3. In `_ChoresScreenState.build`, replace

```dart
      content = _phoneList(l, info, groups);
```

with

```dart
      content = LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= boardBreakpoint
            ? _board(info, groups)
            : _phoneList(l, info, groups),
      );
```

4. Directly after the `_phoneList` method, add:

```dart
  Widget _board(_DayInfo info, List<ChoreGroup> groups) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: ChoresBoard(groups: groups, cardBuilder: (group, status) => _card(info, group, status)),
      );
```

The day bar (day switcher and scope toggle) stays above `content`, so it is on top in both layouts.

- [x] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/chores_board_test.dart test/features/chores_screen_test.dart`
Expected: PASS (the phone tests run at the default 800 dp width, below the breakpoint).

- [x] **Step 6: Run the full suite**

Run: `flutter analyze --no-fatal-infos` then `flutter test`
Expected: no errors or warnings; all tests pass.

- [x] **Step 7: Commit**

```bash
git add lib/features/chores/chores_board.dart lib/features/chores/chores_screen.dart test/features/chores_board_test.dart
git commit -m "feat(chores): landscape tablet board with independent columns" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Ticking polish — who did it, late chores, celebration, Today chores

**Files:**
- Create: `lib/features/chores/who_did_it.dart`, `lib/features/chores/celebration.dart`, `lib/features/chores/late_strip.dart`, `test/features/chore_ticking_test.dart`, `test/features/today_chores_test.dart`
- Modify: `lib/features/chores/chores_screen.dart`, `lib/features/today/today_screen.dart`, both ARB files

**Interfaces:**
- Consumes: Tasks 1–7; `lateChores`, `choreDoneProvider`, `todayProvider`, `canToggle`, `progressOf`, `choresForDay`, `MemberAvatar(progress:)`.
- Produces:
  - `Future<Member?> showWhoDidIt(BuildContext context, List<Member> members)` — bottom sheet with `ValueKey('whoDid-<uid>')` rows; used when a parent ticks an "anyone" chore (a child's tick of an anyone chore records the child without asking).
  - `void celebrate(BuildContext context, {bool big = false})` — overlay emoji burst (~900 ms; 8 emoji normal, 24 big) plus `HapticFeedback.lightImpact()` (`mediumImpact` when big); does nothing visual when `MediaQuery.disableAnimationsOf(context)` is true (haptic still fires). Called after a tick (never after untick); `big` when that tick completes all of the person's chores for the day.
  - `class LateStrip extends ConsumerWidget { const LateStrip({super.key, required this.onlyMine}); final bool onlyMine; }` — key `Key('lateStrip')`; hidden when empty; lists late chores from `lateChores(today: todayProvider)` over `choreDoneProvider((from: dateKey(addDays(today,-60)), to: dateKey(today)))` using the late colours from `AppTokens`; each card ticks the chore for its late `date` (same who-did-it rules). `onlyMine`: my chores and anyone chores.
  - Children see past days read-only except yesterday (via `canToggle`); parents can tick/untick any day.
  - Today screen, inserted between header and shopping: `Key('todayMembers')` row of `MemberAvatar(progress:)` with "done/total" for today; `LateStrip(onlyMine: true)`; `Key('todayMyChores')` section with my chores for today using `ChoreCard` (tick works the same as on the Chores tab).
  - New l10n keys: `late`, `lateSince` ({date}), `whoDidIt`, `yourChores`, `allDone`.
- Commit: `feat(chores): who did it, late chores, celebration and Today chores`

Notes:
- **Late ticks for children.** A child may only tick for today or yesterday (`canToggle`, and the Task 5 rules), but a late chore is usually older. So the strip ticks for the late date when `canToggle` allows it (parents, or a child when the late date is yesterday), and otherwise for **today**. A done record dated today also clears the chore from `lateChores` ("no done record dated after that occurrence up to and including today"). A child can therefore clear "Order blinds" (late since 28 Sep): it is recorded as `blinds_2026-10-01`. `lateTickDay` in `late_strip.dart` holds this rule. See INTERFACE ISSUES.
- "Children see past days read-only except yesterday; parents can tick/untick any day" is already built into Task 6's cards through `canToggle`, and tested there ("past days: a child can change yesterday but not the day before", "parents can correct any past day"). This task adds no code for it.
- `big` is decided by `toggleChore` from `siblings`, the other chores of the same person that day. The Chores tab passes the member's group; Today passes my chores. "Anyone" chores and late-strip ticks belong to no one person's day, so they always get the normal burst.
- The burst is an `OverlayEntry` driven by an `AnimationController`, not by a `Timer`. When a test ends, the tree is torn down and the controller is disposed, so no timer is left pending. The burst is wrapped in `IgnorePointer`, so it never blocks the next tap (the Undo button included).
- `choresForDay` and `lateChores` get `languageCode: Localizations.localeOf(context).languageCode`.
- **Coming back after midnight (orchestrator update):** `todayProvider` (Task 5) moves on with a midnight timer, but that timer can fire late on a sleeping phone. `TodayChores` registers an `AppLifecycleListener(onResume: () => ref.invalidate(todayProvider))` and disposes it with the widget. It sits on the Today tab, which `HomeShell`'s `IndexedStack` keeps alive, so the listener lives as long as the app shell. Today's date line (Task 2's `_TodayHeader`) now reads `todayProvider` instead of `clockProvider`, so the date and the chores under it always agree.

- [ ] **Step 1: Write the failing tests**

Create `test/features/chore_ticking_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/features/chores/chores_screen.dart';
import 'package:family_app/features/chores/late_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<FakeFirebaseFirestore> seeded() async {
  final db = await seedFamily();
  await seedChores(db);
  return db;
}

Future<void> addChore(FakeFirebaseFirestore db, Chore chore) =>
    db.doc('families/f1/chores/${chore.id}').set(chore.toMap());

Future<bool> isDone(FakeFirebaseFirestore db, String doneId) async =>
    (await db.doc('families/f1/choreDone/$doneId').get()).exists;

/// Scrolls the widget into view (clear of the add button) before tapping it.
Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key, skipOffstage: false));
  await settle(tester);
  await tester.tap(find.byKey(key));
  await settle(tester);
}

/// Emoji in the celebration burst on screen now (0 when there is none).
int burstSize(WidgetTester tester) => find
    .descendant(of: find.byKey(const Key('celebration')), matching: find.byType(Text))
    .evaluate()
    .length;

/// An "anyone" chore that starts today, so it is never late in these tests.
const dishes = Chore(
  id: 'dishes',
  title: 'Wash dishes',
  repeat: Repeat.daily,
  startDate: '2026-10-01',
  createdBy: 'u1',
);

/// A second chore for Sara, so ticking one is not yet "all done".
const readBook = Chore(
  id: 'read',
  title: 'Read a book',
  assignee: 'u2',
  repeat: Repeat.daily,
  startDate: '2026-09-01',
  createdBy: 'u2',
);

void main() {
  testWidgets('a parent ticking an anyone chore picks who did it', (tester) async {
    final db = await seeded();
    await addChore(db, dishes);
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-dishes'));
    expect(find.text('Who did it?'), findsOneWidget);
    expect(find.byKey(const ValueKey('whoDid-u1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('whoDid-u2')));
    await settle(tester);

    final data = (await db.doc('families/f1/choreDone/dishes_2026-10-01').get()).data()!;
    expect(data['doneBy'], 'u2');
    expect(data['doneByName'], 'Sara');
    expect(data['choreTitle'], 'Wash dishes');
    expect(data['assignee'], isNull);
  });

  testWidgets('closing "who did it?" ticks nothing', (tester) async {
    final db = await seeded();
    await addChore(db, dishes);
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-dishes'));
    await tester.tapAt(const Offset(400, 10)); // the dimmed area above the sheet
    await settle(tester);
    expect(find.text('Who did it?'), findsNothing);
    expect(await isDone(db, 'dishes_2026-10-01'), isFalse);
  });

  testWidgets('a child ticking an anyone chore is recorded as themselves without asking', (tester) async {
    final db = await seeded();
    await addChore(db, dishes);
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-dishes'));
    expect(find.text('Who did it?'), findsNothing);
    final data = (await db.doc('families/f1/choreDone/dishes_2026-10-01').get()).data()!;
    expect(data['doneBy'], 'u2');
    expect(data['doneByName'], 'Sara');
  });

  testWidgets("ticking celebrates; finishing a person's day celebrates big; unticking does not", (tester) async {
    final db = await seeded();
    await addChore(db, readBook);
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-brush')); // one of Sara's two chores
    expect(burstSize(tester), 8);
    await tester.pump(const Duration(seconds: 1)); // the burst lasts ~900 ms
    await settle(tester);
    expect(find.byKey(const Key('celebration')), findsNothing);

    await tapKey(tester, const ValueKey('tick-read')); // her last one for today
    expect(burstSize(tester), 24);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    await tapKey(tester, const ValueKey('tick-read')); // untick
    expect(find.byKey(const Key('celebration')), findsNothing);
    expect(await isDone(db, 'read_2026-10-01'), isFalse);
  });

  testWidgets('with animations off there is no burst, only a vibration', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
    await tapKey(tester, const ValueKey('tick-brush')); // Sara's only chore: the big one
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('celebration')), findsNothing);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    expect(await isDone(db, 'brush_2026-10-01'), isTrue);
  });

  testWidgets('the Chores tab shows late chores only when viewing today', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    expect(find.byType(LateStrip), findsOneWidget);
    final strip = find.byKey(const Key('lateStrip'), skipOffstage: false);
    for (final title in ['Order blinds', 'Water plants']) {
      expect(
        find.descendant(of: strip, matching: find.text(title, skipOffstage: false), skipOffstage: false),
        findsOneWidget,
      );
    }
    await tapKey(tester, const Key('dayPrev'));
    expect(find.byKey(const Key('lateStrip'), skipOffstage: false), findsNothing);
  });

  testWidgets('a parent ticks a late anyone chore for its own date', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-plants')); // late since Saturday 26 Sep
    await tester.tap(find.byKey(const ValueKey('whoDid-u2')));
    await settle(tester);

    final data = (await db.doc('families/f1/choreDone/plants_2026-09-26').get()).data()!;
    expect(data['doneBy'], 'u2');
    expect(data['doneByName'], 'Sara');
    expect(find.byKey(const ValueKey('lateChore-plants'), skipOffstage: false), findsNothing);
  });
}
```

Create `test/features/today_chores_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/providers.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/dates.dart';
import 'package:family_app/features/chores/chore_card.dart';
import 'package:family_app/features/today/today_screen.dart';
import 'package:family_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<FakeFirebaseFirestore> seeded() async {
  final db = await seedFamily();
  await seedChores(db);
  return db;
}

Future<bool> isDone(FakeFirebaseFirestore db, String doneId) async =>
    (await db.doc('families/f1/choreDone/$doneId').get()).exists;

Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key, skipOffstage: false));
  await settle(tester);
  await tester.tap(find.byKey(key));
  await settle(tester);
}

Finder byKey(Key key) => find.byKey(key, skipOffstage: false);

Finder inside(Finder parent, String text) => find.descendant(
      of: parent,
      matching: find.text(text, skipOffstage: false),
      skipOffstage: false,
    );

ChoreCard cardOf(WidgetTester tester, String choreId) =>
    tester.widget<ChoreCard>(byKey(ValueKey('chore-$choreId')));

Widget arabic(Widget child) => Builder(
      builder: (context) =>
          Localizations.override(context: context, locale: const Locale('ar'), child: child),
    );

/// Tells the app it went to the background or came back, as Android does.
Future<void> sendLifecycle(WidgetTester tester, AppLifecycleState state) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
      (_) {},
    );

void main() {
  testWidgets("Today shows everyone's progress, late chores and my chores", (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const TodayScreen());

    expect(inside(byKey(const ValueKey('todayMember-u1')), '✓ 0/1'), findsOneWidget); // Dad: bins
    expect(inside(byKey(const ValueKey('todayMember-u2')), '✓ 0/1'), findsOneWidget); // Sara: brush
    expect(inside(byKey(const Key('todayMembers')), '✓ 0/1'), findsNWidgets(2));

    final strip = byKey(const Key('lateStrip'));
    expect(inside(strip, 'Water plants'), findsOneWidget);
    expect(inside(strip, 'Anyone · Late since 26 Sep'), findsOneWidget);
    expect(inside(strip, 'Order blinds'), findsOneWidget);
    expect(inside(strip, 'Anyone · Late since 28 Sep'), findsOneWidget);
    expect(
      tester.getTopLeft(byKey(const ValueKey('lateChore-plants'))).dy,
      lessThan(tester.getTopLeft(byKey(const ValueKey('lateChore-blinds'))).dy),
    );

    final mine = byKey(const Key('todayMyChores'));
    expect(inside(mine, 'Your chores'), findsOneWidget);
    expect(inside(mine, 'Brush teeth'), findsOneWidget);
    expect(find.text('Take out bins', skipOffstage: false), findsNothing);
  });

  testWidgets('ticking on Today updates my progress and says all done', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const TodayScreen());

    await tapKey(tester, const ValueKey('tick-brush'));
    expect(await isDone(db, 'brush_2026-10-01'), isTrue);
    expect(find.text('All done for today! 🎉', skipOffstage: false), findsOneWidget);
    expect(inside(byKey(const ValueKey('todayMember-u2')), '✓ 1/1'), findsOneWidget);
    expect(cardOf(tester, 'brush').status.isDone, isTrue);
  });

  testWidgets('a child clears an old late chore; it is recorded for today', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const TodayScreen());

    await tapKey(tester, const ValueKey('tick-blinds')); // late since 28 Sep: too old for a child's own date
    final data = (await db.doc('families/f1/choreDone/blinds_2026-10-01').get()).data()!;
    expect(data['doneBy'], 'u2');
    expect(await isDone(db, 'blinds_2026-09-28'), isFalse);
    expect(byKey(const ValueKey('lateChore-blinds')), findsNothing);
    expect(byKey(const ValueKey('lateChore-plants')), findsOneWidget);
  });

  testWidgets('the late strip is hidden when nothing is late', (tester) async {
    final db = await seeded();
    for (final done in [
      ChoreDone(
        choreId: 'plants',
        date: '2026-09-26',
        choreTitle: 'Water plants',
        doneBy: 'u1',
        doneByName: 'Dad',
        dayNumber: dayNumberOf(DateTime(2026, 9, 26)),
      ),
      ChoreDone(
        choreId: 'blinds',
        date: '2026-09-28',
        choreTitle: 'Order blinds',
        doneBy: 'u1',
        doneByName: 'Dad',
        dayNumber: dayNumberOf(DateTime(2026, 9, 28)),
      ),
    ]) {
      await db.doc('families/f1/choreDone/${done.id}').set(done.toMap());
    }
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const TodayScreen());
    expect(byKey(const Key('lateStrip')), findsNothing);
    expect(byKey(const Key('todayMyChores')), findsOneWidget);
  });

  testWidgets('coming back to the app after midnight shows the new day', (tester) async {
    final db = await seeded();
    var now = DateTime(2026, 10, 1, 20);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        currentUidProvider.overrideWithValue('u2'),
        authReadyProvider.overrideWithValue(true),
        authPhotoUrlProvider.overrideWithValue(null),
        clockProvider.overrideWithValue(() => now), // a clock this test can move
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TodayScreen(),
      ),
    ));
    await settle(tester);
    expect(find.text('Thursday, October 1'), findsOneWidget);
    await tapKey(tester, const ValueKey('tick-brush'));
    expect(find.text('All done for today! 🎉', skipOffstage: false), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); // let the burst finish
    await settle(tester);

    // The phone slept past midnight and the midnight timer has not fired yet.
    now = DateTime(2026, 10, 2, 7, 30);
    await sendLifecycle(tester, AppLifecycleState.paused);
    await sendLifecycle(tester, AppLifecycleState.resumed);
    await settle(tester);
    expect(find.text('Friday, October 2'), findsOneWidget);
    expect(find.text('All done for today! 🎉', skipOffstage: false), findsNothing);
    expect(cardOf(tester, 'brush').status.isDone, isFalse); // 2 Oct's brush is not done yet
  });

  testWidgets('Today fits small phones in Arabic', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final size in const [Size(320, 640), Size(360, 740)]) {
      for (final scale in const [1.0, 1.3]) {
        for (final pictureTiles in const [false, true]) {
          final label = '$size, text x$scale, picture tiles $pictureTiles';
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          final db = await seeded();
          await db.doc('families/f1/chores/brush').update({
            'title': 'ترتيب غرفة النوم وتنظيف المكتب وجمع الألعاب قبل موعد النوم',
          });
          await db.doc('families/f1/members/u2').update({'pictureTiles': pictureTiles});
          await pumpWithFamily(tester, db: db, uid: 'u2', child: arabic(const TodayScreen()));
          expect(tester.takeException(), isNull, reason: label);
          expect(byKey(const Key('todayMyChores')), findsOneWidget, reason: label);
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/chore_ticking_test.dart test/features/today_chores_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:family_app/features/chores/late_strip.dart'` in `chore_ticking_test.dart`; in `today_chores_test.dart`, `Key('todayMembers')` and the other chores parts are not found.

- [ ] **Step 3: Add the strings**

In `lib/l10n/app_en.arb`, add a comma after the current last entry and append:

```json
  "late": "Late",
  "lateSince": "Late since {date}",
  "@lateSince": { "placeholders": { "date": { "type": "String" } } },
  "whoDidIt": "Who did it?",
  "yourChores": "Your chores",
  "allDone": "All done for today! 🎉"
```

In `lib/l10n/app_ar.arb`, add a comma after the current last entry and append:

```json
  "late": "متأخرة",
  "lateSince": "متأخرة منذ {date}",
  "whoDidIt": "من قام بها؟",
  "yourChores": "مهامك",
  "allDone": "أنجزت كل مهام اليوم! 🎉"
```

Run: `flutter gen-l10n`
Expected: no errors. (`late` is a built-in identifier in Dart, not a reserved word, so `String get late` is a valid getter.)

- [ ] **Step 4: Implement "who did it?" and the celebration**

Create `lib/features/chores/who_did_it.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/member_avatar.dart';

/// Asks a parent who did an "anyone" chore. Null when the sheet is closed.
Future<Member?> showWhoDidIt(BuildContext context, List<Member> members) {
  return showModalBottomSheet<Member>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final l = AppLocalizations.of(sheetContext)!;
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.whoDidIt, style: Theme.of(sheetContext).textTheme.titleLarge),
          ),
          for (final m in members)
            ListTile(
              key: ValueKey('whoDid-${m.uid}'),
              leading: MemberAvatar(member: m),
              title: Text(m.name),
              onTap: () => Navigator.of(sheetContext).pop(m),
            ),
        ],
      );
    },
  );
}
```

Create `lib/features/chores/celebration.dart`:

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _burstEmoji = ['🎉', '⭐', '✨', '🌟', '💫', '🎊'];

/// A short emoji burst over the screen and a light vibration; a bigger burst
/// and a stronger vibration when [big]. With "remove animations" on in the
/// phone's settings there is no burst, only the vibration.
void celebrate(BuildContext context, {bool big = false}) {
  unawaited(big ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact());
  if (MediaQuery.disableAnimationsOf(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Burst(
      count: big ? 24 : 8,
      big: big,
      onDone: () {
        entry.remove();
        entry.dispose();
      },
    ),
  );
  overlay.insert(entry);
}

class _Burst extends StatefulWidget {
  const _Burst({required this.count, required this.big, required this.onDone});

  final int count;
  final bool big;
  final VoidCallback onDone;

  @override
  State<_Burst> createState() => _BurstState();
}

/// Driven by an AnimationController, not a Timer: tearing the screen down
/// disposes it, so nothing is left pending.
class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reach = widget.big ? 0.9 : 0.55;
    return Positioned.fill(
      key: const Key('celebration'),
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Material(
            type: MaterialType.transparency,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_controller.value);
                return Stack(
                  children: [
                    for (var i = 0; i < widget.count; i++)
                      Align(
                        alignment: Alignment(
                          math.cos(2 * math.pi * i / widget.count) * reach * t,
                          -0.1 + math.sin(2 * math.pi * i / widget.count) * reach * t,
                        ),
                        child: Opacity(
                          opacity: 1 - _controller.value,
                          child: Text(
                            _burstEmoji[i % _burstEmoji.length],
                            style: TextStyle(fontSize: widget.big ? 34 : 28),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implement the late strip**

Create `lib/features/chores/late_strip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import 'chore_card.dart';
import 'chore_groups.dart';
import 'chores_screen.dart';
import 'repeat_label.dart';

/// Late chores wear the theme's red "late" colours.
PersonColor latePersonColor(AppTokens tokens) => PersonColor(
      fill: tokens.late,
      onFill: tokens.lateTint,
      tint: tokens.lateTint,
      onTint: tokens.onLateTint,
    );

/// The day a late chore's tick is recorded for: its own late [date] when
/// allowed (parents; children when it was yesterday), otherwise today. Children
/// may only tick today or yesterday, and a record dated today also clears the
/// chore from [lateChores]. Null when the chore can't be ticked at all.
DateTime? lateTickDay({
  required Chore chore,
  required String date,
  required bool isParent,
  required String me,
  required DateTime today,
}) {
  final lateDay = parseDateKey(date);
  if (canToggle(chore: chore, isParent: isParent, me: me, day: lateDay, today: today)) return lateDay;
  if (canToggle(chore: chore, isParent: isParent, me: me, day: today, today: today)) return today;
  return null;
}

/// The red strip of late chores (one-time and "anyone" chores nobody did).
/// With [onlyMine], only my chores and "anyone" chores.
class LateStrip extends ConsumerWidget {
  const LateStrip({super.key, required this.onlyMine});

  final bool onlyMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final today = ref.watch(todayProvider);
    final me = ref.watch(currentUidProvider);
    final isParent = ref.watch(isParentProvider);
    final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];
    final chores = ref.watch(choresProvider).valueOrNull;
    final done = ref
        .watch(choreDoneProvider((from: dateKey(addDays(today, -60)), to: dateKey(today))))
        .valueOrNull;
    if (me == null || chores == null || done == null) return const SizedBox.shrink();

    final overdue = [
      for (final item in lateChores(
        chores: chores,
        done: done,
        today: today,
        languageCode: Localizations.localeOf(context).languageCode,
      ))
        if (!onlyMine || item.chore.isAnyone || item.chore.assignee == me) item,
    ];
    if (overdue.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tokens = context.tokens;
    final color = latePersonColor(tokens);
    return Padding(
      key: const Key('lateStrip'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: tokens.late),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.late,
                  style: theme.textTheme.titleMedium?.copyWith(color: tokens.late, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in overdue)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ChoreCard(
                    key: ValueKey('lateChore-${item.chore.id}'),
                    status: ChoreStatus(item.chore, null),
                    color: color,
                    pictureTile: false,
                    late: true,
                    onToggle: _onToggle(context, ref, item, isParent: isParent, me: me, today: today),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12, top: 2),
                    child: Text(
                      '${_who(l, members, item.chore)} · '
                      '${l.lateSince(shortDate(l.localeName, parseDateKey(item.date)))}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedText),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _who(AppLocalizations l, List<Member> members, Chore chore) {
    if (chore.isAnyone) return l.anyone;
    return memberById(members, chore.assignee)?.name ?? l.formerMember;
  }

  VoidCallback? _onToggle(
    BuildContext context,
    WidgetRef ref,
    LateChore item, {
    required bool isParent,
    required String me,
    required DateTime today,
  }) {
    final day = lateTickDay(chore: item.chore, date: item.date, isParent: isParent, me: me, today: today);
    if (day == null) return null;
    return () => toggleChore(context, ref, status: ChoreStatus(item.chore, null), day: day);
  }
}
```

- [ ] **Step 6: Wire who-did-it, the celebration and the late strip into the Chores tab**

Replace `lib/features/chores/chores_screen.dart` with (Task 6's screen plus Task 7's board, now with "who did it?", celebrations and the late strip):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../../data/chore_repository.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/empty_state.dart';
import '../common/offline_chip.dart';
import 'celebration.dart';
import 'chore_card.dart';
import 'chore_groups.dart';
import 'chore_sheet.dart';
import 'chores_board.dart';
import 'late_strip.dart';
import 'repeat_label.dart';
import 'who_did_it.dart';

/// From this available width the Chores tab shows the tablet board.
const boardBreakpoint = 840.0;

/// Ticks or unticks one chore for [day]. Every screen with chore cards ticks
/// through here. Writes go through [fireAndForget] and are never awaited.
///
/// A parent ticking an "anyone" chore is asked who did it; a child is recorded
/// as themselves. A tick celebrates, and the celebration is the big one when the
/// tick completes all of [siblings] (that person's chores for the day).
Future<void> toggleChore(
  BuildContext context,
  WidgetRef ref, {
  required ChoreStatus status,
  required DateTime day,
  List<ChoreStatus> siblings = const [],
}) async {
  final me = ref.read(currentUidProvider);
  if (me == null) return;
  final repo = ref.read(choreRepositoryProvider);
  final chore = status.chore;
  final date = dateKey(day);
  if (status.isDone) {
    fireAndForget(repo.untick(choreId: chore.id, date: date));
    return;
  }
  final isParent = ref.read(isParentProvider);
  final members = [...(ref.read(membersProvider).valueOrNull ?? const <Member>[])]..sort(compareMembers);
  final now = ref.read(clockProvider)();
  final String doneBy;
  if (chore.isAnyone && isParent) {
    final who = await showWhoDidIt(context, members);
    if (!context.mounted) return;
    if (who == null) return;
    doneBy = who.uid;
  } else {
    // A parent ticking someone's chore records that person; otherwise it's me.
    doneBy = isParent && chore.assignee != null ? chore.assignee! : me;
  }
  fireAndForget(repo.tick(
    chore: chore,
    date: date,
    doneBy: doneBy,
    doneByName: memberById(members, doneBy)?.name ?? '',
    now: now,
  ));
  final big = !chore.isAnyone &&
      siblings.isNotEmpty &&
      siblings.every((s) => s.isDone || s.chore.id == chore.id);
  celebrate(context, big: big);
  _showTicked(context, repo, chore, date);
}

/// "Brush teeth done · Undo", like buying in a shopping list.
void _showTicked(BuildContext context, ChoreRepository repo, Chore chore, String date) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final l = AppLocalizations.of(context)!;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      // A SnackBar with an action stays until dismissed unless persist is false.
      persist: false,
      content: Text(l.choreTicked(chore.title)),
      action: SnackBarAction(
        label: l.undo,
        onPressed: () => fireAndForget(repo.untick(choreId: chore.id, date: date)),
      ),
    ));
}

class ChoresScreen extends ConsumerStatefulWidget {
  const ChoresScreen({super.key});

  @override
  ConsumerState<ChoresScreen> createState() => _ChoresScreenState();
}

/// What every card on the screen needs to know about the day on show.
class _DayInfo {
  const _DayInfo({
    required this.day,
    required this.today,
    required this.me,
    required this.isParent,
    required this.colors,
    required this.choreIds,
  });

  final DateTime day;
  final DateTime today;
  final String me;
  final bool isParent;
  final Map<String, int> colors;

  /// Chores that still exist. A deleted chore's done day comes back from
  /// `choresForDay` as a stand-in, which stays read-only.
  final Set<String> choreIds;

  bool get isToday => day == today;
}

class _ChoresScreenState extends ConsumerState<ChoresScreen> {
  DateTime? _day; // null: follow today
  bool? _onlyMe; // null: children start on Me, parents on Everyone

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final today = ref.watch(todayProvider);
    final day = _day ?? today;
    final me = ref.watch(currentUidProvider);
    final isParent = ref.watch(isParentProvider);
    final onlyMe = _onlyMe ?? !isParent;
    final colors = ref.watch(memberColorsProvider);
    final membersAsync = ref.watch(membersProvider);
    final choresAsync = ref.watch(choresProvider);
    final key = dateKey(day);
    final doneAsync = ref.watch(choreDoneProvider((from: key, to: key)));

    final Widget content;
    if (me != null && membersAsync.hasValue && choresAsync.hasValue && doneAsync.hasValue) {
      final members = membersAsync.requireValue;
      final chores = choresAsync.requireValue;
      final view = choresForDay(
        chores: chores,
        done: doneAsync.requireValue,
        memberUids: {for (final m in members) m.uid},
        day: day,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      final info = _DayInfo(
        day: day,
        today: today,
        me: me,
        isParent: isParent,
        colors: colors,
        choreIds: {for (final c in chores) c.id},
      );
      final groups = buildChoreGroups(view: view, members: members, me: me, isParent: isParent, onlyMe: onlyMe);
      content = LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= boardBreakpoint
            ? _board(info, groups, onlyMe)
            : _phoneList(l, info, groups, onlyMe),
      );
    } else if (membersAsync.hasError || choresAsync.hasError || doneAsync.hasError) {
      content = Center(child: Text(l.somethingWentWrong));
    } else {
      content = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.tabChores), actions: const [OfflineChip()]),
      floatingActionButton: FloatingActionButton(
        key: const Key('addChore'),
        tooltip: l.addChore,
        onPressed: () => showChoreSheet(context, day: day),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _dayBar(l, day, today, onlyMe),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _dayBar(AppLocalizations l, DateTime day, DateTime today, bool onlyMe) {
    final material = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('dayPrev'),
                tooltip: material.previousPageTooltip,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _day = addDays(day, -1)),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('dayLabel'),
                  onPressed: () => _pickDay(day, today),
                  child: Text(
                    day == today ? l.today : dayTitle(l.localeName, day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                key: const Key('dayNext'),
                tooltip: material.nextPageTooltip,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _day = addDays(day, 1)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SegmentedButton<bool>(
            key: const Key('choresScope'),
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(l.everyone)),
              ButtonSegment(value: true, label: Text(l.me)),
            ],
            selected: {onlyMe},
            onSelectionChanged: (selection) => setState(() => _onlyMe = selection.first),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDay(DateTime day, DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      currentDate: today,
    );
    if (picked != null && mounted) setState(() => _day = dayOnly(picked));
  }

  Widget _phoneList(AppLocalizations l, _DayInfo info, List<ChoreGroup> groups, bool onlyMe) {
    final allEmpty = groups.every((g) => g.items.isEmpty);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), // room for the add button
      children: [
        if (info.isToday) LateStrip(onlyMine: onlyMe),
        if (allEmpty)
          EmptyState(emoji: '🎉', title: info.isToday ? l.noChoresToday : l.noChores)
        else
          for (final g in groups) _section(l, info, g),
      ],
    );
  }

  Widget _board(_DayInfo info, List<ChoreGroup> groups, bool onlyMe) {
    return Column(
      children: [
        if (info.isToday)
          ConstrainedBox(
            // The board keeps most of the height; a long late list scrolls.
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              primary: false,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LateStrip(onlyMine: onlyMe),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: ChoresBoard(groups: groups, cardBuilder: (group, status) => _card(info, group, status)),
          ),
        ),
      ],
    );
  }

  Widget _section(AppLocalizations l, _DayInfo info, ChoreGroup group) {
    final cards = [for (final s in group.items) _card(info, group, s)];
    return Padding(
      key: ValueKey('choreSection-${group.id}'),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoreGroupHeader(group: group),
          const SizedBox(height: 8),
          if (cards.isEmpty)
            Text(l.noChores, style: TextStyle(color: context.tokens.mutedText))
          else if (group.member?.pictureTiles ?? false)
            PictureTileGrid(children: cards)
          else
            for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: card),
        ],
      ),
    );
  }

  Widget _card(_DayInfo info, ChoreGroup group, ChoreStatus status) {
    final chore = status.chore;
    final exists = info.choreIds.contains(chore.id);
    final canTick =
        exists && canToggle(chore: chore, isParent: info.isParent, me: info.me, day: info.day, today: info.today);
    final canEdit = exists && (info.isParent || (chore.createdBy == info.me && chore.assignee == info.me));
    return ChoreCard(
      key: ValueKey('chore-${chore.id}'),
      status: status,
      color: _colorFor(info, group, status),
      pictureTile: group.member?.pictureTiles ?? false,
      onToggle: canTick
          ? () => toggleChore(
                context,
                ref,
                status: status,
                day: info.day,
                siblings: group.member == null ? const [] : group.items,
              )
          : null,
      onLongPress: canEdit ? () => showChoreSheet(context, chore: chore, day: info.day) : null,
    );
  }

  /// Member chores wear the member's colour. "Anyone" and former-member chores
  /// take the colour of whoever did them, and a neutral one until then.
  PersonColor _colorFor(_DayInfo info, ChoreGroup group, ChoreStatus status) {
    final theme = Theme.of(context);
    final uid = group.member?.uid ?? status.done?.doneBy;
    final index = uid == null ? null : info.colors[uid];
    return index == null ? neutralPersonColor(theme) : personColor(index, theme.brightness);
  }
}
```

- [ ] **Step 7: Add the chores parts to Today**

In `lib/features/today/today_screen.dart` (as Task 2 left it):

1. Add these imports (Task 2's file has none of them; keep the import groups sorted):

```dart
import '../../app/palette.dart';
import '../../core/chores.dart';
import '../../core/dates.dart';
import '../chores/chore_card.dart';
import '../chores/chore_groups.dart';
import '../chores/chore_sheet.dart';
import '../chores/chores_screen.dart';
import '../chores/late_strip.dart';
import '../common/member_avatar.dart';
```

2. In `TodayScreen.build`, replace the line

```dart
      // Chores sections go here (between the header and shopping).
```

with

```dart
      const TodayChores(),
```

3. The date line must move on with `todayProvider` too (otherwise, after the app comes back past midnight, the chores show the new day under yesterday's date). In `_TodayHeader.build`, replace

```dart
    final now = ref.watch(clockProvider)();
    return Text(
      DateFormat.MMMMEEEEd(lang).format(now),
```

with

```dart
    final today = ref.watch(todayProvider);
    return Text(
      DateFormat.MMMMEEEEd(lang).format(today),
```

(Only the header. `_ListSummaryCard` keeps `ref.watch(clockProvider)()`, since it needs the time as well as the date.)

4. Append to the end of the file:

```dart
/// Today's chores: everyone's progress, my late chores and my chores for today.
class TodayChores extends ConsumerStatefulWidget {
  const TodayChores({super.key});

  @override
  ConsumerState<TodayChores> createState() => _TodayChoresState();
}

class _TodayChoresState extends ConsumerState<TodayChores> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The midnight timer can fire late on a sleeping phone, so check the date
    // again whenever the app comes back to the foreground.
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(todayProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final me = ref.watch(currentUidProvider);
    final isParent = ref.watch(isParentProvider);
    final colors = ref.watch(memberColorsProvider);
    final members = ref.watch(membersProvider).valueOrNull;
    final chores = ref.watch(choresProvider).valueOrNull;
    final key = dateKey(today);
    final done = ref.watch(choreDoneProvider((from: key, to: key))).valueOrNull;
    if (me == null || members == null || chores == null || done == null) return const SizedBox.shrink();

    final view = choresForDay(
      chores: chores,
      done: done,
      memberUids: {for (final m in members) m.uid},
      day: today,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    final people = [
      for (final g in buildChoreGroups(view: view, members: members, me: me, isParent: isParent, onlyMe: false))
        if (g.member != null) g,
    ];
    final choreIds = {for (final c in chores) c.id};
    final mine = view.byMember[me] ?? const <ChoreStatus>[];
    final myProgress = progressOf(mine);
    final myColorIndex = colors[me];
    final myColor = myColorIndex == null ? neutralPersonColor(theme) : personColor(myColorIndex, theme.brightness);
    final pictureTiles = memberById(members, me)?.pictureTiles ?? false;
    final cards = [
      for (final s in mine)
        ChoreCard(
          key: ValueKey('chore-${s.chore.id}'),
          status: s,
          color: myColor,
          pictureTile: pictureTiles,
          onToggle: choreIds.contains(s.chore.id) &&
                  canToggle(chore: s.chore, isParent: isParent, me: me, day: today, today: today)
              ? () => toggleChore(context, ref, status: s, day: today, siblings: mine)
              : null,
          onLongPress: choreIds.contains(s.chore.id) &&
                  (isParent || (s.chore.createdBy == me && s.chore.assignee == me))
              ? () => showChoreSheet(context, chore: s.chore, day: today)
              : null,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          key: const Key('todayMembers'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              for (final g in people) _MemberProgress(member: g.member!, items: g.items),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const LateStrip(onlyMine: true),
        Column(
          key: const Key('todayMyChores'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.yourChores, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (mine.isEmpty)
              Text(l.noChoresToday, style: TextStyle(color: context.tokens.mutedText))
            else ...[
              if (myProgress.done == myProgress.total)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(l.allDone, style: theme.textTheme.titleSmall),
                ),
              if (pictureTiles)
                PictureTileGrid(children: cards)
              else
                for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: card),
            ],
          ],
        ),
      ],
    );
  }
}

/// One member's avatar with a progress ring and "✓ done/total" for today.
class _MemberProgress extends StatelessWidget {
  const _MemberProgress({required this.member, required this.items});

  final Member member;
  final List<ChoreStatus> items;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final progress = progressOf(items);
    return Padding(
      key: ValueKey('todayMember-${member.uid}'),
      padding: const EdgeInsetsDirectional.only(end: 16),
      child: Semantics(
        label: member.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemberAvatar(
              member: member,
              size: 48,
              progress: progress.total == 0 ? null : progress.done / progress.total,
            ),
            const SizedBox(height: 4),
            Text(l.doneCount(progress.done, progress.total), style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
```

Task 2's own Today tests keep passing: with only `seedFamily()` there are no chores, so `TodayChores` shows the members row, no late strip, "Your chores" and "No chores today".

- [ ] **Step 8: Run the tests to verify they pass**

Run: `flutter test test/features/chore_ticking_test.dart test/features/today_chores_test.dart test/features/chores_screen_test.dart test/features/chores_board_test.dart test/features/today_screen_test.dart`
Expected: PASS

- [ ] **Step 9: Run the full suite**

Run: `flutter analyze --no-fatal-infos` then `flutter test`
Expected: no errors or warnings; all tests pass.

- [ ] **Step 10: Commit**

```bash
git add lib/features/chores lib/features/today/today_screen.dart lib/l10n test/features/chore_ticking_test.dart test/features/today_chores_test.dart
git commit -m "feat(chores): who did it, late chores, celebration and Today chores" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

#### Drafting notes (writer C): interface issues resolved at merge

1. **Children can't tick most late chores "for the late date".** The interface says each late card ticks for its late `date`. But `canToggle` and the Task 5 rules only let a child tick today or yesterday, and most late chores are older ("Order blinds" is late since 28 Sep). As written, a child could never clear a late chore. Task 8 therefore ticks for the late date when `canToggle` allows it (parents always; children when it was yesterday) and **otherwise for today**. Task 4's `lateChores` already treats a done record dated today as clearing the chore. The rule lives in `lateTickDay` (`late_strip.dart`) and is tested ("a child clears an old late chore; it is recorded for today").
2. **Undo after ticking, and three extra l10n keys.** Spec §5 says "ticking, Undo … look and work the same for chores and shopping", but the interface has no Undo for chores. Task 6 adds the Release 1 Undo SnackBar, using `SnackBar(persist: false)` so it closes by itself and leaves no timer pending. That needs `choreTicked` ({title}). Two more keys are needed: `noChores`, for an empty section or an empty past or future day (`noChoresToday` would be wrong there), and `everyNMonthsOnDay` ({count} plural, {day}), because the model and sheet allow "every N months" but the key list has no label for it.
3. **Files outside Task 6's list:** `lib/data/write.dart` and the new `test/data/write_test.dart` (orchestrator update; `fireAndForget` now uses `then<void>(…, onError: …)`), and `test/app/home_shell_test.dart`. Task 2's test asserts exactly `['Today', 'Lists', 'Family']`, so adding the Chores tab must update it to `['Today', 'Chores', 'Lists', 'Family']`.
4. **Stand-in cards for deleted chores are fully read-only**: no long-press, as the orchestrator asked, and also no tick. Unticking one would delete the only history record of a chore that no longer exists, with no way to tick it back. If parents should be able to remove such history, allow `onToggle` for parents on stand-ins.
5. **`choreDoneProvider` is not `autoDispose`** (Task 5). Every day a user steps to on the Chores tab opens one more Firestore listener, which stays open until the app restarts. Suggest `StreamProvider.autoDispose.family`. Correctness is not affected.
6. **Card keys:** `ValueKey('chore-<id>')` is the `ChoreCard`'s own `key`, set by the caller (Chores tab, board, Today). The late strip gives its cards `ValueKey('lateChore-<id>')`, so on a day where a chore is both late and scheduled, finders for `chore-<id>` still match once. The tick inside a card is always `tick-<id>`.
7. **Public helpers beyond the interface** (defined in this part's own files and used across Tasks 6–8): `toggleChore` (the only place that ticks or unticks), `boardBreakpoint` (`chores_screen.dart`); `ChoreGroupHeader`, `compareMembers`, `memberById` (`chore_groups.dart`); `PictureTileGrid`, `neutralPersonColor` (`chore_card.dart`); `ChoreSheet` (the sheet's widget); `weekOrder`, `weekdayName`, `weekdaysLabel`, `shortDate`, `dayTitle`, `longDate`, `parseChoreTime`, `choreTimeKey`, `formatChoreTime`, `choreCaption` (`repeat_label.dart`); `ChoresBoard.minColumnWidth`; `latePersonColor`, `lateTickDay` (`late_strip.dart`); `TodayChores` (`today_screen.dart`).
8. **For Task 9:** the Remind switch calls `_setRemind(bool on)` in `chore_sheet.dart`; that is where to ask for the notification permission. Remind is disabled until a time is set, clearing the time turns it off, and a chore without a time is always saved with `remind: false`.
9. **`every`:** `validateChore` has no check on `every`, and the rules now require an int ≥ 1. The sheet parses Arabic or Latin digits and clamps to 1–99, so it can never send 0.
10. **Today's date line** (Task 2's `_TodayHeader`) is switched from `clockProvider` to `todayProvider` in Task 8. Otherwise, after the app resumes past midnight, the chores would show the new day under the old date. Task 2's tests are unaffected: both give 1 Oct 2026 under `testNow`.
11. **Lifecycle test scope:** `pumpWithFamily`'s clock is fixed, so "coming back to the app after midnight shows the new day" builds its own `ProviderScope` with a clock it can move. It overrides the same providers as `pumpWithFamily` after Task 3. If Task 9 adds an override that `TodayScreen` needs (today it needs none of the scheduler or preferences providers), add it there too.
12. **`late`** is used as an ARB key (per the interface) and as `ChoreCard`'s parameter name. It is a Dart built-in identifier, not a reserved word, so both are legal.

---

### Task 9: Reminders on each phone

**Files:**
- Create: `lib/core/reminders.dart`, `lib/data/reminder_scheduler.dart`, `test/core/reminders_test.dart`, `test/support/fake_scheduler.dart`, `test/app/reminder_sync_test.dart`
- Modify: `pubspec.yaml` (add `flutter_local_notifications`, `timezone`, `flutter_timezone`, `shared_preferences`), `lib/main.dart` (timezone + prefs init), `lib/app/providers.dart`, `lib/app/app.dart` (`ReminderSync` around `HomeShell`), `lib/features/chores/chore_sheet.dart` (ask permission when Remind is switched on), `lib/features/family/family_screen.dart` (parents: `Key('remindEveryone')` switch), `lib/features/common/dialogs.dart` (`askReminderPermission`), `test/support/pump.dart` (override scheduler + prefs), `android/app/build.gradle.kts` (core library desugaring as the plugin requires), `android/app/src/main/AndroidManifest.xml` (permissions and receivers the plugin's README requires for scheduled notifications), both ARB files

**Interfaces:**
- Consumes: `Chore`, `ChoreDone`, `occursOn`, `choreDoneId`, `dateKey`, `addDays`, `parseDateKey` (Task 4); `choresProvider`, `choreDoneProvider`, `todayProvider` (Task 5); `clockProvider`, `currentUidProvider`, `isParentProvider`, `membersProvider` (existing).
- Produces:
  - `class PlannedReminder { const PlannedReminder({required this.id, required this.choreId, required this.date, required this.title, required this.at}); final int id; final String choreId; final String date; final String title; final DateTime at; }` with value equality.
  - `int reminderId(String choreId, String date)` — 32-bit FNV-1a of `'$choreId|$date'` masked to `0x7fffffff`.
  - `List<PlannedReminder> planReminders({required List<Chore> chores, required List<ChoreDone> done, required String me, required bool everyone, required DateTime now, int days = 7})` — chores with `remind && time != null`, assigned to `me` (plus all others, including anyone chores, when `everyone`), occurring on each of the next `days` days starting today, not already done, with `at` after `now`; sorted by `at`. Title: `chore.title` (the body/person name is added by the scheduler).
  - `abstract class ReminderScheduler { Future<bool> requestPermission(); Future<void> replaceAll(List<PlannedReminder> reminders); }`
  - `class LocalReminderScheduler implements ReminderScheduler` — wraps `FlutterLocalNotificationsPlugin`; channel id `chores`, name from constructor; `replaceAll` cancels all pending then `zonedSchedule`s each with `AndroidScheduleMode.inexactAllowWhileIdle` at `tz.TZDateTime.from(at, tz.local)`.
  - `final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));`
  - `final remindEveryoneProvider = StateNotifierProvider<RemindEveryone, bool>` backed by `SharedPreferences` key `remindEveryone` (default false).
  - `final reminderSchedulerProvider = Provider<ReminderScheduler>`
  - `class ReminderSync extends ConsumerWidget { const ReminderSync({super.key, required this.child}); }` — whenever chores, done records (window today..today+7), me, `remindEveryone` or `isParentProvider` change, calls `replaceAll(planReminders(...))` (everyone only counts for parents).
  - `class FakeReminderScheduler implements ReminderScheduler { List<PlannedReminder> scheduled; bool permission = true; int permissionRequests; }` in `test/support/fake_scheduler.dart`; `pumpWithFamily` gains optional `ReminderScheduler? scheduler` and always overrides `sharedPreferencesProvider` (after `SharedPreferences.setMockInitialValues({})`).
  - New l10n keys: `remindersChannel`, `remindEveryone`, `reminderBody` ({name}), `notificationsDenied`.

**Package versions this task is written against** (resolved by `flutter pub add` on Flutter 3.47.5 / Dart 3.13 on 2026-09-28): `flutter_local_notifications` **22.3.1**, `timezone` **0.11.1**, `flutter_timezone` **5.1.0**, `shared_preferences` **2.5.5**. APIs used, checked in those sources:
- `FlutterLocalNotificationsPlugin()` is a singleton factory. `initialize({required InitializationSettings settings, ...})` — named `settings:`.
- `zonedSchedule({required int id, required TZDateTime scheduledDate, required NotificationDetails notificationDetails, required AndroidScheduleMode androidScheduleMode, String? title, String? body, String? payload, DateTimeComponents? matchDateTimeComponents})` — all named; throws `ArgumentError` if `scheduledDate` is not in the future.
- `cancelAllPendingNotifications()` cancels scheduled ones only (notifications already on screen stay); `cancelAll()` would also remove shown ones, so it is not used.
- `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission()` → `Future<bool?>`: shows the Android 13+ prompt; on older Android returns whether notifications are enabled; throws a `PlatformException` if a request is already in progress.
- `AndroidScheduleMode.inexactAllowWhileIdle` needs no exact-alarm permission.
- `FlutterTimezone.getLocalTimezone()` now returns a `TimezoneInfo`; the IANA name is `.identifier`.
- `timezone`: `import 'package:timezone/data/latest_all.dart'` → `initializeTimeZones()`; `tz.setLocalLocation(tz.getLocation(name))`; `tz.local` defaults to UTC; `tz.TZDateTime.from(DateTime, Location)` keeps the same instant.
- The plugin's README (Android setup) requires: core library desugaring with `com.android.tools:desugar_jdk_libs:2.1.4`; AGP ≥ 8.11.1 (this project: 9.1.0) and `compileSdk` ≥ 35 (Flutter 3.47.5 default: 36), so neither needs changing; for scheduled notifications, `RECEIVE_BOOT_COMPLETED` plus the `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` entries. The plugin's own manifest already adds `POST_NOTIFICATIONS` and `VIBRATE`; the app lists `POST_NOTIFICATIONS` too, to make it explicit.
- `SharedPreferences.setMockInitialValues({})` resets the cached instance, so `getInstance()` afterwards returns a fresh in-memory store.

**Additions beyond the interface list** (see INTERFACE ISSUES at the end): `PlannedReminder` gets an optional `assignee` (so the scheduler can name the person in the body); `LocalReminderScheduler({required String channelName, required String Function(PlannedReminder) bodyFor, FlutterLocalNotificationsPlugin? plugin})`; `RemindEveryone.setOn(bool)`; `askReminderPermission(BuildContext, ReminderScheduler)` in `lib/features/common/dialogs.dart`; `ReminderSync` also asks for the permission once per phone (SharedPreferences key `notificationsAsked`) the first time that phone has a reminder to schedule.

- [ ] **Step 1: Add the packages**

Run: `flutter pub add flutter_local_notifications timezone flutter_timezone shared_preferences`

Then open `pubspec.yaml`. Under `dependencies:` there must be four new lines with a caret (on Windows `flutter.bat` can strip the `^`; put it back if it did):

```yaml
  flutter_local_notifications: ^22.3.1
  timezone: ^0.11.1
  flutter_timezone: ^5.1.0
  shared_preferences: ^2.5.5
```

Expected: `Changed 17 dependencies!` (or similar). If pub resolves a different **major** version of any of the four, stop and report it: the code below uses the APIs listed above. Report the four resolved versions.

- [ ] **Step 2: Write the failing planner tests**

Create `test/core/reminders_test.dart`:

```dart
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

// Thursday 1 October 2026, noon.
final now = DateTime(2026, 10, 1, 12);

Chore chore(
  String id, {
  String? assignee = 'me',
  String? time = '18:00',
  bool remind = true,
  Repeat repeat = Repeat.daily,
  List<int> weekdays = const [],
  String start = '2026-09-01',
  String? end,
}) =>
    Chore(
      id: id,
      title: 'Chore $id',
      assignee: assignee,
      time: time,
      repeat: repeat,
      weekdays: weekdays,
      startDate: start,
      endDate: end,
      remind: remind,
      createdBy: 'parent',
    );

ChoreDone doneOn(String choreId, String date) => ChoreDone(
      choreId: choreId,
      date: date,
      choreTitle: 'Chore $choreId',
      assignee: 'me',
      doneBy: 'me',
      doneByName: 'Me',
      dayNumber: 0,
    );

List<PlannedReminder> plan(
  List<Chore> chores, {
  List<ChoreDone> done = const [],
  bool everyone = false,
  int days = 7,
}) =>
    planReminders(chores: chores, done: done, me: 'me', everyone: everyone, now: now, days: days);

/// "choreId date" for each reminder, in order.
List<String> keys(List<PlannedReminder> reminders) => [for (final r in reminders) '${r.choreId} ${r.date}'];

const week = [
  '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05', '2026-10-06', '2026-10-07',
];

void main() {
  test('only chores with the reminder on and a time', () {
    final result = plan([
      chore('a'),
      chore('noRemind', remind: false),
      chore('noTime', time: null),
    ]);
    expect(keys(result), [for (final d in week) 'a $d']);
  });

  test('a reminder carries the chore, its day, its time and whose chore it is', () {
    final first = plan([chore('a')]).first;
    expect(first.choreId, 'a');
    expect(first.date, '2026-10-01');
    expect(first.title, 'Chore a');
    expect(first.at, DateTime(2026, 10, 1, 18));
    expect(first.assignee, 'me');
    expect(first.id, reminderId('a', '2026-10-01'));
  });

  test('my chores only; everyone adds other people\'s and "anyone" chores', () {
    final chores = [
      chore('mine', time: '18:00'),
      chore('sara', assignee: 'sara', time: '18:10'),
      chore('shared', assignee: null, time: '18:20'),
    ];
    expect(plan(chores, days: 1).map((r) => r.choreId), ['mine']);
    expect(plan(chores, everyone: true, days: 1).map((r) => r.choreId), ['mine', 'sara', 'shared']);
  });

  test('skips days that are already done', () {
    final result = plan([chore('a')], done: [doneOn('a', '2026-10-02'), doneOn('other', '2026-10-03')]);
    expect(keys(result), [for (final d in week) if (d != '2026-10-02') 'a $d']);
  });

  test('skips a time that has already passed today', () {
    final morning = plan([chore('a', time: '07:00')]);
    expect(keys(morning), [for (final d in week.skip(1)) 'a $d']);
    final noon = plan([chore('b', time: '12:00')]);
    expect(noon.first.date, '2026-10-02', reason: 'exactly now is not in the future');
  });

  test('covers 7 days from today by default, or the given number of days', () {
    expect(plan([chore('a')]).length, 7);
    expect(keys(plan([chore('a')], days: 2)), ['a 2026-10-01', 'a 2026-10-02']);
    expect(plan([chore('late', repeat: Repeat.once, start: '2026-10-07')]).length, 1);
    expect(plan([chore('far', repeat: Repeat.once, start: '2026-10-08')]), isEmpty);
    expect(plan([chore('past', repeat: Repeat.once, start: '2026-09-30')]), isEmpty);
  });

  test('follows the repeat rule and the end date', () {
    // Saturday is weekday 6: 3 October 2026.
    expect(keys(plan([chore('sat', repeat: Repeat.weekly, weekdays: [6])])), ['sat 2026-10-03']);
    expect(keys(plan([chore('ends', end: '2026-10-02')])), ['ends 2026-10-01', 'ends 2026-10-02']);
  });

  test('sorted by time across days and chores', () {
    final result = plan([
      chore('evening', time: '19:00'),
      chore('morning', time: '08:00'),
      chore('dinner', time: '18:00'),
    ], days: 2);
    expect(keys(result), [
      'dinner 2026-10-01',
      'evening 2026-10-01',
      'morning 2026-10-02',
      'dinner 2026-10-02',
      'evening 2026-10-02',
    ]);
  });

  test('ignores a malformed time', () {
    expect(plan([chore('bad', time: '25:99'), chore('odd', time: 'soon')]), isEmpty);
  });

  test('reminder ids are stable, positive and differ per chore and day', () {
    expect(reminderId('a', '2026-10-01'), reminderId('a', '2026-10-01'));
    expect(reminderId('a', '2026-10-01'), isNot(reminderId('a', '2026-10-02')));
    expect(reminderId('a', '2026-10-01'), isNot(reminderId('b', '2026-10-01')));
    // FNV-1a of "brush|2026-10-01", masked to 31 bits.
    expect(reminderId('brush', '2026-10-01'), 122604501);
    for (final r in plan([chore('a'), chore('b', time: '19:00')])) {
      expect(r.id, inInclusiveRange(0, 0x7fffffff));
    }
    final ids = {for (final r in plan([chore('a'), chore('b', time: '19:00')])) r.id};
    expect(ids.length, 14);
  });

  test('reminders compare by value', () {
    PlannedReminder make(String title) =>
        PlannedReminder(id: 1, choreId: 'a', date: '2026-10-01', title: title, at: DateTime(2026, 10, 1, 18));
    expect(make('T'), make('T'));
    expect(make('T').hashCode, make('T').hashCode);
    expect(make('T'), isNot(make('T2')));
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/core/reminders_test.dart`
Expected: FAIL, compilation error: `lib/core/reminders.dart` can't be found (`Target of URI doesn't exist: 'package:family_app/core/reminders.dart'` in the analyzer).

- [ ] **Step 4: Implement the planner**

Create `lib/core/reminders.dart`:

```dart
import 'dart:convert';

import 'chores.dart';
import 'dates.dart';

/// One notification to show on this phone: a chore on a given day at its time.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.choreId,
    required this.date,
    required this.title,
    required this.at,
    this.assignee,
  });

  /// Notification id, from [reminderId].
  final int id;
  final String choreId;

  /// The chore's day, `YYYY-MM-DD`.
  final String date;

  /// The chore's title.
  final String title;

  /// When to remind: the chore's day at its time, in the phone's local time.
  final DateTime at;

  /// Whose chore it is (member uid), or null for an "anyone" chore.
  final String? assignee;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.choreId == choreId &&
      other.date == date &&
      other.title == title &&
      other.at == at &&
      other.assignee == assignee;

  @override
  int get hashCode => Object.hash(id, choreId, date, title, at, assignee);

  @override
  String toString() => 'PlannedReminder($choreId, $date, $at)';
}

/// A stable notification id for a chore on a day: 32-bit FNV-1a of
/// `'$choreId|$date'`, kept positive because Android ids are signed 32-bit ints.
int reminderId(String choreId, String date) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode('$choreId|$date')) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// The reminders this phone should have scheduled.
///
/// Only chores with a reminder switched on and a time. Normally only chores
/// assigned to [me]; with [everyone] (a parent's choice) also everyone else's
/// and the "anyone" chores. Covers [days] days starting today, skips days
/// already done and times that have already passed, sorted by time.
List<PlannedReminder> planReminders({
  required List<Chore> chores,
  required List<ChoreDone> done,
  required String me,
  required bool everyone,
  required DateTime now,
  int days = 7,
}) {
  final doneIds = {for (final d in done) choreDoneId(d.choreId, d.date)};
  final today = dayOnly(now);
  final result = <PlannedReminder>[];
  for (final chore in chores) {
    if (!chore.remind) continue;
    if (!everyone && chore.assignee != me) continue;
    final time = _parseTime(chore.time);
    if (time == null) continue;
    for (var i = 0; i < days; i++) {
      final day = addDays(today, i);
      if (!occursOn(chore, day)) continue;
      final date = dateKey(day);
      if (doneIds.contains(choreDoneId(chore.id, date))) continue;
      final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      if (!at.isAfter(now)) continue;
      result.add(PlannedReminder(
        id: reminderId(chore.id, date),
        choreId: chore.id,
        date: date,
        title: chore.title,
        at: at,
        assignee: chore.assignee,
      ));
    }
  }
  result.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    if (byTime != 0) return byTime;
    final byTitle = a.title.compareTo(b.title);
    return byTitle != 0 ? byTitle : a.choreId.compareTo(b.choreId);
  });
  return result;
}

/// Reads `"HH:mm"`; null when missing or malformed.
({int hour, int minute})? _parseTime(String? time) {
  if (time == null) return null;
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return (hour: hour, minute: minute);
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/core/reminders_test.dart`
Expected: PASS, `+11: All tests passed!`

- [ ] **Step 6: Add the scheduler and its test fake**

Create `lib/data/reminder_scheduler.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/reminders.dart';

/// Schedules chore reminders as notifications on this phone.
abstract class ReminderScheduler {
  /// Asks the phone for permission to show notifications (Android 13+ shows a
  /// prompt; older versions answer at once). True when notifications are allowed.
  Future<bool> requestPermission();

  /// Replaces every pending chore reminder on this phone with [reminders].
  /// Notifications already showing are left alone.
  Future<void> replaceAll(List<PlannedReminder> reminders);
}

/// [ReminderScheduler] backed by flutter_local_notifications.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({
    required this.channelName,
    required this.bodyFor,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'chores';

  /// The channel's name in the phone's notification settings.
  final String channelName;

  /// The notification's second line, e.g. "Chore for Sara".
  final String Function(PlannedReminder reminder) bodyFor;

  final FlutterLocalNotificationsPlugin _plugin;

  // Shared by every instance: the plugin is a singleton, and a new scheduler is
  // created when the language or the members change, so one replacement must
  // finish before the next starts.
  static Future<void>? _ready;
  static Future<void> _queue = Future<void>.value();

  Future<void> _init() => _ready ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      )
      .then((_) {});

  @override
  Future<bool> requestPermission() async {
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) {
    final next = _queue.then((_) => _replace(reminders));
    _queue = next.catchError((Object error) {
      debugPrint('Scheduling reminders failed: $error');
    });
    return next;
  }

  Future<void> _replace(List<PlannedReminder> reminders) async {
    await _init();
    await _plugin.cancelAllPendingNotifications();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    for (final r in reminders) {
      final at = tz.TZDateTime.from(r.at, tz.local);
      if (!at.isAfter(tz.TZDateTime.now(tz.local))) continue;
      try {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: bodyFor(r),
          scheduledDate: at,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (error) {
        debugPrint('Scheduling reminder ${r.choreId} ${r.date} failed: $error');
      }
    }
  }
}
```

Create `test/support/fake_scheduler.dart`:

```dart
import 'package:family_app/core/reminders.dart';
import 'package:family_app/data/reminder_scheduler.dart';

/// Records what the app asked to schedule, instead of touching the phone.
class FakeReminderScheduler implements ReminderScheduler {
  /// The reminders from the latest [replaceAll].
  List<PlannedReminder> scheduled = [];

  /// What [requestPermission] answers.
  bool permission = true;

  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    scheduled = List.of(reminders);
  }
}
```

Run: `flutter analyze lib/core/reminders.dart lib/data/reminder_scheduler.dart test/support/fake_scheduler.dart`
Expected: `No issues found!`

- [ ] **Step 7: Add the strings**

In `lib/l10n/app_en.arb`, add these entries at the end (put a comma after the entry that is currently last, before the closing `}`):

```json
  "remindersChannel": "Chore reminders",
  "remindEveryone": "Remind me about everyone's chores",
  "reminderBody": "Chore for {name}",
  "@reminderBody": { "placeholders": { "name": { "type": "String" } } },
  "notificationsDenied": "Notifications are off for Family, so chore reminders won't show on this phone. To turn them on, open the phone's Settings, then Apps, then Family, then Notifications."
```

In `lib/l10n/app_ar.arb`, the same way:

```json
  "remindersChannel": "تذكير المهام",
  "remindEveryone": "ذكّرني بمهام الجميع",
  "reminderBody": "مهمة {name}",
  "notificationsDenied": "الإشعارات متوقفة لتطبيق Family، لذلك لن تظهر تذكيرات المهام على هذا الهاتف. لتشغيلها افتح إعدادات الهاتف، ثم التطبيقات، ثم Family، ثم الإشعارات."
```

Run: `flutter gen-l10n`
Expected: no errors; `lib/l10n/app_localizations.dart` now has `remindersChannel`, `remindEveryone`, `reminderBody(String name)` and `notificationsDenied`.

- [ ] **Step 8: Add the providers**

In `lib/app/providers.dart`, add each of these imports that isn't there yet (`dart:async` first, the package import with the other package imports, the relative ones with the other relative imports):

```dart
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/reminder_scheduler.dart';
import '../l10n/app_localizations.dart';
```

Then append at the end of the file:

```dart

// Reminders (kept on this phone only).

/// Opened in main() before the app starts; tests override it too.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override in main'),
);

/// A parent's choice to be reminded about everyone's chores, saved on this phone.
class RemindEveryone extends StateNotifier<bool> {
  RemindEveryone(this._prefs) : super(_prefs.getBool(key) ?? false);

  static const key = 'remindEveryone';
  final SharedPreferences _prefs;

  void setOn(bool on) {
    state = on;
    unawaited(_prefs.setBool(key, on));
  }
}

final remindEveryoneProvider = StateNotifierProvider<RemindEveryone, bool>(
  (ref) => RemindEveryone(ref.watch(sharedPreferencesProvider)),
);

/// Real notifications on the phone; tests override it with a fake.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final code = ref.watch(localeProvider)?.languageCode ??
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final l = lookupAppLocalizations(Locale(code == 'ar' ? 'ar' : 'en'));
  final names = {
    for (final m in ref.watch(membersProvider).valueOrNull ?? const <Member>[]) m.uid: m.name,
  };
  return LocalReminderScheduler(
    channelName: l.remindersChannel,
    bodyFor: (r) => l.reminderBody(
      r.assignee == null ? l.anyone : names[r.assignee] ?? l.formerMember,
    ),
  );
});
```

(`lookupAppLocalizations` is generated by gen-l10n; `l.anyone` and `l.formerMember` come from Task 6. When the language or the members change, a new scheduler is built and `ReminderSync` reschedules with the new wording.)

- [ ] **Step 9: Let the test helper fake the scheduler and the saved settings**

In `test/support/pump.dart`, make four edits.

Before:
```dart
import 'package:family_app/app/providers.dart';
```
After:
```dart
import 'package:family_app/app/providers.dart';
import 'package:family_app/data/reminder_scheduler.dart';
```

Before:
```dart
import 'package:flutter_test/flutter_test.dart';
```
After:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_scheduler.dart';
```

Before (as left by Task 3):
```dart
  String uid = 'u1',
  String? photoUrl,
}) async {
  await tester.pumpWidget(ProviderScope(
```
After:
```dart
  String uid = 'u1',
  String? photoUrl,
  ReminderScheduler? scheduler,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
```

Before:
```dart
      clockProvider.overrideWithValue(() => testNow),
```
After:
```dart
      clockProvider.overrideWithValue(() => testNow),
      sharedPreferencesProvider.overrideWithValue(prefs),
      reminderSchedulerProvider.overrideWithValue(scheduler ?? FakeReminderScheduler()),
```

(Leave the override Task 3 added, `authPhotoUrlProvider`, and anything else in the list as it is.)

- [ ] **Step 10: Write the failing widget tests**

Create `test/app/reminder_sync_test.dart` (the chore-sheet and Family-screen permission tests live here too, so no other task's test file changes):

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart';
import 'package:family_app/app/providers.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/reminders.dart';
import 'package:family_app/data/chore_repository.dart';
import 'package:family_app/features/chores/chore_sheet.dart';
import 'package:family_app/features/family/family_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_scheduler.dart';
import '../support/pump.dart';
import '../support/seed.dart';

// testNow is Thursday 1 October 2026, 12:00.
const dishes = Chore(
  id: 'dishes', title: 'Dishes', assignee: 'u1', time: '18:00', repeat: Repeat.daily,
  startDate: '2026-09-01', remind: true, createdBy: 'u1',
);
const teeth = Chore(
  id: 'teeth', title: 'Brush teeth', assignee: 'u2', time: '07:00', repeat: Repeat.daily,
  startDate: '2026-09-01', remind: true, createdBy: 'u1',
);
const plants = Chore(
  id: 'plants', title: 'Water plants', time: '19:00', repeat: Repeat.daily,
  startDate: '2026-09-01', remind: true, createdBy: 'u1',
);
const bins = Chore(
  id: 'bins', title: 'Bins', assignee: 'u1', time: '20:00', repeat: Repeat.daily,
  startDate: '2026-09-01', createdBy: 'u1',
);

Future<FakeFirebaseFirestore> seedWithChores() async {
  final db = await seedFamily();
  for (final c in [dishes, teeth, plants, bins]) {
    await db.doc('families/f1/chores/${c.id}').set(c.toMap());
  }
  return db;
}

Future<FakeReminderScheduler> pumpSync(WidgetTester tester, FakeFirebaseFirestore db, {String uid = 'u1'}) async {
  final scheduler = FakeReminderScheduler();
  await pumpWithFamily(tester, db: db, uid: uid, scheduler: scheduler, child: const ReminderSync(child: SizedBox()));
  await settle(tester);
  return scheduler;
}

ProviderContainer containerOf(WidgetTester tester, Type widget) =>
    ProviderScope.containerOf(tester.element(find.byType(widget)));

/// "choreId date" for each scheduled reminder, in order.
List<String> keys(List<PlannedReminder> reminders) => [for (final r in reminders) '${r.choreId} ${r.date}'];

void main() {
  group('ReminderSync', () {
    testWidgets('on start, schedules my reminders for the next 7 days and asks permission once', (tester) async {
      final db = await seedWithChores();
      final scheduler = await pumpSync(tester, db);
      expect(keys(scheduler.scheduled), [
        for (var day = 1; day <= 7; day++) 'dishes 2026-10-0$day',
      ]);
      expect(scheduler.scheduled.first.at, DateTime(2026, 10, 1, 18));
      expect(scheduler.permissionRequests, 1);
    });

    testWidgets('ticking today\'s chore removes today\'s reminder', (tester) async {
      final db = await seedWithChores();
      final scheduler = await pumpSync(tester, db);
      await ChoreRepository(db, 'f1').tick(chore: dishes, date: '2026-10-01', doneBy: 'u1', doneByName: 'Dad');
      await settle(tester);
      expect(scheduler.scheduled.length, 6);
      expect(scheduler.scheduled.first.date, '2026-10-02');
      expect(scheduler.permissionRequests, 1, reason: 'the phone is asked only once');
    });

    testWidgets('a parent who turns on "everyone" also gets everyone\'s reminders', (tester) async {
      final db = await seedWithChores();
      final scheduler = await pumpSync(tester, db);
      containerOf(tester, ReminderSync).read(remindEveryoneProvider.notifier).setOn(true);
      await settle(tester);
      expect(scheduler.scheduled.map((r) => r.choreId).toSet(), {'dishes', 'teeth', 'plants'});
      expect(keys(scheduler.scheduled).take(3), ['dishes 2026-10-01', 'plants 2026-10-01', 'teeth 2026-10-02']);
      expect((await SharedPreferences.getInstance()).getBool('remindEveryone'), isTrue);
    });

    testWidgets('a child gets only their own reminders, even with "everyone" on', (tester) async {
      final db = await seedWithChores();
      final scheduler = await pumpSync(tester, db, uid: 'u2');
      containerOf(tester, ReminderSync).read(remindEveryoneProvider.notifier).setOn(true);
      await settle(tester);
      expect(scheduler.scheduled.map((r) => r.choreId).toSet(), {'teeth'});
      expect(scheduler.scheduled.length, 6, reason: 'today 07:00 has already passed');
    });

    testWidgets('with nothing to remind about, clears reminders and does not ask', (tester) async {
      final db = await seedFamily();
      final scheduler = FakeReminderScheduler()
        ..scheduled = [
          PlannedReminder(id: 1, choreId: 'old', date: '2026-10-01', title: 'Old', at: DateTime(2026, 10, 1, 18)),
        ];
      await pumpWithFamily(tester, db: db, scheduler: scheduler, child: const ReminderSync(child: SizedBox()));
      await settle(tester);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.permissionRequests, 0);
    });
  });

  group('asking for the notification permission', () {
    Future<void> openSheet(WidgetTester tester, FakeReminderScheduler scheduler) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final db = await seedFamily();
      await pumpWithFamily(
        tester,
        db: db,
        scheduler: scheduler,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showChoreSheet(context, day: DateTime(2026, 10, 1)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('choreRemind')));
      await settle(tester);
    }

    testWidgets('switching Remind on in the chore sheet asks; switching it off does not', (tester) async {
      final scheduler = FakeReminderScheduler();
      await openSheet(tester, scheduler);
      await tester.tap(find.byKey(const Key('choreRemind')));
      await settle(tester);
      expect(scheduler.permissionRequests, 1);
      expect(find.byKey(const Key('notificationsDenied')), findsNothing);

      await tester.tap(find.byKey(const Key('choreRemind')));
      await settle(tester);
      expect(scheduler.permissionRequests, 1);
    });

    testWidgets('when the phone says no, the sheet explains how to turn notifications on', (tester) async {
      final scheduler = FakeReminderScheduler()..permission = false;
      await openSheet(tester, scheduler);
      await tester.tap(find.byKey(const Key('choreRemind')));
      await settle(tester);
      expect(find.byKey(const Key('notificationsDenied')), findsOneWidget);
      expect(find.textContaining('Notifications are off for Family'), findsOneWidget);
    });

    testWidgets('parents see "Remind me about everyone\'s chores"; turning it on saves it and asks', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final db = await seedFamily();
      final scheduler = FakeReminderScheduler();
      await pumpWithFamily(tester, db: db, scheduler: scheduler, child: const FamilyScreen());
      expect(find.text("Remind me about everyone's chores"), findsOneWidget);

      await tester.tap(find.byKey(const Key('remindEveryone')));
      await settle(tester);
      expect(containerOf(tester, FamilyScreen).read(remindEveryoneProvider), isTrue);
      expect((await SharedPreferences.getInstance()).getBool('remindEveryone'), isTrue);
      expect(scheduler.permissionRequests, 1);
    });

    testWidgets('children do not see the remind-everyone switch', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
      expect(find.byKey(const Key('leaveFamily')), findsOneWidget);
      expect(find.byKey(const Key('remindEveryone')), findsNothing);
    });
  });
}
```

- [ ] **Step 11: Run the tests to verify they fail**

Run: `flutter test test/app/reminder_sync_test.dart`
Expected: FAIL, compilation errors `Couldn't find constructor 'ReminderSync'` and `Undefined name 'ReminderSync'`.

- [ ] **Step 12: Add `ReminderSync` and put it around the home shell**

In `lib/app/app.dart`, add these imports if they are not there yet (`dart:async` above the package imports, the other two with the relative imports):

```dart
import 'dart:async';

import '../core/dates.dart';
import '../core/reminders.dart';
```

In `RootGate.build`, make `ReminderSync` the direct parent of `HomeShell`, inside `_MembershipGuard` (it needs the family) and inside Task 3's `ProfileSync`.

Before (as left by Task 3):
```dart
              : const _MembershipGuard(child: ProfileSync(child: HomeShell())),
```
After:
```dart
              : const _MembershipGuard(child: ProfileSync(child: ReminderSync(child: HomeShell()))),
```

Append at the end of the file:

```dart

/// Keeps this phone's chore reminders in step with the chores while the app
/// runs: on start, and whenever chores, done records, the signed-in person or
/// the "remind me about everyone" choice change.
class ReminderSync extends ConsumerWidget {
  const ReminderSync({super.key, required this.child});
  final Widget child;

  /// Set once this phone has been asked for the notification permission.
  static const askedKey = 'notificationsAsked';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUidProvider);
    final today = ref.watch(todayProvider);
    final chores = ref.watch(choresProvider).valueOrNull;
    final done = ref
        .watch(choreDoneProvider((from: dateKey(today), to: dateKey(addDays(today, 7)))))
        .valueOrNull;
    final everyone = ref.watch(isParentProvider) && ref.watch(remindEveryoneProvider);
    final scheduler = ref.watch(reminderSchedulerProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final now = ref.watch(clockProvider)();
    if (me != null && me.isNotEmpty && chores != null && done != null) {
      final plan = planReminders(chores: chores, done: done, me: me, everyone: everyone, now: now);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fireAndForget(scheduler.replaceAll(plan));
        // Ask once, the first time this phone has something to remind about
        // (for example a child whose parent switched a reminder on).
        if (plan.isNotEmpty && prefs.getBool(askedKey) != true) {
          unawaited(prefs.setBool(askedKey, true));
          unawaited(scheduler.requestPermission());
        }
      });
    }
    return child;
  }
}
```

(`ReminderSync` returns the same `child` instance, so a rebuild does not rebuild `HomeShell`. It waits until chores and done records have loaded, so it never clears reminders just because the data is still loading.)

- [ ] **Step 13: Ask for the permission from the chore sheet and the Family screen**

In `lib/features/common/dialogs.dart`, add the import:

Before:
```dart
import '../../l10n/app_localizations.dart';
```
After:
```dart
import '../../data/reminder_scheduler.dart';
import '../../l10n/app_localizations.dart';
```

and append at the end of the file:

```dart

/// Asks the phone for permission to show reminders. If the answer is no,
/// explains how to turn notifications on in the phone's settings.
Future<void> askReminderPermission(BuildContext context, ReminderScheduler scheduler) async {
  final granted = await scheduler.requestPermission();
  if (granted || !context.mounted) return;
  final l = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('notificationsDenied'),
      content: Text(l.notificationsDenied),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
        ),
      ],
    ),
  );
}
```

In `lib/features/chores/chore_sheet.dart` (Task 6), the Remind switch calls `_setRemind` in `_ChoreSheetState` (a `ConsumerState`, so `ref` is available; the file already imports `'../../app/providers.dart'` and `'../common/dialogs.dart'`).

Before:
```dart
  void _setRemind(bool on) => setState(() => _remind = on);
```
After:
```dart
  void _setRemind(bool on) {
    setState(() => _remind = on);
    if (on) askReminderPermission(context, ref.read(reminderSchedulerProvider));
  }
```

In `lib/features/family/family_screen.dart` (as left by Task 3), add the parents-only switch as the last row of the settings card, directly under the theme row. `isParent`, `l`, `ref` and `context` already exist in `build`; add `import '../common/dialogs.dart';` if it is missing.

Before:
```dart
                        fireAndForget(ref
                            .read(familyRepositoryProvider)
                            .setThemeMode(uid, choice == 'system' ? null : choice));
                      }
                    },
                  ),
                ),
              ],
```
After:
```dart
                        fireAndForget(ref
                            .read(familyRepositoryProvider)
                            .setThemeMode(uid, choice == 'system' ? null : choice));
                      }
                    },
                  ),
                ),
                if (isParent)
                  SwitchListTile(
                    key: const Key('remindEveryone'),
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: Text(l.remindEveryone),
                    value: ref.watch(remindEveryoneProvider),
                    onChanged: (on) {
                      ref.read(remindEveryoneProvider.notifier).setOn(on);
                      if (on) askReminderPermission(context, ref.read(reminderSchedulerProvider));
                    },
                  ),
              ],
```

This row pushes `Key('leaveFamily')` down for parents. If a Release 1 or Task 3 test can no longer tap it on the default 800×600 test surface, add `await tester.ensureVisible(find.byKey(const Key('leaveFamily')));` before that tap and report it as a Deviation (positioning only).

- [ ] **Step 14: Run the tests to verify they pass**

Run: `flutter test test/app/reminder_sync_test.dart test/core/reminders_test.dart`
Expected: PASS, `+20: All tests passed!`

- [ ] **Step 15: Set up the time zone and saved settings at start-up**

Replace `lib/main.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app/app.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // reads android/app/google-services.json
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  await _initTimeZone();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const FamilyApp(),
  ));
}

/// Reminders are scheduled in the phone's own time zone.
Future<void> _initTimeZone() async {
  tzdata.initializeTimeZones();
  try {
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  } catch (error) {
    // Unknown zone name: tz.local stays UTC. Reminders still fire at the right
    // moment, because TZDateTime.from keeps the same instant.
    debugPrint('Could not set the local time zone: $error');
  }
}
```

(If Task 1 or another task already changed `main.dart`, keep their changes and add only the new imports, the `_initTimeZone()` and `SharedPreferences` lines and the `overrides:` entry.)

- [ ] **Step 16: Android set-up the notifications plugin requires**

In `android/app/build.gradle.kts`, enable core library desugaring.

Before:
```kotlin
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
```
After:
```kotlin
    compileOptions {
        // Needed by flutter_local_notifications for scheduled notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
```

Before (end of file):
```kotlin
flutter {
    source = "../.."
}
```
After:
```kotlin
flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

(The plugin's README also shows Java 17 and `multiDexEnabled`; neither is needed here: the app's Java 11 settings only affect the app's own code, and minSdk 24 has multidex built in. A release build with exactly these changes was verified.)

In `android/app/src/main/AndroidManifest.xml`:

Before:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
```
After:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Chore reminders: show notifications, and re-create them after the phone restarts. -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <application
```

Before:
```xml
        <!-- Don't delete the meta-data below.
```
After:
```xml
        <!-- flutter_local_notifications: shows scheduled notifications, and reschedules them after a reboot or app update. -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <!-- Don't delete the meta-data below.
```

No `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`: reminders use `inexactAllowWhileIdle`, so they may arrive a few minutes late, but need no special permission.

- [ ] **Step 17: Run the full suite and a build**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: no errors or warnings (only the existing infos); all tests pass.

Then check that the Android changes build (needs `android/app/google-services.json`, which is on this PC):

Run (Git Bash): `GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false flutter build apk --debug`
Expected: `√ Built build\app\outputs\flutter-apk\app-debug.apk`. (Without the desugaring lines, Gradle stops with an error saying `:flutter_local_notifications` requires core library desugaring to be enabled for `:app`.)

If a Release 1 Family screen test that taps `leaveFamily` or `signOut` now fails because that row moved below the 800×600 test window, add `await tester.ensureVisible(find.byKey(const Key('leaveFamily')));` (or `signOut`) before the tap in that test and report it as a Deviation.

- [ ] **Step 18: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/reminders.dart lib/data/reminder_scheduler.dart lib/main.dart lib/app/providers.dart lib/app/app.dart lib/features/common/dialogs.dart lib/features/chores/chore_sheet.dart lib/features/family/family_screen.dart lib/l10n test/core/reminders_test.dart test/support/fake_scheduler.dart test/support/pump.dart test/app/reminder_sync_test.dart android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml
git commit -m "feat(reminders): chore reminders scheduled on each phone

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Add `test/features/family_screen_test.dart` to the `git add` only if Step 17's `ensureVisible` fix was needed. Never add `android/app/google-services.json`.)

---

### Task 10: Release 1.1.0 — build, setup notes, device checklist

**Files:**
- Modify: `pubspec.yaml` (`version: 1.1.0+2`), `docs/SETUP.md` (notification permission note; fix the debug-key step wording: keytool lives in Android Studio's `jbr\bin`, PowerShell uses `.\gradlew signingReport`)

**Interfaces:**
- Consumes: everything above.
- Produces: `build/app/outputs/flutter-apk/app-release.apk` (debug-key fallback when no `key.properties`), and a manual device checklist in this task for Firas (reminders firing at the chore time; permission prompt; tablet landscape board with independent column scrolling; light/dark switching; Arabic layout; child vs parent permissions on two phones; late chores; celebration).

- [ ] **Step 1: Bump the version**

In `pubspec.yaml`:

Before:
```yaml
version: 1.0.0+1
```
After:
```yaml
version: 1.1.0+2
```

(The GitHub release workflow still takes the version name from the tag and the build number from the run number; this line sets the version of APKs built on this PC.)

- [ ] **Step 2: Update the setup guide**

In `docs/SETUP.md`, make four edits.

Before:
```markdown
Everything happens in a web browser: GitHub and the Firebase console. Nothing needs to be installed on your computer.
```
After:
```markdown
Everything happens in a web browser: GitHub and the Firebase console. Nothing needs to be installed on your computer, except for the optional "Debug key" step in section 2, which uses Android Studio.
```

Before:
```markdown
2. **Debug key (test APK):** the test APK built on your PC is signed with that PC's debug key, so its SHA-1 and SHA-256 must be added too. To see them, either:
   - open a terminal in the repository, run `cd android`, then `gradlew signingReport`; or
   - run `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android`.
```
After:
```markdown
2. **Debug key (test APK):** only needed if you install test APKs built on your PC (the APK from a GitHub release doesn't need it). The test APK is signed with that PC's debug key, so its SHA-1 and SHA-256 must be added too. To see them, open **PowerShell** and either:
   - go to the repository folder, then run these three lines (Gradle needs to know where Android Studio's Java is):
     `$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"`
     `cd android`
     `.\gradlew signingReport`
     and copy the `SHA1:` and `SHA-256:` lines shown under `Variant: debug`; or
   - run `keytool` from Android Studio's Java folder (it is not on the normal PATH):
     `& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android`
```

Before:
```markdown
4. Promote your wife (or anyone else) to parent from the Family tab.
```
After:
```markdown
4. Promote your wife (or anyone else) to parent from the Family tab.
5. **Chore reminders need notifications.** The first time someone switches on a chore reminder, or the first time a phone has a chore with a reminder, Android asks **"Allow Family to send you notifications?"**. Tap **Allow**. If someone tapped **Don't allow**, fix it on that phone: **Settings → Apps → Family → Notifications → on**. Reminders can arrive a few minutes after the chore's time (Android groups them to save battery). On some phones (Samsung, Xiaomi, Huawei) also set **Settings → Apps → Family → Battery → Unrestricted**, or the phone may hold reminders back.
```

Before:
```markdown
If `firestore.rules` changes in a later version, paste it into the Firestore **Rules** tab again and click Publish.
```
After:
```markdown
If `firestore.rules` changes in a later version, paste it into the Firestore **Rules** tab again and click Publish.

**Version 1.1.0 (chores) changes `firestore.rules`.** Publish the new rules first, then install 1.1.0 on every phone. Until the new rules are published, chores can't be saved.
```

- [ ] **Step 3: Run every check**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: no errors or warnings; all tests pass. Report the test count.

Run (Git Bash): `export JAVA_HOME="C:\Program Files\Android\Android Studio\jbr" && cd rules-tests && npm run emulate`
Expected: all rules tests passing, 0 failing (Release 1 tests plus the Task 3 and Task 5 additions).

- [ ] **Step 4: Build the release APK**

Run (Git Bash, from the repository root): `GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false flutter build apk --release`
Expected: `√ Built build\app\outputs\flutter-apk\app-release.apk (NN.NMB)`, after about 4–5 minutes. With no `android/key.properties` on this PC it is signed with the debug key (the fallback from Release 1). Report the size. For comparison, 1.0.0 was 53.2 MB, and 1.0.0 plus only the Task 9 packages was 55.6 MB, so expect about 56–58 MB with the bundled font.

- [ ] **Step 5: Check what's inside the APK**

Run (Git Bash):
```bash
AAPT="$LOCALAPPDATA/Android/Sdk/build-tools/36.1.0/aapt.exe"
"$AAPT" dump badging build/app/outputs/flutter-apk/app-release.apk | grep -E "^package:|^sdkVersion|^application-label:|POST_NOTIFICATIONS|RECEIVE_BOOT_COMPLETED"
"$AAPT" dump xmltree build/app/outputs/flutter-apk/app-release.apk AndroidManifest.xml | grep -c "ScheduledNotification"
```
Expected:
```
package: name='com.firas.familia' versionCode='2' versionName='1.1.0' ...
sdkVersion:'24'
uses-permission: name='android.permission.POST_NOTIFICATIONS'
uses-permission: name='android.permission.RECEIVE_BOOT_COMPLETED'
application-label:'Family'
```
and `2` from the second command (both notification receivers are in the manifest). If `36.1.0` is missing, use any folder under `$LOCALAPPDATA/Android/Sdk/build-tools/` that has `aapt.exe`.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml docs/SETUP.md
git commit -m "chore(release): 1.1.0 build and setup notes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: Device checklist (Firas, on real phones)**

**Before you start**

- A. **Publish the new rules:** Firebase console → Firestore Database → **Rules** → replace everything with the contents of `firestore.rules` from this repository → **Publish**.
- B. **Install 1.1.0** on three devices, the same way you installed 1.0.0: your phone (a parent), a child's phone (in these steps the child is Sara), and the tablet. Either publish a GitHub release `v1.1.0` (SETUP section 3) or send `build/app/outputs/flutter-apk/app-release.apk` from this PC over WhatsApp or Drive. If Android says **App not installed**, the old copy was signed with a different key: uninstall Family, then install again. Your family data is in Firebase, so nothing is lost.
- C. Open Family once on each device and check you're signed in.

Do each step and compare with "You should see". If something doesn't match, note the step number and what you saw, and tell Claude.

1. **Nothing lost.** Open Family on your phone.
   You should see: you're still in the family; your shopping lists are under **Lists**; the bottom bar reads **Today · Chores · Lists · Family**; the History button at the top of Lists opens your purchases.
2. **Light and dark.** Family tab → **Theme** → **Dark**, then look at every tab. Then **Light**. Then **System**, and switch your phone's dark mode on and off from the quick-settings panel.
   You should see: every tab turns dark or light, all text is easy to read, and on System the app follows the phone.
3. **Colours and photos.** On the Family tab, tap the coloured dot next to Sara and pick another colour.
   You should see: people with a Google photo show it, others show a coloured letter; Sara's avatar and her chores change to the new colour on both phones within a few seconds.
4. **Picture tiles.** Family tab → switch on **Picture tiles** for Sara. Open Chores.
   You should see: Sara's chores as big emoji tiles; long titles end with "…".
5. **A chore with a reminder (the permission prompt).** On your phone: Chores → **+** → title "Brush teeth", emoji 🪥, Who: **Sara**, Time: **5 minutes from now**, Repeat: **Daily**, switch **Remind** on, then Save.
   You should see: the first time, Android asks **"Allow Family to send you notifications?"**. Tap **Allow**.
6. **The reminder fires on Sara's phone.** On Sara's phone, open Family once (so it picks up the new chore). If Android asks to allow notifications, tap **Allow**. Lock the phone and wait.
   You should see: within about 15 minutes of the chore's time, a notification **Brush teeth — Chore for Sara**. Your own phone shows nothing.
7. **Ticking cancels today's reminder.** Make another chore for Sara, 10 minutes from now, with Remind on. On Sara's phone, open the app and tick it before its time.
   You should see: no notification for that chore.
8. **Reminders survive a restart.** Make a chore for Sara 10 minutes from now with Remind on. Open the app on Sara's phone once, then restart her phone and don't open the app again.
   You should see: the reminder still arrives.
9. **"Remind me about everyone's chores".** On your phone: Family tab → switch on **Remind me about everyone's chores**. Make a chore for Sara 5 minutes from now with Remind on.
   You should see: this time your phone also shows **… — Chore for Sara**, as well as Sara's phone.
10. **If notifications were refused.** On your phone: Settings → Apps → Family → Notifications → **off**. In Family, edit a chore, switch Remind off and on again. If Android asks, tap **Don't allow**.
    You should see: a message in the app explaining how to turn notifications back on. Follow it to turn them on again.
11. **Child vs parent (two phones).** On Sara's phone:
    - tap **+**: under Who she sees only herself;
    - she can tick her own chores and "Anyone" chores; your chores have a greyed-out tick she can't press, and long-pressing your chore does nothing;
    - go back one day with ◀: she can still tick yesterday's chores; two days back, nothing can be ticked.
    On your phone: you can tick and untick anyone's chore, on any day.
12. **"Anyone" chores.** Make an Anyone chore "Water plants". Tick it on your phone.
    You should see: the app asks **Who did it?**; pick Sara; both phones show it done by Sara. When Sara ticks an Anyone chore, the app doesn't ask; it records Sara.
13. **Late chores.** Make a one-time chore for Sara with the start date **yesterday**; don't tick it. Open **Today**.
    You should see: a red **Late** strip with that chore. Tick it: the strip disappears.
14. **Celebration.** Tick one of Sara's chores. Then tick her last chore of the day. Then turn on **Remove animations** (Settings → Accessibility; on Samsung it's under Visibility enhancements) and tick another chore; afterwards turn the setting off again.
    You should see: a small emoji burst and a light buzz; a bigger burst for the last chore of the day; with Remove animations on, no burst but still the buzz.
15. **Tablet board.** On the tablet, hold it sideways (landscape) and open **Chores**. Scroll down inside one person's column. Then turn the tablet upright.
    You should see: one column per person side by side, plus Anyone; only the column you scrolled moves; upright, the chores stack in sections instead.
16. **Arabic.** Family tab → Language → **العربية**. Look at Today, Chores (phone and tablet) and Family. Add a chore with a long Arabic title.
    You should see: everything right-to-left, including the day arrows and the tablet columns; the long title ends with "…" instead of spilling over; the next reminder's text is in Arabic (**مهمة سارة**).
17. **Offline.** Turn on airplane mode on Sara's phone, tick a chore, then turn airplane mode off.
    You should see: within a few seconds your phone shows it ticked.

---

#### Drafting notes (writer D): interface issues resolved at merge

1. **`PlannedReminder` can't tell the scheduler whose chore it is.** The interface says the scheduler adds the person's name to the body, but `PlannedReminder` had no assignee. Added an optional `final String? assignee;` (default null, part of value equality); `planReminders` fills it from `chore.assignee`. Additive: no other task uses `PlannedReminder`.
2. **`LocalReminderScheduler` constructor** (interface said only "name from constructor"): `LocalReminderScheduler({required String channelName, required String Function(PlannedReminder) bodyFor, FlutterLocalNotificationsPlugin? plugin})`. `reminderSchedulerProvider` builds it with `lookupAppLocalizations(...)` from `localeProvider` and names from `membersProvider`, using Task 6's `anyone` and `formerMember` strings. Because the provider builds a new scheduler when the language or members change, plugin initialisation and `replaceAll` calls are serialised through static fields shared by all instances.
3. **`RemindEveryone` method name**: the interface named the class but no setter; the plan uses `void setOn(bool on)`.
4. **Spec gap: children's phones never get asked for the permission.** Spec §7 asks "the first time a reminder is switched on", but the reminder fires on the assignee's phone. When a parent switches on a reminder for Sara, Sara's phone (Android 13+) has never been asked, so it can't show anything. Resolution in this plan: `ReminderSync` also asks **once per phone** (SharedPreferences key `notificationsAsked`) the first time that phone has a reminder to schedule. This still isn't "at app start" for phones with nothing to remind about. **Firas/PM to confirm.**
5. **Files block is missing `lib/features/common/dialogs.dart`** (Modify). It gets `askReminderPermission(BuildContext, ReminderScheduler)`, shared by the chore sheet and the Family screen. Please add it to Task 9's Modify list when assembling the plan.
6. **Test placement.** The chore-sheet and Family-screen permission tests are in `test/app/reminder_sync_test.dart` (the only widget-test file Task 9 creates), so the Task 3 and Task 6 test files are not touched. The chore-sheet test opens `showChoreSheet(context, day:)`, finds `Key('choreRemind')` with `ensureVisible` and taps it. It relies on Task 6's defaults (new chore → Remind off).
7. **Family screen length.** The new switch sits above Leave family. If, after Tasks 2 and 3, a Release 1 Family screen test taps `leaveFamily`/`signOut` below the 800×600 window, Task 9 Step 17 tells the developer to add `ensureVisible` in `test/features/family_screen_test.dart` and report a Deviation. With the Release 1 layout all 128 tests passed.
8. **For Task 5 (not fixed here): `todayProvider` never changes while the app runs.** It reads the clock once, so a tablet left on the wall overnight keeps showing yesterday as "Today" until the app restarts. That matters for the 2a tablet board and even more for 2b wall mode. `ReminderSync` doesn't depend on this: it plans from a fresh `clockProvider()` each time it runs. Suggest a midnight tick (e.g. a `StreamProvider` or `Timer` that invalidates `todayProvider` at the next local midnight) in Task 5 or later.
9. **Parked, not in scope:** signing out leaves up to 7 days of that person's reminders scheduled on the phone (a later fix could have sign-out call `replaceAll([])`). The notification icon is the launcher icon (`@mipmap/ic_launcher`); a proper monochrome status-bar icon would look better. The channel name is set when first created, so switching language later doesn't rename it in Android settings (the notification text does follow the language).

---

## Plan-level amendments (orchestrator, 2026-09-29)

These override anything above that disagrees. Each was raised by a plan writer (see the "Drafting notes" at the end of each group of tasks) and accepted.

1. `todayProvider` is `NotifierProvider<TodayNotifier, DateTime>` and rolls over at midnight (Task 5). It is also refreshed on app resume (Task 8).
2. `choresForDay` and `lateChores` take an optional `languageCode`. Callers pass `Localizations.localeOf(context).languageCode`.
3. `choresForDay` also returns the day's done records whose chore was edited or deleted. Deleted-chore stand-ins are read-only: no tick and no edit (Tasks 4 and 6).
4. `fireAndForget` is changed in Task 6 to `then<void>(…, onError: …)` so a failing `Future<String>` never throws. Task 6's Files also cover `lib/data/write.dart`, `test/data/write_test.dart` and `test/app/home_shell_test.dart`.
5. Chore ticks get the same Undo SnackBar as shopping (Task 6), plus l10n keys `choreTicked`, `noChores` and `everyNMonthsOnDay`.
6. A child ticking a late chore records it for today, since children may only tick today or yesterday. Parents tick it for the late date (Task 8).
7. Reminders: `PlannedReminder.assignee`, `LocalReminderScheduler(channelName:, bodyFor:)`, `RemindEveryone.setOn(bool)`, and `askReminderPermission` in `lib/features/common/dialogs.dart`. Each phone asks for notification permission once, the first time it has a reminder to show (Task 9).
8. Task 1 also updates `lib/features/lists/item_tile.dart` for readable text on light tiles. `context.tokens` falls back to default tokens when a theme has none. `tabHistory` is replaced by `history`. `pumpWithFamily` gains optional `photoUrl` (Task 3) and `scheduler` (Task 9) parameters.
9. Parked, not in this release:
   - `choreDoneProvider` as `autoDispose`. Task 5's verified tests read it with `container.read(...future)`, and correctness isn't affected.
   - The member create rule doesn't validate `color` or `photoUrl`.
   - New joiners get their colour the next time a parent opens the app.
