import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/dashboard_screen.dart'; // Import your clean new screen dashboard!

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Core background system initialization
  await Supabase.initialize(
    url: 'http://127.0.0.1:54321',
    publishableKey: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
  );

  runApp(const TableTennisApp());
}

class TableTennisApp extends StatelessWidget {
  const TableTennisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ping Pong MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const DashboardScreen(), // Launches cleanly onto our screen file
    );
  }
}