import 'package:family_app/core/text.dart';
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
}
