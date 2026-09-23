/// Pure domain value object for FargoRate stats.
class FargoPlayerStats {
  const FargoPlayerStats({
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

  FargoPlayerStats copyWith({
    int? matchesPlayed,
    int? wins,
    int? losses,
    int? rating,
  }) {
    return FargoPlayerStats(
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      rating: rating ?? this.rating,
    );
  }
}
