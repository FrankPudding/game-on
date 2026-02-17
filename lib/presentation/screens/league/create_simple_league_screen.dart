import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../providers/leagues_provider.dart';
import '../../theme/app_theme.dart';

import '../../../domain/entities/ranking_policy.dart';
import '../../../domain/entities/ranking_policies/simple_ranking_policy.dart';

class CreateSimpleLeagueScreen extends ConsumerStatefulWidget {
  const CreateSimpleLeagueScreen({super.key});

  @override
  ConsumerState<CreateSimpleLeagueScreen> createState() =>
      _CreateSimpleLeagueScreenState();
}

class _CreateSimpleLeagueScreenState
    extends ConsumerState<CreateSimpleLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _winPointsController = TextEditingController(text: '3');
  final _drawPointsController = TextEditingController(text: '1');
  final _lossPointsController = TextEditingController(text: '0');
  final _uuid = const Uuid();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _winPointsController.dispose();
    _drawPointsController.dispose();
    _lossPointsController.dispose();
    super.dispose();
  }

  Future<void> _createLeague() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(leaguesProvider.notifier);
      final name = _nameController.text.trim();

      final leagueId = _uuid.v4();

      RankingPolicy rankingPolicy = SimpleRankingPolicy(
        id: 'simple_$leagueId',
        name: 'Simple Ranking Policy',
        leagueId: leagueId,
        pointsForWin: int.parse(_winPointsController.text),
        pointsForDraw: int.parse(_drawPointsController.text),
        pointsForLoss: int.parse(_lossPointsController.text),
      );

      await notifier.addLeague(
        id: leagueId,
        name: name,
        rankingPolicy: rankingPolicy,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('League created successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Simple League')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader('League Details'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'League Name',
                  hintText: 'e.g. Office Pool League',
                  prefixIcon: Icon(Icons.emoji_events),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Scoring Rules'),
              const SizedBox(height: 8),
              const Text('Points awarded for each match outcome.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _buildNumberField(_winPointsController, 'Win')),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildNumberField(_drawPointsController, 'Draw')),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildNumberField(_lossPointsController, 'Loss')),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createLeague,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.black),
                        )
                      : const Text('Create League'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.accentRed,
          ),
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null,
    );
  }
}
