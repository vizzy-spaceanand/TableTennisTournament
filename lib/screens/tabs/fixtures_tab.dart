import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/standings_engine.dart';
import '../../services/bracket_engine.dart';

class FixturesTab extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final int roundRobinSets;
  final int knockoutSets;
  final String knockoutFormat;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> matches;
  final VoidCallback onRefreshRequired;

  const FixturesTab({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.roundRobinSets,
    required this.knockoutSets,
    required this.knockoutFormat,
    required this.players,
    required this.matches,
    required this.onRefreshRequired,
  });

  @override
  State<FixturesTab> createState() => _FixturesTabState();
}

class _FixturesTabState extends State<FixturesTab> {
  String _activeViewMode = 'list';

  Future<void> _generateRoundRobinFixtures(BuildContext context) async {
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
      widget.onRefreshRequired();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Engine Guard: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showScoreLoggingModal(BuildContext context, Map<String, dynamic> matchRow) async {
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
                              child: Text(modalError!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
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
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(hintText: '0', border: OutlineInputBorder(), contentPadding: EdgeInsets.zero),
                              ),
                            ),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('-')),
                            Expanded(
                              child: TextField(
                                controller: p2PointControllers[i],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
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
                  onPressed: () {
                    Navigator.pop(context);
                  }, 
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

                      if (t1.isEmpty && t2.isEmpty) {
                        continue;
                      }

                      int? pts1 = int.tryParse(t1);
                      int? pts2 = int.tryParse(t2);

                      if (pts1 == null || pts2 == null || pts1 < 0 || pts2 < 0) {
                        setModalState(() {
                          modalError = 'Set ${i + 1} fields require positive numeric scores.';
                        });
                        return;
                      }

                      if (p1HasMathematicallyWon || p2HasMathematicallyWon) {
                        setModalState(() {
                          modalError = 'Impossible Score! Set ${i + 1} cannot contain data entries.';
                        });
                        return;
                      }

                      bool isP1Win = (pts1 == 11 && pts2 <= 9) || (pts1 > 11 && (pts1 - pts2 == 2));
                      bool isP2Win = (pts2 == 11 && pts1 <= 9) || (pts2 > 11 && (pts2 - pts1 == 2));

                      if (!isP1Win && !isP2Win) {
                        setModalState(() {
                          modalError = 'Set ${i + 1} score ($pts1-$pts2) is invalid. Must clear by 2.';
                        });
                        return;
                      }

                      if (pts1 > pts2) {
                        computedP1SetsWon++;
                      } else {
                        computedP2SetsWon++;
                      }

                      calculatedSetsJson.add({'p1': pts1, 'p2': pts2});

                      if (computedP1SetsWon == setsRequiredToWin) {
                        p1HasMathematicallyWon = true;
                      }
                      if (computedP2SetsWon == setsRequiredToWin) {
                        p2HasMathematicallyWon = true;
                      }
                    }

                    if (computedP1SetsWon != setsRequiredToWin && computedP2SetsWon != setsRequiredToWin) {
                      setModalState(() {
                        modalError = 'Match is uncompleted!';
                      });
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
                      setModalState(() {
                        modalError = 'Server Write Failure: $error';
                      });
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
    widget.onRefreshRequired();
  }

  Widget _buildBracketNodeCard(Map<String, dynamic> match) {
    final String p1Name = match['player1_name_fallback']?.split(' (')[0] ?? 'TBD';
    final String p2Name = match['player2_name_fallback']?.split(' (')[0] ?? 'TBD';
    final bool isCompleted = match['status'] == 'completed';
    final int p1Score = match['player1_score'] ?? 0;
    final int p2Score = match['player2_score'] ?? 0;

    return Container(
      width: 240,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: isCompleted ? Colors.green.shade300 : Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Text(p1Name, style: TextStyle(fontWeight: p1Score > p2Score && isCompleted ? FontWeight.bold : FontWeight.normal)),
              trailing: Text(isCompleted ? p1Score.toString() : '-', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1, indent: 12, endIndent: 12),
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Text(p2Name, style: TextStyle(fontWeight: p2Score > p1Score && isCompleted ? FontWeight.bold : FontWeight.normal)),
              trailing: Text(isCompleted ? p2Score.toString() : '-', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Container(
              width: double.infinity,
              color: Colors.grey[50],
              child: TextButton(
                onPressed: () {
                  _showScoreLoggingModal(context, match);
                },
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                child: Text(isCompleted ? 'Edit Result' : 'Log Score', style: TextStyle(fontSize: 11, color: isCompleted ? Colors.green : Colors.blueAccent)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupMatches = widget.matches.where((m) => m['stage'] == 'group').toList();
    final knockoutMatches = widget.matches.where((m) => m['stage'] != 'group').toList();

    String? latestKnockoutStage;
    bool allLatestRoundCompleted = false;
    bool nextStageExists = false;

    if (knockoutMatches.isNotEmpty) {
      final stagesOrder = ['round_of_32', 'round_of_16', 'quarterfinal', 'semifinal', 'final'];
      for (var stage in stagesOrder) {
        if (knockoutMatches.any((m) => m['stage'] == stage)) {
          latestKnockoutStage = stage;
        }
      }
      if (latestKnockoutStage != null) {
        final latestMatches = knockoutMatches.where((m) => m['stage'] == latestKnockoutStage).toList();
        allLatestRoundCompleted = latestMatches.every((m) => m['status'] == 'completed');
        
        final int currentIdx = stagesOrder.indexOf(latestKnockoutStage);
        if (currentIdx + 1 < stagesOrder.length) {
          final String nextStageName = stagesOrder[currentIdx + 1];
          nextStageExists = knockoutMatches.any((m) => m['stage'] == nextStageName);
        }
      }
    }

    final Map<String, List<Map<String, dynamic>>> bracketRounds = {
      'Round of 32': knockoutMatches.where((m) => m['stage'] == 'round_of_32').toList(),
      'Round of 16': knockoutMatches.where((m) => m['stage'] == 'round_of_16').toList(),
      'Quarterfinals': knockoutMatches.where((m) => m['stage'] == 'quarterfinal').toList(),
      'Semifinals': knockoutMatches.where((m) => m['stage'] == 'semifinal').toList(),
      'Finals': knockoutMatches.where((m) => m['stage'] == 'final').toList(),
    };
    bracketRounds.removeWhere((key, list) => list.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Tournament Schedule', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (knockoutMatches.isNotEmpty) ...[
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'list', label: Text('Pool Matches'), icon: Icon(Icons.list)),
                      ButtonSegment(value: 'bracket', label: Text('Elimination Bracket'), icon: Icon(Icons.account_tree)),
                    ],
                    selected: {_activeViewMode},
                    onSelectionChanged: (set) {
                      setState(() => _activeViewMode = set.first);
                    },
                  ),
                ],
                
                if (widget.knockoutFormat != 'league_topper' && 
                    knockoutMatches.isEmpty && 
                    groupMatches.isNotEmpty && 
                    groupMatches.every((m) => m['status'] == 'completed')) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final standingsResult = StandingsEngine.generateGroupStandings(
                          players: widget.players,
                          matches: widget.matches,
                        );
                        final knockoutFixtures = BracketEngine.generateInitialKnockoutMatches(
                          tournamentId: widget.tournamentId,
                          format: widget.knockoutFormat,
                          leaderboards: standingsResult['leaderboards'],
                        );
                        if (knockoutFixtures.isNotEmpty) {
                          await Supabase.instance.client.from('matches').insert(knockoutFixtures);
                          widget.onRefreshRequired();
                          setState(() => _activeViewMode = 'bracket');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Bracket Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.account_tree),
                    label: const Text('Generate Bracket'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                  ),
                ],

                if (latestKnockoutStage != null && 
                    latestKnockoutStage != 'final' && 
                    allLatestRoundCompleted && 
                    !nextStageExists) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final nextStageFixtures = BracketEngine.generateNextStageMatches(
                          tournamentId: widget.tournamentId,
                          currentKnockoutMatches: knockoutMatches,
                        );
                        if (nextStageFixtures.isNotEmpty) {
                          await Supabase.instance.client.from('matches').insert(nextStageFixtures);
                          widget.onRefreshRequired();
                          
                          // 🛡️ REPAIRED SYNCHRONIZATION LINT PASS: Check local context mount state with block braces
                          if (!context.mounted) {
                            return;
                          }
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🏆 Winners Advanced to Next Elimination Tier!'), 
                              backgroundColor: Colors.purple,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Advancement Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.emoji_events),
                    label: const Text('Advance Bracket'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                  ),
                ],

                if (widget.matches.isEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      _generateRoundRobinFixtures(context);
                    },
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Generate Fixtures'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
              ],
            ),
          ],
        ),
        const Divider(height: 24),
        const SizedBox(height: 10),

        Expanded(
          child: widget.matches.isEmpty
              ? const Center(child: Text('No matches generated yet.'))
              : _activeViewMode == 'list'
                  ? ListView.builder(
                      itemCount: groupMatches.length,
                      itemBuilder: (context, index) {
                        final match = groupMatches[index];
                        final p1Name = match['player1_name_fallback'] ?? 'Player 1';
                        final p2Name = match['player2_name_fallback'] ?? 'Player 2';
                        final isCompleted = match['status'] == 'completed';
                        final p1Score = match['player1_score'] ?? 0;
                        final p2Score = match['player2_score'] ?? 0;

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
                                      Text(
                                        isCompleted ? 'Result: $p1Score - $p2Score Sets' : 'Status: SCHEDULED', 
                                        style: TextStyle(color: isCompleted ? Colors.green : Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _showScoreLoggingModal(context, match);
                                  },
                                  icon: Icon(isCompleted ? Icons.check_circle : Icons.edit_note, size: 18),
                                  label: Text(isCompleted ? 'Edit Score' : 'Log Score'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: bracketRounds.entries.map((roundEntry) {
                          final String roundTitle = roundEntry.key;
                          final List<Map<String, dynamic>> roundMatches = roundEntry.value;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Chip(
                                  label: Text(roundTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  backgroundColor: Colors.blueAccent,
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: SizedBox(
                                    width: 240,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: const ClampingScrollPhysics(),
                                      itemCount: roundMatches.length,
                                      itemBuilder: (context, matchIndex) {
                                        return _buildBracketNodeCard(roundMatches[matchIndex]);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
        ),
      ],
    );
  }
}