import 'package:flutter_test/flutter_test.dart';
import 'package:table_tennis_tournament/services/standings_engine.dart'; // Ensure this matches your pubspec name!

void main() {
  group('🏆 StandingsEngine - ITTF Tournament Scenario Tests', () {
    
    // --- SCENARIO 1: THE CLEAN SLATE ---
    test('Scenario 1: Simple Round Robin - Clear Winner, No Ties', () {
      final mockPlayers = [
        {'id': 'p1', 'name': 'Vivek', 'group_label': 'Group A'},
        {'id': 'p2', 'name': 'Rahul', 'group_label': 'Group A'},
      ];

      final mockMatches = [
        {
          'id': 1,
          'status': 'completed',
          'stage': 'group',
          'player1_id': 'p1',
          'player2_id': 'p2',
          'player1_score': 3,
          'player2_score': 1,
          'set_scores': [
            {'p1': 11, 'p2': 5},
            {'p1': 11, 'p2': 7},
            {'p1': 9, 'p2': 11},
            {'p1': 11, 'p2': 6},
          ]
        }
      ];

      final result = StandingsEngine.generateGroupStandings(
        players: mockPlayers,
        matches: mockMatches,
      );

      final groupA = result['leaderboards']['Group A'] as List<Map<String, dynamic>>;

      // Assertions
      expect(groupA.length, 2);
      expect(groupA[0]['name'], 'Vivek'); // Winner gets Rank 1
      expect(groupA[0]['match_points'], 2); // 2 Points for a Win
      expect(groupA[1]['name'], 'Rahul'); // Loser gets Rank 2
      expect(groupA[1]['match_points'], 1); // 1 Point for a Loss
    });

    // --- SCENARIO 2: THE TWO-WAY TIE ---
    test('Scenario 2: Two Players Equal on Match Points - Head-to-Head Resolves', () {
      final mockPlayers = [
        {'id': 'p1', 'name': 'Vivek', 'group_label': 'Group A'},
        {'id': 'p2', 'name': 'Rahul', 'group_label': 'Group A'},
      ];

      // Since they only played one match against each other, the winner of that fixture must rank higher
      final mockMatches = [
        {
          'id': 1,
          'status': 'completed',
          'stage': 'group',
          'player1_id': 'p1',
          'player2_id': 'p2',
          'player1_score': 1,
          'player2_score': 3,
          'set_scores': [
            {'p1': 5, 'p2': 11},
            {'p1': 11, 'p2': 8},
            {'p1': 6, 'p2': 11},
            {'p1': 9, 'p2': 11},
          ]
        }
      ];

      final result = StandingsEngine.generateGroupStandings(
        players: mockPlayers,
        matches: mockMatches,
      );

      final groupA = result['leaderboards']['Group A'] as List<Map<String, dynamic>>;

      expect(groupA[0]['name'], 'Rahul'); // Rahul won the head-to-head match
      expect(groupA[1]['name'], 'Vivek');
    });

    // --- SCENARIO 3: THE THREE-WAY TIE CASCADE ---
    test('Scenario 3: Three-Way Tie Cluster - Resolves via Point Ratio Cascades', () {
      final mockPlayers = [
        {'id': 'p1', 'name': 'Alice', 'group_label': 'Group B'},
        {'id': 'p2', 'name': 'Bob', 'group_label': 'Group B'},
        {'id': 'p3', 'name': 'Charlie', 'group_label': 'Group B'},
      ];

      // Rock-Paper-Scissors scenario: Alice beats Bob, Bob beats Charlie, Charlie beats Alice
      // All players finish with exactly 1 Win and 1 Played Loss (3 Base Match Points each).
      // All sets ratios inside the isolated circle are perfectly matched at 4-4 (Ratio 1.0).
      // Sorting must cascade down to the point level calculations!
      final mockMatches = [
        {
          'id': 1,
          'status': 'completed',
          'stage': 'group',
          'player1_id': 'p1', // Alice
          'player2_id': 'p2', // Bob
          'player1_score': 3,
          'player2_score': 1,
          'set_scores': [
            {'p1': 11, 'p2': 5},
            {'p1': 11, 'p2': 5},
            {'p1': 5, 'p2': 11},
            {'p1': 11, 'p2': 5}, // Alice +38 pts, Bob +26 pts
          ]
        },
        {
          'id': 2,
          'status': 'completed',
          'stage': 'group',
          'player1_id': 'p2', // Bob
          'player2_id': 'p3', // Charlie
          'player1_score': 3,
          'player2_score': 1,
          'set_scores': [
            {'p1': 11, 'p2': 5},
            {'p1': 11, 'p2': 5},
            {'p1': 5, 'p2': 11},
            {'p1': 11, 'p2': 5}, // Bob +38 pts, Charlie +26 pts
          ]
        },
        {
          'id': 3,
          'status': 'completed',
          'stage': 'group',
          'player1_id': 'p3', // Charlie
          'player2_id': 'p1', // Alice
          'player1_score': 3,
          'player2_score': 1,
          'set_scores': [
            {'p1': 11, 'p2': 0},
            {'p1': 11, 'p2': 0},
            {'p1': 0, 'p2': 11},
            {'p1': 11, 'p2': 0}, // Charlie +33 pts, Alice +11 pts
          ]
        }
      ];

      // Isolated Point Calculations Summary:
      // Charlie: Pts Won = 26 + 33 = 59 | Pts Lost = 38 + 11 = 49 | Ratio = 1.204 (Rank 1)
      // Bob:     Pts Won = 26 + 38 = 64 | Pts Lost = 38 + 26 = 64 | Ratio = 1.000 (Rank 2)
      // Alice:   Pts Won = 38 + 11 = 49 | Pts Lost = 26 + 33 = 59 | Ratio = 0.830 (Rank 3)

      final result = StandingsEngine.generateGroupStandings(
        players: mockPlayers,
        matches: mockMatches,
      );

      final groupB = result['leaderboards']['Group B'] as List<Map<String, dynamic>>;

      expect(groupB[0]['name'], 'Charlie');
      expect(groupB[1]['name'], 'Bob');
      expect(groupB[2]['name'], 'Alice');
      
      // Confirm the engine logged the audit trail calculation markers
      final groupBAudit = result['audit_trails']['Group B'];
      expect(groupBAudit['steps'].isNotEmpty, true);
    });

    // --- SCENARIO 4: THE EDGE-CASE GRID ---
    test('Scenario 4: Guard Bounds - Scheduled Matches are Safely Ignored', () {
      final mockPlayers = [
        {'id': 'p1', 'name': 'Vivek', 'group_label': 'Group C'},
        {'id': 'p2', 'name': 'Rahul', 'group_label': 'Group C'},
      ];

      final mockMatches = [
        {
          'id': 1,
          'status': 'scheduled', // Match hasn't been played yet!
          'stage': 'group',
          'player1_id': 'p1',
          'player2_id': 'p2',
          'player1_score': 0,
          'player2_score': 0,
          'set_scores': []
        }
      ];

      final result = StandingsEngine.generateGroupStandings(
        players: mockPlayers,
        matches: mockMatches,
      );

      final groupC = result['leaderboards']['Group C'] as List<Map<String, dynamic>>;

      // Both stay at 0 match points, sequence doesn't crash on empty fields
      expect(groupC[0]['match_points'], 0);
      expect(groupC[1]['match_points'], 0);
    });
  });
}