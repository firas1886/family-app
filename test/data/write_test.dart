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
