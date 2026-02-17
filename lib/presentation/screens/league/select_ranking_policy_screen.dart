import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../../domain/entities/ranking_policy_type.dart';
import 'create_simple_league_screen.dart';

class SelectRankingPolicyScreen extends StatelessWidget {
  const SelectRankingPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Scoring System')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: RankingPolicyType.values.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final policyType = RankingPolicyType.values[index];
          return Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () {
                if (policyType == RankingPolicyType.simple) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateSimpleLeagueScreen(),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      policyType.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      policyType.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
