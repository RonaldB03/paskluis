import 'package:local_auth/local_auth.dart';

class SecurityService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();

      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: 'Bevestig je identiteit om de pincode te bekijken',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}