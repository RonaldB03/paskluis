import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/l10n.dart';

String authErrorMessage(AuthException error) {
  final message = error.message.toLowerCase();
  final code = error.code;
  if (code == 'insufficient_aal' ||
      message.contains('aal2') ||
      message.contains('mfa')) {
    return L10n.current.accountMfaRequired;
  }
  if (code == 'reauthentication_needed' ||
      message.contains('reauthentication')) {
    return L10n.current.accountReauthenticationRequired;
  }
  if (code == 'same_password' ||
      message.contains('different from the old password')) {
    return L10n.current.accountPasswordMustDiffer;
  }
  if (code == 'weak_password' ||
      message.contains('password should') ||
      message.contains('password must')) {
    return L10n.current.thePasswordDoesNotMeetTheSecurity;
  }
  if (message.contains('invalid login credentials'))
    return L10n.current.theEmailAddressOrPasswordIsIncorrect;
  if (message.contains('already registered'))
    return L10n.current.anAccountWithThisEmailAddressAlready;
  if (message.contains('email not confirmed'))
    return L10n.current.confirmYourEmailAddressUsingTheEmail;
  if (code == 'over_email_send_rate_limit' || error.statusCode == '429')
    return L10n.current.accountPleaseWait;
  return L10n.current.pleaseTryAgain;
}
