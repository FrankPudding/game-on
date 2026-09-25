import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/hive_box_names.dart';
import '../../../domain/entities/ranking_policies/elo_ranking_policy.dart';
import '../../../domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import '../../../domain/entities/ranking_policies/simple_ranking_policy.dart';
import '../../../domain/entities/ranking_policy_type.dart';
import '../../../providers/leagues_provider.dart';
import '../../theme/app_theme.dart';
import 'create_simple_league_screen.dart';
import 'create_goal_difference_league_screen.dart';
import 'create_fargo_rate_league_screen.dart';

/// Repo-driven provider: allowed [RankingPolicyType] for a category.
/// Queries [RankingPolicyRepository.getByCategory] and maps to types.
///
/// Simple and Goal Difference are only available in the custom category
/// ([kFallbackCategoryId]). FargoRate is only available in sports/pubgames
/// ([kSportsCategoryId]/[kPubGamesCategoryId]) via unconditional whitelist
/// — always returns [fargoRate] regardless of repo state (Pool must always
/// be available under Sports + Pub Games per kSeedCategoryPolicyTypes).
/// For other categories this provider returns an empty list.
/// Falls back to all types for custom when repo is empty or fails.
/// Bootstrap vs corruption distinction applies only to Custom fallback, not Fargo.
final rankingPolicyTypesForCategoryProvider =
    FutureProvider.family<List<RankingPolicyType>, String>(
        (ref, categoryId) async {
  // Fargo whitelist: sports/pubgames — unconditional Pool availability.
  // Pool (FargoRate) must ALWAYS be available under Sports + Pub Games via
  // whitelist from kSeedCategoryPolicyTypes, regardless of repo state.
  // Bootstrap vs corruption distinction applies only to Custom fallback, not Fargo.
  if (categoryId == kSportsCategoryId || categoryId == kPubGamesCategoryId) {
    return [RankingPolicyType.elo];
  }
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
      } else if (p is EloRankingPolicy) {
        types.add(RankingPolicyType.elo);
      } else if (p is FargoRateRankingPolicy) {
        types.add(RankingPolicyType.fargoRate);
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
                          case RankingPolicyType.elo:
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CreateFargoRateLeagueScreen(
                                        categoryId: effectiveCategoryId),
                              ),
                            );
                            break;
                          case RankingPolicyType.fargoRate:
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CreateFargoRateLeagueScreen(
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
