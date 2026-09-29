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

    test('text on To buy tiles is coral 900 in both themes and meets 4.5:1', () {
      for (final brightness in Brightness.values) {
        final tokens = buildTheme(brightness).extension<AppTokens>()!;
        expect(tokens.onToBuy, const Color(0xFF4A1B0C), reason: '$brightness');
        expect(contrast(tokens.onToBuy, tokens.toBuy), greaterThanOrEqualTo(4.5), reason: '$brightness');
      }
      expect(AppTokens.light.copyWith().onToBuy, AppTokens.light.onToBuy);
      expect(AppTokens.light.copyWith(onToBuy: const Color(0xFF000000)).onToBuy, const Color(0xFF000000));
      expect(AppTokens.light.lerp(AppTokens.dark, 0.5).onToBuy, const Color(0xFF4A1B0C));
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
