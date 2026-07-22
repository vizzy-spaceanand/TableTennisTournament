import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_tournament_screen.dart';
import 'tournament_details_screen.dart';
import 'auth/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Map<String, dynamic>>> _tournamentsFuture;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _refreshTournaments();

    // Rebuild the app bar (login button vs avatar) whenever auth state changes,
    // e.g. after the user logs in from another screen or logs out.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _refreshTournaments() {
    setState(() {
      _tournamentsFuture = Supabase.instance.client
          .from('tournaments')
          .select()
          .order('created_at', ascending: false)
          .then((value) => List<Map<String, dynamic>>.from(value));
    });
  }

  bool get _isLoggedIn => Supabase.instance.client.auth.currentUser != null;

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out')),
      );
    }
  }

  Future<void> _handleCreateTournamentTap() async {
    if (!_isLoggedIn) {
      // Send them to login first, then bounce back here to try again.
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (!mounted || !_isLoggedIn) return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTournamentScreen()),
    );
    _refreshTournaments();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏓 Table Tennis Master'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTournaments,
          ),
          if (_isLoggedIn)
            PopupMenuButton<String>(
              icon: const CircleAvatar(
                backgroundColor: Colors.deepOrange,
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
              onSelected: (value) {
                if (value == 'logout') _signOut();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    user?.userMetadata?['name'] ?? user?.email ?? 'Account',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18),
                      SizedBox(width: 8),
                      Text('Sign out'),
                    ],
                  ),
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                if (mounted) setState(() {}); // Refresh app bar after returning
              },
              icon: const Icon(Icons.login, color: Colors.black87),
              label: const Text('Sign in', style: TextStyle(color: Colors.black87)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: _handleCreateTournamentTap,
                icon: const Icon(Icons.add_circle),
                label: const Text('Configure New Tournament'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 35),
            const Text('Active Tournament Brackets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _tournamentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Query Failure: ${snapshot.error}'));
                  }

                  final dataRows = snapshot.data ?? [];
                  if (dataRows.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.layers_clear, size: 60, color: Colors.grey[400]),
                          const SizedBox(height: 15),
                          Text('No Active Tournaments Found', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: dataRows.length,
                    itemBuilder: (context, index) {
                      final item = dataRows[index];
                      final settings = item['settings'] as Map<String, dynamic>?;
                      final rrSets = settings?['best_of']?['round-robin'] ?? 3;
                      final koSets = settings?['best_of']?['knockout'] ?? 5;
                      final isOwnedByMe = item['created_by'] != null &&
                          item['created_by'] == Supabase.instance.client.auth.currentUser?.id;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 1.5,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepOrange,
                            child: Icon(
                              isOwnedByMe ? Icons.star : Icons.emoji_events,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(item['name'] ?? 'Unnamed Bracket', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('Stage Specs: Best of $rrSets Sets (Group) / Best of $koSets (Finals)'),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TournamentDetailsScreen(
                                  tournamentId: item['id'].toString(),
                                  tournamentName: item['name'] ?? 'Unnamed Tournament',
                                  roundRobinSets: rrSets,
                                  knockoutSets: koSets,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}