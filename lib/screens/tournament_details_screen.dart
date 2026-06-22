import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'player_registration_screen.dart';

class TournamentDetailsScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final int roundRobinSets;
  final int knockoutSets;

  const TournamentDetailsScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.roundRobinSets,
    required this.knockoutSets,
  });

  @override
  State<TournamentDetailsScreen> createState() => _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends State<TournamentDetailsScreen> {
  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _matches = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _refreshScreenData();
  }

  Future<void> _refreshScreenData() async {
    try {
      final playersData = await Supabase.instance.client
          .from('players')
          .select()
          .eq('tournament_id', widget.tournamentId)
          .order('group_label', ascending: true);

      final matchesData = await Supabase.instance.client
          .from('matches')
          .select()
          .eq('tournament_id', widget.tournamentId)
          .order('id', ascending: true);

      if (mounted) {
        setState(() {
          _players = List<Map<String, dynamic>>.from(playersData);
          _matches = List<Map<String, dynamic>>.from(matchesData);
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Data Pipeline Error: $e');
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  // --- SCORE LOGGING MODAL WITH FRONT-FACING DIALOG VALIDATION BANNER ---
  Future<void> _showScoreLoggingModal(Map<String, dynamic> matchRow) async {
    final String stage = matchRow['stage'] ?? 'group';
    final int maxBestOfFormat = (stage == 'group') ? widget.roundRobinSets : widget.knockoutSets;
    final int setsRequiredToWin = (maxBestOfFormat / 2).floor() + 1;

    List<TextEditingController> p1PointControllers = List.generate(maxBestOfFormat, (_) => TextEditingController());
    List<TextEditingController> p2PointControllers = List.generate(maxBestOfFormat, (_) => TextEditingController());

    final existingSets = matchRow['set_scores'] as List<dynamic>? ?? [];
    for (int i = 0; i < existingSets.length && i < maxBestOfFormat; i++) {
      p1PointControllers[i].text = existingSets[i]['p1']?.toString() ?? '';
      p2PointControllers[i].text = existingSets[i]['p2']?.toString() ?? '';
    }

    await showDialog(
      context: context,
      builder: (context) {
        String? modalError;

        // ✅ FIXED: Encloses the ENTIRE dialog so setModalState is shared across components
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.tournamentName, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  Text('Log Set Points (Best of $maxBestOfFormat)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (modalError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                modalError!,
                                style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    Container(
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '📋 Target win threshold: First to $setsRequiredToWin sets. Minimum 11 points per set with a 2-point clear margin.',
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        Expanded(
                          child: Text(
                            matchRow['player1_name_fallback']?.split(' (')[0] ?? 'Player 1',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            matchRow['player2_name_fallback']?.split(' (')[0] ?? 'Player 2',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),

                    for (int i = 0; i < maxBestOfFormat; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Text('Set ${i + 1}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 15),
                            Expanded(
                              child: TextField(
                                controller: p1PointControllers[i],
                                keyboardType: TextInputType.number, // ✅ FIXED
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(hintText: '0', border: OutlineInputBorder(), contentPadding: EdgeInsets.zero),
                              ),
                            ),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('-')),
                            Expanded(
                              child: TextField(
                                controller: p2PointControllers[i],
                                keyboardType: TextInputType.number, // ✅ FIXED
                                textAlign: TextAlign.center, // ✅ FIXED
                                decoration: const InputDecoration(hintText: '0', border: OutlineInputBorder(), contentPadding: EdgeInsets.zero),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () async {
                    int computedP1SetsWon = 0;
                    int computedP2SetsWon = 0;
                    List<Map<String, int>> calculatedSetsJson = [];
                    bool p1HasMathematicallyWon = false;
                    bool p2HasMathematicallyWon = false;

                    for (int i = 0; i < maxBestOfFormat; i++) {
                      String t1 = p1PointControllers[i].text.trim();
                      String t2 = p2PointControllers[i].text.trim();

                      if (t1.isEmpty && t2.isEmpty) continue;

                      int? pts1 = int.tryParse(t1);
                      int? pts2 = int.tryParse(t2);

                      if (pts1 == null || pts2 == null || pts1 < 0 || pts2 < 0) {
                        setModalState(() => modalError = 'Set ${i + 1} fields require positive numeric scores.');
                        return;
                      }

                      if (p1HasMathematicallyWon || p2HasMathematicallyWon) {
                        setModalState(() => modalError = 'Impossible Score! Set ${i + 1} cannot contain data entries because a competitor already won $setsRequiredToWin sets earlier.');
                        return;
                      }

                      bool isP1Win = (pts1 == 11 && pts2 <= 9) || (pts1 > 11 && (pts1 - pts2 == 2));
                      bool isP2Win = (pts2 == 11 && pts1 <= 9) || (pts2 > 11 && (pts2 - pts1 == 2));

                      if (!isP1Win && !isP2Win) {
                        setModalState(() => modalError = 'Set ${i + 1} score ($pts1-$pts2) is invalid. Must reach 11 pts minimum with a 2-point margin clear!');
                        return;
                      }

                      if (pts1 > pts2) {
                        computedP1SetsWon++;
                      } else {
                        computedP2SetsWon++;
                      }

                      calculatedSetsJson.add({'p1': pts1, 'p2': pts2});

                      if (computedP1SetsWon == setsRequiredToWin) p1HasMathematicallyWon = true;
                      if (computedP2SetsWon == setsRequiredToWin) p2HasMathematicallyWon = true;
                    }

                    if (computedP1SetsWon != setsRequiredToWin && computedP2SetsWon != setsRequiredToWin) {
                      setModalState(() => modalError = 'Match is uncompleted! A player needs exactly $setsRequiredToWin sets won to claim victory.');
                      return;
                    }

                    try {
                      final String winnerId = (computedP1SetsWon > computedP2SetsWon) 
                          ? matchRow['player1_id'].toString() 
                          : matchRow['player2_id'].toString();

                      await Supabase.instance.client.from('matches').update({
                        'player1_score': computedP1SetsWon,
                        'player2_score': computedP2SetsWon,
                        'status': 'completed',
                        'winner_id': winnerId,
                        'set_scores': calculatedSetsJson,
                      }).eq('id', matchRow['id']);

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🎯 Match Result Calculated & Persisted!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (error) {
                      setModalState(() => modalError = 'Server Write Failure: $error');
                    }
                  },
                  child: const Text('Confirm Official Score'),
                ),
              ],
            );
          },
        );
      },
    );
    _refreshScreenData();
  }

  // --- MATCH FIXTURE GENERATOR ENGINE ---
  Future<void> _generateRoundRobinFixtures() async {
    try {
      final players = await Supabase.instance.client
          .from('players')
          .select()
          .eq('tournament_id', widget.tournamentId);

      if (players.length < 2) {
        throw 'You need at least 2 players registered to spin up match pairs, boss!';
      }

      Map<String, List<Map<String, dynamic>>> groupBuckets = {};
      for (var player in players) {
        final String groupLabel = player['group_label'] ?? 'Group A';
        groupBuckets.putIfAbsent(groupLabel, () => []).add(player);
      }

      List<Map<String, dynamic>> matchesToInsert = [];

      groupBuckets.forEach((groupName, groupPlayers) {
        if (groupPlayers.length >= 2) {
          for (int i = 0; i < groupPlayers.length; i++) {
            for (int j = i + 1; j < groupPlayers.length; j++) {
              matchesToInsert.add({
                'tournament_id': widget.tournamentId,
                'player1_id': groupPlayers[i]['id'],
                'player2_id': groupPlayers[j]['id'],
                'player1_name_fallback': '${groupPlayers[i]['name']} ($groupName)',
                'player2_name_fallback': '${groupPlayers[j]['name']} ($groupName)',
                'status': 'scheduled',
                'stage': 'group',
              });
            }
          }
        }
      });

      if (matchesToInsert.isEmpty) {
        throw 'Groups are too sparse! Need at least 2 players inside a single group pool setup.';
      }

      await Supabase.instance.client.from('matches').insert(matchesToInsert);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Group Pool Match Fixtures Generated!'), backgroundColor: Colors.green),
        );
        _refreshScreenData(); 
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Engine Guard: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.tournamentName),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: "Roster Management"),
              Tab(icon: Icon(Icons.sports_tennis), text: "Match Fixtures"),
            ],
          ),
        ),
        body: _isLoadingData && _players.isEmpty && _matches.isEmpty
            ? const Center(child: CircularProgressIndicator()) 
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: TabBarView(
                  children: [
                    // --- TAB 1: PLAYER ROSTER ---
                    Column(
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
                                      tournamentId: widget.tournamentId,
                                      tournamentName: widget.tournamentName,
                                    ),
                                  ),
                                );
                                _refreshScreenData();
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
                          child: _players.isEmpty
                              ? const Center(child: Text('No players signed up yet. Add some profiles above!'))
                              : ListView.builder(
                                  itemCount: _players.length,
                                  itemBuilder: (context, index) {
                                    final player = _players[index];
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
                                                // ✅ FIXED: Routes to appropriate operations conditional on label choices
                                                if (action == 'edit') {
                                                  _updatePlayerInDatabase(player['id'], currentName, currentTier, currentGroup);
                                                } else if (action == 'delete') {
                                                  _deletePlayerFromDatabase(player['id'], currentName);
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
                    ),

                    // --- TAB 2: ROUND ROBIN MATCH FIXTURES ---
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tournament Schedule', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ElevatedButton.icon(
                              onPressed: _generateRoundRobinFixtures,
                              icon: const Icon(Icons.flash_on),
                              label: const Text('Generate Fixtures'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _matches.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.calendar_today, size: 50, color: Colors.grey),
                                      SizedBox(height: 10),
                                      Text('No matches generated yet.', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text('Register players across groups, then tap to pair!', textAlign: TextAlign.center),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _matches.length,
                                  itemBuilder: (context, index) {
                                    final match = _matches[index];
                                    final p1Name = match['player1_name_fallback'] ?? 'Player 1';
                                    final p2Name = match['player2_name_fallback'] ?? 'Player 2';
                                    final isCompleted = match['status'] == 'completed';
                                    
                                    final p1Score = match['player1_score'] ?? 0;
                                    final p2Score = match['player2_score'] ?? 0;

                                    String setScoresString = '';
                                    if (isCompleted && match['set_scores'] != null) {
                                      final setsList = match['set_scores'] as List<dynamic>;
                                      setScoresString = ' (${setsList.map((s) => '${s['p1']}-${s['p2']}').join(', ')})';
                                    }

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      color: isCompleted ? Colors.green[50] : Colors.white,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('$p1Name vs $p2Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                  const SizedBox(height: 4),
                                                  isCompleted 
                                                    ? RichText(
                                                        text: TextSpan(
                                                          style: const TextStyle(color: Colors.black, fontSize: 13),
                                                          children: [
                                                            const TextSpan(text: 'Result: ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                                            TextSpan(text: '$p1Score - $p2Score Sets', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                            TextSpan(text: setScoresString, style: TextStyle(color: Colors.grey[700], fontSize: 12, fontStyle: FontStyle.italic)),
                                                          ],
                                                        ),
                                                      )
                                                    : Text('Status: ${match['status'].toString().toUpperCase()}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: () => _showScoreLoggingModal(match),
                                              icon: Icon(isCompleted ? Icons.check_circle : Icons.edit_note, size: 18),
                                              label: Text(isCompleted ? 'Edit Score' : 'Log Score'),
                                              style: isCompleted ? ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green) : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // --- CRUD OPERATION: UPDATE PLAYER PROFILE ---
  Future<void> _updatePlayerInDatabase(dynamic playerId, String currentName, String currentTier, String currentGroup) async {
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
    _refreshScreenData();
  }

  // --- CRUD OPERATION: DELETE PLAYER PROFILE ---
  Future<void> _deletePlayerFromDatabase(dynamic playerId, String playerName) async {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ Player removed from tournament.'), backgroundColor: Colors.orange),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deletion Block: $error'), backgroundColor: Colors.red),
          );
        }
      }
      _refreshScreenData();
    }
  }
}