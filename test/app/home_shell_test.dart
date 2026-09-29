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
