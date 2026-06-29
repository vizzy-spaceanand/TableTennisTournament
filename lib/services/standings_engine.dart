/// Represents the calculated statistical state of a competitor within a group pool.
class PlayerGroupStats {
  final String id;
  final String name;
  final String group;
  
  int matchPoints = 0; // Win = 2, Loss = 1, Default = 0
  int matchesWon = 0;
  int matchesLost = 0;

  // Sub-Group Metrics (ITTF Isolation metrics for ties)
  int subGamesWon = 0;
  int subGamesLost = 0;
  int subPointsWon = 0;
  int subPointsLost = 0;

  PlayerGroupStats({required this.id, required this.name, required this.group});

  double get subGameRatio => subGamesLost == 0 ? double.infinity : subGamesWon / subGamesLost;
  double get subPointRatio => subPointsLost == 0 ? double.infinity : subPointsWon / subPointsLost;

  Map<String, dynamic> toMap(int rank) => {
    'rank': rank,
    'id': id,
    'name': name,
    'group': group,
    'match_points': matchPoints,
    'w_l': '$matchesWon - $matchesLost',
  };
}

/// Audit log snapshot detailing exactly how a tie-breaker filter sequence was executed.
class TieBreakerAuditLog {
  final String groupName;
  final List<String> tiedPlayerNames;
  final List<String> stepsTaken;
  final Map<String, String> finalRatiosEvaluated;

  TieBreakerAuditLog({
    required this.groupName, 
    required this.tiedPlayerNames, 
    required this.stepsTaken,
    required this.finalRatiosEvaluated,
  });
}

class StandingsEngine {
  /// Compiles dynamic group standings and generates an explainable "White Box" Audit Trail 
  /// using the official ITTF 5-Step Sub-Group Isolation Algorithm.
  static Map<String, dynamic> generateGroupStandings({
    required List<Map<String, dynamic>> players,
    required List<Map<String, dynamic>> matches,
  }) {
    // 1. Map player rows into structural statistical objects
    final Map<String, PlayerGroupStats> statsMap = {
      for (var p in players)
        p['id'].toString(): PlayerGroupStats(
          id: p['id'].toString(),
          name: p['name'].toString(),
          group: p['group_label']?.toString() ?? 'Default',
        )
    };

    // 2. Step 1: Process basic Match Points from completed fixtures
    for (var match in matches) {
      if (match['status'] != 'completed') continue;
      
      final p1Id = match['player1_id'].toString();
      final p2Id = match['player2_id'].toString();
      final p1Sets = match['player1_score'] as int? ?? 0;
      final p2Sets = match['player2_score'] as int? ?? 0;

      if (!statsMap.containsKey(p1Id) || !statsMap.containsKey(p2Id)) continue;

      if (p1Sets > p2Sets) {
        statsMap[p1Id]!.matchPoints += 2; // Win
        statsMap[p1Id]!.matchesWon += 1;
        statsMap[p2Id]!.matchPoints += 1; // Played Loss
        statsMap[p2Id]!.matchesLost += 1;
      } else if (p2Sets > p1Sets) {
        statsMap[p2Id]!.matchPoints += 2; // Win
        statsMap[p2Id]!.matchesWon += 1;
        statsMap[p1Id]!.matchPoints += 1; // Played Loss
        statsMap[p1Id]!.matchesLost += 1;
      }
    }

    // 3. Segment the statistics array by group classifications
    final Map<String, List<PlayerGroupStats>> groupsMap = {};
    for (var stat in statsMap.values) {
      groupsMap.putIfAbsent(stat.group, () => []).add(stat);
    }

    final Map<String, List<Map<String, dynamic>>> finalLeaderboards = {};
    final Map<String, Map<String, dynamic>> globalAuditTrails = {};

    // 4. Run the ITTF sorting loops independently inside each group pool
    groupsMap.forEach((groupName, groupPlayers) {
      final List<PlayerGroupStats> sortedGroupList = [];
      final List<String> groupAuditSteps = [];
      final Map<String, String> groupAuditRatios = {};

      // Cluster players by base match points to identify distinct tie groups
      final Map<int, List<PlayerGroupStats>> scoreBuckets = {};
      for (var p in groupPlayers) {
        scoreBuckets.putIfAbsent(p.matchPoints, () => []).add(p);
      }

      // Sort keys descending so highest match points sort first
      final sortedPointsKeys = scoreBuckets.keys.toList()..sort((a, b) => b.compareTo(a));

      for (var pts in sortedPointsKeys) {
        final bucketPlayers = scoreBuckets[pts]!;

        if (bucketPlayers.length == 1) {
          // No tie at this score level, insert safely
          sortedGroupList.add(bucketPlayers.first);
          continue;
        }

        // TIE DETECTED: Activate ITTF Sub-Group Isolation Filter Loop
        final tiedIds = bucketPlayers.map((p) => p.id).toSet();
        final tiedNames = bucketPlayers.map((p) => p.name).toList();
        groupAuditSteps.add("Tie Identified at $pts Match Points between: ${tiedNames.join(', ')}");

        // Step 2: Isolate the sub-group by wiping clean match stats and counting only head-to-head metrics
        for (var p in bucketPlayers) {
          p.subGamesWon = 0;
          p.subGamesLost = 0;
          p.subPointsWon = 0;
          p.subPointsLost = 0;
        }

        for (var match in matches) {
          if (match['status'] != 'completed') continue;
          final p1Id = match['player1_id'].toString();
          final p2Id = match['player2_id'].toString();

          // Rule constraint: Completely ignore matches played against players outside this tie circle!
          if (!tiedIds.contains(p1Id) || !tiedIds.contains(p2Id)) continue;

          final p1Sets = match['player1_score'] as int? ?? 0;
          final p2Sets = match['player2_score'] as int? ?? 0;
          
          statsMap[p1Id]!.subGamesWon += p1Sets;
          statsMap[p1Id]!.subGamesLost += p2Sets;
          statsMap[p2Id]!.subGamesWon += p2Sets;
          statsMap[p2Id]!.subGamesLost += p1Sets;

          // Parse the deep nested JSONB rally point dictionaries array
          final rawSetScores = match['set_scores'] as List<dynamic>? ?? [];
          for (var set in rawSetScores) {
            final p1Pts = set['p1'] as int? ?? 0;
            final p2Pts = set['p2'] as int? ?? 0;
            statsMap[p1Id]!.subPointsWon += p1Pts;
            statsMap[p1Id]!.subPointsLost += p2Pts;
            statsMap[p2Id]!.subPointsWon += p2Pts; 
            statsMap[p2Id]!.subPointsLost += p1Pts;
          }
        }

        // Step 3 & 4: Sub-sort the tied sub-group utilizing ITTF ratio cascades
        bucketPlayers.sort((a, b) {
          // Compare Game Ratios
          if (a.subGameRatio != b.subGameRatio) {
            return b.subGameRatio.compareTo(a.subGameRatio);
          }
          // Compare Point Ratios if Game Ratios are perfectly balanced
          if (a.subPointRatio != b.subPointRatio) {
            return b.subPointRatio.compareTo(a.subPointRatio);
          }
          // Step 5 Fallback: Head-to-Head evaluation if exactly two players remain locked
          return 0; 
        });

        // Generate the Explainable UI logging strings mapping out the execution details
        for (var p in bucketPlayers) {
          groupAuditRatios[p.name] = "Sets Ratio: ${p.subGameRatio.toStringAsFixed(2)} | Points Ratio: ${p.subPointRatio.toStringAsFixed(2)}";
        }
        groupAuditSteps.add("ITTF Isolation calculation finalized. Sub-group sorted successfully.");

        // Merge sorted sub-group array records back into master list
        sortedGroupList.addAll(bucketPlayers);
      }

      // Convert sorted objects into final indexing map lists
      int rankCounter = 1;
      finalLeaderboards[groupName] = sortedGroupList.map((p) => p.toMap(rankCounter++)).toList();
      globalAuditTrails[groupName] = {
        'steps': groupAuditSteps,
        'ratios': groupAuditRatios,
      };
    });

    return {
      'leaderboards': finalLeaderboards,
      'audit_trails': globalAuditTrails,
    };
  }
}