import 'package:flutter/material.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/locale_service.dart';
import '../../features/settings/backup_screen.dart';

class BackupHealthCard extends StatelessWidget {
  const BackupHealthCard({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: BackupService.revision,
    builder: (context, _, child) {
      if (!BackupService.enabled) return const SizedBox.shrink();
      final last = DateTime.tryParse(BackupService.lastSuccess ?? '');
      final stale =
          last == null ||
          DateTime.now().difference(last) > const Duration(days: 7);
      if (BackupService.error == null && !stale) return const SizedBox.shrink();
      final nl = LocaleService.languageCode == 'nl';
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(nl ? 'Controleer je back-up' : 'Check your backup'),
          subtitle: Text(
            nl
                ? 'Je nieuwste wijzigingen zijn mogelijk nog niet veiliggesteld.'
                : 'Your latest changes may not be backed up yet.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BackupScreen()),
          ),
        ),
      );
    },
  );
}
