import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../player_registration_screen.dart';

class RosterTab extends StatelessWidget {
  final String tournamentId;
  final String tournamentName;
  final List<Map<String, dynamic>> players;
  final VoidCallback onRefreshRequired;

  const RosterTab({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.players,
    required this.onRefreshRequired,
  });

  // --- CRUD OPERATION: UPDATE PLAYER PROFILE ---
  Future<void> _updatePlayerInDatabase(BuildContext context, dynamic playerId, String currentName, String currentTier, String currentGroup) async {
    final nameController = TextEditingController(text: currentName);
    String selectedTier = currentTier;
    String selectedGroup = currentGroup;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modify Competitor Metrics', style: TextStyle(fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Player Name')),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTier,
                      decoration: const InputDecoration(labelText: 'Skill Tier'),
                      items: const [
                        DropdownMenuItem(value: 'Beginner', child: Text('Beginner Tier')),
                        DropdownMenuItem(value: 'Intermediate', child: Text('Intermediate Tier')),
                        DropdownMenuItem(value: 'Advanced', child: Text('Advanced Tier')),
                      ],
                      onChanged: (val) => setDialogState(() => selectedTier = val!),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGroup,
                      decoration: const InputDecoration(labelText: 'Group Bracket Pool'),
                      items: const [
                        DropdownMenuItem(value: 'Group A', child: Text('Group A Pool')),
                        DropdownMenuItem(value: 'Group B', child: Text('Group B Pool')),
                        DropdownMenuItem(value: 'Group C', child: Text('Group C Pool')),
                        DropdownMenuItem(value: 'Group D', child: Text('Group D Pool')),
                      ],
                      onChanged: (val) => setDialogState(() => selectedGroup = val!),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await Supabase.instance.client.from('players').update({
                    'name': nameController.text.trim(),
                    'class_tier': selectedTier,
                    'group_label': selectedGroup,
                  }).eq('id', playerId);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🎉 Player row updated successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Update Failure: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
    onRefreshRequired();
  }

  // --- CRUD OPERATION: DELETE PLAYER PROFILE ---
  Future<void> _deletePlayerFromDatabase(BuildContext context, dynamic playerId, String playerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Roster Removal?'),
        content: Text('Are you sure you want to permanently remove $playerName from this tournament?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('players').delete().eq('id', playerId);
        onRefreshRequired();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deletion Block: $error'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Registered Roster', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerRegistrationScreen(
                      tournamentId: tournamentId,
                      tournamentName: tournamentName,
                    ),
                  ),
                );
                onRefreshRequired();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Player'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 10),
        Expanded(
          child: players.isEmpty
              ? const Center(child: Text('No players signed up yet. Add some profiles above!'))
              : ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final currentGroup = player['group_label'] ?? 'Group A';
                    final currentTier = player['class_tier'] ?? 'Beginner';
                    final currentName = player['name'] ?? 'Unknown Player';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[50],
                          child: Icon(Icons.person, color: Colors.blueAccent.shade200),
                        ),
                        title: Text(currentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Tier: $currentTier'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(currentGroup, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueAccent)),
                              backgroundColor: Colors.blue.shade50,
                              side: BorderSide(color: Colors.blue.shade100),
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _updatePlayerInDatabase(context, player['id'], currentName, currentTier, currentGroup);
                                } else if (action == 'delete') {
                                  _deletePlayerFromDatabase(context, player['id'], currentName);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit Player / Group Pool')])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete Profile', style: TextStyle(color: Colors.red))])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}