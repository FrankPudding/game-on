class League {
  final String id;
  final String name;
  final DateTime createdAt;
  final bool isArchived;
  final int pointsForWin;
  final int pointsForDraw;
  final int pointsForLoss;

  League({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isArchived = false,
    this.pointsForWin = 3,
    this.pointsForDraw = 1,
    this.pointsForLoss = 0,
  });

  League copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    bool? isArchived,
    int? pointsForWin,
    int? pointsForDraw,
    int? pointsForLoss,
  }) {
    return League(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
      pointsForWin: pointsForWin ?? this.pointsForWin,
      pointsForDraw: pointsForDraw ?? this.pointsForDraw,
      pointsForLoss: pointsForLoss ?? this.pointsForLoss,
    );
  }
}
