import 'package:flutter/material.dart';
import 'features/home/home_screen.dart';
import 'core/theme/app_theme.dart';
import 'data/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();

  runApp(const PasKluisApp());
}

class PasKluisApp extends StatelessWidget {
  const PasKluisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PasKluis',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}