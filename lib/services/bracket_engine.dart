class BracketEngine {
  static bool requiresKnockout(String format) {
    return format != 'league_topper';
  }

  static int getExpectedPlayerCount(String format) {
    switch (format) {
      case 'finals': return 2;
      case 'sf': return 4;
      case 'qf': return 8;
      case 'r16': return 16;
      case 'r32': return 32;
      default: return 0;
    }
  }

  /// 1. Generates the initial round from Group Pool leaderboards
  static List<Map<String, dynamic>> generateInitialKnockoutMatches({
    required String tournamentId,
    required String format,
    required Map<String, List<Map<String, dynamic>>> leaderboards,
  }) {
    if (!requiresKnockout(format)) return [];

    final int targetCount = getExpectedPlayerCount(format);
    final List<Map<String, dynamic>> qualifiedPool = [];

    int depthIndex = 1;
    while (qualifiedPool.length < targetCount) {
      bool foundAnyAtDepth = false;
      for (var groupName in leaderboards.keys) {
        final groupList = leaderboards[groupName]!;
        final playerAtDepth = groupList.firstWhere(
          (p) => p['rank'] == depthIndex,
          orElse: () => {},
        );
        if (playerAtDepth.isNotEmpty && qualifiedPool.length < targetCount) {
          qualifiedPool.add(playerAtDepth);
          foundAnyAtDepth = true;
        }
      }
      if (!foundAnyAtDepth) break;
      depthIndex++;
    }

    if (qualifiedPool.length < targetCount) {
      throw 'Cannot generate $format bracket! Need $targetCount qualified players, but only found ${qualifiedPool.length}.';
    }

    List<Map<String, dynamic>> generatedFixtures = [];
    final String stageLabel = _getStageLabel(format);

    int leftPointer = 0;
    int rightPointer = qualifiedPool.length - 1;

    while (leftPointer < rightPointer) {
      final p1 = qualifiedPool[leftPointer];
      final p2 = qualifiedPool[rightPointer];

      generatedFixtures.add({
        'tournament_id': tournamentId,
        'player1_id': p1['id'],
        'player2_id': p2['id'],
        'player1_name_fallback': '${p1['name']} (${p1['group']})',
        'player2_name_fallback': '${p2['name']} (${p2['group']})',
        'status': 'scheduled',
        'stage': stageLabel,
      });

      leftPointer++;
      rightPointer--;
    }

    return generatedFixtures;
  }

  /// 2. ✅ NEW: Progresses winners from one elimination tier to the next (e.g. Semifinals -> Finals)
  static List<Map<String, dynamic>> generateNextStageMatches({
    required String tournamentId,
    required List<Map<String, dynamic>> currentKnockoutMatches,
  }) {
    final stagesOrder = ['round_of_32', 'round_of_16', 'quarterfinal', 'semifinal', 'final'];
    String? latestActiveStage;

    // Determine what elimination tier we are currently on
    for (var stage in stagesOrder) {
      if (currentKnockoutMatches.any((m) => m['stage'] == stage)) {
        latestActiveStage = stage;
      }
    }

    if (latestActiveStage == null || latestActiveStage == 'final') return [];

    final stageMatches = currentKnockoutMatches.where((m) => m['stage'] == latestActiveStage).toList();
    
    if (stageMatches.any((m) => m['status'] != 'completed')) {
      throw 'Cannot advance yet! Some matches in the $latestActiveStage round are still in progress.';
    }

    final int currentIdx = stagesOrder.indexOf(latestActiveStage);
    final String nextStageLabel = stagesOrder[currentIdx + 1];

    // Filter and collect winning profile fallbacks sequentially
    List<Map<String, dynamic>> winners = [];
    for (var m in stageMatches) {
      final String winnerId = m['winner_id'].toString();
      if (winnerId == m['player1_id'].toString()) {
        winners.add({'id': m['player1_id'], 'name': m['player1_name_fallback']});
      } else {
        winners.add({'id': m['player2_id'], 'name': m['player2_name_fallback']});
      }
    }

    // Pair up bracket node neighbors sequentially (Winner M1 vs Winner M2)
    List<Map<String, dynamic>> nextFixtures = [];
    for (int i = 0; i < winners.length; i += 2) {
      if (i + 1 < winners.length) {
        nextFixtures.add({
          'tournament_id': tournamentId,
          'player1_id': winners[i]['id'],
          'player2_id': winners[i + 1]['id'],
          'player1_name_fallback': winners[i]['name'],
          'player2_name_fallback': winners[i + 1]['name'],
          'status': 'scheduled',
          'stage': nextStageLabel,
        });
      }
    }

    return nextFixtures;
  }

  static String _getStageLabel(String format) {
    switch (format) {
      case 'finals': return 'final';
      case 'sf': return 'semifinal';
      case 'qf': return 'quarterfinal';
      case 'r16': return 'round_of_16';
      case 'r32': return 'round_of_32';
      default: return 'knockout';
    }
  }
}