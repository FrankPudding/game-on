import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/hive_box_names.dart';
import '../../../domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import '../../../domain/entities/ranking_policies/simple_ranking_policy.dart';
import '../../../domain/entities/ranking_policy_type.dart';
import '../../../providers/leagues_provider.dart';
import '../../theme/app_theme.dart';
import 'create_simple_league_screen.dart';
import 'create_goal_difference_league_screen.dart';

/// Repo-driven provider: allowed [RankingPolicyType] for a category.
/// Queries [RankingPolicyRepository.getByCategory] and maps to types.
///
/// Simple and Goal Difference are only available in the custom category
/// ([kFallbackCategoryId]). For any other category this provider returns
/// an empty list, causing the UI to show "No scoring systems available".
/// Falls back to all types for custom when repo is empty or fails
/// (seed-only map is not runtime truth; custom is the only category
/// that supports these types).
final rankingPolicyTypesForCategoryProvider =
    FutureProvider.family<List<RankingPolicyType>, String>(
        (ref, categoryId) async {
  // Enforcement: only custom category supports simple / goalDifference.
  if (categoryId != kFallbackCategoryId) {
    return <RankingPolicyType>[];
  }
  final repo = ref.read(rankingPolicyRepositoryProvider);
  try {
    final policies = await repo.getByCategory(categoryId);
    if (policies.isEmpty) return RankingPolicyType.values;
    final types = <RankingPolicyType>{};
    for (final p in policies) {
      if (p is SimpleRankingPolicy) {
        types.add(RankingPolicyType.simple);
      } else if (p is GoalDifferenceRankingPolicy) {
        types.add(RankingPolicyType.goalDifference);
      }
    }
    if (types.isEmpty) return RankingPolicyType.values;
    return types.toList();
  } catch (_) {
    // Fallback to show all for custom if repo fails
    return RankingPolicyType.values;
  }
});

class SelectScoringSystemScreen extends ConsumerWidget {
  const SelectScoringSystemScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        final exists = categories.any((c) => c.id == categoryId);
        // Invalid categoryId fallback to kFallbackCategoryId with SnackBar, not pop (F5)
        final effectiveCategoryId = exists ? categoryId : kFallbackCategoryId;
        if (!exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Invalid category'),
                  backgroundColor: AppTheme.errorRed),
            );
          });
        }

        final allowedAsync = ref
            .watch(rankingPolicyTypesForCategoryProvider(effectiveCategoryId));
        return allowedAsync.when(
          data: (allowed) {
            if (allowed.isEmpty) {
              return Scaffold(
                appBar: AppBar(title: const Text('Select Scoring System')),
                body: const Center(
                    child:
                        Text('No scoring systems available for this category')),
              );
            }
            return Scaffold(
              appBar: AppBar(title: const Text('Select Scoring System')),
              body: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: allowed.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final policyType = allowed[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () {
                        switch (policyType) {
                          case RankingPolicyType.simple:
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateSimpleLeagueScreen(
                                    categoryId: effectiveCategoryId),
                              ),
                            );
                            break;
                          case RankingPolicyType.goalDifference:
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CreateGoalDifferenceLeagueScreen(
                                        categoryId: effectiveCategoryId),
                              ),
                            );
                            break;
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              policyType.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
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
          },
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Select Scoring System')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (err, stack) => Scaffold(
            appBar: AppBar(title: const Text('Select Scoring System')),
            body: Center(
                child: Text('Error: $err',
                    style: const TextStyle(color: AppTheme.errorRed))),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Select Scoring System')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('Select Scoring System')),
        body: Center(
            child: Text('Error: $err',
                style: const TextStyle(color: AppTheme.errorRed))),
      ),
    );
  }
}
