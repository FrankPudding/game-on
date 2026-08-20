enum RankingPolicyType {
  simple,
  goalDifference,
}

extension RankingPolicyTypeExtension on RankingPolicyType {
  String get displayName {
    switch (this) {
      case RankingPolicyType.simple:
        return 'Simple Scoring';
      case RankingPolicyType.goalDifference:
        return 'Goal Difference';
    }
  }

  String get description {
    switch (this) {
      case RankingPolicyType.simple:
        return 'Standard points for Match outcomes (e.g. 3 for Win, 1 for Draw, 0 for Loss).';
      case RankingPolicyType.goalDifference:
        return 'Enter the score for each match and rank by points, goal difference, then goals for (e.g. Ping Pong, Table Football).';
    }
  }
}
