/// The Store UUID is assigned by Garmin and is not the manifest application ID.
/// Leave unset until the actual listing has been verified.
abstract final class GarminStore {
  static const listingId = String.fromEnvironment('GARMIN_STORE_ID');

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
