import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🌍 Dynamic Compile-Time Environment Variable Injections
  const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54323', // Smooth fallback to local instance gateway
  );
  
  const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '', // Safe local development fallback empty default
  );

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey, // ✅ FIXED: Replaced deprecated anonKey property
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Table Tennis Tournament Engine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      // 🏓 Note: If you have a dedicated TournamentListScreen or custom landing screen, 
      // swap out this placeholder Scaffold and point the home property directly to it!
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_tennis, size: 80, color: Colors.blueAccent),
              SizedBox(height: 16),
              Text(
                'Table Tennis Tournament Organizer',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                'Ecosystem fully linked and active.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}