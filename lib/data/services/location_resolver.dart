import 'package:geolocator/geolocator.dart';

/// Reuse a recent accurate fix before starting GPS. Concurrent screens share
/// the expensive measurement; permission checks remain in LocationService.
class LocationResolver {
  final Future<Position?> Function() lastKnown;
  final Future<Position> Function() current;
  final DateTime Function() now;
  Future<Position?>? _pending;

  LocationResolver({
    required this.lastKnown,
    required this.current,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  bool usable(Position? position, Duration maxAge) =>
      position != null &&
      now().difference(position.timestamp).abs() <= maxAge &&
      position.accuracy.isFinite && position.accuracy >= 0 &&
      position.accuracy <= 100 &&
      position.latitude.isFinite && position.latitude.abs() <= 90 &&
      position.longitude.isFinite && position.longitude.abs() <= 180;

  Future<Position?> resolve() async {
    Position? cached;
    try { cached = await lastKnown(); } catch (_) {}
    if (usable(cached, const Duration(seconds: 30))) return cached;
    final existing = _pending;
    if (existing != null) return existing;
    final pending = _measure(cached);
    _pending = pending;
    try {
      return await pending;
    } finally {
      if (identical(_pending, pending)) _pending = null;
    }
  }

  Future<Position?> _measure(Position? cached) async {
    try {
      final position = await current();
      if (usable(position, const Duration(minutes: 2))) return position;
    } catch (_) {}
    return usable(cached, const Duration(minutes: 2)) ? cached : null;
  }
}
