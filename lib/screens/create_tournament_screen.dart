import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _drFormController = TextEditingController();
  
  int _roundRobinBestOf = 3;
  int _knockoutBestOf = 5;
  bool _isLoading = false;

  Future<void> _saveTournamentToDatabase() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final drUrl = _drFormController.text.trim();

      final settingsConfig = {
        "best_of": {
          "round-robin": _roundRobinBestOf,
          "knockout": _knockoutBestOf,
        }
      };

      await Supabase.instance.client.from('tournaments').insert({
        'name': name,
        'status': 'upcoming',
        'settings': settingsConfig,
        'dr_form_url': drUrl.isEmpty ? null : drUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Tournament Created Successfully inside Postgres!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scary Error: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configure Tournament')),
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
                    const Text('Tournament Metadata', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    const Divider(),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Tournament Name *', hintText: 'e.g., Office Monsoon Smash 2026'),
                      validator: (value) => value == null || value.isEmpty ? 'Please give it a cool name' : null,
                    ),
                    const SizedBox(height: 30),
                    
                    const Text('Match Game Rules Format', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    const Divider(),
                    DropdownButtonFormField<int>(
                      initialValue: _roundRobinBestOf,
                      decoration: const InputDecoration(labelText: 'Group Stage (Round Robin) Format'),
                      items: const [
                        DropdownMenuItem(value: 3, child: Text('Best of 3 Sets')),
                        DropdownMenuItem(value: 5, child: Text('Best of 5 Sets')),
                      ],
                      onChanged: (val) => setState(() => _roundRobinBestOf = val!),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<int>(
                      initialValue: _knockoutBestOf,
                      decoration: const InputDecoration(labelText: 'Knockout Stage (Finals) Format'),
                      items: const [
                        DropdownMenuItem(value: 3, child: Text('Best of 3 Sets')),
                        DropdownMenuItem(value: 5, child: Text('Best of 5 Sets')),
                        DropdownMenuItem(value: 7, child: Text('Best of 7 Sets (High Stakes)')),
                      ],
                      onChanged: (val) => setState(() => _knockoutBestOf = val!),
                    ),
                    const SizedBox(height: 30),

                    const Text('Business Continuity / DR Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    const Divider(),
                    TextFormField(
                      controller: _drFormController,
                      decoration: const InputDecoration(
                        labelText: 'Backup Fallback Google Form URL (Optional)',
                        hintText: 'https://forms.gle/...',
                      ),
                    ),
                    const SizedBox(height: 50),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveTournamentToDatabase,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                        child: const Text('Save & Initialize Tournament', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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