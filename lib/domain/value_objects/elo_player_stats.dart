/// Pure domain value object for Elo stats.
class EloPlayerStats {
  const EloPlayerStats({
    required this.matchesPlayed,
    required this.wins,
    required this.losses,
    required this.rating,
  });

  final int matchesPlayed;
  final int wins;
  final int losses;
  final int rating;

  /// Win rate = wins / matchesPlayed or 0 if 0.
  double get winRate => matchesPlayed == 0 ? 0 : wins / matchesPlayed;

  EloPlayerStats copyWith({
    int? matchesPlayed,
    int? wins,
    int? losses,
    int? rating,
  }) {
    return EloPlayerStats(
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      rating: rating ?? this.rating,
    );
  }
}

@Deprecated('Use EloPlayerStats')
typedef FargoPlayerStats = EloPlayerStats;
