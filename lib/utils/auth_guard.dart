import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';

/// Phase 1 auth guard.
///
/// Call this at the top of any write action (creating a tournament,
/// registering a player, logging a score) before hitting Supabase.
/// If the user isn't logged in, it shows a friendly dialog and offers
/// to take them to the Login screen. Returns true if the action should
/// proceed, false if it should be aborted.
///
/// Usage:
/// ```dart
/// onPressed: () async {
///   if (!await requireAuth(context)) return;
///   // ... proceed with the write action
/// }
/// ```
Future<bool> requireAuth(BuildContext context) async {
  final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
  if (isLoggedIn) return true;

  if (!context.mounted) return false;

  final shouldGoToLogin = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.lock_outline, color: Colors.deepOrange, size: 32),
      title: const Text('Sign in required'),
      content: const Text('You need to be signed in to do this.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sign in'),
        ),
      ],
    ),
  );

  if (shouldGoToLogin != true || !context.mounted) return false;

  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );

  // After returning from the login screen, check again — they may have
  // signed in successfully, or just hit back.
  return Supabase.instance.client.auth.currentUser != null;
}