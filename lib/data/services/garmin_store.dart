/// The Store UUID is assigned by Garmin and is not the manifest application ID.
/// Verified in Connect IQ on 15 October 2026; pending Garmin review.
abstract final class GarminStore {
  static const listingId = String.fromEnvironment(
    'GARMIN_STORE_ID',
    defaultValue: 'e5582836-4178-442e-bd16-afa95b42e9c8',
  );

  static Uri? listingUri(String id) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      return null;
    }
    return Uri.https('apps.garmin.com', '/apps/$id');
  }

  static Uri? get uri => listingUri(listingId);
}
