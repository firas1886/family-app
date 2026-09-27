import 'package:flutter/foundation.dart';

/// Starts a Firestore write without waiting for the server.
/// Offline, the write is applied to the local cache at once and synced later.
void fireAndForget(Future<void> write) {
  write.catchError((Object error) {
    debugPrint('Firestore write failed: $error');
  });
}
