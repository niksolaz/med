import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.load();

  runApp(MedApp(storage: storage));
}

class MedApp extends StatelessWidget {
  final StorageService storage;

  const MedApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Med Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1b5a5a),
          primary: const Color(0xFF1b5a5a),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFfafafa),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      home: HomeScreen(storage: storage),
    );
  }
}