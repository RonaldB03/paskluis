import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate({
    String? reason,
  }) async {
    try {
      final isSupported = await _auth.isDeviceSupported();

      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: reason ?? L10n.current.confirmYourIdentityToViewThePin,
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
