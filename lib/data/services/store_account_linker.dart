/// Coalesces automatic links from the several widgets loading Plus status.
/// Only an unlinked, verified store purchase may be claimed automatically.
class StoreAccountLinker {
  final Map<String, Future<void>> _pending = {};

  Future<void> link({
    required String userId,
    required String? Function() currentUserId,
    required bool active,
    required String? linkedUserId,
    required Future<void> Function() verifyAndLink,
  }) {
    if (!active || linkedUserId != null || currentUserId() != userId) {
      return Future.value();
    }
    return _pending.putIfAbsent(userId, () async {
      try {
        // Defer until the pending entry exists, including synchronous failures.
        await Future<void>.value();
        if (currentUserId() == userId) await verifyAndLink();
      } finally {
        _pending.remove(userId);
      }
    });
  }
}
