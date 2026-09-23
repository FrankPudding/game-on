import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/hive_box_names.dart';
import '../../../domain/entities/ranking_policies/fargo_rate_ranking_policy.dart';
import '../../../providers/leagues_provider.dart';
import '../../theme/app_theme.dart';

class CreateFargoRateLeagueScreen extends ConsumerStatefulWidget {
  const CreateFargoRateLeagueScreen(
      {super.key, this.categoryId = kSportsCategoryId});
  final String categoryId;

  @override
  ConsumerState<CreateFargoRateLeagueScreen> createState() =>
      _CreateFargoRateLeagueScreenState();
}

class _CreateFargoRateLeagueScreenState
    extends ConsumerState<CreateFargoRateLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _uuid = const Uuid();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createLeague() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final notifier = ref.read(leaguesProvider.notifier);
    final name = _nameController.text.trim();
    final leagueId = _uuid.v4();
    final rankingPolicy = FargoRateRankingPolicy(
      id: 'fargo_$leagueId',
      name: 'FargoRate Ranking Policy',
      leagueId: leagueId,
      categoryIds: kFargoCategoryIds,
    );
    await notifier.addLeague(
      id: leagueId,
      name: name,
      rankingPolicy: rankingPolicy,
    );
    if (mounted) {
      final state = ref.read(leaguesProvider);
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${state.error}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('League created successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  /// For testing / direct call
  Future<void> createLeague(WidgetRef ref, String name) async {
    final leagueId = _uuid.v4();
    final rankingPolicy = FargoRateRankingPolicy(
      id: 'fargo_$leagueId',
      name: 'FargoRate Ranking Policy',
      leagueId: leagueId,
      categoryIds: kFargoCategoryIds,
    );
    await ref.read(leaguesProvider.notifier).addLeague(
          id: leagueId,
          name: name,
          rankingPolicy: rankingPolicy,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New FargoRate League')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'League Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.accentRed,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'League Name',
                  hintText: 'e.g. Pool League',
                  prefixIcon: Icon(Icons.emoji_events),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter a name' : null,
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
}
