import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paskluis_v1/data/services/account_service.dart';
import 'package:paskluis_v1/features/account/account_screen.dart';
import 'package:paskluis_v1/features/account/account_verification_dialog.dart';
import 'package:paskluis_v1/features/account/auth_error_message.dart';
import 'package:paskluis_v1/l10n/l10n.dart';

void main() {
  test(
    'MFA, recent-auth and reused-password errors are not weak-password errors',
    () {
      for (final error in [
        const AuthException(
          'AAL2 session is required to update email or password when MFA is enabled.',
          code: 'insufficient_aal',
        ),
        const AuthException(
          'Password update requires reauthentication',
          code: 'reauthentication_needed',
        ),
        const AuthException(
          'New password should be different from the old password.',
          code: 'same_password',
        ),
      ]) {
        expect(
          authErrorMessage(error),
          isNot(L10n.current.thePasswordDoesNotMeetTheSecurity),
        );
      }
      expect(
        authErrorMessage(
          const AuthException(
            'Password should be at least 8 characters.',
            code: 'weak_password',
          ),
        ),
        L10n.current.thePasswordDoesNotMeetTheSecurity,
      );
    },
  );

  testWidgets(
    'Failed password save keeps form open and permits a successful retry',
    (tester) async {
      var attempts = 0;
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ChangePasswordSheet(
                      save: (_) async {
                        attempts++;
                        if (attempts == 1)
                          throw const AuthException(
                            'New password should be different from the old password.',
                            code: 'same_password',
                          );
                      },
                    ),
                  );
                  completed = result != null;
                },
                child: const Text('Recover'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Recover'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'NewValidPassword9',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'NewValidPassword9',
      );
      await tester.tap(find.text(L10n.current.savePassword));
      await tester.pumpAndSettle();
      expect(completed, isFalse);
      expect(find.byType(ChangePasswordSheet), findsOneWidget);
      expect(find.text(L10n.current.accountPasswordMustDiffer), findsOneWidget);
      await tester.tap(find.text(L10n.current.savePassword));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(completed, isTrue);
      expect(find.byType(ChangePasswordSheet), findsNothing);
    },
  );

  testWidgets('MFA dialog does not complete when a code is rejected', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountVerificationDialog(
            instructions: 'Authenticator code',
            verify: (_) async {
              attempts++;
              throw const AuthException('Invalid code');
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text(L10n.current.accountVerify));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.byType(AccountVerificationDialog), findsOneWidget);
    expect(find.text(L10n.current.accountVerificationFailed), findsOneWidget);
  });

  testWidgets('Unknown or failed Plus status never displays Free version', (
    tester,
  ) async {
    for (final loading in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountPlusStatusCard(
              status: PlusStatus.inactive,
              loading: loading,
              failed: !loading,
            ),
          ),
        ),
      );
      expect(find.text(L10n.current.freeVersion), findsNothing);
      expect(
        find.text(
          loading
              ? L10n.current.checkingPlusStatus
              : L10n.current.accountPlusUnavailable,
        ),
        findsWidgets,
      );
    }
  });
}

