import 'package:family_app/features/lists/lists_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

void main() {
  testWidgets('parents can create a list', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const ListsScreen());
    expect(find.text('Home'), findsOneWidget);
    await tester.tap(find.byKey(const Key('newListFab')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('promptField')), 'Pharmacy');
    await tester.tap(find.byKey(const Key('promptConfirm')));
    await settle(tester);
    expect(find.text('Pharmacy'), findsOneWidget);
  });

  testWidgets('children cannot create lists', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ListsScreen());
    expect(find.byKey(const Key('newListFab')), findsNothing);
  });
}
