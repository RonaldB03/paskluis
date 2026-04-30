import 'package:local_auth/local_auth.dart';

class SecurityService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate() async {
    try {
      final canAuthenticate =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: 'Bevestig je identiteit om de pincode te bekijken',
        biometricOnly: false,
        stickyAuth: true,
      );
    } catch (_) {
      return false;
    }
  }
}