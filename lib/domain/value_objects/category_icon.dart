enum CategoryIcon {
  chess,
  playingCards,
  sportsSoccer,
  sportsEsports,
  sportsTennis,
  categoryOther,
  other,
}

extension CategoryIconExtension on CategoryIcon {
  String get iconName {
    switch (this) {
      case CategoryIcon.chess:
        return 'chess';
      case CategoryIcon.playingCards:
        return 'playing_cards';
      case CategoryIcon.sportsSoccer:
        return 'sports_soccer';
      case CategoryIcon.sportsEsports:
        return 'sports_esports';
      case CategoryIcon.sportsTennis:
        return 'sports_tennis';
      case CategoryIcon.categoryOther:
        return 'category_other';
      case CategoryIcon.other:
        return 'other';
    }
  }

  static CategoryIcon fromName(String? name) {
    if (name == null) return CategoryIcon.other;
    switch (name) {
      case 'chess':
        return CategoryIcon.chess;
      case 'playing_cards':
        return CategoryIcon.playingCards;
      case 'sports_soccer':
        return CategoryIcon.sportsSoccer;
      case 'sports_esports':
        return CategoryIcon.sportsEsports;
      case 'sports_tennis':
        return CategoryIcon.sportsTennis;
      case 'category_other':
        return CategoryIcon.categoryOther;
      case 'other':
        return CategoryIcon.other;
      default:
        return CategoryIcon.other;
    }
  }
}
