import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tabs/roster_tab.dart';
import 'tabs/fixtures_tab.dart';
import 'tabs/standings_tab.dart';

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
  String _knockoutFormat = 'league_topper'; // 👈 ADDED: Local state format tracker
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _refreshScreenData();
  }

  Future<void> _refreshScreenData() async {
    try {
      // 1. Fetch current tournament configuration rules dynamically
      final tournamentData = await Supabase.instance.client
          .from('tournaments')
          .select('knockout_format')
          .eq('id', widget.tournamentId)
          .maybeSingle();

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
          
          if (tournamentData != null && tournamentData['knockout_format'] != null) {
            _knockoutFormat = tournamentData['knockout_format'].toString();
          }
          
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.tournamentName),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: "Roster Management"),
              Tab(icon: Icon(Icons.sports_tennis), text: "Match Fixtures"),
              Tab(icon: Icon(Icons.analytics), text: "Group Standings"),
            ],
          ),
        ),
        body: _isLoadingData && _players.isEmpty && _matches.isEmpty
            ? const Center(child: CircularProgressIndicator()) 
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: TabBarView(
                  children: [
                    RosterTab(
                      tournamentId: widget.tournamentId,
                      tournamentName: widget.tournamentName,
                      players: _players,
                      onRefreshRequired: _refreshScreenData,
                    ),
                    
                    // 🔌 WIRING PASS: Added knockoutFormat parameter down the pipe
                    FixturesTab(
                      tournamentId: widget.tournamentId,
                      tournamentName: widget.tournamentName,
                      roundRobinSets: widget.roundRobinSets,
                      knockoutSets: widget.knockoutSets,
                      knockoutFormat: _knockoutFormat, // 👈 PASS THIS NOW
                      players: _players,
                      matches: _matches,
                      onRefreshRequired: _refreshScreenData,
                    ),
                    
                    StandingsTab(
                      players: _players,
                      matches: _matches,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}