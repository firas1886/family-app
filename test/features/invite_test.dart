import 'package:family_app/features/family/family_screen.dart';
import 'package:family_app/features/family/invite.dart';
import 'package:family_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

void main() {
  const link = 'https://github.com/firas/family-app/releases/latest/download/family-app.apk';

  test('the invite carries the link and the code (English)', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final text = inviteText(l, code: 'ABC234', link: link);
    expect(text, contains(link));
    expect(text, contains('ABC234'));
  });

  test('the invite carries the link and the code (Arabic)', () {
    final l = lookupAppLocalizations(const Locale('ar'));
    final text = inviteText(l, code: 'ABC234', link: link);
    expect(text, contains(link));
    expect(text, contains('ABC234'));
  });

  test('invite without a link still carries the code', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final text = inviteText(l, code: 'ABC234', link: '');
    expect(text, contains('ABC234'));
    expect(text, isNot(contains('http')));
  });

  testWidgets('Invite to family shares the code once (no link in a test build)', (tester) async {
    final db = await seedFamily();
    final shared = <String>[];
    await pumpWithFamily(tester, db: db, shared: shared, child: const FamilyScreen());
    await tester.tap(find.byKey(const Key('inviteFamily')));
    await settle(tester);
    expect(shared, hasLength(1));
    expect(shared.single, contains('ABC234'));
    // appDownloadUrl is empty in a test build, so this is the no-link form.
    expect(shared.single, lookupAppLocalizations(const Locale('en')).inviteMessageNoLink('ABC234'));
  });
}
