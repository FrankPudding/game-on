import 'package:flutter/material.dart';
import '../../domain/value_objects/category_icon.dart';

IconData mapCategoryIconToIconData(CategoryIcon icon) {
  switch (icon) {
    case CategoryIcon.chess:
      return Icons.grid_on;
    case CategoryIcon.playingCards:
      return Icons.style;
    case CategoryIcon.sportsSoccer:
      return Icons.sports_soccer;
    case CategoryIcon.sportsEsports:
      return Icons.sports_esports;
    case CategoryIcon.categoryOther:
      return Icons.category_outlined;
    case CategoryIcon.other:
      return Icons.category;
  }
}

IconData mapIconNameToIconData(String iconName) {
  final icon = CategoryIconExtension.fromName(iconName);
  return mapCategoryIconToIconData(icon);
}
