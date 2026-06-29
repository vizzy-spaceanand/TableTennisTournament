import 'package:flutter/material.dart';
import '../../services/standings_engine.dart';

class StandingsTab extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> matches;

  const StandingsTab({
    super.key,
    required this.players,
    required this.matches,
  });

  void _showTieBreakerInspector(BuildContext context, String groupName, Map<String, dynamic> auditData) {
    final List<dynamic> steps = auditData['steps'] ?? [];
    final Map<dynamic, dynamic> ratios = auditData['ratios'] ?? {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.psychology, color: Colors.deepOrange),
            const SizedBox(width: 10),
            Text('$groupName Math Audit Trail', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ITTF Isolation Calculation Steps:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                const SizedBox(height: 8),
                if (steps.isEmpty)
                  const Text('No ties detected at this score boundary. Sorted naturally via basic Match Points.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
                else
                  ...steps.map((step) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                            Expanded(child: Text(step.toString(), style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                const Divider(height: 24),
                const Text('Computed Performance Metrics Ratio Map:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                const SizedBox(height: 8),
                ...ratios.entries.map((entry) => Card(
                      color: Colors.grey[50],
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        title: Text(entry.key.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(entry.value.toString(), style: TextStyle(color: Colors.grey[800], fontFamily: 'monospace')),
                      ),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Dismiss Monitor')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final standingsResult = StandingsEngine.generateGroupStandings(players: players, matches: matches);
    final leaderboards = standingsResult['leaderboards'] as Map<String, List<Map<String, dynamic>>>;
    final auditTrails = standingsResult['audit_trails'] as Map<String, Map<String, dynamic>>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Live Group Rankings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text('Rankings adjust in real-time as match points and set margins are logged.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const Divider(),
        Expanded(
          child: leaderboards.isEmpty
              ? const Center(child: Text('No active group mappings compiled. Add players to groups to initiate leaderboards!'))
              : ListView.builder(
                  itemCount: leaderboards.keys.length,
                  itemBuilder: (context, groupIndex) {
                    final String groupName = leaderboards.keys.elementAt(groupIndex);
                    final List<Map<String, dynamic>> groupRankings = leaderboards[groupName]!;
                    final Map<String, dynamic> auditTrail = auditTrails[groupName] ?? {'steps': [], 'ratios': {}};

                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      elevation: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: Colors.deepOrange.shade50, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                                TextButton.icon(
                                  onPressed: () => _showTieBreakerInspector(context, groupName, auditTrail),
                                  icon: const Icon(Icons.insights, size: 16, color: Colors.deepOrange),
                                  label: const Text('Tie-Breaker Logic', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                ),
                              ],
                            ),
                          ),
                          
                          DataTable(
                            columnSpacing: 18,
                            headingRowHeight: 40,
                            columns: const [
                                 DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold))),
                                 DataColumn(label: Text('Player Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                 DataColumn(label: Text('MP', style: TextStyle(fontWeight: FontWeight.bold))),
                                 DataColumn(label: Text('W - L', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: groupRankings.map((playerRow) {
                              final int currentRank = playerRow['rank'] as int;
                              
                              return DataRow(
                                color: WidgetStateProperty.resolveWith<Color?>((states) {
                                  if (currentRank <= 2) return Colors.green.withValues(alpha: 0.03); 
                                  return null;
                                }),
                                cells: [
                                  DataCell(
                                    CircleAvatar(
                                      radius: 11,
                                      backgroundColor: currentRank <= 2 ? Colors.green : Colors.grey[300],
                                      child: Text(currentRank.toString(), style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  DataCell(Text(playerRow['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(Text(playerRow['match_points'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(playerRow['w_l'].toString())),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}