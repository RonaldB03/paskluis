import 'package:geolocator/geolocator.dart';
import 'location_resolver.dart';

import 'storage_service.dart';
import 'locale_service.dart';
import 'settings_service.dart';

enum LocationAccessState {
  checking,
  ready,
  permissionNeeded,
  permissionDeniedForever,
  servicesDisabled,
  unavailable,
}

class DeviceLocation {
  final double latitude;
  final double longitude;

  const DeviceLocation({required this.latitude, required this.longitude});
}

class LocationSnapshot {
  final LocationAccessState state;
  final DeviceLocation? location;

  const LocationSnapshot(this.state, [this.location]);
}

abstract final class LocationService {
  static final _resolver = LocationResolver(
    lastKnown: Geolocator.getLastKnownPosition,
    current: () => Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    ),
  );
  static double get nearbyRadiusMeters =>
      SettingsService.nearbyRadiusMeters.toDouble();

  static Future<LocationSnapshot> resolve({
    bool requestPermission = false,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationSnapshot(LocationAccessState.servicesDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationSnapshot(LocationAccessState.permissionNeeded);
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationSnapshot(
          LocationAccessState.permissionDeniedForever,
        );
      }

      final position = await _resolver.resolve();
      if (position == null) {
        return const LocationSnapshot(LocationAccessState.unavailable);
      }
      return LocationSnapshot(
        LocationAccessState.ready,
        DeviceLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (_) {
      return const LocationSnapshot(LocationAccessState.unavailable);
    }
  }

  static Future<void> rememberCardUse(String cardId) async {
    if (cardId.isEmpty || !SettingsService.locationCardsEnabled) return;
    final snapshot = await resolve();
    final location = snapshot.location;
    if (snapshot.state != LocationAccessState.ready || location == null) return;

    for (final key in StorageService.cardsBox.keys.toList()) {
      final raw = StorageService.cardsBox.get(key);
      if (raw is! Map || raw['id']?.toString() != cardId) continue;
      final card = Map<String, dynamic>.from(raw);
      card['lastUsedLatitude'] = location.latitude;
      card['lastUsedLongitude'] = location.longitude;
      card['locationRecordedAt'] = DateTime.now().toIso8601String();
      await StorageService.saveCard(key, card);
      return;
    }
  }

  static double? distanceTo(
    Map<String, dynamic> card,
    DeviceLocation current,
  ) {
    final latitude = double.tryParse(
      card['lastUsedLatitude']?.toString() ?? '',
    );
    final longitude = double.tryParse(
      card['lastUsedLongitude']?.toString() ?? '',
    );
    if (latitude == null || longitude == null) return null;
    return Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      latitude,
      longitude,
    );
  }

  static String formatDistance(double meters) {
    if (meters < 1000) {
      final roundedMeters = meters < 100
          ? (meters / 10).round() * 10
          : (meters / 50).round() * 50;
      return '$roundedMeters m';
    }
    final kilometers = meters / 1000;
    return kilometers < 10
        ? '${kilometers.toStringAsFixed(1).replaceAll('.', LocaleService.languageCode == 'nl' ? ',' : '.')} km'
        : '${kilometers.round()} km';
  }

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static Future<bool> openLocationSettings() =>
      Geolocator.openLocationSettings();
}
