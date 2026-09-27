import 'package:flutter/material.dart';
import '../../data/services/account_service.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/locale_service.dart';

/// Both entry points use the same consent and restore-first protections.
abstract final class BackupActions {
  static String t(String nl, String en) => LocaleService.languageCode == 'nl' ? nl : en;
  static String message(String code) => switch (code) {
    'RESTORE_FIRST' => t('Er staat al een back-up klaar. Open Herstellen en beheren om die eerst te herstellen.', 'A backup already exists. Open Restore and manage to restore it first.'),
    'BACKUP_QUOTA' => t('De back-up past niet binnen 10 MB voor drie versies samen. Je vorige back-up blijft bewaard.', 'The backup exceeds 10 MB across three versions. Your previous backup is safe.'),
    'ACCOUNT_CHANGED' || 'SESSION_REPLACED' => t('Je account of actieve toestel is gewijzigd. Log opnieuw in.', 'Your account or active device changed. Sign in again.'),
    _ => t('De actie is niet gelukt. Open Herstellen en beheren om de status te bekijken en opnieuw te proberen.', 'The action failed. Open Restore and manage to check the status and retry.'),
  };
  static Future<bool> _confirm(BuildContext context, String title, String detail) async => await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: Text(title), content: Text(detail), actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Annuleren', 'Cancel'))),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Doorgaan', 'Continue'))),
    ],
  )) ?? false;
  static void _error(BuildContext context, Object e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message(e.toString().split(': ').last))));
  }
  static Future<bool> enable(BuildContext context, bool value, {bool oneTime = false}) async {
    final userId = AccountService.currentUser?.id;
    if (userId == null || BackupService.busy) return false;
    if (value && !await _confirm(context,
      oneTime ? t('Eenmalige back-up maken?', 'Create a one-time backup?') : t('Automatische back-up inschakelen?', 'Enable automatic backup?'),
      t('Je eigen kaarten, pincodes en afbeeldingen worden versleuteld bij je account opgeslagen. Niet-gekoppelde kaarten worden aan dit back-upaccount gekoppeld. Ontvangen gedeelde kaarten worden niet meegenomen. Maximaal 10 MB en drie versies. PasKluis beheert de ontsleutelsleutels voor herstel na telefoonverlies.', 'Your own cards, PINs and images will be encrypted and stored with your account. Unassigned cards will be linked to this backup account. Received shared cards are excluded. Maximum 10 MB and three versions. PasKluis manages decryption keys for recovery after phone loss.') +
        (oneTime ? t('\nAutomatische back-up blijft uit.', '\nAutomatic backup stays off.') : ''),
    )) return false;
    if (!context.mounted || AccountService.currentUser?.id != userId) return false;
    try { await BackupService.setEnabled(value); if (oneTime) await BackupService.setEnabled(false); return true; }
    catch (e) { _error(context, e); return false; }
  }
  static Future<void> upload(BuildContext context) async {
    if (BackupService.busy) return;
    final userId = AccountService.currentUser?.id;
    if (userId == null) return;
    if (!BackupService.enabled && !await enable(context, true, oneTime: true)) return;
    if (!context.mounted || userId != AccountService.currentUser?.id) return;
    await BackupService.upload();
    if (BackupService.error != null) _error(context, BackupService.error!);
    else if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Back-up opgeslagen', 'Backup saved'))));
  }
}
