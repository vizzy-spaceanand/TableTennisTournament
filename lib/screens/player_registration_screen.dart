import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlayerRegistrationScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;

  const PlayerRegistrationScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<PlayerRegistrationScreen> createState() => _PlayerRegistrationScreenState();
}

class _PlayerRegistrationScreenState extends State<PlayerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedTier = 'Beginner';
  String _selectedGroup = 'Group A'; // Default group choice cell
  bool _isLoading = false;

  Future<void> _registerPlayerToPostgres() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final playerName = _nameController.text.trim();

      await Supabase.instance.client.from('players').insert({
        'name': playerName,
        'class_tier': _selectedTier,
        'tournament_id': widget.tournamentId,
        'group_label': _selectedGroup, // Saves group choice safely
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Player Registered & Assigned to Group!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Error: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Competitor Player')),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registering for: ${widget.tournamentName}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Player Real Name *', hintText: 'e.g., Ananya Nair'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a competitor name' : null,
                    ),
                    const SizedBox(height: 25),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTier,
                      decoration: const InputDecoration(labelText: 'Skill Categorization Tier Placement'),
                      items: const [
                        DropdownMenuItem(value: 'Beginner', child: Text('Beginner Tier')),
                        DropdownMenuItem(value: 'Intermediate', child: Text('Intermediate Tier')),
                        DropdownMenuItem(value: 'Advanced', child: Text('Advanced Tier')),
                      ],
                      onChanged: (val) => setState(() => _selectedTier = val!),
                    ),
                    const SizedBox(height: 25),
                    
                    // --- NEW FRESH GROUP SELECTOR DROPDOWN Component ---
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGroup,
                      decoration: const InputDecoration(labelText: 'Assign Group Pool Bracket *'),
                      items: const [
                        DropdownMenuItem(value: 'Group A', child: Text('Group A Pool')),
                        DropdownMenuItem(value: 'Group B', child: Text('Group B Pool')),
                        DropdownMenuItem(value: 'Group C', child: Text('Group C Pool')),
                        DropdownMenuItem(value: 'Group D', child: Text('Group D Pool')),
                      ],
                      onChanged: (val) => setState(() => _selectedGroup = val!),
                    ),
                    const SizedBox(height: 50),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _registerPlayerToPostgres,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                        child: const Text('Confirm & Save Competitor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}