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
