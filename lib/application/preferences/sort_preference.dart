// ignore_for_file: public_member_api_docs, unintended_html_in_doc_comment

/// Sort mode for leagues list.
///
/// - [lastPlayed]  → default, sorted by most recent completed match (R1)
/// - [alphabetical] → sorted via [compareNames] (R2)
enum LeagueSortMode {
  lastPlayed,
  alphabetical,
}

/// Persisted sort preference for My Leagues.
///
/// Invariants:
/// - Default is [LeagueSortMode.lastPlayed] descending (most recent first,
///   null/Never last) — fulfils R1 + R4 no-flicker requirement.
/// - [descending] reverses direction in either mode (R3).
/// - Persisted in Hive Box<String> `app_preferences` under keys
///   `sort_mode` / `sort_descending` (R4).
/// - Domain-pure value object: no DTO / Hive imports.
///
/// Skeleton: structure only.
class LeagueSortPreference {
  const LeagueSortPreference({
    required this.mode,
    required this.descending,
  });

  final LeagueSortMode mode;
  final bool descending;

  /// Default preference: lastPlayed descending with no flicker.
  static const defaultPreference = LeagueSortPreference(
    mode: LeagueSortMode.lastPlayed,
    descending: true,
  );

  /// Helper consts for the single-button sort menu (Latest / Oldest / A-Z / Z-A).
  static const latest = LeagueSortPreference(
    mode: LeagueSortMode.lastPlayed,
    descending: true,
  );
  static const oldest = LeagueSortPreference(
    mode: LeagueSortMode.lastPlayed,
    descending: false,
  );
  static const aToZ = LeagueSortPreference(
    mode: LeagueSortMode.alphabetical,
    descending: false,
  );
  static const zToA = LeagueSortPreference(
    mode: LeagueSortMode.alphabetical,
    descending: true,
  );

  LeagueSortPreference copyWith({
    LeagueSortMode? mode,
    bool? descending,
  }) {
    return LeagueSortPreference(
      mode: mode ?? this.mode,
      descending: descending ?? this.descending,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeagueSortPreference &&
        other.mode == mode &&
        other.descending == descending;
  }

  @override
  int get hashCode => Object.hash(mode, descending);

  @override
  String toString() =>
      'LeagueSortPreference(mode: $mode, descending: $descending)';
}
