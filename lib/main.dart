import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🌍 Dynamic Compile-Time Environment Variable Injections
  const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321', // Automatically falls back to your local instance URL
  );

  const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH', // Automatically falls back to your local key
  );

  // Core background system initialization
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
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
      home: const AuthGate(), // 👈 Routes between Login and Dashboard based on session
    );
  }
}

/// Listens to Supabase auth state and shows the right screen automatically.
///
/// Public viewers (no login) still land on the Dashboard — reads are public
/// per the Phase 1 RLS policy. Login is only required for write actions
/// (create tournament, register player, log scores), which are gated
/// individually inside those screens.
///
/// If you want a fully gated app instead (login required to see anything),
/// swap the `else` branch below to return `const LoginScreen()` instead of
/// `const DashboardScreen()`.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStateStream;

  @override
  void initState() {
    super.initState();
    _authStateStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStateStream,
      builder: (context, snapshot) {
        // While Supabase is restoring a previous session on app start
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // The Dashboard is public — no auth required to view tournaments.
        // It internally shows/hides write actions (like "Create Tournament")
        // based on whether a user is logged in.
        return const DashboardScreen();
      },
    );
  }
}