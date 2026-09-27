import 'package:family_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const PlaceholderApp());
    expect(find.text('Family'), findsOneWidget);
  });
}
