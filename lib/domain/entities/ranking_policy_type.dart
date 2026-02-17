enum RankingPolicyType {
  simple,
}

extension RankingPolicyTypeExtension on RankingPolicyType {
  String get displayName {
    switch (this) {
      case RankingPolicyType.simple:
        return 'Simple Scoring';
    }
  }

  String get description {
    switch (this) {
      case RankingPolicyType.simple:
        return 'Standard points for Match outcomes (e.g. 3 for Win, 1 for Draw, 0 for Loss).';
    }
  }
}
