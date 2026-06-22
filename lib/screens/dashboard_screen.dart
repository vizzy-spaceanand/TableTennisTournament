import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_tournament_screen.dart';
import 'tournament_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Map<String, dynamic>>> _tournamentsFuture;

  @override
  void initState() {
    super.initState();
    _refreshTournaments();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏓 Table Tennis Master'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), 
            onPressed: _refreshTournaments, // Cleaned up target execution block
          ),
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
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTournamentScreen()),
                  );
                  _refreshTournaments();
                },
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

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 1.5,
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.deepOrange,
                            child: Icon(Icons.emoji_events, color: Colors.white),
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