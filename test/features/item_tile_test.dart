import 'package:family_app/core/text.dart';
import 'package:family_app/features/lists/item_tile.dart';
import 'package:family_app/features/lists/list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

/// Tiles must fit small phones: letter, 2-line name and quantity all visible,
/// with no RenderFlex overflow.
void main() {
  const names = {
    'English': 'Extra virgin olive oil large bottle',
    'Arabic': 'زيت زيتون بكر ممتاز عبوة كبيرة',
  };
  const sizes = [Size(360, 740), Size(320, 640)];
  const scales = [1.0, 1.3];

  for (final entry in names.entries) {
    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets('${entry.key} long name + quantity fits at $size, text x$scale', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final db = await seedFamily();
          await db.doc('families/f1/items/milk').update({'name': entry.value});
          await pumpWithFamily(tester, db: db, child: const ListScreen(listId: 'l1'));

          expect(tester.takeException(), isNull);
          expect(find.text(tileLetter(entry.value)), findsWidgets);
          expect(find.text(entry.value), findsOneWidget);
          expect(find.text('2 L'), findsOneWidget);
        });
      }
    }
  }

  testWidgets('text on the coral To buy tile meets WCAG AA 4.5:1', (tester) async {
    const coral = Color(0xFFEE6A6A);
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const ListScreen(listId: 'l1'));

    // The tile keeps its coral colour.
    final toBuyTile = find.byWidgetPredicate((w) => w is ItemTile && w.color == coral);
    expect(toBuyTile, findsOneWidget);
    expect(tester.widget<ItemTile>(toBuyTile).name, 'Milk');
    final box = tester.widget<AnimatedContainer>(
      find.descendant(of: toBuyTile, matching: find.byType(AnimatedContainer)),
    );
    expect((box.decoration! as BoxDecoration).color, coral);

    // Letter, name and quantity caption.
    for (final label in ['M', 'Milk', '2 L']) {
      final text = tester.widget<Text>(find.descendant(of: toBuyTile, matching: find.text(label)));
      final shown = Color.alphaBlend(text.style!.color!, coral);
      final ratio = contrast(shown, coral);
      debugPrint('To buy tile "$label": ${ratio.toStringAsFixed(2)}:1');
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '"$label" on the To buy tile');
    }
  });
}
